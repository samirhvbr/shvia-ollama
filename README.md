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
  (motor genérico, `num_ctx 16384`, calibração Gemma 4). **Requer as mudanças
  no SHVIA-WEB e o rollout sequenciado** de
  [docs/ARQUITETURA-CAMADAS.md §6](docs/ARQUITETURA-CAMADAS.md) — app primeiro,
  modelo depois.

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

Tesla V100-PCIE-16GB · Ollama systemd com `OLLAMA_KEEP_ALIVE=-1`,
`OLLAMA_MAX_LOADED_MODELS=1`, `OLLAMA_NUM_PARALLEL=1` · modelo base
`gemma4:26b-a4b-it-qat` (MoE 25.2B/3.8B ativos, QAT Q4_0, tool calling nativo).
Atenção: em Ollama ≤ ~0.2x, Flash Attention não ativa em Volta →
`OLLAMA_KV_CACHE_TYPE=q8_0` é ignorado (KV em f16); corrigido em ≥ ~0.30 com
driver 580.159+ (**conferir `ollama -v` em produção e registrar no CHANGELOG**).
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
