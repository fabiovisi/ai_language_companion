import 'student_profile.dart';

/// Nomes e descrições amigáveis dos níveis, exibidos ao aluno.
/// Por dentro, o app e a IA continuam usando os códigos (A1 a C2).
extension CefrLevelLabels on CefrLevel {
  String get label => switch (this) {
        CefrLevel.a1 => 'Iniciante',
        CefrLevel.a2 => 'Básico',
        CefrLevel.b1 => 'Intermediário',
        CefrLevel.b2 => 'Intermediário avançado',
        CefrLevel.c1 => 'Avançado',
        CefrLevel.c2 => 'Fluente',
      };

  String get description => switch (this) {
        CefrLevel.a1 => 'Conheço palavras e frases bem simples',
        CefrLevel.a2 => 'Falo de mim e da minha rotina com frases curtas',
        CefrLevel.b1 => 'Mantenho uma conversa sobre temas do dia a dia',
        CefrLevel.b2 => 'Converso com naturalidade sobre vários assuntos',
        CefrLevel.c1 =>
          'Me expresso com fluência, inclusive em temas complexos. '
              'Correções no idioma estudado',
        CefrLevel.c2 =>
          'Domino o idioma quase como um nativo. Correções no idioma estudado',
      };
}
