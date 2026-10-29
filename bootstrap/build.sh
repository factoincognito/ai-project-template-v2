#!/usr/bin/env bash
# Build the bootstrapper: a clean copy of this repo for starting new
# projects. Spec: docs/BACKLOG.md, PBI-1.10.
#
# Usage: bootstrap/build.sh <out-dir> <version> <commit>
#   <out-dir>  must be empty or absent
#   <version>  release tag, vMAJOR.MINOR.PATCH (e.g. v2.1.0)
#   <commit>   full 40-character SHA the build is made from
#
# Output = every path in bootstrap/manifest.txt, copied as is (less the
# paths its "exclude" lines leave out), plus every file in
# bootstrap/stubs/, plus .github/README.md: the bootstrapper's own
# README, made from bootstrap/bootstrapper-README.md with the marked
# part of this repo's README.md in place of its {{TEMPLATE_README_SETUP}}
# line (PBI-1.29). The CHANGELOG.md and bootstrap-project.sh stubs are
# stamped with the version and commit, in place, keeping each file's
# mode. The build is assembled in a temp dir and checked; <out-dir> is
# only written when every check passes.
set -euo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"
MANIFEST="$HERE/manifest.txt"
STUBS="$HERE/stubs"
OWN_README_SRC="$HERE/bootstrapper-README.md"
OWN_README_OUT=".github/README.md"
OWN_README_SLOT='{{TEMPLATE_README_SETUP}}'
MARK_START='<!-- bootstrapper-readme: start -->'
MARK_END='<!-- bootstrapper-readme: end -->'

FORBIDDEN_FIXED=('trig_' '(PR #')
FORBIDDEN_REGEX=('PBI-[0-9]' 'open question [0-9]')

err() { echo "build.sh: error: $*" >&2; }
fail() { err "$@"; exit 1; }

# ---------- arguments ----------

[ "$#" -eq 3 ] || fail "usage: build.sh <out-dir> <version> <commit>"
OUT="$1"
VERSION="$2"
COMMIT="$3"

[[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || fail "version '$VERSION' is not vMAJOR.MINOR.PATCH"
[[ "$COMMIT" =~ ^[0-9a-fA-F]{40}$ ]] \
  || fail "commit '$COMMIT' is not a 40-character hex SHA"

if [ -e "$OUT" ] || [ -L "$OUT" ]; then
  [ -d "$OUT" ] || fail "out-dir '$OUT' is not a directory"
  [ -z "$(ls -A "$OUT")" ] || fail "out-dir '$OUT' is not empty"
fi

# ---------- manifest ----------

[ -f "$MANIFEST" ] || fail "manifest not found: $MANIFEST"

ENTRIES=()
EXCLUDES=()
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  line="${line#"${line%%[![:space:]]*}"}"   # trim leading whitespace
  line="${line%"${line##*[![:space:]]}"}"   # trim trailing whitespace
  case "$line" in ''|'#'*) continue ;; esac
  case "$line" in
    'exclude '*)
      line="${line#exclude }"
      line="${line#"${line%%[![:space:]]*}"}"
      while [ "${line%/}" != "$line" ]; do line="${line%/}"; done
      case "/$line/" in
        //*|*/../*|*/./*) fail "manifest path must be relative, inside the repo: $line" ;;
      esac
      [ -e "$SRC/$line" ] || [ -L "$SRC/$line" ] \
        || fail "manifest exclude path does not exist: $line"
      EXCLUDES+=("$line")
      continue
      ;;
  esac
  while [ "${line%/}" != "$line" ]; do line="${line%/}"; done
  case "/$line/" in
    //*|*/../*|*/./*) fail "manifest path must be relative, inside the repo: $line" ;;
  esac
  [ -e "$SRC/$line" ] || [ -L "$SRC/$line" ] \
    || fail "manifest path does not exist: $line"
  ENTRIES+=("$line")
done <"$MANIFEST"

[ "${#ENTRIES[@]}" -gt 0 ] || fail "manifest lists no paths"

# An excluded path must be inside a listed folder: excluding a listed
# file, or a path nothing would copy, is a mistake in the manifest. No
# folder between the two may be a symlink: removing the path from the
# stage would then remove a file outside it.
for x in ${EXCLUDES[@]+"${EXCLUDES[@]}"}; do
  inside=""
  for m in "${ENTRIES[@]}"; do
    if [ -d "$SRC/$m" ] && [ ! -L "$SRC/$m" ]; then
      case "$x" in "$m"/*) inside="$m" ;; esac
    fi
  done
  [ -n "$inside" ] || fail "manifest exclude path is not inside a listed folder: $x"
  p="${x%/*}"
  while [ "$p" != "$inside" ]; do
    [ ! -L "$SRC/$p" ] || fail "manifest exclude path goes through a symlink: $x"
    p="${p%/*}"
  done
done

# is_excluded <path>: the path is an excluded one or inside one. (A
# function, not a case in a $(...): bash 3.2 ends a $(...) at a case
# pattern's ")".)
is_excluded() {
  local x
  for x in ${EXCLUDES[@]+"${EXCLUDES[@]}"}; do
    case "$1" in "$x"|"$x"/*) return 0 ;; esac
  done
  return 1
}

# ---------- the bootstrapper's own README ----------

# Both files are read without carriage returns (.gitattributes keeps
# them LF; a CRLF copy gives the same result). The slot and each marker
# must be there once, each on a line of its own and nowhere else.
[ -f "$OWN_README_SRC" ] || fail "bootstrapper README source not found: bootstrap/bootstrapper-README.md"
[ -f "$SRC/README.md" ] || fail "template README not found: README.md"
[ "$(tr -d '\r' <"$OWN_README_SRC" | grep -cxF -- "$OWN_README_SLOT" || true)" -eq 1 ] \
  && [ "$(tr -d '\r' <"$OWN_README_SRC" | grep -cF -- "$OWN_README_SLOT" || true)" -eq 1 ] \
  || fail "bootstrap/bootstrapper-README.md must have the line $OWN_README_SLOT exactly once, on a line of its own"
for mk in "$MARK_START" "$MARK_END"; do
  [ "$(tr -d '\r' <"$SRC/README.md" | grep -cxF -- "$mk" || true)" -eq 1 ] \
    && [ "$(tr -d '\r' <"$SRC/README.md" | grep -cF -- "$mk" || true)" -eq 1 ] \
    || fail "README.md must have the line $mk exactly once, on a line of its own"
done
mark_start_line="$(tr -d '\r' <"$SRC/README.md" | grep -nxF -- "$MARK_START" | cut -d: -f1)"
mark_end_line="$(tr -d '\r' <"$SRC/README.md" | grep -nxF -- "$MARK_END" | cut -d: -f1)"
[ "$mark_start_line" -lt "$mark_end_line" ] \
  || fail "README.md: the line $MARK_START must come before $MARK_END"
# marked_part: the lines strictly between the two markers. grep -c reads
# all of it: grep -q would stop early and, under pipefail, the writer's
# SIGPIPE would fail the check at random.
marked_part() {
  tr -d '\r' <"$SRC/README.md" | awk -v s="$mark_start_line" -v e="$mark_end_line" 'NR > s && NR < e'
}
[ "$(marked_part | grep -c '[^[:space:]]' || true)" -gt 0 ] \
  || fail "README.md: nothing between $MARK_START and $MARK_END"

# ---------- stubs ----------

STUB_FILES=()
if [ -d "$STUBS" ]; then
  while IFS= read -r s; do
    STUB_FILES+=("$s")
  done < <(cd "$STUBS" && find . \( -type f -o -type l \) | sed 's|^\./||' | sort)
fi

for s in ${STUB_FILES[@]+"${STUB_FILES[@]}"}; do
  for m in "${ENTRIES[@]}"; do
    case "$s" in
      "$m"|"$m"/*) fail "stub overlaps manifest path (ambiguous source): $s" ;;
    esac
  done
done

# The stubs that carry the version stamp. Each must hold both
# placeholders; the stamp is the only link back to the template.
STAMPED=(CHANGELOG.md bootstrap-project.sh)
for s in "${STAMPED[@]}"; do
  [ ! -L "$STUBS/$s" ] || fail "$s stub must be a regular file, not a symlink"
  [ -f "$STUBS/$s" ] || fail "$s stub not found in $STUBS"
  for p in '{{TEMPLATE_VERSION}}' '{{TEMPLATE_COMMIT}}'; do
    grep -qF "$p" "$STUBS/$s" || fail "$s stub lacks $p"
  done
done

# ---------- assemble in a temp dir ----------

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

for m in "${ENTRIES[@]}"; do
  if [ -d "$SRC/$m" ] && [ ! -L "$SRC/$m" ]; then
    mkdir -p "$STAGE/$m"
    cp -a "$SRC/$m/." "$STAGE/$m/"
  else
    mkdir -p "$STAGE/$(dirname "$m")"
    cp -a "$SRC/$m" "$STAGE/$m"
  fi
done

for s in ${STUB_FILES[@]+"${STUB_FILES[@]}"}; do
  mkdir -p "$STAGE/$(dirname "$s")"
  cp -a "$STUBS/$s" "$STAGE/$s"
done

for x in ${EXCLUDES[@]+"${EXCLUDES[@]}"}; do
  rm -rf "${STAGE:?}/$x"
done

# The bootstrapper's own README: the source with the marked part of the
# template's README.md in place of its slot line (the marker lines left
# out). Nothing else may already put a file there.
if [ -e "$STAGE/$OWN_README_OUT" ] || [ -L "$STAGE/$OWN_README_OUT" ]; then
  fail "the build writes $OWN_README_OUT, but a manifest path or a stub already gives it"
fi
mkdir -p "$STAGE/$(dirname "$OWN_README_OUT")"
OWN_PART="$(mktemp)"
trap 'rm -rf "$STAGE" "$OWN_PART"' EXIT
marked_part >"$OWN_PART"
tr -d '\r' <"$OWN_README_SRC" | SLOT="$OWN_README_SLOT" awk -v part="$OWN_PART" '
  $0 == ENVIRON["SLOT"] { while ((getline l < part) > 0) print l; next }
  { print }' >"$STAGE/$OWN_README_OUT"

# Stamp the version. Both values are validated above, so they are safe
# in a sed replacement. In place: the stamped text is written back over
# the staged copy (cat >), which keeps its mode; a `sed > tmp; mv` would
# replace the file with a new one and drop the script's executable bit.
# Not `sed -i`, whose syntax differs between GNU and BSD sed. The temp
# file is outside the stage, so it cannot end up in the output.
STAMP_TMP="$(mktemp)"
trap 'rm -rf "$STAGE" "$OWN_PART" "$STAMP_TMP"' EXIT
for s in "${STAMPED[@]}"; do
  sed -e "s|{{TEMPLATE_VERSION}}|$VERSION|g" -e "s|{{TEMPLATE_COMMIT}}|$COMMIT|g" \
    "$STAGE/$s" >"$STAMP_TMP"
  cat "$STAMP_TMP" >"$STAGE/$s"
done

# ---------- check the output ----------

problems=0
problem() { err "$@"; problems=$((problems + 1)); }

list_rel() { (cd "$1" && find . \( -type f -o -type l \) | sed 's|^\./||' | sort -u); }

[ ! -e "$STAGE/docs/RELEASE_NOTES.md" ] || problem "forbidden path in output: docs/RELEASE_NOTES.md"
[ ! -e "$STAGE/bootstrap" ] || problem "forbidden path in output: bootstrap/"

# Stamping must not change a stub's executable bit.
for s in "${STAMPED[@]}"; do
  if [ -x "$STUBS/$s" ] && [ ! -x "$STAGE/$s" ]; then
    problem "stamping dropped the executable bit of $s"
  fi
done

while IFS= read -r f; do
  problem "placeholder left in output: $f"
done < <(cd "$STAGE" && grep -rlF '{{TEMPLATE_' . | sed 's|^\./||' | sort || true)

for s in "${FORBIDDEN_FIXED[@]}"; do
  while IFS= read -r f; do
    problem "forbidden string '$s' in output file: $f"
  done < <(cd "$STAGE" && grep -rlF -- "$s" . | sed 's|^\./||' | sort || true)
done
for r in "${FORBIDDEN_REGEX[@]}"; do
  while IFS= read -r f; do
    problem "forbidden pattern '$r' in output file: $f"
  done < <(cd "$STAGE" && grep -rlE -- "$r" . | sed 's|^\./||' | sort || true)
done

for x in ${EXCLUDES[@]+"${EXCLUDES[@]}"}; do
  [ ! -e "$STAGE/$x" ] || problem "excluded path in output: $x"
done

# The output must be exactly the manifest paths (less the excluded
# ones) plus the stubs plus the bootstrapper's own README.
EXPECTED="$(
  for m in "${ENTRIES[@]}"; do
    if [ -d "$SRC/$m" ] && [ ! -L "$SRC/$m" ]; then
      (cd "$SRC" && find "$m" \( -type f -o -type l \))
    else
      echo "$m"
    fi
  done | while IFS= read -r f; do
    is_excluded "$f" || echo "$f"
  done
  for s in ${STUB_FILES[@]+"${STUB_FILES[@]}"}; do echo "$s"; done
  echo "$OWN_README_OUT"
)"
if ! diff <(echo "$EXPECTED" | sort -u) <(list_rel "$STAGE") >&2; then
  problem "output file list differs from manifest plus stubs (diff above)"
fi

[ "$problems" -eq 0 ] || fail "$problems problem(s) found; nothing written to $OUT"

# ---------- publish to out-dir ----------

mkdir -p "$OUT"
cp -a "$STAGE/." "$OUT/"
echo "Built bootstrapper $VERSION from $COMMIT into $OUT ($(list_rel "$OUT" | wc -l | tr -d ' ') files)"
