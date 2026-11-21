/// Idioma nativo do aluno: usado nas instruções de correção (Iniciante a
/// Intermediário avançado) e nos pedidos de ajuda.
///
/// Fase de uso pessoal: fixo em português do Brasil, em um único lugar.
/// Na distribuição, vira a opção "Seu idioma" nas Configurações.
class NativeLanguage {
  /// Código para voz e reconhecimento (ex.: 'pt_BR').
  final String localeId;

  /// Nome usado nas instruções da IA.
  final String promptName;

  /// Nome que o Whisper devolve ao identificar o idioma (minúsculas).
  final String whisperName;

  const NativeLanguage({
    required this.localeId,
    required this.promptName,
    required this.whisperName,
  });
}

const nativeLanguage = NativeLanguage(
  localeId: 'pt_BR',
  promptName: 'Brazilian Portuguese (português do Brasil)',
  whisperName: 'portuguese',
);
