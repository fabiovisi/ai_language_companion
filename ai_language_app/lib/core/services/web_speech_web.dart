import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'voice_choice.dart';
import 'web_speech_outcome.dart';

// Referência à frase em andamento: sem ela, o Chrome pode descartar a frase
// da memória antes do fim, e o aviso de fim nunca chega.
web.SpeechSynthesisUtterance? _current;

List<WebVoice> webVoices() => [
      for (final v in web.window.speechSynthesis.getVoices().toDart)
        (name: v.name, lang: v.lang, local: v.localService),
    ];

Future<WebSpeakOutcome> webSpeak(
  String text, {
  required String lang,
  String? voiceName,
  required double rate,
  required Duration timeout,
}) async {
  final synth = web.window.speechSynthesis;
  // Limpa a fila e destrava o motor de voz, mas só quando há algo pendente:
  // cancelar com o motor parado pode atrasar o início da próxima frase.
  if (synth.speaking || synth.pending || synth.paused) synth.cancel();

  final utterance = web.SpeechSynthesisUtterance(text)
    ..lang = lang
    ..rate = rate;
  if (voiceName != null) {
    for (final v in synth.getVoices().toDart) {
      if (v.name == voiceName) {
        utterance.voice = v;
        break;
      }
    }
  }

  final done = Completer<WebSpeakOutcome>();
  utterance.onend = ((web.Event _) {
    if (!done.isCompleted) done.complete(WebSpeakOutcome.completed);
  }).toJS;
  utterance.onerror = ((web.SpeechSynthesisErrorEvent e) {
    if (done.isCompleted) return;
    // Interrompida pelo próprio app (cancel): não é falha da voz.
    final cancelled = e.error == 'interrupted' || e.error == 'canceled';
    done.complete(
        cancelled ? WebSpeakOutcome.cancelled : WebSpeakOutcome.error);
  }).toJS;

  _current = utterance;
  synth.speak(utterance);

  final outcome = await done.future
      .timeout(timeout, onTimeout: () => WebSpeakOutcome.timeout);
  if (outcome == WebSpeakOutcome.timeout) synth.cancel();
  if (identical(_current, utterance)) _current = null;
  return outcome;
}

void webCancel() => web.window.speechSynthesis.cancel();
