import '../../domain/models/student_profile.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/correction.dart';

/// Resultado de uma atualização da memória.
/// [lessonNote]: o assunto desta aula, para retomar na próxima.
typedef MemoryUpdate = ({String memory, String? lessonNote});

class AiTurn {
  final String text;      // fala principal (retorno sobre o que o aluno disse)
  final String? followUp; // nova pergunta, falada após uma pausa
  final Correction? correction;

  // Preenchidos apenas quando há erro detectado:
  final String? correctionReaction; // fala no idioma alvo (ex: "I didn't catch that...")
  final String? instructionPt;      // instrução específica (português até B2; idioma alvo em C1-C2)

  /// Resposta a um pedido de ajuda: explicação no idioma nativo (até B2),
  /// com as palavras do idioma da aula entre aspas. Quando presente, [text]
  /// traz a mesma explicação e [followUp], a pergunta com palavras simples.
  final String? help;

  /// O aluno pediu para falar mais devagar: a pergunta seguinte usa uma
  /// velocidade mais lenta.
  final bool slower;

  /// O aluno pediu para encerrar ou pausar a aula (em qualquer idioma ou
  /// frase). Quem age é o app; [text] vem vazio.
  final LessonCommand? command;

  const AiTurn({
    required this.text,
    this.followUp,
    this.correction,
    this.correctionReaction,
    this.instructionPt,
    this.help,
    this.slower = false,
    this.command,
  });

  bool get hasCorrection => correction != null;
  bool get isHelp => help != null;
}

/// Comandos de controle da aula reconhecidos pela IA.
enum LessonCommand { end, pause }

/// Informações de debug que os serviços de IA reais expõem para a tela.
abstract class LlmDebugInfo {
  String get providerName;   // ex.: 'Groq'
  String? get lastModel;     // modelo que respondeu no último turno
  Duration? get lastDuration; // tempo de resposta do último turno
  String? get lastError;     // motivo da última falha; null se não houve
}

abstract class ConversationService {
  // Interface abstrata para o motor conversacional/LLM (AC-03).
  // Regra para distribuição: chaves de API ficam no backend (PR-04).
  // Fase atual (uso pessoal): a chave do Gemini vem via --dart-define.

  /// O que o app lembra do aluno de aulas anteriores, usado nas instruções
  /// da IA. Null: sem memória.
  String? get memory;
  set memory(String? value);

  /// Atualiza a memória com as últimas trocas da conversa. [lessonNote]: o
  /// assunto desta aula até agora. Devolve a nova memória e a nova nota da
  /// aula, ou null se não for possível (sem conversa, falha ou mock).
  Future<MemoryUpdate?> updateMemory({
    required String? previous,
    required StudentProfile profile,
    String? lessonNote,
  });

  /// Reescreve no idioma nativo uma instrução de correção que veio em outro
  /// idioma, mantendo as palavras entre chaves. Null se não for possível.
  Future<String?> rewriteInstruction(String instruction);

  /// Abertura da conversa: saudação (text) e primeira pergunta (followUp),
  /// no idioma, tema e nível da aula. [previousLesson]: o assunto da aula
  /// anterior, para retomar (ver previousLessonText).
  Future<AiTurn> startConversation({
    required StudentProfile profile,
    required SessionConfig config,
    String? previousLesson,
  });

  /// [isRetryAfterCorrection]: o aluno está tentando de novo após uma correção.
  /// Pedidos de ajuda são reconhecidos pela IA pelo sentido da fala.
  Future<AiTurn> sendTurn({
    required String userUtterance,
    required StudentProfile profile,
    required SessionConfig config,
    bool isRetryAfterCorrection = false,
  });
}
