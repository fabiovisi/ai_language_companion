class SttResult {
  final String transcript;
  final double confidence; // 0.0 a 1.0

  /// Idioma identificado na fala, em inglês e minúsculas (ex.: 'english',
  /// 'portuguese'). Null quando o reconhecimento não identifica o idioma.
  final String? language;

  const SttResult({
    required this.transcript,
    required this.confidence,
    this.language,
  });

  static const empty = SttResult(transcript: '', confidence: 0.0);

  bool get isReliable => confidence >= 0.7; // limiar a validar
}

abstract class SttService {
  // Interface abstrata para Speech-to-Text (VO-01).

  /// Nome do reconhecimento, para o debug (ex.: 'Whisper', 'Navegador').
  String get engineName;

  /// Motivo da última falha, para o debug. Null se não houve erro.
  String? get lastError;

  /// Medidas da última escuta, para o debug (ex.: volume). Null se não houver.
  String? get debugInfo;

  /// Ouve o aluno e devolve o texto no idioma da aula [localeId]
  /// (ex.: 'en_US'). Fala em outro idioma (ex.: um pedido de ajuda em
  /// português) pode chegar traduzida para o idioma da aula.
  Future<SttResult> recognize({required String localeId});

  Future<void> cancel();
}
