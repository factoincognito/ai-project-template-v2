#!/usr/bin/env bash
# Tests for bootstrap/stubs/bootstrap-project.sh: its message helpers,
# its test hooks (BOOTSTRAP_GH, BOOTSTRAP_RUN) and the plain-language
# checks on every user-facing string. The layout-pack subcommand has its
# own tests in tools/test-layout-pack.sh; packaging and stamping are
# tested in bootstrap/test.sh.
# Usage: bash bootstrap/test-bootstrap-project.sh
#
# Template-only: bootstrap/ is not in bootstrap/manifest.txt, so this
# file never ships. It runs on bash 3.2 (macOS /bin/bash) and Git for
# Windows bash as well as Linux: no associative arrays, no mapfile, no
# GNU-only flags, temp dirs from mktemp, nothing from /proc.
#
# Unit tests load the script with `source`: the script runs its main
# part only when it is executed, not when it is sourced, so a test can
# call one function at a time. Each test runs in its own subshell.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SCRIPT="$HERE/stubs/bootstrap-project.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/test-bootstrap-project.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0
FAILED_NAMES=()

# ---------- harness ----------

run_test() {
  local name="$1"
  local log="$WORK/$name.log" rc
  # Not inside an `if`: errexit is ignored in condition context.
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

# A fresh temp dir per call. Its name has a space on purpose: Windows and
# macOS user folders often do, so paths must be quoted everywhere.
tmpdir() { mktemp -d "$WORK/t m p.XXXXXX"; }

# load_script: source the script with no arguments, defining its
# functions without running its main part.
load_script() {
  set --
  # shellcheck source=/dev/null
  . "$SCRIPT"
}

# expect_same <name> <want-file> <got-file>
expect_same() {
  diff "$2" "$3" >&2 || die "$1 differs (want, then got, above)"
}

# ---------- stub gh ----------
# A stand-in for gh, selected with BOOTSTRAP_GH. Every call appends one
# line to $STUB_GH_LOG: GH_PROMPT_DISABLED=<value>, then each argument,
# tab-separated. What it emulates is the case statement at the end: each
# later piece of the script adds the gh calls it needs there (repo
# create, repo clone, api, pr ...). A call with no emulation fails loudly
# (exit 64), so a test never passes on a gh call nobody emulated.

make_stub_gh() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
: "${STUB_GH_LOG:?stub gh: STUB_GH_LOG is not set}"
{
  printf 'GH_PROMPT_DISABLED=%s' "${GH_PROMPT_DISABLED-<unset>}"
  for a in "$@"; do printf '\t%s' "$a"; done
  printf '\n'
} >>"$STUB_GH_LOG"
case "${1:-}" in
  --version) echo "gh version 0.0.0 (stub)" ;;
  *) echo "stub gh: no emulation for: $*" >&2; exit 64 ;;
esac
STUB
  chmod +x "$path"
}

# ---------- stub runner ----------
# A stand-in for the runner of offered commands (installs, logins),
# selected with BOOTSTRAP_RUN. It runs nothing: it appends the command
# string it was given to $STUB_RUN_LOG and exits with $STUB_RUN_RC
# (default 0).

make_stub_run() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
: "${STUB_RUN_LOG:?stub runner: STUB_RUN_LOG is not set}"
printf '%s\n' "$*" >>"$STUB_RUN_LOG"
exit "${STUB_RUN_RC:-0}"
STUB
  chmod +x "$path"
}

# ---------- user-facing strings ----------
# How the strings are collected: every message the script shows goes
# through its message helpers, and the helpers live in one marked block
# ("# ---------- messages ----------" up to "# ---------- end of messages
# ----------"). A second test makes sure nothing outside that block writes
# to the terminal by itself, so this list is complete:
#   - every line inside the block that is not a comment (the helpers'
#     own fixed texts, the usage text);
#   - every call of a message helper outside the block, with its
#     continuation lines (a line ending in \).
# Shell variables are removed: their content is a path or a value the
# user typed, not wording. say_command is not collected: its argument is
# an exact command for the user to copy, which may contain any word.

MSG_HELPERS='say|step_start|step_end|show_error|fail'

# user_strings <file>: prints "<line number>: <text>" for each.
user_strings() {
  awk -v helpers="$MSG_HELPERS" '
    /^[[:space:]]*# ---------- messages ----------/ { inblk = 1; next }
    /^[[:space:]]*# ---------- end of messages ----------/ { inblk = 0; next }
    cont { print NR ": " $0; cont = ($0 ~ /\\$/); next }
    /^[[:space:]]*#/ { next }
    inblk { print NR ": " $0; next }
    match($0, "(^|[^A-Za-z0-9_])(" helpers ")[[:space:]]") {
      print NR ": " substr($0, RSTART)
      cont = ($0 ~ /\\$/)
    }
  ' "$1" | sed -E 's/\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*|\$[0-9@*#?]//g'
}

# banned_hits: reads collected strings on stdin, prints each line that
# uses a banned word without its explanation. Banned (Ease-of-use
# requirements): clone, scope, status check, PR, repo, branch, API, with
# their plural and verb forms, and "repository" as the long form of repo.
# A word counts as explained when it is followed straight away by an
# explanation in brackets of at least three words, as in
# "repo (your project's home on GitHub)". Whether the explanation is a
# good one is for review.
banned_hits() {
  local f="$WORK/strings.$RANDOM"
  sed -E 's/[A-Za-z]+ \(([^) ]+ ){2,}[^) ]+\)//g' >"$f"
  grep -Ewi 'clon(e|es|ed|ing)|scopes?|status checks?|repos?|repositor(y|ies)|branch(es|ed)?' "$f" || true
  grep -Ew 'PRs?|APIs?' "$f" || true
}

# bypass_lines <file>: lines outside the messages block that write to the
# terminal without a helper (echo, printf, a heredoc, or >&2). A line
# that writes somewhere else on purpose ends with "# not-user-facing".
bypass_lines() {
  awk '
    /^[[:space:]]*# ---------- messages ----------/ { inblk = 1; next }
    /^[[:space:]]*# ---------- end of messages ----------/ { inblk = 0; next }
    inblk { next }
    /^[[:space:]]*#/ { next }
    /# not-user-facing[[:space:]]*$/ { next }
    { line = $0; gsub(/<<</, "", line) }
    line ~ /(^|[^A-Za-z0-9_])(echo|printf)([[:space:]]|$)/ || line ~ /<</ || line ~ />&2/ { print NR ": " $0 }
  ' "$1"
}

# ---------- loading the script ----------

test_sourcing_the_script_defines_functions_and_runs_nothing() {
  local out="$WORK/out.$RANDOM"
  ( load_script; type say >/dev/null && type fail >/dev/null ) >"$out" 2>&1 \
    || { cat "$out" >&2; die "sourcing the script failed or defined no helpers"; }
  [ ! -s "$out" ] || { cat "$out" >&2; die "sourcing the script printed something (its main part ran)"; }
}

test_script_piped_into_bash_still_runs_its_main_part() {
  # `curl ... | bash` is not supported (the prompts read stdin), but the
  # sourced-or-executed check must not make a piped run silently do
  # nothing: it runs, and with no arguments shows the usage (exit 2).
  local err="$WORK/err.$RANDOM" rc=0
  bash <"$SCRIPT" >/dev/null 2>"$err" || rc=$?
  [ "$rc" -eq 2 ] || { cat "$err" >&2; die "piped run exited $rc, want 2"; }
  grep -qF 'usage:' "$err" || { cat "$err" >&2; die "piped run did not show the usage"; }
}

# ---------- message helpers ----------

test_step_start_prints_one_start_line() {
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  printf '==> Checking your computer\n' >"$want"
  ( load_script; step_start "Checking your computer" ) >"$got" 2>"$got.err"
  expect_same "step start line" "$want" "$got"
  [ ! -s "$got.err" ] || die "step_start wrote to stderr"
}

test_step_end_prints_one_done_line() {
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  printf '    Done. git is installed\n' >"$want"
  ( load_script; step_end "git is installed" ) >"$got" 2>"$got.err"
  expect_same "step end line" "$want" "$got"
  [ ! -s "$got.err" ] || die "step_end wrote to stderr"
}

test_say_prints_the_line_to_stdout() {
  local got="$WORK/got.$RANDOM"
  ( load_script; say "Hello there" ) >"$got" 2>"$got.err"
  [ "$(cat "$got")" = "Hello there" ] || die "say printed: $(cat "$got")"
  [ ! -s "$got.err" ] || die "say wrote to stderr"
}

test_say_command_prints_the_command_indented() {
  local got="$WORK/got.$RANDOM"
  ( load_script; say_command "gh auth status" ) >"$got"
  [ "$(cat "$got")" = "    gh auth status" ] || die "say_command printed: $(cat "$got")"
}

test_error_shows_message_then_next_action_then_raw_text() {
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM" rc=0
  cat >"$want" <<'EOF'
What happened: GitHub did not accept the request.
What to do next: Check your internet connection, then run the script again.
Details for support (you can ignore these):
    HTTP 502: Bad Gateway
    (request id 1234)
EOF
  ( load_script; fail 1 "GitHub did not accept the request." \
      "Check your internet connection, then run the script again." \
      "HTTP 502: Bad Gateway
(request id 1234)" ) >"$got.out" 2>"$got" || rc=$?
  [ "$rc" -eq 1 ] || die "fail exited $rc, want 1"
  expect_same "error output" "$want" "$got"
  [ ! -s "$got.out" ] || die "the error went to stdout"
}

test_error_without_raw_text_has_no_support_block() {
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  printf '%s\n' "What happened: The folder is not empty." "What to do next: Choose an empty folder." >"$want"
  ( load_script; show_error "The folder is not empty." "Choose an empty folder." ) 2>"$got"
  expect_same "error output" "$want" "$got"
}

test_error_never_shows_raw_text_alone() {
  # A call with no message or no next action still says what happened
  # and what to do, above the raw text.
  local got="$WORK/got.$RANDOM"
  ( load_script; show_error "" "" "HTTP 500" ) 2>"$got"
  sed -n 1p "$got" | grep -qxF 'What happened: Something unexpected happened.' \
    || { cat "$got" >&2; die "no plain message above the raw text"; }
  sed -n 2p "$got" | grep -qE '^What to do next: .{10,}' \
    || { cat "$got" >&2; die "no next action above the raw text"; }
  sed -n 4p "$got" | grep -qxF '    HTTP 500' || { cat "$got" >&2; die "raw text not shown below for support"; }
}

test_error_raw_text_has_carriage_returns_removed() {
  # Windows tools end lines with \r\n; a stray \r would garble the output.
  local got="$WORK/got.$RANDOM"
  ( load_script; show_error "It failed." "Try again." "$(printf 'line one\r\nline two\r')" ) 2>"$got"
  ! grep -q "$(printf '\r')" "$got" || die "a carriage return reached the output"
  grep -qxF '    line two' "$got" || { cat "$got" >&2; die "raw text lost"; }
}

test_fail_exits_with_the_code_it_is_given() {
  local rc=0
  ( load_script; fail 3 "It stopped." "Run it again." ) 2>/dev/null || rc=$?
  [ "$rc" -eq 3 ] || die "fail exited $rc, want 3"
}

test_layout_pack_errors_use_the_error_format() {
  # The existing errors keep their wording and exit codes (pinned in
  # tools/test-layout-pack.sh) and now also say what to do next.
  local out err rc
  out="$(tmpdir)"; touch "$out/x"
  err="$WORK/err.$RANDOM"; rc=0
  PACKS_DIR="$REPO/languages" bash "$SCRIPT" layout-pack node "$out" 2>"$err" >/dev/null || rc=$?
  [ "$rc" -eq 1 ] || die "non-empty target exited $rc, want 1"
  grep -qE '^What happened: .*target dir is not empty' "$err" || { cat "$err" >&2; die "no What happened line"; }
  grep -qE '^What to do next: .{10,}' "$err" || { cat "$err" >&2; die "no next action"; }
  rc=0
  PACKS_DIR="$REPO/languages" bash "$SCRIPT" layout-pack ruby "$(tmpdir)/new" 2>"$err" >/dev/null || rc=$?
  [ "$rc" -eq 2 ] || die "unknown pack exited $rc, want 2"
  grep -qE '^What happened: .*unknown pack: ruby' "$err" || { cat "$err" >&2; die "no What happened line"; }
  grep -qE '^What to do next: .{10,}' "$err" || { cat "$err" >&2; die "no next action"; }
}

# ---------- hook: BOOTSTRAP_GH ----------

test_gh_hook_runs_the_command_named_in_bootstrap_gh() {
  local d log out
  d="$(tmpdir)"; log="$d/gh.log"
  make_stub_gh "$d/stub bin/gh"
  out="$( load_script; STUB_GH_LOG="$log" BOOTSTRAP_GH="$d/stub bin/gh" run_gh --version )" \
    || die "run_gh failed"
  [ "$out" = "gh version 0.0.0 (stub)" ] || die "run_gh output: $out"
  [ "$(cat "$log")" = "$(printf 'GH_PROMPT_DISABLED=1\t--version')" ] || { cat "$log" >&2; die "call not logged as expected"; }
}

test_gh_hook_passes_arguments_unchanged() {
  # Spaces, quotes and globs reach gh as the same separate arguments.
  local d log
  d="$(tmpdir)"; log="$d/gh.log"
  make_stub_gh "$d/gh"
  ( load_script; STUB_GH_LOG="$log" BOOTSTRAP_GH="$d/gh" run_gh api 'a b' '"q"' '*' '' ) 2>/dev/null || true
  [ "$(cat "$log")" = "$(printf 'GH_PROMPT_DISABLED=1\tapi\ta b\t"q"\t*\t')" ] || { cat "$log" >&2; die "arguments changed"; }
}

test_gh_hook_returns_gh_exit_code_and_stderr() {
  local d log rc=0 err
  d="$(tmpdir)"; log="$d/gh.log"; err="$d/err"
  make_stub_gh "$d/gh"
  ( load_script; STUB_GH_LOG="$log" BOOTSTRAP_GH="$d/gh" run_gh no-such-command ) 2>"$err" || rc=$?
  [ "$rc" -eq 64 ] || die "run_gh returned $rc, want the stub's 64"
  grep -qF 'stub gh: no emulation for: no-such-command' "$err" || { cat "$err" >&2; die "gh stderr lost"; }
}

test_gh_hook_defaults_to_gh_on_the_path() {
  # Unset or empty BOOTSTRAP_GH: the real command name, gh, found on PATH.
  local d log
  d="$(tmpdir)"; log="$d/gh.log"
  make_stub_gh "$d/bin/gh"
  ( load_script; unset BOOTSTRAP_GH; PATH="$d/bin:$PATH" STUB_GH_LOG="$log" run_gh --version ) >/dev/null \
    || die "run_gh with BOOTSTRAP_GH unset failed"
  ( load_script; PATH="$d/bin:$PATH" STUB_GH_LOG="$log" BOOTSTRAP_GH='' run_gh --version ) >/dev/null \
    || die "run_gh with BOOTSTRAP_GH empty failed"
  [ "$(grep -c -- '--version' "$log")" -eq 2 ] || { cat "$log" >&2; die "gh on PATH was not called twice"; }
}

test_gh_hook_set_means_gh_on_the_path_is_not_called() {
  # The gh on PATH only leaves a marker, so it is clear which one ran.
  local d
  d="$(tmpdir)"
  mkdir -p "$d/bin"
  printf '#!/usr/bin/env bash\ntouch "%s/path-gh-ran"\n' "$d" >"$d/bin/gh"
  chmod +x "$d/bin/gh"
  make_stub_gh "$d/hook/gh"
  ( load_script; PATH="$d/bin:$PATH" STUB_GH_LOG="$d/hook.log" BOOTSTRAP_GH="$d/hook/gh" run_gh --version ) >/dev/null
  [ -s "$d/hook.log" ] || die "the hook was not called"
  [ ! -e "$d/path-gh-ran" ] || die "gh on PATH was called although BOOTSTRAP_GH is set"
}

test_stub_gh_fails_loudly_without_a_log() {
  local d rc=0
  d="$(tmpdir)"
  make_stub_gh "$d/gh"
  ( unset STUB_GH_LOG; "$d/gh" --version ) >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 0 ] || die "stub gh ran without STUB_GH_LOG"
}

# ---------- hook: BOOTSTRAP_RUN ----------

test_run_hook_replaces_the_runner_so_nothing_runs() {
  local d marker
  d="$(tmpdir)"; marker="$d/it-ran"
  make_stub_run "$d/run"
  ( load_script; STUB_RUN_LOG="$d/run.log" BOOTSTRAP_RUN="$d/run" run_offered "touch '$marker'" ) \
    || die "run_offered failed"
  [ ! -e "$marker" ] || die "the offered command really ran"
  [ "$(cat "$d/run.log")" = "touch '$marker'" ] || { cat "$d/run.log" >&2; die "the runner did not get the exact command"; }
}

test_run_hook_returns_the_runner_exit_code() {
  local d rc=0
  d="$(tmpdir)"
  make_stub_run "$d/run"
  ( load_script; STUB_RUN_LOG="$d/run.log" STUB_RUN_RC=5 BOOTSTRAP_RUN="$d/run" run_offered "true" ) || rc=$?
  [ "$rc" -eq 5 ] || die "run_offered returned $rc, want 5"
}

test_run_hook_unset_runs_the_command() {
  local d marker rc=0
  d="$(tmpdir)"; marker="$d/it-ran"
  ( load_script; unset BOOTSTRAP_RUN; run_offered "touch '$marker'" ) || die "run_offered failed"
  [ -e "$marker" ] || die "with BOOTSTRAP_RUN unset the command did not run"
  ( load_script; BOOTSTRAP_RUN='' run_offered "exit 7" ) || rc=$?
  [ "$rc" -eq 7 ] || die "run_offered returned $rc, want the command's 7"
}

test_run_offered_runs_with_gh_prompts_enabled() {
  # The offered login and scope-refresh commands need gh's own prompts,
  # so they run with GH_PROMPT_DISABLED unset even when it is set around
  # them (run_gh sets it for every other gh call).
  local d got
  d="$(tmpdir)"
  got="$( load_script; export GH_PROMPT_DISABLED=1; unset BOOTSTRAP_RUN
          run_offered 'printf "%s" "${GH_PROMPT_DISABLED-unset}"' )"
  [ "$got" = unset ] || die "the offered command saw GH_PROMPT_DISABLED=$got"
  make_stub_run "$d/run"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "${GH_PROMPT_DISABLED-unset}" >>"$STUB_RUN_LOG"' >"$d/run"
  ( load_script; export GH_PROMPT_DISABLED=1 STUB_RUN_LOG="$d/run.log"; BOOTSTRAP_RUN="$d/run" run_offered "x" )
  [ "$(cat "$d/run.log")" = unset ] || die "the BOOTSTRAP_RUN runner saw GH_PROMPT_DISABLED=$(cat "$d/run.log")"
}

# ---------- plain language ----------

test_user_facing_strings_are_collected() {
  # Guards the collector: if it found nothing, the banned-word test
  # below would pass on any wording.
  local s="$WORK/strings.$RANDOM" t
  user_strings "$SCRIPT" >"$s"
  for t in 'usage: bootstrap-project.sh layout-pack' 'unknown pack: ' 'target dir is not empty' \
    'missing from the pack: ' 'not in the layout table: ' 'pack folder not found' 'Laid out the' \
    'What happened:' 'What to do next:' 'Something unexpected happened' \
    'Choose one of the packs' 'This copy of the bootstrapper is incomplete' \
    'Choose a folder that is empty' 'Check that the languages folder'; do
    grep -qF -- "$t" "$s" || { cat "$s" >&2; die "collector missed: $t"; }
  done
}

test_no_output_bypasses_the_message_helpers() {
  local hits
  hits="$(bypass_lines "$SCRIPT")"
  [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "output written outside the message helpers"; }
}

test_bypass_check_catches_a_planted_echo() {
  # Only the planted lines (after the script's own last line) are counted.
  local copy="$WORK/copy.$RANDOM.sh" last n
  cp "$SCRIPT" "$copy"
  last="$(wc -l <"$copy" | tr -d ' ')"
  # A here-string (<<<) feeds a command, not the terminal: not caught.
  printf '%s\n' 'cmd_x() { echo "hello"; }' 'printf "%s\n" hi' 'cat <<EOF' 'x >&2' \
    'echo "to a file" >"$f"  # not-user-facing' 'done <<<"$table"' >>"$copy"
  n="$(bypass_lines "$copy" | awk -F: -v last="$last" '$1 > last' | wc -l | tr -d ' ')"
  [ "$n" -eq 4 ] || { bypass_lines "$copy" >&2; die "caught $n of 4 planted outputs"; }
}

test_no_banned_words_in_user_facing_strings() {
  local hits
  hits="$(user_strings "$SCRIPT" | banned_hits)"
  [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "banned word without its explanation"; }
}

test_banned_words_check_catches_planted_violations() {
  # Each planted line holds one banned word in a form a message might
  # use; each must be caught, through the same collection the real
  # check uses.
  # Only the planted lines (after the script's own last line) are counted,
  # so this tests the checker whatever the script says.
  local copy="$WORK/copy.$RANDOM.sh" w n hits last
  local planted='Making a copy (clone) now
Could not clone it
It was cloned
Missing scope
The status check failed
Your PR is open
Open PRs: 2
Creating the repo
Two repos found
The repository exists
On the main branch
The API said no'
  cp "$SCRIPT" "$copy"
  last="$(wc -l <"$copy" | tr -d ' ')"
  while IFS= read -r w; do
    printf 'say "%s"\n' "$w" >>"$copy"
  done <<<"$planted"
  # A continuation line of a helper call is collected too.
  printf '%s\n' 'fail 1 "It failed." \' '  "Open the branch page."' >>"$copy"
  hits="$(user_strings "$copy" | banned_hits | awk -F: -v last="$last" '$1 > last')"
  n="$(printf '%s\n' "$hits" | grep -c . || true)"
  # 12 planted say lines minus "copy (clone)" (one word in brackets is
  # not an explanation of three words, so it is still caught: 12), plus
  # the continuation line: 13.
  [ "$n" -eq 13 ] || { printf '%s\n' "$hits" >&2; die "caught $n of 13 planted violations"; }
}

test_banned_word_with_its_explanation_or_in_a_command_passes() {
  local copy="$WORK/copy.$RANDOM.sh" hits last
  cp "$SCRIPT" "$copy"
  last="$(wc -l <"$copy" | tr -d ' ')"
  printf '%s\n' \
    'say "Your repo (the home of your project on GitHub) is ready."' \
    'say_command "gh repo clone $owner/$name"' \
    'say "Problems: none. Approval step done."' >>"$copy"
  hits="$(user_strings "$copy" | banned_hits | awk -F: -v last="$last" '$1 > last')"
  [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "an explained word or a command was flagged"; }
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
