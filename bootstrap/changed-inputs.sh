#!/usr/bin/env bash
# changed-inputs.sh: whether a change can affect the tests of this repo
# (PBI-1.22, part 1). The files no test reads are listed in
# bootstrap/not-read-by-tests.txt.
#
# Usage:
#   bash bootstrap/changed-inputs.sh needed <base> <head>
#     Prints "true" when the change from <base> to <head> touches a file
#     that is not listed (added, changed, deleted or renamed, on either
#     side), else "false"; each changed file is named on stderr. An empty
#     change prints "true". Exits 2 when a commit cannot be read.
#   bash bootstrap/changed-inputs.sh remove
#     Deletes the listed files from the working tree (run from the repo
#     root), so a test that reads one fails. A listed path that is
#     absolute, holds "..", or names a folder is refused (exit 2) before
#     anything is deleted.
#
# The list is read from bootstrap/not-read-by-tests.txt next to this
# script; LIST=<file> uses another one (for the tests).
#
# Template-only: bootstrap/ is not in bootstrap/manifest.txt.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="${LIST:-$HERE/not-read-by-tests.txt}"

die() { echo "changed-inputs: $*" >&2; exit 2; }

# listed: the paths of the list, one per line, each checked.
listed() {
  local line
  [ -r "$LIST" ] || die "cannot read $LIST"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in "" | "#"*) continue ;; esac
    case "$line" in
      /* | ../* | */../* | .. | */.. | */ | *[*?[]* | *" "*) die "not a plain repo path in $LIST: '$line'" ;;
    esac
    printf '%s\n' "$line"
  done <"$LIST"
}

case "${1:-}" in
  needed)
    [ $# -eq 3 ] || die "usage: needed <base> <head>"
    git rev-parse -q --verify "$2^{commit}" >/dev/null || die "no commit $2"
    git rev-parse -q --verify "$3^{commit}" >/dev/null || die "no commit $3"
    paths="$(listed)"
    changed="$(git diff --name-only --no-renames "$2" "$3")"
    if [ -z "$changed" ]; then
      echo "No file changed: the tests run." >&2
      echo true
      exit 0
    fi
    need=false
    while IFS= read -r f; do
      if printf '%s\n' "$paths" | grep -qxF -- "$f"; then
        echo "  not read by the tests: $f" >&2
      else
        echo "  read by the tests:     $f" >&2
        need=true
      fi
    done <<<"$changed"
    echo "$need"
    ;;
  remove)
    [ $# -eq 1 ] || die "usage: remove"
    paths="$(listed)"
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -d "$f" ] || die "a listed path is a folder: $f"
    done <<<"$paths"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      rm -f -- "$f"
      echo "removed before the tests: $f"
    done <<<"$paths"
    ;;
  *)
    die "usage: needed <base> <head> | remove"
    ;;
esac
