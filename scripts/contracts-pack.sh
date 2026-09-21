#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

project="examples/contracts/src/Contracts/Contracts.csproj"
version=""
output="${RUNNER_TEMP:-/tmp}/contracts-package"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) project="$2"; shift 2 ;;
    --version) version="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) echo "usage: $0 [--project path] --version MAJOR.MINOR.PATCH [--output dir]" >&2; exit 2 ;;
  esac
done

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Contracts package version must be MAJOR.MINOR.PATCH (without v)." >&2
  exit 2
}
[ -f "$project" ] || { echo "Contracts project not found: $project" >&2; exit 1; }

if grep -nE '<ProjectReference([[:space:]>]|=)' "$project"; then
  echo "Contracts.csproj must not reference domain or infrastructure projects." >&2
  exit 1
fi

mkdir -p "$output"
dotnet pack "$project" --configuration Release --output "$output" --nologo \
  -p:PackageVersion="$version" -p:Version="$version"

package="$output/TemplatePipeline.Contracts.$version.nupkg"
[ -f "$package" ] || { echo "Expected package was not produced: $package" >&2; exit 1; }

if unzip -p "$package" '*.nuspec' | grep -q '<dependency'; then
  echo "Contracts package unexpectedly contains project dependencies." >&2
  exit 1
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "package=$package" >> "$GITHUB_OUTPUT"
fi
echo "Packed immutable Contracts package: $package"
