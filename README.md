# SHVIA-OLLAMA

Versioned Ollama Modelfiles, persona material and model rollout records for ShvIA.
This repository supplies model definitions. The Web gateway selects targets and
assembles requests; the anna CLI and Workspace own their agent execution. This
repository does not implement those applications or an inference server.

## Start here

- [Operating guide](docs/operations.md): prerequisites, local builds, application
  contract, verification, promotion and rollback boundaries.
- [Modelfile catalogue](modelfiles/README.md): every definition and known lineage issue.
- [Layered architecture](docs/ARQUITETURA-CAMADAS.md): the original design and rollout
  sequence, with a current-state notice distinguishing completed work from proposals.
- [September 23 rollout observation](docs/rollout-observation-20260923.md): dated
  production evidence, preserved without treating it as today's deployment state.
- [Code-mode diagnosis](docs/DIAGNOSTICO-BUG-ANNA-CODE.md): historical root-cause analysis.
- [Anna persona material](personas/anna-blue3.md): application persona and knowledge
  source material; its presence here does not prove an application loads it.

## Current repository state

Reviewed on October 26, 2026 against source commit `ca27c31` (repository version
`1.3.2`). There are **24 tracked Modelfiles**: 2 in `active/`, 4 in `tools/`, 3 in
`shana/`, and 15 in `archive/`. The repository version describes this collection;
it is separate from model tags such as `ShvIA:v9` and the installed Ollama version.

`modelfiles/active/ShvIA_v9.Modelfile` is the default build input. It uses
`gemma4:26b-a4b-it-qat`, a neutral fallback system prompt, `num_ctx 32768`,
`num_batch 256`, `num_predict -1`, temperature `1.0`, top-k `64`, top-p `0.95`
and repeat penalty `1.0`. v8 remains available as a historical definition with the
Anna persona embedded and `num_ctx 4096`. A file in `active/` does not prove that
its model is loaded on a server.

The last production measurement committed here is from **September 23, 2026**:
`ShvIA:latest` matched v9, while the application still preserved the Modelfile
system prompt. This review did not access a GPU host, change application settings,
create a model, run inference or revalidate that observation.

## Build a separate candidate

Requires Bash, an installed Ollama CLI, access to the selected Ollama server and
sufficient model storage/memory. These commands download model data and create
or replace the named tag on the server selected by `OLLAMA_HOST`:

```bash
./scripts/build.sh modelfiles/active/ShvIA_v9.Modelfile ShvIA:v9-candidate
```

Choose a candidate tag that is not already serving traffic. With no arguments,
the script instead uses the same v9 input and writes `ShvIA:v9`. The script
pulls the base and runs `ollama create`; its final VRAM lines are instructions
for a human, not an automated GPU or acceptance test. See the operating guide
before promotion.

## Repository map

| Path | Responsibility |
|---|---|
| `modelfiles/active/` | v9 engine and retained v8 definition |
| `modelfiles/tools/` | developer and terminal model variants |
| `modelfiles/shana/` | separate personal persona lineage |
| `modelfiles/archive/` | superseded definitions, retained for comparison |
| `personas/` | persona and knowledge material for application integration |
| `scripts/build.sh` | pull base, create the selected tag |
| `scripts/atlz.sh` | pull only the fixed Gemma base; does not rebuild custom tags |
| `scripts/estado-da-producao.sh` | limited read-only model/application observation |
| `scripts/prova-modelfile-nao-e-duplicata.sh` | check tracked definitions against the declared duplicate list |
| `.github/workflows/ci.yml` | run `scripts/prova-*.sh` on PRs and master pushes |

## Validation and contributions

Use Bash 4+ and GNU `md5sum` for the duplicate ruler (the macOS system Bash is
insufficient). Run:

```bash
bash scripts/prova-modelfile-nao-e-duplicata.sh
bash -n scripts/build.sh scripts/atlz.sh scripts/estado-da-producao.sh
```

The ruler reads tracked `*.Modelfile` paths and compares their bytes against
`modelfiles/duplicatas-declaradas.txt`. Untracked files are outside its coverage;
a pass does not establish valid Modelfile syntax or semantic differences between
models. CI runs all `scripts/prova-*.sh` (currently this ruler); it does not
exercise Ollama, GPU fit, Chat/Code quality or deployed settings. Record acceptance separately with date, model tag,
base, parameters, runtime/driver, application revision and measured outcomes.

Follow [agent instructions](AGENTS.md) and [the changelog](CHANGELOG.md). Changes,
including documentation, bump `version.md` in the same commit and use
`X.Y.Z - description in English (US)`. A PR is reviewed before landing; a repository
release does not create or deploy an Ollama model.

For model-definition changes, record base/parameter choices and A/B outcomes in
the changelog. Review system directives, stop tokens and sampling whenever the
base family changes; never promote an unresolved placeholder. Keep at most the
current and candidate definitions in `active/`, with superseded definitions and
their reasons in the catalogue/archive. These maintenance rules do not identify
the model currently serving production.
