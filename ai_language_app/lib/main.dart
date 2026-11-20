import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/storage/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appSettings.load(); // últimas escolhas guardadas no aparelho
  runApp(const App());
}
