import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/app_settings.dart';
import '../debug/debug_settings.dart';
import 'key_value_store.dart';

/// Configurações atuais do app. As telas escutam este objeto; cada mudança
/// é guardada no aparelho.
class SettingsController extends ValueNotifier<AppSettings> {
  SettingsController(this._store) : super(const AppSettings());

  final KeyValueStore _store;
  static const _key = 'app_settings_v1';

  /// Carrega o que foi guardado. Se não houver nada, ou se der erro, fica
  /// com os valores padrão.
  Future<void> load() async {
    try {
      final raw = await _store.getString(_key);
      if (raw != null) {
        value = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // Dado corrompido ou armazenamento indisponível: segue com o padrão.
    }
    showDebugInfo.value = value.showDebugInfo;
  }

  /// Aplica uma mudança e guarda.
  Future<void> update(AppSettings Function(AppSettings current) change) async {
    value = change(value);
    showDebugInfo.value = value.showDebugInfo;
    try {
      await _store.setString(_key, jsonEncode(value.toJson()));
    } catch (_) {
      // Sem armazenamento, a mudança vale só até fechar o app.
    }
  }
}

/// Instância usada pelo app.
final appSettings = SettingsController(SharedPrefsStore());
