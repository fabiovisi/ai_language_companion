import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/models/session_config.dart';
import 'tts_service.dart';
import 'voice_choice.dart';
import 'web_speech.dart';

/// TTS usando a voz do próprio aparelho ou navegador (gratuito).
///
/// - Navegador: voz do Chrome usada diretamente (ver web_speech.dart), com
///   prazo por frase e troca para a voz local do sistema se a voz do Google
///   falhar.
/// - Celular: flutter_tts.
class DeviceTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _configured = false;

  // Navegador: idiomas cuja voz do Google falhou nesta sessão (passam a usar
  // a voz local do sistema), última voz usada e última falha.
  final Set<String> _webFallback = {};
  String? _lastVoice;
  String? _lastError;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  String? get debugInfo {
    if (!kIsWeb) return null;
    final voice = _lastVoice ?? 'padrão';
    return _lastError == null ? voice : '$voice · falha: $_lastError';
  }

  @override
  Future<void> speak(
    String text, {
    required SpeechRate rate,
    required String localeId,
  }) async {
    if (text.trim().isEmpty) return;
    await _configureOnce();

    // A voz usa o formato 'en-US'; o app usa 'en_US'.
    final lang = localeId.replaceAll('_', '-');
    final rateValue = _rateValue(rate) * _rateFactor(lang);

    _isSpeaking = true;
    try {
      if (kIsWeb) {
        await _speakWeb(text, lang, rateValue);
      } else {
        await _speakDevice(text, lang, rateValue);
      }
    } finally {
      _isSpeaking = false;
    }
  }

  @override
  Future<void> stop() async {
    if (kIsWeb) {
      webCancel();
    } else {
      await _tts.stop();
    }
    _isSpeaking = false;
  }

  // — Navegador —

  // Fala a frase; se a voz falhar (erro, prazo esgotado ou fim rápido demais),
  // troca para a voz local do idioma pelo resto da sessão e repete a frase.
  Future<void> _speakWeb(String text, String lang, double rate) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      final fallback = _webFallback.contains(lang);
      final voice = chooseWebVoice(webVoices(), lang, fallback: fallback);
      _lastVoice = voice?.name;

      final watch = Stopwatch()..start();
      final outcome = await webSpeak(text,
          lang: lang,
          voiceName: voice?.name,
          rate: rate,
          timeout: speakTimeout(text, rate));

      if (outcome == WebSpeakOutcome.cancelled) return; // pausa ou saída
      final tooFast = outcome == WebSpeakOutcome.completed &&
          finishedTooFast(text, watch.elapsed, rate);
      if (outcome == WebSpeakOutcome.completed && !tooFast) return;

      _lastError =
          '${tooFast ? 'terminou sem falar' : outcome.name} (${voice?.name ?? lang})';
      if (fallback) return; // já estava na voz local: segue a aula
      _webFallback.add(lang);
    }
  }

  // — Celular —

  Future<void> _speakDevice(String text, String lang, double rate) async {
    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(rate);
    // Segurança: se o aviso de fim nunca chegar, não trava a aula.
    await _tts.speak(text).timeout(speakTimeout(text, rate * 2),
        onTimeout: () async {
      await _tts.stop();
    });
  }

  Future<void> _configureOnce() async {
    if (_configured) return;
    if (kIsWeb) {
      await _waitForVoices();
    } else {
      // Faz o speak() só terminar quando a fala acabar.
      await _tts.awaitSpeakCompletion(true);
    }
    _configured = true;
  }

  // No navegador, a lista de vozes carrega alguns instantes depois de a
  // página abrir. Sem esperar, a primeira fala sai com a voz padrão do sistema.
  // Confere a cada 0,1 s e desiste após 2 s, para nunca travar a aula.
  Future<void> _waitForVoices() async {
    for (var i = 0; i < 20; i++) {
      if (webVoices().isNotEmpty) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // Ajuste de velocidade por idioma, só no navegador: algumas vozes falam
  // naturalmente mais devagar. Ex.: 1.15 = 15% mais rápido. A ajustar ouvindo.
  static const _webRateFactors = {'pt-br': 1.15};

  double _rateFactor(String lang) =>
      kIsWeb ? (_webRateFactors[lang.toLowerCase()] ?? 1.0) : 1.0;

  // Cada plataforma usa uma escala própria: no navegador o normal é 1.0;
  // no Android e no iPhone, 0.5. Valores iniciais, a ajustar ouvindo.
  double _rateValue(SpeechRate rate) {
    if (kIsWeb) {
      return switch (rate) {
        SpeechRate.normal => 1.0,
        SpeechRate.slow => 0.8,
        SpeechRate.verySlow => 0.6,
      };
    }
    return switch (rate) {
      SpeechRate.normal => 0.5,
      SpeechRate.slow => 0.4,
      SpeechRate.verySlow => 0.3,
    };
  }
}
