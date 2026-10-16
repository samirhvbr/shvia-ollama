# Operating the ShvIA model definitions

Reviewed October 15, 2026 against shvia-ollama `7e86446`, shvia-web `25704dbc`
and shvia-code `b872d8c`. This is a source review, not live production acceptance.

## Ownership and the application contract

The Modelfile supplies base weights, context and sampling defaults, plus a fallback
system prompt. The Web application supplies Chat persona or the Code protocol;
retrieved documents are contextual data. Tool definitions and the agent loop are
application/CLI responsibilities. A neutral model tag alone does not deliver the
complete Chat/Code integration.

In the reviewed Web source (`config/ollama.php` and
`app/Services/AI/Drivers/OllamaDriver.php`):

| Setting or path | Current implementation |
|---|---|
| `OLLAMA_PRESERVE_MODELFILE_SYSTEM` | Defaults to `true`; callers can override per request. Enabled folds application system messages into the first user turn. Disabled merges opening system messages. |
| `OLLAMA_KEEP_ALIVE` | Defaults to empty: omit the request field and let the server decide. A configured numeric value is sent as a JSON number, not a duration string. |
| `OLLAMA_TRUNCATE_STRICT` | Defaults to `true`; sends top-level `truncate:false`. Context overflow is visible rather than silently truncated. |
| Code loop nudge | A user turn, rather than a trailing system message. |
| `/code/chat` errors | Emit `message`, with `codigo` and integer `status` when available. |
| anna history | Client-side message-count compaction exists; this is not proof that every token-sized prompt fits a model's context. |

These pieces already exist, although the older architecture page describes some
as work to build. Its per-mode output budgets and retry-after-overflow sequence
remain design material unless verified in the owning implementation. Do not move
retrieved text into system authority simply to match a sample payload.

Model selection also depends on request/user preferences, model roles, configured
host defaults and server availability. Updating a tag or one environment variable
does not prove all consumers switched. Inspect the effective target in the Web
application's own operational workflow.

## Build and verify

Run from the repository root. `scripts/build.sh [Modelfile] [tag]` resolves its
working directory there, pulls the first `FROM` base, then runs `ollama create`.
Defaults are the v9 definition and `ShvIA:v9`. `scripts/atlz.sh` only pulls
`gemma4:26b-a4b-it-qat`; it does not update custom tags or application routing.

Keep the currently serving tag intact and build a separate candidate. Record the
candidate's resolved base/digest and full definition; a mutable `FROM` tag can
resolve to different weights later even when this repository commit is unchanged.

After a first inference, inspect `ollama show <tag>`, `ollama ps`, GPU memory and
service logs. Exercise Chat persona, actual Code tool calls, long history,
overflow behavior and any image path the selected model must support. The v9
hardware comments document a past V100 configuration; memory fit and runtime
compatibility need measurement on the target host. The historical Shana catalogue
specifically records that a text-only fit does not prove a vision fit.

## Observe without promoting

For the model side only:

```bash
OLLAMA_HOST=http://127.0.0.1:11434 MODELO=ShvIA:v9 \
  ./scripts/estado-da-producao.sh
```

The script calls `/api/show`, extracts context, system-presence and parent model,
and prints a compatibility hint. An authorized operator may additionally set
`SHVIA_WEB_ENV` to a readable application environment file; it reads only the
preserve flag. Do not copy credentials into this repository or diagnostic records.

Interpretation limits matter:

- The script reads a file, not Laravel's effective cached configuration or
  per-request overrides. An absent flag is interpreted using its coded default.
- It uses text matching, not full response validation, and does not use curl's
  HTTP-failure flag. Missing fields or an API error body can end with exit `0`.
- A context size of at least `32768` means compatible capacity, not proof of v9
  identity; a smaller custom model is not necessarily v8.
- It does not verify full sampling, weights/digest, selected Web target, persona
  content, GPU fit or inference behavior. Its exit code is not an acceptance gate.

Record observations with a timestamp and explicit unknowns. The
[September record](rollout-observation-20260923.md) is historical, not a live probe.

## Promotion and rollback

Promotion is an operator action after candidate acceptance. Preserve the actual
serving model under a distinct backup tag and record the effective application
routing before replacing any alias. The file called v8 is not necessarily what
`ShvIA:latest` points to; the September observation already showed that alias on v9.

Change application routing/configuration through the Web runbook, refresh its
configuration cache as required, then repeat Chat and Code acceptance through the
application. Check explicit user model choices and all relevant model roles, not
only the host default. This documentation review performs none of those actions.

To roll back, restore the recorded tag/digest and routing/configuration together,
then repeat acceptance. Switching the preserve flag alone restores only folding
behavior; it does not restore weights, persona material or routing. Do not delete
a tag until confirming no application or user still selects it.

## Code findings awaiting a decision

No scripts or Modelfiles were changed by this review. Suggested follow-ups:

1. Make `estado-da-producao.sh` distinguish HTTP/API/parse failures with nonzero
   exits and compare full identity instead of equating context size with v8/v9.
2. Pin or record the resolved base digest for reproducible model builds; the build
   script currently pulls a mutable base tag on every invocation.
3. Resolve the existing placeholder in `tools/Dev.Modelfile` before using that
   variant, and review the family-specific directives recorded in the catalogue.

These are source findings, not confirmed failures in the currently deployed GPU.
