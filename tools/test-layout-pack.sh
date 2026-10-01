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

test_python_layout_matches_readme_table() {
  local out="$WORK/python.$RANDOM" expected
  bash "$LAYOUT" python "$out" >/dev/null || die "layout failed"
  expected="$( {
    printf '%s\n' .github/workflows/ci.yml .gitignore .vscode/extensions.json \
      .vscode/settings.json pyproject.toml requirements.txt requirements-dev.txt \
      .pre-commit-config.yaml
    (cd "$REPO/languages/python/starter" && find src -type f)
  } | LC_ALL=C sort)"
  diff <(list_files "$out") <(echo "$expected") || die "python layout differs from the README table"
  [ -f "$out/src/tests/test_placeholder.py" ] || die "no placeholder test in src/tests/"
}

test_react_native_layout_matches_readme_table() {
  local out="$WORK/rn.$RANDOM" expected
  bash "$LAYOUT" react-native "$out" >/dev/null || die "layout failed"
  expected="$( {
    printf '%s\n' .github/workflows/ci.yml .gitignore .vscode/extensions.json \
      .vscode/settings.json biome.json package.json tsconfig.json app.json
    (cd "$REPO/languages/react-native/starter" && find src -type f)
  } | LC_ALL=C sort)"
  diff <(list_files "$out") <(echo "$expected") || die "react-native layout differs from the README table"
  [ -f "$out/src/App.test.tsx" ] || die "no starter test in src/"
}

test_react_native_files_are_byte_identical_to_the_pack() {
  local out="$WORK/rn.$RANDOM" p="$REPO/languages/react-native"
  bash "$LAYOUT" react-native "$out" >/dev/null
  cmp -s "$p/ci.yml" "$out/.github/workflows/ci.yml" || die "ci.yml differs"
  cmp -s "$p/gitignore" "$out/.gitignore" || die "gitignore differs"
  cmp -s "$p/app.json" "$out/app.json" || die "app.json differs"
  cmp -s "$p/package.json" "$out/package.json" || die "package.json differs"
  cmp -s "$p/starter/src/App.tsx" "$out/src/App.tsx" || die "starter App differs"
  cmp -s "$p/starter/src/index.ts" "$out/src/index.ts" || die "starter entry differs"
  [ ! -e "$out/code-standards.md" ] || die "code-standards.md laid out"
  [ ! -e "$out/starter" ] || die "starter/ copied as is"
}

test_react_native_entry_point_is_laid_out() {
  # package.json "main" must name a file the layout creates, or the app
  # has no entry point.
  local out="$WORK/rn.$RANDOM" main
  bash "$LAYOUT" react-native "$out" >/dev/null
  main="$(sed -n 's/^ *"main": "\([^"]*\)".*/\1/p' "$out/package.json")"
  [ -n "$main" ] || die "package.json has no main"
  [ -f "$out/$main" ] || die "package.json main $main is not laid out"
}

test_npm_packs_have_no_lockfile() {
  local p f
  for p in node web react-native; do
    for f in package-lock.json yarn.lock pnpm-lock.yaml bun.lockb; do
      [ ! -e "$REPO/languages/$p/$f" ] || die "lockfile in the $p pack: $f"
    done
  done
}

test_npm_packs_pin_every_dependency_exactly() {
  local p n=0 v
  for p in node web react-native; do
    while IFS= read -r v; do
      n=$((n + 1))
      [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "$p package.json: not pinned exactly: $v"
    done < <(node -e '
      const pkg = require(process.argv[1]);
      for (const d of [pkg.dependencies, pkg.devDependencies]) for (const v of Object.values(d || {})) console.log(v);
    ' "$REPO/languages/$p/package.json")
  done
  [ "$n" -ge 15 ] || die "found only $n dependencies; the parser is broken"
}

test_python_files_are_byte_identical_to_the_pack() {
  local out="$WORK/python.$RANDOM" p="$REPO/languages/python"
  bash "$LAYOUT" python "$out" >/dev/null
  cmp -s "$p/ci.yml" "$out/.github/workflows/ci.yml" || die "ci.yml differs"
  cmp -s "$p/pre-commit-config.yaml" "$out/.pre-commit-config.yaml" || die "pre-commit config differs"
  cmp -s "$p/pyproject.toml" "$out/pyproject.toml" || die "pyproject.toml differs"
  cmp -s "$p/starter/src/tests/test_placeholder.py" "$out/src/tests/test_placeholder.py" \
    || die "placeholder test differs"
  [ ! -e "$out/code-standards.md" ] || die "code-standards.md laid out"
  [ ! -e "$out/starter" ] || die "starter/ copied as is"
}

test_python_pack_has_no_lockfile() {
  local f
  for f in requirements.lock poetry.lock uv.lock Pipfile.lock pdm.lock; do
    [ ! -e "$REPO/languages/python/$f" ] || die "lockfile in the pack: $f"
  done
}

test_python_pack_pins_every_requirement_exactly() {
  local f line n=0
  for f in requirements.txt requirements-dev.txt; do
    while IFS= read -r line; do
      n=$((n + 1))
      [[ "$line" =~ ^[A-Za-z0-9._-]+==[0-9][0-9A-Za-z.]*$ ]] || die "$f: not pinned exactly: $line"
    done < <(grep -vE '^[[:space:]]*(#|$)' "$REPO/languages/python/$f")
  done
  [ "$n" -ge 4 ] || die "found only $n requirements; the parser is broken"
}

test_python_pre_commit_ruff_matches_the_pinned_ruff() {
  # The hook and CI must run the same Ruff, or a commit that passes the
  # hook can fail CI.
  local p="$REPO/languages/python" pinned rev
  pinned="$(sed -n 's/^ruff==//p' "$p/requirements-dev.txt")"
  [ -n "$pinned" ] || die "ruff not pinned in requirements-dev.txt"
  rev="$(grep -A1 'astral-sh/ruff-pre-commit' "$p/pre-commit-config.yaml" | sed -n 's/^ *rev: v//p')"
  [ "$rev" = "$pinned" ] || die "pre-commit ruff rev v$rev != requirements-dev ruff==$pinned"
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
  expect_fail "unknown pack: ruby" ruby "$WORK/o.$RANDOM"
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
  # Both placement tables: the template's README and the bootstrapper's.
  local f readme
  for readme in "$REPO/README.md" "$REPO/bootstrap/stubs/README.md"; do
    for f in ci.yml gitignore vscode-settings.json vscode-extensions.json package.json \
      tsconfig.json biome.json placeholder.test.ts index.html vite.config.mts \
      playwright.config.ts 'starter/src/' 'starter/e2e/' pyproject.toml requirements.txt \
      requirements-dev.txt pre-commit-config.yaml '.pre-commit-config.yaml' app.json; do
      grep -qF "\`$f\`" "$readme" || die "$readme table lacks $f"
    done
    grep -qE '^ *\| python: ' "$readme" || die "$readme table has no python row"
    grep -qE '^ *\| react-native: ' "$readme" || die "$readme table has no react-native row"
    grep -qE '^ *\|[^|]*react-native[^|]*: [^|]*`package.json`' "$readme" \
      || die "$readme table does not place react-native's package.json"
  done
}

test_packs_workflow_uses_the_script_for_every_pack() {
  local wf="$REPO/.github/workflows/packs.yml"
  [ -f "$wf" ] || die "no packs.yml"
  grep -qE '^  pack-node:' "$wf" || die "no pack-node job"
  grep -qE '^  pack-web:' "$wf" || die "no pack-web job"
  grep -qE '^  pack-python:' "$wf" || die "no pack-python job"
  grep -qE '^  pack-react-native:' "$wf" || die "no pack-react-native job"
  grep -qE 'tools/layout-pack\.sh react-native ' "$wf" || die "pack-react-native does not use layout-pack.sh"
  grep -qE 'tools/layout-pack\.sh python ' "$wf" || die "pack-python does not use layout-pack.sh"
  grep -qE 'tools/layout-pack\.sh node ' "$wf" || die "pack-node does not use layout-pack.sh"
  grep -qE 'tools/layout-pack\.sh web ' "$wf" || die "pack-web does not use layout-pack.sh"
  grep -qF 'npx playwright install --with-deps chromium' "$wf" || die "no browser install"
  grep -qF 'npm run test:e2e' "$wf" || die "no e2e run"
  grep -qF 'bash tools/test-layout-pack.sh' "$wf" || die "script tests not run"
}

test_packs_workflow_tests_the_pack_from_the_built_bootstrapper() {
  # Chain test: every pack job builds the bootstrapper, lays the pack out
  # from the build output's languages/ folder, and makes the project from
  # that output, with languages/ deleted.
  local wf="$REPO/.github/workflows/packs.yml" p n
  for p in node web python react-native; do
    grep -qE "PACKS_DIR=bootstrapper/languages bash template/tools/layout-pack\\.sh $p pack" "$wf" \
      || die "pack-$p does not lay out from the built bootstrapper"
  done
  n="$(grep -cF 'bash template/bootstrap/build.sh bootstrapper v0.0.0' "$wf")"
  [ "$n" -eq 4 ] || die "expected 4 bootstrapper builds in packs.yml, found $n"
  n="$(grep -cF 'cp -a bootstrapper project' "$wf")"
  [ "$n" -eq 4 ] || die "expected 4 project copies from the bootstrapper, found $n"
  n="$(grep -cF 'cp -a pack/. project/' "$wf")"
  [ "$n" -eq 4 ] || die "expected 4 pack overlays onto the project, found $n"
  n="$(grep -cF 'rm -rf project/languages' "$wf")"
  [ "$n" -eq 4 ] || die "expected 4 languages/ deletions, found $n"
  ! grep -qE 'layout-pack\.sh [a-z-]+ project' "$wf" || die "a pack job still lays out straight from the template"
}

test_packs_workflow_simulates_the_setup_change_and_a_refused_change() {
  # In every pack job the project is a git repo: the bootstrapper output is
  # committed on main and the pack is laid out on a `setup` branch. The
  # pack's own check runs verbatim on that change (with the base set to
  # main) and must pass; then a source change without a test is made and
  # the project's own check command, read from its ci.yml, must exit 1.
  local wf="$REPO/.github/workflows/packs.yml" n
  n="$(grep -cF 'git -C project init -q -b main' "$wf")"
  [ "$n" -eq 4 ] || die "expected 4 project repos (git init -b main), found $n"
  n="$(grep -cF 'git -C project checkout -q -b setup' "$wf")"
  [ "$n" -eq 4 ] || die "expected 4 setup branches, found $n"
  n="$(grep -cF 'run: bash .github/scripts/require-test-change.sh' "$wf")"
  [ "$n" -eq 4 ] || die "expected the check run verbatim in 4 pack jobs, found $n"
  n="$(grep -B3 -F 'run: bash .github/scripts/require-test-change.sh' "$wf" | grep -cF 'TEST_FIRST_BASE: main')"
  [ "$n" -eq 4 ] || die "expected TEST_FIRST_BASE: main on the 4 verbatim checks, found $n"
  n="$(grep -cF 'git merge -q --ff-only setup' "$wf")"
  [ "$n" -eq 4 ] || die "expected setup merged into main 4 times, found $n"
  n="$(grep -cF '[ "$rc" -eq 1 ]' "$wf")"
  [ "$n" -eq 4 ] || die "expected 4 refused-change assertions (exit 1), found $n"
  n="$(grep -cF 'cmd="$(sed -n' "$wf")"
  [ "$n" -eq 4 ] || die "expected the project's check command read from its ci.yml 4 times, found $n"
  # The refused-change step is the last step of each pack job, so the branch
  # it leaves behind cannot affect the pack's own steps.
  n="$(awk '
    /^  [a-z][a-z-]*:$/ { if (job ~ /^pack-(node|web|python|react-native)$/ && last ~ /Refuse a source change without a test/) ok++; job = $1; sub(":", "", job); last = "" }
    /^      - (name|uses): / { last = $0 }
    END { if (job ~ /^pack-(node|web|python|react-native)$/ && last ~ /Refuse a source change without a test/) ok++; print ok + 0 }
  ' "$wf")"
  [ "$n" -eq 4 ] || die "the refused-change step is not the last step of all 4 pack jobs (found $n)"
}

test_packs_workflow_node_version_matches_pack_ci() {
  local wf="$REPO/.github/workflows/packs.yml" v
  for p in node web react-native; do
    v="$(grep -oE 'node-version: "[0-9]+"' "$REPO/languages/$p/ci.yml")" || die "$p ci.yml has no node-version"
    grep -qF "$v" "$wf" || die "packs.yml lacks $v from the $p pack"
  done
}

test_packs_workflow_python_version_matches_pack_ci() {
  local wf="$REPO/.github/workflows/packs.yml" v
  v="$(grep -oE 'python-version: "[0-9.]+"' "$REPO/languages/python/ci.yml")" \
    || die "python ci.yml has no python-version"
  grep -qF "$v" "$wf" || die "packs.yml lacks $v from the python pack"
}

test_pack_ci_steps_are_single_line() {
  # The drift test below reads `run:` lines one at a time; a multi-line
  # `run: |` block would slip past it.
  local p
  for p in node web python react-native; do
    [ -f "$REPO/languages/$p/ci.yml" ] || die "no $p ci.yml"
    ! grep -nE '^ *run: *[|>]' "$REPO/languages/$p/ci.yml" || die "$p ci.yml has a multi-line run"
  done
}

test_packs_workflow_runs_every_pack_ci_step() {
  # packs.yml must run each pack's CI commands verbatim, so the two
  # cannot drift apart. `npm ci` is the one it may precede with
  # `npm install`, because the template has no lockfile.
  local wf="$REPO/.github/workflows/packs.yml" p cmd n=0
  for p in node web python react-native; do
    while IFS= read -r cmd; do
      n=$((n + 1))
      grep -qF -- "run: $cmd" "$wf" || die "packs.yml lacks the $p pack step: $cmd"
    done < <(sed -n 's/^ *run: //p' "$REPO/languages/$p/ci.yml")
  done
  [ "$n" -ge 17 ] || die "found only $n pack CI steps; the parser is broken"
}

test_packs_workflow_uses_the_pack_ci_action_versions() {
  local wf="$REPO/.github/workflows/packs.yml" u
  while IFS= read -r u; do
    grep -qF -- "$u" "$wf" || die "packs.yml lacks $u from the pack ci.yml"
  done < <(grep -hoE 'uses: [^ ]+' "$REPO/languages/node/ci.yml" "$REPO/languages/web/ci.yml" \
    "$REPO/languages/python/ci.yml" "$REPO/languages/react-native/ci.yml" | sort -u)
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
