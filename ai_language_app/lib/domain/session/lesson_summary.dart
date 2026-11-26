/// Resumo de uma aula, mostrado e falado no fim.
class LessonSummary {
  /// Tempo de aula, sem as pausas.
  final Duration duration;

  /// Quantas vezes o aluno falou (respostas e pedidos de ajuda).
  final int answers;

  /// Formas corretas das frases corrigidas, no idioma da aula.
  final List<String> corrections;

  /// Palavras do idioma da aula que o aluno pediu para explicar.
  final List<String> words;

  const LessonSummary({
    required this.duration,
    required this.answers,
    required this.corrections,
    required this.words,
  });

  /// Sem nenhuma fala do aluno: não há o que resumir.
  bool get isEmpty => answers == 0;

  /// Tempo para a tela (ex.: "12 min", "menos de 1 min").
  String get durationLabel =>
      duration.inSeconds < 60 ? 'menos de 1 min' : '${_minutes(duration)} min';

  /// Texto falado no idioma nativo. As frases e palavras do idioma da aula vêm
  /// entre chaves, para serem faladas com a voz desse idioma.
  String spokenText() {
    final minutes = _minutes(duration);
    final time = duration.inSeconds < 60
        ? 'menos de um minuto'
        : minutes == 1
            ? '1 minuto'
            : '$minutes minutos';
    final times = answers == 1 ? '1 vez' : '$answers vezes';
    final b = StringBuffer('Resumo da aula: você praticou $time e falou $times. ');

    if (corrections.isEmpty) {
      b.write('Você não teve correções hoje. ');
    } else {
      b.write('Para revisar: ${_join(corrections.map((c) => '{$c}'))}. ');
    }
    if (words.isNotEmpty) {
      b.write('Palavras novas: ${_join(words.map((w) => '{$w}'))}. ');
    }
    b.write('Bom trabalho!');
    return b.toString();
  }

  static int _minutes(Duration d) => (d.inSeconds / 60).round();

  static String _join(Iterable<String> items) {
    final list = items.toList();
    if (list.length <= 1) return list.join();
    return '${list.sublist(0, list.length - 1).join(', ')} e ${list.last}';
  }
}

/// Registra o que acontece na aula para montar o resumo no fim.
class LessonTracker {
  // Limites do resumo: curto, para ser falado.
  static const maxCorrections = 3;
  static const maxWords = 5;

  DateTime? _start;
  DateTime? _pausedAt;
  Duration _paused = Duration.zero;
  int _answers = 0;
  final List<String> _corrections = [];
  final List<String> _words = [];

  void start(DateTime now) => _start ??= now;

  void pause(DateTime now) => _pausedAt ??= now;

  void resume(DateTime now) {
    final pausedAt = _pausedAt;
    if (pausedAt == null) return;
    _paused += now.difference(pausedAt);
    _pausedAt = null;
  }

  void addAnswer() => _answers++;

  void addCorrection(String correctForm) {
    final c = correctForm.trim();
    if (c.isEmpty) return;
    if (_corrections.any((x) => x.toLowerCase() == c.toLowerCase())) return;
    _corrections.add(c);
  }

  /// Palavras explicadas numa ajuda. Ignora trechos longos (frases inteiras).
  void addWords(Iterable<String> words) {
    for (final w in words.map((w) => w.trim())) {
      if (w.isEmpty || w.split(RegExp(r'\s+')).length > 4) continue;
      if (_words.any((x) => x.toLowerCase() == w.toLowerCase())) continue;
      _words.add(w);
    }
  }

  LessonSummary summary(DateTime now) {
    resume(now);
    final start = _start ?? now;
    var duration = now.difference(start) - _paused;
    if (duration.isNegative) duration = Duration.zero;
    return LessonSummary(
      duration: duration,
      answers: _answers,
      // As mais recentes são as mais úteis para revisar.
      corrections: _corrections.reversed.take(maxCorrections).toList(),
      words: _words.reversed.take(maxWords).toList(),
    );
  }
}
