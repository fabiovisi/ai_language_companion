import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/models/cefr_level_labels.dart';
import '../../domain/models/language_locale.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/student_profile.dart';
import '../../domain/session/session_state.dart';
import '../../domain/session/session_state_manager.dart';
import '../../core/debug/debug_settings.dart';
import '../../core/permissions/permission_handler.dart';
import '../../core/services/device_stt_service.dart';
import '../../core/services/stt_service.dart';
import '../../core/services/device_tts_service.dart';
import '../../core/services/conversation_service.dart';
import '../../core/services/gemini_conversation_service.dart';
import '../../core/services/groq_conversation_service.dart';
import '../../core/services/mock_conversation_service.dart';
import '../../core/services/speech_segments.dart';
import '../../domain/pedagogy/cefr_rules.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _sessionManager = SessionStateManager();
  final _permissionHandler = AppPermissionHandler();
  final _stt = DeviceSttService();
  final _tts = DeviceTtsService();
  // IA real conforme a chave informada no comando de execução:
  // Groq, senão Gemini, senão mock.
  final ConversationService _conversation = GroqConversationService.isConfigured
      ? GroqConversationService()
      : GeminiConversationService.isConfigured
          ? GeminiConversationService()
          : MockConversationService();

  StudentProfile? _profile;
  SessionConfig? _config;
  String _lastAiText = '';
  String _instructionPt = '';
  bool _cycleRunning = false;

  // Nova pergunta da IA, falada depois do retorno e de uma pausa.
  String? _pendingFollowUp;

  // Pausa entre o retorno da IA e a nova pergunta (modo contínuo, em teste).
  static const _followUpPause = Duration(seconds: 2);

  // Última fala reconhecida e motivo técnico da última falha do STT.
  SttResult? _lastHeard;
  String? _lastSttError;

  // Aguarda escolha do aluno no fluxo de correção
  // true = tentar novamente, false = repetir instrução
  Completer<bool>? _correctionChoice;

  // Código do idioma da aula para STT e TTS (ex.: 'en_US').
  String get _localeId =>
      localeIdFor((_profile ?? _defaultProfile).targetLanguage);

  // Idioma da instrução de correção: português até B2; idioma alvo em C1-C2.
  String get _instructionLocaleId =>
      CefrRules.instructionLanguage((_profile ?? _defaultProfile).cefrLevel) ==
              InstructionLanguage.portuguese
          ? 'pt_BR'
          : _localeId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profile == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is (StudentProfile, SessionConfig)) {
        _profile = args.$1;
        _config = args.$2;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _sessionManager.addListener(_onStateChanged);
    _prepare();
  }

  void _onStateChanged() {
    if (_sessionManager.state == SessionState.ready && !_cycleRunning) {
      _runCycle();
    }
  }

  Future<void> _prepare() async {
    if (kDebugMode) {
      _sessionManager.transition(SessionState.ready);
      return;
    }
    final granted = await _permissionHandler.requestMicrophone();
    if (!mounted) return;
    if (granted) {
      _sessionManager.transition(SessionState.ready);
    } else {
      _sessionManager.transition(SessionState.noPermission);
    }
  }

  Future<void> _runCycle() async {
    _cycleRunning = true;

    while (mounted && !_shouldStop()) {
      // 0. Abertura: saudação e primeira pergunta pedidas à IA
      // (hora do dia, tema e nível), com reserva fixa no idioma da aula.
      if (_lastAiText.isEmpty) {
        _sessionManager.transition(SessionState.preparing);
        final opening = await _conversation.startConversation(
          profile: _profile ?? _defaultProfile,
          config: _config ?? _defaultConfig,
        );
        if (_shouldStop()) break;
        _lastAiText = opening.text;
        _pendingFollowUp = opening.followUp;
      }

      // 1. IA fala
      _sessionManager.transition(SessionState.aiSpeaking);
      await _tts.speak(_lastAiText, rate: _config?.speechRate ?? SpeechRate.normal, localeId: _localeId);
      if (_shouldStop()) break;

      // 1b. Pausa e nova pergunta, quando a IA deu um retorno antes
      final followUp = _pendingFollowUp;
      _pendingFollowUp = null;
      if (followUp != null && followUp.isNotEmpty) {
        await Future.delayed(_followUpPause);
        if (_shouldStop()) break;
        _lastAiText = followUp;
        _sessionManager.transition(SessionState.aiSpeaking); // atualiza o texto na tela
        await _tts.speak(followUp, rate: _config?.speechRate ?? SpeechRate.normal, localeId: _localeId);
        if (_shouldStop()) break;
      }

      // 2. Ouve o aluno
      _sessionManager.transition(SessionState.listening);
      final sttResult = await _stt.recognize(localeId: _localeId);
      _rememberHeard(sttResult);
      if (_shouldStop()) break;

      // 3. Processa
      _sessionManager.transition(SessionState.processing);
      final aiTurn = await _conversation.sendTurn(
        userUtterance: sttResult.transcript,
        profile: _profile ?? _defaultProfile,
        config: _config ?? _defaultConfig,
      );
      if (_shouldStop()) break;

      // 4. Fluxo de correção
      if (aiTurn.hasCorrection) {
        // IA reage no idioma alvo
        _lastAiText = aiTurn.correctionReaction!;
        _instructionPt = aiTurn.instructionPt!;

        _sessionManager.transition(SessionState.aiSpeaking);
        await _tts.speak(_lastAiText, rate: _config?.speechRate ?? SpeechRate.normal, localeId: _localeId);
        if (_shouldStop()) break;

        // Fala a instrução logo após a reação: em um app de voz, o aluno
        // (ao volante) não lê o cartão.
        _lastAiText = _instructionPt;
        _sessionManager.transition(SessionState.aiSpeaking); // atualiza o texto na tela
        await _speakInstruction();
        if (_shouldStop()) break;

        // Loop de correção — repete instrução até aluno escolher tentar
        bool wantsToRetry = false;
        while (!wantsToRetry && !_shouldStop()) {
          _sessionManager.transition(SessionState.correcting);

          _correctionChoice = Completer<bool>();
          wantsToRetry = await _correctionChoice!.future;
          _correctionChoice = null;

          if (!wantsToRetry && !_shouldStop()) {
            // Repete apenas a instrução (português até B2; idioma alvo em C1-C2)
            _lastAiText = _instructionPt;
            _sessionManager.transition(SessionState.aiSpeaking);
            await _speakInstruction();
          }
        }

        if (_shouldStop()) break;

        // Aluno tenta novamente
        _sessionManager.transition(SessionState.listening);
        final retryResult = await _stt.recognize(localeId: _localeId);
        _rememberHeard(retryResult);
        if (_shouldStop()) break;

        _sessionManager.transition(SessionState.processing);
        final retryTurn = await _conversation.sendTurn(
          userUtterance: retryResult.transcript,
          profile: _profile ?? _defaultProfile,
          config: _config ?? _defaultConfig,
          isRetryAfterCorrection: true,
        );
        if (_shouldStop()) break;

        _lastAiText = retryTurn.text;
        _pendingFollowUp = retryTurn.followUp;
        _instructionPt = '';
      } else {
        _lastAiText = aiTurn.text;
        _pendingFollowUp = aiTurn.followUp;
        _instructionPt = '';
      }
    }

    _cycleRunning = false;
  }

  // Fala a instrução de correção. Em A1-B2 ela está em português, com os
  // exemplos no idioma da aula entre aspas: cada trecho usa a voz do seu idioma.
  Future<void> _speakInstruction() async {
    final rate = _config?.speechRate ?? SpeechRate.normal;
    if (_instructionLocaleId == _localeId) {
      await _tts.speak(_instructionPt, rate: rate, localeId: _localeId);
      return;
    }
    for (final segment in splitQuoted(_instructionPt)) {
      if (_shouldStop()) return;
      await _tts.speak(
        segment.text,
        rate: rate,
        localeId: segment.quoted ? _localeId : _instructionLocaleId,
      );
    }
  }

  bool _shouldStop() =>
      !mounted ||
      _sessionManager.state == SessionState.paused ||
      _sessionManager.state == SessionState.ended;

  // Guarda a última fala reconhecida (exibida na tela) e o motivo técnico
  // de falha do reconhecimento (exibido só no debug).
  void _rememberHeard(SttResult result) {
    _lastHeard = result;
    _lastSttError = _stt.lastError;
  }

  // Última fala do aluno, como parte da conversa.
  Widget _buildHeard() {
    final heard = _lastHeard;
    if (heard == null) return const SizedBox.shrink();
    final empty = heard.transcript.isEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Você',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            empty
                ? 'Não consegui ouvir. Tente de novo.'
                : '"${heard.transcript}"',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontStyle: empty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Debug: confiança (ou motivo da falha) do reconhecimento e IA em uso.
  String get _debugLine {
    final service = _conversation;
    var ai = 'IA: mock';
    if (service is LlmDebugInfo) {
      final info = service as LlmDebugInfo;
      final model = info.lastModel?.split('/').last;
      final duration = info.lastDuration;
      final details = [
        ?model,
        if (duration != null)
          '${(duration.inMilliseconds / 1000).toStringAsFixed(1).replaceAll('.', ',')} s',
      ].join(', ');
      final error = info.lastError;
      ai = 'IA: ${info.providerName}'
          '${details.isNotEmpty ? ' ($details)' : ''}'
          '${error != null ? ' erro: $error' : ''}';
    }
    final heard = _lastHeard;
    if (heard == null) return ai;
    final stt = heard.transcript.isEmpty
        ? 'Fala: não reconhecida (${_lastSttError ?? 'sem fala detectada'})'
        : 'Fala: confiança ${(heard.confidence * 100).round()}%';
    return '$stt\n$ai';
  }

  void _resumeSession() {
    _sessionManager.transition(SessionState.ready);
  }

  StudentProfile get _defaultProfile => StudentProfile(
        targetLanguage: 'Inglês',
        cefrLevel: CefrLevel.a2,
        lastSessionConfig: SessionConfig(
          mode: SessionMode.continuous,
          speechRate: SpeechRate.normal,
        ),
      );

  SessionConfig get _defaultConfig => SessionConfig(
        mode: SessionMode.continuous,
        speechRate: SpeechRate.normal,
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_sessionManager, showDebugInfo]),
      builder: (context, _) {
        final debug = showDebugInfo.value;
        return Scaffold(
          appBar: AppBar(
            title: Text(_profile?.targetLanguage ?? 'Sessão de conversação'),
            bottom: _profile != null
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(44),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _AppBarBadge(
                            icon: Icons.school_outlined,
                            label: _profile!.cefrLevel.label,
                          ),
                          const SizedBox(width: 8),
                          _AppBarBadge(
                            icon: Icons.topic_outlined,
                            label: _config?.topic ?? 'Tema livre',
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(child: _buildStateView(_sessionManager.state)),
                _buildHeard(),
                if (debug)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _debugLine,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                  ),
                _buildControls(),
                if (debug) _buildDebugBar(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStateView(SessionState state) {
    return switch (state) {
      SessionState.preparing => const _StatusView(
          icon: Icons.hourglass_top,
          message: 'Preparando sessão...',
        ),
      SessionState.ready => const _StatusView(
          icon: Icons.check_circle_outline,
          color: Color(0xFF176B65),
          message: 'Sessão pronta!\nA IA vai iniciar em instantes.',
        ),
      SessionState.noPermission => _NoPermissionView(
          isPermanent: false,
          onRetry: _prepare,
        ),
      SessionState.aiSpeaking => _StatusView(
          icon: Icons.volume_up_outlined,
          color: const Color(0xFF176B65),
          message: 'IA falando...\n\n"$_lastAiText"',
        ),
      SessionState.listening => const _StatusView(
          icon: Icons.mic,
          color: Colors.red,
          message: 'Ouvindo...',
        ),
      SessionState.processing => const _StatusView(
          icon: Icons.sync,
          message: 'Processando...',
        ),
      SessionState.correcting => _CorrectionView(
          instruction: _instructionPt,
          onRetry: () => _correctionChoice?.complete(true),
          onRepeat: () => _correctionChoice?.complete(false),
        ),
      SessionState.interval => const _StatusView(
          icon: Icons.pause_circle_outline,
          message: 'Intervalo — próximo diálogo em breve.',
        ),
      SessionState.paused => _PausedView(onResume: _resumeSession),
      SessionState.ended => const _StatusView(
          icon: Icons.flag_outlined,
          message: 'Sessão encerrada.',
        ),
      SessionState.noConnectivity => const _StatusView(
          icon: Icons.wifi_off,
          message: 'Sem conexão. Verifique sua rede.',
        ),
      SessionState.reconnecting => const _StatusView(
          icon: Icons.wifi_find,
          message: 'Reconectando...',
        ),
      _ => const _StatusView(
          icon: Icons.error_outline,
          message: 'Algo deu errado. Tente novamente.',
        ),
    };
  }

  Widget _buildControls() {
    final state = _sessionManager.state;
    final isActive = state == SessionState.ready ||
        state == SessionState.aiSpeaking ||
        state == SessionState.listening ||
        state == SessionState.processing ||
        state == SessionState.correcting;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: state == SessionState.paused ? Icons.play_arrow : Icons.pause,
          label: state == SessionState.paused ? 'Retomar' : 'Pausar',
          onTap: isActive
              ? () => _sessionManager.transition(SessionState.paused)
              : state == SessionState.paused
                  ? _resumeSession
                  : null,
        ),
        _ControlButton(
          icon: Icons.stop,
          label: 'Encerrar',
          color: Colors.red,
          onTap: isActive || state == SessionState.paused
              ? () => _sessionManager.transition(SessionState.ended)
              : null,
        ),
      ],
    );
  }

  Widget _buildDebugBar() {
    const states = [
      SessionState.preparing,
      SessionState.ready,
      SessionState.aiSpeaking,
      SessionState.listening,
      SessionState.processing,
      SessionState.correcting,
      SessionState.interval,
      SessionState.paused,
      SessionState.ended,
      SessionState.noPermission,
      SessionState.noConnectivity,
      SessionState.reconnecting,
    ];

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 4),
            child: Text('DEBUG — forçar estado',
                style: TextStyle(color: Colors.yellow, fontSize: 11)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: states.map((s) {
                final isActive = _sessionManager.state == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => _sessionManager.transition(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.yellow : Colors.white24,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive ? Colors.black : Colors.white,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _correctionChoice?.complete(false);
    _stt.cancel(); // desliga o microfone ao sair da tela
    _tts.stop(); // interrompe a voz ao sair da tela
    _sessionManager.removeListener(_onStateChanged);
    _sessionManager.dispose();
    super.dispose();
  }
}

// — Views —

class _StatusView extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const _StatusView({required this.icon, required this.message, this.color});

  @override
  Widget build(BuildContext context) {
    // Rolável: textos longos da IA não estouram a altura da tela.
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: color ?? Colors.grey),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPermissionView extends StatelessWidget {
  final bool isPermanent;
  final VoidCallback onRetry;

  const _NoPermissionView({required this.isPermanent, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_off, size: 72, color: Colors.red),
          const SizedBox(height: 24),
          const Text(
            'O microfone é necessário para a sessão de conversação.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(isPermanent ? Icons.settings : Icons.mic),
            label: Text(
                isPermanent ? 'Abrir configurações' : 'Permitir microfone'),
            onPressed: isPermanent ? openAppSettings : onRetry,
          ),
        ],
      ),
    );
  }
}

class _PausedView extends StatelessWidget {
  final VoidCallback onResume;

  const _PausedView({required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle, size: 72, color: Color(0xFF176B65)),
          const SizedBox(height: 24),
          const Text('Sessão pausada', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Retomar'),
            onPressed: onResume,
          ),
        ],
      ),
    );
  }
}

class _CorrectionView extends StatelessWidget {
  final String instruction;
  final VoidCallback onRetry;
  final VoidCallback onRepeat;

  const _CorrectionView({
    required this.instruction,
    required this.onRetry,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    // Rolável: instruções longas da IA não escondem os botões.
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_note, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Atenção',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange),
              ),
              const SizedBox(height: 12),
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              const Text(
                'O que você quer fazer?',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12, // espaço entre os botões
                runSpacing: 8, // espaço entre linhas, se quebrar
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.replay),
                    label: const Text('Repetir instrução'),
                    onPressed: onRepeat,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.mic),
                    label: const Text('Tentar novamente'),
                    onPressed: onRetry,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          icon: Icon(icon),
          iconSize: 32,
          style: IconButton.styleFrom(
            backgroundColor: onTap == null
                ? Colors.grey.shade300
                : color ?? const Color(0xFF176B65),
          ),
          onPressed: onTap,
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _AppBarBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AppBarBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
