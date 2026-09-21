#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

git -C "$tmp" init -q
git -C "$tmp" config user.email test@example.invalid
git -C "$tmp" config user.name migration-test
mkdir -p "$tmp/src/Widget/Migrations"
printf '%s\n' 'initial' > "$tmp/src/Widget/Migrations/20260101000000_Initial.cs"
printf '%s\n' 'snapshot' > "$tmp/src/Widget/Migrations/WidgetModelSnapshot.cs"
git -C "$tmp" add .
git -C "$tmp" commit -qm base
base="$(git -C "$tmp" rev-parse HEAD)"

printf '%s\n' 'snapshot changed' > "$tmp/src/Widget/Migrations/WidgetModelSnapshot.cs"
git -C "$tmp" add .
git -C "$tmp" commit -qm snapshot-change
(cd "$tmp" && BASE_REF="$base" "$root/scripts/check-migrations-immutable.sh")

printf '%s\n' 'historical migration changed' > "$tmp/src/Widget/Migrations/20260101000000_Initial.cs"
git -C "$tmp" add .
git -C "$tmp" commit -qm migration-change
if (cd "$tmp" && BASE_REF="$base" "$root/scripts/check-migrations-immutable.sh") >/dev/null 2>&1; then
  echo "FAIL: alteração de migration histórica deveria reprovar." >&2
  exit 1
fi

echo "OK: ModelSnapshot pode mudar; migration histórica não pode."
