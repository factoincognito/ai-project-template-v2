#!/usr/bin/env bash
# Tests for .github/scripts/require-test-change.sh, the check that fails a
# pull request which changes code without changing a test.
# Usage: bash tools/test-require-test-change.sh
# Template-only: tools/ is not in bootstrap/manifest.txt.
# Each test builds a small git fixture (a bare "origin" plus a clone) and
# runs the script in the clone with a clean GitHub environment, so these
# tests give the same result on a laptop and inside GitHub Actions.
# Cases that need a pack's or the template's own `run:` line (not here)
# live in the pull requests that create those lines.
set -euo pipefail
# A failing fixture step inside $( ) must fail the test, not hide.
shopt -s inherit_errexit 2>/dev/null || true
# Same result on a laptop as in CI: no inherited git state or user config.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SCRIPT="$REPO/.github/scripts/require-test-change.sh"
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

# new_repo <name>: a bare origin and a clone, main holding README.md,
# pushed. Prints the clone's path.
new_repo() {
  local d="$WORK/$1"
  mkdir -p "$d"
  git init -q --bare -b main "$d/origin.git"
  git clone -q "$d/origin.git" "$d/w" 2>/dev/null
  git -C "$d/w" config user.name test
  git -C "$d/w" config user.email test@example.invalid
  git -C "$d/w" config commit.gpgsign false
  put "$d/w" README.md "hello"
  commit "$d/w" "start"
  git -C "$d/w" push -q -u origin main 2>/dev/null
  echo "$d/w"
}

# put <repo> <path> [content]: write and stage a file.
put() {
  local w="$1" p="$2" c="${3:-x}"
  mkdir -p "$(dirname "$w/$p")"
  printf '%s\n' "$c" >"$w/$p"
  git -C "$w" add -- "$p"
}

commit() { git -C "$1" commit -q -m "$2"; }

on_main() { git -C "$1" push -q origin main 2>/dev/null; }

branch() { git -C "$1" checkout -q -b "$2"; }

# run_check <repo> "<VAR=value ...>" <script args...>
# Sets CHECK_RC and CHECK_OUT (stdout and stderr). Every variable the
# script reads is cleared first, so a real GitHub Actions environment
# cannot leak into a test.
run_check() {
  local w="$1" envspec="$2"
  shift 2
  set +e
  CHECK_OUT="$(cd "$w" && env -u GITHUB_EVENT_NAME -u GITHUB_BASE_REF -u GITHUB_REF_NAME \
    -u GITHUB_REF -u TEST_FIRST_BASE -u GITHUB_STEP_SUMMARY $envspec \
    bash "$SCRIPT" "$@" 2>&1)"
  CHECK_RC=$?
  set -e
}

# The usual patterns, as a node project would use them.
NODE=(--code 'src/*' --test 'src/*.test.ts')
BASE="TEST_FIRST_BASE=origin/main"

expect_rc() { [ "$CHECK_RC" -eq "$1" ] || die "exit $CHECK_RC, expected $1; output: $CHECK_OUT"; }
expect_out() { grep -qF -- "$1" <<<"$CHECK_OUT" || die "output lacks: $1; output: $CHECK_OUT"; }
expect_line() { grep -qxF -- "$1" <<<"$CHECK_OUT" || die "no output line: $1; output: $CHECK_OUT"; }
expect_no_line() { ! grep -qxF -- "$1" <<<"$CHECK_OUT" || die "unexpected output line: $1"; }

# ---------- code and test changes ----------

test_script_exists() {
  [ -f "$SCRIPT" ] || die "no $SCRIPT"
}

test_code_without_test_fails_and_names_the_file() {
  local w; w="$(new_repo t1)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
  expect_line "code: src/a.ts"
  expect_out "::error::"
}

test_failure_message_gives_both_ways_out() {
  local w; w="$(new_repo t2)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
  expect_out "add a test"
  expect_out 'git commit --allow-empty -m "Test-exempt: <reason>" --trailer "Test-exempt: <reason>"'
}

test_code_with_test_passes() {
  local w; w="$(new_repo t3)"
  branch "$w" feat; put "$w" src/a.ts; put "$w" src/a.test.ts; commit "$w" "both"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 0
  expect_line "code: src/a.ts"
  expect_line "test: src/a.test.ts"
}

test_docs_only_passes() {
  local w; w="$(new_repo t4)"
  branch "$w" feat; put "$w" docs/notes.md "words"; commit "$w" "docs"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 0
  expect_out "no code changed"
  expect_line "other: docs/notes.md"
}

test_test_only_passes() {
  local w; w="$(new_repo t5)"
  branch "$w" feat; put "$w" src/a.test.ts; commit "$w" "test"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 0
}

test_no_changes_at_all_passes() {
  local w; w="$(new_repo t6)"
  branch "$w" feat
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 0
  expect_out "no code changed"
}

test_code_plus_deleted_test_fails() {
  # Deleting a test is not changing one.
  local w; w="$(new_repo t7)"
  put "$w" src/a.test.ts; commit "$w" "a test"; on_main "$w"
  branch "$w" feat
  git -C "$w" rm -q src/a.test.ts; put "$w" src/b.ts; commit "$w" "code, test deleted"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
  expect_line "code: src/b.ts"
  expect_no_line "test: src/a.test.ts"
}

test_deleting_code_only_passes() {
  local w; w="$(new_repo t8)"
  put "$w" src/a.ts; commit "$w" "code"; on_main "$w"
  branch "$w" feat
  git -C "$w" rm -q src/a.ts; commit "$w" "remove"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 0
  expect_out "no code changed"
}

test_rename_counts_as_a_change() {
  local w; w="$(new_repo t9)"
  put "$w" src/a.ts "same content"; commit "$w" "code"; on_main "$w"
  branch "$w" feat
  git -C "$w" mv src/a.ts src/b.ts; commit "$w" "rename"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
  expect_line "code: src/b.ts"
}

test_type_change_is_not_counted() {
  # --diff-filter=ACMR leaves out T (a file turned into a symlink).
  local w; w="$(new_repo t10)"
  put "$w" src/a.ts; commit "$w" "code"; on_main "$w"
  branch "$w" feat
  rm "$w/src/a.ts"; ln -s ../README.md "$w/src/a.ts"; git -C "$w" add src/a.ts; commit "$w" "symlink"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 0
}

# ---------- patterns ----------

test_test_pattern_beats_code_pattern() {
  local w; w="$(new_repo p1)"
  branch "$w" feat; put "$w" src/x.test.ts; commit "$w" "test"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 0
  expect_line "test: src/x.test.ts"
  expect_no_line "code: src/x.test.ts"
}

test_ignore_beats_code() {
  local w; w="$(new_repo p2)"
  branch "$w" feat; put "$w" src/gen/x.ts; commit "$w" "generated"
  run_check "$w" "$BASE" "${NODE[@]}" --ignore 'src/gen/*'
  expect_rc 0
  expect_line "ignored: src/gen/x.ts"
}

test_ignore_does_not_beat_test() {
  local w; w="$(new_repo p3)"
  branch "$w" feat; put "$w" src/gen/x.test.ts; commit "$w" "t"
  run_check "$w" "$BASE" "${NODE[@]}" --ignore 'src/gen/*'
  expect_rc 0
  expect_line "test: src/gen/x.test.ts"
}

test_star_matches_slash() {
  local w; w="$(new_repo p4)"
  branch "$w" feat; put "$w" src/a/b/c.ts; commit "$w" "deep"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
  expect_line "code: src/a/b/c.ts"
}

test_flags_are_repeatable() {
  local w; w="$(new_repo p5)"
  branch "$w" feat; put "$w" index.html "<p>"; commit "$w" "page"
  run_check "$w" "$BASE" --code 'src/*' --code 'index.html' --test 'src/*.test.ts' --test 'e2e/*'
  expect_rc 1
  expect_line "code: index.html"
  put "$w" e2e/smoke.e2e.ts; commit "$w" "e2e"
  run_check "$w" "$BASE" --code 'src/*' --code 'index.html' --test 'src/*.test.ts' --test 'e2e/*'
  expect_rc 0
}

test_path_with_a_space() {
  local w; w="$(new_repo p6)"
  branch "$w" feat; put "$w" "src/my file.ts"; commit "$w" "space"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
  expect_line "code: src/my file.ts"
}

test_non_ascii_path_is_seen() {
  # Without -z git quotes the name and it would match no pattern.
  local w; w="$(new_repo p7)"
  branch "$w" feat; put "$w" "src/é.ts"; commit "$w" "accent"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
  expect_line "code: src/é.ts"
}

test_several_patterns_after_one_flag() {
  # `--code A B --test C D`: every pattern after a flag belongs to it.
  local w; w="$(new_repo p8)"
  branch "$w" feat; put "$w" lib/a.ts; commit "$w" "code in the second pattern"
  run_check "$w" "$BASE" --code 'src/*' 'lib/*' --test 'src/*.test.ts' 'lib/*.test.ts'
  expect_rc 1
  expect_line "code: lib/a.ts"
  put "$w" lib/a.test.ts; commit "$w" "test in the second test pattern"
  run_check "$w" "$BASE" --code 'src/*' 'lib/*' --test 'src/*.test.ts' 'lib/*.test.ts'
  expect_rc 0
}

test_pattern_without_a_flag_is_an_error() {
  local w; w="$(new_repo p9)"
  run_check "$w" "$BASE" 'src/*' --code 'src/*' --test 'src/*.test.ts'
  expect_rc 2
}

test_empty_pattern_is_an_error() {
  # An empty pattern matches nothing, so a CI line built from an empty
  # variable would pass forever.
  local w; w="$(new_repo p10)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  run_check "$w" "$BASE" --code '' --test 'src/*.test.ts'
  expect_rc 2
  run_check "$w" "$BASE" --code 'src/*' --test ''
  expect_rc 2
  run_check "$w" "$BASE" "${NODE[@]}" --ignore ''
  expect_rc 2
}

test_run_from_a_subdirectory_sees_the_whole_repo() {
  # diff.relative=true would otherwise list only the files under the
  # current directory, and a change elsewhere would pass unseen.
  local w; w="$(new_repo p11)"
  git -C "$w" config diff.relative true
  branch "$w" feat; put "$w" src/a.ts; put "$w" docs/d.md; commit "$w" "code and docs"
  run_check "$w/docs" "$BASE" "${NODE[@]}"
  expect_rc 1
  expect_line "code: src/a.ts"
}

test_file_name_cannot_inject_a_workflow_command() {
  # A name with a newline would otherwise print a line that GitHub reads
  # as a workflow command.
  local w; w="$(new_repo p12)"
  branch "$w" feat
  put "$w" "$(printf 'src/a\n::warning::injected.ts')"; commit "$w" "nasty name"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
  ! grep -q '^::warning::' <<<"$CHECK_OUT" || die "a file name produced a workflow command: $CHECK_OUT"
}

test_escaping_covers_percent_and_carriage_return() {
  local w; w="$(new_repo p13)"
  branch "$w" feat
  put "$w" "src/100%.ts"; put "$w" "$(printf 'src/b\r::warning::x.ts')"; commit "$w" "odd names"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
  expect_line "code: src/100%25.ts"
  expect_line "code: src/b%0D::warning::x.ts"
  ! grep -q "$(printf '\r')" <<<"$CHECK_OUT" || die "a raw carriage return reached the log"
}

# ---------- Test-exempt trailer ----------

test_trailer_with_reason_passes_and_prints_it() {
  local w; w="$(new_repo x1)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  git -C "$w" commit -q --allow-empty -m "exempt" --trailer "Test-exempt: proven by the pack chain run"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 0
  expect_out "::notice::"
  expect_out "proven by the pack chain run"
  expect_line "exempt: proven by the pack chain run"
}

test_trailer_without_reason_does_not_count() {
  local w; w="$(new_repo x2)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  git -C "$w" commit -q --allow-empty --cleanup=verbatim -m "$(printf 'exempt\n\nTest-exempt:')"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
}

test_trailer_already_on_main_does_not_count() {
  local w; w="$(new_repo x3)"
  git -C "$w" commit -q --allow-empty -m "old exemption" --trailer "Test-exempt: long ago"
  on_main "$w"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 1
}

test_trailer_is_not_needed_when_a_test_changes() {
  local w; w="$(new_repo x4)"
  branch "$w" feat; put "$w" src/a.ts; put "$w" src/a.test.ts; commit "$w" "both"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 0
  ! grep -qF "::notice::" <<<"$CHECK_OUT" || die "notice printed without an exemption"
}

# ---------- which commits are compared ----------

test_pull_request_uses_the_merge_commit_against_the_base_branch() {
  # main moves after the branch started. The merge commit must be
  # compared with origin/main, so only the branch's own files count.
  # If main's later files were attributed to the PR, main's new test
  # would hide that the branch changed code without one.
  local w; w="$(new_repo r1)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "branch code, no test"
  git -C "$w" checkout -q main
  put "$w" src/other.ts; put "$w" src/other.test.ts; commit "$w" "main moved on"; on_main "$w"
  git -C "$w" fetch -q origin
  git -C "$w" checkout -q --detach origin/main
  git -C "$w" merge -q --no-ff -m "Merge feat into main" feat
  run_check "$w" "GITHUB_EVENT_NAME=pull_request GITHUB_BASE_REF=main" "${NODE[@]}"
  expect_rc 1
  expect_line "code: src/a.ts"
  expect_no_line "code: src/other.ts"
  expect_no_line "test: src/other.test.ts"
}

test_pull_request_with_a_test_passes() {
  local w; w="$(new_repo r2)"
  branch "$w" feat; put "$w" src/a.ts; put "$w" src/a.test.ts; commit "$w" "both"
  git -C "$w" checkout -q --detach origin/main
  git -C "$w" merge -q --no-ff -m "Merge feat into main" feat
  run_check "$w" "GITHUB_EVENT_NAME=pull_request GITHUB_BASE_REF=main" "${NODE[@]}"
  expect_rc 0
}

test_pull_request_compares_with_its_own_base_branch() {
  # The base is whatever the pull request targets, not always main.
  local w; w="$(new_repo r7)"
  git -C "$w" push -q origin main:release 2>/dev/null
  # main moves on, so origin/main and origin/release really differ: a
  # check that used the wrong base would see main's later test file.
  put "$w" src/later.test.ts; commit "$w" "main moved after release was cut"; on_main "$w"
  git -C "$w" checkout -q -b feat origin/release
  put "$w" src/a.ts; commit "$w" "code"
  git -C "$w" fetch -q origin
  git -C "$w" checkout -q --detach origin/release
  git -C "$w" merge -q --no-ff -m "Merge feat into release" feat
  run_check "$w" "GITHUB_EVENT_NAME=pull_request GITHUB_BASE_REF=release" "${NODE[@]}"
  expect_rc 1
  run_check "$w" "GITHUB_EVENT_NAME=pull_request GITHUB_BASE_REF=nope" "${NODE[@]}"
  expect_rc 2
}

test_branch_push_is_compared_with_origin_main() {
  # A branch push and its pull request must give the same verdict.
  local w; w="$(new_repo r3)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  run_check "$w" "GITHUB_EVENT_NAME=push GITHUB_REF_NAME=feat" "${NODE[@]}"
  expect_rc 1
  expect_line "code: src/a.ts"
  put "$w" src/a.test.ts; commit "$w" "test"
  run_check "$w" "GITHUB_EVENT_NAME=push GITHUB_REF_NAME=feat" "${NODE[@]}"
  expect_rc 0
}

test_branch_push_ignores_what_main_changed_after_the_branch_started() {
  # The comparison is from the merge base (three dots). With two dots a
  # change that landed on main afterwards would show up as this branch's.
  local w; w="$(new_repo r6)"
  put "$w" src/m.ts "v1"; commit "$w" "existing code"; on_main "$w"
  branch "$w" feat; put "$w" docs/n.md "docs only"; commit "$w" "docs"
  git -C "$w" checkout -q main
  put "$w" src/m.ts "v2"; commit "$w" "main changes code"; on_main "$w"
  git -C "$w" checkout -q feat
  git -C "$w" fetch -q origin
  run_check "$w" "GITHUB_EVENT_NAME=push GITHUB_REF_NAME=feat" "${NODE[@]}"
  expect_rc 0
  expect_no_line "code: src/m.ts"
}

test_push_to_main_passes_with_a_notice() {
  local w; w="$(new_repo r4)"
  put "$w" src/a.ts; commit "$w" "code straight on main"
  run_check "$w" "GITHUB_EVENT_NAME=push GITHUB_REF_NAME=main" "${NODE[@]}"
  expect_rc 0
  expect_out "::notice::"
}

test_test_first_base_overrides_the_event() {
  local w; w="$(new_repo r5)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  run_check "$w" "GITHUB_EVENT_NAME=push GITHUB_REF_NAME=main TEST_FIRST_BASE=origin/main" "${NODE[@]}"
  expect_rc 1
}

# ---------- errors are exit 2, never a pass ----------

test_shallow_clone_is_an_error() {
  local d="$WORK/s1" w
  mkdir -p "$d"
  git init -q --bare -b main "$d/origin.git"
  git clone -q "$d/origin.git" "$d/seed" 2>/dev/null
  git -C "$d/seed" config user.name test; git -C "$d/seed" config user.email t@example.invalid
  put "$d/seed" README.md one; commit "$d/seed" one
  put "$d/seed" README.md two; commit "$d/seed" two
  git -C "$d/seed" push -q -u origin main 2>/dev/null
  git clone -q --depth 1 "file://$d/origin.git" "$d/w" 2>/dev/null
  w="$d/w"
  git -C "$w" config user.name test; git -C "$w" config user.email t@example.invalid
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 2
  expect_out "fetch-depth: 0"
}

test_missing_base_ref_is_an_error() {
  local w; w="$(new_repo e1)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  run_check "$w" "TEST_FIRST_BASE=origin/nope" "${NODE[@]}"
  expect_rc 2
  expect_out "fetch-depth: 0"
}

test_no_merge_base_is_an_error() {
  local w; w="$(new_repo e2)"
  git -C "$w" checkout -q --orphan other
  git -C "$w" rm -rqf .
  put "$w" src/a.ts; commit "$w" "unrelated history"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 2
}

test_event_without_a_base_needs_test_first_base() {
  local w; w="$(new_repo e3)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  run_check "$w" "GITHUB_EVENT_NAME=workflow_dispatch" "${NODE[@]}"
  expect_rc 2
  expect_out "TEST_FIRST_BASE"
}

test_local_run_without_github_variables_needs_test_first_base() {
  local w; w="$(new_repo e4)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  run_check "$w" "" "${NODE[@]}"
  expect_rc 2
  expect_out "TEST_FIRST_BASE"
}

test_missing_code_flag_is_an_error() {
  local w; w="$(new_repo e5)"
  run_check "$w" "$BASE" --test 'src/*.test.ts'
  expect_rc 2
  expect_out "--code"
}

test_missing_test_flag_is_an_error() {
  local w; w="$(new_repo e6)"
  run_check "$w" "$BASE" --code 'src/*'
  expect_rc 2
  expect_out "--test"
}

test_unknown_flag_is_an_error() {
  local w; w="$(new_repo e7)"
  run_check "$w" "$BASE" "${NODE[@]}" --bogus
  expect_rc 2
}

test_outside_a_git_repo_is_an_error() {
  mkdir -p "$WORK/nogit"
  set +e
  CHECK_OUT="$(cd "$WORK/nogit" && env -u GITHUB_EVENT_NAME -u GITHUB_BASE_REF -u GITHUB_STEP_SUMMARY \
    TEST_FIRST_BASE=origin/main bash "$SCRIPT" "${NODE[@]}" 2>&1)"
  CHECK_RC=$?
  set -e
  expect_rc 2
}

# ---------- job summary ----------

test_summary_file_is_written_when_set() {
  local w sum; w="$(new_repo m1)"; sum="$WORK/summary.md"
  branch "$w" feat; put "$w" src/a.ts; put "$w" src/a.test.ts; put "$w" docs/n.md; commit "$w" "mixed"
  run_check "$w" "$BASE GITHUB_STEP_SUMMARY=$sum" "${NODE[@]}"
  expect_rc 0
  [ -s "$sum" ] || die "summary file empty"
  grep -qF "src/a.ts" "$sum" || die "summary lacks the code file"
  grep -qF "src/a.test.ts" "$sum" || die "summary lacks the test file"
  grep -qF "docs/n.md" "$sum" || die "summary lacks the other file"
}

test_summary_shows_the_exemption_reason() {
  local w sum; w="$(new_repo m2)"; sum="$WORK/summary2.md"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  git -C "$w" commit -q --allow-empty -m "exempt" --trailer "Test-exempt: nothing a test could check"
  run_check "$w" "$BASE GITHUB_STEP_SUMMARY=$sum" "${NODE[@]}"
  expect_rc 0
  grep -qF "nothing a test could check" "$sum" || die "summary lacks the reason"
}

test_summary_names_the_base_it_compared_with() {
  local w sum; w="$(new_repo m3)"; sum="$WORK/summary3.md"
  branch "$w" feat; put "$w" src/a.test.ts; commit "$w" "t"
  run_check "$w" "$BASE GITHUB_STEP_SUMMARY=$sum" "${NODE[@]}"
  expect_rc 0
  grep -qF "Compared with" "$sum" || die "summary lacks the base line"
  grep -qF "origin/main" "$sum" || die "summary lacks the base name"
}

test_summary_is_written_for_a_push_to_main() {
  local w sum; w="$(new_repo m4)"; sum="$WORK/summary4.md"
  run_check "$w" "GITHUB_EVENT_NAME=push GITHUB_REF_NAME=main GITHUB_STEP_SUMMARY=$sum" "${NODE[@]}"
  expect_rc 0
  grep -qF "not checked" "$sum" || die "summary lacks the push-to-main line"
}

test_several_exemptions_are_all_shown() {
  local w; w="$(new_repo m5)"
  branch "$w" feat; put "$w" src/a.ts; commit "$w" "code"
  git -C "$w" commit -q --allow-empty -m "one" --trailer "Test-exempt: first reason"
  git -C "$w" commit -q --allow-empty -m "two" --trailer "Test-exempt: second reason"
  run_check "$w" "$BASE" "${NODE[@]}"
  expect_rc 0
  expect_line "exempt: first reason"
  expect_line "exempt: second reason"
  expect_out "::notice::"
  # git log lists the newest commit first; reasons are joined with "; ".
  grep -qF "reason: second reason; first reason" <<<"$CHECK_OUT" || die "notice lacks both reasons, joined: $CHECK_OUT"
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
