#!/usr/bin/env bash
# Tests for tools/check-status.sh.
# Usage: bash tools/test-check-status.sh
# Template-only: tools/ is not in bootstrap/manifest.txt.
#
# Every case runs on a fixture copy. The repo's own STATUS.md is in
# bootstrap/not-read-by-tests.txt, so no test here reads it; the CI build
# job runs the check on it instead.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
CHECK="$HERE/check-status.sh"
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

# A well-formed file, written to a fresh path that is echoed.
good() {
  local f
  f="$(mktemp "$WORK/status.XXXXXX")"
  cat >"$f" <<'EOF'
<!--
How to keep this file.
-->

# Status

Last update: 2026-10-28

## Phase
Build.

## Current focus
The check.

## Next step
A session runs it.

## Blockers
None.
EOF
  echo "$f"
}

expect_pass() {
  local err="$WORK/err.$RANDOM"
  bash "$CHECK" "$@" 2>"$err" >/dev/null || { cat "$err" >&2; die "check failed: $*"; }
}

# expect_fail <expected-stderr-substring> <files...>
expect_fail() {
  local msg="$1"; shift
  local err="$WORK/err.$RANDOM" rc=0
  bash "$CHECK" "$@" 2>"$err" >/dev/null || rc=$?
  [ "$rc" -eq 1 ] || { cat "$err" >&2; die "exit $rc, want 1"; }
  grep -qF -- "$msg" "$err" || { cat "$err" >&2; die "stderr lacks: $msg"; }
}

# edit <file> <sed expression>: portable in-place edit (BSD and GNU sed).
edit() { sed "$2" "$1" >"$1.tmp" && mv "$1.tmp" "$1"; }

# ---------- happy path ----------

test_good_file_passes() {
  expect_pass "$(good)"
}

test_stub_placeholder_date_passes() {
  local d="$WORK/ph.$RANDOM/bootstrap/stubs"
  mkdir -p "$d"
  cp "$(good)" "$d/STATUS.md"
  edit "$d/STATUS.md" 's/^Last update: .*/Last update: YYYY-MM-DD/'
  expect_pass "$d/STATUS.md"
}

test_placeholder_date_outside_the_stub_fails() {
  # A filled file whose date was never set gives the overview no date.
  local f; f="$(good)"
  edit "$f" 's/^Last update: .*/Last update: YYYY-MM-DD/'
  expect_fail 'placeholder date "YYYY-MM-DD" outside the stub: set the date' "$f"
}

test_shipped_stub_passes() {
  expect_pass "$REPO/bootstrap/stubs/STATUS.md"
}

test_extra_heading_after_blockers_passes() {
  local f; f="$(good)"
  printf '\n## Notes\nMore.\n' >>"$f"
  expect_pass "$f"
}

test_defaults_are_the_root_file_and_the_stub() {
  local root="$WORK/root.$RANDOM"
  mkdir -p "$root/bootstrap/stubs"
  cp "$(good)" "$root/STATUS.md"
  cp "$(good)" "$root/bootstrap/stubs/STATUS.md"
  local err="$WORK/err.$RANDOM"
  STATUS_ROOT="$root" bash "$CHECK" 2>"$err" >/dev/null || { cat "$err" >&2; die "defaults failed"; }
  edit "$root/bootstrap/stubs/STATUS.md" 's/^Last update: .*/Last update: YYYY-MM-DD/'
  STATUS_ROOT="$root" bash "$CHECK" 2>"$err" >/dev/null || { cat "$err" >&2; die "the stub's placeholder failed by default"; }
  edit "$root/bootstrap/stubs/STATUS.md" '/^## Blockers$/d'
  local rc=0
  STATUS_ROOT="$root" bash "$CHECK" 2>"$err" >/dev/null || rc=$?
  [ "$rc" -eq 1 ] || die "a broken stub passed with the default files"
  grep -qF "bootstrap/stubs/STATUS.md" "$err" || die "stderr does not name the stub"
}

# ---------- error paths ----------

test_missing_heading_fails_and_names_it() {
  local f; f="$(good)"
  edit "$f" '/^## Next step$/d'
  expect_fail 'missing heading "## Next step"' "$f"
}

test_renamed_heading_fails() {
  local f; f="$(good)"
  edit "$f" 's/^## Next step$/## Next steps/'
  expect_fail 'missing heading "## Next step"' "$f"
}

test_heading_with_trailing_space_fails() {
  local f; f="$(good)"
  edit "$f" 's/^## Phase$/## Phase /'
  expect_fail 'missing heading "## Phase"' "$f"
}

test_duplicate_heading_fails() {
  local f; f="$(good)"
  printf '\n## Phase\nAgain.\n' >>"$f"
  expect_fail 'heading "## Phase" appears 2 times' "$f"
}

test_wrong_order_fails() {
  local f; f="$(good)"
  edit "$f" 's/^## Phase$/## TMP/; s/^## Blockers$/## Phase/; s/^## TMP$/## Blockers/'
  expect_fail 'headings out of order' "$f"
}

test_missing_title_fails() {
  local f; f="$(good)"
  edit "$f" '/^# Status$/d'
  expect_fail 'missing title "# Status"' "$f"
}

test_missing_last_update_fails() {
  local f; f="$(good)"
  edit "$f" '/^Last update:/d'
  expect_fail 'missing "Last update: YYYY-MM-DD" line' "$f"
}

test_last_update_not_a_date_fails() {
  local f; f="$(good)"
  edit "$f" 's/^Last update: .*/Last update: today/'
  expect_fail 'missing "Last update: YYYY-MM-DD" line' "$f"
}

test_missing_file_fails() {
  expect_fail 'cannot read' "$WORK/nope.md"
}

test_every_problem_is_reported_not_only_the_first() {
  local f g; f="$(good)"; g="$(good)"
  edit "$f" '/^## Phase$/d'
  edit "$g" '/^## Blockers$/d'
  local err="$WORK/err.$RANDOM"
  ! bash "$CHECK" "$f" "$g" 2>"$err" >/dev/null || die "check passed"
  grep -qF '"## Phase"' "$err" || die "first file's problem not reported"
  grep -qF '"## Blockers"' "$err" || die "second file's problem not reported"
}

test_crlf_file_passes() {
  local f; f="$(good)"
  awk '{ printf "%s\r\n", $0 }' "$f" >"$f.crlf"
  expect_pass "$f.crlf"
}

# ---------- wiring ----------

# The exact step line, so a commented-out or reworded step does not pass.
test_ci_build_runs_the_check() {
  grep -qxF '        run: bash tools/check-status.sh' "$REPO/.github/workflows/ci.yml" \
    || die "ci.yml does not run the check as a step"
}

test_scripts_test_runs_these_tests() {
  grep -qxF '        run: bash tools/test-check-status.sh' "$REPO/.github/workflows/bootstrapper.yml" \
    || die "bootstrapper.yml does not run these tests as a step"
}

# That the template's own ci.yml never ships is pinned in bootstrap/test.sh.
test_check_is_template_only() {
  local m="$REPO/bootstrap/manifest.txt"
  [ -f "$m" ] || die "no $m"
  ! grep -qE '^tools' "$m" || die "tools/ listed in the manifest"
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
