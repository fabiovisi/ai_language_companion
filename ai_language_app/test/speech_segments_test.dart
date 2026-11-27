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

  test('instrução em inglês fora das chaves é detectada', () {
    // O caso relatado pelo usuário.
    expect(
        looksEnglishOutsideBraces('Use {In} instead of {at} for times of day. '
            'Diga: {Usually I go to the beach in the afternoon}'),
        isTrue);
    expect(
        looksEnglishOutsideBraces(
            'The past of {go} is {went}. Try to say it again.'),
        isTrue);
  });

  test('instrução misturada (português e inglês) é detectada', () {
    // O caso relatado: explicação em inglês e "Diga:" em português, com a
    // frase entre aspas em vez de chaves.
    expect(
        looksEnglishOutsideBraces('Use "In" instead of "at" for times of day. '
            'Diga: "Usually I go to the beach in the afternoon"'),
        isTrue);
    expect(
        looksEnglishOutsideBraces(
            'Você errou a preposição. Use {in} instead of {at}. Tente de novo.'),
        isTrue);
    expect(
        looksEnglishOutsideBraces(
            'O passado de {go} é {went}. Diga: "Yesterday I went to the park."'),
        isTrue);
  });
  test('instrução padrão fica em português', () {
    final text = fallbackInstruction('I went to the park.');
    expect(text, contains('{I went to the park.}'));
    expect(looksEnglishOutsideBraces(text), isFalse);
  });
  test('instrução em português não é detectada como inglês', () {
    expect(
        looksEnglishOutsideBraces(
            'Use {went}, o passado do verbo {go}. A palavra "gostar" é {like}.'),
        isFalse);
    expect(
        looksEnglishOutsideBraces('Com períodos do dia, use {in} e não {at}. '
            'Diga: {Usually I go to the beach in the afternoon.}'),
        isFalse);
    expect(
        looksEnglishOutsideBraces(
            'Você usou o passado errado do verbo {go}. Tente dizer: {I went}.'),
        isFalse);
    expect(looksEnglishOutsideBraces('Diga: {I went to the park.}'), isFalse);
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
