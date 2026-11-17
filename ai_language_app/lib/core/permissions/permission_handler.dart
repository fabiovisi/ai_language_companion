import 'package:permission_handler/permission_handler.dart';

class AppPermissionHandler {
  // Solicita permissão de microfone de forma contextual (PR-01).
  // Retorna true se concedida, false caso contrário.

  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> isMicrophoneGranted() async {
    return await Permission.microphone.isGranted;
  }

  Future<bool> isMicrophonePermanentlyDenied() async {
    return await Permission.microphone.isPermanentlyDenied;
  }
}
