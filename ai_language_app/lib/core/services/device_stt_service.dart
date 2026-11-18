import 'dart:async';

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
  String? lastError;

  static const _empty = SttResult(transcript: '', confidence: 0.0);

  @override
  Future<SttResult> recognize({required String localeId}) async {
    lastError = null;
    if (!await _ensureInitialized()) {
      lastError = 'reconhecimento indisponível ou microfone negado';
      return _empty;
    }

    final completer = Completer<SttResult>();
    _pending = completer;

    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 30), // tempo máximo ouvindo
        pauseFor: const Duration(seconds: 3), // silêncio que encerra a fala
        partialResults: false, // só queremos o texto final
        cancelOnError: true,
      ),
    );

    return completer.future;
  }

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
    if (!result.finalResult) return;
    final confidence = result.hasConfidenceRating ? result.confidence : 1.0;
    _finish(SttResult(transcript: result.recognizedWords, confidence: confidence));
  }

  // Erros (ex.: não entendeu nada) devolvem texto vazio com confiança 0.
  void _onError(SpeechRecognitionError error) {
    lastError = error.errorMsg;
    _finish(_empty);
  }

  // Se a escuta terminar sem resultado final, devolve texto vazio.
  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus) _finish(_empty);
  }

  // Entrega o resultado uma única vez por escuta.
  void _finish(SttResult result) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    _pending = null;
    pending.complete(result);
  }
}
