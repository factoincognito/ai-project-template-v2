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
#
# Test hooks (environment variables the tests set; users leave them unset):
#   BOOTSTRAP_GH   the gh command to run (default: gh on the PATH).
#   BOOTSTRAP_RUN  a command that replaces the runner of the install and
#                  login commands the script offers. It gets the command
#                  as one argument, so the tests never install anything.
#
# Sourcing this file defines its functions and runs nothing (the tests
# load it that way); running it with bash runs the main part at the end.
set -euo pipefail

# The bootstrapper version and commit this script ships with. The build
# stamps both values in place; in the template the script is unstamped
# and these hold the placeholders. These two lines are the only place a
# placeholder may appear: the build refuses any left in its output, so
# code compares against these variables, never a literal placeholder.
SCRIPT_VERSION='{{TEMPLATE_VERSION}}'
SCRIPT_COMMIT='{{TEMPLATE_COMMIT}}'

# ---------- messages ----------
# Everything the script shows the user goes through these helpers, and
# nothing outside this block writes to the terminal by itself, so the
# tests can check every user-facing string for plain words (see
# "Ease-of-use requirements" in the spec). Only say_command may print
# any word: it shows an exact command for the user to copy.

usage() {
  printf '%s\n' "usage: bootstrap-project.sh layout-pack <node|web|python|react-native> <target-dir>" >&2
  exit 2
}

# say <text>: one line of information.
say() { printf '%s\n' "$*"; }

# say_command <command>: a command for the user to copy, indented.
say_command() { printf '    %s\n' "$*"; }

# step_start <what>, step_end <result>: the first and last line of a step.
step_start() { printf '==> %s\n' "$*"; }
step_end() { printf '    Done. %s\n' "$*"; }

# show_error <what happened> <what to do next> [raw text]: an error in
# plain words with the next action, on stderr. Raw text (an error from a
# tool or from GitHub) is never shown alone: it comes below, for support.
show_error() {
  local what="${1:-}" next="${2:-}" raw="${3:-}" line
  [ -n "$what" ] || what="Something unexpected happened."
  [ -n "$next" ] || next="Run the script again. If the same thing happens, ask for help and show the details below."
  {
    printf 'What happened: %s\n' "$what"
    printf 'What to do next: %s\n' "$next"
    if [ -n "$raw" ]; then
      printf 'Details for support (you can ignore these):\n'
      printf '%s\n' "$raw" | tr -d '\r' | while IFS= read -r line; do
        printf '    %s\n' "$line"
      done
    fi
  } >&2
}

# fail <exit code> <what happened> <what to do next> [raw text]
fail() {
  local code="$1"
  shift
  show_error "$@"
  exit "$code"
}

# Texts used by more than one message. They live here so the tests
# check them with the rest.
LP_PACK_NEXT="Choose one of the packs: node, web, python or react-native."
LP_BROKEN_NEXT="This copy of the bootstrapper is incomplete. Download it again; if that does not help, report it to the bootstrapper's maintainers."

# ---------- end of messages ----------

# ---------- test hooks ----------

# run_gh <args...>: runs gh, or $BOOTSTRAP_GH, with gh's own prompts
# turned off. They misbehave in Git Bash's terminal, so the script asks
# its own questions.
run_gh() {
  GH_PROMPT_DISABLED=1 "${BOOTSTRAP_GH:-gh}" "$@"
}

# run_offered <command>: runs a fixed command that the script offered and
# the user approved (an install or a login), or hands it to
# $BOOTSTRAP_RUN. gh's prompts stay on: a login needs them.
# The argument runs through bash -c, so it must be a fixed string written
# in this script, never built from user input or any variable (the spec:
# "never built from user input"); the tests refuse a $ in it.
run_offered() {
  (
    unset GH_PROMPT_DISABLED
    if [ -n "${BOOTSTRAP_RUN:-}" ]; then
      "$BOOTSTRAP_RUN" "$1"
    else
      bash -c "$1"
    fi
  )
}

# ---------- layout-pack ----------

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

  # CDPATH is cleared: a user's CDPATH could send cd to another folder of
  # the same name, or make it print the folder into $here.
  here="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
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
      fail 2 "layout-pack: unknown pack: $pack (expected node, web, python or react-native)" "$LP_PACK_NEXT"
      ;;
  esac

  src="$packs_dir/$pack"
  [ -d "$src" ] || fail 1 "layout-pack: pack folder not found: $src" \
    "Check that the languages folder is next to this script, or set PACKS_DIR to the folder that holds the packs."

  if [ -e "$out" ] && [ -n "$(ls -A "$out")" ]; then
    fail 1 "layout-pack: target dir is not empty: $out" "Choose a folder that is empty or does not exist yet."
  fi

  # Every table source must exist.
  while read -r from _; do
    if [ "${from%/}" != "$from" ]; then
      [ -d "$src/$from" ] || fail 1 "layout-pack: missing from the pack: $from" "$LP_BROKEN_NEXT"
    else
      [ -f "$src/$from" ] || fail 1 "layout-pack: missing from the pack: $from" "$LP_BROKEN_NEXT"
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
    [ -n "$covered" ] || fail 1 "layout-pack: not in the layout table: $f" "$LP_BROKEN_NEXT"
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

  say "Laid out the $pack pack in $out"
}

# ---------- main ----------

main() {
  [ "$#" -ge 1 ] || usage
  case "$1" in
    layout-pack) shift; cmd_layout_pack "$@" ;;
    *) usage ;;
  esac
}

# Run unless sourced. Piped into bash there is no BASH_SOURCE: run too.
if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
