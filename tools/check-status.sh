#!/usr/bin/env bash
# Checks that STATUS.md files keep the format the product owner's
# overview of all projects reads: the title "# Status", a
# "Last update: YYYY-MM-DD" line, and the headings Phase, Current focus,
# Next step and Blockers, each exactly once and in that order, written
# exactly so. Headings after Blockers are allowed.
# Usage: bash tools/check-status.sh [file...]
#   With no files: STATUS.md and bootstrap/stubs/STATUS.md under the repo
#   root (STATUS_ROOT overrides the root, for the tests).
# Exits 1 when a file breaks the format, naming every problem on stderr.
#
# Template-only: tools/ is not in bootstrap/manifest.txt. Run by the
# build job of .github/workflows/ci.yml (docs/NEXT_SESSION.md item 15).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${STATUS_ROOT:-$HERE/..}"
HEADINGS=("Phase" "Current focus" "Next step" "Blockers")

if [ $# -eq 0 ]; then
  set -- "$ROOT/STATUS.md" "$ROOT/bootstrap/stubs/STATUS.md"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PROBLEMS=0
problem() {
  echo "check-status: $1: $2" >&2
  PROBLEMS=$((PROBLEMS + 1))
}

check_file() {
  local file="$1" text="$WORK/text" h n line last=0 complete=true in_order=true
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    problem "$file" "cannot read"
    return
  fi
  tr -d '\r' <"$file" >"$text"
  grep -qx '# Status' "$text" || problem "$file" 'missing title "# Status"'
  grep -Eqx 'Last update: (YYYY-MM-DD|[0-9]{4}-[0-9]{2}-[0-9]{2})' "$text" \
    || problem "$file" 'missing "Last update: YYYY-MM-DD" line'
  for h in "${HEADINGS[@]}"; do
    n="$(grep -cxF -- "## $h" "$text" || true)"
    if [ "$n" -eq 0 ]; then
      problem "$file" "missing heading \"## $h\""
      complete=false
    elif [ "$n" -gt 1 ]; then
      problem "$file" "heading \"## $h\" appears $n times"
      complete=false
    else
      line="$(grep -nxF -- "## $h" "$text" | cut -d: -f1)"
      [ "$line" -gt "$last" ] || in_order=false
      last="$line"
    fi
  done
  # Order is judged only when every heading is there once.
  if [ "$complete" = true ] && [ "$in_order" = false ]; then
    problem "$file" "headings out of order: want Phase, Current focus, Next step, Blockers"
  fi
}

for f in "$@"; do
  check_file "$f"
done

if [ "$PROBLEMS" -ne 0 ]; then
  echo "check-status: $PROBLEMS problem(s); the format is in bootstrap/stubs/STATUS.md" >&2
  exit 1
fi
echo "check-status: ok: $*"
