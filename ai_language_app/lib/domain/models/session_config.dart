enum SessionMode { continuous, spaced }

enum SpeechRate { normal, slow, verySlow }

class SessionConfig {
  // Configuração escolhida pelo aluno antes de iniciar a sessão (PF-03 a PF-05).
  // Pode ser alterada antes da sessão; mudança durante sessão preserva contexto (PF-04).

  final String? topic;         // null = tema livre
  final SessionMode mode;
  final SpeechRate speechRate;

  const SessionConfig({
    this.topic,
    required this.mode,
    required this.speechRate,
  });
}
