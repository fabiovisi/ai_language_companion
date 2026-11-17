class DriveModeDetector {
  // Responsável por detectar se o app está rodando em contexto de condução.
  // Futuramente vai consultar UiModeManager (Android) e CarPlay (iOS).

  Future<bool> isDriving() async {
    return false; // placeholder
  }
}
