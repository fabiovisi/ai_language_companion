import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/services/conversation_prompt.dart';
import 'package:ai_language_app/domain/models/session_config.dart';

void main() {
  const travel = SessionConfig(
    topic: 'Viagem',
    mode: SessionMode.continuous,
    speechRate: SpeechRate.normal,
  );
  const free = SessionConfig(
    mode: SessionMode.continuous,
    speechRate: SpeechRate.normal,
  );

  test('período do dia', () {
    expect(timeOfDay(DateTime(2026, 1, 1, 8)), 'morning');
    expect(timeOfDay(DateTime(2026, 1, 1, 14)), 'afternoon');
    expect(timeOfDay(DateTime(2026, 1, 1, 21)), 'evening');
    expect(timeOfDay(DateTime(2026, 1, 1, 3)), 'evening');
  });

  test('pedido de abertura traz hora do dia e um ângulo do tema', () {
    final message =
        openingMessage(travel, now: DateTime(2026, 1, 1, 8), random: Random(1));

    expect(message, startsWith('[START]'));
    expect(message, contains('morning'));
    expect(message, contains('Angle for the first question:'));
  });

  test('ângulos variam entre sessões', () {
    final random = Random(42);
    final messages = {
      for (var i = 0; i < 20; i++) openingMessage(free, random: random),
    };

    expect(messages.length, greaterThan(1));
  });

  test('reserva no idioma da aula, com saudação e pergunta', () {
    final turn =
        fallbackOpening('Espanhol', now: DateTime(2026, 1, 1, 21), random: Random(0));

    expect(turn.text, contains('Buenas noches'));
    expect(turn.followUp, startsWith('¿'));
  });

  test('idioma desconhecido usa inglês', () {
    final turn = fallbackOpening('Klingon', now: DateTime(2026, 1, 1, 8));

    expect(turn.text, contains('Good morning'));
  });
}
