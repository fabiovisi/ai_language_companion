import 'dart:convert';

import 'key_value_store.dart';

/// Memória do aluno, uma por idioma: um resumo curto (em português) com fatos
/// pessoais, interesses e erros que se repetem. Fica guardada no aparelho e
/// vai nas instruções da IA a cada aula.
class MemoryStore {
  MemoryStore(this._store);

  final KeyValueStore _store;

  static String _key(String language) => 'memory_v1_$language';

  /// Memória do idioma, ou null se não houver (ou se o dado estiver ruim).
  Future<String?> load(String language) async {
    try {
      final raw = await _store.getString(_key(language));
      if (raw == null) return null;
      final memory = (jsonDecode(raw) as Map<String, dynamic>)['memory'];
      return memory is String && memory.trim().isNotEmpty ? memory : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String language, String memory) async {
    try {
      await _store.setString(
        _key(language),
        jsonEncode({
          'memory': memory,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {
      // Sem armazenamento, a memória vale só até fechar o app.
    }
  }

  Future<void> clear(String language) async {
    try {
      await _store.remove(_key(language));
    } catch (_) {}
  }
}

/// Instância usada pelo app.
final studentMemory = MemoryStore(SharedPrefsStore());
