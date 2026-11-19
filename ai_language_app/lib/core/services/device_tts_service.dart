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
    final lang = localeId.replaceAll('_', '-');
    await _tts.setLanguage(lang);
    if (kIsWeb) {
      final voice = await _preferredWebVoice(lang);
      if (voice != null) await _tts.setVoice(voice);
    }
    await _tts.setSpeechRate(_rateValue(rate) * _rateFactor(lang));

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
    if (kIsWeb) await _waitForVoices();
    _configured = true;
  }

  // No navegador, a lista de vozes carrega alguns instantes depois de a
  // página abrir. Sem esperar, a primeira fala sai com a voz padrão do sistema.
  // Confere a cada 0,1 s e desiste após 2 s, para nunca travar a aula.
  Future<void> _waitForVoices() async {
    for (var i = 0; i < 20; i++) {
      final voices = await _tts.getVoices;
      if (voices is List && voices.isNotEmpty) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // Voz escolhida por idioma no navegador (guardada para não procurar de novo).
  final Map<String, Map<String, String>?> _webVoices = {};

  // No navegador, o flutter_tts pega a primeira voz do idioma, que no Windows
  // costuma ser uma voz da Microsoft, mais robótica. Prefere as vozes do Google.
  Future<Map<String, String>?> _preferredWebVoice(String lang) async {
    if (_webVoices.containsKey(lang)) return _webVoices[lang];

    Map<String, String>? first;
    Map<String, String>? google;
    final voices = await _tts.getVoices;
    if (voices is List) {
      for (final v in voices) {
        if (v is! Map) continue;
        final voice = {
          'name': '${v['name'] ?? ''}',
          'locale': '${v['locale'] ?? ''}',
        };
        if (voice['locale']!.toLowerCase() != lang.toLowerCase()) continue;
        first ??= voice;
        if (google == null && voice['name']!.contains('Google')) google = voice;
      }
    }

    final chosen = google ?? first;
    _webVoices[lang] = chosen;
    return chosen;
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

  // Tempo máximo generoso: 10 s + 150 ms por caractere.
  Duration _maxDuration(String text) =>
      Duration(milliseconds: 10000 + text.length * 150);
}
