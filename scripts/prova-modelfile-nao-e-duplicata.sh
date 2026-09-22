#!/usr/bin/env bash
#
# No two Modelfiles are byte-identical, unless a line in the allowlist says why.
#
# Exit codes follow the house convention: 0 clean · 1 found one · 2 could not measure.
#
# ## Why this exists (measured 2026-09-22, `f154`)
#
# `modelfiles/shana/Shana-v2.3.Modelfile` was a byte-for-byte copy of v2.2. It had one
# commit in its whole history — `1ebc20e "Nova versao"` — and it was ALREADY identical to
# v2.2 in that commit, so nothing of its own was ever overwritten. It was born a copy.
#
# It cost two things. Whoever promoted "v2.3" believed they were shipping a change and
# shipped v2.2. And the catalogue stopped at v2.2, so the repository disagreed with its
# own directory listing with nothing to notice it.
#
# ⚠️ **An allowlist, not a blanket ban**, because one duplicate here is DELIBERATE and
# documented: `archive/ShvIA_qwen.Modelfile` is the archived byte-copy of
# `tools/SShvTerm.Modelfile`, and both the catalogue and the CHANGELOG say so. A guard
# that cannot tell a declared duplicate from an accidental one gets switched off.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

LISTA="modelfiles/duplicatas-declaradas.txt"

command -v md5sum >/dev/null 2>&1 || { echo "prova-modelfile: no md5sum — did not measure." >&2; exit 2; }
[ -d modelfiles ] || { echo "prova-modelfile: no modelfiles/ — did not measure." >&2; exit 2; }
[ -f "$LISTA" ] || { echo "prova-modelfile: no $LISTA — did not measure." >&2; exit 2; }

# ⚠️ `\.Modelfile$` and NOT `grep -i modelfile`: the directory is called `modelfiles/`,
# so a name filter matches every path inside it — the first version of this ruler was
# sweeping `modelfiles/README.md` and this ruler's own allowlist, reported 26 files where
# there are 24, and would have called two identical DOCS a duplicate Modelfile.
# Measured 2026-09-22: every tracked Modelfile in this repository ends in `.Modelfile`,
# and none lives outside `modelfiles/`.
mapfile -t ARQUIVOS < <(git ls-files | grep -E '\.Modelfile$' | sort)
if [ "${#ARQUIVOS[@]}" -eq 0 ]; then
    echo "prova-modelfile: no tracked Modelfile — did not measure." >&2
    exit 2
fi

# Declared pairs, normalised to "a|b" with the two paths sorted, so the order a line is
# written in does not matter.
declare -A DECLARADO=()
while IFS= read -r linha; do
    linha="${linha%%#*}"
    linha="$(printf '%s' "$linha" | xargs || true)"
    [ -z "$linha" ] && continue
    # shellcheck disable=SC2086
    set -- $linha
    [ "$#" -eq 2 ] || { echo "prova-modelfile: bad line in $LISTA: $linha" >&2; exit 2; }
    chave="$(printf '%s\n%s\n' "$1" "$2" | sort | paste -sd'|' -)"
    DECLARADO["$chave"]=1
done < "$LISTA"

declare -A VISTO=()
ACHADOS=0

for f in "${ARQUIVOS[@]}"; do
    h="$(md5sum "$f" | cut -d' ' -f1)"
    if [ -n "${VISTO[$h]:-}" ]; then
        chave="$(printf '%s\n%s\n' "${VISTO[$h]}" "$f" | sort | paste -sd'|' -)"
        if [ -z "${DECLARADO[$chave]:-}" ]; then
            echo "🔴 byte-identical and not declared:"
            echo "     ${VISTO[$h]}"
            echo "     $f"
            ACHADOS=$((ACHADOS + 1))
        fi
    else
        VISTO[$h]="$f"
    fi
done

echo "prova-modelfile: ${#ARQUIVOS[@]} Modelfile(s), ${#DECLARADO[@]} declared duplicate(s), $ACHADOS undeclared."

if [ "$ACHADOS" -gt 0 ]; then
    echo "   A new version that differs from the old one in nothing is not a version." >&2
    echo "   Either give it its own content, delete it, or declare the pair in $LISTA." >&2
    exit 1
fi
