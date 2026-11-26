import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/router.dart';
import '../../core/drive_mode/drive_mode_provider.dart';
import '../../core/storage/settings_controller.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/cefr_level_labels.dart';
import '../common/option_widgets.dart';
import '../settings/settings_screen.dart';

/// Tela inicial: começar a praticar rápido. As escolhas que quase não mudam
/// ficam nas Configurações; o tema, que muda mais, fica aqui.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _freeTopic = 'Tema livre';

  static const _topics = [
    'Apresentações pessoais',
    'Encontros sociais',
    'Viagem',
    'Compras e serviços',
    'Trabalho e networking',
    'Saúde e emergências',
    'Cultura e entretenimento',
    _freeTopic,
  ];

  @override
  void initState() {
    super.initState();
    driveModeProvider.check();
  }

  Future<void> _startSession() async {
    if (!kDebugMode || !driveModeProvider.isDriving) {
      await driveModeProvider.check();
    }
    if (!mounted) return;

    final s = appSettings.value;
    final route = driveModeProvider.isDriving
        ? AppRouter.drivingConversation
        : AppRouter.conversation;

    Navigator.pushNamed(context, route,
        arguments: (s.toStudentProfile(), s.toSessionConfig()));
  }

  void _openSettings() => Navigator.pushNamed(context, AppRouter.settings);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Language Companion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configurações',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: appSettings,
        builder: (context, s, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Olá! Vamos praticar?',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Escolha o tema e comece a conversar.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    const SectionLabel('Sua prática'),
                    ConfigCard(
                      icon: Icons.language,
                      title: '${s.targetLanguage} · ${s.cefrLevel.label}',
                      subtitle: 'Fala ${SettingsScreen.speechRateLabel(s.speechRate).toLowerCase()}'
                          ' · Modo ${SettingsScreen.paceLabel(s.mode, s.intervalSeconds).toLowerCase()}',
                      onTap: _openSettings,
                    ),
                    const SizedBox(height: 8),
                    const SectionLabel('Tema'),
                    ConfigCard(
                      icon: Icons.topic_outlined,
                      title: s.topic ?? _freeTopic,
                      subtitle: 'Tema da conversa',
                      onTap: () => showOptionsSheet<String>(
                        context: context,
                        title: 'Tema da conversa',
                        options: _topics,
                        selected: s.topic ?? _freeTopic,
                        label: (t) => t,
                        onSelect: (t) => appSettings.update((c) =>
                            c.copyWith(topic: () => t == _freeTopic ? null : t)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _startSession,
                  icon: const Icon(Icons.mic),
                  label: const Text('Iniciar conversação',
                      style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
