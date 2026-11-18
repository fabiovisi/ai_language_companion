class SttResult {
  final String transcript;
  final double confidence; // 0.0 a 1.0

  const SttResult({required this.transcript, required this.confidence});

  bool get isReliable => confidence >= 0.7; // limiar a validar
}

abstract class SttService {
  // Interface abstrata para Speech-to-Text (VO-01).

  /// Ouve o aluno no idioma informado (ex.: 'en_US') e devolve o texto.
  Future<SttResult> recognize({required String localeId});
  Future<void> cancel();
}
