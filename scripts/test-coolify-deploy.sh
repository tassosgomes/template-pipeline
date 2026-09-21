#!/usr/bin/env bash
set -euo pipefail

action_dir="$(cd "$(dirname "$0")/.." && pwd)"
validation="$(yq e -r '.runs.steps[0].run' "$action_dir/actions/coolify-deploy/action.yml")"

check() {
  local image="$1" expected="$2" output
  output="$(mktemp)"
  if IMAGE_REF="$image" GITHUB_OUTPUT="$output" bash -c "$validation" >/dev/null 2>&1; then
    [ "$expected" = pass ] || { echo "unexpectedly accepted: $image" >&2; rm -f "$output"; return 1; }
  else
    [ "$expected" = fail ] || { echo "unexpectedly rejected: $image" >&2; rm -f "$output"; return 1; }
  fi
  rm -f "$output"
}

check 'ghcr.io/acme/orders@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' pass
check 'ghcr.io/acme/orders:latest' fail
check 'ghcr.io/acme/orders@sha256:deadbeef' fail
echo 'OK: Coolify aceita somente referências por digest e rejeita latest.'
