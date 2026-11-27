// Marcador de idioma nas falas da IA no idioma nativo (instrução de correção
// e ajuda): as palavras do idioma da aula vêm entre chaves, {like}. Aspas
// continuam sendo destaque comum, falado na voz do idioma nativo:
//   A palavra {like} significa "gostar".
// As chaves não são usadas pela IA em texto comum, só porque as instruções
// mandam; por isso não se confundem com as traduções.

/// Trecho de texto para a voz. [target] indica que estava entre chaves
/// (idioma da aula).
typedef SpeechSegment = ({String text, bool target});

final _braces = RegExp(r'\{([^{}]*)\}');
final _hasLetter = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Divide o texto pelas chaves: fora delas, idioma nativo; dentro, idioma
/// da aula. Ex.: 'A palavra {like} significa "gostar".' →
/// [A palavra] [like] [significa "gostar".]
List<SpeechSegment> splitTargetLanguage(String text) {
  final segments = <SpeechSegment>[];
  void add(String part, bool target) {
    // Sem pontuação solta no início (ex.: o ponto depois de "{went}.").
    final trimmed = part.trim().replaceFirst(RegExp(r'^[.,;:!?)\]]+\s*'), '');
    // Ignora trechos só com pontuação (ex.: o ponto final depois das chaves).
    if (_hasLetter.hasMatch(trimmed)) {
      segments.add((text: trimmed, target: target));
    }
  }

  var last = 0;
  for (final m in _braces.allMatches(text)) {
    add(text.substring(last, m.start), false);
    add(m.group(1)!, true);
    last = m.end;
  }
  add(text.substring(last), false);
  return segments;
}

// Palavras muito comuns em inglês e quase inexistentes em português: servem
// para notar uma explicação escrita em inglês fora das chaves.
const _englishMarkers = {
  'the', 'is', 'are', 'was', 'were', 'you', 'your', 'instead', 'of', 'for',
  'with', 'should', 'when', 'this', 'that', 'it', 'and', 'to', 'say', 'try',
  'means', 'mean', 'word', 'verb', 'tense', 'past', 'present', 'correct',
  'wrong', 'times', 'day', 'not', 'because', 'like', 'in', 'at', 'on',
  // (nada de "use" e "do", que também são palavras em português)
  'i', 'my', 'we', 'they', 'he', 'she', 'have', 'has', 'does',
  'go', 'went', 'usually', 'afternoon', 'morning', 'evening', 'sentence',
  'phrase', 'which', 'what', 'here', 'there', 'after', 'before',
};


/// True quando o texto FORA das chaves parece estar em inglês (a IA escreveu
/// a explicação em inglês, e não no idioma nativo). As palavras entre chaves
/// são do idioma da aula e não contam.
bool looksEnglishOutsideBraces(String text) {
  final outside = text.replaceAll(_braces, ' ').toLowerCase();
  final words = RegExp(r"[\p{L}']+", unicode: true)
      .allMatches(outside)
      .map((m) => m.group(0)!)
      .toList();
  // Basta um trecho em inglês: a instrução pode vir misturada, com partes em
  // português (ex.: 'Use "in" instead of "at" for times of day. Diga: ...').
  // As palavras da lista não existem em português, então 2 já indicam inglês.
  final english = words.where(_englishMarkers.contains).length;
  return english >= 2;
}

/// Instrução de correção simples, em português, usada quando a da IA veio em
/// inglês e não pôde ser reescrita.
String fallbackInstruction(String correctForm) =>
    'O certo é assim. Tente dizer: {$correctForm}';

/// Texto para exibir na tela: as chaves viram aspas.
/// Ex.: 'A palavra {like} significa "gostar".' →
/// 'A palavra "like" significa "gostar".'
String displayText(String text) =>
    text.replaceAllMapped(_braces, (m) => '"${m.group(1)}"');

/// Palavras do idioma da aula marcadas no texto (entre chaves).
List<String> targetWords(String text) => _braces
    .allMatches(text)
    .map((m) => m.group(1)!.trim())
    .where((w) => w.isNotEmpty)
    .toList();

/// Divide [sentence] em trechos, marcando os que coincidem com alguma das
/// [words] (sem diferenciar maiúsculas), para destacá-los na tela.
List<({String text, bool highlight})> highlightWords(
    String sentence, List<String> words) {
  final escaped = (words.toSet().toList()
        ..sort((a, b) => b.length.compareTo(a.length))) // frases antes
      .where((w) => w.isNotEmpty)
      .map(RegExp.escape)
      .toList();
  if (escaped.isEmpty) return [(text: sentence, highlight: false)];

  final pattern = RegExp(
      r'(?<![\p{L}\p{N}])(' + escaped.join('|') + r')(?![\p{L}\p{N}])',
      caseSensitive: false,
      unicode: true);

  final parts = <({String text, bool highlight})>[];
  var last = 0;
  for (final m in pattern.allMatches(sentence)) {
    if (m.start > last) {
      parts.add((text: sentence.substring(last, m.start), highlight: false));
    }
    parts.add((text: m.group(0)!, highlight: true));
    last = m.end;
  }
  if (last < sentence.length) {
    parts.add((text: sentence.substring(last), highlight: false));
  }
  return parts;
}
