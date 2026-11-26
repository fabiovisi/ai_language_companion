import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/domain/session/lesson_summary.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 8, 0);

  test('tempo de aula sem as pausas', () {
    final tracker = LessonTracker()
      ..start(t0)
      ..pause(t0.add(const Duration(minutes: 5)))
      ..resume(t0.add(const Duration(minutes: 8)));
    final summary = tracker.summary(t0.add(const Duration(minutes: 15)));

    expect(summary.duration, const Duration(minutes: 12));
    expect(summary.durationLabel, '12 min');
  });

  test('pausa em andamento no fim também é descontada', () {
    final tracker = LessonTracker()
      ..start(t0)
      ..pause(t0.add(const Duration(minutes: 4)));

    expect(tracker.summary(t0.add(const Duration(minutes: 10))).duration,
        const Duration(minutes: 4));
  });

  test('correções e palavras sem repetição, mais recentes primeiro', () {
    final tracker = LessonTracker()
      ..start(t0)
      ..addCorrection('I went to the park.')
      ..addCorrection('i went to the park.') // repetida
      ..addCorrection('She has two brothers.')
      ..addWords(['commute', 'Commute', 'rush hour'])
      ..addWords(['Do you like your trip to work every day?']); // frase longa
    final s = tracker.summary(t0);

    expect(s.corrections, ['She has two brothers.', 'I went to the park.']);
    expect(s.words, ['rush hour', 'commute']);
  });

  test('limites do resumo', () {
    final tracker = LessonTracker()..start(t0);
    for (var i = 0; i < 6; i++) {
      tracker
        ..addCorrection('Sentence $i.')
        ..addWords(['word$i']);
    }
    final s = tracker.summary(t0);

    expect(s.corrections.length, LessonTracker.maxCorrections);
    expect(s.words.length, LessonTracker.maxWords);
  });

  test('texto falado: idioma da aula entre chaves', () {
    final tracker = LessonTracker()
      ..start(t0)
      ..addAnswer()
      ..addAnswer()
      ..addCorrection('I went to the park.')
      ..addWords(['commute', 'rush hour']);
    final text = tracker.summary(t0.add(const Duration(minutes: 1))).spokenText();

    expect(text, contains('1 minuto'));
    expect(text, contains('falou 2 vezes'));
    expect(text, contains('{I went to the park.}'));
    expect(text, contains('{rush hour} e {commute}'));
  });

  test('sem correções; menos de um minuto', () {
    final tracker = LessonTracker()
      ..start(t0)
      ..addAnswer();
    final s = tracker.summary(t0.add(const Duration(seconds: 30)));

    expect(s.durationLabel, 'menos de 1 min');
    expect(s.spokenText(), contains('menos de um minuto'));
    expect(s.spokenText(), contains('não teve correções'));
  });

  test('sem nenhuma fala: resumo vazio', () {
    expect((LessonTracker()..start(t0)).summary(t0).isEmpty, isTrue);
  });
}
