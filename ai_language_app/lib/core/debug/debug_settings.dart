import 'package:flutter/foundation.dart';

/// Mostrar informações de debug nas telas de conversa (confiança da fala,
/// IA em uso e barra de estados). Ligada nas Configurações e guardada no
/// aparelho junto com as outras escolhas (ver SettingsController).
///
/// Opção da fase de uso pessoal: remover ou esconder antes de publicar.
final showDebugInfo = ValueNotifier<bool>(false);
