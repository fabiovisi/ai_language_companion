import '../../domain/models/session_config.dart';

abstract class TtsService {
  // Interface abstrata para Text-to-Speech (VO-02).

  /// Fala o texto no idioma informado (ex.: 'en_US', 'pt_BR') e só termina
  /// quando a fala acaba.
  Future<void> speak(
    String text, {
    required SpeechRate rate,
    required String localeId,
  });
  Future<void> stop();
  bool get isSpeaking;

  /// Voz em uso e última falha, para o debug. Null se não houver.
  String? get debugInfo;
}
