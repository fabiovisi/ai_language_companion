enum ErrorType { grammar, vocabulary, pronunciation, contextualUsage }

class Correction {
  // Representa um erro detectado e o fluxo pedagógico associado (CP-01 a CP-06).
  // attempts: quantas tentativas o aluno já fez para corrigir.
  // resolved: true quando o aluno acertou ou o limite foi atingido.

  final ErrorType type;
  final String originalUtterance;
  final String correctForm;
  final int attempts;
  final bool resolved;

  const Correction({
    required this.type,
    required this.originalUtterance,
    required this.correctForm,
    this.attempts = 0,
    this.resolved = false,
  });
}
