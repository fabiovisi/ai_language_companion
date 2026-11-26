import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/drive_mode/drive_mode_provider.dart';
import '../../core/storage/memory_store.dart';
import '../../core/storage/settings_controller.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/cefr_level_labels.dart';
import '../../domain/models/language_locale.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/student_profile.dart';
import '../common/option_widgets.dart';

/// O que o app lembra sobre o aluno no idioma, e o botão para apagar.
class _MemorySection extends StatefulWidget {
  final String language;
  const _MemorySection({super.key, required this.language});

  @override
  State<_MemorySection> createState() => _MemorySectionState();
}

class _MemorySectionState extends State<_MemorySection> {
  String? _memory;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    studentMemory.load(widget.language).then((memory) {
      if (mounted) {
        setState(() {
          _memory = memory;
          _loaded = true;
        });
      }
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar memória?'),
        content: Text(
            'O app vai esquecer o que sabe sobre você nas aulas de '
            '${widget.language}. Isso não pode ser desfeito.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await studentMemory.clear(widget.language);
    if (mounted) setState(() => _memory = null); // atualiza na hora
  }

  @override
  Widget build(BuildContext context) {
    final memory = _memory;
    final empty = memory == null || memory.trim().isEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('O que o app lembra sobre você (${widget.language})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              !_loaded
                  ? 'Carregando...'
                  : empty
                      ? 'Nada guardado ainda. A memória é criada durante as '
                          'aulas.'
                      : memory,
              style: TextStyle(
                  color: empty ? Colors.grey : null,
                  fontStyle: empty ? FontStyle.italic : null),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fica no aparelho e é enviada à IA a cada aula, para '
              'personalizar a conversa.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (!empty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Apagar memória'),
                  onPressed: _confirmClear,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
            const SectionLabel('Memória'),
            _MemorySection(
                key: ValueKey(s.targetLanguage), language: s.targetLanguage),
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
