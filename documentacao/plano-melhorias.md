# Plano de melhorias — AI Language Companion

Melhorias aprovadas para tornar o app mais atraente, em ordem de implementação.
A ordem segue o diferencial do app (praticar com as mãos livres, no trânsito) e as
dependências entre as etapas. Esforço estimado com a estrutura atual (Groq gratuito,
dados no aparelho, testes no Chrome).

Forma de trabalho: uma etapa por vez, em passos pequenos, com explicação antes,
teste do usuário depois e commit ao final de cada etapa.

---

## Etapa 0 — Teste do reconhecimento em português (sem código)

**Objetivo:** saber se dá para fazer pedidos em português numa aula de outro idioma.

O reconhecimento de fala escuta um idioma por vez. Numa aula de inglês, ele está em
inglês; uma frase em português pode chegar deformada.

**Como testar:** com o debug ligado, numa aula de inglês, falar em português:
- "Essa frase tem palavras que não conheço."
- "O que significa commute?"
- "Como se diz 'trânsito' em inglês?"
- "Repete mais devagar."

Anotar o que aparece no balão "Você".

**Decisão que sai do teste:**
- Texto reconhecível (mesmo com erros): a IA interpreta o pedido (etapa 1 como planejada).
- Texto irreconhecível: usar palavras-chave curtas que o reconhecimento capte bem
  (ex.: "help", "explain") ou um botão "Não entendi" que muda a escuta para português.

---

## Etapa 1 — Pedidos de ajuda pela fala

**Objetivo:** o aluno pede ajuda falando, sem tocar na tela. Esforço: médio.

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

---

## Etapa 2 — Comandos de controle pela fala e parada imediata

**Objetivo:** controlar a aula pela voz. Esforço: médio.

- "Pausa", "continua", "encerra", "muda de assunto".
- Na correção: "tentar de novo" e "repetir" substituem os botões (os botões continuam
  na tela para quem preferir). Depois disso, a IA passa a falar a pergunta
  "Quer tentar novamente ou ouvir a instrução de novo?".
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

## Sugestão para a próxima sessão

Etapa 0 (teste, minutos) e, conforme o resultado, etapa 1. Se sobrar tempo, começar a
etapa 2 pela parada imediata de voz e microfone.
