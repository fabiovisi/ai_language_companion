# Resumo do Projeto — AI Language Companion (sessões a partir de 18/11/2026)

Use este arquivo como contexto ao iniciar uma nova conversa.

## Como trabalhamos
- Passos pequenos: antes de cada passo, explicar o que será feito e por quê; mostrar o resultado; só seguir após confirmação.
- Orientações de interface (console, sites) só com base em print ou descrição da tela. Prints: o usuário salva o arquivo e informa o caminho.
- Não fazer push, deletar ou mexer em configurações sem pedir.

## Visão geral
App Flutter de tutor de idiomas por voz com IA. Alvo final: Android Auto, Apple CarPlay e multimídia do BYD Song Pro. Desenvolvimento e testes no Chrome (agora) e tablet Android (depois).

## Decisão de fase: uso pessoal
- Por enquanto o app é só para o usuário usar e testar. A distribuição ao público fica para quando estiver completo.
- Ficam para a fase de distribuição: modelo de preço (ideia: assinatura de R$ 15 a R$ 20/mês com limite de uso diário; venda única de até US$ 1 não cobre IA na nuvem), backend que guarda a chave, privacidade/LGPD, conversar com possíveis usuários.

## Decisão principal desta sessão: solução gratuita (sem AWS)

| Etapa | Solução | Situação |
|---|---|---|
| Ouvir (STT) | `speech_to_text` (reconhecimento do aparelho/navegador) | **Real e testado no Chrome** ("Let's talk about", confiança 98%) |
| Falar (TTS) | `flutter_tts` (voz do aparelho/navegador) | **Real e testado no Chrome** (`DeviceTtsService`) |
| Pensar (LLM) | **Groq** (nível gratuito, modelos GPT-OSS); Gemini como alternativa | **Real e testado no Chrome** (`GroqConversationService`, resposta em ~1 s) |

Chave da IA:
- Agora (uso pessoal): opção A — chave passada via `--dart-define`, nunca em arquivo, git, print ou chat. Na versão web a chave fica no código do app no navegador (aceitável só para uso pessoal).
- Antes de outras pessoas usarem: opção B — backend gratuito (ex.: Cloudflare Workers) guardando a chave.

## Arquitetura (inalterada)
- `core/` serviços externos atrás de interfaces; `domain/` regras pedagógicas e estados; `features/` telas.
- Regras: A1–B2 correções em português; C1–C2 no idioma alvo; máx. 2 tentativas; instrução específica com exemplo.

## Mudanças de código nesta sessão (commit `c42be1a`, já no GitHub)
- `core/services/stt_service.dart`: `recognize({required String localeId})` (antes recebia stream de áudio).
- `core/services/mock_stt_service.dart`: nova assinatura.
- `core/services/device_stt_service.dart` (novo): STT real com `speech_to_text`; escuta até 30 s, encerra após 3 s de silêncio; sem confiança informada assume 1.0; erros devolvem texto vazio e preenchem `lastError`.
- `domain/models/language_locale.dart` (novo): `localeIdFor()` — Inglês→en_US, Espanhol→es_ES, Francês→fr_FR, Alemão→de_DE, Italiano→it_IT.
- `features/conversation/conversation_screen.dart`: usa `DeviceSttService`; cancela o STT no `dispose`; em debug mostra "Você disse: ... (confiança X%)" ou "Não ouvi nada (motivo)".
- `android/app/src/main/AndroidManifest.xml`: permissões `RECORD_AUDIO`, `INTERNET` e query de `android.speech.RecognitionService`.
- `pubspec.yaml`: `speech_to_text: ^7.5.0`, `flutter_tts: ^4.2.5`.
- Correções antigas: `test/widget_test.dart` (teste que abre a Home; passa), removido campo não usado em `mock_conversation_service.dart`, `withOpacity` → `withValues(alpha:)`.
- Pendente por decisão do usuário: migrar `package:flutter/material.dart` → `package:material_ui/material_ui.dart` (8 avisos; app funciona igual).
- A tela do carro (`driving_conversation_screen.dart`) ainda usa só mocks.

Mudanças posteriores (mesmo dia):
- `device_stt_service.dart`: cronômetro de segurança de 35 s (30 s de escuta + 5 s); se nenhum aviso chegar, devolve "Não ouvi nada (tempo esgotado)" e cancela a escuta. Evita a aula travar em "Ouvindo...".
- `conversation_screen.dart`: botões da tela de correção em `Wrap` (antes `Row`), para não estourar a largura em telas estreitas.
- Voz real: `tts_service.dart` com `speak(text, rate:, localeId:)`; novo `device_tts_service.dart` (`flutter_tts`, `awaitSpeakCompletion`, idioma `en_US`→`en-US`, velocidade web 1.0/0.8/0.6 e celular 0.5/0.4/0.3, tempo máximo 10 s + 150 ms por caractere). A tela usa `DeviceTtsService`; respostas no idioma da aula, instrução de correção em `pt_BR`; `_tts.stop()` no `dispose`.
- Escuta (`device_stt_service.dart`): no navegador o fim chega como `notListening` (não `done`) e agora encerra a escuta, com 2 s de espera por um resultado atrasado; `partialResults: true` (liga o modo contínuo no Chrome; parciais ignorados); silêncio de 5 s antes de começar a falar e 1,5 s depois da primeira palavra (`changePauseFor`). Ritmo aprovado nos testes.
- `mock_conversation_service.dart`: tempo de "pensar" de 1,5 s para 0,5 s.
- Conhecido: Pausar/Encerrar não interrompem a voz nem o microfone na hora; só valem depois da fala atual.

Mudanças da parte final do dia (IA real e ajustes de voz):
- `conversation_service.dart`: interface com `isRetryAfterCorrection`; `AiTurn.followUp` (nova pergunta); interface `LlmDebugInfo` (nome, modelo, tempo, último erro).
- Novo `conversation_prompt.dart`: parte comum às IAs — instruções da aula, marcadores `[SILENCE]` e `[RETRY]`, `turnFromJson`, frase de reserva por idioma, histórico curto (4 trocas). JSON com `feedback` (retorno, sem pergunta), `question` (nova pergunta), `hasError`, `reaction`, `instruction`, `errorType`, `correctForm`. Em A1–B2 a instrução é **sempre em português**, com exemplo completo e lembrete no fim; palavras no idioma da aula vão **entre aspas duplas**. Texto simples, sem markdown.
- Novo `groq_conversation_service.dart` (em uso): `openai/gpt-oss-120b`, reserva `openai/gpt-oss-20b`; troca de modelo em 429/404/5xx/tempo; 10 s por tentativa; `response_format: json_object`, `reasoning_effort: low`.
- `gemini_conversation_service.dart`: usa a parte comum; mantido como alternativa (`gemini-flash-lite-latest`).
- Tela: escolhe Groq, senão Gemini, senão mock (conforme a chave no comando). Fala reação → instrução automaticamente (sem precisar tocar). Instrução dividida pelas aspas (`speech_segments.dart`): português com voz pt-BR, exemplos com a voz do idioma da aula. Sem erro: retorno → pausa de **2 s** (`_followUpPause`) → pergunta. Debug mostra "IA: Groq (gpt-oss-120b, 0,8 s)".
- `device_tts_service.dart`: no navegador espera a lista de vozes (até 2 s) antes da primeira fala (a saudação saía com a voz padrão do Windows); prefere vozes com "Google" no nome; português 15% mais rápido no navegador (`_webRateFactors`).
- Pacote `http: ^1.6.0`. Testes: 8 (Home, `splitQuoted`, `turnFromJson`), todos passando.

## IA de conversa: testes feitos
- Gemini gratuito: funciona, mas sobrecarregado (503 "high demand") e lento (9 a 27 s); modelos 2.5 indisponíveis para contas novas; no gratuito o Google usa as conversas para treino.
- Groq gratuito (sem cartão): `gpt-oss-120b` e `gpt-oss-20b` em menos de 1 s, correção certa; Llama 3.x indisponíveis (404). Por padrão não guarda nem treina com as conversas. Limite estimado (não confirmado na página oficial): ~200 mil tokens/dia nos GPT-OSS ≈ 150 a 250 turnos.
- Aceitam chamadas do navegador (CORS testado): Groq, OpenRouter, Gemini. OpenRouter gratuito: só 50 pedidos/dia. Cerebras: só teste de 30 dias. Mistral: condições incertas.
- Chaves: criadas pelo usuário (Groq com validade de 90 dias). Nunca em arquivo, git, print ou chat. No terminal: `$env:GROQ_API_KEY = Read-Host "Cole a chave do Groq"` (não grava no histórico do PowerShell).

## Como rodar e testar no notebook
```
$env:GROQ_API_KEY = Read-Host "Cole a chave do Groq"
flutter run -d web-server --web-port 8080 --dart-define=GROQ_API_KEY=$env:GROQ_API_KEY
```
Sem `--dart-define`, o app usa o mock. Para o Gemini: `--dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY`. Mudou a chave: fechar com `q` e rodar de novo (o `R` não basta).
Abrir `http://localhost:8080` no Chrome normal. Para recarregar: `R` no terminal + F5 na página.
Não usar `flutter run -d chrome`: a janela que o Flutter abre não capta o microfone (erro `audio-capture`).

## Build Android no notebook (resolvido)
- A rede da empresa usa **Zscaler**, que inspeciona alguns sites (ex.: `plugins-artifacts.gradle.org`). O Java não confiava no certificado do Zscaler e o Gradle falhava (erro PKIX).
- O Java do Android Studio (JBR 25) não tem o provedor `Windows-ROOT`, então a opção de usar os certificados do Windows não funciona.
- Solução: cópia da lista de certificados do Java com o "Zscaler Root CA" (que a TI instalou no Windows) em `C:\Users\fabio.vsilva\.gradle\certs\cacerts-zscaler`, e `C:\Users\fabio.vsilva\.gradle\gradle.properties` com `systemProp.javax.net.ssl.trustStore` e `trustStorePassword=changeit` (senha padrão pública). Nenhuma verificação desligada.
- Para desfazer: apagar a pasta `.gradle\certs` e o arquivo `.gradle\gradle.properties`. Se o Android Studio for atualizado e o erro voltar, refazer a cópia.
- O NDK 28.2 não instalava sozinho (o `sdkmanager` agora repassa para o novo Android CLI, que não entendeu o nome). Instalado com: `cmdline-tools\latest\bin\android.exe sdk install ndk/28.2.13676358`.
- `flutter build apk --debug` funciona. APK em `ai_language_app\build\app\outputs\flutter-apk\app-debug.apk`.

## Emulador Android
- Emuladores existentes: `Pixel_7` e `Medium_Phone_API_37.0` (API 37, com Play Store); aceleração WHPX disponível.
- Abrir: `flutter emulators --launch Pixel_7` (a mensagem "exited with code 1" pode aparecer mesmo com a janela abrindo). Rodar: `flutter run -d emulator-5554`.
- Microfone: controles do emulador (⋯) > Microphone > **Enable Host Microphone Access**.
- Resultado: a voz funcionou uma vez; depois o emulador fechou sozinho e passou a receber só silêncio (log: `NO_SPEECH_DETECTED`). Serve para testar telas; voz no Android fica para o tablet. Tentativa não feita: abrir com `-allow-host-audio -no-snapshot-load`. Suspeita para os fechamentos: modo de vídeo `hw.gpu.mode=auto` (alternativa: `swiftshader_indirect`).

## Limites do notebook (é da empresa)
- O Zscaler pode afetar outras ferramentas que não usam os certificados do Windows (ex.: uma chamada da AWS CLI falhou; npm provavelmente também).
- O tablet ainda não foi conectado (precisa de depuração USB ativa).
- Questão de política: projeto pessoal em notebook da empresa; prints estão no OneDrive da Dataprev. Cabe ao usuário verificar.

## AWS (abandonada por custo)
- Conta pessoal `545934667227`, no plano pago após upgrade, **sem recursos rodando**. Gasto: menos de US$ 0,01.
- Polly, Transcribe, CloudFormation e parte do IAM bloqueados por SCP `p-b5037ihu` (organização `o-tbxgfv7s2x`); Bedrock/Claude funcionou.
- Chamado aberto no suporte (Conta e faturamento). Pode ser encerrado.
- Orçamento `ai-companion-mensal`: US$ 10/mês, alertas para `fabio.vieira@outlook.com`.
- Usuário IAM `ai-companion-dev` removido; credenciais locais removidas (ficou apenas `[sso-session d-946775f8b5]` no `~/.aws/config`, provavelmente da empresa).
- Imagens Docker do SAM e pasta `backend/` removidas.
- Decisões pendentes do usuário: encerrar o chamado; manter ou fechar a conta; ativar MFA no root se mantiver.
- Custo estimado por aluno com tudo na AWS: US$ 8 (15 min/dia) a US$ 33 (1 h/dia) por mês.

## Ferramentas instaladas no notebook
Flutter, Kiro, Git, Chrome (em uso). AWS CLI 2.41 e SAM CLI (não usados mais; podem ser desinstalados). Docker 28.5, Python 3.14, Node 14 (já existiam; Node 14 é antigo demais para o Cloudflare Wrangler).

## Sessão seguinte (commits `fa8591c` e da saudação)
- **Respostas longas cortadas: resolvido.** O pacote junta os trechos do Chrome (`_aggregateResults` ligado), então a causa era o silêncio de 1,5 s. Agora 3 s (`_speechPause`); aprovado nos testes.
- Telas de status e cartão de correção roláveis (`SingleChildScrollView`): a instrução longa da IA estourava a altura ("bottom overflowed").
- **"Você" na conversa**: balão com a última fala do aluno, sempre visível ("Não consegui ouvir. Tente de novo." quando falha).
- **Debug opcional**: opção "Mostrar informações de debug" (`core/debug/debug_settings.dart`) mostra confiança da fala (ou motivo técnico), IA/modelo/tempo e a barra de estados (também na tela do carro). O pulo da permissão de microfone continua preso ao `kDebugMode`.
- **Nomes amigáveis dos níveis** (`domain/models/cefr_level_labels.dart`): Iniciante, Básico, Intermediário, Intermediário avançado, Avançado, Fluente, com descrição; Avançado e Fluente avisam "Correções no idioma estudado". O código (A1 a C2) não aparece mais na tela; a IA continua recebendo o código.
- **Configurações guardadas no aparelho**: pacote `shared_preferences`; interface `KeyValueStore` (`core/storage/key_value_store.dart`); `AppSettings` (`domain/models/app_settings.dart`: idioma, nível, tema, modo, velocidade, debug; valores desconhecidos voltam ao padrão); `SettingsController` (`core/storage/settings_controller.dart`, instância `appSettings`, carregada em `main.dart`). No Chrome os dados ficam presos a `http://localhost:8080`.
- **Tela de Configurações** (`settings_screen.dart`): idioma, nível (com descrição), modo, velocidade; seção Desenvolvimento com debug e "Simular modo carro" (só em `kDebugMode`). `driveModeProvider` virou instância única.
- **Home simplificada**: engrenagem no topo, cartão "Sua prática" (resumo, abre as Configurações), tema (fica na Home) e "Iniciar conversação". Componentes comuns em `features/common/option_widgets.dart`.
- **Saudação gerada pela IA**: `startConversation` na interface `ConversationService`. Pedido `[START]` com hora do dia (morning/afternoon/evening) e um ângulo sorteado do tema (5 por tema; 6 no tema livre). Resposta = saudação → pausa → primeira pergunta; entra no histórico. Reserva fixa nos 5 idiomas (saudação pela hora + pergunta sorteada), também usada pelo mock. Tela mostra "Preparando sessão..." durante o pedido.
- Aviso: `flutter pub add` pediu o Modo de Desenvolvedor do Windows (links simbólicos de plugins). Só afeta a versão Windows desktop (não usada); web, Android e testes funcionam.
- Testes: 18, todos passando.

## Itens da sessão
- Idioma, nível, velocidade: funcionam (agora nas Configurações).
- Tema: funciona com a IA real (instruções e ângulo da abertura); fica na Home.
- Modo: **ainda sem efeito**. Definição do usuário: o modo define a pausa entre o retorno da IA e a nova pergunta. Contínuo = 2 s. Intervalado = 30 s, 1 min ou 2 min, à escolha.

## Próximos passos
1. **Memória da conversa por idioma** (etapa 3 do armazenamento, aprovada): resumo curto sobre o aluno e erros recorrentes, atualizado pela IA a cada 4 trocas e guardado no aparelho; entra nas instruções e na abertura; botão "Apagar memória" nas Configurações. O resumo é enviado ao Groq a cada aula (aceitável no uso pessoal).
2. **Modo intervalado**: nas Configurações, Modo com 4 opções (Contínuo, Intervalado 30 s, 1 min, 2 min); `AppSettings`/`SessionConfig` com o tempo da pausa; durante a pausa, estado "Intervalo" com contagem, microfone desligado e botão "Continuar agora".
3. Parar voz e microfone na hora em que a aula pausa ou termina.
4. Responder por voz na correção ("tentar de novo" / "repetir"); só então falar a pergunta "Quer tentar novamente...?".
5. Tela do carro com os serviços reais.
6. Migração para `material_ui` (quando o usuário quiser).
7. Testar voz no tablet Android; conferir velocidade das vozes no Android; backend gratuito (opção B), Android Auto/CarPlay, detecção de modo carro; remover a opção de debug antes de publicar.
