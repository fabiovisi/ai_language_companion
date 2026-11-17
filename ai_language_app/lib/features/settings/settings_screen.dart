import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Tela de configurações — idioma de estudo e nível de proficiência.
  // Os valores aqui alimentam o contexto da IA na conversa.

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Settings Screen'),
      ),
    );
  }
}
