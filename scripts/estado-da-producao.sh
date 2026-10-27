#!/bin/bash
# O que a GPU está servindo AGORA, e o app está no comportamento v8 ou v9?
#
# Uso:
#   OLLAMA_HOST=http://servidor:11434 ./scripts/estado-da-producao.sh
#   SHVIA_WEB_ENV=/caminho/do/SHVIA-WEB/.env ./scripts/estado-da-producao.sh   # opcional
#
# ## Por que existe (achado G-52 da revisão de 01/09/2026)
#
# O README deste repo afirma que **produção roda o v8, com bug conhecido no modo Code**
# (`num_ctx 4096` → truncamento silencioso), e que o v9 "requer as mudanças no SHVIA-WEB e o
# rollout sequenciado". O CHANGELOG e o README param em 29-30/07, e **nenhum documento, nos
# dois repositórios, diz "Fase 2 feita em DD/MM"**.
#
# Só há duas leituras possíveis, e elas são muito diferentes:
#
#   1. o rollout aconteceu e ninguém registrou — a doc mente para o lado bom;
#   2. o rollout NÃO aconteceu — e o bug mais antigo documentado do produto está em
#      produção desde julho.
#
# Enquanto a pergunta não for respondida, ela reaparece em toda revisão. Este script a
# responde em um comando, contra a máquina de verdade, em vez de contra a memória de alguém.
#
# ⚠️ **Ele MEDE, não conserta.** Se a resposta for "v8 em produção", o rollout continua sendo
# trabalho de tamanho M, sequenciado, com a Fase 1 no SHVIA-WEB antes.
set -uo pipefail

HOST="${OLLAMA_HOST:-}"
MODELO="${MODELO:-ShvIA:latest}"
WEB_ENV="${SHVIA_WEB_ENV:-}"

if [[ -z "$HOST" ]]; then
  echo "estado-da-producao: defina OLLAMA_HOST (ex.: http://gpu.interna:11434)." >&2
  echo "                    Sem ele não há o que medir — e adivinhar é o que criou este achado." >&2
  exit 1
fi
HOST="${HOST%/}"

for dependency in curl jq; do
  command -v "$dependency" >/dev/null 2>&1 || {
    echo "estado-da-producao: falta $dependency — não foi possível medir." >&2
    exit 2
  }
done

echo "── GPU: $MODELO em $HOST"
REQUEST="$(jq -nc --arg model "$MODELO" '{model: $model}')" || exit 2
RESP="$(curl -sS -m 20 -w '\n%{http_code}' -H 'Content-Type: application/json' \
  "$HOST/api/show" -d "$REQUEST" 2>&1)" || {
  echo "   ✗ não consegui falar com a GPU. Rede? Porta? O serviço está de pé?" >&2
  exit 2
}

# curl succeeding means transport succeeded, not that /api/show returned model data.
HTTP_STATUS="${RESP##*$'\n'}"
RESP="${RESP%$'\n'*}"
case "$HTTP_STATUS" in
  2[0-9][0-9]) ;;
  *) echo "   ✗ /api/show respondeu HTTP $HTTP_STATUS — modelo não medido." >&2; exit 2 ;;
esac

# Read only the API's typed parameters, never context-looking text in prompts or error bodies.
# Slurp also rejects multiple JSON documents instead of silently accepting the last one.
DATA="$(printf '%s' "$RESP" | jq -sce '
  if length != 1 then error("expected one JSON object") else .[0] end
  | if type != "object" then error("expected an object") else . end
  | if has("error") then error("API error response") else . end
  | if (.parameters | type) != "string" then error("parameters must be a string") else . end
  | if has("system") and (.system | type) != "string" then error("system must be a string") else . end
  | if has("details") and (.details | type) != "object" then error("details must be an object") else . end
  | (.details // {}) as $details
  | if ($details | has("parent_model")) and ($details.parent_model | type) != "string"
    then error("parent_model must be a string") else . end
  | (.parameters | split("\n") | map(select(test("^[ \\t]*num_ctx([ \\t]|$)")))) as $context
  | if ($context | length) != 1 then error("num_ctx missing or ambiguous") else . end
  | ($context[0] | capture("^[ \\t]*num_ctx[ \\t]+(?<value>[1-9][0-9]*)[ \\t\\r]*$").value) as $num_ctx
  | {num_ctx: $num_ctx, compatible: (($num_ctx | tonumber) >= 32768),
     system: ((.system // "") | length > 0), parent_model: ($details.parent_model // "")}
')" || {
  echo "   ✗ resposta de /api/show inválida ou sem num_ctx configurado — modelo não medido." >&2
  exit 2
}
NUM_CTX="$(printf '%s' "$DATA" | jq -r '.num_ctx')"
TEM_SYSTEM="$(printf '%s' "$DATA" | jq -r 'if .system then "sim" else "não" end')"
BASE="$(printf '%s' "$DATA" | jq -r '.parent_model')"
COMPATIBLE="$(printf '%s' "$DATA" | jq -r '.compatible')"

echo "   num_ctx ............ ${NUM_CTX:-não reportado}"
echo "   SYSTEM no Modelfile  $TEM_SYSTEM"
[[ -n "$BASE" ]] && echo "   base ............... $BASE"

# ── O lado do app ───────────────────────────────────────────────────────────
# A Fase 1 do rollout exige `OLLAMA_PRESERVE_MODELFILE_SYSTEM=false`. O default do
# código é `true` (comportamento pré-v9), então NÃO estar no `.env` significa v8.
# "não medi" e "medi e está errado" são estados DIFERENTES, e confundi-los é o que
# transforma incerteza em falsa certeza — o defeito que este achado persegue.
MEDIU_APP=0
PRESERVE="(não medido)"
if [[ -n "$WEB_ENV" && -r "$WEB_ENV" ]]; then
  MEDIU_APP=1
  V="$(sed -n 's/^OLLAMA_PRESERVE_MODELFILE_SYSTEM=//p' "$WEB_ENV" | tail -1 | tr -d '"'"'"' \r')"
  PRESERVE="${V:-true (ausente do .env — vale o default do código)}"
fi
echo "── App: OLLAMA_PRESERVE_MODELFILE_SYSTEM = $PRESERVE"
[[ $MEDIU_APP -eq 0 ]] && echo "   (passe SHVIA_WEB_ENV=/caminho/do/SHVIA-WEB/.env para medir também este lado)"

# ── Veredito ────────────────────────────────────────────────────────────────
echo
if [[ "$COMPATIBLE" == true ]]; then
  echo "✅ O modelo reporta num_ctx ${NUM_CTX} — capacidade compatível com o v9."
  if [[ $MEDIU_APP -eq 0 ]]; then
    echo "   ⚠️ O lado do APP não foi medido, então isto ainda não é um veredito completo:"
    echo "      contexto amplo não confirma o modelo nem o comportamento do app."
    echo "      Rode de novo com SHVIA_WEB_ENV para medir também o preserve."
  else
    case "$PRESERVE" in
      false*) echo "   E o app está na Fase 1 (preserve=false). **Registre a data no README.**" ;;
      *)      echo "   ⚠️ Mas o app está em preserve=$PRESERVE: a persona do Modelfile continua" ;
              echo "      sendo dobrada. Rollout pela METADE — o pior estado, porque cada metade" ;
              echo "      parece certa sozinha." ;;
    esac
  fi
else
  echo "🔴 O modelo reporta num_ctx ${NUM_CTX} — abaixo dos 32768 esperados para o v9:"
  echo "   requisições de 15-31k tokens podem exceder esse contexto. Confira como o"
  echo "   app trata o limite: truncamento ou recusa dependem das opções da requisição."
  echo "   O contexto sozinho não identifica a versão. Ver docs/ARQUITETURA-CAMADAS.md §6."
fi
echo
echo "Seja qual for a resposta, ela precisa VIRAR REGISTRO no README deste repo e no"
echo "docs/INFRA do SHVIA-WEB, com data. Foi a ausência desse registro que criou o G-52."
