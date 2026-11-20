import 'session_config.dart';
import 'student_profile.dart';

/// Escolhas do aluno guardadas no aparelho entre uma sessão e outra.
class AppSettings {
  final String targetLanguage;
  final CefrLevel cefrLevel;
  final String? topic; // null = tema livre
  final SessionMode mode;
  final SpeechRate speechRate;
  final bool showDebugInfo;

  const AppSettings({
    this.targetLanguage = 'Inglês',
    this.cefrLevel = CefrLevel.a2,
    this.topic,
    this.mode = SessionMode.continuous,
    this.speechRate = SpeechRate.normal,
    this.showDebugInfo = false,
  });

  AppSettings copyWith({
    String? targetLanguage,
    CefrLevel? cefrLevel,
    String? Function()? topic, // função para permitir voltar a null
    SessionMode? mode,
    SpeechRate? speechRate,
    bool? showDebugInfo,
  }) =>
      AppSettings(
        targetLanguage: targetLanguage ?? this.targetLanguage,
        cefrLevel: cefrLevel ?? this.cefrLevel,
        topic: topic != null ? topic() : this.topic,
        mode: mode ?? this.mode,
        speechRate: speechRate ?? this.speechRate,
        showDebugInfo: showDebugInfo ?? this.showDebugInfo,
      );

  Map<String, dynamic> toJson() => {
        'targetLanguage': targetLanguage,
        'cefrLevel': cefrLevel.name,
        'topic': topic,
        'mode': mode.name,
        'speechRate': speechRate.name,
        'showDebugInfo': showDebugInfo,
      };

  /// Lê o que foi guardado. Valores ausentes ou desconhecidos (ex.: de uma
  /// versão antiga do app) voltam ao padrão, sem erro.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const d = AppSettings();
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);

    return AppSettings(
      targetLanguage: json['targetLanguage'] is String
          ? json['targetLanguage'] as String
          : d.targetLanguage,
      cefrLevel: byName(CefrLevel.values, json['cefrLevel'], d.cefrLevel),
      topic: json['topic'] is String ? json['topic'] as String : null,
      mode: byName(SessionMode.values, json['mode'], d.mode),
      speechRate: byName(SpeechRate.values, json['speechRate'], d.speechRate),
      showDebugInfo: json['showDebugInfo'] == true,
    );
  }

  SessionConfig toSessionConfig() =>
      SessionConfig(topic: topic, mode: mode, speechRate: speechRate);

  StudentProfile toStudentProfile() => StudentProfile(
        targetLanguage: targetLanguage,
        cefrLevel: cefrLevel,
        lastSessionConfig: toSessionConfig(),
      );
}
