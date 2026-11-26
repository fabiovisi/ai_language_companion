import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/services/voice_choice.dart';

void main() {
  const voices = <WebVoice>[
    (name: 'Microsoft Zira - English (United States)', lang: 'en-US', local: true),
    (name: 'Google US English', lang: 'en-US', local: false),
    (name: 'Google UK English Female', lang: 'en-GB', local: false),
    (name: 'Microsoft Maria - Portuguese (Brazil)', lang: 'pt-BR', local: true),
  ];

  test('normal: prefere a voz do Google do idioma', () {
    expect(chooseWebVoice(voices, 'en-US')?.name, 'Google US English');
  });

  test('depois de uma falha: usa a voz local do idioma', () {
    expect(chooseWebVoice(voices, 'en-US', fallback: true)?.name,
        startsWith('Microsoft Zira'));
  });

  test('sem voz do Google: usa a que existir', () {
    expect(chooseWebVoice(voices, 'pt-BR')?.name, startsWith('Microsoft Maria'));
  });

  test('idioma sem voz: nenhuma', () {
    expect(chooseWebVoice(voices, 'it-IT'), isNull);
  });

  test('prazo da frase cresce com o texto e com a fala mais lenta', () {
    final short = speakTimeout('Hi!', 1.0);
    final long = speakTimeout('x' * 100, 1.0);
    final slow = speakTimeout('x' * 100, 0.6);

    expect(short.inMilliseconds, greaterThanOrEqualTo(4000));
    expect(long, greaterThan(short));
    expect(slow, greaterThan(long));
  });

  test('fim rápido demais indica que o navegador não falou', () {
    final text = 'What do you usually do on the weekend?'; // 38 letras
    expect(finishedTooFast(text, const Duration(milliseconds: 50), 1.0), isTrue);
    expect(finishedTooFast(text, const Duration(seconds: 2), 1.0), isFalse);
    // Frases curtas terminam rápido mesmo.
    expect(finishedTooFast('Great!', const Duration(milliseconds: 50), 1.0),
        isFalse);
  });
}
