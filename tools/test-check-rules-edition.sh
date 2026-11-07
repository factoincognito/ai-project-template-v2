#!/usr/bin/env bash
# Tests for .github/scripts/check-rules-edition.sh.
# Usage: bash tools/test-check-rules-edition.sh
# Template-only: tools/ is not in bootstrap/manifest.txt.
#
# Every case runs on a fixture: an edition folder written here, in the
# format the edition builder writes (line 1 the edition id, then one
# "<sha256>  <path>" line per file, sorted by path, paths relative to the
# folder). The template-mode cases that compare with a base run in a
# throwaway git repository.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
CHECK="$REPO/.github/scripts/check-rules-edition.sh"
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
  (
    set -euo pipefail
    "$name"
  ) >"$log" 2>&1
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

die() {
  echo "assertion failed: $*" >&2
  exit 1
}

sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# write_edition <dir>: writes <dir>/EDITION for the files under <dir>, as
# the builder does.
write_edition() {
  local d="$1" f
  {
    echo "2026-11-05-0123abc"
    (cd "$d" && find . -type f ! -path ./EDITION | sed 's|^\./||' | LC_ALL=C sort) | while IFS= read -r f; do
      printf '%s  %s\n' "$(sha "$d/$f")" "$f"
    done
  } >"$d.EDITION.tmp"
  mv "$d.EDITION.tmp" "$d/EDITION"
}

# good <dir>: a well-formed edition at <dir>. P-10 sorts before P-2.
good() {
  local d="$1"
  mkdir -p "$d/processes" "$d/policies"
  printf '# Rules\n\n§ 1 (C) Scope\n(1) These rules.\n' >"$d/RULES.md"
  printf '# P-1\n' >"$d/processes/P-1-session-startup.md"
  printf '# P-10\n' >"$d/processes/P-10-unattended-and-scheduled-work.md"
  printf '# P-2\n' >"$d/processes/P-2-change-flow.md"
  printf '# Policy\n' >"$d/policies/third-party-ip.md"
  write_edition "$d"
}

fresh() {
  local d
  d="$(mktemp -d "$WORK/ed.XXXXXX")"
  echo "$d/rules"
}

# run [args...]: runs the check; sets RC and OUT (stdout and stderr).
run() {
  local out="$WORK/out.$RANDOM"
  RC=0
  bash "$CHECK" "$@" >"$out" 2>&1 || RC=$?
  OUT="$(cat "$out")"
}

expect() {
  local want="$1" msg="${2:-}"
  [ "$RC" -eq "$want" ] || {
    printf '%s\n' "$OUT" >&2
    die "exit $RC, want $want"
  }
  if [ -n "$msg" ]; then
    grep -qF -- "$msg" <<<"$OUT" || {
      printf '%s\n' "$OUT" >&2
      die "output lacks: $msg"
    }
  fi
}

# edit <file> <sed expression>: portable in-place edit (BSD and GNU sed).
edit() { sed "$2" "$1" >"$1.tmp" && mv "$1.tmp" "$1"; }

# ---------- a good edition ----------

test_good_edition_passes() {
  local d
  d="$(fresh)"
  good "$d"
  run "$d"
  expect 0 "2026-11-05-0123abc"
}

test_the_builder_format_passes() {
  # Written out by hand, byte for byte as the builder writes it: the
  # SHA-256 of "a" plus a newline, two spaces, the path.
  local d
  d="$(fresh)"
  mkdir -p "$d"
  printf 'a\n' >"$d/RULES.md"
  printf '2026-11-05-0123abc\n87428fc522803d31065e7bce3cf03fe475096631e5e07bbd7a0fde60c4cf25c7  RULES.md\n' >"$d/EDITION"
  run "$d"
  expect 0
}

test_a_relative_folder_passes() {
  local d
  d="$(fresh)"
  good "$d"
  (cd "$(dirname "$d")" && bash "$CHECK" rules) >/dev/null 2>&1 || die "a relative folder failed"
}

# ---------- a changed, missing or extra file ----------

test_a_changed_byte_fails() {
  local d
  d="$(fresh)"
  good "$d"
  edit "$d/processes/P-2-change-flow.md" 's/P-2/P-3/'
  run "$d"
  expect 1 "changed: processes/P-2-change-flow.md"
}

test_an_appended_newline_fails() {
  local d
  d="$(fresh)"
  good "$d"
  printf '\n' >>"$d/RULES.md"
  run "$d"
  expect 1 "changed: RULES.md"
}

test_a_missing_file_fails() {
  local d
  d="$(fresh)"
  good "$d"
  rm "$d/policies/third-party-ip.md"
  run "$d"
  expect 1 "missing: policies/third-party-ip.md"
}

test_an_extra_file_fails() {
  local d
  d="$(fresh)"
  good "$d"
  printf 'x\n' >"$d/processes/P-6-audit.md"
  run "$d"
  expect 1 "not in EDITION: processes/P-6-audit.md"
}

test_an_extra_file_in_a_new_folder_fails() {
  local d
  d="$(fresh)"
  good "$d"
  mkdir -p "$d/notes"
  printf 'x\n' >"$d/notes/a.md"
  run "$d"
  expect 1 "not in EDITION: notes/a.md"
}

test_an_extra_symlink_fails() {
  local d
  d="$(fresh)"
  good "$d"
  ln -s RULES.md "$d/LINK.md" 2>/dev/null || return 0 # no symlinks here: nothing to test
  [ -L "$d/LINK.md" ] || return 0
  run "$d"
  expect 1 "not in EDITION: LINK.md"
}

test_every_problem_is_named() {
  local d
  d="$(fresh)"
  good "$d"
  printf 'x\n' >>"$d/RULES.md"
  rm "$d/processes/P-1-session-startup.md"
  printf 'x\n' >"$d/extra.md"
  run "$d"
  expect 1 "changed: RULES.md"
  expect 1 "missing: processes/P-1-session-startup.md"
  expect 1 "not in EDITION: extra.md"
}

# ---------- a malformed EDITION ----------

# malformed <sed expression> <expected message>: a good edition whose
# EDITION is edited so.
malformed() {
  local d
  d="$(fresh)"
  good "$d"
  edit "$d/EDITION" "$1"
  run "$d"
  expect 1 "$2"
}

test_an_empty_edition_file_fails() {
  local d
  d="$(fresh)"
  good "$d"
  : >"$d/EDITION"
  run "$d"
  expect 1 "EDITION is malformed"
}

test_a_bad_edition_id_fails() { malformed '1s/.*/edition-1/' "line 1: not an edition id"; }
test_an_edition_id_with_a_long_sha_fails() { malformed '1s/.*/2026-11-05-0123abc1/' "line 1: not an edition id"; }
test_an_id_only_edition_fails() { malformed '2,$d' "lists no file"; }
test_one_space_after_the_hash_fails() { malformed '2s/  / /' "line 2: not"; }
test_an_upper_case_hash_fails() { malformed '2s/^\(.\)/A/' "line 2: not"; }
test_a_short_hash_fails() { malformed '2s/^.//' "line 2: not"; }
test_an_absolute_path_fails() { malformed '2s|  RULES.md|  /RULES.md|' "line 2: not a plain relative path"; }
test_a_dot_dot_path_fails() { malformed '2s|  RULES.md|  ../RULES.md|' "line 2: not a plain relative path"; }
test_a_dot_slash_path_fails() { malformed '2s|  RULES.md|  ./RULES.md|' "line 2: not a plain relative path"; }
test_a_blank_line_fails() { malformed '2s/.*//' "line 2: not"; }

test_edition_listing_itself_fails() {
  local d
  d="$(fresh)"
  good "$d"
  printf '%s  EDITION\n' "$(sha "$d/RULES.md")" >>"$d/EDITION"
  run "$d"
  expect 1 "lists EDITION itself"
}

test_unsorted_lines_fail() {
  # Sorted by path, byte order: P-10 before P-2.
  local d
  d="$(fresh)"
  good "$d"
  {
    sed -n 1p "$d/EDITION"
    sed 1d "$d/EDITION" | LC_ALL=C sort -r
  } >"$d/E" && mv "$d/E" "$d/EDITION"
  run "$d"
  expect 1 "not sorted by path"
}

test_a_duplicate_line_fails() {
  local d
  d="$(fresh)"
  good "$d"
  {
    sed -n 1,2p "$d/EDITION"
    sed 1d "$d/EDITION"
  } >"$d/E" && mv "$d/E" "$d/EDITION"
  run "$d"
  expect 1 "not sorted by path"
}

test_crlf_line_ends_fail() {
  local d
  d="$(fresh)"
  good "$d"
  awk '{ printf "%s\r\n", $0 }' "$d/EDITION" >"$d/E" && mv "$d/E" "$d/EDITION"
  run "$d"
  expect 1 "carriage return"
}

test_a_missing_last_newline_fails() {
  local d
  d="$(fresh)"
  good "$d"
  printf '%s' "$(cat "$d/EDITION")" >"$d/E" && mv "$d/E" "$d/EDITION"
  run "$d"
  expect 1 "does not end with a newline"
}

# ---------- project mode: the folder must be there ----------

test_project_mode_absent_folder_fails() {
  local d
  d="$(fresh)"
  run "$d"
  expect 1 "no folder"
}

test_project_mode_folder_without_edition_fails() {
  local d
  d="$(fresh)"
  good "$d"
  rm "$d/EDITION"
  run "$d"
  expect 1 "no EDITION"
}

test_project_mode_needs_no_git() {
  # A made project's CI runs it in the checkout; locally it may run
  # anywhere. It reads no git state in project mode.
  local d
  d="$(fresh)"
  good "$d"
  (cd "$WORK" && GIT_DIR=/nonexistent bash "$CHECK" "$d") >/dev/null 2>&1 || die "project mode needed git"
}

# ---------- template mode ----------

# tpl_repo: a git repo with a main commit holding a file outside the
# folder; the folder is bootstrap/stubs/rules. Echoes its path.
tpl_repo() {
  local r
  r="$(mktemp -d "$WORK/tpl.XXXXXX")"
  (
    cd "$r"
    git init -q -b main . 2>/dev/null || { git init -q . && git checkout -q -b main; }
    git config user.email t@example.invalid
    git config user.name t
    git config commit.gpgsign false
    mkdir -p bootstrap docs
    printf 'build\n' >bootstrap/build.sh
    printf 'doc\n' >docs/a.md
    git add -A && git commit -q -m base
  )
  echo "$r"
}

# commit_all <repo> <message>
commit_all() { (cd "$1" && git add -A && git commit -q -m "$2"); }

# trun <repo> [args...]: runs the check in template mode inside <repo>,
# compared with main, as on a pull request.
trun() {
  local r="$1" out="$WORK/out.$RANDOM"
  shift
  RC=0
  (cd "$r" && env -u GITHUB_EVENT_NAME -u GITHUB_BASE_REF -u GITHUB_REF_NAME EDITION_BASE=main \
    bash "$CHECK" --template bootstrap/stubs/rules "$@") >"$out" 2>&1 || RC=$?
  OUT="$(cat "$out")"
}

test_template_mode_absent_folder_passes() {
  local r
  r="$(tpl_repo)"
  (cd "$r" && git checkout -q -b feat && printf 'x\n' >>bootstrap/build.sh) && commit_all "$r" change
  trun "$r"
  expect 0 "nothing to check"
}

test_template_mode_good_edition_passes() {
  local r
  r="$(tpl_repo)"
  (cd "$r" && git checkout -q -b feat) && good "$r/bootstrap/stubs/rules" && commit_all "$r" edition
  trun "$r"
  expect 0 "2026-11-05-0123abc"
}

test_template_mode_checks_the_hashes() {
  local r
  r="$(tpl_repo)"
  (cd "$r" && git checkout -q -b feat) && good "$r/bootstrap/stubs/rules"
  printf 'x\n' >>"$r/bootstrap/stubs/rules/RULES.md"
  commit_all "$r" edition
  trun "$r"
  expect 1 "changed: RULES.md"
}

test_template_mode_folder_with_another_file_fails() {
  local r
  r="$(tpl_repo)"
  (cd "$r" && git checkout -q -b feat) && good "$r/bootstrap/stubs/rules"
  printf 'x\n' >>"$r/docs/a.md"
  commit_all "$r" mixed
  trun "$r"
  expect 1 "changes bootstrap/stubs/rules/ together with other files"
  expect 1 "docs/a.md"
}

test_template_mode_other_files_alone_pass() {
  local r
  r="$(tpl_repo)"
  good "$r/bootstrap/stubs/rules" && commit_all "$r" "edition on main"
  (cd "$r" && git checkout -q -b feat && printf 'x\n' >>docs/a.md) && commit_all "$r" other
  trun "$r"
  expect 0
}

test_template_mode_a_new_edition_alone_passes() {
  local r
  r="$(tpl_repo)"
  good "$r/bootstrap/stubs/rules" && commit_all "$r" "edition on main"
  (cd "$r" && git checkout -q -b feat && rm bootstrap/stubs/rules/processes/P-2-change-flow.md &&
    printf '# P-3\n' >bootstrap/stubs/rules/processes/P-3-review.md) && write_edition "$r/bootstrap/stubs/rules"
  commit_all "$r" "new edition"
  trun "$r"
  expect 0
}

test_template_mode_deleting_the_folder_with_another_file_fails() {
  local r
  r="$(tpl_repo)"
  good "$r/bootstrap/stubs/rules" && commit_all "$r" "edition on main"
  (cd "$r" && git checkout -q -b feat && rm -r bootstrap/stubs/rules && printf 'x\n' >>docs/a.md)
  commit_all "$r" "delete with other"
  trun "$r"
  expect 1 "together with other files"
}

test_template_mode_deleting_the_folder_alone_fails() {
  # Once an edition is taken the folder is always there (it is replaced
  # whole, never removed), so a change that only deletes it fails.
  local r
  r="$(tpl_repo)"
  good "$r/bootstrap/stubs/rules" && commit_all "$r" "edition on main"
  (cd "$r" && git checkout -q -b feat && git rm -rq bootstrap/stubs/rules)
  commit_all "$r" "delete the edition"
  trun "$r"
  expect 1 "deletes bootstrap/stubs/rules/"
}

test_template_mode_deleting_the_folder_on_a_pull_request_fails() {
  local r
  r="$(tpl_repo)"
  good "$r/bootstrap/stubs/rules" && commit_all "$r" "edition on main"
  (cd "$r" && git update-ref refs/remotes/origin/main main &&
    git checkout -q -b feat && git rm -rq bootstrap/stubs/rules)
  commit_all "$r" "delete the edition"
  RC=0
  OUT="$(cd "$r" && env -u EDITION_BASE GITHUB_EVENT_NAME=pull_request GITHUB_BASE_REF=main \
    bash "$CHECK" --template bootstrap/stubs/rules 2>&1)" || RC=$?
  expect 1 "deletes bootstrap/stubs/rules/"
}

test_template_mode_folder_added_after_the_base_and_absent_passes() {
  # Absent at HEAD and at the merge base (main moved on, the branch did
  # not take it): nothing was deleted by this change.
  local r
  r="$(tpl_repo)"
  (cd "$r" && git checkout -q -b feat && printf 'x\n' >>docs/a.md) && commit_all "$r" other
  (cd "$r" && git checkout -q main) && good "$r/bootstrap/stubs/rules" && commit_all "$r" "edition on main"
  (cd "$r" && git checkout -q feat)
  trun "$r"
  expect 0 "nothing to check"
}

test_template_mode_renaming_out_of_the_folder_fails() {
  # A rename counts as a delete in the folder and an add outside it.
  local r
  r="$(tpl_repo)"
  good "$r/bootstrap/stubs/rules" && commit_all "$r" "edition on main"
  (cd "$r" && git checkout -q -b feat && git mv bootstrap/stubs/rules/RULES.md docs/RULES.md)
  commit_all "$r" rename
  trun "$r"
  expect 1 "together with other files"
}

test_template_mode_a_sibling_folder_is_not_the_folder() {
  # bootstrap/stubs/rules-old/ is outside bootstrap/stubs/rules/.
  local r
  r="$(tpl_repo)"
  (cd "$r" && git checkout -q -b feat && mkdir -p bootstrap/stubs/rules-old && printf 'x\n' >bootstrap/stubs/rules-old/a.md)
  good "$r/bootstrap/stubs/rules"
  commit_all "$r" sibling
  trun "$r"
  expect 1 "bootstrap/stubs/rules-old/a.md"
}

test_template_mode_on_a_pull_request_compares_with_the_base_branch() {
  local r
  r="$(tpl_repo)"
  (cd "$r" && git checkout -q -b feat) && good "$r/bootstrap/stubs/rules"
  printf 'x\n' >>"$r/docs/a.md"
  commit_all "$r" mixed
  (cd "$r" && git update-ref refs/remotes/origin/main main)
  RC=0
  OUT="$(cd "$r" && env -u EDITION_BASE GITHUB_EVENT_NAME=pull_request GITHUB_BASE_REF=main \
    bash "$CHECK" --template bootstrap/stubs/rules 2>&1)" || RC=$?
  expect 1 "together with other files"
}

test_template_mode_push_to_main_skips_only_the_pull_request_check() {
  local r
  r="$(tpl_repo)"
  good "$r/bootstrap/stubs/rules"
  printf 'x\n' >>"$r/docs/a.md"
  commit_all "$r" mixed
  RC=0
  OUT="$(cd "$r" && env -u EDITION_BASE GITHUB_EVENT_NAME=push GITHUB_REF_NAME=main \
    bash "$CHECK" --template bootstrap/stubs/rules 2>&1)" || RC=$?
  expect 0 "push to main"
  printf 'x\n' >>"$r/bootstrap/stubs/rules/RULES.md"
  commit_all "$r" broken
  RC=0
  OUT="$(cd "$r" && env -u EDITION_BASE GITHUB_EVENT_NAME=push GITHUB_REF_NAME=main \
    bash "$CHECK" --template bootstrap/stubs/rules 2>&1)" || RC=$?
  expect 1 "changed: RULES.md"
}

test_template_mode_without_a_base_cannot_run() {
  local r
  r="$(tpl_repo)"
  RC=0
  OUT="$(cd "$r" && env -u EDITION_BASE -u GITHUB_EVENT_NAME bash "$CHECK" --template bootstrap/stubs/rules 2>&1)" || RC=$?
  expect 2 "EDITION_BASE"
}

test_template_mode_unknown_base_cannot_run() {
  local r
  r="$(tpl_repo)"
  RC=0
  OUT="$(cd "$r" && EDITION_BASE=nope bash "$CHECK" --template bootstrap/stubs/rules 2>&1)" || RC=$?
  expect 2 "base 'nope' not found"
}

test_template_mode_shallow_checkout_cannot_run() {
  local r s
  r="$(tpl_repo)"
  (cd "$r" && printf 'y\n' >>docs/a.md) && commit_all "$r" second
  s="$WORK/shallow.$RANDOM"
  git clone -q --depth 1 "file://$r" "$s" 2>/dev/null
  RC=0
  OUT="$(cd "$s" && EDITION_BASE=HEAD bash "$CHECK" --template bootstrap/stubs/rules 2>&1)" || RC=$?
  expect 2 "shallow"
}

test_template_mode_outside_git_cannot_run() {
  local d
  d="$(mktemp -d "$WORK/nogit.XXXXXX")"
  RC=0
  OUT="$(cd "$d" && GIT_CEILING_DIRECTORIES="$WORK" EDITION_BASE=main bash "$CHECK" --template rules 2>&1)" || RC=$?
  expect 2 "not inside a git repository"
}

test_template_mode_refuses_a_path_that_is_not_plain() {
  local r
  r="$(tpl_repo)"
  RC=0
  OUT="$(cd "$r" && EDITION_BASE=main bash "$CHECK" --template "$r/bootstrap/stubs/rules" 2>&1)" || RC=$?
  expect 2 "a plain path relative to the repository root"
  RC=0
  OUT="$(cd "$r" && EDITION_BASE=main bash "$CHECK" --template bootstrap/../bootstrap/stubs/rules 2>&1)" || RC=$?
  expect 2 "a plain path relative to the repository root"
}

test_template_mode_from_a_subfolder_uses_the_repo_root() {
  local r
  r="$(tpl_repo)"
  (cd "$r" && git checkout -q -b feat) && good "$r/bootstrap/stubs/rules"
  printf 'x\n' >>"$r/docs/a.md"
  commit_all "$r" mixed
  RC=0
  OUT="$(cd "$r/docs" && EDITION_BASE=main bash "$CHECK" --template bootstrap/stubs/rules 2>&1)" || RC=$?
  expect 1 "together with other files"
}

# ---------- usage ----------

test_no_arguments_is_a_usage_error() {
  run
  expect 2 "usage"
}
test_an_unknown_flag_is_a_usage_error() {
  run --nope x
  expect 2 "usage"
}
test_two_folders_is_a_usage_error() {
  run a b
  expect 2 "usage"
}

# ---------- the real tree and the wiring ----------

test_the_template_tree_passes() {
  # Until the first edition is taken, bootstrap/stubs/rules is absent and
  # this passes as "nothing to check"; from then on, the real edition. As
  # on a push to main, so that a shallow checkout (the test job's) works:
  # the CI build job checks the change itself, with full history.
  (cd "$REPO" && env -u EDITION_BASE GITHUB_EVENT_NAME=push GITHUB_REF_NAME=main \
    bash "$CHECK" --template bootstrap/stubs/rules) >/dev/null 2>&1 ||
    die "the template's own tree fails the check"
}

# The exact step line, so a commented-out or reworded step does not pass.
test_ci_build_runs_the_check_in_template_mode() {
  grep -qxF '        run: bash .github/scripts/check-rules-edition.sh --template bootstrap/stubs/rules' \
    "$REPO/.github/workflows/ci.yml" || die "ci.yml does not run the check as a step"
}

test_scripts_test_runs_these_tests() {
  # Under coverage since PBI-1.41 (c2): bootstrap/coverage.sh run
  # <folder> <name> <suite> runs it.
  grep -qxE '        run: bash (bootstrap/coverage[.]sh run "[$]RUNNER_TEMP/coverage-results" [a-z0-9-]+ )?tools/test-check-rules-edition[.]sh' \
    "$REPO/.github/workflows/bootstrapper.yml" ||
    die "bootstrapper.yml does not run these tests as a step"
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
