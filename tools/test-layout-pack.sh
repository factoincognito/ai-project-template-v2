#!/usr/bin/env bash
# Tests for tools/layout-pack.sh.
# Usage: bash tools/test-layout-pack.sh
# Template-only: tools/ is not in bootstrap/manifest.txt.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
LAYOUT="$HERE/layout-pack.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0
FAILED_NAMES=()

# ---------- harness ----------

run_test() {
  local name="$1"
  local log="$WORK/$name.log" rc
  set +e
  ( set -euo pipefail; "$name" ) >"$log" 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    PASSED=$((PASSED + 1))
    echo "ok   $name"
  else
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$name")
    echo "FAIL $name"
    sed 's/^/     | /' "$log"
  fi
}

die() { echo "assertion failed: $*" >&2; exit 1; }

# expect_fail <expected-stderr-substring> <args...>
expect_fail() {
  local msg="$1"; shift
  local err="$WORK/err.$RANDOM"
  if bash "$LAYOUT" "$@" 2>"$err" >/dev/null; then
    die "layout succeeded, expected failure containing: $msg"
  fi
  grep -qF -- "$msg" "$err" || { cat "$err" >&2; die "stderr lacks: $msg"; }
}

list_files() {
  (cd "$1" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
}

# A copy of the real packs, to break without touching the repo.
copy_packs() {
  local d
  d="$(mktemp -d "$WORK/packs.XXXXXX")"
  cp -R "$REPO/languages/." "$d/"
  echo "$d"
}

# ---------- happy path: the README table ----------

test_node_layout_matches_readme_table() {
  local out="$WORK/node.$RANDOM"
  bash "$LAYOUT" node "$out" >/dev/null || die "layout failed"
  diff <(list_files "$out") <(printf '%s\n' \
    .github/workflows/ci.yml .gitignore .vscode/extensions.json .vscode/settings.json \
    biome.json package.json src/placeholder.test.ts tsconfig.json | LC_ALL=C sort) \
    || die "node layout differs from the README table"
}

test_web_layout_matches_readme_table() {
  local out="$WORK/web.$RANDOM" expected
  bash "$LAYOUT" web "$out" >/dev/null || die "layout failed"
  expected="$( {
    printf '%s\n' .github/workflows/ci.yml .gitignore .vscode/extensions.json \
      .vscode/settings.json biome.json package.json tsconfig.json index.html \
      vite.config.mts playwright.config.ts
    (cd "$REPO/languages/web/starter" && find src e2e -type f)
  } | LC_ALL=C sort)"
  diff <(list_files "$out") <(echo "$expected") || die "web layout differs from the README table"
}

test_files_are_byte_identical_to_the_pack() {
  local out="$WORK/web.$RANDOM"
  bash "$LAYOUT" web "$out" >/dev/null
  cmp -s "$REPO/languages/web/ci.yml" "$out/.github/workflows/ci.yml" || die "ci.yml differs"
  cmp -s "$REPO/languages/web/gitignore" "$out/.gitignore" || die "gitignore differs"
  cmp -s "$REPO/languages/web/vscode-settings.json" "$out/.vscode/settings.json" || die "settings differs"
  cmp -s "$REPO/languages/web/starter/src/example.ts" "$out/src/example.ts" || die "starter src differs"
  cmp -s "$REPO/languages/web/starter/e2e/smoke.e2e.ts" "$out/e2e/smoke.e2e.ts" || die "starter e2e differs"
}

test_optional_and_doc_files_are_not_laid_out() {
  local out="$WORK/web.$RANDOM"
  bash "$LAYOUT" web "$out" >/dev/null
  [ ! -e "$out/deploy.yml" ] && [ ! -e "$out/.github/workflows/deploy.yml" ] || die "deploy.yml laid out"
  [ ! -e "$out/wrangler.jsonc" ] || die "wrangler.jsonc laid out"
  [ ! -e "$out/code-standards.md" ] || die "code-standards.md laid out"
  [ ! -e "$out/starter" ] || die "starter/ copied as is"
}

test_empty_existing_dir_is_accepted() {
  local out="$WORK/empty.$RANDOM"
  mkdir "$out"
  bash "$LAYOUT" node "$out" >/dev/null || die "layout into empty dir failed"
  [ -f "$out/package.json" ] || die "nothing written"
}

test_packs_dir_can_be_overridden() {
  local packs out="$WORK/o.$RANDOM"
  packs="$(copy_packs)"
  echo '{"name":"from-override"}' >"$packs/node/package.json"
  PACKS_DIR="$packs" bash "$LAYOUT" node "$out" >/dev/null || die "layout failed"
  grep -qF from-override "$out/package.json" || die "PACKS_DIR not used"
}

# ---------- error paths ----------

test_wrong_arg_count_fails_with_usage() {
  expect_fail "usage:" node
  expect_fail "usage:" node "$WORK/o.$RANDOM" extra
  expect_fail "usage:"
}

test_unknown_pack_fails() {
  expect_fail "unknown pack: python" python "$WORK/o.$RANDOM"
  expect_fail "unknown pack: ../node" ../node "$WORK/o.$RANDOM"
}

test_non_empty_target_dir_fails() {
  local out="$WORK/full.$RANDOM"
  mkdir "$out"; echo x >"$out/keep.txt"
  expect_fail "is not empty" node "$out"
  [ "$(cat "$out/keep.txt")" = x ] || die "existing file touched"
}

test_pack_file_not_in_the_table_fails() {
  # A new pack file must be placed by the table (README and this script)
  # or listed as not laid out; it must never be silently dropped.
  local packs out="$WORK/o.$RANDOM"
  packs="$(copy_packs)"
  echo "{}" >"$packs/web/new-tool.json"
  PACKS_DIR="$packs" expect_fail "not in the layout table: new-tool.json" web "$out"
  [ ! -e "$out" ] || [ -z "$(ls -A "$out")" ] || die "files written despite the error"
}

test_new_starter_folder_fails() {
  local packs out="$WORK/o.$RANDOM"
  packs="$(copy_packs)"
  mkdir "$packs/web/starter/public"; echo x >"$packs/web/starter/public/x.txt"
  PACKS_DIR="$packs" expect_fail "not in the layout table: starter/public/x.txt" web "$out"
}

test_missing_pack_file_fails() {
  local packs out="$WORK/o.$RANDOM"
  packs="$(copy_packs)"
  rm "$packs/node/tsconfig.json"
  PACKS_DIR="$packs" expect_fail "missing from the pack: tsconfig.json" node "$out"
}

# ---------- the README and the workflow agree with the script ----------

test_readme_table_names_every_laid_out_file() {
  local f
  for f in ci.yml gitignore vscode-settings.json vscode-extensions.json package.json \
    tsconfig.json biome.json placeholder.test.ts index.html vite.config.mts \
    playwright.config.ts 'starter/src/' 'starter/e2e/'; do
    grep -qF "\`$f\`" "$REPO/README.md" || die "README table lacks $f"
  done
}

test_packs_workflow_uses_the_script_for_both_packs() {
  local wf="$REPO/.github/workflows/packs.yml"
  [ -f "$wf" ] || die "no packs.yml"
  grep -qE '^  pack-node:' "$wf" || die "no pack-node job"
  grep -qE '^  pack-web:' "$wf" || die "no pack-web job"
  grep -qE 'tools/layout-pack\.sh node ' "$wf" || die "pack-node does not use layout-pack.sh"
  grep -qE 'tools/layout-pack\.sh web ' "$wf" || die "pack-web does not use layout-pack.sh"
  grep -qF 'npx playwright install --with-deps chromium' "$wf" || die "no browser install"
  grep -qF 'npm run test:e2e' "$wf" || die "no e2e run"
  grep -qF 'bash tools/test-layout-pack.sh' "$wf" || die "script tests not run"
}

test_packs_workflow_node_version_matches_pack_ci() {
  local wf="$REPO/.github/workflows/packs.yml" v
  for p in node web; do
    v="$(grep -oE 'node-version: "[0-9]+"' "$REPO/languages/$p/ci.yml")" || die "$p ci.yml has no node-version"
    grep -qF "$v" "$wf" || die "packs.yml lacks $v from the $p pack"
  done
}

test_packs_workflow_runs_every_pack_ci_step() {
  # packs.yml must run each pack's CI commands verbatim, so the two
  # cannot drift apart. `npm ci` is the one it may precede with
  # `npm install`, because the template has no lockfile.
  local wf="$REPO/.github/workflows/packs.yml" p cmd n=0
  for p in node web; do
    while IFS= read -r cmd; do
      n=$((n + 1))
      grep -qF -- "run: $cmd" "$wf" || die "packs.yml lacks the $p pack step: $cmd"
    done < <(sed -n 's/^ *run: //p' "$REPO/languages/$p/ci.yml")
  done
  [ "$n" -ge 9 ] || die "found only $n pack CI steps; the parser is broken"
}

test_packs_workflow_uses_the_pack_ci_action_versions() {
  local wf="$REPO/.github/workflows/packs.yml" u
  while IFS= read -r u; do
    grep -qF -- "$u" "$wf" || die "packs.yml lacks $u from the pack ci.yml"
  done < <(grep -hoE 'uses: [^ ]+' "$REPO/languages/node/ci.yml" "$REPO/languages/web/ci.yml" | sort -u)
}

test_template_only_files_are_not_in_the_manifest() {
  ! grep -qE '^(tools|\.github/workflows/packs\.yml)' "$REPO/bootstrap/manifest.txt" \
    || die "template-only file listed in the manifest"
}

# ---------- run ----------

TESTS=$(declare -F | awk '{print $3}' | grep '^test_')
for t in $TESTS; do
  run_test "$t"
done

echo
echo "$PASSED passed, $FAILED failed"
if [ "$FAILED" -ne 0 ]; then
  printf '  %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
