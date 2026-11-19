# Resumo do Projeto — AI Language Companion (sessão de 18/11/2026)

Use este arquivo como contexto ao iniciar uma nova conversa.

## Como trabalhamos
- Passos pequenos: antes de cada passo, explicar o que será feito e por quê; mostrar o resultado; só seguir após confirmação.
- Orientações de interface (console, sites) só com base em print ou descrição da tela. Prints: o usuário salva o arquivo e informa o caminho.
- Não fazer push, deletar ou mexer em configurações sem pedir.

## Visão geral
App Flutter de tutor de idiomas por voz com IA. Alvo final: Android Auto, Apple CarPlay e multimídia do BYD Song Pro. Desenvolvimento e testes no Chrome (agora) e tablet Android (depois).

## Decisão principal desta sessão: solução gratuita (sem AWS)

| Etapa | Solução | Situação |
|---|---|---|
| Ouvir (STT) | `speech_to_text` (reconhecimento do aparelho/navegador) | **Real e testado no Chrome** ("Let's talk about", confiança 98%) |
| Falar (TTS) | `flutter_tts` (voz do aparelho/navegador) | **Real e testado no Chrome** (`DeviceTtsService`) |
| Pensar (LLM) | A decidir — sugestão: Google Gemini (nível gratuito); alternativa: IA no aparelho (Gemma) | Ainda usa `MockConversationService` |

Chave da IA:
- Agora (só o usuário usa): opção A — chave passada via `--dart-define=GEMINI_API_KEY=...`, nunca em arquivo, git, print ou chat; chave restrita à API do Gemini; conta Google sem faturamento.
- Antes de outras pessoas usarem: opção B — backend gratuito (ex.: Cloudflare Workers) guardando a chave.
- Antes de escolher o Gemini: conferir as regras atuais do nível gratuito.

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
- Conhecido: Pausar/Encerrar não interrompem a voz nem o microfone na hora; só valem depois da fala atual. C1–C2 ainda recebem instrução em português (resolver com a IA real).

## Como rodar e testar no notebook
```
flutter run -d web-server --web-port 8080
```
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

## Próximos passos
1. **IA real**: conferir nível gratuito do Gemini; usuário cria a chave; implementar `ConversationService` com as instruções pedagógicas, devolvendo `AiTurn`.
2. Parar voz e microfone na hora em que a aula pausa ou termina.
3. Tela do carro com os serviços reais.
4. Migração para `material_ui` (quando o usuário quiser).
5. Testar voz no tablet Android; backend gratuito (opção B), Android Auto/CarPlay, detecção de modo carro.
