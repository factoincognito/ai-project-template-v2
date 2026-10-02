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
  api)
    # The signed-in account: login, then profile name (empty when the
    # profile has none), one per line. STUB_GH_LOGIN and STUB_GH_NAME
    # set them, STUB_GH_CR adds a carriage return to each line (as on
    # Windows), STUB_GH_USER_ERROR makes the call fail with that text.
    if [ "$#" -eq 4 ] && [ "$2" = user ] && [ "$3" = --jq ] && [ "$4" = '.login, (.name // "")' ]; then
      if [ -n "${STUB_GH_USER_ERROR:-}" ]; then
        printf '%s\n' "$STUB_GH_USER_ERROR" >&2
        exit 1
      fi
      printf '%s%s\n%s%s\n' "${STUB_GH_LOGIN:-octo-user}" "${STUB_GH_CR:-}" \
        "${STUB_GH_NAME-Octo User}" "${STUB_GH_CR:-}"
    else
      echo "stub gh: no emulation for: $*" >&2; exit 64
    fi
    ;;
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

# ---------- safe defaults for the hooks ----------
# Every test runs with both hooks pointing at stubs that refuse: they log
# the call to $REFUSE_LOG, say which hook to set, and exit 70. So a test
# that forgets to set a hook runs no real install, login or gh, and
# fails. A test that needs the real default unsets the hook itself.

make_refuser() {
  local path="$1" hook="$2"
  cat >"$path" <<STUB
#!/usr/bin/env bash
printf '%s\\n' "$hook \$*" >>"\${REFUSE_LOG:-$WORK/refused.log}"
echo "test harness: refused to run '\$*' for real; this test must set $hook" >&2
exit 70
STUB
  chmod +x "$path"
}
mkdir -p "$WORK/refuse"
make_refuser "$WORK/refuse/run" BOOTSTRAP_RUN
make_refuser "$WORK/refuse/gh" BOOTSTRAP_GH
export BOOTSTRAP_RUN="$WORK/refuse/run" BOOTSTRAP_GH="$WORK/refuse/gh"

# ---------- user-facing strings ----------
# How the strings are collected, for the banned-words check:
#   - every line inside the messages block ("# ---------- messages
#     ----------" up to "# ---------- end of messages ----------") that
#     is not a comment: the helpers' fixed texts, shared texts, usage;
#   - every call of a listed message helper (MSG_HELPERS) outside the
#     block, with its continuation lines (a line ending in \);
#   - every quoted string literal anywhere in the script that holds a
#     space (literal_strings), so a message kept in a variable or passed
#     to a helper not in MSG_HELPERS is checked too.
# Shell variables are removed: their content is a path or a value the
# user typed, not wording. Not seen, so for review: a banned word held in
# a one-word value (local what=repo; say "Creating the $what") or passed
# unquoted to a helper not in MSG_HELPERS. The argument of say_command and run_offered
# is not checked for banned words: it is an exact command, so instead it
# must start with a known command word (command_arg_violations).
# What reaches the terminal some other way is the job of bypass_lines;
# what it cannot see is listed there.

MSG_HELPERS='say|step_start|step_end|show_error|fail|ask|prompt_for|answer|add_problem'

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

# literal_strings <file>: every quoted string literal ("..." or '...',
# also over several lines) that contains a space, outside comments, as
# "<first line>: <text>", with shell variables removed. A message built
# in a variable, or passed to a helper the harness does not list, is a
# literal somewhere, so this sees it. The arguments of say_command and
# run_offered are left out: they are exact commands (checked by
# command_arg_violations instead).
literal_strings() {
  awk -v sq="'" '
    function flush() {
      if (lit ~ / / && !skip) { gsub(/\n/, " ", lit); print start ": " lit }
    }
    {
      line = $0; n = length(line); i = 1
      if (q == "") prefix = ""
      while (i <= n) {
        c = substr(line, i, 1)
        if (q == "") {
          if (c == "#" && (i == 1 || substr(line, i - 1, 1) ~ /[[:space:];]/)) break
          if (c == "\\") { prefix = prefix substr(line, i, 2); i += 2; continue }
          if (c == "\"" || c == sq) {
            q = c; lit = ""; start = NR
            skip = (prefix ~ /(^|[^A-Za-z0-9_])(say_command|run_offered)[[:space:]]+$/)
          } else {
            prefix = prefix c
            if (c == ";" || c == "|" || c == "&") prefix = ""
          }
        } else if (c == q) {
          flush(); q = ""; prefix = prefix "S"
        } else if (q == "\"" && c == "\\") {
          lit = lit substr(line, i + 1, 1); i += 2; continue
        } else {
          lit = lit c
        }
        i++
      }
      if (q != "") lit = lit "\n"
    }
  ' "$1" | sed -E 's/\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*|\$[0-9@*#?]//g'
}

# all_banned_hits <file>: every banned-word hit in the file's user-facing
# strings (the helper calls and the messages block, plus every literal),
# one line per source line.
all_banned_hits() {
  { user_strings "$1"; literal_strings "$1"; } | banned_hits | LC_ALL=C sort -t: -k1,1n -u
}

# The first words a copy-paste command may start with: the tools the spec
# names. say_command may also print a line starting with sudo (on Linux
# the script prints the package-manager line for the user to run);
# run_offered never runs sudo.
CMD_WORDS='gh git npm node winget brew bash cd xcode-select'
SAY_CMD_WORDS="$CMD_WORDS sudo"

# command_arg_violations <file>: say_command and run_offered calls whose
# argument is not one quoted literal starting with an allowed command
# word. A run_offered argument may hold no $ or backtick at all: it runs
# through bash -c, so it must be a fixed string, never built from input.
command_arg_violations() {
  awk -v sq="'" -v say_words=" $SAY_CMD_WORDS " -v run_words=" $CMD_WORDS " '
    /^[[:space:]]*#/ { next }
    match($0, /(^|[^A-Za-z0-9_])(say_command|run_offered)([[:space:]]|$)/) {
      rest = substr($0, RSTART + RLENGTH)
      kind = ($0 ~ /(^|[^A-Za-z0-9_])run_offered([[:space:]]|$)/) ? "run" : "say"
      sub(/^[[:space:]]+/, "", rest)
      q = substr(rest, 1, 1)
      if (q != "\"" && q != sq) { print NR ": " $0; next }
      arg = substr(rest, 2); end = index(arg, q)
      if (end == 0) { print NR ": " $0; next }
      arg = substr(arg, 1, end - 1)
      word = arg; sub(/[[:space:]].*/, "", word)
      words = (kind == "run") ? run_words : say_words
      if (word == "" || index(words, " " word " ") == 0) { print NR ": " $0; next }
      if (kind == "run" && arg ~ /[$`]/) { print NR ": " $0; next }
    }
  ' "$1"
}

# bypass_lines <file>: lines outside the messages block that can put text
# on the terminal without a helper. A line that writes somewhere else on
# purpose ends with "# not-user-facing". Checked:
#   - echo, printf or >&2, on the line with its quoted strings removed;
#   - /dev/stderr, /dev/stdout, /dev/tty or /dev/fd/N (on the full line);
#   - BOOTSTRAP_GH outside the body of run_gh: every gh call goes through
#     run_gh, so its output is seen here;
#   - a heredoc (<< or <<-, not the here-string <<<, and not a << shift
#     inside $(( )) or (( ))), wherever its command's output goes: its
#     body is text the banned-words check does not read;
#   - each run_gh, gh, git, npm, cat or tee command whose own stdout is
#     neither captured ($( ), <( ) or backticks around it) nor sent
#     elsewhere with a stdout redirect (>, >>, 1>, &>) in the same
#     command, or after the same pipeline or ( ) subshell. The command
#     may be written \gh or with a path (/usr/bin/gh, ./bin/gh). A walker
#     reads the code with its quotes ('...', "...", $'...' with its \
#     escapes), $( ), $(( )) and ( ) nesting and continuation lines, so a
#     capture or redirect elsewhere on the line does not count (the S4
#     review's note A). It skips a heredoc body up to its terminator line
#     (tabs before it allowed for <<-, the delimiter read with its quotes
#     or \ removed), so the quotes in a body do not carry over. A heredoc
#     with no terminator line would hide the rest of the file, so its
#     first line is flagged even when it is marked quiet.
# Not covered (no static scan can tell): the stderr of those commands
# (gh's error text is raw: tests check that each gh call's error is
# shown through show_error), the stdout of other commands (ls, sed,
# find, tr ...: the script uses them inside a capture or a redirected
# pipeline), output through an eval or a { } group, code in a string run
# later (trap '...', bash -c '...'), a command named through a variable
# or in quotes ("gh", $gh, "$dir"/gh), raw output passed to a helper
# (say "$(run_gh ...)"), a case pattern inside $( ), a nested ( )
# subshell written (( with no space (read as arithmetic), and a helper
# defined outside the messages block that prints through say (its texts
# are still checked by literal_strings). The body lines of a heredoc get
# the line checks above, but not the walker.
# run_offered's own output reaches the terminal on purpose: an install or
# a login has to show its progress and prompts.
bypass_lines() {
  awk -v sq="'" '
    function flag(n) { if (!(n in quiet)) hit[n] = 1 }
    function settle() { if (pend[d]) flag(pend[d]); pend[d] = 0 }
    function push(t) { d++; ctx[d] = t; pend[d] = 0; par[d] = 0 }
    function pop() {
      # The output of a ( ) subshell goes where the subshell sends it.
      if (ctx[d] == "p" && pend[d] && !pend[d - 1]) pend[d - 1] = pend[d]
      d--
    }
    function captured(   k) {
      for (k = 2; k <= d; k++) if (ctx[k] == "c" || ctx[k] == "b") return 1
      return 0
    }
    # after_path(i): the word at i ends a path (/usr/bin/gh, ./gh, ~/gh)
    # that starts where a word may start (not after $ = { } or \).
    function after_path(i,   j, tok) {
      j = i - 1
      while (j >= 1 && substr($0, j, 1) ~ /[A-Za-z0-9_.\/~-]/) j--
      tok = substr($0, j + 1, i - 1 - j)
      if (tok !~ /^(\/|\.\.?\/|~\/)/) return 0
      return (j == 0 || substr($0, j, 1) !~ /[$={}\\]/)
    }
    # heredoc(i): reads the delimiter after the << (or <<-) at i and
    # queues it; returns the index just after the delimiter word.
    function heredoc(i,   strip, ch, w, q) {
      i += 2; strip = 0
      if (substr($0, i, 1) == "-") { strip = 1; i++ }
      while (substr($0, i, 1) ~ /[ \t]/) i++
      w = ""
      while (i <= n) {
        ch = substr($0, i, 1)
        if (ch ~ /[ \t;|&<>()]/) break
        if (ch == "\\") { w = w substr($0, i + 1, 1); i += 2; continue }
        if (ch == sq || ch == "\"") {
          q = ch; i++
          while (i <= n && substr($0, i, 1) != q) {
            if (q == "\"" && substr($0, i, 1) == "\\") i++
            w = w substr($0, i, 1); i++
          }
          i++; continue
        }
        w = w ch; i++
      }
      if (w != "") { nh++; hdelim[nh] = w; hstrip[nh] = strip; hline[nh] = NR }
      return i
    }
    BEGIN { d = 1; ctx[1] = "t"; pend[1] = 0; nh = 0; hcur = 0 }
    /^[[:space:]]*# ---------- messages ----------/ { inblk = 1; next }
    /^[[:space:]]*# ---------- end of messages ----------/ { inblk = 0; next }
    inblk { next }
    d == 1 && !hcur && /^[[:space:]]*#/ { next }
    {
      src[NR] = $0
      if ($0 ~ /# not-user-facing[[:space:]]*$/) quiet[NR] = 1
      line = $0
      gsub(/"([^"\\]|\\.)*"/, "", line); gsub(sq "[^" sq "]*" sq, "", line)
      if (line ~ /(^|[^A-Za-z0-9_])(echo|printf)([[:space:]]|$)/ || line ~ />&2/) flag(NR)
      if ($0 ~ /\/dev\/(stderr|stdout|tty|fd\/[0-9])/) flag(NR)
      if ($0 ~ /^run_gh\(\)[[:space:]]*\{/) in_run_gh = 1
      if ($0 ~ /BOOTSTRAP_GH/ && !in_run_gh) flag(NR)
      if (in_run_gh && $0 ~ /^\}/) in_run_gh = 0

      # A heredoc body: data up to its terminator line.
      if (hcur) {
        term = $0
        if (hstrip[hcur]) sub(/^\t+/, "", term)
        if (term == hdelim[hcur]) { hcur++; if (hcur > nh) { hcur = 0; nh = 0 } }
        next
      }

      n = length($0); i = 1; cont = 0; wb = 0
      while (i <= n) {
        c = substr($0, i, 1); t = ctx[d]; nx = substr($0, i + 1, 1)
        nx2 = substr($0, i + 2, 1)
        pv = (i > 1) ? substr($0, i - 1, 1) : ""
        if (t == "s") { if (c == sq) d--; i++; continue }
        if (t == "e") {
          if (c == "\\") { i += 2; continue }
          if (c == sq) d--
          i++; continue
        }
        if (t == "d") {
          if (c == "\\") { i += 2; continue }
          if (c == "\"") { d--; i++; continue }
          if (c == "$" && nx == "(" && nx2 == "(") { push("a"); i += 3; continue }
          if (c == "$" && nx == "(") { push("c"); i += 2; continue }
          if (c == "`") { push("b"); i++; continue }
          i++; continue
        }
        if (t == "a") {
          # Arithmetic: only its nesting matters; << here is a shift.
          if (c == "(") { par[d]++; i++; continue }
          if (c == ")") {
            if (par[d] > 0) { par[d]--; i++; continue }
            d--; i += (nx == ")") ? 2 : 1; continue
          }
          if (c == "$" && nx == "(" && nx2 == "(") { push("a"); i += 3; continue }
          if (c == "$" && nx == "(") { push("c"); i += 2; continue }
          if (c == "`") { push("b"); i++; continue }
          i++; continue
        }
        # A command context: the top level, $( ), <( ), ( ) or backticks.
        if (c == "\\") {
          if (i == n) { cont = 1; i++; continue }
          # \gh runs gh: the word after the \ is checked.
          if (nx ~ /[A-Za-z_]/ && (i == 1 || pv !~ /[A-Za-z0-9_$={}\/.-]/)) { wb = i + 1; i++; continue }
          i += 2; continue
        }
        if (c == sq) { push("s"); i++; continue }
        if (c == "$" && nx == sq) { push("e"); i += 2; continue }
        if (c == "\"") { push("d"); i++; continue }
        if (c == "`") { if (t == "b") pop(); else push("b"); i++; continue }
        if (c == "#" && (i == 1 || pv ~ /[[:space:];]/)) break
        if (c == "<" && nx == "<") {
          if (nx2 == "<") { i += 3; continue }
          flag(NR); i = heredoc(i); continue
        }
        if (c == "$" && nx == "(" && nx2 == "(") { push("a"); i += 3; continue }
        if (c == "(" && nx == "(") { push("a"); i += 2; continue }
        if ((c == "$" || c == "<") && nx == "(") { push("c"); i += 2; continue }
        if (c == "(") { push("p"); i++; continue }
        if (c == ")") { if (d > 1) pop(); else settle(); i++; continue }
        if (c == ";") { settle(); i++; continue }
        if (c == "&") {
          if (nx == ">") { pend[d] = 0; i += 2; continue }
          if (nx == "&") { settle(); i += 2; continue }
          settle(); i++; continue
        }
        if (c == "|") { if (nx == "|") { settle(); i += 2 } else i++; continue }
        if (c == ">") {
          if (nx == "&") { i += 2; continue }
          if (pv ~ /[0-9]/ && !(pv == "1" && (i < 3 || substr($0, i - 2, 1) !~ /[A-Za-z0-9_]/))) { i++; continue }
          pend[d] = 0; i++; continue
        }
        if (c ~ /[A-Za-z_]/ && (i == 1 || i == wb || pv !~ /[A-Za-z0-9_$={}\/.-]/ || (pv == "/" && after_path(i)))) {
          w = substr($0, i); match(w, /^[A-Za-z0-9_-]+/); w = substr(w, 1, RLENGTH)
          nw = substr($0, i + length(w), 1)
          if (w ~ /^(run_gh|gh|git|npm|cat|tee)$/ && nw != "=" && nw != "(" && !captured()) pend[d] = NR
          i += length(w); continue
        }
        i++
      }
      if (!cont && ctx[d] != "s" && ctx[d] != "d" && ctx[d] != "e") settle()
      if (nh && !cont) hcur = 1
    }
    END {
      if (nh) hit[hline[hcur ? hcur : 1]] = 1
      for (k = 1; k <= NR; k++) if (k in hit) print k ": " src[k]
    }
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
  # `curl ... | bash` is not supported (the prompts read stdin, which is
  # then the script itself), but the sourced-or-executed check must not
  # make a piped run silently do nothing: it runs, and with no arguments
  # (the questions) it refuses in plain words with exit 2, asking nothing.
  local err="$WORK/err.$RANDOM" out="$WORK/out.$RANDOM" rc=0
  bash <"$SCRIPT" >"$out" 2>"$err" || rc=$?
  [ "$rc" -eq 2 ] || { cat "$err" >&2; die "piped run exited $rc, want 2"; }
  sed -n 1p "$err" | grep -qE '^What happened: .*(pipe|piped)' || { cat "$err" >&2; die "piped run did not say why it stopped"; }
  grep -qE '^What to do next: .*README' "$err" || { cat "$err" >&2; die "piped run did not point to the README command"; }
  ! grep -q ': $' "$out" || { cat "$out" >&2; die "piped run asked a question"; }
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

test_a_test_that_forgets_the_hooks_runs_nothing_real() {
  # Review round 1: CI must be safe by structure, not by each test
  # remembering the hooks. A test that sets neither hook runs no real
  # install, login or gh: the harness defaults both to stubs that refuse
  # loudly (non-zero exit), so the forgetful test fails.
  local d rc
  d="$(tmpdir)"; mkdir -p "$d/bin"
  printf '#!/usr/bin/env bash\ntouch "%s/real-gh-ran"\n' "$d" >"$d/bin/gh"
  chmod +x "$d/bin/gh"
  rc=0
  ( load_script; export REFUSE_LOG="$d/refused.log" PATH="$d/bin:$PATH"; run_offered "touch '$d/real-run-ran'" ) \
    2>"$d/err" || rc=$?
  [ ! -e "$d/real-run-ran" ] || die "run_offered ran the real command in a test that set no hook"
  [ "$rc" -ne 0 ] || die "run_offered without a hook returned 0; a forgetful test would pass"
  rc=0
  ( load_script; export REFUSE_LOG="$d/refused.log" PATH="$d/bin:$PATH"; run_gh --version ) 2>>"$d/err" || rc=$?
  [ ! -e "$d/real-gh-ran" ] || die "run_gh ran the gh on PATH in a test that set no hook"
  [ "$rc" -ne 0 ] || die "run_gh without a hook returned 0; a forgetful test would pass"
  grep -qF 'BOOTSTRAP_RUN' "$d/err" && grep -qF 'BOOTSTRAP_GH' "$d/err" \
    || { cat "$d/err" >&2; die "the refusals do not name the hook to set"; }
  [ "$(wc -l <"$d/refused.log" | tr -d ' ')" -eq 2 ] || die "refusals not logged"
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
    'Choose a folder that is empty' 'Check that the languages folder' \
    'There is no default, because only you can choose it' 'Please try again' \
    'not one this script knows' 'needs a value after it' 'Some options are missing or cannot be used' \
    'a question got no answer' 'Could not read your GitHub account'; do
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
  hits="$(all_banned_hits "$SCRIPT")"
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

# plant <lines...>: a copy of the script with the lines added at the end;
# prints the copy's path. planted_from prints the copy's first planted
# line number, so a test can count only what it planted.
plant() {
  local copy
  copy="$(mktemp "$WORK/copy.XXXXXX")"
  cp "$SCRIPT" "$copy"
  printf '%s\n' "$@" >>"$copy"
  printf '%s\n' "$copy"
}
planted_from() { echo $(( $(wc -l <"$SCRIPT" | tr -d ' ') + 1 )); }

# only_planted <first line>: keeps the "<line>: ..." / "<line><tab>..."
# hits at or after that line.
only_planted() { awk -F'[:\t]' -v from="$1" '$1 >= from'; }

test_banned_words_in_a_message_held_in_a_variable_are_caught() {
  # Review round 1: a message built in a variable got past the check.
  local copy hits from
  copy="$(plant 'cmd_x() {' \
    '  local msg="Creating the repo now"' \
    '  say "$msg"' \
    '  local next="Open the repo page and approve the PR."' \
    '  fail 1 "It stopped." "$next"' \
    '}')"
  from="$(planted_from)"
  hits="$(all_banned_hits "$copy" | only_planted "$from")"
  [ "$(printf '%s\n' "$hits" | grep -c .)" -eq 2 ] || { printf '%s\n' "$hits" >&2; die "variable messages not both caught"; }
}

test_banned_words_through_an_unlisted_helper_are_caught() {
  # Review round 1: a helper that is not in MSG_HELPERS got past the check.
  local copy hits from
  copy="$(plant 'warn() { say "Warning: $*"; }' 'cmd_x() { warn "The status check failed"; }')"
  from="$(planted_from)"
  hits="$(all_banned_hits "$copy" | only_planted "$from")"
  [ "$(printf '%s\n' "$hits" | grep -c .)" -eq 1 ] || { printf '%s\n' "$hits" >&2; die "unlisted helper's text not caught"; }
}

test_output_routes_without_echo_or_printf_are_caught() {
  # Review round 1: these reach the terminal without echo, printf, a
  # heredoc or >&2. Raw gh output also breaks "never raw text alone".
  local copy n from
  copy="$(plant 'cmd_x() {' \
    '  run_gh pr checks 1' \
    '  cat "$file"' \
    '  tee /dev/stderr <<<"Clone failed"' \
    '  cat >/dev/stderr' \
    '  printf "%s" x >/dev/tty' \
    '}')"
  from="$(planted_from)"
  n="$(bypass_lines "$copy" | only_planted "$from" | wc -l | tr -d ' ')"
  [ "$n" -eq 5 ] || { bypass_lines "$copy" >&2; die "caught $n of 5 planted output routes"; }
}

test_captured_or_redirected_gh_output_is_allowed() {
  local copy hits from
  copy="$(plant 'cmd_x() {' \
    '  out="$(run_gh api user)"' \
    '  run_gh api user >/dev/null' \
    '  run_gh api user >"$f" 2>"$err"' \
    '  if run_gh auth status >/dev/null 2>&1; then :; fi' \
    '  if out="$(run_gh api user --jq '"'"'.login, (.name // "")'"'"' 2>"$err")"; then :; fi' \
    '  raw="$(cat "$err")"' \
    '  run_gh api user \' \
    '    --jq .login >"$f"' \
    '  ( cat "$f" ) >"$g"' \
    '  run_gh api user | tr -d x >"$f"' \
    '  done < <(run_gh api user)' \
    '  x=cat; y=$(git rev-parse HEAD)' \
    '}')"
  from="$(planted_from)"
  hits="$(bypass_lines "$copy" | only_planted "$from")"
  [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "captured gh output was flagged"; }
}

test_output_hidden_by_a_capture_elsewhere_on_the_line_is_caught() {
  # Review of the harness (note A): a capture or redirect anywhere on the
  # line used to exempt the whole line, so these reached the terminal
  # unseen. Each planted line must now be caught on its own.
  local copy n from
  copy="$(plant 'cmd_y() {' \
    '  run_gh pr create --body-file <(say "x")' \
    '  run_gh pr checks $(current_pr)' \
    '  run_gh pr checks >"$out"; cat "$out"' \
    '  cat<"$file"' \
    '  relay() { cat; }' \
    '  "${BOOTSTRAP_GH:-gh}" pr checks >"$out"' \
    '  ( cat "$f" )' \
    '  run_gh api user \' \
    '    --jq .login' \
    '}')"
  from="$(planted_from)"
  n="$(bypass_lines "$copy" | only_planted "$from" | wc -l | tr -d ' ')"
  [ "$n" -eq 8 ] || { bypass_lines "$copy" | only_planted "$from" >&2; die "caught $n of 8 planted output routes"; }
}

# flagged_offsets <copy> <first planted line>: the flagged planted lines,
# as offsets from the first planted line (1 = the first), space-separated.
flagged_offsets() {
  bypass_lines "$1" | awk -F: -v from="$2" '$1 >= from { printf "%s%d", sep, $1 - from + 1; sep = " " }'
}

# expect_flagged <what> <copy> <first planted line> <offsets...>: exactly
# these planted lines are flagged.
expect_flagged() {
  local what="$1" copy="$2" from="$3" got
  shift 3
  got="$(flagged_offsets "$copy" "$from")"
  [ "$got" = "$*" ] || { bypass_lines "$copy" | only_planted "$from" >&2; die "$what: flagged planted lines [$got], want [$*]"; }
}

test_a_quiet_heredoc_does_not_hide_later_output() {
  # Review of 869cb9f (finding 1): the walker kept quote and $( ) state
  # through a heredoc body, so an apostrophe, a " or an unclosed $( in
  # the body stopped every later check. The body is data: it is skipped
  # up to its terminator line, and the later bare commands are caught.
  local body copy from
  for body in "It's a body" 'Say "hello' 'Run $( now'; do
    copy="$(plant 'write_notes() {' \
      '  cat >"$f" <<EOF  # not-user-facing' \
      "$body" \
      'EOF' \
      '}' \
      'cmd_z() {' \
      '  run_gh pr checks' \
      '  cat "$x"' \
      '}')"
    from="$(planted_from)"
    expect_flagged "body [$body]" "$copy" "$from" 7 8
  done
}

test_a_heredoc_inside_a_capture_does_not_hide_later_output() {
  # The heredoc line itself is flagged as any heredoc is (its body is not
  # read by the banned-words check); the later bare run_gh is too.
  local copy from
  copy="$(plant 'cmd_y() {' \
    '  body="$(cat <<'"'"'EOF'"'"'' \
    "It's the body" \
    'EOF' \
    '  )"' \
    '  run_gh pr checks' \
    '}')"
  from="$(planted_from)"
  expect_flagged "heredoc in a capture" "$copy" "$from" 2 6
}

test_heredoc_delimiters_quoted_or_dash_are_read() {
  # <<-: the terminator may be indented with tabs. A quoted delimiter
  # ('EOF', "EOF", \EOF) ends at the bare word. Two heredocs on one line
  # end one after the other. The body lines are not checked as commands.
  local tab copy from
  tab="$(printf '\t')"
  copy="$(plant 'cmd_y() {' \
    '  cat >"$f" <<-EOF  # not-user-facing' \
    "${tab}It's indented" \
    "${tab}run_gh pr checks" \
    "${tab}EOF" \
    '  run_gh pr checks' \
    '  cat >"$f" <<'"'"'EOF'"'"'  # not-user-facing' \
    "It's quoted" \
    'EOF' \
    '  run_gh pr checks' \
    '  cat >"$f" <<"END"  # not-user-facing' \
    'Say "hi' \
    'END' \
    '  run_gh pr checks' \
    '  cat >"$f" <<\EOF  # not-user-facing' \
    "It's escaped" \
    'EOF' \
    '  run_gh pr checks' \
    '  paste - /dev/fd/3 >"$f" <<A 3<<'"'"'B'"'"'  # not-user-facing' \
    "It's one" \
    'A' \
    'Run $( two' \
    'B' \
    '  run_gh pr checks' \
    '}')"
  from="$(planted_from)"
  expect_flagged "quoted or dash delimiters" "$copy" "$from" 6 10 14 18 24
}

test_a_here_string_or_a_shift_is_not_a_heredoc() {
  # <<< feeds one string; << inside $(( )) or (( )) is a bit shift. None
  # starts a body, so the lines after them are still checked.
  local copy from
  copy="$(plant 'cmd_y() {' \
    '  x="$(tr a b <<<"$y")"' \
    '  run_gh pr checks' \
    '  n=$((1 << 2))' \
    '  run_gh pr checks' \
    '  (( n <<= 1 )) || :' \
    '  run_gh pr checks' \
    '  m="$(( (n + 1) << 1 ))"' \
    '  run_gh pr checks' \
    '}')"
  from="$(planted_from)"
  expect_flagged "here-string or shift" "$copy" "$from" 3 5 7 9
}

test_an_unterminated_heredoc_is_flagged() {
  # A heredoc with no terminator line would hide the rest of the file,
  # so its first line is flagged even when it is marked quiet.
  local copy from
  copy="$(plant 'cmd_y() {' \
    '  cat >"$f" <<EOF  # not-user-facing' \
    'no end' \
    '  run_gh pr checks' \
    '}')"
  from="$(planted_from)"
  expect_flagged "unterminated heredoc" "$copy" "$from" 2
}

test_an_ansi_c_string_does_not_hide_later_output() {
  # Review of 869cb9f (finding 1): $'...' takes \ as an escape, so
  # $'\'' is one quote character, not the end of the string.
  local copy from
  copy="$(plant 'cmd_y() {' \
    "  q=\$'\\''" \
    '  run_gh pr checks' \
    "  s=\$'it\\'s'; t='plain'" \
    '  cat "$x"' \
    '}')"
  from="$(planted_from)"
  expect_flagged "ANSI-C string" "$copy" "$from" 3 5
}

test_a_command_named_with_a_backslash_or_path_is_caught() {
  # Review of 869cb9f (finding 2): \gh and /usr/bin/gh run gh too.
  local copy from
  copy="$(plant 'cmd_y() {' \
    '  \gh pr checks' \
    '  /usr/bin/gh pr checks' \
    '  ./bin/run_gh pr checks' \
    '  \cat "$x"' \
    '  gh_path=/usr/bin/gh; v=a/cat' \
    '}')"
  from="$(planted_from)"
  expect_flagged "backslash or path" "$copy" "$from" 2 3 4 5
}

test_say_command_and_run_offered_take_a_known_command() {
  # Review round 1: say_command is exempt from the banned words because
  # it prints a command to copy, so its argument must be one. run_offered
  # also takes only a fixed string (no $), and never sudo.
  local copy hits from n
  copy="$(plant 'cmd_x() {' \
    '  say_command "Open the PR page and approve the branch"' \
    '  say_command "$cmd"' \
    '  say_command' \
    '  run_offered "sudo apt install git"' \
    '  run_offered "gh auth refresh -h github.com -s $scope"' \
    '  run_offered "$cmd"' \
    '  say_command "gh auth status"' \
    '  say_command "bash bootstrap-project.sh --resume --name $name"' \
    "  run_offered 'gh auth refresh -h github.com -s workflow'" \
    '  run_offered "winget install --id Git.Git -e"' \
    '}')"
  from="$(planted_from)"
  hits="$(command_arg_violations "$copy" | only_planted "$from")"
  n="$(printf '%s\n' "$hits" | grep -c . || true)"
  [ "$n" -eq 6 ] || { printf '%s\n' "$hits" >&2; die "flagged $n, want the first 6 planted calls"; }
  ! printf '%s\n' "$hits" | awk -F'[:\t]' -v f="$from" '$1 >= f + 7' | grep -q . \
    || { printf '%s\n' "$hits" >&2; die "an allowed command was flagged"; }
}

test_say_command_and_run_offered_calls_in_the_script_are_commands() {
  local hits
  hits="$(command_arg_violations "$SCRIPT")"
  [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "say_command or run_offered with something that is not a known command"; }
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

# ---------- inputs ----------
# parse_args reads the options; collect_inputs checks them, asks for the
# missing ones (with --non-interactive: takes the defaults, asks nothing)
# and fills in the defaults. `inputs <dir> <options...>` runs both with
# the script loaded, a stub gh, and stdin from <dir>/in (empty when
# absent). It writes the resolved answers to <dir>/dump (dump_inputs),
# stdout to <dir>/out, stderr to <dir>/err, gh calls to <dir>/gh.log, and
# sets RC. It is never called in a condition, so errexit behaves as in a
# real run.

REQUIRED_OPTS=(--name my-app --description "Lends tools to neighbours." --pack node --license mit)

dump_inputs() {
  printf '%s\n' "NAME=$IN_NAME" "OWNER=$IN_OWNER" "PROJECT_NAME=$IN_PROJECT_NAME" \
    "DESCRIPTION=$IN_DESCRIPTION" "PO_NAME=$IN_PO_NAME" "PACK=$IN_PACK" \
    "WITH_DEPLOY=$IN_WITH_DEPLOY" "VISIBILITY=$IN_VISIBILITY" "LICENSE=$IN_LICENSE" \
    "COPYRIGHT_HOLDER=$IN_COPYRIGHT_HOLDER" "DIR=$IN_DIR" "CI_TIMEOUT=$IN_CI_TIMEOUT" \
    "SLUG=$IN_SLUG" "NON_INTERACTIVE=$OPT_NON_INTERACTIVE" "YES=$OPT_YES" \
    "DRY_RUN=$OPT_DRY_RUN" "RESUME=$OPT_RESUME"
}

inputs() {
  local d="$1"
  shift
  [ -e "$d/in" ] || : >"$d/in"
  [ -x "$d/gh" ] || make_stub_gh "$d/gh"
  rm -f "$d/dump"
  set +e
  ( load_script
    export STUB_GH_LOG="$d/gh.log" BOOTSTRAP_GH="$d/gh"
    parse_args "$@"
    collect_inputs
    dump_inputs >"$d/dump"
  ) <"$d/in" >"$d/out" 2>"$d/err"
  RC=$?
  set -e
}

# expect_inputs <dir> <NAME=value...>: the run succeeded and has each.
expect_inputs() {
  local d="$1" l
  shift
  [ "$RC" -eq 0 ] && [ -s "$d/dump" ] || { cat "$d/err" >&2; die "no answers collected (exit $RC)"; }
  for l in "$@"; do
    grep -qxF -- "$l" "$d/dump" || { cat "$d/dump" >&2; die "answers lack: $l"; }
  done
}

# expect_refused <dir> <option>: exit 2, a plain error first, the option
# listed with its problem, and no answers collected.
expect_refused() {
  local d="$1" opt="$2"
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "exit $RC, want 2 for $opt"; }
  sed -n 1p "$d/err" | grep -q '^What happened: ' || { cat "$d/err" >&2; die "no plain error first"; }
  grep -qE -- "^    - $opt: .{10,}" "$d/err" || { cat "$d/err" >&2; die "$opt not listed with its problem"; }
  grep -qE '^What to do next: .{10,}' "$d/err" || { cat "$d/err" >&2; die "no next action"; }
  [ ! -e "$d/dump" ] || die "answers were collected although $opt was refused"
}

# refuses <option> <value...>: each value, given as the option with the
# other required options, is refused with exit 2 naming the option.
refuses() {
  local opt="$1" v d
  shift
  for v in "$@"; do
    d="$(tmpdir)"
    echo "checking $opt $(printf '%q' "$v")" >&2
    inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner acme --po-name Ada "$opt" "$v"
    expect_refused "$d" "$opt"
  done
}

# accepts <option> <value> <NAME=value>: the value is taken, as shown.
accepts() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner acme --po-name Ada "$1" "$2"
  expect_inputs "$d" "$3"
}

test_inputs_come_from_the_options() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name My.App --owner acme-inc --project-name "My App" \
    --description "Tracks the things we lend out." --po-name "Ada Lovelace" --pack web \
    --with-deploy --private --license apache-2.0 --copyright-holder "Acme Inc." \
    --dir "$d/work dir" --ci-timeout 45
  expect_inputs "$d" NAME=My.App OWNER=acme-inc "PROJECT_NAME=My App" \
    "DESCRIPTION=Tracks the things we lend out." "PO_NAME=Ada Lovelace" PACK=web \
    WITH_DEPLOY=yes VISIBILITY=private LICENSE=apache-2.0 "COPYRIGHT_HOLDER=Acme Inc." \
    "DIR=$d/work dir" CI_TIMEOUT=45 SLUG=my-app NON_INTERACTIVE=1
  [ ! -e "$d/gh.log" ] || { cat "$d/gh.log" >&2; die "GitHub was asked although --owner and --po-name were given"; }
}

test_options_also_take_the_name_equals_value_form() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name=my-app "--description=Lends tools, = and all." \
    --pack=python --license=none --owner=acme --po-name=Ada --ci-timeout=5
  expect_inputs "$d" NAME=my-app "DESCRIPTION=Lends tools, = and all." PACK=python \
    LICENSE=none OWNER=acme PO_NAME=Ada CI_TIMEOUT=5
}

test_defaults_fill_the_options_left_out() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}"
  expect_inputs "$d" OWNER=octo-user PROJECT_NAME=my-app "PO_NAME=Octo User" \
    "COPYRIGHT_HOLDER=Octo User" VISIBILITY=public WITH_DEPLOY=no DIR=./my-app \
    CI_TIMEOUT=20 SLUG=my-app YES= DRY_RUN= RESUME=
  # One gh call, with gh's prompts off.
  [ "$(cat "$d/gh.log")" = "$(printf 'GH_PROMPT_DISABLED=1\tapi\tuser\t--jq\t.login, (.name // "")')" ] \
    || { cat "$d/gh.log" >&2; die "GitHub was not asked exactly once, as expected"; }
}

test_po_name_defaults_to_the_login_when_the_profile_has_no_name() {
  local d
  d="$(tmpdir)"
  export STUB_GH_NAME=""
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}"
  expect_inputs "$d" OWNER=octo-user PO_NAME=octo-user COPYRIGHT_HOLDER=octo-user
}

test_copyright_holder_defaults_to_the_po_name_given() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner acme --po-name "Ada Lovelace"
  expect_inputs "$d" "PO_NAME=Ada Lovelace" "COPYRIGHT_HOLDER=Ada Lovelace"
  [ ! -e "$d/gh.log" ] || die "GitHub was asked although no default needed it"
}

test_github_account_answer_has_carriage_returns_removed() {
  local d
  d="$(tmpdir)"
  STUB_GH_CR="$(printf '\r')"
  export STUB_GH_CR
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}"
  expect_inputs "$d" OWNER=octo-user "PO_NAME=Octo User"
  # Removed where the output is read, not only by the later checks.
  make_stub_gh "$d/gh2"
  [ "$( load_script; STUB_GH_LOG="$d/gh2.log" BOOTSTRAP_GH="$d/gh2" read_github_user
        printf '%s|%s' "$GH_LOGIN" "$GH_PROFILE_NAME" )" = "octo-user|Octo User" ] \
    || die "a carriage return is left in what GitHub answered"
}

test_github_account_failure_is_explained_with_the_raw_text_below() {
  # gh's own error text is raw: it is shown only below a plain message
  # and a next action, for support. Nothing is collected, exit 1.
  local d
  d="$(tmpdir)"
  export STUB_GH_USER_ERROR="HTTP 401: Bad credentials (https://api.github.com/user)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}"
  [ "$RC" -eq 1 ] || { cat "$d/err" >&2; die "exit $RC, want 1"; }
  sed -n 1p "$d/err" | grep -q '^What happened: Could not read your GitHub account' \
    || { cat "$d/err" >&2; die "no plain message first"; }
  sed -n 2p "$d/err" | grep -qE '^What to do next: .*--owner' || { cat "$d/err" >&2; die "no next action"; }
  sed -n 3p "$d/err" | grep -qF 'Details for support' || { cat "$d/err" >&2; die "raw text not introduced"; }
  sed -n 4p "$d/err" | grep -qxF '    HTTP 401: Bad credentials (https://api.github.com/user)' \
    || { cat "$d/err" >&2; die "raw text not shown below"; }
  [ ! -s "$d/out" ] || { cat "$d/out" >&2; die "something went to stdout"; }
  [ ! -e "$d/dump" ] || die "answers were collected"
}

test_non_interactive_lists_every_missing_required_input() {
  local d o
  d="$(tmpdir)"
  inputs "$d" --non-interactive
  for o in --name --description --pack --license; do expect_refused "$d" "$o"; done
  [ ! -e "$d/gh.log" ] || die "GitHub was asked before the missing inputs were reported"
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name my-app --pack web
  for o in --description --license; do expect_refused "$d" "$o"; done
  ! grep -qE -- '^    - --(name|pack):' "$d/err" || { cat "$d/err" >&2; die "a given option was listed as missing"; }
}

test_non_interactive_never_reads_stdin() {
  # The first line of stdin is still there after the inputs are collected.
  local d
  d="$(tmpdir)"
  printf '%s\n' first-line second-line >"$d/in"
  make_stub_gh "$d/gh"
  # Not in a condition, so a failing step stops the subshell (errexit).
  set +e
  ( load_script
    export STUB_GH_LOG="$d/gh.log" BOOTSTRAP_GH="$d/gh"
    parse_args --non-interactive "${REQUIRED_OPTS[@]}"
    collect_inputs
    dump_inputs >"$d/dump"
    IFS= read -r line
    printf '%s\n' "$line" >"$d/first"
  ) <"$d/in" >"$d/out" 2>"$d/err"
  RC=$?
  set -e
  expect_inputs "$d" NAME=my-app OWNER=octo-user
  [ "$(cat "$d/first")" = first-line ] || die "stdin was read: next line is $(cat "$d/first")"
  ! grep -q ': $' "$d/out" || { cat "$d/out" >&2; die "a question was asked"; }
}

test_non_interactive_run_works_with_stdin_from_dev_null_or_closed() {
  # The whole script, as a user runs it. The steps after the questions are
  # not built yet: it stops there, with exit 1, having created nothing.
  local d rc
  d="$(tmpdir)"
  make_stub_gh "$d/gh"
  export STUB_GH_LOG="$d/gh.log" BOOTSTRAP_GH="$d/gh"
  rc=0
  bash "$SCRIPT" --non-interactive "${REQUIRED_OPTS[@]}" </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$d/err" >&2; die "exit $rc, want 1"; }
  grep -qF 'stops after the questions' "$d/err" || { cat "$d/err" >&2; die "no stop message"; }
  rc=0
  bash "$SCRIPT" --non-interactive "${REQUIRED_OPTS[@]}" <&- >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$d/err" >&2; die "stdin closed: exit $rc, want 1"; }
  grep -qF 'stops after the questions' "$d/err" || { cat "$d/err" >&2; die "stdin closed: no stop message"; }
  [ "$(cut -f2- "$d/gh.log" | sort -u)" = "$(printf 'api\tuser\t--jq\t.login, (.name // "")')" ] \
    || { cat "$d/gh.log" >&2; die "gh was used for more than reading the account"; }
}

test_running_with_no_options_starts_the_questions() {
  local d rc=0
  d="$(tmpdir)"
  bash "$SCRIPT" </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 2 ] || { cat "$d/err" >&2; die "exit $rc, want 2 (no answer)"; }
  grep -q '^Project name: $' "$d/out" || { cat "$d/out" >&2; die "the first question was not asked"; }
}

test_unknown_option_is_refused() {
  local d
  d="$(tmpdir)"
  inputs "$d" --nmae my-app
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -qE '^What happened: .*--nmae' || { cat "$d/err" >&2; die "the option is not named"; }
  grep -qE '^What to do next: .*--help' "$d/err" || { cat "$d/err" >&2; die "no pointer to --help"; }
}

test_option_without_its_value_is_refused() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -qE '^What happened: .*--name.*needs a value' || { cat "$d/err" >&2; die "not explained"; }
  d="$(tmpdir)"
  inputs "$d" --non-interactive --description "" --name my-app
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "empty value: exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -qE '^What happened: .*--description.*needs a value' || { cat "$d/err" >&2; die "empty value not explained"; }
}

test_switch_given_a_value_is_refused() {
  local d
  d="$(tmpdir)"
  inputs "$d" --yes=no
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -qE '^What happened: .*--yes' || { cat "$d/err" >&2; die "not explained"; }
}

test_a_word_that_is_not_an_option_shows_the_usage() {
  local d rc=0
  d="$(tmpdir)"
  bash "$SCRIPT" my-app </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 2 ] || { cat "$d/err" >&2; die "exit $rc, want 2"; }
  grep -qF 'usage:' "$d/err" || { cat "$d/err" >&2; die "no usage shown"; }
}

test_help_lists_every_option() {
  local d rc=0 o
  d="$(tmpdir)"
  bash "$SCRIPT" --help </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 0 ] || { cat "$d/err" >&2; die "exit $rc, want 0"; }
  for o in --name --owner --project-name --description --po-name --pack --with-deploy \
    --public --private --license --copyright-holder --dir --ci-timeout --non-interactive \
    --yes --dry-run --resume --help layout-pack; do
    grep -qF -- "$o" "$d/out" || { cat "$d/out" >&2; die "help lacks $o"; }
  done
}

test_name_takes_letters_digits_dots_dashes_and_underscores() {
  accepts --name a NAME=a
  accepts --name 9lives NAME=9lives
  accepts --name My.App_v2-x NAME=My.App_v2-x
  refuses --name -x .x _x "my app" a/b café "a+b" "a$(printf '\t')b" "a\$b"
}

test_dots_in_the_name_become_dashes_in_the_lowercase_slug() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name My.Cool.App --description "x y." --pack node --license mit --owner a --po-name b
  expect_inputs "$d" NAME=My.Cool.App PROJECT_NAME=My.Cool.App SLUG=my-cool-app DIR=./My.Cool.App
}

test_name_whose_slug_npm_does_not_allow_is_refused() {
  local long214 long215
  long214="a$(printf '%0213d' 0)"
  long215="a$(printf '%0214d' 0)"
  refuses --name node_modules NODE_MODULES "$long215"
  accepts --name "$long214" "NAME=$long214"
}

test_name_values_refuse_characters_that_break_json_or_html() {
  # Spec: name values may not contain control characters, ", \, <, >, &
  # or a backtick. The description must be one line.
  local opt c
  for opt in --project-name --description --po-name --copyright-holder; do
    for c in '"' '\' '<' '>' '&' '`' "$(printf '\t')" "$(printf '\r')" "$(printf '\033')" "$(printf '\177')" '
'; do
      refuses "$opt" "a${c}b"
    done
  done
  refuses --dir "a$(printf '\t')b" "a
b"
}

test_a_bar_is_refused_in_the_po_name_and_display_name_only() {
  refuses --project-name "a | b"
  refuses --po-name "a|b"
  accepts --copyright-holder "a | b" "COPYRIGHT_HOLDER=a | b"
  accepts --description "Either this | or that." "DESCRIPTION=Either this | or that."
}

test_description_must_be_one_line_and_not_blank() {
  refuses --description "   " "first
second"
  accepts --description "  One line.  " "DESCRIPTION=One line."
}

test_pack_must_be_one_of_the_four() {
  local p
  refuses --pack ruby nodejs 2
  for p in node web python react-native; do accepts --pack "$p" "PACK=$p"; done
  accepts --pack Web PACK=web
}

test_with_deploy_is_only_for_the_web_pack() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b --with-deploy
  expect_refused "$d" --with-deploy
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name x --description "x y." --pack web --license mit --owner a --po-name b --with-deploy
  expect_inputs "$d" PACK=web WITH_DEPLOY=yes
}

test_public_and_private_cannot_both_be_given() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b --private --public
  expect_refused "$d" --private
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b --private
  expect_inputs "$d" VISIBILITY=private
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b --public
  expect_inputs "$d" VISIBILITY=public
}

test_licence_is_a_listed_choice_or_a_github_licence_key() {
  local l
  for l in none mit apache-2.0 gpl-3.0 bsd-3-clause polyform-noncommercial-1.0.0 agpl-3.0 cc0-1.0; do
    accepts --license "$l" "LICENSE=$l"
  done
  accepts --license MIT LICENSE=mit
  # Whether a key exists on GitHub is a GitHub check, made before
  # anything is created (preflight); here only its form is checked.
  refuses --license "my licence" "mit;x" ../mit -mit .mit
}

test_ci_wait_is_a_whole_number_of_minutes() {
  refuses --ci-timeout 0 -5 1.5 ten 10000 000
  accepts --ci-timeout 1 CI_TIMEOUT=1
  accepts --ci-timeout 9999 CI_TIMEOUT=9999
  accepts --ci-timeout 020 CI_TIMEOUT=20
}

test_owner_is_a_github_account_name() {
  refuses --owner "my org" a/b -acme ac.me ac_me
  accepts --owner Acme-Inc OWNER=Acme-Inc
}

test_every_problem_is_listed_at_once() {
  local d o
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name "bad name" --pack ruby --ci-timeout x
  for o in --name --pack --ci-timeout --description --license; do expect_refused "$d" "$o"; done
}

test_resume_dry_run_and_yes_are_recorded() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b --resume --dry-run --yes
  expect_inputs "$d" RESUME=1 DRY_RUN=1 YES=1
}

test_a_github_profile_name_that_cannot_be_used_is_refused_with_its_option() {
  local d
  d="$(tmpdir)"
  export STUB_GH_NAME="Ada | Lovelace"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}"
  expect_refused "$d" --po-name
}

# ---------- questions ----------
# Without --non-interactive the script asks for every input not given as
# an option, reading one answer per line from stdin. The question order:
# name, display name, description, owner, PO name, pack, deploy files
# (web only), visibility, licence, copyright holder (not for "none"),
# folder.

test_questions_are_asked_for_every_input_not_given() {
  local d
  d="$(tmpdir)"
  printf '%s\n' my-app "My App" "Lends tools to neighbours." "" "" web y private mit "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" NAME=my-app "PROJECT_NAME=My App" "DESCRIPTION=Lends tools to neighbours." \
    OWNER=octo-user "PO_NAME=Octo User" PACK=web WITH_DEPLOY=yes VISIBILITY=private \
    LICENSE=mit "COPYRIGHT_HOLDER=Octo User" DIR=./my-app CI_TIMEOUT=20 NON_INTERACTIVE=
  [ "$(grep -c ': $' "$d/out")" -eq 11 ] || { cat "$d/out" >&2; die "not 11 questions"; }
}

test_an_empty_answer_takes_the_default_shown() {
  local d
  d="$(tmpdir)"
  printf '%s\n' my-app "" "Lends tools." "" "" python "" mit "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" PROJECT_NAME=my-app OWNER=octo-user "PO_NAME=Octo User" VISIBILITY=public \
    "COPYRIGHT_HOLDER=Octo User" DIR=./my-app WITH_DEPLOY=no
  grep -qxF 'Display name [my-app]: ' "$d/out" || { cat "$d/out" >&2; die "default not shown"; }
  grep -qxF 'Owner [octo-user]: ' "$d/out" || { cat "$d/out" >&2; die "owner default not shown"; }
}

test_answers_have_spaces_and_carriage_returns_removed() {
  local d cr
  d="$(tmpdir)"
  cr="$(printf '\r')"
  printf '%s\n' "  my-app $cr" "My App$cr" "Lends tools.$cr" "acme$cr" "Ada$cr" "node$cr" \
    "public$cr" "none$cr" "work$cr" >"$d/in"
  inputs "$d"
  expect_inputs "$d" NAME=my-app "PROJECT_NAME=My App" "DESCRIPTION=Lends tools." OWNER=acme \
    PO_NAME=Ada PACK=node VISIBILITY=public LICENSE=none DIR=work
}

test_questions_are_skipped_for_inputs_given_as_options() {
  local d
  d="$(tmpdir)"
  # Asked: display name, description, owner, PO name, visibility, folder.
  # Not asked: deploy files (python) and copyright holder (licence none).
  printf '%s\n' "" "Lends tools." "" "" "" "" >"$d/in"
  inputs "$d" --name my-app --pack python --license none
  expect_inputs "$d" NAME=my-app PACK=python LICENSE=none "DESCRIPTION=Lends tools." WITH_DEPLOY=no \
    "COPYRIGHT_HOLDER=Octo User"
  [ "$(grep -c ': $' "$d/out")" -eq 6 ] || { cat "$d/out" >&2; die "not 6 questions"; }
  ! grep -qE '^(Project name|Language pack|Licence|Add the publishing files|Copyright holder)' "$d/out" \
    || { cat "$d/out" >&2; die "asked for something given or not needed"; }
}

test_a_wrong_answer_is_explained_and_asked_again() {
  local d t
  d="$(tmpdir)"
  printf '%s\n' "my app" my-app "" "" "Lends tools." "" "" ruby 2 maybe n "" 7 mit "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" NAME=my-app PACK=web WITH_DEPLOY=no LICENSE=mit "DESCRIPTION=Lends tools."
  [ "$(grep -c '^Project name: $' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "name not asked again"; }
  [ "$(grep -c '^Description: $' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "empty required answer not asked again"; }
  [ "$(grep -c '^Language pack' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "pack not asked again"; }
  [ "$(grep -c '^Licence' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "licence not asked again"; }
  [ "$(grep -c 'Please try again\.$' "$d/out")" -eq 5 ] || { cat "$d/out" >&2; die "not 5 retries"; }
  # Each retry first says what was wrong with the answer.
  for t in '^Use only letters, digits' '^An answer is needed here' '^Choose one of the packs' \
    '^Answer yes or no' '^Choose a number from 1 to 6'; do
    grep -qE "$t.* Please try again\.$" "$d/out" || { cat "$d/out" >&2; die "retry not explained: $t"; }
  done
}

test_pack_and_licence_can_be_chosen_by_number_or_name() {
  local d
  d="$(tmpdir)"
  printf '%s\n' my-app "" "Lends tools." "" "" 4 "" 6 "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" PACK=react-native LICENSE=polyform-noncommercial-1.0.0
  d="$(tmpdir)"
  printf '%s\n' my-app "" "Lends tools." "" "" 1 "" 1 "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" PACK=node LICENSE=none
  d="$(tmpdir)"
  printf '%s\n' my-app "" "Lends tools." "" "" python 2 agpl-3.0 "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" PACK=python VISIBILITY=private LICENSE=agpl-3.0
}

test_running_out_of_answers_stops_with_exit_2() {
  local d
  d="$(tmpdir)"
  printf '%s\n' my-app >"$d/in"
  inputs "$d"
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -q '^What happened: .*a question got no answer' || { cat "$d/err" >&2; die "not explained"; }
  grep -qE '^What to do next: .*--non-interactive' "$d/err" || { cat "$d/err" >&2; die "no next action"; }
  [ ! -e "$d/dump" ] || die "answers were collected"
}

test_invalid_options_are_refused_before_any_question() {
  local d
  d="$(tmpdir)"
  printf '%s\n' my-app >"$d/in"
  inputs "$d" --pack ruby
  expect_refused "$d" --pack
  ! grep -q ': $' "$d/out" || { cat "$d/out" >&2; die "a question was asked"; }
}

test_deploy_question_on_another_pack_than_web_is_refused() {
  # --with-deploy given, and the pack chosen at the question is not web.
  local d
  d="$(tmpdir)"
  printf '%s\n' my-app "" "Lends tools." "" "" node "" mit "" "" >"$d/in"
  inputs "$d" --with-deploy
  expect_refused "$d" --with-deploy
  # It stops at once: no question after the pack.
  ! grep -qE '^(Visibility|Licence|Folder)' "$d/out" || { cat "$d/out" >&2; die "questions went on after the conflict"; }
}

# A full question run (web, a licence): every question is asked.
full_transcript() {
  local d="$1"
  printf '%s\n' my-app "" "Lends tools." "" "" web "" "" mit "" "" >"$d/in"
  inputs "$d"
  [ "$RC" -eq 0 ] || { cat "$d/err" >&2; die "the question run failed"; }
}

test_every_question_has_a_one_line_explanation_above_it() {
  # The explanation is the nearest line above the question that is not
  # an indented choice: one sentence or more, at least six words, ending
  # in a full stop.
  local d bad
  d="$(tmpdir)"
  full_transcript "$d"
  bad="$(awk '
    /: $/ {
      n = split(why, w, " ")
      if (why == "" || n < 6 || why !~ /\.$/) print "no explanation above: " $0
      why = ""; next
    }
    /^  / { next }
    { why = $0 }
  ' "$d/out")"
  [ -z "$bad" ] || { cat "$d/out" >&2; printf '%s\n' "$bad" >&2; die "a question has no explanation"; }
}

test_required_questions_have_no_default_and_say_why() {
  local d got
  d="$(tmpdir)"
  full_transcript "$d"
  got="$(awk '
    /: $/ {
      if ($0 ~ / \[[^]]*\]: $/) next
      print $0 (why ~ /There is no default, because only you can choose it\./ ? "WHY" : "NOWHY")
      why = ""; next
    }
    /^  / { next }
    { why = $0 }
  ' "$d/out")"
  [ "$got" = "$(printf '%s\n' 'Project name: WHY' 'Description: WHY' \
    'Language pack (type the number or the name): WHY' 'Licence (type the number or the name): WHY')" ] \
    || { printf '%s\n' "$got" >&2; die "required questions are not exactly the four, each saying why"; }
}

test_pack_and_licence_questions_explain_each_choice() {
  local d c line
  d="$(tmpdir)"
  full_transcript "$d"
  for c in '1) node' '2) web' '3) python' '4) react-native' '1) none' '2) mit' '3) apache-2.0' \
    '4) gpl-3.0' '5) bsd-3-clause' '6) polyform-noncommercial-1.0.0'; do
    line="$(grep -F -- "  $c: " "$d/out" | head -1)"
    [ -n "$line" ] || { cat "$d/out" >&2; die "choice not shown: $c"; }
    [ "$(printf '%s\n' "${line#*: }" | wc -w | tr -d ' ')" -ge 5 ] || die "choice not explained in words: $line"
  done
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
