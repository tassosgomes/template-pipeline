#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
resolver="$(yq e -r '.runs.steps[0].run' "$root/actions/resolve-version/action.yml")"

run_case() {
  local ref="$1" service="$2" expected_version="$3" expected_service="$4" output
  output="$(mktemp)"
  GITHUB_REF="$ref" REQUESTED_SERVICE="$service" GITHUB_OUTPUT="$output" bash -c "$resolver" >/dev/null
  grep -qx "version=$expected_version" "$output"
  grep -qx "service-name=$expected_service" "$output"
  rm -f "$output"
}

run_case refs/tags/identity/v1.2.3 '' v1.2.3 identity
run_case refs/tags/v2.0.0 orders v2.0.0 orders

output="$(mktemp)"
if GITHUB_REF=refs/tags/identity/not-semver REQUESTED_SERVICE='' GITHUB_OUTPUT="$output" bash -c "$resolver" >/dev/null 2>&1; then
  echo 'malformed service tag was accepted' >&2
  rm -f "$output"
  exit 1
fi
rm -f "$output"
echo 'OK: versionamento por serviço e rejeição de tag malformada.'
