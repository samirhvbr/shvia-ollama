# Rollout observation — September 23, 2026

Historical evidence copied from the README at commit `7e86446`. It was not repeated
on October 15, 2026. Host versions, aliases and application settings below are
observations for that date, not a statement about production today.

See the [current operating guide](operations.md) before planning another rollout.
The original mixed-language quotation is preserved as evidence.

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
