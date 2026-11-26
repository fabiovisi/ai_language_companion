import '../../domain/models/session_config.dart';
import 'tts_service.dart';

class MockTtsService implements TtsService {
  bool _isSpeaking = false;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  String? get debugInfo => null;

  @override
  Future<void> speak(
    String text, {
    required SpeechRate rate,
    required String localeId,
  }) async {
    _isSpeaking = true;
    final duration = switch (rate) {
      SpeechRate.normal => const Duration(seconds: 2),
      SpeechRate.slow => const Duration(milliseconds: 2800),
      SpeechRate.verySlow => const Duration(milliseconds: 3600),
    };
    await Future.delayed(duration);
    _isSpeaking = false;
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
  }
}
