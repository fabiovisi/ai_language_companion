# Plano de melhorias — AI Language Companion

Melhorias aprovadas para tornar o app mais atraente, em ordem de implementação.
A ordem segue o diferencial do app (praticar com as mãos livres, no trânsito) e as
dependências entre as etapas. Esforço estimado com a estrutura atual (Groq gratuito,
dados no aparelho, testes no Chrome).

Forma de trabalho: uma etapa por vez, em passos pequenos, com explicação antes,
teste do usuário depois e commit ao final de cada etapa.

---

## Etapa 0 — Teste do reconhecimento em português (feito)

**Resultado:** o reconhecimento do Chrome escuta um idioma por vez. Numa aula de
inglês, a fala em português vira palavras em inglês e o pedido se perde.

**Alternativas avaliadas e descartadas:**
- Palavra ou frase de chamada ("Help", "I need some help") que troca a escuta para o
  português. Descartada: duas falas por pedido e risco de disparar no meio da conversa.
- Personagem com nome para invocar ("Gabi"). Descartado como mecanismo de ajuda: o
  nome precisaria ser reconhecido de forma estável no Chrome (sem dicas de vocabulário)
  e a ajuda exigiria duas falas. A ideia de um personagem pode voltar como identidade
  do app na etapa 7 (opcional).

**Teste do Whisper (Groq, whisper-large-v3-turbo), com gravações do usuário:**
- Modo automático (sem idioma fixo, sem dica): "Essa frase tem palavras que não
  conheço." e "O que significa commute?" reconhecidas em português, corretas,
  "commute" escrito certo. Tempo de 0,8 a 1,1 s.
- Idioma fixo em inglês: o Whisper **traduziu** o português. Usar o modo automático.
- Dica de estilo (prompt) em inglês: piorou tudo (traduziu o português e perdeu
  "commute"). Não usar dica.
- "Yesterday I goed to the park" virou "I go to the park". O Chrome faz o mesmo
  ("goed" → "go"). Empate: palavras inventadas viram palavras reais nos dois. A IA
  ainda corrige o tempo verbal.
- Limite gratuito: cerca de 2.000 pedidos e 8 horas de áudio por dia.

**Decisão:** trocar o reconhecimento de fala pelo Whisper do Groq. O aluno pede ajuda
falando direto no idioma nativo, a qualquer momento, sem botões e sem palavra de chamada.

---

## Etapa 1a — Reconhecimento com Whisper

**Objetivo:** o app ouve em qualquer idioma e sabe qual idioma foi falado.
Esforço: médio a alto.

- **Gravação:** pacote `record` (Chrome e Android). Grava só em "Ouvindo...", em
  memória; o áudio é descartado depois do envio. Nada fica salvo.
- **Fim da fala:** detectado pelo app, pelo volume do microfone, com as regras atuais:
  5 s para começar a falar, 3 s de silêncio para encerrar, 30 s no máximo. Sem fala,
  não envia nada (economiza o limite).
- **Envio:** novo `WhisperSttService` na interface `SttService`. Envia ao Groq
  (modo automático, sem dica) e devolve texto, confiança e **idioma identificado**.
- **Reserva:** sem a chave do Groq, continua o reconhecimento do Chrome/Android.
- **Debug:** mostra o reconhecimento em uso e o idioma identificado.
- **Idioma nativo** do aluno em um único lugar do código (português do Brasil por
  enquanto); vira opção na distribuição.

Riscos: detectar o fim da fala pelo volume é menos refinado que o detector do Chrome
(ruído, carro); o áudio passa a ir para o Groq (não guarda por padrão).

**Concluída.** Como ficou:
- `WhisperSttService` (modelo `whisper-large-v3-turbo`), gravação PCM 16 kHz mono com
  redução de ruído e cancelamento de eco; **ganho automático desligado** (amplificava o
  ruído no silêncio e o Whisper inventava frases).
- `SpeechEndDetector` (`whisper_audio.dart`): volume em janelas de 20 ms, ruído de
  fundo que começa baixo, desce na hora e sobe devagar (~7 s); fala = ao menos 0,3 s de
  som acima de 3× o ruído; estalos (< 60 ms) não contam; som perto do fim dos 5 s
  iniciais espera o silêncio depois dele.
- Filtros na resposta: descarta trechos com chance de silêncio ≥ 40% ou confiança muito
  baixa, e frases típicas inventadas ("next video", "thanks for watching", "subscribe",
  "obrigado por assistir", "amara.org"). "Thank you." curto é mantido.
- Debug: reconhecimento em uso, idioma identificado e linha "Volume" (ruído, pico, fala).
- Idioma nativo em `domain/models/native_language.dart`.

**Limite conhecido:** com sotaque, o Whisper às vezes identifica português numa fala em
inglês e **traduz** a fala. Tratado na etapa 1b (segunda transcrição). Ideias para
depois, se incomodar: aviso discreto no balão quando a fala veio da segunda transcrição;
testar outros modelos de reconhecimento do Groq.

---

## Etapa 1b — Pedidos de ajuda pela fala

**Objetivo:** o aluno pede ajuda falando, sem tocar na tela. Esforço: médio.

Fala no **idioma nativo** (identificado pelo Whisper) = pedido de ajuda. Pedidos simples
no idioma da aula ("Can you repeat?", "Slower, please", "What does X mean?") também são
reconhecidos pela IA, sem contar como erro.

Pedidos:
- **Palavras desconhecidas:** "Essa frase tem palavras que não conheço" ou
  "O que significa X?". A IA explica em português as palavras mais difíceis para o
  nível (ou só as que o aluno citou), com as palavras do idioma entre aspas, e repete
  a pergunta com palavras mais simples. Não conta como erro.
- **Como se diz...?:** "Como se diz 'trânsito'?". A IA responde com a palavra ou
  frase e um exemplo curto, e devolve a vez ao aluno.
- **Traduzir:** "Traduz a pergunta". Tradução completa só quando pedida.
- **Repetir / mais devagar:** a IA repete a última fala; "mais devagar" repete com a
  velocidade reduzida.

Como implementar:
- A resposta JSON da IA ganha um campo `intent` (ex.: `conversation`,
  `explainWords`, `howToSay`, `translate`, `repeat`, `slower`). A IA identifica o
  pedido, porque o texto pode vir deformado e porque ela tem a última fala no histórico.
- Explicações em português usam a divisão por aspas que já existe (`speech_segments.dart`).
- Nível Avançado e Fluente: explicação no idioma estudado, com palavras simples.
- As palavras explicadas ficam registradas para a revisão (etapa 4).

Atenção: cada regra nova aumenta as instruções enviadas a cada turno. Manter as
instruções curtas, porque o limite gratuito do Groq é por tokens por dia.

**Concluída.** Como ficou (difere do planejado em alguns pontos):
- Sem campo `intent`: a resposta ganhou `help` (explicação) e `slower` (falar mais
  devagar). Marcador `[HELP]` na fala do aluno.
- **Marcador de idioma: chaves, não aspas.** Só as palavras do idioma da aula vão entre
  chaves: `A palavra {like} significa "gostar".` As aspas viravam a tradução para a voz
  em inglês. Na tela, as chaves aparecem como aspas. Vale para ajuda e correção.
- **Cartão de ajuda** na tela: "A FRASE" (última fala da IA no idioma da aula, com as
  palavras explicadas em negrito), "EXPLICAÇÃO" e o estado atual. Fica visível até a
  resposta do aluno.
- **Segunda transcrição:** quando o Whisper identifica o idioma nativo, o mesmo áudio é
  transcrito de novo com o idioma da aula fixo; as duas versões vão à IA (`[HELP?]`),
  que decide pelo sentido se era pedido de ajuda ou resposta com sotaque. O áudio fica
  em memória só até a próxima escuta.
- "Mais devagar": a pergunta seguinte sai uma velocidade abaixo da escolhida.
- Pedido de ajuda logo após uma correção: a IA explica e a conversa segue a partir da
  pergunta repetida.
- Ainda não feito: registrar as palavras explicadas para revisão (depende da etapa 4).

---

## Etapa 2 — Comandos de controle pela fala e parada imediata

**Objetivo:** controlar a aula pela voz. Esforço: médio.

- "Pausa", "continua", "encerra", "muda de assunto".
- Na correção: "tentar de novo" e "repetir" substituem os botões, que **saem da tela**
  (decisão do usuário: só voz). A IA passa a falar a pergunta
  "Quer tentar novamente ou ouvir a instrução de novo?".
- Com o Whisper, os comandos podem ser ditos no idioma nativo ("pausa", "encerra").

**Implementada (aguardando teste).** Decisões do usuário: retomar dizendo "continuar"
(microfone ligado na pausa); botões Pausar/Retomar/Encerrar ficam; na correção, a
próxima fala já é a nova tentativa.
- `voice_commands.dart`: pausar, continuar, encerrar e repetir, em português e nos
  idiomas da aula, só quando são a fala inteira (ignora acentos, pontuação e
  cortesias). Detectados pelo app, sem a IA.
- Parada imediata de voz e microfone ao pausar/encerrar (voz ou botão).
- Pausa: aviso falado; microfone esperando "continuar"/"encerrar"; outras falas
  ignoradas. Ao retomar, a IA repete a última fala (na correção, repete a instrução).
- Encerrar por voz: despedida no idioma da aula.
- Correção sem botões: reação → instrução → pergunta ("Tente dizer a frase de novo, ou
  diga 'repetir'...") → escuta. "Repetir" repete a instrução; primeiro silêncio repete
  a pergunta; segundo silêncio segue a conversa.
- "Muda de assunto" ainda não tem regra própria (a IA pode atender pelo contexto).
- **Parar voz e microfone na hora** em que a aula pausa ou termina (hoje só valem
  depois da fala atual). Necessário para o comando "pausa".

Decisão em aberto: comandos simples ("pausa", "encerra") podem ser detectados no
próprio app, por palavra-chave, sem esperar a IA. Mais rápido, mas depende do
resultado da etapa 0.

---

## Etapa 3 — Tela do carro com os serviços reais

**Objetivo:** a tela do carro passa a usar voz, escuta e IA reais, com a mesma lógica
da tela de conversa. Depende da etapa 2 (no carro não há botões). Esforço: médio.

- Reaproveitar a lógica da aula em um componente comum às duas telas, em vez de copiar.
- Conferir textos e tempos pensando em quem está dirigindo.

---

## Etapa 4 — Memória, resumo da aula e revisão

**Objetivo:** o app lembra do aluno e mostra evolução. Esforço: médio.

- **Memória por idioma** (já aprovada): resumo curto sobre o aluno (fatos pessoais,
  interesses) e erros recorrentes, atualizado pela IA a cada 4 trocas e guardado no
  aparelho. Entra nas instruções e na abertura.
- **Resumo no fim da aula**, falado e na tela: minutos falados, erros que se
  repetiram, palavras novas (incluindo as da etapa 1).
- **Revisão:** a IA cria situações para o aluno usar de novo o que errou e as
  palavras que pediu para explicar.
- **Retomar de onde parou:** a abertura pode retomar o assunto da aula anterior.
- **Conversas sobre a vida do aluno**, a partir da memória.
- Botão **"Apagar memória"** nas Configurações.

Privacidade: o resumo vai para o Groq a cada aula (aceitável no uso pessoal; rever na
distribuição).

---

## Etapa 5 — Cenas de role-play

**Objetivo:** prática de situações reais com a IA fazendo um personagem.
Esforço: baixo.

- Cenas ao lado dos temas, por exemplo: pedir no restaurante, check-in no hotel,
  entrevista de emprego, consulta médica, pedir informação na rua.
- Cada cena define o papel da IA, o objetivo do aluno e um final ("missão cumprida").
- Decisão em aberto: cenas como mais um item na lista de temas ou como uma escolha
  separada na Home.

---

## Etapa 6 — Ritmo da aula: duração do trajeto e modo intervalado

**Objetivo:** a aula se adapta ao tempo disponível. Esforço: baixo a médio.

- **Duração:** "Tenho 10 / 20 / 30 minutos". A IA dá ritmo e encerra com o resumo
  (etapa 4) no fim do tempo.
- **Modo intervalado** (já definido): pausa entre o retorno da IA e a nova pergunta.
  Contínuo = 2 s; Intervalado = 30 s, 1 min ou 2 min. Durante a pausa: estado
  "Intervalo" com contagem, microfone desligado e botão "Continuar agora".

---

## Etapa 7 — Personalização

**Objetivo:** o aluno escolhe como quer ser acompanhado. Esforço: baixo a médio.

- **Jeito de corrigir:** tudo, só erros importantes, ou só no fim da aula.
- **Personalidade do tutor:** paciente, divertido ou formal.
- **Voz e sotaque:** masculina ou feminina; inglês americano ou britânico, espanhol
  da Espanha ou do México. No navegador depende das vozes do Chrome; no Android, das
  vozes do aparelho.

---

## Etapa 8 — Hábito e conquista

**Objetivo:** fazer o aluno voltar. Esforço: baixo a médio.

- **Meta diária** (ex.: 15 minutos) e **sequência de dias**.
- **Sugestão de subir de nível** quando o aluno erra pouco por algumas aulas.

---

## Pendências que continuam valendo

- Migração `material.dart` → `material_ui` (quando o usuário quiser).
- Testar voz no tablet Android e conferir a velocidade das vozes no Android.
- Fase de distribuição: backend gratuito para a chave (opção B), privacidade/LGPD,
  modelo de preço, remover a opção de debug, Android Auto/CarPlay, detecção de modo
  carro.
- Limite conhecido: o app não avalia pronúncia (o reconhecimento devolve só texto).

## Ordem atual

Etapas 1a e 1b concluídas. Etapa 2 implementada, **aguardando teste do usuário**.
Depois: etapa 3 → demais etapas.
