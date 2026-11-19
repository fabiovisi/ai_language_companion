/// Trecho de texto para a voz. [quoted] indica que estava entre aspas duplas.
typedef SpeechSegment = ({String text, bool quoted});

/// Divide o texto pelas aspas duplas ("..." ou “...”).
///
/// Usado na instrução de correção (A1-B2): o texto fora das aspas é falado
/// em português e o texto entre aspas, no idioma da aula.
/// Ex.: 'Tente dizer: "I live".' → [Tente dizer:] [I live] [.]
List<SpeechSegment> splitQuoted(String text) {
  final segments = <SpeechSegment>[];
  var quoted = false;
  for (final part in text.split(RegExp('["“”]'))) {
    final trimmed = part.trim();
    // Ignora trechos só com pontuação (ex.: o ponto final depois das aspas).
    if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(trimmed)) {
      segments.add((text: trimmed, quoted: quoted));
    }
    quoted = !quoted;
  }
  return segments;
}
