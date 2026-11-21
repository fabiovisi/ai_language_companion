import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/services/voice_commands.dart';

void main() {
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

  test('frases de correção e despedida por idioma', () {
    expect(correctionPrompt(null), contains('repetir'));
    expect(correctionPrompt('Inglês'), contains('repeat'));
    expect(goodbyePhrase('Espanhol'), contains('próxima'));
  });
}
