# Diagnóstico: por que a Anna ignora tarefas de código (modo Code)

**Data:** 2026-07-29 · **Sintoma:** no modo Code do ShvIA, o modelo recebe "Leia o TAREFA.md e execute…", faz algumas chamadas de ferramenta e então responde *"Olá! Eu sou a Anna, assistente virtual da Blue3 Internet…"* como se fosse um atendimento de suporte.

**Veredito: não é um bug — são duas causas-raiz que se reforçam, mais três agravantes.** Ambas confirmadas por inspeção do código-fonte (Ollama e SHVIA-WEB).

---

## Causa-raiz 1 — `num_ctx 4096` vs. requisições de 15–31k tokens

O `ShvIA_v8.Modelfile` (produção, `ShvIA:latest`) define `num_ctx 4096`. As requisições do modo Code observadas chegam a **15.694 e 31.166 tokens**.

O que o Ollama faz nesse caso (código-fonte, `server/prompt.go`, função `chatPrompt`):

> *"chatPrompt truncates any messages that exceed the context window of the model, making sure to always include 1) the latest message and 2) system messages"*

- Descarta mensagens **das mais antigas para as mais novas** até caber.
- A mensagem **system sempre sobrevive** (é re-inserida no topo mesmo que caia na região descartada).
- O único aviso é um `slog.Debug(...)` — **invisível no log padrão**; a resposta da API não sinaliza nada.

Ou seja: a persona de suporte (SYSTEM do Modelfile) tem **sobrevivência garantida**, e a tarefa/histórico de ferramentas tem **descarte garantido**. O modelo termina vendo só "você é a Anna do suporte da Blue3" + fragmentos recentes — e responde como atendente.

**Agravante histórico:** o v7 tinha `num_ctx 16384`. O v8 **regrediu para 4096** sem registro do motivo (provavelmente para caber na VRAM — ver §Hardware).

## Causa-raiz 2 — a dobra `foldSystemIntoFirstUser` do app

O SHVIA-WEB tem uma proteção deliberada em `app/Services/AI/Drivers/OllamaDriver.php:388-423` (flag `OLLAMA_PRESERVE_MODELFILE_SYSTEM`, default `true`): **toda mensagem `role:system` é removida do array e concatenada como prefixo da primeira mensagem `user`**.

Foi feita porque o `/api/chat` do Ollama **substitui** o SYSTEM do Modelfile quando a primeira mensagem da requisição é `system` (confirmado em `server/routes.go`, `ChatHandler`) — e à época a persona vivia no Modelfile, então "dobrar" o system do app protegia a Anna.

Consequência perversa no modo Code:

1. O cliente `anna` (SHVIA-CODE, `src/project.rs:30-69`) envia um **bom** protocolo de agente como `role:system`.
2. O `OllamaDriver` o rebaixa a texto de **user**, no **turno mais antigo** da conversa.
3. O turno mais antigo é **o primeiro descartado** pelo truncamento da Causa 1.
4. A persona de suporte do Modelfile, como system "real", **sempre vence**.

As duas causas se acoplam: mesmo sem truncamento, o protocolo de agente compete como "texto de usuário" contra uma persona com autoridade de system; com truncamento, ele simplesmente desaparece.

## Agravantes

3. **SYSTEM do v8 é 100% persona de suporte** — ~210 linhas de atendimento ao cliente + 5 linhas de "SERVIDOR TERMINal" coladas no fim, com instrução central agramatical (*"nao responda como fazer quando voce puder fazer"*). Nenhuma menção às ferramentas reais (`read_file`, `list_dir`, `grep`…).
4. **Linhagem anti-código** — Anna-v1.0 e bk.Anna proibiam explicitamente lidar com código (*"Você NÃO é especialista em programação; encaminhe à equipe de desenvolvimento"*). A cultura do prompt sempre foi "suporte, não código".
5. **`repeat_penalty 1.10`** — penaliza tokens estruturais repetidos (indentação, chaves, nomes de identificadores), degradando geração de código e formatos de tool call. Para código, o correto é 1.0.

Sobre `temperature 0.85`: **não** é a vilã que parecia. A calibração oficial do Gemma 4 QAT é `temp 1.0 / top_k 64 / top_p 0.95`, e a família se comporta mal em temperaturas muito baixas. O v5 tinha isso documentado em comentário; o comentário foi perdido no v7/v8.

## Hardware (restrição real por trás da regressão do num_ctx)

Servidor: **Tesla V100-PCIE-16GB** — com o modelo carregado (26B-A4B QAT, num_ctx 4096): **15.182 MiB / 16.384 MiB usados** (folga ~1,2 GB). O `ollama.service` já roda com `OLLAMA_FLASH_ATTENTION=1` e `OLLAMA_KV_CACHE_TYPE=q8_0` — as mitigações "fáceis" já estão ligadas.

Atenuante: o Gemma 4 usa atenção híbrida (camadas sliding-window intercaladas), então o KV cache cresce **muito** mais devagar que num modelo denso de atenção full — subir para 16k–32k custa na ordem de 1–2 GB, não "vários GB". É apertado no V100, mas plausível; **validar com `ollama ps`** (ver plano na [ARQUITETURA-CAMADAS.md](ARQUITETURA-CAMADAS.md)).

## Fatos úteis descobertos na investigação (fonte: código/doc oficial do Ollama)

| Fato | Implicação para o SHVIA |
|---|---|
| `"truncate": false` na requisição → HTTP 400 em vez de truncamento silencioso | O app deve enviar isso e tratar o erro — truncamento nunca mais passa despercebido. |
| `/api/chat`: 1ª mensagem `role:system` → SYSTEM do Modelfile é **ignorado por completo** | Base da arquitetura v9: a persona/protocolo viaja por request. Cuidado: system fora da posição [0] **coexiste** com o do Modelfile. |
| `options.num_ctx` por request funciona, mas **mudar o valor recarrega o modelo** | Padronizar UM `num_ctx` para todos os modos; variar apenas sampling (não causa reload). |
| Sampling por request (`temperature`, `top_p`, `repeat_penalty`, `num_predict`) **não** causa reload | O app pode ter perfis por modo (Chat vs Code) sem custo. |
| Gemma 4 tem **tool calling nativo** no Ollama (renderer/parser dedicados, tags `<\|tool_call>`) | O modo Code está correto em usar o campo `tools` — nada a mudar aí. |
| Default do Ollama para `repeat_penalty` é **1.1** | Se o Modelfile não declarar, herda um valor ruim para código. Declarar `1.0` explícito. |
| `num_predict -1` = geração ilimitada (até EOS) — e já é o default atual | Inofensivo; teto explícito só como proteção anti-loop. |

## Correção

Arquitetura em 3 camadas (motor genérico no Modelfile v9 + persona/protocolo injetados pelo app por modo + fatos via RAG) — especificada em [ARQUITETURA-CAMADAS.md](ARQUITETURA-CAMADAS.md), com plano de rollout sequenciado (a ordem importa: v9 sem ajuste no app = Chat sem persona; ajuste no app sem v9 = dobra continua enterrando o protocolo).
