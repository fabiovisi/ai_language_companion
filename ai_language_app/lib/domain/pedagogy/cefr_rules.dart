import '../models/student_profile.dart';

enum InstructionLanguage { portuguese, targetLanguage }

class CefrRules {
  // Regras pedagógicas por faixa CEFR (seção 7 da spec).
  // A1-B2: instruções em português. C1-C2: tudo no idioma-alvo.

  static InstructionLanguage instructionLanguage(CefrLevel level) {
    return switch (level) {
      CefrLevel.c1 || CefrLevel.c2 => InstructionLanguage.targetLanguage,
      _ => InstructionLanguage.portuguese,
    };
  }

  static bool allowsTranslation(CefrLevel level) {
    return level != CefrLevel.c1 && level != CefrLevel.c2;
  }
}
