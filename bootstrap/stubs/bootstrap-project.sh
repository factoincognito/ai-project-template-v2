#!/usr/bin/env bash
# bootstrap-project.sh: sets up a new project from this bootstrapper.
# Spec: "Turn-key bootstrap script" in
# https://github.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG.md
#
# Built so far: the layout-pack subcommand only.
#
# Usage:
#   bash bootstrap-project.sh layout-pack <node|web|python|react-native> <target-dir>
#     Lays out a language pack in <target-dir>, which must be empty or
#     absent. The packs are read from PACKS_DIR, by default the
#     languages/ folder next to this script.
#
# Exit codes: 0 done, 1 failed, 2 usage error or unknown pack.
# Runs on bash 3.2 (macOS /bin/bash): no associative arrays, no mapfile,
# no ${var,,}.
set -euo pipefail

usage() {
  echo "usage: bootstrap-project.sh layout-pack <node|web|python|react-native> <target-dir>" >&2
  exit 2
}

# ---------- layout-pack ----------

lp_fail() { echo "layout-pack: $*" >&2; exit 1; }

# The layout table: "<pack path> <project path>". A path ending in / is
# a folder, copied with everything in it. The optional deploy files
# (web: deploy.yml, wrangler.jsonc) and code-standards.md are not laid
# out. Every other pack file must be in the table, so a new pack file
# cannot be silently left out.
cmd_layout_pack() {
  [ "$#" -eq 2 ] || usage
  local pack="$1" out="$2"
  local here packs_dir common typescript table not_laid_out src
  local from to f covered skip

  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  packs_dir="${PACKS_DIR:-$here/languages}"

  common="ci.yml .github/workflows/ci.yml
gitignore .gitignore
vscode-settings.json .vscode/settings.json
vscode-extensions.json .vscode/extensions.json"
  typescript="package.json package.json
tsconfig.json tsconfig.json
biome.json biome.json"

  case "$pack" in
    node)
      table="$common
$typescript
placeholder.test.ts src/placeholder.test.ts"
      not_laid_out="code-standards.md"
      ;;
    web)
      table="$common
$typescript
index.html index.html
vite.config.mts vite.config.mts
playwright.config.ts playwright.config.ts
starter/src/ src/
starter/e2e/ e2e/"
      not_laid_out="code-standards.md deploy.yml wrangler.jsonc"
      ;;
    python)
      table="$common
pyproject.toml pyproject.toml
requirements.txt requirements.txt
requirements-dev.txt requirements-dev.txt
pre-commit-config.yaml .pre-commit-config.yaml
starter/src/ src/"
      not_laid_out="code-standards.md"
      ;;
    react-native)
      table="$common
$typescript
app.json app.json
starter/src/ src/"
      not_laid_out="code-standards.md"
      ;;
    *)
      echo "layout-pack: unknown pack: $pack (expected node, web, python or react-native)" >&2
      exit 2
      ;;
  esac

  src="$packs_dir/$pack"
  [ -d "$src" ] || lp_fail "pack folder not found: $src"

  if [ -e "$out" ] && [ -n "$(ls -A "$out")" ]; then
    lp_fail "target dir is not empty: $out"
  fi

  # Every table source must exist.
  while read -r from _; do
    if [ "${from%/}" != "$from" ]; then
      [ -d "$src/$from" ] || lp_fail "missing from the pack: $from"
    else
      [ -f "$src/$from" ] || lp_fail "missing from the pack: $from"
    fi
  done <<<"$table"

  # Every pack file must be in the table or in not_laid_out.
  while IFS= read -r f; do
    covered=""
    for skip in $not_laid_out; do
      [ "$f" = "$skip" ] && covered=1
    done
    while read -r from _; do
      if [ "$f" = "$from" ]; then covered=1; fi
      case "$from" in */) case "$f" in "$from"*) covered=1 ;; esac ;; esac
    done <<<"$table"
    [ -n "$covered" ] || lp_fail "not in the layout table: $f"
  done < <(cd "$src" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)

  mkdir -p "$out"
  while read -r from to; do
    if [ "${from%/}" != "$from" ]; then
      mkdir -p "$out/$to"
      cp -R "$src/$from." "$out/$to"
    else
      mkdir -p "$(dirname "$out/$to")"
      cp "$src/$from" "$out/$to"
    fi
  done <<<"$table"

  echo "Laid out the $pack pack in $out"
}

# ---------- main ----------

[ "$#" -ge 1 ] || usage
case "$1" in
  layout-pack) shift; cmd_layout_pack "$@" ;;
  *) usage ;;
esac
