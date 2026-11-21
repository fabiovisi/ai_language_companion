// Peças do reconhecimento com Whisper que não dependem do microfone nem da
// rede (testáveis): detector de fim de fala, montagem do WAV e leitura da
// resposta do Whisper.

import 'dart:math';
import 'dart:typed_data';

import 'stt_service.dart';

/// Decide quando a fala terminou, a partir do áudio PCM 16 bits, mono,
/// little-endian. Mede o volume em janelas de 20 ms e acompanha o ruído de
/// fundo, para funcionar com microfones e ambientes diferentes.
///
/// Regras (as mesmas do reconhecimento do aparelho):
/// - sem fala por [initialSilence] desde o início: encerra sem fala;
/// - depois de começar a falar, [endSilence] de silêncio: encerra;
/// - no máximo [maxDuration].
class SpeechEndDetector {
  SpeechEndDetector({
    this.sampleRate = 16000,
    this.initialSilence = const Duration(seconds: 5),
    this.endSilence = const Duration(seconds: 3),
    this.maxDuration = const Duration(seconds: 30),
  }) : _frameSamples = sampleRate ~/ 50; // 20 ms

  final int sampleRate;
  final Duration initialSilence;
  final Duration endSilence;
  final Duration maxDuration;

  // Volume mínimo para contar como fala (escala de 0 a 32768): evita que o
  // silêncio absoluto de um microfone muito limpo vire "fala".
  static const _minSpeechLevel = 400.0;
  // A fala precisa ficar acima do ruído de fundo por este fator.
  static const _speechOverNoise = 3.0;
  // Janelas seguidas acima do limite para considerar que a fala começou
  // (60 ms): ignora estalos curtos.
  static const _framesToStart = 3;

  // Ruído de fundo inicial: começa baixo (ambiente silencioso), para que a
  // fala seja detectada mesmo se o aluno começar a falar logo no início.
  static const _initialNoiseFloor = 100.0;
  // Quanto o ruído de fundo sobe a cada janela de 20 ms (~7 s para se
  // adaptar a um ruído constante, como o do carro).
  static const _noiseRise = 0.003;

  // Som acima do ruído, somando os trechos, para considerar que houve fala
  // (e enviar ao Whisper). Ruídos curtos e esparsos não chegam a isso.
  static const _minSpeech = Duration(milliseconds: 300);

  final int _frameSamples;
  final List<int> _pending = []; // amostras que ainda não fecharam uma janela
  int _samples = 0;
  int _lastSpeechSample = -1;
  int _loudFrames = 0; // janelas seguidas acima do limite
  int _speechSamples = 0; // total de som que contou como fala
  double _noiseFloor = _initialNoiseFloor;
  double _peakLevel = 0;

  /// Se houve fala suficiente (ao menos 0,3 s de som acima do ruído).
  bool get heardSpeech =>
      _speechSamples * 1000000 ~/ sampleRate >= _minSpeech.inMicroseconds;

  /// Medidas da escuta, para o debug: ruído de fundo, pico e tempo de fala.
  String get stats {
    final speech = (_speechSamples / sampleRate).toStringAsFixed(1);
    return 'ruído ${_noiseFloor.round()} · pico ${_peakLevel.round()} · '
        'fala ${speech.replaceAll('.', ',')} s';
  }

  /// Duração do áudio processado até agora.
  Duration get elapsed =>
      Duration(microseconds: _samples * 1000000 ~/ sampleRate);

  /// Processa mais um trecho do áudio. Devolve true quando a escuta deve
  /// terminar.
  bool add(Uint8List chunk) {
    final data = ByteData.sublistView(chunk);
    for (var i = 0; i + 1 < chunk.length; i += 2) {
      _pending.add(data.getInt16(i, Endian.little));
      if (_pending.length == _frameSamples) {
        _processFrame();
        _pending.clear();
      }
    }
    return _shouldStop();
  }

  void _processFrame() {
    var sum = 0.0;
    for (final s in _pending) {
      sum += s * s;
    }
    final level = sqrt(sum / _pending.length);
    _samples += _pending.length;

    final threshold = max(_minSpeechLevel, _noiseFloor * _speechOverNoise);
    _peakLevel = max(_peakLevel, level);

    if (level > threshold) {
      _loudFrames++;
      // Só conta a partir de 3 janelas seguidas (60 ms): ignora estalos.
      if (_loudFrames == _framesToStart) {
        _speechSamples += _frameSamples * _framesToStart;
        _lastSpeechSample = _samples;
      } else if (_loudFrames > _framesToStart) {
        _speechSamples += _frameSamples;
        _lastSpeechSample = _samples;
      }
    } else {
      _loudFrames = 0;
    }

    // Ruído de fundo: desce na hora (pausas entre as palavras, silêncio) e
    // sobe devagar (um ruído constante deixa de contar como fala).
    _noiseFloor = level < _noiseFloor
        ? level
        : _noiseFloor + (level - _noiseFloor) * _noiseRise;
  }

  bool _shouldStop() {
    if (elapsed >= maxDuration) return true;
    final silence = _lastSpeechSample < 0
        ? elapsed
        : Duration(
            microseconds:
                (_samples - _lastSpeechSample) * 1000000 ~/ sampleRate);
    // Antes de haver fala suficiente: espera os 5 s iniciais; se um som
    // começou perto do fim desse prazo, espera também o silêncio depois dele.
    if (!heardSpeech) return elapsed >= initialSilence && silence >= endSilence;
    return silence >= endSilence;
  }
}

/// Envolve o áudio PCM 16 bits mono em um arquivo WAV.
Uint8List wavFromPcm16(Uint8List pcm, {int sampleRate = 16000}) {
  const channels = 1;
  const bytesPerSample = 2;
  final header = ByteData(44);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // tamanho do bloco fmt
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(
      28, sampleRate * channels * bytesPerSample, Endian.little); // bytes/s
  header.setUint16(32, channels * bytesPerSample, Endian.little);
  header.setUint16(34, bytesPerSample * 8, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);

  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm))
      .takeBytes();
}

// Frases que o Whisper costuma "inventar" em áudio com ruído e sem fala,
// vindas dos vídeos usados no treino dele. Frases curtas e legítimas numa
// conversa ("Thank you.", "Obrigado.") ficam de fora de propósito.
const _hallucinations = [
  'thanks for watching',
  'thank you for watching',
  'next video',
  'subscribe',
  'obrigado por assistir',
  'obrigada por assistir',
  'inscreva-se',
  'legendas pela comunidade',
  'amara.org',
];

/// True quando o texto parece uma dessas frases inventadas.
bool isLikelyHallucination(String text) {
  final t = text.toLowerCase();
  return _hallucinations.any(t.contains);
}

/// Lê a resposta do Whisper (formato verbose_json).
///
/// - confiança: média da probabilidade das palavras de cada trecho;
/// - trechos que o Whisper considera provavelmente silêncio são descartados,
///   porque em áudio quase vazio ele às vezes "inventa" frases como
///   "Thank you." ou "Obrigado.".
SttResult sttResultFromWhisperJson(Map<String, dynamic> data) {
  final language = (data['language'] as String?)?.trim().toLowerCase();
  final segments = (data['segments'] as List?)?.whereType<Map>().toList();

  if (segments == null || segments.isEmpty) {
    final text = (data['text'] as String? ?? '').trim();
    if (isLikelyHallucination(text)) return SttResult.empty;
    return SttResult(
        transcript: text,
        confidence: text.isEmpty ? 0.0 : 1.0,
        language: language);
  }

  // Descarta trechos que o Whisper considera provável silêncio ou que ele
  // transcreveu com confiança muito baixa.
  final kept = segments.where((s) {
    final noSpeech = (s['no_speech_prob'] as num?)?.toDouble() ?? 0.0;
    final logProb = (s['avg_logprob'] as num?)?.toDouble() ?? 0.0;
    return noSpeech < 0.4 && logProb > -1.0;
  }).toList();
  if (kept.isEmpty) return SttResult.empty;

  final text =
      kept.map((s) => (s['text'] as String? ?? '').trim()).join(' ').trim();
  if (isLikelyHallucination(text)) return SttResult.empty;
  final probs = kept
      .map((s) => exp((s['avg_logprob'] as num?)?.toDouble() ?? 0.0))
      .toList();
  final confidence =
      (probs.reduce((a, b) => a + b) / probs.length).clamp(0.0, 1.0);

  return SttResult(transcript: text, confidence: confidence, language: language);
}
