import '../models/correction.dart';

class CorrectionFlow {
  // Gerencia o fluxo de correção pedagógica (CP-01 a CP-06).
  // maxAttempts: limite de tentativas antes de dar o modelo e seguir (CP-06).
  // Hipótese inicial: 2 tentativas adicionais — a validar.

  static const int maxAttempts = 2;

  static Correction registerAttempt(Correction correction, bool success) {
    if (success) {
      return Correction(
        type: correction.type,
        originalUtterance: correction.originalUtterance,
        correctForm: correction.correctForm,
        attempts: correction.attempts + 1,
        resolved: true,
      );
    }

    final newAttempts = correction.attempts + 1;
    return Correction(
      type: correction.type,
      originalUtterance: correction.originalUtterance,
      correctForm: correction.correctForm,
      attempts: newAttempts,
      resolved: newAttempts >= maxAttempts,
    );
  }
}
