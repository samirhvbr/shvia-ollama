#!/bin/bash
# Cria/atualiza um modelo no Ollama a partir de um Modelfile deste repositório.
#
# Uso:
#   ./scripts/build.sh                                    # build padrão: v9 -> ShvIA:v9
#   ./scripts/build.sh modelfiles/active/ShvIA_v9.Modelfile ShvIA:latest
#   OLLAMA_HOST=http://servidor:11434 ./scripts/build.sh  # contra servidor remoto
#
# Promoção a produção (o app resolve por papéis/model_roles, a tag ShvIA:latest
# é a referência histórica — ver docs/ARQUITETURA-CAMADAS.md):
#   ./scripts/build.sh modelfiles/active/ShvIA_v9.Modelfile ShvIA:v9   # 1. build com tag de versão
#   # 2. teste (chat + modo Code com tarefa real)
#   ./scripts/build.sh modelfiles/active/ShvIA_v9.Modelfile ShvIA:latest  # 3. promove
set -euo pipefail

cd "$(dirname "$0")/.."

MODELFILE="${1:-modelfiles/active/ShvIA_v9.Modelfile}"
TAG="${2:-ShvIA:v9}"

[[ -f "$MODELFILE" ]] || { echo "ERRO: Modelfile não encontrado: $MODELFILE" >&2; exit 1; }

BASE=$(awk '/^FROM /{print $2; exit}' "$MODELFILE")
echo "==> Modelfile: $MODELFILE"
echo "==> Base:      $BASE"
echo "==> Tag:       $TAG"

# Garante a base local (no-op se já existir)
ollama pull "$BASE"

ollama create "$TAG" -f "$MODELFILE"

echo
echo "==> Modelo criado. Verificação de VRAM/contexto (rode após a 1ª inferência):"
echo "    ollama ps    # coluna PROCESSOR deve mostrar 100% GPU; SIZE = pesos+KV"
echo "    (se aparecer % em CPU, o num_ctx do Modelfile estourou a VRAM — ver docs/ARQUITETURA-CAMADAS.md)"
