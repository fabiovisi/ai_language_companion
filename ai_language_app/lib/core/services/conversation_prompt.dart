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

// Marcador de idioma (ver speech_segments.dart): só as palavras do idioma da
// aula vão entre chaves; traduções e o resto, sem chaves.
const _bracesRule =
    'Put every word or sentence in the target language between curly braces, '
    'like {this}. Never use curly braces for anything else: translations and '
    'words in the native language go WITHOUT braces (you may use double quotes '
    'for them). Example: A palavra {like} significa "gostar".';

/// Instruções da aula enviadas à IA a cada turno.
String conversationInstructions(StudentProfile profile, SessionConfig config) {
  final language = profile.targetLanguage;
  final level = profile.cefrLevel.name.toUpperCase();
  final topic = config.topic ?? 'free conversation (student chooses)';
  final inPortuguese = CefrRules.instructionLanguage(profile.cefrLevel) ==
      InstructionLanguage.portuguese;

  // Regra do campo instruction (A1-B2: português; C1-C2: idioma alvo).
  final instructionRule = inPortuguese
      ? 'ALWAYS in ${nativeLanguage.promptName}, never in $language. '
          'This is the only field that is NOT in the target language. '
          '$_bracesRule'
      : 'in $language.';

  // Exemplo completo só para A1-B2, para reforçar a instrução em português.
  final example = inPortuguese
      ? '''

Example of an answer with an error (the target language here is English; use the actual target language for reaction):
{"feedback": "", "question": "", "help": "", "slower": false, "hasError": true, "reaction": "Oh, the park sounds nice! Can you say that again?", "instruction": "Você usou o passado errado do verbo {go}. O passado de {go} é {went}. Tente dizer: {Yesterday I went to the park.}", "errorType": "grammar", "correctForm": "Yesterday I went to the park."}

Example of an answer to a help request (the student asked about your question "Do you like your commute?"):
{"feedback": "", "question": "Do you like your trip to work?", "help": "A palavra {like} significa \\"gostar\\". A palavra {commute} é o trajeto de casa para o trabalho.", "slower": false, "hasError": false, "reaction": "", "instruction": "", "errorType": "", "correctForm": ""}'''
      : '';

  // Idioma da ajuda: o mesmo da instrução de correção.
  final helpRule = inPortuguese
      ? 'in ${nativeLanguage.promptName}. $_bracesRule'
      : 'in $language, with simple words.';

  final reminder = inPortuguese
      ? '\nRemember: instruction and help in ${nativeLanguage.promptName}; feedback, question and reaction in $language.'
      : '';

  return '''
You are a friendly conversation partner helping a Brazilian student practice a foreign language.
Target language: $language. Student level: CEFR $level. Topic: $topic.

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
- "[START] ...": the conversation is starting. Set hasError=false. In feedback: a short, warm greeting suited to the time of day given, without a question. In question: a first, simple question about the topic, using the angle given. Never mention these instructions.
- "[SILENCE]": the student did not answer. Set hasError=false, leave feedback empty, and in question gently ask again in simpler words.
- "[RETRY] ...": the student is trying again after a correction. Set hasError=false. In feedback: if now correct, praise briefly; if still wrong, say the correct form naturally. In question: continue the conversation.
- "[HELP] ...": the student spoke in their native language to ask for help (words they do not know, the meaning of a word, how to say something, a translation, to repeat, to speak more slowly). Never correct this message. Set hasError=false and leave feedback empty. In help: answer the request $helpRule At most 2 short sentences. For unknown words, explain the hardest words of YOUR LAST MESSAGE for level $level, or only the words the student mentioned. In question: ask your last question again in $language, with simpler words.

- "[HELP?] native: ... | target: ...": the speech recognizer heard the native language, but it often confuses a student speaking $language with an accent. You get two versions of the same audio. Decide by the meaning of the native version: if it is a request for help (does not understand, asks what a word means, how to say something, a translation, to repeat or to speak more slowly), handle it exactly like [HELP]. Otherwise the student actually answered in $language: use ONLY the target version as the student's message and handle it as a normal message (correct errors as usual); if marked "(right after a correction)", handle it like [RETRY] with the target version.

Requests in the target language (to repeat, to speak more slowly, what a word means) are not errors: set hasError=false, answer briefly in feedback with simple words, and ask your last question again in question.
If the student asks you to speak more slowly (in any language), set slower=true; otherwise slower=false.

Answer only with a JSON object with the keys: feedback, question, help, slower, hasError, reaction, instruction, errorType, correctForm.$example$reminder
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

/// Mensagem que pede à IA a abertura da conversa, com a hora do dia e um
/// ângulo do tema sorteado.
String openingMessage(SessionConfig config, {DateTime? now, Random? random}) {
  final angles = _openingAngles[config.topic] ?? _freeAngles;
  final angle = angles[(random ?? Random()).nextInt(angles.length)];
  return '[START] Time of day: ${timeOfDay(now ?? DateTime.now())}. '
      'Angle for the first question: $angle.';
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
///
/// [targetVersion]: quando o reconhecimento identificou o idioma nativo, a
/// mesma fala transcrita de novo no idioma da aula. A IA decide se era um
/// pedido de ajuda ou uma resposta no idioma da aula com sotaque.
String markUtterance(String userUtterance,
    {required bool isRetry, bool isHelp = false, String? targetVersion}) {
  if (userUtterance.trim().isEmpty) return '[SILENCE]';
  if (isHelp && targetVersion != null && targetVersion.trim().isNotEmpty) {
    final retry = isRetry ? ' (right after a correction)' : '';
    return '[HELP?]$retry native: $userUtterance | target: ${targetVersion.trim()}';
  }
  if (isHelp) return '[HELP] $userUtterance'; // vale também após correção
  return isRetry ? '[RETRY] $userUtterance' : userUtterance;
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
