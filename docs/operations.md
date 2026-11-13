# Operating the ShvIA model definitions

Status: `ACTIVE`.

Reviewed November 5, 2026 against shvia-ollama `e1eb95a`, shvia-web `b24e45a5`
and shvia-code `7b5dd3f` (first written October 15 against `7e86446`, `25704dbc`
and `b872d8c`); the preserve-flag and `think` rows were re-read the same day against
shvia-web `2db8252a`. This is a source review, not live production acceptance.

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
| `OLLAMA_SYSTEM_PROMPT`, `OLLAMA_SYSTEM_PROMPT_FILE` | The application's persona text: the inline value wins; otherwise the file's contents. A missing or unreadable file yields an empty prompt rather than an error. Under v9 an empty value means the neutral fallback answers Chat without the Anna persona. |
| `OLLAMA_PRESERVE_MODELFILE_SYSTEM` | Defaults to `true`. It decides every call that does not override it, Chat and Code included. Enabled folds application system messages into the first user turn, so the Modelfile's own `SYSTEM` stays in force. Disabled merges the opening system messages into one, and that message, when there is one, replaces the Modelfile's `SYSTEM`. The driver accepts a per-request override, and seven machine callers always pass `false`, because their prompt is the whole task and the persona is noise: the domain judge (`DomainJudge`), the conversation roll-up (`RollUpConversation`), memory consolidation (`ConsolidateConversationMemory`), meeting minutes (`MeetingMinutesWriter`), the model tier (`RunModelTier`), metadata-filter inference (`MetadataFilterInferrer`) and the compare judge (`CompareJudgeService`). The flag does not describe those seven calls; every other caller follows it, the price extractor (`PriceExtractor`, whose system message is also a whole task) among them. |
| `OLLAMA_KEEP_ALIVE` | Defaults to empty: omit the request field and let the server decide. A configured numeric value is sent as a JSON number, not a duration string. |
| `OLLAMA_TRUNCATE_STRICT` | Defaults to `true`; sends top-level `truncate:false`. Context overflow is visible rather than silently truncated. |
| `OLLAMA_NUM_PREDICT`, `OLLAMA_NUM_PREDICT_MAX` | Every request sends `options.num_predict`: `8192` by default, or a caller's `max_tokens` clamped to `16384`; `0` sends nothing and leaves the Modelfile's `num_predict -1`. No Chat or Code caller passes a per-mode budget. |
| `OLLAMA_THINK`, `OLLAMA_THINKING_MODELS` | `think` is sent only when `OLLAMA_THINK` is set, or when the request carries an effort and the model is listed in `OLLAMA_THINKING_MODELS` (empty by default; an entry without `:tag`, such as `ShvIA`, matches every tag). On a listed model `low` sends `think:false` and any other effort sends `think:true`, overriding `OLLAMA_THINK`; on any other model the effort is ignored. The effort comes from the effort selector, a conversation's saved effort, a bot or project pin, or `AI_DEFAULT_EFFORT` when none of those is set; six of the seven machine callers named for the preserve flag pass `low`, and the compare judge passes the evaluator's own effort. Otherwise the model's own default applies. |
| Code loop nudge | A user turn, rather than a trailing system message. |
| `/code/chat` errors | Emit `message`, with `codigo` and integer `status` when available. |
| anna history | Client-side compaction by message count, and by estimated tokens when the gateway reports the target's context window (old tool outputs are pruned first). This is not proof that every prompt fits a model's context. |

These pieces already exist, although the older architecture page describes some
as work to build. Its per-mode output budgets (Chat 2048 / Code 4096) and its
retry-after-overflow sequence were not found in the reviewed Web source; treat them
as design material. Do not move retrieved text into system authority simply to
match a sample payload.

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

The script requires Bash, curl and `jq`. It calls `/api/show`, requires a 2xx response
and one JSON object without an API error, then validates the fields it reads. Context
comes only from one positive integer `num_ctx` declaration in the API's `parameters`
string. Template, system prompt and raw Modelfile text are not authoritative for
this measurement. It reports system-presence and parent model when provided and
prints a capacity compatibility hint. An authorized operator may additionally set
`SHVIA_WEB_ENV` to a readable application environment file; it reads only the
preserve flag. Do not copy credentials into this repository or diagnostic records.

| Exit | Meaning |
|---|---|
| `0` | Model context was measured, including when it is below `32768`; read the printed capacity/app caveats. |
| `1` | The required `OLLAMA_HOST` was not provided. |
| `2` | A dependency, transport, HTTP, API, JSON or field-validation failure prevented measurement, including absent, malformed or ambiguous `num_ctx`. |

Interpretation limits matter:

- The script reads a file, not Laravel's effective cached configuration or
  per-request overrides. An absent flag is interpreted using its coded default.
  The flag it reads decides only the calls that do not override it, Chat and Code
  among them; the seven machine callers that always pass `false` do not depend on it.
- A model without explicit `num_ctx` in `parameters` is unmeasured, even when the
  server could choose a default context for inference. The script does not infer
  that default from model architecture metadata or prompt text.
- A context size of at least `32768` means compatible capacity, not proof of v9
  identity; a smaller custom model is not necessarily v8.
- It does not verify full sampling, weights/digest, selected Web target, persona
  content, GPU fit or inference behavior. Its exit code is not an acceptance gate.

Record observations with a timestamp and explicit unknowns. The script's closing
lines still ask for the record to go into this repository's README; dated
observations now live in their own page under `docs/`, like the
[September record](rollout-observation-20260923.md), which is historical, not a
live probe.

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

Neither the October 15 nor the November 5 documentation review changed scripts or
Modelfile directives; the November 5 one corrected a comment in
`ShvIA_v9.Modelfile`. The diagnostic's HTTP/API/parse handling was corrected in
1.3.3 and checked with local HTTP fixtures. Remaining follow-ups:

1. Compare full model identity; a valid context capacity is not proof of v8/v9 identity.
2. Pin or record the resolved base digest for reproducible model builds; the build
   script currently pulls a mutable base tag on every invocation.
3. Resolve the existing placeholder in `tools/Dev.Modelfile` before using that
   variant, and review the family-specific directives recorded in the catalogue.

These are source findings, not confirmed failures in the currently deployed GPU.
