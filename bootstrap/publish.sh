#!/usr/bin/env bash
# Publish a built bootstrapper to the bootstrap repo. Called by
# .github/workflows/bootstrapper.yml on a pushed v* tag, after build.sh.
# Spec: docs/BACKLOG.md, PBI-1.10.
#
# Usage: bootstrap/publish.sh <out-dir> <version> <commit> <remote-url>
#
# Makes the remote's default branch match <out-dir> exactly (files not in
# <out-dir> are deleted) as one new commit on top of its history, or as
# its first commit if the remote is empty, and pushes tag <version> on
# that commit. Branch and tag go in one atomic push. Fails, changing
# nothing, if tag <version> already exists on the remote.
set -euo pipefail
export LC_ALL=C

SOURCE_REPO="factoincognito/ai-project-template-v2"

err() { echo "publish.sh: error: $*" >&2; }
fail() { err "$@"; exit 1; }

[ "$#" -eq 4 ] || fail "usage: publish.sh <out-dir> <version> <commit> <remote-url>"
OUT="$1"
VERSION="$2"
COMMIT="$3"
REMOTE="$4"

[[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || fail "version '$VERSION' is not vMAJOR.MINOR.PATCH"
[[ "$COMMIT" =~ ^[0-9a-fA-F]{40}$ ]] \
  || fail "commit '$COMMIT' is not a 40-character hex SHA"
[ -d "$OUT" ] && [ -n "$(ls -A "$OUT")" ] \
  || fail "out-dir '$OUT' is missing or empty; run build.sh first"
[ -n "$REMOTE" ] || fail "remote url is empty"
OUT="$(cd "$OUT" && pwd)"

GITDIR="$(mktemp -d)"
trap 'rm -rf "$GITDIR"' EXIT
git init -q --bare "$GITDIR"
# The build output is the work tree, so the commit is exactly its content.
g() { git --git-dir="$GITDIR" --work-tree="$OUT" "$@"; }

export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-github-actions[bot]}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"

# 1. Refuse to overwrite an existing release. (The atomic push below
#    also refuses, which covers a race between this check and the push.)
tags="$(git ls-remote --tags "$REMOTE")" || fail "cannot read the bootstrap repo (check the token)"
if printf '%s\n' "$tags" | awk -v r="refs/tags/$VERSION" '$2 == r || $2 == r"^{}" { found = 1 } END { exit !found }'; then
  fail "tag $VERSION already exists in the bootstrap repo; not overwriting"
fi

# 2. Find the default branch. An empty repo may or may not advertise
#    its unborn HEAD; if it does not, use main.
head_ref="$(git ls-remote --symref "$REMOTE" HEAD | awk '$1 == "ref:" && $3 == "HEAD" { print $2; exit }')"
BRANCH="${head_ref#refs/heads/}"
[ -n "$BRANCH" ] || BRANCH="main"

parent=""
if [ -n "$(git ls-remote --heads "$REMOTE" "refs/heads/$BRANCH")" ]; then
  g fetch -q --depth 1 "$REMOTE" "refs/heads/$BRANCH"
  parent="$(g rev-parse FETCH_HEAD)"
  g read-tree "$parent"
  echo "Publishing $VERSION onto $BRANCH (parent $parent)"
else
  echo "Bootstrap repo is empty; publishing $VERSION as the first commit on $BRANCH"
fi

# 3. Stage the output exactly: -A picks up deletions against the parent
#    tree, -f keeps the shipped .gitignore from dropping shipped files.
g add -A -f .
tree="$(g write-tree)"

diff <(g ls-tree -r --name-only "$tree" | sort) \
     <(cd "$OUT" && find . \( -type f -o -type l \) | sed 's|^\./||' | sort) >&2 \
  || fail "staged tree differs from the build output (diff above)"

msg="Bootstrapper $VERSION from $SOURCE_REPO@$COMMIT"
if [ -n "$parent" ]; then
  new="$(g commit-tree "$tree" -p "$parent" -m "$msg")"
else
  new="$(g commit-tree "$tree" -m "$msg")"
fi

# 4. Branch and tag together, or neither. No force: a moved branch or an
#    existing tag rejects the whole push.
g push -q --atomic "$REMOTE" "$new:refs/heads/$BRANCH" "$new:refs/tags/$VERSION" \
  || fail "push to the bootstrap repo was rejected; nothing was published"

echo "Published $VERSION as $new on $BRANCH"
