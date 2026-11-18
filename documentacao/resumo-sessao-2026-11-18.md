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
| Falar (TTS) | `flutter_tts` (voz do aparelho/navegador) | Pacote instalado; ainda usa `MockTtsService` |
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

## Como rodar e testar no notebook
```
flutter run -d web-server --web-port 8080
```
Abrir `http://localhost:8080` no Chrome normal. Para recarregar: `R` no terminal + F5 na página.
Não usar `flutter run -d chrome`: a janela que o Flutter abre não capta o microfone (erro `audio-capture`).

## Limites do notebook (é da empresa)
- A rede inspeciona HTTPS: o **Gradle falha** (erro PKIX), então não há build Android aqui. Também afetou uma chamada da AWS CLI; provavelmente afetaria npm.
- Saídas para o build Android: GitHub Actions gerando o `.apk` (sugestão; conferir cota gratuita), pedir à TI o certificado para Java/Gradle, ou outra rede se permitido.
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
1. **Voz real (TTS)** com `flutter_tts`: explicar a interface `TtsService`, implementar `DeviceTtsService` (idioma via `localeIdFor`, velocidade da Home), ligar na tela.
2. **IA real**: conferir nível gratuito do Gemini; usuário cria a chave; implementar `ConversationService` com as instruções pedagógicas, devolvendo `AiTurn`.
3. Tela do carro com os serviços reais.
4. Migração para `material_ui` (quando o usuário quiser).
5. Build Android (GitHub Actions ou outra saída), backend gratuito (opção B), Android Auto/CarPlay, detecção de modo carro.
