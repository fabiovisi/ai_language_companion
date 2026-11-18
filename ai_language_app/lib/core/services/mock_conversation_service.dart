import 'dart:math';
import '../../domain/models/student_profile.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/correction.dart';
import 'conversation_service.dart';

class MockConversationService implements ConversationService {
  final _random = Random();

  static const _normalResponses = [
    'Nice to meet you! Tell me more about yourself.',
    'That sounds interesting! What do you enjoy doing in your free time?',
    'Great! How often do you practice English during the week?',
    'I see! Have you ever traveled to an English-speaking country?',
    'Wonderful! Let\'s keep going. What did you do last weekend?',
  ];

  // Reação no idioma alvo + instrução específica em português, por erro
  static const _corrections = [
    (
      reaction: 'I didn\'t quite catch that, could you say it again?',
      instruction: 'Você usou o tempo errado do verbo "go". Tente usar "went" na frase.',
      correctForm: 'went',
      type: ErrorType.grammar,
    ),
    (
      reaction: 'Sorry, I\'m not sure I understood. Want to try once more?',
      instruction: 'O artigo está incorreto antes de "university". Em inglês, use "a" e não "an" aqui.',
      correctForm: 'a university',
      type: ErrorType.grammar,
    ),
    (
      reaction: 'Hmm, that wasn\'t very clear to me. Can you repeat?',
      instruction: 'Você esqueceu o auxiliar "did" na pergunta. Tente: "Did you go to the store?"',
      correctForm: 'Did you go',
      type: ErrorType.grammar,
    ),
    (
      reaction: 'I think something got lost there. Could you rephrase that?',
      instruction: 'A ordem das palavras ficou invertida. Em inglês o adjetivo vem antes do substantivo.',
      correctForm: 'a big house',
      type: ErrorType.grammar,
    ),
    (
      reaction: 'Let me make sure I understood — could you say that differently?',
      instruction: 'Cuidado com o plural de "person" — o correto é "people", não "persons".',
      correctForm: 'people',
      type: ErrorType.vocabulary,
    ),
  ];

  // Confirmações após correção bem-sucedida — variadas
  static const _confirmations = [
    'Ok, I know what you mean! Let\'s continue.',
    'Got it! That makes much more sense now.',
    'Perfect, now I understood you clearly!',
    'Exactly! Well done. Let\'s move on.',
    'Great correction! I\'m glad we cleared that up.',
  ];

  int _responseIndex = 0;
  int _correctionIndex = 0;
  int _confirmationIndex = 0;

  @override
  Future<AiTurn> sendTurn({
    required String userUtterance,
    required StudentProfile profile,
    required SessionConfig config,
    bool isRetryAfterCorrection = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    // Após correção, confirma e segue
    if (isRetryAfterCorrection) {
      final confirmation = _confirmations[_confirmationIndex % _confirmations.length];
      _confirmationIndex++;
      return AiTurn(text: confirmation);
    }

    // ~30% de chance de erro por turno
    final hasError = _random.nextDouble() < 0.3;

    if (hasError) {
      final c = _corrections[_correctionIndex % _corrections.length];
      _correctionIndex++;
      return AiTurn(
        text: c.reaction,
        correctionReaction: c.reaction,
        instructionPt: c.instruction,
        correction: Correction(
          type: c.type,
          originalUtterance: userUtterance,
          correctForm: c.correctForm,
        ),
      );
    }

    final text = _normalResponses[_responseIndex % _normalResponses.length];
    _responseIndex++;
    return AiTurn(text: text);
  }
}
