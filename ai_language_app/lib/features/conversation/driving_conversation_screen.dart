import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/session/session_state.dart';
import '../../domain/session/session_state_manager.dart';

class DrivingConversationScreen extends StatefulWidget {
  const DrivingConversationScreen({super.key});

  @override
  State<DrivingConversationScreen> createState() =>
      _DrivingConversationScreenState();
}

class _DrivingConversationScreenState extends State<DrivingConversationScreen>
    with TickerProviderStateMixin {
  final _sessionManager = SessionStateManager();

  // Pulso — usado em ready, aiSpeaking, listening, processing
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Ripple — usado em correcting
  late final AnimationController _rippleController;
  late final Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _sessionManager.addListener(_onStateChanged);
    _sessionManager.transition(SessionState.ready);
  }

  void _onStateChanged() {
    final state = _sessionManager.state;

    final shouldPulse = state == SessionState.ready ||
        state == SessionState.aiSpeaking ||
        state == SessionState.listening ||
        state == SessionState.processing;

    final shouldRipple = state == SessionState.correcting;

    if (shouldPulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!shouldPulse) {
      _pulseController.stop();
    }

    if (shouldRipple && !_rippleController.isAnimating) {
      _rippleController.repeat();
    } else if (!shouldRipple) {
      _rippleController.stop();
    }
  }

  Color get _stateColor => switch (_sessionManager.state) {
        SessionState.aiSpeaking => const Color(0xFF176B65),
        SessionState.listening => Colors.red,
        SessionState.ready => const Color(0xFF176B65),
        SessionState.processing => Colors.orange,
        SessionState.correcting => Colors.amber,
        _ => Colors.grey,
      };

  String get _stateLabel => switch (_sessionManager.state) {
        SessionState.preparing => 'Preparando...',
        SessionState.ready => 'Pronto',
        SessionState.aiSpeaking => 'IA falando',
        SessionState.listening => 'Ouvindo',
        SessionState.processing => 'Processando',
        SessionState.correcting => 'Correção',
        SessionState.interval => 'Intervalo',
        SessionState.paused => 'Pausado',
        SessionState.ended => 'Encerrado',
        SessionState.noConnectivity => 'Sem conexão',
        SessionState.reconnecting => 'Reconectando',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sessionManager,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(child: _buildVisual(_sessionManager.state)),
                ),
                Text(
                  _stateLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 32),
                if (kDebugMode) _buildDebugBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisual(SessionState state) {
    if (state == SessionState.correcting) {
      return AnimatedBuilder(
        animation: _rippleAnimation,
        builder: (context, _) => CustomPaint(
          size: const Size(260, 260),
          painter: _RipplePainter(
            progress: _rippleAnimation.value,
            color: _stateColor,
          ),
        ),
      );
    }

    final staticIcon = _staticIcon(state);
    if (staticIcon != null) {
      return Icon(staticIcon, size: 96, color: _stateColor);
    }

    // Pulso — ready, aiSpeaking, listening, processing
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) => CustomPaint(
        size: const Size(260, 260),
        painter: _PulseCirclePainter(
          scale: _pulseAnimation.value,
          color: _stateColor,
        ),
      ),
    );
  }

  IconData? _staticIcon(SessionState state) => switch (state) {
        SessionState.paused => Icons.pause_circle,
        SessionState.ended => Icons.check_circle,
        SessionState.noConnectivity => Icons.wifi_off,
        SessionState.reconnecting => Icons.wifi_find,
        SessionState.interval => Icons.hourglass_top,
        SessionState.noPermission => Icons.mic_off,
        _ => null,
      };

  Widget _buildDebugBar() {
    const states = [
      SessionState.ready,
      SessionState.aiSpeaking,
      SessionState.listening,
      SessionState.processing,
      SessionState.correcting,
      SessionState.interval,
      SessionState.paused,
      SessionState.ended,
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
            child: Text(
              'DEBUG — forçar estado',
              style: TextStyle(color: Colors.yellow, fontSize: 11),
            ),
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
    _pulseController.dispose();
    _rippleController.dispose();
    _sessionManager.removeListener(_onStateChanged);
    _sessionManager.dispose();
    super.dispose();
  }
}

// Pulso — ready, aiSpeaking, listening, processing
class _PulseCirclePainter extends CustomPainter {
  final double scale;
  final Color color;

  _PulseCirclePainter({required this.scale, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;

    for (int i = 3; i >= 1; i--) {
      final waveRadius = baseRadius * scale * (1 + i * 0.15);
      final opacity = (0.15 - i * 0.04).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        waveRadius,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }

    canvas.drawCircle(
      center,
      baseRadius * scale * 0.6,
      Paint()..color = color.withValues(alpha: 0.9),
    );

    canvas.drawCircle(
      center,
      baseRadius * scale * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
  }

  @override
  bool shouldRepaint(_PulseCirclePainter old) =>
      old.scale != scale || old.color != color;
}

// Ripple — correcting: 3 ondas que expandem do centro e somem
class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 3 ondas defasadas em 1/3 do ciclo
    for (int i = 0; i < 3; i++) {
      final wave = (progress + i / 3) % 1.0;
      final radius = maxRadius * wave;
      final opacity = (1.0 - wave) * 0.5;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Círculo central fixo
    canvas.drawCircle(
      center,
      maxRadius * 0.3,
      Paint()..color = color.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.color != color;
}
