import 'session_config.dart';

enum CefrLevel { a1, a2, b1, b2, c1, c2 }

class StudentProfile {
  // Perfil persistido entre sessões (AC-01).
  // Um perfil por instalação no MVP — sem login/conta por enquanto.

  final String targetLanguage;
  final CefrLevel cefrLevel;
  final SessionConfig lastSessionConfig;

  const StudentProfile({
    required this.targetLanguage,
    required this.cefrLevel,
    required this.lastSessionConfig,
  });
}
