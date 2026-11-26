import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/session_config.dart';
import '../../domain/models/student_profile.dart';
import 'conversation_prompt.dart';
import 'conversation_service.dart';

/// Conversa com IA pelo Groq (nível gratuito, uso pessoal).
///
/// A chave vem do comando de execução:
///   flutter run ... --dart-define=GROQ_API_KEY=$env:GROQ_API_KEY
class GroqConversationService implements ConversationService, LlmDebugInfo {
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  // Em ordem de preferência; se um falhar por sobrecarga ou limite, usa o próximo.
  static const _models = ['openai/gpt-oss-120b', 'openai/gpt-oss-20b'];
  static const _timeout = Duration(seconds: 10);

  /// True quando a chave foi informada no comando de execução.
  static bool get isConfigured => _apiKey.isNotEmpty;

  final http.Client _client = http.Client();
  final ConversationHistory _history = ConversationHistory();

  @override
  String get providerName => 'Groq';
  @override
  String? lastModel;
  @override
  Duration? lastDuration;
  @override
  String? lastError;

  @override
  Future<AiTurn> startConversation({
    required StudentProfile profile,
    required SessionConfig config,
  }) async {
    final turn = await _turn(openingMessage(config), '', profile, config);
    // Sem resposta válida da IA: abertura fixa no idioma da aula.
    return lastError != null || turn.hasCorrection
        ? fallbackOpening(profile.targetLanguage)
        : turn;
  }

  @override
  Future<AiTurn> sendTurn({
    required String userUtterance,
    required StudentProfile profile,
    required SessionConfig config,
    bool isRetryAfterCorrection = false,
  }) =>
      _turn(
          markUtterance(userUtterance, isRetry: isRetryAfterCorrection),
          userUtterance, profile, config);

  Future<AiTurn> _turn(String message, String userUtterance,
      StudentProfile profile, SessionConfig config) async {
    lastError = null;
    lastModel = null;
    final language = profile.targetLanguage;

    final messages = [
      {'role': 'system', 'content': conversationInstructions(profile, config)},
      for (final e in _history.exchanges) ...[
        {'role': 'user', 'content': e.user},
        {'role': 'assistant', 'content': e.model},
      ],
      {'role': 'user', 'content': message},
    ];

    final watch = Stopwatch()..start();
    try {
      for (final model in _models) {
        final rawJson = await _tryModel(model, messages);
        if (rawJson == null) continue; // falha temporária: tenta o próximo

        final AiTurn turn;
        try {
          turn = turnFromJson(
              jsonDecode(rawJson) as Map<String, dynamic>, userUtterance, language);
        } catch (_) {
          lastError = 'resposta em formato inesperado ($model)';
          continue;
        }

        lastModel = model;
        lastError = null;
        _history.add(message, rawJson);
        return turn;
      }
    } catch (e) {
      lastError = e.toString();
    } finally {
      lastDuration = watch.elapsed;
    }

    lastError ??= 'nenhum modelo respondeu';
    return AiTurn(text: fallbackPhrase(language));
  }

  /// Devolve o JSON da resposta, ou null se o modelo estiver indisponível
  /// no momento (sobrecarga, limite, fora do ar). Erros definitivos, como
  /// chave inválida, lançam exceção.
  Future<String?> _tryModel(
      String model, List<Map<String, String>> messages) async {
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 800,
      'response_format': {'type': 'json_object'},
      'reasoning_effort': 'low',
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: body,
          )
          .timeout(_timeout);
    } on TimeoutException {
      lastError = 'tempo esgotado ($model)';
      return null;
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] as String? ?? '';
    }

    final code = response.statusCode;
    if (code == 429 || code == 404 || code >= 500) {
      lastError = 'HTTP $code ($model)';
      return null;
    }
    throw Exception('HTTP $code');
  }
}
