import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/router.dart';
import '../../core/drive_mode/drive_mode_provider.dart';
import '../../domain/models/student_profile.dart';
import '../../domain/models/session_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _driveModeProvider = DriveModeProvider();

  String _targetLanguage = 'Inglês';
  CefrLevel _cefrLevel = CefrLevel.a2;
  String? _topic;
  SessionMode _mode = SessionMode.continuous;
  SpeechRate _speechRate = SpeechRate.normal;

  static const _languages = ['Inglês', 'Espanhol', 'Francês', 'Alemão', 'Italiano'];

  static const _topics = [
    'Apresentações pessoais',
    'Encontros sociais',
    'Viagem',
    'Compras e serviços',
    'Trabalho e networking',
    'Saúde e emergências',
    'Cultura e entretenimento',
    'Tema livre',
  ];

  @override
  void initState() {
    super.initState();
    _driveModeProvider.check();
  }

  @override
  void dispose() {
    _driveModeProvider.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (!kDebugMode || !_driveModeProvider.isDriving) {
      await _driveModeProvider.check();
    }
    if (!mounted) return;

    final profile = StudentProfile(
      targetLanguage: _targetLanguage,
      cefrLevel: _cefrLevel,
      lastSessionConfig: SessionConfig(
        topic: _topic,
        mode: _mode,
        speechRate: _speechRate,
      ),
    );
    final config = SessionConfig(
      topic: _topic,
      mode: _mode,
      speechRate: _speechRate,
    );

    final route = _driveModeProvider.isDriving
        ? AppRouter.drivingConversation
        : AppRouter.conversation;

    Navigator.pushNamed(context, route, arguments: (profile, config));
  }

  void _showOptions<T>({
    required String title,
    required List<T> options,
    required T selected,
    required String Function(T) label,
    required void Function(T) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ...options.map((option) => ListTile(
                    title: Text(label(option)),
                    trailing: option == selected ? const Icon(Icons.check, color: Color(0xFF176B65)) : null,
                    onTap: () {
                      onSelect(option);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String get _cefrLabel => _cefrLevel.name.toUpperCase();

  String get _modeLabel => _mode == SessionMode.continuous ? 'Contínuo' : 'Intervalado';

  String get _speechRateLabel => switch (_speechRate) {
        SpeechRate.normal => 'Normal',
        SpeechRate.slow => 'Lenta',
        SpeechRate.verySlow => 'Muito lenta',
      };

  String get _topicLabel => _topic ?? 'Tema livre';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Language Companion'),
      ),
      body: Padding(
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
              'Configure sua sessão e comece a conversar.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _SectionLabel('Idioma e nível'),
                  _ConfigCard(
                    icon: Icons.language,
                    title: _targetLanguage,
                    subtitle: 'Idioma de estudo',
                    onTap: () => _showOptions(
                      title: 'Idioma de estudo',
                      options: _languages,
                      selected: _targetLanguage,
                      label: (l) => l,
                      onSelect: (l) => setState(() => _targetLanguage = l),
                    ),
                  ),
                  _ConfigCard(
                    icon: Icons.school_outlined,
                    title: _cefrLabel,
                    subtitle: 'Nível de proficiência',
                    onTap: () => _showOptions(
                      title: 'Nível CEFR',
                      options: CefrLevel.values,
                      selected: _cefrLevel,
                      label: (l) => l.name.toUpperCase(),
                      onSelect: (l) => setState(() => _cefrLevel = l),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionLabel('Sessão'),
                  _ConfigCard(
                    icon: Icons.topic_outlined,
                    title: _topicLabel,
                    subtitle: 'Tema da conversa',
                    onTap: () => _showOptions(
                      title: 'Tema da conversa',
                      options: _topics,
                      selected: _topicLabel,
                      label: (t) => t,
                      onSelect: (t) => setState(() => _topic = t == 'Tema livre' ? null : t),
                    ),
                  ),
                  _ConfigCard(
                    icon: Icons.repeat,
                    title: _modeLabel,
                    subtitle: 'Modo da sessão',
                    onTap: () => _showOptions(
                      title: 'Modo da sessão',
                      options: SessionMode.values,
                      selected: _mode,
                      label: (m) => m == SessionMode.continuous ? 'Contínuo' : 'Intervalado',
                      onSelect: (m) => setState(() => _mode = m),
                    ),
                  ),
                  _ConfigCard(
                    icon: Icons.speed,
                    title: _speechRateLabel,
                    subtitle: 'Velocidade da fala',
                    onTap: () => _showOptions(
                      title: 'Velocidade da fala',
                      options: SpeechRate.values,
                      selected: _speechRate,
                      label: (r) => switch (r) {
                        SpeechRate.normal => 'Normal',
                        SpeechRate.slow => 'Lenta',
                        SpeechRate.verySlow => 'Muito lenta',
                      },
                      onSelect: (r) => setState(() => _speechRate = r),
                    ),
                  ),
                ],
              ),
            ),
            if (kDebugMode)
              ListenableBuilder(
                listenable: _driveModeProvider,
                builder: (context, _) => SwitchListTile(
                  title: const Text(
                    'DEBUG — simular modo carro',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  value: _driveModeProvider.isDriving,
                  onChanged: (v) => _driveModeProvider.setDrivingOverride(v),
                  dense: true,
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startSession,
                icon: const Icon(Icons.mic),
                label: const Text('Iniciar conversação', style: TextStyle(fontSize: 17)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ConfigCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF176B65), size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
