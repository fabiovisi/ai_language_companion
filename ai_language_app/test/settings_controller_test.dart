import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/debug/debug_settings.dart';
import 'package:ai_language_app/core/storage/key_value_store.dart';
import 'package:ai_language_app/core/storage/settings_controller.dart';
import 'package:ai_language_app/domain/models/session_config.dart';
import 'package:ai_language_app/domain/models/student_profile.dart';

/// Armazenamento em memória, só para os testes.
class _MemoryStore implements KeyValueStore {
  final data = <String, String>{};

  @override
  Future<String?> getString(String key) async => data[key];

  @override
  Future<void> setString(String key, String value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);
}

void main() {
  test('sem nada guardado: valores padrão', () async {
    final controller = SettingsController(_MemoryStore());
    await controller.load();

    expect(controller.value.targetLanguage, 'Inglês');
    expect(controller.value.cefrLevel, CefrLevel.a2);
    expect(controller.value.topic, isNull);
  });

  test('guarda e recupera as escolhas', () async {
    final store = _MemoryStore();
    await SettingsController(store).update((s) => s.copyWith(
          targetLanguage: 'Espanhol',
          cefrLevel: CefrLevel.b1,
          topic: () => 'Viagem',
          speechRate: SpeechRate.slow,
          showDebugInfo: true,
        ));

    final reopened = SettingsController(store);
    await reopened.load();

    expect(reopened.value.targetLanguage, 'Espanhol');
    expect(reopened.value.cefrLevel, CefrLevel.b1);
    expect(reopened.value.topic, 'Viagem');
    expect(reopened.value.speechRate, SpeechRate.slow);
    expect(reopened.value.showDebugInfo, isTrue);
    expect(showDebugInfo.value, isTrue);
  });

  test('modo intervalado: guarda o intervalo e passa para a sessão', () async {
    final store = _MemoryStore();
    await SettingsController(store).update((s) =>
        s.copyWith(mode: SessionMode.spaced, intervalSeconds: 120));

    final reopened = SettingsController(store);
    await reopened.load();

    expect(reopened.value.mode, SessionMode.spaced);
    expect(reopened.value.intervalSeconds, 120);
    expect(reopened.value.toSessionConfig().spacedInterval,
        const Duration(minutes: 2));
  });

  test('intervalo inválido ou ausente volta ao padrão (1 min)', () async {
    final store = _MemoryStore()
      ..data['app_settings_v1'] = '{"mode": "spaced", "intervalSeconds": 45}';
    final controller = SettingsController(store);
    await controller.load();

    expect(controller.value.mode, SessionMode.spaced);
    expect(controller.value.intervalSeconds, 60);
  });

  test('rótulo do intervalo', () {
    expect(intervalLabel(30), '30 s');
    expect(intervalLabel(60), '1 min');
    expect(intervalLabel(120), '2 min');
  });

  test('tema pode voltar a ser livre', () async {
    final controller = SettingsController(_MemoryStore());
    await controller.update((s) => s.copyWith(topic: () => 'Viagem'));
    await controller.update((s) => s.copyWith(topic: () => null));

    expect(controller.value.topic, isNull);
  });

  test('dado corrompido não quebra: volta ao padrão', () async {
    final store = _MemoryStore()..data['app_settings_v1'] = '{não é json';
    final controller = SettingsController(store);
    await controller.load();

    expect(controller.value.targetLanguage, 'Inglês');
  });

  test('valor desconhecido (versão antiga) volta ao padrão', () async {
    final store = _MemoryStore()
      ..data['app_settings_v1'] = '{"cefrLevel": "z9", "targetLanguage": "Alemão"}';
    final controller = SettingsController(store);
    await controller.load();

    expect(controller.value.cefrLevel, CefrLevel.a2);
    expect(controller.value.targetLanguage, 'Alemão');
  });
}
