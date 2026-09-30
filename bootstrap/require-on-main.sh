#!/usr/bin/env bash
# Refuse to publish a commit that is not on main. Called by
# .github/workflows/bootstrapper.yml before build and publish, so a tag
# pushed on an unmerged commit (one that never went through review and
# branch protection) cannot reach the bootstrap repo.
#
# Usage: bootstrap/require-on-main.sh <repo-dir> <commit> <main-ref>
#   <main-ref> is normally origin/main; the checkout needs full history.
set -euo pipefail

err() { echo "require-on-main.sh: error: $*" >&2; }
fail() { err "$@"; exit 1; }

[ "$#" -eq 3 ] || fail "usage: require-on-main.sh <repo-dir> <commit> <main-ref>"
REPO="$1"
COMMIT="$2"
REF="$3"

[[ "$COMMIT" =~ ^[0-9a-fA-F]{40}$ ]] \
  || fail "commit '$COMMIT' is not a 40-character hex SHA"
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 \
  || fail "'$REPO' is not a git repository"
main_sha="$(git -C "$REPO" rev-parse -q --verify "$REF^{commit}")" \
  || fail "ref $REF not found (is the checkout shallow or missing that branch?)"
git -C "$REPO" cat-file -e "$COMMIT^{commit}" 2>/dev/null \
  || fail "commit $COMMIT not found in '$REPO'"

# --is-ancestor exits 1 for "no" and other codes for errors; only 0 passes.
if git -C "$REPO" merge-base --is-ancestor "$COMMIT" "$main_sha"; then
  echo "Commit $COMMIT is on $REF ($main_sha)"
else
  fail "commit $COMMIT is not on $REF; only merged commits are published. Tag a commit on main."
fi
