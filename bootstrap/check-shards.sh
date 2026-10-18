#!/usr/bin/env bash
# The gate of the required check bootstrapper-test (spec: docs/BACKLOG.md,
# PBI-1.18). It passes only if every test job it needs succeeded and,
# for every OS leg, the shards of bootstrap/test-bootstrap-project.sh
# together ran every test exactly once.
#
# Usage: RESULTS="<result> ..." bash bootstrap/check-shards.sh <dir> <tests> <os>...
#   RESULTS  the needs' results, space-separated (needs.*.result).
#   <dir>    the shards' manifests, each named <os>-<i>-of-<n>.txt and
#            holding the names of the tests that shard ran, one per line
#            (BOOTSTRAP_TEST_MANIFEST).
#   <tests>  every test of the harness, one per line
#            (BOOTSTRAP_TEST_LIST=1 bash bootstrap/test-bootstrap-project.sh).
#   <os>     every OS leg that must have reported, e.g. windows-latest.
#
# Every problem is reported (as ::error:: lines), then it exits 1.
# Template-only: bootstrap/ is not in bootstrap/manifest.txt.
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "usage: RESULTS=\"...\" bash bootstrap/check-shards.sh <dir> <tests> <os>..." >&2
  exit 2
fi
DIR="$1"
ALL="$2"
shift 2

PROBLEMS=0
problem() {
  echo "::error::$*"
  PROBLEMS=$((PROBLEMS + 1))
}

# Every need succeeded. A job skipped because a need failed reports as
# skipped, not success, so it fails here.
echo "Results: ${RESULTS:-}"
if [ -z "${RESULTS:-}" ]; then
  problem "No results from the test jobs."
else
  for r in $RESULTS; do
    if [ "$r" != success ]; then
      problem "A test job did not succeed (results: $RESULTS)."
      break
    fi
  done
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The list of tests, without carriage returns or blank lines.
clean() { tr -d '\r' | grep -v '^$' || true; }
clean <"$ALL" | LC_ALL=C sort >"$WORK/all"
if [ ! -s "$WORK/all" ]; then
  problem "the list of tests is empty: $ALL"
fi

# Every file in DIR is a manifest of a listed OS.
if [ -d "$DIR" ]; then
  for f in "$DIR"/* "$DIR"/.[!.]*; do
    [ -e "$f" ] || continue
    b="${f##*/}"
    os="$(printf '%s\n' "$b" | sed -nE 's/^(.+)-[1-9][0-9]*-of-[1-9][0-9]*\.txt$/\1/p')"
    known=""
    for o in "$@"; do
      if [ "$os" = "$o" ]; then known=1; fi
    done
    [ -n "$known" ] && [ -f "$f" ] || problem "unexpected file: $b"
  done
fi

for os in "$@"; do
  # The shards of this OS: their numbers and their shard count.
  missing=""
  left=""
  : >"$WORK/is"
  : >"$WORK/ns"
  if [ -d "$DIR" ]; then
    for f in "$DIR/$os"-*-of-*.txt; do
      [ -f "$f" ] || continue
      b="${f##*/}"
      rest="${b#"$os"-}"
      i="${rest%%-of-*}"
      n="${rest#*-of-}"
      n="${n%.txt}"
      case "$i$n" in "" | *[!0-9]*) continue ;; esac
      echo "$i" >>"$WORK/is"
      echo "$n" >>"$WORK/ns"
    done
  fi
  if [ ! -s "$WORK/ns" ]; then
    problem "$os: no shard reported."
    continue
  fi
  if [ "$(sort -u "$WORK/ns" | wc -l | tr -d ' ')" -ne 1 ]; then
    problem "$os: shards disagree on their count: $(sort -u "$WORK/ns" | tr '\n' ' ')"
    continue
  fi
  n="$(head -n 1 "$WORK/ns")"
  i=1
  while [ "$i" -le "$n" ]; do
    if [ -f "$DIR/$os-$i-of-$n.txt" ]; then
      clean <"$DIR/$os-$i-of-$n.txt" >>"$WORK/ran.$os"
    else
      problem "$os: shard $i of $n did not report."
      missing=1
    fi
    i=$((i + 1))
  done
  while read -r i; do
    [ "$i" -le "$n" ] || problem "$os: shard $i of $n is beyond the count."
  done <"$WORK/is"
  : >>"$WORK/ran.$os"
  LC_ALL=C sort "$WORK/ran.$os" >"$WORK/sorted"
  twice="$(uniq -d "$WORK/sorted" | tr '\n' ' ')"
  [ -z "$twice" ] || problem "$os: ran more than once: $twice"
  LC_ALL=C sort -u "$WORK/sorted" >"$WORK/once"
  extra="$(LC_ALL=C comm -13 "$WORK/all" "$WORK/once" | tr '\n' ' ')"
  [ -z "$extra" ] || problem "$os: not in the list of tests: $extra"
  if [ -z "$missing" ]; then
    left="$(LC_ALL=C comm -23 "$WORK/all" "$WORK/once" | tr '\n' ' ')"
    [ -z "$left" ] || problem "$os: did not run: $left"
  fi
  if [ -z "$missing" ] && [ -z "$twice" ] && [ -z "$extra" ] && [ -z "$left" ]; then
    echo "$os: $n shards ran all $(wc -l <"$WORK/all" | tr -d ' ') tests, each once."
  fi
done

if [ "$PROBLEMS" -ne 0 ]; then
  echo "$PROBLEMS problem(s); bootstrapper-test fails."
  exit 1
fi
echo "Every test job succeeded and every shard of every OS leg reported."
