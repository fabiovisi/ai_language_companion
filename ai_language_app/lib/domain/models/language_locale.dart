/// Converte o idioma escolhido na Home no código usado por STT e TTS.
const _localeIds = {
  'Inglês': 'en_US',
  'Espanhol': 'es_ES',
  'Francês': 'fr_FR',
  'Alemão': 'de_DE',
  'Italiano': 'it_IT',
};

/// Idiomas que o aluno pode estudar, na ordem exibida.
final List<String> supportedLanguages = List.unmodifiable(_localeIds.keys);

/// Devolve o código do idioma (ex.: 'en_US'). Usa inglês se não reconhecer.
String localeIdFor(String targetLanguage) =>
    _localeIds[targetLanguage] ?? 'en_US';
