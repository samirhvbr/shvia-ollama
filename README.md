# SHVIA-OLLAMA

Modelfiles, personas e documentação de arquitetura dos modelos Ollama do
ecossistema ShvIA (Blue3). Este repositório define **o motor** — o
comportamento por modo (Chat/Code) e os fatos vivem nas camadas do app e do
RAG (ver [docs/ARQUITETURA-CAMADAS.md](docs/ARQUITETURA-CAMADAS.md)).

## TL;DR

- **In production:** `ShvIA:latest` is the **v9** engine — `num_ctx 32768`, calibrated for
  Gemma 4 — and has been **since 2026-07-30**. Measured on 2026-09-23 (below).
- 🔴 **But the app side is still pre-v9** (`preserve_modelfile_system = true`), so the rollout
  of [docs/ARQUITETURA-CAMADAS.md §6](docs/ARQUITETURA-CAMADAS.md) is **half done** — the
  worst state, because each half looks right on its own.

> ### 📍 Rollout state — MEASURED 2026-09-23 against the real machines
>
> Measured from the app server (`shvia-site`), which reaches the GPU the app actually uses
> (`srv1`); the GPU host itself refuses this machine's key, so it was read through the app,
> exactly as production reads it.
>
> **The model side — v9, since 2026-07-30.** `ollama show ShvIA:latest` returns:
>
> ```
> num_batch 256 · num_ctx 32768 · num_predict -1 · repeat_penalty 1
> temperature 1 · top_k 64 · top_p 0.95 · SYSTEM present · modified 2026-07-30
> ```
>
> That matches `ShvIA_v9.Modelfile` parameter for parameter, and **not** v8 (which would be
> `num_ctx 4096`, `repeat_penalty 1.10`, `temperature 0.85`, no `num_batch`).
>
> **The app side — still pre-v9.** In production (`/srv/shvia`, at `2.110.433`):
> `ollama.preserve_modelfile_system = true`, `ollama.truncate_strict = true`.
>
> 🔴 **What that combination costs.** With `preserve=true` the driver **folds** the app's system
> message into the first user turn and keeps the Modelfile's SYSTEM in force. Under v8 that
> SYSTEM was the Anna persona, so preserving it made sense. **Under v9 the Modelfile's SYSTEM is
> the neutral fallback** — so today the Code-mode protocol reaches the model **without system
> authority**, which is precisely the gain Phase 1 was meant to deliver.
>
> ✅ **What it does NOT cost:** `truncate:false` (on since 2026-08-08) is safe. With
> `num_ctx 32768`, Code requests of 15–31k tokens fit; the hard-400-at-4k scenario that
> `ARQUITETURA-CAMADAS.md` warned about does not happen.
>
> ⚠️ **The 2026-09-02 note here was wrong, and in the direction that matters.** It said the
> commit `1.1.1 - num_ctx 32768: produção registrada (30/07)` *"looks like a rollout record and
> is not"*. **It was one:** the model on the GPU was modified that same day and serves exactly
> that engine. The note read the commit's diff (it only touched the v9 Modelfile and docs) and
> concluded nothing happened on the machine — but `ollama create` leaves no trace in a repo.
> **A repository cannot prove what a server does; only the server can.** That is the whole
> reason `scripts/estado-da-producao.sh` exists, and it is the command that settled this.
>
> **Closing the rollout** is one line in production — `OLLAMA_PRESERVE_MODELFILE_SYSTEM=false`
> in `/srv/shvia/.env` — and it is a production act, so it is the owner's call.

```bash
> OLLAMA_HOST=http://<gpu>:11434 SHVIA_WEB_ENV=/caminho/SHVIA-WEB/.env \
>   ./scripts/estado-da-producao.sh
> ```
>
> Ele mede os **dois** lados — o `num_ctx` que a GPU serve e o interruptor do app — porque um
> rollout pela metade é o pior estado: cada metade parece certa sozinha. E ele distingue
> "não medi" de "medi e está errado".
>
> **Seja qual for a resposta, ela precisa virar registro aqui e no `docs/INFRA` do
> SHVIA-WEB, com data.** Foi a ausência desse registro que criou este achado — e enquanto
> ela durar, a doc afirma que produção roda um modelo com bug conhecido desde julho.

```bash
./scripts/build.sh                       # cria ShvIA:v9 a partir do Modelfile v9
./scripts/build.sh <Modelfile> <tag>     # build de qualquer outro
```

## Estrutura

```
├── modelfiles/
│   ├── README.md        ← catálogo completo (status e defeitos de cada versão)
│   ├── active/          ← produção (v8) + próxima (v9). Nada além disso.
│   ├── tools/           ← assistentes utilitários (Dev, terminal)
│   ├── shana/           ← persona pessoal
│   └── archive/         ← superseded (não usar; motivo documentado no catálogo)
├── personas/
│   └── anna-blue3.md    ← persona Anna destilada (camada do app) + fatos p/ RAG
├── docs/
│   ├── DIAGNOSTICO-BUG-ANNA-CODE.md   ← por que a Anna ignorava o modo Code
│   └── ARQUITETURA-CAMADAS.md         ← motor/persona/RAG + integração + rollout
├── scripts/
│   ├── build.sh         ← ollama create + verificação de VRAM
│   └── atlz.sh          ← pull do modelo base
└── CHANGELOG.md         ← histórico das versões (manter atualizado!)
```

## As 3 camadas (resumo)

| Camada | Mora onde | Conteúdo |
|---|---|---|
| **Motor** | Modelfile (`ShvIA:v9`) | Base, sampling, `num_ctx`, SYSTEM neutro de fallback |
| **Comportamento** | App, `role:system` na posição 0 por modo | Chat: persona Anna · Code: protocolo do agente (`anna`/project.rs) |
| **Fatos** | RAG (blue3-kb) + lookup CRM | Institucional Blue3, planos, LGPD; dados do cliente por sessão |

Por que assim: o SYSTEM do Modelfile é a única coisa que **sempre sobrevive** ao
truncamento do Ollama, e mensagens antigas são as primeiras descartadas. Persona
no Modelfile + protocolo como texto de user = exatamente o bug do v8. Detalhes e
fontes (código do Ollama) no [diagnóstico](docs/DIAGNOSTICO-BUG-ANNA-CODE.md).

## Servidor (referência)

Tesla V100-PCIE-16GB · **Ollama 0.32.3 + driver 580.173.02** (registrado
2026-07-30) · systemd com `OLLAMA_KEEP_ALIVE=-1`, `OLLAMA_MAX_LOADED_MODELS=1`,
`OLLAMA_NUM_PARALLEL=1` · modelo base `gemma4:26b-a4b-it-qat` (MoE 25.2B/3.8B
ativos, QAT Q4_0, tool calling nativo). Nessa combinação Flash Attention está
ativa no V100 (issue #15641 corrigido em ≥0.30) e o `OLLAMA_KV_CACHE_TYPE=q8_0`
vale — é o que sustenta o `num_ctx 32768` da v9. Em Ollama ≤0.2x FA ficava OFF
(KV f16) e o teto seria 16384 — reavaliar a cada upgrade/downgrade.
Dimensionamento e validação: comentários do
[ShvIA_v9.Modelfile](modelfiles/active/ShvIA_v9.Modelfile) e Fase 0 do rollout.

## Regras de manutenção deste repo

1. Toda mudança de Modelfile ganha entrada no [CHANGELOG.md](CHANGELOG.md) —
   inclusive resultado de testes A/B e motivo de trocas de FROM/parâmetro
   (a linhagem já perdeu 3 decisões por não registrar).
2. Ao trocar o FROM de família (qwen ↔ gemma ↔ llama ↔ gpt-oss), revisar TODAS
   as diretivas de SYSTEM (`/no_think`, `Reasoning:`), stops e sampling — as
   6 lições recorrentes estão no [catálogo](modelfiles/README.md).
3. Nunca versionar placeholder `[PREENCHA...]` em SYSTEM que vá para produção.
4. `active/` contém no máximo 2 arquivos: o que roda e o que vem a seguir.
