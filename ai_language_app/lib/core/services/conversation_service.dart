import '../../domain/models/student_profile.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/correction.dart';

class AiTurn {
  final String text;      // fala principal (retorno sobre o que o aluno disse)
  final String? followUp; // nova pergunta, falada após uma pausa
  final Correction? correction;

  // Preenchidos apenas quando há erro detectado:
  final String? correctionReaction; // fala no idioma alvo (ex: "I didn't catch that...")
  final String? instructionPt;      // instrução específica (português até B2; idioma alvo em C1-C2)

  /// Resposta a um pedido de ajuda: explicação no idioma nativo (até B2),
  /// com as palavras do idioma da aula entre aspas. Quando presente, [text]
  /// traz a mesma explicação e [followUp], a pergunta com palavras simples.
  final String? help;

  /// O aluno pediu para falar mais devagar: a pergunta seguinte usa uma
  /// velocidade mais lenta.
  final bool slower;

  const AiTurn({
    required this.text,
    this.followUp,
    this.correction,
    this.correctionReaction,
    this.instructionPt,
    this.help,
    this.slower = false,
  });

  bool get hasCorrection => correction != null;
  bool get isHelp => help != null;
}

/// Informações de debug que os serviços de IA reais expõem para a tela.
abstract class LlmDebugInfo {
  String get providerName;   // ex.: 'Groq'
  String? get lastModel;     // modelo que respondeu no último turno
  Duration? get lastDuration; // tempo de resposta do último turno
  String? get lastError;     // motivo da última falha; null se não houve
}

abstract class ConversationService {
  // Interface abstrata para o motor conversacional/LLM (AC-03).
  // Regra para distribuição: chaves de API ficam no backend (PR-04).
  // Fase atual (uso pessoal): a chave do Gemini vem via --dart-define.

  /// Abertura da conversa: saudação (text) e primeira pergunta (followUp),
  /// no idioma, tema e nível da aula.
  Future<AiTurn> startConversation({
    required StudentProfile profile,
    required SessionConfig config,
  });

  /// [isRetryAfterCorrection]: o aluno está tentando de novo após uma correção.
  /// Pedidos de ajuda são reconhecidos pela IA pelo sentido da fala.
  Future<AiTurn> sendTurn({
    required String userUtterance,
    required StudentProfile profile,
    required SessionConfig config,
    bool isRetryAfterCorrection = false,
  });
}
