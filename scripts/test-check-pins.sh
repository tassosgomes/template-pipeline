#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fixture_repo="$(mktemp -d)"
trap 'rm -rf -- "$fixture_repo"' EXIT

mkdir -p "$fixture_repo/.github/workflows" "$fixture_repo/actions/local" "$fixture_repo/scripts"
cp "$script_dir/check-pins.sh" "$fixture_repo/scripts/check-pins.sh"
chmod +x "$fixture_repo/scripts/check-pins.sh"

write_fixture() {
  local external_ref="${1:-}"

  {
    printf '%s\n' 'name: Pin fixture'
    printf '%s\n' 'on: [push]'
    printf '%s\n' 'jobs:'
    printf '%s\n' '  check:'
    printf '%s\n' '    runs-on: ubuntu-latest'
    printf '%s\n' '    steps:'
    printf '%s\n' '      - uses: docker://alpine:3.20'
    printf '%s\n' '      - uses: ./actions/local'
    if [ -n "$external_ref" ]; then
      printf '      - uses: %s\n' "$external_ref"
    fi
  } > "$fixture_repo/.github/workflows/fixture.yml"
}

write_fixture
if ! output=$("$fixture_repo/scripts/check-pins.sh" 2>&1); then
  printf '%s\n' "$output" >&2
  printf '%s\n' 'FAIL: referências docker:// e locais deveriam ser ignoradas.' >&2
  exit 1
fi

write_fixture 'example/unpinned-action@v1'
if output=$("$fixture_repo/scripts/check-pins.sh" 2>&1); then
  printf '%s\n' 'FAIL: action externa não pinada deveria reprovar.' >&2
  exit 1
fi

if ! grep -Fq 'example/unpinned-action@v1' <<< "$output"; then
  printf '%s\n' "$output" >&2
  printf '%s\n' 'FAIL: a saída não identificou a action externa não pinada.' >&2
  exit 1
fi

if grep -Fq 'docker://alpine:3.20' <<< "$output" || grep -Fq './actions/local' <<< "$output"; then
  printf '%s\n' "$output" >&2
  printf '%s\n' 'FAIL: a saída acusou uma referência que deveria ser ignorada.' >&2
  exit 1
fi

printf '%s\n' 'OK: check-pins ignora docker:// e actions locais, mas reprova action externa não pinada.'
