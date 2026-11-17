import 'package:flutter/material.dart';
import '../features/home/home_screen.dart';
import '../features/conversation/conversation_screen.dart';
import '../features/conversation/driving_conversation_screen.dart';
import '../features/settings/settings_screen.dart';

class AppRouter {
  // Define as rotas nomeadas do app.
  // Centralizar aqui facilita controlar navegação por contexto (ex: drive mode).

  static const String home = '/';
  static const String conversation = '/conversation';
  static const String drivingConversation = '/driving-conversation';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes => {
        home: (_) => const HomeScreen(),
        conversation: (_) => const ConversationScreen(),
        drivingConversation: (_) => const DrivingConversationScreen(),
        settings: (_) => const SettingsScreen(),
      };
}
