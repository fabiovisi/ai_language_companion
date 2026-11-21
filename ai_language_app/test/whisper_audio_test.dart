import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/core/services/whisper_audio.dart';

const _rate = 16000;

/// Gera [seconds] de áudio PCM 16 bits com ruído de fundo ([noise] é a
/// amplitude máxima do ruído). Com [speech], acrescenta "sílabas": tom de
/// 200 Hz por 200 ms e pausa de 60 ms, como numa fala real. Com [tone], um
/// tom contínuo.
Uint8List _gen(double seconds, Random random,
    {bool speech = false, bool tone = false, double noise = 60}) {
  final n = (seconds * _rate).round();
  final data = ByteData(n * 2);
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    final loud = tone || (speech && (t % 0.26) < 0.2);
    final signal = loud ? 8000 * sin(2 * pi * 200 * t) : 0.0;
    final bg = (random.nextDouble() - 0.5) * 2 * noise;
    data.setInt16(
        i * 2, (signal + bg).round().clamp(-32768, 32767), Endian.little);
  }
  return data.buffer.asUint8List();
}

Uint8List _silence(double s, Random r) => _gen(s, r);
Uint8List _speech(double s, Random r) => _gen(s, r, speech: true);

/// Alimenta o detector em pedaços de 100 ms e devolve o instante em que ele
/// pediu para encerrar (ou null, se não pediu).
Duration? _feed(SpeechEndDetector d, Uint8List audio) {
  const chunk = _rate ~/ 10 * 2;
  for (var i = 0; i < audio.length; i += chunk) {
    final end = min(i + chunk, audio.length);
    if (d.add(Uint8List.sublistView(audio, i, end))) return d.elapsed;
  }
  return null;
}

void main() {
  group('SpeechEndDetector', () {
    test('só silêncio: encerra em 5 s, sem fala', () {
      final d = SpeechEndDetector();
      final stoppedAt = _feed(d, _silence(10, Random(1)));

      expect(stoppedAt, isNotNull);
      expect(stoppedAt!.inMilliseconds, closeTo(5000, 150));
      expect(d.heardSpeech, isFalse);
    });

    test('fala e silêncio: encerra 3 s depois do fim da fala', () {
      final d = SpeechEndDetector();
      final r = Random(2);
      final audio = (BytesBuilder()
            ..add(_silence(1, r))
            ..add(_speech(2, r))
            ..add(_silence(6, r)))
          .takeBytes();
      final stoppedAt = _feed(d, audio);

      expect(d.heardSpeech, isTrue);
      expect(stoppedAt!.inMilliseconds, closeTo(6000, 150)); // 1 + 2 + 3 s
    });

    test('fala logo no início é detectada', () {
      final d = SpeechEndDetector();
      final r = Random(6);
      final audio =
          (BytesBuilder()..add(_speech(2, r))..add(_silence(6, r))).takeBytes();
      final stoppedAt = _feed(d, audio);

      expect(d.heardSpeech, isTrue);
      expect(stoppedAt!.inMilliseconds, closeTo(5000, 150)); // 2 + 3 s
    });

    test('pausa de 2 s no meio da fala não encerra', () {
      final d = SpeechEndDetector();
      final r = Random(3);
      final audio = (BytesBuilder()
            ..add(_speech(1, r))
            ..add(_silence(2, r)) // pausa para pensar
            ..add(_speech(1, r))
            ..add(_silence(5, r)))
          .takeBytes();
      final stoppedAt = _feed(d, audio);

      expect(stoppedAt!.inMilliseconds, closeTo(7000, 150)); // 1+2+1+3 s
    });

    test('estalo curto não conta como fala', () {
      final d = SpeechEndDetector();
      final r = Random(4);
      final audio = (BytesBuilder()
            ..add(_silence(0.5, r))
            ..add(_gen(0.02, r, tone: true)) // 20 ms
            ..add(_silence(6, r)))
          .takeBytes();
      _feed(d, audio);

      expect(d.heardSpeech, isFalse);
    });

    test('ruídos curtos e esparsos não contam como fala', () {
      final d = SpeechEndDetector();
      final r = Random(8);
      final audio = (BytesBuilder()
            ..add(_silence(0.5, r))
            ..add(_gen(0.1, r, tone: true)) // 100 ms
            ..add(_silence(1, r))
            ..add(_gen(0.1, r, tone: true)) // 100 ms (total 0,2 s)
            ..add(_silence(8, r)))
          .takeBytes();
      final stoppedAt = _feed(d, audio);

      expect(d.heardSpeech, isFalse);
      expect(stoppedAt, isNotNull);
    });

    test('som perto do fim dos 5 s iniciais não corta a fala', () {
      final d = SpeechEndDetector();
      final r = Random(9);
      final audio = (BytesBuilder()
            ..add(_silence(4.8, r))
            ..add(_speech(2, r)) // começa aos 4,8 s
            ..add(_silence(6, r)))
          .takeBytes();
      final stoppedAt = _feed(d, audio);

      expect(d.heardSpeech, isTrue);
      expect(stoppedAt!.inMilliseconds, closeTo(9800, 200)); // 4,8 + 2 + 3 s
    });

    test('ruído constante não prende a escuta até o limite', () {
      final d = SpeechEndDetector();
      final stoppedAt = _feed(d, _gen(25, Random(7), noise: 1400));

      expect(stoppedAt, isNotNull);
      expect(stoppedAt!.inSeconds, lessThan(12));
    });

    test('limite de 30 s', () {
      final d = SpeechEndDetector();
      final stoppedAt = _feed(d, _speech(35, Random(5)));

      expect(stoppedAt!.inMilliseconds, closeTo(30000, 150));
    });
  });

  test('WAV: cabeçalho correto', () {
    final pcm = Uint8List(3200); // 100 ms
    final wav = wavFromPcm16(pcm);
    final h = ByteData.sublistView(wav);

    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(h.getUint32(4, Endian.little), 36 + 3200);
    expect(h.getUint16(22, Endian.little), 1); // mono
    expect(h.getUint32(24, Endian.little), 16000);
    expect(h.getUint16(34, Endian.little), 16); // 16 bits
    expect(h.getUint32(40, Endian.little), 3200);
    expect(wav.length, 44 + 3200);
  });

  group('resposta do Whisper', () {
    test('texto, idioma e confiança', () {
      final r = sttResultFromWhisperJson({
        'language': 'Portuguese',
        'text': ' Essa frase tem palavras que não conheço.',
        'segments': [
          {
            'text': ' Essa frase tem palavras que não conheço.',
            'avg_logprob': -0.1,
            'no_speech_prob': 0.01,
          },
        ],
      });

      expect(r.transcript, 'Essa frase tem palavras que não conheço.');
      expect(r.language, 'portuguese');
      expect(r.confidence, closeTo(0.905, 0.01)); // e^-0.1
    });

    test('trecho provavelmente silencioso é descartado', () {
      final r = sttResultFromWhisperJson({
        'language': 'English',
        'text': ' Thank you.',
        'segments': [
          {'text': ' Thank you.', 'avg_logprob': -0.8, 'no_speech_prob': 0.9},
        ],
      });

      expect(r.transcript, isEmpty);
    });

    test('frase inventada em áudio sem fala é descartada', () {
      final r = sttResultFromWhisperJson({
        'language': 'English',
        'text': " I'm going to go to the next video.",
        'segments': [
          {
            'text': " I'm going to go to the next video.",
            'avg_logprob': -0.3,
            'no_speech_prob': 0.1,
          },
        ],
      });

      expect(r.transcript, isEmpty);
    });

    test('"Thank you." curto e legítimo é mantido', () {
      final r = sttResultFromWhisperJson({
        'language': 'English',
        'text': ' Thank you.',
        'segments': [
          {'text': ' Thank you.', 'avg_logprob': -0.2, 'no_speech_prob': 0.05},
        ],
      });

      expect(r.transcript, 'Thank you.');
    });

    test('trecho com confiança muito baixa é descartado', () {
      final r = sttResultFromWhisperJson({
        'language': 'English',
        'text': ' blah',
        'segments': [
          {'text': ' blah', 'avg_logprob': -1.5, 'no_speech_prob': 0.1},
        ],
      });

      expect(r.transcript, isEmpty);
    });

    test('sem trechos: usa o texto', () {
      final r = sttResultFromWhisperJson({'language': 'english', 'text': 'Hi'});

      expect(r.transcript, 'Hi');
      expect(r.confidence, 1.0);
    });
  });
}
