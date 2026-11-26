import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/drive_mode/drive_mode_provider.dart';
import '../../core/storage/settings_controller.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/cefr_level_labels.dart';
import '../../domain/models/language_locale.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/student_profile.dart';
import '../common/option_widgets.dart';

/// Uma opção de modo: contínuo, ou intervalado com o tempo em segundos.
typedef _Pace = ({SessionMode mode, int seconds});

/// Configurações que quase não mudam entre uma aula e outra.
/// Cada mudança é guardada no aparelho.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Modo da sessão com o intervalo (ex.: "Intervalado · 1 min").
  static String paceLabel(SessionMode mode, int seconds) =>
      mode == SessionMode.continuous
          ? 'Contínuo'
          : 'Intervalado · ${intervalLabel(seconds)}';

  // Opções de modo: contínuo e os intervalos do modo intervalado.
  static final List<_Pace> _paces = [
    (mode: SessionMode.continuous, seconds: 0),
    for (final s in spacedIntervalOptions) (mode: SessionMode.spaced, seconds: s),
  ];

  static String _paceDescription(_Pace p) => p.mode == SessionMode.continuous
      ? 'A próxima pergunta vem 2 s depois do comentário da IA'
      : 'A IA espera ${intervalLabel(p.seconds)} antes da próxima pergunta. '
          'Diga "continuar" para seguir antes';

  static String speechRateLabel(SpeechRate r) => switch (r) {
        SpeechRate.normal => 'Normal',
        SpeechRate.slow => 'Lenta',
        SpeechRate.verySlow => 'Muito lenta',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: appSettings,
        builder: (context, s, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SectionLabel('Idioma e nível'),
            ConfigCard(
              icon: Icons.language,
              title: s.targetLanguage,
              subtitle: 'Idioma de estudo',
              onTap: () => showOptionsSheet(
                context: context,
                title: 'Idioma de estudo',
                options: supportedLanguages,
                selected: s.targetLanguage,
                label: (l) => l,
                onSelect: (l) =>
                    appSettings.update((c) => c.copyWith(targetLanguage: l)),
              ),
            ),
            ConfigCard(
              icon: Icons.school_outlined,
              title: s.cefrLevel.label,
              subtitle: 'Nível',
              onTap: () => showOptionsSheet<CefrLevel>(
                context: context,
                title: 'Nível',
                options: CefrLevel.values,
                selected: s.cefrLevel,
                label: (l) => l.label,
                description: (l) => l.description,
                onSelect: (l) =>
                    appSettings.update((c) => c.copyWith(cefrLevel: l)),
              ),
            ),
            const SizedBox(height: 8),
            const SectionLabel('Sessão'),
            ConfigCard(
              icon: Icons.repeat,
              title: paceLabel(s.mode, s.intervalSeconds),
              subtitle: 'Modo da sessão',
              onTap: () => showOptionsSheet<_Pace>(
                context: context,
                title: 'Modo da sessão',
                options: _paces,
                selected: s.mode == SessionMode.continuous
                    ? (mode: SessionMode.continuous, seconds: 0)
                    : (mode: SessionMode.spaced, seconds: s.intervalSeconds),
                label: (p) => paceLabel(p.mode, p.seconds),
                description: _paceDescription,
                onSelect: (p) => appSettings.update((c) => c.copyWith(
                      mode: p.mode,
                      intervalSeconds:
                          p.mode == SessionMode.spaced ? p.seconds : null,
                    )),
              ),
            ),
            ConfigCard(
              icon: Icons.speed,
              title: speechRateLabel(s.speechRate),
              subtitle: 'Velocidade da fala',
              onTap: () => showOptionsSheet<SpeechRate>(
                context: context,
                title: 'Velocidade da fala',
                options: SpeechRate.values,
                selected: s.speechRate,
                label: speechRateLabel,
                onSelect: (r) =>
                    appSettings.update((c) => c.copyWith(speechRate: r)),
              ),
            ),
            const SizedBox(height: 8),
            const SectionLabel('Desenvolvimento'),
            SwitchListTile(
              title: const Text('Mostrar informações de debug'),
              subtitle: const Text('Confiança da fala, IA em uso e estados'),
              value: s.showDebugInfo,
              onChanged: (v) =>
                  appSettings.update((c) => c.copyWith(showDebugInfo: v)),
            ),
            if (kDebugMode)
              ListenableBuilder(
                listenable: driveModeProvider,
                builder: (context, _) => SwitchListTile(
                  title: const Text('Simular modo carro'),
                  subtitle: const Text('Abre a tela de conversa do carro'),
                  value: driveModeProvider.isDriving,
                  onChanged: driveModeProvider.setDrivingOverride,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
