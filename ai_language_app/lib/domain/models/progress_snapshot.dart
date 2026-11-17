class ProgressSnapshot {
  // Avaliação contínua nas 6 dimensões (PG-01 a PG-06).
  // Valores entre 0.0 e 1.0 — estimativas pedagógicas internas, não notas oficiais.
  // evidenceCount: número de interações consideradas na janela de avaliação.

  final double grammar;
  final double vocabulary;
  final double auditoryComprehension;
  final double fluency;
  final double pronunciation;
  final double autonomy;
  final int evidenceCount;

  const ProgressSnapshot({
    this.grammar = 0.0,
    this.vocabulary = 0.0,
    this.auditoryComprehension = 0.0,
    this.fluency = 0.0,
    this.pronunciation = 0.0,
    this.autonomy = 0.0,
    this.evidenceCount = 0,
  });
}
