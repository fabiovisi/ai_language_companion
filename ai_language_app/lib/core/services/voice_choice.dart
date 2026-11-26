// Regras da voz no navegador que não dependem do navegador (testáveis):
// escolha da voz, prazo de cada frase e fim rápido demais.

/// Voz disponível no navegador. [local]: instalada no sistema (não depende
/// da internet).
typedef WebVoice = ({String name, String lang, bool local});

/// Escolhe a voz do idioma [lang] (ex.: 'en-US').
/// - normal: prefere as vozes do Google (mais naturais, dependem da internet);
/// - [fallback]: prefere vozes locais, usadas depois de uma falha.
WebVoice? chooseWebVoice(List<WebVoice> voices, String lang,
    {bool fallback = false}) {
  final ofLang =
      voices.where((v) => v.lang.toLowerCase() == lang.toLowerCase()).toList();
  if (ofLang.isEmpty) return null;
  bool isGoogle(WebVoice v) => v.name.contains('Google');

  final preferred = fallback
      ? ofLang.where((v) => v.local && !isGoogle(v))
      : ofLang.where(isGoogle);
  return preferred.isNotEmpty ? preferred.first : ofLang.first;
}

/// Prazo para uma frase terminar: generoso, proporcional ao texto e à
/// velocidade (ex.: 60 letras na velocidade 1 → cerca de 9 s).
Duration speakTimeout(String text, double rate) => Duration(
    milliseconds: 4000 + (text.length * 90 / (rate <= 0 ? 1 : rate)).round());

/// True quando a fala "terminou" rápido demais para o tamanho do texto: sinal
/// de que o navegador não falou nada. Só vale para textos com 20 letras ou
/// mais (frases curtas terminam rápido mesmo).
bool finishedTooFast(String text, Duration elapsed, double rate) {
  if (text.length < 20) return false;
  final minimum = text.length * 20 / (rate <= 0 ? 1 : rate); // ms
  return elapsed.inMilliseconds < minimum;
}
