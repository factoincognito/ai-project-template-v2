#!/usr/bin/env bash
# Build the bootstrapper: a clean copy of this repo for starting new
# projects. Spec: docs/BACKLOG.md, PBI-1.10.
#
# Usage: bootstrap/build.sh <out-dir> <version> <commit>
#   <out-dir>  must be empty or absent
#   <version>  release tag, vMAJOR.MINOR.PATCH (e.g. v2.1.0)
#   <commit>   full 40-character SHA the build is made from
#
# Output = every path in bootstrap/manifest.txt, copied as is, plus every
# file in bootstrap/stubs/. The CHANGELOG.md stub is stamped with the
# version and commit. The build is assembled in a temp dir and checked;
# <out-dir> is only written when every check passes.
set -euo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"
MANIFEST="$HERE/manifest.txt"
STUBS="$HERE/stubs"

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
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  line="${line#"${line%%[![:space:]]*}"}"   # trim leading whitespace
  line="${line%"${line##*[![:space:]]}"}"   # trim trailing whitespace
  case "$line" in ''|'#'*) continue ;; esac
  while [ "${line%/}" != "$line" ]; do line="${line%/}"; done
  case "/$line/" in
    //*|*/../*|*/./*) fail "manifest path must be relative, inside the repo: $line" ;;
  esac
  [ -e "$SRC/$line" ] || [ -L "$SRC/$line" ] \
    || fail "manifest path does not exist: $line"
  ENTRIES+=("$line")
done <"$MANIFEST"

[ "${#ENTRIES[@]}" -gt 0 ] || fail "manifest lists no paths"

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

[ -f "$STUBS/CHANGELOG.md" ] || fail "CHANGELOG.md stub not found in $STUBS"
for p in '{{TEMPLATE_VERSION}}' '{{TEMPLATE_COMMIT}}'; do
  grep -qF "$p" "$STUBS/CHANGELOG.md" || fail "CHANGELOG.md stub lacks $p"
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

# Stamp the version. Both values are validated above, so they are safe
# in a sed replacement.
sed -e "s|{{TEMPLATE_VERSION}}|$VERSION|g" -e "s|{{TEMPLATE_COMMIT}}|$COMMIT|g" \
  "$STAGE/CHANGELOG.md" >"$STAGE/CHANGELOG.md.tmp"
mv "$STAGE/CHANGELOG.md.tmp" "$STAGE/CHANGELOG.md"

# ---------- check the output ----------

problems=0
problem() { err "$@"; problems=$((problems + 1)); }

list_rel() { (cd "$1" && find . \( -type f -o -type l \) | sed 's|^\./||' | sort -u); }

[ ! -e "$STAGE/docs/RELEASE_NOTES.md" ] || problem "forbidden path in output: docs/RELEASE_NOTES.md"
[ ! -e "$STAGE/bootstrap" ] || problem "forbidden path in output: bootstrap/"

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

# The output must be exactly the manifest paths plus the stubs.
EXPECTED="$(
  for m in "${ENTRIES[@]}"; do
    if [ -d "$SRC/$m" ] && [ ! -L "$SRC/$m" ]; then
      (cd "$SRC" && find "$m" \( -type f -o -type l \))
    else
      echo "$m"
    fi
  done
  for s in ${STUB_FILES[@]+"${STUB_FILES[@]}"}; do echo "$s"; done
)"
if ! diff <(echo "$EXPECTED" | sort -u) <(list_rel "$STAGE") >&2; then
  problem "output file list differs from manifest plus stubs (diff above)"
fi

[ "$problems" -eq 0 ] || fail "$problems problem(s) found; nothing written to $OUT"

# ---------- publish to out-dir ----------

mkdir -p "$OUT"
cp -a "$STAGE/." "$OUT/"
echo "Built bootstrapper $VERSION from $COMMIT into $OUT ($(list_rel "$OUT" | wc -l | tr -d ' ') files)"

# throwaway line: a code change with no test change, to prove the check goes red. Never merge.
