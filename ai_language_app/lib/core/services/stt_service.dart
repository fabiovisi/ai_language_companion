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

  /// Ouve o aluno e devolve o texto. [localeId] é o idioma da aula
  /// (ex.: 'en_US'); reconhecimentos multilíngues podem ignorá-lo.
  Future<SttResult> recognize({required String localeId});

  /// Transcreve de novo a última fala, com o idioma fixo em [localeId].
  /// Usado quando o reconhecimento identificou o idioma nativo e pode ter se
  /// confundido com o sotaque. Devolve null se não for possível (sem áudio
  /// guardado ou reconhecimento que não suporta).
  Future<SttResult?> retranscribe({required String localeId});

  Future<void> cancel();
}
