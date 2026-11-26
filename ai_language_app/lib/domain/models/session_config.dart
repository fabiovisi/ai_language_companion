enum SessionMode { continuous, spaced }

enum SpeechRate { normal, slow, verySlow }

/// Intervalos disponíveis no modo intervalado, em segundos.
const spacedIntervalOptions = [30, 60, 120];
const defaultSpacedIntervalSeconds = 60;

/// Texto do intervalo para a tela (ex.: 30 → "30 s", 60 → "1 min").
String intervalLabel(int seconds) =>
    seconds % 60 == 0 ? '${seconds ~/ 60} min' : '$seconds s';

class SessionConfig {
  // Configuração escolhida pelo aluno antes de iniciar a sessão (PF-03 a PF-05).
  // Pode ser alterada antes da sessão; mudança durante sessão preserva contexto (PF-04).

  final String? topic;         // null = tema livre
  final SessionMode mode;
  final SpeechRate speechRate;

  /// Modo intervalado: tempo entre o comentário da IA e a próxima pergunta.
  final Duration spacedInterval;

  const SessionConfig({
    this.topic,
    required this.mode,
    required this.speechRate,
    this.spacedInterval =
        const Duration(seconds: defaultSpacedIntervalSeconds),
  });
}
