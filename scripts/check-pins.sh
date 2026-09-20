#!/usr/bin/env bash
# Garante que toda action de terceiro está fixada por SHA completo de commit.
#
# Tags são móveis: quem comprometer o repositório de uma action reescreve `v4` e passa a
# executar código arbitrário em todo pipeline que a referencia (pesquisa §5.2).
# Referências locais (./...) não precisam de pin: o código já está no workspace.
set -euo pipefail

cd "$(dirname "$0")/.."

status=0
while IFS= read -r line; do
  file="${line%%:*}"
  rest="${line#*:}"
  lineno="${rest%%:*}"
  ref=$(echo "$line" | sed -E 's/.*uses:[[:space:]]*//' | awk '{print $1}')

  case "$ref" in
    ./*) continue ;;                                   # action local
    docker://*) ;;                                     # imagem: versionada na própria tag
  esac

  if ! echo "$ref" | grep -qE '@[0-9a-f]{40}$'; then
    echo "❌ ${file}:${lineno} — não pinada por SHA: ${ref}"
    status=1
  fi
done < <(grep -rn --include='*.yml' --include='*.yaml' -E '^\s*(-\s+)?uses:' .github/workflows actions 2>/dev/null)

if [ "$status" -eq 0 ]; then
  n=$(grep -rh --include='*.yml' --include='*.yaml' -E '^\s*(-\s+)?uses:' .github/workflows actions | grep -vc 'uses:[[:space:]]*\./' || true)
  echo "✅ todas as ${n} referências a actions de terceiros estão pinadas por SHA"
fi
exit "$status"
