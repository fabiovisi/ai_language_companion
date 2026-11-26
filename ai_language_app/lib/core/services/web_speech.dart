// Voz do Chrome usada diretamente, sem o flutter_tts.
//
// Motivo: no navegador, o flutter_tts guarda se está "falando" e só aceita
// uma frase nova quando acha que está parado. Quando o aviso de fim da frase
// se perde (comum com as vozes do Google, que dependem da internet), ele
// ignora todas as frases seguintes, em silêncio, até recarregar a página.
// Aqui cada frase é criada do zero e tem um prazo, sem estado que fique preso.

export 'web_speech_outcome.dart';
export 'web_speech_stub.dart' if (dart.library.js_interop) 'web_speech_web.dart';
