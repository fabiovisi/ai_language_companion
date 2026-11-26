import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/session_config.dart';
import '../../domain/models/student_profile.dart';
import 'conversation_prompt.dart';
import 'conversation_service.dart';

/// Conversa com a IA do Google Gemini (nível gratuito, uso pessoal).
///
/// A chave vem do comando de execução:
///   flutter run ... --dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY
class GeminiConversationService implements ConversationService, LlmDebugInfo {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-flash-lite-latest';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// True quando a chave foi informada no comando de execução.
  static bool get isConfigured => _apiKey.isNotEmpty;

  final http.Client _client = http.Client();
  final ConversationHistory _history = ConversationHistory();

  @override
  String get providerName => 'Gemini';
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

    final contents = [
      for (final e in _history.exchanges) ...[
        _content('user', e.user),
        _content('model', e.model),
      ],
      _content('user', message),
    ];

    final watch = Stopwatch()..start();
    final String rawJson;
    try {
      rawJson = await _generate(
          conversationInstructions(profile, config, memory: memory), contents);
      lastModel = _model;
    } catch (e) {
      lastError = e.toString();
      return AiTurn(text: fallbackPhrase(profile.targetLanguage));
    } finally {
      lastDuration = watch.elapsed;
    }

    final AiTurn turn;
    try {
      turn = turnFromJson(jsonDecode(rawJson) as Map<String, dynamic>,
          userUtterance, profile.targetLanguage);
    } catch (e) {
      lastError = 'resposta em formato inesperado';
      return AiTurn(text: fallbackPhrase(profile.targetLanguage));
    }

    _history.add(message, rawJson);
    return turn;
  }

  @override
  String? memory;

  @override
  Future<String?> updateMemory({
    required String? previous,
    required StudentProfile profile,
  }) async {
    final exchanges = _history.exchanges;
    if (exchanges.isEmpty) return null;

    // Roda em segundo plano: não altera o debug da conversa.
    final error = lastError, model = lastModel, duration = lastDuration;
    try {
      final raw = await _generate(
        memoryUpdateInstructions(profile.targetLanguage),
        [_content('user', memoryUpdateMessage(previous, exchanges))],
        schema: _memorySchema,
      );
      return memoryFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    } finally {
      lastError = error;
      lastModel = model;
      lastDuration = duration;
    }
  }

  static const _memorySchema = {
    'type': 'OBJECT',
    'properties': {
      'memory': {'type': 'STRING'},
    },
    'required': ['memory'],
  };

  Future<String> _generate(
      String instructions, List<Map<String, dynamic>> contents,
      {Map<String, Object> schema = _responseSchema}) async {
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': instructions}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
        'responseMimeType': 'application/json',
        'responseSchema': schema,
      },
    });

    // Uma nova tentativa em caso de sobrecarga ou falha temporária.
    for (var attempt = 1; attempt <= 2; attempt++) {
      final http.Response response;
      try {
        response = await _client
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _apiKey,
              },
              body: body,
            )
            .timeout(const Duration(seconds: 20));
      } on TimeoutException {
        if (attempt == 2) throw Exception('tempo esgotado');
        continue;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final parts = data['candidates'][0]['content']['parts'] as List;
        return parts.map((p) => p['text'] ?? '').join();
      }

      final temporary = response.statusCode == 429 || response.statusCode >= 500;
      if (!temporary || attempt == 2) {
        throw Exception('HTTP ${response.statusCode}');
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    throw Exception('falha desconhecida');
  }

  // Formato fixo da resposta da IA.
  static const _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'feedback': {'type': 'STRING'},
      'question': {'type': 'STRING'},
      'help': {'type': 'STRING'},
      'slower': {'type': 'BOOLEAN'},
      'hasError': {'type': 'BOOLEAN'},
      'reaction': {'type': 'STRING'},
      'instruction': {'type': 'STRING'},
      'errorType': {
        'type': 'STRING',
        'enum': ['grammar', 'vocabulary', 'contextualUsage'],
      },
      'correctForm': {'type': 'STRING'},
    },
    'required': ['hasError'],
  };

  static Map<String, dynamic> _content(String role, String text) => {
        'role': role,
        'parts': [
          {'text': text}
        ],
      };
}
