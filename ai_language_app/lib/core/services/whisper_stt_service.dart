import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import 'stt_service.dart';
import 'whisper_audio.dart';

/// Reconhecimento de fala com o Whisper do Groq (nível gratuito, uso pessoal).
///
/// Identifica o idioma falado sozinho: o aluno pode falar no idioma da aula ou
/// no idioma nativo. O áudio fica só na memória e é descartado após o envio.
///
/// A chave é a mesma da IA de conversa:
///   flutter run ... --dart-define=GROQ_API_KEY=$env:GROQ_API_KEY
class WhisperSttService implements SttService {
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _endpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const _model = 'whisper-large-v3-turbo';
  static const _sampleRate = 16000;
  static const _requestTimeout = Duration(seconds: 15);

  /// True quando a chave foi informada no comando de execução.
  static bool get isConfigured => _apiKey.isNotEmpty;

  final AudioRecorder _recorder = AudioRecorder();
  final http.Client _client = http.Client();

  Completer<void>? _stopSignal;
  bool _cancelled = false;

  // Última fala, só na memória e só até a próxima escuta: permite transcrever
  // de novo com o idioma fixo (ver retranscribe).
  Uint8List? _lastWav;

  @override
  String get engineName => 'Whisper';

  @override
  String? lastError;

  @override
  String? debugInfo;

  @override
  Future<SttResult> recognize({required String localeId}) async {
    lastError = null;
    debugInfo = null;
    _cancelled = false;
    _lastWav = null; // descarta o áudio da fala anterior

    final bool allowed;
    try {
      allowed = await _recorder.hasPermission();
    } catch (_) {
      lastError = 'microfone indisponível';
      return SttResult.empty;
    }
    if (!allowed) {
      lastError = 'microfone negado';
      return SttResult.empty;
    }

    final pcm = await _record();
    if (pcm == null || _cancelled) return SttResult.empty;
    final wav = wavFromPcm16(pcm, sampleRate: _sampleRate);
    _lastWav = wav;
    return _transcribe(wav);
  }

  @override
  Future<SttResult?> retranscribe({required String localeId}) async {
    final wav = _lastWav;
    if (wav == null) return null;
    // Código de idioma do Whisper: 'en_US' → 'en'.
    return _transcribe(wav, language: localeId.split('_').first.toLowerCase());
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    _lastWav = null;
    final stop = _stopSignal;
    if (stop != null && !stop.isCompleted) stop.complete();
  }

  /// Grava até o fim da fala. Devolve o áudio, ou null se não houve fala
  /// (nesse caso nada é enviado, para poupar o limite gratuito).
  Future<Uint8List?> _record() async {
    final detector = SpeechEndDetector(sampleRate: _sampleRate);
    final audio = BytesBuilder(copy: false);
    final stop = Completer<void>();
    _stopSignal = stop;

    final Stream<Uint8List> stream;
    try {
      stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        // Desligado: no silêncio, o ganho automático amplifica o ruído de
        // fundo, que passava a contar como fala (e o Whisper inventava frases).
        autoGain: false,
      ));
    } catch (_) {
      lastError = 'falha ao abrir o microfone';
      return null;
    }

    final sub = stream.listen(
      (chunk) {
        audio.add(chunk);
        if (detector.add(chunk) && !stop.isCompleted) stop.complete();
      },
      onError: (_) {
        lastError = 'erro na gravação';
        if (!stop.isCompleted) stop.complete();
      },
      onDone: () {
        if (!stop.isCompleted) stop.complete();
      },
    );

    // Segurança: nunca grava além do máximo, mesmo se o áudio parar de chegar.
    await stop.future.timeout(
      detector.maxDuration + const Duration(seconds: 2),
      onTimeout: () {},
    );
    await sub.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    _stopSignal = null;

    debugInfo = detector.stats;
    if (_cancelled) return null;
    if (!detector.heardSpeech) {
      lastError ??= 'sem fala detectada';
      return null;
    }
    return audio.takeBytes();
  }

  /// [language]: idioma fixo (ex.: 'en'). Sem ele, o Whisper identifica o
  /// idioma sozinho (modo normal).
  Future<SttResult> _transcribe(Uint8List wav, {String? language}) async {
    // Uma nova tentativa em caso de sobrecarga ou falha temporária.
    for (var attempt = 1; attempt <= 2; attempt++) {
      final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = _model
        ..fields['response_format'] = 'verbose_json'
        ..fields['temperature'] = '0'
        // Sem idioma fixo (identifica sozinho) e sem dica de estilo: nos
        // testes, os dois faziam o Whisper traduzir o português.
        ..files.add(
            http.MultipartFile.fromBytes('file', wav, filename: 'speech.wav'));
      if (language != null) request.fields['language'] = language;

      final http.Response response;
      try {
        response = await http.Response.fromStream(
            await _client.send(request).timeout(_requestTimeout));
      } on TimeoutException {
        lastError = 'tempo esgotado';
        continue;
      } catch (_) {
        lastError = 'falha de rede';
        continue;
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          final result = sttResultFromWhisperJson(data);
          lastError = result.transcript.isEmpty ? 'sem fala detectada' : null;
          return result;
        } catch (_) {
          lastError = 'resposta em formato inesperado';
          return SttResult.empty;
        }
      }

      lastError = 'HTTP ${response.statusCode}';
      final temporary =
          response.statusCode == 429 || response.statusCode >= 500;
      if (!temporary) break;
      await Future.delayed(const Duration(seconds: 1));
    }
    return SttResult.empty;
  }
}
