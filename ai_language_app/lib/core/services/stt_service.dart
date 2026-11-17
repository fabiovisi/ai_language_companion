class SttResult {
  final String transcript;
  final double confidence; // 0.0 a 1.0

  const SttResult({required this.transcript, required this.confidence});

  bool get isReliable => confidence >= 0.7; // limiar a validar
}

abstract class SttService {
  // Interface abstrata para Speech-to-Text (VO-01).
  // Implementação real depende de decisão de provedor (seção 16 da spec).

  Future<SttResult> recognize(Stream<List<int>> audioStream);
  Future<void> cancel();
}
