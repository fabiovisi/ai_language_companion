import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/services/speech_segments.dart';

void main() {
  test('separa o texto em português dos exemplos entre aspas', () {
    final segments =
        splitQuoted('Você errou o uso do verbo. Tente dizer: "I live".');

    expect(segments, [
      (text: 'Você errou o uso do verbo. Tente dizer:', quoted: false),
      (text: 'I live', quoted: true),
    ]);
  });

  test('aceita aspas curvas e vários exemplos', () {
    final segments = splitQuoted('O passado de “go” é “went”.');

    expect(segments.map((s) => s.text).toList(),
        ['O passado de', 'go', 'é', 'went']);
    expect(segments.map((s) => s.quoted).toList(), [false, true, false, true]);
  });

  test('texto sem aspas fica inteiro', () {
    expect(splitQuoted('Muito bem!'), [(text: 'Muito bem!', quoted: false)]);
  });
}
