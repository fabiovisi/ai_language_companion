import 'package:flutter/foundation.dart';
import 'session_state.dart';

class SessionStateManager extends ChangeNotifier {
  // Centraliza todas as transições de estado da sessão.
  // Garante que microfone é desligado nos estados corretos (PR-02).
  // Nunca retoma áudio automaticamente após interrupção externa (AC-13).

  SessionState _state = SessionState.preparing;
  SessionState get state => _state;

  bool get isMicrophoneActive =>
      _state == SessionState.listening ||
      _state == SessionState.lowConfidenceRetry;

  void transition(SessionState next) {
    _state = next;
    notifyListeners();
  }
}
