import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'stt_service.dart';

/// STT usando o reconhecimento de fala do próprio aparelho (gratuito).
class DeviceSttService implements SttService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  // Resultado da escuta em andamento. Fica null quando ninguém está ouvindo.
  Completer<SttResult>? _pending;

  /// Motivo da última falha, para exibir em debug. Null se não houve erro.
  @override
  String? lastError;

  @override
  String get engineName => kIsWeb ? 'Navegador' : 'Aparelho';

  @override
  String? get debugInfo => null;

  // Escuta em um idioma só: não há o que transcrever de novo.
  @override
  Future<SttResult?> retranscribe({required String localeId}) async => null;

  static const _empty = SttResult.empty;

  @override
  Future<SttResult> recognize({required String localeId}) async {
    lastError = null;
    if (!await _ensureInitialized()) {
      lastError = 'reconhecimento indisponível ou microfone negado';
      return _empty;
    }

    final completer = Completer<SttResult>();
    _pending = completer;
    _pauseShortened = false;

    // Segurança: se nenhum aviso (resultado, erro ou fim) chegar a tempo,
    // cancela a escuta e devolve vazio, para a aula nunca travar em "Ouvindo".
    final safety = Timer(_listenFor + _safetyMargin, () {
      if (completer.isCompleted) return;
      lastError = 'tempo esgotado';
      _finish(_empty);
      _speech.cancel();
    });
    completer.future.whenComplete(safety.cancel);

    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: _listenFor, // tempo máximo ouvindo
        pauseFor: _initialPause, // silêncio aceito antes de começar a falar
        // Necessário para o modo contínuo no navegador e para o pauseFor
        // saber que o aluno ainda fala. Os parciais são ignorados em _onResult.
        partialResults: true,
        cancelOnError: true,
      ),
    );

    return completer.future;
  }

  static const _listenFor = Duration(seconds: 30);
  static const _safetyMargin = Duration(seconds: 5);

  // Silêncio que encerra a escuta: maior antes de o aluno começar a falar
  // (tempo para pensar), menor depois (para a conversa fluir).
  static const _initialPause = Duration(seconds: 5);
  // 3 s: com 1,5 s, pausas para pensar cortavam respostas longas.
  static const _speechPause = Duration(seconds: 3);

  // Se o tempo de silêncio já foi reduzido nesta escuta.
  bool _pauseShortened = false;

  @override
  Future<void> cancel() async {
    await _speech.cancel();
    _finish(_empty);
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: _onError,
      onStatus: _onStatus,
    );
    return _initialized;
  }

  void _onResult(SpeechRecognitionResult result) {
    // Na primeira palavra reconhecida, encurta o silêncio que encerra a fala.
    if (!_pauseShortened && result.recognizedWords.trim().isNotEmpty) {
      _pauseShortened = true;
      _speech.changePauseFor(_speechPause);
    }
    if (!result.finalResult) return;
    final confidence = result.hasConfidenceRating ? result.confidence : 1.0;
    _finish(SttResult(transcript: result.recognizedWords, confidence: confidence));
  }

  // Erros (ex.: não entendeu nada) devolvem texto vazio com confiança 0.
  void _onError(SpeechRecognitionError error) {
    lastError = error.errorMsg;
    _finish(_empty);
  }

  // Fim da escuta. No Android chega 'done'; no navegador só 'notListening'.
  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus) {
      _finish(_empty);
    } else if (status == SpeechToText.notListeningStatus) {
      // O texto reconhecido pode chegar logo depois deste aviso; espera um
      // pouco antes de concluir que não houve fala.
      final pending = _pending;
      if (pending == null) return;
      Timer(_resultGrace, () {
        if (_pending != pending || pending.isCompleted) return;
        lastError ??= 'escuta encerrada sem fala';
        _finish(_empty);
      });
    }
  }

  static const _resultGrace = Duration(seconds: 2);

  // Entrega o resultado uma única vez por escuta.
  void _finish(SttResult result) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    _pending = null;
    pending.complete(result);
  }
}
