import '../../domain/models/student_profile.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/correction.dart';

class AiTurn {
  final String text;
  final Correction? correction;

  // Preenchidos apenas quando há erro detectado:
  final String? correctionReaction; // fala no idioma alvo (ex: "I didn't catch that...")
  final String? instructionPt;      // instrução específica em português

  const AiTurn({
    required this.text,
    this.correction,
    this.correctionReaction,
    this.instructionPt,
  });

  bool get hasCorrection => correction != null;
}

abstract class ConversationService {
  // Interface abstrata para o motor conversacional/LLM (AC-03).
  // Chaves de API nunca ficam no cliente — passam pelo backend (PR-04).
  // Implementação real depende de decisão de provedor e arquitetura de backend.

  Future<AiTurn> sendTurn({
    required String userUtterance,
    required StudentProfile profile,
    required SessionConfig config,
  });
}
