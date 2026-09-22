# CHANGELOG — Modelfiles SHVIA

## 1.2.8 - delete the Shana v2.3 copy, and refuse an undeclared duplicate Modelfile

`f154`. `modelfiles/shana/Shana-v2.3.Modelfile` was byte-for-byte `Shana-v2.2.Modelfile`
(md5 `2a14097f97f440eebe6f6170b77f7ff1` on both).

### It was born a copy — nothing was lost

The open question was whether v2.3 ever had content of its own that a later commit
overwrote. It did not, and git answers it flatly: the file has **one** commit in its whole
history, `1ebc20e "Nova versao"` (2026-08-04), and it was **already identical to v2.2 in
that commit**. There is no lost version to reconstruct.

What it cost was real anyway: whoever promoted "v2.3" would ship v2.2 believing they were
shipping a change, and the catalogue in `modelfiles/README.md` stopped at v2.2 — the
repository disagreed with its own directory listing and nothing noticed.

### The guard, with an allowlist

`scripts/prova-modelfile-nao-e-duplicata.sh` fails on any byte-identical pair of tracked
Modelfiles that is not named in `modelfiles/duplicatas-declaradas.txt`. Exit codes follow
the house convention — **0** clean, **1** found one, **2** could not measure.

⚠️ **An allowlist and not a blanket ban**, because one duplicate here is deliberate and
documented: `archive/ShvIA_qwen.Modelfile` is the archived byte-copy of
`tools/SShvTerm.Modelfile`, and both `modelfiles/README.md:49` and `CHANGELOG.md:184` say
so. A guard that cannot tell a declared copy from an accidental one is a guard somebody
switches off.

🔬 **The second pair was found by the guard, not by the finding.** The finding named only
Shana; sweeping all 26 tracked Modelfiles by md5 turned up `ShvIA_qwen`/`SShvTerm` as well,
and reading the catalogue is what showed it was intentional. Measuring the whole set was
cheaper than trusting the one pair somebody had already noticed.

| reversal | result |
|---|---|
| the allowlist file is absent | exit **2** — did not measure |
| the declared pair loses its line | exit **1**, naming `ShvIA_qwen`/`SShvTerm` |
| a fresh copy of v2.2 is added | exit **1**, naming it |
| current tree | exit **0**, 25 Modelfiles, 1 declared, 0 undeclared |

### And a trigger, in the same commit

`.github/workflows/` held only `release.yml`, which publishes a Release and checks
nothing. A ruler added here would have had content and no trigger, which protects zero.
`ci.yml` runs **every** `scripts/prova-*.sh` on push and pull request — globbed, so adding
a ruler does not mean remembering to edit the workflow — and fails the job when the glob
matches nothing, because a job that passes by measuring nothing is the failure mode the
whole convention exists to avoid.

## 1.2.7 - the git hooks arrive from repodocs and are enabled here

Both hooks of the standard now run here: `commit-msg`, which checks the shape of
the subject (`X.Y.Z - description`), refuses a Conventional Commits prefix and a
vague message, **and checks that the subject's `X.Y.Z` is the version this commit
carries in `version.md`**; and `pre-push`, which compares the local `version.md`
against the remote default branch for a repeated version and for one that moves
backwards.

The hook does **not** check the language and could not: what it measures is the
shape and the number.

Until now the commit rule lived here only as prose in `CLAUDE.md`, and prose is
what gets forgotten at the end of a long session. On 07/09/2026 the hooks were
enabled in 3 clones out of 58, and two repositories of the fleet were measurably
off the norm with nothing to say so.

Escape hatch, declared in both: `REPODOCS_NO_HOOK=1`. It exists so the hooks stay installed —
a guard with no declared bypass gets bypassed with `--no-verify`, which switches
off every guard at once. In a fresh clone, enable them with
`git config core.hooksPath tools/git-hooks`.

## 1.2.4 - COMMIT-RULE: the agent commits, and nothing is finished until it is committed

This repository's agent instructions never said who commits or when. That was
survivable while the COMMITTER skill was running the cycle; it is not now that
the skill is off across the fleet (03/09/2026), because nothing downstream
packages the work any more.

Adds the `COMMIT-RULE` echo block, whose single source is
[samirhvbr/repodocs `docs/versioning.md`](https://github.com/samirhvbr/repodocs/blob/master/docs/versioning.md#who-commits-and-when)
(ADR-016 there): the agent commits, nothing is reported as finished until it is
committed, one subject per commit, and a large delivery is split into blocks
grouped by subject. The block is delimited and regenerable, so a later
correction to the rule is one fleet pass rather than an archaeology.


## 1.2.3 - production state becomes a command, and the gitlink to an abandoned repo leaves the index

Findings **G-50**, **G-51** and **G-52** of the 01/09/2026 technical review.

### G-52 · the v8 → v9 rollout had no record of completion

The README states that production runs **v8, with a known bug in Code mode** (`num_ctx 4096`
→ silent truncation of 15-31k token requests), and no document in either repository says
"Phase 2 done on DD/MM". There are only two readings, and they are very different: either
the rollout happened and nobody recorded it, or **the oldest documented bug in the product
has been in production since July**.

**What could be measured from here** (02/09): the `.env` of the SHVIA-WEB development
checkout does not set `OLLAMA_PRESERVE_MODELFILE_SYSTEM`, so it defaults to `true` — the
pre-v9 behaviour. The GPU **could not be queried**: the host slot is empty in that `.env`,
which is a development one. Production state remains **unmeasured**, and that is written
down as such.

⚠️ **One commit in the log looks like a rollout record and is not.** `1.1.1 - num_ctx 32768:
produção registrada` (30/07) measured Ollama and the V100 driver in order to **justify 32768
in the v9 Modelfile** — it touches the Modelfile and the docs, not production. Reading only
the subject leads to the opposite conclusion; the commit body had to be opened.

**`scripts/estado-da-producao.sh`** answers the question in one command, against the real
machine. It measures **both** sides — the GPU's `num_ctx` and the app's switch — because a
half-done rollout is the worst state: each half looks right on its own. And it distinguishes
**"I did not measure" from "I measured and it is wrong"**, which is the confusion that turns
uncertainty into false certainty. All four verdicts were exercised against a fake Ollama, and
so were the two refusal paths (no host, unreachable host).

### G-50 · `IA-MODELFILES/` was a gitlink with no `.gitmodules`, pointing at a repo declared abandoned

Mode `160000` in the index and no `.gitmodules`: a `git clone` created the folder **empty**,
and the local content was invisible to git from outside. The folder does not even have a
`.git` inside — it is not so much as a nested checkout.

**Measured before removing it:** the **eleven** Modelfiles there already exist in this
repository, **byte for byte** (`modelfiles/archive/`, `modelfiles/shana/`,
`modelfiles/tools/`). The only unique files were `README.md` and `version.md` — belonging to
the OTHER repository. Removing the pointer lost nothing, and that is a `diff`'s conclusion,
not a reading's.

The gitlink left the index (`git rm --cached`) and the path entered `.gitignore` with the
reason. **The folder stays on disk** for whoever already had it: deleting it is the owner's
decision, not mine.

### G-51 · no `version.md`

The repository used the house convention in its commit messages (`1.1.1 - …`) and did not
have the file. The four commits since 1.1.1 went out with no version; this delivery resumes
at **1.2.3** because it brings a new capability (the measurement script).


## 1.2.2 - Agent doc: Releases rule and the English-only language rule

Marked echo of the single source at samirhvbr/repodocs. Two rules land here:

1. The `version.md` of the default branch ON GITHUB is what the GitHub Releases
   show, and a commit that bumps it is not finished until that version has a
   tag, a Release and the `Latest` badge — same push, not "later".
2. Everything in this repository is English (US): documents, commit messages,
   pull requests, issues, code comments. The only carve-out is end-user-facing
   product strings. History is not rewritten.

Delimited by a marker, so re-running replaces instead of duplicating.

## 1.2.1 - Regra de Releases no doc de agente: bump e Release sao um ato so

Eco marcado da norma unica em samirhvbr/repodocs (docs/versioning.md). O
`version.md` da branch padrao NO GITHUB e o que as Releases no GitHub mostram, e
um commit que bumpa o `version.md` nao esta terminado ate aquela versao ter tag,
Release e o badge `Latest`.

Bloco delimitado por marcador: rodar de novo substitui, nao duplica.

## [v9] — 2026-07-29 — MOTOR GENÉRICO (arquitetura em camadas)

**Mudança estrutural:** o Modelfile deixa de carregar a persona. Vira motor neutro; a persona Anna (Chat) e o protocolo de agente (Code) passam a ser injetados pelo app como `role:system` por requisição, e os fatos institucionais/de cliente migram para RAG.

- `num_ctx`: 4096 → **32768** (cobre as requisições reais de 15–31k do modo Code). Sustentado pelo ambiente registrado em produção 2026-07-30: **Ollama 0.32.3 + driver 580.173** → Flash Attention ativa no V100 (issue #15641 corrigido em ≥0.30) e KV q8_0 valendo; contingência se FA regredir: 16384 (comentários no arquivo + Fase 0 em docs/ARQUITETURA-CAMADAS.md).
- `repeat_penalty`: 1.10 → **1.0** (o default 1.1 do Ollama penaliza tokens estruturais de código).
- `temperature/top_k/top_p`: calibração oficial do Gemma 4 QAT (1.0/64/0.95) — a família se comporta mal em temperatura baixa; o app pode reduzir por modo via `options` (sem reload).
- Motivação completa: docs/DIAGNOSTICO-BUG-ANNA-CODE.md.
- **Requer mudanças no SHVIA-WEB** (dobra `foldSystemIntoFirstUser`, `options` por modo, `truncate:false`) — rollout sequenciado em docs/ARQUITETURA-CAMADAS.md.

## [v8] — produção atual (`ShvIA:latest`) — ⚠ bug conhecido

- SYSTEM do v7 + seção "SERVIDOR TERMINAL" (5 linhas coladas no fim, primeira tentativa de modo agêntico).
- **REGRESSÃO sem registro: `num_ctx` 16384 → 4096** (provável tentativa de caber na VRAM do V100 16GB). É a causa-raiz nº 1 do bug do modo Code: requisições de 15–31k tokens truncadas silenciosamente, sobra só a persona de suporte.
- `num_predict`: 2048 → -1 (ilimitado).

## [v7] — melhor SYSTEM da linhagem

- Reescrita completa e organizada da persona Anna em seções (IDENTIDADE / SOBRE A BLUE3 / OBJETIVOS / COMPORTAMENTO / PRECISÃO / SUPORTE TÉCNICO / RECOMENDAÇÕES / ESTILO / TRANSPARÊNCIA / REGRA MAIS IMPORTANTE).
- `num_ctx`: 8192 → 16384 (ponto alto da linhagem).
- `temperature`: 1.0 → 0.85 — e o comentário do v5 justificando a calibração QAT foi perdido nessa reescrita.
- Base da persona destilada em `personas/anna-blue3.md`.

## [v6] — primeira persona completa

- Primeiro SYSTEM "de verdade": prioridades de atendimento, protocolo de confiança ALTA/MÉDIA/BAIXA, listas de nunca-inventar, regras de estilo.
- Defeitos de colagem: regra-mestra enfiada no meio do bloco de confiança MÉDIA, typo "atendimentno", bullet órfão. Corrigidos na reescrita do v7.

## [v5] — troca de base: qwen3 → gemma4

- FROM `qwen3:14b` → `gemma4:26b-a4b-it-qat`.
- Porte correto: removeu o `/no_think` (hack específico do qwen3).
- `temperature`: 0.3 → 1.0 com comentário: *"recomendado pelo Google pra Gemma 4 — o QAT é calibrado pra temp 1.0"* (comentário depois perdido no v7).
- SYSTEM continuou esqueleto (seções vazias desde o v3).

## [v4] — rename

- Diff de 1 linha sobre o v3: persona "ShvIA" → "Anna". (Lição: mudança desse tamanho não justifica versão; registrar aqui.)

## [v3] — origem da linhagem ativa

- FROM `qwen3:14b`, `/no_think` embutido, temp 0.3, num_ctx 8192.
- SYSTEM esqueleto: seções "Como responder:" e "Segurança:" **vazias** (permaneceram vazias até o v6).
- Persona Blue3 + regra dura de precisão com vocabulário de assistente Linux (man/--help) — resíduo do prompt de terminal de onde nasceu (ver `archive/ShvIA_q3.Modelfile`, o "elo perdido").

---

## [Shana v2.2] — 2026-08-04 — persona com visão (prints de tela)

Requisito novo: a Shana precisa **interpretar prints de tela**. Isso redefine a base e o orçamento de VRAM. Alvo: Tesla V100 16GB.

- **FROM `gemma4:26b-a4b-it-qat` → `gemma4:12b-it-qat`.** O 26b **não cabe com visão ligada**: pesos 14,0 GB + projector CLIP 573M BF16 1,2 GB = **16,0 GB de pesos numa placa de 16 GB**. Os 15,2/16,4 GB medidos no v9 são leitura **só-texto** — o projector só carrega quando chega imagem, e o primeiro print estoura o cartão. O `12b-it-qat` custa 7,0 GB + 0,175 GB = **7,2 GB**, deixando ~7 GB de folga. Bônus: dense 11,9B ativa ~3x mais parâmetros por token que o MoE 26B-A4B (3,8B ativos) — melhor para raciocinar sobre a imagem. Perda aceita: vision tower menor (52,4M vs 573M).
- **Resolve o A/B pendente do v2.0/v2.1** (qwen3:14b vs gemma4:12b, lição 3 do README): vence a família **gemma4** por decisão de requisito, não de benchmark — o qwen3:14b não tem visão. Registrado aqui para não ficar mais um A/B sem resultado.
- `temperature/top_p/top_k`: 0.9/0.9/50 → **1.0/0.95/64** (blob `params` oficial publicado com o modelo). Os valores antigos eram herança da linhagem qwen3 — lição 2.
- `repeat_penalty`: 1.15 → **1.0** (desligado). 1.15 é mais agressivo até que o default 1.1 já criticado no v9; degradava transcrição de log/código e corroía os bordões da persona.
- `num_ctx`: 8192 → **32768**. Print widescreen vira vários tiles (o Gemma 4 aceita resolução e aspect ratio variáveis); 8k sumia em duas ou três imagens com histórico.
- `num_predict`: 512 → **-1**. O gemma4 é modelo *thinking* e os tokens de raciocínio saem do mesmo orçamento — repetição exata do bug do Shana v2.0 (qwen3 sem `/no_think`). `think` não é parâmetro de Modelfile: é campo de requisição da API (`/set nothink` no CLI).
- `num_batch` **512** explícito, para o 256 do ShvIA_v9 não ser copiado — lá é contingência de placa cheia, aqui há folga e o batch maior acelera o prompt processing das imagens.
- **Removidos os stops mortos** `<|end_of_text|>`, `<|eot_id|>` (llama) e `<|im_end|>` (ChatML) — lição 1, já flagrada para o v2.1 no README e copiada mesmo assim. Gemma fecha turno com `<end_of_turn>`, vindo do template da base.
- SYSTEM: header copiado do ShvIA_v9 (com definições em branco e instruções de rollout do `ShvIA:v9`) reescrito para a Shana; nova seção **"Prints e imagens"** obriga ler e transcrever literalmente antes do deboche, e proibe adivinhar texto ilegível.
- ⚠ **Inversão em relação ao ShvIA:** aqui o SYSTEM *é* o produto. Cliente que enviar `role:system` em `messages[0]` **apaga a Shana** (substituição total, `server/routes.go`). Consumir via `ollama run`, sem system próprio.
- Validação: a primeira rodada pós-`create` **tem que ser com print** — teste só-texto não prova que cabe. Depois `ollama ps` = "100% GPU".

---

## Linhagens paralelas (resumo — detalhes em modelfiles/README.md)

- **Anna v1.0→v2.4 + bk.Anna** (arquivada): linhagem de atendimento puro-closed-book. Do documento LGPD de 11 KB colado no SYSTEM (v1.0) até a máquina de recusa greedy (v2.2). Proibia código explicitamente — a semente cultural do bug. Pares A/B v2.3/v2.4 sem registro do vencedor.
- **Shana v1.0→v2.2**: persona pessoal. v1.0 tinha TEMPLATE que quebrava multi-turno e stops nos próprios bordões; v2.0 corrigiu; v2.1 abriu um A/B de base (qwen3 vs gemma4:12b) sem registro do vencedor — **fechado no v2.2** (gemma4, por causa do requisito de visão). v2.2 é a primeira da casa com multimodalidade e a primeira a dimensionar VRAM contando o projector.
- **Terminal (SShvTerm / ShvIA_qwen / ShvIA_qwen_2 / ShvIA_gpt)**: assistentes de shell. `ShvIA_qwen_2` (num_ctx 32768, diretivas limpas) é o melhor; `ShvIA_qwen` era duplicata e foi arquivado. `ShvIA_gpt` demonstrou porte correto de diretivas entre famílias.
- **Dev.Modelfile**: assistente da stack SHVIA sobre qwen2.5-coder — melhor candidato a modelo de código dedicado se o modo Code ganhar modelo próprio (papel `task`/`code` no model_roles do app).
