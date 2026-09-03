# SHVIA-OLLAMA

Modelfiles, personas e documentação de arquitetura dos modelos Ollama do
ecossistema ShvIA (Blue3). Este repositório define **o motor** — o
comportamento por modo (Chat/Code) e os fatos vivem nas camadas do app e do
RAG (ver [docs/ARQUITETURA-CAMADAS.md](docs/ARQUITETURA-CAMADAS.md)).

## TL;DR

- **Produção atual:** `ShvIA:latest` ← `modelfiles/active/ShvIA_v8.Modelfile`
  (persona Anna no Modelfile, `num_ctx 4096`) — **com bug conhecido no modo
  Code** ([diagnóstico](docs/DIAGNOSTICO-BUG-ANNA-CODE.md)).
- **Próxima produção:** `ShvIA:v9` ← `modelfiles/active/ShvIA_v9.Modelfile`
  (motor genérico, `num_ctx 32768`, calibração Gemma 4). **Requer as mudanças
  no SHVIA-WEB e o rollout sequenciado** de
  [docs/ARQUITETURA-CAMADAS.md §6](docs/ARQUITETURA-CAMADAS.md) — app primeiro,
  modelo depois.

> ### 📍 Estado do rollout — medido em 02/09/2026 (achado G-52)
>
> **Não há registro de conclusão em nenhum dos dois repositórios**, e o que se pôde medir
> desta máquina aponta para o rollout **não ter acontecido**:
>
> - o `.env` do checkout de desenvolvimento do SHVIA-WEB **não define**
>   `OLLAMA_PRESERVE_MODELFILE_SYSTEM` nem `OLLAMA_SYSTEM_PROMPT_FILE`, então vale o default
>   do código — `preserve_modelfile_system = true`, o comportamento **pré-v9**;
> - a GPU **não pôde ser consultada daqui**: o slot `OLLAMA_REMOTE_HOST_1` está vazio nesse
>   `.env`, que é de desenvolvimento. O estado da produção segue **não medido**.
>
> ⚠️ **Um commit do log parece um registro de rollout e não é.** O `1.1.1 - num_ctx 32768:
> produção registrada (30/07)` mediu a versão do Ollama e o driver do V100 para **justificar
> o 32768 no Modelfile v9** — ele muda `ShvIA_v9.Modelfile` e docs, não a produção. Ler só o
> título do commit leva à conclusão oposta.
>
> **Para responder de vez, um comando:**
>
> ```bash
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
