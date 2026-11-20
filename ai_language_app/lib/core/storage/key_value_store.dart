import 'package:shared_preferences/shared_preferences.dart';

/// Armazenamento simples de textos no aparelho, atrás de uma interface
/// (como voz e IA), para poder trocar a implementação sem mexer nas telas.
abstract class KeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// Usa o shared_preferences: armazenamento interno no Android e
/// localStorage no navegador (preso ao endereço, ex.: localhost:8080).
class SharedPrefsStore implements KeyValueStore {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> getString(String key) async => (await _prefs).getString(key);

  @override
  Future<void> setString(String key, String value) async =>
      (await _prefs).setString(key, value);

  @override
  Future<void> remove(String key) async => (await _prefs).remove(key);
}
