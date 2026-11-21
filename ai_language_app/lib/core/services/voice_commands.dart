// Comandos de voz reconhecidos pelo próprio app (sem esperar a IA), para
// serem imediatos e confiáveis. Valem em português e nos idiomas da aula, e
// só quando forem a fala inteira: "I like to stop at the coffee shop" não
// encerra nada.

enum VoiceCommand {
  pause, // pausar a aula
  resume, // retomar (durante a pausa)
  end, // encerrar a aula
  repeatInstruction, // ouvir de novo a instrução de correção
}

const _phrases = <VoiceCommand, List<String>>{
  VoiceCommand.pause: [
    'pausa', 'pausar', 'pause', 'faz uma pausa', 'faca uma pausa',
    'vamos pausar', 'pausa a aula', 'pausar a aula', 'pause the lesson',
    'pausa la clase', 'mets en pause', 'pausieren', 'pausa la lezione',
  ],
  VoiceCommand.resume: [
    'continuar', 'continua', 'continue', 'retomar', 'retoma', 'voltar',
    'vamos continuar', 'vamos voltar', 'pode continuar', 'resume',
    'lets continue', 'go on', 'sigamos', 'continuemos', 'continuer',
    'continuons', 'weiter', 'weitermachen', 'continuiamo', 'riprendi',
  ],
  VoiceCommand.end: [
    'encerrar', 'encerra', 'encerrar a aula', 'encerra a aula', 'terminar',
    'termina', 'terminar a aula', 'finalizar', 'acabar', 'fim', 'parar',
    'stop', 'end', 'finish', 'end the lesson', 'finish the lesson',
    'terminar la clase', 'terminer', 'arreter', 'beenden', 'aufhoren',
    'finire', 'basta',
  ],
  VoiceCommand.repeatInstruction: [
    'repetir', 'repete', 'repita', 'repete a instrucao', 'repetir a instrucao',
    'de novo', 'repeat', 'repeat it', 'say it again', 'again', 'repite',
    'repetir otra vez', 'repete', 'repete stp', 'wiederholen', 'wiederhole',
    'nochmal', 'ripeti', 'ripetere',
  ],
};

// Palavras de cortesia e muletas ignoradas no começo ou no fim.
const _fillers = [
  'por favor', 'please', 'ok', 'okay', 'ta', 'entao', 'agora', 'now',
  'bitte', 'per favore', 's il te plait', 'stp', 'vamos', 'lets',
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
