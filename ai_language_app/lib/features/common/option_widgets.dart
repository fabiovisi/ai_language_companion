import 'package:flutter/material.dart';

// Componentes de escolha usados pela Home e pelas Configurações.

const _accent = Color(0xFF176B65);

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

class ConfigCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ConfigCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: _accent, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Lista de opções em uma folha que sobe da parte de baixo da tela.
/// [description], se informado, mostra um texto de apoio em cada opção.
void showOptionsSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required T selected,
  required String Function(T) label,
  String Function(T)? description,
  required void Function(T) onSelect,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...options.map((option) => ListTile(
                  title: Text(label(option)),
                  subtitle:
                      description != null ? Text(description(option)) : null,
                  trailing: option == selected
                      ? const Icon(Icons.check, color: _accent)
                      : null,
                  onTap: () {
                    onSelect(option);
                    Navigator.pop(sheetContext);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
