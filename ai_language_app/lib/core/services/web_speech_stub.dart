import 'voice_choice.dart';
import 'web_speech_outcome.dart';

// Fora do navegador não há voz do Chrome: o DeviceTtsService usa o
// flutter_tts. Estas funções não são chamadas nesse caso.

List<WebVoice> webVoices() => const [];

Future<WebSpeakOutcome> webSpeak(
  String text, {
  required String lang,
  String? voiceName,
  required double rate,
  required Duration timeout,
}) async =>
    WebSpeakOutcome.error;

void webCancel() {}
