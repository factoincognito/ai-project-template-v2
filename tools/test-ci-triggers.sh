#!/usr/bin/env bash
# Checks the triggers of the template's own ci.yml and packs.yml (PBI-1.25,
# part 2): each runs on pull requests to main and on pushes to main only.
# A push trigger on every branch would run the workflow twice for every
# push to a pull request branch (once as push, once as pull_request).
# Usage: bash tools/test-ci-triggers.sh
# Template-only: tools/ is not in bootstrap/manifest.txt. Runs in the
# `build` job of ci.yml.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

fail() {
  echo "FAIL $*" >&2
  FAILED=1
}

# on_block <file>: the lines of the top-level `on:` block, comments out.
on_block() {
  awk '
    /^on:/ { inon = 1; next }
    inon && /^[^ #]/ { exit }
    inon && !/^[[:space:]]*#/ { print }
  ' "$1"
}

# event_block <on-block> <event>: the lines under `  <event>:` (two-space
# indent) up to the next event.
event_block() {
  awk -v ev="$2" '
    $0 ~ "^  " ev ":" { ine = 1; next }
    ine && /^  [^ ]/ { exit }
    ine { print }
  ' <<<"$1"
}

for wf in ci.yml packs.yml; do
  f="$REPO/.github/workflows/$wf"
  [ -f "$f" ] || {
    fail "$wf: no such workflow"
    continue
  }
  on="$(on_block "$f")"
  [ -n "$on" ] || {
    fail "$wf: no on: block found"
    continue
  }

  grep -qE '^  pull_request:' <<<"$on" || fail "$wf: no pull_request trigger"
  pr="$(event_block "$on" pull_request)"
  grep -qE 'branches: *\[ *main *\]' <<<"$pr" || fail "$wf: pull_request is not limited to main"

  grep -qE '^  push:' <<<"$on" || fail "$wf: no push trigger (pushes to main must run it)"
  push="$(event_block "$on" push)"
  grep -qE 'branches: *\[ *main *\]' <<<"$push" || fail "$wf: push is not limited to branches: [main]"
  if grep -qE '\*' <<<"$push"; then
    fail "$wf: push has a wildcard branch trigger (runs twice per push to a PR branch)"
  fi
done

if [ "$FAILED" -ne 0 ]; then
  echo "tools/test-ci-triggers.sh: FAILED" >&2
  exit 1
fi
echo "ok   ci.yml and packs.yml run on pull requests to main and on pushes to main only"
