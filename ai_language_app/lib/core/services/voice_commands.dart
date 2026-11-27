// Comandos de voz reconhecidos pelo próprio app (sem esperar a IA), para
// serem imediatos e confiáveis. Valem só quando forem a fala inteira:
// "I like to stop at the coffee shop" não encerra nada.
//
// O reconhecimento (Whisper) escreve sempre no idioma da aula: um comando
// dito em português chega TRADUZIDO (ex.: "encerrar" → "Finish." ou "End the
// session."). Por isso a lista tem também as traduções prováveis. O que
// escapar daqui é reconhecido pela IA (campo "command" da resposta).

enum VoiceCommand {
  pause, // pausar a aula
  resume, // retomar (durante a pausa ou o intervalo)
  end, // encerrar a aula
  repeatInstruction, // ouvir de novo a instrução de correção
}

// Lições/aulas em inglês, para as traduções prováveis.
const _lessonWords = ['lesson', 'class', 'session', 'conversation', 'practice'];

List<String> _withLesson(List<String> verbs) => [
      for (final v in verbs) ...[
        v,
        for (final w in _lessonWords) ...['$v the $w', '$v this $w', '$v $w'],
      ],
    ];

final _phrases = <VoiceCommand, List<String>>{
  VoiceCommand.pause: [
    // Português (e o que o reconhecimento do navegador escreve)
    'pausa', 'pausar', 'faz uma pausa', 'faca uma pausa', 'vamos pausar',
    'pausa a aula', 'pausar a aula', 'da uma pausa', 'para um pouco',
    // Inglês, incluindo traduções prováveis do português
    ..._withLesson(['pause', 'pause for a moment']),
    'take a break', 'lets take a break', 'make a pause', 'a pause', 'break',
    'hold on', 'wait a moment', 'give me a break',
    // Outros idiomas da aula
    'pausa la clase', 'haz una pausa', 'mets en pause', 'fais une pause',
    'pausieren', 'mach eine pause', 'pausa la lezione', 'fai una pausa',
  ],
  VoiceCommand.resume: [
    'continuar', 'continua', 'retomar', 'retoma', 'voltar', 'vamos continuar',
    'vamos voltar', 'pode continuar', 'continuar a aula', 'voltar para a aula',
    ..._withLesson(['continue', 'resume']),
    'lets continue', 'lets go on', 'go on', 'go ahead', 'lets go', 'go back',
    'keep going', 'back to the lesson', 'lets get back', 'come back',
    'sigamos', 'continuemos', 'sigue', 'continuer', 'continuons', 'weiter',
    'weitermachen', 'continuiamo', 'riprendi', 'continua pure',
  ],
  VoiceCommand.end: [
    'encerrar', 'encerra', 'encerrar a aula', 'encerra a aula', 'terminar',
    'termina', 'terminar a aula', 'finalizar', 'finalizar a aula', 'acabar',
    'acabar a aula', 'fim', 'fim da aula', 'parar', 'parar a aula',
    ..._withLesson(['end', 'finish', 'stop', 'close', 'quit', 'terminate']),
    'thats all for today', 'im done for today', 'lets stop', 'lets finish',
    'lets end', 'end it', 'the end',
    'terminar la clase', 'terminemos', 'terminer', 'arreter', 'beenden',
    'aufhoren', 'finire', 'basta', 'fine della lezione',
  ],
  VoiceCommand.repeatInstruction: [
    'repetir', 'repete', 'repita', 'repete a instrucao', 'repetir a instrucao',
    'repete a explicacao', 'de novo', 'outra vez',
    'repeat', 'repeat it', 'repeat that', 'repeat the explanation',
    'repeat the instruction', 'say it again', 'say that again', 'again',
    'one more time', 'once more', 'again please',
    'repite', 'repetir otra vez', 'otra vez', 'repete stp', 'wiederholen',
    'wiederhole', 'nochmal', 'ripeti', 'ripetere',
  ],
};

/// Texto exibido no balão "Você" quando a fala foi um comando, em português
/// (a fala chegou traduzida para o idioma da aula).
String commandLabel(VoiceCommand command) => switch (command) {
      VoiceCommand.pause => 'Pausar a aula',
      VoiceCommand.resume => 'Continuar a aula',
      VoiceCommand.end => 'Encerrar a aula',
      VoiceCommand.repeatInstruction => 'Repetir a explicação',
    };

// Palavras de cortesia e muletas ignoradas no começo ou no fim.
const _fillers = [
  'por favor', 'please', 'ok', 'okay', 'ta', 'entao', 'agora', 'now',
  'bitte', 'per favore', 's il te plait', 'stp', 'vamos', 'lets',
  'sorry', 'desculpa', 'desculpe', 'well', 'hmm', 'um', 'uh',
];

/// Identifica um comando quando ele é a fala inteira. [allowed] limita os
/// comandos aceitos no momento (ex.: só "continuar" e "encerrar" na pausa).
VoiceCommand? detectCommand(String text, {Set<VoiceCommand>? allowed}) {
  final t = _strip(_normalize(text));
  if (t.isEmpty) return null;
  for (final entry in _phrases.entries) {
    if (allowed != null && !allowed.contains(entry.key)) continue;
    for (final phrase in entry.value) {
      if (t == phrase) return entry.key;
    }
  }
  return null;
}

// — Pedido de ajuda "não entendi" —
// Dito em português, chega traduzido ("não entendi essa frase" → "I don't
// understand this phrase"), e a IA às vezes explicava a própria fala do aluno.
// O app reconhece essas frases e avisa a IA de que é pedido de ajuda.
const _notUnderstood = [
  'i dont understand', 'i didnt understand', 'i do not understand',
  'i did not understand', 'i cant understand', 'i couldnt understand',
  'i dont get', 'i didnt get', 'i did not get',
];
const _whatWasNotUnderstood = [
  '', 'it', 'that', 'this', 'you', 'this phrase', 'that phrase', 'the phrase',
  'this sentence', 'that sentence', 'the sentence', 'the question',
  'this question', 'your question', 'the explanation', 'what you said',
  'what you mean', 'what that means', 'what it means', 'this part',
  'anything', 'a thing', 'the word', 'this word', 'that word',
];
final _helpPhrases = <String>{
  for (final a in _notUnderstood)
    for (final b in _whatWasNotUnderstood) b.isEmpty ? a : '$a $b',
  'what does that mean', 'what does it mean', 'what does this mean',
  'what does this phrase mean', 'what does this sentence mean',
  'what do you mean', 'what did you say', 'what did you mean',
  // Português (reconhecimento do navegador)
  'nao entendi', 'nao entendo', 'nao entendi essa frase',
  'nao entendi a frase', 'nao entendi a pergunta', 'nao entendi nada',
  'o que significa isso', 'o que quer dizer isso',
};

/// True quando a fala inteira é um pedido do tipo "não entendi" (sobre a
/// última fala da IA). "I don't know" não entra: é resposta normal.
bool isNotUnderstoodRequest(String text) {
  final t = _strip(_normalize(text));
  return t.isNotEmpty && _helpPhrases.contains(t);
}

/// Minúsculas, sem acentos, sem pontuação e com espaços simples.
String _normalize(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñß';
  const to = 'aaaaaeeeeiiiiooooouuuucns';
  final buffer = StringBuffer();
  for (final ch in text.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer
      .toString()
      .replaceAll(RegExp("['’]"), '') // let's → lets
      .replaceAll(RegExp(r"[^a-z0-9 ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Tira palavras de cortesia do começo e do fim ("pausa, por favor").
String _strip(String t) {
  var changed = true;
  while (changed && t.isNotEmpty) {
    changed = false;
    for (final f in _fillers) {
      if (t == f) return '';
      if (t.startsWith('$f ')) {
        t = t.substring(f.length + 1);
        changed = true;
      }
      if (t.endsWith(' $f')) {
        t = t.substring(0, t.length - f.length - 1);
        changed = true;
      }
    }
  }
  return t;
}

/// Pergunta falada depois da instrução de correção, no idioma da instrução
/// (nativo até B2; idioma da aula em C1-C2). [language]: nome do idioma da
/// aula (ex.: 'Inglês') ou null para o idioma nativo.
String correctionPrompt(String? language) => switch (language) {
      null =>
        'Tente dizer a frase de novo, ou diga "repetir" para ouvir a explicação.',
      'Espanhol' =>
        'Intenta decirlo de nuevo, o di "repite" para escuchar la explicación.',
      'Francês' =>
        "Essaie de le redire, ou dis « répète » pour réécouter l'explication.",
      'Alemão' =>
        'Versuch es noch einmal, oder sag „wiederholen", um die Erklärung noch einmal zu hören.',
      'Italiano' =>
        'Prova a ridirlo, oppure di "ripeti" per riascoltare la spiegazione.',
      _ => 'Try saying it again, or say "repeat" to hear the explanation.',
    };

/// Despedida falada ao encerrar a aula por voz, no idioma da aula.
String goodbyePhrase(String language) => switch (language) {
      'Espanhol' => '¡Muy bien! Hasta la próxima.',
      'Francês' => 'Très bien ! À la prochaine.',
      'Alemão' => 'Sehr gut! Bis zum nächsten Mal.',
      'Italiano' => 'Molto bene! Alla prossima.',
      _ => 'Great job today! See you next time.',
    };

/// Aviso falado ao pausar, no idioma nativo.
const pausedPrompt = 'Aula pausada. Diga "continuar" quando quiser voltar.';
