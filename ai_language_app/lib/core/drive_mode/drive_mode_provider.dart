import 'package:flutter/foundation.dart';
import 'drive_mode_detector.dart';

class DriveModeProvider extends ChangeNotifier {
  final DriveModeDetector _detector = DriveModeDetector();

  bool _isDriving = false;
  bool get isDriving => _isDriving;

  Future<void> check() async {
    _isDriving = await _detector.isDriving();
    notifyListeners();
  }

  // Apenas para testes em kDebugMode — simula detecção real
  void setDrivingOverride(bool value) {
    assert(kDebugMode, 'setDrivingOverride só pode ser usado em debug');
    _isDriving = value;
    notifyListeners();
  }
}
