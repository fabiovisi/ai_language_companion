import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/services/conversation_prompt.dart';
import 'package:ai_language_app/core/storage/key_value_store.dart';
import 'package:ai_language_app/core/storage/memory_store.dart';
import 'package:ai_language_app/domain/models/session_config.dart';
import 'package:ai_language_app/domain/models/student_profile.dart';

/// Armazenamento em memória, só para os testes.
class _MemoryKv implements KeyValueStore {
  final data = <String, String>{};

  @override
  Future<String?> getString(String key) async => data[key];

  @override
  Future<void> setString(String key, String value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);
}

const _profile = StudentProfile(
  targetLanguage: 'Inglês',
  cefrLevel: CefrLevel.a2,
  lastSessionConfig:
      SessionConfig(mode: SessionMode.continuous, speechRate: SpeechRate.normal),
);
const _config =
    SessionConfig(mode: SessionMode.continuous, speechRate: SpeechRate.normal);

void main() {
  group('MemoryStore', () {
    test('guarda e recupera por idioma', () async {
      final kv = _MemoryKv();
      final store = MemoryStore(kv);
      await store.save('Inglês', '- Trabalha como desenvolvedor');

      expect(await store.load('Inglês'), '- Trabalha como desenvolvedor');
      expect(await store.load('Espanhol'), isNull);
    });

    test('apagar remove só o idioma', () async {
      final store = MemoryStore(_MemoryKv());
      await store.save('Inglês', '- Gosta de surfar');
      await store.save('Espanhol', '- Mora em Brasília');
      await store.clear('Inglês');

      expect(await store.load('Inglês'), isNull);
      expect(await store.load('Espanhol'), '- Mora em Brasília');
    });

    test('dado corrompido não quebra', () async {
      final kv = _MemoryKv()..data['memory_v1_Inglês'] = '{ruim';

      expect(await MemoryStore(kv).load('Inglês'), isNull);
    });
  });

  group('instruções', () {
    test('com memória: entra nas instruções da aula', () {
      final text = conversationInstructions(_profile, _config,
          memory: '- Gosta de surfar\n- Erra o passado de "go"');

      expect(text, contains('What you remember about the student'));
      expect(text, contains('- Gosta de surfar'));
    });

    test('sem memória: nenhum bloco', () {
      expect(conversationInstructions(_profile, _config),
          isNot(contains('What you remember')));
      expect(conversationInstructions(_profile, _config, memory: '  '),
          isNot(contains('What you remember')));
    });

    test('pedido de atualização leva a memória anterior e as trocas', () {
      final message = memoryUpdateMessage('- Mora em Brasília', [
        (user: 'I surf every weekend', model: '{"feedback": "Cool!"}'),
      ]);

      expect(message, contains('- Mora em Brasília'));
      expect(message, contains('Student: I surf every weekend'));
      expect(memoryUpdateMessage(null, const []), contains('(empty)'));
    });

    test('memória atualizada: lida e limitada em tamanho', () {
      expect(memoryFromJson({'memory': ' - Gosta de surfar '}),
          '- Gosta de surfar');
      expect(memoryFromJson({'memory': ''}), isNull);
      expect(memoryFromJson({}), isNull);
      expect(memoryFromJson({'memory': 'x' * 2000})!.length, 800);
    });
  });
}
