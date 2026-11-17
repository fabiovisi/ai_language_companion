import '../models/progress_snapshot.dart';

class ProgressEvaluator {
  // Avalia progresso nas 6 dimensões e decide ajustes de dificuldade (PG-01 a PG-06).
  // Ajuste só ocorre com evidência de múltiplas interações — limiares a calibrar (AC-11).
  // Placeholder: lógica real depende de decisão de produto sobre janela e limiares.

  static bool shouldIncreaseDifficulty(ProgressSnapshot snapshot) {
    // TODO: calibrar limiares com base em QA e testes de usabilidade
    return false;
  }

  static bool shouldDecreaseDifficulty(ProgressSnapshot snapshot) {
    // TODO: calibrar limiares com base em QA e testes de usabilidade
    return false;
  }
}
