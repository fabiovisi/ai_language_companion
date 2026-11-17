import '../../domain/models/session_config.dart';

abstract class TtsService {
  // Interface abstrata para Text-to-Speech (VO-02).
  // Implementação real depende de decisão de provedor (seção 16 da spec).

  Future<void> speak(String text, {required SpeechRate rate});
  Future<void> stop();
  bool get isSpeaking;
}
