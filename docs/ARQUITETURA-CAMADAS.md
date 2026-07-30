# Arquitetura em camadas — motor (Modelfile) · persona (app) · fatos (RAG)

**Status:** especificado em 2026-07-29, junto com o diagnóstico do bug do modo
Code ([DIAGNOSTICO-BUG-ANNA-CODE.md](DIAGNOSTICO-BUG-ANNA-CODE.md)). A v9 só
entrega o benefício completo com as mudanças no SHVIA-WEB descritas aqui —
**a ordem do rollout importa** (§6).

## 1. Quem mora onde e por quê

### Camada 1 — Modelfile (`ShvIA:v9`, o MOTOR — muda raramente)

- **Contém:** modelo base (`gemma4:26b-a4b-it-qat`), parâmetros de runner e
  sampling (`num_ctx 16384`, `temp 1.0`, `top_k 64`, `top_p 0.95`,
  `repeat_penalty 1.0`, `num_batch 256`, `num_predict -1`) e um SYSTEM neutro
  mínimo que só vale como fallback para uso direto (`ollama run`, debug).
- **Nunca contém:** persona de empresa, fatos institucionais, protocolo de
  modo, dados de cliente, TEMPLATE custom, stops de outras famílias.
- **Racional:** o Modelfile é a peça mais cara de alterar (recreate + reload) e
  a única camada que **sempre sobrevive ao truncamento** do Ollama — foi
  exatamente assim que a Anna "engoliu" a tarefa no v8. Motor neutro = mesmo
  que algo trunque, o que sobra é um assistente técnico genérico, não uma
  atendente.

### Camada 2 — System por modo (injetado pelo app como `messages[0]`, `role:system`)

- **Mecanismo** (confirmado no código do Ollama, `server/routes.go`): se a
  PRIMEIRA mensagem do `/api/chat` for `role:system`, o SYSTEM do Modelfile é
  totalmente ignorado. **Pegadinha:** a checagem é só na posição `[0]` — um
  system fora da primeira posição faz o SYSTEM do Modelfile ser injetado
  JUNTO (persona fantasma). O app deve fundir todos os system em UMA mensagem
  na posição 0.
- **Modo Chat:** persona Anna ([../personas/anna-blue3.md](../personas/anna-blue3.md),
  Parte A) + bloco de fatos preenchido com chunks do RAG. Orçamento alvo:
  ~450 tokens de persona + até ~2.000 de fatos.
- **Modo Code:** protocolo do agente que já existe no `anna`
  (SHVIA-CODE/src/project.rs:30-69) — regras de execução, escolha de
  ferramenta, "proponha, não force". As ferramentas continuam no campo
  `tools` nativo (o gemma4 tem renderer/parser dedicados no Ollama que
  devolvem `message.tool_calls` estruturado).
- **Racional:** regra de comportamento precisa estar presente em 100% das
  requisições → vive no system do app; não no Modelfile (contaminaria o outro
  modo) e não no RAG (§ abaixo).

### Camada 3 — RAG (conhecimento recuperável)

- **Vai para o índice** (blue3-kb / KnowledgeRetriever do SHVIA-WEB): fatos
  institucionais (Parte B da persona), planos/preços/cobertura, LGPD + DPO,
  procedimentos por equipamento homologado, FAQ. Chunks autossuficientes, um
  fato por chunk, sem meta-texto.
- **Dados de cliente** (plano, equipamento, chamados): NÃO entram no índice
  vetorial compartilhado (LGPD). Lookup determinístico (cliente logado → CRM)
  e injeção por sessão em bloco próprio do system do Chat.
- **Injeção:** sempre concatenado ao FIM da mensagem system única
  (`messages[0]`), em bloco demarcado — nunca como segunda mensagem system
  (pegadinha do prepend), nunca como mensagem antiga (primeira a ser
  descartada em truncamento).

### O que NÃO vai para o RAG (e por quê)

- **Regras de comportamento, tom, prioridades, proibições**: não são
  recuperáveis por similaridade — "minha internet caiu" jamais "recupera" a
  regra "evite dizer com certeza". Regra que vale sempre vai no system, sempre.
- **Protocolo do modo Code e definição de ferramentas**: idem — system + campo `tools`.
- **Contatos oficiais críticos**: ficam indexados, mas o app também os injeta
  incondicionalmente no system do Chat (~50 tokens) — pequenos e obrigatórios
  demais para dependerem de similaridade vetorial.
- **Segredos, credenciais, tokens**: nunca, em nenhuma camada de prompt.

## 2. A dobra `foldSystemIntoFirstUser` — DESLIGAR

`app/Services/AI/Drivers/OllamaDriver.php:388-423`, flag
`OLLAMA_PRESERVE_MODELFILE_SYSTEM` (default `true`).

A dobra existia porque a persona vivia no Modelfile e um system na requisição
a apagaria. Com a persona saindo do Modelfile, **a substituição vira o
comportamento desejado nos dois modos**:

- `config/ollama.php`: `OLLAMA_PRESERVE_MODELFILE_SYSTEM=false` (manter o
  código da dobra atrás da flag para rollback instantâneo).
- No caminho `flag=false`, o `OllamaDriver` deve coletar as mensagens
  `role:system` **de abertura** e fundi-las em UMA na posição 0 (pegadinha do §1).
  **Exceção importante:** o nudge antiloop que o `CodeChatController.php:226`
  injeta como `role:system` no FIM do array existe pelo efeito de recência —
  arrastá-lo para a posição 0 mata a função dele. Correção certa: trocar esse
  nudge para `role:user` (o `AgentLoop.php:161` já faz assim, corretamente).
  Depois disso vale o invariante simples: **um único system, sempre em [0]**.
- Efeito que conserta a causa-raiz nº 2: como system real, o protocolo do
  agente passa a ser **sempre preservado** pelo truncador do Ollama, em vez de
  ser o primeiro texto de user descartado.
- `OLLAMA_SYSTEM_LOCKED_MODELS=anna,shana`: **verificado no código**
  (`ModelCatalog::isSystemLocked`, compara o nome-base antes do `:`) — `ShvIA:v9`
  não casa, nada a fazer.
- **Segurança (não regredir):** hoje o app injeta RAG deliberadamente no turno
  do usuário embrulhado em `UntrustedContent` (`ChatService.php:241-247`).
  Mover chunks de RAG para o system[0] **eleva conteúdo não-confiável a
  autoridade de system** — o bloco demarcado de fatos DEVE manter o wrapper
  `UntrustedContent` dentro do system, e o texto da persona deve instruir que o
  bloco é dado, não instrução.

## 3. Options por requisição (sampling não recarrega o modelo)

| Regra | Detalhe |
|---|---|
| **NUNCA enviar `num_ctx`** por requisição | Valor diferente do carregado dispara reload completo (`sched.go/needsReload`). `num_ctx` vive só no Modelfile (16384). Idem **`shift`**: no Ollama 0.32.x, alternar `shift` por request também dispara reload — não enviar. |
| Chat | `options: { "num_predict": 2048 }` — sampling herdado do Modelfile (calibração Gemma 4). |
| Code | `options: { "num_predict": 4096 }` — o default atual do app (8192, teto 16384) fica **inviável** com `num_ctx 16384`: prompt de ~12k + 8192 de saída não cabem. Temperatura: manter 1.0 herdada (Gemma 4 é exceção à regra "temp baixa p/ código"); A/B via options muda sem reload. |
| Ambos | `"truncate": false` no **topo** da requisição (não em `options`) → estouro de contexto vira **HTTP 400 visível** em vez de truncamento silencioso. Verificado no código da release estável (`ChatRequest.Truncate`, `routes.go`), mas **não documentado** em `docs/api.md` para `/api/chat` — contrato de código, vigiar em upgrades. **Só ligar na Fase 2** (com o v8 de `num_ctx 4096` ainda ativo, toda requisição Code de 15–31k viraria 400 duro — pior que o bug) e **somente junto com o tratamento do 400** (§4). Nota de compat: atinge também `/agent/chat` (contrato público) — comunicar a integradores que dependiam do truncamento silencioso. |
| `num_predict` por modo | **Exige encanamento novo**: nenhum caller passa `options.max_tokens` hoje (o driver cai no default global 8192, `OllamaDriver.php:112-117`). Adicionar a passagem por modo (Chat 2048 / Code 4096) na Fase 1 — via env global não dá, afetaria os dois modos igualmente. |
| `keep_alive` | O app manda `"30m"` hardcoded via cast em `OllamaDriver.php:105`, que **derruba** o `OLLAMA_KEEP_ALIVE=-1` do systemd (o modelo descarrega após 30 min ociosos apesar do preload). **Cuidado:** o cast `(string)` do driver transformaria `-1` em `"-1"`, que o `time.ParseDuration` do Ollama rejeita (400 em tudo). Correção certa: **omitir o campo** quando a config estiver vazia (o env do servidor manda — mais limpo, o systemd já tem `-1`); alternativa: `is_numeric($ka) ? (int)$ka : (string)$ka`. |

## 4. Guarda de orçamento + compactação (quem faz o quê)

**Arquitetura real do modo Code (corrigido na revisão adversarial):** o loop do
Code é **no cliente** — o `anna` (SHVIA-CODE) guarda a sessão e o histórico; o
lado servidor é o `CodeChatController` **stateless** (o `AgentLoop.php` serve
apenas `/agent/run`). Logo a compactação do Code mora em dois lugares:

- **`anna` (cliente, dono do histórico)** — compactação preventiva antes de
  enviar, nesta ordem:
  1. Truncar saídas de ferramenta antigas (`read_file`: cap de linhas; `grep`:
     cap de matches; substituir por `[saída truncada — N linhas omitidas]`).
  2. Descartar pares tool_call/tool mais antigos já consumidos.
  3. Resumir turnos antigos em uma mensagem-sumário.
  4. **Nunca tocar** no `system[0]` nem na tarefa original.
  Lembrete: a validação do servidor tem teto `messages max:200`
  (`CodeChatController.php:58`) — a compactação também protege esse limite.
- **`CodeChatController` (servidor)** — pré-flight + retry-once: num 400 de
  contexto nada foi streamado ainda, então dá para comprimir com o
  `ToolResultCompressor` (já existe, linha 164) e re-chamar UMA vez antes de
  propagar o erro.
- **Encanamento do erro (falta hoje):** o evento SSE `error` do
  `CodeChatController.php:326-332` só carrega `message` — incluir
  `status`/`kind` no payload para o `anna` distinguir overflow de outros erros
  sem parsear string (`agent.rs:42-43` hoje só imprime e encerra o turno).
- **Invariante de segurança a preservar:** `config/provider_errors.php:70-75`
  classifica overflow de contexto como `retriable:false` — é isso que impede a
  `TargetChain` de re-enviar os 31k tokens para o próximo alvo (que pode ser
  **nuvem** → vazamento LGPD). Não "consertar" o retry genérico; o retry-once
  é local, após compactar, no mesmo alvo.
- **Chat (ChatService):** janela deslizante de turnos + sumário; o
  `applyContextBudget` existente já lê o `num_ctx` real via `/api/show`
  (exige `memory.auto_compaction_enabled` ligado).
- `MAX_PROMPT_TOKENS = 16384 − num_predict(modo) − 512` (≈ 13,8k Chat / ≈ 11,7k
  Code). Estimador: **`chars/4`, o mesmo do resto do app**
  (`ContextBudget.php:65`, `OllamaDriver.php:240`) — não introduzir um segundo
  estimador.
- **Monitoração:** logar `prompt_eval_count` vs. estimado — atenção ao falso
  positivo: com KV-cache hit o Ollama reporta `prompt_eval_count` baixo/zero
  (o driver já trata em `OllamaDriver.php:234-241`); alertar só quando não for
  cache hit.

## 5. Payloads resultantes (`/api/chat`) — estado final (Fase 2+)

Notas: `keep_alive` como **número** JSON (ou omitido — ver §3); `truncate:false`
só a partir da Fase 2.

```jsonc
// CHAT
{ "model": "ShvIA:v9", "stream": true, "keep_alive": -1, "truncate": false,
  "messages": [
    { "role": "system", "content": "<persona Anna (Parte A)>\n\n=== CONTEXTO INSTITUCIONAL ===\n<chunks RAG>" },
    { "role": "user", "content": "minha internet caiu" } ],
  "options": { "num_predict": 2048 } }

// CODE
{ "model": "ShvIA:v9", "stream": true, "keep_alive": -1, "truncate": false,
  "messages": [
    { "role": "system", "content": "<protocolo do agente (project.rs:30-69)>" },
    { "role": "user", "content": "Leia o TAREFA.md e execute" },
    { "role": "assistant", "tool_calls": [ { "function": { "name": "read_file", "arguments": { "path": "TAREFA.md" } } } ] },
    { "role": "tool", "content": "<conteúdo, cap de linhas>" } ],
  "tools": [ /* list_dir/read_file/grep/edit_file/write_file — formato OpenAI-like já em produção */ ],
  "options": { "num_predict": 4096 } }
```

## 6. Rollout sequenciado (sem janela quebrada)

**Regra de ouro: app PRIMEIRO, modelo DEPOIS.** Inverter quebra: v9 + dobra
ligada = Chat sem persona e protocolo ainda enterrado como user.

### Fase 0 — validar infra (sem tráfego)

```bash
ollama -v          # REGISTRAR a versão no CHANGELOG — as premissas de FA/KV dependem dela
./scripts/build.sh modelfiles/active/ShvIA_v9.Modelfile ShvIA:v9   # tag NOVA; não tocar em ShvIA:latest
curl -s localhost:11434/api/generate -d '{"model":"ShvIA:v9","prompt":"ping","stream":false}'
ollama ps          # EXIGIR "100% GPU"; split CPU/GPU = offload → num_batch 128; persiste → num_ctx 12288
nvidia-smi         # headroom com o modelo carregado a 16k
journalctl -u ollama --since "-15 min" | grep -iE "flash|kv cache|offload|truncat|reload"
# Ollama <= ~0.2x no V100: esperado "FlashAttention:Disabled" + "quantized kv
#   cache requested but flash attention disabled" (q8_0 inativo → premissa do teto 16k).
# Ollama >= ~0.30 + driver 580.159+: os avisos NÃO aparecem — FA liga no V100
#   (issue #15641 corrigido), q8_0 passa a valer e há headroom para reavaliar
#   num_ctx 24-32k. AUSÊNCIA dos avisos = versão nova, não falha.
# Reavaliar a cada upgrade do Ollama/driver.
```

Teste de pico: prompt de ~13k tokens + geração longa, observando `nvidia-smi`.

### Fase 1 — deploy do app (ainda apontando para o v8)

Entra: flag `OLLAMA_PRESERVE_MODELFILE_SYSTEM=false` + persona no system[0]
(usar **`OLLAMA_SYSTEM_PROMPT_FILE`**, não a env inline — são ~450 tokens
multilinha; `config/ollama.php:105-116`; atenção: arquivo
inexistente/ilegível vira `''` **silenciosamente** — incluir a checagem no
preflight/`shvia:doctor`) + nudge do `CodeChatController:226` para `role:user`
+ encanamento do `num_predict` por modo + correção do `keep_alive` (omitir) +
evento SSE `error` com `status`/`kind` + compactação/retry do §4.

**NÃO entra na Fase 1: `truncate:false`.** Com o v8 (`num_ctx 4096`) ainda
ativo, ele transformaria toda requisição Code de 15–31k em 400 duro — pior que
o bug atual. Liga na Fase 2, quando o `num_ctx` real for 16384 e o tratamento
do 400 já estiver deployado.

**Seguro com o v8 ainda ativo:** o system da requisição SUBSTITUI o SYSTEM do
Modelfile, então o Chat mantém a Anna (agora vinda do app) e o Code **já
melhora** (protocolo com autoridade de system e protegido do truncamento)
mesmo antes do v9.

### Fase 2 — trocar o modelo (mover TODOS os caminhos de resolução)

O `anna` envia **`profile_name`, não `model`** — a resolução cai em:
request → `users.default_model` (banco, por usuário) → `model_roles` → default
do host. Trocar só a config **não move o modo Code**: perfil "ShvIA" sem tag
resolve para `ShvIA:latest` = v8. Passos:

- Apontar `model_roles` (tabela `model_roles` / `app/Models/ModelRole.php`) e
  o default do host para `ShvIA:v9`;
- **Atualizar `users.default_model` dos usuários que apontam para
  `ShvIA:latest`/`ShvIA`** (ou avisar os devs para trocar o perfil no
  `config.toml`/`/model`) — alternativa: antecipar o
  `ollama cp ShvIA:v9 ShvIA:latest` desta para esta fase, backupeando o v8
  antes sob outra tag (`ollama cp ShvIA:latest ShvIA:v8-bak`);
- Ligar `truncate:false` (agora seguro);
- `ExecStartPost` do ollama.service (pré-carrega `"ShvIA"` → `"ShvIA:v9"`);
- `OLLAMA_THINKING_MODELS=ShvIA`: **verificado no código**
  (`ModelCatalog::ollamaModelSupportsThinking`) — entrada sem `:tag` casa
  qualquer tag do mesmo nome, então `ShvIA:v9` já casa. Nada a fazer.
- `systemctl daemon-reload && systemctl restart ollama`.

### Fase 3 — bake-in e limpeza

Após 1–2 semanas estáveis: opcionalmente `ollama cp ShvIA:v9 ShvIA:latest`
para realinhar a tag histórica; arquivar o v8 como backup.

### Testes canário (após cada fase)

1. Chat: "Quem é você?" → persona Anna, contatos SÓ os do contexto institucional.
2. Code: "Leia o TAREFA.md e execute" com histórico ≥ 12k tokens →
   `tool_calls` estruturados, **zero** "Olá! Eu sou a Anna" (o sintoma do bug).
3. Overflow (Fase 2+): prompt > 16k → HTTP 400 (`truncate:false`), o
   `CodeChatController`/`anna` compacta e reenvia uma vez, e o erro chega ao
   cliente com `status`/`kind` se persistir.
4. `prompt_eval_count` vs. estimado (detector de truncamento residual —
   ignorando KV-cache hits).
5. `ollama ps` continua "100% GPU" sob carga real.
6. SShvTerm modo host (`anna --json --tools host`, aba Agente): propõe UM
   comando `bash` por vez com explicação — mesmo motor, caminho próprio.

### Rollback (cada fase independente, reversível por config)

- Fase 2 → voltar `model_roles` para `ShvIA:latest` (v8 intacto, nunca sobrescrito).
- Fase 1 → `OLLAMA_PRESERVE_MODELFILE_SYSTEM=true` restaura a dobra antiga.
- Fase 0 → `ollama rm ShvIA:v9`.

## 7. Ressalva de capacidade (limite do V100 16GB)

Com `OLLAMA_MAX_LOADED_MODELS=1` e 16 GB, não há como servir um segundo modelo
dedicado ao Code sem swap a cada alternância — por isso a v9 é **um motor para
os dois modos**. Se o produto exigir contexto real de 32k+, os caminhos são:

- **Upgrade do Ollama/driver** (≥ ~0.30 + driver 580.159+ liga FA no próprio
  V100 → KV q8_0 passa a valer → 32k+ fica viável sem trocar hardware) e/ou
  **GPU Turing+ com mais VRAM** (64k fica barato); ou
- **modelo menor** (12b/14b — ex.: `tools/Dev.Modelfile` sobre qwen2.5-coder
  como modelo dedicado do papel `task`/code), aceitando perda de qualidade.

Decisão de produto, não de Modelfile.

## 8. Riscos conhecidos / observações

- Consumidores do `OllamaDriver` com a dobra desligada — **verificados, nenhum
  quebra**: `RagService` bypassa o driver (HTTP direto com system[0] próprio);
  `/agent/run` e `SubagentTool` montam system[0] próprios; `/agent/chat` usa
  `buildHistory`; kb_search/memory_search são `role:tool`; SShvTerm host usa o
  mesmo `/code/chat` com system[0] do `anna`.
- Histórico antigo persistido no banco **não** contém a dobra (ela é aplicada
  por request no driver; as conversas guardam turnos crus) — migrar não exige
  nenhum backfill.
- O caminho RAG isolado (`RagService.php`) usa `qwen3:8b` **hardcoded** com
  `OLLAMA_MAX_LOADED_MODELS=1`: cada chamada troca o modelo carregado (swap
  caro do 26B ↔ 8B). Idem embeddings (`bge-m3`) no mesmo host. Se esses fluxos
  crescerem, considerar instância Ollama separada para modelos auxiliares (o
  pool `srvN` do app já suporta múltiplos hosts).
- `nvidia-smi` mostrou o servidor com ~35% de utilização e 15,2 GB ocupados em
  repouso — não há folga para picos concorrentes; `OLLAMA_NUM_PARALLEL=1` está
  correto e deve permanecer.
- Os arquivos `configs/` (ollama.service, nvidia-smi, journalctl) foram
  deletados do working tree sem commit. Os fatos relevantes estão registrados
  nos docs; decidir se a deleção é para valer (commitar + .gitignore) ou
  restaurar (`git checkout -- configs/`).
