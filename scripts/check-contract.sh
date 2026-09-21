#!/usr/bin/env bash
# Verifica que os seis workflows ci-*.yml expõem contratos idênticos (ADR 0002).
#
# Divergência de contrato é tratada como bug: ela quebraria o IssueOps (Fase 2), que
# escolhe o arquivo por stack e preenche sempre os mesmos campos, e o CD (Fase 3),
# que consome sempre os mesmos outputs.
set -euo pipefail

cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

stacks=(dotnet java go node python react-ts)
ref=""
status=0

for s in "${stacks[@]}"; do
  f=".github/workflows/ci-${s}.yml"
  [ -f "$f" ] || { echo "❌ ausente: $f"; exit 1; }

  # Nome, tipo e default de cada input, além do nome de cada output. O default faz
  # parte do contrato: os seis workflows precisam evoluir juntos.
  {
    echo "== inputs =="
    yq e '.on.workflow_call.inputs | to_entries | .[] | .key + ":" + (.value.type // "string") + ":" + ((.value.default // "<unset>") | tostring)' "$f" | sort
    echo "== outputs =="
    yq e '.on.workflow_call.outputs | keys | .[]' "$f" | sort
  } > "$tmp/$s.txt"

  if [ -z "$ref" ]; then
    ref="$s"
  elif ! diff -q "$tmp/$ref.txt" "$tmp/$s.txt" > /dev/null; then
    echo "❌ ci-${s}.yml diverge do contrato de ci-${ref}.yml:"
    diff -u "$tmp/$ref.txt" "$tmp/$s.txt" | sed 's/^/     /'
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  n=$(grep -c ':' "$tmp/$ref.txt" || true)
  echo "✅ contrato idêntico nas ${#stacks[@]} stacks ($n entradas verificadas)"
fi
exit "$status"
