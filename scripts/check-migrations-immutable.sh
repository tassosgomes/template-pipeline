#!/usr/bin/env bash
# Reprova alterações, remoções ou renomeações de migrations já existentes na base.
# ModelSnapshot é excluído porque ele é reescrito quando uma migration nova é criada.
set -euo pipefail

BASE_REF="${BASE_REF:-origin/main}"

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "error: BASE_REF '$BASE_REF' não existe neste checkout." >&2
  echo "Defina BASE_REF para a branch/ref da base antes de executar o gate." >&2
  exit 2
fi

changed="$(git diff --name-status --diff-filter=MDR "$BASE_REF...HEAD" -- '*Migrations/*' \
  | grep -v 'ModelSnapshot\.cs$' || true)"

if [ -n "$changed" ]; then
  echo "error: migrations existentes em $BASE_REF foram alteradas, removidas ou renomeadas:" >&2
  echo "$changed" >&2
  echo >&2
  echo "Uma migration aplicada é imutável; crie uma nova migration corretiva." >&2
  exit 1
fi

echo "ok: nenhuma migration existente em $BASE_REF foi alterada."
