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

echo "── GPU: $MODELO em $HOST"
RESP="$(curl -sS -m 20 "$HOST/api/show" -d "{\"model\":\"$MODELO\"}" 2>&1)" || {
  echo "   ✗ não consegui falar com a GPU. Rede? Porta? O serviço está de pé?" >&2
  exit 2
}

# `num_ctx` pode vir dos parameters do Modelfile OU do template; procura nos dois.
NUM_CTX="$(printf '%s' "$RESP" | grep -oE '"?num_ctx"?[ :=]+[0-9]+' | grep -oE '[0-9]+$' | head -1)"
TEM_SYSTEM="não"
printf '%s' "$RESP" | grep -q '"system"[[:space:]]*:[[:space:]]*"..' && TEM_SYSTEM="sim"
BASE="$(printf '%s' "$RESP" | grep -oE '"parent_model"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)"

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
if [[ "${NUM_CTX:-0}" -ge 32768 ]]; then
  echo "✅ A GPU serve um modelo com num_ctx ${NUM_CTX} — compatível com o v9."
  if [[ $MEDIU_APP -eq 0 ]]; then
    echo "   ⚠️ O lado do APP não foi medido, então isto ainda não é um veredito completo:"
    echo "      um rollout pela metade (GPU no v9, app em preserve=true) é o pior estado,"
    echo "      porque cada metade parece certa sozinha. Rode de novo com SHVIA_WEB_ENV."
  else
    case "$PRESERVE" in
      false*) echo "   E o app está na Fase 1 (preserve=false). **Registre a data no README.**" ;;
      *)      echo "   ⚠️ Mas o app está em preserve=$PRESERVE: a persona do Modelfile continua" ;
              echo "      sendo dobrada. Rollout pela METADE — o pior estado, porque cada metade" ;
              echo "      parece certa sozinha." ;;
    esac
  fi
elif [[ -n "${NUM_CTX:-}" ]]; then
  echo "🔴 A GPU serve num_ctx ${NUM_CTX} — é o **v8**, com o bug conhecido do modo Code:"
  echo "   requisição real usa 15-31k tokens, o servidor trunca em silêncio e o modelo"
  echo "   'esquece' o começo sem ninguém ser avisado."
  echo "   O rollout NÃO aconteceu. Ver docs/ARQUITETURA-CAMADAS.md §6."
else
  echo "⚠️ A GPU não reportou num_ctx. Confira à mão: ollama show $MODELO"
fi
echo
echo "Seja qual for a resposta, ela precisa VIRAR REGISTRO no README deste repo e no"
echo "docs/INFRA do SHVIA-WEB, com data. Foi a ausência desse registro que criou o G-52."
