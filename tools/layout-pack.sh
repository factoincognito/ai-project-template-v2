#!/usr/bin/env bash
# Lays out a language pack in a project directory, exactly as the README
# table "Creating a project from the template", step 2, says to by hand.
# Usage: bash tools/layout-pack.sh <node|web|python> <target-dir>
#
# Template-only: tools/ is not in bootstrap/manifest.txt. Used by
# .github/workflows/packs.yml to test each pack on a fresh project.
# The optional deploy files (web: deploy.yml, wrangler.jsonc) and
# code-standards.md are not laid out. Every other pack file must be in
# the table below, so a new pack file cannot be silently left out.
# PACKS_DIR overrides where the packs are read from (for tests).
set -euo pipefail

usage() { echo "usage: $0 <node|web|python> <target-dir>" >&2; exit 2; }
fail() { echo "layout-pack: $*" >&2; exit 1; }

[ "$#" -eq 2 ] || usage
PACK="$1"
OUT="$2"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKS_DIR="${PACKS_DIR:-$HERE/../languages}"

# Layout table: "<pack path> <project path>". A path ending in / is a
# folder, copied with everything in it.
COMMON="ci.yml .github/workflows/ci.yml
gitignore .gitignore
vscode-settings.json .vscode/settings.json
vscode-extensions.json .vscode/extensions.json"
TYPESCRIPT="package.json package.json
tsconfig.json tsconfig.json
biome.json biome.json"

case "$PACK" in
  node)
    TABLE="$COMMON
$TYPESCRIPT
placeholder.test.ts src/placeholder.test.ts"
    NOT_LAID_OUT="code-standards.md"
    ;;
  web)
    TABLE="$COMMON
$TYPESCRIPT
index.html index.html
vite.config.mts vite.config.mts
playwright.config.ts playwright.config.ts
starter/src/ src/
starter/e2e/ e2e/"
    NOT_LAID_OUT="code-standards.md deploy.yml wrangler.jsonc"
    ;;
  python)
    TABLE="$COMMON
pyproject.toml pyproject.toml
requirements.txt requirements.txt
requirements-dev.txt requirements-dev.txt
pre-commit-config.yaml .pre-commit-config.yaml
starter/src/ src/"
    NOT_LAID_OUT="code-standards.md"
    ;;
  *) fail "unknown pack: $PACK (expected node, web or python)" ;;
esac

SRC="$PACKS_DIR/$PACK"
[ -d "$SRC" ] || fail "pack folder not found: $SRC"

if [ -e "$OUT" ] && [ -n "$(ls -A "$OUT")" ]; then
  fail "target dir is not empty: $OUT"
fi

# Every table source must exist.
while read -r from _; do
  if [ "${from%/}" != "$from" ]; then
    [ -d "$SRC/$from" ] || fail "missing from the pack: $from"
  else
    [ -f "$SRC/$from" ] || fail "missing from the pack: $from"
  fi
done <<<"$TABLE"

# Every pack file must be in the table or in NOT_LAID_OUT.
while IFS= read -r f; do
  covered=""
  for skip in $NOT_LAID_OUT; do
    [ "$f" = "$skip" ] && covered=1
  done
  while read -r from _; do
    if [ "$f" = "$from" ]; then covered=1; fi
    case "$from" in */) case "$f" in "$from"*) covered=1 ;; esac ;; esac
  done <<<"$TABLE"
  [ -n "$covered" ] || fail "not in the layout table: $f"
done < <(cd "$SRC" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)

mkdir -p "$OUT"
while read -r from to; do
  if [ "${from%/}" != "$from" ]; then
    mkdir -p "$OUT/$to"
    cp -R "$SRC/$from." "$OUT/$to"
  else
    mkdir -p "$(dirname "$OUT/$to")"
    cp "$SRC/$from" "$OUT/$to"
  fi
done <<<"$TABLE"

echo "Laid out the $PACK pack in $OUT"
