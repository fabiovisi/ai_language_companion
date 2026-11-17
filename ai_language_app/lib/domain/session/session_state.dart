enum SessionState {
  // Fluxo principal (seção 4 da spec)
  preparing,
  ready,
  aiSpeaking,
  listening,
  processing,
  correcting,
  interval,
  paused,
  ended,

  // Estados de falha (seção 13 da spec)
  noPermission,
  noConnectivity,
  lowConfidenceRetry,
  processingTimeout,
  ttsUnavailable,
  serviceUnavailable,
  interrupted,        // chamada, navegação ou sistema
  reconnecting,
}
