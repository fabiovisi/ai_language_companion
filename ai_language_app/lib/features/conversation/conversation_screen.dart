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
import '../../core/services/whisper_stt_service.dart';
import '../../domain/models/native_language.dart';
import '../../core/services/stt_service.dart';
import '../../core/services/device_tts_service.dart';
import '../../core/services/conversation_service.dart';
import '../../core/services/gemini_conversation_service.dart';
import '../../core/services/groq_conversation_service.dart';
import '../../core/services/mock_conversation_service.dart';
import '../../core/services/speech_segments.dart';
import '../../core/services/voice_commands.dart';
import '../../domain/pedagogy/cefr_rules.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _sessionManager = SessionStateManager();
  final _permissionHandler = AppPermissionHandler();
  // Whisper (identifica o idioma falado) quando há chave do Groq;
  // senão, o reconhecimento do navegador ou do aparelho.
  final SttService _stt = WhisperSttService.isConfigured
      ? WhisperSttService()
      : DeviceSttService();
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
  bool _followUpSlower = false; // o aluno pediu para falar mais devagar
  bool _lastAiIsHelp = false; // a próxima fala é resposta a um pedido de ajuda

  // Última fala da IA no idioma da aula (a frase sobre a qual o aluno pede ajuda).
  String? _lastAiTargetText;

  // Cartão de ajuda exibido durante e depois da explicação.
  String? _helpSentence;
  String? _helpExplanation;

  // Pausa entre o retorno da IA e a nova pergunta (modo contínuo, em teste).
  static const _followUpPause = Duration(seconds: 2);

  // Última fala reconhecida e motivo técnico da última falha do STT.
  SttResult? _lastHeard;
  String? _lastSttError;
  String? _lastSttDebug; // medidas da escuta (ex.: volume), só no debug

  // Correção por voz: etapa atual (permite retomar depois de uma pausa).
  bool _inCorrection = false;
  _CorrectionStage _correctionStage = _CorrectionStage.reaction;
  String _correctionReaction = '';
  int _correctionSilences = 0;

  // Pausa por voz e parada imediata.
  SessionState? _previousState;
  bool _pauseListening = false;

  // Código do idioma da aula para STT e TTS (ex.: 'en_US').
  String get _localeId =>
      localeIdFor((_profile ?? _defaultProfile).targetLanguage);

  // Idioma da instrução de correção: português até B2; idioma alvo em C1-C2.
  String get _instructionLocaleId =>
      CefrRules.instructionLanguage((_profile ?? _defaultProfile).cefrLevel) ==
              InstructionLanguage.portuguese
          ? nativeLanguage.localeId
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
    final state = _sessionManager.state;
    final previous = _previousState;
    _previousState = state;

    // Parada imediata: ao pausar ou encerrar (por voz ou pelo botão), a voz e
    // o microfone param na hora.
    if ((state == SessionState.paused || state == SessionState.ended) &&
        previous != state) {
      _tts.stop();
      _stt.cancel();
    }
    // Saiu da pausa (ex.: botão "Retomar"): para a escuta do "continuar" e o
    // aviso da pausa.
    if (previous == SessionState.paused && state != SessionState.paused) {
      _tts.stop();
      _stt.cancel();
    }

    if (state == SessionState.ready && !_cycleRunning) {
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
      // Correção em andamento (também ao retomar depois de uma pausa).
      if (_inCorrection) {
        await _runCorrection();
        continue;
      }

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

      // 1. IA fala. A resposta a um pedido de ajuda usa a voz do idioma
      // nativo, com as palavras entre chaves na voz do idioma da aula.
      // Ao retomar depois de uma pausa, a última fala é repetida.
      _sessionManager.transition(SessionState.aiSpeaking);
      if (_lastAiIsHelp) {
        await _speakMixed(_lastAiText);
      } else {
        _lastAiTargetText = _lastAiText;
        await _tts.speak(_lastAiText, rate: _rate, localeId: _localeId);
      }
      if (_shouldStop()) break;
      _lastAiIsHelp = false;

      // 1b. Pausa e nova pergunta, quando a IA deu um retorno antes
      // (mais devagar, se o aluno pediu). A pergunta só é descartada depois
      // de falada, para não se perder se a aula for pausada no meio.
      final followUp = _pendingFollowUp;
      final slower = _followUpSlower;
      if (followUp != null && followUp.isNotEmpty) {
        await Future.delayed(_followUpPause);
        if (_shouldStop()) break;
        _lastAiText = followUp;
        _lastAiTargetText = followUp;
        _pendingFollowUp = null;
        _followUpSlower = false;
        _sessionManager.transition(SessionState.aiSpeaking); // atualiza o texto na tela
        await _tts.speak(followUp,
            rate: slower ? _slowerRate : _rate, localeId: _localeId);
        if (_shouldStop()) break;
      } else {
        _pendingFollowUp = null;
        _followUpSlower = false;
      }

      // 2. Ouve o aluno
      _sessionManager.transition(SessionState.listening);
      final sttResult = await _stt.recognize(localeId: _localeId);
      if (_shouldStop()) break;
      _rememberHeard(sttResult);
      if (await _handleControlCommand(sttResult)) break;

      // 3. Processa. Fala no idioma nativo: pode ser pedido de ajuda ou uma
      // resposta com sotaque; a IA decide com as duas versões.
      _sessionManager.transition(SessionState.processing);
      final targetVersion = await _targetVersionOf(sttResult);
      final aiTurn = await _conversation.sendTurn(
        userUtterance: sttResult.transcript,
        profile: _profile ?? _defaultProfile,
        config: _config ?? _defaultConfig,
        isHelpRequest: _isHelpRequest(sttResult),
        targetVersion: targetVersion?.transcript,
      );
      if (_shouldStop()) break;
      _applyTargetVersion(aiTurn, targetVersion);

      // 4. Erro: começa a correção (próxima volta do ciclo).
      if (aiTurn.hasCorrection) {
        _startCorrection(aiTurn);
      } else {
        _setNextTurn(aiTurn);
      }
    }

    _cycleRunning = false;
    if (mounted && _sessionManager.state == SessionState.paused) {
      _listenWhilePaused();
    }
  }

  // — Correção por voz —

  void _startCorrection(AiTurn turn) {
    _clearHelpCard();
    _correctionReaction = turn.correctionReaction!;
    _instructionPt = turn.instructionPt!;
    _inCorrection = true;
    _correctionStage = _CorrectionStage.reaction;
    _correctionSilences = 0;
  }

  // Reação → instrução → pergunta → escuta. "Repetir" repete a instrução;
  // qualquer outra fala é a nova tentativa. Pode ser retomada depois de uma
  // pausa, a partir da etapa em que parou.
  Future<void> _runCorrection() async {
    if (_correctionStage == _CorrectionStage.reaction) {
      _lastAiText = _correctionReaction;
      _lastAiTargetText = _correctionReaction;
      _sessionManager.transition(SessionState.aiSpeaking);
      await _tts.speak(_correctionReaction, rate: _rate, localeId: _localeId);
      if (_shouldStop()) return;
      _correctionStage = _CorrectionStage.instruction;
    }

    if (_correctionStage == _CorrectionStage.instruction) {
      _sessionManager.transition(SessionState.correcting); // cartão na tela
      await _speakInstruction();
      if (_shouldStop()) return;
      _correctionStage = _CorrectionStage.prompt;
    }

    if (_correctionStage == _CorrectionStage.prompt) {
      _sessionManager.transition(SessionState.correcting);
      await _speakCorrectionPrompt();
      if (_shouldStop()) return;
      _correctionStage = _CorrectionStage.listening;
    }

    _sessionManager.transition(SessionState.listening);
    final result = await _stt.recognize(localeId: _localeId);
    if (_shouldStop()) return;
    _rememberHeard(result);
    if (await _handleControlCommand(result)) return;

    if (detectCommand(result.transcript,
            allowed: const {VoiceCommand.repeatInstruction}) !=
        null) {
      _correctionStage = _CorrectionStage.instruction;
      return;
    }

    // Primeiro silêncio: repete a pergunta. No segundo, segue a conversa.
    if (result.transcript.isEmpty && _correctionSilences == 0) {
      _correctionSilences++;
      _correctionStage = _CorrectionStage.prompt;
      return;
    }

    // Nova tentativa (ou pedido de ajuda, ou o segundo silêncio).
    _sessionManager.transition(SessionState.processing);
    final target = await _targetVersionOf(result);
    final turn = await _conversation.sendTurn(
      userUtterance: result.transcript,
      profile: _profile ?? _defaultProfile,
      config: _config ?? _defaultConfig,
      isRetryAfterCorrection: true,
      // Pedido de ajuda no lugar da nova tentativa: a IA explica e a
      // conversa segue a partir da pergunta repetida.
      isHelpRequest: _isHelpRequest(result),
      targetVersion: target?.transcript,
    );
    if (_shouldStop()) {
      _correctionStage = _CorrectionStage.instruction; // ao retomar
      return;
    }
    _applyTargetVersion(turn, target);
    _inCorrection = false;
    _setNextTurn(turn);
  }

  // Pergunta depois da instrução, no idioma da instrução.
  Future<void> _speakCorrectionPrompt() {
    final native = _instructionLocaleId == nativeLanguage.localeId;
    final language = (_profile ?? _defaultProfile).targetLanguage;
    return _tts.speak(
      correctionPrompt(native ? null : language),
      rate: _rate,
      localeId: _instructionLocaleId,
    );
  }

  // — Comandos de controle e pausa por voz —

  // "Pausa" e "encerrar": tratados pelo app, na hora. Devolve true se a fala
  // era um desses comandos.
  Future<bool> _handleControlCommand(SttResult result) async {
    switch (detectCommand(result.transcript,
        allowed: const {VoiceCommand.pause, VoiceCommand.end})) {
      case VoiceCommand.pause:
        _sessionManager.transition(SessionState.paused);
        return true;
      case VoiceCommand.end:
        await _endByVoice();
        return true;
      default:
        return false;
    }
  }

  // Despede-se no idioma da aula e encerra.
  Future<void> _endByVoice() async {
    final language = (_profile ?? _defaultProfile).targetLanguage;
    _lastAiText = goodbyePhrase(language);
    _clearHelpCard();
    _inCorrection = false;
    _sessionManager.transition(SessionState.aiSpeaking);
    await _tts.speak(_lastAiText, rate: _rate, localeId: _localeId);
    if (mounted) _sessionManager.transition(SessionState.ended);
  }

  // Durante a pausa, o microfone fica ligado esperando "continuar" ou
  // "encerrar". Só envia áudio ao Whisper quando detecta fala; outras falas
  // são ignoradas.
  Future<void> _listenWhilePaused() async {
    if (_pauseListening) return;
    _pauseListening = true;
    try {
      await _tts.speak(pausedPrompt,
          rate: _rate, localeId: nativeLanguage.localeId);
      while (mounted && _sessionManager.state == SessionState.paused) {
        final result = await _stt.recognize(localeId: _localeId);
        if (!mounted || _sessionManager.state != SessionState.paused) return;
        switch (detectCommand(result.transcript,
            allowed: const {VoiceCommand.resume, VoiceCommand.end})) {
          case VoiceCommand.resume:
            _resumeSession();
            return;
          case VoiceCommand.end:
            await _endByVoice();
            return;
          default:
            break; // ignora outras falas
        }
      }
    } finally {
      _pauseListening = false;
    }
  }

  // Prepara a próxima fala da IA (retorno ou ajuda) e a pergunta seguinte.
  void _setNextTurn(AiTurn turn) {
    _lastAiText = turn.text;
    _lastAiIsHelp = turn.isHelp;
    _pendingFollowUp = turn.followUp;
    _followUpSlower = turn.slower;
    _instructionPt = '';

    // Cartão de ajuda: a frase sobre a qual o aluno pediu ajuda (a última
    // fala da IA no idioma da aula) e a explicação. Fica visível até a
    // próxima resposta do aluno que não seja outro pedido de ajuda.
    if (turn.isHelp) {
      _helpSentence = _lastAiTargetText;
      _helpExplanation = turn.text;
    } else {
      _clearHelpCard();
    }
  }

  void _clearHelpCard() {
    _helpSentence = null;
    _helpExplanation = null;
  }

  // Fala no idioma nativo = possível pedido de ajuda (só o Whisper identifica
  // o idioma). Pode ser engano por causa do sotaque; a IA confirma.
  bool _isHelpRequest(SttResult result) =>
      result.transcript.isNotEmpty &&
      result.language == nativeLanguage.whisperName;

  // Fala identificada no idioma nativo: transcreve de novo no idioma da aula,
  // para a IA decidir se era pedido de ajuda ou resposta com sotaque.
  Future<SttResult?> _targetVersionOf(SttResult result) async =>
      _isHelpRequest(result) ? _stt.retranscribe(localeId: _localeId) : null;

  // Não era ajuda (a IA usou a versão no idioma da aula): o balão "Você"
  // passa a mostrar essa versão.
  void _applyTargetVersion(AiTurn turn, SttResult? targetVersion) {
    if (targetVersion == null || targetVersion.transcript.isEmpty) return;
    final decision = turn.isHelp ? 'pedido de ajuda' : 'resposta no idioma da aula';
    _lastSttDebug = '${_lastSttDebug ?? ''} · 2ª transcrição: $decision';
    if (!turn.isHelp) _lastHeard = targetVersion;
  }

  SpeechRate get _rate => _config?.speechRate ?? SpeechRate.normal;

  // Uma velocidade abaixo da escolhida (para "mais devagar").
  SpeechRate get _slowerRate => switch (_rate) {
        SpeechRate.normal => SpeechRate.slow,
        _ => SpeechRate.verySlow,
      };

  // Fala a instrução de correção.
  Future<void> _speakInstruction() => _speakMixed(_instructionPt);

  // Fala um texto no idioma das instruções (nativo em A1-B2), com os
  // exemplos no idioma da aula entre aspas: cada trecho usa a voz do seu idioma.
  Future<void> _speakMixed(String text) async {
    final rate = _rate;
    if (_instructionLocaleId == _localeId) {
      await _tts.speak(text, rate: rate, localeId: _localeId);
      return;
    }
    for (final segment in splitTargetLanguage(text)) {
      if (_shouldStop()) return;
      await _tts.speak(
        segment.text,
        rate: rate,
        localeId: segment.target ? _localeId : _instructionLocaleId,
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
    _lastSttDebug = _stt.debugInfo;
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
        ? 'Fala (${_stt.engineName}): não reconhecida '
            '(${_lastSttError ?? 'sem fala detectada'})'
        : 'Fala (${_stt.engineName}): confiança '
            '${(heard.confidence * 100).round()}%'
            '${heard.language != null ? ' · idioma: ${heard.language}' : ''}';
    final levels = _lastSttDebug;
    return levels == null ? '$stt\n$ai' : '$stt\nVolume: $levels\n$ai';
  }

  // Ao retomar no meio da correção, a instrução é repetida para dar contexto.
  void _resumeSession() {
    if (_inCorrection && _correctionStage == _CorrectionStage.listening) {
      _correctionStage = _CorrectionStage.instruction;
    }
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
    // Cartão de correção: durante a instrução, a pergunta e a escuta da nova
    // tentativa.
    if (_inCorrection &&
        _correctionStage != _CorrectionStage.reaction &&
        (state == SessionState.correcting ||
            state == SessionState.listening)) {
      return _CorrectionView(
        instruction: displayText(_instructionPt),
        listening: state == SessionState.listening,
      );
    }

    // Cartão de ajuda: durante a explicação, a pergunta mais simples e a
    // escuta da resposta.
    final explanation = _helpExplanation;
    if (explanation != null &&
        (state == SessionState.aiSpeaking ||
            state == SessionState.listening)) {
      final listening = state == SessionState.listening;
      final explaining = _lastAiText == explanation;
      return _HelpView(
        sentence: _helpSentence,
        explanation: explanation,
        statusIcon: listening ? Icons.mic : Icons.volume_up_outlined,
        statusColor: listening ? Colors.red : const Color(0xFF176B65),
        status: listening
            ? 'Ouvindo...'
            : explaining
                ? 'IA explicando...'
                : 'IA falando: "${displayText(_lastAiText)}"',
      );
    }

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
          message: 'IA falando...\n\n"${displayText(_lastAiText)}"',
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
          instruction: displayText(_instructionPt),
          listening: false,
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
          const SizedBox(height: 8),
          const Text('Diga "continuar" para retomar, ou "encerrar".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey)),
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

/// Cartão de ajuda: a frase sobre a qual o aluno pediu ajuda (com as palavras
/// explicadas em destaque), a explicação e o que o app está fazendo agora.
class _HelpView extends StatelessWidget {
  final String? sentence;
  final String explanation; // com as chaves do marcador de idioma
  final IconData statusIcon;
  final Color statusColor;
  final String status;

  const _HelpView({
    required this.sentence,
    required this.explanation,
    required this.statusIcon,
    required this.statusColor,
    required this.status,
  });

  static const _blue = Color(0xFF1E5AA8);

  @override
  Widget build(BuildContext context) {
    final sentence = this.sentence;
    const label = TextStyle(
        fontSize: 13, fontWeight: FontWeight.bold, color: _blue);

    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _blue.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sentence != null && sentence.isNotEmpty) ...[
                const Text('A FRASE', style: label),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 18, fontStyle: FontStyle.italic),
                    children: [
                      for (final part
                          in highlightWords(sentence, targetWords(explanation)))
                        TextSpan(
                          text: part.text,
                          style: part.highlight
                              ? const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.normal,
                                  color: _blue)
                              : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text('EXPLICAÇÃO', style: label),
              const SizedBox(height: 6),
              Text(displayText(explanation),
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(status,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.grey)),
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

/// Etapas da correção por voz.
enum _CorrectionStage { reaction, instruction, prompt, listening }

/// Cartão de correção: a instrução e o que o app está fazendo agora.
/// Sem botões: o aluno responde por voz.
class _CorrectionView extends StatelessWidget {
  final String instruction;
  final bool listening;

  const _CorrectionView({required this.instruction, required this.listening});

  @override
  Widget build(BuildContext context) {
    // Rolável: instruções longas da IA não estouram a altura da tela.
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(listening ? Icons.mic : Icons.volume_up_outlined,
                      color:
                          listening ? Colors.red : const Color(0xFF176B65),
                      size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      listening
                          ? 'Ouvindo... diga a frase de novo, ou "repetir"'
                          : 'IA explicando...',
                      style:
                          const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
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
