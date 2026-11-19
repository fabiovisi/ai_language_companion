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

  const AiTurn({
    required this.text,
    this.followUp,
    this.correction,
    this.correctionReaction,
    this.instructionPt,
  });

  bool get hasCorrection => correction != null;
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

  /// [isRetryAfterCorrection]: o aluno está tentando de novo após uma correção.
  Future<AiTurn> sendTurn({
    required String userUtterance,
    required StudentProfile profile,
    required SessionConfig config,
    bool isRetryAfterCorrection = false,
  });
}
