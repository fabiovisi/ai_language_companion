
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Language Companion'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            const Text(
              'Olá! Vamos praticar?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Aprenda um novo idioma conversando com inteligência artificial.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),

            const SizedBox(height: 40),

            const Text(
              'Seu idioma de estudo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.language,
                  color: Color(0xFF176B65),
                  size: 32,
                ),
                title: const Text('Inglês'),
                subtitle: const Text('Idioma selecionado'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Seu nível atual',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.school_outlined,
                  color: Color(0xFF176B65),
                  size: 32,
                ),
                title: const Text('A2 - Elementar'),
                subtitle: const Text('Nível de proficiência'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.mic),
                label: const Text(
                  'Iniciar conversação',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
