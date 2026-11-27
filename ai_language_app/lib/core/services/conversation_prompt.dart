// Partes comuns a todos os serviços de IA de conversa (Gemini, Groq...):
// instruções da aula, abertura, marcadores, histórico e conversão da resposta
// em AiTurn. Cada serviço cuida só da chamada à sua API.

import 'dart:math';

import '../../domain/models/correction.dart';
import '../../domain/models/native_language.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/student_profile.dart';
import '../../domain/pedagogy/cefr_rules.dart';
import 'conversation_service.dart';
import 'voice_commands.dart';

// Marcador de idioma (ver speech_segments.dart): só as palavras do idioma da
// aula vão entre chaves; traduções e o resto, sem chaves.
const _bracesRule =
    'Put every word or sentence in the target language between curly braces, '
    'like {this}. Never use curly braces for anything else: translations and '
    'words in the native language go WITHOUT braces (you may use double quotes '
    'for them). Example: A palavra {like} significa "gostar".';

/// Instruções da aula enviadas à IA a cada turno.
///
/// [memory]: o que o app lembra do aluno de aulas anteriores (ver
/// memoryUpdateInstructions). Null ou vazio: sem memória.
String conversationInstructions(StudentProfile profile, SessionConfig config,
    {String? memory}) {
  final memoryBlock = memory == null || memory.trim().isEmpty
      ? ''
      : '''

What you remember about the student from previous lessons (written in Portuguese). Use it naturally to personalize the conversation, to ask about things the student told you before and to practice their recurring mistakes. Never read it aloud, list it or mention that you have notes:
${memory.trim()}
''';
  final language = profile.targetLanguage;
  final level = profile.cefrLevel.name.toUpperCase();
  final topic = config.topic ?? 'free conversation (student chooses)';
  final inPortuguese = CefrRules.instructionLanguage(profile.cefrLevel) ==
      InstructionLanguage.portuguese;

  // Regra do campo instruction (A1-B2: português; C1-C2: idioma alvo).
  final instructionRule = inPortuguese
      ? 'ALWAYS in ${nativeLanguage.promptName}, never in $language. '
          'This is the only field that is NOT in the target language. '
          'Even the explanation itself (what was wrong, the grammar rule) '
          'must be written in ${nativeLanguage.promptName}; only the words '
          'and sentences in $language go inside curly braces. '
          '$_bracesRule'
      : 'in $language.';

  // Exemplo completo só para A1-B2, para reforçar a instrução em português.
  final example = inPortuguese
      ? '''

Example of an answer with an error (the target language here is English; use the actual target language for reaction):
{"feedback": "", "question": "", "help": "", "slower": false, "command": "", "hasError": true, "reaction": "Oh, the park sounds nice! Can you say that again?", "instruction": "Você usou o passado errado do verbo {go}. O passado de {go} é {went}. Tente dizer: {Yesterday I went to the park.}", "errorType": "grammar", "correctForm": "Yesterday I went to the park."}

Another example of an instruction, about prepositions. WRONG (explanation in English): "Use {in} instead of {at} for times of day. Diga: ..." RIGHT: "Com períodos do dia, use {in} e não {at}. Diga: {Usually I go to the beach in the afternoon.}"

Example of an answer to a help request (the student asked about your question "Do you like your commute?"):
{"feedback": "", "question": "Do you like your trip to work?", "help": "A palavra {like} significa \\"gostar\\". A palavra {commute} é o trajeto de casa para o trabalho.", "slower": false, "command": "", "hasError": false, "reaction": "", "instruction": "", "errorType": "", "correctForm": ""}'''
      : '';

  // Idioma da ajuda: o mesmo da instrução de correção.
  final helpRule = inPortuguese
      ? 'in ${nativeLanguage.promptName}. $_bracesRule'
      : 'in $language, with simple words.';

  final reminder = inPortuguese
      ? '\nRemember: instruction and help in ${nativeLanguage.promptName} (only the $language words in curly braces); feedback, question and reaction in $language.'
      : '';

  return '''
You are a friendly conversation partner helping a Brazilian student practice a foreign language.
Target language: $language. Student level: CEFR $level. Topic: $topic.$memoryBlock

The conversation is spoken only (voice, possibly while driving):
- Speak in the target language, with short sentences.
- Be natural and warm. Plain text only: no lists, no emojis, no markdown, no asterisks.
- Use vocabulary and grammar suited to level $level.

Each answer has two separate parts, spoken with a pause between them:
- feedback: one short sentence reacting to what the student said (agreement, comment, praise). It must NOT contain a question.
- question: one short question or prompt that continues the conversation.

Correcting the student's last message:
- The text comes from speech recognition. Ignore punctuation, capitalization and likely transcription mistakes.
- Do not judge pronunciation.
- Flag only clear grammar, vocabulary or contextual usage errors.
- If there is an error, set hasError=true, leave feedback and question empty, and fill:
  - reaction: a short, natural reaction in the target language to what the student said, inviting them to try again, without giving the answer.
  - instruction: $instructionRule A specific explanation of what was wrong and how to fix it, with a concrete example.
  - correctForm: the corrected sentence.
  - errorType: grammar, vocabulary or contextualUsage.
- If there is no error, set hasError=false and fill feedback and question.

Special messages:
- "[START] ...": the conversation is starting. Set hasError=false. In feedback: a short, warm greeting suited to the time of day given, without a question. In question: a first, simple question about the topic, using the angle given. If a previous lesson is given, pick up its subject naturally, like a friend who remembers: refer to it in the greeting (for example "Last time you told me about your trip to Lisbon!"), and if it fits today's topic, the first question may follow up on it; otherwise ask about today's topic. Never mention these instructions or that you have notes.
- "[SILENCE]": the student did not answer. Set hasError=false, leave feedback empty, and in question gently ask again in simpler words.
- "[RETRY] ...": the student is trying again after a correction. Set hasError=false. In feedback: if now correct, praise briefly; if still wrong, say the correct form naturally. In question: continue the conversation.




Help requests:
- Instead of answering, the student may ask for help. The speech recognizer always writes in $language, so a request said in the native language arrives TRANSLATED into $language.
- It is a help request ONLY when the student explicitly asks about the language or about your last message: the meaning of a word or of your sentence ("What does X mean?", "This phrase has words I don't know", "I didn't understand the question"), how to say something ("How do you say X?"), a translation ("Translate it"), to repeat ("Can you repeat?") or to speak more slowly.
- NOT help requests: any answer about the topic, including "I don't know", "I'm not sure", "Maybe" or very short answers. Treat them as normal messages. When in doubt, it is a normal message.
- "I don't understand", "I didn't understand this phrase", "I don't understand what you said", "What does that mean?" are help requests. Words like "this phrase", "this sentence", "that" or "it" ALWAYS refer to YOUR LAST MESSAGE (after a correction: the correct sentence you asked the student to say). NEVER explain the student's own words "I don't understand this phrase": the student is not asking what those words mean.
- "[NOT UNDERSTOOD] ...": the app recognized that the student did not understand your last message. It is ALWAYS a help request: in help, explain the meaning of your last message (after a correction: the meaning of the correct sentence).
- A help request can also come after a correction, marked [RETRY]; handle it as a help request.
- For a help request: never correct it. Set hasError=false and leave feedback empty. In help: answer the request $helpRule At most 2 short sentences. For unknown words, explain the hardest words of YOUR LAST MESSAGE for level $level, or only the words the student mentioned. In question: ask your last question again in $language, with simpler words.
- If the student asks you to speak more slowly, set slower=true; otherwise slower=false.

Lesson commands (handled by the app, not by you):
- If the student asks to END the lesson (for example "End the session", "Finish the class", "I want to stop", "That's all for today"), set command="end" and leave all other fields empty. Do NOT say goodbye: the app gives the lesson summary and the goodbye.
- If the student asks to PAUSE the lesson (for example "Pause the class", "Let's take a break"), set command="pause" and leave all other fields empty.
- Only when the student clearly asks to control the lesson. A message that only mentions stopping or pausing as part of the conversation (for example "I stop at the gym after work") is a normal message: command="".
- Otherwise command="".

Answer only with a JSON object with the keys: feedback, question, help, slower, command, hasError, reaction, instruction, errorType, correctForm.$example$reminder
''';
}

// — Abertura da conversa —

/// Ângulos sorteados para a primeira pergunta, por tema (nomes da Home).
/// Variam a abertura de uma sessão para outra.
const _openingAngles = <String, List<String>>{
  'Apresentações pessoais': [
    'where the student lives',
    'their job or studies',
    'their family',
    'a hobby they enjoy',
    'why they are learning this language',
  ],
  'Encontros sociais': [
    'a recent party or gathering',
    'meeting new people',
    'plans for the weekend',
    'a good friend',
    'how they celebrate birthdays',
  ],
  'Viagem': [
    'their last trip',
    'a dream destination',
    'their favorite way to travel',
    'what they always pack',
    'a funny or difficult moment while traveling',
  ],
  'Compras e serviços': [
    'a recent purchase',
    'shopping online versus in stores',
    'grocery shopping',
    'a recent visit to a restaurant',
    'a service they use often',
  ],
  'Trabalho e networking': [
    'their daily work routine',
    'a colleague they like',
    'a goal at work',
    'a work event or meeting',
    'their ideal job',
  ],
  'Saúde e emergências': [
    'healthy habits',
    'how they sleep',
    'a visit to the doctor',
    'exercise and sports',
    'what to do in an emergency',
  ],
  'Cultura e entretenimento': [
    'a movie or series they watched',
    'music they like',
    'a book they read',
    'a local festival or tradition',
    'what they do for fun on weekends',
  ],
};

const _freeAngles = [
  'their daily routine',
  'food they like',
  'the weather today',
  'plans for the weekend',
  'a hobby',
  'something good that happened recently',
];

/// Período do dia usado na saudação.
String timeOfDay(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'morning';
  if (h >= 12 && h < 18) return 'afternoon';
  return 'evening';
}

/// Mensagem que pede à IA a abertura da conversa, com a hora do dia, um
/// ângulo do tema sorteado e, se houver, o assunto da aula anterior
/// (ver previousLessonText).
String openingMessage(SessionConfig config,
    {DateTime? now, Random? random, String? previousLesson}) {
  final angles = _openingAngles[config.topic] ?? _freeAngles;
  final angle = angles[(random ?? Random()).nextInt(angles.length)];
  final previous = previousLesson == null || previousLesson.trim().isEmpty
      ? ''
      : ' Previous lesson ($previousLesson).';
  return '[START] Time of day: ${timeOfDay(now ?? DateTime.now())}. '
      'Angle for the first question: $angle.$previous';
}

/// Abertura fixa, no idioma da aula, para quando a IA não responde
/// (ou quando o app usa o mock).
AiTurn fallbackOpening(String language, {DateTime? now, Random? random}) {
  final period = timeOfDay(now ?? DateTime.now());
  final texts = _fallbackOpenings[language] ?? _fallbackOpenings['Inglês']!;
  final questions = texts.questions;
  return AiTurn(
    text: texts.greetings[period]!,
    followUp: questions[(random ?? Random()).nextInt(questions.length)],
  );
}

const _fallbackOpenings = <String,
    ({Map<String, String> greetings, List<String> questions})>{
  'Inglês': (
    greetings: {
      'morning': "Good morning! It's nice to talk to you.",
      'afternoon': "Good afternoon! It's nice to talk to you.",
      'evening': "Good evening! It's nice to talk to you.",
    },
    questions: [
      'How are you today?',
      'What have you been up to lately?',
      'What would you like to talk about today?',
    ],
  ),
  'Espanhol': (
    greetings: {
      'morning': '¡Buenos días! Qué bueno hablar contigo.',
      'afternoon': '¡Buenas tardes! Qué bueno hablar contigo.',
      'evening': '¡Buenas noches! Qué bueno hablar contigo.',
    },
    questions: [
      '¿Cómo estás hoy?',
      '¿Qué has hecho últimamente?',
      '¿De qué te gustaría hablar hoy?',
    ],
  ),
  'Francês': (
    greetings: {
      'morning': 'Bonjour ! Ravi de parler avec toi.',
      'afternoon': 'Bonjour ! Ravi de parler avec toi.',
      'evening': 'Bonsoir ! Ravi de parler avec toi.',
    },
    questions: [
      "Comment ça va aujourd'hui ?",
      "Qu'est-ce que tu as fait récemment ?",
      "De quoi aimerais-tu parler aujourd'hui ?",
    ],
  ),
  'Alemão': (
    greetings: {
      'morning': 'Guten Morgen! Schön, mit dir zu sprechen.',
      'afternoon': 'Guten Tag! Schön, mit dir zu sprechen.',
      'evening': 'Guten Abend! Schön, mit dir zu sprechen.',
    },
    questions: [
      'Wie geht es dir heute?',
      'Was hast du in letzter Zeit gemacht?',
      'Worüber möchtest du heute sprechen?',
    ],
  ),
  'Italiano': (
    greetings: {
      'morning': 'Buongiorno! È bello parlare con te.',
      'afternoon': 'Buon pomeriggio! È bello parlare con te.',
      'evening': 'Buonasera! È bello parlare con te.',
    },
    questions: [
      'Come stai oggi?',
      'Cosa hai fatto di recente?',
      'Di cosa ti piacerebbe parlare oggi?',
    ],
  ),
};

/// Texto enviado à IA para a fala do aluno, com os marcadores especiais.
/// Pedidos de ajuda não têm marcador: a IA os reconhece pelo sentido.
String markUtterance(String userUtterance, {required bool isRetry}) {
  if (userUtterance.trim().isEmpty) return '[SILENCE]';
  // "Não entendi (essa frase)": o app já sabe que é pedido de ajuda.
  final text = isNotUnderstoodRequest(userUtterance)
      ? '[NOT UNDERSTOOD] $userUtterance'
      : userUtterance;
  return isRetry ? '[RETRY] $text' : text;
}

/// Converte a resposta JSON da IA no modelo do app.
AiTurn turnFromJson(
    Map<String, dynamic> data, String userUtterance, String language) {
  String field(String name) => (data[name] as String? ?? '').trim();

  final feedback = field('feedback');
  final question = field('question');
  final help = field('help');
  final slower = data['slower'] == true;
  final reaction = field('reaction');
  final instruction = field('instruction');

  // Pedido para encerrar ou pausar a aula: quem age é o app.
  final command = switch (field('command').toLowerCase()) {
    'end' => LessonCommand.end,
    'pause' => LessonCommand.pause,
    _ => null,
  };
  if (command != null) return AiTurn(text: '', command: command);

  if (data['hasError'] == true && reaction.isNotEmpty && instruction.isNotEmpty) {
    return AiTurn(
      text: reaction,
      correctionReaction: reaction,
      instructionPt: instruction,
      correction: Correction(
        type: ErrorType.values.firstWhere(
          (t) => t.name == field('errorType'),
          orElse: () => ErrorType.grammar,
        ),
        originalUtterance: userUtterance,
        correctForm: field('correctForm'),
      ),
    );
  }

  // Pedido de ajuda: explicação, pausa e a pergunta com palavras simples.
  if (help.isNotEmpty) {
    return AiTurn(
      text: help,
      help: help,
      followUp: question.isNotEmpty ? question : null,
      slower: slower,
    );
  }

  // Retorno e pergunta: a tela fala o retorno, faz uma pausa e faz a pergunta.
  if (feedback.isNotEmpty && question.isNotEmpty) {
    return AiTurn(text: feedback, followUp: question, slower: slower);
  }
  // Só uma das partes (ex.: pergunta repetida após silêncio): sem pausa.
  final single = feedback.isNotEmpty
      ? feedback
      : question.isNotEmpty
          ? question
          : field('reply'); // formato antigo, por segurança
  return AiTurn(
    text: single.isNotEmpty ? single : fallbackPhrase(language),
    slower: slower,
  );
}

/// Frase falada quando a IA não responde, no idioma da aula.
String fallbackPhrase(String language) => switch (language) {
      'Espanhol' => 'Perdón, tuve un problema de conexión. ¿Puedes repetirlo?',
      'Francês' => "Désolé, j'ai eu un problème de connexion. Tu peux répéter ?",
      'Alemão' =>
        'Entschuldigung, ich hatte ein Verbindungsproblem. Kannst du das wiederholen?',
      'Italiano' => 'Scusa, ho avuto un problema di connessione. Puoi ripetere?',
      _ => 'Sorry, I had a connection problem. Could you say that again?',
    };

// — Instrução de correção no idioma errado —

/// Pede à IA para reescrever no idioma nativo uma instrução de correção que
/// veio em inglês (fora das chaves).
final instructionRewriteInstructions = '''
Rewrite this explanation for a language student in ${nativeLanguage.promptName}.
Keep every word or sentence inside curly braces {like this} exactly as it is, in the original language.
Everything outside the braces must be in Portuguese: translate any explanation that is in another language.
Every word or sentence the student must say or use, in the language being learned, goes inside curly braces, even if it was in quotes (for example: Diga: "I go" → Diga: {I go}).
Keep it short, with the same meaning.
Answer only with a JSON object: {"instruction": "..."}
''';

/// Lê a instrução reescrita. Null se vier vazia ou fora do formato.
String? rewrittenInstructionFromJson(Map<String, dynamic> data) {
  final text = (data['instruction'] as String? ?? '').trim();
  return text.isEmpty ? null : text;
}

// — Memória do aluno —

/// Tamanho máximo guardado (a memória vai nas instruções de cada turno).
const _maxMemoryLength = 800;

/// Instruções para atualizar a memória do aluno a partir da conversa recente.
String memoryUpdateInstructions(String language) => '''
You keep a short memory about a student of $language, used to personalize future lessons.
Merge the previous memory with what the student revealed in the recent conversation.
Keep only useful, lasting information:
- personal facts the student shared (job, family, hobbies, places, plans, preferences);
- topics the student enjoyed;
- recurring language mistakes, with the correct form (for example: Erra o passado de "go": usar "went").
Drop small talk and one-off details. Never invent facts. If nothing new was revealed, return the previous memory unchanged.
Write in ${nativeLanguage.promptName}, one fact per line starting with "- ", at most 8 lines and 600 characters.

Also keep a note about THIS lesson, used to pick up the subject in the next lesson:
- lessonNote: one or two short sentences in ${nativeLanguage.promptName} about what the student talked about in this lesson so far (for example: Contou que vai viajar para Lisboa em dezembro e que está aprendendo a surfar.). Merge it with "This lesson so far". Only what the student said; no corrections, no grammar.

Answer only with a JSON object: {"memory": "...", "lessonNote": "..."}
''';

/// Mensagem com a memória anterior, a nota desta aula até agora e as últimas
/// trocas da conversa.
String memoryUpdateMessage(
    String? previous, List<({String user, String model})> exchanges,
    {String? lessonNote}) {
  String orEmpty(String? s) => s == null || s.trim().isEmpty ? '(empty)' : s;
  final b = StringBuffer()
    ..writeln('Previous memory:')
    ..writeln(orEmpty(previous))
    ..writeln()
    ..writeln('This lesson so far:')
    ..writeln(orEmpty(lessonNote))
    ..writeln()
    ..writeln('Recent conversation:');
  for (final e in exchanges) {
    b
      ..writeln('Student: ${e.user}')
      ..writeln('Tutor (JSON): ${e.model}');
  }
  return b.toString();
}

/// Tamanho máximo da nota da aula.
const _maxLessonNoteLength = 300;

/// Lê a memória atualizada. Null se a memória vier vazia ou fora do formato.
MemoryUpdate? memoryFromJson(Map<String, dynamic> data) {
  String? cut(Object? value, int max) {
    final s = (value is String ? value : '').trim();
    if (s.isEmpty) return null;
    return s.length > max ? s.substring(0, max) : s;
  }

  final memory = cut(data['memory'], _maxMemoryLength);
  if (memory == null) return null;
  return (
    memory: memory,
    lessonNote: cut(data['lessonNote'], _maxLessonNoteLength),
  );
}

/// Texto da aula anterior para a abertura (ex.: "2 days ago: ..."). Null se
/// não houver nota, ou se a aula foi há mais de [maxAge] (assunto antigo).
String? previousLessonText(String? note, DateTime? date,
    {DateTime? now, Duration maxAge = const Duration(days: 14)}) {
  if (note == null || note.trim().isEmpty || date == null) return null;
  final today = now ?? DateTime.now();
  final age = DateTime(today.year, today.month, today.day)
      .difference(DateTime(date.year, date.month, date.day));
  if (age.isNegative || age > maxAge) return null;
  final days = age.inDays;
  final when = days == 0
      ? 'earlier today'
      : days == 1
          ? 'yesterday'
          : '$days days ago';
  return '$when: ${note.trim()}';
}

/// Histórico curto da conversa: últimas trocas (fala do aluno + resposta da IA).
class ConversationHistory {
  ConversationHistory({this.maxExchanges = 4});

  final int maxExchanges;
  final List<({String user, String model})> _items = [];

  List<({String user, String model})> get exchanges => List.unmodifiable(_items);

  void add(String user, String model) {
    _items.add((user: user, model: model));
    while (_items.length > maxExchanges) {
      _items.removeAt(0);
    }
  }
}
