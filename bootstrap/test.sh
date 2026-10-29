#!/usr/bin/env bash
# Tests for bootstrap/build.sh and bootstrap/publish.sh.
# Usage: bash bootstrap/test.sh
# Each test builds into its own temp dir. Fixture repos are small fake
# source trees with a copy of build.sh in their bootstrap/ folder, so the
# failure cases do not depend on this repo's real content.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
BUILD="$HERE/build.sh"
PUBLISH="$HERE/publish.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SHA="0123456789abcdef0123456789abcdef01234567"
PASSED=0
FAILED=0
FAILED_NAMES=()

# ---------- harness ----------

run_test() {
  local name="$1"
  local log="$WORK/$name.log" rc
  # Not inside an `if`: errexit is ignored in condition context.
  # Each test gets its own empty WORK, so the $RANDOM in its temp names
  # cannot collide with another test's.
  set +e
  ( set -euo pipefail; WORK="$WORK/$name.d"; mkdir "$WORK"; "$name" ) >"$log" 2>&1
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

test_harness_gives_each_test_an_empty_work_dir() {
  # Tests name their temp dirs "$WORK/<name>.$RANDOM". In one shared
  # WORK, two tests that draw the same number collide (seen once as
  # "out-dir ... real.4209 is not empty").
  [ -d "$WORK" ] || die "no WORK dir"
  [ -z "$(ls -A "$WORK")" ] || die "WORK is not empty: $(ls -A "$WORK" | head -n 3 | tr '\n' ' ')"
}

# expect_build_fail <fixture> <expected-stderr-substring> <out> <version> <commit>
expect_build_fail() {
  local fx="$1" msg="$2"; shift 2
  local err="$WORK/err.$RANDOM"
  if bash "$fx/bootstrap/build.sh" "$@" 2>"$err" >/dev/null; then
    die "build succeeded, expected failure containing: $msg"
  fi
  grep -qF -- "$msg" "$err" || { cat "$err" >&2; die "stderr lacks: $msg"; }
}

build_ok() {
  local fx="$1"; shift
  bash "$fx/bootstrap/build.sh" "$@" >/dev/null || die "build failed: $*"
}

# Sorted list of all files (and symlinks) under a dir, relative paths.
list_files() {
  (cd "$1" && find . \( -type f -o -type l \) | sed 's|^\./||' | LC_ALL=C sort)
}

# A small fake source repo with build.sh in bootstrap/.
make_fixture() {
  local d
  d="$(mktemp -d "$WORK/fx.XXXXXX")"
  mkdir -p "$d/bootstrap/stubs/docs" "$d/docs" "$d/lang/a" "$d/.github/workflows"
  cp "$BUILD" "$d/bootstrap/build.sh"
  cat >"$d/bootstrap/manifest.txt" <<'EOF'
# comment line, ignored

CLAUDE.md
.gitignore
lang/
.github/workflows/ci.yml
EOF
  echo "entry point" >"$d/CLAUDE.md"
  echo "*.tmp" >"$d/.gitignore"
  echo "x" >"$d/lang/a/x.txt"
  echo "b" >"$d/lang/b.txt"
  echo "hidden" >"$d/lang/.hidden"
  echo "name: CI" >"$d/.github/workflows/ci.yml"
  echo "name: template-only" >"$d/.github/workflows/other.yml"
  echo "release notes" >"$d/docs/RELEASE_NOTES.md"
  echo "not listed" >"$d/unlisted.md"
  printf '# Changelog\n\n## Created from template {{TEMPLATE_VERSION}} ({{TEMPLATE_COMMIT}})\n' \
    >"$d/bootstrap/stubs/CHANGELOG.md"
  printf '# Backlog\n\n## Open questions\n' >"$d/bootstrap/stubs/docs/BACKLOG.md"
  printf '%s\n' '#!/usr/bin/env bash' "SCRIPT_VERSION='{{TEMPLATE_VERSION}}'" \
    "SCRIPT_COMMIT='{{TEMPLATE_COMMIT}}'" 'echo "$SCRIPT_VERSION $SCRIPT_COMMIT"' \
    >"$d/bootstrap/stubs/bootstrap-project.sh"
  chmod 755 "$d/bootstrap/stubs/bootstrap-project.sh"
  printf '%s\n' '# The bootstrapper' '' 'Intro.' '' '{{TEMPLATE_README_SETUP}}' '' '## After' \
    >"$d/bootstrap/bootstrapper-README.md"
  printf '%s\n' '# Template' '' 'Before.' '<!-- bootstrapper-readme: start -->' 'Step 0.' '' 'Step 1.' \
    '<!-- bootstrapper-readme: end -->' 'After.' >"$d/README.md"
  echo "$d"
}

# ---------- build.sh: happy path ----------

test_fixture_output_is_exactly_manifest_plus_stubs() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  diff <(list_files "$out") <(printf '%s\n' \
    .github/README.md .github/workflows/ci.yml .gitignore CHANGELOG.md CLAUDE.md \
    bootstrap-project.sh docs/BACKLOG.md lang/.hidden lang/a/x.txt lang/b.txt | LC_ALL=C sort) \
    || die "output file list differs from manifest plus stubs"
}

test_copied_files_are_byte_identical() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  for f in CLAUDE.md .gitignore lang/a/x.txt lang/.hidden .github/workflows/ci.yml; do
    cmp -s "$fx/$f" "$out/$f" || die "$f differs from source"
  done
  cmp -s "$fx/bootstrap/stubs/docs/BACKLOG.md" "$out/docs/BACKLOG.md" \
    || die "stub docs/BACKLOG.md differs"
}

test_placeholders_replaced_with_version_and_commit() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  grep -qF "## Created from template v1.2.3 ($SHA)" "$out/CHANGELOG.md" \
    || { cat "$out/CHANGELOG.md" >&2; die "CHANGELOG not stamped"; }
  ! grep -rqF '{{TEMPLATE_' "$out" || die "placeholder left"
}

test_changelog_stamp_is_byte_for_byte_as_before() {
  # Stamping the script too must not change what the CHANGELOG gets.
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  cmp -s "$out/CHANGELOG.md" <(printf '# Changelog\n\n## Created from template v1.2.3 (%s)\n' "$SHA") \
    || { cat "$out/CHANGELOG.md" >&2; die "CHANGELOG stamp changed"; }
  [ ! -e "$out/CHANGELOG.md.tmp" ] || die "temp file left in output"
}

test_project_script_stub_is_stamped_with_version_and_commit() {
  local fx out f
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  f="$out/bootstrap-project.sh"
  grep -qxF "SCRIPT_VERSION='v1.2.3'" "$f" || { cat "$f" >&2; die "script version not stamped"; }
  grep -qxF "SCRIPT_COMMIT='$SHA'" "$f" || { cat "$f" >&2; die "script commit not stamped"; }
  ! grep -qF '{{TEMPLATE_' "$f" || die "placeholder left in the script"
  [ "$(bash "$f")" = "v1.2.3 $SHA" ] || die "stamped script does not report its stamp"
}

test_stamped_project_script_stays_executable() {
  # Stamping rewrites the file; it must keep the stub's executable bit
  # (a sed-to-temp-then-mv stamp would drop it).
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  [ -x "$out/bootstrap-project.sh" ] || { ls -l "$out" >&2; die "stamping dropped the executable bit"; }
}

test_project_script_stub_without_placeholders_rejected() {
  local fx; fx="$(make_fixture)"
  printf '%s\n' '#!/usr/bin/env bash' "SCRIPT_VERSION='{{TEMPLATE_VERSION}}'" \
    >"$fx/bootstrap/stubs/bootstrap-project.sh"
  expect_build_fail "$fx" "bootstrap-project.sh stub lacks {{TEMPLATE_COMMIT}}" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  printf '%s\n' '#!/usr/bin/env bash' "SCRIPT_COMMIT='{{TEMPLATE_COMMIT}}'" \
    >"$fx/bootstrap/stubs/bootstrap-project.sh"
  expect_build_fail "$fx" "bootstrap-project.sh stub lacks {{TEMPLATE_VERSION}}" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  rm "$fx/bootstrap/stubs/bootstrap-project.sh"
  expect_build_fail "$fx" "bootstrap-project.sh stub not found" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_stamped_stub_that_is_a_symlink_rejected() {
  # Stamping writes in place; through a symlink it would write into
  # whatever the link points at, possibly the source tree. The link is
  # absolute: a relative one would be broken once copied into the
  # build's temp folder, and nothing could be written through it.
  local fx target out err rc
  fx="$(make_fixture)"; out="$WORK/o.$RANDOM"; err="$WORK/err.$RANDOM"
  target="$WORK/outside-changelog.$RANDOM.md"
  mv "$fx/bootstrap/stubs/CHANGELOG.md" "$target"
  ln -s "$target" "$fx/bootstrap/stubs/CHANGELOG.md"
  set +e
  bash "$fx/bootstrap/build.sh" "$out" v1.2.3 "$SHA" >/dev/null 2>"$err"
  rc=$?
  set -e
  grep -qF '{{TEMPLATE_VERSION}}' "$target" || { cat "$target" >&2; die "the link target outside the build was modified"; }
  [ ! -L "$out/CHANGELOG.md" ] || die "CHANGELOG.md shipped as a symlink"
  [ "$rc" -ne 0 ] || die "build succeeded, expected the symlinked stub to be refused"
  grep -qF "CHANGELOG.md stub must be a regular file, not a symlink" "$err" || { cat "$err" >&2; die "stderr lacks the symlink refusal"; }
}

test_build_fails_if_stamping_drops_the_executable_bit() {
  # Pins the output check in build.sh: the fixture's own copy of
  # build.sh is patched so that the stamp step strips the mode, and the
  # build must then refuse. No hook in build.sh; the patch must apply,
  # or this test fails instead of passing on an unchanged copy.
  local fx b
  fx="$(make_fixture)"; b="$fx/bootstrap/build.sh"
  grep -qxF '  cat "$STAMP_TMP" >"$STAGE/$s"' "$b" || die "stamp line not found in build.sh; update this test"
  sed -e 's|^  cat "\$STAMP_TMP" >"\$STAGE/\$s"$|&; chmod a-x "$STAGE/$s"|' "$b" >"$b.new"
  cat "$b.new" >"$b"; rm "$b.new"
  grep -qF 'chmod a-x "$STAGE/$s"' "$b" || die "the patch did not apply"
  expect_build_fail "$fx" "stamping dropped the executable bit of bootstrap-project.sh" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_absent_out_dir_is_created() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/new.$RANDOM/nested"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  [ -f "$out/CLAUDE.md" ] || die "out-dir not created"
}

test_empty_existing_out_dir_is_accepted() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/empty.$RANDOM"; mkdir "$out"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  [ -f "$out/CLAUDE.md" ] || die "nothing written"
}

test_uppercase_hex_commit_is_accepted() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v10.0.12 "0123456789ABCDEF0123456789ABCDEF01234567"
}

test_open_questions_heading_is_not_a_false_positive() {
  # "Open questions" (no number) and "PBI-x" (no digit) must pass.
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  printf 'open questions\nPBI-x\nPR #3\ntrig\n' >>"$fx/CLAUDE.md"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
}

test_real_repo_build_matches_manifest_plus_stubs() {
  # Build this repo for real and compare against git-tracked files.
  local out expected
  out="$WORK/real.$RANDOM"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  expected="$WORK/expected.$RANDOM"
  {
    grep -vE '^[[:space:]]*(#|$)' "$REPO/bootstrap/manifest.txt" | grep -v '^exclude ' | while read -r p; do
      p="${p%/}"
      if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$REPO" ls-files -- "$p"
      else
        (cd "$REPO" && find "$p" -type f)
      fi
    done
    (cd "$REPO/bootstrap/stubs" && find . -type f | sed 's|^\./||')
    echo .github/README.md
  } | LC_ALL=C sort -u | grep -vxF -f <(sed -n 's/^exclude //p' "$REPO/bootstrap/manifest.txt"; echo '/nothing/') >"$expected"
  diff <(list_files "$out") "$expected" || die "real output differs from manifest plus stubs"
  grep -qF "v2.1.0" "$out/CHANGELOG.md" || die "real CHANGELOG lacks version"
  grep -qF "$SHA" "$out/CHANGELOG.md" || die "real CHANGELOG lacks commit"
  [ ! -e "$out/docs/RELEASE_NOTES.md" ] || die "RELEASE_NOTES shipped"
  [ ! -e "$out/bootstrap" ] || die "bootstrap/ shipped"
  [ ! -e "$out/.github/workflows/bootstrapper.yml" ] || die "bootstrapper.yml shipped"
  [ ! -e "$out/.github/workflows/packs.yml" ] || die "packs.yml shipped"
  [ ! -e "$out/tools" ] || die "tools/ shipped"
}

test_real_build_ships_the_generic_docs() {
  # Generic docs every project needs ship; the template's own do not.
  local out="$WORK/real.$RANDOM"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -f "$out/docs/DEV_INFRASTRUCTURE.md" ] || die "DEV_INFRASTRUCTURE.md not shipped"
  [ -f "$out/languages/python/code-standards.md" ] || die "python pack not shipped"
  cmp -s "$REPO/docs/DEV_INFRASTRUCTURE.md" "$out/docs/DEV_INFRASTRUCTURE.md" \
    || die "DEV_INFRASTRUCTURE.md shipped altered"
}

test_real_build_ships_the_status_stub() {
  # Every project gets STATUS.md at its root, in the fixed format the
  # product owner's status overview reads, with its update rule in an
  # HTML comment at the top and every field still to be written.
  local out="$WORK/real.$RANDOM" want="$WORK/want.$RANDOM" body="$WORK/body.$RANDOM"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -f "$out/STATUS.md" ] || die "STATUS.md not shipped"
  cmp -s "$REPO/bootstrap/stubs/STATUS.md" "$out/STATUS.md" || die "STATUS.md shipped altered"
  [ "$(sed -n 1p "$out/STATUS.md")" = '<!--' ] || die "STATUS.md does not start with the comment that holds its update rule"
  sed -n '1,/^-->$/p' "$out/STATUS.md" >"$body"
  for t in 'in the same PR' 'Last update' 'Forward-looking only' 'History lives in Git'; do
    grep -qF -- "$t" "$body" || die "the update rule in STATUS.md does not say: $t"
  done
  sed '1,/^-->$/d' "$out/STATUS.md" >"$body"
  cat >"$want" <<'TEXT'

# Status

Last update: YYYY-MM-DD

## Phase
One line: where the project is in its life (idea, design, build, running).

## Current focus
What the project is working on now.

## Next step
The next concrete step and who takes it.

## Blockers
What stops progress, and who can unblock it. "None" when nothing does.
A blocker that waits on the product owner starts with "Product Owner:".
TEXT
  diff "$want" "$body" >&2 || die "STATUS.md after its comment is not the fixed format (diff above)"
}

test_real_build_ships_the_template_licence() {
  # The template's own files are PolyForm Noncommercial 1.0.0. The text
  # must ship unaltered, with a Required Notice line, in licenses/ and
  # never as a root LICENSE (which projects would inherit as their own).
  local out="$WORK/real.$RANDOM" lic="licenses/PolyForm-Noncommercial-1.0.0.md" sum
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -f "$out/$lic" ] || die "$lic not shipped"
  sum="$(sha256sum "$out/$lic" | cut -d' ' -f1)"
  [ "$sum" = "c0ea4a896d2c8c394b29f9427589996db826cd501c512279ff0ed3ef48fabbe5" ] \
    || die "$lic differs from the official PolyForm Noncommercial 1.0.0 text"
  grep -qE '^Required Notice: Copyright .+' "$out/licenses/NOTICE" \
    || die "licenses/NOTICE lacks a Required Notice line"
  [ ! -e "$out/LICENSE" ] || die "root LICENSE shipped"
  [ ! -e "$out/LICENSE.md" ] || die "root LICENSE.md shipped"
}

test_real_stubs_have_no_forbidden_strings() {
  ! grep -rnE 'trig_|PBI-[0-9]|open question [0-9]' "$REPO/bootstrap/stubs" || die "forbidden regex in stubs"
  ! grep -rnF '(PR #' "$REPO/bootstrap/stubs" || die "(PR # in stubs"
}

test_shipped_ci_does_not_reference_bootstrap() {
  # What ships is the stub (the template's own ci.yml does not ship).
  local stub="$REPO/bootstrap/stubs/.github/workflows/ci.yml"
  [ -f "$stub" ] || die "no stub ci.yml at bootstrap/stubs/.github/workflows/ci.yml"
  ! grep -n 'bootstrap/' "$stub" || die "stub ci.yml references bootstrap/"
  ! grep -n 'tools/' "$stub" || die "stub ci.yml references tools/"
  ! grep -n 'require-test-change' "$stub" || die "stub ci.yml runs the check (a project with no pack has no src/ to define)"
}

test_real_build_ships_the_stub_ci_unchanged() {
  local out="$WORK/real.$RANDOM" f=".github/workflows/ci.yml"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  cmp -s "$REPO/bootstrap/stubs/$f" "$out/$f" || die "shipped ci.yml differs from the stub"
  ! grep -q 'require-test-change' "$out/$f" || die "shipped ci.yml runs the template's check"
  grep -qE '^  build:' "$out/$f" || die "shipped ci.yml has no job named build"
}

test_template_ci_is_not_in_the_manifest() {
  ! grep -vE '^[[:space:]]*(#|$)' "$REPO/bootstrap/manifest.txt" | grep -xF '.github/workflows/ci.yml' >/dev/null \
    || die "the template's own ci.yml is listed in the manifest, so it would ship"
}

# ---------- changelog.yml: the reminder after a merge (shipped) ----------
# After a merge, changelog.yml asks Crog for a CHANGELOG.md PR. A PR that
# already changed CHANGELOG.md (such as a project's setup PR) gets no
# reminder. The tests run the step's own run: script with a stub gh on
# PATH that logs its calls and answers `gh api` with a list of files.

CWF="$REPO/.github/workflows/changelog.yml"
CHANGELOG_REMINDER="<!-- clead-changelog-step --> PR merged. Crog: open a PR updating CHANGELOG.md."

# changelog_step_script <out>: write the step's run: | script to <out>.
changelog_step_script() {
  [ "$(grep -cE '^ *run:' "$CWF")" = 1 ] || die "changelog.yml must have exactly one run: step"
  wf_run_block <"$CWF" >"$1"
  [ -s "$1" ] || die "changelog.yml has no run: | script"
}

# run_changelog_step <dir> [file ...]: run the step for PR 7 of o/r with
# a stub gh whose `gh api` prints the given file names, one per line (or
# fails when GH_API_FAIL is set). Leaves the gh calls in <dir>/gh.log,
# the output in <dir>/out and the exit code in <dir>/rc.
run_changelog_step() {
  local d="$1" rc=0; shift
  mkdir -p "$d/bin"
  : >"$d/gh.log"
  if [ "$#" -gt 0 ]; then printf '%s\n' "$@" >"$d/files"; else : >"$d/files"; fi
  cat >"$d/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_GH_LOG"
case "$1" in
  api) if [ -n "${GH_API_FAIL:-}" ]; then echo "HTTP 502: Bad Gateway" >&2; exit 1; fi; cat "$STUB_GH_FILES" ;;
  pr) exit 0 ;;
  *) echo "stub gh: unexpected call: $*" >&2; exit 64 ;;
esac
STUB
  chmod 755 "$d/bin/gh"
  changelog_step_script "$d/step.sh"
  PATH="$d/bin:$PATH" STUB_GH_LOG="$d/gh.log" STUB_GH_FILES="$d/files" \
    PR_NUMBER=7 REPO=o/r GH_TOKEN=t bash "$d/step.sh" >"$d/out" 2>&1 || rc=$?
  echo "$rc" >"$d/rc"
}

# The two calls the step may make, as the stub logs them.
CHANGELOG_API_CALL="api repos/o/r/pulls/7/files?per_page=100 --paginate --jq .[].filename"
CHANGELOG_COMMENT_CALL="pr comment 7 --body $CHANGELOG_REMINDER --repo o/r"

test_changelog_reminder_is_posted_when_the_merged_pr_did_not_change_the_changelog() {
  local d="$WORK/step"
  run_changelog_step "$d" src/app.ts README.md docs/CHANGELOG.md
  [ "$(cat "$d/rc")" = 0 ] || { cat "$d/out" >&2; die "the step failed"; }
  printf '%s\n' "$CHANGELOG_API_CALL" "$CHANGELOG_COMMENT_CALL" >"$d/want"
  diff "$d/want" "$d/gh.log" >&2 || die "the step did not read the PR's files and then post the reminder"
}

test_changelog_reminder_is_skipped_when_the_merged_pr_changed_the_changelog() {
  # CHANGELOG.md anywhere in the list (the API pages are joined), and
  # as the only file.
  local d files
  for files in "README.md CHANGELOG.md src/app.ts" "CHANGELOG.md"; do
    d="$WORK/step.$RANDOM"
    # shellcheck disable=SC2086 # split the list into file names
    run_changelog_step "$d" $files
    [ "$(cat "$d/rc")" = 0 ] || { cat "$d/out" >&2; die "the step failed for: $files"; }
    printf '%s\n' "$CHANGELOG_API_CALL" >"$d/want"
    diff "$d/want" "$d/gh.log" >&2 || die "the step posted a comment although the PR changed CHANGELOG.md: $files"
    grep -qF "already changes CHANGELOG.md" "$d/out" || { cat "$d/out" >&2; die "no log line says why the reminder was skipped"; }
  done
}

test_changelog_reminder_is_skipped_when_the_changelog_comes_first_in_a_long_list() {
  # GitHub lists files in path order, so a root CHANGELOG.md comes early.
  # A check that stops reading at the match (grep -q at the end of a
  # pipe) can make the writer die of SIGPIPE; under pipefail that reads
  # as "not found" and the reminder is posted. About 200 KB of names
  # after the match make that happen every time.
  local d="$WORK/step"
  # shellcheck disable=SC2046 # one argument per generated name
  run_changelog_step "$d" CHANGELOG.md $(seq -f 'src/components/feature-%04g/index.test.ts' 1 5000)
  [ "$(cat "$d/rc")" = 0 ] || { tail -n 5 "$d/out" >&2; die "the step failed"; }
  printf '%s\n' "$CHANGELOG_API_CALL" >"$d/want"
  diff "$d/want" "$d/gh.log" >&2 || die "the step posted a comment although CHANGELOG.md is first in the list"
}

test_changelog_reminder_step_fails_and_posts_nothing_when_the_file_list_cannot_be_read() {
  local d="$WORK/step"
  GH_API_FAIL=1 run_changelog_step "$d" src/app.ts
  [ "$(cat "$d/rc")" != 0 ] || die "the step passed although gh api failed"
  printf '%s\n' "$CHANGELOG_API_CALL" >"$d/want"
  diff "$d/want" "$d/gh.log" >&2 || die "the step posted a comment although it could not read the PR's files"
}

test_changelog_workflow_runs_on_merged_prs_with_the_token_it_needs() {
  grep -qE '^    types: \[closed\]$' "$CWF" || die "changelog.yml no longer runs on closed PRs"
  grep -qxF '    if: github.event.pull_request.merged == true' "$CWF" || die "the job is not limited to merged PRs"
  # Least privilege: reading the PR's files needs pull requests read,
  # which pull-requests: write includes. Nothing else.
  [ "$(awk '/^    permissions:/ { p = 1; next } p && /^      / { print; next } { p = 0 }' "$CWF")" = '      pull-requests: write' ] \
    || die "the job's permissions are not exactly pull-requests: write"
  grep -qxF '          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}' "$CWF" || die "the step does not get the job's token"
  grep -qxF '          PR_NUMBER: ${{ github.event.pull_request.number }}' "$CWF" || die "the step does not get the PR number"
  grep -qxF '          REPO: ${{ github.repository }}' "$CWF" || die "the step does not get the repo"
  local s="$WORK/step.sh"
  changelog_step_script "$s"
  ! grep -nF '${{' "$s" >&2 || die "the run: script uses an expression; pass it in env instead"
}

# ---------- build.sh: argument errors ----------

test_wrong_arg_count_fails_with_usage() {
  local fx; fx="$(make_fixture)"
  expect_build_fail "$fx" "usage:" "$WORK/o.$RANDOM" v1.2.3
  expect_build_fail "$fx" "usage:" "$WORK/o.$RANDOM" v1.2.3 "$SHA" extra
}

test_bad_version_rejected() {
  local fx v; fx="$(make_fixture)"
  for v in 1.2.3 v1.2 v1.2.3-rc1 V1.2.3 "v1.2.3 " "" v1.2.x; do
    expect_build_fail "$fx" "is not vMAJOR.MINOR.PATCH" "$WORK/o.$RANDOM" "$v" "$SHA"
  done
}

test_bad_commit_rejected() {
  local fx c; fx="$(make_fixture)"
  for c in "${SHA:0:39}" "${SHA}0" "g${SHA:1}" "" "${SHA:0:7}"; do
    expect_build_fail "$fx" "is not a 40-character hex SHA" "$WORK/o.$RANDOM" v1.2.3 "$c"
  done
}

test_non_empty_out_dir_rejected_and_untouched() {
  local fx out; fx="$(make_fixture)"; out="$WORK/full.$RANDOM"
  mkdir "$out"; echo keep >"$out/.existing"
  expect_build_fail "$fx" "is not empty" "$out" v1.2.3 "$SHA"
  [ "$(list_files "$out")" = ".existing" ] || die "out-dir was modified"
}

test_out_dir_that_is_a_file_rejected() {
  local fx out; fx="$(make_fixture)"; out="$WORK/file.$RANDOM"
  echo x >"$out"
  expect_build_fail "$fx" "is not a directory" "$out" v1.2.3 "$SHA"
}

# ---------- build.sh: manifest and stub errors ----------

test_missing_manifest_path_rejected() {
  local fx out; fx="$(make_fixture)"; out="$WORK/o.$RANDOM"
  echo "docs/NOPE.md" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "manifest path does not exist: docs/NOPE.md" "$out" v1.2.3 "$SHA"
  [ ! -e "$out" ] || die "failed build left output behind"
}

test_missing_manifest_file_rejected() {
  local fx; fx="$(make_fixture)"
  rm "$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "manifest not found" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_manifest_path_escaping_repo_rejected() {
  local fx p; fx="$(make_fixture)"
  for p in /etc/passwd ../outside lang/../CLAUDE.md; do
    fx="$(make_fixture)"
    echo "$p" >>"$fx/bootstrap/manifest.txt"
    expect_build_fail "$fx" "must be relative" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  done
}

test_manifest_glob_is_not_expanded() {
  local fx; fx="$(make_fixture)"
  echo "lang/*.txt" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "manifest path does not exist: lang/*.txt" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_stub_same_path_as_manifest_entry_rejected() {
  local fx; fx="$(make_fixture)"
  echo "stub" >"$fx/bootstrap/stubs/CLAUDE.md"
  expect_build_fail "$fx" "stub overlaps manifest path (ambiguous source): CLAUDE.md" \
    "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_stub_inside_manifest_directory_rejected() {
  local fx; fx="$(make_fixture)"
  mkdir -p "$fx/bootstrap/stubs/lang/a"
  echo "stub" >"$fx/bootstrap/stubs/lang/a/new.txt"
  expect_build_fail "$fx" "stub overlaps manifest path (ambiguous source): lang/a/new.txt" \
    "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

# ---------- build.sh: the bootstrapper's own README ----------
# Spec: docs/BACKLOG.md, PBI-1.29, item 2. The bootstrapper's README is
# bootstrap/bootstrapper-README.md with its {{TEMPLATE_README_SETUP}}
# line replaced by the lines between the two markers in the template's
# README.md, written to .github/README.md (GitHub shows it before the
# root README.md, which stays the README a new project starts with).

test_build_writes_the_bootstrapper_readme_from_its_source_and_the_marked_part() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  diff <(printf '%s\n' '# The bootstrapper' '' 'Intro.' '' 'Step 0.' '' 'Step 1.' '' '## After') \
    "$out/.github/README.md" >&2 || die ".github/README.md is not the source with the marked part in place (diff above)"
  [ ! -e "$out/README.md" ] || die "the template's README.md shipped"
}

test_bootstrapper_readme_source_missing_rejected() {
  local fx out; fx="$(make_fixture)"; out="$WORK/o.$RANDOM"
  rm "$fx/bootstrap/bootstrapper-README.md"
  expect_build_fail "$fx" "bootstrapper README source not found: bootstrap/bootstrapper-README.md" "$out" v1.2.3 "$SHA"
  [ ! -e "$out" ] || die "failed build left output behind"
}

test_bootstrapper_readme_placeholder_must_be_one_line_of_its_own() {
  local fx
  fx="$(make_fixture)"
  printf '%s\n' '# B' 'no placeholder here' >"$fx/bootstrap/bootstrapper-README.md"
  expect_build_fail "$fx" "bootstrap/bootstrapper-README.md must have the line {{TEMPLATE_README_SETUP}} exactly once" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  printf '%s\n' '# B' '{{TEMPLATE_README_SETUP}}' '{{TEMPLATE_README_SETUP}}' >"$fx/bootstrap/bootstrapper-README.md"
  expect_build_fail "$fx" "bootstrap/bootstrapper-README.md must have the line {{TEMPLATE_README_SETUP}} exactly once" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  printf '%s\n' '# B' 'see {{TEMPLATE_README_SETUP}} here' >"$fx/bootstrap/bootstrapper-README.md"
  expect_build_fail "$fx" "bootstrap/bootstrapper-README.md must have the line {{TEMPLATE_README_SETUP}} exactly once" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_template_readme_markers_must_be_there_once_and_in_order() {
  local fx s='<!-- bootstrapper-readme: start -->' e='<!-- bootstrapper-readme: end -->'
  fx="$(make_fixture)"
  printf '%s\n' '# T' 'Step 0.' "$e" >"$fx/README.md"
  expect_build_fail "$fx" "README.md must have the line $s exactly once" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  printf '%s\n' '# T' "$s" 'Step 0.' >"$fx/README.md"
  expect_build_fail "$fx" "README.md must have the line $e exactly once" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  printf '%s\n' "$s" 'a' "$e" "$s" 'b' "$e" >"$fx/README.md"
  expect_build_fail "$fx" "README.md must have the line $s exactly once" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  printf '%s\n' "$e" 'Step 0.' "$s" >"$fx/README.md"
  expect_build_fail "$fx" "README.md: the line $s must come before $e" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  printf '%s\n' "$s" '' '   ' "$e" >"$fx/README.md"
  expect_build_fail "$fx" "README.md: nothing between $s and $e" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  rm "$fx/README.md"
  expect_build_fail "$fx" "template README not found: README.md" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_a_stub_at_the_bootstrapper_readme_path_rejected() {
  local fx; fx="$(make_fixture)"
  mkdir -p "$fx/bootstrap/stubs/.github"
  echo "stub" >"$fx/bootstrap/stubs/.github/README.md"
  expect_build_fail "$fx" "the build writes .github/README.md, but a manifest path or a stub already gives it" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_a_manifest_path_at_the_bootstrapper_readme_path_rejected() {
  local fx; fx="$(make_fixture)"
  echo "readme" >"$fx/.github/README.md"
  echo ".github/README.md" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "the build writes .github/README.md, but a manifest path or a stub already gives it" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_the_marked_part_goes_through_the_output_checks() {
  local fx; fx="$(make_fixture)"
  printf '%s\n' '<!-- bootstrapper-readme: start -->' 'see PBI-4' '<!-- bootstrapper-readme: end -->' >"$fx/README.md"
  expect_build_fail "$fx" "in output file: .github/README.md" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

# ---------- build.sh: paths left out of a listed folder ----------

test_manifest_exclude_leaves_a_file_out_of_a_listed_folder() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  echo "exclude lang/b.txt" >>"$fx/bootstrap/manifest.txt"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  [ ! -e "$out/lang/b.txt" ] || die "the excluded file shipped"
  [ -f "$out/lang/a/x.txt" ] || die "the rest of the folder did not ship"
}

test_manifest_exclude_of_a_missing_path_rejected() {
  local fx; fx="$(make_fixture)"
  echo "exclude lang/nope.txt" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "manifest exclude path does not exist: lang/nope.txt" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_manifest_exclude_outside_a_listed_folder_rejected() {
  local fx; fx="$(make_fixture)"
  echo "exclude unlisted.md" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "manifest exclude path is not inside a listed folder: unlisted.md" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  fx="$(make_fixture)"
  echo "exclude CLAUDE.md" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "manifest exclude path is not inside a listed folder: CLAUDE.md" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_real_build_ships_the_bootstrapper_readme() {
  # The real source and the real marked part: steps 0 and 1 and the one
  # command are in it, the markers and the placeholder are not.
  local out="$WORK/real.$RANDOM" r
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  r="$out/.github/README.md"
  [ -f "$r" ] || die ".github/README.md not shipped"
  grep -qF '**Step 0: install gh and sign in.**' "$r" || die "step 0 is not in the bootstrapper's README"
  grep -qF '**Step 1: run the setup.**' "$r" || die "step 1 is not in the bootstrapper's README"
  grep -qxF 'gh api repos/factoincognito/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh && bash bootstrap-project.sh' "$r" \
    || die "the command that starts a new setup is not on a line of its own"
  ! grep -qF 'bootstrapper-readme:' "$r" || die "a marker line shipped"
  ! grep -qF '{{TEMPLATE_' "$r" || die "a placeholder shipped"
  ! grep -qF 'ai-project-template-v2' "$r" || die "the bootstrapper's README points to the template"
  cmp -s "$REPO/bootstrap/stubs/README.md" "$out/README.md" || die "the README a new project starts with is not the stub"
}

test_real_build_leaves_out_the_languages_readme() {
  local out="$WORK/real.$RANDOM"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ ! -e "$out/languages/README.md" ] || die "languages/README.md shipped"
  [ -f "$out/languages/web/code-standards.md" ] || die "the packs did not ship"
}

# ---------- build.sh: output checks ----------

test_release_notes_in_output_rejected() {
  local fx out; fx="$(make_fixture)"; out="$WORK/o.$RANDOM"
  echo "docs/RELEASE_NOTES.md" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "forbidden path in output: docs/RELEASE_NOTES.md" "$out" v1.2.3 "$SHA"
  [ ! -e "$out" ] || die "failed build left output behind"
}

test_bootstrap_dir_in_output_rejected() {
  local fx; fx="$(make_fixture)"
  echo "bootstrap" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "forbidden path in output: bootstrap/" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_bootstrap_stub_in_output_rejected() {
  local fx; fx="$(make_fixture)"
  mkdir -p "$fx/bootstrap/stubs/bootstrap"
  echo x >"$fx/bootstrap/stubs/bootstrap/x.sh"
  expect_build_fail "$fx" "forbidden path in output: bootstrap/" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_leftover_placeholder_rejected() {
  local fx out; fx="$(make_fixture)"; out="$WORK/o.$RANDOM"
  echo "built on {{TEMPLATE_DATE}}" >>"$fx/lang/b.txt"
  expect_build_fail "$fx" "placeholder left in output: lang/b.txt" "$out" v1.2.3 "$SHA"
  [ ! -e "$out" ] || die "failed build left output behind"
}

test_changelog_stub_without_placeholders_rejected() {
  # The stamp is the only link back to the template; losing it silently
  # would be worse than failing.
  local fx; fx="$(make_fixture)"
  printf '# Changelog\n\n## Created from template {{TEMPLATE_VERSION}}\n' \
    >"$fx/bootstrap/stubs/CHANGELOG.md"
  expect_build_fail "$fx" "CHANGELOG.md stub lacks {{TEMPLATE_COMMIT}}" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  rm "$fx/bootstrap/stubs/CHANGELOG.md"
  expect_build_fail "$fx" "CHANGELOG.md stub not found" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_placeholder_outside_changelog_not_replaced() {
  # Only the CHANGELOG and script stubs are stamped; the same placeholder
  # anywhere else is left in and therefore fails the build.
  local fx; fx="$(make_fixture)"
  echo "{{TEMPLATE_VERSION}}" >>"$fx/CLAUDE.md"
  expect_build_fail "$fx" "placeholder left in output: CLAUDE.md" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

check_forbidden_in_manifest_file() {
  local s="$1" fx out
  fx="$(make_fixture)"; out="$WORK/o.$RANDOM"
  printf 'line with %s inside\n' "$s" >>"$fx/lang/a/x.txt"
  expect_build_fail "$fx" "in output file: lang/a/x.txt" "$out" v1.2.3 "$SHA"
  [ ! -e "$out" ] || die "failed build left output behind"
}

test_forbidden_trig_rejected()          { check_forbidden_in_manifest_file 'trig_abc123'; }
test_forbidden_pr_ref_rejected()        { check_forbidden_in_manifest_file 'see (PR #58)'; }
test_forbidden_pbi_id_rejected()        { check_forbidden_in_manifest_file 'PBI-1.10'; }
test_forbidden_open_question_rejected() { check_forbidden_in_manifest_file 'open question 3'; }

test_forbidden_string_in_stub_rejected() {
  local fx; fx="$(make_fixture)"
  echo "see PBI-4" >>"$fx/bootstrap/stubs/docs/BACKLOG.md"
  expect_build_fail "$fx" "in output file: docs/BACKLOG.md" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_forbidden_string_in_dotfile_rejected() {
  local fx; fx="$(make_fixture)"
  echo "trig_x" >>"$fx/lang/.hidden"
  expect_build_fail "$fx" "in output file: lang/.hidden" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

# ---------- publish.sh (against local bare repos) ----------
# Bare repos are created with HEAD on main, like a new empty GitHub repo.

make_bootstrap_output() {
  local fx out
  # mktemp, not $RANDOM: callers use $(...), where bash 3.2 can repeat it.
  fx="$(make_fixture)"; out="$(mktemp -d "$WORK/pubout.XXXXXX")"
  build_ok "$fx" "$out" "$1" "$SHA"
  echo "$out"
}

test_make_bootstrap_output_gives_a_new_dir_on_each_call() {
  # bash 3.2 does not reseed $RANDOM in a command substitution inside a
  # subshell that already used it, so two $(...) calls in one test got
  # the same "$WORK/pubout.$RANDOM" and the second build found it full.
  local a b
  : "$RANDOM"  # seed this subshell first, as a test that used $RANDOM would
  a="$(make_bootstrap_output v1.0.0)"
  b="$(make_bootstrap_output v1.1.0)"
  [ -n "$a" ] && [ -n "$b" ] || die "a build failed"
  [ "$a" != "$b" ] || die "both calls returned $a"
  grep -qF v1.1.0 "$b/CHANGELOG.md" || die "second output is not v1.1.0"
}

test_publish_to_empty_repo_creates_first_commit_and_tag() {
  local remote out clone
  remote="$WORK/remote.$RANDOM.git"; git init -q --bare -b main "$remote"
  out="$(make_bootstrap_output v1.0.0)"
  bash "$PUBLISH" "$out" v1.0.0 "$SHA" "$remote" >/dev/null || die "publish failed"
  clone="$WORK/clone.$RANDOM"; git clone -q "$remote" "$clone"
  [ "$(git -C "$clone" rev-list --count HEAD)" = 1 ] || die "expected exactly one commit"
  [ "$(git -C "$clone" log -1 --format=%s)" = \
    "Bootstrapper v1.0.0 from factoincognito/ai-project-template-v2@$SHA" ] || die "bad commit message"
  [ "$(git -C "$clone" rev-parse "v1.0.0^{commit}")" = "$(git -C "$clone" rev-parse HEAD)" ] \
    || die "tag does not point at the release commit"
  diff <(git -C "$clone" ls-files | LC_ALL=C sort) <(list_files "$out") || die "tree differs"
}

test_publish_second_release_mirrors_output_and_keeps_history() {
  local remote out1 out2 clone
  remote="$WORK/remote.$RANDOM.git"; git init -q --bare -b main "$remote"
  out1="$(make_bootstrap_output v1.0.0)"
  echo "obsolete" >"$out1/obsolete.md"
  bash "$PUBLISH" "$out1" v1.0.0 "$SHA" "$remote" >/dev/null || die "publish 1 failed"
  out2="$(make_bootstrap_output v1.1.0)"
  bash "$PUBLISH" "$out2" v1.1.0 "$SHA" "$remote" >/dev/null || die "publish 2 failed"
  clone="$WORK/clone.$RANDOM"; git clone -q "$remote" "$clone"
  [ "$(git -C "$clone" rev-list --count HEAD)" = 2 ] || die "history not kept"
  [ ! -e "$clone/obsolete.md" ] || die "file not in output was not deleted"
  diff <(git -C "$clone" ls-files | LC_ALL=C sort) <(list_files "$out2") || die "tree differs"
  git -C "$clone" rev-parse -q --verify refs/tags/v1.0.0 >/dev/null || die "v1.0.0 tag gone"
  git -C "$clone" rev-parse -q --verify refs/tags/v1.1.0 >/dev/null || die "v1.1.0 tag missing"
}

test_publish_uses_existing_default_branch() {
  local remote seed out
  remote="$WORK/remote.$RANDOM.git"; git init -q --bare -b main "$remote"
  git -C "$remote" symbolic-ref HEAD refs/heads/trunk
  seed="$WORK/seed.$RANDOM"; git init -q -b trunk "$seed"
  echo seed >"$seed/seed.txt"; git -C "$seed" add .; git -C "$seed" -c user.name=test -c user.email=test@example.invalid commit -qm seed
  git -C "$seed" push -q "$remote" trunk
  out="$(make_bootstrap_output v1.0.0)"
  bash "$PUBLISH" "$out" v1.0.0 "$SHA" "$remote" >/dev/null || die "publish failed"
  [ "$(git -C "$remote" rev-list --count trunk)" = 2 ] || die "did not commit on trunk"
  ! git -C "$remote" rev-parse -q --verify refs/heads/main >/dev/null || die "created a main branch"
}

test_publish_fails_if_tag_exists_and_changes_nothing() {
  local remote out before
  remote="$WORK/remote.$RANDOM.git"; git init -q --bare -b main "$remote"
  out="$(make_bootstrap_output v1.0.0)"
  bash "$PUBLISH" "$out" v1.0.0 "$SHA" "$remote" >/dev/null || die "publish 1 failed"
  before="$(git -C "$remote" for-each-ref)"
  echo changed >"$out/CLAUDE.md"
  if bash "$PUBLISH" "$out" v1.0.0 "$SHA" "$remote" 2>"$WORK/perr" >/dev/null; then
    die "publish succeeded although tag exists"
  fi
  grep -qF "tag v1.0.0 already exists" "$WORK/perr" || { cat "$WORK/perr" >&2; die "bad message"; }
  [ "$(git -C "$remote" for-each-ref)" = "$before" ] || die "remote refs changed"
}

test_publish_rejects_bad_arguments() {
  local remote out
  remote="$WORK/remote.$RANDOM.git"; git init -q --bare -b main "$remote"
  out="$(make_bootstrap_output v1.0.0)"
  ! bash "$PUBLISH" "$out" 1.0.0 "$SHA" "$remote" 2>/dev/null || die "bad version accepted"
  ! bash "$PUBLISH" "$out" v1.0.0 abc "$remote" 2>/dev/null || die "bad commit accepted"
  ! bash "$PUBLISH" "$WORK/nope" v1.0.0 "$SHA" "$remote" 2>/dev/null || die "missing out-dir accepted"
  ! bash "$PUBLISH" "$out" v1.0.0 "$SHA" 2>/dev/null || die "missing remote accepted"
  [ -z "$(git -C "$remote" for-each-ref)" ] || die "remote changed"
}

# ---------- require-on-main.sh ----------
# A tagged commit may only be published if it is on main.

REQUIRE="$HERE/require-on-main.sh"

# A repo with main (two commits) and an unmerged side branch.
make_history_repo() {
  local d
  d="$(mktemp -d "$WORK/hist.XXXXXX")"
  git init -q -b main "$d"
  gc() { git -C "$d" -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }
  echo 1 >"$d/f"; gc add f; gc commit -qm one
  echo 2 >"$d/f"; gc commit -qam two
  gc checkout -q -b side
  echo 3 >"$d/f"; gc commit -qam unmerged
  gc checkout -q main
  echo "$d"
}

test_on_main_commit_on_main_accepted() {
  local d; d="$(make_history_repo)"
  bash "$REQUIRE" "$d" "$(git -C "$d" rev-parse main)" main >/dev/null || die "tip of main rejected"
  bash "$REQUIRE" "$d" "$(git -C "$d" rev-parse main~1)" main >/dev/null || die "older main commit rejected"
}

test_on_main_unmerged_commit_rejected() {
  local d; d="$(make_history_repo)"
  if bash "$REQUIRE" "$d" "$(git -C "$d" rev-parse side)" main 2>"$WORK/rerr" >/dev/null; then
    die "unmerged commit accepted"
  fi
  grep -qF "is not on main" "$WORK/rerr" || { cat "$WORK/rerr" >&2; die "bad message"; }
}

test_on_main_unknown_commit_rejected() {
  local d; d="$(make_history_repo)"
  if bash "$REQUIRE" "$d" "$SHA" main 2>"$WORK/rerr" >/dev/null; then
    die "unknown commit accepted"
  fi
  grep -qF "not found" "$WORK/rerr" || { cat "$WORK/rerr" >&2; die "bad message"; }
}

test_on_main_missing_ref_rejected() {
  local d; d="$(make_history_repo)"
  if bash "$REQUIRE" "$d" "$(git -C "$d" rev-parse main)" origin/main 2>"$WORK/rerr" >/dev/null; then
    die "missing ref accepted"
  fi
  grep -qF "ref origin/main not found" "$WORK/rerr" || { cat "$WORK/rerr" >&2; die "bad message"; }
}

test_on_main_bad_arguments_rejected() {
  local d; d="$(make_history_repo)"
  ! bash "$REQUIRE" "$d" abc main 2>/dev/null || die "bad commit accepted"
  ! bash "$REQUIRE" "$d" "$(git -C "$d" rev-parse main)" 2>/dev/null || die "missing arg accepted"
  ! bash "$REQUIRE" "$WORK/nope" "$SHA" main 2>/dev/null || die "missing repo accepted"
}

test_workflow_publish_requires_commit_on_main() {
  # The publish job must run the check against origin/main with full
  # history, before building or publishing.
  local wf="$REPO/.github/workflows/bootstrapper.yml"
  grep -qF 'fetch-depth: 0' "$wf" || die "publish checkout lacks fetch-depth: 0"
  grep -qE 'bootstrap/require-on-main\.sh .*origin/main' "$wf" || die "publish does not run require-on-main.sh against origin/main"
  awk '/require-on-main\.sh/ { c = NR } /bootstrap\/publish\.sh/ { p = NR } END { exit !(c && p && c < p) }' "$wf" \
    || die "on-main check does not come before publish.sh"
}

test_workflow_test_job_named_bootstrapper_test() {
  grep -qE '^  bootstrapper-test:' "$REPO/.github/workflows/bootstrapper.yml" || die "no bootstrapper-test job"
  grep -qE 'needs: \[bootstrapper-test, packs\]' "$REPO/.github/workflows/bootstrapper.yml" || die "publish does not need bootstrapper-test and packs"
}

test_workflow_publish_needs_the_pack_chain_test() {
  # The chain test (packs.yml) is a reusable workflow called on a tag,
  # and publish needs it, so a bootstrapper whose packs fail in a project
  # made from it is never published.
  local wf="$REPO/.github/workflows/bootstrapper.yml"
  grep -qE '^  packs:' "$wf" || die "no packs job in bootstrapper.yml"
  grep -qF 'uses: ./.github/workflows/packs.yml' "$wf" || die "packs job does not call packs.yml"
  grep -qE '^  workflow_call:' "$REPO/.github/workflows/packs.yml" || die "packs.yml is not callable"
}

# ---------- bootstrapper.yml: one required check over an OS matrix ----------
# Branch protection requires a check named bootstrapper-test. A matrix
# renames its checks ("job (ubuntu-latest)", ...), so the tests run in
# other jobs and bootstrapper-test is a single aggregate job that needs
# them, always runs, and fails unless every one of them succeeded: a job
# skipped because a need failed reports as success, which would turn
# the required check green on failing tests.

BWF="$REPO/.github/workflows/bootstrapper.yml"

# wf_job <id>: the lines of one job under jobs:, from "  <id>:" up to the
# next job or top-level key. Empty if there is no such job.
wf_job() {
  awk -v id="$1" '
    /^[^ #]/ { injobs = ($0 ~ /^jobs:/); inj = 0; next }
    injobs && /^  [A-Za-z0-9_-]+:/ { inj = ($0 ~ ("^  " id ":[[:space:]]*$")) }
    inj { print }' "$BWF"
}

# wf_job_ids: every job id under jobs:, one per line.
wf_job_ids() {
  awk '/^[^ #]/ { injobs = ($0 ~ /^jobs:/); next }
       injobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { sub(/^  /, ""); sub(/:.*/, ""); print }' "$BWF"
}

# wf_needs <id>: the job's needs, one per line. Only the inline form
# "needs: [a, b]" is read; any other form fails the test.
wf_needs() {
  local line
  line="$(wf_job "$1" | grep -E '^    needs:' || true)"
  [ -n "$line" ] || return 0
  grep -qE '^    needs: \[[A-Za-z0-9_, -]+\][[:space:]]*$' <<<"$line" \
    || die "needs of $1 is not in the form needs: [a, b]: $line"
  printf '%s\n' "$line" | sed -E 's/^    needs: \[//; s/\][[:space:]]*$//' | tr ',' '\n' | sed -E 's/^ +//; s/ +$//'
}

# wf_jobs_running <script>: ids of the jobs with a step line that runs
# the script with bash or /bin/bash and no arguments.
wf_jobs_running() {
  local id re
  re="^ *(run: )?(/bin/)?bash $(printf '%s' "$1" | sed 's/[./]/\\&/g') *$"
  for id in $(wf_job_ids); do
    if wf_job "$id" | grep -E "$re" >/dev/null; then echo "$id"; fi
  done
}

# wf_step <id> <regex>: the lines of the steps of a job that have a line
# matching the regex. Steps start at "      - ".
wf_step() {
  wf_job "$1" | awk -v re="$2" '
    /^      - / { if (hit) printf "%s", buf; buf = ""; hit = 0; instep = 1 }
    /^    [A-Za-z]/ { if (hit) printf "%s", buf; buf = ""; hit = 0; instep = 0 }
    instep { buf = buf $0 "\n"; if ($0 ~ re) hit = 1 }
    END { if (hit) printf "%s", buf }'
}

# wf_run_block: reads one step on stdin and prints its "run: |" script,
# dedented.
wf_run_block() {
  awk 'inrun && /[^[:space:]]/ { match($0, /^ */); if (RLENGTH <= ind) inrun = 0 }
       inrun { print substr($0, ind + 3); next }
       /^ *run: \|[[:space:]]*$/ { match($0, /^ */); ind = RLENGTH; inrun = 1 }'
}

# assert_gated <script>: the script runs in exactly one job, that job is
# not bootstrapper-test itself, and bootstrapper-test needs it.
assert_gated() {
  local jobs n
  jobs="$(wf_jobs_running "$1")"
  n="$(printf '%s' "$jobs" | grep -c . || true)"
  [ "$n" -eq 1 ] || die "$1 runs in $n jobs, expected 1: $jobs"
  [ "$jobs" != bootstrapper-test ] || die "$1 runs in bootstrapper-test itself, not in a job it needs"
  wf_needs bootstrapper-test | grep -xF "$jobs" >/dev/null || die "bootstrapper-test does not need $jobs, which runs $1"
}

# The job that runs the bootstrap script's tests (the OS matrix).
matrix_job() {
  local jobs
  jobs="$(wf_jobs_running bootstrap/test-bootstrap-project.sh)"
  [ -n "$jobs" ] || die "no job runs bootstrap/test-bootstrap-project.sh"
  [ "$(printf '%s\n' "$jobs" | sort -u | wc -l | tr -d ' ')" = 1 ] || die "several jobs run it: $jobs"
  printf '%s\n' "$jobs" | head -n 1
}

# wf_on: the workflow's on: block, without comments and blank lines.
wf_on() {
  awk '/^on:/ { p = 1; next } /^[^ #]/ { p = 0 } p' "$BWF" | grep -vE '^[[:space:]]*(#|$)' || true
}

test_workflow_bootstrapper_runs_on_pull_requests_to_main_and_v_tags_only() {
  # One run per pull request push: no branch push trigger, which ran the
  # whole OS matrix a second time for every push to a PR branch. Main
  # only changes through pull requests, which run it on the merge ref.
  # A pushed v* tag still runs the tests, the pack chain and publish.
  local want got
  want='  push:
    tags: ["v*"]
  pull_request:
    branches: [main]'
  got="$(wf_on)"
  [ "$got" = "$want" ] || { printf 'on: block is:\n%s\n' "$got" >&2; die "triggers are not pull_request to main and v* tags only"; }
}

test_workflow_bootstrapper_cancels_superseded_pr_runs_but_never_a_tag_run() {
  # A newer push to the same pull request cancels the older run; a tag
  # run (tests, pack chain, publish) is never cancelled in progress.
  local top pub
  top="$(awk '/^concurrency:/ { p = 1; print; next } /^[^ #]/ { p = 0 } p' "$BWF")"
  [ -n "$top" ] || die "no workflow-level concurrency"
  grep -qxF '  group: bootstrapper-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}' <<<"$top" \
    || { printf '%s\n' "$top" >&2; die "concurrency group is not per pull request (or per ref for a tag)"; }
  grep -qxF "  cancel-in-progress: \${{ github.event_name == 'pull_request' }}" <<<"$top" \
    || { printf '%s\n' "$top" >&2; die "cancel-in-progress is not limited to pull_request runs"; }
  [ "$(printf '%s\n' "$top" | grep -vE '^[[:space:]]*(#|$)' | wc -l | tr -d ' ')" = 3 ] \
    || { printf '%s\n' "$top" >&2; die "unexpected keys in the workflow-level concurrency"; }
  # The publish job keeps its own group, which never cancels a publish.
  pub="$(wf_job publish | awk '/^    concurrency:/ { p = 1; next } /^    [A-Za-z]/ { p = 0 } p')"
  [ "$pub" = '      group: bootstrapper-publish
      cancel-in-progress: false' ] || { printf '%s\n' "$pub" >&2; die "publish job concurrency changed"; }
}

# assert_no_continue_on_error: no continue-on-error key, bare or quoted
# ("continue-on-error": or 'continue-on-error':, which YAML reads as the
# same key), in bootstrapper-test or a job it needs, in the workflow at
# BWF; dies naming the job.
assert_no_continue_on_error() {
  local id ids n=0
  ids="bootstrapper-test $(wf_needs bootstrapper-test | tr '\n' ' ')"
  for id in $ids; do
    [ -n "$(wf_job "$id")" ] || die "no job $id"
    n=$((n + 1))
    ! wf_job "$id" | grep -nE '(^|[[:space:]])["'"'"']?continue-on-error["'"'"']?[[:space:]]*:' >&2 \
      || die "continue-on-error in $id"
  done
  CHECKED_IDS="$ids"
  CHECKED_N="$n"
}

test_workflow_no_continue_on_error_in_the_required_check_or_its_needs() {
  # continue-on-error on a test job or step turns a failing leg into a
  # success result, and the required check green with it.
  local id ids n
  assert_no_continue_on_error
  ids="$CHECKED_IDS"; n="$CHECKED_N"
  [ "$n" -ge 3 ] || die "expected bootstrapper-test and at least two needs, got: $ids"
  for id in scripts-test bootstrap-project-test; do
    grep -qF " $id " <<<" $ids " || die "$id is not checked (not needed by bootstrapper-test)"
  done
}

test_workflow_continue_on_error_check_catches_the_bare_and_quoted_key() {
  # YAML reads "continue-on-error": true and 'continue-on-error': true as
  # the same key as the bare one, so each of the three, on a step of a job
  # bootstrapper-test needs, must fail the check; the real workflow, copied
  # unchanged, must pass it. Not caught: the key inside a flow mapping,
  # such as "- {continue-on-error: true}" (preceded by "{", not a space).
  local fx key err
  fx="$WORK/bootstrapper.yml"
  cp "$BWF" "$fx"
  ( BWF="$fx"; assert_no_continue_on_error ) || die "the unchanged copy of the workflow fails the check"
  for key in 'continue-on-error' '"continue-on-error"' "'continue-on-error'"; do
    awk -v k="$key" '{ print }
      /^  scripts-test:[[:space:]]*$/ { injob = 1; next }
      /^  [A-Za-z0-9_-]+:/ { injob = 0 }
      injob && !done && /^      - uses: actions\/checkout/ { print "        " k ": true"; done = 1 }' "$BWF" >"$fx"
    grep -qF "        $key: true" "$fx" || die "fixture: the key $key was not inserted"
    err="$WORK/err.$RANDOM"
    if ( BWF="$fx"; assert_no_continue_on_error ) 2>"$err"; then
      die "the check passed a step with $key: true in scripts-test"
    fi
    grep -qF "continue-on-error in scripts-test" "$err" || { cat "$err" >&2; die "the check failed for another reason with $key"; }
  done
}

test_workflow_matrix_cannot_drop_an_os() {
  # An exclude: entry would remove a leg and the aggregate would never
  # see it. include: cannot remove one, so only exclude is refused.
  local j job o
  j="$(matrix_job)"; job="$(wf_job "$j")"
  ! printf '%s\n' "$job" | grep -nE '^[[:space:]]+exclude[[:space:]]*:' >&2 || die "$j has a matrix exclude"
  for o in ubuntu-latest macos-latest windows-latest; do
    printf '%s\n' "$job" | grep -E '^        os: \[' | grep -E "(\[|, *)$o *(,|\])" >/dev/null || die "$o missing from the matrix os list"
  done
}

test_workflow_macos_bash_check_passes_on_3_2_and_fails_on_5() {
  # Runs the macOS step's actual script with a fake bash on PATH (put
  # there by a fake ln standing in for linking /bin/bash), reporting
  # the version given, and a stub test file, so nothing slow runs.
  local j step script fake d v out rc
  j="$(matrix_job)"
  step="$(wf_step "$j" "^        if: runner[.]os == 'macOS'\$")"
  [ -n "$step" ] || die "no macOS step in $j"
  script="$WORK/mac.$RANDOM.sh"
  printf '%s\n' "$step" | wf_run_block >"$script"
  [ -s "$script" ] || die "empty macOS run script"
  fake="$WORK/fakebin.$RANDOM"; mkdir -p "$fake"
  # The fake ln writes a fake bash at its last argument.
  cat >"$fake/ln" <<'LN'
#!/bin/sh
for a in "$@"; do dest="$a"; done
cat >"$dest" <<'FB'
#!/bin/sh
case "$1" in
  --version) echo "GNU bash, version $FAKE_BASH_VERSION(1)-release"; exit 0 ;;
  -c) case "$2" in *BASH_VERSINFO*) echo "$FAKE_BASH_VERSION" | cut -d. -f1-2; exit 0 ;; esac ;;
esac
exec "$REAL_BASH" "$@"
FB
chmod +x "$dest"
LN
  chmod +x "$fake/ln"
  for v in 3.2.57 5.2.21; do
    d="$WORK/mac.$v.$RANDOM"; mkdir -p "$d/bootstrap" "$d/tmp"
    printf 'echo STUB TESTS RAN\n' >"$d/bootstrap/test-bootstrap-project.sh"
    set +e
    out="$(cd "$d" && PATH="$fake:$PATH" RUNNER_TEMP="$d/tmp" REAL_BASH="$BASH" FAKE_BASH_VERSION="$v" \
      "$BASH" --noprofile --norc -eo pipefail "$script" 2>&1)"
    rc=$?
    set -e
    [ -x "$d/tmp/bash32/bash" ] || { printf '%s\n' "$out" >&2; die "the step did not link a bash into RUNNER_TEMP; this test checks nothing"; }
    case "$v" in
      3.2.*)
        [ "$rc" -eq 0 ] || { printf '%s\n' "$out" >&2; die "check failed on bash $v"; }
        grep -qxF 'STUB TESTS RAN' <<<"$out" || { printf '%s\n' "$out" >&2; die "tests not run on bash $v"; } ;;
      *)
        [ "$rc" -ne 0 ] || { printf '%s\n' "$out" >&2; die "check passed on bash $v"; }
        grep -qF '::error::' <<<"$out" || { printf '%s\n' "$out" >&2; die "no ::error:: on bash $v"; }
        ! grep -qxF 'STUB TESTS RAN' <<<"$out" || die "tests ran on bash $v" ;;
    esac
  done
}

test_workflow_bootstrapper_test_is_one_job_that_always_runs() {
  local job
  job="$(wf_job bootstrapper-test)"
  [ -n "$job" ] || die "no bootstrapper-test job"
  # A matrix or a job name would rename the required check.
  ! grep -qE '^    (strategy|name):' <<<"$job" || die "bootstrapper-test has a matrix or a name; the check would be renamed"
  ! grep -qF 'matrix' <<<"$job" || die "bootstrapper-test uses a matrix"
  grep -qxE '    runs-on: ubuntu-latest' <<<"$job" || die "bootstrapper-test does not run on ubuntu-latest"
  # Without always(), a failed or cancelled need skips it, and a skipped
  # required check counts as passed.
  grep -qxE '    if: always\(\)' <<<"$job" || die "bootstrapper-test lacks if: always()"
  [ -n "$(wf_needs bootstrapper-test)" ] || die "bootstrapper-test needs nothing"
}

# ---------- the test jobs run only when a change can affect them ----------
# (PBI-1.22, part 1.) bootstrap/not-read-by-tests.txt lists the files no
# test reads; bootstrap/changed-inputs.sh needed <base> <head> says
# whether a change touches anything else, and remove deletes the listed
# files before the tests run in CI.

CHANGED_INPUTS="$HERE/changed-inputs.sh"
NOT_READ="$HERE/not-read-by-tests.txt"

# inputs_repo <dir>: a git repo with a few files, one commit (base).
inputs_repo() {
  mkdir -p "$1/docs" "$1/bootstrap"
  git -C "$1" init -q -b main
  printf 'x\n' >"$1/README.md"; printf 'x\n' >"$1/docs/BACKLOG.md"; printf 'x\n' >"$1/docs/SPEC.md"
  printf 'x\n' >"$1/bootstrap/build.sh"; printf 'x\n' >"$1/STATUS.md"
  printf '%s\n' '# comment' '' docs/BACKLOG.md STATUS.md >"$1/list"
  git -C "$1" add -A
  git -C "$1" -c user.name=T -c user.email=t@example.com commit -q -m base
}

# needed_in <dir> <change...>: makes the changes (shell commands run in
# <dir>), commits them, and prints the tool's answer for base..HEAD.
needed_in() {
  local d="$1"; shift
  ( cd "$d" && eval "$@" && git add -A && git -c user.name=T -c user.email=t@example.com commit -q --allow-empty -m change ) \
    || die "the change '$*' could not be made"
  ( cd "$d" && LIST="$d/list" bash "$CHANGED_INPUTS" needed HEAD~1 HEAD 2>/dev/null )
}

test_changed_inputs_says_the_tests_are_needed_unless_only_unread_files_changed() {
  local d
  [ -f "$CHANGED_INPUTS" ] || die "no bootstrap/changed-inputs.sh"
  d="$WORK/r1"; inputs_repo "$d"
  [ "$(needed_in "$d" 'printf y >>docs/BACKLOG.md')" = false ] || die "a change to a listed file alone needs the tests"
  [ "$(needed_in "$d" 'printf y >>docs/BACKLOG.md; printf y >>STATUS.md')" = false ] || die "two listed files need the tests"
  [ "$(needed_in "$d" 'printf y >>docs/BACKLOG.md; printf y >>README.md')" = true ] || die "a listed and an unlisted file do not need the tests"
  [ "$(needed_in "$d" 'printf y >>docs/SPEC.md')" = true ] || die "an unlisted doc does not need the tests"
  [ "$(needed_in "$d" 'printf y >new-file.md')" = true ] || die "a new file does not need the tests"
  # Deleting a listed file needs the tests: the list must keep naming
  # tracked files only, so that pull request also edits the list.
  [ "$(needed_in "$d" 'git rm -q STATUS.md')" = true ] || die "deleting a listed file does not need the tests"
  [ "$(needed_in "$d" 'printf x >STATUS.md')" = true ] || die "adding a listed file does not need the tests"
  [ "$(needed_in "$d" 'git rm -q bootstrap/build.sh')" = true ] || die "deleting an unlisted file does not need the tests"
  [ "$(needed_in "$d" 'git mv docs/BACKLOG.md docs/OTHER.md')" = true ] || die "renaming a listed file to an unlisted name does not need the tests"
  [ "$(needed_in "$d" 'true')" = true ] || die "an empty change does not need the tests"
  # The changed files are named on stderr, each with its side.
  d="$WORK/r1b"; inputs_repo "$d"
  ( cd "$d" && printf y >>README.md && git add -A && git -c user.name=T -c user.email=t@example.com commit -q -m c \
    && LIST="$d/list" bash "$CHANGED_INPUTS" needed HEAD~1 HEAD ) >"$WORK/out" 2>"$WORK/err"
  grep -qF 'read by the tests:     README.md' "$WORK/err" || { cat "$WORK/err" >&2; die "the changed file is not named"; }
  ( cd "$d" && printf y >>docs/BACKLOG.md && git add -A && git -c user.name=T -c user.email=t@example.com commit -q -m c \
    && LIST="$d/list" bash "$CHANGED_INPUTS" needed HEAD~1 HEAD ) >"$WORK/out" 2>"$WORK/err"
  grep -qF 'not read by the tests: docs/BACKLOG.md' "$WORK/err" || { cat "$WORK/err" >&2; die "the listed file is not named"; }
}

test_changed_inputs_refuses_what_it_cannot_judge() {
  # A commit it cannot read, a list it cannot read or a list entry that
  # is not a plain repo path: exit 2, so the workflow's step fails and
  # the gate does not pass on it.
  local d bad rc
  d="$WORK/r2"; inputs_repo "$d"
  set +e
  ( cd "$d" && LIST="$d/list" bash "$CHANGED_INPUTS" needed nosuchref HEAD ) >/dev/null 2>&1; rc=$?
  set -e
  [ "$rc" -eq 2 ] || die "an unknown commit: exit $rc, want 2"
  set +e
  ( cd "$d" && LIST="$d/missing" bash "$CHANGED_INPUTS" needed HEAD HEAD ) >/dev/null 2>&1; rc=$?
  set -e
  [ "$rc" -eq 2 ] || die "a missing list: exit $rc, want 2"
  for bad in '/etc/passwd' '../outside' 'docs/../README.md' 'docs/' 'docs/*.md' 'with space'; do
    printf '%s\n' "$bad" >"$d/badlist"
    set +e
    ( cd "$d" && LIST="$d/badlist" bash "$CHANGED_INPUTS" needed HEAD HEAD ) >/dev/null 2>"$WORK/err"; rc=$?
    set -e
    [ "$rc" -eq 2 ] || die "list entry '$bad': exit $rc, want 2"
    grep -qF 'not a plain repo path' "$WORK/err" || { cat "$WORK/err" >&2; die "list entry '$bad': not refused for its path"; }
  done
  set +e
  ( cd "$d" && LIST="$d/list" bash "$CHANGED_INPUTS" ) >/dev/null 2>&1; rc=$?
  set -e
  [ "$rc" -eq 2 ] || die "no subcommand: exit $rc, want 2"
}

test_changed_inputs_remove_deletes_only_the_listed_files() {
  local d rc
  d="$WORK/r3"; inputs_repo "$d"
  ( cd "$d" && LIST="$d/list" bash "$CHANGED_INPUTS" remove ) >"$WORK/out" 2>&1 || { cat "$WORK/out" >&2; die "remove failed"; }
  [ ! -e "$d/docs/BACKLOG.md" ] && [ ! -e "$d/STATUS.md" ] || die "a listed file is still there"
  [ -f "$d/README.md" ] && [ -f "$d/docs/SPEC.md" ] && [ -f "$d/bootstrap/build.sh" ] || die "an unlisted file was deleted"
  # A list saved with CR LF line ends works the same (Git Bash).
  printf 'x\n' >"$d/STATUS.md"
  printf '%s\r\n' '# c' STATUS.md >"$d/crlf"
  ( cd "$d" && LIST="$d/crlf" bash "$CHANGED_INPUTS" remove ) >/dev/null 2>&1 || die "remove with a CR LF list failed"
  [ ! -e "$d/STATUS.md" ] || die "a CR LF list did not delete its file"
  # Again, with the files gone: still fine.
  ( cd "$d" && LIST="$d/list" bash "$CHANGED_INPUTS" remove ) >/dev/null 2>&1 || die "remove failed when the files were already gone"
  # A listed folder is refused before anything is deleted.
  printf '%s\n' README.md docs >"$d/dirlist"
  set +e
  ( cd "$d" && LIST="$d/dirlist" bash "$CHANGED_INPUTS" remove ) >/dev/null 2>&1; rc=$?
  set -e
  [ "$rc" -eq 2 ] || die "a listed folder: exit $rc, want 2"
  [ -f "$d/README.md" ] || die "a file was deleted before the folder was refused"
}

test_not_read_list_holds_only_tracked_files_and_every_test_job_deletes_them() {
  # The real list: plain paths of files this repo tracks (a stale or
  # mistyped entry would let a pull request skip the tests for a file
  # that does not exist under that name), never a file the build or a
  # suite is named as reading here, and every job that runs tests
  # deletes the listed files first, so a test that starts reading one
  # fails in CI.
  local f j job
  [ -f "$NOT_READ" ] || die "no bootstrap/not-read-by-tests.txt"
  ( cd "$REPO" && LIST="$NOT_READ" bash "$CHANGED_INPUTS" needed HEAD HEAD ) >/dev/null 2>"$WORK/err" \
    || { cat "$WORK/err" >&2; die "the list does not pass the tool's own checks"; }
  grep -vE '^(#|$)' "$NOT_READ" >"$WORK/listed"
  [ -s "$WORK/listed" ] || die "the list is empty"
  while IFS= read -r f; do
    git -C "$REPO" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || die "listed but not tracked: $f"
    case "$f" in
      bootstrap/* | tools/* | languages/* | .github/* | README.md | CLAUDE.md | docs/SPEC.md | docs/DEV_INFRASTRUCTURE.md)
        die "listed, but the tests or the build read it: $f" ;;
    esac
    ! grep -qxF -- "$f" "$HERE/manifest.txt" || die "listed, but the build ships it: $f"
  done <"$WORK/listed"
  # tools/test-layout-pack.sh runs in packs.yml, which this PR does not
  # change: it runs on every pull request, so it is not skipped, and a
  # listed file it read would only show there. It reads none (measured).
  for j in $(wf_jobs_running bootstrap/test.sh) $(wf_jobs_running tools/test-require-test-change.sh) \
    $(wf_jobs_running bootstrap/test-e2e-check.sh) $(wf_jobs_running tools/test-check-status.sh) \
    "$(matrix_job)"; do
    job="$(wf_job "$j")"
    grep -qxF '        run: bash bootstrap/changed-inputs.sh remove' <<<"$job" \
      || die "job $j runs tests without deleting the files no test reads first"
    # Before the first step that runs a suite.
    awk '/run: bash bootstrap\/changed-inputs.sh remove/ { r = NR } /(\/bin\/)?bash (bootstrap|tools)\/test/ && !f { f = NR } END { exit !(r && f && r < f) }' <<<"$job" \
      || die "job $j deletes the files after a suite has run"
  done
}

test_workflow_test_jobs_run_only_when_the_changes_job_says_so() {
  # The changes job decides from the base branch's copy of the script and
  # the list; both test jobs need it and run only on "true"; the gate
  # needs it too.
  local j job ch
  ch="$(wf_job changes)"
  [ -n "$ch" ] || die "no changes job"
  grep -qF 'git show HEAD^1:bootstrap/changed-inputs.sh' <<<"$ch" || die "the changes job does not use the base branch's script"
  grep -qF 'git show HEAD^1:bootstrap/not-read-by-tests.txt' <<<"$ch" || die "the changes job does not use the base branch's list"
  grep -qF 'needed HEAD^1 HEAD' <<<"$ch" || die "the changes job does not compare the base with the merge commit"
  grep -qxF '          fetch-depth: 2' <<<"$ch" || die "the changes job does not fetch the base parent"
  grep -qxF '      needed: ${{ steps.judge.outputs.needed }}' <<<"$ch" || die "the changes job does not output needed"
  for j in scripts-test "$(matrix_job)"; do
    job="$(wf_job "$j")"
    [ "$(wf_needs "$j")" = changes ] || die "$j does not need changes (only)"
    grep -qxF "    if: needs.changes.outputs.needed == 'true'" <<<"$job" || die "$j does not run only when the tests are needed"
  done
  wf_needs bootstrapper-test | grep -xF changes >/dev/null || die "bootstrapper-test does not need changes"
}

test_workflow_changes_job_answers_true_unless_only_unread_files_changed() {
  # Runs the changes job's script in a repo whose HEAD is a merge commit
  # of a base and a branch, as GitHub checks out a pull request.
  local step script d out
  step="$(wf_step changes '^ *run: [|]')"
  script="$WORK/judge.sh"
  printf '%s\n' "$step" | wf_run_block >"$script"
  [ -s "$script" ] || die "no run script in the changes job"
  merge_case() { # <name> <event> <change in the branch> [broken] -> prints needed
    d="$WORK/m.$1"; mkdir -p "$d/bootstrap" "$d/docs"
    git -C "$d" init -q -b main
    cp "$CHANGED_INPUTS" "$d/bootstrap/changed-inputs.sh"; cp "$NOT_READ" "$d/bootstrap/not-read-by-tests.txt"
    [ -z "${4:-}" ] || printf '%s\n' '#!/usr/bin/env bash' 'exit 3' >"$d/bootstrap/changed-inputs.sh"
    printf 'x\n' >"$d/README.md"; printf 'x\n' >"$d/docs/BACKLOG.md"
    git -C "$d" add -A; git -C "$d" -c user.name=T -c user.email=t@example.com commit -q -m base
    git -C "$d" checkout -q -b pr
    ( cd "$d" && eval "$3" && git add -A && git -c user.name=T -c user.email=t@example.com commit -q -m pr )
    git -C "$d" checkout -q main
    git -C "$d" -c user.name=T -c user.email=t@example.com merge -q --no-ff -m merge pr
    : >"$WORK/out.$1"
    ( cd "$d" && EVENT="$2" GITHUB_OUTPUT="$WORK/out.$1" RUNNER_TEMP="$WORK" bash "$script" ) >/dev/null 2>&1 \
      || die "$1: the changes job failed"
    sed -n 's/^needed=//p' "$WORK/out.$1"
  }
  [ "$(merge_case docs pull_request 'printf y >>docs/BACKLOG.md')" = false ] || die "a pull request changing only docs/BACKLOG.md needs the tests"
  [ "$(merge_case readme pull_request 'printf y >>README.md')" = true ] || die "a pull request changing README.md does not need the tests"
  [ "$(merge_case list pull_request 'printf "README.md\n" >>bootstrap/not-read-by-tests.txt; printf y >>README.md')" = true ] \
    || die "a pull request that lists README.md itself skipped its own tests (the base's list must decide)"
  # A pull request cannot switch off its own tests through the list or
  # the script: the base branch's copies decide.
  [ "$(merge_case list2 pull_request 'printf "README.md\nbootstrap/not-read-by-tests.txt\n" >>bootstrap/not-read-by-tests.txt; printf y >>README.md')" = true ] \
    || die "a pull request listing README.md and the list itself skipped its own tests"
  [ "$(merge_case script pull_request 'printf "%s\n" "#!/usr/bin/env bash" "echo false" >bootstrap/changed-inputs.sh; printf y >>docs/BACKLOG.md')" = true ] \
    || die "a pull request that replaced the script skipped its own tests"
  [ "$(merge_case script2 pull_request 'printf "%s\n" "#!/usr/bin/env bash" "echo false" >bootstrap/changed-inputs.sh; printf "bootstrap/changed-inputs.sh\n" >>bootstrap/not-read-by-tests.txt; printf y >>docs/BACKLOG.md')" = true ] \
    || die "a pull request that replaced and listed the script skipped its own tests"
  # A judge that fails runs the tests (and does not block the pull request).
  [ "$(merge_case broken pull_request 'printf y >>docs/BACKLOG.md' broken)" = true ] || die "a failing judge did not run the tests"
  [ "$(merge_case tag push 'printf y >>docs/BACKLOG.md')" = true ] || die "a tag run does not run the tests"
  # A base branch without the script (the first pull request): the tests run.
  d="$WORK/m.nobase"; mkdir -p "$d/docs"
  git -C "$d" init -q -b main; printf 'x\n' >"$d/docs/BACKLOG.md"
  git -C "$d" add -A; git -C "$d" -c user.name=T -c user.email=t@example.com commit -q -m base
  git -C "$d" checkout -q -b pr; printf y >>"$d/docs/BACKLOG.md"; git -C "$d" -c user.name=T -c user.email=t@example.com commit -q -am pr
  git -C "$d" checkout -q main; git -C "$d" -c user.name=T -c user.email=t@example.com merge -q --no-ff -m merge pr
  : >"$WORK/out.nobase"
  ( cd "$d" && EVENT=pull_request GITHUB_OUTPUT="$WORK/out.nobase" RUNNER_TEMP="$WORK" bash "$script" ) >/dev/null 2>&1 || die "nobase: failed"
  [ "$(sed -n 's/^needed=//p' "$WORK/out.nobase")" = true ] || die "with no script on the base, the tests were skipped"
}

test_workflow_bootstrapper_test_passes_a_skip_only_when_the_changes_job_said_so() {
  # The gate's step with the results GitHub would pass when the test jobs
  # were skipped: it passes only for changes=success, needed=false and
  # both test jobs skipped; every other mix is judged in full and fails
  # (no shard reported).
  local step script d r
  step="$(wf_step bootstrapper-test '^ *run: [|]')"
  script="$WORK/gate.skip.sh"
  printf '%s\n' "$step" | wf_run_block >"$script"
  d="$WORK/gate.skip"; gate_fixture "$d"; rm -f "$d/shard-list/"*
  ( cd "$d" && RESULTS="success skipped skipped" CHANGES_RESULT=success TESTS_NEEDED=false TEST_RESULTS="skipped skipped" bash "$script" ) \
    >"$WORK/out" 2>&1 || { cat "$WORK/out" >&2; die "a pull request with only unread files did not pass"; }
  for r in "success|true|skipped skipped" "failure|false|skipped skipped" "success||skipped skipped" \
           "success|false|success skipped" "success|false|skipped success" "success|false|failure skipped" \
           "skipped|false|skipped skipped" "cancelled|false|skipped skipped" "success|False|skipped skipped"; do
    IFS='|' read -r c n t <<<"$r"
    ! ( cd "$d" && RESULTS="$c $t" CHANGES_RESULT="$c" TESTS_NEEDED="$n" TEST_RESULTS="$t" bash "$script" ) >/dev/null 2>&1 \
      || die "the gate passed: changes=$c needed='$n' tests='$t'"
  done
}

# ---------- bootstrapper-test: the shards of the OS legs ----------
# Each OS leg of the bootstrap script's tests runs as several shards
# (BOOTSTRAP_TEST_SHARD=i/n): shard i runs the tests at index i-1, i-1+n,
# ... of the harness's list, interleaved because the slow tests are
# spread over the whole list. Each shard records the tests it ran
# (BOOTSTRAP_TEST_MANIFEST); bootstrapper-test fails unless every need
# succeeded and, for every OS, shards 1..n together ran every test
# exactly once (bootstrap/check-shards.sh).

HARNESS="$HERE/test-bootstrap-project.sh"
CHECK_SHARDS="$HERE/check-shards.sh"

# run_harness <out> [NAME=value ...]: runs the harness with the given
# environment, stdout and stderr to <out>, and returns its exit code.
# Capped at 60 s (timeout, on the ubuntu runner): a harness that ignores
# list mode would otherwise run all of its tests here.
run_harness() {
  local out="$1" cap=""
  shift
  if command -v timeout >/dev/null 2>&1; then cap="timeout 60"; fi
  env "$@" $cap bash "$HARNESS" >"$out" 2>&1
}

# harness_tests: every test function the harness defines, sorted, read
# from its source independently of the harness's own list.
harness_tests() {
  grep -oE '^test_[A-Za-z0-9_]+\(\)' "$HARNESS" | sed 's/()$//' | LC_ALL=C sort
}

# harness_list <out> [shard]: the harness's list of the tests it would
# run (all, or one shard's), one name per line, nothing else in it.
harness_list() {
  local out="$1"
  if [ -n "${2:-}" ]; then
    run_harness "$out" BOOTSTRAP_TEST_LIST=1 BOOTSTRAP_TEST_SHARD="$2" || { head -n 5 "$out" >&2; die "list mode failed for shard ${2}"; }
  else
    run_harness "$out" BOOTSTRAP_TEST_LIST=1 || { head -n 5 "$out" >&2; die "list mode failed"; }
  fi
  ! grep -vE '^test_[A-Za-z0-9_]+$' "$out" | head -n 5 >&2 || die "list mode printed something other than test names (shard ${2:-all})"
}

test_harness_list_mode_lists_every_test_and_runs_none() {
  local got="$WORK/list" want="$WORK/want"
  harness_tests >"$want"
  [ "$(wc -l <"$want" | tr -d ' ')" -gt 100 ] || die "found too few tests in the harness source; this test checks nothing"
  harness_list "$got"
  LC_ALL=C sort "$got" | diff "$want" - >&2 || die "list mode does not list exactly the harness's tests (want, then got)"
}

test_harness_shards_together_run_every_test_exactly_once() {
  # For several shard counts, shards 1..n together list every test
  # once: none left out, none twice, and the shards differ in size by
  # at most one test.
  local want="$WORK/want" all="$WORK/all" n i sizes min max s
  harness_tests >"$want"
  for n in 1 2 3 4 5 7; do
    : >"$all"; sizes=""
    i=1
    while [ "$i" -le "$n" ]; do
      harness_list "$WORK/shard.$n.$i" "$i/$n"
      cat "$WORK/shard.$n.$i" >>"$all"
      sizes="$sizes $(wc -l <"$WORK/shard.$n.$i" | tr -d ' ')"
      i=$((i + 1))
    done
    [ -z "$(LC_ALL=C sort "$all" | uniq -d)" ] || { LC_ALL=C sort "$all" | uniq -d | head >&2; die "with $n shards, these tests run twice"; }
    LC_ALL=C sort "$all" | diff "$want" - >&2 || die "with $n shards, the shards together do not run every test once (want, then got)"
    min=""; max=""
    for s in $sizes; do
      if [ -z "$min" ] || [ "$s" -lt "$min" ]; then min="$s"; fi
      if [ -z "$max" ] || [ "$s" -gt "$max" ]; then max="$s"; fi
    done
    [ $((max - min)) -le 1 ] || die "with $n shards, the sizes are uneven:$sizes"
  done
}

test_harness_shards_interleave_by_index() {
  # Shard i of n holds the tests at index i-1, i-1+n, ... of the full
  # list, not a contiguous range: the slowest tests are spread over the
  # list, and contiguous ranges balanced worse (PBI-1.18).
  local full="$WORK/full" want="$WORK/want" i
  harness_list "$full"
  for i in 1 2 3 4; do
    awk -v i="$i" '(NR - 1) % 4 == i - 1' "$full" >"$want"
    harness_list "$WORK/got.$i" "$i/4"
    diff "$want" "$WORK/got.$i" >&2 || die "shard $i/4 is not every 4th test from index $((i - 1)) (want, then got)"
  done
}

test_harness_refuses_a_shard_setting_it_cannot_read() {
  local v out="$WORK/out" rc
  # The last ones overflow bash's integers (review of #178, B1): [ -gt ]
  # then errs inside an if, and the setting was taken.
  for v in 0/4 5/4 1/0 4 1/4/2 a/b 1/b -1/4 01/4 1/04 ' 1/4' '1 /4' 1/ \
           1/99999999999999999999 99999999999999999999/4 2/9223372036854775808 1/1000000; do
    set +e
    run_harness "$out" BOOTSTRAP_TEST_SHARD="$v"
    rc=$?
    set -e
    [ "$rc" -eq 2 ] || { head -n 5 "$out" >&2; die "BOOTSTRAP_TEST_SHARD='$v': exit $rc, want 2"; }
    grep -qF "BOOTSTRAP_TEST_SHARD" "$out" || { cat "$out" >&2; die "BOOTSTRAP_TEST_SHARD='$v': the message does not name the setting"; }
    ! grep -qE '^(ok|FAIL) ' "$out" || die "BOOTSTRAP_TEST_SHARD='$v': tests ran"
  done
}

test_harness_records_the_tests_it_ran() {
  # BOOTSTRAP_TEST_MANIFEST names a file (relative to where the harness
  # starts) that gets one line per test run. A shard count above the
  # number of tests leaves shard 1 with only the first test, so this
  # runs one real test.
  local d="$WORK/rec" first out="$WORK/out"
  harness_tests >"$WORK/tests"
  first="$(sed -n 1p "$WORK/tests")"
  mkdir -p "$d"
  ( cd "$d" && run_harness "$out" BOOTSTRAP_TEST_SHARD=1/100000 BOOTSTRAP_TEST_MANIFEST=list/ran.txt ) \
    || { tail -n 20 "$out" >&2; die "the one-test shard failed"; }
  [ -f "$d/list/ran.txt" ] || { cat "$out" >&2; die "no manifest at list/ran.txt, relative to where the harness started"; }
  [ "$(cat "$d/list/ran.txt")" = "$first" ] || { cat "$d/list/ran.txt" >&2; die "the manifest is not the one test that ran ($first)"; }
  grep -qxF "ok   $first" "$out" || { cat "$out" >&2; die "$first did not run"; }
  grep -qxF '1 passed, 0 failed' "$out" || { cat "$out" >&2; die "not exactly one test ran"; }
}

# ---------- shards split by measured duration (PBI-1.22, part 2) ----------
# With BOOTSTRAP_TEST_WEIGHTS=<file>:<column>, shard i of n holds the
# tests a greedy split by duration gives it: longest first, each to the
# shard with the least total so far (ties: the shard with fewer tests,
# then the lower one; equal weights keep the list's order). <file> has a
# header line "test <column names...>" and one line per test, its
# seconds in each column; a test the file does not list, or lists with
# 0, weighs the median (the lower middle one) of the column's other
# values. The split must still put every test in exactly one shard.

DURATIONS="$HERE/test-durations.txt"

test_harness_shards_by_duration_together_run_every_test_exactly_once() {
  # The real durations file and each of its columns, for several shard
  # counts: none left out, none twice.
  local want="$WORK/want" all="$WORK/all" n i col
  harness_tests >"$want"
  [ -f "$DURATIONS" ] || die "no bootstrap/test-durations.txt"
  for col in ubuntu-latest macos-latest windows-latest; do
    for n in 1 2 4 5; do
      : >"$all"
      i=1
      while [ "$i" -le "$n" ]; do
        run_harness "$WORK/s.$col.$n.$i" BOOTSTRAP_TEST_LIST=1 BOOTSTRAP_TEST_SHARD="$i/$n" \
          BOOTSTRAP_TEST_WEIGHTS="$DURATIONS:$col" || { head -n 5 "$WORK/s.$col.$n.$i" >&2; die "list mode failed ($col, $i/$n)"; }
        ! grep -vE '^test_[A-Za-z0-9_]+$' "$WORK/s.$col.$n.$i" | head -n 5 >&2 || die "list mode printed something other than test names"
        cat "$WORK/s.$col.$n.$i" >>"$all"
        i=$((i + 1))
      done
      [ -z "$(LC_ALL=C sort "$all" | uniq -d)" ] || { LC_ALL=C sort "$all" | uniq -d | head >&2; die "$col, $n shards: tests run twice"; }
      LC_ALL=C sort "$all" | diff "$want" - >&2 || die "$col, $n shards: not every test once (want, then got)"
    done
  done
}

test_harness_shards_by_duration_balance_the_measured_time() {
  # The greedy split by the durations file: for each column, the 4
  # shards' totals (by the same file) differ by at most the longest test.
  local col i tot max min longest
  for col in ubuntu-latest macos-latest windows-latest; do
    max=""; min=""
    for i in 1 2 3 4; do
      run_harness "$WORK/b.$col.$i" BOOTSTRAP_TEST_LIST=1 BOOTSTRAP_TEST_SHARD="$i/4" BOOTSTRAP_TEST_WEIGHTS="$DURATIONS:$col" \
        || die "list mode failed"
      tot="$(awk -v col="$col" 'NR == FNR { if (FNR == 1) { for (k = 2; k <= NF; k++) if ($k == col) c = k; next } w[$1] = $c * 100; next }
        { s += w[$1] } END { printf "%d\n", s }' "$DURATIONS" "$WORK/b.$col.$i")"
      if [ -z "$max" ] || [ "$tot" -gt "$max" ]; then max="$tot"; fi
      if [ -z "$min" ] || [ "$tot" -lt "$min" ]; then min="$tot"; fi
    done
    longest="$(awk -v col="$col" 'FNR == 1 { for (k = 2; k <= NF; k++) if ($k == col) c = k; next } $c * 100 > m { m = $c * 100 } END { printf "%d\n", m }' "$DURATIONS")"
    [ $((max - min)) -le "$longest" ] || die "$col: shard totals range ${min}..${max} (centiseconds), more than the longest test ($longest)"
  done
}

test_harness_shards_by_duration_follow_the_greedy_rule() {
  # A made-up weights file whose split is known: one test weighs 100000
  # seconds, one 1, and every unlisted test the median (here 1, the
  # middle of 1 and 100000 being taken as the lower one). Greedy puts the
  # heavy one alone in shard 1 and every other test in shard 2, whose
  # total never reaches 100000. An interleaved split would not.
  local w="$WORK/w" heavy light
  harness_tests >"$WORK/names"
  heavy="$(sed -n 5p "$WORK/names")"
  light="$(sed -n 9p "$WORK/names")"
  printf 'test a\n%s 100000\n%s 1\n' "$heavy" "$light" >"$w"
  run_harness "$WORK/g1" BOOTSTRAP_TEST_LIST=1 BOOTSTRAP_TEST_SHARD=1/2 BOOTSTRAP_TEST_WEIGHTS="$w:a" || { cat "$WORK/g1" >&2; die "list mode failed"; }
  run_harness "$WORK/g2" BOOTSTRAP_TEST_LIST=1 BOOTSTRAP_TEST_SHARD=2/2 BOOTSTRAP_TEST_WEIGHTS="$w:a" || { cat "$WORK/g2" >&2; die "list mode failed"; }
  [ "$(cat "$WORK/g1")" = "$heavy" ] || { cat "$WORK/g1" >&2; die "shard 1 is not the heavy test alone"; }
  grep -vxF "$heavy" "$WORK/names" | diff - "$WORK/g2" >&2 || die "shard 2 is not every other test, in the list's order (want, then got)"
}

# shard_of <weights> <column> <i> <n>: the harness's list of shard i of n.
shard_of() {
  run_harness "$WORK/one.$3" BOOTSTRAP_TEST_LIST=1 BOOTSTRAP_TEST_SHARD="$3/$4" BOOTSTRAP_TEST_WEIGHTS="$1:$2" \
    || { cat "$WORK/one.$3" >&2; die "list mode failed for shard $3/$4"; }
  cat "$WORK/one.$3"
}

# split_of <weights> <column> <n>: the harness's lists of shards 1..n,
# as "<shard> <test>" lines.
split_of() {
  local i=1
  while [ "$i" -le "$3" ]; do
    run_harness "$WORK/split.$i" BOOTSTRAP_TEST_LIST=1 BOOTSTRAP_TEST_SHARD="$i/$3" BOOTSTRAP_TEST_WEIGHTS="$1:$2" \
      || { cat "$WORK/split.$i" >&2; die "list mode failed for shard $i/$3"; }
    sed "s/^/$i /" "$WORK/split.$i"
    i=$((i + 1))
  done
}

test_harness_shards_by_duration_weigh_unlisted_and_zero_tests_as_the_lower_median() {
  # Four tests are listed with 10, 20, 30 and 0 seconds; the 0 counts as
  # not measured, so the measured ones are 10, 20 and 30 and their median
  # is 20, which every unlisted test and the 0 weigh too. With as many
  # shards as tests, each shard holds one test, in the order of the
  # split: the 30, then the 20s in list order (the 0-second test is the
  # first name, so it comes first among them), then the 10 last. A 0
  # weight for unlisted tests would put them last, the largest weight
  # first. Then 10, 20, 30 and 40 (an even count): the lower middle one,
  # 20, so the 40 and the 30 come first; the upper middle one (30) would
  # put an unlisted test next to the 30 in shard 2 (list order).
  local w="$WORK/w" n t10 t20 t30 t0 t40
  harness_tests >"$WORK/names"
  n="$(grep -c . "$WORK/names")"
  t0="$(sed -n 1p "$WORK/names")"; t10="$(sed -n 3p "$WORK/names")"
  t20="$(sed -n 7p "$WORK/names")"; t30="$(sed -n 11p "$WORK/names")"
  printf 'test a\n%s 10\n%s 20\n%s 30\n%s 0\n' "$t10" "$t20" "$t30" "$t0" >"$w"
  [ "$(shard_of "$w" a 1 "$n")" = "$t30" ] || die "shard 1 is not the 30-second test"
  [ "$(shard_of "$w" a 2 "$n")" = "$t0" ] || die "shard 2 is not the 0-second test (it should weigh the median, 20, and lead the 20s in list order)"
  [ "$(shard_of "$w" a "$n" "$n")" = "$t10" ] || die "the last shard is not the 10-second test (the unlisted tests should weigh the median, 20)"
  t40="$(sed -n 13p "$WORK/names")"
  printf 'test a\n%s 10\n%s 20\n%s 30\n%s 40\n' "$t10" "$t20" "$t30" "$t40" >"$w"
  [ "$(shard_of "$w" a 1 "$n")" = "$t40" ] || die "shard 1 is not the 40-second test"
  [ "$(shard_of "$w" a 2 "$n")" = "$t30" ] || die "shard 2 is not the 30-second test (the median of four is the lower middle one, 20)"
}

test_harness_shards_by_duration_break_ties_by_fewer_tests_then_lower_shard() {
  # Weights A=4, B=3, C=3 (in list order) and every other test 1, over
  # 2 shards. A goes to shard 1, B and C to shard 2 (6),
  # the next two 1s to shard 1 (6). The totals are equal, 6 and 6, with
  # 3 tests in shard 1 and 2 in shard 2: the next test goes to shard 2,
  # the one with fewer tests, although shard 1 is the lower. Then, all
  # weights equal: on equal totals and counts the lower shard, so the
  # tests alternate from shard 1 in list order.
  local w="$WORK/w" a b c rest4 rest5 got first second third
  harness_tests >"$WORK/names"
  a="$(sed -n 2p "$WORK/names")"; b="$(sed -n 4p "$WORK/names")"; c="$(sed -n 6p "$WORK/names")"
  { printf 'test x\n'; awk -v a="$a" -v b="$b" -v c="$c" '{ print $0, ($0 == a) ? 4 : ($0 == b || $0 == c) ? 3 : 1 }' "$WORK/names"; } >"$w"
  grep -vxF -e "$a" -e "$b" -e "$c" "$WORK/names" >"$WORK/rest"
  rest4="$(sed -n 1p "$WORK/rest")"; rest5="$(sed -n 3p "$WORK/rest")"
  got="$(shard_of "$w" x 2 2)"
  grep -qxF "$b" <<<"$got" && grep -qxF "$c" <<<"$got" || die "the two 3-second tests are not in shard 2"
  grep -qxF "$rest4" <<<"$got" && die "the first 1-second test is in shard 2, want shard 1"
  grep -qxF "$rest5" <<<"$got" || die "on equal totals (6 and 6) the next test did not go to shard 2, the one with fewer tests"
  { printf 'test x\n'; awk '{ print $0, 1 }' "$WORK/names"; } >"$w"
  got="$(shard_of "$w" x 1 2)"
  first="$(sed -n 1p "$WORK/names")"; second="$(sed -n 2p "$WORK/names")"; third="$(sed -n 3p "$WORK/names")"
  grep -qxF "$first" <<<"$got" && ! grep -qxF "$second" <<<"$got" && grep -qxF "$third" <<<"$got" \
    || die "equal weights do not alternate from shard 1 in list order"
}

test_harness_fails_when_its_shard_by_duration_selects_no_test() {
  # A split by duration with more shards than tests leaves the last one
  # empty: that run fails, says no test ran and names the total, and runs
  # nothing.
  local w="$WORK/w" n out="$WORK/out" rc
  harness_tests >"$WORK/names"
  n="$(grep -c . "$WORK/names")"
  printf 'test x\n%s 1\n' "$(sed -n 1p "$WORK/names")" >"$w"
  set +e
  run_harness "$out" BOOTSTRAP_TEST_SHARD="$((n + 1))/$((n + 1))" BOOTSTRAP_TEST_WEIGHTS="$w:x"
  rc=$?
  set -e
  [ "$rc" -eq 1 ] || { cat "$out" >&2; die "exit $rc, want 1"; }
  ! grep -qE '^(ok|FAIL) ' "$out" || die "tests ran"
  grep -qF "shard $((n + 1)) of $((n + 1)) selects none of the $n tests" "$out" || { cat "$out" >&2; die "the message does not name the shard and the $n tests"; }
}

test_harness_reads_a_weights_file_with_windows_line_endings() {
  # A durations file saved with CR LF line ends gives the same split as
  # the LF one, also when the column is the last one.
  local lf="$WORK/lf" crlf="$WORK/crlf"
  printf 'test a b c\n' >"$lf"
  harness_tests | awk '{ printf "%s 1 2 %d\n", $0, (NR * 37) % 101 }' >>"$lf"
  awk '{ printf "%s\r\n", $0 }' "$lf" >"$crlf"
  split_of "$lf" c 3 >"$WORK/want"
  split_of "$crlf" c 3 >"$WORK/got"
  diff "$WORK/want" "$WORK/got" >&2 || die "CR LF gave another split (LF, then CR LF)"
}

test_harness_refuses_weights_it_cannot_read() {
  # A weights setting that does not name a readable file and one of its
  # columns, or a file whose numbers are not numbers, stops the harness
  # with exit 2 before any test runs: a shard would otherwise run a
  # wrong set of tests.
  local w="$WORK/w" v why out="$WORK/out" rc
  printf 'test a\ntest_x 1\n' >"$w"
  printf 'test a\ntest_x one\n' >"$WORK/bad-number"
  printf 'nothead a\ntest_x 1\n' >"$WORK/bad-head"
  : >"$WORK/empty"
  printf 'test a\n' >"$WORK/header-only"
  mkdir -p "$WORK/a-folder"
  for v in "$WORK/missing:a|no readable file" "$w|not <file>:<column>" "$w:|not <file>:<column>" \
    ":a|not <file>:<column>" "$w:b|no column b" "$WORK/bad-number:a|no number in column a" \
    "$WORK/bad-head:a|not a header" "$WORK/empty:a|it is empty" "$WORK/header-only:a|no line of times" \
    "$WORK/a-folder:a|no readable file"; do
    why="${v##*|}"; v="${v%|*}"
    set +e
    run_harness "$out" BOOTSTRAP_TEST_SHARD=1/2 BOOTSTRAP_TEST_WEIGHTS="$v"
    rc=$?
    set -e
    [ "$rc" -eq 2 ] || { head -n 5 "$out" >&2; die "BOOTSTRAP_TEST_WEIGHTS='$v': exit $rc, want 2"; }
    grep -qF BOOTSTRAP_TEST_WEIGHTS "$out" || { cat "$out" >&2; die "'$v': the message does not name the setting"; }
    grep -qF -- "$why" "$out" || { cat "$out" >&2; die "'$v': the message does not say '$why'"; }
    ! grep -qE '^(ok|FAIL) ' "$out" || die "'$v': tests ran"
  done
}

test_durations_file_lists_every_test_with_a_time_for_each_os() {
  # The checked-in durations cover the harness's tests: a test missing
  # from it still runs (median weight), but a name the harness no longer
  # has is stale, and every OS leg has its column.
  local want="$WORK/want"
  harness_tests >"$want"
  [ -f "$DURATIONS" ] || die "no bootstrap/test-durations.txt"
  [ "$(sed -n 1p "$DURATIONS")" = 'test ubuntu-latest macos-latest windows-latest' ] || die "unexpected header: $(sed -n 1p "$DURATIONS")"
  ! awk 'NR > 1 && (NF != 4 || $2 !~ /^[0-9]+(\.[0-9]+)?$/ || $3 !~ /^[0-9]+(\.[0-9]+)?$/ || $4 !~ /^[0-9]+(\.[0-9]+)?$/)' "$DURATIONS" | grep . >&2 \
    || die "a line of the durations file is not a name and three numbers"
  awk 'NR > 1 { print $1 }' "$DURATIONS" | LC_ALL=C sort >"$WORK/listed"
  LC_ALL=C comm -13 "$want" "$WORK/listed" | grep . >&2 && die "the durations file lists tests the harness does not have"
  [ -z "$(awk 'NR > 1 { print $1 }' "$DURATIONS" | LC_ALL=C sort | uniq -d)" ] || die "a test is listed twice"
}

test_workflow_shards_split_by_the_durations_of_their_os() {
  # The matrix job hands each shard the durations file and the column of
  # its own OS.
  local job
  job="$(wf_job "$(matrix_job)")"
  grep -qxF '      BOOTSTRAP_TEST_WEIGHTS: bootstrap/test-durations.txt:${{ matrix.os }}' <<<"$job" \
    || die "the shards are not split by bootstrap/test-durations.txt for their OS"
}

test_durations_from_logs_reads_the_times_between_result_lines() {
  # bootstrap/durations-from-logs.sh <os>=<log>... prints the durations
  # file from Actions job logs: each test's time is its result line's
  # timestamp minus the result line before (the step start for the
  # first), the mean over the logs of one OS it appears in, in tenths.
  local d="$WORK/logs" tool="$HERE/durations-from-logs.sh"
  [ -f "$tool" ] || die "no bootstrap/durations-from-logs.sh"
  mkdir -p "$d"
  printf '%s\n' '2026-10-26T22:22:16.1000000Z ##[group]Runner Image' \
    '2026-10-26T22:22:18.0000000Z ##[group]Run bash bootstrap/test-bootstrap-project.sh' \
    '2026-10-26T22:22:20.5000000Z ok   test_a' '2026-10-26T22:22:21.0000000Z      | detail' \
    '2026-10-26T22:22:30.0000000Z FAIL test_b' '2026-10-26T22:22:31.0000000Z 2 passed' >"$d/u1.log"
  printf '%s\n' '2026-10-26T22:00:00.0000000Z ##[group]Run /bin/bash bootstrap/test-bootstrap-project.sh' \
    '2026-10-26T22:00:04.0000000Z ok   test_c' >"$d/m1.log"
  printf '%s\r\n' '2026-10-26T22:00:00.0000000Z ##[group]Run bash bootstrap/test-bootstrap-project.sh' \
    '2026-10-26T22:01:00.0000000Z ok   test_a' '2026-10-26T22:01:01.0000000Z ok   test_c' \
    '2026-10-26T22:01:01.0400000Z ok   test_d' >"$d/w1.log"
  # A second macOS log (another run) where test_c took 6 s: the mean, 5.
  printf '%s\n' '2026-10-27T01:00:00.0000000Z ##[group]Run /bin/bash bootstrap/test-bootstrap-project.sh' \
    '2026-10-27T01:00:06.0000000Z ok   test_c' >"$d/m2.log"
  bash "$tool" ubuntu-latest="$d/u1.log" macos-latest="$d/m1.log" windows-latest="$d/w1.log" macos-latest="$d/m2.log" >"$d/out" 2>"$d/err" \
    || { cat "$d/err" >&2; die "the tool failed"; }
  printf '%s\n' 'test ubuntu-latest macos-latest windows-latest' 'test_a 2.5 0 60.0' 'test_b 9.5 0 0' 'test_c 0 5.0 1.0' \
    'test_d 0 0 0.1' >"$d/want"
  diff "$d/want" "$d/out" >&2 || die "unexpected durations (want, then got)"
  # A log with no test step is refused: it would give every test 0.
  printf '%s\n' '2026-10-26T22:00:00.0000000Z ##[group]Run actions/checkout@v7' >"$d/empty.log"
  ! bash "$tool" ubuntu-latest="$d/empty.log" >/dev/null 2>&1 || die "a log with no test results was taken"
}

test_harness_fails_when_its_shard_selects_no_test() {
  # A valid setting can select nothing (shard i of n with i above the
  # number of tests). A run that ran no test fails, so it is never taken
  # for a green one; list mode just lists nothing.
  local out="$WORK/out" rc
  set +e
  run_harness "$out" BOOTSTRAP_TEST_SHARD=100000/100000
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { cat "$out" >&2; die "a shard that ran no test exited 0"; }
  [ "$rc" -ne 124 ] || die "timed out"
  grep -qF 'ran no test' "$out" || { cat "$out" >&2; die "the failure does not say no test ran"; }
  ! grep -qE '^(ok|FAIL) ' "$out" || die "tests ran"
  run_harness "$out" BOOTSTRAP_TEST_LIST=1 BOOTSTRAP_TEST_SHARD=100000/100000 || { cat "$out" >&2; die "list mode of an empty shard failed"; }
  [ ! -s "$out" ] || { cat "$out" >&2; die "list mode of an empty shard printed something"; }
}

# shard_fixture <dir> <n> <os>...: <dir>/all.txt lists 10 tests;
# <dir>/shards holds, for each os, the manifests of shards 1..n of n,
# interleaved, as the harness writes them.
shard_fixture() {
  local d="$1" n="$2" os i
  shift 2
  mkdir -p "$d/shards"
  printf 'test_%s\n' a b c d e f g h i j >"$d/all.txt"
  for os in "$@"; do
    i=1
    while [ "$i" -le "$n" ]; do
      awk -v i="$i" -v n="$n" '(NR - 1) % n == i - 1' "$d/all.txt" >"$d/shards/$os-$i-of-$n.txt"
      i=$((i + 1))
    done
  done
}

# check_shards <dir> <results> <os>...: runs check-shards.sh on the
# fixture; output in <dir>/out; returns its exit code.
check_shards() {
  local d="$1" r="$2"
  shift 2
  [ -f "$CHECK_SHARDS" ] || die "no bootstrap/check-shards.sh"
  # Capped at 20 s (timeout, on the ubuntu runner): a check that loops
  # over an absurd shard count fails here instead of hanging.
  if command -v timeout >/dev/null 2>&1; then
    RESULTS="$r" timeout 20 bash "$CHECK_SHARDS" "$d/shards" "$d/all.txt" "$@" >"$d/out" 2>&1
  else
    RESULTS="$r" bash "$CHECK_SHARDS" "$d/shards" "$d/all.txt" "$@" >"$d/out" 2>&1
  fi
}

# expect_shards_refused <dir> <results> <message> <os>...
expect_shards_refused() {
  local d="$1" r="$2" msg="$3"
  shift 3
  if check_shards "$d" "$r" "$@"; then cat "$d/out" >&2; die "passed, want refused with: $msg"; fi
  grep -qF -- "$msg" "$d/out" || { cat "$d/out" >&2; die "refused, but without: $msg"; }
  grep -qF '::error::' "$d/out" || { cat "$d/out" >&2; die "no ::error:: line"; }
}

test_check_shards_passes_when_every_need_succeeded_and_every_shard_ran_all_tests() {
  local d="$WORK/fx"
  shard_fixture "$d" 3 os-a os-b
  check_shards "$d" "success success" os-a os-b || { cat "$d/out" >&2; die "refused a complete, green run"; }
  # One shard per OS is a complete run too.
  d="$WORK/fx1"; shard_fixture "$d" 1 os-a
  check_shards "$d" "success" os-a || { cat "$d/out" >&2; die "refused one shard of one"; }
}

test_check_shards_fails_unless_every_need_succeeded() {
  local d="$WORK/fx" r
  shard_fixture "$d" 2 os-a
  for r in "" "failure" "success failure" "failure success" "skipped success" \
           "success skipped" "success cancelled" "cancelled" "success  success failure"; do
    if check_shards "$d" "$r" os-a; then die "passed on results: '$r'"; fi
    grep -qF '::error::' "$d/out" || { cat "$d/out" >&2; die "no ::error:: on results: '$r'"; }
  done
}

test_check_shards_fails_when_a_shard_is_missing() {
  local d="$WORK/fx"
  shard_fixture "$d" 4 os-a os-b
  rm "$d/shards/os-b-3-of-4.txt"
  expect_shards_refused "$d" "success success" "os-b: shard 3 of 4 did not report" os-a os-b
  # The last shard missing, too: nothing else says there were 4.
  d="$WORK/fx2"; shard_fixture "$d" 4 os-a
  rm "$d/shards/os-a-4-of-4.txt"
  expect_shards_refused "$d" "success" "os-a: shard 4 of 4 did not report" os-a
}

test_check_shards_fails_when_an_os_did_not_report() {
  local d="$WORK/fx"
  shard_fixture "$d" 2 os-a
  expect_shards_refused "$d" "success success" "os-b: no shard reported" os-a os-b
}

test_check_shards_fails_when_a_test_ran_twice_or_not_at_all() {
  local d="$WORK/fx"
  shard_fixture "$d" 2 os-a
  echo test_c >>"$d/shards/os-a-2-of-2.txt"
  expect_shards_refused "$d" "success" "os-a: ran more than once: test_c" os-a
  d="$WORK/fx2"; shard_fixture "$d" 2 os-a
  grep -vxF test_e "$d/shards/os-a-1-of-2.txt" >"$d/x" && mv "$d/x" "$d/shards/os-a-1-of-2.txt"
  expect_shards_refused "$d" "success" "os-a: did not run: test_e" os-a
  d="$WORK/fx3"; shard_fixture "$d" 2 os-a
  echo test_zzz >>"$d/shards/os-a-2-of-2.txt"
  expect_shards_refused "$d" "success" "os-a: not in the list of tests: test_zzz" os-a
}

test_check_shards_fails_when_shards_disagree_on_their_count() {
  local d="$WORK/fx"
  shard_fixture "$d" 2 os-a
  cp "$d/shards/os-a-2-of-2.txt" "$d/shards/os-a-3-of-3.txt"
  expect_shards_refused "$d" "success" "os-a: shards disagree on their count" os-a
}

test_check_shards_refuses_a_shard_count_above_a_matrix_at_once() {
  # A GitHub matrix has at most 256 jobs, so a manifest named with a
  # larger count is refused at once, not looped over (review of #178).
  local d="$WORK/fx" n
  for n in 257 9223372036854775807 99999999999999999999; do
    d="$WORK/fx.$n"; shard_fixture "$d" 1 os-a
    mv "$d/shards/os-a-1-of-1.txt" "$d/shards/os-a-1-of-$n.txt"
    expect_shards_refused "$d" "success" "os-a: shard count $n is above 256" os-a
  done
  # 256 itself is a count a matrix can have.
  d="$WORK/fx.256"; shard_fixture "$d" 1 os-a
  mv "$d/shards/os-a-1-of-1.txt" "$d/shards/os-a-1-of-256.txt"
  expect_shards_refused "$d" "success" "os-a: shard 2 of 256 did not report" os-a
}

test_check_shards_fails_on_a_file_it_does_not_expect() {
  local d="$WORK/fx"
  shard_fixture "$d" 2 os-a
  : >"$d/shards/os-c-1-of-1.txt"
  expect_shards_refused "$d" "success" "unexpected file: os-c-1-of-1.txt" os-a
  d="$WORK/fx2"; shard_fixture "$d" 2 os-a
  : >"$d/shards/notes.txt"
  expect_shards_refused "$d" "success" "unexpected file: notes.txt" os-a
}

test_check_shards_fails_on_an_empty_test_list_or_no_manifests() {
  local d="$WORK/fx"
  shard_fixture "$d" 1 os-a
  : >"$d/all.txt"
  expect_shards_refused "$d" "success" "the list of tests is empty" os-a
  d="$WORK/fx2"; shard_fixture "$d" 1 os-a
  rm -rf "$d/shards"
  expect_shards_refused "$d" "success" "no shard reported" os-a
  d="$WORK/fx3"; shard_fixture "$d" 1 os-a
  if RESULTS=success bash "$CHECK_SHARDS" "$d/shards" "$d/all.txt" >/dev/null 2>&1; then
    die "passed with no OS to check"
  fi
}

test_check_shards_reads_manifests_with_windows_line_ends() {
  local d="$WORK/fx"
  shard_fixture "$d" 2 os-a
  awk '{ printf "%s\r\n", $0 }' "$d/shards/os-a-1-of-2.txt" >"$d/x" && mv "$d/x" "$d/shards/os-a-1-of-2.txt"
  check_shards "$d" "success" os-a || { cat "$d/out" >&2; die "refused manifests with CRLF line ends"; }
}

# gate_fixture <dir>: a checkout for the aggregate step's script: a stub
# harness whose list mode lists 5 tests (it fails if run otherwise), the
# real check-shards.sh, and the manifests of 4 shards for each OS leg
# in shard-list/, where the step downloads them.
gate_fixture() {
  local d="$1" os i
  mkdir -p "$d/bootstrap" "$d/shard-list"
  cat >"$d/bootstrap/test-bootstrap-project.sh" <<'STUB'
if [ "${BOOTSTRAP_TEST_LIST:-}" = 1 ]; then printf 'test_%s\n' one two three four five; exit 0; fi
echo "stub harness: only list mode is emulated" >&2; exit 64
STUB
  [ -f "$CHECK_SHARDS" ] || die "no bootstrap/check-shards.sh"
  cp "$CHECK_SHARDS" "$d/bootstrap/check-shards.sh"
  for os in ubuntu-latest macos-latest windows-latest; do
    for i in 1 2 3 4; do
      printf 'test_%s\n' one two three four five | awk -v i="$i" '(NR - 1) % 4 == i - 1' >"$d/shard-list/$os-$i-of-4.txt"
    done
  done
}

test_workflow_bootstrapper_test_fails_unless_every_need_succeeded() {
  # Runs the aggregate job's script, in a checkout with every shard's
  # manifest, with the results GitHub would pass.
  local step script r d
  step="$(wf_step bootstrapper-test '^ *run: [|]')"
  [ -n "$step" ] || die "bootstrapper-test has no run: | step"
  [ "$(printf '%s\n' "$step" | grep -cE '^ *run:')" = 1 ] || die "expected one run step in bootstrapper-test"
  # Every need's result, by construction: a need added later is covered.
  grep -qxF "          RESULTS: \${{ join(needs.*.result, ' ') }}" <<<"$step" \
    || die "the step does not get every need's result in RESULTS"
  script="$WORK/gate.$RANDOM.sh"
  printf '%s\n' "$step" | wf_run_block >"$script"
  [ -s "$script" ] || die "empty run script"
  d="$WORK/gate"; gate_fixture "$d"
  for r in "success" "success success" "success success success"; do
    ( cd "$d" && RESULTS="$r" bash "$script" ) >"$WORK/out" 2>&1 || { cat "$WORK/out" >&2; die "failed on results: $r"; }
  done
  for r in "" "failure" "success failure" "failure success" "skipped success" \
           "success skipped" "success cancelled" "cancelled" "success  success failure"; do
    ! ( cd "$d" && RESULTS="$r" bash "$script" ) >/dev/null 2>&1 || die "passed on results: '$r'"
  done
}

test_workflow_bootstrapper_test_fails_when_a_shard_or_leg_did_not_report() {
  # All needs green, but one shard's manifest is missing (its upload did
  # not happen, or the matrix lost the shard), or a whole OS leg's: the
  # required check fails.
  local step script d f
  step="$(wf_step bootstrapper-test '^ *run: [|]')"
  script="$WORK/gate.$RANDOM.sh"
  printf '%s\n' "$step" | wf_run_block >"$script"
  for f in windows-latest-2-of-4.txt macos-latest-4-of-4.txt ubuntu-latest-1-of-4.txt; do
    d="$WORK/gate.$f"; gate_fixture "$d"
    rm "$d/shard-list/$f"
    if ( cd "$d" && RESULTS="success success" bash "$script" ) >"$WORK/out" 2>&1; then
      die "passed with $f missing"
    fi
    grep -qF 'did not report' "$WORK/out" || { cat "$WORK/out" >&2; die "failed with $f missing, but not for that reason"; }
  done
  d="$WORK/gate.leg"; gate_fixture "$d"
  rm "$d/shard-list/macos-latest-"*
  if ( cd "$d" && RESULTS="success success" bash "$script" ) >"$WORK/out" 2>&1; then
    die "passed with the macOS leg missing"
  fi
  grep -qF 'macos-latest: no shard reported' "$WORK/out" || { cat "$WORK/out" >&2; die "the missing macOS leg is not named"; }
}

test_workflow_every_os_leg_is_sharded_and_records_what_it_ran() {
  # The matrix job runs shards 1..n of every OS, each recording the
  # tests it ran into shard-list/ and uploading that; bootstrapper-test
  # downloads them all into shard-list/ before its step runs.
  local j job n list agg
  j="$(matrix_job)"; job="$(wf_job "$j")"
  list="$(printf '%s\n' "$job" | grep -E '^        shard: \[' | sed -E 's/^        shard: \[//; s/\][[:space:]]*$//' | tr -d ' ' || true)"
  [ -n "$list" ] || die "$j has no matrix shard list"
  n="$(printf '%s\n' "$list" | tr ',' '\n' | grep -c .)"
  [ "$list" = "$(seq -s, 1 "$n")" ] || die "the shard list is not 1..$n: $list"
  [ "$n" -ge 2 ] || die "the legs are not sharded (n = $n)"
  grep -qxF "      BOOTSTRAP_TEST_SHARD: \${{ matrix.shard }}/$n" <<<"$job" \
    || die "the shard setting is not matrix.shard/$n"
  grep -qxF "      BOOTSTRAP_TEST_MANIFEST: shard-list/\${{ matrix.os }}-\${{ matrix.shard }}-of-$n.txt" <<<"$job" \
    || die "the shards do not record what they ran as shard-list/<os>-<i>-of-$n.txt"
  grep -qE '^        uses: actions/upload-artifact@v[0-9]+$|^      - uses: actions/upload-artifact@v[0-9]+$' <<<"$job" \
    || die "the shards do not upload what they ran"
  grep -qxF '          name: bootstrap-tests-${{ matrix.os }}-${{ matrix.shard }}' <<<"$job" || die "unexpected artifact name"
  grep -qxF '          path: shard-list/' <<<"$job" || die "the upload is not shard-list/"
  grep -qxF '          if-no-files-found: error' <<<"$job" || die "an upload with no manifest does not fail"
  agg="$(wf_job bootstrapper-test)"
  grep -qE 'uses: actions/download-artifact@v[0-9]+$' <<<"$agg" || die "bootstrapper-test does not download the manifests"
  grep -qxF '          pattern: bootstrap-tests-*' <<<"$agg" || die "the download pattern is not bootstrap-tests-*"
  grep -qxF '          path: shard-list' <<<"$agg" || die "the manifests are not downloaded to shard-list"
  grep -qxF '          merge-multiple: true' <<<"$agg" || die "the manifests are not merged into one folder"
  # The gate runs even when the download fails (no artifact at all).
  wf_step bootstrapper-test '^ *run: [|]' | grep -xF '        if: always()' >/dev/null || die "the gate step does not run when the download fails"
}

test_workflow_bootstrapper_test_gates_the_build_and_publish_tests() {
  # bootstrap/test.sh stays on ubuntu only (spec): build.sh and
  # publish.sh run only in the ubuntu release job.
  local job
  assert_gated bootstrap/test.sh
  job="$(wf_jobs_running bootstrap/test.sh)"
  wf_job "$job" | grep -xE '    runs-on: ubuntu-latest' >/dev/null || die "$job does not run on ubuntu-latest only"
}

test_workflow_bootstrapper_test_gates_the_require_test_change_tests() {
  # The check's own tests run in a job the required bootstrapper-test
  # check needs, from the first PR that adds them.
  assert_gated tools/test-require-test-change.sh
}

test_workflow_bootstrapper_test_gates_the_check_status_tests() {
  # The STATUS.md format check runs in ci.yml's build job; its own tests
  # run in a job the required bootstrapper-test check needs.
  assert_gated tools/test-check-status.sh
}

test_workflow_bootstrapper_test_gates_the_bootstrap_project_tests() {
  [ -f "$HERE/test-bootstrap-project.sh" ] || die "no bootstrap/test-bootstrap-project.sh"
  assert_gated bootstrap/test-bootstrap-project.sh
}

test_workflow_bootstrapper_test_gates_the_e2e_check_tests() {
  # The tests of the end-to-end checker run in a job the required
  # bootstrapper-test check needs, on ubuntu (they need jq, which the
  # ubuntu runner image has).
  local job
  [ -f "$HERE/test-e2e-check.sh" ] || die "no bootstrap/test-e2e-check.sh"
  assert_gated bootstrap/test-e2e-check.sh
  job="$(wf_jobs_running bootstrap/test-e2e-check.sh)"
  wf_job "$job" | grep -xE '    runs-on: ubuntu-latest' >/dev/null || die "$job does not run on ubuntu-latest"
}

test_workflow_bootstrap_project_tests_run_on_ubuntu_macos_and_windows() {
  local j job oses
  j="$(matrix_job)"; job="$(wf_job "$j")"
  grep -qxF '    runs-on: ${{ matrix.os }}' <<<"$job" || die "$j does not run on matrix.os"
  oses="$(printf '%s\n' "$job" | grep -E '^        os: \[' | sed -E 's/^        os: \[//; s/\][[:space:]]*$//' \
    | tr ',' '\n' | sed -E 's/^ +//; s/ +$//' | LC_ALL=C sort | tr '\n' ' ')"
  [ "$oses" = "macos-latest ubuntu-latest windows-latest " ] || die "matrix os is '$oses'"
  # All three results show, even when one leg fails first.
  grep -qxF '      fail-fast: false' <<<"$job" || die "$j does not set fail-fast: false"
}

test_workflow_windows_leg_runs_the_tests_in_git_bash() {
  # shell: bash on a Windows runner is Git for Windows' bash.
  local j
  j="$(matrix_job)"
  wf_job "$j" | awk '/^    defaults:$/ { d = 1; next } d && /^      run:$/ { r = 1; next }
                     d && r && /^        shell: bash$/ { ok = 1 } /^    [A-Za-z]/ { d = 0; r = 0 }
                     END { exit !ok }' || die "$j does not default to shell: bash"
}

test_workflow_macos_leg_runs_the_tests_with_bin_bash_3_2() {
  # Apple's /bin/bash is 3.2. Anything the tests start with plain bash
  # (the script, build.sh) must be that bash too, not a newer one the
  # runner image may put first on PATH, and the step proves it is 3.2.
  local j mac other
  j="$(matrix_job)"
  mac="$(wf_step "$j" "^        if: runner[.]os == 'macOS'\$")"
  [ -n "$mac" ] || die "no step with if: runner.os == 'macOS' in $j"
  grep -qE '^ +/bin/bash bootstrap/test-bootstrap-project\.sh *$' <<<"$mac" \
    || die "the macOS step does not run the tests with /bin/bash"
  grep -qE 'ln -sf? /bin/bash ' <<<"$mac" || die "the macOS step does not link bash to /bin/bash"
  grep -qE 'PATH=' <<<"$mac" || die "the macOS step does not put that link first on PATH"
  grep -qF 'BASH_VERSINFO' <<<"$mac" && grep -qF '3.2' <<<"$mac" \
    || die "the macOS step does not check that bash is 3.2"
  other="$(wf_step "$j" "^        if: runner[.]os != 'macOS'\$")"
  grep -qE '^ +run: bash bootstrap/test-bootstrap-project\.sh *$' <<<"$other" \
    || die "no step runs the tests with bash on the other legs"
}

test_real_build_does_not_ship_the_bootstrap_project_tests() {
  # The harness and its stub gh are template-only: bootstrap/ is not in
  # the manifest, and no test file of the script ships next to it.
  local out="$WORK/real.$RANDOM"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -z "$(cd "$out" && find . -name 'test-bootstrap-project*')" ] || die "the script's tests shipped"
  ! grep -vE '^[[:space:]]*(#|$)' "$REPO/bootstrap/manifest.txt" | grep -E '^bootstrap(/|$)' >/dev/null \
    || die "bootstrap/ is listed in the manifest"
}

test_real_build_does_not_ship_the_e2e_checker() {
  # bootstrap/e2e-check.sh is template-only (spec: "A template-only
  # bootstrap/e2e-check.sh"): not in the manifest, and not in the output.
  local out="$WORK/real.$RANDOM"
  [ -f "$HERE/e2e-check.sh" ] || die "no bootstrap/e2e-check.sh"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -z "$(cd "$out" && find . -name '*e2e-check*')" ] || die "the end-to-end checker or its tests shipped"
  ! grep -vE '^[[:space:]]*(#|$)' "$REPO/bootstrap/manifest.txt" | grep -E '(^|/)(test-)?e2e-check\.sh$' >/dev/null \
    || die "the end-to-end checker is listed in the manifest"
}

test_real_build_ships_the_require_test_change_script() {
  # The shared check ships byte for byte, through the manifest. The
  # tools/ folder that holds its tests does not.
  local out="$WORK/real.$RANDOM" f=".github/scripts/require-test-change.sh"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -f "$out/$f" ] || die "$f not shipped"
  cmp -s "$REPO/$f" "$out/$f" || die "$f shipped altered"
  [ ! -e "$out/tools" ] || die "tools/ shipped"
}

# ---------- bootstrap-project.sh (shipped as a stub) ----------
# The source is bootstrap/stubs/bootstrap-project.sh; stubs mirror the
# output, so it ships at the bootstrapper root, where packs are under
# languages/.

PROJECT_SCRIPT="$HERE/stubs/bootstrap-project.sh"

test_build_preserves_the_executable_bit_of_a_stub() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  printf '#!/usr/bin/env bash\necho hi\n' >"$fx/bootstrap/stubs/run.sh"
  chmod 755 "$fx/bootstrap/stubs/run.sh"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  [ -x "$out/run.sh" ] || die "build dropped the executable bit of a stub"
}

test_real_build_ships_the_project_script_stamped() {
  local out="$WORK/real.$RANDOM" f
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  f="$out/bootstrap-project.sh"
  grep -qxF "SCRIPT_VERSION='v2.1.0'" "$f" || die "shipped script lacks the version stamp"
  grep -qxF "SCRIPT_COMMIT='$SHA'" "$f" || die "shipped script lacks the commit stamp"
  ! grep -qF '{{TEMPLATE_' "$f" || die "placeholder left in the shipped script"
  [ -x "$f" ] || die "shipped script is not executable after stamping"
  ! grep -q $'\r' "$f" || die "shipped script has CR line endings"
}

test_real_build_project_script_reports_its_stamp_with_version() {
  # --version prints the stamped version and commit, exits 0, and calls
  # no gh (BOOTSTRAP_GH is a stand-in that logs every call).
  local out="$WORK/real.$RANDOM" f got rc=0 gh="$WORK/gh.$RANDOM"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  f="$out/bootstrap-project.sh"
  printf '#!/usr/bin/env bash\necho "$*" >>"%s.log"\n' "$gh" >"$gh"
  chmod +x "$gh"
  got="$(BOOTSTRAP_GH="$gh" bash "$f" --version </dev/null)" || rc=$?
  [ "$rc" -eq 0 ] || die "--version: exit $rc, want 0"
  [ "$got" = "bootstrap-project.sh v2.1.0, built from factoincognito/ai-project-template-v2@$SHA" ] \
    || die "--version printed: $got"
  [ ! -e "$gh.log" ] || { cat "$gh.log" >&2; die "--version called gh"; }
}

test_project_script_holds_only_the_two_placeholder_assignments() {
  # The build fails on any {{TEMPLATE_ left in the output, and stamps
  # every one in this file. So the two assignments are the only place
  # the placeholders may appear: later code compares against
  # SCRIPT_VERSION, never against a literal placeholder.
  local f="$PROJECT_SCRIPT"
  [ -f "$f" ] || die "no $f"
  grep -qxF "SCRIPT_VERSION='{{TEMPLATE_VERSION}}'" "$f" || die "no SCRIPT_VERSION placeholder assignment"
  grep -qxF "SCRIPT_COMMIT='{{TEMPLATE_COMMIT}}'" "$f" || die "no SCRIPT_COMMIT placeholder assignment"
  [ "$(grep -oF '{{TEMPLATE_' "$f" | wc -l | tr -d ' ')" -eq 2 ] \
    || { grep -nF '{{TEMPLATE_' "$f" >&2; die "placeholder outside the two assignments"; }
}

test_unstamped_project_script_still_lays_out() {
  # In the template the script is never stamped (tools/layout-pack.sh
  # and packs.yml run it from bootstrap/stubs/), so the placeholder
  # values must not break it.
  local a="$WORK/unstamped.$RANDOM" b="$WORK/wrapper.$RANDOM"
  grep -qF '{{TEMPLATE_VERSION}}' "$PROJECT_SCRIPT" || die "the stub is not unstamped; this test checks nothing"
  PACKS_DIR="$REPO/languages" bash "$PROJECT_SCRIPT" layout-pack node "$a" >/dev/null \
    || die "unstamped script layout-pack failed"
  (unset PACKS_DIR; bash "$REPO/tools/layout-pack.sh" node "$b") >/dev/null || die "wrapper failed"
  diff -r "$a" "$b" >&2 || die "unstamped script and wrapper lay out different trees"
}

test_project_script_is_committed_executable_and_lf() {
  # .gitattributes cannot set the mode, so the index must hold 100755,
  # and the eol attribute must be lf.
  local mode eol
  git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "needs a git checkout"
  mode="$(git -C "$REPO" ls-files -s -- bootstrap/stubs/bootstrap-project.sh | cut -d' ' -f1)"
  [ "$mode" = 100755 ] || die "bootstrap/stubs/bootstrap-project.sh has mode '$mode' in the index, want 100755"
  eol="$(git -C "$REPO" check-attr eol -- bootstrap/stubs/bootstrap-project.sh | sed 's/.*: //')"
  [ "$eol" = lf ] || die "eol attribute is '$eol', want lf"
}

test_real_build_ships_the_project_script_at_the_root() {
  local out="$WORK/real.$RANDOM" f="bootstrap-project.sh"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -f "$out/$f" ] || die "$f not shipped at the root"
  [ -x "$out/$f" ] || die "$f shipped without the executable bit"
  ! grep -q $'\r' "$out/$f" || die "$f has CR line endings"
  head -n1 "$out/$f" | grep -xF '#!/usr/bin/env bash' >/dev/null || die "$f has no bash shebang"
}

test_shipped_project_script_lays_out_from_its_own_languages_dir() {
  # At the bootstrapper root the script finds the packs in languages/
  # with no PACKS_DIR, and lays out what the template's wrapper does.
  local out="$WORK/real.$RANDOM" p a b
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  for p in node web python react-native; do
    a="$WORK/shipped.$p.$RANDOM"; b="$WORK/wrapper.$p.$RANDOM"
    (unset PACKS_DIR; cd "$WORK" && bash "$out/bootstrap-project.sh" layout-pack "$p" "$a") >/dev/null \
      || die "shipped script layout-pack $p failed"
    (unset PACKS_DIR; bash "$REPO/tools/layout-pack.sh" "$p" "$b") >/dev/null || die "wrapper $p failed"
    diff -r "$a" "$b" >&2 || die "$p: shipped script and wrapper lay out different trees"
  done
}

test_shipped_project_script_ignores_the_users_cdpath() {
  # The script finds itself with cd. A CDPATH in the user's environment
  # must not change where it looks (a decoy folder of the same name) or
  # make cd print the folder into the captured path, when it is called
  # by a relative path.
  local out="$WORK/real.$RANDOM" parent name decoy a b
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  parent="$(dirname "$out")"; name="$(basename "$out")"
  decoy="$WORK/decoy.$RANDOM"; mkdir -p "$decoy/$name"
  b="$WORK/wrapper.$RANDOM"
  (unset PACKS_DIR; bash "$REPO/tools/layout-pack.sh" node "$b") >/dev/null || die "wrapper failed"
  # CDPATH holding the script's own parent: cd would print the folder.
  a="$WORK/cdp1.$RANDOM"
  (unset PACKS_DIR; cd "$parent" && CDPATH="$parent" bash "$name/bootstrap-project.sh" layout-pack node "$a") \
    >/dev/null || die "layout-pack failed with CDPATH set to the script's parent"
  diff -r "$a" "$b" >&2 || die "CDPATH (script's parent) changed the layout"
  # CDPATH holding a decoy folder with the same name: cd would go there.
  a="$WORK/cdp2.$RANDOM"
  (unset PACKS_DIR; cd "$parent" && CDPATH="$decoy" bash "$name/bootstrap-project.sh" layout-pack node "$a") \
    >/dev/null || die "layout-pack failed with CDPATH set to a decoy"
  diff -r "$a" "$b" >&2 || die "CDPATH (decoy) changed the layout"
}

test_project_script_avoids_listed_bash4_constructs() {
  # A partial static scan, not a proof of bash 3.2 compatibility (macOS
  # /bin/bash is 3.2). It refuses the bash 4+ constructs listed below in
  # every line that is not a full-line comment, plus `bash -n`. Anything
  # not listed passes; a real run on bash 3.2 comes with the OS matrix.
  # Each pattern comes with a sample it must match, so a broken pattern
  # fails the test instead of passing.
  local f="$PROJECT_SCRIPT" code="$WORK/code.$RANDOM" i
  local pats=() samples=()
  [ -f "$f" ] || die "no $f"
  bash -n "$f" || die "syntax error in $f"
  pats+=('(declare|local|typeset|readonly)[[:space:]]+-[a-zA-Z]*[Anlu]'); samples+=('local -A map')
  pats+=('(declare|typeset)[[:space:]]+-[a-zA-Z]*g'); samples+=('declare -g x=1')
  pats+=('\[\[?[[:space:]]+(!+[[:space:]]+)?-[vR][[:space:]]'); samples+=('[ -v x ] && :')
  pats+=('\{[A-Za-z_][A-Za-z0-9_]*\}[<>]'); samples+=('exec {fd}>/dev/null')
  pats+=('BASHPID|BASH_COMPAT|BASH_LOADABLES_PATH|READLINE_|COPROC|SRANDOM'); samples+=('echo "$BASHPID"')
  pats+=('%-?[0-9]*\([^)]*\)T'); samples+=("printf '%(%F)T' -1")
  pats+=('(declare|typeset|local)[[:space:]]+-[a-zA-Z]*I'); samples+=('local -I x')
  pats+=('shopt[[:space:]]+-s[[:space:]]+(checkjobs|direxpand|globasciiranges|inherit_errexit|localvar_inherit|assoc_expand_once)'); samples+=('shopt -s inherit_errexit')
  pats+=('\$\{[A-Za-z_][A-Za-z0-9_]*:[0-9]+:-[0-9]+\}'); samples+=('y="${x:2:-1}"')
  pats+=('read[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-[a-zA-Z]*N[[:space:]]'); samples+=('read -N 3 x')
  pats+=('\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?(,,?|\^\^?)'); samples+=('y="${x,,}"')
  pats+=('\$\{[A-Za-z_][A-Za-z0-9_]*@[QEPAaKkUuL]\}'); samples+=('y="${x@Q}"')
  pats+=('(^|[^A-Za-z0-9_])(mapfile|readarray|coproc)([^A-Za-z0-9_]|$)'); samples+=('mapfile -t lines')
  pats+=('&>>'); samples+=('cmd &>>log')
  pats+=('\|&'); samples+=('cmd |& tee log')
  pats+=(';;&|;&$|;&[[:space:]]'); samples+=('a) x ;;&')
  pats+=('shopt[[:space:]]+-s[[:space:]]+(globstar|lastpipe|autocd)'); samples+=('shopt -s globstar')
  pats+=('wait[[:space:]]+-n'); samples+=('wait -n')
  pats+=('read[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-[a-zA-Z]*i'); samples+=('read -e -i default x')
  pats+=('\$\{[A-Za-z_][A-Za-z0-9_]*\[-[0-9]+\]\}'); samples+=('y="${a[-1]}"')
  pats+=('EPOCHSECONDS|EPOCHREALTIME|BASH_ARGV0'); samples+=('t=$EPOCHSECONDS')
  pats+=('\{[0-9]+\.\.[0-9]+\.\.[0-9]+\}'); samples+=('for i in {1..9..2}')
  grep -nvE '^[[:space:]]*#' "$f" >"$code" || true
  [ "$(wc -l <"$code")" -ge 20 ] || die "found almost no code lines; the filter is broken"
  for i in "${!pats[@]}"; do
    grep -qE -- "${pats[$i]}" <<<"${samples[$i]}" \
      || die "pattern ${pats[$i]} misses its sample: ${samples[$i]}"
    ! grep -E -- "${pats[$i]}" "$code" >&2 || die "bash 4+ construct (${pats[$i]}) in $f"
  done
}

# A pipe that ends in grep -q fails at random under pipefail: grep -q
# exits at the first match, the command writing into the pipe can then
# die of SIGPIPE, and pipefail reports that as the result of the pipe
# although the text matched (seen once in four runs of this file on a
# loaded machine, 2026-10-26). Give grep -q a here-string or a file
# instead, or drop -q and send grep's output to /dev/null: then grep
# reads all of its input and the writer finishes.
test_no_grep_q_at_the_end_of_a_pipe() {
  local f g=grep code="$WORK/code.$RANDOM" big="$WORK/big.$RANDOM" s hits=""
  local pat='(^|[^|])\|[[:space:]]*grep[[:space:]]+(-[A-Za-z]+[[:space:]]+)*(-[A-Za-z]*q|--quiet|--silent)'
  # The pattern catches every form and leaves the safe ones alone.
  for s in "x | $g -q y" "x |$g -qxF y" "x | $g -F -vq y" "! x | $g --quiet y"; do
    grep -qE -- "$pat" <<<"$s" || die "the pattern misses: $s"
  done
  for s in "x || $g -q y" "$g -q y <<<\"\$x\"" "x | $g -xF y >/dev/null" "$g -q y file"; do
    ! grep -qE -- "$pat" <<<"$s" || die "the pattern flags the safe form: $s"
  done
  # The /dev/null form is safe only if grep then reads all of its input.
  awk 'BEGIN { print "match"; for (i = 0; i < 200000; i++) print "filler line" }' >"$big"
  cat "$big" | grep -xF match >/dev/null \
    || die "with its output to /dev/null, grep stopped reading at the first match: the /dev/null form is not safe"
  for f in bootstrap/test.sh bootstrap/test-bootstrap-project.sh bootstrap/test-e2e-check.sh \
           tools/test-layout-pack.sh bootstrap/check-shards.sh bootstrap/e2e-check.sh \
           tools/test-require-test-change.sh tools/check-status.sh tools/test-check-status.sh; do
    [ -f "$REPO/$f" ] || die "no $f"
    grep -q 'pipefail' "$REPO/$f" || die "$f no longer sets pipefail; update this test"
    grep -nvE '^[[:space:]]*#' "$REPO/$f" >"$code" || true
    if grep -E -- "$pat" "$code" | sed "s|^|$f:|" >&2; then hits="$hits $f"; fi
  done
  [ -z "$hits" ] || die "grep -q at the end of a pipe in:$hits (lines above)"
}

test_project_script_mentions_no_template_only_path() {
  # It ships to the bootstrapper and then to projects, where tools/,
  # bootstrap/ and the template-only workflows do not exist.
  local f="$PROJECT_SCRIPT"
  [ -f "$f" ] || die "no $f"
  ! grep -nE '(^|[^A-Za-z0-9_.-])(tools|bootstrap|stubs)/' "$f" >&2 || die "template-only folder named in $f"
  ! grep -nE 'packs\.yml|bootstrapper\.yml|manifest\.txt|test-layout-pack|layout-pack\.sh' "$f" >&2 \
    || die "template-only file named in $f"
}

test_project_script_passes_the_forbidden_string_checks() {
  local f="$PROJECT_SCRIPT"
  [ -f "$f" ] || die "no $f"
  ! grep -nE 'trig_|PBI-[0-9]|open question [0-9]' "$f" >&2 || die "forbidden pattern in $f"
  ! grep -nF '(PR #' "$f" >&2 || die "(PR # in $f"
  grep -qE 'https://github\.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG\.md' "$f" \
    || die "$f header does not link the spec by URL"
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
