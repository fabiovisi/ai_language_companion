import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/services/conversation_prompt.dart';
import 'package:ai_language_app/domain/models/session_config.dart';
import 'package:ai_language_app/domain/models/student_profile.dart';

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

  test('pedido de ajuda: explicação e pergunta mais simples', () {
    final turn = turnFromJson({
      'hasError': false,
      'feedback': '',
      'help': 'A palavra "commute" é o trajeto de casa para o trabalho.',
      'question': 'How long is your trip to work?',
    }, 'Essa frase tem palavras que não conheço', 'Inglês');

    expect(turn.isHelp, isTrue);
    expect(turn.hasCorrection, isFalse);
    expect(turn.text, contains('"commute"'));
    expect(turn.followUp, 'How long is your trip to work?');
  });

  test('"mais devagar": marca a próxima pergunta como mais lenta', () {
    final turn = turnFromJson({
      'hasError': false,
      'feedback': 'Sure!',
      'question': 'Where do you work?',
      'slower': true,
    }, 'Slower, please', 'Inglês');

    expect(turn.slower, isTrue);
    expect(turn.isHelp, isFalse);
  });

  test('marcadores da fala do aluno', () {
    expect(markUtterance('', isRetry: false), '[SILENCE]');
    expect(markUtterance('I went', isRetry: true), '[RETRY] I went');
    // Pedidos de ajuda não têm marcador: a IA os reconhece pelo sentido.
    expect(markUtterance('What does commute mean?', isRetry: false),
        'What does commute mean?');
  });

  test('instruções explicam o pedido de ajuda no idioma nativo', () {
    final text = conversationInstructions(
      const StudentProfile(
        targetLanguage: 'Inglês',
        cefrLevel: CefrLevel.a2,
        lastSessionConfig: SessionConfig(
            mode: SessionMode.continuous, speechRate: SpeechRate.normal),
      ),
      const SessionConfig(
          mode: SessionMode.continuous, speechRate: SpeechRate.normal),
    );

    expect(text, contains('Help requests:'));
    expect(text, contains('arrives TRANSLATED'));
    expect(text, contains('When in doubt, it is a normal message'));
    expect(text, isNot(contains('[HELP')));
    expect(text, contains('Brazilian Portuguese'));
    expect(text, contains('help, slower'));
  });

  test('resposta vazia: frase de reserva no idioma da aula', () {
    final turn = turnFromJson({'hasError': false}, 'hola', 'Espanhol');

    expect(turn.text, contains('Perdón'));
  });
}
