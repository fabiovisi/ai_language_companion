abstract class AudioFocusService {
  // Gerencia foco de áudio do sistema (VO-02, AC-13).
  // Garante que chamadas, navegação e outros apps interrompem a sessão corretamente.
  // Implementação varia entre Android nativo, Android Auto e CarPlay.

  Future<bool> requestFocus();
  Future<void> abandonFocus();
  Stream<bool> get focusLostEvents;
}
