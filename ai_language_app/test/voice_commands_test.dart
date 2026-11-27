import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/services/voice_commands.dart';

void main() {
  test('pedidos "não entendi" são reconhecidos', () {
    expect(isNotUnderstoodRequest("I don't understand this phrase."), isTrue);
    expect(isNotUnderstoodRequest("Sorry, I didn't understand."), isTrue);
    expect(isNotUnderstoodRequest("I don't understand what you said"), isTrue);
    expect(isNotUnderstoodRequest('What does that mean?'), isTrue);
    expect(isNotUnderstoodRequest('Não entendi essa frase'), isTrue);
    // Respostas normais não são pedidos de ajuda.
    expect(isNotUnderstoodRequest("I don't know."), isFalse);
    expect(isNotUnderstoodRequest("I don't understand why people work on "
        'weekends'), isFalse);
  });

  test('comandos em português e no idioma da aula', () {
    expect(detectCommand('Pausa.'), VoiceCommand.pause);
    expect(detectCommand('pause'), VoiceCommand.pause);
    expect(detectCommand('Continuar'), VoiceCommand.resume);
    expect(detectCommand("Let's continue."), VoiceCommand.resume);
    expect(detectCommand('Encerrar a aula'), VoiceCommand.end);
    expect(detectCommand('Stop!'), VoiceCommand.end);
    expect(detectCommand('Repetir'), VoiceCommand.repeatInstruction);
    expect(detectCommand('Repeat, please.'), VoiceCommand.repeatInstruction);
  });

  test('cortesia e acentos não atrapalham', () {
    expect(detectCommand('Pausa, por favor.'), VoiceCommand.pause);
    expect(detectCommand('Ok, repete a instrução.'),
        VoiceCommand.repeatInstruction);
    expect(detectCommand('Then, CONTINUAR!'), isNull); // "then" não é cortesia
  });

  test('só vale quando é a fala inteira', () {
    expect(detectCommand('I like to stop at the coffee shop'), isNull);
    expect(detectCommand('I need a pause from work sometimes'), isNull);
    expect(detectCommand('Yesterday I went to the park'), isNull);
    expect(detectCommand(''), isNull);
    expect(detectCommand('por favor'), isNull);
  });

  test('aceita só os comandos permitidos no momento', () {
    const paused = {VoiceCommand.resume, VoiceCommand.end};
    expect(detectCommand('Continuar', allowed: paused), VoiceCommand.resume);
    expect(detectCommand('Repetir', allowed: paused), isNull);
  });

  test('comandos em português chegam traduzidos pelo Whisper', () {
    // "encerrar", "encerrar a aula", "terminar"...
    expect(detectCommand('Finish.'), VoiceCommand.end);
    expect(detectCommand('End the session.'), VoiceCommand.end);
    expect(detectCommand('Close the class.'), VoiceCommand.end);
    expect(detectCommand('Finish the lesson, please.'), VoiceCommand.end);
    expect(detectCommand("That's all for today."), VoiceCommand.end);
    // "pausa", "faz uma pausa"...
    expect(detectCommand('Pause the class.'), VoiceCommand.pause);
    expect(detectCommand("Let's take a break."), VoiceCommand.pause);
    // "continuar", "voltar"...
    expect(detectCommand('Continue the lesson.'), VoiceCommand.resume);
    expect(detectCommand('Go back.'), VoiceCommand.resume);
    // "repetir", "de novo"...
    expect(detectCommand('Repeat the explanation.'),
        VoiceCommand.repeatInstruction);
    expect(detectCommand('One more time.'), VoiceCommand.repeatInstruction);
  });

  test('falas de conversa não viram comando', () {
    expect(detectCommand('Goodbye!'), isNull); // pode ser resposta normal
    expect(detectCommand('I finish work at six.'), isNull);
    expect(detectCommand('I take a break at lunch.'), isNull);
  });

  test('texto do comando para o balão "Você"', () {
    expect(commandLabel(VoiceCommand.end), 'Encerrar a aula');
    expect(commandLabel(VoiceCommand.pause), 'Pausar a aula');
  });

  test('frases de correção e despedida por idioma', () {
    expect(correctionPrompt(null), contains('repetir'));
    expect(correctionPrompt('Inglês'), contains('repeat'));
    expect(goodbyePhrase('Espanhol'), contains('próxima'));
  });
}
