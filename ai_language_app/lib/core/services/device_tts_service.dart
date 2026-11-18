import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/models/session_config.dart';
import 'tts_service.dart';

/// TTS usando a voz do próprio aparelho ou navegador (gratuito).
class DeviceTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _configured = false;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<void> speak(
    String text, {
    required SpeechRate rate,
    required String localeId,
  }) async {
    if (text.trim().isEmpty) return;
    await _configureOnce();

    // flutter_tts usa o formato 'en-US'; o app usa 'en_US'.
    await _tts.setLanguage(localeId.replaceAll('_', '-'));
    await _tts.setSpeechRate(_rateValue(rate));

    _isSpeaking = true;
    try {
      // Segurança: se o aviso de fim nunca chegar, não trava a aula.
      await _tts.speak(text).timeout(_maxDuration(text), onTimeout: () async {
        await _tts.stop();
      });
    } finally {
      _isSpeaking = false;
    }
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> _configureOnce() async {
    if (_configured) return;
    // Faz o speak() só terminar quando a fala acabar.
    await _tts.awaitSpeakCompletion(true);
    _configured = true;
  }

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

  // Tempo máximo generoso: 10 s + 150 ms por caractere.
  Duration _maxDuration(String text) =>
      Duration(milliseconds: 10000 + text.length * 150);
}
