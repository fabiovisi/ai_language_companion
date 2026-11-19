import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/services/conversation_prompt.dart';

void main() {
  test('sem erro: separa retorno e pergunta', () {
    final turn = turnFromJson({
      'hasError': false,
      'feedback': 'That sounds great!',
      'question': 'What do you do on weekends?',
    }, 'I like the beach', 'Inglês');

    expect(turn.hasCorrection, isFalse);
    expect(turn.text, 'That sounds great!');
    expect(turn.followUp, 'What do you do on weekends?');
  });

  test('silêncio: só a pergunta, sem pausa', () {
    final turn = turnFromJson({
      'hasError': false,
      'feedback': '',
      'question': 'Do you like music?',
    }, '', 'Inglês');

    expect(turn.text, 'Do you like music?');
    expect(turn.followUp, isNull);
  });

  test('com erro: reação e instrução', () {
    final turn = turnFromJson({
      'hasError': true,
      'feedback': '',
      'question': '',
      'reaction': 'Can you say that again?',
      'instruction': 'Use "went".',
      'errorType': 'grammar',
      'correctForm': 'I went to the park.',
    }, 'I goed to the park', 'Inglês');

    expect(turn.hasCorrection, isTrue);
    expect(turn.text, 'Can you say that again?');
    expect(turn.instructionPt, 'Use "went".');
    expect(turn.followUp, isNull);
  });

  test('resposta vazia: frase de reserva no idioma da aula', () {
    final turn = turnFromJson({'hasError': false}, 'hola', 'Espanhol');

    expect(turn.text, contains('Perdón'));
  });
}
