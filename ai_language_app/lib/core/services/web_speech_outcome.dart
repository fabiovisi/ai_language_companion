/// Resultado de uma frase falada pelo navegador.
enum WebSpeakOutcome {
  completed, // terminou normalmente
  cancelled, // interrompida pelo app (pausa, encerrar, sair da tela)
  error, // o navegador avisou um erro
  timeout, // não terminou no prazo (provavelmente travou em silêncio)
}
