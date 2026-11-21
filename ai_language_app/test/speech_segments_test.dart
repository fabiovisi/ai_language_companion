import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/services/speech_segments.dart';

void main() {
  test('chaves: idioma da aula; aspas: tradução no idioma nativo', () {
    final segments =
        splitTargetLanguage('A palavra {like} significa "gostar".');

    expect(segments, [
      (text: 'A palavra', target: false),
      (text: 'like', target: true),
      (text: 'significa "gostar".', target: false),
    ]);
  });

  test('instrução de correção com exemplo completo', () {
    final segments = splitTargetLanguage(
        'O passado de {go} é {went}. Tente dizer: {Yesterday I went to the park.}');

    expect(segments.map((s) => s.text).toList(), [
      'O passado de',
      'go',
      'é',
      'went',
      'Tente dizer:',
      'Yesterday I went to the park.',
    ]);
    expect(segments.map((s) => s.target).toList(),
        [false, true, false, true, false, true]);
  });

  test('texto sem chaves fica inteiro', () {
    expect(splitTargetLanguage('Muito bem!'),
        [(text: 'Muito bem!', target: false)]);
  });

  test('na tela, as chaves viram aspas', () {
    expect(displayText('A palavra {like} significa "gostar".'),
        'A palavra "like" significa "gostar".');
  });

  test('palavras marcadas', () {
    expect(targetWords('{commute} é o trajeto; {rush hour} é o horário de pico.'),
        ['commute', 'rush hour']);
  });

  test('destaque das palavras na frase original', () {
    final parts = highlightWords(
        'What do you do during your Commute in rush hour?',
        ['commute', 'rush hour']);

    expect(parts.where((p) => p.highlight).map((p) => p.text).toList(),
        ['Commute', 'rush hour']);
    expect(parts.map((p) => p.text).join(),
        'What do you do during your Commute in rush hour?');
  });

  test('destaque não pega pedaço de outra palavra', () {
    final parts = highlightWords('I like the likely result.', ['like']);

    expect(parts.where((p) => p.highlight).length, 1);
  });
}
