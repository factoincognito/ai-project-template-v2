#!/usr/bin/env bash
# Tests for bootstrap/stubs/bootstrap-project.sh: its message helpers,
# its test hooks (BOOTSTRAP_GH, BOOTSTRAP_RUN) and the plain-language
# checks on every user-facing string. The layout-pack subcommand has its
# own tests in tools/test-layout-pack.sh; packaging and stamping are
# tested in bootstrap/test.sh.
# Usage: bash bootstrap/test-bootstrap-project.sh
#
# Settings, all optional (unset: every test runs, as before):
#   BOOTSTRAP_TEST_SHARD=i/n   run only shard i of n: the tests at index
#                              i-1, i-1+n, i-1+2n, ... of the sorted list
#                              of tests (interleaved, so the slow tests
#                              spread over the shards). CI runs each OS
#                              leg as n shards (PBI-1.18).
#   BOOTSTRAP_TEST_WEIGHTS=f:c with BOOTSTRAP_TEST_SHARD: split by
#                              measured duration instead (PBI-1.22).
#                              File f has a header "test <columns...>"
#                              and one line per test, its seconds in each
#                              column; c names the column (CI: the OS).
#                              Longest test first, each to the shard with
#                              the least total so far (ties: fewer tests,
#                              then the lower shard); a test f does not
#                              list, or lists with 0, weighs the median
#                              of the column. bootstrap/
#                              test-durations.txt holds the measured
#                              times (bootstrap/durations-from-logs.sh).
#   BOOTSTRAP_TEST_LIST=1      print the names of the tests that would
#                              run, one per line, and run none.
#   BOOTSTRAP_TEST_MANIFEST=f  write the name of each test run to file f
#                              (relative to where this starts), one per
#                              line; bootstrap/check-shards.sh reads it.
#   BOOTSTRAP_NEWCOMER_SCREEN=<folder>  the test of the newcomer's screen
#                              (PBI-1.30) writes screen.txt and README.md
#                              there, the two texts of the pre-check in
#                              docs/NEWCOMER_PRECHECK.md (an absolute path
#                              or relative to where this starts; unset:
#                              a folder of the test, deleted with it).
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

# The shard setting, read before anything else so a bad one fails fast.
SHARD_I=1
SHARD_N=1
if [ -n "${BOOTSTRAP_TEST_SHARD:-}" ]; then
  case "$BOOTSTRAP_TEST_SHARD" in
    [1-9]*/[1-9]*) SHARD_I="${BOOTSTRAP_TEST_SHARD%%/*}"; SHARD_N="${BOOTSTRAP_TEST_SHARD#*/}" ;;
    *) SHARD_I=x ;;
  esac
  # More than 6 digits is refused before any arithmetic: a number that
  # overflows bash's integers would make the test below err (and so be
  # false) or wrap.
  case "$SHARD_I/$SHARD_N" in
    *[!0-9/]* | */*/* | *[0-9][0-9][0-9][0-9][0-9][0-9][0-9]*) SHARD_I=x ;;
  esac
  if [ "$SHARD_I" = x ] || [ "$SHARD_I" -gt "$SHARD_N" ]; then
    echo "BOOTSTRAP_TEST_SHARD must be i/n, whole numbers of up to 6 digits with 1 <= i <= n and no leading zeros; got '$BOOTSTRAP_TEST_SHARD'." >&2
    exit 2
  fi
fi
# The weights setting, read before anything else too: a shard that
# cannot read it would run a wrong set of tests. The file's content is
# checked where it is read, before any test runs (by_duration).
WEIGHTS_FILE=""
WEIGHTS_COL=""
weights_refused() {
  echo "BOOTSTRAP_TEST_WEIGHTS must be <file>:<column> of a durations file; '$BOOTSTRAP_TEST_WEIGHTS': $1." >&2
  exit 2
}
if [ -n "${BOOTSTRAP_TEST_WEIGHTS:-}" ]; then
  case "$BOOTSTRAP_TEST_WEIGHTS" in *?:?*) ;; *) weights_refused "it is not <file>:<column>" ;; esac
  WEIGHTS_FILE="${BOOTSTRAP_TEST_WEIGHTS%:*}"
  WEIGHTS_COL="${BOOTSTRAP_TEST_WEIGHTS##*:}"
  case "$WEIGHTS_FILE" in /*) ;; *) WEIGHTS_FILE="$PWD/$WEIGHTS_FILE" ;; esac
  [ -f "$WEIGHTS_FILE" ] && [ -r "$WEIGHTS_FILE" ] || weights_refused "no readable file $WEIGHTS_FILE"
  [ -s "$WEIGHTS_FILE" ] || weights_refused "it is empty"
fi
MANIFEST="${BOOTSTRAP_TEST_MANIFEST:-}"
case "$MANIFEST" in
  "" | /*) ;;
  *) MANIFEST="$PWD/$MANIFEST" ;;
esac

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
    if [ -s "$WORK/$name.skip" ]; then
      SKIPPED_LIST="$SKIPPED_LIST  $name ($(cat "$WORK/$name.skip"))
"
      echo "     skipped here: $(cat "$WORK/$name.skip")"
    fi
  else
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$name")
    echo "FAIL $name"
    sed 's/^/     | /' "$log"
  fi
}

die() { echo "assertion failed: $*" >&2; exit 1; }

# skip_test <reason>: the calling test checks nothing on this computer,
# for <reason>. It still counts as passed, but run_test shows the reason
# under its ok line and the summary lists it, so a skip is never taken
# for a pass (#247 review, N1). The test returns 0 right after.
SKIPPED_LIST=""
skip_test() {
  printf '%s\n' "$1" >"$WORK/${FUNCNAME[1]}.skip"
}

# A fresh temp dir per call. Its name has a space on purpose: Windows and
# macOS user folders often do, so paths must be quoted everywhere.
tmpdir() { mktemp -d "$WORK/t m p.XXXXXX"; }

# The first line of every stand-in the harness writes (stub gh, runner,
# npm, refusers, fake tools, hooks): the bash running the harness,
# started directly. Through /usr/bin/env, each call of a stand-in started
# two processes (env, then bash), and on Windows every process start
# costs about 30 ms (PBI-1.18, PBI-1.22). A bash path that is empty, not
# absolute or has a space cannot be named on that line, so env is kept
# for it.
# stand_in_shebang <bash path>: prints that first line for the path.
stand_in_shebang() {
  case "$1" in
    "" | [!/]* | *[[:space:]]*) printf '%s\n' '#!/usr/bin/env bash' ;;
    *) printf '#!%s\n' "$1" ;;
  esac
}
STAND_IN_SHEBANG="$(stand_in_shebang "${BASH:-}")"

# write_stand_in <path> <text>: writes the stand-in <path>, its first
# line STAND_IN_SHEBANG and then <text>, and makes it executable. Only
# builtins, except chmod, and mkdir when the folder is new (as the
# helpers it replaces did: make_stub_gh "$d/stub bin/gh" makes the
# folder).
write_stand_in() {
  case "$1" in */*) ;; *) die "write_stand_in: '$1' has no folder" ;; esac
  [ -d "${1%/*}" ] || mkdir -p "${1%/*}"
  printf '%s\n%s' "$STAND_IN_SHEBANG" "$2" >"$1" && chmod +x "$1"
}

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

IFS= read -r -d '' STUB_GH_TEXT <<'STUB' || true
set -euo pipefail
: "${STUB_GH_LOG:?stub gh: STUB_GH_LOG is not set}"
{
  printf 'GH_PROMPT_DISABLED=%s' "${GH_PROMPT_DISABLED-<unset>}"
  for a in "$@"; do printf '\t%s' "$a"; done
  printf '\n'
} >>"$STUB_GH_LOG"
# fails_left <name>: true while the file <name> next to the log holds a
# number above 0, counting it down; a test writes 1 there to make a call
# fail once and then work, as if the user had fixed it in between.
fails_left() {
  local f="${STUB_GH_LOG%/*}/$1" n
  [ -f "$f" ] || return 1
  read -r n <"$f" || true
  [ "$n" -gt 0 ] || return 1
  echo $((n - 1)) >"$f"
}
# The helpers of the api emulation (also used by repo create and edit).
should_fail() {
  [ -f "${STUB_GH_LOG%/*}/$1" ] || return 0
  fails_left "$1"
}
respond() {
  local st="$1" rs="$2" ctype="$3" h
  shift 3
  printf 'HTTP/2.0 %s %s\n' "$st" "$rs"
  printf 'Content-Type: %s\r\n' "$ctype"
  for h in "$@"; do printf '%s\r\n' "$h"; done
  printf '\r\n'
}
http_error() {
  respond "$1" "$2" 'application/json; charset=utf-8'
  printf '{"message":"%s","documentation_url":"https://docs.github.com/rest","status":"%s"}' "$3" "$1"
  printf 'gh: %s (HTTP %s)\n' "$3" "$1" >&2
  exit 1
}
emit_failure() {
  case "$1" in
    signed-out)
      printf '%s\n' 'To get started with GitHub CLI, please run:  gh auth login' \
        'Alternatively, populate the GH_TOKEN environment variable with a GitHub API authentication token.' >&2
      exit 4
      ;;
    expired) http_error 401 Unauthorized 'Bad credentials' ;;
    offline)
      printf '%s\n' 'error connecting to api.github.com' \
        'check your internet connection or https://githubstatus.com' >&2
      exit 1
      ;;
    server) http_error 503 'Service Unavailable' 'Service Unavailable' ;;
    rate-limit) http_error 403 Forbidden 'API rate limit exceeded for user ID 1.' ;;
    forbidden) http_error 403 Forbidden 'Resource not accessible by integration' ;;
    not-found) http_error 404 'Not Found' 'Not Found' ;;
    teapot) http_error 418 'I am a teapot' 'Short and stout' ;;
    too-many) http_error 429 'Too Many Requests' 'Too Many Requests' ;;
    plan) http_error 403 Forbidden 'Upgrade to GitHub Pro or make this repository public to enable this feature.' ;;
    token) http_error 403 Forbidden 'Resource not accessible by personal access token' ;;
    mystery) http_error 403 Forbidden 'Something about this request was refused.' ;;
    *) echo "stub gh: unknown failure mode: $1" >&2; exit 64 ;;
  esac
}
# is_pulls_list <endpoint>: the list of a project's proposed changes from
# bootstrap-setup, as --resume asks for it.
is_pulls_list() {
  case "$1" in repos/*'/pulls?state=all&head='*':bootstrap-setup') return 0 ;; esac
  return 1
}
# seed_project OWNER/NAME: what GitHub makes from the template: a bare
# repo remotes/OWNER/NAME.git next to the log whose main holds the files
# of STUB_GH_TEMPLATE (a real build.sh output) as one commit. git is the
# real one (STUB_GIT), so a fake git's log sees only the script's calls.
seed_project() {
  local bare="${STUB_GH_LOG%/*}/remotes/$1.git" w g="${STUB_GIT:-git}"
  w="$(mktemp -d "${STUB_GH_LOG%/*}/seed.XXXXXX")"
  mkdir -p "$bare"
  "$g" -c init.defaultBranch=main init -q --bare "$bare"
  "$g" --git-dir="$bare" symbolic-ref HEAD refs/heads/main
  cp -R "$STUB_GH_TEMPLATE/." "$w/"
  "$g" -c init.defaultBranch=main init -q "$w"
  "$g" -C "$w" symbolic-ref HEAD refs/heads/main
  "$g" -C "$w" add -A
  "$g" -C "$w" -c user.name=GitHub -c user.email=noreply@github.com commit -q -m "Initial commit"
  "$g" -C "$w" push -q "$bare" main 2>/dev/null
  rm -rf "$w"
}
case "${1:-}" in
  --version)
    # gh-missing: gh is not installed (yet).
    if fails_left gh-missing; then echo "gh: command not found" >&2; exit 127; fi
    echo "gh version 0.0.0 (stub)"
    ;;
  repo)
    # The feature check: a gh new enough lists --template; gh-old: too old.
    if [ "$*" = "repo create --help" ]; then
      echo "Create a new GitHub repository."
      echo "  -d, --description string   Description of the repository"
      fails_left gh-old || echo "  -p, --template repository  Make the new repository based on a template repository"
    elif [ "${2:-}" = create ]; then
      # gh repo create OWNER/NAME --template ... : the project is made
      # (its name is added to the file "created" next to the log, so a
      # later api -i repos/OWNER/NAME finds it) and gh prints its link.
      # STUB_GH_CREATE_FAIL makes it fail (always, or while the counter
      # file create-fails is above 0) as: signed-out (gh's exit 4),
      # taken (GitHub's "name already exists"), refused (no permission),
      # broken (an error with no known cause), broken-but-made (the same,
      # after the project was made), killed (the script ends there with
      # no chance to run its traps, as Ctrl-C in Git Bash seemed to do in
      # end-to-end run 1, finding 6; nothing made) and killed-after-made
      # (the same, after the project was made).
      if [ "${STUB_GH_CREATE_FAIL:-}" = killed-after-made ]; then
        printf '%s\n' "$3" >>"${STUB_GH_LOG%/*}/created"
        [ -z "${STUB_GH_TEMPLATE:-}" ] || seed_project "$3"
        kill -KILL "$PPID"
        exit 1
      fi
      if [ -n "${STUB_GH_CREATE_FAIL:-}" ] && should_fail create-fails; then
        case "$STUB_GH_CREATE_FAIL" in
          killed) kill -KILL "$PPID" ;;
          signed-out) emit_failure signed-out ;;
          taken) echo "GraphQL: Name already exists on this account (cloneTemplateRepository)" >&2 ;;
          refused) echo "GraphQL: Resource not accessible by personal access token (cloneTemplateRepository)" >&2 ;;
          # rate-limit: GitHub's rate limit, in gh's words for an HTTP 403.
          rate-limit) echo "HTTP 403: API rate limit exceeded for user ID 1. (https://api.github.com/graphql)" >&2 ;;
          broken) echo "stub gh: the connection broke off" >&2 ;;
          broken-but-made)
            printf '%s\n' "$3" >>"${STUB_GH_LOG%/*}/created"
            echo "stub gh: the connection broke off" >&2
            ;;
          *) echo "stub gh: unknown failure mode: $STUB_GH_CREATE_FAIL" >&2; exit 64 ;;
        esac
        exit 1
      fi
      printf '%s\n' "$3" >>"${STUB_GH_LOG%/*}/created"
      # A private project is listed in the file "private" next to the log
      # (api -i repos/OWNER/NAME --jq .private reads it).
      [ "${6:-}" != --private ] || printf '%s\n' "$3" >>"${STUB_GH_LOG%/*}/private"
      # With STUB_GH_TEMPLATE set, the project also gets its files, so a
      # later repo clone can copy it (seed_project).
      [ -z "${STUB_GH_TEMPLATE:-}" ] || seed_project "$3"
      printf 'https://github.com/%s\n' "$3"
    elif [ "${2:-}" = clone ]; then
      # gh repo clone OWNER/NAME DIR: a real git clone of the bare repo
      # that repo create seeded; gh passes git's progress to stderr.
      # STUB_GH_CLONE_FAIL makes it fail (always, or while the counter
      # file clone-fails is above 0) as signed-out (gh's exit 4), broken
      # (git's text for a network failure, exit 128, nothing made) or
      # auth (git's text when it cannot sign in to GitHub and may not ask
      # at the terminal, exit 128, nothing made). The stub records
      # GIT_TERMINAL_PROMPT, as the clone got it, in clone-prompt.
      printf '%s\n' "${GIT_TERMINAL_PROMPT-<unset>}" >>"${STUB_GH_LOG%/*}/clone-prompt"
      if [ -n "${STUB_GH_CLONE_FAIL:-}" ] && should_fail clone-fails; then
        case "$STUB_GH_CLONE_FAIL" in
          signed-out) emit_failure signed-out ;;
          broken)
            printf "Cloning into '%s'...\nfatal: unable to access 'https://github.com/%s.git/': Could not resolve host: github.com\n" "$4" "$3" >&2
            exit 128
            ;;
          auth)
            printf "Cloning into '%s'...\nfatal: could not read Username for 'https://github.com': terminal prompts disabled\n" "$4" >&2
            exit 128
            ;;
          # auth-partial: the folder is made and has a file in it, then
          # git cannot sign in (a copy broken off part way, to be made
          # again after the sign-in guide).
          auth-partial)
            mkdir -p "$4"
            printf 'part\n' >"$4/partial-file"
            printf "Cloning into '%s'...\nfatal: could not read Username for 'https://github.com': terminal prompts disabled\n" "$4" >&2
            exit 128
            ;;
          # partial: the folder is made and has a file in it, then the
          # network fails (a copy broken off part way).
          partial)
            mkdir -p "$4"
            printf 'part\n' >"$4/partial-file"
            printf "Cloning into '%s'...\nfatal: the remote end hung up unexpectedly\n" "$4" >&2
            exit 128
            ;;
          *) echo "stub gh: unknown failure mode: $STUB_GH_CLONE_FAIL" >&2; exit 64 ;;
        esac
      fi
      bare="${STUB_GH_LOG%/*}/remotes/$3.git"
      if [ ! -d "$bare" ]; then
        echo "GraphQL: Could not resolve to a Repository with the name '$3'. (repository)" >&2
        exit 1
      fi
      exec "${STUB_GIT:-git}" clone "$bare" "$4"
    elif [ "${2:-}" = edit ] && [ "$*" = "repo edit ${3:-} --visibility public --accept-visibility-change-consequences" ]; then
      # gh repo edit OWNER/NAME --visibility public ...: the project is no
      # longer listed as private. STUB_GH_VISIBILITY_FAIL: gh's text for a
      # 403, nothing changes.
      if [ -n "${STUB_GH_VISIBILITY_FAIL:-}" ]; then
        echo "HTTP 403: Must have admin rights to Repository. (https://api.github.com/repos/$3)" >&2
        exit 1
      fi
      f="${STUB_GH_LOG%/*}/private"
      if [ -f "$f" ]; then grep -vxF -- "$3" "$f" >"$f.new" || true; mv "$f.new" "$f"; fi
      printf '%s\n' "$3" >>"${STUB_GH_LOG%/*}/made-public"
    elif [ "${2:-}" = edit ]; then
      # gh repo edit OWNER/NAME --delete-branch-on-merge --enable-squash-merge;
      # STUB_GH_EDIT_FAIL set: it fails with gh's text for a 403.
      if [ -n "${STUB_GH_EDIT_FAIL:-}" ]; then
        echo "HTTP 403: Must have admin rights to Repository. (https://api.github.com/repos/$3)" >&2
        exit 1
      fi
    else
      echo "stub gh: no emulation for: $*" >&2; exit 64
    fi
    ;;
  api)
    # gh api -i: the status line, the header lines (ending in \r\n, as gh
    # prints them), a blank line, then the body; on an HTTP error gh
    # prints the raw JSON body (no --jq), "gh: <message> (HTTP <n>)" on
    # stderr, and exits 1. Three calls are emulated:
    #   - the signed-in account (api -i user --jq ...): login, then
    #     profile name, one per line. STUB_GH_LOGIN and STUB_GH_NAME set
    #     them, STUB_GH_CR adds a carriage return to each body line (as
    #     on Windows). The X-OAuth-Scopes header is STUB_GH_SCOPES
    #     (default "repo, read:org, gist, workflow"; "-" sends no header,
    #     as for a fine-grained token). With STUB_GH_SCOPES_LATER set,
    #     that value is sent once the counter file scopes-old runs out.
    #   - the bootstrapper's CHANGELOG.md (raw contents): the file
    #     STUB_GH_CHANGELOG (the harness sets the template's own stub).
    #   - a project, api -i repos/OWNER/NAME: found (200) when OWNER/NAME
    #     is in STUB_GH_EXISTING (space-separated), else 404. With the
    #     counter file repo-there, only while it is above 0 (then the
    #     user deleted or renamed it).
    #     A project made by repo create (in the file "created") is found
    #     too.
    # STUB_GH_USER_FAIL, STUB_GH_CHANGELOG_FAIL and STUB_GH_REPO_FAIL make
    # those calls fail as <mode> (see emit_failure): always, or while the
    # counter file user-fails, changelog-fails or repo-fails is above 0.
    # With STUB_GH_REPO_FAIL_LATER set too, the project call fails as that
    # mode once repo-fails runs out.
    # After a project is made, three more calls are emulated:
    #   - api -i repos/OWNER/NAME/branches/main and .../contents/CHANGELOG.md:
    #     404 while the counter file main-missing (or changelog-missing) is
    #     above 0, as while GitHub is still copying the template; else 200.
    #     STUB_GH_BRANCH_FAIL and STUB_GH_FILES_FAIL fail them as <mode>.
    #   - api -i -X PUT repos/OWNER/NAME/branches/main/protection --input -:
    #     the body read from stdin is appended, with a line break, to the
    #     file protection-bodies next to the log; 200, or <mode> with
    #     STUB_GH_PROTECT_FAIL (plan, token, mystery, not-found, ...).
    #     STUB_GH_REQUIRE_FAIL fails only a body that requires build (the
    #     PUT of step 16).
    # And the licence text (step 10):
    #   - api -i licenses/<key> --jq .body: the file <key> in the folder
    #     STUB_GH_LICENSES (the harness writes mit and apache-2.0 from
    #     GitHub's texts), printed as gh prints a string picked by --jq:
    #     as is, plus a line break (so it ends in a blank line); with
    #     STUB_GH_CR each line ends in a carriage return. Any other key is
    #     GitHub's 404. STUB_GH_LICENSE_FAIL fails it as <mode>, or as
    #     empty: 200 with an empty text (gh prints just a line break).
    # And the two early stops:
    #   - the licence check of the preflight, api -i licenses/<key> --jq
    #     .key: 200 with the key when STUB_GH_LICENSES has a text for it
    #     or the key is in STUB_GH_LICENSE_KNOWN (space-separated: known
    #     at the check, but its text is gone at step 10), else GitHub's
    #     404. STUB_GH_LICENSE_CHECK_FAIL fails it as <mode>.
    #   - whether Actions is turned on, api -i
    #     repos/OWNER/NAME/actions/permissions --jq .enabled: 200 with
    #     true; false while the counter file actions-off is above 0 (then
    #     the user turned it on); STUB_GH_ACTIONS_ANSWER replaces the
    #     value printed (an answer of another shape);
    #     STUB_GH_ACTIONS_FAIL fails it as <mode>.
    # And the steps after the proposed change (15 to 17):
    #   - which actions GitHub Actions allows, api -i
    #     repos/OWNER/NAME/actions/permissions --jq .allowed_actions:
    #     STUB_GH_ALLOWED_ACTIONS (default all); STUB_GH_ALLOWED_FAIL
    #     fails it as <mode>.
    #   - the protection read back, api -i
    #     repos/OWNER/NAME/branches/main/protection --jq <the script's
    #     expression>: one "field=value" line per field, as that
    #     expression prints them for what the last PUT body set (so a
    #     wrong body shows as a difference). STUB_GH_READBACK replaces the
    #     lines (separated by ";"); STUB_GH_READBACK_FAIL fails it.
    #   - the proposed change, api -i repos/OWNER/NAME/pulls/N --jq
    #     <the script's expression>: "true <id>" once pr merge has added it
    #     (the id from merge-sha, or STUB_GH_MERGED_SHA), else "false"
    #     and an id (GitHub's test change, which is not in main).
    #     STUB_GH_PULL_FAIL fails it as <mode>.
    if [ "$*" = 'api -i user --jq .login, (.name // "")' ]; then
      if [ -n "${STUB_GH_USER_FAIL:-}" ] && should_fail user-fails; then emit_failure "$STUB_GH_USER_FAIL"; fi
      scopes="${STUB_GH_SCOPES-repo, read:org, gist, workflow}"
      if [ -n "${STUB_GH_SCOPES_LATER+x}" ] && ! fails_left scopes-old; then scopes="$STUB_GH_SCOPES_LATER"; fi
      if [ "$scopes" = - ]; then
        respond 200 OK 'application/json; charset=utf-8'
      else
        respond 200 OK 'application/json; charset=utf-8' "X-Oauth-Scopes: $scopes"
      fi
      printf '%s%s\n%s%s\n' "${STUB_GH_LOGIN:-octo-user}" "${STUB_GH_CR:-}" \
        "${STUB_GH_NAME-Octo User}" "${STUB_GH_CR:-}"
    elif [ "$*" = 'api -i -H Accept: application/vnd.github.raw+json repos/factoincognito/ai-project-bootstrap/contents/CHANGELOG.md' ]; then
      if [ -n "${STUB_GH_CHANGELOG_FAIL:-}" ] && should_fail changelog-fails; then emit_failure "$STUB_GH_CHANGELOG_FAIL"; fi
      : "${STUB_GH_CHANGELOG:?stub gh: STUB_GH_CHANGELOG is not set}"
      respond 200 OK 'application/vnd.github.raw'
      cat "$STUB_GH_CHANGELOG"
    elif [ "$#" -eq 5 ] && [ "$3 $4" = '-H Accept: application/vnd.github.raw+json' ] && [ "${5#repos/}" != "$5" ] && [ "${5#*/contents/}" != "$5" ]; then
      # --resume: the raw text of a file on a project's main (or on the
      # line of work named by ?ref=), read from its bare repo; 404 when it
      # lacks the file. STUB_GH_CONTENTS_FAIL fails it.
      if [ -n "${STUB_GH_CONTENTS_FAIL:-}" ]; then emit_failure "$STUB_GH_CONTENTS_FAIL"; fi
      rest="${5#repos/}"
      bare="${STUB_GH_LOG%/*}/remotes/${rest%%/contents/*}.git"
      p="${rest#*/contents/}"
      ref=main
      q='?ref='
      case "$p" in *"$q"*) ref="${p#*"$q"}"; p="${p%%"$q"*}" ;; esac
      # Not <rev>:<path>: Git Bash rewrites a <rev>:.github/... (#239).
      blob=""
      if [ -d "$bare" ]; then
        blob="$("${STUB_GIT:-git}" --git-dir="$bare" ls-tree "refs/heads/$ref" -- "$p" 2>/dev/null)" || blob=""
      fi
      blob="${blob%%"$(printf '\t')"*}"
      case "$blob" in
        *" blob "*)
          respond 200 OK 'application/vnd.github.raw'
          "${STUB_GIT:-git}" --git-dir="$bare" cat-file blob "${blob##* }"
          ;;
        *) http_error 404 'Not Found' 'Not Found' ;;
      esac
    elif [ "$#" -eq 5 ] && [ "$2" = -i ] && [ "${3#repos/}" != "$3" ] && [ "$4 $5" = "--jq .private" ]; then
      # --resume: whether the project is private: listed in the file
      # "private" (made with --private and not made public since) or in
      # STUB_GH_PRIVATE. STUB_GH_PRIVATE_FAIL fails it.
      if [ -n "${STUB_GH_PRIVATE_FAIL:-}" ]; then emit_failure "$STUB_GH_PRIVATE_FAIL"; fi
      respond 200 OK 'application/json; charset=utf-8'
      if grep -qxF -- "${3#repos/}" "${STUB_GH_LOG%/*}/private" 2>/dev/null; then
        echo true
      else
        case " ${STUB_GH_PRIVATE:-} " in *" ${3#repos/} "*) echo true ;; *) echo false ;; esac
      fi
    elif [ "$#" -eq 5 ] && [ "$2" = -i ] && [ "${3#repos/}" != "$3" ] && [ "${3#*/branches/}" != "$3" ] && [ "$4 $5" = "--jq .commit.sha" ]; then
      # --resume: the id of a line of work's last change on the bare repo;
      # 404 when it is not there. STUB_GH_SHA_FAIL fails it.
      if [ -n "${STUB_GH_SHA_FAIL:-}" ]; then emit_failure "$STUB_GH_SHA_FAIL"; fi
      rest="${3#repos/}"
      bare="${STUB_GH_LOG%/*}/remotes/${rest%%/branches/*}.git"
      sha="$("${STUB_GIT:-git}" --git-dir="$bare" rev-parse -q --verify "refs/heads/${rest#*/branches/}" 2>/dev/null)" || sha=""
      [ -n "$sha" ] || http_error 404 'Not Found' 'Branch not found'
      respond 200 OK 'application/json; charset=utf-8'
      printf '%s\n' "$sha"
    elif [ "$#" -eq 5 ] && [ "$2" = -i ] && is_pulls_list "$3" && [ "$4" = --jq ] && [ "$5" = '.[] | "\(.state) \(.merged_at // "-") \(.html_url)"' ]; then
      # --resume: the proposed changes from bootstrap-setup, newest first,
      # from the file "pulls" (pr create adds "<n> open", pr merge makes it
      # "<n> merged"): "open - <link>" or "closed <time> <link>".
      # STUB_GH_PULLS_FAIL fails it.
      if [ -n "${STUB_GH_PULLS_FAIL:-}" ]; then emit_failure "$STUB_GH_PULLS_FAIL"; fi
      respond 200 OK 'application/json; charset=utf-8'
      on="${3#repos/}"
      on="${on%%/pulls*}"
      [ ! -f "${STUB_GH_LOG%/*}/pulls" ] || awk -v on="$on" '{ l[NR] = $0 } END {
          for (i = NR; i > 0; i--) {
            split(l[i], f, " ")
            if (f[2] == "open") print "open - https://github.com/" on "/pull/" f[1]
            else print "closed 2031-02-03T10:00:00Z https://github.com/" on "/pull/" f[1]
          }
        }' "${STUB_GH_LOG%/*}/pulls"
    elif [ "$#" -eq 3 ] && [ "$2" = -i ] && [ "${3%/branches/main}" != "$3" ]; then
      if [ -n "${STUB_GH_BRANCH_FAIL:-}" ] && should_fail branch-fails; then emit_failure "$STUB_GH_BRANCH_FAIL"; fi
      if fails_left main-missing; then http_error 404 'Not Found' 'Branch not found'; fi
      respond 200 OK 'application/json; charset=utf-8'
      printf '{"name":"main","protected":false}\n'
    elif [ "$#" -eq 3 ] && [ "$2" = -i ] && [ "${3%/contents/CHANGELOG.md}" != "$3" ]; then
      if [ -n "${STUB_GH_FILES_FAIL:-}" ] && should_fail files-fail; then emit_failure "$STUB_GH_FILES_FAIL"; fi
      if fails_left changelog-missing; then http_error 404 'Not Found' 'Not Found'; fi
      respond 200 OK 'application/json; charset=utf-8'
      printf '{"name":"CHANGELOG.md","path":"CHANGELOG.md"}\n'
    elif [ "$#" -eq 7 ] && [ "$3 $4 $6 $7" = "-X PUT --input -" ] && [ "${5%/branches/main/protection}" != "$5" ]; then
      cat >>"${STUB_GH_LOG%/*}/protection-bodies"
      printf '\n' >>"${STUB_GH_LOG%/*}/protection-bodies"
      if [ -n "${STUB_GH_PROTECT_FAIL:-}" ]; then emit_failure "$STUB_GH_PROTECT_FAIL"; fi
      if [ -n "${STUB_GH_REQUIRE_FAIL:-}" ] && grep . "${STUB_GH_LOG%/*}/protection-bodies" | tail -1 | grep -F '"contexts":["build"]' >/dev/null; then
        emit_failure "$STUB_GH_REQUIRE_FAIL"
      fi
      # A body GitHub took: the read-back reports the last one.
      grep . "${STUB_GH_LOG%/*}/protection-bodies" | tail -1 >>"${STUB_GH_LOG%/*}/protected"
      respond 200 OK 'application/json; charset=utf-8'
      printf '{"url":"https://api.github.com/%s"}\n' "$5"
    elif [ "$#" -eq 5 ] && [ "$2" = -i ] && [ "${3%/actions/permissions}" != "$3" ] && [ "$4 $5" = "--jq .enabled" ]; then
      if [ -n "${STUB_GH_ACTIONS_FAIL:-}" ]; then emit_failure "$STUB_GH_ACTIONS_FAIL"; fi
      respond 200 OK 'application/json; charset=utf-8'
      if fails_left actions-off; then
        printf 'false\n'
      else
        printf '%s\n' "${STUB_GH_ACTIONS_ANSWER-true}"
      fi
    elif [ "$#" -eq 5 ] && [ "$2" = -i ] && [ "${3#licenses/}" != "$3" ] && [ "$4 $5" = "--jq .key" ]; then
      if [ -n "${STUB_GH_LICENSE_CHECK_FAIL:-}" ]; then emit_failure "$STUB_GH_LICENSE_CHECK_FAIL"; fi
      : "${STUB_GH_LICENSES:?stub gh: STUB_GH_LICENSES is not set}"
      case " ${STUB_GH_LICENSE_KNOWN:-} " in
        *" ${3#licenses/} "*) ;;
        *) [ -f "$STUB_GH_LICENSES/${3#licenses/}" ] || emit_failure not-found ;;
      esac
      respond 200 OK 'application/json; charset=utf-8'
      printf '%s\n' "${3#licenses/}"
    elif [ "$#" -eq 3 ] && [ "$2" = -i ] && [ "${3#repos/}" != "$3" ]; then
      if [ -n "${STUB_GH_REPO_FAIL:-}" ] && should_fail repo-fails; then emit_failure "$STUB_GH_REPO_FAIL"; fi
      if [ -n "${STUB_GH_REPO_FAIL:-}" ] && [ -n "${STUB_GH_REPO_FAIL_LATER:-}" ]; then emit_failure "$STUB_GH_REPO_FAIL_LATER"; fi
      if [ -f "${STUB_GH_LOG%/*}/created" ] && grep -qxF -- "${3#repos/}" "${STUB_GH_LOG%/*}/created"; then
        respond 200 OK 'application/json; charset=utf-8'
        printf '{"full_name":"%s","private":false}\n' "${3#repos/}"
        exit 0
      fi
      case " ${STUB_GH_EXISTING:-} " in
        *" ${3#repos/} "*)
          if [ ! -f "${STUB_GH_LOG%/*}/repo-there" ] || fails_left repo-there; then
            respond 200 OK 'application/json; charset=utf-8'
            printf '{"full_name":"%s","private":false}\n' "${3#repos/}"
            exit 0
          fi
          ;;
      esac
      emit_failure not-found
    elif [ "$#" -eq 5 ] && [ "$2" = -i ] && [ "${3%/branches/main/protection}" != "$3" ] && [ "$4" = --jq ] \
      && [ "$5" = '"contexts=\(.required_status_checks.contexts // [] | join(","))", "strict=\(.required_status_checks.strict)", "enforce_admins=\(.enforce_admins.enabled)", "approvals=\(.required_pull_request_reviews.required_approving_review_count)", "restrictions=\(.restrictions)", "allow_force_pushes=\(.allow_force_pushes.enabled)", "allow_deletions=\(.allow_deletions.enabled)"' ]; then
      if [ -n "${STUB_GH_READBACK_FAIL:-}" ]; then emit_failure "$STUB_GH_READBACK_FAIL"; fi
      if [ -n "${STUB_GH_READBACK:-}" ]; then
        respond 200 OK 'application/json; charset=utf-8'
        printf '%s\n' "$STUB_GH_READBACK" | tr ';' '\n'
        exit 0
      fi
      # main never protected: GitHub's 404 (and no 200 before it).
      [ -s "${STUB_GH_LOG%/*}/protected" ] || http_error 404 'Not Found' 'Branch not protected'
      respond 200 OK 'application/json; charset=utf-8'
      last="$(tail -1 "${STUB_GH_LOG%/*}/protected")"
      field() { case "$last" in *"$2"*) printf '%s=%s\n' "$1" "$3" ;; *) printf '%s=%s\n' "$1" "$4" ;; esac; }
      field contexts '"contexts":["build"]' build ""
      case "$last" in *'"strict":false'*) echo strict=false ;; *'"strict":true'*) echo strict=true ;; *) echo strict=null ;; esac
      field enforce_admins '"enforce_admins":true' true false
      field approvals '"required_approving_review_count":0' 0 null
      field restrictions '"restrictions":null' null '{}'
      field allow_force_pushes '"allow_force_pushes":false' false true
      field allow_deletions '"allow_deletions":false' false true
    elif [ "$#" -eq 5 ] && [ "$2" = -i ] && [ "${3%/pulls/[0-9]*}" != "$3" ] && [ "$4 $5" = '--jq "\(.merged) \(.merge_commit_sha)"' ]; then
      if [ -n "${STUB_GH_PULL_FAIL:-}" ]; then emit_failure "$STUB_GH_PULL_FAIL"; fi
      respond 200 OK 'application/json; charset=utf-8'
      if [ -f "${STUB_GH_LOG%/*}/merge-sha" ]; then
        printf 'true %s\n' "${STUB_GH_MERGED_SHA:-$(cat "${STUB_GH_LOG%/*}/merge-sha")}"
      else
        printf 'false 1111111111111111111111111111111111111111\n'
      fi
    elif [ "$#" -eq 5 ] && [ "$2" = -i ] && [ "${3%/actions/permissions}" != "$3" ] && [ "$4 $5" = "--jq .allowed_actions" ]; then
      if [ -n "${STUB_GH_ALLOWED_FAIL:-}" ]; then emit_failure "$STUB_GH_ALLOWED_FAIL"; fi
      respond 200 OK 'application/json; charset=utf-8'
      printf '%s\n' "${STUB_GH_ALLOWED_ACTIONS:-all}"
    elif [ "$#" -eq 5 ] && [ "$2" = -i ] && [ "${3#licenses/}" != "$3" ] && [ "$4 $5" = "--jq .body" ]; then
      if [ "${STUB_GH_LICENSE_FAIL:-}" = empty ]; then
        respond 200 OK 'application/json; charset=utf-8'
        printf '\n'
        exit 0
      fi
      if [ -n "${STUB_GH_LICENSE_FAIL:-}" ]; then emit_failure "$STUB_GH_LICENSE_FAIL"; fi
      : "${STUB_GH_LICENSES:?stub gh: STUB_GH_LICENSES is not set}"
      [ -f "$STUB_GH_LICENSES/${3#licenses/}" ] || emit_failure not-found
      respond 200 OK 'application/json; charset=utf-8'
      { cat "$STUB_GH_LICENSES/${3#licenses/}"; printf '\n'; } | while IFS= read -r line || [ -n "$line" ]; do
        printf '%s%s\n' "$line" "${STUB_GH_CR:-}"
      done
    else
      echo "stub gh: no emulation for: $*" >&2; exit 64
    fi
    ;;
  pr)
    # gh pr create --repo OWNER/NAME --base main --head BRANCH --title
    # TITLE --body-file FILE: GitHub opens the proposed change when BRANCH
    # is on the bare repo of OWNER/NAME (sent there by git push); the body
    # file is appended to the file pr-bodies next to the log, then a line
    # "-----", and gh prints the change's link (number 1, 2, ...).
    # STUB_GH_PR_FAIL makes it fail as signed-out (gh's exit 4), exists
    # (gh's text when the branch has one already), broken (an error with
    # no known cause) or no-link (exit 0 with nothing printed).
    #
    # gh pr checks N --repo OWNER/NAME --json name,bucket,event --jq
    # <the script's expression>: what --jq prints for the checks named
    # build, "<event> <bucket>" per line (gh prints a string as is). The
    # lines are STUB_GH_BUILD, separated by ";" (default: a push run and a
    # pull_request run, both passed; empty: no build reported, only other
    # checks). While the counter file build-pending is above 0 both runs
    # are pending, and gh exits 8 (its code for pending checks); while
    # checks-none is above 0, no check has reported at all (gh's text,
    # exit 1). STUB_GH_CHECKS_FAIL fails it as signed-out or broken.
    #
    # gh pr merge N --squash --delete-branch --match-head-commit SHA, run
    # in the copy: gh finds the project from the copy's origin (the bare
    # repo). The head of bootstrap-setup there is written to merged-head
    # and the folder gh ran in to merge-cwd (GIT_TERMINAL_PROMPT, as gh
    # got it, to merge-prompt). When SHA is that head, the
    # change is squashed onto main as one new change (its id in
    # merge-sha) and bootstrap-setup is deleted there; then, as gh does in
    # a copy on that line of work, the copy is switched to main, brought
    # up to date and its bootstrap-setup deleted (not with
    # STUB_GH_MERGE_LOCAL=no). Another SHA: GitHub's refusal, nothing
    # changes. STUB_GH_MERGE_FAIL: signed-out, refused (GitHub's text when
    # the protection does not allow it; nothing changes), or
    # broken-but-merged (added, then gh fails as if the connection broke).
    #
    # The feature checks of the preflight: pr checks --help lists --json
    # and pr merge --help lists --match-head-commit, unless the counter
    # file gh-old-pr-checks (or gh-old-pr-merge) is above 0: a gh too old
    # for that one option.
    if [ "$*" = "pr checks --help" ]; then
      echo "Show CI status for a single pull request."
      fails_left gh-old-pr-checks || echo "      --json fields   Output JSON with the specified fields"
      exit 0
    fi
    if [ "$*" = "pr merge --help" ]; then
      echo "Merge a pull request on GitHub."
      fails_left gh-old-pr-merge || echo "      --match-head-commit SHA   Commit SHA that the pull request head must match to allow merge"
      exit 0
    fi
    if [ "${2:-}" = checks ]; then
      if [ "$#" -ne 9 ] || [ "$4 $6 $7 $8" != "--repo --json name,bucket,event --jq" ] \
        || [ "$9" != '.[] | select(.name == "build") | "\(.event) \(.bucket)"' ]; then
        echo "stub gh: no emulation for: $*" >&2; exit 64
      fi
      case "${STUB_GH_CHECKS_FAIL:-}" in
        "") ;;
        signed-out) emit_failure signed-out ;;
        broken) echo "stub gh: the connection broke off" >&2; exit 1 ;;
        *) echo "stub gh: unknown failure mode: $STUB_GH_CHECKS_FAIL" >&2; exit 64 ;;
      esac
      if fails_left checks-none; then echo "no checks reported on the 'bootstrap-setup' branch" >&2; exit 1; fi
      if fails_left build-pending; then printf '%s\n' 'push pending' 'pull_request pending'; exit 8; fi
      # build-mixed: a new pull_request run still pending listed before an
      # old one that failed (as after a re-run); the pending one decides.
      if fails_left build-mixed; then printf '%s\n' 'pull_request pending' 'pull_request fail'; exit 8; fi
      printf '%s\n' "${STUB_GH_BUILD-push pass;pull_request pass}" | tr ';' '\n'
      exit 0
    fi
    if [ "${2:-}" = merge ]; then
      if [ "$#" -ne 7 ] || [ "$4 $5 $6" != "--squash --delete-branch --match-head-commit" ]; then
        echo "stub gh: no emulation for: $*" >&2; exit 64
      fi
      g="${STUB_GIT:-git}"
      printf '%s\n' "$PWD" >>"${STUB_GH_LOG%/*}/merge-cwd"
      printf '%s\n' "${GIT_TERMINAL_PROMPT-<unset>}" >>"${STUB_GH_LOG%/*}/merge-prompt"
      bare="$("$g" remote get-url origin)"
      head="$("$g" --git-dir="$bare" rev-parse -q --verify refs/heads/bootstrap-setup)" \
        || { echo "GraphQL: Could not resolve to a PullRequest with the number of $3. (repository.pullRequest)" >&2; exit 1; }
      printf '%s\n' "$head" >"${STUB_GH_LOG%/*}/merged-head"
      case "${STUB_GH_MERGE_FAIL:-}" in
        "" | broken-but-merged) ;;
        signed-out) emit_failure signed-out ;;
        refused) echo "GraphQL: Required status check \"build\" is expected. (mergePullRequest)" >&2; exit 1 ;;
        *) echo "stub gh: unknown failure mode: $STUB_GH_MERGE_FAIL" >&2; exit 64 ;;
      esac
      if [ "$7" != "$head" ]; then
        echo "GraphQL: Head branch was modified. Review and try the merge again. (mergePullRequest)" >&2
        exit 1
      fi
      tree="$("$g" --git-dir="$bare" rev-parse "$head^{tree}")"
      # GitHub's squash change keeps the author of the proposed change.
      an="$("$g" --git-dir="$bare" log -1 --format=%an "$head")"
      ae="$("$g" --git-dir="$bare" log -1 --format=%ae "$head")"
      new="$(GIT_AUTHOR_NAME="$an" GIT_AUTHOR_EMAIL="$ae" GIT_COMMITTER_NAME=GitHub GIT_COMMITTER_EMAIL=noreply@github.com \
        "$g" --git-dir="$bare" commit-tree "$tree" -p refs/heads/main -m "Set up my-app (#$3)")"
      "$g" --git-dir="$bare" update-ref refs/heads/main "$new"
      "$g" --git-dir="$bare" update-ref -d refs/heads/bootstrap-setup
      printf '%s\n' "$new" >"${STUB_GH_LOG%/*}/merge-sha"
      if [ -f "${STUB_GH_LOG%/*}/pulls" ]; then
        awk -v n="$3" '$1 == n && $2 == "open" { $2 = "merged" } { print }' "${STUB_GH_LOG%/*}/pulls" >"${STUB_GH_LOG%/*}/pulls.new"
        mv "${STUB_GH_LOG%/*}/pulls.new" "${STUB_GH_LOG%/*}/pulls"
      fi
      if [ "${STUB_GH_MERGE_FAIL:-}" = broken-but-merged ]; then echo "stub gh: the connection broke off" >&2; exit 1; fi
      echo "Squashed and merged pull request #$3 (Set up my-app)" >&2
      if [ "${STUB_GH_MERGE_LOCAL:-yes}" = yes ]; then
        "$g" checkout -q main
        "$g" pull -q --ff-only
        "$g" branch -q -D bootstrap-setup
        echo "Deleted local branch bootstrap-setup and switched to branch main" >&2
      fi
      exit 0
    fi
    if [ "${2:-}" != create ] || [ "$#" -ne 12 ] || [ "$3 $5 $7 $9 ${11}" != "--repo --base --head --title --body-file" ]; then
      echo "stub gh: no emulation for: $*" >&2; exit 64
    fi
    case "${STUB_GH_PR_FAIL:-}" in
      "") ;;
      signed-out) emit_failure signed-out ;;
      exists)
        printf 'a pull request for branch "%s" into branch "%s" already exists:\nhttps://github.com/%s/pull/1\n' "$8" "$6" "$4" >&2
        exit 1
        ;;
      broken) echo "stub gh: the connection broke off" >&2; exit 1 ;;
      no-link) exit 0 ;;
      *) echo "stub gh: unknown failure mode: $STUB_GH_PR_FAIL" >&2; exit 64 ;;
    esac
    bare="${STUB_GH_LOG%/*}/remotes/$4.git"
    if ! "${STUB_GIT:-git}" --git-dir="$bare" rev-parse -q --verify "refs/heads/$8" >/dev/null 2>&1; then
      echo "pull request create failed: GraphQL: Head sha can't be blank, Base sha can't be blank, No commits between $6 and $8, Head ref must be a branch (createPullRequest)" >&2
      exit 1
    fi
    { cat "${12}"; printf '%s\n' -----; } >>"${STUB_GH_LOG%/*}/pr-bodies"
    n="$(grep -cx -- ----- "${STUB_GH_LOG%/*}/pr-bodies")"
    printf '%s open\n' "$n" >>"${STUB_GH_LOG%/*}/pulls"
    printf 'https://github.com/%s/pull/%s\n' "$4" "$n"
    ;;
  auth)
    # gh auth git-credential get: what git asks a credential helper. It
    # reads git's lines up to a blank one and answers with a user name and
    # password (stand-ins, not a real key).
    if [ "$*" != "auth git-credential get" ]; then echo "stub gh: no emulation for: $*" >&2; exit 64; fi
    while IFS= read -r line && [ -n "$line" ]; do :; done
    printf '%s\n' protocol=https host=github.com username=stub-user password=stub-password
    ;;
  *) echo "stub gh: no emulation for: $*" >&2; exit 64 ;;
esac
STUB
make_stub_gh() { write_stand_in "$1" "$STUB_GH_TEXT"; }

# ---------- stub runner ----------
# A stand-in for the runner of offered commands (installs, logins),
# selected with BOOTSTRAP_RUN. It runs nothing: it appends the command
# string it was given to $STUB_RUN_LOG and exits with $STUB_RUN_RC
# (default 0).

IFS= read -r -d '' STUB_RUN_TEXT <<'STUB' || true
set -euo pipefail
: "${STUB_RUN_LOG:?stub runner: STUB_RUN_LOG is not set}"
printf '%s\n' "$*" >>"$STUB_RUN_LOG"
exit "${STUB_RUN_RC:-0}"
STUB
make_stub_run() { write_stand_in "$1" "$STUB_RUN_TEXT"; }

# ---------- stub npm ----------
# A stand-in for npm, selected with BOOTSTRAP_NPM, so CI never reaches
# the npm registry. Every call appends one line to $STUB_NPM_LOG: the
# folder it ran in, then each argument, tab-separated. It emulates only
# the lockfile command, `install --package-lock-only --no-audit --no-fund`,
# as npm 10.9 does it (seen in a real run on the node pack): it writes
# package-lock.json (lockfileVersion 3, its name and version read from
# package.json at that moment, two spaces of indent, LF, a newline at the
# end), changes nothing else, prints "up to date in <time>" after a blank
# line on stdout and exits 0. STUB_NPM_FAIL makes it fail as npm 10 does:
# offline (no network: npm's ENOTFOUND text) or notarget (a version the
# registry lacks: ETARGET), on stderr, exit 1, writing nothing. Any other
# call fails loudly (exit 64).
# It reads one line of its stdin when stdin is open and not a terminal,
# and writes what it got to the file npm-stdin next to its log, so a test
# sees whether the script handed npm its own stdin (#154 review, finding
# 3: real npm does not prompt here, but a stub that never reads cannot
# show that the script keeps npm away from the answers on stdin).
# STUB_NPM_CRLF set: the lockfile has Windows line endings (CR LF), as a
# tool on Windows might write it; STUB_NPM_CRLF=lone: its lines end in a
# carriage return alone (as on old Macs), which git does not change. STUB_NPM_STRAY=<name>: npm also leaves
# a file of that name in the folder it ran in. STUB_NPM_TOUCH=<path>: npm
# also adds a line to that file of the folder; STUB_NPM_DELETE=<path>:
# npm also deletes it (#155 review, finding 1: a changed or deleted file
# the setup does not change).

IFS= read -r -d '' STUB_NPM_TEXT <<'STUB' || true
set -euo pipefail
: "${STUB_NPM_LOG:?stub npm: STUB_NPM_LOG is not set}"
{
  printf '%s' "$PWD"
  for a in "$@"; do printf '\t%s' "$a"; done
  printf '\n'
} >>"$STUB_NPM_LOG"
if [ ! -t 0 ] && IFS= read -r line 2>/dev/null; then
  printf '%s\n' "$line" >>"${STUB_NPM_LOG%/*}/npm-stdin"
fi
if [ "$*" != "install --package-lock-only --no-audit --no-fund" ]; then
  echo "stub npm: no emulation for: $*" >&2; exit 64
fi
case "${STUB_NPM_FAIL:-}" in
  "") ;;
  offline)
    printf '%s\n' 'npm error code ENOTFOUND' 'npm error syscall getaddrinfo' 'npm error errno ENOTFOUND' \
      'npm error network request to https://registry.npmjs.org/@biomejs%2fbiome failed, reason: getaddrinfo ENOTFOUND registry.npmjs.org' \
      'npm error network This is a problem related to network connectivity.' \
      'npm error network In most cases you are behind a proxy or have bad network settings.' \
      "npm error A complete log of this run can be found in: $HOME/.npm/_logs/2031-02-03T10_00_00_000Z-debug-0.log" >&2
    exit 1
    ;;
  notarget)
    printf '%s\n' 'npm error code ETARGET' 'npm error notarget No matching version found for jest@30.5.2.' \
      'npm error notarget In most cases you or one of your dependencies are requesting' \
      "npm error notarget a package version that doesn't exist." >&2
    exit 1
    ;;
  *) echo "stub npm: unknown failure mode: $STUB_NPM_FAIL" >&2; exit 64 ;;
esac
[ -f package.json ] || { echo 'npm error code ENOENT' >&2; exit 254; }
name="$(grep -m1 '^  "name": ' package.json | sed 's/^  "name": "\(.*\)",$/\1/')"
version="$(grep -m1 '^  "version": ' package.json | sed 's/^  "version": "\(.*\)",$/\1/')"
printf '%s\n' '{' "  \"name\": \"$name\"," "  \"version\": \"$version\"," '  "lockfileVersion": 3,' \
  '  "requires": true,' '  "packages": {' '    "": {' "      \"name\": \"$name\"," \
  "      \"version\": \"$version\"" '    }' '  }' '}' >package-lock.json
if [ "${STUB_NPM_CRLF:-}" = lone ]; then
  awk '{ printf "%s\r", $0 }' package-lock.json >package-lock.json.tmp
  mv package-lock.json.tmp package-lock.json
elif [ -n "${STUB_NPM_CRLF:-}" ]; then
  awk '{ printf "%s\r\n", $0 }' package-lock.json >package-lock.json.tmp
  mv package-lock.json.tmp package-lock.json
fi
[ -z "${STUB_NPM_STRAY:-}" ] || printf 'stray\n' >"$STUB_NPM_STRAY"
[ -z "${STUB_NPM_TOUCH:-}" ] || printf 'touched\n' >>"$STUB_NPM_TOUCH"
[ -z "${STUB_NPM_DELETE:-}" ] || rm "$STUB_NPM_DELETE"
printf '\nup to date in 2s\n'
STUB
make_stub_npm() { write_stand_in "$1" "$STUB_NPM_TEXT"; }

# ---------- safe defaults for the hooks ----------
# Every test runs with the hooks pointing at stubs that refuse: they log
# the call to $REFUSE_LOG, say which hook to set, and exit 70. So a test
# that forgets to set a hook runs no real install, login or gh, and
# fails. A test that needs the real default unsets the hook itself.

make_refuser() {
  local path="$1" hook="$2" text
  IFS= read -r -d '' text <<STUB || true
printf '%s\\n' "$hook \$*" >>"\${REFUSE_LOG:-$WORK/refused.log}"
echo "test harness: refused to run '\$*' for real; this test must set $hook" >&2
exit 70
STUB
  write_stand_in "$path" "$text"
}
mkdir -p "$WORK/refuse"
make_refuser "$WORK/refuse/run" BOOTSTRAP_RUN
make_refuser "$WORK/refuse/gh" BOOTSTRAP_GH
make_refuser "$WORK/refuse/npm" BOOTSTRAP_NPM
export BOOTSTRAP_RUN="$WORK/refuse/run" BOOTSTRAP_GH="$WORK/refuse/gh" BOOTSTRAP_NPM="$WORK/refuse/npm"
# The pause between two checks of GitHub (BOOTSTRAP_SLEEP): a stand-in
# that waits for nothing, so no test waits for real. It appends the
# seconds it was asked to wait to $STUB_SLEEP_LOG (default $WORK/sleep.log).
IFS= read -r -d '' STUB_SLEEP_TEXT <<STUB || true
printf '%s\n' "\$*" >>"\${STUB_SLEEP_LOG:-$WORK/sleep.log}"
STUB
write_stand_in "$WORK/refuse/sleep" "$STUB_SLEEP_TEXT"
export BOOTSTRAP_SLEEP="$WORK/refuse/sleep"
# The terminal an offered command's yes is read from: a file that does not
# exist, so no test ever waits on the real terminal and no yes is given
# unless a test writes one.
export BOOTSTRAP_TTY="$WORK/no-terminal"
# Colour (finding 8): off in every test unless a test turns it on with
# the hook, whatever the shell that starts the harness has set.
unset BOOTSTRAP_COLOR
# The bootstrapper's CHANGELOG.md as the stub gh serves it: the template's
# own, unstamped stub, so the unstamped script under test finds its own
# version there. Tests that need another version serve a stamped copy.
export STUB_GH_CHANGELOG="$REPO/bootstrap/stubs/CHANGELOG.md"
# The licence texts the stub gh serves (licenses/<key>), as GitHub has
# them: MIT with choosealicense.com's [year] and [fullname], and the
# start and the appendix of Apache 2.0, whose placeholders are others
# ([yyyy], [name of copyright owner]) and stay as they are.
export STUB_GH_LICENSES="$WORK/licence-texts"
mkdir -p "$STUB_GH_LICENSES"
cat >"$STUB_GH_LICENSES/mit" <<'TEXT'
MIT License

Copyright (c) [year] [fullname]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
TEXT
cat >"$STUB_GH_LICENSES/apache-2.0" <<'TEXT'
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

   Copyright [yyyy] [name of copyright owner]

   Licensed under the Apache License, Version 2.0 (the "License");
TEXT
# A token in the environment changes the permission guide; the tests set
# one themselves when they need it.
unset GH_TOKEN GITHUB_TOKEN
# Whether git may ask at the terminal: the script sets it itself, and the
# tests check that it does, so none comes from the environment the tests
# run in.
unset GIT_TERMINAL_PROMPT GIT_ASKPASS

# ---------- fake tools and a fake home ----------
# git is real (its path is kept here); a test that needs git, npm, uname,
# brew or winget to behave otherwise puts a fake one first on PATH.

REAL_GIT="$(command -v git)"
# A run's cut-down PATH (in_env) has GIT_ONLY_DIR after the fakes, a folder that
# holds only git and the helpers it starts to copy from and send to a
# project in a folder (git-upload-pack, git-receive-pack), each a
# wrapper that runs the real one. git's own folder is not put on that
# PATH: Git for Windows keeps git in /mingw64/bin with many other tools,
# and Homebrew's /opt/homebrew/bin holds brew and gh, which a test
# without them must not find. Wrappers, not links: a link made by Git
# for Windows' ln may be a copy, and a copied git.exe cannot find the
# rest of git.

# make_git_only_dir <git's folder> <new folder>
make_git_only_dir() {
  local t
  mkdir -p "$2"
  for t in git git-upload-pack git-receive-pack; do
    [ -x "$1/$t" ] || [ -x "$1/$t.exe" ] || continue
    printf '%s\n' '#!/bin/sh' "exec '$1/$t' \"\$@\"" >"$2/$t"
    chmod +x "$2/$t"
  done
}
GIT_ONLY_DIR="$WORK/git only"
make_git_only_dir "$(dirname "$REAL_GIT")" "$GIT_ONLY_DIR"
REAL_DATE="$(command -v date)"
# The stub gh seeds and copies projects with the real git.
export STUB_GIT="$REAL_GIT"

# GIT_BASH_ARGS: stand-in text that rewrites "$@" the way Git Bash does
# before it starts a native program such as git.exe: an argument whose
# first : has a / before it and a . or a / (not //) right after it, but
# not ./ or ../, is taken as a list of paths (git-for-windows/msys2-runtime,
# winsup/cygwin/msys2_path_conv.cc, find_path_start_and_type). Its : become
# ;, which is enough to break a <rev>:<path> the way Windows does (r1e,
# #239). Arguments that start with -, /, ~ or :, or that hold a space, a
# quote, a glob character, =, ::, /~ or @@, are left alone: Git Bash skips
# most of these, and the rest are not simulated.
IFS= read -r -d '' GIT_BASH_ARGS <<'EOF' || true
n=$#
while [ "$n" -gt 0 ]; do
  a="$1"
  shift
  n=$((n - 1))
  case "$a" in
    *[[:space:]\'\"\`*?=]* | *\[* | *\]* | *::* | */~* | *@@*) ;;
    [!/:~-]*:*)
      case "${a%%:*}" in
        */*)
          case "${a#*:}" in
            ./* | ../* | //*) ;;
            [./]*) a="${a//:/;}" ;;
          esac
          ;;
      esac
      ;;
  esac
  set -- "$@" "$a"
done
EOF

# git_bash_git <dir>: makes <dir>/git-bash-git, a git that gets its
# arguments as from Git Bash (GIT_BASH_ARGS), for STUB_GIT.
git_bash_git() {
  write_stand_in "$1/git-bash-git" "$GIT_BASH_ARGS
exec \"$REAL_GIT\" \"\$@\"
"
}

# fake_tool <dir> <name> [output]: makes <dir>/bin/<name>. Each call is
# logged to <dir>/tools.log. While <dir>/<name>-fails holds a number above
# 0 it counts it down and fails as a missing command does (exit 127): a
# test writes 1 there for "missing, then installed by the user". Otherwise
# a fake git runs the real git, and any other fake prints [output].
# With <dir>/git-bash-paths present, a fake git first rewrites its
# arguments as Git Bash does (GIT_BASH_ARGS).
fake_tool() {
  local d="$1" name="$2" out="${3:-}" text
  IFS= read -r -d '' text <<EOF || true
printf '%s\n' "$name \$*" >>"$d/tools.log"
f="$d/$name-fails"
if [ -f "\$f" ]; then
  read -r n <"\$f" || true
  if [ "\$n" -gt 0 ]; then echo \$((n - 1)) >"\$f"; echo "$name: command not found" >&2; exit 127; fi
fi
if [ "$name" = git ]; then
  [ ! -x "$d/push-hook" ] || "$d/push-hook" "\$@" || exit \$?
  if [ -f "$d/git-bash-paths" ]; then
$GIT_BASH_ARGS
  fi
  exec "$REAL_GIT" "\$@"
fi
printf '%s\n' "$out"
EOF
  write_stand_in "$d/bin/$name" "$text"
}

# failing_push <dir> <mode> [times]: the fake git of <dir> fails each git
# push (any call with the word push) that many times (default: always),
# with git's text for <mode>, then pushes for real:
#   auth      git cannot sign in to GitHub and may not ask at the terminal
#   offline   GitHub cannot be reached
#   workflow  GitHub refuses a change to a workflow file without the
#             workflow permission
#   other     an error the script has no explanation for
# Every push, failing or not, records GIT_TERMINAL_PROMPT, as it got it,
# in <dir>/push-prompt (#155 review, finding 2: the retry that works is
# pinned too). failing_push <dir> ok 0 records without ever failing.
failing_push() {
  printf '%s\n' "$2" >"$1/push-mode"
  printf '%s\n' "${3:-9999}" >"$1/push-fails"
  write_stand_in "$1/push-hook" "$PUSH_HOOK_TEXT"
}
IFS= read -r -d '' PUSH_HOOK_TEXT <<'HOOK' || true
case "$0" in */*) here="${0%/*}" ;; *) here=. ;; esac
case " $* " in *" push "*) ;; *) exit 0 ;; esac
printf '%s\n' "${GIT_TERMINAL_PROMPT-<unset>}" >>"$here/push-prompt"
read -r n <"$here/push-fails" || true
[ "$n" -gt 0 ] || exit 0
echo $((n - 1)) >"$here/push-fails"
read -r mode <"$here/push-mode" || true
case "$mode" in
  auth) echo "fatal: could not read Username for 'https://github.com': terminal prompts disabled" >&2 ;;
  offline) echo "fatal: unable to access 'https://github.com/octo-user/my-app.git/': Could not resolve host: github.com" >&2 ;;
  workflow)
    printf '%s\n' 'To https://github.com/octo-user/my-app.git' \
      ' ! [remote rejected] bootstrap-setup -> bootstrap-setup (refusing to allow an OAuth App to create or update workflow `.github/workflows/ci.yml` without `workflow` scope)' \
      "error: failed to push some refs to 'https://github.com/octo-user/my-app.git'" >&2
    exit 1
    ;;
  *) echo "error: the stub push broke off" >&2 ;;
esac
exit 128
HOOK

# fake_home <dir> [git name] [git email]: a home folder whose global git
# settings hold only the name and email given.
# A name and an email of plain characters are written as git config
# --file writes them, with no git started; any other value goes through
# git config, which quotes it.
fake_home() {
  [ -d "$1" ] || mkdir -p "$1"
  : >"$1/.gitconfig"
  if plain_config_value "${2:-}" && plain_config_value "${3:-}"; then
    if [ -n "${2:-}" ] || [ -n "${3:-}" ]; then
      {
        printf '[user]\n'
        [ -z "${2:-}" ] || printf '\tname = %s\n' "$2"
        [ -z "${3:-}" ] || printf '\temail = %s\n' "$3"
      } >"$1/.gitconfig"
    fi
    return 0
  fi
  [ -z "${2:-}" ] || "$REAL_GIT" config --file "$1/.gitconfig" user.name "$2"
  [ -z "${3:-}" ] || "$REAL_GIT" config --file "$1/.gitconfig" user.email "$3"
}

# plain_config_value <value>: true when it is empty, or only letters,
# digits, @ . _ - and spaces with no space at either end: a value git
# config writes unquoted.
plain_config_value() {
  case "$1" in
    "") return 0 ;;
    " "* | *" " | *[!A-Za-z0-9@._\ -]*) return 1 ;;
  esac
  return 0
}

# use_home <dir>: in the current (sub)shell, git reads its global settings
# from <dir> only.
use_home() {
  export HOME="$1" GIT_CONFIG_NOSYSTEM=1
  unset XDG_CONFIG_HOME GIT_CONFIG_GLOBAL
}

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

MSG_HELPERS='say|say_note|say_log|say_sign|say_heading|step_start|step_end|show_error|fail|lp_fail|stop_with_error|ask|ask_terminal|prompt_for|answer|add_problem|guide_begin|guide_step|guide_end'

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
# Opt-out (#136 review, note D): a literal that is not a message (text
# matched against a tool's output, or a command captured in $( )) is
# left out when it starts and ends on a line whose comment is exactly
# "# not-a-message". Only this scan honours it: a message helper's text
# on such a line is still collected by user_strings, and a literal over
# several lines is never left out.
literal_strings() {
  awk -v sq="'" '
    function flush() {
      if (lit ~ / / && !skip) { np++; plit[np] = lit; pstart[np] = start }
    }
    {
      line = $0; n = length(line); i = 1; np = 0; marked = 0
      if (q == "") prefix = ""
      while (i <= n) {
        c = substr(line, i, 1)
        if (q == "") {
          if (c == "#" && (i == 1 || substr(line, i - 1, 1) ~ /[[:space:];]/)) {
            marked = (substr(line, i) ~ /^# not-a-message[[:space:]]*$/)
            break
          }
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
      for (k = 1; k <= np; k++) {
        if (marked && pstart[k] == NR) continue
        gsub(/\n/, " ", plit[k]); print pstart[k] ": " plit[k]
      }
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
# word, or that reads as a sentence (a ", " in it, or a full stop at the
# end). Every call on a line is checked, not only the first (#136 review,
# note B). A run_offered argument may hold no $ or backtick at all: it
# runs through bash -c, so it must be a fixed string, never built from
# input. Not seen: a sentence with no comma and no full stop whose first
# word is a command word ("git then open the page").
command_arg_violations() {
  awk -v sq="'" -v say_words=" $SAY_CMD_WORDS " -v run_words=" $CMD_WORDS " '
    /^[[:space:]]*#/ { next }
    {
      line = $0; bad = 0
      while (!bad && match(line, /(^|[^A-Za-z0-9_])(say_command|run_offered)([[:space:]]|$)/)) {
        call = substr(line, RSTART, RLENGTH)
        kind = (call ~ /run_offered/) ? "run" : "say"
        rest = substr(line, RSTART + RLENGTH)
        sub(/^[[:space:]]+/, "", rest)
        q = substr(rest, 1, 1)
        if (q != "\"" && q != sq) { bad = 1; break }
        arg = substr(rest, 2); end = index(arg, q)
        if (end == 0) { bad = 1; break }
        line = substr(arg, end + 1)
        arg = substr(arg, 1, end - 1)
        word = arg; sub(/[[:space:]].*/, "", word)
        words = (kind == "run") ? run_words : say_words
        if (word == "" || index(words, " " word " ") == 0) bad = 1
        else if (arg ~ /, / || arg ~ /\.$/) bad = 1
        else if (kind == "run" && arg ~ /[$`]/) bad = 1
      }
      if (bad) print NR ": " $0
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
  sed -n 1p "$err" | grep -E '^What happened: .*(pipe|piped)' >/dev/null || { cat "$err" >&2; die "piped run did not say why it stopped"; }
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
  sed -n 1p "$got" | grep -xF 'What happened: Something unexpected happened.' >/dev/null \
    || { cat "$got" >&2; die "no plain message above the raw text"; }
  sed -n 2p "$got" | grep -E '^What to do next: .{10,}' >/dev/null \
    || { cat "$got" >&2; die "no next action above the raw text"; }
  sed -n 4p "$got" | grep -xF '    HTTP 500' >/dev/null || { cat "$got" >&2; die "raw text not shown below for support"; }
}

test_error_raw_text_has_carriage_returns_removed() {
  # Windows tools end lines with \r\n; a stray \r would garble the output.
  local got="$WORK/got.$RANDOM"
  ( load_script; show_error "It failed." "Try again." "$(printf 'line one\r\nline two\r')" ) 2>"$got"
  ! has_cr "$got" || die "a carriage return reached the output"
  grep -qxF '    line two' "$got" || { cat "$got" >&2; die "raw text lost"; }
}

test_fail_exits_with_the_code_it_is_given() {
  local rc=0
  ( load_script; fail 3 "It stopped." "Run it again." ) 2>/dev/null || rc=$?
  [ "$rc" -eq 3 ] || die "fail exited $rc, want 3"
}

# ---------- message helpers: blank lines and colour ----------
# Finding 8 (end-to-end run 1): what the script says to the user (a
# question, the plan, a guide, a stop, the closing "What to do next") is
# told apart from its progress log by one blank line before it, never
# two, and the lines the user must act on are in one colour, only at a
# terminal that takes colour (BOOTSTRAP_COLOR stands in for the terminal).

# End-to-end run 1 on v2.7.0, finding r1g (Adam): a line where the user
# types an answer (COLOUR_ON) is told apart from the text the user reads
# to act (READ_ON: the explanation above a question, a guide, "What to do
# next", the instruction line above a command).
COLOUR_ON="$(printf '\033[1;36m')"
COLOUR_OFF="$(printf '\033[0m')"
READ_ON="$(printf '\033[1;35m')"
# The command colour, for a command the user is to copy or that the
# script offers to run (end-to-end run 1 repeated, finding r1d): its
# instruction line is in READ_ON, the command itself in COMMAND_ON.
COMMAND_ON="$(printf '\033[1;32m')"
# The third, for the progress log (Adam, 2026-10-27, with the colour key):
# dim, which follows the terminal's own text colour on light and dark
# backgrounds alike.
LOG_ON="$(printf '\033[2m')"
# has_esc <file>: the file holds an escape character (the start of a
# colour code), read through od -c as has_cr does.
has_esc() { od -A n -c "$1" | grep -F '033' >/dev/null; }

test_a_question_after_progress_lines_comes_after_one_blank_line() {
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  printf '%s\n' '==> Checking your computer' '    Done. git is installed' 'A line of work.' '' \
    'Why it is asked, in one sentence.' 'Name [x]: ' >"$want"
  ( load_script; step_start "Checking your computer"; step_end "git is installed"; say "A line of work."
    ask "Why it is asked, in one sentence." "Name" x ) <<<"y" >"$got" 2>"$got.err"
  expect_same "a question after progress lines" "$want" "$got"
  [ ! -s "$got.err" ] || { cat "$got.err" >&2; die "wrote to stderr"; }
  # The first thing the script prints has no blank line above it.
  printf '%s\n' 'Why it is asked, in one sentence.' 'Name [x]: ' >"$want"
  ( load_script; ask "Why it is asked, in one sentence." "Name" x ) <<<"y" >"$got"
  expect_same "a question printed first" "$want" "$got"
}

test_the_log_after_a_question_comes_after_one_blank_line() {
  # r1i (run 1 on v2.7.0; Adam: fold it into #248): the progress log that
  # follows the last answer is set apart by one blank line, as under #202,
  # after any question or prompt: a question, a question asked at the
  # terminal, the pause of a guide. Never two blank lines, and a question
  # right after another still has one blank line between.
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  printf 'no\n' >"$got.tty"
  ( load_script; export BOOTSTRAP_TTY="$got.tty"
    ask "Why it is asked, in one sentence." "Your email address for git" a@b.c
    step_start "Checking that npm is installed"; say "A line of work."
    ask_terminal "It runs only if you type yes." "Run it now? (yes or no)" || true; step_end "It works."
    wait_for_enter || true; say_log "Checking again."; step_end "It works now."
    ask "Why the first one." First a; ask "Why the second one." Second b; step_start "Next"
  ) <<<"$(printf 'x@y.z\n\n1\n2')" >"$got" 2>"$got.err"
  printf '%s\n' 'Why it is asked, in one sentence.' 'Your email address for git [a@b.c]: ' \
    '' '==> Checking that npm is installed' 'A line of work.' \
    '' 'It runs only if you type yes.' 'Run it now? (yes or no) [no]: ' '' '    Done. It works.' \
    '' 'Press Enter to check again, or type q to stop: ' '' 'Checking again.' '    Done. It works now.' \
    '' 'Why the first one.' 'First [a]: ' '' 'Why the second one.' 'Second [b]: ' '' '==> Next' >"$want"
  expect_same "the log after a question" "$want" "$got"
  [ ! -s "$got.err" ] || { cat "$got.err" >&2; die "wrote to stderr"; }
}

test_an_offered_command_run_after_yes_never_doubles_a_blank_line() {
  # #248 review, B1: after yes to "Run it now?", the blank line of r1i
  # comes right after the answer, before the command's own output, which
  # no helper sees; so output that ends in a blank line is not followed
  # by a second one before "The command finished".
  local d want
  d="$(tmpdir)"
  printf 'yes\n' >"$d/tty"
  printf '%s\n' '#!/bin/sh' 'printf "output of the command: %s\n\n" "$1"' >"$d/run"
  chmod +x "$d/run"
  ( load_script; export BOOTSTRAP_TTY="$d/tty" BOOTSTRAP_RUN="$d/run"; OFFER=gh-setup-git; offer_command ) >"$d/out" 2>"$d/err"
  want="$(printf '%s\n' 'The script can run this command for you:' '    gh auth setup-git' '' \
    'It runs only if you type yes; Enter or any other answer skips it, and you can run it yourself.' \
    'Run it now? (yes or no) [no]: ' '' 'output of the command: gh auth setup-git' '' \
    'The command finished. Checking again.')"
  [ "$(cat "$d/out")" = "$want" ] || { printf 'want:\n%s\ngot:\n' "$want" >&2; cat "$d/out" >&2; die "the lines around an offered command differ"; }
  ! awk 'prev == "" && NR > 1 && $0 == "" { bad = 1 } { prev = $0 } END { exit !bad }' "$d/out" \
    || { cat "$d/out" >&2; die "two blank lines in a row"; }
}

test_the_log_after_the_command_to_continue_comes_after_one_blank_line() {
  # #248 review, N3: the block with the command to continue, shown after
  # "Proceed?" and before the first change, is set apart from the log that
  # follows it by one blank line, as after a question (r1i): in a new
  # setup before "==> Creating the project", and in a continued one before
  # its next step.
  local d n
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  n="$(grep -nxF "$(load_script; printf '%s' "$ADVANCE_INTRO")" "$d/out" | cut -d: -f1)"
  [ -n "$n" ] || { cat "$d/out" >&2; die "no command to continue"; }
  [ "$(sed -n "$((n + 2)),$((n + 4))p" "$d/out")" = "$(printf '%s\n\n%s' \
    'If the project was not created yet, that command says so and shows the command to start again.' \
    '==> Creating the project octo-user/my-app on GitHub')" ] \
    || { sed -n "$n,$((n + 5))p" "$d/out" >&2; die "no blank line between the command to continue and the log"; }
  # Continued with --resume after the limit of the wait: the command, one
  # blank line, the next step.
  d="$(tmpdir)"
  echo 9999 >"$d/build-pending"
  setup_run "$d" --non-interactive --yes --ci-timeout 1
  expect_rc 1 "$d"
  echo 0 >"$d/build-pending"
  again "$d"
  expect_rc 0 "$d"
  n="$(grep -nxF "$(load_script; printf '%s' "$ADVANCE_INTRO")" "$d/out" | cut -d: -f1)"
  [ -n "$n" ] || { cat "$d/out" >&2; die "resume: no command to continue"; }
  [ -z "$(sed -n "$((n + 2))p" "$d/out")" ] && sed -n "$((n + 3))p" "$d/out" | grep '^==> ' >/dev/null \
    || { sed -n "$n,$((n + 4))p" "$d/out" >&2; die "resume: no blank line between the command to continue and the next step"; }
}

test_blocks_one_after_another_have_one_blank_line_between_never_two() {
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  printf '%s\n' 'Working.' '' 'Why the first one.' 'First [a]: ' '' 'Why the second one.' 'Second [b]: ' \
    '' 'The title.' 'Why this is needed: a reason' '  1. Do it.' 'When it has worked: a' \
    'If you see something else: b' 'How the script checks it: c' '' \
    'Press Enter to check again, or type q to stop: ' >"$want"
  ( load_script; say "Working."; block_start; block_start
    ask "Why the first one." First a; ask "Why the second one." Second b
    guide_begin "The title." "a reason"; guide_step "Do it."; guide_end a b c; block_start
    wait_for_enter || true ) <<<"$(printf '1\n2\nq')" >"$got"
  expect_same "blocks one after another" "$want" "$got"
  # An open line of the wait's stars is ended first, then one blank line;
  # a stop after it puts the blank line on stdout too.
  printf '%s\n' 'Checking the build status *****' '' 'Why it is asked, in one sentence.' 'Name [x]: ' >"$want"
  ( load_script; say_open "Checking the build status"; say_open " *****"
    ask "Why it is asked, in one sentence." "Name" x ) <<<"y" >"$got"
  expect_same "a question after an open line of stars" "$want" "$got"
  ( load_script; say_open "Checking the build status ***"; show_error "It broke." "Run it again." ) >"$got" 2>&1
  printf '%s\n' 'Checking the build status ***' '' 'What happened: It broke.' 'What to do next: Run it again.' >"$want"
  expect_same "a stop after an open line of stars" "$want" "$got"
}

test_a_stop_and_the_closing_next_step_come_after_one_blank_line() {
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  # The blank line before a stop goes to stdout, after the progress log
  # it closes, so stderr still begins with "What happened".
  ( load_script; say "Working."; show_error "It broke." "Run it again." ) >"$got.out" 2>"$got.err"
  printf '%s\n' 'Working.' '' >"$want"
  expect_same "stdout before a stop" "$want" "$got.out"
  printf '%s\n' 'What happened: It broke.' 'What to do next: Run it again.' >"$want"
  expect_same "the stop" "$want" "$got.err"
  # As a terminal shows both streams: one blank line between.
  ( load_script; say "Working."; show_error "It broke." "Run it again." ) >"$got" 2>&1
  printf '%s\n' 'Working.' '' 'What happened: It broke.' 'What to do next: Run it again.' >"$want"
  expect_same "the stop, both streams" "$want" "$got"
  # A stop that shows the command to start again or to continue: the
  # command opens the block, and the stop follows it after a blank line.
  ( load_script; IN_NAME=my-app; RESTART_CMD="bootstrap-project.sh --name my-app"
    step_end "Checked."; stop_with_error "It broke." "Run it again." "" ) >"$got" 2>&1 || true
  printf '%s\n' '    Done. Checked.' '' 'To start again, run this command:' \
    '    bash bootstrap-project.sh --name my-app' '' 'What happened: It broke.' 'What to do next: Run it again.' >"$want"
  expect_same "a stop with its command" "$want" "$got"
  # The closing "What to do next" said through say, and the plan's heading.
  ( load_script; say "    Licence: mit"; say "What to do next: open the Claude app."
    step_end "Checked."; say_heading "Here is the plan."; say "The project:" ) >"$got"
  printf '%s\n' '    Licence: mit' '' 'What to do next: open the Claude app.' '    Done. Checked.' '' \
    'Here is the plan.' 'The project:' >"$want"
  expect_same "the closing next step and the plan heading" "$want" "$got"
  # The command to continue, shown once before the first change, is a
  # block of its own, plain; the closing help line follows "What to do
  # next" straight on, plain.
  ( load_script; step_end "Checked."; say "$ADVANCE_INTRO"; say_command "bash x.sh --resume"
    step_start "Creating"; say "What to do next: open it."; say "If you ever feel stuck, ask Clead." ) >"$got"
  printf '%s\n' '    Done. Checked.' '' "$ADVANCE_INTRO" '    bash x.sh --resume' '==> Creating' '' \
    'What to do next: open it.' 'If you ever feel stuck, ask Clead.' >"$want"
  expect_same "the command to continue and the closing lines" "$want" "$got"
}

test_no_colour_codes_by_default_in_a_file_or_pipe() {
  local got="$WORK/got.$RANDOM"
  ( load_script; unset BOOTSTRAP_COLOR NO_COLOR BOOTSTRAP_STDOUT_TERMINAL; export TERM=xterm BOOTSTRAP_TTY="$got.tty"
    printf 'no\n' >"$got.tty"
    ask "Why it is asked, in one sentence." "Name" x; ask_terminal "It runs only if you type yes." "Run it now?" || true
    wait_for_enter || true; say_heading "Here is the plan."; say "What to do next: open it."
    show_colour_key; step_start "Checking"; say "A line of work."; say_open "Waiting"; say_open " *"; step_end "It works."
    say "$CONTINUE_INTRO"; say_command "bash x.sh --resume"
    guide_begin "The title." "a reason"; guide_step "Run this command:"; say_command "gh auth status"; guide_end a b c
    OFFER=gh-setup-git; offer_command || true; say_command "gh auth status" err
    show_error "It broke." "Run it again." ) <<<"$(printf 'y\nq')" >"$got" 2>"$got.err"
  ! has_esc "$got" || { od -c "$got" | head >&2; die "colour codes on stdout without a terminal"; }
  ! has_esc "$got.err" || { od -c "$got.err" | head >&2; die "colour codes on stderr without a terminal"; }
  ( load_script; unset BOOTSTRAP_COLOR NO_COLOR BOOTSTRAP_STDOUT_TERMINAL; export TERM=xterm; colour_on ) >"$got" \
    && die "colour_on said yes for a file"
  return 0
}

test_the_colour_hook_paints_only_the_lines_the_user_acts_on() {
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  printf 'no\n' >"$got.tty"
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1 BOOTSTRAP_TTY="$got.tty"
    step_start "Checking"; say "A line of work."; step_end "It works."; say_command "gh auth status"
    ask "Why it is asked, in one sentence." "Pack" "" "1) node: the first choice"
    ask_terminal "It runs only if you type yes." "Run it now? (yes or no)" || true
    guide_begin "The title." "a reason"; guide_step "Do it."; guide_end a b c
    wait_for_enter || true
    say_heading "Here is the plan."; say "    On GitHub: a/b"
    say "What to do next: open the Claude app."; say "If you ever feel stuck, ask Clead."
    step_start "Checking"; say_note "You can follow the check here: x"; step_end "It works." ) <<<"$(printf 'node\nq')" >"$got" 2>"$got.err"
  # r1g: the line where the user types an answer in one colour (COLOUR_ON,
  # up to the space where the answer goes); the text read to act (the
  # explanation above a question, a guide's title, why, steps, "When it
  # has worked" and "If you see something else", the plan's heading,
  # "What to do next", a note) in another (READ_ON). The choices, "How the
  # script checks it", the plan's lines and the closing help line stay
  # plain.
  {
    printf '%s==> Checking%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '%sA line of work.%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '    %sDone. It works.%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '    %sgh auth status%s\n' "$COMMAND_ON" "$COLOUR_OFF"
    printf '\n%sWhy it is asked, in one sentence.%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%s\n' '  1) node: the first choice'
    printf '%sPack:%s \n' "$COLOUR_ON" "$COLOUR_OFF"
    printf '\n%sIt runs only if you type yes.%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sRun it now? (yes or no) [no]:%s \n' "$COLOUR_ON" "$COLOUR_OFF"
    printf '\n%sThe title.%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sWhy this is needed: a reason%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '  %s1. Do it.%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sWhen it has worked: a%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sIf you see something else: b%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%s\n' 'How the script checks it: c' ''
    printf '%sPress Enter to check again, or type q to stop:%s \n' "$COLOUR_ON" "$COLOUR_OFF"
    printf '\n%sHere is the plan.%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%s\n' '    On GitHub: a/b' ''
    printf '%sWhat to do next: open the Claude app.%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%s\n' 'If you ever feel stuck, ask Clead.'
    printf '%s==> Checking%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '%sYou can follow the check here: x%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '    %sDone. It works.%s\n' "$LOG_ON" "$COLOUR_OFF"
  } >"$want"
  expect_same "painted lines" "$want" "$got"
  [ ! -s "$got.err" ] || { cat "$got.err" >&2; die "wrote to stderr"; }
  # A stop, on stderr: only its "What to do next" line is painted.
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1
    show_error "It broke." "Run it again." "raw text" ) 2>"$got"
  {
    printf '%s\n' 'What happened: It broke.'
    printf '%sWhat to do next: Run it again.%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%s\n' 'Details for support (you can ignore these):' '    raw text'
  } >"$want"
  expect_same "a painted stop" "$want" "$got"
}

# every_line_kind <tty file>: one of each kind of line the script prints,
# on stdout and stderr (call after load_script; stdin gives the answers).
every_line_kind() {
  printf 'no\n' >"$1"
  export BOOTSTRAP_TTY="$1"
  show_colour_key; step_start "Checking"; say "A line of work."; say "Warning: be careful."
  say_note "You can follow the check here: x"; say_open "Waiting"; say_open " *"; step_end "It works."
  ask "Why it is asked, in one sentence." "Pack" "" "1) node: the first choice"
  ask_terminal "It runs only if you type yes." "Run it now? (yes or no)" || true
  guide_begin "The title." "a reason"; guide_step "Run this command:"; say_command "gh auth status"
  guide_step "Come back to this window."; guide_end a b c; guide_details "raw text"
  OFFER=gh-setup-git; offer_command || true; wait_for_enter || true
  say_heading "Here is the plan."; say "    On GitHub: a/b"
  say "$ADVANCE_INTRO"; say_command "bash x.sh --resume"; say "$CONTINUE_INTRO"; say_command "bash x.sh --resume"
  say "What to do next: open it."; say "If you ever feel stuck, ask Clead."
  say_command "gh auth status" err; show_error "It broke." "Run it again." "raw text"
}

test_colour_off_output_is_the_coloured_output_without_its_codes() {
  # r1g: the colours change no text. With colour forced, every kind of
  # line with its codes taken out is the output without a terminal, byte
  # for byte (the key aside, which only colour shows); NO_COLOR and
  # TERM=dumb give exactly the output without a terminal.
  local d esc
  d="$(tmpdir)"
  esc="$(printf '\033')"
  ( load_script; unset BOOTSTRAP_COLOR NO_COLOR BOOTSTRAP_STDOUT_TERMINAL; export TERM=xterm
    every_line_kind "$d/tty" ) <<<"$(printf 'node\nq')" >"$d/plain" 2>"$d/plain.err"
  ! has_esc "$d/plain" && ! has_esc "$d/plain.err" || die "codes without a terminal"
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1
    every_line_kind "$d/tty" ) <<<"$(printf 'node\nq')" >"$d/colour" 2>"$d/colour.err"
  grep -F "$READ_ON" "$d/colour" >/dev/null || die "no line in the read colour"
  grep -F "$COLOUR_ON" "$d/colour" >/dev/null || die "no line in the answer colour"
  sed "s/$esc\\[[0-9;]*m//g" "$d/colour" | sed '/^Colour key: /d' | sed '1{/^$/d;}' >"$d/stripped"
  sed "s/$esc\\[[0-9;]*m//g" "$d/colour.err" >"$d/stripped.err"
  expect_same "stdout with the codes taken out" "$d/plain" "$d/stripped"
  expect_same "stderr with the codes taken out" "$d/plain.err" "$d/stripped.err"
  ( load_script; export TERM=xterm BOOTSTRAP_COLOR=1 NO_COLOR=1
    every_line_kind "$d/tty" ) <<<"$(printf 'node\nq')" >"$d/nc" 2>"$d/nc.err"
  cmp -s "$d/plain" "$d/nc" && cmp -s "$d/plain.err" "$d/nc.err" || die "NO_COLOR output differs from the output without a terminal"
  ( load_script; unset NO_COLOR; export TERM=dumb BOOTSTRAP_COLOR=1
    every_line_kind "$d/tty" ) <<<"$(printf 'node\nq')" >"$d/dumb" 2>"$d/dumb.err"
  cmp -s "$d/plain" "$d/dumb" && cmp -s "$d/plain.err" "$d/dumb.err" || die "TERM=dumb output differs from the output without a terminal"
}

test_the_read_colour_stays_off_the_log_the_plan_lines_and_the_report() {
  # r1g, "not a lit-up Christmas tree": the read colour marks only what
  # the user reads to act. A progress line, a warning, a line of the plan
  # or of the report, "How the script checks it", "What happened" and the
  # details for support never carry it.
  local d l
  d="$(tmpdir)"
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1
    every_line_kind "$d/tty" ) <<<"$(printf 'node\nq')" >"$d/out" 2>"$d/err"
  for l in '==> Checking' 'A line of work.' 'Warning: be careful.' 'Waiting' 'Done. It works.' \
    '1) node: the first choice' 'How the script checks it: c' 'Details for support' 'raw text' \
    'On GitHub: a/b' 'If you ever feel stuck, ask Clead.' 'What happened: It broke.'; do
    ! grep -F -- "$l" "$d/out" "$d/err" | grep -F "$READ_ON" >/dev/null || { grep -F -- "$l" "$d/out" "$d/err" | od -c | head >&2; die "in the read colour: $l"; }
  done
  # The lines offered with a command: its line in the read colour, the
  # question in the answer colour, and the line after a no in the read
  # colour, as it tells the user what to do.
  grep -qxF "${READ_ON}The script can run this command for you:${COLOUR_OFF}" "$d/out" || { od -c "$d/out" | head -60 >&2; die "the offer's line is not in the read colour"; }
  grep -qF "${COLOUR_ON}Run it now? (yes or no) [no]:${COLOUR_OFF} " "$d/out" || die "the offer's question is not in the answer colour"
  grep -qF "${READ_ON}Not run. To run it yourself" "$d/out" || { grep -F 'Not run' "$d/out" | od -c >&2; die "the line after a no is not in the read colour"; }
}

test_no_color_and_a_dumb_terminal_win_over_the_colour_hook() {
  # NO_COLOR (https://no-color.org), when set and not empty, turns colour
  # off whatever else says on, the hook and a real terminal; so does a
  # terminal that says it is dumb. An empty NO_COLOR does not count.
  local got="$WORK/got.$RANDOM"
  ( load_script; export TERM=xterm BOOTSTRAP_COLOR=1 NO_COLOR=1
    show_colour_key; step_start "Checking"; say "A line of work."; say_open "Waiting"; say_open " *"; step_end "It works."
    say_heading "Here is the plan."; say "$CONTINUE_INTRO"; say_command "bash x.sh --resume"
    guide_begin "The title." "a reason"; guide_step "Run this command:"; say_command "gh auth status"
    say_command "gh auth status" err; show_error "It broke." "Run it again." ) >"$got" 2>&1
  ! has_esc "$got" || { od -c "$got" | head >&2; die "NO_COLOR did not turn colour off"; }
  ( load_script; unset NO_COLOR; export TERM=dumb BOOTSTRAP_COLOR=1
    show_colour_key; step_start "Checking"; say "A line of work."; say_open "Waiting"; say_open " *"; step_end "It works."
    say_heading "Here is the plan."; say "$CONTINUE_INTRO"; say_command "bash x.sh --resume"
    guide_begin "The title." "a reason"; guide_step "Run this command:"; say_command "gh auth status"
    say_command "gh auth status" err; show_error "It broke." "Run it again." ) >"$got" 2>&1
  ! has_esc "$got" || { od -c "$got" | head >&2; die "TERM=dumb did not turn colour off"; }
  ( load_script; export TERM=xterm BOOTSTRAP_COLOR=1 NO_COLOR=
    say_heading "Here is the plan." ) >"$got"
  has_esc "$got" || die "an empty NO_COLOR turned colour off"
}

test_colour_follows_the_terminal_check_of_the_wait() {
  # Colour on stdout asks stdout_is_terminal (#204), so its hook
  # BOOTSTRAP_STDOUT_TERMINAL counts as the terminal; NO_COLOR and
  # TERM=dumb still win. A stop on stderr asks whether stderr is a
  # terminal, which a file is not.
  local got="$WORK/got.$RANDOM"
  ( load_script; unset NO_COLOR BOOTSTRAP_COLOR; export TERM=xterm BOOTSTRAP_STDOUT_TERMINAL=yes
    say_heading "Here is the plan."; show_error "It broke." "Run it again." ) >"$got" 2>"$got.err"
  grep -qF "${READ_ON}Here is the plan.${COLOUR_OFF}" "$got" || { od -c "$got" | head >&2; die "no colour with BOOTSTRAP_STDOUT_TERMINAL=yes"; }
  ! has_esc "$got.err" || { od -c "$got.err" | head >&2; die "colour on stderr that is a file"; }
  ( load_script; unset NO_COLOR BOOTSTRAP_COLOR; export TERM=xterm BOOTSTRAP_STDOUT_TERMINAL=no
    say_heading "Here is the plan." ) >"$got"
  ! has_esc "$got" || die "colour with BOOTSTRAP_STDOUT_TERMINAL=no"
  ( load_script; unset BOOTSTRAP_COLOR; export TERM=xterm BOOTSTRAP_STDOUT_TERMINAL=yes NO_COLOR=1
    say_heading "Here is the plan." ) >"$got"
  ! has_esc "$got" || die "NO_COLOR did not win over BOOTSTRAP_STDOUT_TERMINAL=yes"
  ( load_script; unset NO_COLOR BOOTSTRAP_COLOR; export TERM=dumb BOOTSTRAP_STDOUT_TERMINAL=yes
    say_heading "Here is the plan." ) >"$got"
  ! has_esc "$got" || die "TERM=dumb did not win over BOOTSTRAP_STDOUT_TERMINAL=yes"
}

# Adam, 2026-10-27, with r1d: the progress log in a colour of its own, and
# a colour key at the start that says in words what each colour marks.
test_the_progress_log_is_dim_only_when_colour_is_on() {
  # The log: a step's first and last line, a say inside a step, and the
  # wait's open line. A say after the step, or inside a block the user
  # reads (here a guide) even within a step, is not log; a warning is
  # never dimmed. The indent of the done line stays outside the code.
  # r1h: the signs of life of the wait (its lines and the stars on a line
  # of their own) are not dim, so they are easy to see. r1g: say_log is dim
  # also after a block the user reads (what the script did after an answer).
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1
    step_start "Checking"; say "A line of work."; say "Warning: be careful."
    wait_line "Waiting"; say_open "*"; say_open "*"; step_end "It works."; say "After the step."
    step_start "Checking again"; guide_begin "The title." "a reason"; say "In the guide."
    guide_end a b c; say_log "Not made public."; step_end "It works now." ) >"$got" 2>"$got.err"
  {
    printf '%s==> Checking%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '%sA line of work.%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '%s\n' 'Warning: be careful.' 'Waiting' '**'
    printf '    %sDone. It works.%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '%s\n' 'After the step.'
    printf '%s==> Checking again%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '\n%sThe title.%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sWhy this is needed: a reason%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%s\n' 'In the guide.'
    printf '%sWhen it has worked: a%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sIf you see something else: b%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%s\n' 'How the script checks it: c'
    printf '%sNot made public.%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '    %sDone. It works now.%s\n' "$LOG_ON" "$COLOUR_OFF"
  } >"$want"
  expect_same "the dim progress log" "$want" "$got"
  [ ! -s "$got.err" ] || { cat "$got.err" >&2; die "wrote to stderr"; }
  # Colour off (no terminal, NO_COLOR, TERM=dumb): the same lines, plain.
  printf '%s\n' '==> Checking' 'A line of work.' 'Waiting *' '    Done. It works.' >"$want"
  ( load_script; unset NO_COLOR BOOTSTRAP_COLOR BOOTSTRAP_STDOUT_TERMINAL; export TERM=xterm
    step_start "Checking"; say "A line of work."; say_open "Waiting"; say_open " *"; step_end "It works." ) >"$got"
  expect_same "the progress log with no terminal" "$want" "$got"
  ( load_script; export TERM=xterm BOOTSTRAP_COLOR=1 NO_COLOR=1
    step_start "Checking"; say "A line of work."; say_open "Waiting"; say_open " *"; step_end "It works." ) >"$got"
  expect_same "the progress log with NO_COLOR" "$want" "$got"
  ( load_script; unset NO_COLOR; export TERM=dumb BOOTSTRAP_COLOR=1
    step_start "Checking"; say "A line of work."; say_open "Waiting"; say_open " *"; step_end "It works." ) >"$got"
  expect_same "the progress log with TERM=dumb" "$want" "$got"
}

test_lines_inside_a_step_the_user_may_act_on_are_not_dim() {
  # #237 review, N2: a line inside a step that gives the user a link, an
  # option or something to set is said with say_note, never dim; the
  # progress lines around it stay dim.
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM" d l
  # r1g: such a line is in the read colour, as it tells the user what to
  # read and do.
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1
    step_start "Checking"; say "Working."; say_note "You can follow the check here: x"
    say "More work."; step_end "It works." ) >"$got"
  {
    printf '%s==> Checking%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '%sWorking.%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '%sYou can follow the check here: x%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sMore work.%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '    %sDone. It works.%s\n' "$LOG_ON" "$COLOUR_OFF"
  } >"$want"
  expect_same "a note inside a step" "$want" "$got"
  # The permissions the setup needs, when GitHub does not say which ones
  # gh has (a fine-grained token).
  d="$(tmpdir)"
  export TERM=xterm BOOTSTRAP_COLOR=1 STUB_GH_SCOPES=-
  unset NO_COLOR
  pre "$d" ni with_vis private preflight_github_permissions
  unset STUB_GH_SCOPES
  expect_rc 0 "$d"
  grep -qxF "${LOG_ON}==> Checking that gh has the permissions on GitHub that the setup needs${COLOUR_OFF}" "$d/out" \
    || { od -c "$d/out" | head -20 >&2; die "permissions: the step line is not dim"; }
  for l in "GitHub does not say which permissions this sign-in has, as with a fine-grained token (a key made on GitHub with chosen permissions)." \
    "The setup needs these permissions, each set to \"Read and write\": Administration, Contents, Workflows and Pull requests; and your account must be allowed to create repositories (new projects on GitHub)." \
    "If one of them is missing, a later step stops and says so."; do
    grep -qxF -- "${READ_ON}$l${COLOUR_OFF}" "$d/out" || { od -c "$d/out" | head -40 >&2; die "permissions: not in the read colour: $l"; }
  done
  # Going on without protection (--allow-unprotected), GitHub Actions not
  # checked, and the wait's limit and link to the checks, in one run.
  d="$(tmpdir)"
  unset BOOTSTRAP_COLOR
  export STUB_GH_PROTECT_FAIL=plan
  setup_run "$d" --non-interactive --yes --private
  expect_rc 3 "$d"
  export BOOTSTRAP_COLOR=1 STUB_GH_ACTIONS_FAIL=forbidden
  again "$d" --allow-unprotected
  unset STUB_GH_PROTECT_FAIL STUB_GH_ACTIONS_FAIL BOOTSTRAP_COLOR
  expect_rc 0 "$d"
  grep -qxF "${LOG_ON}==> Protecting the main version of the project${COLOUR_OFF}" "$d/out" \
    || { od -c "$d/out" | head -20 >&2; die "the protection step line is not dim"; }
  for l in "GitHub does not protect the main version of this project on its plan; its answer is below." \
    "You chose to go on without protection with --allow-unprotected, so the script goes on, and writes that decision into the project's memory/decisions.md." \
    "The script could not check whether GitHub Actions is turned on for the project: GitHub did not say (its answer is below). This check only warns early, so the setup goes on." \
    "$WAIT_LIMIT_LINE" "$WAIT_LINK_LINE"; do
    grep -qxF -- "${READ_ON}$l${COLOUR_OFF}" "$d/out" || { cat "$d/out" >&2; die "not in the read colour: $l"; }
  done
  # A licence typed at the question that GitHub does not know (#237
  # delta review, B1): the problem and "Please try again." come inside
  # the licence check, before the question is asked again.
  d="$(tmpdir)"
  working_git "$d"
  printf '%s\n' my-app "" "Lends tools." "" "" python "" mti "" "" "" "" mit no >"$d/in"
  export BOOTSTRAP_COLOR=1
  whole "$d"
  unset BOOTSTRAP_COLOR
  expect_rc 1 "$d"
  grep -qxF "${LOG_ON}==> Checking that GitHub knows the licence mti${COLOUR_OFF}" "$d/out" \
    || { od -c "$d/out" | head -20 >&2; die "licence: the step line is not dim"; }
  l="GitHub has no licence with the short name mti. Use none, one of the listed licences, or the short name of a licence on https://choosealicense.com/licenses/ (each licence's page shows its short name, such as mit). Please try again."
  grep -qxF -- "${READ_ON}$l${COLOUR_OFF}" "$d/out" || { grep -F 'no licence with the short name' "$d/out" | od -c | head -20 >&2; die "licence: not in the read colour: $l"; }
}

test_the_colour_key_says_in_words_what_each_colour_marks() {
  # At most 4 short lines, one per colour, each in its own colour and
  # saying in words what it marks, then a blank line; nothing at all when
  # colour is off. r1g: four colours, the answer line and the text read to
  # act apart.
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1; show_colour_key; step_start "Checking" ) >"$got"
  {
    printf '%sColour key: where you type an answer%s\n' "$COLOUR_ON" "$COLOUR_OFF"
    printf '%sColour key: what to read and do%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sColour key: commands to copy or to run%s\n' "$COMMAND_ON" "$COLOUR_OFF"
    printf '%sColour key: the progress log of what the script does%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '\n%s==> Checking%s\n' "$LOG_ON" "$COLOUR_OFF"
  } >"$want"
  expect_same "the colour key" "$want" "$got"
  # Adam's fallback (r1g, 15:23): the answer line and the text read to act
  # in one colour, changed in one place (READ_COLOUR); the key then shows
  # them as one line, and every such line is in that colour.
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1; READ_COLOUR="$ANSWER_COLOUR"
    show_colour_key; ask "Why it is asked, in one sentence." "Name" x ) <<<"y" >"$got"
  {
    printf '%sColour key: where you type an answer, and what to read and do%s\n' "$COLOUR_ON" "$COLOUR_OFF"
    printf '%sColour key: commands to copy or to run%s\n' "$COMMAND_ON" "$COLOUR_OFF"
    printf '%sColour key: the progress log of what the script does%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '\n%sWhy it is asked, in one sentence.%s\n' "$COLOUR_ON" "$COLOUR_OFF"
    printf '%sName [x]:%s \n' "$COLOUR_ON" "$COLOUR_OFF"
  } >"$want"
  expect_same "the colour key with the answer and read colours the same" "$want" "$got"
  ( load_script; unset NO_COLOR BOOTSTRAP_COLOR BOOTSTRAP_STDOUT_TERMINAL; export TERM=xterm; show_colour_key ) >"$got"
  [ ! -s "$got" ] || { cat "$got" >&2; die "a colour key with no terminal"; }
  ( load_script; export TERM=xterm BOOTSTRAP_COLOR=1 NO_COLOR=1; show_colour_key ) >"$got"
  [ ! -s "$got" ] || { cat "$got" >&2; die "a colour key with NO_COLOR"; }
  ( load_script; unset NO_COLOR; export TERM=dumb BOOTSTRAP_COLOR=1; show_colour_key ) >"$got"
  [ ! -s "$got" ] || { cat "$got" >&2; die "a colour key with TERM=dumb"; }
  # A question right after the key: one blank line between, never two.
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1; show_colour_key
    ask "Why it is asked, in one sentence." "Name" x ) <<<"y" >"$got"
  [ "$(sed -n '5p;6p' "$got")" = "$(printf '\n%sWhy it is asked, in one sentence.%s' "$READ_ON" "$COLOUR_OFF")" ] \
    || { od -c "$got" | head -20 >&2; die "the key and a question are not one blank line apart"; }
}

# End-to-end run 1 repeated, finding r1d (Adam): "When the user is
# instructed to execute a prompt it should be color coded for easy
# identification. One color for the instruction [...], another color for
# the command". The instruction is in the colour of the other lines the
# user acts on; the command in a second one, around its text only, not
# the indent in front of it.
test_an_instruction_and_the_command_below_it_are_in_two_colours() {
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM" n advance
  [ "$COMMAND_ON" != "$READ_ON" ] || die "the command colour is the instruction colour"
  advance="$(load_script; printf '%s' "$ADVANCE_INTRO")"
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1
    say "$CONTINUE_INTRO"; say_command "bash x.sh --resume"
    say "$START_AGAIN_INTRO"; say_command "bash x.sh"
    say "$ADVANCE_INTRO"; say_command "bash x.sh --resume"
    guide_begin "The title." "a reason"; guide_step "Run this command; it does a thing:"
    say_command "gh auth status"; guide_step "Come back to this window."; guide_end a b c ) >"$got" 2>"$got.err"
  # r1g: the instruction lines in the read colour, as every step of a
  # guide, with or without a command below it.
  {
    printf '%sTo continue the setup, run this command:%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '    %sbash x.sh --resume%s\n' "$COMMAND_ON" "$COLOUR_OFF"
    printf '\n%sTo start again, run this command:%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '    %sbash x.sh%s\n' "$COMMAND_ON" "$COLOUR_OFF"
    printf '\n%s%s%s\n' "$READ_ON" "$advance" "$COLOUR_OFF"
    printf '    %sbash x.sh --resume%s\n' "$COMMAND_ON" "$COLOUR_OFF"
    printf '\n%sThe title.%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sWhy this is needed: a reason%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '  %s1. Run this command; it does a thing:%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '    %sgh auth status%s\n' "$COMMAND_ON" "$COLOUR_OFF"
    printf '  %s2. Come back to this window.%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sWhen it has worked: a%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sIf you see something else: b%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%s\n' 'How the script checks it: c'
  } >"$want"
  expect_same "an instruction and its command" "$want" "$got"
  [ ! -s "$got.err" ] || { cat "$got.err" >&2; die "wrote to stderr"; }
  # The command the script offers to run: its line in the instruction
  # colour, the command right below it in the command colour.
  printf 'no\n' >"$got.tty"
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1 BOOTSTRAP_TTY="$got.tty"
    OFFER=gh-setup-git; offer_command || true ) >"$got" 2>"$got.err"
  n="$(grep -nxF -- "${READ_ON}The script can run this command for you:${COLOUR_OFF}" "$got" | cut -d: -f1)"
  [ -n "$n" ] || { od -c "$got" | head -20 >&2; die "the line before the offered command is not in the instruction colour"; }
  [ "$(sed -n "$((n + 1))p" "$got")" = "    ${COMMAND_ON}gh auth setup-git${COLOUR_OFF}" ] \
    || { od -c "$got" | head -20 >&2; die "the offered command is not right below its line, in the command colour"; }
}

test_a_command_on_stderr_follows_the_terminal_check_of_stderr() {
  # A command printed on stderr asks whether stderr is a terminal ([ -t 2 ],
  # which a file is not), as the stop does, even when stdout counts as one;
  # the hook forces colour there too, and NO_COLOR still wins.
  local want="$WORK/want.$RANDOM" got="$WORK/got.$RANDOM"
  ( load_script; unset NO_COLOR BOOTSTRAP_COLOR; export TERM=xterm BOOTSTRAP_STDOUT_TERMINAL=yes
    say_command "gh auth status"; say_command "gh auth status" err ) >"$got" 2>"$got.err"
  printf '    %sgh auth status%s\n' "$COMMAND_ON" "$COLOUR_OFF" >"$want"
  expect_same "a command on stdout that counts as a terminal" "$want" "$got"
  printf '%s\n' '    gh auth status' >"$want"
  expect_same "a command on stderr that is a file" "$want" "$got.err"
  ( load_script; unset NO_COLOR; export TERM=xterm BOOTSTRAP_COLOR=1
    say_command "gh auth status" err ) >"$got" 2>"$got.err"
  [ ! -s "$got" ] || { cat "$got" >&2; die "a command for stderr went to stdout"; }
  printf '    %sgh auth status%s\n' "$COMMAND_ON" "$COLOUR_OFF" >"$want"
  expect_same "a command on stderr with the colour hook" "$want" "$got.err"
  ( load_script; export TERM=xterm BOOTSTRAP_COLOR=1 NO_COLOR=1
    say_command "gh auth status" err ) 2>"$got"
  printf '%s\n' '    gh auth status' >"$want"
  expect_same "a command on stderr with NO_COLOR" "$want" "$got"
}

# The instruction colour of a guide step goes by its text: a step that
# ends with a colon introduces the command printed right below it. So
# every such step must be followed by a command, and every command
# printed outside the messages block must come right after such a step
# or after one of the instruction lines (the texts *_INTRO). Read from
# the script's source, so a guide added later is held to it too.
command_intro_faults() {
  awk '
    /^[[:space:]]*# ---------- messages ----------/ { inblk = 1; next }
    /^[[:space:]]*# ---------- end of messages ----------/ { inblk = 0; next }
    inblk || /^[[:space:]]*#/ { next }
    /^offered\(\) \{/ { inoffered = 1 }
    inoffered { if ($0 ~ /^}/) inoffered = 0; next }
    /(^|[^A-Za-z0-9_])say_command[[:space:]]/ || /(^|[^A-Za-z0-9_])say_shown_command([[:space:];]|$)/ || /(^|[^A-Za-z0-9_])offered [^ ;]+ show/ {
      if (!intro) print NR ": a command with no instruction line right above it: " $0
      pending = 0
      next
    }
    /(^|[^A-Za-z0-9_])guide_step[[:space:]]/ {
      if (pending) print pending ": a step that ends with a colon, with no command below it"
      intro = ($0 ~ /:"[[:space:]]*$/)
      pending = intro ? NR : 0
      next
    }
    /(^|[^A-Za-z0-9_])(say|say_note|say_log|say_sign|say_heading|guide_begin|guide_end|show_error|fail|stop_with_error|ask|ask_terminal|step_start|step_end)[[:space:]]/ {
      if (pending) print pending ": a step that ends with a colon, with no command below it"
      pending = 0
      intro = ($0 ~ /say "\$[A-Z_]*_INTRO"/)
    }
  ' "$1"
}

test_every_command_comes_right_after_its_instruction_line() {
  local hits bad="$WORK/bad.$RANDOM"
  hits="$(command_intro_faults "$SCRIPT")"
  [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "a command and its instruction line are not together"; }
  # The check itself sees each fault: a step with a colon and no command
  # below it, a command below a step with no colon, a command below a
  # plain line; an intro line and a step with a colon (also through a
  # case) are not faults.
  printf '%s\n' 'g() {' '  guide_step "Run this command:"' '  guide_end a b c' \
    '  guide_step "Run it."' '  say_command "gh auth status"' '  say "Something."' \
    '  offered gh-setup-git show' '  say "$CONTINUE_INTRO"' '  say_command "bash x.sh"' \
    '  guide_step "Run this command:"' '  case "$X" in' '    a) say_command "gh a" ;;' \
    '    b) offered brew-gh show ;;' '  esac' '}' >"$bad"
  hits="$(command_intro_faults "$bad" | cut -d: -f1 | tr '\n' ' ')"
  [ "$hits" = "2 5 7 " ] || die "the check on a broken guide found lines: $hits (want 2 5 7)"
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
  printf '%s\ntouch "%s/path-gh-ran"\n' "$STAND_IN_SHEBANG" "$d" >"$d/bin/gh"
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
  printf '%s\n' "$STAND_IN_SHEBANG" 'printf "%s\n" "${GH_PROMPT_DISABLED-unset}" >>"$STUB_RUN_LOG"' >"$d/run"
  ( load_script; export GH_PROMPT_DISABLED=1 STUB_RUN_LOG="$d/run.log"; BOOTSTRAP_RUN="$d/run" run_offered "x" )
  [ "$(cat "$d/run.log")" = unset ] || die "the BOOTSTRAP_RUN runner saw GH_PROMPT_DISABLED=$(cat "$d/run.log")"
}

test_a_test_that_forgets_the_hooks_runs_nothing_real() {
  # Review round 1: CI must be safe by structure, not by each test
  # remembering the hooks. A test that sets no hook runs no real
  # install, login, gh or npm: the harness defaults each to a stub that
  # refuses loudly (non-zero exit), so the forgetful test fails.
  local d rc
  d="$(tmpdir)"; mkdir -p "$d/bin"
  printf '%s\ntouch "%s/real-gh-ran"\n' "$STAND_IN_SHEBANG" "$d" >"$d/bin/gh"
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
  # The lockfile step's npm (BOOTSTRAP_NPM), likewise.
  printf '%s\ntouch "%s/real-npm-ran"\n' "$STAND_IN_SHEBANG" "$d" >"$d/bin/npm"
  chmod +x "$d/bin/npm"
  rc=0
  ( load_script; export REFUSE_LOG="$d/refused.log" PATH="$d/bin:$PATH"; run_npm --version ) 2>>"$d/err" || rc=$?
  [ ! -e "$d/real-npm-ran" ] || die "run_npm ran the npm on PATH in a test that set no hook"
  [ "$rc" -ne 0 ] || die "run_npm without a hook returned 0; a forgetful test would pass"
  grep -qF 'BOOTSTRAP_NPM' "$d/err" || { cat "$d/err" >&2; die "the npm refusal does not name the hook to set"; }
  [ "$(wc -l <"$d/refused.log" | tr -d ' ')" -eq 3 ] || die "refusals not logged"
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
    'a question got no answer' 'is not signed in to your GitHub account' \
    'not the current version' 'already exists on GitHub' 'Details for support' \
    'does not have every permission on GitHub' 'could not reach GitHub' \
    'Why this is needed: ' 'When it has worked: ' 'If you see something else: ' \
    'How the script checks it: ' 'To start again, run this command' 'git is not installed' \
    'Your name for git' 'Your email address for git' 'Proceed? (yes or no)' 'Here is the plan' \
    'needs a paid GitHub plan' 'The setup is finished' 'create a Claude Project' 'is always there to help' \
    "Waiting for the project's check build" 'Making the check build required' \
    'To continue the setup, run this command' 'Making a copy of the project on this computer' \
    'line of work' 'already has' 'is inside another project that git keeps track of' \
    'The script may not write in the folder' 'does not exist' \
    "Filling in the project's name, description and product owner" 'in which the setup fills in' \
    'left for your first session with Clead' 'If the setup stops before it finishes, for any reason' \
    'that command says so and shows the command to start again'; do
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
  ! printf '%s\n' "$hits" | awk -F'[:\t]' -v f="$from" '$1 >= f + 7' | grep . >/dev/null \
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
# absent), in <dir>/cwd, with git's global settings read from the fake
# home <dir>/home (name "Test Person", email test@example.com, unless
# the test made that folder itself). It writes the resolved answers to <dir>/dump (dump_inputs),
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
    "DRY_RUN=$OPT_DRY_RUN" "RESUME=$OPT_RESUME" "GIT_NAME=$IN_GIT_NAME" "GIT_EMAIL=$IN_GIT_EMAIL"
}

inputs() {
  local d="$1"
  shift
  [ -e "$d/in" ] || : >"$d/in"
  [ -x "$d/gh" ] || make_stub_gh "$d/gh"
  [ -d "$d/home" ] || fake_home "$d/home" "Test Person" test@example.com
  mkdir -p "$d/cwd"
  rm -f "$d/dump"
  set +e
  ( load_script
    cd "$d/cwd"
    use_home "$d/home"
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
  sed -n 1p "$d/err" | grep '^What happened: ' >/dev/null || { cat "$d/err" >&2; die "no plain error first"; }
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
  # One gh call, with gh's prompts off: the account, with its headers.
  [ "$(cat "$d/gh.log")" = "$(printf 'GH_PROMPT_DISABLED=1\tapi\t-i\tuser\t--jq\t.login, (.name // "")')" ] \
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
  [ "$( load_script; STUB_GH_LOG="$d/gh2.log" BOOTSTRAP_GH="$d/gh2" check_github_account
        printf '%s|%s|%s' "$GH_LOGIN" "$GH_PROFILE_NAME" "$GH_SCOPES" )" = "octo-user|Octo User|repo,read:org,gist,workflow" ] \
    || die "a carriage return is left in what GitHub answered"
}

test_github_account_failure_is_explained_with_the_raw_text_below() {
  # An answer from GitHub that has no guide (here GitHub's own trouble)
  # is explained in plain words with the next action; gh's raw text comes
  # only below, for support. Nothing is collected, exit 1.
  local d
  d="$(tmpdir)"
  export STUB_GH_USER_FAIL=server
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}"
  [ "$RC" -eq 1 ] || { cat "$d/err" >&2; die "exit $RC, want 1"; }
  sed -n 1p "$d/err" | grep '^What happened: GitHub had a problem of its own' >/dev/null \
    || { cat "$d/err" >&2; die "no plain message first"; }
  sed -n 2p "$d/err" | grep -E '^What to do next: .*few minutes' >/dev/null || { cat "$d/err" >&2; die "no next action"; }
  sed -n 3p "$d/err" | grep -F 'Details for support' >/dev/null || { cat "$d/err" >&2; die "raw text not introduced"; }
  grep -qxF '    HTTP 503: Service Unavailable' "$d/err" || { cat "$d/err" >&2; die "status and message not shown below"; }
  grep -qxF '    gh: Service Unavailable (HTTP 503)' "$d/err" || { cat "$d/err" >&2; die "gh's own text not shown below"; }
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
  fake_home "$d/home" "Test Person" test@example.com
  # Not in a condition, so a failing step stops the subshell (errexit).
  set +e
  ( load_script
    use_home "$d/home"
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
  # The whole script, as a user gets it (the built copy) and runs it, with
  # --yes (needed with --non-interactive). It goes through to the report,
  # with exit 0.
  local d rc
  d="$(tmpdir)"
  make_stub_gh "$d/gh"
  fake_home "$d/home" "Test Person" test@example.com
  fake_tool "$d" npm 10.0.0
  make_stub_npm "$d/npm"
  mkdir -p "$d/cwd"
  use_built "$d"
  rc=0
  ( cd "$d/cwd"; use_home "$d/home"; export PATH="$d/bin:$PATH" STUB_GH_LOG="$d/gh.log" BOOTSTRAP_GH="$d/gh" \
      STUB_NPM_LOG="$d/npm.log" BOOTSTRAP_NPM="$d/npm"
    bash "$RUN_SCRIPT" --non-interactive --yes "${REQUIRED_OPTS[@]}" ) </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 0 ] || { cat "$d/err" >&2; die "exit $rc, want 0"; }
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "no report"; }
  rm -rf "$d/created" "$d/remotes" "$d/cwd/my-app" "$d/merge-sha" "$d/pr-bodies"
  rc=0
  ( cd "$d/cwd"; use_home "$d/home"; export PATH="$d/bin:$PATH" STUB_GH_LOG="$d/gh.log" BOOTSTRAP_GH="$d/gh" \
      STUB_NPM_LOG="$d/npm.log" BOOTSTRAP_NPM="$d/npm"
    bash "$RUN_SCRIPT" --non-interactive --yes "${REQUIRED_OPTS[@]}" ) <&- >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 0 ] || { cat "$d/err" >&2; die "stdin closed: exit $rc, want 0"; }
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "stdin closed: no report"; }
  # gh: the two checks on this computer, the GitHub checks (the account,
  # the published version, the name, the licence), then creating and
  # protecting the project, checking that Actions is on, making the copy
  # on this computer, reading the licence,
  # proposing the change (its body in a temporary file, written <file>),
  # waiting for build, requiring it and reading the protection back, and
  # adding the change (the id of the change sent, written <sha>),
  # every one with gh's own prompts off; the copy is the only thing made
  # on this computer.
  [ "$(cut -f2- "$d/gh.log" | awk -F'\t' -v OFS='\t' '{ for (i = 2; i <= NF; i++) { if ($(i - 1) == "--body-file") $i = "<file>"; if ($(i - 1) == "--match-head-commit") $i = "<sha>" } print }' | LC_ALL=C sort -u)" = "$(printf '%s\n' '--version' "$(printf 'repo\tcreate\t--help')" \
      "$(printf 'pr\tchecks\t--help')" "$(printf 'pr\tmerge\t--help')" \
      "$(printf 'api\t-i\tuser\t--jq\t.login, (.name // "")')" \
      "$(printf 'api\t-i\t-H\tAccept: application/vnd.github.raw+json\trepos/factoincognito/ai-project-bootstrap/contents/CHANGELOG.md')" \
      "$(printf 'api\t-i\trepos/octo-user/my-app')" \
      "$(printf 'api\t-i\tlicenses/mit\t--jq\t.key')" \
      "$(printf 'repo\tcreate\tocto-user/my-app\t--template\tfactoincognito/ai-project-bootstrap\t--public\t--description\tLends tools to neighbours.')" \
      "$(printf 'api\t-i\trepos/octo-user/my-app/branches/main')" \
      "$(printf 'api\t-i\trepos/octo-user/my-app/contents/CHANGELOG.md')" \
      "$(printf 'api\t-i\t-X\tPUT\trepos/octo-user/my-app/branches/main/protection\t--input\t-')" \
      "$(printf 'repo\tedit\tocto-user/my-app\t--delete-branch-on-merge\t--enable-squash-merge')" \
      "$(printf 'api\t-i\trepos/octo-user/my-app/actions/permissions\t--jq\t.enabled')" \
      "$(printf 'repo\tclone\tocto-user/my-app\t./my-app')" \
      "$(printf 'api\t-i\tlicenses/mit\t--jq\t.body')" \
      "$(printf 'pr\tcreate\t--repo\tocto-user/my-app\t--base\tmain\t--head\tbootstrap-setup\t--title\tSet up my-app\t--body-file\t<file>')" \
      "$(printf 'pr\tchecks\t1\t--repo\tocto-user/my-app\t--json\tname,bucket,event\t--jq\t%s' "$BUILD_JQ")" \
      "$(printf 'api\t-i\trepos/octo-user/my-app/branches/main/protection\t--jq\t%s' "$READBACK_JQ")" \
      "$(printf 'pr\tmerge\t1\t--squash\t--delete-branch\t--match-head-commit\t<sha>')" \
      "$(printf 'api\t-i\trepos/octo-user/my-app/pulls/1\t--jq\t%s' "$MERGED_JQ")" | LC_ALL=C sort)" ] \
    || { cat "$d/gh.log" >&2; die "gh was used for more than its checks and the steps built so far"; }
  [ "$(cut -f1 "$d/gh.log" | LC_ALL=C sort -u)" = GH_PROMPT_DISABLED=1 ] \
    || { cat "$d/gh.log" >&2; die "a gh call ran with gh's prompts on"; }
  [ "$(ls -A "$d/cwd")" = my-app ] || { ls -A "$d/cwd" >&2; die "something other than the copy was made"; }
  [ -f "$d/cwd/my-app/package.json" ] || die "the node pack was not laid out in the copy"
}

test_running_with_no_options_starts_the_questions() {
  local d rc=0
  d="$(tmpdir)"
  make_stub_gh "$d/gh"
  ( export STUB_GH_LOG="$d/gh.log" BOOTSTRAP_GH="$d/gh"
    bash "$SCRIPT" ) </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 2 ] || { cat "$d/err" >&2; die "exit $rc, want 2 (no answer)"; }
  grep -q '^Project name: $' "$d/out" || { cat "$d/out" >&2; die "the first question was not asked"; }
}

test_unknown_option_is_refused() {
  local d
  d="$(tmpdir)"
  inputs "$d" --nmae my-app
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -E '^What happened: .*--nmae' >/dev/null || { cat "$d/err" >&2; die "the option is not named"; }
  grep -qE '^What to do next: .*--help' "$d/err" || { cat "$d/err" >&2; die "no pointer to --help"; }
}

test_option_without_its_value_is_refused() {
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -E '^What happened: .*--name.*needs a value' >/dev/null || { cat "$d/err" >&2; die "not explained"; }
  d="$(tmpdir)"
  inputs "$d" --non-interactive --description "" --name my-app
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "empty value: exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -E '^What happened: .*--description.*needs a value' >/dev/null || { cat "$d/err" >&2; die "empty value not explained"; }
}

test_switch_given_a_value_is_refused() {
  local d
  d="$(tmpdir)"
  inputs "$d" --yes=no
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -E '^What happened: .*--yes' >/dev/null || { cat "$d/err" >&2; die "not explained"; }
}

test_a_word_that_is_not_an_option_gets_what_happened_and_what_to_do_next() {
  # S18b: a bare word (here the name without --name) got the plain usage
  # text; it gets the message every other option problem gets, naming
  # the word, with exit code 2.
  local d rc=0
  d="$(tmpdir)"
  bash "$SCRIPT" my-app </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 2 ] || { cat "$d/err" >&2; die "exit $rc, want 2"; }
  sed -n 1p "$d/err" | grep -E '^What happened: .*my-app' >/dev/null || { cat "$d/err" >&2; die "the word is not named"; }
  sed -n 2p "$d/err" | grep -E '^What to do next: .*--help' >/dev/null || { cat "$d/err" >&2; die "no next action pointing to --help"; }
  ! grep -qF 'usage:' "$d/err" || { cat "$d/err" >&2; die "the plain usage text was shown"; }
}

test_help_lists_every_option() {
  local d rc=0 o
  d="$(tmpdir)"
  bash "$SCRIPT" --help </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 0 ] || { cat "$d/err" >&2; die "exit $rc, want 0"; }
  for o in --name --owner --project-name --description --po-name --pack --with-deploy --without-deploy \
    --public --private --license --copyright-holder --dir --ci-timeout --non-interactive \
    --yes --dry-run --resume --help --git-name --git-email layout-pack; do
    grep -qF -- "$o" "$d/out" || { cat "$d/out" >&2; die "help lacks $o"; }
  done
  # S18b: --non-interactive alone is refused, so the help says what it needs.
  grep -qF -- "(needs --yes or --dry-run)" "$d/out" || { cat "$d/out" >&2; die "help does not say --non-interactive needs --yes or --dry-run"; }
}

test_help_stays_plain_with_the_colour_hook() {
  local d rc=0
  d="$(tmpdir)"
  BOOTSTRAP_COLOR=1 TERM=xterm bash "$SCRIPT" --help </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 0 ] || { cat "$d/err" >&2; die "exit $rc, want 0"; }
  ! has_esc "$d/out" || die "the help has colour codes"
  bash "$SCRIPT" --help </dev/null >"$d/plain"
  cmp -s "$d/plain" "$d/out" || { diff "$d/plain" "$d/out" >&2; die "the help changed with the hook"; }
}

# --version (product owner, 2026-10-27): one line with the version and
# the template commit the script was built from, exit 0, before any
# check, question, network or gh call. The unstamped script in the
# template says it is not a release.
UNSTAMPED_VERSION_LINE='bootstrap-project.sh, not a release: the copy in factoincognito/ai-project-template-v2 that releases are built from'

# version_run <dir> <script> <options...>: runs the script with the
# options and stdin empty; gh, git, npm, curl, wget and the runner of
# offered commands are stand-ins that log each call (gh.log, tools.log,
# npm.log, run.log). RC is the exit code.
version_run() {
  local d="$1" s="$2" t
  shift 2
  make_stub_gh "$d/gh"
  make_stub_run "$d/run"
  make_stub_npm "$d/npm"
  for t in git npm curl wget; do fake_tool "$d" "$t"; done
  RC=0
  ( export PATH="$d/bin:$PATH" STUB_GH_LOG="$d/gh.log" BOOTSTRAP_GH="$d/gh" STUB_RUN_LOG="$d/run.log" \
      BOOTSTRAP_RUN="$d/run" STUB_NPM_LOG="$d/npm.log" BOOTSTRAP_NPM="$d/npm"
    bash "$s" "$@" ) </dev/null >"$d/out" 2>"$d/err" || RC=$?
}

# expect_version_line <dir> <line>: exit 0, exactly that line on stdout,
# nothing on stderr, and no tool was called.
expect_version_line() {
  local d="$1" f
  [ "$RC" -eq 0 ] || { cat "$d/out" "$d/err" >&2; die "exit $RC, want 0"; }
  [ "$(cat "$d/out")" = "$2" ] && [ "$(wc -l <"$d/out" | tr -d ' ')" -eq 1 ] \
    || { cat "$d/out" >&2; die "stdout is not the one line: $2"; }
  [ ! -s "$d/err" ] || { cat "$d/err" >&2; die "wrote to stderr"; }
  for f in gh.log tools.log npm.log run.log; do
    [ ! -s "$d/$f" ] || { cat "$d/$f" >&2; die "a tool was called ($f)"; }
  done
}

test_version_prints_one_line_and_calls_nothing() {
  local d
  d="$(tmpdir)"
  version_run "$d" "$SCRIPT" --version
  expect_version_line "$d" "$UNSTAMPED_VERSION_LINE"
  # Plain, also where colour is forced, as the help is.
  BOOTSTRAP_COLOR=1 TERM=xterm bash "$SCRIPT" --version </dev/null >"$d/colour" 2>&1
  cmp -s "$d/out" "$d/colour" || { diff "$d/out" "$d/colour" >&2; die "the line changed with the colour hook"; }
  # The built script, as a user gets it: its stamped version and commit.
  built_bootstrapper
  d="$(tmpdir)"
  version_run "$d" "$BUILT/bootstrap-project.sh" --version
  expect_version_line "$d" "bootstrap-project.sh $BUILT_VERSION, built from factoincognito/ai-project-template-v2@0123456789abcdef0123456789abcdef01234567"
}

test_version_with_other_options_is_read_where_it_stands_as_help_is() {
  # Like --help: the options are read in order; the first of --version
  # and --help ends the run there, so the options after it are not read,
  # and a wrong option before it is refused as in any run.
  local d
  d="$(tmpdir)"
  version_run "$d" "$SCRIPT" --non-interactive --yes --resume --name my-app --version --pack nope --nmae x
  expect_version_line "$d" "$UNSTAMPED_VERSION_LINE"
  d="$(tmpdir)"
  version_run "$d" "$SCRIPT" --version --help
  expect_version_line "$d" "$UNSTAMPED_VERSION_LINE"
  d="$(tmpdir)"
  version_run "$d" "$SCRIPT" --help --version
  [ "$RC" -eq 0 ] || { cat "$d/err" >&2; die "--help --version: exit $RC, want 0"; }
  [ "$(sed -n 1p "$d/out")" = "usage: bootstrap-project.sh [options]" ] || { cat "$d/out" >&2; die "--help --version: not the help"; }
  ! grep -qF 'not a release' "$d/out" || { cat "$d/out" >&2; die "--help --version: the version line was shown too"; }
  d="$(tmpdir)"
  version_run "$d" "$SCRIPT" --nmae x --version
  [ "$RC" -eq 2 ] || { cat "$d/out" "$d/err" >&2; die "--nmae x --version: exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -E '^What happened: .*--nmae' >/dev/null || { cat "$d/err" >&2; die "--nmae x --version: not refused"; }
  [ ! -s "$d/out" ] || { cat "$d/out" >&2; die "--nmae x --version: something on stdout"; }
  d="$(tmpdir)"
  version_run "$d" "$SCRIPT" --version=yes
  [ "$RC" -eq 2 ] || { cat "$d/out" "$d/err" >&2; die "--version=yes: exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -E '^What happened: The option --version does not take a value\.$' >/dev/null \
    || { cat "$d/err" >&2; die "--version=yes: not refused"; }
}

test_help_lists_the_version_option() {
  local d rc=0
  d="$(tmpdir)"
  bash "$SCRIPT" --help </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 0 ] || { cat "$d/err" >&2; die "exit $rc, want 0"; }
  grep -qE '^  --version +[a-z]' "$d/out" || { cat "$d/out" >&2; die "help lacks --version"; }
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
  refuses --name node_modules NODE_MODULES
}

test_name_longer_than_github_allows_is_refused() {
  # #146 review note: GitHub's "Creating a new repository" doc says the
  # name "must not exceed 100 characters" (npm's 214 is the looser limit).
  local long100 long101
  long100="a$(printf '%099d' 0)"
  long101="a$(printf '%0100d' 0)"
  refuses --name "$long101" "a.$(printf '%099d' 0)"
  accepts --name "$long100" "NAME=$long100"
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

test_without_deploy_gives_the_answer_no_to_the_publishing_files() {
  # End-to-end run 1 (repeat), r1e: a no to the publishing files could not
  # be given as an option, so the command to continue could not carry it
  # and the resumed run asked again. --without-deploy is that no.
  local d
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name x --description "x y." --pack web --license mit --owner a --po-name b --without-deploy
  expect_inputs "$d" PACK=web WITH_DEPLOY=no
  # Given, it is not asked.
  d="$(tmpdir)"
  printf '%s\n' "" "" "" "" "" "" "" "" >"$d/in"
  inputs "$d" --name x --description "x y." --pack web --license mit --without-deploy
  expect_inputs "$d" PACK=web WITH_DEPLOY=no
  ! grep -qF 'Add the publishing files' "$d/out" || { cat "$d/out" >&2; die "the publishing question was asked although --without-deploy was given"; }
  # Another pack has no publishing files, so the no does no harm.
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b --without-deploy
  expect_inputs "$d" PACK=node WITH_DEPLOY=no
  # Not with --with-deploy, and it takes no value.
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name x --description "x y." --pack web --license mit --owner a --po-name b --with-deploy --without-deploy
  expect_refused "$d" --without-deploy
  d="$(tmpdir)"
  inputs "$d" --non-interactive --name x --description "x y." --pack web --license mit --owner a --po-name b --without-deploy=yes
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "--without-deploy=yes: exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep -F 'What happened: The option --without-deploy does not take a value.' >/dev/null || { cat "$d/err" >&2; die "--without-deploy=yes is not refused as an option without a value"; }
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
  # #146 review note: an Enterprise Managed User's login is the user name,
  # an underscore and the enterprise's short code, as in mona-cat_octo
  # (GitHub's "Username considerations for external authentication").
  refuses --owner "my org" a/b -acme ac.me _acme
  accepts --owner Acme-Inc OWNER=Acme-Inc
  accepts --owner mona-cat_octo OWNER=mona-cat_octo
  accepts --owner ac_me OWNER=ac_me
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
  printf '%s\n' my-app "My App" "Lends tools to neighbours." "" "" web y private mit "" "" \
    "Ada Lovelace" ada@example.com >"$d/in"
  inputs "$d"
  expect_inputs "$d" NAME=my-app "PROJECT_NAME=My App" "DESCRIPTION=Lends tools to neighbours." \
    OWNER=octo-user "PO_NAME=Octo User" PACK=web WITH_DEPLOY=yes VISIBILITY=private \
    LICENSE=mit "COPYRIGHT_HOLDER=Octo User" DIR=./my-app CI_TIMEOUT=20 NON_INTERACTIVE= \
    "GIT_NAME=Ada Lovelace" GIT_EMAIL=ada@example.com
  [ "$(grep -c ': $' "$d/out")" -eq 13 ] || { cat "$d/out" >&2; die "not 13 questions"; }
}

test_an_empty_answer_takes_the_default_shown() {
  local d
  d="$(tmpdir)"
  printf '%s\n' my-app "" "Lends tools." "" "" python "" mit "" "" "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" PROJECT_NAME=my-app OWNER=octo-user "PO_NAME=Octo User" VISIBILITY=public \
    "COPYRIGHT_HOLDER=Octo User" DIR=./my-app WITH_DEPLOY=no "GIT_NAME=Test Person" \
    GIT_EMAIL=test@example.com
  grep -qxF 'Display name [my-app]: ' "$d/out" || { cat "$d/out" >&2; die "default not shown"; }
  grep -qxF 'Owner [octo-user]: ' "$d/out" || { cat "$d/out" >&2; die "owner default not shown"; }
}

# line_above <file> <exact line>: the line just above the first line
# that is exactly <exact line> (a question's explanation).
line_above() {
  LINE="$2" awk '$0 == ENVIRON["LINE"] { print prev; found = 1; exit } { prev = $0 } END { if (!found) exit 1 }' "$1"
}

test_po_name_question_says_its_default_is_the_github_profile_name() {
  # End-to-end run 1, finding 4: the question did not say where its
  # default came from.
  local d why
  d="$(tmpdir)"
  printf '%s\n' my-app "" "Lends tools." "" "" python "" mit "" "" "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" "PO_NAME=Octo User"
  why="$(line_above "$d/out" 'Product owner name [Octo User]: ')" \
    || { cat "$d/out" >&2; die "the product owner question with its default was not asked"; }
  [ "$why" = "The name of the product owner, the person who decides what the project should do (usually you). The default is the name on the GitHub profile of octo-user, the account gh is signed in to." ] \
    || { cat "$d/out" >&2; die "the explanation does not say the default is the profile name: [$why]"; }
}

test_po_name_question_says_its_default_is_the_account_name_when_the_profile_has_none() {
  local d why
  d="$(tmpdir)"
  export STUB_GH_NAME=""
  printf '%s\n' my-app "" "Lends tools." "" "" python "" mit "" "" "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" PO_NAME=octo-user
  why="$(line_above "$d/out" 'Product owner name [octo-user]: ')" \
    || { cat "$d/out" >&2; die "the product owner question with its default was not asked"; }
  [ "$why" = "The name of the product owner, the person who decides what the project should do (usually you). The default is octo-user, the name of the GitHub account gh is signed in to, because its profile has no name." ] \
    || { cat "$d/out" >&2; die "the explanation does not say the default is the account name: [$why]"; }
}

test_answers_have_spaces_and_carriage_returns_removed() {
  local d cr
  d="$(tmpdir)"
  cr="$(printf '\r')"
  printf '%s\n' "  my-app $cr" "My App$cr" "Lends tools.$cr" "acme$cr" "Ada$cr" "node$cr" \
    "public$cr" "none$cr" "work$cr" " Ada L $cr" "ada@example.com$cr" >"$d/in"
  inputs "$d"
  expect_inputs "$d" NAME=my-app "PROJECT_NAME=My App" "DESCRIPTION=Lends tools." OWNER=acme \
    PO_NAME=Ada PACK=node VISIBILITY=public LICENSE=none DIR=./work "GIT_NAME=Ada L" \
    GIT_EMAIL=ada@example.com
}

test_questions_are_skipped_for_inputs_given_as_options() {
  local d
  d="$(tmpdir)"
  # Asked: display name, description, owner, PO name, visibility, folder,
  # git name and email.
  # Not asked: deploy files (python) and copyright holder (licence none).
  printf '%s\n' "" "Lends tools." "" "" "" "" "" "" >"$d/in"
  inputs "$d" --name my-app --pack python --license none
  expect_inputs "$d" NAME=my-app PACK=python LICENSE=none "DESCRIPTION=Lends tools." WITH_DEPLOY=no \
    "COPYRIGHT_HOLDER=Octo User"
  [ "$(grep -c ': $' "$d/out")" -eq 8 ] || { cat "$d/out" >&2; die "not 8 questions"; }
  ! grep -qE '^(Project name|Language pack|Licence|Add the publishing files|Copyright holder)' "$d/out" \
    || { cat "$d/out" >&2; die "asked for something given or not needed"; }
}

test_a_wrong_answer_is_explained_and_asked_again() {
  local d t
  d="$(tmpdir)"
  printf '%s\n' "my app" my-app "" "" "Lends tools." "" "" ruby 2 maybe n "" 7 mit "" "" "" "" >"$d/in"
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
  printf '%s\n' my-app "" "Lends tools." "" "" 4 "" 6 "" "" "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" PACK=react-native LICENSE=polyform-noncommercial-1.0.0
  d="$(tmpdir)"
  printf '%s\n' my-app "" "Lends tools." "" "" 1 "" 1 "" "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" PACK=node LICENSE=none
  d="$(tmpdir)"
  printf '%s\n' my-app "" "Lends tools." "" "" python 2 agpl-3.0 "" "" "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" PACK=python VISIBILITY=private LICENSE=agpl-3.0
}

test_running_out_of_answers_stops_with_exit_2() {
  local d
  d="$(tmpdir)"
  printf '%s\n' my-app >"$d/in"
  inputs "$d"
  [ "$RC" -eq 2 ] || { cat "$d/err" >&2; die "exit $RC, want 2"; }
  sed -n 1p "$d/err" | grep '^What happened: .*a question got no answer' >/dev/null || { cat "$d/err" >&2; die "not explained"; }
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
  printf '%s\n' my-app "" "Lends tools." "" "" web "" "" mit "" "" "" "" >"$d/in"
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

# ---------- guided preflight: checks on this computer ----------
# Before anything is created the script checks this computer: bash 3.2 or
# later, git, gh (new enough to create a project from a template), npm for
# the node, web and react-native packs, and the target folder. A check
# that fails prints a guide (numbered steps for the OS, why, what the user
# sees when it worked, what to do otherwise, how the script checks it),
# then waits for Enter and checks again, until it passes or the user
# stops; then it prints the command to start again (exit 3). With
# --non-interactive it prints the guide and exits 3 at once. A command
# the script can run itself is offered, and run (through BOOTSTRAP_RUN)
# only after a yes read from the terminal (BOOTSTRAP_TTY), never from
# stdin and never because of --yes.
#
# `pre <dir> <command...>` runs a function of the loaded script after
# detect_os, with PATH="<dir>/bin:<GIT_ONLY_DIR>:/usr/bin:/bin" (so only
# the fake tools a test makes, git, and the system's own are found:
# no brew or winget unless faked), a stub gh, a stub runner and a stub npm (BOOTSTRAP_NPM, the
# npm the lockfile step runs; the check that npm is installed uses a fake
# npm on PATH), stdin from <dir>/in, the terminal from <dir>/tty and the
# Linux release file from <dir>/os-release when they exist, in <dir>/cwd
# with the fake home <dir>/home. stdout goes to <dir>/out, stderr to
# <dir>/err, the runner's log to <dir>/run.log, npm's to <dir>/npm.log.
# `whole <dir> <options...>` does the same for the whole script (or for
# $RUN_SCRIPT when a test sets it: see use_built).

prepare() {
  local d="$1"
  [ -e "$d/in" ] || : >"$d/in"
  [ -x "$d/gh" ] || make_stub_gh "$d/gh"
  [ -x "$d/run" ] || make_stub_run "$d/run"
  [ -x "$d/npm" ] || make_stub_npm "$d/npm"
  [ -d "$d/home" ] || fake_home "$d/home" "Test Person" test@example.com
  [ -d "$d/cwd" ] && [ -d "$d/bin" ] || mkdir -p "$d/cwd" "$d/bin"
  : >>"$d/run.log"
  : >>"$d/npm.log"
}

# in_env <dir>: the environment of a run, in the current subshell.
in_env() {
  local d="$1"
  cd "$d/cwd"
  use_home "$d/home"
  export PATH="$d/bin:$GIT_ONLY_DIR:/usr/bin:/bin" STUB_GH_LOG="$d/gh.log" BOOTSTRAP_GH="$d/gh" \
    STUB_RUN_LOG="$d/run.log" BOOTSTRAP_RUN="$d/run" STUB_SLEEP_LOG="$d/sleep.log" \
    STUB_NPM_LOG="$d/npm.log" BOOTSTRAP_NPM="$d/npm"
  # git never looks above the harness's own temp folder for a project,
  # so a test sees only the git projects it made itself.
  export GIT_CEILING_DIRECTORIES="$WORK"
  [ ! -e "$d/tty" ] || export BOOTSTRAP_TTY="$d/tty"
  [ ! -e "$d/os-release" ] || export BOOTSTRAP_OS_RELEASE="$d/os-release"
  # WSL (Linux on Windows) is read from <dir>/kernel-release, never from
  # this computer's own (on_wsl writes one), and the Windows drives are
  # <dir>/drives: so a test runs the same on a computer that is WSL.
  export BOOTSTRAP_KERNEL_RELEASE="$d/kernel-release" BOOTSTRAP_WINDOWS_DRIVES="$d/drives"
  # Temporary files go to <dir>/tmp, so a test can see what is left there.
  [ -d "$d/tmp" ] || mkdir -p "$d/tmp"
  export TMPDIR="$d/tmp"
  # RUN_CWD: a test that runs the script from another folder (such as
  # inside the copy) sets it.
  [ -z "${RUN_CWD:-}" ] || cd "$RUN_CWD"
}

test_a_run_finds_git_and_what_git_needs_for_a_copy_on_this_computer() {
  # A run's PATH is cut down to the fake tools and the system's own, but
  # git must be on it, as on every user's computer, and so must the
  # helpers git starts to copy from and send to a project in a folder
  # (git-upload-pack, git-receive-pack). Git for Windows keeps git and
  # both helpers in /mingw64/bin, which is not /usr/bin or /bin: there the
  # first run found no git at all, and the stub's projects, copied with
  # the real git, stopped with "git-upload-pack: command not found".
  local d bare
  d="$(tmpdir)"
  prepare "$d"
  bare="$d/a remote.git"
  "$REAL_GIT" -c init.defaultBranch=main init -q --bare "$bare"
  ( in_env "$d"
    command -v git >/dev/null || die "no git on the run's PATH"
    git -c init.defaultBranch=main init -q "$d/w"
    printf 'x\n' >"$d/w/f"
    git -C "$d/w" add f
    git -C "$d/w" -c user.name=T -c user.email=t@example.com commit -q -m one
    git -C "$d/w" push -q "$bare" main || die "git could not send to a project in a folder"
    git clone -q "$bare" "$d/c" || die "git could not copy a project from a folder"
    [ "$(cat "$d/c/f")" = x ] || die "the copy lacks the file" ) || exit 1
}

test_the_git_folder_of_a_run_holds_only_git_and_its_helpers() {
  # git's own folder holds other tools too: Homebrew's /opt/homebrew/bin
  # holds brew and gh, Git for Windows' /mingw64/bin many more. With that
  # folder on a run's PATH, the macOS runner's brew was found, and the
  # script offered and ran "brew install gh" in a test that has no brew.
  # So a run gets a folder of its own that holds only git and the two
  # helpers, each running the real one.
  local d src
  d="$(tmpdir)"
  src="$d/tools of git"
  mkdir -p "$src"
  for t in git git-upload-pack git-receive-pack brew gh winget npm; do
    printf '%s\n' '#!/bin/sh' "echo \"$t \$*\"" >"$src/$t"
    chmod +x "$src/$t"
  done
  make_git_only_dir "$src" "$d/only"
  [ "$(cd "$d/only" && ls | LC_ALL=C sort | tr '\n' ' ')" = "git git-receive-pack git-upload-pack " ] \
    || { ls -A "$d/only" >&2; die "the folder holds more than git and its helpers"; }
  for t in git git-upload-pack git-receive-pack; do
    [ "$("$d/only/$t" a 'b c')" = "$t a b c" ] || die "$t does not run the real $t with its arguments"
  done
  # A helper that git's folder does not hold (git finds it in its own
  # exec-path there) is left out.
  rm "$src/git-upload-pack"
  make_git_only_dir "$src" "$d/only2"
  [ ! -e "$d/only2/git-upload-pack" ] || die "a helper that is not there was made"
  [ -e "$d/only2/git" ] || die "git was not made"
}

test_every_stand_in_starts_the_harness_bash_directly() {
  # PBI-1.22: a stand-in started through /usr/bin/env costs two process
  # starts per call (env, then bash); on Windows each start is about
  # 30 ms. Every stand-in the harness writes names the harness's own bash
  # on its first line instead (env only for a bash path with a space).
  local d want f hits
  # The choice, for this bash and for paths env is kept for.
  [ "$(stand_in_shebang /usr/bin/bash)" = '#!/usr/bin/bash' ] || die "an absolute path is not named"
  [ "$(stand_in_shebang '/c/Program Files/Git/usr/bin/bash')" = '#!/usr/bin/env bash' ] || die "a path with a space is named"
  [ "$(stand_in_shebang bash)" = '#!/usr/bin/env bash' ] || die "a path that is not absolute is named"
  [ "$(stand_in_shebang '')" = '#!/usr/bin/env bash' ] || die "an empty path is named"
  want="$(stand_in_shebang "$BASH")"
  [ "$STAND_IN_SHEBANG" = "$want" ] || die "STAND_IN_SHEBANG is '$STAND_IN_SHEBANG', want '$want'"
  # Every stand-in in this file takes its first line from
  # STAND_IN_SHEBANG: apart from the file's own first line and
  # stand_in_shebang, no line writes a bash shebang of its own.
  # Read with awk, which skips this test and stand_in_shebang.
  hits="$(awk -v me="${FUNCNAME[0]}" '
    $0 ~ "^(" me "|stand_in_shebang)\\(\\) \\{" { skip = 1 }
    skip && /^}/ { skip = 0; next }
    skip || NR == 1 { next }
    /#!\/usr\/bin\/env bash|#!\/bin\/bash/ { print NR ": " $0 }
  ' "$HERE/test-bootstrap-project.sh")"
  [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "a stand-in writes its own bash shebang"; }
  d="$(tmpdir)"
  # Each file as the harness wrote it, checked where it was written.
  first_line_is() {
    [ -x "$1" ] || die "$2 is not executable"
    [ "$(sed -n 1p "$1")" = "$want" ] || die "$2 starts with '$(sed -n 1p "$1")', want '$want'"
  }
  make_stub_gh "$d/s/gh"; first_line_is "$d/s/gh" "the stub gh"
  make_stub_run "$d/s/run"; first_line_is "$d/s/run" "the stub runner"
  make_stub_npm "$d/s/npm"; first_line_is "$d/s/npm" "the stub npm"
  make_refuser "$d/s/refuser" BOOTSTRAP_GH; first_line_is "$d/s/refuser" "a refuser"
  first_line_is "$WORK/refuse/gh" "the gh refuser"; first_line_is "$WORK/refuse/sleep" "the sleep stand-in"
  fake_tool "$d" git; first_line_is "$d/bin/git" "the fake git"
  fake_tool "$d" uname Linux; first_line_is "$d/bin/uname" "a fake tool"
  failing_push "$d" auth; first_line_is "$d/push-hook" "the failing-push hook"
  finish_hook "$d" offline; first_line_is "$d/push-hook" "the finish hook"
  use_built "$d"; first_line_is "$d/bin/date" "the fake date"
}

test_write_stand_in_refuses_a_path_with_no_folder_and_makes_its_folder() {
  # Error path of write_stand_in (#224 review): a path with no folder
  # would make a folder named like the file, so it stops instead and
  # writes nothing; a folder that is missing is made, as make_stub_gh
  # "$d/stub bin/gh" needs.
  local d rc=0
  d="$(tmpdir)"
  ( cd "$d" && write_stand_in no-folder 'exit 0' ) 2>"$d/err" || rc=$?
  [ "$rc" -ne 0 ] || die "a path with no folder was accepted"
  grep -qF "write_stand_in: 'no-folder' has no folder" "$d/err" || { cat "$d/err" >&2; die "the refusal does not say why"; }
  [ ! -e "$d/no-folder" ] || die "something was made for a path with no folder"
  write_stand_in "$d/new folder/tool" 'echo ran'
  [ "$("$d/new folder/tool")" = ran ] || die "the stand-in in a new folder did not run"
}

test_fake_home_writes_what_git_config_writes_without_starting_git() {
  # PBI-1.22: fake_home runs in nearly every test. For a plain name and
  # email it writes the settings file itself, byte for byte as
  # git config --file writes it; any other value still goes through git.
  local d v
  d="$(tmpdir)"
  for v in "Test Person|test@example.com" "Grace Hopper|grace@example.com" "Grace Hopper|" "|grace@example.com" "|" \
    "Ada Lovelace-King 2|a.b_c@x-y.org"; do
    rm -rf "$d/want" "$d/got"
    mkdir -p "$d/want"; : >"$d/want/.gitconfig"
    [ -z "${v%%|*}" ] || "$REAL_GIT" config --file "$d/want/.gitconfig" user.name "${v%%|*}"
    [ -z "${v#*|}" ] || "$REAL_GIT" config --file "$d/want/.gitconfig" user.email "${v#*|}"
    ( REAL_GIT="$d/no-git"; fake_home "$d/got" "${v%%|*}" "${v#*|}" ) 2>"$d/err" || true
    cmp -s "$d/want/.gitconfig" "$d/got/.gitconfig" \
      || { od -c "$d/want/.gitconfig" "$d/got/.gitconfig" >&2; cat "$d/err" >&2; die "fake_home '$v' differs from git config"; }
  done
  # A value git quotes or escapes still goes through git config.
  for v in 'Ada "the first"' ' lead' 'trail ' 'semi;colon' 'hash#tag' 'back\slash'; do
    rm -rf "$d/got"
    fake_home "$d/got" "$v" ada@example.com
    [ "$("$REAL_GIT" config --file "$d/got/.gitconfig" user.name)" = "$v" ] || die "fake_home lost the name '$v'"
  done
}

test_a_failing_push_hook_counts_down_and_names_its_mode() {
  # The push hook reads its counter and mode with builtins (PBI-1.22):
  # it fails that many pushes with the mode's text, then lets them run.
  local d rc want
  d="$(tmpdir)"
  failing_push "$d" offline 2
  for want in 128 128 0; do
    rc=0; "$d/push-hook" -C x push origin main 2>"$d/err" || rc=$?
    [ "$rc" -eq "$want" ] || die "exit $rc, want $want"
  done
  rc=0; "$d/push-hook" -C x status 2>"$d/err" || rc=$?
  [ "$rc" -eq 0 ] || die "a call without push failed"
  failing_push "$d" offline 1
  "$d/push-hook" push 2>"$d/err" || true
  grep -qF 'Could not resolve host: github.com' "$d/err" || { cat "$d/err" >&2; die "the offline text is missing"; }
  [ "$(grep -c . "$d/push-prompt")" -eq 4 ] || die "not every push recorded GIT_TERMINAL_PROMPT"
}

test_a_run_has_no_brew_or_winget_unless_a_test_fakes_them() {
  # The guides offer a command only where brew (macOS) or winget
  # (Windows) is found; tests without them rely on the run's PATH having
  # neither, whatever the runner has installed.
  local d
  d="$(tmpdir)"
  prepare "$d"
  ( in_env "$d"
    ! command -v brew >/dev/null 2>&1 || die "brew is on the run's PATH: $(command -v brew)"
    ! command -v winget >/dev/null 2>&1 || die "winget is on the run's PATH: $(command -v winget)"
    # The same git on every OS: the wrapper, so it is what the tests run.
    [ "$(command -v git)" = "$GIT_ONLY_DIR/git" ] || die "git on the run's PATH is not the wrapper: $(command -v git)" ) || exit 1
}

pre_from_stdin() {
  local d="$1"
  shift
  prepare "$d"
  set +e
  ( load_script; in_env "$d"; detect_os; "$@" ) >"$d/out" 2>"$d/err"
  RC=$?
  set -e
}

pre() {
  local d="$1"
  shift
  prepare "$d"
  pre_from_stdin "$d" "$@" <"$d/in"
}

# run_script_of <dir>: the script a whole run in <dir> runs: RUN_SCRIPT
# when a test set it (use_built), else a copy of the template's script in
# a folder of its own under WORK, named after <dir> without its spaces
# (as the script in this checkout had none). A stop saves its answers
# next to the script it ran (r2l), so a run never uses the script in
# this checkout itself: the file would land in bootstrap/stubs/.
run_script_of() {
  local base="${1##*/}"
  printf '%s\n' "${RUN_SCRIPT:-$WORK/scripts/${base// /}/bootstrap-project.sh}"
}

# long_of <dir> <line>: a command line as shown, with a short command
# (r2l: the script with --again) written out as the long one it stands
# for: the words saved in the file that --again reads, quoted as the
# script quotes them. Another line is printed as it is. So the tests of
# what a command to start again or to continue carries read what --again
# will carry.
long_of() {
  local d="$1" line f
  # The cd to the folder the run started in (#267 review, B1) is checked
  # and taken off: the tests of what a command carries read the rest.
  line="$(strip_cd "$d" "$2")"
  case "$line" in
    "    bash "*" --again" | "    bash "*" --again "* | "bash "*" --again" | "bash "*" --again "*) ;;
    *) printf '%s\n' "$line"; return 0 ;;
  esac
  f="$(again_file_of "$d")"
  [ -f "$f" ] || die "the short command was shown, and there is no saved file $f: $line"
  ( load_script
    head="${line%% --again*}"
    rest="${line#"$head --again"}"
    while IFS= read -r w; do quote_word "$w"; head="$head $QUOTED"; done <"$f"
    printf '%s\n' "$head$rest" )
}

# strip_cd <dir> <line>: the shown line without the cd to the run's
# folder in front of it; a cd to another folder fails the test.
strip_cd() {
  local cdp lead=""
  case "$2" in "    "*) lead="    " ;; esac
  case "${2#    }" in
    "cd "*)
      cdp="$(start_cd_of "$1")"
      case "${2#    }" in "$cdp"*) printf '%s%s\n' "$lead" "${2#"$lead$cdp"}" ;; *) die "the cd in front of the command is not to the run's folder ($cdp): $2" ;; esac
      ;;
    *) printf '%s\n' "$2" ;;
  esac
}

# strip_any_cd <line>: the shown line without the cd in front of it,
# whatever its folder, for again and advance_again: a test may run the
# next command from another folder on purpose (RUN_CWD), as a user who
# went there; the cd itself is tested in
# test_the_command_shown_goes_to_the_folder_the_script_started_in.
strip_any_cd() {
  case "$1" in
    "    cd "*" && bash "*) printf '    bash %s\n' "${1#* && bash }" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# shown_after <dir> <line>: the command shown right below that exact
# line of the output, written out (long_of).
shown_after() { long_of "$1" "$(grep -A1 -xF -- "$2" "$1/out" | sed -n 2p)"; }

whole() {
  local d="$1" s
  shift
  prepare "$d"
  s="$(run_script_of "$d")"
  if [ -z "${RUN_SCRIPT:-}" ] && [ ! -f "$s" ]; then mkdir -p "${s%/*}" && cp "$SCRIPT" "$s"; fi
  set +e
  ( in_env "$d"; "$BASH" "$s" "$@" ) <"$d/in" >"$d/out" 2>"$d/err"
  RC=$?
  set -e
}

# Settings for `pre`, run before the function they wrap.
ni() { OPT_NON_INTERACTIVE=1; "$@"; }
yes_opt() { OPT_YES=1; "$@"; }
resume() { OPT_RESUME=1; "$@"; }
with_pack() { IN_PACK="$1"; shift; "$@"; }
with_dir() { IN_DIR="$1"; shift; "$@"; }
# path_first <folder>: the folder comes first on the run's PATH.
path_first() { PATH="$1:$PATH"; shift; "$@"; }
# in_folder <folder>: the run goes on in that folder.
in_folder() { cd "$1"; shift; "$@"; }
# path_last <folder>: the folder comes last on the run's PATH.
path_last() { PATH="$PATH:$1"; shift; "$@"; }
# tty_answers: the Nth question asked at the terminal reads line N of
# <dir>/tty-answers (no line left: no answer), for a test whose answers
# differ from one question to the next; the test makes <dir>/tty too.
# The script's own ask_terminal still reads them.
tty_answers() {
  eval "real_ask_terminal() $(declare -f ask_terminal | sed 1d)"
  TTY_ASKED=0
  ask_terminal() {
    TTY_ASKED=$((TTY_ASKED + 1))
    sed -n "${TTY_ASKED}p" "$BOOTSTRAP_TTY-answers" >"$BOOTSTRAP_TTY"
    real_ask_terminal "$@"
  }
  "$@"
}

# on_os <dir> <macos|linux|windows> [debian|fedora|arch|suse|other]: the
# OS the script sees, through a fake uname and release file.
on_os() {
  local d="$1" os="$2" distro="${3:-debian}"
  case "$os" in
    macos) fake_tool "$d" uname Darwin ;;
    linux) fake_tool "$d" uname Linux ;;
    windows) fake_tool "$d" uname MINGW64_NT-10.0-19045 ;;
  esac
  case "$distro" in
    debian) printf '%s\n' 'NAME="Ubuntu"' 'ID=ubuntu' 'ID_LIKE=debian' >"$d/os-release" ;;
    fedora) printf '%s\n' 'NAME="Fedora Linux"' 'ID=fedora' >"$d/os-release" ;;
    arch) printf '%s\n' 'NAME="Arch Linux"' 'ID=arch' >"$d/os-release" ;;
    suse) printf '%s\n' 'NAME="openSUSE Leap"' 'ID="opensuse-leap"' 'ID_LIKE="suse opensuse"' >"$d/os-release" ;;
    other) printf '%s\n' 'NAME="Something"' 'ID=something' >"$d/os-release" ;;
  esac
}

# on_wsl <dir> [release]: Linux in WSL on Windows, as the script sees it
# (Ubuntu, and a kernel release as WSL 2 has it, unless given).
on_wsl() {
  on_os "$1" linux debian
  printf '%s\n' "${2:-5.15.167.4-microsoft-standard-WSL2}" >"$1/kernel-release"
}

# windows_npm <dir>: an npm as Windows' Node.js has it, in
# <dir>/drives/c/Program Files/nodejs (where WSL shows C:\Program Files),
# that logs "windows-npm <args>" to <dir>/tools.log and prints 11.16.0.
# Put its folder first on PATH with path_first "$(windows_npm_dir <dir>)".
windows_npm_dir() { printf '%s\n' "$1/drives/c/Program Files/nodejs/"; }
windows_npm() {
  write_stand_in "$(windows_npm_dir "$1")npm" "printf '%s\n' \"windows-npm \$*\" >>\"$1/tools.log\"
echo 11.16.0
"
}

# missing <dir> <tool> [times]: the fake <tool> fails as a missing
# command that many times (default: always), then works.
missing() { fake_tool "$1" "$2" 1.0.0; echo "${3:-9999}" >"$1/$2-fails"; }

# A git that works, from the fakes (it runs the real git).
working_git() { fake_tool "$1" git; }

expect_rc() {
  [ "$RC" -eq "$1" ] || { cat "$2/out" "$2/err" >&2; die "exit $RC, want $1"; }
}
expect_out() {
  grep -qF -- "$2" "$1/out" || { cat "$1/out" "$1/err" >&2; die "output lacks: $2"; }
}
expect_no_out() {
  ! grep -qF -- "$2" "$1/out" || { cat "$1/out" >&2; die "output has: $2"; }
}
expect_nothing_ran() {
  [ ! -s "$1/run.log" ] || { cat "$1/run.log" >&2; die "an offered command ran"; }
}

test_git_missing_is_guided_and_checked_again_after_enter() {
  local d
  d="$(tmpdir)"
  on_os "$d" linux debian
  missing "$d" git 1
  printf '\n' >"$d/in"
  pre "$d" preflight_git
  expect_rc 0 "$d"
  expect_out "$d" "git is not installed."
  expect_out "$d" "  1. "
  expect_out "$d" "Press Enter to check again, or type q to stop: "
  [ "$(tail -1 "$d/out")" = "    Done. git is installed." ] || { cat "$d/out" >&2; die "no done line after the check passed"; }
  [ "$(grep -c '^git --version' "$d/tools.log")" -eq 2 ] || { cat "$d/tools.log" >&2; die "git was not checked twice"; }
}

test_a_guide_shows_again_until_the_check_passes() {
  local d
  d="$(tmpdir)"
  on_os "$d" linux debian
  missing "$d" git 2
  printf '\n\n' >"$d/in"
  pre "$d" preflight_git
  expect_rc 0 "$d"
  [ "$(grep -c '^git is not installed\.$' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "the guide was not shown twice"; }
  [ "$(grep -c '^git --version' "$d/tools.log")" -eq 3 ] || die "git was not checked three times"
  # Each showing numbers its steps from 1 (#148 review, finding 1).
  [ "$(grep -c '^  1\. ' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "the second showing does not start at 1."; }
  ! grep -q '^  3\. ' "$d/out" || { cat "$d/out" >&2; die "the step numbers carried on into the second showing"; }
}

test_stopping_at_a_guide_prints_the_command_to_start_again() {
  # Typing q, or no more input, stops with exit 3 and the exact command
  # the user ran, quoted so it can be copied.
  local d input
  for input in 'q' 'Q' 'stop' ''; do
    d="$(tmpdir)"
    on_os "$d" linux debian
    missing "$d" git
    # Enter lines after the answer: q must stop at once, not read them.
    [ -z "$input" ] || printf '%s\n' "$input" "" "" >"$d/in"
    whole "$d" --name my-app --description "Lends tools." --pack node
    expect_rc 3 "$d"
    [ "$(grep -c '^git is not installed\.$' "$d/out")" -eq 1 ] \
      || { cat "$d/out" >&2; die "the guide was shown again after '$input'"; }
    expect_out "$d" "To start again, run this command:"
    shown_after "$d" "To start again, run this command:" \
      | grep -E "^    bash .*bootstrap-project\.sh --name my-app --description 'Lends tools\.' --pack node$" >/dev/null \
      || { cat "$d/out" >&2; die "the command to start again is not the one that was run (input '$input')"; }
    sed -n 1p "$d/err" | grep -E '^What happened: .*git is not installed' >/dev/null || { cat "$d/err" >&2; die "no plain message"; }
    grep -qE '^What to do next: .{10,}' "$d/err" || { cat "$d/err" >&2; die "no next action"; }
    [ -z "$(ls -A "$d/cwd")" ] || die "something was created"
  done
}

test_non_interactive_prints_the_guide_and_exits_3_without_waiting() {
  local d
  d="$(tmpdir)"
  on_os "$d" macos
  missing "$d" git
  printf '%s\n' "" "" first-unread >"$d/in"
  printf 'yes\n' >"$d/tty"
  pre "$d" ni preflight_git
  expect_rc 3 "$d"
  expect_out "$d" "git is not installed."
  expect_out "$d" "    xcode-select --install"
  expect_out "$d" "To start again, run this command:"
  expect_no_out "$d" "Press Enter"
  expect_no_out "$d" "Run it now?"
  expect_nothing_ran "$d"
  [ "$(grep -c '^git --version' "$d/tools.log")" -eq 1 ] || die "git was checked more than once"
}

test_non_interactive_never_reads_stdin_at_a_guide() {
  local d
  d="$(tmpdir)"
  on_os "$d" linux debian
  missing "$d" git
  printf '%s\n' first-line >"$d/in"
  prepare "$d"
  set +e
  ( load_script; in_env "$d"; detect_os
    ( ni preflight_git ) || true
    IFS= read -r line
    printf '%s\n' "$line" >"$d/first" ) <"$d/in" >"$d/out" 2>"$d/err"
  set -e
  [ "$(cat "$d/first")" = first-line ] || die "stdin was read at the guide"
}

test_an_offered_command_runs_after_yes_through_the_runner() {
  # macOS, git missing: the script offers to start Apple's installer. The
  # yes comes from the terminal; the runner logs instead of installing.
  # After it ran, the check runs again straight away.
  local d
  d="$(tmpdir)"
  on_os "$d" macos
  missing "$d" git 1
  printf 'yes\n' >"$d/tty"
  pre "$d" preflight_git
  expect_rc 0 "$d"
  [ "$(cat "$d/run.log")" = "xcode-select --install" ] || { cat "$d/run.log" >&2; die "the runner did not get the offered command"; }
  expect_out "$d" "Run it now? (yes or no) [no]: "
  expect_no_out "$d" "Press Enter"
  expect_out "$d" "    Done. git is installed."
}

test_answering_no_or_nothing_to_an_offer_runs_nothing() {
  local d answer
  for answer in no n "" maybe; do
    d="$(tmpdir)"
    on_os "$d" macos
    missing "$d" git
    printf '%s\n' "$answer" >"$d/tty"
    printf 'q\n' >"$d/in"
    pre "$d" preflight_git
    expect_rc 3 "$d"
    expect_nothing_ran "$d"
    expect_out "$d" "Not run."
  done
  # No terminal to read the answer from: not run either.
  d="$(tmpdir)"
  on_os "$d" macos
  missing "$d" git
  printf 'q\n' >"$d/in"
  pre "$d" preflight_git
  expect_rc 3 "$d"
  expect_nothing_ran "$d"
  expect_out "$d" "Not run."
}

test_the_yes_to_an_offer_is_read_from_the_terminal_not_from_stdin() {
  local d
  d="$(tmpdir)"
  on_os "$d" macos
  missing "$d" git
  : >"$d/tty"
  printf '%s\n' yes yes q >"$d/in"
  pre "$d" preflight_git
  expect_rc 3 "$d"
  expect_nothing_ran "$d"
}

test_the_yes_option_does_not_approve_an_install() {
  local d
  d="$(tmpdir)"
  on_os "$d" macos
  missing "$d" git
  printf 'q\n' >"$d/in"
  pre "$d" yes_opt preflight_git
  expect_rc 3 "$d"
  expect_nothing_ran "$d"
  expect_out "$d" "Run it now? (yes or no) [no]: "
}

test_a_command_is_offered_once_per_check() {
  # The offered command ran but did not fix it: the guide shows again,
  # without an offer straight away, and waits for Enter (the command may
  # still be working, as Apple's installer does in its own window). Once
  # per round: the next round offers again (the tests below).
  local d
  d="$(tmpdir)"
  on_os "$d" macos
  missing "$d" git 2
  printf 'yes\n' >"$d/tty"
  printf '\n' >"$d/in"
  pre "$d" preflight_git
  expect_rc 0 "$d"
  [ "$(grep -c . "$d/run.log")" -eq 1 ] || { cat "$d/run.log" >&2; die "the command was offered and run more than once"; }
  [ "$(grep -c 'Run it now?' "$d/out")" -eq 1 ] || die "offered more than once"
}

test_an_accidental_no_is_offered_again_and_a_yes_then_runs_it() {
  # End-to-end run 1: Enter at "Run it now?" by accident, then Enter to
  # check again, and the check still fails: the command is offered
  # again, and a yes at the terminal runs it.
  local d
  d="$(tmpdir)"
  on_os "$d" macos
  missing "$d" git 2
  : >"$d/tty"
  printf '%s\n' "" yes >"$d/tty-answers"
  printf '\n' >"$d/in"
  pre "$d" tty_answers preflight_git
  expect_rc 0 "$d"
  [ "$(grep -c 'Run it now?' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "not offered again after the no"; }
  [ "$(cat "$d/run.log")" = "xcode-select --install" ] || { cat "$d/run.log" >&2; die "the yes did not run the command once"; }
  [ "$(grep -c 'Press Enter to check again' "$d/out")" -eq 1 ] || { cat "$d/out" >&2; die "not one wait, after the no"; }
  [ "$(tail -1 "$d/out")" = "    Done. git is installed." ] || { cat "$d/out" >&2; die "no done line"; }
}

test_answering_no_every_time_reads_input_on_every_round() {
  # A no on every round never checks again without reading a line: each
  # round offers, then waits for Enter, and the end of the input stops.
  # The same without a terminal to read the answer from, and on Windows.
  local d os
  for os in macos none windows; do
    d="$(tmpdir)"
    on_os "$d" "${os/none/macos}"
    fake_tool "$d" winget
    missing "$d" git
    [ "$os" = none ] || printf 'no\n' >"$d/tty"
    printf '\n\n\n' >"$d/in"
    pre "$d" preflight_git
    expect_rc 3 "$d"
    expect_nothing_ran "$d"
    [ "$(grep -c 'Run it now?' "$d/out")" -eq 4 ] || { cat "$d/out" >&2; die "$os: not offered on each of the 4 rounds"; }
    [ "$(grep -c 'Press Enter to check again' "$d/out")" -eq 4 ] || { cat "$d/out" >&2; die "$os: not a wait on each round"; }
    [ "$(grep -c '^git --version' "$d/tools.log")" -eq 4 ] || { cat "$d/tools.log" >&2; die "$os: checked other than once per round"; }
  done
}

test_a_command_that_ran_is_offered_again_only_after_enter() {
  # A yes to each offer and a command that never fixes it: between two
  # runs there is always an Enter, so the end of the input stops it. The
  # terminal has 5 yeses, then no answer: without the Enter between two
  # runs this fails (5 runs) instead of going round for ever.
  local d
  d="$(tmpdir)"
  on_os "$d" macos
  missing "$d" git
  : >"$d/tty"
  printf '%s\n' yes yes yes yes yes >"$d/tty-answers"
  printf '\n\n' >"$d/in"
  pre "$d" tty_answers preflight_git
  expect_rc 3 "$d"
  [ "$(grep -c . "$d/run.log")" -eq 3 ] || { cat "$d/run.log" >&2; die "not run 3 times (one more than the Enters)"; }
  [ "$(grep -c 'Run it now?' "$d/out")" -eq 3 ] || { cat "$d/out" >&2; die "not offered 3 times"; }
  [ "$(grep -c 'Press Enter to check again' "$d/out")" -eq 3 ] || { cat "$d/out" >&2; die "not a wait after each run"; }
}

# The "Not run." lines: the offers whose guide says to come back to this
# window, and the winget installs, whose guide says to start the script
# again in a new Git Bash window (this window does not see the install).
NOT_RUN_TERMINAL="Not run. To run it yourself, open another terminal window (this one is waiting), run the command there, then come back here and press Enter to check again."
NOT_RUN_GIT_BASH="Not run. To run it yourself, open another Git Bash window (this one is waiting), run the command there, then come back here and press Enter to check again."
NOT_RUN_WINGET="Not run. To run it yourself, run it in another Git Bash window. When it has finished, type q here and copy the command the script shows to start again. Then close both windows, open Git Bash again from the Start menu, and run that command there."
NEW_WINDOW_NEEDED="The script cannot check again in this window, because a program installed with winget is found only in a Git Bash window opened after the install. Type q here and copy the command the script shows to start again. Then close this window, open Git Bash again from the Start menu, and run that command there."

test_not_run_says_where_to_run_the_command() {
  # This window waits for Enter, so the command runs in another one: a
  # terminal window on macOS, Git Bash on Windows for the gh refresh
  # (its guide says to come back to this window). A winget install is
  # found only in a new Git Bash window, as its guide says: its line
  # says to start again there, never to press Enter here.
  local d c want
  for c in macos-git windows-refresh windows-gh windows-gh-old windows-git; do
    d="$(tmpdir)"
    on_os "$d" "${c%%-*}"
    fake_tool "$d" winget
    printf 'no\n' >"$d/tty"
    printf 'q\n' >"$d/in"
    case "$c" in
      macos-git) missing "$d" git; pre "$d" preflight_git; want="$NOT_RUN_TERMINAL" ;;
      windows-refresh)
        export STUB_GH_SCOPES="repo"
        pre "$d" with_vis public preflight_github_permissions
        unset STUB_GH_SCOPES
        want="$NOT_RUN_GIT_BASH"
        ;;
      windows-gh) make_stub_gh "$d/gh"; echo 9999 >"$d/gh-missing"; working_git "$d"; pre "$d" preflight_gh; want="$NOT_RUN_WINGET" ;;
      windows-gh-old) make_stub_gh "$d/gh"; echo 9999 >"$d/gh-old"; working_git "$d"; pre "$d" preflight_gh; want="$NOT_RUN_WINGET" ;;
      windows-git) missing "$d" git; pre "$d" preflight_git; want="$NOT_RUN_WINGET" ;;
    esac
    expect_rc 3 "$d"
    expect_out "$d" "Run it now?"
    grep -qxF "$want" "$d/out" || { cat "$d/out" >&2; die "$c: the Not run line is not: $want"; }
    expect_no_out "$d" "Follow the steps above yourself."
    if [ "$want" = "$NOT_RUN_WINGET" ]; then expect_no_out "$d" "come back here and press Enter"; fi
  done
}

test_a_winget_install_that_ran_is_not_offered_again_in_this_window() {
  # Windows: after a yes to a winget install the check still fails (this
  # window does not see the install). Each round after it says to start
  # again in a new Git Bash window instead of offering the install again.
  local d c
  for c in gh-missing gh-old git; do
    d="$(tmpdir)"
    on_os "$d" windows
    fake_tool "$d" winget
    printf 'yes\n' >"$d/tty"
    printf '\n\n' >"$d/in"
    case "$c" in
      git) missing "$d" git; pre "$d" preflight_git ;;
      *) make_stub_gh "$d/gh"; echo 9999 >"$d/$c"; working_git "$d"; pre "$d" preflight_gh ;;
    esac
    expect_rc 3 "$d"
    [ "$(grep -c . "$d/run.log")" -eq 1 ] || { cat "$d/run.log" >&2; die "$c: the install ran other than once"; }
    [ "$(grep -c 'Run it now?' "$d/out")" -eq 1 ] || { cat "$d/out" >&2; die "$c: offered again in this window"; }
    [ "$(grep -cxF "$NEW_WINDOW_NEEDED" "$d/out")" -eq 3 ] || { cat "$d/out" >&2; die "$c: not told on each of the 3 rounds after the install to start again in a new window"; }
    [ "$(grep -c 'Press Enter to check again' "$d/out")" -eq 3 ] || { cat "$d/out" >&2; die "$c: not a wait on each round"; }
  done
  # The gh refresh is not a winget install: after a yes that did not fix
  # it, the round after the Enter offers it again.
  d="$(tmpdir)"
  on_os "$d" windows
  export STUB_GH_SCOPES="repo"
  printf 'yes\n' >"$d/tty"
  printf '\n' >"$d/in"
  pre "$d" with_vis public preflight_github_permissions
  expect_rc 3 "$d"
  [ "$(grep -c 'Run it now?' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "refresh: not offered again after Enter"; }
  expect_no_out "$d" "$NEW_WINDOW_NEEDED"
}

test_each_offered_command_is_the_one_shown_in_the_guide() {
  # The command run is exactly a command line the guide showed, for every
  # offer: git on macOS and Windows, gh missing or too old on macOS (with
  # brew) and Windows (with winget).
  local d os tool times want case_
  for case_ in "macos git 1 xcode-select --install" \
    "windows git 1 winget install --id Git.Git -e --source winget" \
    "macos gh-missing 1 brew install gh" "macos gh-old 1 brew upgrade gh" \
    "windows gh-missing 1 winget install --id GitHub.cli -e --source winget" \
    "windows gh-old 1 winget upgrade --id GitHub.cli -e --source winget"; do
    set -- $case_
    os="$1" tool="$2" times="$3"; shift 3; want="$*"
    d="$(tmpdir)"
    on_os "$d" "$os"
    fake_tool "$d" brew
    fake_tool "$d" winget
    printf 'yes\n' >"$d/tty"
    case "$tool" in
      git) missing "$d" git "$times"; pre "$d" preflight_git ;;
      *) make_stub_gh "$d/gh"; echo "$times" >"$d/$tool"; working_git "$d"; pre "$d" preflight_gh ;;
    esac
    expect_rc 0 "$d"
    [ "$(cat "$d/run.log")" = "$want" ] || { cat "$d/out" "$d/run.log" >&2; die "$case_: ran something else"; }
    grep -qxF "    $want" "$d/out" || { cat "$d/out" >&2; die "$case_: the command run was not shown"; }
  done
}

test_the_gh_guide_on_windows_without_winget_names_the_msi_download() {
  # End-to-end run 3, r3b: cli.github.com no longer has a "Download for
  # Windows" button; its Windows options are "Windows - WinGet" and
  # "Windows - Download MSI" (fetched by Clead, 2026-10-29). Without
  # winget the guide names the option the page shows, the MSI.
  local d
  d="$(tmpdir)"
  on_os "$d" windows
  make_stub_gh "$d/gh"; echo 1 >"$d/gh-missing"; working_git "$d"
  printf 'yes\n' >"$d/tty"; printf '\n' >"$d/in"
  pre "$d" preflight_gh
  expect_nothing_ran "$d"
  expect_out "$d" "Open https://cli.github.com in your browser, choose the Windows option that says Download MSI (not the one that says WinGet), and run the downloaded installer, keeping the default choices."
  expect_no_out "$d" "Download for Windows"
}

test_the_git_and_gh_guides_on_windows_have_you_type_q_first() {
  # p2.8.4-e (found in the review of #318): as the npm guide before
  # p2.8.4-c, the last step of the Windows git guide and gh guides said
  # to close the window and "start the script there", before the Enter/q
  # pause: only q shows the command to start again, so a newcomer who
  # closes the window as told never sees it. The step now says to type q
  # first and copy the command, then close the window, open Git Bash
  # again from the Start menu and run that command; with and without
  # winget. The gh guides' "If you see something else" line says the same
  # on Windows. Other systems keep their wording.
  local d tool with step again
  for tool in git gh-missing gh-old; do
    for with in "" winget; do
      d="$(tmpdir)"
      on_os "$d" windows
      [ -z "$with" ] || fake_tool "$d" winget
      case "$tool" in
        git)
          missing "$d" git
          pre "$d" ni preflight_git
          step="When the install has finished, type q here if the script waits, and copy the command it shows to start again. Then close this window, open Git Bash again from the Start menu, and run that command there, so that it finds git."
          ;;
        *)
          make_stub_gh "$d/gh"; echo 9999 >"$d/$tool"; working_git "$d"
          pre "$d" ni preflight_gh
          step="When the install has finished, type q here if the script waits, and copy the command it shows to start again. Then close this window, open Git Bash again from the Start menu, and run that command there, so that it finds the new gh."
          if [ "$tool" = gh-old ]; then again="if the script still says that gh is too old"; else again="if the script still says that gh is not installed"; fi
          ;;
      esac
      expect_rc 3 "$d"
      expect_out "$d" ". $step"
      expect_no_out "$d" "and start the script there"
      expect_out "$d" "To start again, run this command:"
      if [ "$tool" != git ]; then
        expect_out "$d" "${again}, type q if the script waits and copy the command it shows; then close this window, open Git Bash again from the Start menu (not from this window), and run that command there."
        expect_no_out "$d" "close this window, open a new one"
      fi
    done
  done
  # Other systems keep their steps.
  d="$(tmpdir)"
  on_os "$d" macos
  make_stub_gh "$d/gh"; echo 9999 >"$d/gh-missing"; working_git "$d"
  pre "$d" ni preflight_gh
  expect_rc 3 "$d"
  expect_out "$d" "if the script still says that gh is not installed, close this window, open a new one, and start the script again there."
  expect_no_out "$d" "type q here if the script waits"
}

test_no_offer_without_brew_or_winget_and_never_on_linux() {
  # Without brew (macOS) or winget (Windows) the guide points to a web
  # page. On Linux the package-manager line needs sudo, so it is only
  # shown, never offered.
  local d
  d="$(tmpdir)"
  on_os "$d" macos
  make_stub_gh "$d/gh"; echo 1 >"$d/gh-missing"; working_git "$d"
  printf 'yes\n' >"$d/tty"; printf '\n' >"$d/in"
  pre "$d" preflight_gh
  expect_rc 0 "$d"; expect_nothing_ran "$d"; expect_no_out "$d" "Run it now?"
  expect_out "$d" "https://cli.github.com"
  d="$(tmpdir)"
  on_os "$d" windows
  missing "$d" git 1
  printf 'yes\n' >"$d/tty"; printf '\n' >"$d/in"
  pre "$d" preflight_git
  expect_rc 0 "$d"; expect_nothing_ran "$d"; expect_no_out "$d" "Run it now?"
  expect_out "$d" "https://git-scm.com/download/win"
  local distro line
  for distro in "debian sudo apt install git" "fedora sudo dnf install git" \
    "arch sudo pacman -S git" "suse sudo zypper install git"; do
    set -- $distro
    d="$(tmpdir)"
    on_os "$d" linux "$1"; shift; line="$*"
    missing "$d" git 1
    fake_tool "$d" sudo
    printf 'yes\n' >"$d/tty"; printf '\n' >"$d/in"
    pre "$d" preflight_git
    expect_rc 0 "$d"; expect_nothing_ran "$d"; expect_no_out "$d" "Run it now?"
    grep -qxF "    $line" "$d/out" || { cat "$d/out" >&2; die "$distro: package line not shown"; }
    ! grep -q '^sudo' "$d/tools.log" || die "sudo ran"
  done
  d="$(tmpdir)"
  on_os "$d" linux other
  missing "$d" git 1
  printf '\n' >"$d/in"
  pre "$d" preflight_git
  expect_rc 0 "$d"
  expect_out "$d" "https://git-scm.com/download/linux"
}

test_gh_missing_or_too_old_is_guided() {
  local d
  d="$(tmpdir)"
  on_os "$d" linux debian
  working_git "$d"
  make_stub_gh "$d/gh"; echo 1 >"$d/gh-missing"
  printf '\n' >"$d/in"
  pre "$d" preflight_gh
  expect_rc 0 "$d"
  expect_out "$d" "The GitHub command-line tool (gh) is not installed."
  expect_out "$d" "    Done. gh is installed and can create a project from a template."
  d="$(tmpdir)"
  on_os "$d" linux debian
  make_stub_gh "$d/gh"; echo 1 >"$d/gh-old"
  printf '\n' >"$d/in"
  pre "$d" preflight_gh
  expect_rc 0 "$d"
  expect_out "$d" "The GitHub command-line tool (gh) on this computer is too old."
  # The feature check, not a version number: repo create --help lists
  # --template. gh's prompts are off for both checks.
  [ "$(grep -c "$(printf '^GH_PROMPT_DISABLED=1\trepo\tcreate\t--help$')" "$d/gh.log")" -eq 2 ] \
    || { cat "$d/gh.log" >&2; die "the feature was not checked twice through run_gh"; }
  ! grep -q '^GH_PROMPT_DISABLED=<unset>' "$d/gh.log" || die "gh ran with its prompts on"
}

test_a_gh_too_old_to_read_checks_or_merge_stops_before_anything_is_made() {
  # S18b: steps 15 and 17 use gh pr checks --json and gh pr merge
  # --match-head-commit. A gh without one of them failed only after the
  # project existed; the preflight finds it as gh too old (exit 3),
  # before anything is created. Each option alone, so each check counts.
  local d mode
  for mode in gh-old-pr-checks gh-old-pr-merge; do
    d="$(tmpdir)"
    echo 9999 >"$d/$mode"
    setup_run "$d" --non-interactive --yes
    expect_rc 3 "$d"
    expect_out "$d" "The GitHub command-line tool (gh) on this computer is too old."
    expect_out "$d" "How the script checks it: it checks that gh's commands for creating a project, for reading its checks and for adding a proposed change offer the options the script uses: --template, --json and --match-head-commit."
    [ ! -e "$d/created" ] || die "$mode: a project was created"
    ! grep -q "$(printf '\trepo\tcreate\t[^-]')" "$d/gh.log" || { cat "$d/gh.log" >&2; die "$mode: gh repo create ran"; }
    ! grep -q "$(printf '\tapi\t')" "$d/gh.log" || { cat "$d/gh.log" >&2; die "$mode: GitHub was asked before the checks passed"; }
  done
}

test_npm_is_needed_only_for_node_web_and_react_native() {
  local d p
  d="$(tmpdir)"
  missing "$d" npm
  pre "$d" ni with_pack python preflight_npm
  expect_rc 0 "$d"
  [ ! -e "$d/tools.log" ] || { cat "$d/tools.log" >&2; die "npm was checked for python"; }
  [ ! -s "$d/out" ] || { cat "$d/out" >&2; die "python printed an npm check"; }
  for p in node web react-native; do
    d="$(tmpdir)"
    on_os "$d" linux debian
    missing "$d" npm
    pre "$d" ni with_pack "$p" preflight_npm
    expect_rc 3 "$d"
    expect_out "$d" "npm (part of Node.js) is not installed."
    expect_out "$d" "https://nodejs.org"
    # r2j: on Linux the guide ends with a new window, not this one.
    expect_out "$d" "open a new terminal window, and run that command there"
    expect_no_out "$d" "Come back to this window"
    expect_nothing_ran "$d"
    d="$(tmpdir)"
    fake_tool "$d" npm 10.0.0
    pre "$d" ni with_pack "$p" preflight_npm
    expect_rc 0 "$d"
    expect_out "$d" "    Done. npm is installed."
  done
}

test_on_linux_the_npm_guide_has_you_start_again_in_a_new_window() {
  # End-to-end run 2 repeated, r2j: nodejs.org's Linux steps install
  # Node.js with nvm, which puts npm on PATH only for windows opened after
  # it, so Enter in the waiting window still found no npm. Outside WSL the
  # guide has the page's commands run in another window, then the script
  # started again in a new window with the command shown at q (#255 N2);
  # "Come back to this window" is gone. The note on the system's own
  # software list stays. The WSL wording is not shown.
  local d
  d="$(tmpdir)"
  on_os "$d" linux debian
  missing "$d" npm
  pre "$d" ni with_pack node preflight_npm
  expect_rc 3 "$d"
  expect_out "$d" "npm (part of Node.js) is not installed."
  expect_out "$d" "1. Open https://nodejs.org/en/download in your browser. Keep Linux and the version marked LTS (the one with long-term support) chosen there; the Node.js in your system's own software list may be older than the one your project's checks use."
  expect_out "$d" "2. Open another terminal window and run there, one by one, the commands the page shows"
  expect_out "$d" "3. When they have finished, type q here if the script waits, and copy the command it shows to start again. Then close this window, open a new terminal window, and run that command there: the new npm is found only in a window opened after the install."
  expect_out "$d" "If you see something else: if the script still says that npm is not installed, check that the commands from the page ended without an error, then start the script again in a new terminal window."
  expect_no_out "$d" "Come back to this window"
  expect_no_out "$d" "choose your system"
  expect_no_out "$d" "this Linux"
  expect_out "$d" "To start again, run this command:"
  expect_nothing_ran "$d"
  # Without --non-interactive the script waits; after q it shows the
  # command to start again, as step 3 says.
  d="$(tmpdir)"
  on_os "$d" linux debian
  missing "$d" npm
  printf 'q\n' >"$d/in"
  pre "$d" with_pack node preflight_npm
  expect_rc 3 "$d"
  expect_out "$d" "Press Enter to check again, or type q to stop:"
  expect_out "$d" "To start again, run this command:"
}

test_the_npm_guide_on_macos_and_windows_keeps_its_steps() {
  # Guard for r2i/r2j: the Linux and WSL change leaves the macOS and
  # Windows (Git Bash) steps as they were.
  local d
  d="$(tmpdir)"
  on_os "$d" macos
  missing "$d" npm
  pre "$d" ni with_pack node preflight_npm
  expect_rc 3 "$d"
  expect_out "$d" "1. Open https://nodejs.org in your browser and download the version marked LTS (the one with long-term support)."
  expect_out "$d" "2. Open the downloaded file and follow the installer, then come back to this window."
  expect_out "$d" "If you see something else: if the script still says that npm is not installed, close this window, open a new one, and start the script again there."
  d="$(tmpdir)"
  on_os "$d" windows
  missing "$d" npm
  pre "$d" ni with_pack node preflight_npm
  expect_rc 3 "$d"
  expect_out "$d" "1. Open https://nodejs.org in your browser and download the version marked LTS (the one with long-term support)."
  expect_out "$d" "2. Run the downloaded installer, keeping the default choices."
  # End-to-end run 4, r4a: a Git Bash window opened from the old one kept
  # its old program search list, so npm was still not found; the step
  # says why it must be the Start menu, and so does the line after it.
  # p2.8.4-c (newcomer pre-check on v2.8.4): as on Linux and in WSL, the
  # command to start again is shown only after q, so step 3 says to type
  # q first and copy it, and the line after it says the same.
  expect_out "$d" "3. When the installer has finished, type q here if the script waits, and copy the command it shows to start again. Then close this window, open Git Bash again from the Start menu, and run that command there. Use the Start menu, not a new window opened from this one: a window opened from another one keeps that window's old list of the folders where programs are found, so it would not find the new npm either."
  expect_out "$d" "If you see something else: if the script still says that npm is not installed, type q if the script waits and copy the command it shows; then close this window, open Git Bash again from the Start menu (not from this window), and run that command there."
  expect_no_out "$d" "close this window, open a new one"
  expect_no_out "$d" "and start the script there"
  expect_no_out "$d" "and start the script again there"
  expect_out "$d" "To start again, run this command:"
  expect_nothing_ran "$d"
  # Without --non-interactive the script waits; after q it shows the
  # command to start again, as step 3 says.
  d="$(tmpdir)"
  on_os "$d" windows
  missing "$d" npm
  printf 'q\n' >"$d/in"
  pre "$d" with_pack node preflight_npm
  expect_rc 3 "$d"
  expect_out "$d" "Press Enter to check again, or type q to stop:"
  expect_out "$d" "To start again, run this command:"
}

test_in_wsl_the_windows_npm_counts_as_no_npm_and_its_guide_says_why() {
  # r2e (end-to-end run 2, Ubuntu in WSL): the check passed with the
  # Windows npm, reached through WSL's Windows interop on PATH
  # (/mnt/c/Program Files/nodejs//npm). A project in Linux should not
  # depend on it: in WSL an npm under the Windows drives counts as none,
  # and its guide says why and how to install Node.js in Linux. The
  # Windows npm is not run.
  local d p want
  for p in node web react-native; do
    d="$(tmpdir)"
    on_wsl "$d"
    windows_npm "$d"
    pre "$d" ni with_pack "$p" path_first "$(windows_npm_dir "$d")" preflight_npm
    expect_rc 3 "$d"
    want="$(windows_npm_dir "$d")"
    want="${want%/}/npm"
    expect_out "$d" "The npm this Linux finds is the Windows one, so npm (part of Node.js) is not installed in this Linux."
    expect_out "$d" "the npm it found, $want, is a Windows program"
    expect_out "$d" "A project in this Linux should use a Node.js installed in Linux"
    expect_out "$d" "https://nodejs.org/en/download"
    expect_out "$d" "choose Linux"
    expect_out "$d" "How the script checks it: it looks where the npm it finds is, following links: one in the folder of a Windows drive (/mnt/c/, /mnt/d/ and so on, where this Linux shows the Windows drives) is the Windows one."
    expect_out "$d" "To start again, run this command:"
    expect_no_out "$d" "    Done. npm is installed."
    expect_no_out "$d" "npm (part of Node.js) is not installed."
    [ ! -e "$d/tools.log" ] || ! grep -q '^windows-npm' "$d/tools.log" || { cat "$d/tools.log" >&2; die "$p: the Windows npm was run"; }
    expect_nothing_ran "$d"
  done
}

test_in_wsl_the_npm_check_passes_once_npm_is_installed_in_linux() {
  # The guide is checked again after Enter, as every guide is: once
  # Node.js is installed in Linux, its npm comes before the Windows one
  # on PATH and the check passes, with the Linux npm.
  local d
  d="$(tmpdir)"
  on_wsl "$d"
  windows_npm "$d"
  fake_tool "$d" npm 10.9.2
  mkdir -p "$d/later"
  mv "$d/bin/npm" "$d/later/npm"
  printf '\n' >"$d/in"
  # The Linux folder npm moves to comes first (path_first prepends).
  pre "$d" with_pack node linux_npm_on_enter "$d" path_first "$(windows_npm_dir "$d")" path_first "$d/linux bin" preflight_npm
  expect_rc 0 "$d"
  [ "$(grep -c '^The npm this Linux finds is the Windows one' "$d/out")" -eq 1 ] || { cat "$d/out" >&2; die "the guide was not shown once"; }
  [ "$(tail -1 "$d/out")" = "    Done. npm is installed." ] || { cat "$d/out" >&2; die "no done line after npm was installed in Linux"; }
  [ "$(grep -c '^npm --version' "$d/tools.log")" -eq 1 ] || { cat "$d/tools.log" >&2; die "the Linux npm was not checked once"; }
  ! grep -q '^windows-npm' "$d/tools.log" || { cat "$d/tools.log" >&2; die "the Windows npm was run"; }
}

# linux_npm_on_enter <dir> <command...>: at the first Enter the user
# presses, <dir>/later/npm moves to "<dir>/linux bin", which the test puts
# before the Windows folder on PATH, as an install of Node.js in Linux
# puts its npm before the Windows one.
linux_npm_on_enter() {
  LATER_DIR="$1"
  shift
  eval "real_wait_for_enter() $(declare -f wait_for_enter | sed 1d)"
  wait_for_enter() {
    real_wait_for_enter "$@" || return 1
    [ ! -e "$LATER_DIR/later/npm" ] || { mkdir -p "$LATER_DIR/linux bin"; mv "$LATER_DIR/later/npm" "$LATER_DIR/linux bin/npm"; }
  }
  "$@"
}

test_in_wsl_a_link_to_the_windows_npm_counts_as_no_npm() {
  # #255 review, N1: the place npm is found is followed to the file it
  # leads to. A link in a Linux folder to the Windows npm is the Windows
  # npm too: refused, and not run. Git Bash without the right to make
  # links makes a copy for ln -s (#255 review, N8): no link, so nothing
  # to check there.
  local d
  d="$(tmpdir)"
  on_wsl "$d"
  windows_npm "$d"
  mkdir -p "$d/linux bin"
  if ! ln -s "$(windows_npm_dir "$d")npm" "$d/linux bin/npm" 2>/dev/null || [ ! -L "$d/linux bin/npm" ]; then
    skip_test "no symbolic links here (ln -s made no link)"
    return 0
  fi
  pre "$d" ni with_pack node path_first "$d/linux bin" preflight_npm
  expect_rc 3 "$d"
  expect_out "$d" "The npm this Linux finds is the Windows one"
  [ ! -e "$d/tools.log" ] || ! grep -q '^windows-npm' "$d/tools.log" || { cat "$d/tools.log" >&2; die "the Windows npm was run through a link"; }
}

test_in_wsl_dot_on_path_in_a_windows_folder_counts_as_no_npm() {
  # #255 review, N1: with . on PATH while the current folder is the
  # Windows Node.js folder, command -v says ./npm; followed from the
  # current folder, that is the Windows npm: refused, and not run.
  # Not on Git Bash (MSYS, Cygwin): there readlink -f builds ./npm from
  # the current folder as MSYS turns it back from its Windows path, which
  # can be spelled otherwise than the same folder given as a path (on the
  # CI runner most likely the temp folder, C:\Users\RUNNER~1\... read
  # back as /c/Users/runneradmin/... rather than /tmp/...; inferred from
  # the failing run, not seen), so the two do not compare equal. WSL, where alone this check runs, has no such
  # translation: its readlink is GNU's on Linux paths.
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
      skip_test "Git Bash spells the current folder otherwise than its path, which cannot happen in WSL, where this check runs"
      return 0
      ;;
  esac
  local d
  d="$(tmpdir)"
  on_wsl "$d"
  windows_npm "$d"
  pre "$d" ni with_pack node in_folder "$(windows_npm_dir "$d")" path_first . preflight_npm
  expect_rc 3 "$d"
  expect_out "$d" "The npm this Linux finds is the Windows one"
  [ ! -e "$d/tools.log" ] || ! grep -q '^windows-npm' "$d/tools.log" || { cat "$d/tools.log" >&2; die "the Windows npm was run through . on PATH"; }
}

test_in_wsl_a_linux_npm_passes_and_a_missing_one_gets_the_usual_guide() {
  # Error paths of the WSL check: only an npm under a Windows drive
  # (/mnt/<letter>/) is the Windows one. A Linux npm, also one in a folder
  # under /mnt that is not a drive, passes; no npm at all gets the usual
  # guide, not the Windows one.
  local d
  d="$(tmpdir)"
  on_wsl "$d"
  windows_npm "$d"
  fake_tool "$d" npm 10.9.2
  # WSL puts the Windows folders after the Linux ones on PATH.
  pre "$d" ni with_pack node path_last "$(windows_npm_dir "$d")" preflight_npm
  expect_rc 0 "$d"
  expect_out "$d" "    Done. npm is installed."
  d="$(tmpdir)"
  on_wsl "$d"
  write_stand_in "$d/drives/data/node/bin/npm" 'echo 10.9.2'
  pre "$d" ni with_pack node path_first "$d/drives/data/node/bin" preflight_npm
  expect_rc 0 "$d"
  expect_out "$d" "    Done. npm is installed."
  # No npm at all: the usual title, not the Windows one, with the WSL
  # steps (r2i, foreseen as #255 N5): the browser runs on Windows, so the
  # page offers Windows; choose Linux and run its commands in another
  # window of this Linux, then start again in a new one (r2j), as the
  # Windows-npm guide says.
  d="$(tmpdir)"
  on_wsl "$d"
  missing "$d" npm
  pre "$d" ni with_pack node preflight_npm
  expect_rc 3 "$d"
  expect_out "$d" "npm (part of Node.js) is not installed."
  expect_no_out "$d" "the Windows one"
  expect_out "$d" "1. Open https://nodejs.org/en/download in your browser. It shows the steps for Windows, because the browser runs on Windows"
  expect_out "$d" "choose Linux"
  expect_out "$d" "2. Open another window of this Linux (from the Start menu, as you opened this one) and run there, one by one, the commands the page shows"
  expect_out "$d" "3. When they have finished, type q here if the script waits, and copy the command it shows to start again. Then close this window, open a new window of this Linux, and run that command there: the new npm is found only in a window opened after the install."
  expect_out "$d" "If you see something else: if the script still says that npm is not installed, check that the commands from the page ended without an error, then start the script again in a new window of this Linux."
  expect_no_out "$d" "choose your system"
  expect_no_out "$d" "download the version marked LTS"
  expect_no_out "$d" "Come back to this window"
  expect_no_out "$d" "terminal window"
}

test_outside_wsl_an_npm_under_mnt_is_not_refused() {
  # Outside WSL nothing changes: an npm in a folder under /mnt (a disk
  # mounted there on Linux) is used as before, on Linux without WSL and
  # on a Linux whose kernel release names no Microsoft.
  local d
  d="$(tmpdir)"
  on_os "$d" linux debian
  windows_npm "$d"
  pre "$d" ni with_pack node path_first "$(windows_npm_dir "$d")" preflight_npm
  expect_rc 0 "$d"
  expect_out "$d" "    Done. npm is installed."
  grep -q '^windows-npm --version' "$d/tools.log" || { cat "$d/tools.log" >&2; die "the npm under /mnt was not run"; }
  d="$(tmpdir)"
  on_wsl "$d" 6.8.0-45-generic
  windows_npm "$d"
  pre "$d" ni with_pack node path_first "$(windows_npm_dir "$d")" preflight_npm
  expect_rc 0 "$d"
  expect_out "$d" "    Done. npm is installed."
}

test_bash_older_than_3_2_is_refused_with_steps() {
  local d v
  for v in "3 2" "3 10" "4 0" "5 2"; do
    ( load_script; check_bash_version $v ) || die "bash $v refused"
  done
  for v in "3 1" "3 0" "2 9"; do
    ! ( load_script; check_bash_version $v ) || die "bash $v accepted"
  done
  d="$(tmpdir)"
  on_os "$d" linux debian
  printf '\n' >"$d/in"
  pre "$d" preflight_bash 3 1
  # A re-check in the same run cannot change the bash that runs it, so it
  # does not wait: steps, the command to start again, exit 3.
  expect_rc 3 "$d"
  expect_out "$d" "This bash is too old for the script: it needs version 3.2 or later."
  expect_out "$d" "To start again, run this command:"
  expect_no_out "$d" "Press Enter"
  d="$(tmpdir)"
  pre "$d" preflight_bash 3 2
  expect_rc 0 "$d"
  expect_out "$d" "    Done. bash 3.2 is new enough."
}

test_the_tool_checks_print_a_start_and_a_done_line() {
  local d
  d="$(tmpdir)"
  working_git "$d"
  fake_tool "$d" npm 10.0.0
  pre "$d" ni preflight_tools
  expect_rc 0 "$d"
  grep -qE '^==> Checking .*bash' "$d/out" || { cat "$d/out" >&2; die "no start line for bash"; }
  grep -qE '^==> Checking .*git' "$d/out" || { cat "$d/out" >&2; die "no start line for git"; }
  grep -qE '^==> Checking .*gh' "$d/out" || { cat "$d/out" >&2; die "no start line for gh"; }
  [ "$(grep -c '^==> ' "$d/out")" -eq "$(grep -c '^    Done\. ' "$d/out")" ] \
    || { cat "$d/out" >&2; die "not every start line has a done line"; }
}

test_target_folder_absent_or_empty_passes_and_nothing_is_made() {
  local d
  d="$(tmpdir)"
  pre "$d" ni with_dir "$d/new folder" preflight_target_dir
  expect_rc 0 "$d"
  [ ! -e "$d/new folder" ] || die "the folder was made by the check"
  expect_out "$d" "    Done. "
  mkdir "$d/empty"
  pre "$d" ni with_dir "$d/empty" preflight_target_dir
  expect_rc 0 "$d"
}

test_target_folder_with_files_is_a_guided_refusal() {
  local d
  d="$(tmpdir)"
  mkdir "$d/full"; touch "$d/full/.hidden"
  pre "$d" ni with_dir "$d/full" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "The folder $d/full already has files in it."
  expect_out "$d" "--dir"
  expect_out "$d" "To start again, run this command:"
  [ -e "$d/full/.hidden" ] || die "a file in the folder was touched"
  printf 'q\n' >"$d/in"
  pre "$d" with_dir "$d/full" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "Press Enter to check again"
}

test_a_folder_emptied_after_the_guide_passes_on_the_next_check() {
  # The user empties the folder while the script waits; Enter checks again.
  local d n=0
  d="$(tmpdir)"
  mkdir "$d/full"; touch "$d/full/x"
  prepare "$d"
  { while ! grep -q 'Press Enter' "$d/out" 2>/dev/null; do
      n=$((n + 1)); [ "$n" -lt 600 ] || break; sleep 0.1
    done
    rm -f "$d/full/x"; echo
  } | { pre_from_stdin "$d" with_dir "$d/full" preflight_target_dir; echo "$RC" >"$d/rc"; }
  [ "$(cat "$d/rc")" -eq 0 ] || { cat "$d/out" "$d/err" >&2; die "exit $(cat "$d/rc"), want 0"; }
  [ "$(grep -c 'already has files in it' "$d/out")" -eq 1 ] || die "guide not shown exactly once"
  [ "$(tail -1 "$d/out")" = "    Done. The folder is new or empty." ] || { cat "$d/out" >&2; die "no done line"; }
}

# own_copy <dir> <origin>: a git project in <dir> with one saved change
# and <origin> as the address it was copied from.
own_copy() {
  mkdir -p "$1"
  "$REAL_GIT" -c init.defaultBranch=main init -q "$1"
  printf 'x\n' >"$1/README.md"
  "$REAL_GIT" -C "$1" add -A
  "$REAL_GIT" -C "$1" -c user.name=T -c user.email=t@example.com commit -q -m one
  "$REAL_GIT" -C "$1" remote add origin "$2"
}

test_resume_allows_a_folder_with_files_but_not_a_file() {
  local d
  d="$(tmpdir)"
  own_copy "$d/full" https://github.com/octo-user/my-app.git
  pre "$d" ni resume with_project octo-user my-app with_dir "$d/full" preflight_target_dir
  expect_rc 0 "$d"
  touch "$d/a-file"
  pre "$d" ni resume with_dir "$d/a-file" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "$d/a-file is a file, not a folder."
  pre "$d" ni with_dir "$d/a-file" preflight_target_dir
  expect_rc 3 "$d"
}

test_the_folder_must_be_in_a_folder_that_exists_and_is_outside_any_git_project() {
  # #148 review, finding 7, the part that belongs to the copy: the folder
  # above the target exists and may be written, and the target is not
  # inside another git project. (Whether a folder kept by --resume is
  # this project's own copy is resume logic, S15.)
  local d
  # No folder above it: guided, nothing made.
  d="$(tmpdir)"
  pre "$d" ni with_dir "$d/no such/app" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "The folder $d/no such, which would hold the folder $d/no such/app, does not exist."
  expect_out "$d" "--dir"
  expect_out "$d" "To start again, run this command:"
  [ ! -e "$d/no such" ] || die "the folder above was made by the check"
  # Once that folder is there, the same check passes.
  mkdir -p "$d/no such"
  pre "$d" ni with_dir "$d/no such/app" preflight_target_dir
  expect_rc 0 "$d"
  # Inside another git project, new or empty: guided, and the guide names
  # the folder where that project starts.
  d="$(tmpdir)"
  "$REAL_GIT" init -q "$d/outer"
  mkdir -p "$d/outer/sub/empty"
  pre "$d" ni with_dir "$d/outer/sub/app" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "The folder $d/outer/sub/app is inside another project that git keeps track of (the one in $d/outer)."
  pre "$d" ni with_dir "$d/outer/sub/empty" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "is inside another project that git keeps track of"
  # With --resume too: a kept folder is checked by the folder above it.
  mkdir -p "$d/outer/sub/kept"; touch "$d/outer/sub/kept/x"
  pre "$d" ni resume with_dir "$d/outer/sub/kept" preflight_target_dir
  expect_rc 3 "$d"
  # A copy that is a git project of its own, in a plain folder, still
  # passes with --resume: only the folders above it count.
  own_copy "$d/plain/copy" https://github.com/octo-user/my-app.git
  pre "$d" ni resume with_project octo-user my-app with_dir "$d/plain/copy" preflight_target_dir
  expect_rc 0 "$d"
  # Not writable. Only where the test can make such a folder: as root, or
  # on Windows, every folder can be written, and the case is skipped.
  d="$(tmpdir)"
  mkdir -p "$d/locked"
  chmod 555 "$d/locked"
  if [ -w "$d/locked" ]; then
    echo "note: this account can write in any folder here; the not-writable case was not run"
  else
    pre "$d" ni with_dir "$d/locked/app" preflight_target_dir
    expect_rc 3 "$d"
    expect_out "$d" "The script may not write in the folder $d/locked."
    mkdir -p "$d/locked2/empty"
    chmod 555 "$d/locked2/empty"
    pre "$d" ni with_dir "$d/locked2/empty" preflight_target_dir
    expect_rc 3 "$d"
    expect_out "$d" "The script may not write in the folder $d/locked2/empty."
    chmod 755 "$d/locked2/empty"
  fi
  chmod 755 "$d/locked"
}

test_the_project_around_the_folder_is_named_as_the_user_wrote_the_path() {
  # git names the project's top folder with every symbolic link resolved
  # (on macOS /var is /private/var, so a folder under $TMPDIR came out as
  # /private/var/...; Git for Windows writes C:/Users/...). The guide
  # names it as the user wrote the folder, so both paths in one sentence
  # are spelled alike.
  local d
  d="$(tmpdir)"
  mkdir -p "$d/real"
  "$REAL_GIT" init -q "$d/real/outer"
  mkdir -p "$d/real/outer/sub" "$d/real/outer/deep/er"
  ln -s "$d/real" "$d/link" 2>/dev/null || { echo "no symbolic links here; skipped"; return 0; }
  # Below the top folder, and straight in it.
  pre "$d" ni with_dir "$d/link/outer/sub/app" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "The folder $d/link/outer/sub/app is inside another project that git keeps track of (the one in $d/link/outer)."
  pre "$d" ni with_dir "$d/link/outer/app" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "(the one in $d/link/outer)."
  # A link inside the project, so the path given does not end in git's
  # path of the folder: git's own name for the top folder is shown.
  if ln -s "$d/real/outer/deep/er" "$d/real/outer/lnk" 2>/dev/null && [ -L "$d/real/outer/lnk" ]; then
    pre "$d" ni with_dir "$d/real/outer/lnk/app" preflight_target_dir
    expect_rc 3 "$d"
    expect_out "$d" "(the one in $(cd "$d/real/outer" && pwd -P))."
  else
    echo "symbolic links are copies here; the link-inside-the-project case was not run"
  fi
}

test_a_folder_starting_with_a_tilde_is_in_the_home_folder() {
  # Review note (#146): a typed ~/projects/app made a folder named ~.
  local d
  d="$(tmpdir)"
  printf '%s\n' my-app "" "Lends tools." "" "" python "" none "~/projects/app" "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" "DIR=$d/home/projects/app"
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b --dir "~"
  expect_inputs "$d" "DIR=$d/home"
  d="$(tmpdir)"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b "--dir=~/x y"
  expect_inputs "$d" "DIR=$d/home/x y"
  # Only ~ and ~/ are understood; another account's ~name is refused.
  refuses --dir "~other/app" "~other"
  accepts --dir "a~b" "DIR=./a~b"
}

test_a_relative_folder_is_written_with_dot_slash_in_front() {
  # #152 review, finding 1: a folder such as my=app reached awk as an
  # operand, which awk reads as a variable setting (name=value), not a
  # file; one starting with - reached gh, ls, rm and mkdir as an option.
  # A relative folder gets ./ in front; ~, absolute, ./ and ../ paths
  # stay as they are.
  accepts --dir "my=app" "DIR=./my=app"
  accepts --dir -app "DIR=./-app"
  accepts --dir "projects/app" "DIR=./projects/app"
  accepts --dir "./app" "DIR=./app"
  accepts --dir "../app" "DIR=../app"
  accepts --dir "/srv/app" "DIR=/srv/app"
  accepts --dir "." "DIR=."
  accepts --dir ".." "DIR=.."
  # Git Bash also takes Windows paths with a drive letter.
  accepts --dir "C:/work/app" "DIR=C:/work/app"
  accepts --dir 'D:\work\app' 'DIR=D:\work\app'
}

test_git_defaults_are_the_global_settings_not_those_of_a_local_project() {
  # #148 review, finding 1: started inside a git project whose own
  # settings hold another name and email, the defaults are still the
  # global ones (git config --global, not --get, which would read the
  # project's own settings first).
  local d
  d="$(tmpdir)"
  fake_home "$d/home" "Grace Hopper" grace@example.com
  mkdir -p "$d/cwd"
  "$REAL_GIT" init -q "$d/cwd"
  "$REAL_GIT" -C "$d/cwd" config user.name "Local Person"
  "$REAL_GIT" -C "$d/cwd" config user.email local@example.com
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b
  expect_inputs "$d" "GIT_NAME=Grace Hopper" GIT_EMAIL=grace@example.com
}

test_a_tilde_folder_is_refused_when_the_home_folder_is_not_known() {
  # #148 review, finding 1: the branch of check_dir for an empty HOME.
  local h
  for h in empty unset; do
    ( load_script
      if [ "$h" = empty ]; then HOME=""; else unset HOME; fi
      ! check_dir "~/projects/app" || die "HOME $h: ~/projects/app was taken as $CHECKED"
      case "$PROBLEM" in
        *"home folder is not known"*"full path"*) ;;
        *) die "HOME $h: problem not explained: $PROBLEM" ;;
      esac
      check_dir "/tmp/app" || die "HOME $h: a full path was refused"
    ) || exit 1
  done
}

test_a_dangling_link_at_the_folder_path_is_refused_like_a_file() {
  # #148 review, finding 1: a symbolic link whose target is gone is not
  # "absent": the copy cannot be made there, with or without --resume.
  local d
  d="$(tmpdir)"
  ln -s "$d/gone" "$d/link" 2>/dev/null || { echo "no symbolic links here; skipped" >&2; return 0; }
  [ -L "$d/link" ] && [ ! -e "$d/link" ] || { echo "not a dangling link here; skipped" >&2; return 0; }
  pre "$d" ni with_dir "$d/link" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "$d/link is a file, not a folder."
  pre "$d" ni resume with_dir "$d/link" preflight_target_dir
  expect_rc 3 "$d"
  [ -L "$d/link" ] || die "the link was touched"
}

test_git_name_and_email_default_from_the_global_git_settings() {
  local d
  d="$(tmpdir)"
  fake_home "$d/home" "Grace Hopper" grace@example.com
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b
  expect_inputs "$d" "GIT_NAME=Grace Hopper" GIT_EMAIL=grace@example.com
  d="$(tmpdir)"
  fake_home "$d/home" "Grace Hopper" grace@example.com
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b --git-name "Ada L" \
    --git-email=ada@example.com
  expect_inputs "$d" "GIT_NAME=Ada L" GIT_EMAIL=ada@example.com
  # Asked, with the git settings as the default.
  d="$(tmpdir)"
  fake_home "$d/home" "Grace Hopper" grace@example.com
  printf '%s\n' my-app "" "Lends tools." "" "" python "" none "" "" "" >"$d/in"
  inputs "$d"
  expect_inputs "$d" "GIT_NAME=Grace Hopper" GIT_EMAIL=grace@example.com
  expect_out "$d" "Your name for git [Grace Hopper]: "
  expect_out "$d" "Your email address for git [grace@example.com]: "
}

test_missing_git_name_and_email_join_the_list_of_missing_options() {
  local d
  d="$(tmpdir)"
  fake_home "$d/home"
  inputs "$d" --non-interactive --name my-app
  expect_refused "$d" --git-name
  expect_refused "$d" --git-email
  expect_refused "$d" --description
  [ ! -e "$d/gh.log" ] || die "GitHub was asked before the missing options were reported"
  d="$(tmpdir)"
  fake_home "$d/home" "Grace Hopper"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}"
  expect_refused "$d" --git-email
  ! grep -q -- '- --git-name:' "$d/err" || die "a name from the git settings was listed as missing"
}

test_git_questions_without_a_default_need_an_answer() {
  local d
  d="$(tmpdir)"
  fake_home "$d/home"
  printf '%s\n' my-app "" "Lends tools." "" "" python "" none "" "" "Ada L" "" ada@example.com >"$d/in"
  inputs "$d"
  expect_inputs "$d" "GIT_NAME=Ada L" GIT_EMAIL=ada@example.com
  [ "$(grep -c '^Your name for git: $' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "name not asked again"; }
  [ "$(grep -c '^Your email address for git: $' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "email not asked again"; }
}

test_git_name_and_email_are_checked_like_the_other_names() {
  local c
  for c in '"' '\' '<' '>' '&' '`' "$(printf '\t')"; do
    refuses --git-name "a${c}b"
    refuses --git-email "a${c}b@example.com"
  done
  refuses --git-email "ada" "ada@" "@example.com" "ada lovelace@example.com" "ada@exa mple.com" \
    "a@b@c"
  accepts --git-name "Ada Lovelace | Team" "GIT_NAME=Ada Lovelace | Team"
  accepts --git-email " ada@example.com " GIT_EMAIL=ada@example.com
  # A name from the git settings that cannot be used is refused with its
  # option, so the user knows which one to give.
  local d
  d="$(tmpdir)"
  fake_home "$d/home" 'Ada "the first"' ada@example.com
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b
  expect_refused "$d" --git-name
}

test_git_name_and_email_are_only_collected_not_written() {
  local d before
  d="$(tmpdir)"
  fake_home "$d/home" "Grace Hopper" grace@example.com
  before="$(cat "$d/home/.gitconfig")"
  inputs "$d" --non-interactive "${REQUIRED_OPTS[@]}" --owner a --po-name b --git-name "Ada L" \
    --git-email ada@example.com
  expect_inputs "$d" "GIT_NAME=Ada L"
  [ "$(cat "$d/home/.gitconfig")" = "$before" ] || die "the global git settings were changed"
  [ -z "$(ls -A "$d/cwd")" ] || die "something was written in the current folder"
}

test_checks_on_this_computer_come_before_any_github_call_and_question() {
  # gh too old: the script stops at the gh check, before reading the
  # GitHub account and before the first question.
  local d
  d="$(tmpdir)"
  on_os "$d" linux debian
  working_git "$d"
  echo 9999 >"$d/gh-old"
  printf '%s\n' my-app q >"$d/in"
  whole "$d"
  expect_rc 3 "$d"
  ! grep -q "$(printf '\tapi\t')" "$d/gh.log" || { cat "$d/gh.log" >&2; die "GitHub was asked before the checks passed"; }
  expect_no_out "$d" "Project name"
  # All pass: the tool checks come first, then the account and the
  # published version (before the questions), then the permissions (a
  # fresh read of the account), the name and the licence. A dry run
  # stops there.
  d="$(tmpdir)"
  working_git "$d"
  fake_tool "$d" npm 10.0.0
  whole "$d" --non-interactive --dry-run "${REQUIRED_OPTS[@]}"
  expect_rc 0 "$d"
  [ "$(awk -F'\t' '{ print $2 " " $NF }' "$d/gh.log")" = "$(printf '%s\n' '--version --version' 'repo --help' 'pr --help' 'pr --help' \
      'api .login, (.name // "")' 'api repos/factoincognito/ai-project-bootstrap/contents/CHANGELOG.md' \
      'api .login, (.name // "")' 'api repos/octo-user/my-app' 'api .key')" ] \
    || { cat "$d/gh.log" >&2; die "gh calls not in the order: tools, account, version, name, licence"; }
}

test_npm_and_folder_checks_come_after_the_questions() {
  local d
  d="$(tmpdir)"
  on_os "$d" linux debian
  working_git "$d"
  missing "$d" npm
  printf '%s\n' my-app "" "Lends tools." "" "" node "" none "" "" "" q >"$d/in"
  whole "$d"
  expect_rc 3 "$d"
  expect_out "$d" "npm (part of Node.js) is not installed."
  grep -n 'Your email address for git' "$d/out" | head -1 | cut -d: -f1 >"$d/q"
  grep -n 'npm (part of Node.js)' "$d/out" | head -1 | cut -d: -f1 >"$d/g"
  [ "$(cat "$d/q")" -lt "$(cat "$d/g")" ] || { cat "$d/out" >&2; die "npm was checked before the questions"; }
  d="$(tmpdir)"
  working_git "$d"
  fake_tool "$d" npm 10.0.0
  mkdir -p "$d/cwd/my-app"; touch "$d/cwd/my-app/x"
  whole "$d" --non-interactive --yes "${REQUIRED_OPTS[@]}"
  expect_rc 3 "$d"
  expect_out "$d" "The folder ./my-app already has files in it."
}

# guide_cases: every guide, as a function to run after detect_os. The
# GitHub guides read what their check found; the gg_ wrappers set it.
guide_cases() {
  printf '%s\n' guide_git guide_gh_missing guide_gh_old guide_npm gg_npm_windows guide_dir_not_empty \
    guide_dir_is_file guide_bash_old gg_signed_out gg_expired gg_offline gg_permissions \
    gg_permissions_repo gg_permissions_token gg_old_script gg_project_exists \
    gg_create_taken gg_create_refused gg_protect_plan gg_protect_token gg_protect_unknown \
    guide_dir_no_parent gg_dir_not_writable gg_dir_in_git gg_dir_in_git_unknown \
    gg_actions_off gg_actions_local_only
}
gg_actions_off() { IN_OWNER=acme; IN_NAME=my-app; ACTIONS_PROBLEM=off; guide_actions_off; }
gg_actions_local_only() {
  IN_OWNER=acme; IN_NAME=my-app; PR_URL=https://github.com/acme/my-app/pull/1
  ACTIONS_PROBLEM=local-only; guide_actions_off
}
gg_npm_windows() { NPM_PROBLEM=windows; NPM_WINDOWS_PATH="/mnt/c/Program Files/nodejs//npm"; guide_npm; }
gg_dir_not_writable() { DIR_UNWRITABLE=/srv/shared; guide_dir_not_writable; }
gg_dir_in_git() { DIR_OUTER=/home/me/work; guide_dir_in_git; }
gg_dir_in_git_unknown() { DIR_OUTER=""; guide_dir_in_git; }
gg_signed_out() { ACCOUNT_PROBLEM=signed-out; guide_github_account; }
gg_expired() { ACCOUNT_PROBLEM=expired; API_STATUS=401; API_MESSAGE="Bad credentials"; guide_github_account; }
gg_offline() { ACCOUNT_PROBLEM=offline; API_ERR="error connecting to api.github.com"; guide_github_account; }
gg_permissions() { PERM_PROBLEM=missing; PERM_MISSING=workflow; IN_VISIBILITY=public; guide_github_permissions; }
gg_permissions_repo() { PERM_PROBLEM=missing; PERM_MISSING="repo workflow"; IN_VISIBILITY=private; guide_github_permissions; }
gg_permissions_token() { GH_TOKEN=x; PERM_PROBLEM=missing; PERM_MISSING=workflow; IN_VISIBILITY=public; guide_github_permissions; }
gg_old_script() { PUBLISHED_VERSION=v9.9.9; guide_old_script; }
gg_project_exists() { IN_OWNER=acme; IN_NAME=my-app; guide_project_exists; }
gg_create_taken() { IN_OWNER=acme; IN_NAME=my-app; CREATE_ERR="GraphQL: Name already exists on this account"; guide_create_taken; }
gg_create_refused() {
  IN_OWNER=acme; IN_NAME=my-app; GH_LOGIN=octo-user; GH_SCOPES_SEEN=""
  CREATE_ERR="GraphQL: Resource not accessible by personal access token"; guide_create_refused
}
gg_protect() {
  IN_OWNER=acme; IN_NAME=my-app; RESTART_CMD="bootstrap-project.sh --resume"
  PROTECT_PROBLEM="$1"; API_STATUS=403; API_MESSAGE="$2"; guide_protect
}
gg_protect_plan() { gg_protect plan "Upgrade to GitHub Pro or make this repository public to enable this feature."; }
gg_protect_token() { gg_protect token "Resource not accessible by personal access token"; }
gg_protect_unknown() { gg_protect unknown "Something about this request was refused."; }

# guide_shape_problem <file>: checks a guide's output as the every-guide
# test needs it, line by line with bash's own regular expressions (the
# extended ones grep -E uses), so no process is started: a one-line title
# first, then somewhere a why, a numbered step, the result, the fallback
# and the check. Prints the first part missing ("" when none is).
GUIDE_RE_TITLE='^[A-Za-z].{10,}\.$'
GUIDE_RE_WHY='^Why this is needed: ([^ ]+ ){5,}'
GUIDE_RE_STEP='^  1\. .{10,}'
GUIDE_RE_WORKED='^When it has worked: .{10,}'
GUIDE_RE_ELSE='^If you see something else: .{10,}'
GUIDE_RE_HOW='^How the script checks it: .{10,}'
guide_shape_problem() {
  local line n=0 title="" why="" step="" worked="" other="" how=""
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if [ "$n" -eq 1 ] && [[ $line =~ $GUIDE_RE_TITLE ]]; then title=1; fi
    if [[ $line =~ $GUIDE_RE_WHY ]]; then why=1; fi
    if [[ $line =~ $GUIDE_RE_STEP ]]; then step=1; fi
    if [[ $line =~ $GUIDE_RE_WORKED ]]; then worked=1; fi
    if [[ $line =~ $GUIDE_RE_ELSE ]]; then other=1; fi
    if [[ $line =~ $GUIDE_RE_HOW ]]; then how=1; fi
  done <"$1"
  if [ -z "$title" ]; then echo "no one-line title first"
  elif [ -z "$why" ]; then echo "no why"
  elif [ -z "$step" ]; then echo "no numbered step"
  elif [ -z "$worked" ]; then echo "no result"
  elif [ -z "$other" ]; then echo "no fallback"
  elif [ -z "$how" ]; then echo "no check named"
  fi
}

# numbered_prose <file> <label>: prints the lines of a guide's output
# that are not indented by four spaces (the commands) as "<N>: <line>",
# N counting on over every call (PROSE_N), as awk's NR did for one case:
# that is what banned_hits reads, so no label is in it. PROSE_LABEL[N]
# keeps "<label> <n>", n counting within this call; PROSE_CASE_LINES is
# the number of lines this call printed. Run it in the current shell
# (with a redirect, not in $( )), so the counters carry over.
PROSE_N=0
PROSE_CASE_LINES=0
PROSE_LABEL=()
numbered_prose() {
  local line n=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in "    "*) continue ;; esac
    n=$((n + 1))
    PROSE_N=$((PROSE_N + 1))
    PROSE_LABEL[PROSE_N]="$2 $n"
    printf '%s: %s\n' "$PROSE_N" "$line"
  done <"$1"
  PROSE_CASE_LINES=$n
}

# labelled_hits: reads banned_hits' lines ("<N>: <text>") on stdin and
# prints each as "<label> <n>: <text>" (from PROSE_LABEL).
labelled_hits() {
  local hit
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    printf '%s: %s\n' "${PROSE_LABEL[${hit%%:*}]}" "${hit#*: }"
  done
}

test_every_guide_says_why_how_what_you_see_and_how_it_is_checked() {
  # Ease-of-use requirements: every guide says why the step is needed,
  # gives numbered steps, what the user sees when it worked, what to do
  # otherwise, and how the script checks it; on every OS, with and without
  # brew or winget. Its output has no banned word.
  # PBI-1.22: the 234 cases ran 8,973 processes on Linux. The guides of
  # one OS and tool share a folder (a guide only prints; its output is
  # the same as in a fresh folder), the shape is read with bash's own
  # regular expressions, and the banned words are looked for once, in
  # the prose of every case, each line labelled with its case.
  local d os g with label problem hits prose cases=0
  prose="$(tmpdir)/prose"
  : >"$prose"
  PROSE_N=0; PROSE_LABEL=()
  for os in macos linux windows; do
    for with in "" brew winget; do
      d="$(tmpdir)"
      on_os "$d" "$os"
      [ -z "$with" ] || fake_tool "$d" "$with"
      for g in $(guide_cases); do
        pre "$d" with_pack web with_dir "$d/f" "$g"
        label="$os/${with:-none}/$g"
        [ "$RC" -eq 0 ] || { cat "$d/err" >&2; die "$label failed"; }
        problem="$(guide_shape_problem "$d/out")"
        [ -z "$problem" ] || { cat "$d/out" >&2; die "$label: $problem"; }
        numbered_prose "$d/out" "$label" >>"$prose"
        [ "$PROSE_CASE_LINES" -gt 0 ] || die "$label: no prose collected"
        cases=$((cases + 1))
      done
    done
  done
  [ "$cases" -eq $((3 * 3 * $(guide_cases | grep -c .))) ] || die "only $cases cases were checked"
  hits="$(banned_hits <"$prose")"
  [ -z "$hits" ] || { printf '%s\n' "$hits" | labelled_hits >&2; die "banned word in a guide (cases above)"; }
}

test_the_every_guide_checks_catch_what_they_look_for() {
  # Guards the checks above (PBI-1.22): each missing part is named, a
  # banned word in prose is caught with its case, and one in an indented
  # command line is not.
  local d good f
  d="$(tmpdir)"
  good="$d/good"
  printf '%s\n' 'Something is missing on this computer.' \
    'Why this is needed: the script needs it for every one of its steps.' \
    '  1. Open the page and do what it says.' '    gh auth login' \
    'When it has worked: the page says you are done.' \
    'If you see something else: ask for help in the chat.' \
    'How the script checks it: it runs the tool once more.' >"$good"
  [ -z "$(guide_shape_problem "$good")" ] || die "a good guide was refused: $(guide_shape_problem "$good")"
  for f in 'no one-line title first|1s/.*/no full stop at the end/' 'no why|/^Why/d' 'no numbered step|/^  1\./d' \
    'no result|/^When it/d' 'no fallback|/^If you see/d' 'no check named|/^How the script/d' \
    'no one-line title first|1s/.*/Short./' 'no one-line title first|1s/^/  /' \
    'no why|s/^Why this is needed: .*/Why this is needed: too short./' 'no numbered step|s/^  1\. /1. /'; do
    sed "${f#*|}" "$good" >"$d/bad"
    [ "$(guide_shape_problem "$d/bad")" = "${f%%|*}" ] \
      || die "'${f#*|}': got '$(guide_shape_problem "$d/bad")', want '${f%%|*}'"
  done
  # The last line counts even without a line break after it.
  printf '%s' "$(cat "$good")" >"$d/last"
  [ -z "$(guide_shape_problem "$d/last")" ] || die "a last line with no line break was not read"
  # Command lines (4-space indent) are left out and not counted: one
  # with a banned word comes first here. Two cases in a row: the second
  # case's line is number 2 overall and number 1 within its case.
  printf '%s\n' '    open the repo page' 'Open the repo page.' >"$d/words"
  printf '%s\n' 'All is well here.' >"$d/clean"
  PROSE_N=0; PROSE_LABEL=()
  numbered_prose "$d/clean" linux/none/guide_npm >"$d/prose"
  numbered_prose "$d/words" macos/none/guide_git >>"$d/prose"
  [ "$PROSE_CASE_LINES" -eq 1 ] || die "numbered_prose counted $PROSE_CASE_LINES lines for one prose line"
  [ "$(sed -n 2p "$d/prose")" = "2: Open the repo page." ] || die "numbered_prose read the command line or counted it"
  [ "$(banned_hits <"$d/prose" | labelled_hits)" = "macos/none/guide_git 1: Open the repo page." ] \
    || die "the banned word in prose was not caught with its case, or the command line was read"
  # The why needs at least 6 words (5 words, each followed by a space,
  # then more): 5 in all is refused, 6 accepted.
  sed 's/^Why this is needed: .*/Why this is needed: one two three four five/' "$good" >"$d/bad"
  [ "$(guide_shape_problem "$d/bad")" = "no why" ] || die "a why of 5 words was accepted"
  sed 's/^Why this is needed: .*/Why this is needed: one two three four five six/' "$good" >"$d/ok6"
  [ -z "$(guide_shape_problem "$d/ok6")" ] || die "a why of 6 words was refused"
}

test_the_os_is_read_from_uname_and_the_linux_release_file() {
  local d want got
  for want in "Darwin macos" "Linux linux" "MINGW64_NT-10.0 windows" "MSYS_NT-10.0 windows" \
    "CYGWIN_NT-10.0 windows" "FreeBSD other"; do
    set -- $want
    d="$(tmpdir)"
    fake_tool "$d" uname "$1"
    pre "$d" eval 'say "$OS_KIND"'
    got="$(cat "$d/out")"
    [ "$got" = "$2" ] || die "uname $1 gave $got, want $2"
  done
  for want in "debian apt" "fedora dnf" "arch pacman" "suse zypper" "other none"; do
    set -- $want
    d="$(tmpdir)"
    on_os "$d" linux "$1"
    pre "$d" eval 'say "${LINUX_PM:-none}"'
    got="$(cat "$d/out")"
    [ "$got" = "$2" ] || die "release $1 gave $got, want $2"
  done
  # Carriage returns (a file saved on Windows) and no last line break.
  d="$(tmpdir)"
  fake_tool "$d" uname Linux
  printf 'NAME="Fedora"\r\nID=fedora\r' >"$d/os-release"
  pre "$d" eval 'say "${LINUX_PM:-none}"'
  [ "$(cat "$d/out")" = dnf ] || die "a release file with carriage returns gave $(cat "$d/out")"
}

test_wsl_is_read_from_the_kernel_release_on_linux_only() {
  # r2e: in WSL (Linux on Windows) the Windows npm is on PATH. WSL is
  # read from the kernel release (BOOTSTRAP_KERNEL_RELEASE, by default
  # /proc/sys/kernel/osrelease): WSL 2 and WSL 1 name Microsoft in it.
  local d want
  for want in "5.15.167.4-microsoft-standard-WSL2 yes" "4.4.0-19041-Microsoft yes" \
    "6.8.0-45-generic none" "6.6.87.2-MICROSOFT-standard-WSL2 yes"; do
    set -- $want
    d="$(tmpdir)"
    on_wsl "$d" "$1"
    pre "$d" eval 'say "${LINUX_WSL:-none}"'
    [ "$(cat "$d/out")" = "$2" ] || { cat "$d/err" >&2; die "kernel release $1 gave $(cat "$d/out"), want $2"; }
  done
  # Error paths: no kernel release file, an empty one, one with carriage
  # returns and no line break; and a Microsoft release on another OS
  # (only Linux can be WSL).
  d="$(tmpdir)"
  on_os "$d" linux debian
  pre "$d" eval 'say "${LINUX_WSL:-none}"'
  [ "$(cat "$d/out")" = none ] || die "no kernel release file gave $(cat "$d/out")"
  d="$(tmpdir)"
  on_os "$d" linux debian
  : >"$d/kernel-release"
  pre "$d" eval 'say "${LINUX_WSL:-none}"'
  [ "$(cat "$d/out")" = none ] || die "an empty kernel release file gave $(cat "$d/out")"
  d="$(tmpdir)"
  on_os "$d" linux debian
  printf '5.15.167.4-microsoft-standard-WSL2\r' >"$d/kernel-release"
  pre "$d" eval 'say "${LINUX_WSL:-none}"'
  [ "$(cat "$d/out")" = yes ] || die "a kernel release with a carriage return gave $(cat "$d/out")"
  for want in macos windows; do
    d="$(tmpdir)"
    on_os "$d" "$want"
    printf '%s\n' 5.15.167.4-microsoft-standard-WSL2 >"$d/kernel-release"
    pre "$d" eval 'say "${LINUX_WSL:-none}"'
    [ "$(cat "$d/out")" = none ] || die "$want with a Microsoft kernel release gave $(cat "$d/out")"
  done
}

test_every_say_command_call_on_a_line_is_checked() {
  # Review note B (#136): only the first call on a line was checked, and
  # a sentence that starts with a command word passed.
  local copy hits from n
  copy="$(plant 'cmd_x() {' \
    '  say_command "gh auth status"; say_command "Then open the page"' \
    '  say_command "git push, then open the page and approve it"' \
    '  say_command "brew install gh."' \
    '  say_command "gh auth status"; say_command "git --version"' \
    '}')"
  from="$(planted_from)"
  hits="$(command_arg_violations "$copy" | only_planted "$from")"
  n="$(printf '%s\n' "$hits" | grep -c . || true)"
  [ "$n" -eq 3 ] || { printf '%s\n' "$hits" >&2; die "flagged $n, want the first 3 planted lines"; }
  ! printf '%s\n' "$hits" | awk -F'[:\t]' -v f="$from" '$1 == f + 4' | grep . >/dev/null \
    || { printf '%s\n' "$hits" >&2; die "two good commands on one line were flagged"; }
}

test_the_literal_scan_opt_out_marker_leaves_out_only_its_own_line() {
  # #136 review, note D: matching a tool's own text (here gh's) needs a
  # literal with a banned word in it. "# not-a-message" at the end of
  # the line leaves that line's literals out of the scan, and nothing
  # else: the same literal unmarked, a marked message helper call, a
  # literal on the next line, a marker that is not the whole comment and
  # a literal over several lines are all still caught.
  local copy hits from got
  copy="$(plant 'cmd_x() {' \
    '  case "$raw" in *"Repository not found"*) ;; esac # not-a-message' \
    '  case "$raw" in *"Repository not found"*) ;; esac' \
    '  say "The repo was not found." # not-a-message' \
    '  # not-a-message' \
    '  local m="Open the repo page"' \
    '  x="the repo"; y="other text" # not-a-message: gh text' \
    '  help="$(run_gh repo create --help 2>&1)" || help="" # not-a-message' \
    '  z="first line # not-a-message' \
    '  the repo"' \
    '  w="first line' \
    '  the repo" # not-a-message' \
    '}')"
  # #149 review, finding 1: the multi-line literal that ends on a marked
  # line (planted lines 11 and 12) is the shape that matters; it is
  # flagged on its first line.
  from="$(planted_from)"
  hits="$(all_banned_hits "$copy" | only_planted "$from")"
  got="$(printf '%s\n' "$hits" | awk -F: -v f="$from" 'NF { printf "%s%d", sep, $1 - f + 1; sep = " " }')"
  [ "$got" = "3 4 6 7 9 11" ] || { printf '%s\n' "$hits" >&2; die "flagged planted lines [$got], want [3 4 6 7 9 11]"; }
}

test_ask_terminal_says_no_at_once_when_there_is_no_terminal() {
  # #148 review, finding 2: with no terminal to read from, the answer is
  # no, the question line is ended, and nothing is read from stdin.
  local d
  d="$(tmpdir)"
  printf 'yes\n' >"$d/in"
  set +e
  ( load_script
    export BOOTSTRAP_TTY="$d/no-such-terminal"
    rc=0
    ask_terminal "Why it is asked, in a sentence." "Run it now? (yes or no)" || rc=$?
    echo "rc=$rc"
    IFS= read -r line; echo "stdin=$line"
  ) <"$d/in" >"$d/out" 2>"$d/err"
  set -e
  [ "$(cat "$d/out")" = "$(printf '%s\n' 'Why it is asked, in a sentence.' 'Run it now? (yes or no) [no]: ' 'rc=1' 'stdin=yes')" ] \
    || { cat "$d/out" "$d/err" >&2; die "no terminal: not a plain no"; }
  [ ! -s "$d/err" ] || { cat "$d/err" >&2; die "an error was shown"; }
}

# Keys typed before a question (end-to-end run 1 on v2.7.0, finding r1f):
# an Enter pressed while the script was busy waits at the terminal, and
# the next read takes it, so it answered "Run it now?" with no before the
# user saw the question. Before such a question the script discards
# what is waiting at the terminal (discard_typeahead): stty -g, stty
# -icanon min 0 time 0, one dd read, then the saved mode back.
# typeahead_tools <dir>: a stand-in stty and dd in <dir>/bin. Both log
# each call to <dir>/tty.log. stty -g prints "saved-state";
# STUB_STTY_FAILS names the call that fails: g (stty -g), set (stty
# -icanon min 0 time 0) or restore (stty saved-state). The dd stands for
# the read of what is waiting at a terminal: it reads one line, the one
# typed before the question, and logs it. With BOOTSTRAP_INPUT_TERMINAL=yes
# a file counts as a terminal, so a file "<waiting line><next line>"
# plays a terminal with one line waiting. STUB_DD_SHOWN=<text>: dd also
# logs whether <text> (the question) is in <dir>/out already, so a test
# sees the discard come before the question. STUB_DD_INT set: dd sends
# Ctrl-C (SIGINT) to the shell that started it, as a user's Ctrl-C
# during the discard.
typeahead_tools() {
  local d="$1" text
  IFS= read -r -d '' text <<EOF || true
printf '%s\n' "stty \$*" >>"$d/tty.log"
case "\$*:\${STUB_STTY_FAILS:-}" in
  -g:g | "-icanon min 0 time 0:set" | saved-state:restore) exit 1 ;;
esac
[ "\$*" != -g ] || echo saved-state
EOF
  write_stand_in "$d/bin/stty" "$text"
  IFS= read -r -d '' text <<EOF || true
printf '%s\n' "dd \$*" >>"$d/tty.log"
if [ -n "\${STUB_DD_SHOWN:-}" ]; then
  if grep -F -e "\$STUB_DD_SHOWN" "$d/out" >/dev/null 2>&1; then shown=yes; else shown=no; fi
  printf '%s\n' "dd: question already shown: \$shown" >>"$d/tty.log"
fi
[ -z "\${STUB_DD_INT:-}" ] || kill -INT "\$PPID"
line=""
IFS= read -r line || true
printf '%s\n' "dd read: [\$line]" >>"$d/tty.log"
EOF
  write_stand_in "$d/bin/dd" "$text"
}

# The calls of a discard that worked, with an empty line waiting.
TYPEAHEAD_DISCARDED="$(printf '%s\n' 'stty -g' 'stty -icanon min 0 time 0' 'dd bs=65536 count=1' 'dd read: []' 'stty saved-state')"

test_the_run_offer_is_not_answered_by_keys_typed_before_it() {
  # r1f: an empty line waits at the terminal; the line typed after the
  # question is yes. The waiting line is discarded, the question reads
  # yes, and stdin is not touched.
  local d
  d="$(tmpdir)"
  typeahead_tools "$d"
  printf '\nyes\n' >"$d/tty"
  printf 'from stdin\n' >"$d/in"
  set +e
  ( load_script
    export PATH="$d/bin:$PATH" BOOTSTRAP_TTY="$d/tty" BOOTSTRAP_INPUT_TERMINAL=yes
    rc=0
    ask_terminal "Why it is asked, in a sentence." "Run it now? (yes or no)" || rc=$?
    echo "rc=$rc"
    IFS= read -r line; echo "stdin=$line"
  ) <"$d/in" >"$d/out" 2>"$d/err"
  set -e
  [ "$(cat "$d/out")" = "$(printf '%s\n' 'Why it is asked, in a sentence.' 'Run it now? (yes or no) [no]: ' 'rc=0' 'stdin=from stdin')" ] \
    || { cat "$d/out" "$d/err" "$d/tty.log" >&2; die "the waiting line answered the offer"; }
  [ "$(cat "$d/tty.log")" = "$TYPEAHEAD_DISCARDED" ] || { cat "$d/tty.log" >&2; die "not discarded as expected"; }
  [ ! -s "$d/err" ] || { cat "$d/err" >&2; die "an error was shown"; }
}

test_keys_are_discarded_only_at_a_terminal_never_from_a_file_or_pipe() {
  # r1f: answers given in a file or a pipe (the tests, a user's answers)
  # are all answers: nothing is discarded, and the first line answers, as
  # before. Checked with the hook unset (the shell is asked: [ -t 0 ]) and
  # with BOOTSTRAP_INPUT_TERMINAL=no, for the offer, "Proceed?" and the
  # pause of a guide.
  local d hook rc
  for hook in unset no; do
    d="$(tmpdir)"
    typeahead_tools "$d"
    printf '\nyes\n' >"$d/tty"
    printf '\nyes\n' >"$d/in"
    set +e
    ( load_script
      export PATH="$d/bin:$PATH" BOOTSTRAP_TTY="$d/tty"
      if [ "$hook" = unset ]; then unset BOOTSTRAP_INPUT_TERMINAL; else export BOOTSTRAP_INPUT_TERMINAL=no; fi
      rc=0
      ask_terminal "Why it is asked, in a sentence." "Run it now? (yes or no)" || rc=$?
      echo "offer rc=$rc"
      rc=0
      wait_for_enter <<<"$(printf '\nq')" || rc=$?
      echo "pause rc=$rc"
      confirm_plan
    ) <"$d/in" >"$d/out" 2>"$d/err"
    rc=$?
    set -e
    grep -qx 'offer rc=1' "$d/out" || { cat "$d/out" >&2; die "[$hook] the offer did not read the first line of the file"; }
    grep -qx 'pause rc=0' "$d/out" || { cat "$d/out" >&2; die "[$hook] the pause did not read the first line of the pipe"; }
    [ "$rc" -eq 1 ] && grep '^What happened: You answered no' "$d/err" >/dev/null \
      || { cat "$d/out" "$d/err" >&2; die "[$hook] Proceed? did not read the first line of the file"; }
    [ ! -e "$d/tty.log" ] || { cat "$d/tty.log" >&2; die "[$hook] stty or dd ran for answers from a file"; }
  done
}

test_a_terminal_whose_mode_cannot_be_set_is_read_as_it_is() {
  # r1f, error paths: the discard never blocks a question and never
  # leaves the terminal changed. When stty -g fails, nothing more runs;
  # when the mode cannot be set, dd (which could then wait for a whole
  # line) does not run and the saved mode is put back; when the saved
  # mode cannot be put back, stty sane is tried. The question is asked
  # and read in each case.
  local d fails want rc_want
  for fails in g set restore; do
    d="$(tmpdir)"
    typeahead_tools "$d"
    printf '\nyes\n' >"$d/tty"
    case "$fails" in
      g) want="stty -g"; rc_want=1 ;;
      set) want="$(printf '%s\n' 'stty -g' 'stty -icanon min 0 time 0' 'stty saved-state')"; rc_want=1 ;;
      restore) want="$(printf '%s\n' "$TYPEAHEAD_DISCARDED" 'stty sane')"; rc_want=0 ;;
    esac
    set +e
    ( load_script
      export PATH="$d/bin:$PATH" BOOTSTRAP_TTY="$d/tty" BOOTSTRAP_INPUT_TERMINAL=yes STUB_STTY_FAILS="$fails"
      rc=0
      ask_terminal "Why it is asked, in a sentence." "Run it now? (yes or no)" || rc=$?
      echo "rc=$rc"
    ) </dev/null >"$d/out" 2>"$d/err"
    set -e
    [ "$(cat "$d/tty.log")" = "$want" ] || { cat "$d/tty.log" >&2; die "[$fails] calls differ"; }
    [ "$(cat "$d/out")" = "$(printf '%s\n' 'Why it is asked, in a sentence.' 'Run it now? (yes or no) [no]: ' "rc=$rc_want")" ] \
      || { cat "$d/out" "$d/err" >&2; die "[$fails] the question was not asked and read"; }
    [ ! -s "$d/err" ] || { cat "$d/err" >&2; die "[$fails] an error was shown"; }
  done
}

test_ctrl_c_during_the_discard_puts_the_terminal_mode_back() {
  # #247 review, B1: Ctrl-C while the terminal is set to -icanon min 0
  # time 0 (here: during the dd read) stops the script with exit 130, and
  # the saved mode is still put back (by leave_script), once: a terminal
  # left that way makes every later read return nothing at once, in the
  # user's own shell too, which is r1f again. For the offer (the terminal
  # BOOTSTRAP_TTY) and for "Proceed?" (stdin).
  local d mode rc
  for mode in offer proceed; do
    d="$(tmpdir)"
    typeahead_tools "$d"
    printf '\nyes\n' >"$d/tty"
    printf '\nyes\n' >"$d/in"
    set +e
    ( load_script
      export PATH="$d/bin:$PATH" BOOTSTRAP_TTY="$d/tty" BOOTSTRAP_INPUT_TERMINAL=yes STUB_DD_INT=1
      catch_stops
      case "$mode" in
        offer) ask_terminal "Why it is asked, in a sentence." "Run it now? (yes or no)" ;;
        proceed) confirm_plan ;;
      esac
      echo "not stopped"
    ) <"$d/in" >"$d/out" 2>"$d/err"
    rc=$?
    set -e
    [ "$rc" -eq 130 ] || { cat "$d/out" "$d/err" "$d/tty.log" >&2; die "[$mode] exit $rc, want 130 (Ctrl-C)"; }
    [ "$(cat "$d/tty.log")" = "$TYPEAHEAD_DISCARDED" ] \
      || { cat "$d/tty.log" >&2; die "[$mode] the saved mode was not put back once after Ctrl-C"; }
  done
}

test_the_discard_comes_before_the_question_is_shown() {
  # #247 review, N2: what is waiting is discarded before the question is
  # printed, never after, so nothing typed once the question is shown is
  # thrown away. The stand-in dd looks at the output so far.
  local d mode shown
  for mode in offer proceed pause; do
    d="$(tmpdir)"
    typeahead_tools "$d"
    printf '\nyes\n' >"$d/tty"
    printf '\nq\n' >"$d/in"
    case "$mode" in
      offer) shown='Run it now?' ;;
      proceed) shown='If you answer yes' ;;
      pause) shown='Press Enter' ;;
    esac
    set +e
    ( load_script
      export PATH="$d/bin:$PATH" BOOTSTRAP_TTY="$d/tty" BOOTSTRAP_INPUT_TERMINAL=yes STUB_DD_SHOWN="$shown"
      case "$mode" in
        offer) ask_terminal "Why it is asked, in a sentence." "Run it now? (yes or no)" ;;
        proceed) confirm_plan ;;
        pause) wait_for_enter ;;
      esac
    ) <"$d/in" >"$d/out" 2>"$d/err"
    set -e
    grep -F -e "$shown" "$d/out" >/dev/null || { cat "$d/out" "$d/err" >&2; die "[$mode] the question was not shown"; }
    grep -qx 'dd: question already shown: no' "$d/tty.log" \
      || { cat "$d/tty.log" "$d/out" >&2; die "[$mode] the discard did not come before the question"; }
  done
}

test_keys_typed_before_a_question_are_discarded_at_a_real_terminal() {
  # r1f at a real terminal (a pseudo-terminal from python3's pty module,
  # with this harness's bash: macOS /bin/bash 3.2 and its BSD stty and dd
  # in CI). The child reads a first line "go" to start, so a second line
  # sent with it is waiting before the question, as a key pressed while
  # the script was busy. The driver types yes only once the question is
  # shown. With a line waiting and with none, the offer and "Proceed?"
  # read that yes, and nothing waits for ever. And (#247 review, B1)
  # Ctrl-C during the discard, from a dd that sends it and then reads as
  # the real one: the script stops with 130 and the terminal reads whole
  # lines again (icanon). Python3 with its pty module is needed, except
  # on Windows, where python has none: skipped there, visibly (#247
  # review, N1: a silent skip looked like a pass).
  local d mode waiting call real_dd
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -I -c 'import pty, termios' >/dev/null 2>&1; then
    case "$(uname -s)" in
      MINGW* | MSYS* | CYGWIN*) skip_test "no python3 with a pty module on Windows"; return 0 ;;
    esac
    die "python3 with its pty module is needed for this test here (it is skipped only on Windows)"
  fi
  d="$(tmpdir)"
  real_dd="$(command -v dd)"
  mkdir -p "$d/int"
  write_stand_in "$d/int/dd" "kill -INT \"\$PPID\"; exec '$real_dd' \"\$@\""
  cat >"$d/drive.py" <<'EOF'
import os, pty, sys, time, select
bash, script, call, first = sys.argv[1:5]
child = ('. "$1"; unset BOOTSTRAP_TTY BOOTSTRAP_INPUT_TERMINAL; export NO_COLOR=1; '
         'IFS= read -r go; ' + call)
pid, fd = pty.fork()
if pid == 0:
    os.execv(bash, [bash, '-c', child, '_', script])
os.write(fd, first.encode().replace(b'|', b'\n'))
out, typed, deadline = b'', False, time.time() + 30
while time.time() < deadline:
    if not typed and b'[no]:' in out:
        os.write(fd, b'yes\n')
        typed = True
    r, _, _ = select.select([fd], [], [], 0.2)
    if not r:
        continue
    try:
        got = os.read(fd, 4096)
    except OSError:
        break
    if not got:
        break
    out += got
else:
    os.kill(pid, 9)
    out += b'\nTIMEOUT\n'
os.waitpid(pid, 0)
sys.stdout.write(out.decode('utf-8', 'replace'))
EOF
  for mode in offer proceed; do
    for waiting in yes no; do
      case "$mode" in
        offer) call='ask_terminal "Why it is asked." "Run it now? (yes or no)"' ;;
        proceed) call='confirm_plan' ;;
      esac
      call="if ( $call ); then echo ANSWER=yes; else echo ANSWER=no; fi"
      if [ "$waiting" = yes ]; then first='go||'; else first='go|'; fi
      python3 -I "$d/drive.py" "$BASH" "$SCRIPT" "$call" "$first" >"$d/out.$mode.$waiting" 2>&1 || true
      grep -q 'ANSWER=yes' "$d/out.$mode.$waiting" \
        || { cat "$d/out.$mode.$waiting" >&2; die "[$mode, line waiting: $waiting] the yes typed after the question was not what answered it"; }
    done
  done
  for mode in offer proceed; do
    case "$mode" in
      offer) call='ask_terminal "Why it is asked." "Run it now? (yes or no)"' ;;
      proceed) call='confirm_plan' ;;
    esac
    # The script sets -e: the 130 is caught, so the shell goes on to stty -a.
    call="rc=0; ( PATH=\"$d/int:\$PATH\"; catch_stops; $call ) || rc=\$?; echo \"EXIT=\$rc\"; stty -a"
    python3 -I "$d/drive.py" "$BASH" "$SCRIPT" "$call" 'go|' >"$d/out.$mode.int" 2>&1 || true
    grep -q 'EXIT=130' "$d/out.$mode.int" || { cat "$d/out.$mode.int" >&2; die "[$mode, Ctrl-C] not stopped with 130"; }
    grep -E '(^|[[:space:]])icanon([[:space:];]|$)' "$d/out.$mode.int" >/dev/null \
      || { cat "$d/out.$mode.int" >&2; die "[$mode, Ctrl-C] the terminal was left without icanon"; }
  done
}

test_non_interactive_reports_every_option_problem_before_the_checks() {
  # #148 review, finding 5: with --non-interactive the options are checked
  # before the checks of this computer and of GitHub, so one run lists
  # every missing or wrong option even when gh is missing.
  local d
  d="$(tmpdir)"
  on_os "$d" linux debian
  working_git "$d"
  echo 9999 >"$d/gh-missing"
  whole "$d" --non-interactive --name my-app --pack nodes
  expect_rc 2 "$d"
  grep -qE -- '^    - --pack: ' "$d/err" || { cat "$d/err" >&2; die "the wrong pack was not listed"; }
  grep -qE -- '^    - --description: ' "$d/err" || { cat "$d/err" >&2; die "the missing description was not listed"; }
  grep -qE -- '^    - --license: ' "$d/err" || { cat "$d/err" >&2; die "the missing licence was not listed"; }
  [ ! -e "$d/gh.log" ] || { cat "$d/gh.log" >&2; die "gh was used before the options were reported"; }
  expect_no_out "$d" "==> Checking"
  # With git missing, git's settings cannot be read: the git name and
  # email are not reported as missing; the git guide comes first.
  d="$(tmpdir)"
  on_os "$d" linux debian
  missing "$d" git
  fake_home "$d/home"
  whole "$d" --non-interactive --yes "${REQUIRED_OPTS[@]}"
  expect_rc 3 "$d"
  expect_out "$d" "git is not installed."
  ! grep -q -- '--git-name' "$d/err" || { cat "$d/err" >&2; die "the git name was listed although git is missing"; }
}

# ---------- guided preflight: GitHub checks ----------
# After the checks of this computer and before the questions, the script
# checks that gh is signed in to GitHub (gh api -i user, which also gives
# the defaults for the owner and product owner name and the permissions
# gh has) and that it is the current published version (CHANGELOG.md of
# the bootstrapper, read through the contents API). After the questions
# it checks that gh has the permissions the setup needs for the chosen
# visibility, and that OWNER/NAME does not exist yet. Each uses the same
# guided loop as the checks of this computer. An answer from GitHub that
# has no guide stops with a plain message, the next action and gh's raw
# text below it, exit 1.

with_vis() { IN_VISIBILITY="$1"; shift; "$@"; }
with_project() { IN_OWNER="$1"; IN_NAME="$2"; shift 2; "$@"; }

# expect_err_shape <dir> <first line pattern>: the plain error, then the
# next action, then the raw text under "Details for support".
expect_err_shape() {
  sed -n 1p "$1/err" | grep -E "^What happened: $2" >/dev/null || { cat "$1/err" >&2; die "first line is not: $2"; }
  sed -n 2p "$1/err" | grep -E '^What to do next: .{10,}' >/dev/null || { cat "$1/err" >&2; die "no next action"; }
  sed -n 3p "$1/err" | grep -xF 'Details for support (you can ignore these):' >/dev/null || { cat "$1/err" >&2; die "raw text not introduced"; }
  [ "$(sed -n '4,$p' "$1/err" | grep -vc '^    ')" -eq 0 ] || { cat "$1/err" >&2; die "raw text not indented below"; }
}

# expect_sign_in_first_before_the_code <dir>: the guide says that GitHub
# may first ask the user to sign in (end-to-end run 2 repeated, r2h), in
# a step before the one where the code is pasted.
expect_sign_in_first_before_the_code() {
  local s c
  expect_out "$1" "If your browser is not signed in to GitHub, GitHub first asks you to sign in: your user name or email address, your password, and a two-factor code if you use one. Then it shows the page for the code."
  s="$(grep -nF 'If your browser is not signed in to GitHub' "$1/out" | head -1 | cut -d: -f1)"
  c="$(grep -nF 'paste the code' "$1/out" | head -1 | cut -d: -f1)"
  [ -n "$c" ] && [ "$s" -lt "$c" ] || { cat "$1/out" >&2; die "the sign-in step does not come before the step with the code"; }
}

test_a_signed_out_gh_is_guided_to_sign_in() {
  # gh exits 4 when it is not signed in. The guide shows the sign-in
  # command of the README's step 0 for the user to run; it is not offered
  # (signing in is the README's step 0, done before the script exists).
  local d
  d="$(tmpdir)"
  export STUB_GH_USER_FAIL=signed-out
  printf 'yes\n' >"$d/tty"
  pre "$d" ni preflight_github_account
  expect_rc 3 "$d"
  expect_out "$d" "gh (the GitHub command-line tool) is not signed in to your GitHub account."
  grep -qxF '    gh auth login -h github.com -p https -w -s workflow' "$d/out" \
    || { cat "$d/out" >&2; die "the sign-in command is not shown"; }
  expect_out "$d" "Authenticate Git"
  # End-to-end run 2, r2c: under WSL gh cannot open a browser; the guide
  # says to open the device page yourself, as the README does.
  expect_out "$d" "if the browser does not open, open https://github.com/login/device yourself"
  # Run 2 repeated, r2h: on a browser not signed in to GitHub, the device
  # page first asks for the GitHub sign-in; the guide says so before the
  # step with the code.
  expect_sign_in_first_before_the_code "$d"
  expect_out "$d" "To start again, run this command:"
  expect_no_out "$d" "Run it now?"
  expect_nothing_ran "$d"
  sed -n 1p "$d/err" | grep -E '^What happened: gh .* is not signed in' >/dev/null || { cat "$d/err" >&2; die "no plain error"; }
  # Interactive: signed in while the script waits, Enter checks again.
  d="$(tmpdir)"
  echo 1 >"$d/user-fails"
  printf '\n' >"$d/in"
  pre "$d" preflight_github_account
  expect_rc 0 "$d"
  expect_out "$d" "Press Enter to check again"
  [ "$(tail -1 "$d/out")" = "    Done. gh is signed in to GitHub as octo-user." ] || { cat "$d/out" >&2; die "no done line"; }
  [ "$(grep -c "$(printf '\tuser\t')" "$d/gh.log")" -eq 2 ] || { cat "$d/gh.log" >&2; die "the account was not read twice"; }
}

test_a_sign_in_github_no_longer_accepts_is_guided_with_details() {
  local d
  d="$(tmpdir)"
  export STUB_GH_USER_FAIL=expired
  pre "$d" ni preflight_github_account
  expect_rc 3 "$d"
  expect_out "$d" "GitHub no longer accepts the sign-in that gh (the GitHub command-line tool) has on this computer."
  grep -qxF '    gh auth login -h github.com -p https -w -s workflow' "$d/out" || { cat "$d/out" >&2; die "no sign-in command"; }
  expect_out "$d" "Details for support (you can ignore these):"
  grep -qxF '    HTTP 401: Bad credentials' "$d/out" || { cat "$d/out" >&2; die "raw text not shown below the guide"; }
}

test_github_out_of_reach_is_guided_and_checked_again() {
  local d
  d="$(tmpdir)"
  export STUB_GH_USER_FAIL=offline
  echo 1 >"$d/user-fails"
  printf '\n' >"$d/in"
  pre "$d" preflight_github_account
  expect_rc 0 "$d"
  expect_out "$d" "The script could not reach GitHub."
  expect_out "$d" "https://www.githubstatus.com"
  grep -qxF '    error connecting to api.github.com' "$d/out" || { cat "$d/out" >&2; die "gh's text not shown below the guide"; }
  [ "$(tail -1 "$d/out")" = "    Done. gh is signed in to GitHub as octo-user." ] || { cat "$d/out" >&2; die "no done line"; }
}

test_other_github_errors_are_explained_with_the_raw_text_below() {
  # Every other answer: a plain message chosen from the status and the
  # message GitHub sent, the next action, the command to start again,
  # and the raw text below, exit 1; for each GitHub call of the preflight.
  local d mode want
  for mode in "server GitHub had a problem of its own" "rate-limit GitHub has paused" \
    "forbidden GitHub refused" "teapot Something unexpected happened"; do
    want="${mode#* }"; mode="${mode%% *}"
    d="$(tmpdir)"
    export STUB_GH_USER_FAIL="$mode"
    pre "$d" ni preflight_github_account
    expect_rc 1 "$d"
    expect_err_shape "$d" "$want"
    grep -qE '^    HTTP [0-9]{3}: .' "$d/err" || { cat "$d/err" >&2; die "$mode: status and message not below"; }
    grep -qE '^    gh: .*\(HTTP [0-9]{3}\)$' "$d/err" || { cat "$d/err" >&2; die "$mode: gh's text not below"; }
    expect_out "$d" "To start again, run this command:"
    unset STUB_GH_USER_FAIL
  done
  d="$(tmpdir)"
  export STUB_GH_CHANGELOG_FAIL=not-found
  pre "$d" ni preflight_published_version
  expect_rc 1 "$d"
  expect_err_shape "$d" ".*(current version|bootstrapper)"
  grep -qxF '    HTTP 404: Not Found' "$d/err" || { cat "$d/err" >&2; die "404 not shown below"; }
  unset STUB_GH_CHANGELOG_FAIL
  d="$(tmpdir)"
  export STUB_GH_REPO_FAIL=forbidden
  pre "$d" ni with_project acme my-app preflight_project_absent
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub refused"
  grep -qxF '    HTTP 403: Resource not accessible by integration' "$d/err" || { cat "$d/err" >&2; die "403 not shown below"; }
}

test_github_sign_in_is_checked_before_the_questions() {
  # #146 review note: a user who is not signed in got exit 1 partway
  # through the questions. Now the sign-in is checked before the first
  # question, with its guide (exit 3 with --non-interactive), also when
  # the owner and product owner name are given and need no default.
  local d
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_USER_FAIL=signed-out
  printf '%s\n' my-app q >"$d/in"
  whole "$d"
  expect_rc 3 "$d"
  expect_out "$d" "is not signed in to your GitHub account."
  expect_no_out "$d" "Project name"
  d="$(tmpdir)"
  working_git "$d"
  whole "$d" --non-interactive --yes "${REQUIRED_OPTS[@]}" --owner acme --po-name Ada
  expect_rc 3 "$d"
  expect_out "$d" "is not signed in to your GitHub account."
  unset STUB_GH_USER_FAIL
  # Signed in: the answers to the questions use the account it read,
  # which is read once.
  d="$(tmpdir)"
  working_git "$d"
  fake_tool "$d" npm 10.0.0
  printf '%s\n' my-app "" "Lends tools." "" "" python "" none "" "" "" no >"$d/in"
  whole "$d"
  expect_rc 1 "$d"
  expect_out "$d" "Owner [octo-user]: "
  [ "$(grep -c "$(printf '\tuser\t')" "$d/gh.log")" -eq 2 ] \
    || { cat "$d/gh.log" >&2; die "the account was not read once before the questions and once for the permissions"; }
  grep -n '==> Checking that gh is signed in' "$d/out" | head -1 | cut -d: -f1 >"$d/a"
  grep -n '^Project name: ' "$d/out" | head -1 | cut -d: -f1 >"$d/q"
  [ "$(cat "$d/a")" -lt "$(cat "$d/q")" ] || { cat "$d/out" >&2; die "the sign-in was checked after the questions"; }
}

test_a_missing_workflow_permission_offers_the_refresh_and_checks_again() {
  # The refresh runs only after a yes typed at the terminal, through the
  # runner, with gh's prompts on for that one command; then the check
  # runs again at once.
  local d
  d="$(tmpdir)"
  export STUB_GH_SCOPES="repo, read:org, gist" STUB_GH_SCOPES_LATER="repo, read:org, gist, workflow"
  echo 1 >"$d/scopes-old"
  printf 'yes\n' >"$d/tty"
  prepare "$d"
  local run_text
  IFS= read -r -d '' run_text <<'RUN' || true
printf '%s|%s\n' "$*" "${GH_PROMPT_DISABLED-<unset>}" >>"$STUB_RUN_LOG"
RUN
  write_stand_in "$d/run" "$run_text"
  pre "$d" with_vis public preflight_github_permissions
  expect_rc 0 "$d"
  expect_out "$d" "does not have every permission on GitHub that the setup needs."
  expect_out "$d" "workflow (to add and change the files that run your project's checks)"
  grep -qxF '    gh auth refresh -h github.com -s workflow' "$d/out" || { cat "$d/out" >&2; die "the refresh command is not shown"; }
  expect_out "$d" "https://github.com/login/device"
  expect_sign_in_first_before_the_code "$d"
  [ "$(cat "$d/run.log")" = "gh auth refresh -h github.com -s workflow|<unset>" ] \
    || { cat "$d/run.log" >&2; die "the refresh did not run once, with gh's prompts on"; }
  expect_no_out "$d" "Press Enter"
  [ "$(tail -1 "$d/out")" = "    Done. gh has the permissions on GitHub that the setup needs." ] || { cat "$d/out" >&2; die "no done line"; }
  ! grep -q "$(printf '\tauth\t')" "$d/gh.log" || die "the refresh ran through gh with prompts off"
}

test_the_refresh_asks_for_every_missing_permission() {
  # Public: public_repo (or repo) and workflow; private: repo and
  # workflow. The offer adds whatever is missing to workflow.
  local d c vis scopes want
  for c in "public|read:org, gist|gh auth refresh -h github.com -s public_repo,workflow" \
    "private|public_repo, workflow|gh auth refresh -h github.com -s repo,workflow" \
    "private|read:org|gh auth refresh -h github.com -s repo,workflow" \
    "public|public_repo|gh auth refresh -h github.com -s workflow" \
    "private|repo|gh auth refresh -h github.com -s workflow"; do
    vis="${c%%|*}"; scopes="${c#*|}"; want="${scopes#*|}"; scopes="${scopes%%|*}"
    d="$(tmpdir)"
    export STUB_GH_SCOPES="$scopes"
    printf 'yes\n' >"$d/tty"
    printf 'q\n' >"$d/in"
    pre "$d" with_vis "$vis" preflight_github_permissions
    expect_rc 3 "$d"
    grep -qxF "    $want" "$d/out" || { cat "$d/out" >&2; die "$c: offer not shown"; }
    # What ran is exactly what was shown, once.
    [ "$(cat "$d/run.log")" = "$want" ] || { cat "$d/run.log" >&2; die "$c: ran something else"; }
  done
  for c in "public|public_repo, workflow" "public|repo, workflow" "private|repo, workflow, gist"; do
    d="$(tmpdir)"
    export STUB_GH_SCOPES="${c#*|}"
    pre "$d" ni with_vis "${c%%|*}" preflight_github_permissions
    expect_rc 0 "$d"
    expect_no_out "$d" "does not have every permission"
  done
}

# GH_GIT_QUESTION: the step for gh's own question, in every guide that
# has the user run gh auth login or gh auth refresh. End-to-end run 1
# (repeated), finding r1b: the user had to ask what to answer. gh v2.93.0
# (pkg/cmd/auth/shared/git_credential.go, used by both login and refresh)
# asks it, default Yes, before the one-time code, unless gh already signs
# git in to GitHub; so "If", and right after the command.
GH_GIT_QUESTION='If gh asks "Authenticate Git with your GitHub credentials?", answer Yes: type y and press Enter, or just press Enter.'
gg_permissions_public() { PERM_PROBLEM=missing; PERM_MISSING="public_repo workflow"; IN_VISIBILITY=public; guide_github_permissions; }

test_every_gh_sign_in_guide_says_what_to_answer_when_gh_asks_to_authenticate_git() {
  # For the sign-in guide (signed out, sign-in no longer accepted) and
  # each refresh the permissions guide shows: the command, then at once
  # the step for the question, once, then the one-time code step.
  local d c g want cmd_n q_n code_n
  for c in "gg_signed_out|gh auth login -h github.com -p https -w -s workflow" \
    "gg_expired|gh auth login -h github.com -p https -w -s workflow" \
    "gg_permissions|gh auth refresh -h github.com -s workflow" \
    "gg_permissions_public|gh auth refresh -h github.com -s public_repo,workflow" \
    "gg_permissions_repo|gh auth refresh -h github.com -s repo,workflow"; do
    g="${c%%|*}"; want="${c#*|}"
    d="$(tmpdir)"
    pre "$d" "$g"
    [ "$RC" -eq 0 ] || { cat "$d/err" >&2; die "$g failed"; }
    cmd_n="$(grep -nxF -- "    $want" "$d/out" | cut -d: -f1)"
    [ -n "$cmd_n" ] || { cat "$d/out" >&2; die "$g: the command $want is not shown"; }
    [ "$(grep -cF -- "$GH_GIT_QUESTION" "$d/out")" -eq 1 ] \
      || { cat "$d/out" >&2; die "$g: the Authenticate Git step is not there exactly once"; }
    q_n="$(grep -nF -- "$GH_GIT_QUESTION" "$d/out" | cut -d: -f1)"
    grep -qE '^  [0-9]+\. If gh asks ' <<<"$(sed -n "${q_n}p" "$d/out")" \
      || { cat "$d/out" >&2; die "$g: the Authenticate Git text is not a numbered step of its own"; }
    [ "$q_n" -eq $((cmd_n + 1)) ] || { cat "$d/out" >&2; die "$g: the Authenticate Git step does not come right after the command"; }
    code_n="$(grep -n 'one-time code' "$d/out" | head -1 | cut -d: -f1)"
    [ -n "$code_n" ] && [ "$q_n" -lt "$code_n" ] \
      || { cat "$d/out" >&2; die "$g: the Authenticate Git step does not come before the one-time code step"; }
  done
  # No gh auth command, no question: a token in GH_TOKEN (gh cannot
  # refresh it), and GitHub out of reach.
  for g in gg_permissions_token gg_offline; do
    d="$(tmpdir)"
    pre "$d" "$g"
    [ "$RC" -eq 0 ] || { cat "$d/err" >&2; die "$g failed"; }
    expect_no_out "$d" "Authenticate Git"
    ! grep -qE '^    gh auth (login|refresh)' "$d/out" || { cat "$d/out" >&2; die "$g: a gh auth command is shown"; }
  done
}

api_signed_out() { CREATED_NOTE="$1"; API_STATUS=""; API_RC=4; API_MESSAGE=""; api_fail "read your GitHub account"; }

test_the_sign_in_next_actions_say_what_to_answer_when_gh_asks_to_authenticate_git() {
  # Review of #235, N1: the stop messages that give gh auth login as the
  # next action (before and after the project exists) give the answer
  # in the same line, as the push refusal does for gh auth refresh.
  local d note want
  for note in "" "The project acme/my-app exists on GitHub."; do
    d="$(tmpdir)"
    pre "$d" api_signed_out "$note"
    [ "$RC" -ne 0 ] || { cat "$d/out" "$d/err" >&2; die "[$note]: did not stop"; }
    want='gh auth login -h github.com -p https -w -s workflow (if gh asks "Authenticate Git with your GitHub credentials?", answer Yes), then '
    grep -F -- "$want" <<<"$(sed -n 2p "$d/err")" >/dev/null \
      || { cat "$d/err" >&2; die "[$note]: the next action does not say what to answer when gh asks to authenticate Git"; }
  done
}

test_the_authenticate_git_step_is_one_shared_text_in_every_gh_sign_in_guide() {
  # One text, so the guides cannot drift apart: the script writes gh's
  # question once, and every guide that shows gh auth login or offers a
  # gh auth refresh gives it through that one text.
  local g body found=""
  ( load_script; [ "$GH_GIT_QUESTION_STEP" = "$GH_GIT_QUESTION" ] ) \
    || die "the script's GH_GIT_QUESTION_STEP is not the step this test expects"
  ( load_script; [ "$GH_GIT_QUESTION_TEXT" = 'Authenticate Git with your GitHub credentials?' ] ) \
    || die "the script's GH_GIT_QUESTION_TEXT is not gh's question"
  [ "$(grep -cF 'Authenticate Git with your GitHub credentials' "$SCRIPT")" -eq 1 ] \
    || { grep -nF 'Authenticate Git with your GitHub credentials' "$SCRIPT" >&2; die "gh's question is written more than once in the script"; }
  for g in $(grep -oE '^guide_[a-z_]+\(\)' "$SCRIPT" | sed 's/()//'); do
    body="$(G="$g() {" awk '$0 == ENVIRON["G"] { on = 1; next } on && /^}/ { exit } on { print }' "$SCRIPT")"
    case "$body" in
      *'"gh auth login'* | *'"gh auth refresh'* | *'offered gh-refresh-'*) ;;
      *) continue ;;
    esac
    found="$found $g"
    grep -qxF '  guide_step "$GH_GIT_QUESTION_STEP"' <<<"$body" \
      || die "$g has the user run gh auth login or gh auth refresh but does not give GH_GIT_QUESTION_STEP"
  done
  # The search itself works: it finds the two guides known to have one.
  case "$found " in *" guide_github_account "*) ;; *) die "the search did not find guide_github_account (found:$found)" ;; esac
  case "$found " in *" guide_github_permissions "*) ;; *) die "the search did not find guide_github_permissions (found:$found)" ;; esac
  # Stop messages and guide steps too: every line that names gh auth
  # login or gh auth refresh in words gives gh's question through
  # GH_GIT_QUESTION_TEXT.
  local missing
  missing="$(tmpdir)/missing"
  gh_auth_words_without_answer "$SCRIPT" >"$missing"
  [ ! -s "$missing" ] || { cat "$missing" >&2; die "a message names gh auth login or gh auth refresh without GH_GIT_QUESTION_TEXT (lines above)"; }
  [ "$GH_AUTH_WORD_LINES" -ge 1 ] || die "the search found no message that names gh auth login or gh auth refresh (the push refusal for workflow files has one)"
}

# gh_auth_words_without_answer <file>: prints each line of the file that
# names gh auth login or gh auth refresh in words without
# $GH_GIT_QUESTION_TEXT. Comments and exact commands (say_command,
# run_offered) are left out. GH_AUTH_WORD_LINES counts the lines looked
# at; run it in the current shell (with a redirect, not in $( )).
GH_AUTH_WORD_LINES=0
gh_auth_words_without_answer() {
  local line
  GH_AUTH_WORD_LINES=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in *'gh auth login'* | *'gh auth refresh'*) ;; *) continue ;; esac
    case "${line#"${line%%[![:space:]]*}"}" in '#'*) continue ;; esac
    case "$line" in *say_command*|*run_offered*) continue ;; esac
    GH_AUTH_WORD_LINES=$((GH_AUTH_WORD_LINES + 1))
    case "$line" in *'$GH_GIT_QUESTION_TEXT'*) ;; *) printf '%s\n' "$line" ;; esac
  done <"$1"
}

test_the_gh_auth_words_check_catches_what_it_looks_for() {
  # Guards the check above (review of #235, N5): a guide step or a stop
  # message that names gh auth login or gh auth refresh in words without
  # the answer is caught; one with it, a comment and an exact command
  # are not.
  local d
  d="$(tmpdir)"
  printf '%s\n' \
    '  guide_step "Sign in again with gh auth login -h github.com -p https -w, then come back."' \
    '    stop_with_error "gh lost its sign-in." "Run gh auth login -h github.com -p https -w -s workflow, then start the script again." "$raw"' \
    '        "Give gh that permission with the command gh auth refresh -h github.com -s delete_repo, then continue." \' \
    '  say_command "gh auth login -h github.com -p https -w -s workflow"' \
    '    gh-x) if [ "$2" = run ]; then run_offered "gh auth refresh -s x"; fi ;;' \
    '  # gh auth login asks it too.' \
    'NEXT="Run gh auth login (if gh asks \"$GH_GIT_QUESTION_TEXT\", answer Yes), then start again."' \
    'OTHER="Run gh auth refresh (if gh asks \"$GH_GIT_QUESTION_TEXT\", answer Yes), then continue."' >"$d/script"
  gh_auth_words_without_answer "$d/script" >"$d/missing"
  [ "$(grep -c . "$d/missing")" -eq 3 ] || { cat "$d/missing" >&2; die "want the 3 lines without the answer, got the lines above"; }
  grep -qF 'guide_step "Sign in again with gh auth login' "$d/missing" || die "a guide step naming gh auth login was not caught"
  grep -qF 'Run gh auth login -h github.com -p https -w -s workflow, then start' "$d/missing" || die "a stop message naming gh auth login was not caught"
  grep -qF 'gh auth refresh -h github.com -s delete_repo' "$d/missing" || die "a stop message naming gh auth refresh was not caught"
  [ "$GH_AUTH_WORD_LINES" -eq 5 ] || die "looked at $GH_AUTH_WORD_LINES lines, want 5 (not the comment and the two exact commands)"
}

test_the_refresh_never_runs_without_a_yes_typed_at_the_terminal() {
  local d answer
  export STUB_GH_SCOPES="repo"
  for answer in no "" maybe; do
    d="$(tmpdir)"
    printf '%s\n' "$answer" >"$d/tty"
    printf 'q\n' >"$d/in"
    pre "$d" with_vis public preflight_github_permissions
    expect_rc 3 "$d"
    expect_nothing_ran "$d"
    expect_out "$d" "Not run."
  done
  # A yes on stdin, or --yes, does not approve it.
  d="$(tmpdir)"
  : >"$d/tty"
  printf '%s\n' yes q >"$d/in"
  pre "$d" yes_opt with_vis public preflight_github_permissions
  expect_rc 3 "$d"
  expect_nothing_ran "$d"
}

test_a_token_from_the_environment_is_not_refreshed() {
  # A token in GH_TOKEN or GITHUB_TOKEN cannot be given more permissions
  # by gh, and changing it needs a new window: no offer, no wait, exit 3.
  local d v
  for v in GH_TOKEN GITHUB_TOKEN; do
    d="$(tmpdir)"
    export STUB_GH_SCOPES="repo" "$v=ghp_faketoken000000000000000000000000000"
    printf 'yes\n' >"$d/tty"
    printf '\n\n' >"$d/in"
    pre "$d" with_vis public preflight_github_permissions
    expect_rc 3 "$d"
    expect_out "$d" "https://github.com/settings/tokens"
    expect_no_out "$d" "Run it now?"
    expect_no_out "$d" "Press Enter"
    expect_nothing_ran "$d"
    ! grep -q ghp_faketoken "$d/out" "$d/err" || die "$v: the token was shown"
    unset "$v"
  done
}

test_a_fine_grained_token_gets_a_warning_and_the_setup_carries_on() {
  # No X-OAuth-Scopes header: the script cannot see the permissions, so
  # it names the ones the setup needs and carries on.
  local d p
  d="$(tmpdir)"
  export STUB_GH_SCOPES=-
  pre "$d" ni with_vis private preflight_github_permissions
  expect_rc 0 "$d"
  expect_out "$d" "fine-grained token"
  for p in Administration Contents Workflows "Pull requests" "Read and write" "create repositories (new projects on GitHub)"; do
    expect_out "$d" "$p"
  done
  expect_no_out "$d" "does not have every permission"
  expect_nothing_ran "$d"
  grep -q '^    Done\. ' "$d/out" || { cat "$d/out" >&2; die "no done line"; }
}

test_an_older_script_is_told_to_download_the_current_one() {
  # The published CHANGELOG names another version: the steps give the
  # download command of the README and the command to start the new copy
  # again; no Enter wait (a re-check in this run cannot change the
  # script), exit 3, nothing created.
  local d
  d="$(tmpdir)"
  sed -e 's/{{TEMPLATE_VERSION}}/v9.9.9/' -e "s/{{TEMPLATE_COMMIT}}/$(printf '%040d' 0)/" \
    "$REPO/bootstrap/stubs/CHANGELOG.md" >"$d/published.md"
  export STUB_GH_CHANGELOG="$d/published.md"
  working_git "$d"
  printf '\n\n' >"$d/in"
  whole "$d" --name my-app --description "Lends tools."
  expect_rc 3 "$d"
  expect_out "$d" "This copy of the script is not the current version"
  expect_out "$d" "v9.9.9"
  grep -qxF '    gh api repos/factoincognito/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh' "$d/out" \
    || { cat "$d/out" >&2; die "the download command is not shown"; }
  grep -qxF "    $(start_cd_of "$d")bash bootstrap-project.sh --name my-app --description 'Lends tools.'" "$d/out" \
    || { cat "$d/out" >&2; die "the command to start the downloaded copy is not shown"; }
  expect_no_out "$d" "Press Enter"
  expect_no_out "$d" "Project name"
  [ -z "$(ls -A "$d/cwd")" ] || die "something was created"
}

test_the_published_version_is_compared_with_the_script_version() {
  # The unstamped script (in the template) matches the template's own
  # unstamped CHANGELOG stub; a stamped copy matches the same stamp and
  # not another one.
  local d sha
  sha="$(printf '%040d' 0)"
  d="$(tmpdir)"
  pre "$d" ni preflight_published_version
  expect_rc 0 "$d"
  grep -q '^    Done\. This is the current version of the script' "$d/out" || { cat "$d/out" >&2; die "no done line"; }
  d="$(tmpdir)"
  sed -e 's/{{TEMPLATE_VERSION}}/v2.4.0/' -e "s/{{TEMPLATE_COMMIT}}/$sha/" \
    "$REPO/bootstrap/stubs/CHANGELOG.md" >"$d/published.md"
  export STUB_GH_CHANGELOG="$d/published.md"
  pre "$d" ni eval 'SCRIPT_VERSION=v2.4.0; preflight_published_version'
  expect_rc 0 "$d"
  pre "$d" ni eval 'SCRIPT_VERSION=v2.3.0; preflight_published_version'
  expect_rc 3 "$d"
  expect_out "$d" "v2.3.0"
  expect_out "$d" "v2.4.0"
}

test_the_published_version_is_read_from_the_built_changelog() {
  # The parser reads the CHANGELOG.md that build.sh really ships, and
  # finds the version stamped into the shipped script.
  local out="$WORK/built.$RANDOM" got want
  bash "$REPO/bootstrap/build.sh" "$out" v7.8.9 "$(printf '%040d' 1)" >/dev/null || die "build failed"
  want="$(sed -n "s/^SCRIPT_VERSION='\(.*\)'$/\1/p" "$out/bootstrap-project.sh")"
  [ "$want" = v7.8.9 ] || die "the shipped script is not stamped v7.8.9: $want"
  got="$( load_script; read_published_version "$(cat "$out/CHANGELOG.md")" && printf '%s' "$PUBLISHED_VERSION" )" \
    || die "no version found in the built CHANGELOG.md"
  [ "$got" = "$want" ] || die "read $got from the built CHANGELOG.md, want $want"
  # Carriage returns (a copy saved on Windows) do not change it.
  got="$( load_script; read_published_version "$(sed 's/$/\r/' "$out/CHANGELOG.md")" && printf '%s' "$PUBLISHED_VERSION" )"
  [ "$got" = "$want" ] || die "with carriage returns: read $got"
}

test_a_changelog_without_a_version_is_explained() {
  local d
  d="$(tmpdir)"
  printf '%s\n' '# Changelog' '' 'Nothing here.' >"$d/published.md"
  export STUB_GH_CHANGELOG="$d/published.md"
  pre "$d" ni preflight_published_version
  expect_rc 1 "$d"
  expect_err_shape "$d" ".*version"
}

test_an_existing_project_is_refused_unless_resume() {
  local d
  d="$(tmpdir)"
  export STUB_GH_EXISTING="acme/my-app"
  pre "$d" ni with_project acme my-app preflight_project_absent
  expect_rc 3 "$d"
  expect_out "$d" "A project named acme/my-app already exists on GitHub."
  expect_out "$d" "--name"
  expect_out "$d" "--resume"
  expect_out "$d" "https://github.com/acme/my-app"
  pre "$d" ni resume with_project acme my-app preflight_project_absent
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The project acme/my-app exists on GitHub, which --resume allows."
  pre "$d" ni with_project acme other-app preflight_project_absent
  expect_rc 0 "$d"
  expect_out "$d" "    Done. No project named acme/other-app exists on GitHub yet."
  # Interactive: renamed or deleted on GitHub while the script waits.
  d="$(tmpdir)"
  echo 1 >"$d/repo-there"
  printf '\n' >"$d/in"
  pre "$d" with_project acme my-app preflight_project_absent
  expect_rc 0 "$d"
  expect_out "$d" "Press Enter to check again"
  [ "$(tail -1 "$d/out")" = "    Done. No project named acme/my-app exists on GitHub yet." ] || { cat "$d/out" >&2; die "no done line"; }
}

test_the_name_and_permissions_are_checked_after_the_questions() {
  # They need the answers (owner, name, visibility); a whole run with the
  # name taken stops there, after the last question.
  local d
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_EXISTING="octo-user/my-app" STUB_GH_SCOPES="repo"
  printf '%s\n' my-app "" "Lends tools." "" "" python "" none "" "" "" >"$d/in"
  printf 'no\n' >"$d/tty"
  whole "$d"
  expect_rc 3 "$d"
  grep -n 'Your email address for git' "$d/out" | head -1 | cut -d: -f1 >"$d/q"
  grep -n 'does not have every permission' "$d/out" | head -1 | cut -d: -f1 >"$d/g"
  [ -s "$d/g" ] && [ "$(cat "$d/q")" -lt "$(cat "$d/g")" ] || { cat "$d/out" >&2; die "permissions not checked after the questions"; }
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_SCOPES="repo, workflow"
  whole "$d" --non-interactive --yes "${REQUIRED_OPTS[@]}" --pack python
  expect_rc 3 "$d"
  expect_out "$d" "A project named octo-user/my-app already exists on GitHub."
}

# ---------- the plan, the confirmation, create and protect ----------
# After every check passes, the script prints the plan; --dry-run stops
# there, creating nothing. Otherwise it asks "Proceed?" (default no; --yes
# skips it; --non-interactive needs --yes or --dry-run). Then step 2: gh
# repo create from the bootstrapper, then waiting (up to 60 s, retrying on
# 404) until GitHub has made main and CHANGELOG.md. Then step 3: PUT the
# protection of main with the spec's body, then gh repo edit. A 403 on the
# protection is classified by GitHub's message and stops before anything
# else. After the project exists, every stop shows the command to
# continue with --resume. Then the copy on this computer (see "the copy
# on this computer" below) and the later steps up to the proposed change,
# then the wait for build, the required check, adding the change, the
# finish and the report (see "wait, require, add, finish and report"
# below); a run that goes through ends with exit 0.

# Every answer given as an option, so a run without --non-interactive asks
# only "Proceed?". The visibility is added by setup_run.
ALL_OPTS=(--owner octo-user --project-name "My App" --po-name Ada --copyright-holder "Ada L" \
  --dir ./my-app --git-name "Test Person" --git-email test@example.com)
CREATE_CALL='repo create octo-user/my-app --template factoincognito/ai-project-bootstrap --public --description Lends tools to neighbours.'
BRANCH_CALL='api -i repos/octo-user/my-app/branches/main'
FILES_CALL='api -i repos/octo-user/my-app/contents/CHANGELOG.md'
PROTECT_CALL='api -i -X PUT repos/octo-user/my-app/branches/main/protection --input -'
EDIT_CALL='repo edit octo-user/my-app --delete-branch-on-merge --enable-squash-merge'
PROBE_CALL='api -i repos/octo-user/my-app'
# Right after step 3: is Actions turned on for the project?
ACTIONS_CALL='api -i repos/octo-user/my-app/actions/permissions --jq .enabled'
# The preflight's licence check, for --license mit (before create).
LICENSE_CHECK_CALL='api -i licenses/mit --jq .key'
CLONE_CALL='repo clone octo-user/my-app ./my-app'
# Step 10, for setup_run's --license mit: the gh call after the copy.
LICENSE_CALL='api -i licenses/mit --jq .body'
# Step 14: the proposed change (the body file is a temporary file).
PR_CALL='pr create --repo octo-user/my-app --base main --head bootstrap-setup --title Set up my-app --body-file <file>'
# The spec's body for step 3, field for field.
PROTECT_BODY='{"required_status_checks":null,"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":0},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}'
# Step 16: the step 3 body with build required, written out from the spec
# (a PUT replaces the whole protection, so every field is there again).
REQUIRE_BODY='{"required_status_checks":{"strict":false,"contexts":["build"]},"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":0},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}'
# Steps 15 to 17: the --jq expressions of the script, written out here as
# the stub gh checks them (what they read from GitHub's answers is tested
# with jq in test_the_jq_expressions_read_githubs_documented_answers).
BUILD_JQ='.[] | select(.name == "build") | "\(.event) \(.bucket)"'
READBACK_JQ='"contexts=\(.required_status_checks.contexts // [] | join(","))", "strict=\(.required_status_checks.strict)", "enforce_admins=\(.enforce_admins.enabled)", "approvals=\(.required_pull_request_reviews.required_approving_review_count)", "restrictions=\(.restrictions)", "allow_force_pushes=\(.allow_force_pushes.enabled)", "allow_deletions=\(.allow_deletions.enabled)"'
MERGED_JQ='"\(.merged) \(.merge_commit_sha)"'
CHECKS_CALL="pr checks 1 --repo octo-user/my-app --json name,bucket,event --jq $BUILD_JQ"
READBACK_CALL="api -i repos/octo-user/my-app/branches/main/protection --jq $READBACK_JQ"
MERGE_CALL='pr merge 1 --squash --delete-branch --match-head-commit <sha>'
MERGED_CALL="api -i repos/octo-user/my-app/pulls/1 --jq $MERGED_JQ"
PRIVATE_CALL='api -i repos/octo-user/my-app --jq .private'
ALLOWED_CALL='api -i repos/octo-user/my-app/actions/permissions --jq .allowed_actions'
# The calls after the proposed change, in a run that goes through: build
# looked at once, the required check set and read back, the change added
# and checked on GitHub.
END_CALLS=("$CHECKS_CALL" "$PROTECT_CALL" "$READBACK_CALL" "$MERGE_CALL" "$MERGED_CALL")
# The first line of the report at the end: the run went through.
FINISHED='The setup is finished.'
# The last two lines of every report (end-to-end run 1, finding 10): the
# one next step, the same after a new setup and after --resume, and then
# where to go when stuck, as the very last line.
WHAT_NEXT='What to do next: in the Claude app, create a Claude Project for this project, add the project on GitHub, https://github.com/octo-user/my-app, to that Claude Project, and start a chat inside the Claude Project. The file CLAUDE.md in the project tells Claude the rest.'
ASK_CLEAD="If you ever feel stuck and do not know how to go on, Clead (Claude, the project's Tech Owner) is always there to help: just ask Clead for help, a recommendation or advice in the chat."

# built_bootstrapper: BUILT is a bootstrapper made by bootstrap/build.sh
# from this template, stamped BUILT_VERSION; built once per harness run.
BUILT="$WORK/built"
BUILT_VERSION=v9.8.7
built_bootstrapper() {
  [ -d "$BUILT" ] || bash "$REPO/bootstrap/build.sh" "$BUILT" "$BUILT_VERSION" \
    0123456789abcdef0123456789abcdef01234567 >/dev/null
}

# use_built <dir>: the run uses the script as a user gets it: the built,
# stamped copy, alone in <dir>/dl (not next to the packs), unless the
# test put another one there. The stub gh serves the built CHANGELOG.md
# (or <dir>/changelog when the test wrote one) and makes each new
# project from the built files (or from STUB_GH_TEMPLATE when set).
# Today's date is FAKE_TODAY: a fake date answers +%Y-%m-%d with it (and
# runs the real date for anything else), so a run that crosses midnight
# cannot make a test fail.
FAKE_TODAY=2031-02-03
use_built() {
  built_bootstrapper
  local text
  [ -d "$1/dl" ] || mkdir -p "$1/dl"
  IFS= read -r -d '' text <<EOF || true
if [ "\$*" = +%Y-%m-%d ]; then echo $FAKE_TODAY; else exec "$REAL_DATE" "\$@"; fi
EOF
  write_stand_in "$1/bin/date" "$text"
  [ -f "$1/dl/bootstrap-project.sh" ] || cp "$BUILT/bootstrap-project.sh" "$1/dl/bootstrap-project.sh"
  RUN_SCRIPT="$1/dl/bootstrap-project.sh"
  if [ -f "$1/changelog" ]; then STUB_GH_CHANGELOG="$1/changelog"; else STUB_GH_CHANGELOG="$BUILT/CHANGELOG.md"; fi
  export STUB_GH_CHANGELOG STUB_GH_TEMPLATE="${STUB_GH_TEMPLATE:-$BUILT}"
}

# setup_run <dir> <options...>: the whole script, as a user gets it (see
# use_built), with every input given (pack python, so npm is not needed;
# public unless --private is given) and a working git.
# The warning for a public project with no licence, given in the plan and
# again at step 10.
NO_LICENCE_WARNING='Warning: the project is public and has no licence: anyone can see its code, but nobody else may copy, change or share it. To add a licence later, see https://choosealicense.com.'

setup_run() {
  local d="$1" vis=--public
  shift
  case " $* " in *" --private "*) vis="" ;; esac
  working_git "$d"
  use_built "$d"
  whole "$d" "${REQUIRED_OPTS[@]}" --pack python "${ALL_OPTS[@]}" $vis "$@"
}

# calls_from_create <dir>: the gh calls from creating the project on, one
# per line, the arguments joined by spaces (the prompt column left out).
# The feature checks of the preflight (repo create, pr checks and pr
# merge with --help) are left out, here and in calls_since: a second run
# makes them again. The temporary file after --body-file is written <file>, the change id
# after --match-head-commit <sha> (test_the_change_is_added_with_the_head_that_was_sent
# checks that id).
calls_from_create() {
  awk -F'\t' '$4 == "--help" { next } $2 == "repo" && $3 == "create" { on = 1 }
    on { out = $2; for (i = 3; i <= NF; i++) out = out " " ($(i - 1) == "--body-file" ? "<file>" : ($(i - 1) == "--match-head-commit" ? "<sha>" : $i)); print out }' "$1/gh.log"
}

# expect_calls <dir> <call...>: exactly these calls, in this order, from
# creating the project on.
expect_calls() {
  local d="$1" got want
  shift
  got="$(calls_from_create "$d")"
  want="$(printf '%s\n' "$@")"
  [ "$got" = "$want" ] || { printf 'want:\n%s\ngot:\n%s\n' "$want" "$got" >&2; die "gh calls from the create step differ"; }
}

expect_nothing_created() {
  [ -z "$(calls_from_create "$1")" ] || { cat "$1/gh.log" >&2; die "the project was created"; }
  [ -z "$(ls -A "$1/cwd")" ] || { ls -A "$1/cwd" >&2; die "something was made on this computer"; }
}

# expect_continue_command <dir> <words>: the command to continue is
# shown under its own line, and has the words given (" --resume": the
# option as a word of its own). Since S15 the command also carries every
# answer, after the options, so the words need not end it.
expect_continue_command() {
  local line
  line="$(shown_after "$1" 'To continue the setup, run this command:')"
  case "$line " in
    "    bash "*"$2 "*) ;;
    *) cat "$1/out" >&2; die "no command to continue with: $2 (got: $line)" ;;
  esac
}

test_the_plan_is_shown_after_the_checks_and_a_dry_run_creates_nothing() {
  local d v
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --dry-run
  expect_rc 0 "$d"
  expect_out "$d" "Here is the plan. Nothing has been created yet."
  for v in "octo-user/my-app" "https://github.com/octo-user/my-app" "My App" "Lends tools to neighbours." \
    "Ada" "python" "mit" "Ada L" "./my-app" "Test Person" "test@example.com" "20 minutes" \
    "  1. " "  2. " "  3. " "  4. " "  5. "; do
    expect_out "$d" "$v"
  done
  # Finding 9: the minutes are a limit, and what happens when it is reached.
  grep -qxF "    Waiting for the project's checks: at most 20 minutes; if build has not passed by then, the script stops, leaves the proposed change open and shows how to continue (--ci-timeout sets a different limit)" "$d/out" \
    || { cat "$d/out" >&2; die "the plan does not say the wait is a limit"; }
  expect_out "$d" "This was a dry run (--dry-run): the checks passed, and nothing was created."
  expect_no_out "$d" "Proceed?"
  expect_no_out "$d" "needs a paid GitHub plan"
  # A new setup marks no step (finding 7 marks them only on --resume).
  [ "$(plan_section "$d/out" | step_marks)" = "- - - - - -" ] || { cat "$d/out" >&2; die "a step of a new setup's plan is marked"; }
  grep -n 'Done. No project named octo-user/my-app exists on GitHub yet.' "$d/out" | cut -d: -f1 >"$d/a"
  grep -n 'Here is the plan' "$d/out" | cut -d: -f1 >"$d/p"
  [ -s "$d/a" ] && [ "$(cat "$d/a")" -lt "$(cat "$d/p")" ] || { cat "$d/out" >&2; die "the plan came before the checks"; }
  expect_nothing_created "$d"
  # Every line of the plan, the indented value lines too (#150 review,
  # finding 7: none of the values given here has a banned word).
  [ -z "$(sed -n '/^Here is the plan/,$p' "$d/out" | awk '{print NR ": " $0}' | banned_hits)" ] || { cat "$d/out" >&2; die "banned word in the plan"; }
  # A private project: the plan warns that protection needs a paid plan.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --dry-run --private
  expect_rc 0 "$d"
  expect_out "$d" "needs a paid GitHub plan"
  expect_nothing_created "$d"
}

# plan_section <file>: the lines of the output from the plan's list of
# steps on (a new setup's heading and a resumed one's both start so).
plan_section() { sed -n '/^The steps, in this order/,$p' "$1"; }

# step_marks: reads output on stdin; prints the mark at the end of each of
# the first six numbered steps, one word each: done, next, skipped, or -
# for none.
step_marks() {
  grep -E '^  [1-6]\. ' | head -6 | awk '
    / \(done\)$/ { m = "done" }
    / \(next\)$/ { m = "next" }
    / \(skipped: [^)]*\)$/ { m = "skipped" }
    { printf "%s%s", sep, (m == "" ? "-" : m); sep = " "; m = "" }
    END { print "" }'
}

# RESUME_STEPS_HEADING: the heading of the steps on a --resume run.
RESUME_STEPS_HEADING='The steps, in this order: (done) marks a step that is done already, and (next) the step the setup continues with.'

# expect_resume_steps <dir> <marks>: a --resume run showed the six steps,
# under their heading, after it said where the setup stopped, with these
# marks (as step_marks prints them).
expect_resume_steps() {
  local d="$1" h w got
  h="$(grep -n -xF "$RESUME_STEPS_HEADING" "$d/out" | head -1 | cut -d: -f1 || true)"
  w="$(grep -n -xF '==> Working out where the setup stopped, from GitHub and from the copy on this computer' "$d/out" | head -1 | cut -d: -f1 || true)"
  [ -n "$h" ] && [ -n "$w" ] && [ "$w" -lt "$h" ] || { cat "$d/out" >&2; die "no marked steps after working out where the setup stopped"; }
  got="$(plan_section "$d/out" | step_marks)"
  [ "$got" = "$2" ] || { cat "$d/out" >&2; die "the steps are marked $got, want $2"; }
}

test_the_steps_of_the_plan_are_marked_from_the_resume_state() {
  # End-to-end run 1, finding 7: --resume shows the same six steps as the
  # plan of a new setup, from the same function, each marked from the
  # state. (next) is the first step the run carries out, as run_steps
  # does it: template and fresh go on at the protection (fresh has its
  # copy already); saved, sent and proposed go on in step 5, but sent and
  # proposed first make a new copy when there is none (resume_copy); added
  # only re-checks the protection and reports, and makes no copy.
  local d c state copy want got
  d="$(tmpdir)"
  ( load_script; IN_DIR=./my-app IN_LICENSE=mit; plan_steps ) >"$d/new"
  [ "$(sed -n 1p "$d/new")" = "  1. Create the project on GitHub, with the bootstrapper's files in it." ] || { cat "$d/new" >&2; die "a new setup's steps do not start with step 1 (show_plan gives their heading)"; }
  [ "$(step_marks <"$d/new")" = "- - - - - -" ] || { cat "$d/new" >&2; die "the steps of a new setup are marked"; }
  grep '^  [1-6]\. ' "$d/new" >"$d/new-steps"
  grep -v '^  4\. ' "$d/new-steps" >"$d/new-but-4"
  for c in "template|-|done next - - - -" "fresh|1|done next done - - -" \
    "saved|1|done done done done next -" \
    "sent|1|done done done done next -" "sent|-|done done next done - -" \
    "proposed|1|done done done done next -" "proposed|-|done done next done - -" \
    "added|1|done done done done done next" "added|-|done done skipped done done next"; do
    state="${c%%|*}"
    copy="${c#*|}"
    copy="${copy%%|*}"
    want="${c##*|}"
    [ "$copy" != - ] || copy=""
    ( load_script; IN_DIR=./my-app IN_LICENSE=mit COPY_PRESENT="$copy"; plan_steps "$state" ) >"$d/$state$copy"
    [ "$(sed -n 1p "$d/$state$copy")" = "$RESUME_STEPS_HEADING" ] || { cat "$d/$state$copy" >&2; die "$state: not the heading of a resumed setup"; }
    got="$(step_marks <"$d/$state$copy")"
    [ "$got" = "$want" ] || { cat "$d/$state$copy" >&2; die "$state (copy: ${copy:-none}): marks $got, want $want"; }
    # The same words as a new setup's steps, the mark aside. A step 4 done
    # already does not name this run's licence: the change was made with
    # the licence chosen then.
    sed -E 's/ \((done|next|skipped: [^)]*)\)$//' "$d/$state$copy" | grep '^  [1-6]\. ' >"$d/bare"
    case "$state" in
      template | fresh) expect_same "$state: the steps" "$d/new-steps" "$d/bare" ;;
      *)
        grep -v '^  4\. ' "$d/bare" >"$d/bare-but-4"
        expect_same "$state: steps 1 to 3, 5 and 6" "$d/new-but-4" "$d/bare-but-4"
        ! grep -q '^  4\. .*mit' "$d/bare" || { cat "$d/bare" >&2; die "$state: step 4 names this run's licence"; }
        ;;
    esac
  done
  # The skipped mark says why, in plain words.
  grep -qxF "  3. Make a copy of the project on this computer, in ./my-app. (skipped: the script makes no copy of a project that is set up already)" "$d/added" \
    || { cat "$d/added" >&2; die "added with no copy: step 3 does not say why it is skipped"; }
  # With --allow-unprotected the protection may have been left out, so a
  # step 2 that is past is not said to be simply done; one still to come
  # is (next) as before.
  ( load_script; IN_DIR=./my-app IN_LICENSE=mit COPY_PRESENT=1 OPT_ALLOW_UNPROTECTED=1; plan_steps sent ) >"$d/allow"
  grep -qxF "  2. Protect its main version, so that from then on every change comes as a proposed change, not straight into it. (done, or skipped with --allow-unprotected)" "$d/allow" \
    || { cat "$d/allow" >&2; die "sent with --allow-unprotected: step 2 is said to be done"; }
  ( load_script; IN_DIR=./my-app IN_LICENSE=mit COPY_PRESENT="" OPT_ALLOW_UNPROTECTED=1; plan_steps template ) >"$d/allow2"
  [ "$(step_marks <"$d/allow2")" = "done next - - - -" ] || { cat "$d/allow2" >&2; die "template with --allow-unprotected: marks changed"; }
  # With --license none a step 4 done already does not say none was chosen.
  ( load_script; IN_DIR=./my-app IN_LICENSE=none COPY_PRESENT=1; plan_steps saved ) >"$d/none"
  ! grep -qF 'you chose none' "$d/none" || { cat "$d/none" >&2; die "saved: step 4 speaks of this run's licence none"; }
  # Every word of every list passes the plain-language check.
  [ -z "$(cat "$d"/* | awk '{print NR ": " $0}' | banned_hits)" ] || die "banned word in the steps"
}

test_proceed_is_asked_with_no_as_its_default() {
  local d n why
  # yes: asked once, explained, then the project is created.
  d="$(tmpdir)"
  printf 'yes\n' >"$d/in"
  setup_run "$d"
  expect_rc 0 "$d"
  n="$(grep -c -xF 'Proceed? (yes or no) [no]: ' "$d/out" || true)"
  [ "$n" -eq 1 ] || { cat "$d/out" >&2; die "Proceed? asked $n times"; }
  why="$(grep -B1 -xF 'Proceed? (yes or no) [no]: ' "$d/out" | sed -n 1p)"
  [ "$(printf '%s\n' "$why" | wc -w | tr -d ' ')" -ge 6 ] && [ "${why%.}" != "$why" ] \
    || { cat "$d/out" >&2; die "Proceed? has no explanation above it: $why"; }
  [ "$(calls_from_create "$d" | sed -n 1p)" = "$CREATE_CALL" ] || { cat "$d/gh.log" >&2; die "not created after yes"; }
  # no, or Enter (the default): nothing is created, exit 1.
  for a in no ""; do
    d="$(tmpdir)"
    printf '%s\n' "$a" >"$d/in"
    setup_run "$d"
    expect_rc 1 "$d"
    sed -n 1p "$d/err" | grep '^What happened: You answered no' >/dev/null || { cat "$d/err" >&2; die "answer [$a]: no plain stop"; }
    expect_nothing_created "$d"
  done
  # Another answer is explained and asked again.
  d="$(tmpdir)"
  printf '%s\n' maybe yes >"$d/in"
  setup_run "$d"
  expect_out "$d" "Answer yes or no. Please try again."
  [ "$(calls_from_create "$d" | sed -n 1p)" = "$CREATE_CALL" ] || { cat "$d/gh.log" >&2; die "not created after the second answer"; }
  # No answer at all (stdin ends): exit 2, nothing created.
  d="$(tmpdir)"
  setup_run "$d"
  expect_rc 2 "$d"
  expect_nothing_created "$d"
}

test_proceed_says_why_its_default_is_no() {
  # End-to-end run 1, finding 5: the explanation above "Proceed?" says
  # why the default is no (Enter alone answers no, so nothing happens by
  # accident), on a first run and on a --resume run, and keeps what it
  # said before. Enter then stops with nothing created or changed.
  local d mode why keep enter
  for mode in first resume; do
    d="$(tmpdir)"
    printf '\n' >"$d/in"
    set +e
    ( load_script
      [ "$mode" = first ] || OPT_RESUME=1
      confirm_plan
    ) <"$d/in" >"$d/out" 2>"$d/err"
    RC=$?
    set -e
    if [ "$mode" = first ]; then
      keep="If you answer yes, the script creates the project on GitHub and carries out the plan above; if you answer no, it stops and creates nothing."
      enter="Pressing Enter alone answers no, so nothing is created by accident; type yes to go on."
    else
      keep="If you answer yes, the script continues the setup as described above; if you answer no, it stops and changes nothing."
      enter="Pressing Enter alone answers no, so nothing is changed by accident; type yes to go on."
    fi
    why="$(grep -B1 -xF 'Proceed? (yes or no) [no]: ' "$d/out" | sed -n 1p)"
    [ "$why" = "$keep $enter" ] || { cat "$d/out" >&2; die "[$mode] explanation is: $why"; }
    expect_rc 1 "$d"
    sed -n 1p "$d/err" | grep '^What happened: You answered no' >/dev/null || { cat "$d/err" >&2; die "[$mode] Enter did not stop as a no"; }
  done
}

test_a_no_at_proceed_saves_the_answers_and_shows_the_command_to_start_again() {
  # End-to-end run 3, r3d: Enter at "Proceed?" answered no by accident,
  # and the stop printed no command, so every question would be asked
  # again. A no stops like every other stop: it saves the answers and
  # shows the short command (the README says a stop prints the exact
  # command to run next). Nothing is created.
  local d f
  # First run, answers typed at the questions: the command to start again.
  d="$(tmpdir)"
  working_git "$d"
  use_built "$d"
  printf '%s\n' "${ANSWERS_IN[@]}" no >"$d/in"
  whole "$d"
  expect_rc 1 "$d"
  grep -q '^What happened: You answered no' "$d/err" || { cat "$d/err" >&2; die "did not stop as a no"; }
  expect_out "$d" "To start again, run this command:"
  expect_short_command "$d" "To start again, run this command:"
  expect_again_file "$d" --owner octo-user --name my-app --project-name my-app --description "Lends tools." \
    --po-name "Octo User" --pack python --public --license none --dir ./my-app --git-name "Test Person" \
    --git-email test@example.com
  expect_nothing_created "$d"
  grep -qxF "What to do next: Run the command shown to start again, and answer yes." "$d/err" || { cat "$d/err" >&2; die "the next step does not point at the command shown"; }
  # A --resume run (the project exists) answered no: the command to
  # continue, with --resume saved.
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_PR_FAIL=broken
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_PR_FAIL
  printf 'no\n' >"$d/in"
  setup_run "$d" --resume
  expect_rc 1 "$d"
  grep -q '^What happened: You answered no' "$d/err" || { cat "$d/err" >&2; die "--resume: did not stop as a no"; }
  expect_out "$d" "To continue the setup, run this command:"
  expect_short_command "$d" "To continue the setup, run this command:"
  f="$(again_file_of "$d")"
  grep -qx -- --resume "$f" || { cat "$f" >&2; die "--resume: the saved answers lack --resume"; }
  grep -qxF "What to do next: Run the command shown to continue the setup, and answer yes." "$d/err" || { cat "$d/err" >&2; die "the next step does not point at the command shown"; }
}

test_proceed_and_the_guide_pause_are_not_answered_by_keys_typed_before_them() {
  # r1f: an Enter pressed during the checks before "Proceed?" would stop
  # the setup as a no, and one pressed during a check before the pause of
  # a guide would check again at once. At a terminal (the hook, with the
  # stand-in stty and dd of typeahead_tools) the waiting empty line is
  # discarded: "Proceed?" reads the yes typed after it (first run and
  # --resume), and the pause reads the q.
  local d mode
  for mode in first resume pause; do
    d="$(tmpdir)"
    typeahead_tools "$d"
    if [ "$mode" = pause ]; then printf '\nq\n' >"$d/in"; else printf '\nyes\n' >"$d/in"; fi
    set +e
    ( load_script
      export PATH="$d/bin:$PATH" BOOTSTRAP_INPUT_TERMINAL=yes
      case "$mode" in
        first) confirm_plan; echo "went on" ;;
        resume) OPT_RESUME=1; confirm_plan; echo "went on" ;;
        pause) rc=0; wait_for_enter || rc=$?; echo "pause rc=$rc" ;;
      esac
    ) <"$d/in" >"$d/out" 2>"$d/err"
    set -e
    case "$mode" in
      pause) grep -qx 'pause rc=1' "$d/out" || { cat "$d/out" "$d/err" >&2; die "[pause] the waiting line answered the pause"; } ;;
      *) grep -qx 'went on' "$d/out" || { cat "$d/out" "$d/err" >&2; die "[$mode] the waiting line answered Proceed?"; } ;;
    esac
    [ "$(cat "$d/tty.log")" = "$TYPEAHEAD_DISCARDED" ] || { cat "$d/tty.log" >&2; die "[$mode] not discarded as expected"; }
  done
}

test_yes_skips_proceed_and_non_interactive_needs_yes_or_dry_run() {
  local d
  d="$(tmpdir)"
  setup_run "$d" --yes
  expect_rc 0 "$d"
  expect_no_out "$d" "Proceed?"
  [ "$(calls_from_create "$d" | sed -n 1p)" = "$CREATE_CALL" ] || { cat "$d/gh.log" >&2; die "not created with --yes"; }
  # --non-interactive alone cannot ask: refused with the other option
  # problems, before any check.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive
  expect_rc 2 "$d"
  grep -qE -- '^    - --yes: .*--dry-run' "$d/err" || { cat "$d/err" >&2; die "--yes not listed as needed"; }
  [ ! -e "$d/gh.log" ] || { cat "$d/gh.log" >&2; die "gh was used"; }
  expect_nothing_created "$d"
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --dry-run --yes
  expect_rc 0 "$d"
  expect_nothing_created "$d"
}

# The line above the command to continue that the script shows once, after
# the yes and before its first change (end-to-end run 1, finding 6: a stop
# that runs no trap shows nothing, so the command comes first).
ADVANCE_INTRO='If the setup stops before it finishes, for any reason, also with Ctrl-C or a closed window, continue it with the command below. Copy it now and keep it until the setup has finished:'

# advance_command <dir>: the command shown under ADVANCE_INTRO, without
# its indent; fails unless the intro is there exactly once.
advance_command() {
  local n
  n="$(grep -cxF "$ADVANCE_INTRO" "$1/out" || true)"
  [ "$n" -eq 1 ] || { cat "$1/out" >&2; die "the command to continue was shown $n times before the first change, want 1"; }
  long_of "$1" "$(grep -A1 -xF "$ADVANCE_INTRO" "$1/out" | sed -n 2p | sed 's/^    //')"
}

# line_of <dir> <fixed text>: the number of the first output line that is
# exactly the text (0 when there is none).
line_of() {
  local n
  n="$(grep -nxF -- "$2" "$1/out" | head -1 | cut -d: -f1)"
  echo "${n:-0}"
}

test_the_command_to_continue_is_shown_after_yes_and_before_the_project_is_created() {
  local d cmd p a c
  # Asked, yes: Proceed?, then the command (with --resume and the
  # options), then the create step.
  d="$(tmpdir)"
  printf 'yes\n' >"$d/in"
  setup_run "$d"
  expect_rc 0 "$d"
  # The run went through, so the answers it saved are removed again (r2l),
  # and the command is checked as shown: the short one. What it carries
  # is checked at a stop (test_a_stop_after_the_project_exists_saves_resume...).
  cmd="$(grep -A1 -xF "$ADVANCE_INTRO" "$d/out" | sed -n 2p | sed 's/^    //')"
  [ "$cmd" = "$(start_cd_of "$d")bash $(shown_script_of "$d") --again" ] || die "the command shown is not the short one: $cmd"
  p="$(line_of "$d" 'Proceed? (yes or no) [no]: ')"
  a="$(line_of "$d" "$ADVANCE_INTRO")"
  c="$(line_of "$d" '==> Creating the project octo-user/my-app on GitHub')"
  [ "$p" -gt 0 ] && [ "$p" -lt "$a" ] && [ "$a" -lt "$c" ] || { cat "$d/out" >&2; die "not in the order Proceed? ($p), the command ($a), create ($c)"; }
  expect_out "$d" "If the project was not created yet, that command says so and shows the command to start again."
  # #203 review, N1: after a closed window the command helps only if the
  # user kept it, so the line above it says to copy it and keep it.
  grep -B1 -xF "    $cmd" "$d/out" | sed -n 1p | grep -F 'Copy it now and keep it until the setup has finished:' >/dev/null \
    || { cat "$d/out" >&2; die "the line above the command does not say to copy it and keep it"; }
  # --yes: the same, without Proceed?.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  [ "$(grep -A1 -xF "$ADVANCE_INTRO" "$d/out" | sed -n 2p)" = "    $(start_cd_of "$d")bash $(shown_script_of "$d") --again" ] \
    || { cat "$d/out" >&2; die "--yes: not the short command"; }
  [ "$(line_of "$d" "$ADVANCE_INTRO")" -lt "$(line_of "$d" '==> Creating the project octo-user/my-app on GitHub')" ] || { cat "$d/out" >&2; die "--yes: the command came after create"; }
  # No, Enter, or a dry run: nothing is changed, so no command to continue.
  for a in no ""; do
    d="$(tmpdir)"
    printf '%s\n' "$a" >"$d/in"
    setup_run "$d"
    expect_rc 1 "$d"
    expect_no_out "$d" "$ADVANCE_INTRO"
  done
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --dry-run
  expect_rc 0 "$d"
  expect_no_out "$d" "$ADVANCE_INTRO"
}

test_nothing_is_created_when_a_check_fails() {
  local d
  d="$(tmpdir)"
  export STUB_GH_EXISTING="octo-user/my-app"
  setup_run "$d" --non-interactive --yes
  expect_rc 3 "$d"
  expect_nothing_created "$d"
  expect_no_out "$d" "Here is the plan"
  unset STUB_GH_EXISTING
  d="$(tmpdir)"
  export STUB_GH_SCOPES="repo"
  setup_run "$d" --non-interactive --yes
  expect_rc 3 "$d"
  expect_nothing_created "$d"
}

test_create_waits_for_the_files_then_protects_main_with_the_exact_body() {
  local d n_start n_done
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$ACTIONS_CALL" "$CLONE_CALL" "$LICENSE_CALL" "$PR_CALL" "${END_CALLS[@]}"
  # Byte for byte: the body as sent, then the line break the stub adds
  # (a here-string ends in one too, so two in all). The second body, of
  # step 16, is checked in test_build_is_required_after_it_passed_with_the_exact_body_and_read_back.
  printf '%s\n\n' "$PROTECT_BODY" >"$d/want-body"
  head -2 "$d/protection-bodies" | cmp -s "$d/want-body" - || { od -c "$d/protection-bodies" | head -5 >&2; die "protection body is not the spec's"; }
  [ "$(cut -f1 "$d/gh.log" | LC_ALL=C sort -u)" = GH_PROMPT_DISABLED=1 ] || { cat "$d/gh.log" >&2; die "a gh call ran with prompts on"; }
  [ ! -s "$d/sleep.log" ] || die "it waited although the files were there"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not go through to the report"; }
  [ ! -s "$d/err" ] || { cat "$d/err" >&2; die "a run that went through wrote to stderr"; }
  for t in "==> Creating the project octo-user/my-app on GitHub" "==> Waiting for GitHub to put the bootstrapper's files into the project" \
    "==> Protecting the main version of the project" "==> Setting how proposed changes are added to the project"; do
    expect_out "$d" "$t"
  done
  n_start="$(grep -c '^==> ' "$d/out")"
  n_done="$(grep -c '^    Done\. ' "$d/out")"
  [ "$n_start" -eq "$n_done" ] || { cat "$d/out" >&2; die "$n_start steps started, $n_done ended"; }
  expect_no_out "$d" "needs a paid GitHub plan"
  # Private: the flag, and the plan warned before creating.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes --private
  expect_rc 0 "$d"
  [ "$(calls_from_create "$d" | sed -n 1p)" = "${CREATE_CALL/--public/--private}" ] || { cat "$d/gh.log" >&2; die "not created private"; }
  grep -n 'needs a paid GitHub plan' "$d/out" | head -1 | cut -d: -f1 >"$d/w"
  grep -n '==> Creating the project' "$d/out" | cut -d: -f1 >"$d/c"
  [ -s "$d/w" ] && [ "$(cat "$d/w")" -lt "$(cat "$d/c")" ] || { cat "$d/out" >&2; die "no warning before creating a private project"; }
}

test_the_files_are_waited_for_retrying_on_404_for_up_to_a_minute() {
  local d
  d="$(tmpdir)"
  echo 3 >"$d/main-missing"
  echo 2 >"$d/changelog-missing"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$BRANCH_CALL" "$BRANCH_CALL" "$BRANCH_CALL" \
    "$FILES_CALL" "$FILES_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$ACTIONS_CALL" "$CLONE_CALL" "$LICENSE_CALL" "$PR_CALL" "${END_CALLS[@]}"
  [ "$(cat "$d/sleep.log")" = "$(printf '2\n2\n2\n2\n2')" ] || { cat "$d/sleep.log" >&2; die "not 5 waits of 2 seconds"; }
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/err" >&2; die "did not reach the end of step 3"; }
  # Never there: 30 waits of 2 seconds (60 s), then a plain stop with the
  # command to continue; protection is not touched.
  d="$(tmpdir)"
  echo 9999 >"$d/main-missing"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  [ "$(grep -c . "$d/sleep.log")" -eq 30 ] && [ "$(sort -u "$d/sleep.log")" = 2 ] || { cat "$d/sleep.log" >&2; die "not 30 waits of 2 seconds"; }
  [ "$(calls_from_create "$d" | grep -cxF "$BRANCH_CALL")" -eq 31 ] || { cat "$d/gh.log" >&2; die "not 31 checks"; }
  ! calls_from_create "$d" | grep -F -- '-X PUT' >/dev/null || { cat "$d/gh.log" >&2; die "protection was touched"; }
  expect_err_shape "$d" "GitHub has not finished .* after a minute"
  expect_continue_command "$d" " --resume"
  # #150 review, finding 3: the minute is shared by the two reads: 20
  # waits for main leave 10 for CHANGELOG.md.
  d="$(tmpdir)"
  echo 20 >"$d/main-missing"
  echo 9999 >"$d/changelog-missing"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  [ "$(grep -c . "$d/sleep.log")" -eq 30 ] || { cat "$d/sleep.log" >&2; die "not 30 waits in all"; }
  [ "$(calls_from_create "$d" | grep -cxF "$FILES_CALL")" -eq 11 ] || { cat "$d/gh.log" >&2; die "not 11 reads of CHANGELOG.md"; }
  expect_err_shape "$d" "GitHub has not finished .* after a minute"
  # Another answer while waiting: explained, nothing more.
  d="$(tmpdir)"
  export STUB_GH_BRANCH_FAIL=server
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub had a problem of its own"
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL"
  expect_continue_command "$d" " --resume"
}

test_a_403_on_protection_stops_before_anything_else_with_its_guide() {
  local d mode
  for mode in plan token mystery; do
    d="$(tmpdir)"
    export STUB_GH_PROTECT_FAIL="$mode"
    setup_run "$d" --non-interactive --yes --private
    expect_rc 3 "$d"
    # The plan is told from the token by GitHub's message, and the
    # project's visibility is read from GitHub before the way on is
    # offered (round 2, B1).
    if [ "$mode" != token ]; then
      expect_calls "$d" "${CREATE_CALL/--public/--private}" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$PRIVATE_CALL"
    else
      expect_calls "$d" "${CREATE_CALL/--public/--private}" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL"
    fi
    expect_out "$d" "Details for support (you can ignore these):"
    grep -qE '^    HTTP 403: .' "$d/out" || { cat "$d/out" >&2; die "$mode: GitHub's message not shown below"; }
    expect_continue_command "$d" " --resume"
    expect_no_out "$d" "Press Enter"
    sed -n 1p "$d/err" | grep '^What happened: .*octo-user/my-app exists on GitHub' >/dev/null || { cat "$d/err" >&2; die "$mode: the stop does not say the project exists"; }
    expect_no_out "$d" "$FINISHED"
    [ -z "$(ls -A "$d/cwd")" ] || die "$mode: something was made on this computer"
    case "$mode" in
      plan)
        expect_out "$d" "needs a paid GitHub plan"
        grep -qxF '    gh repo edit octo-user/my-app --visibility public --accept-visibility-change-consequences' "$d/out" \
          || { cat "$d/out" >&2; die "$mode: the command to make it public is not shown"; }
        grep -E '^    (cd .* && )?bash .* --allow-unprotected$' "$d/out" | while IFS= read -r l; do long_of "$d" "$l"; done \
          | grep -E '^    bash .* --resume( .*)? --allow-unprotected$' >/dev/null || { cat "$d/out" >&2; die "$mode: --allow-unprotected not shown"; }
        ;;
      mystery)
        # Round 3, N2: a message that does not say why, on a project
        # GitHub says is private, gets both explanations (the plan steps and
        # the token steps), and still no --allow-unprotected.
        sed -n '/^==> Protecting/,$p' "$d/out" >"$d/guide"
        grep -qF 'https://github.com/settings/billing' "$d/guide" || { cat "$d/guide" >&2; die "mystery: the plan steps are not shown"; }
        grep -qxF '    gh repo edit octo-user/my-app --visibility public --accept-visibility-change-consequences' "$d/guide" || { cat "$d/guide" >&2; die "mystery: the command to make it public is not shown"; }
        ! grep -qF -- '--allow-unprotected' "$d/guide" || { cat "$d/guide" >&2; die "mystery: --allow-unprotected is offered"; }
        ;;
    esac
    case "$mode" in
      token | mystery)
        expect_out "$d" "Administration"
        expect_out "$d" "https://github.com/settings/personal-access-tokens"
        ;;
    esac
    # The guide covers only its own cause (the plan above it warned
    # about the paid plan already, because the project is private).
    sed -n '/^==> Protecting/,$p' "$d/out" >"$d/guide"
    case "$mode" in
      plan) ! grep -qF "Administration" "$d/guide" || { cat "$d/guide" >&2; die "plan: the token steps are shown"; } ;;
      token) ! grep -qF "needs a paid GitHub plan" "$d/guide" || { cat "$d/guide" >&2; die "token: the plan steps are shown"; } ;;
    esac
    unset STUB_GH_PROTECT_FAIL
  done
  # #150 review, finding 3: a rate-limit 403 is not about the plan or the
  # token: the rate-limit text, exit 1, no guide.
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=rate-limit
  setup_run "$d" --non-interactive --yes --private
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub has paused"
  sed -n '/^==> Protecting/,$p' "$d/out" | grep -F 'Why this is needed' >/dev/null && { cat "$d/out" >&2; die "rate limit: a guide was shown"; }
  unset STUB_GH_PROTECT_FAIL
  # Interactive too: it stops at once, with no wait.
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  printf 'yes\n\n\n' >"$d/in"
  setup_run "$d" --private
  expect_rc 3 "$d"
  expect_no_out "$d" "Press Enter"
  ! calls_from_create "$d" | grep -F "$EDIT_CALL" >/dev/null || die "settings changed after the 403"
}

# The command an interactive run shows once every answer is in: the
# answers of ANSWERS_IN below, each as its option (S15: the answers are
# carried, #148, #149 and #150 reviews).
CARRIED=" --owner octo-user --name my-app --project-name my-app --description 'Lends tools.' --po-name 'Octo User' --pack python --public --license none --dir ./my-app --git-name 'Test Person' --git-email test@example.com"
ANSWERS_IN=(my-app "" "Lends tools." "" "" python "" none "" "" "")

test_the_continue_command_carries_every_answer_given_at_the_questions() {
  local d line
  d="$(tmpdir)"
  working_git "$d"
  use_built "$d"
  export STUB_GH_PROTECT_FAIL=plan
  printf '%s\n' "${ANSWERS_IN[@]}" yes >"$d/in"
  whole "$d"
  unset STUB_GH_PROTECT_FAIL
  expect_rc 3 "$d"
  expect_continue_command "$d" " --resume$CARRIED"
  # Run as shown, it asks no question again: only "Proceed?", and it goes
  # through.
  printf 'yes\n' >"$d/in"
  again "$d"
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "the continued run did not go through"; }
  [ "$(grep -c 'Proceed? (yes or no) \[no\]: ' "$d/out")" -eq 1 ] || { cat "$d/out" >&2; die "Proceed? not asked once"; }
  ! grep -qE '^(Project name|Description|Language pack|Licence|Folder|Your name for git)' "$d/out" || { cat "$d/out" >&2; die "a question was asked again"; }
  # A stop before the project exists (a guide the user leaves with q)
  # shows the command to start again, with the answers too.
  d="$(tmpdir)"
  working_git "$d"
  use_built "$d"
  export STUB_GH_EXISTING="octo-user/my-app"
  printf '%s\n' "${ANSWERS_IN[@]}" q >"$d/in"
  whole "$d"
  unset STUB_GH_EXISTING
  expect_rc 3 "$d"
  line="$(shown_after "$d" 'To start again, run this command:')"
  case "$line" in
    "    bash "*"$CARRIED") ;;
    *) cat "$d/out" >&2; die "the command to start again does not carry the answers: $line" ;;
  esac
  case "$line" in *" --resume"*) die "the command to start again has --resume" ;; esac
}

# The web pack's answers, with no (Enter) to the publishing files.
WEB_ANSWERS_IN=(my-app "" "Lends tools." "" "" web "" "" none "" "" "")

test_the_commands_shown_carry_a_no_to_the_publishing_files() {
  # End-to-end run 1 (repeat), r1e: Enter (no) at "Add the publishing
  # files?", Ctrl-C later, and the command to continue asked it again,
  # because a no could not be written as an option.
  local d line
  d="$(tmpdir)"
  working_git "$d"
  use_built "$d"
  fake_tool "$d" npm 10.0.0
  export STUB_GH_PROTECT_FAIL=plan
  printf '%s\n' "${WEB_ANSWERS_IN[@]}" >"$d/in"
  whole "$d" --yes
  unset STUB_GH_PROTECT_FAIL
  expect_rc 3 "$d"
  expect_continue_command "$d" " --without-deploy"
  case " $(advance_command "$d") " in
    *" --resume "*" --without-deploy "*) ;;
    *) cat "$d/out" >&2; die "the command shown before the first change does not carry the no: $(advance_command "$d")" ;;
  esac
  # Run as shown, with no answers at all on stdin, it asks nothing and
  # goes through without the publishing files.
  : >"$d/in"
  again "$d"
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "the continued run did not go through"; }
  ! grep -qF 'Add the publishing files' "$d/out" || { cat "$d/out" >&2; die "the publishing question was asked again"; }
  [ ! -e "$(copy_of "$d")/.github/workflows/deploy.yml" ] || die "the publishing files were added after a no"
  # The command to start again carries it too.
  d="$(tmpdir)"
  working_git "$d"
  use_built "$d"
  fake_tool "$d" npm 10.0.0
  export STUB_GH_EXISTING="octo-user/my-app"
  printf '%s\n' "${WEB_ANSWERS_IN[@]}" q >"$d/in"
  whole "$d"
  unset STUB_GH_EXISTING
  expect_rc 3 "$d"
  line="$(shown_after "$d" 'To start again, run this command:')"
  case "$line " in
    "    bash "*" --without-deploy "*) ;;
    *) cat "$d/out" >&2; die "the command to start again does not carry the no: $line" ;;
  esac
  # A yes is carried as --with-deploy, as before.
  d="$(tmpdir)"
  working_git "$d"
  use_built "$d"
  fake_tool "$d" npm 10.0.0
  export STUB_GH_EXISTING="octo-user/my-app"
  printf '%s\n' my-app "" "Lends tools." "" "" web yes "" none "" "" "" q >"$d/in"
  whole "$d"
  unset STUB_GH_EXISTING
  expect_rc 3 "$d"
  line="$(shown_after "$d" 'To start again, run this command:')"
  case "$line " in
    "    bash "*" --with-deploy "*) ;;
    *) cat "$d/out" >&2; die "the command to start again does not carry the yes: $line" ;;
  esac
}

# ---------- the short command to run again (r2l) ----------
# End-to-end run 2 repeated, r2l: on a touch-only tablet the long command
# shown at a stop could not be copied, so every answer was typed again.
# Product owner (2026-10-28): "A shorter restart command would be nice."
# A stop saves the arguments of the long command, one per line, in
# AGAIN_FILE next to the script, and shows `bash <script> --again`.
AGAIN_FILE=.bootstrap-project.again

# again_file_of <dir>: the file a whole run in <dir> saves its answers to.
again_file_of() { local s; s="$(run_script_of "$1")"; printf '%s\n' "${s%/*}/$AGAIN_FILE"; }

# expect_again_file <dir> <word...>: the saved file holds exactly these
# words, one per line.
expect_again_file() {
  local d="$1" f
  shift
  f="$(again_file_of "$d")"
  [ -f "$f" ] || { cat "$d/out" "$d/err" >&2; die "no saved file $f"; }
  printf '%s\n' "$@" >"$d/want-again"
  expect_same "the saved answers" "$d/want-again" "$f"
}

# shown_script_of <dir>: the script of a whole run in <dir>, as the
# commands shown write it (quoted where it has a space).
shown_script_of() { ( load_script; quote_word "$(run_script_of "$1")"; printf '%s\n' "$QUOTED" ); }

# expect_short_command <dir> <intro> [extra]: the line under <intro> is the
# short command, with the script as the run started it.
expect_short_command() {
  local line
  line="$(grep -A1 -xF -- "$2" "$1/out" | sed -n 2p)"
  [ "$line" = "    $(start_cd_of "$1")bash $(shown_script_of "$1") --again${3:-}" ] \
    || { cat "$1/out" >&2; die "not the short command under '$2': $line"; }
}

test_a_stop_at_a_guide_shows_the_short_command_and_saves_the_long_ones_arguments() {
  local d
  # Options given: the file holds them, one per line, and the long
  # command is not shown.
  d="$(tmpdir)"
  on_os "$d" linux debian
  missing "$d" git
  printf 'q\n' >"$d/in"
  whole "$d" --name my-app --description "Lends tools." --pack node
  expect_rc 3 "$d"
  expect_short_command "$d" "To start again, run this command:"
  expect_again_file "$d" --name my-app --description "Lends tools." --pack node
  expect_no_out "$d" "--name my-app"
  # Answers typed at the questions: saved as their options, as the long
  # command carries them (CARRIED).
  d="$(tmpdir)"
  working_git "$d"
  use_built "$d"
  export STUB_GH_EXISTING="octo-user/my-app"
  printf '%s\n' "${ANSWERS_IN[@]}" q >"$d/in"
  whole "$d"
  unset STUB_GH_EXISTING
  expect_rc 3 "$d"
  expect_short_command "$d" "To start again, run this command:"
  expect_again_file "$d" --owner octo-user --name my-app --project-name my-app --description "Lends tools." \
    --po-name "Octo User" --pack python --public --license none --dir ./my-app --git-name "Test Person" \
    --git-email test@example.com
}

test_a_stop_after_the_project_exists_saves_resume_and_the_guide_offers_the_short_command_with_allow() {
  local d
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  setup_run "$d" --non-interactive --yes --private
  expect_rc 3 "$d"
  expect_short_command "$d" "To continue the setup, run this command:"
  expect_short_command "$d" "$ADVANCE_INTRO"
  expect_again_file "$d" "${REQUIRED_OPTS[@]}" --pack python "${ALL_OPTS[@]}" --non-interactive --yes --private --resume
  # The guide's way on without protection: the same file, with the option
  # added on the command line.
  grep -qxF "    $(start_cd_of "$d")bash $(shown_script_of "$d") --again --allow-unprotected" "$d/out" \
    || { cat "$d/out" >&2; die "the short command with --allow-unprotected is not shown"; }
  # Run as shown, it goes on without protection.
  again "$d" --allow-unprotected
  unset STUB_GH_PROTECT_FAIL
  expect_rc 0 "$d"
  expect_out "$d" "$UNPROTECTED_SAYS"
}

test_again_runs_with_the_saved_answers_and_adds_the_options_after_them() {
  local d
  d="$(tmpdir)"
  working_git "$d"
  use_built "$d"
  export STUB_GH_EXISTING="octo-user/my-app"
  printf '%s\n' "${ANSWERS_IN[@]}" q >"$d/in"
  whole "$d"
  unset STUB_GH_EXISTING
  expect_rc 3 "$d"
  # Nothing on stdin: a question asked again would get no answer.
  : >"$d/in"
  whole "$d" --again --name my-app-2 --dry-run
  expect_rc 0 "$d"
  [ "$(sed -n 1p "$d/out")" = "Using the answers saved when the script stopped last time, for the project octo-user/my-app." ] \
    || { cat "$d/out" >&2; die "the first line does not say whose answers are used"; }
  ! grep -qE '^(Project name|Description|Language pack|Licence|Folder|Your name for git)' "$d/out" \
    || { cat "$d/out" >&2; die "a question was asked again"; }
  # The option given after --again comes after the saved ones, so it wins.
  expect_out "$d" "    On GitHub: octo-user/my-app-2,"
  expect_out "$d" "    Description: Lends tools."
  expect_out "$d" "This was a dry run (--dry-run)"
}

test_again_without_a_saved_file_stops_with_a_plain_error_and_runs_nothing() {
  local d f
  for how in none folder; do
    d="$(tmpdir)"
    f="$(again_file_of "$d")"
    mkdir -p "${f%/*}"
    [ "$how" != folder ] || mkdir "$f"
    whole "$d" --again
    expect_rc 2 "$d"
    sed -n 1p "$d/err" | grep -E '^What happened: .*saved answers' >/dev/null || { cat "$d/err" >&2; die "$how: no plain message"; }
    grep -qE '^What to do next: .*step 1 of the README' "$d/err" || { cat "$d/err" >&2; die "$how: does not point to step 1 of the README"; }
    [ ! -s "$d/gh.log" ] || { cat "$d/gh.log" >&2; die "$how: gh was called"; }
    [ -z "$(ls -A "$d/cwd")" ] || die "$how: something was created"
    expect_no_out "$d" "Using the answers saved"
  done
}

test_an_answer_with_a_newline_or_a_folder_inside_the_copy_is_not_saved_and_the_long_command_is_shown() {
  local t out
  t="$(tmpdir)"
  # Control: AGAIN_DIR set by hand (a sourced script saves nothing), a
  # plain answer is saved, and the short command shown.
  out="$( load_script; remember_command --name my-app; AGAIN_DIR="$t"; RESTART_SCRIPT=x.sh
    stop_at_guide 2>/dev/null )" || true
  [ -f "$t/$AGAIN_FILE" ] || { printf '%s\n' "$out" >&2; die "control: nothing saved"; }
  grep -qxF '    bash x.sh --again' <<<"$out" || { printf '%s\n' "$out" >&2; die "control: no short command"; }
  rm -f "$t/$AGAIN_FILE"
  # An answer with a newline cannot be one line: no file, the long command.
  out="$( load_script; remember_command --name my-app --description "$(printf 'one\ntwo')"; AGAIN_DIR="$t"
    RESTART_SCRIPT=x.sh; stop_at_guide 2>/dev/null )" || true
  [ ! -e "$t/$AGAIN_FILE" ] || die "an answer with a newline was saved"
  ! grep -qF -- '--again' <<<"$out" || { printf '%s\n' "$out" >&2; die "the short command was shown"; }
  grep -qF -- "--name my-app --description 'one" <<<"$out" || { printf '%s\n' "$out" >&2; die "the long command is not shown"; }
  [ -z "$(ls -A "$t")" ] || { ls -A "$t" >&2; die "a file was left in the folder"; }
  # The script's folder is the project's copy (or inside it): the file
  # would be a change in the copy, so it is not saved there.
  mkdir -p "$t/copy/sub"
  out="$( load_script; remember_command --name my-app; AGAIN_DIR="$t/copy/sub"; IN_DIR="$t/copy"
    RESTART_SCRIPT=x.sh; stop_at_guide 2>/dev/null )" || true
  [ ! -e "$t/copy/sub/$AGAIN_FILE" ] || die "saved inside the copy"
  grep -qE '^    bash .* --name my-app$' <<<"$out" || { printf '%s\n' "$out" >&2; die "inside the copy: the long command is not shown"; }
}

test_a_finished_setup_removes_its_saved_file_and_nothing_else() {
  local d f
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_PR_FAIL=broken
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_PR_FAIL
  expect_rc 1 "$d"
  f="$(again_file_of "$d")"
  [ -f "$f" ] || die "no file saved at the stop"
  : >"${f%/*}/other-file"
  again "$d"
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "the run did not go through"; }
  [ ! -e "$f" ] || die "the saved file is still there"
  [ "$(ls -A "${f%/*}" | LC_ALL=C sort | tr '\n' ' ')" = "bootstrap-project.sh other-file " ] \
    || { ls -A "${f%/*}" >&2; die "other files in the folder changed"; }
  # A run that goes through at once leaves no file either.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  [ ! -e "$(again_file_of "$d")" ] || die "a finished first run left its file"
}

test_the_saved_file_is_readable_by_the_user_only() {
  local d f probe
  probe="$(tmpdir)/probe"
  : >"$probe"
  chmod 600 "$probe" 2>/dev/null || true
  case "$(ls -l "$probe" | cut -c1-10)" in
    -rw-------) ;;
    *) skip_test "chmod 600 is not honoured here (Git Bash on Windows shows every file as readable by all)"; return 0 ;;
  esac
  d="$(tmpdir)"
  on_os "$d" linux debian
  missing "$d" git
  ( umask 022; printf 'q\n' >"$d/in"; whole "$d" --name my-app --git-email test@example.com ) || exit 1
  f="$(again_file_of "$d")"
  [ -f "$f" ] || die "no file saved"
  [ "$(ls -l "$f" | cut -c1-10)" = "-rw-------" ] || { ls -l "$f" >&2; die "the file is not readable by the user only"; }
}

test_the_saved_file_is_read_as_words_never_run() {
  local d f
  d="$(tmpdir)"
  working_git "$d"
  use_built "$d"
  f="$(again_file_of "$d")"
  printf '%s\n' --name my-app --description '$(touch pwned) and `touch pwned`' --project-name '; touch pwned2' \
    --pack python --license none --owner octo-user --po-name Ada --dir ./my-app --git-name "Test Person" \
    --git-email test@example.com --public --non-interactive --dry-run >"$f"
  whole "$d" --again
  [ ! -e "$d/cwd/pwned" ] && [ ! -e "$d/cwd/pwned2" ] && [ ! -e "$d/dl/pwned" ] && [ ! -e "$d/dl/pwned2" ] \
    || die "a line of the file was run"
  # The value reached the script as it is: check_text refuses its
  # backticks, so the run stops on it, and says which option.
  expect_rc 2 "$d"
  grep -qF -- '--description' "$d/err" || { cat "$d/err" >&2; die "the description was not read as the value of --description"; }
  # Without the backticks the value goes through, word for word.
  printf '%s\n' --name my-app --description '$(touch pwned); touch pwned' --project-name '; touch pwned2' \
    --pack python --license none --owner octo-user --po-name Ada --dir ./my-app --git-name "Test Person" \
    --git-email test@example.com --public --non-interactive --dry-run >"$f"
  whole "$d" --again
  expect_rc 0 "$d"
  expect_out "$d" '    Description: $(touch pwned); touch pwned'
  expect_out "$d" '    Display name: ; touch pwned2'
  [ -z "$(find "$d" -name 'pwned*')" ] || { find "$d" -name 'pwned*' >&2; die "a line of the file was run"; }
}

test_help_and_readme_name_the_short_command() {
  local d rc=0 step
  d="$(tmpdir)"
  bash "$SCRIPT" --help </dev/null >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 0 ] || die "--help exit $rc"
  [ "$(grep -c -- '--again' "$d/out")" -eq 1 ] || { cat "$d/out" >&2; die "--help does not list --again in one line"; }
  step="$(sed -n '/^\*\*Step 1: /,/^\*\*What the script guides you through/p' "$TEMPLATE_README" | tr '\n' ' ' | sed 's/  */ /g')"
  # #267 review, B1 (Clead): the command goes to the folder itself, so it
  # works from a new window too; the README says so, not "the same folder".
  ! grep -qiF 'in the same folder' <<<"$step" || die "README step 1 still says to run it in the same folder"
  grep -qF '`cd ~/projects && bash bootstrap-project.sh --again`' <<<"$step" || die "README step 1 does not show the command with its cd"
  grep -qiF 'also in a new window' <<<"$step" || die "README step 1 does not say the command works in a new window"
}

# ---------- the command goes to the folder the script started in ----------
# #267 review, B1 (Clead): several guides send the user to a new window,
# which starts in the home folder, where bash bootstrap-project.sh finds
# no script and --dir ./my-app points elsewhere. The command shown starts
# with cd to the folder the script was started in: ~/... under the home
# folder, else the folder quoted.

# start_cd_of <dir>: the "cd <folder> && " a whole run in <dir> shows, for
# its folder (RUN_CWD, else <dir>/cwd), written as the script writes it.
# Both folders are read back with cd and pwd, as the script reads its own
# (pwd), never compared as written: macOS's TMPDIR ends in a /, so a
# path built from it holds a // that pwd does not show (#267, CI on macOS).
start_cd_of() {
  local f home rest
  f="$(cd "${RUN_CWD:-$1/cwd}" && pwd)" || die "start_cd_of: no folder ${RUN_CWD:-$1/cwd}"
  home="$(cd "$1/home" && pwd)" || die "start_cd_of: no folder $1/home"
  case "$f" in
    "$home") printf 'cd ~ && ' ;;
    "$home/"*) rest="${f#"$home/"}"; ( load_script; quote_word "$rest"; printf 'cd ~/%s && ' "$QUOTED" ) ;;
    *) ( load_script; quote_word "$f"; printf 'cd %s && ' "$QUOTED" ) ;;
  esac
}

# run_shown_from <dir> <folder> <line>: runs a shown command line, as
# typed in a new window: bash -c in <folder>, with the run's environment.
run_shown_from() {
  local d="$1" f="$2" line="${3#    }"
  mv "$d/out" "$d/out.prev"
  mv "$d/err" "$d/err.prev"
  set +e
  ( in_env "$d"; cd "$f"; "$BASH" -c "$line" ) <"$d/in" >"$d/out" 2>"$d/err"
  RC=$?
  set -e
}

test_the_command_shown_goes_to_the_folder_the_script_started_in() {
  local d line other
  # Start again: a guide stop; the command, run from another folder, reads
  # the saved answers and reaches the same guide.
  d="$(tmpdir)"
  on_os "$d" linux debian
  missing "$d" git
  printf 'q\n' >"$d/in"
  whole "$d" --name my-app --description "Lends tools." --pack node
  expect_rc 3 "$d"
  line="$(grep -A1 -xF 'To start again, run this command:' "$d/out" | sed -n 2p)"
  [ "$line" = "    $(start_cd_of "$d")bash $(shown_script_of "$d") --again" ] || { cat "$d/out" >&2; die "start again: not the command with its cd: $line"; }
  other="$d/other"; mkdir -p "$other"
  printf 'q\n' >"$d/in"
  run_shown_from "$d" "$other" "$line"
  expect_rc 3 "$d"
  [ "$(sed -n 1p "$d/out")" = "Using the answers saved when the script stopped last time, for the project my-app." ] || { cat "$d/out" "$d/err" >&2; die "start again: the saved answers were not used"; }
  expect_out "$d" "git is not installed."
  [ -z "$(ls -A "$other")" ] || die "start again: something was made in the other folder"
  # Continue: once the project exists, the command run from another folder
  # finds the copy at ./my-app of the first folder and finishes.
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_PR_FAIL=broken
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_PR_FAIL
  expect_rc 1 "$d"
  line="$(grep -A1 -xF 'To continue the setup, run this command:' "$d/out" | sed -n 2p)"
  [ "$line" = "    $(start_cd_of "$d")bash $(shown_script_of "$d") --again" ] || { cat "$d/out" >&2; die "continue: not the command with its cd: $line"; }
  other="$d/other"; mkdir -p "$other"
  run_shown_from "$d" "$other" "$line"
  expect_rc 0 "$d"
  expect_one_of_each "$d"
  [ -z "$(ls -A "$other")" ] || die "continue: something was made in the other folder"
  # Under the home folder the folder is written with ~, and a folder with
  # spaces and quotes is quoted; both work from another folder.
  for sub in "home/projects" "home/my 'quoted' \"dir\"" "it's a \"dir\" \$(x)"; do
    d="$(tmpdir)"
    on_os "$d" linux debian
    missing "$d" git
    prepare "$d"
    mkdir -p "$d/$sub"
    printf 'q\n' >"$d/in"
    RUN_CWD="$d/$sub" whole "$d" --name my-app --description "Lends tools." --pack node
    expect_rc 3 "$d"
    line="$(grep -A1 -xF 'To start again, run this command:' "$d/out" | sed -n 2p)"
    [ "$line" = "    $(RUN_CWD="$d/$sub" start_cd_of "$d")bash $(shown_script_of "$d") --again" ] || { cat "$d/out" >&2; die "$sub: not the command with its cd: $line"; }
    case "$sub" in home/projects) [ "$line" = "    cd ~/projects && bash $(shown_script_of "$d") --again" ] || die "home: not written with ~: $line" ;; esac
    mkdir -p "$d/other"
    printf 'q\n' >"$d/in"
    ( in_env "$d"; cd "$d/other"; "$BASH" -c "${line#    }" ) <"$d/in" >"$d/out2" 2>&1 || true
    grep -qF 'Using the answers saved when the script stopped last time, for the project my-app.' "$d/out2" || { cat "$d/out2" >&2; die "$sub: the command did not run from another folder"; }
    [ -z "$(ls -A "$d/other")" ] || die "$sub: something was made in the other folder"
  done
}

# #267 independent review, B1: README step 1 runs the script with no
# options; a stop before the first answer has no words to save. The
# command shown is then the plain one, and it works.
test_a_stop_before_any_answer_shows_the_plain_command_and_it_works() {
  local d line f
  d="$(tmpdir)"
  on_os "$d" linux debian
  missing "$d" git
  printf 'q\n' >"$d/in"
  whole "$d"
  expect_rc 3 "$d"
  f="$(again_file_of "$d")"
  [ ! -e "$f" ] || { od -c "$f" >&2; die "a file was saved with no answers"; }
  line="$(grep -A1 -xF 'To start again, run this command:' "$d/out" | sed -n 2p)"
  [ "$line" = "    $(start_cd_of "$d")bash $(shown_script_of "$d")" ] || { cat "$d/out" >&2; die "not the plain command: $line"; }
  printf 'q\n' >"$d/in"
  run_shown_from "$d" "$d/cwd" "$line"
  expect_rc 3 "$d"
  expect_out "$d" "git is not installed."
  # A saved file with only empty lines holds no answers: --again refuses it
  # in plain words, as with no file.
  printf '\n\n' >"$f"
  whole "$d" --again
  expect_rc 2 "$d"
  sed -n 1p "$d/err" | grep -E '^What happened: .*no saved answers' >/dev/null || { cat "$d/err" >&2; die "an empty file was not refused as no saved answers"; }
  [ ! -s "$d/gh.log" ] || die "gh was called"
}

# #267 independent review, N5: a temporary file of the saved answers left
# by a stop between its write and its move is removed on the way out.
test_a_temporary_file_of_the_saved_answers_is_removed_on_the_way_out() {
  local t rc=0
  t="$(tmpdir)"
  : >"$t/.bootstrap-project.again.Xy12Zq"
  ( load_script; catch_stops; AGAIN_TMP="$t/.bootstrap-project.again.Xy12Zq"; CLEAN=1; exit 1 ) >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || die "exit $rc, want 1"
  [ ! -e "$t/.bootstrap-project.again.Xy12Zq" ] || die "the temporary file was left"
}

test_other_answers_to_the_protection_request_are_explained() {
  local d
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=not-found
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub did not find"
  ! grep -qF 'Check the names you gave' "$d/err" || { cat "$d/err" >&2; die "the 404 next action is the generic one"; }
  grep -qF 'https://github.com/octo-user/my-app' "$d/err" || { cat "$d/err" >&2; die "the 404 next action does not point at the project"; }
  expect_continue_command "$d" " --resume"
  ! calls_from_create "$d" | grep -F "$EDIT_CALL" >/dev/null || die "settings changed after the 404"
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=server
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub had a problem of its own"
  expect_continue_command "$d" " --resume"
}

# ---------- two early stops ----------
# The licence name is checked with GitHub in the preflight, before
# anything is created (#154 review, finding 1): none and PolyForm
# Noncommercial need no call; any other name is asked for with gh api
# licenses/<key>, and GitHub's 404 means it does not know it. As with
# S6's other inputs, a name given as an option stops with exit 2 (the
# options list), and a name typed at the question is asked again. Step
# 10 keeps its own handling of the 404 (tested above).
# Right after step 3, the script asks GitHub whether Actions is turned
# on for the project (spec, post-create guides; the endpoint's answer is
# UNVERIFIED): when it is off, a guide, before the copy on this computer
# and the push; a 403 or 404 (or an answer of another shape) only says
# what could not be checked, and the setup goes on.

test_the_licence_is_checked_with_github_before_anything_is_created() {
  local d
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not reach the end"; }
  [ "$(grep -F "$(printf '\t--jq\t.key')" "$d/gh.log")" = "$(printf 'GH_PROMPT_DISABLED=1\tapi\t-i\tlicenses/mit\t--jq\t.key')" ] \
    || { cat "$d/gh.log" >&2; die "the licence was not checked once, with gh's prompts off"; }
  grep -n "$(printf '\tlicenses/mit\t--jq\t.key')" "$d/gh.log" | cut -d: -f1 >"$d/k"
  grep -n "$(printf '\trepo\tcreate\tocto-user/my-app')" "$d/gh.log" | cut -d: -f1 >"$d/c"
  [ -s "$d/k" ] && [ -s "$d/c" ] && [ "$(cat "$d/k")" -lt "$(cat "$d/c")" ] || { cat "$d/gh.log" >&2; die "the licence was not checked before create"; }
  # Its own step, a start and a done line straight after it, before the plan.
  grep -A1 -xF '==> Checking that GitHub knows the licence mit' "$d/out" | sed -n 2p >"$d/done"
  [ "$(cat "$d/done")" = "    Done. GitHub knows the licence mit." ] || { cat "$d/out" >&2; die "no step lines for the licence check"; }
  grep -n '^    Done. GitHub knows the licence mit.$' "$d/out" | cut -d: -f1 >"$d/a"
  grep -n '^Here is the plan' "$d/out" | cut -d: -f1 >"$d/p"
  [ "$(cat "$d/a")" -lt "$(cat "$d/p")" ] || { cat "$d/out" >&2; die "the licence was checked after the plan"; }
  # Step 10 still reads the text.
  calls_from_create "$d" | grep -xF "$LICENSE_CALL" >/dev/null || { cat "$d/gh.log" >&2; die "step 10 did not read the text"; }
  # A dry run checks it too (spec: --dry-run runs the preflight).
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --dry-run --license apache-2.0
  expect_rc 0 "$d"
  grep -qF "$(printf '\tapi\t-i\tlicenses/apache-2.0\t--jq\t.key')" "$d/gh.log" || { cat "$d/gh.log" >&2; die "dry run: apache-2.0 not checked"; }
  expect_out "$d" "    Done. GitHub knows the licence apache-2.0."
  expect_nothing_created "$d"
}

test_none_and_polyform_need_no_licence_check() {
  local d l
  for l in none polyform-noncommercial-1.0.0; do
    d="$(tmpdir)"
    setup_run "$d" --non-interactive --dry-run --license "$l"
    expect_rc 0 "$d"
    ! grep -qF 'licenses/' "$d/gh.log" || { cat "$d/gh.log" >&2; die "$l: GitHub was asked about the licence"; }
    expect_no_out "$d" "==> Checking that GitHub knows the licence"
  done
}

test_an_unknown_licence_given_as_an_option_stops_before_anything_is_created() {
  # S6's rule for an option that cannot be used: exit 2 with the options
  # list, with --non-interactive and without it (every answer given as an
  # option, so the run would ask only "Proceed?").
  local d mode
  for mode in --non-interactive ""; do
    d="$(tmpdir)"
    setup_run "$d" $mode --yes --license made-up-2.0
    expect_rc 2 "$d"
    sed -n 1p "$d/err" | grep -xF 'What happened: Some options are missing or cannot be used:' >/dev/null || { cat "$d/err" >&2; die "[$mode] not the options stop"; }
    grep -qF -- '    - --license: GitHub has no licence with the short name made-up-2.0. ' "$d/err" || { cat "$d/err" >&2; die "[$mode] the unknown licence is not named"; }
    grep -qF 'https://choosealicense.com/licenses/' "$d/err" || { cat "$d/err" >&2; die "[$mode] where to find the name is not said"; }
    [ "$(grep -cF "$(printf '\tapi\t-i\tlicenses/made-up-2.0\t--jq\t.key')" "$d/gh.log")" -eq 1 ] || { cat "$d/gh.log" >&2; die "[$mode] not checked once"; }
    expect_no_out "$d" "Here is the plan"
    expect_no_out "$d" "Proceed?"
    expect_nothing_created "$d"
  done
  # Any other answer: the plain message, start again, nothing created.
  d="$(tmpdir)"
  export STUB_GH_LICENSE_CHECK_FAIL=server
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_LICENSE_CHECK_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub had a problem of its own, so the script could not check the licence mit with GitHub\."
  sed -n 2p "$d/err" | grep -F 'start the script again' >/dev/null || { cat "$d/err" >&2; die "server: next action is not to start again"; }
  expect_nothing_created "$d"
}

test_an_unknown_licence_typed_at_the_question_is_asked_again() {
  # S6's rule for an answer that cannot be used: explained, then the
  # question again. The new answer is checked too; none (1) and PolyForm
  # Noncommercial (6) need no check, and the step ends with its own done
  # line right after the question (#156 review), one blank line below it
  # (r1i: the log after a question comes after a blank line).
  local d again want lic
  for again in mit 1 6; do
    d="$(tmpdir)"
    working_git "$d"
    # name, display name, description, owner, product owner, pack,
    # visibility, licence, copyright holder, folder, git name, git email;
    # then the licence again, then "Proceed?".
    printf '%s\n' my-app "" "Lends tools." "" "" python "" mti "" "" "" "" "$again" no >"$d/in"
    whole "$d"
    expect_rc 1 "$d"
    sed -n 1p "$d/err" | grep '^What happened: You answered no' >/dev/null || { cat "$d/err" >&2; die "[$again] did not reach Proceed?"; }
    expect_out "$d" "GitHub has no licence with the short name mti. "
    grep -F 'GitHub has no licence with the short name mti. ' "$d/out" | grep -F "Please try again." >/dev/null || { cat "$d/out" >&2; die "[$again] not asked to try again"; }
    [ "$(grep -cF 'Licence (type the number or the name): ' "$d/out")" -eq 2 ] || { cat "$d/out" >&2; die "[$again] the licence question was not asked twice"; }
    if [ "$again" = mit ]; then
      want="$(printf 'api\t-i\tlicenses/mti\t--jq\t.key\napi\t-i\tlicenses/mit\t--jq\t.key')"
      expect_out "$d" "    Licence: mit, in the name of"
      expect_out "$d" "    Done. GitHub knows the licence mit."
    else
      want="$(printf 'api\t-i\tlicenses/mti\t--jq\t.key')"
      if [ "$again" = 1 ]; then
        lic=none
        expect_out "$d" "    Licence: none (no licence file"
      else
        lic=polyform-noncommercial-1.0.0
        expect_out "$d" "    Licence: polyform-noncommercial-1.0.0, in the name of"
      fi
      grep -A2 -F 'Licence (type the number or the name): ' "$d/out" | tail -2 >"$d/done"
      [ "$(cat "$d/done")" = "$(printf '\n    Done. Nothing to check with GitHub for the licence %s.' "$lic")" ] \
        || { cat "$d/out" >&2; die "[$again] the step does not end with its done line after the question"; }
    fi
    [ "$(grep -F "$(printf '\tlicenses/')" "$d/gh.log" | cut -f2-)" = "$want" ] || { cat "$d/gh.log" >&2; die "[$again] the licence checks were not as expected"; }
    [ "$(grep -c '^==> Checking that GitHub knows the licence' "$d/out")" -eq 1 ] || { cat "$d/out" >&2; die "[$again] the step did not start once"; }
    expect_nothing_created "$d"
  done
}

test_actions_turned_on_are_checked_right_after_protection() {
  local d
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not reach the end"; }
  # After the settings of step 3, before the copy (expect_calls is exact).
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$ACTIONS_CALL" "$CLONE_CALL" "$LICENSE_CALL" "$PR_CALL" "${END_CALLS[@]}"
  grep -A1 -xF "==> Checking that GitHub Actions, which runs the project's checks, is turned on for it" "$d/out" | sed -n 2p >"$d/done"
  [ "$(cat "$d/done")" = "    Done. GitHub Actions is turned on for the project, so its checks can run there." ] \
    || { cat "$d/out" >&2; die "no step lines for the Actions check"; }
  [ "$(grep -F "$(printf '\t--jq\t.enabled')" "$d/gh.log" | cut -f1)" = GH_PROMPT_DISABLED=1 ] || { cat "$d/gh.log" >&2; die "asked with gh's prompts on"; }
}

test_actions_turned_off_stop_before_the_copy_with_their_guide() {
  local d
  d="$(tmpdir)"
  echo 9999 >"$d/actions-off"
  setup_run "$d" --non-interactive --yes
  expect_rc 3 "$d"
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$ACTIONS_CALL"
  expect_out "$d" "GitHub Actions, the GitHub service that runs your project's checks, is turned off for the project octo-user/my-app."
  expect_out "$d" "Why this is needed: "
  expect_out "$d" "https://github.com/octo-user/my-app/settings/actions"
  expect_out "$d" '"Allow all actions and reusable workflows"'
  expect_out "$d" "one of its owners"
  expect_out "$d" "How the script checks it: "
  expect_no_out "$d" "Press Enter"
  expect_continue_command "$d" " --resume"
  sed -n 1p "$d/err" | grep -F "What happened: GitHub Actions, the GitHub service that runs your project's checks, is turned off for the project octo-user/my-app. The script stopped here. The project octo-user/my-app exists on GitHub" >/dev/null \
    || { cat "$d/err" >&2; die "the stop does not say what is off and what exists"; }
  [ -z "$(ls -A "$d/cwd")" ] || { ls -A "$d/cwd" >&2; die "something was made on this computer"; }
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on with Actions off"
  # Interactive: turned on while the script waits; Enter checks again and
  # the setup goes on.
  d="$(tmpdir)"
  echo 1 >"$d/actions-off"
  printf 'yes\n\n' >"$d/in"
  setup_run "$d"
  expect_rc 0 "$d"
  expect_out "$d" "Press Enter to check again"
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$ACTIONS_CALL" "$ACTIONS_CALL" "$CLONE_CALL" "$LICENSE_CALL" "$PR_CALL" "${END_CALLS[@]}"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not go on after Actions was turned on"; }
  # Interactive, stopped at the guide (q): the command to continue, and
  # nothing on this computer.
  d="$(tmpdir)"
  echo 9999 >"$d/actions-off"
  printf 'yes\nq\n' >"$d/in"
  setup_run "$d"
  expect_rc 3 "$d"
  expect_continue_command "$d" " --resume"
  [ -z "$(ls -A "$d/cwd")" ] || { ls -A "$d/cwd" >&2; die "q: something was made on this computer"; }
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$ACTIONS_CALL"
}

test_an_actions_check_github_does_not_answer_carries_on_with_a_note() {
  # A 403 (no permission to read the setting) or a 404 (the endpoint not
  # as the spec has it), or an answer that is neither true nor false,
  # does not stop the setup: it says what could not be checked, with
  # GitHub's answer below, and goes on to the copy.
  local d mode raw
  for mode in forbidden not-found odd; do
    d="$(tmpdir)"
    case "$mode" in
      odd) export STUB_GH_ACTIONS_ANSWER=null; raw='    HTTP 200: enabled is null' ;;
      forbidden) export STUB_GH_ACTIONS_FAIL=forbidden; raw='    HTTP 403: Resource not accessible by integration' ;;
      not-found) export STUB_GH_ACTIONS_FAIL=not-found; raw='    HTTP 404: Not Found' ;;
    esac
    setup_run "$d" --non-interactive --yes
    unset STUB_GH_ACTIONS_ANSWER STUB_GH_ACTIONS_FAIL
    expect_rc 0 "$d"
    grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "$mode: did not go on"; }
    expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$ACTIONS_CALL" "$CLONE_CALL" "$LICENSE_CALL" "$PR_CALL" "${END_CALLS[@]}"
    sed -n "/^==> Checking that GitHub Actions/,/^    Done\. /p" "$d/out" >"$d/step"
    grep -qF "The script could not check whether GitHub Actions is turned on for the project" "$d/step" || { cat "$d/out" >&2; die "$mode: no note"; }
    grep -qxF 'Details for support (you can ignore these):' "$d/step" || { cat "$d/out" >&2; die "$mode: the answer is not introduced"; }
    grep -qxF "$raw" "$d/step" || { cat "$d/out" >&2; die "$mode: GitHub's answer is not below"; }
    [ "$(tail -1 "$d/step")" != "${raw}" ] && tail -1 "$d/step" | grep '^    Done\. Carrying on without this check' >/dev/null \
      || { cat "$d/out" >&2; die "$mode: the step does not end by carrying on"; }
    expect_no_out "$d" "turned off for the project"
  done
  # Any other answer stops like the other calls after create: the plain
  # message, the command to continue, nothing on this computer.
  d="$(tmpdir)"
  export STUB_GH_ACTIONS_FAIL=server
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_ACTIONS_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub had a problem of its own, so the script could not check whether GitHub Actions is turned on for the project\. The project octo-user/my-app exists on GitHub"
  expect_continue_command "$d" " --resume"
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$ACTIONS_CALL"
  [ -z "$(ls -A "$d/cwd")" ] || { ls -A "$d/cwd" >&2; die "server: something was made on this computer"; }
}

test_create_failures_are_guided_or_explained_and_nothing_else_runs() {
  local d
  # Taken although the check saw no project (a private one the account
  # cannot see): guided, a plain new run (no --resume), exit 3.
  d="$(tmpdir)"
  export STUB_GH_CREATE_FAIL=taken
  setup_run "$d" --non-interactive --yes
  expect_rc 3 "$d"
  expect_calls "$d" "$CREATE_CALL"
  expect_out "$d" "already exists"
  expect_out "$d" "--name my-app-2"
  shown_after "$d" 'To start again, run this command:' >"$d/cmd"
  grep -q '^    bash ' "$d/cmd" && ! grep -qF -- '--resume' "$d/cmd" || { cat "$d/out" >&2; die "taken: not a plain new run"; }
  sed -n 1p "$d/err" | grep 'nothing was created' >/dev/null || { cat "$d/err" >&2; die "taken: does not say nothing was created"; }
  grep -qxF '    GraphQL: Name already exists on this account (cloneTemplateRepository)' "$d/out" || { cat "$d/out" >&2; die "taken: gh's text not below"; }
  # Refused, for an organisation, with a fine-grained token: the guide
  # covers both, and keeps the warning's promise ("a later step stops
  # and says so").
  d="$(tmpdir)"
  export STUB_GH_CREATE_FAIL=refused STUB_GH_SCOPES=-
  setup_run "$d" --non-interactive --yes --owner acme
  expect_rc 3 "$d"
  expect_calls "$d" "${CREATE_CALL/octo-user/acme}"
  expect_out "$d" "GitHub did not let your account create the project acme/my-app."
  expect_out "$d" "Member privileges"
  expect_out "$d" "Administration"
  expect_out "$d" "https://github.com/settings/personal-access-tokens"
  expect_out "$d" "https://github.com/new"
  unset STUB_GH_SCOPES
  # Refused for your own account with a classic token: no organisation
  # or token steps, still the page to try by hand.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 3 "$d"
  expect_no_out "$d" "Member privileges"
  expect_no_out "$d" "personal-access-tokens"
  expect_out "$d" "https://github.com/new"
  # Not signed in any more: explained, exit 1.
  d="$(tmpdir)"
  export STUB_GH_CREATE_FAIL=signed-out
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" ".*is not signed in"
  expect_calls "$d" "$CREATE_CALL"
  # Another error: GitHub is asked whether the project exists. Not there:
  # a plain new run; there: continue with --resume.
  d="$(tmpdir)"
  export STUB_GH_CREATE_FAIL=broken
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "gh .* could not create the project octo-user/my-app"
  expect_calls "$d" "$CREATE_CALL" "$PROBE_CALL"
  grep -qxF '    stub gh: the connection broke off' "$d/err" || { cat "$d/err" >&2; die "broken: gh's text not below"; }
  expect_out "$d" "To start again, run this command:"
  d="$(tmpdir)"
  export STUB_GH_CREATE_FAIL=broken-but-made
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" ".*octo-user/my-app exists on GitHub"
  expect_calls "$d" "$CREATE_CALL" "$PROBE_CALL"
  expect_continue_command "$d" " --resume"
  unset STUB_GH_CREATE_FAIL
}

test_a_failed_settings_change_is_explained_with_the_continue_command() {
  local d
  d="$(tmpdir)"
  export STUB_GH_EDIT_FAIL=1
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" ".{10,}"
  grep -qF 'Must have admin rights' "$d/err" || { cat "$d/err" >&2; die "gh's text not below"; }
  expect_continue_command "$d" " --resume"
  expect_no_out "$d" "$FINISHED"
}

test_an_unknown_answer_after_create_says_what_failed_and_how_to_continue() {
  # #150 review, finding 1: a status api_fail has no arm for (the stub's
  # 418) once the project exists printed only the "exists on GitHub" note,
  # with "Run the script again" under the command to continue. The first
  # line must say what failed; the next action must be the command to
  # continue (finding 2: no "start the script again" after create).
  local d mode want
  for mode in "PROTECT protect the main version of the project" \
    "BRANCH check that the project's files are there"; do
    want="${mode#* }"; mode="${mode%% *}"
    d="$(tmpdir)"
    export "STUB_GH_${mode}_FAIL=teapot"
    setup_run "$d" --non-interactive --yes
    expect_rc 1 "$d"
    expect_err_shape "$d" "Something unexpected happened, so the script could not $want\. The project octo-user/my-app exists on GitHub"
    sed -n 2p "$d/err" | grep -F 'continue the setup with the command shown above' >/dev/null || { cat "$d/err" >&2; die "$mode: next action is not to continue"; }
    ! grep -qiE 'run the script again|start the script again' "$d/err" || { cat "$d/err" >&2; die "$mode: told to start again after create"; }
    grep -qxF '    HTTP 418: Short and stout' "$d/err" || { cat "$d/err" >&2; die "$mode: raw text not below"; }
    expect_continue_command "$d" " --resume"
    unset "STUB_GH_${mode}_FAIL"
  done
  # Mapped answers after create continue too: a 503 and a 401 at the
  # wait, a rate limit at the protection request.
  for mode in "BRANCH server" "BRANCH expired" "PROTECT rate-limit"; do
    want="${mode#* }"; mode="${mode%% *}"
    d="$(tmpdir)"
    export "STUB_GH_${mode}_FAIL=$want"
    setup_run "$d" --non-interactive --yes
    expect_rc 1 "$d"
    expect_err_shape "$d" ".*octo-user/my-app exists on GitHub"
    sed -n 2p "$d/err" | grep -F 'continue the setup with the command shown above' >/dev/null || { cat "$d/err" >&2; die "$want: next action is not to continue"; }
    ! grep -qiE 'run the script again|start the script again' "$d/err" || { cat "$d/err" >&2; die "$want: told to start again after create"; }
    unset "STUB_GH_${mode}_FAIL"
  done
  # Before create the same answer still says to start again.
  d="$(tmpdir)"
  export STUB_GH_USER_FAIL=teapot
  pre "$d" ni preflight_github_account
  expect_rc 1 "$d"
  expect_err_shape "$d" "Something unexpected happened, so the script could not read your GitHub account\.\$"
  sed -n 2p "$d/err" | grep -F 'start the script again' >/dev/null || { cat "$d/err" >&2; die "before create: next action is not to start again"; }
}

test_the_lines_that_opt_out_of_the_literal_scan_are_pinned() {
  # #149 review, finding 2: a "# not-a-message" line hides its literals
  # from the banned-words scan, so each one is listed here, and a new
  # one is a test change a reviewer sees.
  local got
  got="$(grep -E '# not-a-message[[:space:]]*$' "$SCRIPT" | sed -E 's/^[[:space:]]+//')"
  [ "$got" = 'help="$(run_gh repo create --help 2>&1)" || help="" # not-a-message' ] \
    || { printf '%s\n' "$got" >&2; die "the lines marked # not-a-message changed"; }
}

test_a_404_or_429_gets_the_next_action_of_its_own_call() {
  # #149 review, finding 3: the 404 on the bootstrapper's CHANGELOG.md is
  # not about names the user gave; a 429 (GitHub's secondary rate limit)
  # shares the rate-limit text. The stub's 429 message does not say "rate
  # limit", so the status alone must map it.
  local d
  d="$(tmpdir)"
  export STUB_GH_CHANGELOG_FAIL=not-found
  pre "$d" ni preflight_published_version
  expect_rc 1 "$d"
  expect_err_shape "$d" ".{10,}"
  ! grep -qF 'Check the names you gave' "$d/err" || { cat "$d/err" >&2; die "the CHANGELOG 404 asks to check names"; }
  grep -q '^What to do next: .*[Dd]ownload' "$d/err" || { cat "$d/err" >&2; die "the CHANGELOG 404 does not say to download again"; }
  unset STUB_GH_CHANGELOG_FAIL
  d="$(tmpdir)"
  export STUB_GH_USER_FAIL=too-many
  pre "$d" ni preflight_github_account
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub has paused"
}

# ---------- the copy on this computer ----------
# After step 3 (spec "Steps, in order" 4, 5, 6 and 9): gh repo clone
# makes the copy in the target folder; origin/main must hold CHANGELOG.md
# stamped with the script's own version; the git name and email are
# written into the copy's own settings (never --global); the line of work
# bootstrap-setup starts from origin/main; the pack is laid out over the
# copy (ci.yml replaced, the pack's gitignore lines added when missing,
# any other target already there an error; --with-deploy adds the web
# deploy files); then the tidy-up. The later steps save (commit), send
# (push) and propose the change (see "self-check, save, send and
# propose" below), and steps 15 to 19 follow (see "wait, require, add,
# finish and report"). These runs use the built, stamped script (use_built), and the
# stub gh makes each project from a real build.sh output.

copy_of() { printf '%s\n' "$1/cwd/my-app"; }
bare_of() { printf '%s\n' "$1/remotes/octo-user/my-app.git"; }
in_git() { "$REAL_GIT" "$@"; }

# tree_of <dir>: every file under <dir> (not .git), one per line, sorted.
tree_of() {
  (cd "$1" && find . -path ./.git -prune -o \( -type f -o -type l \) -print) | sed 's|^\./||' | LC_ALL=C sort
}
# xbit <file>: x when the file can be run, else -.
xbit() { if [ -x "$1" ]; then echo x; else echo -; fi; }

STEPS_AFTER_SETTINGS='==> Checking that GitHub Actions, which runs the project'"'"'s checks, is turned on for it
==> Making a copy of the project on this computer, in ./my-app
==> Writing your name and email into the copy'"'"'s own git settings
==> Starting a separate line of work for the setup, named bootstrap-setup
==> Checking that the copy has everything the setup changes, before it changes anything
==> Adding the python language pack'"'"'s files to the copy
==> Removing what only the setup needed from the copy
==> Filling in the project'"'"'s name, description and product owner in its files
==> Adding the project'"'"'s licence
==> Noting the setup in CHANGELOG.md, the project'"'"'s list of changes
==> Checking the setup'"'"'s changes before saving them
==> Saving the setup'"'"'s changes in the copy as one change, "Set up my-app"
==> Sending the setup'"'"'s changes to GitHub, on the line of work bootstrap-setup
==> Proposing the setup'"'"'s changes on GitHub, where the project'"'"'s checks run on them
==> Waiting for the project'"'"'s check build to pass on the proposed change, for at most 20 minutes
==> Making the check build required, so that from now on a change is added to the main version only after build passes
==> Adding the proposed change to the main version of the project
==> Updating the copy on this computer to the new main version'

test_the_copy_is_made_by_gh_and_checked_against_the_script_version() {
  local d c
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$ACTIONS_CALL" "$CLONE_CALL" "$LICENSE_CALL" "$PR_CALL" "${END_CALLS[@]}"
  [ "$(cut -f1 "$d/gh.log" | LC_ALL=C sort -u)" = GH_PROMPT_DISABLED=1 ] || { cat "$d/gh.log" >&2; die "a gh call ran with prompts on"; }
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" rev-parse origin/main)" = "$(in_git --git-dir="$(bare_of "$d")" rev-parse main)" ] \
    || die "the copy is not of the project that was made"
  # The new steps, in order, each with a start and a done line.
  [ "$(grep '^==> ' "$d/out" | sed -n '/^==> Setting how proposed/,$p' | sed 1d)" = "$STEPS_AFTER_SETTINGS" ] \
    || { cat "$d/out" >&2; die "the steps after the settings are not the Actions check, the copy, name, line of work, pack, tidy-up, fill, licence, CHANGELOG, self-check, save, send, propose, wait, require, add, update"; }
  [ "$(grep -c '^==> ' "$d/out")" -eq "$(grep -c '^    Done\. ' "$d/out")" ] || { cat "$d/out" >&2; die "a step has no done line"; }
  expect_out "$d" "    Done. The copy is in ./my-app, with the files of version $BUILT_VERSION of the bootstrapper."
  # It goes through to the report, with nothing on stderr and no command
  # to continue.
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not go through to the report"; }
  [ ! -s "$d/err" ] || { cat "$d/err" >&2; die "a run that went through wrote to stderr"; }
  expect_no_out "$d" "To continue the setup, run this command:"
}

test_the_git_name_and_email_are_written_into_the_copy_only() {
  local d c
  d="$(tmpdir)"
  prepare "$d"
  cp "$d/home/.gitconfig" "$d/global-before"
  setup_run "$d" --non-interactive --yes --git-name "Ada Lovelace" --git-email ada@example.com
  expect_rc 0 "$d"
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" config --local --get user.name)" = "Ada Lovelace" ] || die "the name is not in the copy's settings"
  [ "$(in_git -C "$c" config --local --get user.email)" = ada@example.com ] || die "the email is not in the copy's settings"
  cmp -s "$d/global-before" "$d/home/.gitconfig" || { cat "$d/home/.gitconfig" >&2; die "the global git settings changed"; }
  # Written right after the copy is made, before the line of work starts,
  # and never with --global or --system.
  grep -n 'config user\.name Ada Lovelace' "$d/tools.log" | head -1 | cut -d: -f1 >"$d/n"
  grep -n ' checkout ' "$d/tools.log" | head -1 | cut -d: -f1 >"$d/b"
  [ -s "$d/n" ] && [ -s "$d/b" ] && [ "$(cat "$d/n")" -lt "$(cat "$d/b")" ] || { cat "$d/tools.log" >&2; die "the name was not written before the line of work"; }
  ! grep -E 'config (--global|--system|--file)' "$d/tools.log" | grep -v -- ' --get ' >/dev/null || { cat "$d/tools.log" >&2; die "git settings outside the copy were written"; }
}

test_the_setup_is_saved_as_one_change_sent_on_its_line_of_work_and_proposed() {
  # Spec steps 5, 13 and 14: the line of work bootstrap-setup starts at
  # main and follows nothing on GitHub; the setup's changes are saved as
  # one change "Set up <name>" under the git name and email of the
  # questions, sent to GitHub on that line of work (main is not touched),
  # and proposed there with gh pr create, its title and body given, so gh
  # asks nothing. Afterwards the copy has nothing left unsaved. The check
  # build fails here, so the run stops right after the proposed change
  # (step 15) and the state of step 14 can be seen.
  local d c bare body
  d="$(tmpdir)"
  export STUB_GH_BUILD="pull_request fail"
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_BUILD
  expect_rc 1 "$d"
  c="$(copy_of "$d")"
  bare="$(bare_of "$d")"
  [ "$(in_git -C "$c" symbolic-ref --short HEAD)" = bootstrap-setup ] || die "the copy is not on bootstrap-setup"
  [ "$(in_git -C "$c" rev-parse HEAD~1)" = "$(in_git --git-dir="$bare" rev-parse main)" ] || die "the saved change does not come right after main"
  [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 2 ] || die "not exactly one change was saved"
  [ "$(in_git -C "$c" log -1 --format=%s%n%b)" = "Set up my-app" ] || { in_git -C "$c" log -1 >&2; die "the change is not named Set up my-app"; }
  [ "$(in_git -C "$c" log -1 --format='%an <%ae>|%cn <%ce>')" = "Test Person <test@example.com>|Test Person <test@example.com>" ] \
    || { in_git -C "$c" log -1 --format=fuller >&2; die "the change is not saved under the git name and email given"; }
  [ -z "$(in_git -C "$c" status --porcelain --untracked-files=all)" ] || { in_git -C "$c" status >&2; die "something is left unsaved"; }
  ! in_git -C "$c" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || die "bootstrap-setup follows a branch on GitHub"
  [ "$(in_git --git-dir="$bare" rev-parse refs/heads/bootstrap-setup)" = "$(in_git -C "$c" rev-parse HEAD)" ] || die "the change was not sent on bootstrap-setup"
  [ "$(in_git --git-dir="$bare" rev-parse main)" = "$(in_git -C "$c" rev-parse origin/main)" ] || die "main on GitHub was changed"
  [ "$(in_git --git-dir="$bare" for-each-ref --format='%(refname)' | LC_ALL=C sort)" = "$(printf '%s\n' refs/heads/bootstrap-setup refs/heads/main)" ] \
    || die "something else was sent to GitHub"
  # gh after the copy: the licence, then the proposed change (then the
  # look at build and, as it failed, at the actions allowed); its body
  # file is a temporary file outside the copy, gone afterwards.
  [ "$(calls_from_create "$d" | sed -n '/^repo clone /,$p')" = "$CLONE_CALL"$'\n'"$LICENSE_CALL"$'\n'"$PR_CALL"$'\n'"$CHECKS_CALL"$'\n'"$ALLOWED_CALL" ] || { cat "$d/gh.log" >&2; die "gh was not used for the licence and then the proposed change"; }
  body="$(awk -F'\t' '$2 == "pr" { for (i = 3; i <= NF; i++) if ($(i - 1) == "--body-file") print $i }' "$d/gh.log")"
  case "$body" in "$c"/*) die "the body file was in the copy: $body" ;; esac
  [ ! -e "$body" ] || die "the body file was left behind: $body"
  # The body says in plain words what the change is.
  for t in "This proposed change sets up My App." "version $BUILT_VERSION of the bootstrapper" \
    "the python language pack" "Licence: mit, in the name of Ada L." "-----"; do
    grep -qF -- "$t" "$d/pr-bodies" || { cat "$d/pr-bodies" >&2; die "the body lacks: $t"; }
  done
  [ -z "$(banned_hits <"$d/pr-bodies")" ] || { cat "$d/pr-bodies" >&2; die "a banned word in the body"; }
  expect_out "$d" "    Done. The proposed change is on GitHub: https://github.com/octo-user/my-app/pull/1"
}

# The spec's fill table (step 8), written out here on purpose rather than
# read from the script, so the test checks the script against the spec:
# one row per (file, exact text, value) for <pack> [--with-deploy], as
# "<file>|<text>|<value key>"; \n in a text is a line break.
want_fill_rows() {
  printf '%s\n' \
    'README.md|[PROJECT NAME]|display' \
    'README.md|[PO NAME]|po' \
    'README.md|[One or two sentences: what this project is and who it is for.]|description' \
    'CLAUDE.md|[PROJECT NAME]|display' \
    'CHANGELOG.md|[PROJECT NAME]|display' \
    'docs/SPEC.md|[PROJECT NAME]|display' \
    'docs/SPEC.md|[DATE]|date' \
    'docs/BACKLOG.md|[PROJECT NAME]|display' \
    'docs/BACKLOG.md|[PO NAME]|po' \
    'docs/NEXT_SESSION.md|[PROJECT NAME]|display' \
    'docs/NEXT_SESSION.md|[DATE]|date' \
    'memory/project.md|[PROJECT NAME]|display' \
    'memory/project.md|[OWNER/REPO]|owner-and-name' \
    'memory/project.md|[What the project is, who it is for, and what problem\nit solves.]|description'
  case "$1" in
    node | web | react-native)
      printf '%s\n' 'package.json|[project-description]|description' 'package.json|[project-name]|slug' ;;
  esac
  case "$1" in
    web)
      echo 'index.html|[project-name]|display'
      [ -z "${2:-}" ] || echo 'wrangler.jsonc|[project-name]|slug'
      ;;
    react-native) printf '%s\n' 'app.json|[PROJECT NAME]|display' 'app.json|[project-slug]|slug' ;;
  esac
}

# W_*: the values the fill must use. The defaults are setup_run's
# answers; a test that gives others sets these to match.
W_DISPLAY="My App" W_PO=Ada W_OWNER_AND_NAME=octo-user/my-app
W_DESCRIPTION="Lends tools to neighbours." W_SLUG=my-app
# W_LICENSE and W_HOLDER: the licence and copyright holder the run used
# (setup_run's --license mit and --copyright-holder "Ada L").
W_LICENSE=mit W_HOLDER="Ada L"
want_value() {
  case "$1" in
    display) printf '%s' "$W_DISPLAY" ;;
    po) printf '%s' "$W_PO" ;;
    owner-and-name) printf '%s' "$W_OWNER_AND_NAME" ;;
    description) printf '%s' "$W_DESCRIPTION" ;;
    slug) printf '%s' "$W_SLUG" ;;
    date) printf '%s' "$FAKE_TODAY" ;;
    *) die "want_value: unknown key $1" ;;
  esac
}

# filled_as <dir> <pack> <deploy> <file> <source> <out>: writes <source>
# with the fill rows of <file> applied, using bash's own literal
# replacement (not the script's awk). Each row's text must be in
# <source>, or the test is stale. The rows used are added to
# <dir>/applied, so the caller can check that every row was used.
filled_as() {
  local d="$1" p="$2" deploy="$3" f="$4" s rf t key v nl=$'\n'
  s="$(cat "$5"; printf x)"
  s="${s%x}"
  while IFS='|' read -r rf t key; do
    [ "$rf" = "$f" ] || continue
    t="${t//\\n/$nl}"
    v="$(want_value "$key")"
    case "$s" in *"$t"*) ;; *) die "$p$deploy: $f has no $t before the fill (test is stale)" ;; esac
    s=${s//"$t"/"$v"}
    printf '%s|%s\n' "$rf" "$key" >>"$d/applied"
  done < <(want_fill_rows "$p" "$deploy")
  printf '%s' "$s" >"$6"
}

# want_changelog_lines <pack> <deploy>: the lines step 11 adds to
# CHANGELOG.md, for the licence W_LICENSE.
want_changelog_lines() {
  if [ -n "${2:-}" ]; then
    printf '%s\n' "- Language pack: $1, with the files that publish the website."
  else
    printf '%s\n' "- Language pack: $1."
  fi
  printf '%s\n' "- Licence: $W_LICENSE." "- Set up by bootstrap-project.sh."
}

# want_licence <key>: the LICENSE a GitHub licence becomes: GitHub's text
# (the stub's) with [year] the year of FAKE_TODAY and [fullname]
# W_HOLDER, by bash's own literal replacement (not the script's awk).
want_licence() {
  local s
  s="$(cat "$STUB_GH_LICENSES/$1")"
  s=${s//"[year]"/"${FAKE_TODAY%%-*}"}
  s=${s//"[fullname]"/"$W_HOLDER"}
  printf '%s\n' "$s"
}

# expect_filled <dir> <pack> <deploy> <file> <source> <copy file>: the
# copy's file is <source> with exactly its fill rows applied, and has the
# same mode.
expect_filled() {
  filled_as "$1" "$2" "$3" "$4" "$5" "$1/filled"
  cmp -s "$1/filled" "$6" || { diff "$1/filled" "$6" >&2 || true; die "$2$3: $4 is not the template's with exactly its texts filled in (want, then got, above)"; }
  [ "$(xbit "$5")" = "$(xbit "$6")" ] || die "$2$3: the mode of $4 changed"
}

# expect_setup_tree <dir> <copy> <pack> [--with-deploy]: the copy holds
# exactly the tree the setup must leave for that pack (see the test
# below), file by file, with the placeholders filled in (spec step 8)
# in exactly the files the fill table names, and nowhere else.
expect_setup_tree() {
  local d="$1" c="$2" p="$3" deploy="${4:-}" fresh f other kept
  fresh="$d/fresh"
  : >"$d/applied"
  PACKS_DIR="$BUILT/languages" bash "$BUILT/bootstrap-project.sh" layout-pack "$p" "$fresh" >/dev/null
  kept=code-standards.md
  [ "$p" != web ] || [ -n "$deploy" ] || kept="$kept deploy.yml wrangler.jsonc"
  { tree_of "$BUILT" | grep -v '^languages/' | grep -vx 'bootstrap-project.sh' | grep -vxF '.github/README.md'
    tree_of "$fresh"
    for f in $kept; do echo "languages/$p/$f"; done
    [ -z "$deploy" ] || printf '%s\n' .github/workflows/deploy.yml wrangler.jsonc
    case "$p" in node | web | react-native) echo package-lock.json ;; esac
    [ "$W_LICENSE" = none ] || echo LICENSE
    [ "$W_LICENSE" != polyform-noncommercial-1.0.0 ] || echo NOTICE
  } | LC_ALL=C sort -u >"$d/want"
  tree_of "$c" >"$d/got"
  expect_same "$p$deploy: the tree" "$d/want" "$d/got"
  # Kept in every pack: the check that each pack's CI runs, and the
  # template's licence folder.
  [ -x "$c/.github/scripts/require-test-change.sh" ] || die "$p$deploy: require-test-change.sh is not kept as a script"
  [ -f "$c/licenses/NOTICE" ] || die "$p$deploy: licenses/ is not kept"
  # Laid out: the same bytes as layout-pack lays out, with the fill rows
  # of that file applied; ci.yml is the pack's, not the stub.
  while IFS= read -r f; do
    [ "$f" != .gitignore ] || continue
    expect_filled "$d" "$p" "$deploy" "$f" "$fresh/$f" "$c/$f"
  done < <(tree_of "$fresh")
  cmp -s "$BUILT/languages/$p/ci.yml" "$c/.github/workflows/ci.yml" || die "$p$deploy: ci.yml is not the pack's"
  if [ -n "$deploy" ]; then
    cmp -s "$BUILT/languages/web/deploy.yml" "$c/.github/workflows/deploy.yml" || die "deploy.yml is not the pack's"
    expect_filled "$d" "$p" "$deploy" wrangler.jsonc "$BUILT/languages/web/wrangler.jsonc" "$c/wrangler.jsonc"
  fi
  # Kept pack files are not filled in: the spec names two that keep a
  # text of the fill table.
  for f in $kept; do
    cmp -s "$BUILT/languages/$p/$f" "$c/languages/$p/$f" || die "$p$deploy: kept $f changed"
  done
  [ "$p" != react-native ] || grep -qF '[project-slug]' "$c/languages/react-native/code-standards.md" \
    || die "react-native: code-standards.md lost its [project-slug]"
  [ "$p" != web ] || [ -n "$deploy" ] || grep -qF '"[project-name]"' "$c/languages/web/wrangler.jsonc" \
    || die "web: the kept wrangler.jsonc lost its [project-name]"
  # Every other file of the bootstrapper is unchanged, mode included,
  # except for the fill rows of that file.
  while IFS= read -r f; do
    case "$f" in README.md | .gitignore | docs/DEV_INFRASTRUCTURE.md | .github/workflows/ci.yml | CHANGELOG.md) continue ;; esac
    expect_filled "$d" "$p" "$deploy" "$f" "$BUILT/$f" "$c/$f"
  done < <(tree_of "$BUILT" | grep -v '^languages/' | grep -vx 'bootstrap-project.sh' | grep -vxF '.github/README.md')
  # The bootstrapper's own README (PBI-1.29) is gone: the project's page
  # shows the project's README.
  [ -f "$BUILT/.github/README.md" ] || die "the built bootstrapper has no .github/README.md (test is stale)"
  [ ! -e "$c/.github/README.md" ] || die "$p$deploy: the bootstrapper's own README is still in the copy"
  [ -d "$c/.github/workflows" ] || die "$p$deploy: the tidy-up removed more of .github/ than its README"
  # .gitignore: the bootstrapper's, then the pack's lines it lacked.
  { cat "$BUILT/.gitignore"
    while IFS= read -r f; do grep -qxF -- "$f" "$BUILT/.gitignore" || printf '%s\n' "$f"; done <"$BUILT/languages/$p/gitignore"
  } >"$d/gitignore"
  expect_same "$p$deploy: .gitignore" "$d/gitignore" "$c/.gitignore"
  # README.md: the section from "## Finishing the setup" up to the next
  # heading (## Setup) is gone, nothing else, and the rest filled in.
  grep -q '^## Finishing the setup' "$BUILT/README.md" || die "the built README has no setup section (test is stale)"
  sed '/^## Finishing the setup/,/^## Setup$/{/^## Setup$/!d;}' "$BUILT/README.md" >"$d/readme"
  [ "$(wc -l <"$d/readme")" -lt "$(wc -l <"$BUILT/README.md")" ] || die "the test's README expectation removed nothing"
  expect_filled "$d" "$p" "$deploy" README.md "$d/readme" "$c/README.md"
  # docs/DEV_INFRASTRUCTURE.md (PBI-1.29): Part 2's sections of the other
  # packs are gone, each from its heading to the next ### or ## heading
  # outside a code block (or the end of the file); its own stays, and
  # nothing points to the template. A second statement of the cut, on
  # purpose (the script's is remove_pack_section).
  cp "$BUILT/docs/DEV_INFRASTRUCTURE.md" "$d/dev"
  for other in node web python react-native; do
    [ "$other" != "$p" ] || continue
    grep -qF "(\`$other\` pack)" "$d/dev" || die "the doc has no section for $other (test is stale)"
    HEAD_END="(\`$other\` pack)" awk '
      /^ *```/ { fence = !fence }
      !fence && skip && (/^### / || /^## /) { skip = 0 }
      !fence && /^### / && substr($0, length($0) - length(ENVIRON["HEAD_END"]) + 1) == ENVIRON["HEAD_END"] { skip = 1 }
      skip { next }
      /^$/ { blanks++; next }
      { while (blanks > 0) { print ""; blanks-- } print }' "$d/dev" >"$d/dev2"
    mv "$d/dev2" "$d/dev"
    ! grep -qE "(^|[^/])languages/$other/" "$c/docs/DEV_INFRASTRUCTURE.md" || die "$p$deploy: a link to the removed $other pack is left"
    ! grep -qF "(\`$other\` pack)" "$c/docs/DEV_INFRASTRUCTURE.md" || die "$p$deploy: the section of the removed $other pack is left"
    # Part 2 (the packs' own sections) no longer speaks of another pack.
    ! sed -n '/^## Part 2/,$p' "$c/docs/DEV_INFRASTRUCTURE.md" | grep -F "\`$other\` pack" >&2 \
      || die "$p$deploy: Part 2 still refers to the removed $other pack"
  done
  [ -z "$(tail -c 1 "$c/docs/DEV_INFRASTRUCTURE.md")" ] && [ -n "$(tail -n 1 "$c/docs/DEV_INFRASTRUCTURE.md")" ] \
    || die "$p$deploy: DEV_INFRASTRUCTURE.md ends with a blank line"
  ! grep -qF 'ai-project-template-v2' "$c/docs/DEV_INFRASTRUCTURE.md" || die "$p$deploy: DEV_INFRASTRUCTURE.md points to the template"
  expect_same "$p$deploy: DEV_INFRASTRUCTURE.md" "$d/dev" "$c/docs/DEV_INFRASTRUCTURE.md"
  grep -qF "\`languages/$p/code-standards.md\`" "$c/docs/DEV_INFRASTRUCTURE.md" || die "$p$deploy: the link to its own pack was rewritten"
  # CHANGELOG.md (step 11): filled in, then the pack, the licence and
  # "set up by bootstrap-project.sh" at the end of "## Project created",
  # which is the file's last section.
  [ "$(grep '^## ' "$BUILT/CHANGELOG.md" | tail -1)" = '## Project created' ] || die "Project created is not the built CHANGELOG's last section (test is stale)"
  filled_as "$d" "$p" "$deploy" CHANGELOG.md "$BUILT/CHANGELOG.md" "$d/changelog"
  want_changelog_lines "$p" "$deploy" >>"$d/changelog"
  expect_same "$p$deploy: CHANGELOG.md" "$d/changelog" "$c/CHANGELOG.md"
  # The lockfile (step 7), for the npm packs only: made by npm in the
  # copy after the fill, so it names the project, not [project-name].
  case "$p" in
    node | web | react-native)
      [ "$(sed -n 2p "$c/package-lock.json")" = "  \"name\": \"$W_SLUG\"," ] \
        || { cat "$c/package-lock.json" >&2; die "$p$deploy: the lockfile does not name the project $W_SLUG"; }
      ;;
  esac
  # The licence (step 10).
  case "$W_LICENSE" in
    none) ;;
    polyform-noncommercial-1.0.0)
      cmp -s "$BUILT/licenses/PolyForm-Noncommercial-1.0.0.md" "$c/LICENSE" || die "$p$deploy: LICENSE is not the PolyForm text"
      printf 'Required Notice: Copyright %s\n' "$W_HOLDER" >"$d/notice"
      expect_same "$p$deploy: NOTICE" "$d/notice" "$c/NOTICE"
      ;;
    *)
      want_licence "$W_LICENSE" >"$d/licence"
      expect_same "$p$deploy: LICENSE" "$d/licence" "$c/LICENSE"
      ;;
  esac
  # Every file the setup wrote has LF line endings.
  for f in CHANGELOG.md LICENSE NOTICE package-lock.json; do
    [ ! -f "$c/$f" ] || ! has_cr "$c/$f" || die "$p$deploy: $f has a carriage return"
  done
  # Every row of the fill table was checked against some file.
  want_fill_rows "$p" "$deploy" | awk -F'|' '{ print $1 "|" $3 }' | LC_ALL=C sort -u >"$d/rows"
  LC_ALL=C sort -u "$d/applied" >"$d/applied-rows"
  expect_same "$p$deploy: the fill rows checked" "$d/rows" "$d/applied-rows"
  # Left for the first session with Clead (spec step 8): not filled in.
  cmp -s "$BUILT/STATUS.md" "$c/STATUS.md" || die "$p$deploy: STATUS.md is not the bootstrapper's stub, unchanged"
  grep -qF '[PHASE NAME]' "$c/docs/BACKLOG.md" || die "$p$deploy: [PHASE NAME] was filled in"
  grep -qxF -- '- [Goal]' "$c/memory/project.md" || die "$p$deploy: [Goal] was filled in"
  grep -qF '[What the system does' "$c/docs/SPEC.md" || die "$p$deploy: the SPEC section prompts were filled in"
  # The format token [DATE] stays where the spec says it does.
  grep -qF 'Adam approved [DATE]' "$c/memory/roles.md" || die "$p$deploy: [DATE] in memory/roles.md was filled in"
  grep -qF '[DATE]**' "$c/docs/CROG_ONBOARDING.md" || die "$p$deploy: [DATE] in docs/CROG_ONBOARDING.md was filled in"
}

test_every_pack_leaves_exactly_the_expected_tree() {
  # Spec, Testing: "every pack's final tree is exactly what is expected",
  # "no fill-table text is left", and "the README section is gone and
  # languages/ is pruned". The expected tree is the built bootstrapper
  # without the script and languages/, plus what layout-pack lays out
  # into an empty folder (its table is pinned in tools/test-layout-pack.sh),
  # plus the pack's files that were not laid out; each file has exactly
  # the fill rows of the spec's table applied (want_fill_rows).
  local d p deploy
  built_bootstrapper
  for p in node web python react-native web+deploy; do
    deploy=""
    [ "$p" != web+deploy ] || { p=web; deploy=--with-deploy; }
    d="$(tmpdir)"
    fake_tool "$d" npm 10.0.0
    setup_run "$d" --non-interactive --yes --pack "$p" $deploy
    expect_rc 0 "$d"
    grep -qxF "$FINISHED" "$d/out" || { cat "$d/err" >&2; die "$p$deploy: did not reach the end"; }
    expect_setup_tree "$d" "$(copy_of "$d")" "$p" "$deploy"
  done
}

test_the_pack_overlay_replaces_ci_yml_adds_missing_gitignore_lines_and_refuses_other_targets() {
  local d out rc
  d="$(tmpdir)"
  out="$d/copy"
  mkdir -p "$out/.github/workflows"
  printf 'stub\n' >"$out/.github/workflows/ci.yml"
  printf 'node_modules/\n.env\n*.log' >"$out/.gitignore"
  printf 'keep\n' >"$out/README.md"
  rc=0
  ( load_script; layout_into node "$REPO/languages" "$out" overlay ) >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 0 ] || { cat "$d/out" "$d/err" >&2; die "overlay failed"; }
  cmp -s "$REPO/languages/node/ci.yml" "$out/.github/workflows/ci.yml" || die "ci.yml was not replaced"
  # The lines that were there stay, the missing ones follow in the pack's
  # order, none twice, and the last line of the old file is ended first.
  printf '%s\n' node_modules/ .env '*.log' dist/ coverage/ .DS_Store Thumbs.db >"$d/want"
  expect_same ".gitignore" "$d/want" "$out/.gitignore"
  [ "$(cat "$out/README.md")" = keep ] || die "a file the pack does not have was changed"
  cmp -s "$REPO/languages/node/package.json" "$out/package.json" || die "package.json not laid out"
  cmp -s "$REPO/languages/node/placeholder.test.ts" "$out/src/placeholder.test.ts" || die "the test file not laid out"
  # Another target already there: an error, before anything is written.
  out="$d/copy2"
  mkdir -p "$out/.github/workflows"
  printf 'stub\n' >"$out/.github/workflows/ci.yml"
  printf 'x\n' >"$out/.gitignore"
  printf '{}\n' >"$out/tsconfig.json"
  rc=0
  ( load_script; layout_into node "$REPO/languages" "$out" overlay ) >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$d/err" >&2; die "exit $rc, want 1"; }
  sed -n 1p "$d/err" | grep -F "What happened: The copy of the project on this computer already has tsconfig.json, which the node pack would add." >/dev/null \
    || { cat "$d/err" >&2; die "the existing target is not named"; }
  sed -n 2p "$d/err" | grep -E '^What to do next: .{10,}' >/dev/null || { cat "$d/err" >&2; die "no next action"; }
  [ ! -e "$out/package.json" ] && [ "$(cat "$out/.github/workflows/ci.yml")" = stub ] && [ "$(cat "$out/.gitignore")" = x ] \
    && [ "$(cat "$out/tsconfig.json")" = '{}' ] || die "something was written before the error"
  # A folder target (python: starter/src/ to src/) that is there already.
  out="$d/copy3"
  mkdir -p "$out/src"
  rc=0
  ( load_script; layout_into python "$REPO/languages" "$out" overlay ) >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 1 ] || die "src/ there: exit $rc, want 1"
  sed -n 1p "$d/err" | grep -F "already has src/, which the python pack would add." >/dev/null || { cat "$d/err" >&2; die "src/ not named"; }
  [ ! -e "$out/pyproject.toml" ] || die "src/ there: something was written"
  # web with the deploy files: laid out, and only code-standards.md is
  # kept in the pack; without them, the deploy files are kept.
  out="$d/copy4"
  ( load_script; layout_into web "$REPO/languages" "$out" overlay yes; printf '%s\n' "$LP_KEPT" >"$d/kept" ) >"$d/out" 2>"$d/err" \
    || { cat "$d/err" >&2; die "web with deploy failed"; }
  cmp -s "$REPO/languages/web/deploy.yml" "$out/.github/workflows/deploy.yml" || die "deploy.yml not laid out"
  cmp -s "$REPO/languages/web/wrangler.jsonc" "$out/wrangler.jsonc" || die "wrangler.jsonc not laid out"
  [ "$(cat "$d/kept")" = code-standards.md ] || die "kept with deploy: $(cat "$d/kept")"
  out="$d/copy5"
  ( load_script; layout_into web "$REPO/languages" "$out" overlay; printf '%s\n' "$LP_KEPT" >"$d/kept" ) >"$d/out" 2>"$d/err" \
    || { cat "$d/err" >&2; die "web without deploy failed"; }
  [ ! -e "$out/.github/workflows/deploy.yml" ] && [ ! -e "$out/wrangler.jsonc" ] || die "deploy files laid out without --with-deploy"
  [ "$(cat "$d/kept")" = "code-standards.md deploy.yml wrangler.jsonc" ] || die "kept without deploy: $(cat "$d/kept")"
}

test_the_readme_setup_section_is_removed_up_to_the_next_heading() {
  local d rc
  d="$(tmpdir)"
  printf '%s\n' '# App' '' 'Intro.' '' '## Finishing the setup' '' 'Steps.' \
    '### A smaller heading' '##Not a heading' '' '## Setup' '' 'Run it.' >"$d/a"
  ( load_script; remove_setup_section "$d/a" ) || die "the section was not found"
  printf '%s\n' '# App' '' 'Intro.' '' '## Setup' '' 'Run it.' >"$d/want"
  expect_same "README" "$d/want" "$d/a"
  # The last section: removed up to the end of the file.
  printf '%s\n' '# App' '' '## Setup' 'x' '' '## Finishing the setup' 'y' >"$d/b"
  ( load_script; remove_setup_section "$d/b" ) || die "the last section was not found"
  printf '%s\n' '# App' '' '## Setup' 'x' '' >"$d/want"
  expect_same "README, last section" "$d/want" "$d/b"
  # No such section: the file is left as it is, and the function says so.
  # S15 (#153 review): only the whole heading line counts, so a heading
  # that only starts the same way (a filled-in description such as
  # "## Finishing the setup: ...", or the bare words) is not the section.
  for t in 'Finishing the setup, run it.' '## Finishing the setup: lends tools' '## Finishing' \
    '## Finishing the setup now' ' ## Finishing the setup' '## Finishing the setup '; do
    printf '%s\n' '# App' '## Setup' "$t" 'more' >"$d/c"
    cp "$d/c" "$d/c0"
    rc=0
    ( load_script; remove_setup_section "$d/c" ) || rc=$?
    [ "$rc" -eq 1 ] || die "no section [$t]: returned $rc, want 1"
    cmp -s "$d/c0" "$d/c" || die "no section [$t]: the file changed"
  done
}

test_a_copy_that_does_not_fit_the_setup_stops_with_the_continue_command() {
  local d c
  built_bootstrapper
  # A file the pack would add is already in the project: a plain stop,
  # nothing laid out, nothing removed.
  d="$(tmpdir)"
  cp -R "$BUILT" "$d/template"
  printf 'x\n' >"$d/template/requirements.txt"
  export STUB_GH_TEMPLATE="$d/template"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -F "What happened: The copy of the project on this computer already has requirements.txt, which the python pack would add. The project octo-user/my-app exists on GitHub, with only the bootstrapper's files in it, and a copy of it is on this computer in ./my-app." >/dev/null \
    || { cat "$d/err" >&2; die "the stop does not name the file and what exists"; }
  sed -n 2p "$d/err" | grep -E '^What to do next: .{10,}' >/dev/null || { cat "$d/err" >&2; die "no next action"; }
  expect_continue_command "$d" " --resume"
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on after the error"
  c="$(copy_of "$d")"
  [ ! -e "$c/pyproject.toml" ] && [ -d "$c/languages/node" ] && [ -f "$c/bootstrap-project.sh" ] || die "something was laid out or removed"
  expect_copy_untouched "$d"
  # A README.md without its setup section: a plain stop, before the copy
  # is changed at all (S15, #152 review: the checks come before the first
  # change, so a stop leaves no half-set-up copy). Only the whole heading
  # line counts (#153 review): here it is cut short.
  d="$(tmpdir)"
  cp -R "$BUILT" "$d/template"
  sed 's/^## Finishing the setup$/## Finishing/' "$BUILT/README.md" >"$d/template/README.md"
  ! cmp -s "$BUILT/README.md" "$d/template/README.md" || die "the heading in the built README is not the one the test expects"
  export STUB_GH_TEMPLATE="$d/template"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -F "What happened: The file README.md in the copy of the project has no section \"## Finishing the setup\", which the setup removes." >/dev/null \
    || { cat "$d/err" >&2; die "the missing section is not explained"; }
  expect_continue_command "$d" " --resume"
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on after the error"
  expect_copy_untouched "$d"
  # #152 review, finding 2: these files come from the project GitHub made
  # from the current bootstrapper, so downloading the script again cannot
  # help: the next action is to report it.
  sed -n 2p "$d/err" | grep -F "Report it to the bootstrapper's maintainers" >/dev/null || { cat "$d/err" >&2; die "README: the next action is not to report it"; }
  ! grep -qF 'Download it again' "$d/err" || { cat "$d/err" >&2; die "README: told to download again"; }
  # A pack file missing from the project's languages/: the same.
  d="$(tmpdir)"
  cp -R "$BUILT" "$d/template"
  rm "$d/template/languages/python/pyproject.toml"
  export STUB_GH_TEMPLATE="$d/template"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -F "What happened: missing from the pack: pyproject.toml" >/dev/null || { cat "$d/err" >&2; die "the missing pack file is not named"; }
  sed -n 2p "$d/err" | grep -F "Report it to the bootstrapper's maintainers" >/dev/null || { cat "$d/err" >&2; die "pack file: the next action is not to report it"; }
  ! grep -qF 'Download it again' "$d/err" || { cat "$d/err" >&2; die "pack file: told to download again"; }
  expect_continue_command "$d" " --resume"
  expect_copy_untouched "$d"
  # S15: the other files the setup changes are checked before the first
  # change too: a CHANGELOG.md without "## Project created", a missing
  # file of the fill table, a missing PolyForm text, a kept pack file
  # that is not there.
  for t in changelog fill polyform kept; do
    d="$(tmpdir)"
    cp -R "$BUILT" "$d/template"
    case "$t" in
      changelog) sed 's/^## Project created$/## Created/' "$BUILT/CHANGELOG.md" >"$d/template/CHANGELOG.md" ;;
      fill) rm "$d/template/docs/BACKLOG.md" ;;
      polyform) rm "$d/template/licenses/PolyForm-Noncommercial-1.0.0.md" ;;
      kept) rm "$d/template/languages/python/code-standards.md" ;;
    esac
    export STUB_GH_TEMPLATE="$d/template"
    if [ "$t" = polyform ]; then
      setup_run "$d" --non-interactive --yes --license polyform-noncommercial-1.0.0
    else
      setup_run "$d" --non-interactive --yes
    fi
    expect_rc 1 "$d"
    sed -n 2p "$d/err" | grep -F "Report it to the bootstrapper's maintainers" >/dev/null || { cat "$d/err" >&2; die "$t: the next action is not to report it"; }
    expect_continue_command "$d" " --resume"
    ! grep -qxF "$FINISHED" "$d/out" || die "$t: it went on after the error"
    expect_copy_untouched "$d"
  done
  unset STUB_GH_TEMPLATE
}

# expect_copy_untouched <dir>: the copy on this computer has none of the
# setup's changes: git sees nothing changed or added, and it has no
# saved change of its own.
expect_copy_untouched() {
  local c
  c="$(copy_of "$1")"
  [ -d "$c" ] || die "there is no copy"
  [ -z "$(in_git -C "$c" status --porcelain --untracked-files=all)" ] || { in_git -C "$c" status >&2; cat "$1/out" >&2; die "the copy was changed before the stop"; }
  [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 1 ] || die "a change was saved in the copy"
}

test_the_awk_helpers_take_a_path_named_like_a_setting() {
  # #152 review, finding 1, second line of defence: even with ./ in front
  # of the folder, the helpers that run awk on a file must read the file
  # itself when its path looks like name=value (here a=b/...), never
  # stdin. stdin holds a line that must not show up anywhere.
  local d
  d="$(tmpdir)"
  mkdir -p "$d/a=b"
  printf '%s\n' '# App' '## Finishing the setup' 'x' '## Setup' 'see x' '### Node (`node` pack)' 'node text' >"$d/a=b/README.md"
  printf '%s\n' 'dist/' >"$d/a=b/gitignore"
  printf '%s\n' 'node_modules/' >"$d/a=b/.gitignore"
  printf '%s\n' 'FROM-STDIN' >"$d/in"
  ( load_script; cd "$d"
    remove_setup_section a=b/README.md
    remove_pack_section a=b/README.md node
    add_missing_lines a=b/gitignore a=b/.gitignore ) <"$d/in" >"$d/out" 2>"$d/err" || { cat "$d/err" >&2; die "a helper failed"; }
  printf '%s\n' '# App' '## Setup' 'see x' >"$d/want"
  expect_same "README" "$d/want" "$d/a=b/README.md"
  printf '%s\n' node_modules/ dist/ >"$d/want"
  expect_same ".gitignore" "$d/want" "$d/a=b/.gitignore"
  ! grep -rqF FROM-STDIN "$d/a=b" || die "a helper read stdin"
}

test_a_folder_named_like_a_setting_or_an_option_gets_the_whole_tree_and_stdin_is_not_read() {
  # #152 review, finding 1 (blocking): with --dir my=app, awk read the
  # operand my=app/README.md as a variable setting and read stdin instead:
  # README.md and DEV_INFRASTRUCTURE.md came out empty, .gitignore held
  # the rest of the layout table, and the rows after it were never laid
  # out, while every step said Done. A folder starting with - reached gh,
  # git and rm as an option. Both must give the full python tree, and
  # --non-interactive must leave stdin unread: the first line is still
  # there after the script ends.
  local d dir
  built_bootstrapper
  for dir in my=app -app; do
    d="$(tmpdir)"
    working_git "$d"
    prepare "$d"
    use_built "$d"
    printf '%s\n' first-line second-line >"$d/in"
    ( in_env "$d"
      rc=0
      "$BASH" "$RUN_SCRIPT" "${REQUIRED_OPTS[@]}" --pack python "${ALL_OPTS[@]}" --public \
        --non-interactive --yes "--dir=$dir" || rc=$?
      echo "$rc" >"$d/rc"
      IFS= read -r line || line="(nothing: stdin was read to its end)"
      printf '%s\n' "$line" >"$d/first"
    ) <"$d/in" >"$d/out" 2>"$d/err"
    [ "$(cat "$d/rc")" -eq 0 ] || { cat "$d/out" "$d/err" >&2; die "$dir: exit $(cat "$d/rc"), want 0"; }
    grep -qxF "$FINISHED" "$d/out" || { cat "$d/err" >&2; die "$dir: did not reach the end"; }
    [ "$(cat "$d/first")" = first-line ] || die "$dir: stdin was read; the next line is: $(cat "$d/first")"
    [ "$(calls_from_create "$d" | grep '^repo clone ')" = "repo clone octo-user/my-app ./$dir" ] || { cat "$d/gh.log" >&2; die "$dir: not copied into ./$dir"; }
    [ "$(ls -A "$d/cwd")" = "$dir" ] || { ls -A "$d/cwd" >&2; die "$dir: the copy is not in the folder named"; }
    expect_setup_tree "$d" "$d/cwd/$dir" python ""
  done
}

test_a_failed_copy_is_explained_with_the_continue_command() {
  local d
  # gh could not make the copy (git's error): plain message, git's text
  # below, the command to continue; nothing else runs.
  d="$(tmpdir)"
  export STUB_GH_CLONE_FAIL=broken
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "The script could not make a copy of the project on this computer, in \./my-app\. The project octo-user/my-app exists on GitHub, with only the bootstrapper's files in it\.\$"
  grep -qxF "    fatal: unable to access 'https://github.com/octo-user/my-app.git/': Could not resolve host: github.com" "$d/err" \
    || { cat "$d/err" >&2; die "git's text is not below"; }
  sed -n 2p "$d/err" | grep -F 'continue the setup with the command shown above' >/dev/null || { cat "$d/err" >&2; die "next action is not to continue"; }
  expect_continue_command "$d" " --resume"
  [ "$(calls_from_create "$d" | tail -1)" = "$CLONE_CALL" ] || { cat "$d/gh.log" >&2; die "gh was used after the failed copy"; }
  [ -z "$(ls -A "$d/cwd")" ] || { ls -A "$d/cwd" >&2; die "something was left on this computer"; }
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on after the error"
  # gh signed out in between: the sign-in next action, to continue.
  d="$(tmpdir)"
  export STUB_GH_CLONE_FAIL=signed-out
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" ".*is not signed in"
  sed -n 2p "$d/err" | grep -F 'continue the setup with the command shown above' >/dev/null || { cat "$d/err" >&2; die "signed out: next action is not to continue"; }
  expect_continue_command "$d" " --resume"
  unset STUB_GH_CLONE_FAIL
}

test_a_copy_from_another_version_or_without_its_stamp_is_refused() {
  local d c
  built_bootstrapper
  # The script is v9.8.8 (and the bootstrapper said so in the checks
  # before), but the project was made from v9.8.7: a newer release came
  # out in between. Refused before anything is changed in the copy.
  d="$(tmpdir)"
  mkdir -p "$d/dl"
  sed "s/^SCRIPT_VERSION='$BUILT_VERSION'\$/SCRIPT_VERSION='v9.8.8'/" "$BUILT/bootstrap-project.sh" >"$d/dl/bootstrap-project.sh"
  grep -qx "SCRIPT_VERSION='v9.8.8'" "$d/dl/bootstrap-project.sh" || die "test setup: the version was not changed"
  sed "s/$BUILT_VERSION/v9.8.8/" "$BUILT/CHANGELOG.md" >"$d/changelog"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "The copy of the project on this computer is from version v9\.8\.7 of the bootstrapper, but this script is version v9\.8\.8\. "
  grep -qF "$BUILT_VERSION, built from" "$d/err" || { cat "$d/err" >&2; die "the stamp is not shown below"; }
  expect_continue_command "$d" " --resume"
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" symbolic-ref --short HEAD)" = main ] || die "the line of work was started"
  [ -z "$(in_git -C "$c" config --local --get user.name)" ] || die "the name was written"
  [ -z "$(in_git -C "$c" status --porcelain)" ] || die "the copy was changed"
  # No CHANGELOG.md, or one without a stamp: not from a bootstrapper.
  for what in missing unstamped; do
    d="$(tmpdir)"
    cp -R "$BUILT" "$d/template"
    if [ "$what" = missing ]; then
      rm "$d/template/CHANGELOG.md"
    else
      printf '# Changelog\n' >"$d/template/CHANGELOG.md"
    fi
    export STUB_GH_TEMPLATE="$d/template"
    setup_run "$d" --non-interactive --yes
    expect_rc 1 "$d"
    expect_err_shape "$d" "The copy of the project on this computer does not say which version of the bootstrapper it came from"
    expect_continue_command "$d" " --resume"
    [ -z "$(in_git -C "$(copy_of "$d")" status --porcelain)" ] || die "$what: the copy was changed"
    unset STUB_GH_TEMPLATE
  done
}

# ---------- filling in the placeholders (spec step 8) ----------
# After the tidy-up, the texts of the spec's fill table are replaced in
# exactly the files the table names (want_fill_rows above, checked file by
# file in expect_setup_tree for every pack).

test_values_with_special_characters_are_copied_literally() {
  # Spec step 8: the replacement is literal (awk index() and substr(),
  # values passed through ENVIRON), so no character of a value is read
  # as part of a pattern or a replacement. The inputs refuse & \ " < > and
  # a backtick (they break JSON and HTML), so this run uses the other
  # characters that sed, awk or bash give a meaning to (. * $ ^ / % [ ]
  # ~ '), spaces and non-ASCII letters, and a dot in the project name,
  # which becomes a - in the slug. The description starts with
  # "## Finishing the setup": the fill runs after the tidy-up, so only the
  # README's real setup section is removed and the description stays.
  local d
  built_bootstrapper
  d="$(tmpdir)"
  fake_tool "$d" npm 10.0.0
  W_DISPLAY="Zoë's Shed *.* \$1 ^a/b\$ ~ [x] 100%s"
  W_PO="Zoë O'Brien \$HOME .* a/b [y]"
  W_DESCRIPTION="## Finishing the setup: lends tools (.*) \$0 a/b ^x\$ to Zoë's street, 100%."
  W_OWNER_AND_NAME=octo-user/Tool.Shed
  W_SLUG=tool-shed
  setup_run "$d" --non-interactive --yes --pack react-native --name Tool.Shed \
    --project-name "$W_DISPLAY" --po-name "$W_PO" --description "$W_DESCRIPTION"
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not reach the end"; }
  expect_setup_tree "$d" "$(copy_of "$d")" react-native
  # The values as typed, where a reader looks for them.
  grep -qxF "# $W_DISPLAY" "$(copy_of "$d")/README.md" || die "README.md: the display name is not the heading"
  grep -qxF "$W_DESCRIPTION" "$(copy_of "$d")/README.md" || die "README.md: the description line is not there"
  grep -qF '"slug": "tool-shed"' "$(copy_of "$d")/app.json" || die "app.json: the slug is not tool-shed"
}

test_the_fill_keeps_cr_lf_with_an_awk_that_drops_the_cr_as_it_reads() {
  # Seen on Git for Windows (S5, first Windows run): the filled CR LF file
  # came out LF, the CR of each line dropped as awk read it. A fake awk
  # that reads that way (CR LF becomes LF, as text-mode input does)
  # stands in for it.
  local d cr=$'\r' nl=$'\n' real_awk
  d="$(tmpdir)"
  real_awk="$(command -v awk)"
  mkdir -p "$d/bin"
  printf '%s\n' "$STAND_IN_SHEBANG" "LC_ALL=C sed 's/\\r\$//' | exec '$real_awk' \"\$@\"" >"$d/bin/awk"
  chmod +x "$d/bin/awk"
  printf '%s' "# [PROJECT NAME]$cr$nl**Owner:** [PO NAME]$cr${nl}last [PROJECT NAME]$cr$nl" >"$d/crlf.md"
  # The fake does drop the CR, so the test would see the bug.
  [ "$(printf 'a\r\n' | PATH="$d/bin:$PATH" awk '{ print length($0) }')" = 1 ] || die "the fake awk keeps the CR"
  ( load_script; cd "$d"; PATH="$d/bin:$PATH"
    IN_PROJECT_NAME='My App' IN_PO_NAME='Ada'
    fill_file crlf.md name po ) >"$d/out" 2>"$d/err" || { cat "$d/err" >&2; die "fill_file failed"; }
  printf '%s' "# My App$cr$nl**Owner:** Ada$cr${nl}last My App$cr$nl" >"$d/want"
  cmp -s "$d/want" "$d/crlf.md" || { od -c "$d/crlf.md" >&2; die "the CR LF line endings were not kept"; }
}

test_the_fill_refuses_a_file_holding_the_byte_it_uses_for_cr() {
  # fill_file passes each CR through awk as the byte 036; a file that
  # already holds that byte would come back with a CR in its place, so
  # it is refused and left as it was.
  local d before
  d="$(tmpdir)"
  printf '# [PROJECT NAME] \036 x\n' >"$d/odd.md"
  before="$(od -c "$d/odd.md")"
  ! ( load_script; cd "$d"; IN_PROJECT_NAME='My App'; fill_file odd.md name ) >"$d/out" 2>"$d/err" \
    || die "a file with the byte 036 was filled"
  [ "$(od -c "$d/odd.md")" = "$before" ] || die "the refused file was changed"
}

test_the_fill_is_literal_in_one_pass_and_keeps_line_endings_and_the_mode() {
  # fill_file <file> <key...>: every text of the keys given is replaced
  # in one pass over the whole file, so:
  #   - a text over two lines (memory/project.md) is found;
  #   - a value that holds another row's text is not filled in again;
  #   - & \ $ . * % in a value are copied as they are;
  #   - CR LF line endings, a missing newline at the end, an empty file
  #     and the executable bit are kept;
  #   - a path named like a setting (a=b/...) is read, never stdin (the
  #     #152 review's finding 1, for the new awk call).
  local d cr=$'\r' nl=$'\n' v p s
  d="$(tmpdir)"
  mkdir -p "$d/a=b"
  printf '%s\n' '# [PROJECT NAME]' '**Owner:** [PO NAME] and [PO NAME]' \
    '**Description:** [What the project is, who it is for, and what problem' 'it solves.]' '[DATE] stays' >"$d/a=b/lf.md"
  printf '%s' "# [PROJECT NAME]$cr$nl**Owner:** [PO NAME]$cr${nl}last [PROJECT NAME]" >"$d/a=b/crlf.sh"
  chmod +x "$d/a=b/crlf.sh"
  : >"$d/a=b/empty.md"
  printf '%s\n' FROM-STDIN >"$d/in"
  v='[PO NAME] & \1 $0 .* a/b %s Zoë'
  p='[PROJECT NAME] \\& ^$'
  s='Lends .* to $HOME/x & y \n'
  ( load_script; cd "$d"
    IN_PROJECT_NAME="$v" IN_PO_NAME="$p" IN_DESCRIPTION="$s"
    fill_file a=b/lf.md name po project-description
    fill_file a=b/crlf.sh name po
    fill_file a=b/empty.md name ) <"$d/in" >"$d/out" 2>"$d/err" || { cat "$d/err" >&2; die "fill_file failed"; }
  printf '%s\n' "# $v" "**Owner:** $p and $p" "**Description:** $s" '[DATE] stays' >"$d/want"
  expect_same "the LF file" "$d/want" "$d/a=b/lf.md"
  printf '%s' "# $v$cr$nl**Owner:** $p$cr${nl}last $v" >"$d/want"
  cmp -s "$d/want" "$d/a=b/crlf.sh" || { od -c "$d/a=b/crlf.sh" >&2; die "the CR LF file without a newline at the end changed otherwise"; }
  # Where chmod cannot make a file without #! runnable (Git for Windows,
  # whose bash decides that from the file's start, not a mode bit), the
  # mode cannot be seen, and this part is skipped.
  printf 'x\n' >"$d/probe"; chmod 755 "$d/probe"
  if [ -x "$d/probe" ]; then
    [ -x "$d/a=b/crlf.sh" ] || die "the executable bit was lost"
  else
    echo "chmod does not set the mode of a file here; the executable bit was not checked"
  fi
  [ ! -s "$d/a=b/empty.md" ] || die "the empty file is no longer empty"
  ! grep -rqF FROM-STDIN "$d/a=b" "$d/out" || die "fill_file read stdin"
}

test_a_file_to_fill_that_is_missing_stops_before_any_file_is_filled() {
  # A file of the fill table that the project lacks: the project came from
  # the current bootstrapper, so the next action is to report it, and
  # every file is checked before the first one is changed.
  local d c
  built_bootstrapper
  d="$(tmpdir)"
  cp -R "$BUILT" "$d/template"
  rm "$d/template/docs/NEXT_SESSION.md"
  export STUB_GH_TEMPLATE="$d/template"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -F "What happened: The copy of the project on this computer has no docs/NEXT_SESSION.md, in which the setup fills in the project's name and other details. The project octo-user/my-app exists on GitHub, with only the bootstrapper's files in it, and a copy of it is on this computer in ./my-app." >/dev/null \
    || { cat "$d/err" >&2; die "the missing file is not named with what exists"; }
  sed -n 2p "$d/err" | grep -F "Report it to the bootstrapper's maintainers" >/dev/null || { cat "$d/err" >&2; die "the next action is not to report it"; }
  expect_continue_command "$d" " --resume"
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on after the error"
  c="$(copy_of "$d")"
  [ "$(sed -n 1p "$c/README.md")" = '# [PROJECT NAME]' ] || die "README.md was filled in before the stop"
  grep -qF '[PROJECT NAME]' "$c/memory/project.md" || die "memory/project.md was filled in before the stop"
  [ ! -e "$c/docs/NEXT_SESSION.md" ] || die "the missing file was made"
  unset STUB_GH_TEMPLATE
}

test_the_placeholders_left_for_clead_are_listed_in_plain_words() {
  # Spec step 8: "Left for the first Clead session (the script lists them
  # at the end)". The end report is a later step; the list is ready for
  # it. That these texts are left as they are is checked for every pack
  # in expect_setup_tree.
  local d t
  d="$(tmpdir)"
  ( load_script; say_left_for_clead ) >"$d/out" 2>"$d/err" || { cat "$d/err" >&2; die "say_left_for_clead failed"; }
  for t in 'left for your first session with Clead' '[PHASE NAME]' docs/BACKLOG.md '[Goal]' \
    memory/project.md docs/SPEC.md memory/context.md STATUS.md; do
    grep -qF -- "$t" "$d/out" || { cat "$d/out" >&2; die "the list does not name $t"; }
  done
  [ ! -s "$d/err" ] || { cat "$d/err" >&2; die "it wrote to stderr"; }
  [ -z "$(banned_hits <"$d/out")" ] || { cat "$d/out" >&2; die "a banned word in the list"; }
}

# ---------- lockfile, licence and CHANGELOG (spec steps 7, 10, 11) ----------
# After the fill: for the npm packs, npm records the exact versions of the
# tools in package-lock.json (step 7, run after the fill so the lockfile
# names the project, not [project-name]); then the licence (step 10): a
# GitHub licence's text with [year] and [fullname] filled in, PolyForm
# Noncommercial from licenses/ with a NOTICE, or no file for none (with a
# warning when the project is public); then CHANGELOG.md gets the pack,
# the licence and "set up by bootstrap-project.sh" at the end of its
# "## Project created" section (step 11). npm is the stub npm
# (BOOTSTRAP_NPM), so no test reaches the npm registry.

test_the_npm_packs_get_a_lockfile_made_by_npm_after_the_fill() {
  local d c p
  built_bootstrapper
  for p in node web react-native; do
    d="$(tmpdir)"
    fake_tool "$d" npm 10.0.0
    # A line waits on the script's stdin: npm must not get it (the stub
    # npm reads a line when it can; #154 review, finding 3).
    printf '%s\n' 'an-answer-for-the-script' >"$d/in"
    setup_run "$d" --non-interactive --yes --pack "$p"
    expect_rc 0 "$d"
    grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "$p: did not reach the end"; }
    [ ! -e "$d/npm-stdin" ] || { cat "$d/npm-stdin" >&2; die "$p: npm read the script's stdin"; }
    c="$(copy_of "$d")"
    # One call, in the copy, with the spec's command (the same as packs.yml).
    printf '%s\tinstall\t--package-lock-only\t--no-audit\t--no-fund\n' "$(cd "$c" && pwd)" >"$d/want-npm"
    expect_same "$p: the npm calls" "$d/want-npm" "$d/npm.log"
    # After the fill: the lockfile names the project.
    grep -qF "\"name\": \"$W_SLUG\"" "$c/package-lock.json" || die "$p: the lockfile does not name the project"
    ! grep -qF '[project-name]' "$c/package-lock.json" || die "$p: the lockfile was made before the fill"
    # Its own step, between the fill and the licence, with a done line.
    grep '^==> ' "$d/out" | sed -n '/^==> Filling in/,$p' >"$d/steps"
    [ "$(sed -n 2p "$d/steps")" = "==> Recording the exact versions of the $p pack's tools in package-lock.json" ] \
      || { cat "$d/out" >&2; die "$p: the lockfile step does not come right after the fill"; }
    [ "$(sed -n 3p "$d/steps")" = "==> Adding the project's licence" ] || { cat "$d/out" >&2; die "$p: the licence does not follow the lockfile"; }
    expect_out "$d" "    Done. package-lock.json lists the exact version of every tool the project uses, so its checks on GitHub install the same ones."
    # npm's own text is not shown when it works.
    expect_no_out "$d" "up to date"
  done
  # A folder whose name starts with -: npm still runs in it (cd would
  # read -app as an option; check_dir makes it ./-app).
  d="$(tmpdir)"
  fake_tool "$d" npm 10.0.0
  setup_run "$d" --non-interactive --yes --pack node --dir=-app
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "-app: did not reach the end"; }
  printf '%s\tinstall\t--package-lock-only\t--no-audit\t--no-fund\n' "$(cd "$d/cwd/-app" && pwd)" >"$d/want-npm"
  expect_same "-app: the npm calls" "$d/want-npm" "$d/npm.log"
  [ -f "$d/cwd/-app/package-lock.json" ] || die "-app: no lockfile"
  # python: no npm call, no lockfile.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  [ ! -s "$d/npm.log" ] || { cat "$d/npm.log" >&2; die "python: npm ran"; }
  [ ! -e "$(copy_of "$d")/package-lock.json" ] || die "python: a lockfile was made"
}

test_a_failed_npm_is_explained_with_its_text_for_support() {
  # Spec, Ease-of-use: errors say what happened and the next action, the
  # raw text below for support. No network: check the connection; any
  # other npm error: the plain fallback. Either way the project exists,
  # so the command shown continues the setup, and nothing after the
  # lockfile runs.
  local d c mode
  built_bootstrapper
  for mode in offline notarget; do
    d="$(tmpdir)"
    fake_tool "$d" npm 10.0.0
    export STUB_NPM_FAIL="$mode"
    setup_run "$d" --non-interactive --yes --pack node
    unset STUB_NPM_FAIL
    expect_rc 1 "$d"
    sed -n 1p "$d/err" | grep -F "What happened: npm could not record the exact versions of the node pack's tools in package-lock.json. The project octo-user/my-app exists on GitHub, with only the bootstrapper's files in it" >/dev/null \
      || { cat "$d/err" >&2; die "$mode: the first line does not say what happened"; }
    case "$mode" in
      offline) sed -n 2p "$d/err" | grep -F "What to do next: Check that this computer is connected to the internet, then continue the setup with the command shown above." >/dev/null \
        || { cat "$d/err" >&2; die "offline: the next action is not to check the connection"; } ;;
      notarget) sed -n 2p "$d/err" | grep -F "What to do next: Continue the setup with the command shown above. If the same thing happens, ask for help and show the details below." >/dev/null \
        || { cat "$d/err" >&2; die "notarget: the next action is not the plain fallback"; } ;;
    esac
    sed -n 3p "$d/err" | grep -xF 'Details for support (you can ignore these):' >/dev/null || { cat "$d/err" >&2; die "$mode: no support block"; }
    grep -qxF "    npm error code $( [ "$mode" = offline ] && echo ENOTFOUND || echo ETARGET)" "$d/err" \
      || { cat "$d/err" >&2; die "$mode: npm's own text is not below for support"; }
    expect_continue_command "$d" " --resume"
    ! grep -qxF "$FINISHED" "$d/out" || die "$mode: it went on after npm failed"
    c="$(copy_of "$d")"
    [ ! -e "$c/package-lock.json" ] && [ ! -e "$c/LICENSE" ] || die "$mode: it went on after npm failed"
    ! grep -qF 'Set up by bootstrap-project.sh' "$c/CHANGELOG.md" || die "$mode: CHANGELOG.md was changed"
  done
}

test_a_github_licence_gets_the_year_and_the_holder_filled_in() {
  # Spec step 10: gh api licenses/<key> --jq .body goes to LICENSE, with
  # [year] and [fullname] filled in, literally (S11's fill), LF line
  # endings even when gh's text has carriage returns (Windows). A
  # licence without those two (Apache 2.0) is written as GitHub has it.
  local d c
  built_bootstrapper
  d="$(tmpdir)"
  W_HOLDER="Zoë O'Brien \$1 [x] .* 100%s"
  export STUB_GH_CR=$'\r'
  setup_run "$d" --non-interactive --yes --copyright-holder "$W_HOLDER"
  unset STUB_GH_CR
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not reach the end"; }
  # The preflight's check of the name, then the text read once at step
  # 10, both with gh's prompts off.
  [ "$(grep -F "$(printf '\tlicenses/')" "$d/gh.log")" = "$(printf 'GH_PROMPT_DISABLED=1\tapi\t-i\tlicenses/mit\t--jq\t.key\nGH_PROMPT_DISABLED=1\tapi\t-i\tlicenses/mit\t--jq\t.body')" ] \
    || { cat "$d/gh.log" >&2; die "the licence was not checked, then read once, with gh's prompts off"; }
  c="$(copy_of "$d")"
  expect_setup_tree "$d" "$c" python
  [ ! -e "$c/NOTICE" ] || die "a NOTICE was made for mit"
  expect_out "$d" "    Done. LICENSE holds the licence mit, in the name of $W_HOLDER."
  d="$(tmpdir)"
  W_LICENSE=apache-2.0 W_HOLDER="Ada L"
  setup_run "$d" --non-interactive --yes --license apache-2.0
  expect_rc 0 "$d"
  expect_setup_tree "$d" "$(copy_of "$d")" python
  grep -qF 'Copyright [yyyy] [name of copyright owner]' "$(copy_of "$d")/LICENSE" || die "apache-2.0: its own placeholders changed"
}

test_polyform_noncommercial_is_copied_from_licenses_with_a_notice() {
  # Spec step 10: the text is copied from licenses/ to LICENSE, and a root
  # NOTICE gets "Required Notice: Copyright <holder>". GitHub is not asked.
  local d c
  built_bootstrapper
  d="$(tmpdir)"
  W_LICENSE=polyform-noncommercial-1.0.0
  setup_run "$d" --non-interactive --yes --license polyform-noncommercial-1.0.0
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not reach the end"; }
  ! grep -qF 'licenses/' "$d/gh.log" || { cat "$d/gh.log" >&2; die "GitHub was asked for the PolyForm text"; }
  c="$(copy_of "$d")"
  expect_setup_tree "$d" "$c" python
  cmp -s "$BUILT/licenses/NOTICE" "$c/licenses/NOTICE" || die "the template's own licenses/NOTICE changed"
  expect_out "$d" "    Done. LICENSE holds the PolyForm Noncommercial licence, and NOTICE names Ada L as the copyright holder."
}

test_no_licence_adds_no_file_and_warns_only_for_a_public_project() {
  # Spec step 10: none: no file, with a warning if the project is public.
  local d vis warning="$NO_LICENCE_WARNING"
  built_bootstrapper
  W_LICENSE=none
  for vis in --public --private; do
    d="$(tmpdir)"
    setup_run "$d" --non-interactive --yes --license none $vis
    expect_rc 0 "$d"
    grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "$vis: did not reach the end"; }
    expect_setup_tree "$d" "$(copy_of "$d")" python
    ! grep -qF 'licenses/' "$d/gh.log" || die "$vis: GitHub was asked for a licence"
    expect_out "$d" "    Done. No licence file was added, because you chose none."
    if [ "$vis" = --public ]; then
      grep -qxF "$warning" "$d/out" || { cat "$d/out" >&2; die "public: no warning"; }
    else
      expect_no_out "$d" "Warning: the project is public"
    fi
  done
}

test_a_licence_github_does_not_know_is_explained_with_the_next_action() {
  # Spec, Ease-of-use: an unknown key (GitHub's 404) says what happened
  # and where to find the right name; any other answer gets the usual
  # plain message. The project exists, so the command shown continues
  # the setup; no LICENSE is written and CHANGELOG.md is not changed.
  # The preflight checks the name before anything is created, so here
  # GitHub knew it then (STUB_GH_LICENSE_KNOWN) and has no text for it
  # at step 10: this step keeps its own handling, as a second line of
  # defence.
  local d c
  built_bootstrapper
  d="$(tmpdir)"
  export STUB_GH_LICENSE_KNOWN=made-up-2.0
  setup_run "$d" --non-interactive --yes --license made-up-2.0
  unset STUB_GH_LICENSE_KNOWN
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -F "What happened: GitHub has no licence with the short name made-up-2.0, so the script could not add it. The project octo-user/my-app exists on GitHub" >/dev/null \
    || { cat "$d/err" >&2; die "the unknown licence is not named"; }
  sed -n 2p "$d/err" | grep -F "https://choosealicense.com/licenses/" >/dev/null || { cat "$d/err" >&2; die "the next action does not say where to find the name"; }
  grep -qxF '    HTTP 404: Not Found' "$d/err" || { cat "$d/err" >&2; die "GitHub's answer is not below for support"; }
  expect_continue_command "$d" " --resume"
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on after the 404"
  c="$(copy_of "$d")"
  [ ! -e "$c/LICENSE" ] || die "a LICENSE was written"
  ! grep -qF 'Set up by bootstrap-project.sh' "$c/CHANGELOG.md" || die "CHANGELOG.md was changed"
  # S15: the licence text is read before the copy is changed at all, so
  # --resume can continue with another --license in the same copy.
  expect_copy_untouched "$d"
  d="$(tmpdir)"
  export STUB_GH_LICENSE_FAIL=server
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_LICENSE_FAIL
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -F "What happened: GitHub had a problem of its own, so the script could not read the text of the licence mit." >/dev/null \
    || { cat "$d/err" >&2; die "a server error is not explained"; }
  expect_continue_command "$d" " --resume"
  [ ! -e "$(copy_of "$d")/LICENSE" ] || die "a LICENSE was written after a server error"
}

test_the_plan_says_whether_a_licence_is_added() {
  # #150 review, finding 8: with --license none the plan's step 4 said
  # "add the licence". It says what will happen.
  local d
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --dry-run
  expect_rc 0 "$d"
  grep -qxF "  4. Add the language pack's files, fill in the project's names and description, and add the licence mit." "$d/out" \
    || { cat "$d/out" >&2; die "mit: step 4 does not name the licence"; }
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --dry-run --license none
  expect_rc 0 "$d"
  grep -qxF "  4. Add the language pack's files and fill in the project's names and description; no licence file is added, because you chose none." "$d/out" \
    || { cat "$d/out" >&2; die "none: step 4 does not say that no licence is added"; }
  expect_no_out "$d" "add the licence"
  # S18b: a public project with no licence gets step 10's warning in the
  # plan too, word for word; a private one does not.
  grep -qxF "$NO_LICENCE_WARNING" "$d/out" || { cat "$d/out" >&2; die "public, none: the plan does not warn"; }
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --dry-run --license none --private
  expect_rc 0 "$d"
  grep -qF "no licence file is added, because you chose none." "$d/out" || { cat "$d/out" >&2; die "private, none: no plan shown"; }
  expect_no_out "$d" "Warning: the project is public"
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --dry-run
  expect_rc 0 "$d"
  expect_no_out "$d" "Warning: the project is public"
}

test_the_changelog_lines_go_at_the_end_of_project_created() {
  # Spec step 11, "under Project created": after the section's last line,
  # before the blank lines and the next heading when one follows; a
  # CHANGELOG.md without the heading stops before changing it.
  local d
  d="$(tmpdir)"
  mkdir -p "$d/copy"
  printf '%s\n' '# Changelog' '' '## Project created' '' '- Bootstrapped from' '  v1, built.' '' '' '## Later' '' '- other' >"$d/copy/CHANGELOG.md"
  ( load_script; IN_DIR="$d/copy" IN_PACK=web IN_WITH_DEPLOY=yes IN_LICENSE=gpl-3.0
    note_setup_in_changelog ) >"$d/out" 2>"$d/err" || { cat "$d/err" >&2; die "note_setup_in_changelog failed"; }
  printf '%s\n' '# Changelog' '' '## Project created' '' '- Bootstrapped from' '  v1, built.' \
    '- Language pack: web, with the files that publish the website.' '- Licence: gpl-3.0.' '- Set up by bootstrap-project.sh.' \
    '' '' '## Later' '' '- other' >"$d/want"
  expect_same "CHANGELOG.md with a later section" "$d/want" "$d/copy/CHANGELOG.md"
  printf '%s\n' '# Changelog' '' '## Unreleased' >"$d/copy/CHANGELOG.md"
  cp "$d/copy/CHANGELOG.md" "$d/before"
  set +e
  ( load_script; IN_DIR="$d/copy" IN_PACK=node IN_WITH_DEPLOY="" IN_LICENSE=mit CREATED_NOTE=x RESTART_CMD=x
    note_setup_in_changelog ) >"$d/out" 2>"$d/err"
  RC=$?
  set -e
  [ "$RC" -eq 1 ] || { cat "$d/out" "$d/err" >&2; die "no heading: exit $RC, want 1"; }
  sed -n 1p "$d/err" | grep -F 'has no section "## Project created"' >/dev/null || { cat "$d/err" >&2; die "no heading: not explained"; }
  sed -n 2p "$d/err" | grep -F "Report it to the bootstrapper's maintainers" >/dev/null || { cat "$d/err" >&2; die "no heading: the next action is not to report it"; }
  expect_same "CHANGELOG.md without the heading" "$d/before" "$d/copy/CHANGELOG.md"
}

test_the_harness_fill_copies_an_ampersand_literally() {
  # #153 review, finding 4: filled_as replaced with an unquoted value, so
  # under bash 5.2's patsub_replacement an & in a W_* value became the
  # text it replaced. The inputs refuse &, so only the harness can meet
  # one; this pins the quoting.
  local d
  d="$(tmpdir)"
  : >"$d/applied"
  printf '%s\n' 'x [PROJECT NAME] y' '[PO NAME]' '[One or two sentences: what this project is and who it is for.]' >"$d/src"
  W_DISPLAY='A & B' W_PO='\& && \\&' W_DESCRIPTION='&'
  filled_as "$d" node "" README.md "$d/src" "$d/got"
  printf '%s\n' 'x A & B y' '\& && \\&' '&' >"$d/want"
  expect_same "an & in the values" "$d/want" "$d/got"
}

test_an_empty_licence_text_or_a_missing_polyform_text_stops_with_the_continue_command() {
  # #154 review, finding 2: two error paths of step 10 had no test.
  # GitHub answering 200 with an empty text, and a copy without
  # licenses/PolyForm-Noncommercial-1.0.0.md: each stops plainly, writes
  # no LICENSE, leaves CHANGELOG.md alone and saves nothing.
  local d c
  built_bootstrapper
  d="$(tmpdir)"
  export STUB_GH_LICENSE_FAIL=empty
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_LICENSE_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub sent an empty text for the licence mit, so the script could not add it\. The project octo-user/my-app exists on GitHub"
  grep -qxF '    HTTP 200 with an empty body for licenses/mit' "$d/err" || { cat "$d/err" >&2; die "empty: what GitHub sent is not below"; }
  expect_continue_command "$d" " --resume"
  ! grep -qxF "$FINISHED" "$d/out" || die "empty: it went on"
  c="$(copy_of "$d")"
  [ ! -e "$c/LICENSE" ] || die "empty: a LICENSE was written"
  ! grep -qF 'Set up by bootstrap-project.sh' "$c/CHANGELOG.md" || die "empty: CHANGELOG.md was changed"
  [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 1 ] || die "empty: a change was saved"
  d="$(tmpdir)"
  cp -R "$BUILT" "$d/template"
  rm "$d/template/licenses/PolyForm-Noncommercial-1.0.0.md"
  export STUB_GH_TEMPLATE="$d/template"
  setup_run "$d" --non-interactive --yes --license polyform-noncommercial-1.0.0
  unset STUB_GH_TEMPLATE
  expect_rc 1 "$d"
  expect_err_shape "$d" "The copy of the project on this computer has no licenses/PolyForm-Noncommercial-1\.0\.0\.md, the text of the PolyForm Noncommercial licence\."
  sed -n 2p "$d/err" | grep -F "Report it to the bootstrapper's maintainers" >/dev/null || { cat "$d/err" >&2; die "PolyForm: the next action is not to report it"; }
  expect_continue_command "$d" " --resume"
  c="$(copy_of "$d")"
  [ ! -e "$c/LICENSE" ] && [ ! -e "$c/NOTICE" ] || die "PolyForm: a LICENSE or NOTICE was written"
  ! grep -qF 'Set up by bootstrap-project.sh' "$c/CHANGELOG.md" || die "PolyForm: CHANGELOG.md was changed"
}

# ---------- self-check, save, send and propose (spec steps 12, 13, 14) ----------
# After the CHANGELOG entry, the self-check (step 12): no text of the fill
# table is left in its file, unless it is part of a value the user gave;
# git status shows only the paths the setup changes; the changes hold no
# GitHub key (gh[pousr]_..., github_pat_...); every file has LF line
# endings. Any of these stops before anything is saved. Then step 13: the
# git name and email are checked, the change "Set up <name>" is saved and
# sent on bootstrap-setup, with gh lent to git as its sign-in helper for
# that one command (-c, no settings changed); if git cannot sign in, a
# guide offers gh auth setup-git, which changes the global git settings,
# so it runs only after a yes typed at the terminal. The copy is made the
# same way. Then step 14: gh pr create, with its title and body given.
# Steps 15 to 19 follow (see "wait, require, add, finish and report").

test_git_borrows_the_gh_sign_in_for_one_command_and_no_settings_change() {
  # The two -c settings are those gh auth setup-git writes into the
  # global settings (gh 2.89.0, run once into a throwaway settings file):
  # an empty helper for https://github.com, which drops the helpers set
  # before it, then gh's own. Here: the push passes exactly those, with
  # the gh the script runs (a path with spaces, quoted for the shell git
  # runs the helper with), and git may not ask at the terminal; the copy
  # is made with git not asking either; no git settings change.
  local d c want
  d="$(tmpdir)"
  prepare "$d"
  cp "$d/home/.gitconfig" "$d/global-before"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/err" >&2; die "did not reach the end"; }
  c="$(copy_of "$d")"
  want="git -c credential.https://github.com.helper= -c credential.https://github.com.helper=!'$d/gh' auth git-credential -C ./my-app push origin bootstrap-setup"
  [ "$(grep -F ' push ' "$d/tools.log")" = "$want" ] || { grep -F ' push ' "$d/tools.log" >&2 || true; die "the push is not: $want"; }
  [ "$(cat "$d/clone-prompt")" = 0 ] || { cat "$d/clone-prompt" >&2 || true; die "the copy was made with git allowed to ask at the terminal"; }
  cmp -s "$d/global-before" "$d/home/.gitconfig" || { cat "$d/home/.gitconfig" >&2; die "the global git settings changed"; }
  ! grep -qi credential "$c/.git/config" || { cat "$c/.git/config" >&2; die "a sign-in helper was written into the copy's settings"; }
  ! grep -E ' config ' "$d/tools.log" | grep -v -- ' --get' | grep -E 'credential|--global|--system' >/dev/null \
    || { cat "$d/tools.log" >&2; die "git settings were written"; }
  # The helper string works: git asks the stub gh through it (path with
  # spaces and all), and a helper from the global settings is never asked.
  d="$(tmpdir)"
  prepare "$d"
  "$REAL_GIT" config --file "$d/home/.gitconfig" credential.helper "!f() { touch '$d/global-helper-ran'; }; f"
  printf '%s\n' protocol=https host=github.com path=octo-user/my-app.git '' >"$d/ask"
  ( load_script; in_env "$d"; with_gh_sign_in "$d/out" "$d/err" credential fill ) <"$d/ask" \
    || { cat "$d/err" >&2; die "git credential fill failed"; }
  grep -qxF username=stub-user "$d/out" && grep -qxF password=stub-password "$d/out" || { cat "$d/out" "$d/err" >&2; die "git did not get the sign-in from gh"; }
  [ "$(cut -f2- "$d/gh.log")" = "$(printf 'auth\tgit-credential\tget')" ] || { cat "$d/gh.log" >&2; die "gh was not asked as git's helper"; }
  [ ! -e "$d/global-helper-ran" ] || die "the helper from the global settings was asked too"
}

test_a_push_git_cannot_sign_in_for_offers_gh_auth_setup_git_after_saying_what_it_changes() {
  # Spec step 13's fallback: gh auth setup-git changes the global git
  # settings, so the guide says so in a sentence, and the command runs
  # only after a yes typed at the terminal (never --yes, never stdin).
  local d c
  # --non-interactive: the guide, then a stop with the command to
  # continue (exit 3); the change is saved but not sent; nothing ran.
  d="$(tmpdir)"
  working_git "$d"
  failing_push "$d" auth
  setup_run "$d" --non-interactive --yes
  expect_rc 3 "$d"
  expect_out "$d" "git could not sign in to GitHub to send the setup's changes."
  expect_out "$d" "Why this is needed: "
  grep -qxF '    gh auth setup-git' "$d/out" || { cat "$d/out" >&2; die "the command is not shown to copy"; }
  grep -qF 'changes your global git settings' "$d/out" || { cat "$d/out" >&2; die "the guide does not say that it changes the global git settings"; }
  expect_out "$d" "How the script checks it: "
  grep -qxF "    fatal: could not read Username for 'https://github.com': terminal prompts disabled" "$d/out" \
    || { cat "$d/out" >&2; die "git's text is not below the guide"; }
  expect_continue_command "$d" " --resume"
  grep -qF 'the setup'"'"'s changes are saved in its copy on this computer' "$d/err" || { cat "$d/err" >&2; die "the stop does not say the changes are saved"; }
  expect_nothing_ran "$d"
  [ "$(cat "$d/push-prompt")" = 0 ] || die "git was allowed to ask at the terminal"
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 2 ] || die "the change was not saved"
  ! in_git --git-dir="$(bare_of "$d")" rev-parse -q --verify refs/heads/bootstrap-setup >/dev/null || die "the change was sent"
  ! calls_from_create "$d" | grep '^pr ' >/dev/null || die "a change was proposed"
  # Asked, with yes typed at the terminal: the command runs (through the
  # runner), then git sends again with its own settings, which now hold
  # gh's helper, so without -c; the run goes on to the end.
  d="$(tmpdir)"
  working_git "$d"
  failing_push "$d" auth 1
  printf 'yes\n' >"$d/tty"
  setup_run "$d" --yes
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "yes: did not reach the end"; }
  [ "$(cat "$d/run.log")" = "gh auth setup-git" ] || { cat "$d/run.log" >&2; die "yes: gh auth setup-git did not run"; }
  [ "$(grep -F ' push ' "$d/tools.log" | sed -n 2p)" = "git -C ./my-app push origin bootstrap-setup" ] \
    || { grep -F ' push ' "$d/tools.log" >&2 || true; die "yes: the second push is not a plain one"; }
  grep -qF 'changes your global git settings' "$d/out" || die "yes: the guide does not say what the command changes"
  [ "$(cat "$d/push-prompt")" = "$(printf '0\n0')" ] || { cat "$d/push-prompt" >&2; die "yes: a push was allowed to ask at the terminal"; }
  calls_from_create "$d" | grep -xF "$PR_CALL" >/dev/null || { cat "$d/gh.log" >&2; die "yes: no proposed change"; }
  # --yes and no answer at the terminal: nothing runs; Enter on stdin
  # checks again, and the user's own fix works.
  d="$(tmpdir)"
  working_git "$d"
  failing_push "$d" auth 1
  printf '\n' >"$d/in"
  setup_run "$d" --yes
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "Enter: did not reach the end"; }
  expect_nothing_ran "$d"
  expect_out "$d" "Not run. To run it yourself, open another "
}

test_other_push_failures_are_explained_with_the_continue_command() {
  # Not a sign-in problem: no guide, a plain stop with git's text below.
  # GitHub out of reach: check the connection. A workflow file refused
  # for want of the workflow permission: the refresh command. Anything
  # else: the plain fallback. The change stays saved; nothing is proposed.
  local d mode
  for mode in offline workflow other; do
    d="$(tmpdir)"
    working_git "$d"
    failing_push "$d" "$mode"
    setup_run "$d" --non-interactive --yes
    expect_rc 1 "$d"
    case "$mode" in
      offline)
        expect_err_shape "$d" "git could not send the setup's changes to GitHub\. "
        sed -n 2p "$d/err" | grep -F 'Check that this computer is connected to the internet, then continue the setup with the command shown above.' >/dev/null \
          || { cat "$d/err" >&2; die "offline: the next action is not to check the connection"; }
        ;;
      workflow)
        expect_err_shape "$d" "GitHub refused the setup's changes, because the sign-in that gh lends to git may not change the project's workflow files"
        sed -n 2p "$d/err" | grep -F 'gh auth refresh -h github.com -s workflow' >/dev/null || { cat "$d/err" >&2; die "workflow: the refresh command is not given"; }
        # r1b: the refresh asks gh's question; the answer comes with it.
        sed -n 2p "$d/err" | grep -F 'gh auth refresh -h github.com -s workflow (if gh asks "Authenticate Git with your GitHub credentials?", answer Yes), then continue the setup' >/dev/null \
          || { cat "$d/err" >&2; die "workflow: the next action does not say what to answer when gh asks to authenticate Git"; }
        ;;
      other)
        expect_err_shape "$d" "git could not send the setup's changes to GitHub\. "
        sed -n 2p "$d/err" | grep -F 'If the same thing happens, ask for help and show the details below.' >/dev/null || { cat "$d/err" >&2; die "other: not the plain fallback"; }
        ;;
    esac
    ! grep -qF 'Why this is needed: ' "$d/out" || { cat "$d/out" >&2; die "$mode: a guide was shown"; }
    expect_continue_command "$d" " --resume"
    ! calls_from_create "$d" | grep '^pr ' >/dev/null || die "$mode: a change was proposed"
    [ "$(in_git -C "$(copy_of "$d")" rev-list --count HEAD)" -eq 2 ] || die "$mode: the change is not saved"
    expect_nothing_ran "$d"
  done
}

test_a_copy_git_cannot_sign_in_for_gets_the_same_guide() {
  # Spec step 4: the sign-in fallback also covers the copy (gh repo
  # clone). --non-interactive: the guide and a stop to continue, nothing
  # left on this computer. A yes at the terminal: gh auth setup-git runs,
  # the copy is made again and the run goes on.
  local d
  d="$(tmpdir)"
  export STUB_GH_CLONE_FAIL=auth
  setup_run "$d" --non-interactive --yes
  expect_rc 3 "$d"
  expect_out "$d" "git could not sign in to GitHub to make the copy of the project on this computer."
  grep -qxF '    gh auth setup-git' "$d/out" || { cat "$d/out" >&2; die "the command is not shown to copy"; }
  grep -qF 'changes your global git settings' "$d/out" || { cat "$d/out" >&2; die "the guide does not say what the command changes"; }
  expect_continue_command "$d" " --resume"
  expect_nothing_ran "$d"
  [ -z "$(ls -A "$d/cwd")" ] || { ls -A "$d/cwd" >&2; die "something was left on this computer"; }
  d="$(tmpdir)"
  echo 1 >"$d/clone-fails"
  printf 'yes\n' >"$d/tty"
  setup_run "$d" --yes
  unset STUB_GH_CLONE_FAIL
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "yes: did not reach the end"; }
  [ "$(cat "$d/run.log")" = "gh auth setup-git" ] || { cat "$d/run.log" >&2; die "yes: gh auth setup-git did not run"; }
  [ "$(calls_from_create "$d" | grep -c '^repo clone ')" -eq 2 ] || { cat "$d/gh.log" >&2; die "yes: the copy was not made again"; }
}

test_the_git_name_and_email_are_checked_before_the_change_is_saved() {
  # Spec step 13: the identity is checked before the commit. A setting
  # that overrides the copy's own (here GIT_AUTHOR_EMAIL in the
  # environment) stops before anything is saved.
  local d c
  d="$(tmpdir)"
  export GIT_AUTHOR_EMAIL=other@example.com
  setup_run "$d" --non-interactive --yes
  unset GIT_AUTHOR_EMAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "git would save the setup's changes under Test Person <other@example\.com>, not under the name and email you gave, Test Person <test@example\.com>\."
  grep -qF 'GIT_AUTHOR_EMAIL' "$d/err" || { cat "$d/err" >&2; die "the next action does not name the settings that override"; }
  expect_continue_command "$d" " --resume"
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 1 ] || die "a change was saved"
  ! grep -qF ' push ' "$d/tools.log" || die "something was sent"
  # S15 (#155 review): git's global settings author.* and committer.*
  # override the copy's user.* too; the next action names them.
  for k in author.email committer.name; do
    d="$(tmpdir)"
    prepare "$d"
    "$REAL_GIT" config --file "$d/home/.gitconfig" "$k" other
    setup_run "$d" --non-interactive --yes
    expect_rc 1 "$d"
    expect_err_shape "$d" "git would save the setup's changes under .*, not under the name and email you gave"
    sed -n 2p "$d/err" | grep -F 'author.name, author.email, committer.name or committer.email' >/dev/null \
      || { cat "$d/err" >&2; die "$k: the next action does not name the global settings that override"; }
    sed -n 2p "$d/err" | grep -F 'GIT_AUTHOR_EMAIL' >/dev/null || { cat "$d/err" >&2; die "$k: the next action no longer names the terminal's settings"; }
    [ "$(in_git -C "$(copy_of "$d")" rev-list --count HEAD)" -eq 1 ] || die "$k: a change was saved"
  done
  # git drops , : ; ' and spaces at the ends of a name or email; the
  # check knows that, so such a name passes and is saved as git has it.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes --git-name "O'Neil, Ada:"
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "a name ending in : did not pass"; }
  [ "$(in_git -C "$(copy_of "$d")" log -1 --format=%an)" = "O'Neil, Ada" ] || die "the name was not saved as git has it"
}

test_a_text_left_to_fill_in_stops_the_self_check_but_a_value_holding_one_does_not() {
  # Spec step 12, per (file, text) pair of the fill table. A value may
  # hold a text of the table (S11: a display name "[PO NAME] App"): that
  # is not a text left. A text outside the values is, and stops.
  local d f k
  d="$(tmpdir)"
  mkdir -p "$d/copy/docs" "$d/copy/memory"
  ( load_script
    IN_DIR="$d/copy" IN_PACK=python IN_WITH_DEPLOY="" IN_OWNER=octo-user IN_NAME=my-app IN_SLUG=my-app
    IN_PROJECT_NAME="[PO NAME] App" IN_PO_NAME="[PROJECT NAME] Ltd" IN_DESCRIPTION="Tracks [DATE] and [OWNER/REPO] tags."
    FILL_DATE=2031-02-03 CREATED_NOTE="The project exists." RESTART_CMD=x
    fill_rows python ""
    # Each file of the table holds every text of its rows, then is filled.
    while read -r f k; do fill_text "$k"; printf '%s\n' "$FILL_TEXT" >>"$d/copy/$f"; done <<<"$FILL_ROWS"
    for f in $(printf '%s\n' "$FILL_ROWS" | cut -d' ' -f1 | LC_ALL=C sort -u); do
      # shellcheck disable=SC2046
      fill_file "$d/copy/$f" $(printf '%s\n' "$FILL_ROWS" | awk -v f="$f" '$1 == f { print $2 }')
    done
    check_texts_left
    printf 'passed\n' >"$d/passed"
    # A text left outside the values: README.md and the two-line text.
    printf '%s\n' 'Owner: [PO NAME]' >>"$d/copy/README.md"
    printf '%s\n' '[What the project is, who it is for, and what problem' 'it solves.]' >>"$d/copy/memory/project.md"
    check_texts_left ) >"$d/out" 2>"$d/err" && die "a text left did not stop the self-check"
  [ -e "$d/passed" ] || { cat "$d/out" "$d/err" >&2; die "values holding a text of the table were taken for texts left"; }
  grep -qF '[PO NAME] App' "$d/copy/README.md" && grep -qF 'Tracks [DATE] and [OWNER/REPO] tags.' "$d/copy/memory/project.md" \
    || die "test setup: the values are not in the files"
  expect_err_shape "$d" "Some texts that the setup fills in are still in the copy of the project, so the script saved and sent nothing: \[PO NAME\] in README\.md; \[What the project is, who it is for, and what problem it solves\.\] in memory/project\.md\. The project exists\.\$"
  sed -n 2p "$d/err" | grep -F "Report it to the bootstrapper's maintainers" >/dev/null || { cat "$d/err" >&2; die "the next action is not to report it"; }
}

test_values_holding_texts_of_the_fill_table_get_through_the_whole_setup() {
  # The same as above, through the whole run (node, so package.json too):
  # the setup is saved, sent and proposed.
  local d c
  d="$(tmpdir)"
  fake_tool "$d" npm 10.0.0
  setup_run "$d" --non-interactive --yes --pack node --project-name "[PO NAME] App" --po-name "[PROJECT NAME] Ltd" \
    --description "Shows [project-name] and [OWNER/REPO] tags."
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not reach the end"; }
  c="$(copy_of "$d")"
  grep -qxF '# [PO NAME] App' "$c/README.md" || die "README.md: the display name is not the heading"
  grep -qF '"description": "Shows [project-name] and [OWNER/REPO] tags."' "$c/package.json" || die "package.json: the description is not there"
  [ -z "$(in_git -C "$c" status --porcelain)" ] || die "something is left unsaved"
}

# expected_case <pack> <deploy: yes or empty> <licence> <code> <path>
# <yes|no>: one row of the table below. The pack's LP_TARGETS and LP_KEPT
# come from layout_into itself (into a scratch folder), and FILL_FILES from
# fill_rows, as in a setup run.
expected_case() {
  local got=no
  ( load_script
    IN_PACK="$1" IN_WITH_DEPLOY="$2" IN_LICENSE="$3"
    layout_into "$1" "$REPO/languages" "$(mktemp -d "$WORK/expected.XXXXXX")/out" strict "$2" >/dev/null
    fill_rows "$1" "$2"
    FILL_FILES="$(while read -r f _; do printf '%s ' "$f"; done <<<"$FILL_ROWS")"
    expected_change "$4" "$5" ) && got=yes
  [ "$got" = "$6" ] || die "expected_change $1${2:+ with deploy}, licence $3, '$4' $5: got $got, want $6"
}

test_expected_change_accepts_exactly_the_changes_the_setup_makes() {
  # #155 review, finding 1 (blocking): every branch of the git status
  # check, accepted and refused. The pack is python, mit, unless a row
  # says otherwise.
  local pack deploy licence code path want
  while IFS='|' read -r pack deploy licence code path want; do
    [ -n "$pack" ] || continue
    expected_case "$pack" "$deploy" "$licence" "$code" "$path" "$want"
  done <<'ROWS'
python||mit|M |README.md|yes
python||mit|M |CHANGELOG.md|yes
python||mit|M |.gitignore|yes
python||mit|M |.github/workflows/ci.yml|yes
python||mit|M |docs/DEV_INFRASTRUCTURE.md|yes
python||mit|M |CLAUDE.md|yes
python||mit|M |docs/SPEC.md|yes
python||mit|M |memory/project.md|yes
python||mit|M |memory/roles.md|no
python||mit|M |docs/CROG_ONBOARDING.md|no
python||mit|M |licenses/NOTICE|no
python||mit|M |pyproject.toml|no
node||mit|M |package.json|no
react-native||mit|M |app.json|no
web|yes|mit|M |wrangler.jsonc|no
python||mit|D |bootstrap-project.sh|yes
python||mit|D |.github/README.md|yes
python||mit|M |.github/README.md|no
python||mit|D |.github/PULL_REQUEST_TEMPLATE.md|no
python||mit|D |languages/README.md|yes
python||mit|D |languages/node/package.json|yes
python||mit|D |languages/node/code-standards.md|yes
python||mit|D |languages/python/pyproject.toml|yes
python||mit|D |languages/python/code-standards.md|no
python||mit|D |docs/SPEC.md|no
python||mit|D |README.md|no
python||mit|D |licenses/NOTICE|no
web||mit|D |languages/web/deploy.yml|no
web||mit|D |languages/web/wrangler.jsonc|no
web|yes|mit|D |languages/web/deploy.yml|yes
web|yes|mit|D |languages/web/code-standards.md|no
python||mit|A |src/__init__.py|yes
python||mit|A |src/tests/test_placeholder.py|yes
python||mit|A |src/my_app/__init__.py|no
python||mit|A |src/deep/er/x.py|no
python||mit|A |src/.DS_Store|no
python||mit|A |srcx.py|no
python||mit|A |e2e/x.spec.ts|no
python||mit|A |pyproject.toml|yes
python||mit|A |.vscode/settings.json|yes
python||mit|A |.vscode/other.json|no
python||mit|A |stray.txt|no
python||mit|A |package-lock.json|no
python||mit|A |LICENSE|yes
python||mit|A |NOTICE|no
python||none|A |LICENSE|no
python||polyform-noncommercial-1.0.0|A |NOTICE|yes
python||polyform-noncommercial-1.0.0|A |LICENSE|yes
node||mit|A |package-lock.json|yes
node||mit|A |src/placeholder.test.ts|yes
node||mit|A |src/other.ts|no
web||mit|A |e2e/smoke.e2e.ts|yes
web||mit|A |src/main.ts|yes
web||mit|A |e2e/app.spec.ts|no
web||mit|A |src/notes.txt|no
web||mit|A |wrangler.jsonc|no
web||mit|A |.github/workflows/deploy.yml|no
web|yes|none|A |wrangler.jsonc|yes
web|yes|none|A |.github/workflows/deploy.yml|yes
web|yes|none|A |package-lock.json|yes
web|yes|none|A |LICENSE|no
react-native||mit|A |app.json|yes
react-native||mit|A |package-lock.json|yes
python||mit|MM|README.md|no
python||mit|AM|pyproject.toml|no
python||mit|R |README.md|no
python||mit|T |README.md|no
python||mit|??|stray.txt|no
ROWS
}

test_a_file_changed_or_deleted_that_the_setup_does_not_change_stops_before_anything_is_saved() {
  # #155 review, finding 1: the "M " and "D " branches through a whole run
  # (node): something else (here npm) changes memory/roles.md, or deletes
  # docs/ROUTINES.md, which the setup never touches.
  local d c var path line epat
  for var in TOUCH:memory/roles.md DELETE:docs/ROUTINES.md; do
    path="${var#*:}"
    d="$(tmpdir)"
    fake_tool "$d" npm 10.0.0
    export "STUB_NPM_${var%%:*}=$path"
    setup_run "$d" --non-interactive --yes --pack node
    unset STUB_NPM_TOUCH STUB_NPM_DELETE
    expect_rc 1 "$d"
    epat="$(printf '%s' "$path" | sed 's/[.]/[.]/g')"
    expect_err_shape "$d" "The copy of the project on this computer has changes that the setup did not make, so the script saved and sent nothing: $epat[.] "
    if [ "${var%%:*}" = TOUCH ]; then line="    M  $path"; else line="    D  $path"; fi
    grep -qxF "$line" "$d/err" || { cat "$d/err" >&2; die "$path: git's line is not below"; }
    expect_continue_command "$d" " --resume"
    c="$(copy_of "$d")"
    [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 1 ] || die "$path: a change was saved"
    ! grep -qF ' push ' "$d/tools.log" || die "$path: something was sent"
    ! calls_from_create "$d" | grep '^pr ' >/dev/null || die "$path: a change was proposed"
  done
}

test_changes_the_setup_did_not_make_stop_before_anything_is_saved() {
  # Spec step 12: git status shows only the paths the setup changes. A
  # file something else left in the copy (here npm) stops it, named.
  local d c
  d="$(tmpdir)"
  fake_tool "$d" npm 10.0.0
  export STUB_NPM_STRAY=stray.txt
  setup_run "$d" --non-interactive --yes --pack node
  unset STUB_NPM_STRAY
  expect_rc 1 "$d"
  expect_err_shape "$d" "The copy of the project on this computer has changes that the setup did not make, so the script saved and sent nothing: stray\.txt\. "
  grep -qxF '    A  stray.txt' "$d/err" || { cat "$d/err" >&2; die "git's line for the file is not below"; }
  expect_continue_command "$d" " --resume"
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 1 ] || die "a change was saved"
  ! grep -qF ' push ' "$d/tools.log" || die "something was sent"
  ! calls_from_create "$d" | grep '^pr ' >/dev/null || die "a change was proposed"
}

test_a_setup_file_that_git_is_told_to_ignore_stops_before_anything_is_saved() {
  # Spec step 12, git status: a file the setup adds must be in the saved
  # change. A list of files to ignore in the user's global git settings
  # (here one that ignores .vscode/, which many editors' users have)
  # would leave the pack's .vscode files out of the change without a
  # word; the self-check names them and stops instead.
  local d c
  d="$(tmpdir)"
  prepare "$d"
  printf '%s\n' '.vscode/' >"$d/home/global-ignore"
  "$REAL_GIT" config --file "$d/home/.gitconfig" core.excludesFile "$d/home/global-ignore"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "Some files that the setup adds are ignored by git, so they would be left out of the saved change, and the script saved and sent nothing: \\.vscode/extensions\\.json, \\.vscode/settings\\.json\\. "
  grep -qF 'core.excludesFile' "$d/err" || { cat "$d/err" >&2; die "the next action does not name the setting"; }
  expect_continue_command "$d" " --resume"
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 1 ] || die "a change was saved"
  ! grep -qF ' push ' "$d/tools.log" || die "something was sent"
}

test_a_github_key_in_the_changes_stops_before_anything_is_saved_and_is_never_shown() {
  # Spec step 12 and "No secrets": what looks like a GitHub key (a
  # classic gh[pousr]_ token or a fine-grained github_pat_ one) in the
  # changes stops the setup, naming the files only, never the key.
  local d c t1 t2
  built_bootstrapper
  t1=ghp_FakeKey0123456789abcdefghijklmnopqrstu
  t2=github_pat_11FAKEKEY0_abcdefghijklmnopqrstuvwxyz0123456789
  d="$(tmpdir)"
  cp -R "$BUILT" "$d/template"
  printf 'KEY = "%s"\n' "$t1" >"$d/template/languages/python/starter/src/settings_one.py"
  printf 'KEY = "%s"\n' "$t2" >"$d/template/languages/python/starter/src/settings_two.py"
  export STUB_GH_TEMPLATE="$d/template"
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_TEMPLATE
  expect_rc 1 "$d"
  expect_err_shape "$d" "The setup's changes hold what looks like a sign-in key for GitHub \(a token\), in src/settings_one\.py, src/settings_two\.py, so the script saved and sent nothing\. "
  ! grep -qF -e "$t1" -e "$t2" "$d/out" "$d/err" || die "the key was shown"
  expect_continue_command "$d" " --resume"
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 1 ] || die "a change was saved"
  ! grep -qF ' push ' "$d/tools.log" || die "something was sent"
}

test_a_file_with_windows_line_endings_stops_before_anything_is_saved() {
  # Spec step 12: every file is LF. S15 (#155 review) decides that the
  # check reads what is saved (git's index, after git add), not the files
  # on disk: the project's .gitattributes (eol=lf) makes git save a CR LF
  # file with LF, so a lockfile with CR LF line endings (as a tool on
  # Windows might write it) goes through, saved with LF. A carriage
  # return git keeps (lines that end in one alone) stops the setup, named.
  local d c
  d="$(tmpdir)"
  fake_tool "$d" npm 10.0.0
  export STUB_NPM_CRLF=1
  setup_run "$d" --non-interactive --yes --pack node
  unset STUB_NPM_CRLF
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "a CR LF lockfile did not go through"; }
  in_git --git-dir="$(bare_of "$d")" show main:package-lock.json >"$d/saved-lockfile"
  ! has_cr "$d/saved-lockfile" || die "the lockfile was saved with carriage returns"
  d="$(tmpdir)"
  fake_tool "$d" npm 10.0.0
  export STUB_NPM_CRLF=lone
  setup_run "$d" --non-interactive --yes --pack node
  unset STUB_NPM_CRLF
  expect_rc 1 "$d"
  expect_err_shape "$d" "Some files in the copy of the project end their lines with a carriage return \(as on Windows\), so the script saved and sent nothing: package-lock\.json\. "
  expect_continue_command "$d" " --resume"
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 1 ] || die "a change was saved"
  ! grep -qF ' push ' "$d/tools.log" || die "something was sent"
}

test_a_key_in_the_environment_never_appears_in_output_or_files() {
  # Spec, "No secrets": with keys in GH_TOKEN and GITHUB_TOKEN, a whole
  # run through to the report shows neither and writes neither into
  # any file: the output, the logs of gh and git (so no command line holds
  # them), the copy and its git settings, the settings and refs of the
  # project on "GitHub", the home folder, the body of the proposed change;
  # nor into the saved change itself, in either place.
  local d t1 t2
  t1=ghp_FakeEnvKey0123456789abcdefghijklmnopq
  t2=github_pat_11FAKEENVKEY_abcdefghijklmnopqrstuvwxyz0123456789
  d="$(tmpdir)"
  export GH_TOKEN="$t1" GITHUB_TOKEN="$t2"
  setup_run "$d" --non-interactive --yes
  unset GH_TOKEN GITHUB_TOKEN
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" && [ "$(calls_from_create "$d" | tail -1)" = "$MERGED_CALL" ] || { cat "$d/out" "$d/err" >&2; die "did not go through to the report"; }
  ! grep -rlF -e "$t1" -e "$t2" "$d" >"$d/hits" 2>/dev/null || { cat "$d/hits" >&2; die "a key from the environment was written"; }
  # git keeps the saved change compressed, where grep -r cannot see it
  # (#155 review, finding 8): every change, with its message and full
  # content, of the copy and of the project on "GitHub", read through git.
  { in_git -C "$(copy_of "$d")" log --all -p --format=fuller
    in_git --git-dir="$(bare_of "$d")" log --all -p --format=fuller; } >"$d/history"
  grep -qF 'Set up my-app' "$d/history" || die "test setup: the saved change is not in the history read"
  ! grep -qF -e "$t1" -e "$t2" "$d/history" || die "a key from the environment is in the saved change"
}

test_failures_to_propose_the_change_are_explained_with_the_continue_command() {
  # Spec step 14, failures mapped plainly. The change is saved and sent
  # by then, and the stop says so.
  local d mode
  for mode in signed-out exists broken no-link; do
    d="$(tmpdir)"
    export STUB_GH_PR_FAIL="$mode"
    setup_run "$d" --non-interactive --yes
    unset STUB_GH_PR_FAIL
    expect_rc 1 "$d"
    case "$mode" in
      signed-out)
        expect_err_shape "$d" "gh \(the GitHub command-line tool\) is not signed in to your GitHub account, so the script could not propose the setup's changes on GitHub\. "
        sed -n 2p "$d/err" | grep -F 'gh auth login' >/dev/null || { cat "$d/err" >&2; die "signed out: the sign-in command is not given"; }
        ;;
      exists)
        expect_err_shape "$d" "GitHub already has a proposed change for the line of work bootstrap-setup\. "
        grep -qxF '    https://github.com/octo-user/my-app/pull/1' "$d/err" || { cat "$d/err" >&2; die "exists: its link is not below"; }
        ;;
      broken)
        expect_err_shape "$d" "gh \(the GitHub command-line tool\) could not propose the setup's changes on GitHub\. "
        sed -n 2p "$d/err" | grep -F 'https://github.com/octo-user/my-app/pulls' >/dev/null || { cat "$d/err" >&2; die "broken: the page to look at is not given"; }
        ;;
      no-link)
        expect_err_shape "$d" "gh \(the GitHub command-line tool\) did not say where the proposed change is\. "
        ;;
    esac
    grep -qF "sent to GitHub on the line of work bootstrap-setup" "$d/err" || { cat "$d/err" >&2; die "$mode: the stop does not say the changes were sent"; }
    expect_continue_command "$d" " --resume"
    ! grep -qxF "$FINISHED" "$d/out" || die "$mode: it went on"
  done
}

# ---------- wait, require, add, finish and report (spec steps 15 to 19) ----------
# After the proposed change: step 15 looks at the check named build with
# gh pr checks every 15 seconds, for up to --ci-timeout minutes, taking
# the run of the pull_request event, else any run of build; a failure
# stops with the proposed change left open and its link (naming GitHub
# Actions' "only the project's own actions" setting when that is the
# cause). Step 16 PUTs the whole protection again with build required and
# reads it back, field by field; step 17 adds the change with gh pr merge
# --match-head-commit, run in the copy; step 18 brings the copy to the new
# main, each action only when still needed; step 19 reports.

# calls_after_proposing <dir>: the gh calls from the proposed change on.
calls_after_proposing() { calls_from_create "$1" | sed -n '/^pr create /,$p'; }

# expect_after_proposing <dir> <call...>: exactly these, in this order.
expect_after_proposing() {
  local d="$1" got want
  shift
  got="$(calls_after_proposing "$d")"
  want="$(printf '%s\n' "$PR_CALL" "$@")"
  [ "$got" = "$want" ] || { printf 'want:\n%s\ngot:\n%s\n' "$want" "$got" >&2; die "gh calls after the proposed change differ"; }
}

# expect_left_open <dir>: the run stopped before the change was added:
# main on "GitHub" is still the template's one change, bootstrap-setup is
# still there, the link of the proposed change is in the stop, and the
# command to continue is shown.
expect_left_open() {
  local d="$1" bare
  bare="$(bare_of "$d")"
  [ "$(in_git --git-dir="$bare" rev-list --count main)" -eq 1 ] || die "the change was added to main"
  in_git --git-dir="$bare" rev-parse -q --verify refs/heads/bootstrap-setup >/dev/null || die "bootstrap-setup is gone on GitHub"
  [ ! -e "$d/merge-sha" ] || die "the stub merged"
  grep -qF 'https://github.com/octo-user/my-app/pull/1' "$d/err" || { cat "$d/err" >&2; die "the link of the proposed change is not in the stop"; }
  expect_continue_command "$d" " --resume"
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on to the report"
}

test_build_still_running_is_looked_at_again_every_15_seconds_until_it_passes() {
  local d
  # Pending three times (gh's exit 8), then passed: four looks, three
  # waits of 15 seconds, one note that it is still running, then the rest.
  d="$(tmpdir)"
  echo 3 >"$d/build-pending"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  expect_after_proposing "$d" "$CHECKS_CALL" "$CHECKS_CALL" "$CHECKS_CALL" "${END_CALLS[@]}"
  [ "$(cat "$d/sleep.log")" = "$(printf '15\n15\n15')" ] || { cat "$d/sleep.log" >&2; die "not 3 waits of 15 seconds"; }
  [ "$(grep -cxF 'The check build has not finished yet; the script looks again every 15 seconds.' "$d/out")" -eq 1 ] \
    || { cat "$d/out" >&2; die "the note that build is still running is not shown once"; }
  grep -A1 -xF "Checking the build status (45 seconds of at most 20 minutes)" "$d/out" | tail -1 >"$d/done"
  [ "$(cat "$d/done")" = "    Done. The check build passed on the proposed change." ] || { cat "$d/out" >&2; die "no done line for the wait"; }
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not go through"; }
  # No check reported yet (gh's "no checks reported", exit 1) is waited
  # for too, then the pending runs, then build passes.
  d="$(tmpdir)"
  echo 2 >"$d/checks-none"
  echo 1 >"$d/build-pending"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  expect_after_proposing "$d" "$CHECKS_CALL" "$CHECKS_CALL" "$CHECKS_CALL" "${END_CALLS[@]}"
  [ "$(grep -c . "$d/sleep.log")" -eq 3 ] || { cat "$d/sleep.log" >&2; die "not 3 waits"; }
  # Only other checks reported, no build yet: waited for as well.
  d="$(tmpdir)"
  export STUB_GH_BUILD=""
  setup_run "$d" --non-interactive --yes --ci-timeout 1
  unset STUB_GH_BUILD
  expect_rc 1 "$d"
  [ "$(grep -c . "$d/sleep.log")" -eq 4 ] || { cat "$d/sleep.log" >&2; die "no build: not waited for"; }
  grep -qxF '    build: not reported yet' "$d/err" || { cat "$d/err" >&2; die "no build: not said below"; }
}

# wait_lines <dir>: the lines of the wait for build, from its step line
# to its done line.
wait_lines() {
  sed -n "/^==> Waiting for the project's check build/,/^    Done\. The check build/p" "$1/out"
}
# End-to-end run 3, r3e: the note says on its own what the limit is; it
# used to open with "That is the limit", pointing back at the line above
# it, which is in another colour.
WAIT_LIMIT_LINE="The script waits at most 20 minutes for build to pass. If build has not passed by then, the script stops, leaves the proposed change open and shows how to continue (--ci-timeout sets a different limit)."
WAIT_LINK_LINE="You can follow the check here: https://github.com/octo-user/my-app/pull/1/checks"
STARS_15='***************'

test_the_wait_says_its_limit_where_to_follow_the_check_and_each_check() {
  # E2E run 1, finding 9: the minutes are a limit, the checks page is
  # given, and each later look says how long the script has waited of
  # the limit. Not a terminal (the tests' default): no stars, one line
  # per look, and the waits stay 15 seconds each.
  local d want
  d="$(tmpdir)"
  echo 2 >"$d/build-pending"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  want="$(printf '%s\n' \
    "==> Waiting for the project's check build to pass on the proposed change, for at most 20 minutes" \
    "$WAIT_LIMIT_LINE" "$WAIT_LINK_LINE" \
    'The check build has not finished yet; the script looks again every 15 seconds.' \
    'Checking the build status (15 seconds of at most 20 minutes)' \
    'Checking the build status (30 seconds of at most 20 minutes)' \
    '    Done. The check build passed on the proposed change.')"
  [ "$(wait_lines "$d")" = "$want" ] || { printf 'want:\n%s\ngot:\n%s\n' "$want" "$(wait_lines "$d")" >&2; die "the lines of the wait differ"; }
  [ "$(cat "$d/sleep.log")" = "$(printf '15\n15')" ] || { cat "$d/sleep.log" >&2; die "not 2 waits of 15 seconds"; }
  expect_no_out "$d" '*'
  # build passed at the first look: the limit and the link, no wait.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  want="$(printf '%s\n' \
    "==> Waiting for the project's check build to pass on the proposed change, for at most 20 minutes" \
    "$WAIT_LIMIT_LINE" "$WAIT_LINK_LINE" \
    '    Done. The check build passed on the proposed change.')"
  [ "$(wait_lines "$d")" = "$want" ] || { printf 'want:\n%s\ngot:\n%s\n' "$want" "$(wait_lines "$d")" >&2; die "a wait with no look again differs"; }
  [ ! -s "$d/sleep.log" ] || { cat "$d/sleep.log" >&2; die "it waited although build had passed"; }
}

test_on_a_terminal_the_wait_shows_a_star_a_second_and_each_check_on_a_new_line() {
  # Adam's indicator (finding 9): one * per second, a new line at each
  # look; r1h (Adam, 15:32): the stars on a line of their own, under the
  # line of the look. BOOTSTRAP_STDOUT_TERMINAL=yes stands for a terminal.
  # The seconds come one at a time from the sleep hook; the total is the
  # same as without a terminal. Colour off here: with colour on, the
  # same lines come with the codes of the progress log (next test).
  local d want
  export NO_COLOR=1
  d="$(tmpdir)"
  echo 5 >"$d/build-pending"
  export BOOTSTRAP_STDOUT_TERMINAL=yes
  setup_run "$d" --non-interactive --yes
  unset BOOTSTRAP_STDOUT_TERMINAL
  expect_rc 0 "$d"
  want="$(printf '%s\n' \
    "==> Waiting for the project's check build to pass on the proposed change, for at most 20 minutes" \
    "$WAIT_LIMIT_LINE" "$WAIT_LINK_LINE" \
    'The check build has not finished yet; the script looks again every 15 seconds.' "$STARS_15" \
    'Checking the build status (15 seconds of at most 20 minutes)' "$STARS_15" \
    'Checking the build status (30 seconds of at most 20 minutes)' "$STARS_15" \
    'Checking the build status (45 seconds of at most 20 minutes)' "$STARS_15" \
    'Checking the build status (1 minute of at most 20 minutes)' "$STARS_15" \
    'Checking the build status (1 minute 15 seconds of at most 20 minutes)' \
    '    Done. The check build passed on the proposed change.')"
  [ "$(wait_lines "$d")" = "$want" ] || { printf 'want:\n%s\ngot:\n%s\n' "$want" "$(wait_lines "$d")" >&2; die "the lines of the wait on a terminal differ"; }
  [ "$(grep -c . "$d/sleep.log")" -eq 75 ] && [ "$(sort -u "$d/sleep.log")" = 1 ] || { cat "$d/sleep.log" >&2; die "not 75 waits of 1 second"; }
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not go through"; }
  [ "$(tail -c 1 "$d/out" | od -A n -c | tr -d ' ')" = '\n' ] || die "the output does not end with a line break"
  # The limit reached on a terminal: the same number of seconds as
  # without one (60 for 1 minute), and the stop starts on a line of its own.
  d="$(tmpdir)"
  echo 9999 >"$d/build-pending"
  export BOOTSTRAP_STDOUT_TERMINAL=yes
  setup_run "$d" --non-interactive --yes --ci-timeout 1
  unset BOOTSTRAP_STDOUT_TERMINAL
  expect_rc 1 "$d"
  [ "$(grep -c . "$d/sleep.log")" -eq 60 ] && [ "$(sort -u "$d/sleep.log")" = 1 ] || { cat "$d/sleep.log" >&2; die "timeout: not 60 waits of 1 second"; }
  [ "$(calls_after_proposing "$d" | grep -cxF "$CHECKS_CALL")" -eq 5 ] || { cat "$d/gh.log" >&2; die "timeout: not 5 looks"; }
  grep -qxF 'Checking the build status (1 minute of at most 1 minute)' "$d/out" || { cat "$d/out" >&2; die "timeout: the last look is not on a line of its own"; }
  expect_continue_command "$d" " --resume"
  expect_err_shape "$d" "The project's check build had not passed on the proposed change after 1 minute, "
  # build failing after a wait on a terminal: the stop on a line of its own.
  d="$(tmpdir)"
  echo 1 >"$d/build-pending"
  export BOOTSTRAP_STDOUT_TERMINAL=yes STUB_GH_BUILD="pull_request fail"
  setup_run "$d" --non-interactive --yes
  unset BOOTSTRAP_STDOUT_TERMINAL STUB_GH_BUILD
  expect_rc 1 "$d"
  grep -qxF 'Checking the build status (15 seconds of at most 20 minutes)' "$d/out" || { cat "$d/out" >&2; die "failed: the last look is not on a line of its own"; }
  expect_continue_command "$d" " --resume"
  expect_err_shape "$d" "The project's check build failed on the proposed change"
  # BOOTSTRAP_STDOUT_TERMINAL=no: no stars, 15-second waits.
  d="$(tmpdir)"
  echo 1 >"$d/build-pending"
  export BOOTSTRAP_STDOUT_TERMINAL=no
  setup_run "$d" --non-interactive --yes
  unset BOOTSTRAP_STDOUT_TERMINAL
  expect_rc 0 "$d"
  expect_no_out "$d" '*'
  [ "$(cat "$d/sleep.log")" = 15 ] || { cat "$d/sleep.log" >&2; die "no: not one wait of 15 seconds"; }
}

test_with_colour_a_whole_run_starts_with_the_colour_key_and_the_stars_end_their_line() {
  # A whole run on a terminal that takes colour: the colour key first,
  # once; the log dim; and the wait's stars, plain on a line of their own
  # (r1h), end their line before any other line, so with the codes taken
  # out the wait's lines are the ones the run shows without colour. The
  # limit reached: the command to continue starts a line of its own,
  # after a blank line, in the instruction colour.
  local d want n esc
  esc="$(printf '\033')"
  export TERM=xterm BOOTSTRAP_STDOUT_TERMINAL=yes
  unset NO_COLOR BOOTSTRAP_COLOR
  d="$(tmpdir)"
  echo 1 >"$d/build-pending"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  {
    printf '%sColour key: where you type an answer%s\n' "$COLOUR_ON" "$COLOUR_OFF"
    printf '%sColour key: what to read and do%s\n' "$READ_ON" "$COLOUR_OFF"
    printf '%sColour key: commands to copy or to run%s\n' "$COMMAND_ON" "$COLOUR_OFF"
    printf '%sColour key: the progress log of what the script does%s\n' "$LOG_ON" "$COLOUR_OFF"
    printf '\n'
  } >"$d/want-key"
  head -n 5 "$d/out" >"$d/got-key"
  expect_same "the start of a run with colour" "$d/want-key" "$d/got-key"
  [ "$(grep -c 'Colour key: ' "$d/out")" -eq 4 ] || { cat "$d/out" >&2; die "the colour key is not shown exactly once"; }
  [ "$(sed -n '6p' "$d/out")" = "${LOG_ON}==> Checking that bash (the program that runs this script) is new enough${COLOUR_OFF}" ] \
    || { sed -n '1,8p' "$d/out" | od -c | head -20 >&2; die "the first check does not come right after the colour key, dim"; }
  ! grep -qE '^==> |^    Done\. ' "$d/out" || { grep -E '^==> |^    Done\. ' "$d/out" >&2; die "a step line is not dim"; }
  ! grep -F '*' "$d/out" | grep -E "$esc\\[1;3[236]m" >/dev/null || { cat "$d/out" >&2; die "a line of stars goes on with a coloured line"; }
  # r1g: in a whole run the read colour marks only the plan's heading, the
  # lines above and below the command to continue, the wait's notes and the closing
  # "What to do next"; no line of the report or of the plan's list.
  grep -F "$READ_ON" "$d/out" | sed "s/$esc\\[[0-9;]*m//g" | sed '/^Colour key: /d' >"$d/read-lines"
  {
    printf '%s\n' 'Here is the plan. Nothing has been created yet.'
    ( load_script; printf '%s\n' "$ADVANCE_INTRO" )
    printf '%s\n' 'If the project was not created yet, that command says so and shows the command to start again.'
    printf '%s\n' "$WAIT_LIMIT_LINE" "$WAIT_LINK_LINE"
  } >"$d/want-read"
  grep -F 'What to do next: ' "$d/read-lines" >>"$d/want-read" || die "the closing next step is not in the read colour"
  expect_same "the lines of a whole run in the read colour" "$d/want-read" "$d/read-lines"
  sed "s/$esc\\[[0-9;]*m//g" "$d/out" >"$d/plain"
  want="$(printf '%s\n' \
    "==> Waiting for the project's check build to pass on the proposed change, for at most 20 minutes" \
    "$WAIT_LIMIT_LINE" "$WAIT_LINK_LINE" \
    'The check build has not finished yet; the script looks again every 15 seconds.' "$STARS_15" \
    'Checking the build status (15 seconds of at most 20 minutes)' \
    '    Done. The check build passed on the proposed change.')"
  [ "$(sed -n "/^==> Waiting for the project's check build/,/^    Done\. The check build/p" "$d/plain")" = "$want" ] \
    || { cat "$d/plain" >&2; die "with the codes taken out, the wait's lines differ"; }
  grep -qxF "$FINISHED" "$d/plain" || { cat "$d/out" "$d/err" >&2; die "did not go through"; }
  d="$(tmpdir)"
  echo 9999 >"$d/build-pending"
  setup_run "$d" --non-interactive --yes --ci-timeout 1
  expect_rc 1 "$d"
  n="$(grep -nxF "${READ_ON}To continue the setup, run this command:${COLOUR_OFF}" "$d/out" | cut -d: -f1)"
  [ -n "$n" ] || { od -c "$d/out" | tail -20 >&2; die "timeout: the command to continue is not on a line of its own, in colour"; }
  [ -z "$(sed -n "$((n - 1))p" "$d/out")" ] || { od -c "$d/out" | tail -20 >&2; die "timeout: no blank line between the stars and the command to continue"; }
  # Colour off: no key anywhere in a whole run.
  export NO_COLOR=1
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  expect_no_out "$d" 'Colour key'
  ! has_esc "$d/out" || die "codes in a run with NO_COLOR"
}

test_with_colour_the_lines_of_a_run_after_the_advance_command_each_have_their_colour() {
  # Adam's screenshots of run 1 on v2.7.0. r1h: the signs of life of the
  # wait (its open lines with their stars, and "Checking the build
  # status") are not dim, so they are easy to see; the other lines of the
  # progress log stay dim. And every line from the command to continue to
  # the end has the colour of its kind: the line below the command explains
  # it (read colour), "GitHub is still copying the files" is progress
  # (dim); plain are only the report, a warning, the plan's list and the
  # signs of life.
  local d esc l n
  esc="$(printf '\033')"
  export TERM=xterm BOOTSTRAP_STDOUT_TERMINAL=yes
  unset NO_COLOR BOOTSTRAP_COLOR
  d="$(tmpdir)"
  echo 1 >"$d/build-pending"
  echo 1 >"$d/main-missing"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  grep -qxF "${READ_ON}If the project was not created yet, that command says so and shows the command to start again.${COLOUR_OFF}" "$d/out" \
    || { grep -F 'If the project was not created yet' "$d/out" | od -c >&2; die "the line below the command to continue is not in the read colour"; }
  grep -qxF "${LOG_ON}GitHub is still copying the files; the script checks again every 2 seconds, for up to a minute.${COLOUR_OFF}" "$d/out" \
    || { grep -F 'still copying' "$d/out" | od -c >&2; die "the line while GitHub copies the files is not dim"; }
  # r1h: no dim code on a line with the stars or on a check of the status;
  # the wait's step line still dim.
  ! grep -F '*' "$d/out" | grep -F "$LOG_ON" >/dev/null || { grep -F '*' "$d/out" | od -c | head -20 >&2; die "the stars of the wait are dim"; }
  grep -F 'Checking the build status' "$d/out" >"$d/checks" || die "no check of the build status"
  ! grep -F "$esc" "$d/checks" >/dev/null || { od -c "$d/checks" >&2; die "a check of the build status is in colour"; }
  grep -qxF "${LOG_ON}==> Waiting for the project's check build to pass on the proposed change, for at most 20 minutes${COLOUR_OFF}" "$d/out" \
    || die "the wait's step line is not dim"
  # The sweep: from the command to continue to the end, a plain line is
  # one of the signs of life, a warning, or a line of the report (from
  # "The setup is finished." on, but its last two lines).
  n="$(grep -nF "$(load_script; printf '%s' "$ADVANCE_INTRO")" "$d/out" | cut -d: -f1)"
  [ -n "$n" ] || die "no command to continue"
  sed -n "$n,\$p" "$d/out" | sed "/^The setup is finished\\.\$/,\$d" | grep -v "^$esc" | grep -v "^    $esc" \
    | grep -v '^$' | grep -v '^Warning: ' | grep -v '^Checking the build status (' | grep -v '^The check build has not finished yet' \
    | grep -v '^\**$' >"$d/plain-lines" || true
  # r1h: the stars on lines of their own, nothing else on them.
  [ "$(grep -c '^\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*$' "$d/out")" -eq 1 ] || { grep -F '*' "$d/out" | od -c | head >&2; die "the stars are not on a line of their own"; }
  [ ! -s "$d/plain-lines" ] || { cat "$d/plain-lines" >&2; die "lines after the command to continue that are plain"; }
  for l in 'If you ever feel stuck'; do
    grep -F -- "$l" "$d/out" | grep -F "$esc" >/dev/null && die "in colour: $l"
  done
  return 0
}

test_a_wait_in_seconds_is_said_in_minutes_and_seconds() {
  local s want
  load_script
  for s in "15|15 seconds" "1|1 second" "60|1 minute" "61|1 minute 1 second" "75|1 minute 15 seconds" \
    "120|2 minutes" "135|2 minutes 15 seconds" "1200|20 minutes" "0|0 seconds"; do
    want="${s#*|}"
    duration_words "${s%%|*}"
    [ "$DURATION" = "$want" ] || die "${s%%|*}: want '$want', got '$DURATION'"
  done
}

test_the_pull_request_run_of_build_counts_and_else_any_run_of_it() {
  # ci.yml runs build on push and on pull_request, so the change has two
  # runs of build: the pull_request one counts, whatever the push one
  # says; without one, any run of build counts (spec step 15).
  local d build want
  for build in "push fail;pull_request pass|0" "pull_request pass;push fail|0" "push pass|0" \
    "push pass;pull_request fail|1" "pull_request fail;push pass|1" "push fail|1"; do
    want="${build#*|}"
    d="$(tmpdir)"
    export STUB_GH_BUILD="${build%|*}"
    setup_run "$d" --non-interactive --yes
    unset STUB_GH_BUILD
    expect_rc "$want" "$d"
    if [ "$want" = 0 ]; then
      grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "[${build%|*}] did not go through"; }
    else
      expect_err_shape "$d" "The project's check build failed on the proposed change"
    fi
  done
}

test_a_failed_build_stops_and_leaves_the_proposed_change_open_with_its_link() {
  local d bucket
  for bucket in fail cancel skipping; do
    d="$(tmpdir)"
    export STUB_GH_BUILD="push pass;pull_request $bucket"
    setup_run "$d" --non-interactive --yes
    unset STUB_GH_BUILD
    expect_rc 1 "$d"
    expect_err_shape "$d" "The project's check build failed on the proposed change, so the script did not add the change to the main version\. The proposed change stays open on GitHub\. The project octo-user/my-app exists on GitHub, and the setup's changes are proposed there: https://github.com/octo-user/my-app/pull/1\$"
    sed -n 2p "$d/err" | grep -F 'Open https://github.com/octo-user/my-app/pull/1 in your browser, click Checks, then build' >/dev/null \
      || { cat "$d/err" >&2; die "$bucket: the next action does not say where to look"; }
    grep -qxF "    build: pull_request $bucket" "$d/err" || { cat "$d/err" >&2; die "$bucket: what gh said is not below"; }
    # Only the actions allowed are asked for: no second protection, no merge.
    expect_after_proposing "$d" "$CHECKS_CALL" "$ALLOWED_CALL"
    [ "$(grep -c . "$d/protection-bodies")" -eq 1 ] || die "$bucket: the protection was changed again"
    expect_left_open "$d"
    expect_no_out "$d" "Why this is needed"
  done
  # GitHub does not say which actions are allowed: the plain stop stands.
  d="$(tmpdir)"
  export STUB_GH_BUILD="pull_request fail" STUB_GH_ALLOWED_FAIL=forbidden
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_BUILD STUB_GH_ALLOWED_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "The project's check build failed on the proposed change"
  expect_left_open "$d"
}

test_a_build_failed_with_only_the_projects_own_actions_allowed_gets_the_actions_guide() {
  # #156 review: with allowed_actions local_only, the check of Actions
  # after step 3 passes (enabled is true), and build fails at its first
  # action made by GitHub. The stop says so, with the steps of the guide
  # for Actions turned off, plus running the check again; exit 3.
  local d
  d="$(tmpdir)"
  export STUB_GH_BUILD="pull_request fail" STUB_GH_ALLOWED_ACTIONS=local_only
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_BUILD STUB_GH_ALLOWED_ACTIONS
  expect_rc 3 "$d"
  expect_out "$d" "GitHub Actions, the GitHub service that runs your project's checks, allows only actions from inside the project octo-user/my-app, so the check build failed: it uses actions made by GitHub."
  expect_out "$d" "Why this is needed: "
  # The same steps as for Actions turned off.
  expect_out "$d" "  1. Open https://github.com/octo-user/my-app/settings/actions in your browser: the project's Settings, then Actions, then General."
  expect_out "$d" "  2. Under \"Actions permissions\", choose \"Allow all actions and reusable workflows\", then click Save."
  # S18b: an organisation may limit Actions, not only turn it off.
  expect_out "$d" "  3. If those choices cannot be changed, the organisation (or enterprise) that owns the project has turned off or limited GitHub Actions for its projects"
  expect_out "$d" "  4. Then run the check again: open https://github.com/octo-user/my-app/pull/1 in your browser, click Checks, then \"Re-run all jobs\""
  expect_out "$d" "How the script checks it: "
  grep -qxF '    allowed_actions: local_only' "$d/out" || { cat "$d/out" >&2; die "GitHub's answer is not below the guide"; }
  # The guide ends with its own steps (#158 review): its last step is to
  # continue, with one result block, and none of the Actions-off ending.
  [ "$(grep -E '^  [0-9]+\. ' "$d/out" | tail -1)" = "  5. Then continue the setup with the command shown below." ] \
    || { cat "$d/out" >&2; die "the guide does not end with its step 5"; }
  [ "$(grep -c '^When it has worked: ' "$d/out")" -eq 1 ] && [ "$(grep -c '^How the script checks it: ' "$d/out")" -eq 1 ] \
    || { cat "$d/out" >&2; die "the guide has more than one result block"; }
  expect_no_out "$d" "if the script is waiting, come back to this window"
  sed -n 1p "$d/err" | grep -F "What happened: GitHub Actions, the GitHub service that runs your project's checks, allows only actions from inside the project octo-user/my-app, so the check build failed: it uses actions made by GitHub. The script stopped here. The project octo-user/my-app exists on GitHub, and the setup's changes are proposed there: https://github.com/octo-user/my-app/pull/1" >/dev/null \
    || { cat "$d/err" >&2; die "the stop does not say what is limited and where the proposed change is"; }
  expect_after_proposing "$d" "$CHECKS_CALL" "$ALLOWED_CALL"
  expect_left_open "$d"
  # Interactive too: it stops (the check has to run again on GitHub
  # first), with no wait.
  d="$(tmpdir)"
  export STUB_GH_BUILD="pull_request fail" STUB_GH_ALLOWED_ACTIONS=local_only
  printf 'yes\n\n\n' >"$d/in"
  setup_run "$d"
  unset STUB_GH_BUILD STUB_GH_ALLOWED_ACTIONS
  expect_rc 3 "$d"
  expect_no_out "$d" "Press Enter"
  # Other settings (all, selected) leave the plain stop.
  d="$(tmpdir)"
  export STUB_GH_BUILD="pull_request fail" STUB_GH_ALLOWED_ACTIONS=selected
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_BUILD STUB_GH_ALLOWED_ACTIONS
  expect_rc 1 "$d"
  expect_no_out "$d" "allows only actions"
}

test_the_wait_for_build_ends_after_the_ci_timeout_with_the_proposed_change_open() {
  local d m
  for m in 1 2; do
    d="$(tmpdir)"
    echo 9999 >"$d/build-pending"
    : >"$d/sleep.log"
    setup_run "$d" --non-interactive --yes --ci-timeout "$m"
    expect_rc 1 "$d"
    # 60 / 15 = 4 waits a minute, and a look before each and after the last.
    [ "$(grep -c . "$d/sleep.log")" -eq $((m * 4)) ] && [ "$(sort -u "$d/sleep.log")" = 15 ] || { cat "$d/sleep.log" >&2; die "$m: not $((m * 4)) waits of 15 seconds"; }
    [ "$(calls_after_proposing "$d" | grep -cxF "$CHECKS_CALL")" -eq $((m * 4 + 1)) ] || { cat "$d/gh.log" >&2; die "$m: not $((m * 4 + 1)) looks"; }
    if [ "$m" = 1 ]; then
      expect_err_shape "$d" "The project's check build had not passed on the proposed change after 1 minute, so the script did not add the change to the main version\. The proposed change stays open on GitHub\. "
      expect_out "$d" "for at most 1 minute"
    else
      expect_err_shape "$d" "The project's check build had not passed on the proposed change after 2 minutes, "
    fi
    sed -n 2p "$d/err" | grep -F -- '--ci-timeout' >/dev/null || { cat "$d/err" >&2; die "$m: the next action does not say how to wait longer"; }
    grep -qxF '    build: pull_request pending' "$d/err" || { cat "$d/err" >&2; die "$m: what gh said is not below"; }
    [ "$(grep -c . "$d/protection-bodies")" -eq 1 ] || die "$m: the protection was changed again"
    expect_left_open "$d"
  done
}

test_gh_failing_to_show_the_checks_is_explained_with_the_proposed_change_open() {
  local d
  d="$(tmpdir)"
  export STUB_GH_CHECKS_FAIL=signed-out
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "gh \(the GitHub command-line tool\) is not signed in to your GitHub account, so the script could not look at the project's checks on the proposed change\. "
  sed -n 2p "$d/err" | grep -F 'gh auth login' >/dev/null || { cat "$d/err" >&2; die "signed out: the sign-in command is not given"; }
  expect_left_open "$d"
  d="$(tmpdir)"
  export STUB_GH_CHECKS_FAIL=broken
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_CHECKS_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "gh \(the GitHub command-line tool\) could not look at the project's checks on the proposed change\. "
  grep -qxF '    stub gh: the connection broke off' "$d/err" || { cat "$d/err" >&2; die "broken: gh's text not below"; }
  expect_after_proposing "$d" "$CHECKS_CALL"
  expect_left_open "$d"
}

test_build_is_required_after_it_passed_with_the_exact_body_and_read_back() {
  # Spec step 16: after build has passed and before the change is added,
  # the whole protection is PUT again, byte for byte the step 3 body with
  # build required, then read back.
  local d
  d="$(tmpdir)"
  echo 1 >"$d/build-pending"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  printf '%s\n\n%s\n\n' "$PROTECT_BODY" "$REQUIRE_BODY" >"$d/want-bodies"
  cmp -s "$d/want-bodies" "$d/protection-bodies" || { od -c "$d/protection-bodies" | tail -5 >&2; die "the protection bodies are not the spec's"; }
  # In order: build looked at until it passed, the PUT, the read-back,
  # then the change added (expect_after_proposing is exact).
  expect_after_proposing "$d" "$CHECKS_CALL" "$CHECKS_CALL" "$PROTECT_CALL" "$READBACK_CALL" "$MERGE_CALL" "$MERGED_CALL"
  grep -A1 -xF '==> Making the check build required, so that from now on a change is added to the main version only after build passes' "$d/out" | sed -n 2p >"$d/done"
  [ "$(cat "$d/done")" = "    Done. GitHub reports the protection of the main version as the script set it, with build required." ] \
    || { cat "$d/out" >&2; die "no step lines for the required check"; }
  [ "$(cut -f1 "$d/gh.log" | LC_ALL=C sort -u)" = GH_PROMPT_DISABLED=1 ] || { cat "$d/gh.log" >&2; die "a gh call ran with prompts on"; }
}

test_a_protection_read_back_that_differs_stops_before_the_change_is_added() {
  local d
  # One field differs and one is missing: each named below, nothing added.
  d="$(tmpdir)"
  export STUB_GH_READBACK="contexts=build;strict=false;enforce_admins=false;approvals=0;restrictions=null;allow_force_pushes=false"
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_READBACK
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub does not report the protection of the main version as the script set it, so the script did not add the setup's change to the main version\. The proposed change stays open on GitHub\. "
  sed -n 2p "$d/err" | grep -F 'https://github.com/octo-user/my-app/settings' >/dev/null || { cat "$d/err" >&2; die "the next action does not say where to look"; }
  [ "$(sed -n '4,$p' "$d/err")" = "$(printf '%s\n' '    enforce_admins: the script set true, GitHub reports false' '    allow_deletions: the script set false, GitHub reports nothing')" ] \
    || { cat "$d/err" >&2; die "the differences are not listed field by field"; }
  expect_after_proposing "$d" "$CHECKS_CALL" "$PROTECT_CALL" "$READBACK_CALL"
  expect_left_open "$d"
  # A wrong required check (as when GitHub kept only the old one).
  d="$(tmpdir)"
  export STUB_GH_READBACK="contexts=;strict=null;enforce_admins=true;approvals=0;restrictions=null;allow_force_pushes=false;allow_deletions=false"
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_READBACK
  expect_rc 1 "$d"
  grep -qxF '    contexts: the script set build, GitHub reports ' "$d/err" && grep -qxF '    strict: the script set false, GitHub reports null' "$d/err" \
    || { cat "$d/err" >&2; die "the required check difference is not listed"; }
  expect_left_open "$d"
  # GitHub does not answer the read-back or refuses the PUT: the plain
  # message of that call, the command to continue, nothing added.
  d="$(tmpdir)"
  export STUB_GH_READBACK_FAIL=server
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_READBACK_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub had a problem of its own, so the script could not read back the protection of the main version\. The project octo-user/my-app exists on GitHub"
  expect_left_open "$d"
  d="$(tmpdir)"
  export STUB_GH_REQUIRE_FAIL=not-found
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_REQUIRE_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub did not find what the script needed to make the check build required for the main version\. "
  sed -n 2p "$d/err" | grep -F 'admins' >/dev/null || { cat "$d/err" >&2; die "the 404 next action is not its own"; }
  expect_after_proposing "$d" "$CHECKS_CALL" "$PROTECT_CALL"
  expect_left_open "$d"
}

test_the_change_is_added_with_the_head_that_was_sent_from_inside_the_copy() {
  # Spec step 17: gh pr merge <n> --squash --delete-branch
  # --match-head-commit <the change sent>, run in the copy; GitHub's new
  # main holds exactly the files of that change.
  local d c bare sent
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  c="$(copy_of "$d")"
  bare="$(bare_of "$d")"
  sent="$(awk -F'\t' '$2 == "pr" && $3 == "merge" && $4 != "--help" { print $NF }' "$d/gh.log")"
  [ -n "$sent" ] && [ "$sent" = "$(cat "$d/merged-head")" ] || { cat "$d/gh.log" >&2; die "the id given is not the head of bootstrap-setup on GitHub"; }
  [ "$(in_git -C "$c" log -1 --format=%s "$sent")" = "Set up my-app" ] || die "the id given is not the setup's change"
  [ "$(awk -F'\t' '$2 == "pr" && $3 == "merge" && $4 != "--help" { print $4, $5, $6, $7 }' "$d/gh.log")" = "1 --squash --delete-branch --match-head-commit" ] \
    || { cat "$d/gh.log" >&2; die "not merged with --squash --delete-branch --match-head-commit"; }
  # Compared as folders, not as text: on macOS $TMPDIR ends in /, so $d
  # holds a // that the shell's $PWD does not.
  [ "$(cd "$(cat "$d/merge-cwd")" && pwd -P)" = "$(cd "$c" && pwd -P)" ] || { cat "$d/merge-cwd" >&2; die "gh pr merge did not run in the copy"; }
  [ "$(in_git --git-dir="$bare" rev-parse main)" = "$(cat "$d/merge-sha")" ] || die "main on GitHub is not the added change"
  [ "$(in_git --git-dir="$bare" rev-parse 'main^{tree}')" = "$(in_git --git-dir="$bare" rev-parse "$sent^{tree}")" ] || die "main does not hold the files sent"
  grep -A1 -xF '==> Adding the proposed change to the main version of the project' "$d/out" | sed -n 2p >"$d/done"
  [ "$(cat "$d/done")" = "    Done. The setup's changes are in the main version of the project on GitHub." ] || { cat "$d/out" >&2; die "no step lines for adding the change"; }
}

test_a_change_github_did_not_add_stops_with_the_proposed_change_open() {
  local d
  # GitHub refuses: gh's text below, nothing added.
  d="$(tmpdir)"
  export STUB_GH_MERGE_FAIL=refused
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_MERGE_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub did not add the proposed change to the main version\. The proposed change stays open on GitHub\. "
  sed -n 2p "$d/err" | grep -F 'Open https://github.com/octo-user/my-app/pull/1 in your browser' >/dev/null || { cat "$d/err" >&2; die "refused: the next action does not give the link"; }
  grep -qF '    GraphQL: Required status check "build" is expected.' "$d/err" || { cat "$d/err" >&2; die "refused: gh's text not below"; }
  expect_after_proposing "$d" "$CHECKS_CALL" "$PROTECT_CALL" "$READBACK_CALL" "$MERGE_CALL" "$MERGED_CALL"
  expect_left_open "$d"
  # Not signed in any more.
  d="$(tmpdir)"
  export STUB_GH_MERGE_FAIL=signed-out
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_MERGE_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "gh \(the GitHub command-line tool\) is not signed in to your GitHub account, so the script could not add the proposed change to the main version\. "
  expect_left_open "$d"
  # gh fails after GitHub added the change: GitHub says it was added, so
  # the setup goes on.
  d="$(tmpdir)"
  export STUB_GH_MERGE_FAIL=broken-but-merged
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_MERGE_FAIL
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "broken but added: did not go on"; }
  # GitHub does not say whether it was added: its plain message.
  d="$(tmpdir)"
  export STUB_GH_PULL_FAIL=server
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_PULL_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub had a problem of its own, so the script could not check whether the proposed change was added to the main version\. "
  expect_continue_command "$d" " --resume"
}

test_the_finish_works_whether_or_not_gh_already_switched_the_copy_to_main() {
  # Spec step 18: gh pr merge --delete-branch may already have switched
  # the copy to main, brought it up to date and deleted bootstrap-setup
  # (the stub does, as gh does in a copy on that line of work), or not
  # (STUB_GH_MERGE_LOCAL=no). Either way the copy ends on main, at the
  # change GitHub made, with no bootstrap-setup left, here or as a
  # leftover of GitHub's, and nothing unsaved; the script does only what
  # is still needed.
  local d c local_done
  for local_done in yes no; do
    d="$(tmpdir)"
    export STUB_GH_MERGE_LOCAL="$local_done"
    setup_run "$d" --non-interactive --yes
    unset STUB_GH_MERGE_LOCAL
    expect_rc 0 "$d"
    c="$(copy_of "$d")"
    [ "$(in_git -C "$c" symbolic-ref --short HEAD)" = main ] || die "$local_done: the copy is not on main"
    [ "$(in_git -C "$c" rev-parse HEAD)" = "$(cat "$d/merge-sha")" ] || die "$local_done: the copy is not at the added change"
    [ "$(in_git -C "$c" for-each-ref --format='%(refname)' refs/heads refs/remotes | grep -v '/HEAD$' | LC_ALL=C sort)" = "$(printf '%s\n' refs/heads/main refs/remotes/origin/main)" ] \
      || { in_git -C "$c" for-each-ref >&2; die "$local_done: a line of work other than main is left in the copy"; }
    [ -z "$(in_git -C "$c" status --porcelain --untracked-files=all)" ] || { in_git -C "$c" status >&2; die "$local_done: something is left unsaved"; }
    if [ "$local_done" = yes ]; then
      ! grep -qE ' checkout -q main$| branch -q -D bootstrap-setup$' "$d/tools.log" || { cat "$d/tools.log" >&2; die "yes: the script did again what gh had done"; }
    else
      grep -qE ' checkout -q main$' "$d/tools.log" && grep -qE ' branch -q -D bootstrap-setup$' "$d/tools.log" \
        || { cat "$d/tools.log" >&2; die "no: the script did not switch to main and delete bootstrap-setup"; }
    fi
    grep -qE " -C \./my-app pull -q --ff-only --prune$" "$d/tools.log" || { cat "$d/tools.log" >&2; die "$local_done: main was not brought up to date"; }
    grep -A1 -xF '==> Updating the copy on this computer to the new main version' "$d/out" | sed -n 2p >"$d/done"
    [ "$(cat "$d/done")" = "    Done. The copy in ./my-app is on the main version, with the setup's changes, and nothing is left unsaved." ] \
      || { cat "$d/out" >&2; die "$local_done: no step lines for the finish"; }
  done
}

test_a_copy_not_at_the_new_main_version_stops_with_both_versions_below() {
  local d
  d="$(tmpdir)"
  export STUB_GH_MERGED_SHA=2222222222222222222222222222222222222222
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_MERGED_SHA
  expect_rc 1 "$d"
  expect_err_shape "$d" "The copy of the project on this computer, in \./my-app, is not at the main version that GitHub has now\. The project octo-user/my-app exists on GitHub, and the setup's changes are in its main version there: https://github.com/octo-user/my-app/pull/1\$"
  grep -qxF "    the copy: $(cat "$d/merge-sha")" "$d/err" && grep -qxF '    main on GitHub: 2222222222222222222222222222222222222222' "$d/err" \
    || { cat "$d/err" >&2; die "both versions are not below"; }
  expect_continue_command "$d" " --resume"
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on to the report"
}

# finish_hook <dir> <mode>: the fake git of <dir> runs this before each
# call: on the update of main (a call with the word pull) it fails as git
# does when GitHub cannot be reached (offline), or it leaves a new file
# in the copy and lets the update run (stray).
finish_hook() {
  local text
  IFS= read -r -d '' text <<HOOK || true
case " \$* " in *" pull "*) ;; *) exit 0 ;; esac
case "$2" in
  offline) echo "fatal: unable to access 'https://github.com/octo-user/my-app.git/': Could not resolve host: github.com" >&2; exit 128 ;;
  stray) echo "left here" >"$1/cwd/my-app/stray.txt" ;;
esac
HOOK
  write_stand_in "$1/push-hook" "$text"
}

test_a_failed_update_of_the_copy_stops_with_gits_text_below() {
  # #158 review, finding 1: step 18's update of main fails (gh did not
  # switch the copy, so the script's own update is the only one).
  local d
  d="$(tmpdir)"
  working_git "$d"
  finish_hook "$d" offline
  export STUB_GH_MERGE_LOCAL=no
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_MERGE_LOCAL
  expect_rc 1 "$d"
  expect_err_shape "$d" "git could not bring the copy of the project on this computer, in \./my-app, up to date with the main version on GitHub\. The project octo-user/my-app exists on GitHub, and the setup's changes are in its main version there: https://github.com/octo-user/my-app/pull/1\$"
  sed -n 2p "$d/err" | grep -F 'connected to the internet' >/dev/null || { cat "$d/err" >&2; die "the next action is not to check the connection"; }
  grep -qxF "    fatal: unable to access 'https://github.com/octo-user/my-app.git/': Could not resolve host: github.com" "$d/err" \
    || { cat "$d/err" >&2; die "git's text is not below"; }
  expect_continue_command "$d" " --resume"
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on to the report"
}

test_a_copy_with_changes_not_saved_after_the_update_stops() {
  # #158 review, finding 1: after the update the copy must have nothing
  # unsaved (spec step 18); a file left in it is named below the stop.
  local d
  d="$(tmpdir)"
  working_git "$d"
  finish_hook "$d" stray
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "The copy of the project on this computer, in \./my-app, has changes that are not saved after the update\. The project octo-user/my-app exists on GitHub"
  grep -qxF '    ?? stray.txt' "$d/err" || { cat "$d/err" >&2; die "the file is not named below"; }
  expect_continue_command "$d" " --resume"
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on to the report"
}

test_gh_pr_merge_may_not_ask_at_the_terminal() {
  # #158 review, note 2: gh pr merge runs git in the copy; git may not ask
  # for a name and password at the terminal there.
  local d
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  [ "$(cat "$d/merge-prompt")" = 0 ] || { cat "$d/merge-prompt" >&2; die "gh pr merge ran with GIT_TERMINAL_PROMPT not 0"; }
}

test_an_id_of_the_new_main_that_is_not_one_stops_before_the_finish() {
  # #158 review, note 4: GitHub says the change was added but gives no
  # usable id of the new main: the script stops, and does not update the
  # copy against it.
  local d
  d="$(tmpdir)"
  export STUB_GH_MERGED_SHA="not-an-id"
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_MERGED_SHA
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub says the proposed change was added to the main version, but it did not give the id of the new main version, so the script cannot check the copy on this computer against it\. "
  # #158 review, round 2, note 1 (wording): the note on what exists says
  # the change is in main, not still proposed.
  sed -n 1p "$d/err" | grep -F "the setup's changes are in its main version there" >/dev/null || { cat "$d/err" >&2; die "the note on what exists is stale"; }
  ! sed -n 1p "$d/err" | grep -F "are proposed there" >/dev/null || { cat "$d/err" >&2; die "the stop says the change is both added and proposed"; }
  grep -qxF '    GitHub reports for the proposed change: true not-an-id' "$d/err" || { cat "$d/err" >&2; die "GitHub's answer is not below"; }
  expect_continue_command "$d" " --resume"
  expect_no_out "$d" "==> Updating the copy on this computer"
}

test_a_pending_run_of_build_is_waited_for_even_next_to_a_failed_one() {
  # #158 review, note 4: two pull_request runs of build, a new one still
  # pending listed before an old one that failed (as after a re-run): the
  # script waits, and goes on once build passes.
  local d
  d="$(tmpdir)"
  echo 1 >"$d/build-mixed"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  [ "$(cat "$d/sleep.log")" = 15 ] || { cat "$d/sleep.log" >&2; die "not one wait of 15 seconds"; }
  expect_after_proposing "$d" "$CHECKS_CALL" "${END_CALLS[@]}"
}

test_the_report_says_what_was_made_and_the_one_thing_to_do_next() {
  # Spec step 19: the project's page, the copy, the proposed change, the
  # pack and the licence; the protection as GitHub read it back; the
  # parts left for Clead; the next step. In plain words, at the end.
  local d
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  sed -n "/^$FINISHED\$/,\$p" "$d/out" >"$d/report"
  cat >"$d/want" <<'TEXT'
The setup is finished.
    The project on GitHub: https://github.com/octo-user/my-app
    Its copy on this computer: ./my-app
    The proposed change with the setup: https://github.com/octo-user/my-app/pull/1
    Language pack: python
    Licence: mit, in the name of Ada L
The protection of the main version, as GitHub reports it:
    - every change comes as a proposed change; approvals needed before one is added: 0
    - a change is added only after these checks pass: build
    - these rules apply to the project's admins too
    - nobody may overwrite the history of the main version or delete it
These parts of the project are left for your first session with Clead (Claude, the project's Tech Owner), who writes them with you:
  - the name of the first phase, [PHASE NAME], in docs/BACKLOG.md;
  - the goals, [Goal], and the rest of memory/project.md;
  - the questions in square brackets in the sections of docs/SPEC.md;
  - memory/context.md;
  - STATUS.md, where the project stands and what comes next.
TEXT
  # The blank line above "What to do next" sets it apart from the report
  # (finding 8: user interaction after one blank line); the line after it
  # follows straight on.
  printf '%s\n' "" "$WHAT_NEXT" "$ASK_CLEAD" >>"$d/want"
  expect_same "the report" "$d/want" "$d/report"
  [ -z "$(awk '{print NR ": " $0}' "$d/report" | banned_hits)" ] || { cat "$d/report" >&2; die "banned word in the report"; }
  [ ! -s "$d/err" ] || { cat "$d/err" >&2; die "a run that went through wrote to stderr"; }
  # No licence, and the web pack with its deploy files.
  d="$(tmpdir)"
  fake_tool "$d" npm 10.0.0
  setup_run "$d" --non-interactive --yes --license none --pack web --with-deploy
  expect_rc 0 "$d"
  grep -qxF '    Licence: none, so no licence file' "$d/out" || { cat "$d/out" >&2; die "none: the licence line"; }
  grep -qxF '    Language pack: web, with the files that publish the website' "$d/out" || { cat "$d/out" >&2; die "web: the pack line"; }
}

# last_two <dir>: the last two lines of its out, as "<line>|<line>".
last_two() { tail -n 2 "$1/out" | tr -d '\r' | paste -sd '|' -; }

test_every_report_ends_with_the_next_step_and_then_the_line_on_asking_clead() {
  # End-to-end run 1, finding 10: the next step says to create a Claude
  # Project and chat inside it, and the very last line printed says Clead
  # is there to help. The same two lines end a new setup, a --resume of a
  # project the script set up, and a --resume of a project set up by hand
  # (the "set up already" ending), with nothing on stderr after them.
  local d want
  want="$WHAT_NEXT|$ASK_CLEAD"
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  [ "$(last_two "$d")" = "$want" ] || { cat "$d/out" >&2; die "new setup: the report does not end with the next step and the line on asking Clead"; }
  [ ! -s "$d/err" ] || { cat "$d/err" >&2; die "new setup: stderr after the report"; }
  setup_run "$d" --non-interactive --yes --resume
  expect_rc 0 "$d"
  [ "$(last_two "$d")" = "$want" ] || { cat "$d/out" >&2; die "resumed, set up already: the report does not end with the two lines"; }
  [ ! -s "$d/err" ] || { cat "$d/err" >&2; die "resumed: stderr after the report"; }
  d="$(tmpdir)"
  hand_made_project "$d"
  export STUB_GH_EXISTING=octo-user/my-app
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING
  expect_rc 0 "$d"
  [ "$(last_two "$d")" = "$want" ] || { cat "$d/out" >&2; die "hand-made, set up already: the report does not end with the two lines"; }
  [ "$(grep -cxF "$ASK_CLEAD" "$d/out")" -eq 1 ] || { cat "$d/out" >&2; die "the line on asking Clead is not printed once"; }
  [ -z "$(printf '%s\n' "$WHAT_NEXT" "$ASK_CLEAD" | banned_hits)" ] || die "a banned word in the last two lines"
}

test_a_run_that_stops_does_not_print_the_next_step_or_the_line_on_asking_clead() {
  # Error path: the two closing lines belong to a finished setup only; a
  # stop has its own "What to do next".
  local d
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  setup_run "$d" --non-interactive --yes --private
  unset STUB_GH_PROTECT_FAIL
  expect_rc 3 "$d"
  expect_no_out "$d" "$ASK_CLEAD"
  expect_no_out "$d" "create a Claude Project"
  ! grep -qF "$ASK_CLEAD" "$d/err" || { cat "$d/err" >&2; die "the stop printed the line on asking Clead"; }
}

test_the_next_step_is_one_text_for_both_endings() {
  # The new-setup and the set-up-already endings print the next step from
  # one function, so the two cannot drift apart again.
  local a b n
  a="$( load_script; IN_OWNER=octo-user IN_NAME=my-app CHANGE_ADDED=""; say_what_next )"
  b="$( load_script; IN_OWNER=octo-user IN_NAME=my-app CHANGE_ADDED=1; say_what_next )"
  [ "$a" = "$(printf '%s\n%s' "$WHAT_NEXT" "$ASK_CLEAD")" ] || { printf '%s\n' "$a" >&2; die "say_what_next does not print the next step and then the line on asking Clead"; }
  [ "$a" = "$b" ] || die "the next step differs between the two endings"
  n="$(grep -c 'What to do next: in the Claude app' "$SCRIPT" || true)"
  [ "$n" -eq 1 ] || die "the next step is written $n times in the script, want 1"
  n="$(grep -c 'say_what_next$' "$SCRIPT" || true)"
  [ "$n" -eq 1 ] || die "say_what_next is called $n times, want once, at the end of report"
}

test_the_jq_expressions_read_githubs_documented_answers() {
  # The stub gh prints what the script's --jq expressions would print, so
  # here the expressions themselves run on answers shaped as GitHub's REST
  # docs show them, with jq (gh's --jq is gojq; the features used, \( ),
  # //, join and select, are the same in both). Skipped where jq is not
  # installed. Also: the script's expressions and step 16 body are the
  # ones this file names.
  local d
  # This file defines the same names, so they are unset first: only the
  # script's own values can make the comparison pass.
  ( t1="$BUILD_JQ" t2="$READBACK_JQ" t3="$MERGED_JQ" t4="$REQUIRE_BODY"
    unset BUILD_JQ READBACK_JQ MERGED_JQ REQUIRE_BODY
    load_script
    [ "${BUILD_JQ-}" = "$t1" ] && [ "${READBACK_JQ-}" = "$t2" ] && [ "${MERGED_JQ-}" = "$t3" ] && [ "${REQUIRE_BODY-}" = "$t4" ] ) \
    || die "the script's expressions or step 16 body are not the ones the tests name"
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is not installed: the expressions were not run"
    return 0
  fi
  d="$(tmpdir)"
  # jq.exe on Windows ends each line with CR LF (its manual: use -b there,
  # which older jq lacks); gh --jq does not, and the script drops CRs
  # from what it reads anyway. So CRs are dropped here before comparing.
  jq_r() { jq -r "$@" | tr -d '\r'; }
  # gh pr checks --json name,bucket,event: an array of checks; another
  # workflow's check (review) is left out.
  printf '%s\n' '[{"name":"build","bucket":"pass","event":"push"},{"name":"review","bucket":"fail","event":"pull_request"},{"name":"build","bucket":"pending","event":"pull_request"}]' >"$d/checks.json"
  [ "$(jq_r "$BUILD_JQ" "$d/checks.json")" = "$(printf '%s\n' 'push pass' 'pull_request pending')" ] || { jq_r "$BUILD_JQ" "$d/checks.json" >&2; die "the checks expression"; }
  # GET .../branches/main/protection, as the REST doc's example has it
  # (restrictions left out, as for a project of a personal account).
  cat >"$d/protection.json" <<'JSON'
{"url":"https://api.github.com/repos/octo-user/my-app/branches/main/protection",
 "required_status_checks":{"url":"https://api.github.com/repos/octo-user/my-app/branches/main/protection/required_status_checks","strict":false,"contexts":["build"],"contexts_url":"https://api.github.com/repos/octo-user/my-app/branches/main/protection/required_status_checks/contexts","checks":[{"context":"build","app_id":15368}]},
 "required_pull_request_reviews":{"url":"https://api.github.com/repos/octo-user/my-app/branches/main/protection/required_pull_request_reviews","dismiss_stale_reviews":false,"require_code_owner_reviews":false,"require_last_push_approval":false,"required_approving_review_count":0},
 "required_signatures":{"url":"https://api.github.com/repos/octo-user/my-app/branches/main/protection/required_signatures","enabled":false},
 "enforce_admins":{"url":"https://api.github.com/repos/octo-user/my-app/branches/main/protection/enforce_admins","enabled":true},
 "required_linear_history":{"enabled":false},"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false},
 "block_creations":{"enabled":false},"required_conversation_resolution":{"enabled":false},"lock_branch":{"enabled":false},"allow_fork_syncing":{"enabled":false}}
JSON
  [ "$(jq_r "$READBACK_JQ" "$d/protection.json")" = "$(printf '%s\n' contexts=build strict=false enforce_admins=true approvals=0 restrictions=null allow_force_pushes=false allow_deletions=false)" ] \
    || { jq_r "$READBACK_JQ" "$d/protection.json" >&2; die "the read-back expression on the documented answer"; }
  # Step 3's protection, before build is required: no check, and no error.
  printf '%s\n' '{"enforce_admins":{"enabled":true},"required_pull_request_reviews":{"required_approving_review_count":0},"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false}}' >"$d/step3.json"
  [ "$(jq_r "$READBACK_JQ" "$d/step3.json" | sed -n 1,2p)" = "$(printf '%s\n' contexts= strict=null)" ] || { jq_r "$READBACK_JQ" "$d/step3.json" >&2; die "the read-back expression with no required check"; }
  # GET .../pulls/N after the merge.
  printf '%s\n' '{"number":1,"state":"closed","merged":true,"merge_commit_sha":"6dcb09b5b57875f334f61aebed695e2e4193db5e"}' >"$d/pull.json"
  [ "$(jq_r "$MERGED_JQ" "$d/pull.json")" = 'true 6dcb09b5b57875f334f61aebed695e2e4193db5e' ] || die "the merged expression"
}

# ---------- resume, failures and private projects (S15) ----------
# --resume works out where the setup stopped from GitHub and the copy on
# this computer, never from a file of its own (spec, "Existing repo"):
# the template's files only (continue at step 3), a change saved in the
# copy but not sent (13), sent but not proposed (14), proposed (15), or
# already added (re-check the protection and report). Nothing is made
# twice: no second project, line of work, proposed change or saved
# change. It refuses a project not made by this version of the
# bootstrapper (decision of 2026-10-02: an older version's project is
# refused, with a fresh project as the next action), and a copy with
# changes not saved (the script never discards work). An unexpected
# failure, or Ctrl-C, says what exists and shows the command to continue;
# a folder the script made for the copy is removed when the copy fails.
# A private project on a plan without protection: --allow-unprotected
# goes on without it and writes that decision into the project, and the
# script makes the project public only after its own yes at the terminal.

# calls_count <dir>: how many gh calls are logged so far.
calls_count() { if [ -f "$1/gh.log" ]; then grep -c . "$1/gh.log"; else echo 0; fi; }

# calls_since <dir> <n>: the gh calls after the first <n>, written as
# calls_from_create writes them.
calls_since() {
  tail -n +"$(($2 + 1))" "$1/gh.log" | awk -F'\t' '$4 == "--help" { next } { out = $2; for (i = 3; i <= NF; i++) out = out " " ($(i - 1) == "--body-file" ? "<file>" : ($(i - 1) == "--match-head-commit" ? "<sha>" : $i)); print out }'
}

# again <dir> [options...]: runs the script again, as the user would: the
# command the last run showed (to continue, or to start again), word for
# word (since r2l mostly the short one, which reads the saved file), with
# the options given added at its end. The last run's output
# is kept in out.prev and err.prev.
again() {
  local d="$1" line
  shift
  line="$(grep -A1 -xE 'To continue the setup, run this command:|To start again, run this command:' "$d/out" | tail -1)"
  line="$(strip_any_cd "$line")"
  case "$line" in
    "    bash "*) ;;
    *) cat "$d/out" "$d/err" >&2; die "the last run showed no command to run again" ;;
  esac
  eval "CMD_ARGS=(${line#    bash })"
  CMD_ARGS=("${CMD_ARGS[@]:1}")
  mv "$d/out" "$d/out.prev"
  mv "$d/err" "$d/err.prev"
  whole "$d" "${CMD_ARGS[@]}" "$@"
}

# seed_existing <dir> <OWNER/NAME> <files>: a project GitHub has that the
# script did not create (as with "Use this template"): a bare repo
# remotes/OWNER/NAME.git next to the log, whose main holds <files> as
# one change. The test lists it in STUB_GH_EXISTING itself. Each further
# path is stored as it is, carriage returns kept: "<path> -text" in the
# seed's .git/info/attributes wins over the template's .gitattributes
# (eol=lf) and over a core.autocrlf of the computer.
seed_existing() {
  local bare="$1/remotes/$2.git" src="$3" w p
  shift 3
  w="$(mktemp -d "$WORK/seed.XXXXXX")"
  mkdir -p "$bare"
  in_git -c init.defaultBranch=main init -q --bare "$bare"
  cp -R "$src/." "$w/"
  in_git -c init.defaultBranch=main init -q "$w"
  # "for p do": no "$@" that bash 3.2 with set -u could call unbound.
  for p do
    mkdir -p "$w/.git/info"
    printf '%s -text\n' "$p" >>"$w/.git/info/attributes"
  done
  in_git -C "$w" add -A
  in_git -C "$w" -c user.name=GitHub -c user.email=noreply@github.com commit -q -m "Initial commit"
  in_git -C "$w" push -q "$bare" HEAD:main 2>/dev/null
  rm -rf "$w"
}

# expect_one_of_each <dir>: one project, one proposed change, and main on
# "GitHub" is the template's change and one added change; the copy is on
# main at that change, with nothing unsaved and no line of work left.
expect_one_of_each() {
  local d="$1" bare c
  bare="$(bare_of "$d")"
  c="$(copy_of "$d")"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "it did not go through to the report"; }
  [ "$(grep -c '	repo	create	octo-user' "$d/gh.log" || true)" -le 1 ] || die "the project was created twice"
  [ "$(grep -cx -- ----- "$d/pr-bodies")" -eq 1 ] || die "not exactly one proposed change"
  [ "$(in_git --git-dir="$bare" rev-list --count main)" -eq 2 ] || die "main does not have exactly one change after the template's"
  ! in_git --git-dir="$bare" rev-parse -q --verify refs/heads/bootstrap-setup >/dev/null || die "bootstrap-setup is still on GitHub"
  [ "$(in_git -C "$c" symbolic-ref --short HEAD)" = main ] || die "the copy is not on main"
  [ "$(in_git -C "$c" rev-parse HEAD)" = "$(in_git --git-dir="$bare" rev-parse main)" ] || die "the copy is not at main"
  [ -z "$(in_git -C "$c" status --porcelain --untracked-files=all)" ] || die "the copy has something unsaved"
  ! in_git -C "$c" rev-parse -q --verify refs/heads/bootstrap-setup >/dev/null || die "the copy still has bootstrap-setup"
}

# saved_changes <dir>: how many times the script saved the setup's change
# (the fake git's log).
saved_changes() { grep -c ' commit -q -m Set up my-app$' "$1/tools.log" || true; }

test_resume_continues_a_project_with_only_the_template_from_step_3() {
  # Stopped at step 3 (no protection on the plan): the project has only
  # the template's files and there is no copy yet.
  local d n
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  setup_run "$d" --non-interactive --yes --private
  unset STUB_GH_PROTECT_FAIL
  expect_rc 3 "$d"
  n="$(calls_count "$d")"
  again "$d"
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The project has only the bootstrapper's files, and there is no copy of it on this computer yet: the setup continues by protecting its main version."
  expect_resume_steps "$d" "done next - - - -"
  ! calls_since "$d" "$n" | grep '^repo create ' >/dev/null || die "a second project was created"
  calls_since "$d" "$n" | grep -xF "$PROTECT_CALL" >/dev/null || die "the protection was not asked for again"
  calls_since "$d" "$n" | grep -xF "$CLONE_CALL" >/dev/null || die "no copy was made"
  expect_one_of_each "$d"
  [ "$(saved_changes "$d")" -eq 1 ] || die "the change was not saved once"
  # It works out the state from GitHub: the project's visibility, its
  # files on main, its proposed changes and its line of work.
  for c in "api -i repos/octo-user/my-app --jq .private" \
    "api -i -H Accept: application/vnd.github.raw+json repos/octo-user/my-app/contents/CHANGELOG.md" \
    "api -i repos/octo-user/my-app/pulls?state=all&head=octo-user:bootstrap-setup --jq .[] | \"\\(.state) \\(.merged_at // \"-\") \\(.html_url)\"" \
    "api -i repos/octo-user/my-app/branches/bootstrap-setup --jq .commit.sha"; do
    calls_since "$d" "$n" | grep -xF "$c" >/dev/null || { calls_since "$d" "$n" >&2; die "not asked: $c"; }
  done
  # Stopped while GitHub was still copying the files: the same.
  d="$(tmpdir)"
  echo 9999 >"$d/main-missing"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  echo 0 >"$d/main-missing"
  again "$d"
  expect_rc 0 "$d"
  expect_one_of_each "$d"
}

test_resume_redoes_the_copys_steps_in_a_copy_with_nothing_saved_and_takes_another_licence() {
  # Stopped before the copy was changed (here the licence text GitHub no
  # longer has): --resume continues in the same copy, with the licence
  # given now (the next action of that stop), and makes no second copy.
  local d c
  d="$(tmpdir)"
  export STUB_GH_LICENSE_KNOWN=made-up-2.0
  setup_run "$d" --non-interactive --yes --license made-up-2.0
  unset STUB_GH_LICENSE_KNOWN
  expect_rc 1 "$d"
  expect_copy_untouched "$d"
  again "$d" --license mit
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The project has only the bootstrapper's files, and its copy on this computer has none of the setup's changes: the setup continues by protecting its main version, then uses that copy."
  expect_resume_steps "$d" "done next done - - -"
  [ "$(grep -c '	repo	clone	' "$d/gh.log")" -eq 1 ] || die "a second copy was made"
  expect_one_of_each "$d"
  c="$(copy_of "$d")"
  grep -qF 'MIT License' "$c/LICENSE" || die "the licence given at the resume was not used"
  grep -qxF -- '- Licence: mit.' "$c/CHANGELOG.md" || die "CHANGELOG.md does not name the licence given at the resume"
}

test_resume_sends_a_saved_change_that_was_not_sent() {
  local d n sha
  d="$(tmpdir)"
  working_git "$d"
  failing_push "$d" other
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  sha="$(in_git -C "$(copy_of "$d")" rev-parse refs/heads/bootstrap-setup)"
  failing_push "$d" ok 0
  n="$(calls_count "$d")"
  again "$d"
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The setup's changes are saved in the copy on this computer but not sent to GitHub: the setup continues by sending them."
  expect_resume_steps "$d" "done done done done next -"
  [ "$(saved_changes "$d")" -eq 1 ] || die "the change was saved again"
  [ "$(cat "$d/merged-head")" = "$sha" ] || die "what was added is not the change saved before"
  ! calls_since "$d" "$n" | grep -E '^repo (create|clone) ' >/dev/null || die "the project or the copy was made again"
  ! calls_since "$d" "$n" | grep -xF "$PROTECT_CALL" >/dev/null || [ "$(grep -c . "$d/protection-bodies")" -eq 2 ] || die "the protection was set again before the required check"
  expect_one_of_each "$d"
}

test_resume_proposes_a_sent_change_that_was_not_proposed() {
  local d n
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_PR_FAIL=broken
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_PR_FAIL
  expect_rc 1 "$d"
  n="$(calls_count "$d")"
  again "$d"
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The setup's changes are on GitHub, on the line of work bootstrap-setup, but not proposed: the setup continues by proposing them."
  expect_resume_steps "$d" "done done done done next -"
  [ "$(calls_since "$d" "$n" | grep -c '^pr create ')" -eq 1 ] || die "not proposed once"
  [ "$(saved_changes "$d")" -eq 1 ] || die "the change was saved again"
  [ "$(grep -c ' push origin bootstrap-setup$' "$d/tools.log")" -eq 1 ] || die "the change was sent again"
  expect_one_of_each "$d"
}

test_resume_waits_for_build_on_the_proposed_change_that_is_there() {
  # Stopped at step 15 (build failed, then fixed and run again on GitHub):
  # no second proposed change; also with the copy moved away (a new copy
  # is made, on the line of work GitHub has), and from inside the copy
  # with --dir . (#152 review).
  local d n how
  for how in copy moved inside; do
    d="$(tmpdir)"
    working_git "$d"
    export STUB_GH_BUILD="pull_request fail"
    setup_run "$d" --non-interactive --yes
    unset STUB_GH_BUILD
    expect_rc 1 "$d"
    n="$(calls_count "$d")"
    case "$how" in
      copy) again "$d" ;;
      moved) mv "$(copy_of "$d")" "$d/elsewhere"; again "$d" ;;
      inside) RUN_CWD="$(copy_of "$d")" again "$d" --dir . ;;
    esac
    expect_rc 0 "$d"
    expect_out "$d" "    Done. The setup's changes are proposed on GitHub, at https://github.com/octo-user/my-app/pull/1: the setup continues by waiting for the check build."
    case "$how" in
      moved) expect_resume_steps "$d" "done done next done - -" ;;
      *) expect_resume_steps "$d" "done done done done next -" ;;
    esac
    ! calls_since "$d" "$n" | grep '^pr create ' >/dev/null || die "$how: a second proposed change"
    calls_since "$d" "$n" | grep -xF "$CHECKS_CALL" >/dev/null || die "$how: build was not looked at"
    case "$how" in
      moved) calls_since "$d" "$n" | grep -xF "$CLONE_CALL" >/dev/null || die "moved: no new copy" ;;
      *) ! calls_since "$d" "$n" | grep '^repo clone ' >/dev/null || die "$how: a second copy" ;;
    esac
    [ "$(saved_changes "$d")" -eq 1 ] || die "$how: the change was saved again"
    expect_one_of_each "$d"
  done
}

# expect_nothing_changed_since <dir> <n>: no gh call after the first <n>
# makes or changes anything.
expect_nothing_changed_since() {
  ! calls_since "$1" "$2" | grep -E '^(repo create|repo clone|repo edit|pr create|pr merge) |-X PUT' >/dev/null \
    || { calls_since "$1" "$2" >&2; die "something was changed"; }
}

test_resume_past_the_pack_step_takes_the_publishing_choice_from_the_project() {
  # End-to-end run 1 (repeat), r1e: once the pack's files are laid out,
  # the publishing files are in the setup's change or not. A resumed run
  # takes that from the change (in the copy, or on GitHub when there is
  # no copy) and asks nothing; an option that says otherwise is refused
  # before anything changes. git, the script's and the stub gh's, gets
  # its arguments as from Git Bash, where a <rev>:.github/... is
  # rewritten before git sees it (#239).
  local d n how
  for how in copy moved; do
    d="$(tmpdir)"
    working_git "$d"
    : >"$d/git-bash-paths"
    git_bash_git "$d"
    export STUB_GIT="$d/git-bash-git"
    fake_tool "$d" npm 10.0.0
    export STUB_GH_BUILD="pull_request fail"
    setup_run "$d" --non-interactive --yes --pack web --with-deploy
    unset STUB_GH_BUILD
    expect_rc 1 "$d"
    [ "$how" != moved ] || mv "$(copy_of "$d")" "$d/elsewhere"
    n="$(calls_count "$d")"
    setup_run "$d" --yes --resume --pack web --without-deploy
    expect_rc 2 "$d"
    grep -qE -- '^    - --without-deploy: .{10,}' "$d/err" || { cat "$d/err" >&2; die "$how: a no that contradicts the change is not refused with its option"; }
    expect_nothing_changed_since "$d" "$n"
    # With no copy, the change on GitHub is read.
    if [ "$how" = moved ]; then
      calls_since "$d" "$n" | grep -xF 'api -i -H Accept: application/vnd.github.raw+json repos/octo-user/my-app/contents/.github/workflows/deploy.yml?ref=bootstrap-setup' >/dev/null \
        || { calls_since "$d" "$n" >&2; die "moved: the setup's change on GitHub was not read"; }
    fi
    # No option, and no answers on stdin: nothing is asked.
    setup_run "$d" --yes --resume --pack web
    expect_rc 0 "$d"
    ! grep -qF 'Add the publishing files' "$d/out" || { cat "$d/out" >&2; die "$how: the publishing question was asked"; }
    grep -qxF '    Language pack: web, with the files that publish the website' "$d/out" || { cat "$d/out" >&2; die "$how: the report does not name the publishing files"; }
    expect_one_of_each "$d"
  done
  # Without the publishing files: a yes is refused, no option takes the no.
  d="$(tmpdir)"
  working_git "$d"
  : >"$d/git-bash-paths"
  git_bash_git "$d"
  export STUB_GIT="$d/git-bash-git"
  fake_tool "$d" npm 10.0.0
  export STUB_GH_BUILD="pull_request fail"
  setup_run "$d" --non-interactive --yes --pack web
  unset STUB_GH_BUILD
  expect_rc 1 "$d"
  n="$(calls_count "$d")"
  setup_run "$d" --yes --resume --pack web --with-deploy
  expect_rc 2 "$d"
  grep -qE -- '^    - --with-deploy: .{10,}' "$d/err" || { cat "$d/err" >&2; die "a yes that contradicts the change is not refused with its option"; }
  expect_nothing_changed_since "$d" "$n"
  setup_run "$d" --yes --resume --pack web
  expect_rc 0 "$d"
  ! grep -qF 'Add the publishing files' "$d/out" || { cat "$d/out" >&2; die "the publishing question was asked"; }
  grep -qxF '    Language pack: web' "$d/out" || { cat "$d/out" >&2; die "the report does not name the pack without the publishing files"; }
  [ ! -e "$(copy_of "$d")/.github/workflows/deploy.yml" ] || die "the publishing files were added"
  expect_one_of_each "$d"
}

test_resume_before_the_pack_step_asks_the_publishing_question_once_the_state_is_known() {
  # A --resume typed without the answer, in a project with only the
  # bootstrapper's files: the pack is not laid out yet, so the choice is
  # still open. It is asked after the state is worked out, not before.
  local d
  d="$(tmpdir)"
  working_git "$d"
  fake_tool "$d" npm 10.0.0
  export STUB_GH_PROTECT_FAIL=plan
  setup_run "$d" --non-interactive --yes --private --pack web
  unset STUB_GH_PROTECT_FAIL
  expect_rc 3 "$d"
  printf 'yes\n' >"$d/in"
  setup_run "$d" --yes --private --resume --pack web
  expect_rc 0 "$d"
  [ "$(grep -c '^Add the publishing files? (yes or no) \[no\]: ' "$d/out")" -eq 1 ] || { cat "$d/out" >&2; die "the publishing question was not asked once"; }
  [ "$(grep -n '^Add the publishing files' "$d/out" | head -1 | cut -d: -f1)" -gt "$(line_of "$d" "==> Working out where the setup stopped, from GitHub and from the copy on this computer")" ] \
    || { cat "$d/out" >&2; die "the publishing question came before the state was worked out"; }
  [ -e "$(copy_of "$d")/.github/workflows/deploy.yml" ] || die "the publishing files were not added after a yes"
  expect_one_of_each "$d"
}

test_ctrl_c_says_what_exists_and_the_resume_finishes_without_duplicates() {
  # Spec Done when 4: an interrupted run (here Ctrl-C during the wait for
  # build) completes with --resume, with no duplicate proposed change or
  # saved change.
  local d
  # A shell started with Ctrl-C ignored (such as a background job) cannot
  # take it: the case is skipped there.
  # (Asked of a shell started here, as bash 3.2 does not list an ignored
  # signal in trap -p.)
  [ "$("$BASH" -c 'trap "echo caught" INT; kill -INT $$; sleep 1' 2>/dev/null)" = caught ] \
    || { echo "note: Ctrl-C is ignored in this shell; the Ctrl-C case was not run"; return 0; }
  d="$(tmpdir)"
  printf '%s\n' "$STAND_IN_SHEBANG" 'kill -INT "$PPID"' >"$d/interrupt"
  chmod +x "$d/interrupt"
  echo 1 >"$d/build-pending"
  export BOOTSTRAP_SLEEP="$d/interrupt"
  setup_run "$d" --non-interactive --yes
  export BOOTSTRAP_SLEEP="$WORK/refuse/sleep"
  expect_rc 130 "$d"
  expect_err_shape "$d" "The script was stopped before it finished\. The project octo-user/my-app exists on GitHub, and the setup's changes are proposed there: https://github.com/octo-user/my-app/pull/1\$"
  expect_continue_command "$d" " --resume"
  ! grep -qxF "$FINISHED" "$d/out" || die "it went on after Ctrl-C"
  again "$d"
  expect_rc 0 "$d"
  [ "$(saved_changes "$d")" -eq 1 ] || die "the change was saved again"
  expect_one_of_each "$d"
}

# advance_again <dir> [options...]: runs the command shown before the
# first change (advance_command), word for word, as again does for the
# command of a stop. The last run's output is kept in out.prev and err.prev.
advance_again() {
  local d="$1" line
  shift
  advance_command "$d" >/dev/null
  # As the user would: the command as shown, short or long (its cd to the
  # run's folder checked and taken off: whole runs there).
  line="$(strip_any_cd "$(grep -A1 -xF "$ADVANCE_INTRO" "$d/out" | sed -n 2p)")"
  line="${line#    }"
  case "$line" in
    "bash "*) ;;
    *) cat "$d/out" "$d/err" >&2; die "no command to continue was shown before the first change" ;;
  esac
  eval "CMD_ARGS=(${line#bash })"
  CMD_ARGS=("${CMD_ARGS[@]:1}")
  mv "$d/out" "$d/out.prev"
  mv "$d/err" "$d/err.prev"
  whole "$d" "${CMD_ARGS[@]}" "$@"
}

test_a_stop_that_runs_no_trap_still_leaves_the_command_to_continue() {
  # End-to-end run 1, finding 6: Ctrl-C right after "Creating the project"
  # in Git Bash ended the script with no stop message, so no command to
  # continue (finding 7: the --resume typed by hand asked every question
  # again). The stub ends the script there with SIGKILL, which no trap
  # sees; the command shown before the first change must be enough.
  local d cmd
  # The project was made before the stop: the command continues it and
  # asks nothing again but Proceed?.
  d="$(tmpdir)"
  working_git "$d"
  use_built "$d"
  export STUB_GH_CREATE_FAIL=killed-after-made
  printf '%s\n' "${ANSWERS_IN[@]}" yes >"$d/in"
  whole "$d"
  unset STUB_GH_CREATE_FAIL
  [ "$RC" -ne 0 ] || die "the stub did not stop the script"
  ! grep -q 'run this command:$' "$d/out" || { cat "$d/out" >&2; die "a stop message was shown (the stop is meant to run no trap)"; }
  cmd="$(advance_command "$d")"
  case "$cmd" in
    "bash "*" --resume$CARRIED") ;;
    *) die "the command does not continue with every answer: $cmd" ;;
  esac
  # #267 review, N1: the file saved right after the yes (the stop ran no
  # trap, so nothing wrote it again) holds --resume and every typed answer.
  expect_again_file "$d" --resume --owner octo-user --name my-app --project-name my-app --description "Lends tools." \
    --po-name "Octo User" --pack python --public --license none --dir ./my-app --git-name "Test Person" \
    --git-email test@example.com
  printf 'yes\n' >"$d/in"
  advance_again "$d"
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The project has only the bootstrapper's files, and there is no copy of it on this computer yet: the setup continues by protecting its main version."
  [ "$(grep -c 'Proceed? (yes or no) \[no\]: ' "$d/out")" -eq 1 ] || { cat "$d/out" >&2; die "Proceed? not asked once"; }
  ! grep -qE '^(Project name|Description|Language pack|Licence|Folder|Your name for git)' "$d/out" || { cat "$d/out" >&2; die "a question was asked again"; }
  expect_one_of_each "$d"
  # The stop came before GitHub made the project: the command says there
  # is no project to continue and shows the command to start again,
  # without --resume, which then sets the project up.
  d="$(tmpdir)"
  export STUB_GH_CREATE_FAIL=killed
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_CREATE_FAIL
  [ "$RC" -ne 0 ] || die "killed: the stub did not stop the script"
  advance_again "$d"
  expect_rc 3 "$d"
  expect_out "$d" "There is no project named octo-user/my-app on GitHub to continue."
  expect_out "$d" "If the setup stopped before it created the project, or to set up a new project with this name, start the script again with the command shown below, which has no --resume."
  shown_after "$d" 'To start again, run this command:' >"$d/cmd"
  grep -q '^    bash ' "$d/cmd" && ! grep -qF -- '--resume' "$d/cmd" || { cat "$d/out" >&2; die "killed: no command to start again without --resume"; }
  again "$d"
  expect_rc 0 "$d"
  # The stopped run's create call is in gh.log but made nothing (the file
  # "created" lists what the stub made), so the project is made once.
  [ "$(grep -cxF octo-user/my-app "$d/created")" -eq 1 ] || die "killed: the project was not made exactly once"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "killed: the new run did not go through"; }
}

test_a_resume_shows_the_command_to_continue_before_its_first_change() {
  local d n cmd
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_PR_FAIL=broken
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_PR_FAIL
  expect_rc 1 "$d"
  n="$(calls_count "$d")"
  # The resumed run saves its answers before its first change (seen here
  # through a stand-in for gh that stops on the proposal), and the run
  # that goes through removes them; the command is the short one.
  again "$d"
  expect_rc 0 "$d"
  cmd="$(grep -A1 -xF "$ADVANCE_INTRO" "$d/out" | sed -n 2p | sed 's/^    //')"
  [ "$cmd" = "$(start_cd_of "$d")bash $(shown_script_of "$d") --again" ] || die "not the short command: $cmd"
  [ ! -e "$(again_file_of "$d")" ] || die "the saved answers were not removed at the end"
  # Shown after the step that works out the state, before proposing.
  [ "$(line_of "$d" "$ADVANCE_INTRO")" -gt "$(line_of "$d" "==> Working out where the setup stopped, from GitHub and from the copy on this computer")" ] \
    && [ "$(line_of "$d" "$ADVANCE_INTRO")" -lt "$(line_of "$d" "==> Proposing the setup's changes on GitHub, where the project's checks run on them")" ] \
    || { cat "$d/out" >&2; die "the command is not between the state step and the first change"; }
  expect_no_out "$d" "If the project was not created yet"
  # A --resume dry run changes nothing, so it shows no command.
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_PR_FAIL=broken
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_PR_FAIL
  again "$d" --dry-run
  expect_rc 0 "$d"
  expect_no_out "$d" "$ADVANCE_INTRO"
  # A --resume run answered no changes nothing either.
  printf 'no\n' >"$d/in"
  setup_run "$d" --resume
  expect_rc 1 "$d"
  expect_no_out "$d" "$ADVANCE_INTRO"
}

test_resume_of_a_finished_setup_only_checks_the_protection_and_reports() {
  local d n
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  n="$(calls_count "$d")"
  setup_run "$d" --non-interactive --yes --resume
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The project is set up already: the script only checks its protection, brings the copy on this computer up to date if there is one, and shows the report."
  expect_resume_steps "$d" "done done done done done next"
  ! calls_since "$d" "$n" | grep -E '^(repo create|repo clone|repo edit|pr create|pr merge) |-X PUT' >/dev/null || { calls_since "$d" "$n" >&2; die "something was changed"; }
  calls_since "$d" "$n" | grep -xF "$READBACK_CALL" >/dev/null || die "the protection was not read back"
  grep -qxF '    The proposed change with the setup: https://github.com/octo-user/my-app/pull/1' "$d/out" || { cat "$d/out" >&2; die "the report lacks the proposed change"; }
  expect_one_of_each "$d"
  # Protection that differs: the plain stop with the differences below,
  # and it does not speak of a change still to add.
  export STUB_GH_READBACK="contexts=;strict=null;enforce_admins=true;approvals=0;restrictions=null;allow_force_pushes=false;allow_deletions=false"
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_READBACK
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub does not report the protection of the main version with the rules the setup gives it\."
  grep -qxF '    contexts: expected build, GitHub reports ' "$d/err" || { cat "$d/err" >&2; die "the difference is not below"; }
  ! grep -qF 'did not add' "$d/err" || { cat "$d/err" >&2; die "the stop speaks of a change not added"; }
}

test_resume_after_the_change_was_added_brings_the_copy_up_to_date() {
  local d n
  d="$(tmpdir)"
  working_git "$d"
  finish_hook "$d" offline
  export STUB_GH_MERGE_LOCAL=no
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_MERGE_LOCAL
  expect_rc 1 "$d"
  rm "$d/push-hook"
  n="$(calls_count "$d")"
  again "$d"
  expect_rc 0 "$d"
  ! calls_since "$d" "$n" | grep '^pr merge ' >/dev/null || die "the change was added again"
  expect_one_of_each "$d"
}

test_resume_refuses_a_project_from_another_version_or_not_from_the_bootstrapper() {
  # Decision of 2026-10-02: a project stamped by an older version is
  # refused, and the next action is a fresh project. One without the
  # bootstrapper's stamp (or without CHANGELOG.md) is refused too.
  local d t
  built_bootstrapper
  for t in older unstamped none; do
    d="$(tmpdir)"
    cp -R "$BUILT" "$d/files"
    case "$t" in
      older) sed "s/^  $BUILT_VERSION, built from\$/  v1.0.0, built from/" "$BUILT/CHANGELOG.md" >"$d/files/CHANGELOG.md" ;;
      unstamped) sed "/, built from\$/d" "$BUILT/CHANGELOG.md" >"$d/files/CHANGELOG.md" ;;
      none) rm "$d/files/CHANGELOG.md" ;;
    esac
    ! cmp -s "$BUILT/CHANGELOG.md" "$d/files/CHANGELOG.md" || die "$t: the stamp was not changed (test is stale)"
    seed_existing "$d" octo-user/my-app "$d/files"
    export STUB_GH_EXISTING="octo-user/my-app"
    setup_run "$d" --non-interactive --yes --resume
    unset STUB_GH_EXISTING
    expect_rc 3 "$d"
    case "$t" in
      older)
        expect_out "$d" "The project octo-user/my-app was made with version v1.0.0 of the bootstrapper, and this script is version $BUILT_VERSION."
        ;;
      *) expect_out "$d" "The project octo-user/my-app on GitHub was not made from the bootstrapper:" ;;
    esac
    grep -qF 'a new project' "$d/out" || { cat "$d/out" >&2; die "$t: the next action is not a new project"; }
    shown_after "$d" 'To start again, run this command:' >"$d/cmd"
    grep -q '^    bash ' "$d/cmd" && ! grep -qF -- '--resume' "$d/cmd" || { cat "$d/out" >&2; die "$t: no command to start again without --resume"; }
    ! grep -vF -- '--help' "$d/gh.log" | grep -E '	(-X	PUT|clone|edit|create)	' >/dev/null || { cat "$d/gh.log" >&2; die "$t: something was changed"; }
    [ -z "$(ls -A "$d/cwd")" ] || die "$t: something was made on this computer"
  done
}

test_resume_completes_a_project_made_with_use_this_template() {
  local d
  built_bootstrapper
  d="$(tmpdir)"
  seed_existing "$d" octo-user/my-app "$BUILT"
  export STUB_GH_EXISTING="octo-user/my-app"
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING
  expect_rc 0 "$d"
  ! grep -v -- '--help' "$d/gh.log" | grep '	repo	create	' >/dev/null || die "a project was created"
  expect_one_of_each "$d"
  in_git --git-dir="$(bare_of "$d")" show main:CHANGELOG.md | grep -xF -- '- Set up by bootstrap-project.sh.' >/dev/null || die "the setup is not in main"
}

test_resume_refuses_a_copy_with_changes_not_saved_and_keeps_them() {
  # npm stopped after the pack was laid out: the copy has changes not
  # saved. --resume refuses and changes nothing (the script never
  # discards work); with the folder moved away it makes a new copy.
  local d c before
  d="$(tmpdir)"
  fake_tool "$d" npm 10.0.0
  export STUB_NPM_FAIL=offline
  setup_run "$d" --non-interactive --yes --pack node
  unset STUB_NPM_FAIL
  expect_rc 1 "$d"
  c="$(copy_of "$d")"
  before="$(in_git -C "$c" status --porcelain --untracked-files=all)"
  [ -n "$before" ] || die "the copy has nothing unsaved (test is stale)"
  again "$d"
  expect_rc 3 "$d"
  expect_out "$d" "The copy of the project in ./my-app has changes that are not saved."
  expect_out "$d" "move the folder ./my-app somewhere else"
  expect_continue_command "$d" " --resume"
  [ "$(in_git -C "$c" status --porcelain --untracked-files=all)" = "$before" ] || die "the changes not saved were touched"
  ! in_git --git-dir="$(bare_of "$d")" rev-parse -q --verify refs/heads/bootstrap-setup >/dev/null || die "something was sent"
  mv "$c" "$d/moved-away"
  again "$d"
  expect_rc 0 "$d"
  expect_one_of_each "$d"
}

test_resume_with_no_project_on_github_creates_nothing() {
  local d
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes --resume
  expect_rc 3 "$d"
  expect_out "$d" "There is no project named octo-user/my-app on GitHub to continue."
  shown_after "$d" 'To start again, run this command:' >"$d/cmd"
  grep -q '^    bash ' "$d/cmd" && ! grep -qF -- '--resume' "$d/cmd" || { cat "$d/out" >&2; die "no command to start again without --resume"; }
  expect_nothing_created "$d"
}

test_resume_continues_with_resume_once_the_project_missing_at_first_is_found() {
  # #203 review: --resume, the project not found at the first check (a
  # typing mistake, or not made yet), found after Enter at the guide. The
  # run goes on, and a later stop shows the command to continue with
  # --resume: the guide's "start again" choice is not kept.
  local d
  built_bootstrapper
  d="$(tmpdir)"
  seed_existing "$d" octo-user/my-app "$BUILT"
  export STUB_GH_EXISTING="octo-user/my-app" STUB_GH_REPO_FAIL=not-found STUB_GH_PROTECT_FAIL=token
  echo 1 >"$d/repo-fails"
  printf '\nyes\n' >"$d/in"
  setup_run "$d" --resume --allow-unprotected
  unset STUB_GH_EXISTING STUB_GH_REPO_FAIL STUB_GH_PROTECT_FAIL
  expect_rc 3 "$d"
  expect_out "$d" "There is no project named octo-user/my-app on GitHub to continue."
  expect_out "$d" "    Done. The project octo-user/my-app exists on GitHub, which --resume allows."
  expect_out "$d" "==> Protecting"
  expect_continue_command "$d" " --resume"
  # --allow-unprotected, given, is carried too (the same choice gates it).
  expect_continue_command "$d" " --allow-unprotected"
}

test_resume_keeps_resume_when_the_check_after_the_project_missing_guide_fails() {
  # #207 review, N1: --resume, the project not found at the first check;
  # after Enter at the guide, GitHub has a problem of its own. Whether the
  # project exists is not known, so the stop keeps --resume as given: only
  # the latest answer counts, not the guide's "start again" choice.
  local d line
  d="$(tmpdir)"
  export STUB_GH_REPO_FAIL=not-found STUB_GH_REPO_FAIL_LATER=server
  echo 1 >"$d/repo-fails"
  printf '\n' >"$d/in"
  setup_run "$d" --resume
  unset STUB_GH_REPO_FAIL STUB_GH_REPO_FAIL_LATER
  expect_rc 1 "$d"
  expect_out "$d" "There is no project named octo-user/my-app on GitHub to continue."
  expect_err_shape "$d" "GitHub had a problem of its own"
  line="$(long_of "$d" "$(grep -A1 -xE 'To continue the setup, run this command:|To start again, run this command:' "$d/out" | tail -1)")"
  case "$line " in
    "    bash "*" --resume "*) ;;
    *) cat "$d/out" "$d/err" >&2; die "the command shown after the failed check has no --resume (got: $line)" ;;
  esac
  expect_nothing_created "$d"
}

test_resume_refuses_a_copy_without_the_line_of_work_github_has() {
  local d c n
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_PR_FAIL=broken
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_PR_FAIL
  expect_rc 1 "$d"
  c="$(copy_of "$d")"
  in_git -C "$c" checkout -q main
  in_git -C "$c" branch -q -D bootstrap-setup
  n="$(calls_count "$d")"
  again "$d"
  expect_rc 3 "$d"
  expect_out "$d" "The copy of the project in ./my-app does not have the line of work bootstrap-setup that GitHub has."
  ! calls_since "$d" "$n" | grep '^pr create ' >/dev/null || die "a change was proposed"
  [ ! -s "$d/pr-bodies" ] || die "a change was proposed"
}

test_resume_dry_run_says_where_it_continues_and_changes_nothing() {
  local d n
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_BUILD="pull_request fail"
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_BUILD
  expect_rc 1 "$d"
  n="$(calls_count "$d")"
  again "$d" --dry-run
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The setup's changes are proposed on GitHub, at https://github.com/octo-user/my-app/pull/1: the setup continues by waiting for the check build."
  expect_out "$d" "This was a dry run (--dry-run): the checks passed, and nothing was changed."
  expect_resume_steps "$d" "done done done done next -"
  ! calls_since "$d" "$n" | grep -E '^(repo|pr) |-X PUT' >/dev/null || { calls_since "$d" "$n" >&2; die "something was changed or looked at past the plan"; }
}

test_resume_keeps_a_folder_only_when_it_is_this_projects_own_copy() {
  # #148 review, finding 7 (S15 part): with --resume a folder with files
  # must be this project's own copy: its top folder, copied from
  # OWNER/NAME on GitHub; also as --dir . from inside it (#152 review),
  # and still not inside another git project.
  local d url
  d="$(tmpdir)"
  mkdir -p "$d/plain"; touch "$d/plain/x"
  pre "$d" ni resume with_project octo-user my-app with_dir "$d/plain" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "The folder $d/plain has files in it, but it is not a copy of the project octo-user/my-app."
  own_copy "$d/other" https://github.com/someone/else.git
  pre "$d" ni resume with_project octo-user my-app with_dir "$d/other" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "but it is not a copy of the project octo-user/my-app."
  for url in https://github.com/octo-user/my-app.git https://github.com/octo-user/my-app git@github.com:Octo-User/My-App.git; do
    rm -rf "$d/own"
    own_copy "$d/own" "$url"
    pre "$d" ni resume with_project octo-user my-app with_dir "$d/own" preflight_target_dir
    expect_rc 0 "$d"
    expect_out "$d" "Done. The folder is a copy of the project octo-user/my-app, which --resume continues."
  done
  mkdir -p "$d/own/sub"; touch "$d/own/sub/y"
  pre "$d" ni resume with_project octo-user my-app with_dir "$d/own/sub" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "but it is not a copy of the project octo-user/my-app."
  RUN_CWD="$d/own" pre "$d" ni resume with_project octo-user my-app with_dir . preflight_target_dir
  expect_rc 0 "$d"
  # The own copy inside another git project: refused as before.
  own_copy "$d/outer" https://github.com/someone/outer.git
  own_copy "$d/outer/inner" https://github.com/octo-user/my-app.git
  pre "$d" ni resume with_project octo-user my-app with_dir "$d/outer/inner" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "is inside another project that git keeps track of"
}

# failing_fill_awk <dir>: a fake awk in <dir>/bin that fails as awk does
# when it runs out of memory, but only in the fill (FILL_N set), and
# runs the real awk otherwise. It reads all of its input first, as a
# real awk does before it fails: one that exits unread makes the writer
# before it in the pipe (tr in fill_file) fail with "Broken pipe" when
# SIGPIPE is ignored, a race seen on the macOS leg (run 40469146376).
failing_fill_awk() {
  local text
  IFS= read -r -d '' text <<EOF || true
if [ -n "\${FILL_N:-}" ]; then cat >/dev/null; echo "awk: out of memory" >&2; exit 2; fi
exec $(command -v awk) "\$@"
EOF
  write_stand_in "$1/bin/awk" "$text"
}

test_the_failing_fill_awk_reads_its_input_so_the_writer_never_sees_a_broken_pipe() {
  # More than a pipe holds (64 KB) goes into the fake awk, with SIGPIPE
  # ignored: the writer must finish without an error, every time. A fake
  # that exits without reading makes it fail with "Broken pipe".
  local d rc
  d="$(tmpdir)"
  failing_fill_awk "$d"
  rc=0
  ( trap '' PIPE
    awk 'BEGIN { for (i = 0; i < 20000; i++) print "0123456789 line of fill text" }' >"$d/big"
    FILL_N=1 bash -c 'cat "$1" | "$2" "{ print }"; exit "${PIPESTATUS[0]}"' _ "$d/big" "$d/bin/awk" ) 2>"$d/err" || rc=$?
  [ "$rc" -eq 0 ] || { cat "$d/err" >&2; die "the writer before the fake awk failed (exit $rc)"; }
  ! grep -qi 'broken pipe' "$d/err" || { cat "$d/err" >&2; die "Broken pipe"; }
  grep -qxF 'awk: out of memory' "$d/err" || { cat "$d/err" >&2; die "the fake awk did not fail as awk"; }
  # Outside the fill it is the real awk.
  [ "$(printf 'a b\n' | "$d/bin/awk" '{ print $2 }')" = b ] || die "outside the fill the fake is not the real awk"
}

test_an_unexpected_failure_says_what_exists_and_leaves_no_temporary_files() {
  # The ERR trap of the spec ("Failure midway"): a command that fails
  # where the script has no message of its own (here awk in the fill,
  # #153 review) still ends with a plain stop: what exists, the command
  # to continue, the raw details below, and no temporary file left.
  local d
  d="$(tmpdir)"
  working_git "$d"
  failing_fill_awk "$d"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "Something unexpected happened, so the script stopped while: Filling in the project's name, description and product owner in its files\. The project octo-user/my-app exists on GitHub"
  sed -n 2p "$d/err" | grep -F 'Continue the setup with the command shown above' >/dev/null || { cat "$d/err" >&2; die "the next action is not to continue"; }
  expect_continue_command "$d" " --resume"
  # Round 2, N1: the details name the command that failed and show its
  # own message.
  grep -qE '^    The command that failed: awk, .* \(exit code [0-9]+, line [0-9]+ of the script\)$' "$d/err" || { cat "$d/err" >&2; die "the details lack the command that failed"; }
  grep -qxF '    awk: out of memory' "$d/err" || { cat "$d/err" >&2; die "the details lack the command's own message"; }
  [ -z "$(ls -A "$d/tmp")" ] || { ls -A "$d/tmp" >&2; die "temporary files were left"; }
  # Before anything exists: the command to start again.
  d="$(tmpdir)"
  pre "$d" ni unexpected_before_create
  expect_rc 1 "$d"
  expect_err_shape "$d" "Something unexpected happened, so the script stopped while: Checking something\. Nothing was created\.\$"
  expect_out "$d" "To start again, run this command:"
  # A run that goes through, and a stop, leave no temporary file either.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  [ -z "$(ls -A "$d/tmp")" ] || { ls -A "$d/tmp" >&2; die "a run that went through left temporary files"; }
}
unexpected_before_create() { catch_stops; step_start "Checking something"; false; }

test_a_folder_the_script_made_for_the_copy_is_removed_when_the_copy_fails() {
  # Spec, "Failure midway": a local folder the script created is removed
  # if it fails before the copy is complete; one that was there already
  # stays.
  local d
  d="$(tmpdir)"
  export STUB_GH_CLONE_FAIL=partial
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  [ ! -e "$(copy_of "$d")" ] || die "the folder the script made is still there"
  expect_continue_command "$d" " --resume"
  d="$(tmpdir)"
  mkdir -p "$d/cwd/my-app"
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_CLONE_FAIL
  expect_rc 1 "$d"
  [ -d "$(copy_of "$d")" ] || die "a folder that was there before was removed"
}

test_a_rate_limit_at_create_is_not_read_as_not_allowed() {
  # #150 review: GitHub's rate limit when creating says to wait, not that
  # the account may not create projects. Nothing was created.
  local d
  d="$(tmpdir)"
  export STUB_GH_CREATE_FAIL=rate-limit
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_CREATE_FAIL
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub has paused answering your account for a while, because it was asked too often, so the script could not create the project\. Nothing was created\.\$"
  sed -n 2p "$d/err" | grep -F 'Wait an hour' >/dev/null || { cat "$d/err" >&2; die "the next action is not to wait"; }
  expect_no_out "$d" "did not let your account create"
  expect_out "$d" "To start again, run this command:"
  [ "$(calls_from_create "$d")" = "$CREATE_CALL" ] || { cat "$d/gh.log" >&2; die "more than the create call"; }
}

test_new_files_in_src_must_be_the_packs_and_ignored_ones_are_left_alone() {
  # #155 review: the rules for src/ and e2e/ were wide both ways. A new
  # file there that the layout did not copy stops the setup; a file git
  # ignores (here .DS_Store, from the user's global list) is no setup
  # file and does not stop it.
  local d
  d="$(tmpdir)"
  fake_tool "$d" npm 10.0.0
  export STUB_NPM_STRAY=src/notes.txt
  setup_run "$d" --non-interactive --yes --pack web
  unset STUB_NPM_STRAY
  expect_rc 1 "$d"
  expect_err_shape "$d" "The copy of the project on this computer has changes that the setup did not make, so the script saved and sent nothing: src/notes\.txt\. "
  d="$(tmpdir)"
  prepare "$d"
  fake_tool "$d" npm 10.0.0
  printf '%s\n' '.DS_Store' >"$d/home/global-ignore"
  "$REAL_GIT" config --file "$d/home/.gitconfig" core.excludesFile "$d/home/global-ignore"
  export STUB_NPM_STRAY=src/.DS_Store
  setup_run "$d" --non-interactive --yes --pack web
  unset STUB_NPM_STRAY
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "an ignored .DS_Store stopped the setup"; }
}

test_allow_unprotected_goes_on_without_protection_and_writes_the_decision() {
  # Spec, "Private repo, no protection possible", option 3 (open decision
  # 5): --resume --allow-unprotected adds the change without protection,
  # and the project's memory/decisions.md says main is unprotected and
  # why.
  local d n row
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  setup_run "$d" --non-interactive --yes --private
  expect_rc 3 "$d"
  n="$(calls_count "$d")"
  again "$d" --allow-unprotected
  unset STUB_GH_PROTECT_FAIL
  expect_rc 0 "$d"
  expect_one_of_each "$d"
  ! grep -qF '"contexts":["build"]' "$d/protection-bodies" || die "build was made required on a project that cannot be protected"
  row="$(in_git --git-dir="$(bare_of "$d")" show main:memory/decisions.md | grep -F "| $FAKE_TODAY | The main version (main) is not protected |")" \
    || { in_git --git-dir="$(bare_of "$d")" show main:memory/decisions.md >&2; die "no decision row"; }
  case "$row" in *"--allow-unprotected"*"paid GitHub plan"*) ;; *) die "the row does not say why: $row" ;; esac
  expect_out "$d" "    - the main version is not protected: you chose to go on without protection (--allow-unprotected), and memory/decisions.md in the project says so"
  [ -z "$(banned_hits <<<"$row")" ] || die "a banned word in the decision row"
  # Only with --resume, after the script showed why.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes --allow-unprotected
  expect_rc 2 "$d"
  grep -qE -- '^    - --allow-unprotected: ' "$d/err" || { cat "$d/err" >&2; die "not refused as an option"; }
  expect_nothing_created "$d"
  # A key without the permission is not a plan without protection: it
  # still stops.
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=token
  setup_run "$d" --non-interactive --yes --private
  again "$d" --allow-unprotected
  unset STUB_GH_PROTECT_FAIL
  expect_rc 3 "$d"
  expect_no_out "$d" "$FINISHED"
  # When protection works by then (the plan was upgraded), it is set as
  # usual and no decision is written.
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  setup_run "$d" --non-interactive --yes --private
  unset STUB_GH_PROTECT_FAIL
  again "$d" --allow-unprotected
  expect_rc 0 "$d"
  grep -qF '"contexts":["build"]' "$d/protection-bodies" || die "build was not made required"
  ! in_git --git-dir="$(bare_of "$d")" show main:memory/decisions.md | grep -F 'is not protected' >/dev/null || die "a decision was written although main is protected"
}

test_making_the_project_public_runs_only_after_its_own_yes() {
  # Spec, option 2: the script makes the project public only after its
  # own yes, typed at the terminal; --yes does not cover it, and
  # --non-interactive never asks.
  local d
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  printf 'yes\n' >"$d/tty"
  setup_run "$d" --yes --private
  expect_rc 3 "$d"
  expect_out "$d" "Make the project public now? (yes or no) [no]: "
  [ "$(cat "$d/made-public")" = octo-user/my-app ] || die "the project was not made public after yes"
  expect_out "$d" "The project octo-user/my-app is public now."
  expect_continue_command "$d" " --resume"
  unset STUB_GH_PROTECT_FAIL
  again "$d"
  expect_rc 0 "$d"
  expect_one_of_each "$d"
  # No at the terminal, or yes only on stdin: not made public.
  for how in no stdin; do
    d="$(tmpdir)"
    export STUB_GH_PROTECT_FAIL=plan
    if [ "$how" = no ]; then printf 'no\n' >"$d/tty"; else printf 'yes\nyes\n' >"$d/in"; fi
    setup_run "$d" --yes --private
    unset STUB_GH_PROTECT_FAIL
    expect_rc 3 "$d"
    [ ! -e "$d/made-public" ] || die "$how: made public without a yes at the terminal"
  done
  # --non-interactive: not asked.
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  printf 'yes\n' >"$d/tty"
  setup_run "$d" --non-interactive --yes --private
  unset STUB_GH_PROTECT_FAIL
  expect_rc 3 "$d"
  expect_no_out "$d" "Make the project public now?"
  [ ! -e "$d/made-public" ] || die "made public with --non-interactive"
}

# ---------- round 2 of the S15 review (PR #159) ----------

# The protection a project with build required has (REQUIRE_BODY).
REQUIRED_PROTECTION='{"required_status_checks":{"strict":false,"contexts":["build"]},"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":0},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}'
DECISION_ROW_KEY='| The main version (main) is not protected |'
UNPROTECTED_SAYS='    - the main version is not protected: you chose to go on without protection (--allow-unprotected), and memory/decisions.md in the project says so'
UNPROTECTED_MISSING='    - the main version is not protected: you chose to go on without protection (--allow-unprotected), but memory/decisions.md in the project does not say so; add a row for it to the table there'

# nothing_changed_on_github <dir>: after a run that only looked, no call
# that changes GitHub or this computer was made.
nothing_changed_on_github() {
  ! grep -v -- '--help' "$1/gh.log" | grep -E '	(-X	(PUT|PATCH|POST|DELETE)|clone|edit|create|merge)	' >/dev/null || { cat "$1/gh.log" >&2; die "something was changed"; }
  [ ! -s "$1/protection-bodies" ] || die "the protection was set"
  [ ! -s "$1/pr-bodies" ] || die "a change was proposed"
  [ -z "$(ls -A "$1/cwd")" ] || { ls -A "$1/cwd" >&2; die "something was made on this computer"; }
}

# hand_made_project <dir>: octo-user/my-app as a person set it up by
# hand: the bootstrapper's files of this version, but no setup section in
# the README and no bootstrap-project.sh, and the protection with build
# required, kept in the file protected (a copy of it in protected.before).
# <script>: gone (the default) or kept. <heading>, the README's setup
# heading: gone (the default), lookalike, kept, crlf (kept, and every
# line of the README ends with CR LF on GitHub), or note (kept with LF,
# and one more line at the end with CR LF). <changelog>: lf (the
# default), crlf (every line ends with CR LF on GitHub), marked (the
# setup's mark added, as the script writes it when the setup is added),
# or crlf-marked (both).
CR="$(printf '\r')"
# has_cr <file>: the file holds a carriage return. Read through od -c,
# which writes it as the two characters \r, so no carriage return itself
# goes through grep or $( ). On Windows CI (#169) Git for Windows' grep
# did not find a CR that od -c showed in the same file, and $( ) dropped
# a CR LF that ended the text. A backslash in the file is \\ in od's
# output and each byte has its own column, so no other text reads as \r.
has_cr() {
  od -A n -c "$1" | grep -F '\r' >/dev/null
}
# to_crlf <file>: every line of the file ends with CR LF.
to_crlf() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\r\n' "${line%"$CR"}"
  done <"$1" >"$1.crlf"
  mv "$1.crlf" "$1"
}
hand_made_project() {
  local d="$1" script="${2:-gone}" heading="${3:-gone}" changelog="${4:-lf}" bare f blob stored=""
  built_bootstrapper
  mkdir -p "$d/files"
  cp -R "$BUILT/." "$d/files/"
  [ "$script" = kept ] || rm -f "$d/files/bootstrap-project.sh"
  case "$heading" in
    gone | lookalike)
      grep -vxF '## Finishing the setup' "$d/files/README.md" >"$d/files/README.new"
      mv "$d/files/README.new" "$d/files/README.md"
      [ "$heading" != lookalike ] || printf '%s\n' '## Finishing the setup: lends tools' >>"$d/files/README.md"
      ! cmp -s "$BUILT/README.md" "$d/files/README.md" || die "the README was not changed (test is stale)"
      ;;
    crlf)
      to_crlf "$d/files/README.md"
      stored="README.md"
      ;;
    note)
      printf 'A note written on Windows.\r\n' >>"$d/files/README.md"
      stored="README.md"
      ;;
  esac
  case "$changelog" in
    marked | crlf-marked) printf '%s\n' '- Set up by bootstrap-project.sh.' >>"$d/files/CHANGELOG.md" ;;
  esac
  case "$changelog" in
    crlf | crlf-marked)
      to_crlf "$d/files/CHANGELOG.md"
      stored="$stored CHANGELOG.md"
      ;;
  esac
  if [ "$script" = kept ]; then [ -e "$d/files/bootstrap-project.sh" ] || die "the script is not there (test is stale)"; else [ ! -e "$d/files/bootstrap-project.sh" ] || die "the script is still there (test is stale)"; fi
  # $stored is a list of plain file names, split on purpose.
  # shellcheck disable=SC2086
  seed_existing "$d" octo-user/my-app "$d/files" $stored
  bare="$(bare_of "$d")"
  # The blob GitHub stores is checked, not the file on disk, with has_cr
  # (see there why not grep or $( )). A known "a\r\n" is checked first, so
  # a failure says whether the check or the blob is wrong.
  if [ -n "$stored" ]; then
    blob="$(mktemp "$WORK/blob.XXXXXX")"
    printf 'a\r\n' >"$blob"
    has_cr "$blob" || { od -A n -c "$blob" >&2; die "has_cr does not see the carriage return of a known a CR LF (od output above): the check, not the fixture, is wrong here"; }
    rm -f "$blob"
  fi
  for f in $stored; do
    blob="$(mktemp "$WORK/blob.XXXXXX")"
    in_git --git-dir="$bare" cat-file -p "main:$f" >"$blob"
    has_cr "$blob" || { od -c "$blob" | tail -4 >&2; die "$f on GitHub has no carriage return (test is stale); its last bytes are above"; }
    rm -f "$blob"
  done
  case "$changelog" in
    marked | crlf-marked)
      in_git --git-dir="$bare" cat-file -p main:CHANGELOG.md | grep -F -- '- Set up by bootstrap-project.sh.' >/dev/null || die "the CHANGELOG on GitHub has no mark (test is stale)"
      ;;
  esac
  printf '%s\n' "$REQUIRED_PROTECTION" >"$d/protected"
  cp "$d/protected" "$d/protected.before"
}

test_allow_unprotected_is_offered_and_accepted_only_for_a_plan_limit_on_a_private_project() {
  # Review of #159, B1: GitHub's message does not say it is the plan, or
  # the project is public: the key is the likely cause, and neither the
  # option nor the public command is offered or accepted.
  local d mode vis
  for vis in public private; do
    for mode in plan mystery; do
      # A private project with the plan message is the one case that is offered.
      [ "$vis $mode" != "private plan" ] || continue
      d="$(tmpdir)"
      export STUB_GH_PROTECT_FAIL="$mode"
      if [ "$vis" = private ]; then setup_run "$d" --non-interactive --yes --private; else setup_run "$d" --non-interactive --yes; fi
      expect_rc 3 "$d"
      sed -n '/^==> Protecting/,$p' "$d/out" >"$d/guide"
      ! grep -qF -- '--allow-unprotected' "$d/guide" || { cat "$d/guide" >&2; die "$vis $mode: --allow-unprotected is offered"; }
      grep -qF 'Administration' "$d/guide" || { cat "$d/guide" >&2; die "$vis $mode: the token steps are not given"; }
      if [ "$vis" = public ]; then
        # Round 3, N2: a public project gets the token steps only.
        ! grep -qF 'gh repo edit' "$d/guide" || { cat "$d/guide" >&2; die "$vis $mode: making it public is offered"; }
        ! grep -qF 'https://github.com/settings/billing' "$d/guide" || { cat "$d/guide" >&2; die "$vis $mode: the plan steps are shown"; }
        grep -qF 'most likely' "$d/guide" || { cat "$d/guide" >&2; die "$vis $mode: the key is not named as the likely cause"; }
      else
        grep -qF 'https://github.com/settings/billing' "$d/guide" || { cat "$d/guide" >&2; die "$vis $mode: the plan steps are not shown"; }
      fi
      # Given anyway, at the resume: still a stop, nothing set, proposed or added.
      again "$d" --allow-unprotected
      expect_rc 3 "$d"
      expect_no_out "$d" "$FINISHED"
      [ ! -s "$d/pr-bodies" ] || die "$vis $mode: a change was proposed"
      [ ! -s "$d/protected" ] || die "$vis $mode: protection was set"
      ! in_git --git-dir="$(bare_of "$d")" show main:memory/decisions.md 2>/dev/null | grep -F "$DECISION_ROW_KEY" >/dev/null || die "$vis $mode: a decision row was written"
      unset STUB_GH_PROTECT_FAIL
    done
  done
}

test_making_the_project_public_is_offered_only_for_a_plan_limit_on_a_private_project() {
  local d c
  for c in "plan public" "token private" "mystery private" "mystery public"; do
    d="$(tmpdir)"
    export STUB_GH_PROTECT_FAIL="${c%% *}"
    printf 'yes\n' >"$d/tty"
    if [ "${c##* }" = private ]; then setup_run "$d" --yes --private; else setup_run "$d" --yes; fi
    unset STUB_GH_PROTECT_FAIL
    expect_rc 3 "$d"
    expect_no_out "$d" "Make the project public now?"
    [ ! -e "$d/made-public" ] || die "$c: the project was made public"
  done
}

test_an_unprotected_merge_without_the_decision_in_the_change_is_refused() {
  # Review of #159, B2: the plan refuses build as a required check only
  # now (in a resume), and the change on its line of work holds no
  # decision row: nothing is added to an unprotected main version, and the
  # next step is the way with protection.
  local d how n
  for how in saved sent proposed; do
    d="$(tmpdir)"
    working_git "$d"
    export STUB_GH_REQUIRE_FAIL=plan
    case "$how" in
      saved) failing_push "$d" other; setup_run "$d" --non-interactive --yes --private ;;
      sent) export STUB_GH_PR_FAIL=broken; setup_run "$d" --non-interactive --yes --private; unset STUB_GH_PR_FAIL ;;
      proposed) setup_run "$d" --non-interactive --yes --private ;;
    esac
    expect_rc 1 "$d"
    [ "$how" != saved ] || failing_push "$d" ok 0
    n="$(calls_count "$d")"
    again "$d" --allow-unprotected
    expect_rc 1 "$d"
    expect_err_shape "$d" "The setup's change, .*does not say in memory/decisions\.md that the main version is not protected"
    expect_no_out "$d" "$FINISHED"
    ! calls_since "$d" "$n" | grep '^pr merge ' >/dev/null || die "$how: the change was added"
    [ "$(in_git --git-dir="$(bare_of "$d")" rev-list --count main)" -eq 1 ] || die "$how: main has a new change"
    shown_after "$d" 'To continue the setup, run this command:' >"$d/cmd"
    grep -q '^    bash ' "$d/cmd" || { cat "$d/out" >&2; die "$how: no command to continue"; }
    ! grep -qF -- '--allow-unprotected' "$d/cmd" || { cat "$d/cmd" >&2; die "$how: the command to continue repeats the option"; }
    # With protection possible again, the command shown goes through.
    unset STUB_GH_REQUIRE_FAIL
    again "$d"
    expect_rc 0 "$d"
    expect_one_of_each "$d"
    expect_out "$d" "The protection of the main version, as GitHub reports it:"
  done
}

test_an_unprotected_merge_with_the_decision_in_the_change_goes_on_and_says_so() {
  # The decision row went into the change in the first run with the
  # option; a resume that goes on to the merge reports it, as it is true.
  local d
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  setup_run "$d" --non-interactive --yes --private
  expect_rc 3 "$d"
  export STUB_GH_BUILD="pull_request fail"
  again "$d" --allow-unprotected
  unset STUB_GH_BUILD
  expect_rc 1 "$d"
  shown_after "$d" 'To continue the setup, run this command:' | grep -F -- '--allow-unprotected' >/dev/null || { cat "$d/out" >&2; die "the command to continue lacks the option"; }
  again "$d"
  unset STUB_GH_PROTECT_FAIL
  expect_rc 0 "$d"
  expect_one_of_each "$d"
  in_git --git-dir="$(bare_of "$d")" show main:memory/decisions.md | grep -F "$DECISION_ROW_KEY" >/dev/null || die "no decision row in main"
  expect_out "$d" "$UNPROTECTED_SAYS"
}

test_the_report_of_a_finished_unprotected_setup_claims_the_decision_only_when_main_has_it() {
  # Review of #159, B2 (added state): a 404 on the protection with the
  # option; the report says memory/decisions.md records it only when main
  # has the row, else says it does not and what to do.
  local d
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes --private
  expect_rc 0 "$d"
  : >"$d/protected"
  setup_run "$d" --non-interactive --yes --private --resume --allow-unprotected
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "no report"; }
  expect_out "$d" "$UNPROTECTED_MISSING"
  expect_no_out "$d" "$UNPROTECTED_SAYS"
  ! in_git --git-dir="$(bare_of "$d")" show main:memory/decisions.md | grep -F "$DECISION_ROW_KEY" >/dev/null || die "a row was written into a main that was added already"
  # The row is there (written by the run that added the change): claimed.
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  setup_run "$d" --non-interactive --yes --private
  again "$d" --allow-unprotected
  expect_rc 0 "$d"
  setup_run "$d" --non-interactive --yes --private --resume --allow-unprotected
  unset STUB_GH_PROTECT_FAIL
  expect_rc 0 "$d"
  expect_out "$d" "$UNPROTECTED_SAYS"
  # A public project with no protection is not the plan's limit: the
  # option is not accepted, and the stop says what to do.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  : >"$d/protected"
  setup_run "$d" --non-interactive --yes --resume --allow-unprotected
  expect_rc 1 "$d"
  expect_no_out "$d" "$FINISHED"
}

test_a_hand_made_project_that_is_set_up_already_is_only_checked_and_changes_nothing() {
  # Review of #159, B3: current release, no setup section in the README,
  # no bootstrap-project.sh: it is set up already. The protection is read
  # and reported; it is not set, nothing else changes, no copy is made.
  local d
  d="$(tmpdir)"
  hand_made_project "$d"
  export STUB_GH_EXISTING=octo-user/my-app
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The project is set up already:"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "no report"; }
  expect_resume_steps "$d" "done done skipped done done next"
  cmp -s "$d/protected" "$d/protected.before" || die "the protection changed"
  nothing_changed_on_github "$d"
  [ "$(in_git --git-dir="$(bare_of "$d")" rev-list --count main)" -eq 1 ] || die "main changed"
  grep -qF 'octo-user/my-app/contents/README.md' "$d/gh.log" || die "the README was not read"
  # The protection differs: the difference and the next action, nothing changed.
  d="$(tmpdir)"
  hand_made_project "$d"
  export STUB_GH_EXISTING=octo-user/my-app STUB_GH_READBACK="contexts=;strict=null;enforce_admins=true;approvals=0;restrictions=null;allow_force_pushes=false;allow_deletions=false"
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING STUB_GH_READBACK
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub does not report the protection of the main version with the rules the setup gives it\."
  grep -qxF '    contexts: expected build, GitHub reports ' "$d/err" || { cat "$d/err" >&2; die "the difference is not below"; }
  nothing_changed_on_github "$d"
  cmp -s "$d/protected" "$d/protected.before" || die "the protection changed"
  # No protection at all: said plainly, with where to turn it on, nothing set.
  d="$(tmpdir)"
  hand_made_project "$d"
  : >"$d/protected"
  export STUB_GH_EXISTING=octo-user/my-app
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub says the main version of the project has no protection"
  sed -n 2p "$d/err" | grep -F 'https://github.com/octo-user/my-app/settings' >/dev/null || { cat "$d/err" >&2; die "the next action does not say where to turn it on"; }
  nothing_changed_on_github "$d"
  [ ! -s "$d/protected" ] || die "protection was set"
}

test_a_project_is_read_as_added_from_each_signal_alone() {
  # Review of #159, N1: the line in CHANGELOG.md, and a merged proposed
  # change, each alone, in a project that still has its README section and
  # script (so the third signal is absent).
  local d signal
  for signal in mark pull; do
    d="$(tmpdir)"
    built_bootstrapper
    mkdir -p "$d/files"
    cp -R "$BUILT/." "$d/files/"
    grep -qxF '## Finishing the setup' "$d/files/README.md" || die "the built README has no section (test is stale)"
    [ -e "$d/files/bootstrap-project.sh" ] || die "the built project has no script (test is stale)"
    case "$signal" in
      mark) printf '%s\n' '- Set up by bootstrap-project.sh.' >>"$d/files/CHANGELOG.md" ;;
      pull) printf '1 merged\n' >"$d/pulls" ;;
    esac
    seed_existing "$d" octo-user/my-app "$d/files"
    printf '%s\n' "$REQUIRED_PROTECTION" >"$d/protected"
    export STUB_GH_EXISTING=octo-user/my-app
    setup_run "$d" --non-interactive --yes --resume
    unset STUB_GH_EXISTING
    expect_rc 0 "$d"
    expect_out "$d" "    Done. The project is set up already:"
    nothing_changed_on_github "$d"
  done
}

test_a_folder_that_holds_a_git_folder_but_is_not_its_top_is_not_the_copy() {
  # Review of #159, N1: the check that the folder is the top of the copy.
  local d
  d="$(tmpdir)"
  own_copy "$d/own" https://github.com/octo-user/my-app.git
  mkdir -p "$d/own/sub/.git"
  touch "$d/own/sub/x"
  pre "$d" ni resume with_project octo-user my-app with_dir "$d/own/sub" preflight_target_dir
  expect_rc 3 "$d"
  expect_out "$d" "but it is not a copy of the project octo-user/my-app."
}

test_resume_refuses_a_copy_whose_line_of_work_is_not_githubs() {
  local d c n
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_BUILD="pull_request fail"
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_BUILD
  expect_rc 1 "$d"
  c="$(copy_of "$d")"
  in_git -C "$c" -c user.name=T -c user.email=t@example.com commit -q --allow-empty -m "one more"
  n="$(calls_count "$d")"
  again "$d"
  expect_rc 3 "$d"
  expect_out "$d" "The line of work bootstrap-setup in the copy of the project in ./my-app is not the same as the one GitHub has."
  ! calls_since "$d" "$n" | grep -E '^(pr merge|pr create|repo clone) ' >/dev/null || die "something was done after the refusal"
  expect_no_out "$d" "$FINISHED"
}

test_resume_refuses_a_copy_that_is_not_at_githubs_main() {
  local d how w
  for how in fresh saved; do
    d="$(tmpdir)"
    working_git "$d"
    case "$how" in
      fresh) export STUB_GH_LICENSE_KNOWN=made-up-2.0; setup_run "$d" --non-interactive --yes --license made-up-2.0; unset STUB_GH_LICENSE_KNOWN ;;
      saved) failing_push "$d" other; setup_run "$d" --non-interactive --yes; failing_push "$d" ok 0 ;;
    esac
    expect_rc 1 "$d"
    # GitHub's main moves on.
    w="$d/other-copy"
    in_git clone -q "$(bare_of "$d")" "$w"
    in_git -C "$w" -c user.name=T -c user.email=t@example.com commit -q --allow-empty -m "moved on"
    in_git -C "$w" push -q origin HEAD:main
    again "$d" --license mit
    expect_rc 3 "$d"
    expect_out "$d" "The copy of the project in ./my-app is not at the main version that GitHub has now."
    expect_no_out "$d" "$FINISHED"
    [ ! -s "$d/pr-bodies" ] || die "$how: a change was proposed"
  done
}

test_a_copy_broken_off_before_a_retry_is_removed_first() {
  # Review of #159, N1: git cannot sign in and leaves a half-made folder;
  # after the guide's command the copy is made again in a clean place.
  local d
  d="$(tmpdir)"
  echo 1 >"$d/clone-fails"
  printf 'yes\n' >"$d/tty"
  export STUB_GH_CLONE_FAIL=auth-partial
  setup_run "$d" --yes
  unset STUB_GH_CLONE_FAIL
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "did not reach the end"; }
  [ ! -e "$(copy_of "$d")/partial-file" ] || die "the half-made folder was kept"
}

test_only_the_whole_setup_heading_starts_the_section_the_readme_loses() {
  # Review of #159, N1: a README with a heading that only starts the same
  # way and, further down, the real one: only the real section goes.
  local d
  d="$(tmpdir)"
  printf '%s\n' '# App' '## Finishing the setup: lends tools' 'keep me' '## Finishing the setup' 'gone' '## Setup' 'x' >"$d/a"
  ( load_script; remove_setup_section "$d/a" ) || die "the section was not found"
  printf '%s\n' '# App' '## Finishing the setup: lends tools' 'keep me' '## Setup' 'x' >"$d/want"
  expect_same "README" "$d/want" "$d/a"
}

test_the_added_state_keeps_a_local_line_of_work_that_holds_more_than_main_has() {
  # Review of #159, N2: the line of work bootstrap-setup in the copy is
  # deleted only when its files are those of the main version; one that
  # holds something else is kept, and the script says so.
  local d c
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  c="$(copy_of "$d")"
  in_git -C "$c" checkout -q -b bootstrap-setup
  printf 'mine\n' >"$c/mine.txt"
  in_git -C "$c" add mine.txt
  in_git -C "$c" -c user.name=T -c user.email=t@example.com commit -q -m "my own work"
  in_git -C "$c" checkout -q main
  setup_run "$d" --non-interactive --yes --resume
  expect_rc 0 "$d"
  in_git -C "$c" rev-parse -q --verify refs/heads/bootstrap-setup >/dev/null || die "the line of work with my own work was deleted"
  in_git -C "$c" show bootstrap-setup:mine.txt >/dev/null || die "my own work is gone"
  expect_out "$d" "was kept: it holds changes that are not in the main version"
  # One with the files of main: deleted, as before.
  in_git -C "$c" branch -q -D bootstrap-setup
  in_git -C "$c" branch -q bootstrap-setup main
  setup_run "$d" --non-interactive --yes --resume
  expect_rc 0 "$d"
  ! in_git -C "$c" rev-parse -q --verify refs/heads/bootstrap-setup >/dev/null || die "the line of work with main's files was kept"
}

test_resume_sends_only_the_single_change_the_script_saved() {
  # Review of #159, N3: the change to send is one "Set up NAME" on top of
  # main; more than one change, or another title, is not the script's.
  local d how c
  for how in more title twin; do
    d="$(tmpdir)"
    working_git "$d"
    failing_push "$d" other
    setup_run "$d" --non-interactive --yes
    expect_rc 1 "$d"
    failing_push "$d" ok 0
    c="$(copy_of "$d")"
    case "$how" in
      more) in_git -C "$c" -c user.name=T -c user.email=t@example.com commit -q --allow-empty -m "one more" ;;
      title) in_git -C "$c" -c user.name=T -c user.email=t@example.com commit -q --amend -m "Something else" ;;
      twin) in_git -C "$c" -c user.name=T -c user.email=t@example.com commit -q --allow-empty -m "Set up my-app" ;;
    esac
    again "$d"
    expect_rc 3 "$d"
    expect_out "$d" "is not the single change \"Set up my-app\" that the script saves."
    [ "$(grep -c ' push origin bootstrap-setup$' "$d/tools.log" || true)" -eq 1 ] || die "$how: something was sent after the refusal"
    expect_no_out "$d" "$FINISHED"
  done
}

test_the_report_of_a_resumed_setup_names_the_pack_and_licence_main_has() {
  # Review of #159, N4: the report reads the pack and the licence from
  # the project, not from this run's answers.
  local d
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  expect_out "$d" "    Language pack: python"
  expect_out "$d" "    Licence: mit, "
  fake_tool "$d" npm 10.0.0
  whole "$d" --name my-app --description "Lends tools to neighbours." --pack node --license none "${ALL_OPTS[@]}" --public --non-interactive --yes --resume
  expect_rc 0 "$d"
  expect_out "$d" "    Language pack: python"
  expect_no_out "$d" "    Language pack: node"
  expect_out "$d" "    Licence: mit"
  expect_no_out "$d" "no licence file"
  # A project that says nothing about them: the report does not guess.
  d="$(tmpdir)"
  hand_made_project "$d"
  export STUB_GH_EXISTING=octo-user/my-app
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING
  expect_rc 0 "$d"
  expect_no_out "$d" "Language pack:"
  expect_no_out "$d" "    Licence:"
}

# ---------- round 3 of the S15 review (PR #159) ----------

test_a_project_with_its_setup_heading_gone_but_its_script_kept_is_refused_before_anything_is_written() {
  # Review of #159, B4: not set up (the script is there) and not waiting
  # for its setup (the heading is gone): nothing can be placed, so nothing
  # is written to GitHub or to this computer, and its protection stays.
  local d
  d="$(tmpdir)"
  hand_made_project "$d" kept gone
  export STUB_GH_EXISTING=octo-user/my-app
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING
  expect_rc 3 "$d"
  expect_out "$d" "no longer has the setup section"
  # S18a: it says how it checked this refusal: from README.md and
  # bootstrap-project.sh, not from CHANGELOG.md as the version refusals do.
  grep '^How the script checks it: ' "$d/out" | tail -1 >"$d/how"
  grep -qF 'README.md' "$d/how" && grep -qF 'bootstrap-project.sh' "$d/how" || { cat "$d/out" >&2; die "how it checks does not name README.md and bootstrap-project.sh"; }
  ! grep -qF 'CHANGELOG.md' "$d/how" || { cat "$d/how" >&2; die "how it checks names CHANGELOG.md"; }
  expect_no_out "$d" "$FINISHED"
  nothing_changed_on_github "$d"
  cmp -s "$d/protected" "$d/protected.before" || die "the protection changed"
  shown_after "$d" 'To start again, run this command:' >"$d/cmd"
  grep -q '^    bash ' "$d/cmd" && ! grep -qF -- '--resume' "$d/cmd" || { cat "$d/out" >&2; die "no command to start again without --resume"; }
  # With the heading kept and the script gone, the setup goes through and
  # the protection ends with build required.
  d="$(tmpdir)"
  hand_made_project "$d" gone kept
  export STUB_GH_EXISTING=octo-user/my-app
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "no report"; }
  [ "$(grep . "$d/protection-bodies" | tail -1)" = "$REQUIRED_PROTECTION" ] || die "build is not required at the end"
}

test_a_readme_with_only_a_lookalike_heading_and_no_script_is_set_up_already() {
  # Review of #159, N1: the heading on GitHub is matched whole.
  local d
  d="$(tmpdir)"
  hand_made_project "$d" gone lookalike
  export STUB_GH_EXISTING=octo-user/my-app
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The project is set up already:"
  nothing_changed_on_github "$d"
  cmp -s "$d/protected" "$d/protected.before" || die "the protection changed"
}

# ---------- S18a: README.md or CHANGELOG.md stored with CR LF on GitHub ----------

# expect_line_endings_stop <dir> <label> <file>: the run stopped at the
# line-endings guide for <file> before anything was written: the
# protection is as it was, no call changed GitHub, nothing was made on
# this computer (no copy), and the command shown continues with --resume.
expect_line_endings_stop() {
  local d="$1" label="$2" file="$3"
  # First, as the reason the old script failed: it set the protection.
  cmp -s "$d/protected" "$d/protected.before" || { cat "$d/out" "$d/err" >&2; die "$label: the protection changed"; }
  nothing_changed_on_github "$d"
  expect_rc 3 "$d"
  # Round 1 of the #169 review, N2: exact for a carriage return anywhere
  # in the file, not only at the end of each line.
  grep -F 'has a carriage return' "$d/out" | grep -F "$file" >/dev/null || { cat "$d/out" "$d/err" >&2; die "$label: no line-endings message for $file"; }
  grep '^How the script checks it: ' "$d/out" | tail -1 | grep -F 'carriage return anywhere' >/dev/null || { cat "$d/out" >&2; die "$label: how it checks is not exact for a carriage return anywhere"; }
  ! grep -qF 'must end without a carriage return' "$d/out" || { cat "$d/out" >&2; die "$label: how it checks still speaks of line ends only"; }
  expect_out "$d" "LF line endings"
  # N3: main may be protected by an earlier run: then a proposed change.
  expect_out "$d" "If GitHub refuses"
  expect_no_out "$d" "$FINISHED"
  shown_after "$d" 'To continue the setup, run this command:' >"$d/cmd"
  grep -q '^    bash ' "$d/cmd" && grep -qF -- '--resume' "$d/cmd" || { cat "$d/out" >&2; die "$label: no command to continue with --resume"; }
}

# fix_line_endings_on_github <dir> <file>: the user saves <file> with LF
# line endings on main, as the guide says.
fix_line_endings_on_github() {
  local d="$1" file="$2" bare w
  bare="$(bare_of "$d")"
  w="$(mktemp -d "$WORK/fix.XXXXXX")"
  in_git clone -q "$bare" "$w/c" 2>/dev/null
  tr -d '\r' <"$w/c/$file" >"$w/c/$file.lf"
  mv "$w/c/$file.lf" "$w/c/$file"
  in_git -C "$w/c" add -A
  in_git -C "$w/c" -c user.name=T -c user.email=t@example.com commit -q -m "LF line endings in $file"
  in_git -C "$w/c" push -q origin HEAD:main 2>/dev/null
  # Read from a file with has_cr: see there.
  in_git --git-dir="$bare" cat-file -p "main:$file" >"$w.blob"
  rm -rf "$w"
  ! has_cr "$w.blob" || die "$file on GitHub still has a carriage return (test is stale)"
  rm -f "$w.blob"
}

test_a_readme_stored_with_crlf_on_github_is_refused_before_anything_is_written() {
  # S18a: the setup section is found on GitHub only with the carriage
  # returns removed, and the copy's check (grep -x) would not find it after
  # the protection was set. It stops before that, script kept or gone;
  # once the README has LF line endings, the command shown sets it up.
  local d script
  for script in kept gone; do
    d="$(tmpdir)"
    hand_made_project "$d" "$script" crlf
    export STUB_GH_EXISTING=octo-user/my-app
    setup_run "$d" --non-interactive --yes --resume
    expect_line_endings_stop "$d" "script $script" README.md
    fix_line_endings_on_github "$d" README.md
    again "$d"
    unset STUB_GH_EXISTING
    expect_rc 0 "$d"
    grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "script $script: no report after the fix"; }
    [ "$(grep . "$d/protection-bodies" | tail -1)" = "$REQUIRED_PROTECTION" ] || die "script $script: build is not required at the end"
  done
}

test_a_changelog_stored_with_crlf_on_github_is_refused_before_anything_is_written() {
  # S18a: the version is read with the carriage returns removed, and the
  # copy's check of the CHANGELOG (grep -x) would fail after the
  # protection was set. It stops before that; once the CHANGELOG has LF
  # line endings, the command shown sets it up.
  local d script
  for script in kept gone; do
    d="$(tmpdir)"
    hand_made_project "$d" "$script" kept crlf
    export STUB_GH_EXISTING=octo-user/my-app
    setup_run "$d" --non-interactive --yes --resume
    expect_line_endings_stop "$d" "script $script" CHANGELOG.md
    fix_line_endings_on_github "$d" CHANGELOG.md
    again "$d"
    unset STUB_GH_EXISTING
    expect_rc 0 "$d"
    grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "script $script: no report after the fix"; }
  done
}

test_a_set_up_project_with_a_crlf_readme_is_still_only_read() {
  # S18a: the CHANGELOG has the setup's mark, so the project is set up
  # already: the README's line endings do not stop it, and it is only
  # read, as before.
  local d
  d="$(tmpdir)"
  hand_made_project "$d" kept crlf marked
  export STUB_GH_EXISTING=octo-user/my-app
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING
  expect_rc 0 "$d"
  expect_out "$d" "    Done. The project is set up already:"
  expect_no_out "$d" "carriage return"
  nothing_changed_on_github "$d"
  cmp -s "$d/protected" "$d/protected.before" || die "the protection changed"
}

test_a_readme_with_one_crlf_line_besides_the_heading_is_refused_before_anything_is_written() {
  # Round 1 of the #169 review, N1: the heading has LF, another line has
  # CR LF. The copy's tidy_up edits the README, git keeps the carriage
  # return of a blob stored with it, and check_line_endings stops after
  # the protection was set. Any carriage return in the README stops it
  # first, as in the CHANGELOG; after the fix the command shown sets it up.
  local d
  d="$(tmpdir)"
  hand_made_project "$d" kept note
  export STUB_GH_EXISTING=octo-user/my-app
  setup_run "$d" --non-interactive --yes --resume
  expect_line_endings_stop "$d" "one line" README.md
  fix_line_endings_on_github "$d" README.md
  again "$d"
  unset STUB_GH_EXISTING
  expect_rc 0 "$d"
  grep -qxF "$FINISHED" "$d/out" || { cat "$d/out" "$d/err" >&2; die "no report after the fix"; }
}

test_a_set_up_project_with_a_crlf_changelog_is_still_only_read() {
  # Round 1 of the #169 review, N4: in state added (the setup's mark in
  # the CHANGELOG, or tidied up: no section and no script) the CHANGELOG's
  # line endings do not stop it, and it is only read.
  local d how
  for how in marked tidied; do
    d="$(tmpdir)"
    if [ "$how" = marked ]; then
      hand_made_project "$d" kept crlf crlf-marked
    else
      hand_made_project "$d" gone gone crlf
    fi
    export STUB_GH_EXISTING=octo-user/my-app
    setup_run "$d" --non-interactive --yes --resume
    unset STUB_GH_EXISTING
    expect_rc 0 "$d"
    expect_out "$d" "    Done. The project is set up already:"
    expect_no_out "$d" "carriage return"
    nothing_changed_on_github "$d"
    cmp -s "$d/protected" "$d/protected.before" || die "$how: the protection changed"
  done
}

test_the_tests_carriage_return_check_sees_one_wherever_it_is() {
  # #169, Windows CI: grep did not see a carriage return there, and $( )
  # dropped a final CR LF. has_cr must see one at a line end, alone at
  # the end without a line end, and in the middle of a line, and must not
  # take LF text or a backslash before an r for one.
  local d n=0 want
  d="$(tmpdir)"
  for want in 'yes:a\r\n' 'yes:a\nb\r\n' 'yes:a\nb\r' 'yes:a\rb\n' 'no:a\nb\n' 'no:a\\r\n' 'no:'; do
    n=$((n + 1))
    # The format holds the bytes on purpose: \r, \n and \\ are printf's.
    # shellcheck disable=SC2059
    printf "${want#*:}" >"$d/f$n"
    if has_cr "$d/f$n"; then
      [ "${want%%:*}" = yes ] || { od -c "$d/f$n" >&2; die "has_cr sees a carriage return in ${want#*:}"; }
    else
      [ "${want%%:*}" = no ] || { od -c "$d/f$n" >&2; die "has_cr does not see the carriage return in ${want#*:}"; }
    fi
  done
}

test_api_call_keeps_a_carriage_return_on_a_last_line_without_a_line_end() {
  # #169 review: a file whose only carriage return ends its last line,
  # with no line end after it, still counts (the read loop's last line).
  local d
  d="$(tmpdir)"
  printf 'HTTP/2.0 200 OK\r\n\r\nfirst\nlast\r' >"$d/answer"
  printf '#!/bin/sh\ncat "%s"\n' "$d/answer" >"$d/gh"
  chmod +x "$d/gh"
  ( load_script
    BOOTSTRAP_GH="$d/gh"
    API_KEEP_CR=1 api_call repos/o/n/contents/README.md
    [ "$API_STATUS" = 200 ] || die "the answer was not read (status $API_STATUS)"
    case "$API_BODY_CR" in *"last$CR"*) ;; *) die "the carriage return of the last line was lost" ;; esac
    [ "$API_BODY" = "first${NL}last$NL" ] || die "API_BODY is not the body"
  )
}

test_api_call_keeps_carriage_returns_only_when_asked() {
  # Round 1 of the #169 review, B1: building the body a second time costs
  # seconds on a big answer (the script's own file), so API_BODY_CR is
  # filled only for a call made with API_KEEP_CR=1, and is empty after
  # any other call. API_BODY never has a carriage return.
  local d
  d="$(tmpdir)"
  printf 'HTTP/2.0 200 OK\r\nContent-Type: text/plain\r\n\r\nA note\r\nlast\r\n' >"$d/answer"
  printf '#!/bin/sh\ncat "%s"\n' "$d/answer" >"$d/gh"
  chmod +x "$d/gh"
  ( load_script
    BOOTSTRAP_GH="$d/gh"
    api_call repos/o/n/contents/README.md
    [ "$API_STATUS" = 200 ] || die "the answer was not read (status $API_STATUS)"
    [ -z "$API_BODY_CR" ] || die "a call that did not ask kept the body with its carriage returns"
    API_KEEP_CR=1 api_call repos/o/n/contents/README.md
    case "$API_BODY_CR" in *"A note$CR$NL"*) ;; *) die "the call that asked did not keep the carriage returns" ;; esac
    case "$API_BODY" in *"$CR"*) die "API_BODY has a carriage return" ;; esac
    [ "$API_BODY" = "A note${NL}last$NL" ] || die "API_BODY is not the body"
    api_call repos/o/n/contents/README.md
    [ -z "$API_BODY_CR" ] || die "API_BODY_CR was left from the call before"
  )
}

test_the_step_16_refusal_holds_with_the_decision_row_in_the_change() {
  # Review of #159, N1: the row is in the change (the option was given at
  # step 3), and at step 16 GitHub's refusal is not the plan's on a
  # private project: an unknown message, or the plan's message after the
  # project was made public. The change is not added.
  local d how n
  for how in unknown made-public; do
    d="$(tmpdir)"
    export STUB_GH_PROTECT_FAIL=plan
    setup_run "$d" --non-interactive --yes --private
    expect_rc 3 "$d"
    export STUB_GH_BUILD="pull_request fail"
    again "$d" --allow-unprotected
    unset STUB_GH_BUILD
    expect_rc 1 "$d"
    in_git --git-dir="$(bare_of "$d")" show bootstrap-setup:memory/decisions.md | grep -F "$DECISION_ROW_KEY" >/dev/null || die "$how: the row is not in the change (test is stale)"
    case "$how" in
      unknown) export STUB_GH_PROTECT_FAIL=mystery ;;
      made-public) grep -vxF octo-user/my-app "$d/private" >"$d/private.new" || true; mv "$d/private.new" "$d/private" ;;
    esac
    n="$(calls_count "$d")"
    again "$d"
    unset STUB_GH_PROTECT_FAIL
    expect_rc 1 "$d"
    ! calls_since "$d" "$n" | grep '^pr merge ' >/dev/null || die "$how: the change was added"
    expect_no_out "$d" "$FINISHED"
    [ "$(in_git --git-dir="$(bare_of "$d")" rev-list --count main)" -eq 1 ] || die "$how: main has a new change"
  done
}

test_a_failed_visibility_read_does_not_count_as_private() {
  # Review of #159, N1: GitHub's answer on the visibility is not there:
  # the project is not taken as private, so no option and no public command.
  local d
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan STUB_GH_PRIVATE_FAIL=server
  setup_run "$d" --non-interactive --yes --private
  unset STUB_GH_PROTECT_FAIL STUB_GH_PRIVATE_FAIL
  expect_rc 3 "$d"
  sed -n '/^==> Protecting/,$p' "$d/out" >"$d/guide"
  ! grep -qF -- '--allow-unprotected' "$d/guide" || { cat "$d/guide" >&2; die "the option is offered"; }
  ! grep -qF 'gh repo edit' "$d/guide" || { cat "$d/guide" >&2; die "making it public is offered"; }
}

test_the_words_for_a_project_set_up_already_are_not_those_for_one_the_script_just_set_up() {
  # Review of #159, N3: the report and the stops of the added state,
  # hand-made or not, do not say "left for your first session with Clead",
  # "give it the new project" or "as the script set it".
  local d p
  d="$(tmpdir)"
  hand_made_project "$d"
  export STUB_GH_EXISTING=octo-user/my-app
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING
  expect_rc 0 "$d"
  for p in 'left for your first session with Clead' 'give it the new project' 'as the script set' "the setup's changes"; do
    expect_no_out "$d" "$p"
  done
  expect_out "$d" "$WHAT_NEXT"
  # A project the script set up, resumed.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 0 "$d"
  setup_run "$d" --non-interactive --yes --resume
  expect_rc 0 "$d"
  for p in 'left for your first session with Clead' 'give it the new project' 'as the script set'; do
    expect_no_out "$d" "$p"
  done
  # The stop for protection that differs.
  d="$(tmpdir)"
  hand_made_project "$d"
  export STUB_GH_EXISTING=octo-user/my-app STUB_GH_READBACK="contexts=;strict=null;enforce_admins=true;approvals=0;restrictions=null;allow_force_pushes=false;allow_deletions=false"
  setup_run "$d" --non-interactive --yes --resume
  unset STUB_GH_EXISTING STUB_GH_READBACK
  expect_rc 1 "$d"
  for p in 'as the script set' 'the script set ' "the setup's changes"; do
    ! grep -qF "$p" "$d/err" || { cat "$d/err" >&2; die "the stop says: $p"; }
  done
}

# ---------- S19: the README steps for the script ----------
# Spec: PBI-1.14, "What changes in the existing manual README steps" and
# "Guided steps in the script, and what only the README can cover". The
# READMEs are read from this checkout (the stub as it ships, before the
# build fills anything in).

STUB_README="$REPO/bootstrap/stubs/README.md"
TEMPLATE_README="$REPO/README.md"
# The one command of the spec ("Obtaining and starting it").
ONE_COMMAND='gh api repos/factoincognito/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh && bash bootstrap-project.sh'
SIGN_IN_LINE='gh auth login -h github.com -p https -w -s workflow'

# section_of <file> <heading line> <stop regex>: the lines after the
# exact heading line up to (not including) the first line matching the
# stop regex. Fails when the heading is not there exactly once.
section_of() {
  [ "$(grep -cxF -- "$2" "$1")" -eq 1 ] || die "$1: the heading \"$2\" is not there exactly once"
  HEADING="$2" STOP="$3" awk '
    on && $0 ~ ENVIRON["STOP"] { exit }
    on { print }
    $0 == ENVIRON["HEADING"] { on = 1 }' "$1"
}

# prose_of: stdin without code: fenced blocks (``` lines, indented or
# not) and inline `code`. That is the text a reader reads as words; an
# exact command or file name is text to copy, as say_command is in the
# script. Indentation alone is not code (review of #174, B1): wrapped
# lines of nested list items are indented too, and they are prose.
prose_of() {
  awk '/^ *```/ { f = !f; next } !f { print }' | sed -E 's/`[^`]*`//g'
}

# placement_rows <file>: every markdown table row that names a pack file
# (the by-hand placement table, under any header).
placement_rows() {
  grep -nE '^ *\|.*(ci\.yml|gitignore|package\.json|pyproject\.toml|app\.json|starter/|vscode-settings)' "$1" || true
}

test_stub_readme_keeps_the_setup_heading_and_its_setup_boundary() {
  # The script (SETUP_HEADING, remove_setup_section, the resume checks)
  # and e2e-check.sh match this whole heading line, and the section ends
  # at "## Setup".
  local next
  grep -qxF -- '## Finishing the setup' "$STUB_README" \
    || die "the stub README lost the setup heading line"
  ( load_script; [ "$SETUP_HEADING" = '## Finishing the setup' ] ) \
    || die "the script's SETUP_HEADING is not the stub's heading"
  next="$(awk '$0 == "## Finishing the setup" { on = 1; next } on && /^## / { print; exit }' "$STUB_README")"
  [ "$next" = '## Setup' ] || die "the next heading after the setup section is [$next], want [## Setup]"
}

test_stub_readme_setup_section_is_three_lines_with_the_resume_command() {
  local body n
  body="$(section_of "$STUB_README" '## Finishing the setup' '^## ')"
  # Lines of text: not empty and not a ``` fence line around the command.
  n="$(grep -v '^ *```' <<<"$body" | grep -c . || true)"
  [ "$n" -eq 3 ] || { printf '%s\n' "$body" >&2; die "the setup section has $n lines of text, want 3"; }
  grep -qF -- "$ONE_COMMAND --resume --owner " <<<"$body" \
    || { printf '%s\n' "$body" >&2; die "the setup section lacks the one command with --resume --owner"; }
  grep -qF -- ' --name ' <<<"$body" || die "the setup section lacks --name"
  grep -qF 'If you see this, the setup of this project has not finished' <<<"$body" \
    || die "the setup section does not say that the setup has not finished"
  # PBI-1.29: step 0 is in the copy itself, in the bootstrapper's README
  # that the project's page shows until the setup has run; nothing points
  # to the template.
  grep -qF '`.github/README.md`' <<<"$body" || die "the setup section does not name .github/README.md"
  grep -qiF 'step 0' <<<"$body" || die "the setup section does not name step 0"
  ! grep -qF 'ai-project-template-v2' <<<"$body" || die "the setup section points to the template"
}

test_stub_readme_setup_section_has_no_pack_table_and_no_numbered_steps() {
  local body
  body="$(section_of "$STUB_README" '## Finishing the setup' '^## ')"
  ! grep -qE '^ *\|' <<<"$body" || die "the setup section still has a table"
  ! grep -qE '^ *[1-9]\. ' <<<"$body" || die "the setup section still has numbered steps"
  [ -z "$(placement_rows "$STUB_README")" ] || { placement_rows "$STUB_README" >&2; die "the stub README still has a placement table row"; }
}

test_placement_row_check_catches_a_table_under_another_header() {
  # Review of #174, note 5: a placement table under a renamed header.
  local d
  d="$(tmpdir)"
  cp "$STUB_README" "$d/r"
  printf '%s\n' '' '| File | Place |' '|---|---|' '| `ci.yml` | `.github/workflows/ci.yml` |' >>"$d/r"
  [ "$(placement_rows "$d/r" | grep -c . || true)" -eq 1 ] || { placement_rows "$d/r" >&2; die "the planted row was not caught exactly once"; }
}

test_stub_readme_branch_protection_points_to_the_runbook() {
  local body
  ! grep -qF 'step 2 above' "$STUB_README" || die "the stub README still says (step 2 above)"
  body="$(section_of "$STUB_README" '## Branch protection' '^## ')"
  grep -qF '`docs/DEV_INFRASTRUCTURE.md`' <<<"$body" \
    || die "the stub README's Branch protection section does not point to docs/DEV_INFRASTRUCTURE.md"
}

test_template_readme_has_step_0_and_the_one_command() {
  local body
  body="$(section_of "$TEMPLATE_README" '### Creating a project from the template' '^##')"
  grep -qiE 'step 0' <<<"$body" || die "no step 0"
  grep -qF -- "$SIGN_IN_LINE" <<<"$body" || die "step 0 lacks the sign-in line"
  grep -qF 'Authenticate Git' <<<"$body" || die "step 0 does not say to answer Yes to Authenticate Git"
  # Review of #235, N2: gh asks it before it shows the one-time code
  # (gh v2.93.0, login_flow.go), so step 0 says it in that order.
  local ask code
  ask="$(grep -nF 'Authenticate Git' <<<"$body" | head -1 | cut -d: -f1)"
  code="$(grep -nF 'one-time code' <<<"$body" | head -1 | cut -d: -f1)"
  [ -n "$code" ] && [ "$ask" -lt "$code" ] || { printf '%s\n' "$body" >&2; die "step 0 does not put the Authenticate Git answer before the one-time code"; }
  grep -qF 'Git for Windows' <<<"$body" || die "step 0 lacks Git for Windows"
  grep -qF 'https://cli.github.com' <<<"$body" || die "step 0 does not say where gh comes from"
  # Here-strings, not printf | grep -q: under pipefail, grep -q leaving
  # early on a match can end printf with SIGPIPE and fail the pipe.
  [ "$(sed 's/^ *//' <<<"$body" | grep -cxF -- "$ONE_COMMAND" || true)" -ge 1 ] \
    || die "the one command is not on a line of its own"
  ! grep -qF 'does not exist until' "$TEMPLATE_README" || die "the stale 'does not exist until' text is still there"
  [ -z "$(placement_rows "$TEMPLATE_README")" ] || { placement_rows "$TEMPLATE_README" >&2; die "the by-hand pack table is still there"; }
  ! grep -qF 'Turn on branch protection for `main`' "$TEMPLATE_README" || die "the by-hand protection step is still there"
}

# gh_auth_parts_without <needle> <file>: the parts of a README that have
# the reader run gh auth login or gh auth refresh, except the item that
# only describes the permissions guide (the guide gives the steps). A
# part starts at a line that is not indented, or at a nested "  - "
# item, and goes on over indented and empty lines (a numbered step with
# its command). Prints the number of such parts on the first line, then
# each part that lacks <needle>, one per line, with one space between
# words (wrapped lines keep their indentation).
gh_auth_parts_without() {
  NEEDLE="$1" awk '
    function check() {
      if (part !~ /gh auth (login|refresh) -h/) return
      gsub(/  +/, " ", part)
      if (index(part, "the script offers to run")) return
      n++
      if (!index(part, ENVIRON["NEEDLE"])) hits[++h] = part
    }
    /^  - / || /^[^ ]/ { check(); part = "" }
    { part = part " " $0 }
    END {
      check()
      print n + 0
      for (i = 1; i <= h; i++) print hits[i]
    }' "$2"
}

test_template_readme_says_what_to_answer_wherever_it_has_you_run_gh_auth() {
  # Review of #235, N4: the README's other gh auth refresh (to delete a
  # project made to try things out) can ask gh's question too. Every
  # part of the README that has the reader run gh auth login or gh auth
  # refresh says to answer Yes to it.
  local out n
  out="$(gh_auth_parts_without 'Authenticate Git with your GitHub credentials?' "$TEMPLATE_README")"
  n="$(sed -n 1p <<<"$out")"
  [ -z "$(sed 1d <<<"$out")" ] || die "a part of the README has the reader run gh auth without the answer to gh's question: $(sed 1d <<<"$out")"
  [ "$n" -ge 2 ] || die "found $n parts of the README that have the reader run gh auth, want at least 2 (step 0 and deleting a project)"
}

test_template_readme_says_what_to_do_when_gh_cannot_open_the_browser() {
  # End-to-end run 2, r2c: under WSL (Windows' Linux) gh could not open a
  # browser ("Failed opening a web browser at
  # https://github.com/login/device") and the README did not say what to
  # do. Every part of the README that has the reader run gh auth login
  # or gh auth refresh says to open that page yourself, as the script's
  # guides do.
  local out n
  out="$(gh_auth_parts_without 'browser does not open' "$TEMPLATE_README")"
  n="$(sed -n 1p <<<"$out")"
  [ -z "$(sed 1d <<<"$out")" ] || die "a part of the README has the reader run gh auth without saying what to do when the browser does not open: $(sed 1d <<<"$out")"
  out="$(gh_auth_parts_without 'https://github.com/login/device' "$TEMPLATE_README")"
  [ -z "$(sed 1d <<<"$out")" ] || die "a part of the README has the reader run gh auth without the address https://github.com/login/device: $(sed 1d <<<"$out")"
  [ "$n" -ge 2 ] || die "found $n parts of the README that have the reader run gh auth, want at least 2 (step 0 and deleting a project)"
}

test_gh_auth_part_check_catches_a_part_without_the_text() {
  # Guards the two checks above: a planted part that runs gh auth
  # refresh, with neither text, is found, also as a nested item; the
  # item that describes the permissions guide is not counted.
  local d out
  d="$(tmpdir)"
  printf '%s\n' '- Top item: run' '  `gh auth refresh -h github.com -s x` once.' \
    '- List:' '  - nested: run `gh auth login -h github.com` and see' '    the browser does not open https://github.com/login/device' \
    '  - the script offers to run' '    `gh auth refresh -h github.com -s workflow`' >"$d/r"
  out="$(gh_auth_parts_without 'browser does not open' "$d/r")"
  [ "$(sed -n 1p <<<"$out")" = 2 ] || { printf '%s\n' "$out" >&2; die "counted $(sed -n 1p <<<"$out") parts, want 2"; }
  [ "$(sed 1d <<<"$out" | grep -c . || true)" = 1 ] && grep -F 'Top item: run' <<<"$out" >/dev/null \
    || { printf '%s\n' "$out" >&2; die "the part without the text was not the one found"; }
}

# README_GUIDES: each guide of the script as "<function>|<group>|<phrase>":
# the phrase is found only in that guide's bullet of the README, under the
# group the guide belongs to. Groups (README "What the script guides you
# through"): recheck (before anything exists; it checks again and goes
# on), restart (before anything exists; it stops, and you start it again),
# create (GitHub refuses to create the project), after (the project
# exists; continue it), resume (only when continuing with --resume).
# A function may have several rows (one per case it covers).
README_GUIDES='guide_bash_old|restart|a bash that is too old
guide_old_script|restart|an older version of the script
guide_github_permissions|restart|a key (a token) set in GH_TOKEN
guide_git|recheck|git not installed
guide_gh_missing|recheck|gh not installed
guide_gh_old|recheck|gh installed, but too old for the script
guide_npm_missing|recheck|Node.js and npm not installed
guide_npm_windows|recheck|only the Windows npm found in Linux on Windows (WSL)
guide_github_account|recheck|gh signed out, or its sign-in no longer accepted
guide_github_permissions|recheck|signed in without the `workflow` permission
guide_github_offline|recheck|GitHub not reachable from this computer
guide_project_exists|recheck|a project with that name that already exists on GitHub
guide_dir_no_parent|recheck|a folder for the new project that does not exist
guide_dir_not_empty|recheck|or that is not empty
guide_dir_is_file|recheck|or that is a file
guide_dir_not_writable|recheck|or that cannot be written to
guide_dir_in_git|recheck|is inside another project that git keeps track of
guide_create_taken|create|the name is taken by a project your account cannot see
guide_create_refused|create|your account may not create projects there (an organisation
guide_protect|after|a private project on a free GitHub account
guide_actions_off|after|GitHub Actions (the GitHub service
guide_git_sign_in|after|git cannot sign in to GitHub
guide_dir_not_own_copy|resume|the folder is not a copy of this project
guide_project_missing|resume|there is no project with that name to continue
refuse_project|resume|the project was not made by this version of the bootstrapper
guide_line_endings|resume|README.md or CHANGELOG.md on GitHub has Windows line endings
refuse_copy|resume|the copy on this computer does not match GitHub'
# README_GUIDE_LEADS: the first words of each group's top bullet.
README_GUIDE_LEADS='recheck|- Before anything is created, the script checks again and goes on
restart|- Before anything is created, the script stops and you start it again
create|- When GitHub refuses to create the project
after|- After the project exists
resume|- Only when you continue a setup with'

# guide_group <group>: the README lines of that group's top bullet, up to
# the next top bullet or the first line that is not indented.
guide_group() {
  local lead
  lead="$(awk -F'|' -v g="$1" '$1 == g { print $2 }' <<<"$README_GUIDE_LEADS")"
  [ -n "$lead" ] || die "no lead for group $1"
  LEAD="$lead" awk '
    on && (/^- / || /^[^ ]/) { exit }
    on { print }
    index($0, ENVIRON["LEAD"]) == 1 { on = 1; print }' "$TEMPLATE_README"
}

test_template_readme_lists_every_guide_in_its_group() {
  # Spec: the README lists every guide of the script, so a user can read
  # them first. Review of #174, notes 2, 3 and 4: a phrase unique to each
  # guide, in the group that says what happens after it.
  local fn group phrase n g
  while IFS='|' read -r fn group phrase; do
    grep -qE "^${fn}\(\) \{" "$SCRIPT" || die "README_GUIDES names $fn, which the script does not have"
    guide_group "$group" | tr '\n' ' ' | sed 's/  */ /g' | grep -F -- "$phrase" >/dev/null \
      || die "the README group $group lacks the guide $fn: $phrase"
    n="$(sed -n '/^### Creating a project from the template$/,/^##[^#]/p' "$TEMPLATE_README" | tr '\n' ' ' | sed 's/  */ /g' | grep -oF -- "$phrase" | grep -c . || true)"
    [ "$n" -eq 1 ] || die "the phrase for $fn is in the README $n times, want 1: $phrase"
  done <<<"$README_GUIDES"
  # Every guide of the script has a row: a new guide must be listed.
  for g in $(grep -oE '^(guide|refuse)_[a-z_]+\(\)' "$SCRIPT" | sed 's/()//'); do
    case "$g" in
      guide_begin | guide_step | guide_end | guide_details) continue ;; # helpers
      guide_gh | guide_npm | guide_dir | guide_project | guide_published_version) continue ;; # pick one of the guides above
    esac
    grep -q "^$g|" <<<"$README_GUIDES" || die "the script's guide $g is not in README_GUIDES (add it to the README and here)"
  done
}

test_template_readme_says_for_windows_too_to_type_q_before_closing_the_window() {
  # p2.8.4-c (newcomer pre-check on v2.8.4): the README's bullet for
  # Node.js and npm said that on Linux and in WSL the window does not go
  # on with Enter and q shows the command to start again; on Windows the
  # guide has the same pause, so the bullet says the same for Windows,
  # and keeps the reason for the Start menu.
  local bullet t
  bullet="$(guide_group recheck | tr '\n' ' ' | sed 's/  */ /g')"
  bullet="${bullet#*- Node.js and npm not installed}"
  bullet="${bullet%%- only the Windows npm*}"
  [ -n "$bullet" ] || die "the Node.js and npm bullet was not found (test is stale)"
  for t in 'on Windows (Git Bash)' 'type `q`, copy the command it shows' 'from the Start menu, not from the window you are closing' 'keeps the old list of the folders where programs are found'; do
    grep -qF -- "$t" <<<"$bullet" || die "the README's Node.js and npm bullet lacks: $t"
  done
}

test_guide_list_check_fails_when_a_bullet_is_deleted() {
  # Review of #174, note 4: deleting the whole old-bash bullet left the
  # old check green. Plant that deletion in a copy and run the check.
  local d
  d="$(tmpdir)"
  grep -vF 'a bash that is too old' "$TEMPLATE_README" >"$d/README.md"
  ! cmp -s "$TEMPLATE_README" "$d/README.md" || die "nothing was deleted (test is stale)"
  ! ( TEMPLATE_README="$d/README.md"; test_template_readme_lists_every_guide_in_its_group ) 2>/dev/null \
    || die "the check passed with the old-bash bullet deleted"
}

test_template_readme_names_every_question() {
  # Review of #174, note 8: the README names every question the script
  # can ask, read from the script's own answer calls.
  local body q n=0
  body="$(section_of "$TEMPLATE_README" '### Creating a project from the template' '^##' | tr '\n' ' ' | sed 's/  */ /g')"
  while IFS= read -r q; do
    n=$((n + 1))
    grep -qiF -- "$q" <<<"$body" || die "the README does not name the question: $q"
  done < <(awk '/^ *answer --/ { want = 3 } want { want--; if (want == 0) print }' "$SCRIPT" \
    | sed -E 's/^ *"//; s/".*//; s/ \(type the number or the name\)//; s/\? \(yes or no\)//')
  [ "$n" -ge 13 ] || die "read $n questions from the script, want at least 13 (test is stale)"
}

test_template_readme_lists_the_readme_only_steps() {
  local body t
  body="$(section_of "$TEMPLATE_README" '### Creating a project from the template' '^##' | tr '\n' ' ' | sed 's/  */ /g')"
  for t in 'Claude app' 'gh repo delete' 'delete_repo' 'Billing and plans' 'Member privileges'; do
    grep -qF -- "$t" <<<"$body" || die "the README-only part does not mention: $t"
  done
}

test_readmes_say_to_chat_inside_a_claude_project_as_the_script_does() {
  # End-to-end run 1, finding 10: the README's "After the script" and both
  # READMEs' "Working setup" say what the script's last step says: create
  # a Claude Project, give it the project, chat inside it. Both READMEs'
  # "Starting later sessions" start the chat inside that Claude Project
  # (review of #206, N2), and none of these sections writes "Claude
  # project" in lower case (N3).
  local body f t
  body="$(section_of "$TEMPLATE_README" '### Creating a project from the template' '^##' | tr '\n' ' ' | sed 's/  */ /g')"
  body="${body#*After the script: }"
  body="${body%%. *}"
  for t in 'create a Claude Project' 'to that Claude Project' 'start a chat inside the Claude Project'; do
    grep -qF -- "$t" <<<"$WHAT_NEXT" || die "the test's next step lacks: $t (test is stale)"
    grep -qF -- "$t" <<<"$body" || die "the README's After the script lacks: $t"
  done
  for f in "$TEMPLATE_README" "$STUB_README"; do
    body="$(section_of "$f" '### Working setup' '^##' | tr '\n' ' ' | sed 's/  */ /g')"
    for t in 'create a Claude Project' 'to that Claude Project' 'start a chat inside the Claude Project'; do
      grep -qF -- "$t" <<<"$body" || die "$f: Working setup lacks: $t"
    done
    ! grep -qF 'Claude project' <<<"$body" || die "$f: Working setup writes Claude project in lower case"
    body="$(section_of "$f" '### Starting later sessions' '^##' | tr '\n' ' ' | sed 's/  */ /g')"
    grep -qF "start a new chat inside the project's Claude Project" <<<"$body" \
      || die "$f: Starting later sessions does not start the chat inside the project's Claude Project"
  done
}

test_template_readme_branch_protection_has_no_step_reference() {
  local body
  ! grep -qF 'step 3 above' "$TEMPLATE_README" || die "the template README still says (step 3 above)"
  body="$(section_of "$TEMPLATE_README" '## Branch protection' '^## ')"
  grep -qF '`docs/DEV_INFRASTRUCTURE.md`' <<<"$body" \
    || die "the template README's Branch protection section does not point to docs/DEV_INFRASTRUCTURE.md"
  # PBI-1.29: the template's own checks moved here from the shipped doc.
  for t in bootstrapper-test bootstrapper.yml check-shards.sh packs.yml; do
    grep -qF -- "$t" <<<"$body" || die "the template README's Branch protection section does not describe the template's own checks: $t"
  done
}

test_readme_resume_sentence_matches_what_the_script_prints() {
  # Review of #174, B2. The script's command to go on: no --resume before
  # the project exists, or when it refuses to continue one (FRESH_START);
  # --resume once it exists, with earlier answers after it. The README
  # says that, and not that the command ends with --resume.
  local out
  out="$( load_script
    RESTART_CMD=bootstrap-project.sh RESTART_ARGS=" --name foo"
    IN_OWNER=me ANSWERED=" --owner " OPT_RESUME="" OPT_ALLOW_UNPROTECTED=""
    CREATED_NOTE="" FRESH_START=""; shown_command; echo "before:$SHOWN_CMD"
    CREATED_NOTE=x; shown_command; echo "after:$SHOWN_CMD"
    FRESH_START=1; shown_command; echo "refused:$SHOWN_CMD" )"
  grep -qxF 'before:bootstrap-project.sh --owner me' <<<"$out" || { echo "$out" >&2; die "before: unexpected command"; }
  grep -qxF 'after:bootstrap-project.sh --resume --owner me' <<<"$out" || { echo "$out" >&2; die "after: --resume is not followed by the answers"; }
  grep -qxF 'refused:bootstrap-project.sh --owner me' <<<"$out" || { echo "$out" >&2; die "refused: unexpected command"; }
  ! grep -qiE 'ends? with `--resume`|always ends with' "$TEMPLATE_README" || die "the README says the command ends with --resume"
  sed -n '/^### Creating a project from the template$/,/^##[^#]/p' "$TEMPLATE_README" | tr '\n' ' ' | sed 's/  */ /g' \
    | grep -ciF 'once the project exists on GitHub, that command includes `--resume`' >/dev/null \
    || die "the README does not say when the command includes --resume"
}

test_readme_says_the_command_to_continue_comes_before_the_first_change() {
  # End-to-end run 1, finding 6: a stop that runs no trap (Ctrl-C in Git
  # Bash) printed nothing, so "If it stops, it says why and prints the
  # exact command to run next" was not true. The README says the command
  # comes before the first change, and at a stop only when the script can.
  local body
  body="$(sed -n '/^### Creating a project from the template$/,/^##[^#]/p' "$TEMPLATE_README" | tr '\n' ' ' | sed 's/  */ /g')"
  ! grep -qF 'If it stops, it says why and prints the exact command to run next:' <<<"$body" \
    || die "the README still promises the command at every stop"
  grep -qF 'Right after your yes, before it changes anything on GitHub, it prints the command to continue the setup if it stops before it finishes, for any reason (also Ctrl-C or a closed window).' <<<"$body" \
    || die "the README does not say the command to continue comes before the first change"
  grep -qF 'When it stops by itself, it also says why and prints the exact command to run next' <<<"$body" \
    || die "the README does not say what a stop prints when the script can"
  grep -qF 'Copy that command and keep it until the setup has finished.' <<<"$body" \
    || die "the README does not say to copy the command and keep it"
  # #203 review, N4: the commands the script offers to run (such as gh auth
  # refresh) carry no answers, so the README says which commands do.
  ! grep -qF 'Every command it prints carries your answers' <<<"$body" \
    || die "the README says every command carries the answers"
  grep -qF 'The command to continue and the command to start again carry your answers along' <<<"$body" \
    || die "the README does not say which commands carry the answers"
  ( load_script; [ "$ADVANCE_INTRO" = 'If the setup stops before it finishes, for any reason, also with Ctrl-C or a closed window, continue it with the command below. Copy it now and keep it until the setup has finished:' ] ) \
    || die "the script's ADVANCE_INTRO is not the line the tests look for"
}

test_template_readme_step_1_folder_example_works_on_every_system() {
  # End-to-end run 2, r2d: step 1's example "cd ~/Documents" failed in a
  # new Ubuntu account, which has no such folder. Every folder that step
  # 1 has you go to with cd is made first, in the same command
  # (mkdir -p <folder> && cd <folder>), so the example works anywhere.
  local step dirs dir n=0
  # Step 1 ends at the next bold lead-in or heading.
  step="$(awk '/^\*\*Step 1: / { on = 1; print; next } on && /^(\*\*|#)/ { exit } on { print }' "$TEMPLATE_README")"
  [ -n "$step" ] || die "the README has no step 1 (test is stale)"
  grep -F -- "$ONE_COMMAND" <<<"$step" >/dev/null || die "step 1 as the test reads it lacks the one command (test is stale)"
  ! grep -F 'Documents' <<<"$step" >/dev/null || { printf '%s\n' "$step" >&2; die "step 1 still names a Documents folder"; }
  dirs="$(grep -oE '(^|[`&;] *)cd [^ `&;]+' <<<"$step" | sed -E 's/^.*cd //' || true)"
  for dir in $dirs; do
    n=$((n + 1))
    grep -F -- "mkdir -p $dir && cd $dir" <<<"$step" >/dev/null \
      || { printf '%s\n' "$step" >&2; die "step 1 has you go to $dir without making it first (mkdir -p $dir && cd $dir)"; }
  done
  [ "$n" -ge 1 ] || { printf '%s\n' "$step" >&2; die "step 1 gives no example of going to a folder"; }
}

test_step_1_folder_check_catches_a_folder_it_does_not_make() {
  # Guards the check above: a step 1 whose example goes to a folder with
  # cd without making it first fails the check.
  local d
  d="$(tmpdir)"
  awk '/^\*\*Step 1: / { print; print "(for example `cd ~/work`)"; next } { print }' "$TEMPLATE_README" >"$d/README.md"
  ! cmp -s "$TEMPLATE_README" "$d/README.md" || die "nothing was planted (test is stale)"
  ! ( TEMPLATE_README="$d/README.md"; test_template_readme_step_1_folder_example_works_on_every_system ) 2>/dev/null \
    || die "the check passed a step 1 that goes to a folder it does not make"
}

test_readme_commands_are_the_ones_the_script_prints() {
  # The download part of the one command and the sign-in line are the
  # script's own strings, so the README and the script cannot drift.
  local dl="${ONE_COMMAND% && bash bootstrap-project.sh}"
  grep -qF -- "say_command '$dl'" "$SCRIPT" || die "the script no longer prints the README's download command"
  grep -qF -- "say_command \"$SIGN_IN_LINE\"" "$SCRIPT" || die "the script no longer prints the README's sign-in line"
}

# ---------- PBI-1.29: what the setup removes, and the READMEs ----------

test_the_setup_pr_says_it_removed_the_bootstrappers_own_readme() {
  local body
  body="$( load_script
    IN_WITH_DEPLOY="" IN_LICENSE=mit IN_COPYRIGHT_HOLDER=Me IN_PROJECT_NAME=app IN_PACK=python
    pr_body; printf '%s\n' "$PR_BODY" )"
  [ "$(grep -F -- '- Removed:' <<<"$body" | grep -cF '.github/README.md' || true)" -eq 1 ] \
    || { printf '%s\n' "$body" >&2; die "the setup PR's Removed: line does not name .github/README.md"; }
}

test_a_refused_project_is_pointed_to_the_runbook_not_to_a_readme() {
  # No README lists the steps still open; the runbook in the project's
  # docs/DEV_INFRASTRUCTURE.md is what is written down for finishing by hand.
  local out
  out="$( load_script; IN_OWNER=me; IN_NAME=app; RESTART_CMD=bootstrap-project.sh RESTART_ARGS=" --name app"
    refuse_project "Title." "Why." 2>&1 )" || true
  grep -qF 'docs/DEV_INFRASTRUCTURE.md' <<<"$out" || { printf '%s\n' "$out" >&2; die "the guide does not point to docs/DEV_INFRASTRUCTURE.md"; }
  grep -qF 'how to protect its main version by hand' <<<"$out" || { printf '%s\n' "$out" >&2; die "the guide does not say what the runbook is for"; }
  ! grep -qF 'the README of the bootstrapper lists them' <<<"$out" || die "the guide still sends the reader to the bootstrapper's README for open steps"
}

# readme_asks_to_be_edited: stdin's prose lines that ask the reader to
# delete, remove or edit part of the README (Adam's rule, PBI-1.29).
readme_asks_to_be_edited() {
  prose_of | grep -niE '(delete|remove|edit) this (section|part|line|file|readme)|\((delete|remove|edit)[^)]*when done\)' || true
}

test_no_readme_asks_the_reader_to_edit_it() {
  local f hits
  for f in "$STUB_README" "$TEMPLATE_README" "$REPO/bootstrap/bootstrapper-README.md"; do
    hits="$(readme_asks_to_be_edited <"$f")"
    [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "$f asks the reader to edit it"; }
  done
}

test_the_edit_request_check_catches_the_old_heading() {
  local hits
  hits="$(printf '%s\n' '## After bootstrapping (delete this section when done)' 'Delete this section once done.' 'Edit the file.' | readme_asks_to_be_edited)"
  [ "$(grep -c . <<<"$hits" || true)" -eq 2 ] || { printf '%s\n' "$hits" >&2; die "want the 2 planted lines"; }
}

test_bootstrapper_readme_draft_has_no_banned_words_and_the_stubs_resume_command() {
  local f="$REPO/bootstrap/bootstrapper-README.md" hits want
  hits="$(prose_of <"$f" | awk '{ print NR ": " $0 }' | banned_hits)"
  [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "banned word without its explanation in the bootstrapper's README"; }
  want="$ONE_COMMAND --resume --owner OWNER --name NAME"
  [ "$(grep -cxF -- "$want" "$f" || true)" -eq 1 ] || die "the bootstrapper's README lacks the line: $want"
  [ "$(sed 's/^ *//' "$STUB_README" | grep -cxF -- "$want" || true)" -eq 1 ] || die "the stub README lacks the line: $want"
}

test_stub_readme_working_from_another_computer() {
  # PBI-1.29 item 7: written steps for another computer: step 0 of the
  # bootstrapper's README, never its step 1, a copy with gh repo clone,
  # git's name and email in that copy, then the Claude app.
  local body hits
  body="$(section_of "$STUB_README" '### Working from another computer' '^##')"
  grep -qiF 'step 0' <<<"$body" || die "the section does not name step 0"
  grep -qF 'https://github.com/factoincognito/ai-project-bootstrap' <<<"$body" || die "the section does not link the bootstrapper"
  grep -qF 'Do not do its step 1' <<<"$body" || die "the section does not warn against step 1"
  grep -qxF '   gh repo clone OWNER/NAME' <<<"$body" || die "the section lacks gh repo clone OWNER/NAME on a line of its own"
  grep -qF 'git config user.name' <<<"$body" || die "the section does not set git's name"
  grep -qF 'git config user.email' <<<"$body" || die "the section does not set git's email"
  [ "$(tr '\n' ' ' <<<"$body" | sed 's/  */ /g' | grep -cF 'not add capacity or let work run in parallel' || true)" -eq 1 ] \
    || die "the section does not say what another computer is not for"
  ! grep -qF -- "$ONE_COMMAND" <<<"$body" || die "the section has the command that creates a new project"
  ! grep -qF 'ai-project-template-v2' <<<"$body" || die "the section points to the template"
  hits="$(prose_of <<<"$body" | awk '{ print NR ": " $0 }' | banned_hits)"
  [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "banned word without its explanation in Working from another computer"; }
}

test_readme_setup_text_has_no_banned_words() {
  # The same banned-word rule as the script's messages, over the prose of
  # the new README text (commands and file names left out).
  local hits
  hits="$( {
    section_of "$STUB_README" '## Finishing the setup' '^## '
    section_of "$TEMPLATE_README" '### Creating a project from the template' '^##'
  } | prose_of | awk '{ print NR ": " $0 }' | banned_hits)"
  [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "banned word without its explanation in the README setup text"; }
}

test_readme_banned_word_check_catches_a_planted_word() {
  # Guards the check above: prose_of keeps prose, also the wrapped and
  # indented lines of nested list items (review of #174, B1), and leaves
  # out fenced blocks and inline code.
  local hits
  hits="$(printf '%s\n' 'Open the repo page.' '  - a folder that is inside' '    another repo that git keeps' \
    '     clone the project' 'Run `gh api user`.' '```' 'git clone x' '```' '   ```' '   gh repo view' '   ```' \
    | prose_of | awk '{ print NR ": " $0 }' | banned_hits)"
  [ "$(grep -c . <<<"$hits" || true)" -eq 3 ] || { printf '%s\n' "$hits" >&2; die "want exactly the 3 planted prose lines"; }
  grep -qF 'Open the repo page.' <<<"$hits" || die "the planted top-level word was not caught"
  grep -qF 'another repo that git keeps' <<<"$hits" || die "the planted word on a wrapped list line was not caught"
  grep -qF 'clone the project' <<<"$hits" || die "the planted word on a 5-space list line was not caught"
}

test_readme_banned_word_check_reads_the_real_list_lines() {
  # The same plant as the review, in a copy of the real README: a banned
  # word on a wrapped line of a nested guide bullet is caught.
  local d hits
  d="$(tmpdir)"
  awk '/download Git for Windows and run the installer/ && !done { sub(/download Git/, "clone the repo, download Git"); done = 1 } { print }' \
    "$TEMPLATE_README" >"$d/README.md"
  ! cmp -s "$TEMPLATE_README" "$d/README.md" || die "nothing was planted (test is stale)"
  hits="$(section_of "$d/README.md" '### Creating a project from the template' '^##' | prose_of | awk '{ print NR ": " $0 }' | banned_hits)"
  grep -qF 'clone the repo' <<<"$hits" || die "the planted word was not caught"
}

test_remove_pack_section_cuts_to_the_next_heading_outside_a_code_block() {
  # PBI-1.29: the setup removes Part 2's section of each pack the project
  # does not use. A # line inside a code block is not a heading, and the
  # last section runs to the end of the file.
  local d rc
  d="$(tmpdir)"
  printf '%s\n' '# Doc' '## Part 2' '### Python (`python` pack)' 'Py text.' '```bash' '# macOS / Linux' '## not a heading' '```' 'More py.' \
    '### Node (`node` pack)' 'Node text.' '### Mobile (`react-native` pack)' 'RN text.' >"$d/a"
  ( load_script; remove_pack_section "$d/a" python ) || die "python: returned $?"
  printf '%s\n' '# Doc' '## Part 2' '### Node (`node` pack)' 'Node text.' '### Mobile (`react-native` pack)' 'RN text.' >"$d/want"
  expect_same "the python section" "$d/want" "$d/a"
  ( load_script; remove_pack_section "$d/a" react-native ) || die "react-native: returned $?"
  printf '%s\n' '# Doc' '## Part 2' '### Node (`node` pack)' 'Node text.' >"$d/want"
  expect_same "the last section" "$d/want" "$d/a"
  # No such section: nothing changes, and it says so. A line that only
  # mentions the pack is not its heading.
  printf '%s\n' '# Doc' 'See the (`web` pack) notes.' '### Web notes (`web` pack) and more' >"$d/b"
  cp "$d/b" "$d/b0"
  rc=0; ( load_script; remove_pack_section "$d/b" web ) || rc=$?
  [ "$rc" -eq 1 ] || die "no web section: returned $rc, want 1"
  cmp -s "$d/b0" "$d/b" || die "no web section: the file changed"
  # A "## " heading ends a section too; an indented code block hides its
  # # lines; a pack heading inside a kept section's code block is not a
  # heading; no blank line is left at the end.
  printf '%s\n' '# Doc' '### Web (`web` pack)' 'Web text.' '  ```' '### x' '## y' '  ```' 'More web.' '## Next' 'Next text.' \
    '### Node (`node` pack)' 'Node text.' '```' '### Py (`python` pack)' '```' '' '### Mobile (`react-native` pack)' 'RN text.' >"$d/c"
  ( load_script; remove_pack_section "$d/c" web ) || die "web: returned $?"
  ( load_script; remove_pack_section "$d/c" python ) && die "python: a heading inside a code block was taken for the section"
  ( load_script; remove_pack_section "$d/c" react-native ) || die "react-native: returned $?"
  printf '%s\n' '# Doc' '## Next' 'Next text.' '### Node (`node` pack)' 'Node text.' '```' '### Py (`python` pack)' '```' >"$d/want"
  expect_same "the ## end, the code blocks and the last blank line" "$d/want" "$d/c"
}

test_the_tidy_up_goes_on_when_another_packs_section_is_missing() {
  # A doc without one of the other packs' sections (edited by hand, or a
  # rerun) does not stop the setup; the other sections are still cut.
  local d rc
  d="$(tmpdir)"
  mkdir -p "$d/c/docs" "$d/c/languages/node" "$d/c/languages/web" "$d/c/.github"
  printf '%s\n' '# App' '## Finishing the setup' 'x' '## Setup' 'y' >"$d/c/README.md"
  printf '%s\n' 'standards' >"$d/c/languages/node/code-standards.md"
  printf '%s\n' 'web' >"$d/c/languages/web/code-standards.md"
  printf '%s\n' '# Doc' '## Part 2' '### Node (`node` pack)' 'Node text.' '### Mobile (`react-native` pack)' 'RN text.' >"$d/c/docs/DEV_INFRASTRUCTURE.md"
  # Not on the left of ||: there bash would ignore errexit in the
  # subshell, and a failing step would not stop the tidy-up.
  rc=0
  ( load_script; IN_DIR="$d/c"; IN_PACK=node; LP_KEPT=code-standards.md; tidy_up ) >"$d/out" 2>&1 &
  wait "$!" || rc=$?
  [ "$rc" -eq 0 ] || { cat "$d/out" >&2; die "the tidy-up stopped on a doc without the web and python sections"; }
  printf '%s\n' '# Doc' '## Part 2' '### Node (`node` pack)' 'Node text.' >"$d/want"
  expect_same "DEV_INFRASTRUCTURE.md" "$d/want" "$d/c/docs/DEV_INFRASTRUCTURE.md"
  [ ! -e "$d/c/languages/web" ] || die "the other pack's folder is left"
}

test_dev_infrastructure_says_the_script_turns_protection_on() {
  local body
  body="$(awk '/^\*\*Turning it on in a new project/ { on = 1 } on && /^\*\*Checking that it works\.\*\*/ { exit } on { print }' "$REPO/docs/DEV_INFRASTRUCTURE.md")"
  [ -n "$body" ] || die "no 'Turning it on in a new project' paragraph"
  grep -qF 'bootstrap-project.sh' <<<"$body" || die "it does not say the setup script does this"
  grep -qiF 'fallback' <<<"$body" || die "the manual steps are not called the fallback"
  grep -qF 'Settings, Branches' <<<"$body" || die "the manual steps are gone"
}

# ---------- the screen a newcomer meets (PBI-1.30) ----------
# docs/NEWCOMER_PRECHECK.md: before each human end-to-end run, a persona
# on a small model reads two texts made by the build of the commit
# checked: the bootstrapper's README and the screen of the interactive
# setup. This test makes both, and checks the setup it ran.

# in_one_stream <dir> <answers> <stream> <command...>: runs the command
# in the environment of <dir> (in_env), stdin from the file <answers>,
# with stdout and stderr in one file, <stream>, in the order they were
# printed (one open file, not two that are put together afterwards).
# RC is the exit status of the command.
in_one_stream() {
  local d="$1" answers="$2" stream="$3"
  shift 3
  set +e
  ( in_env "$d"; "$@" ) <"$answers" >"$stream" 2>&1
  RC=$?
  set -e
}

# first_line_of <file> <text>: the number of the first line of the file
# that has the text in it; dies when there is none.
first_line_of() {
  local n
  n="$(grep -nF -- "$2" "$1" | head -1 | cut -d: -f1 || true)"
  [ -n "$n" ] || { cat "$1" >&2; die "no line with: $2"; }
  printf '%s\n' "$n"
}

# with_answers <stream> <answers> <counts>: prints the stream as a
# terminal would show it: every question has its answer after it. The
# script ends each question with a colon and a space and, as its input
# is not a terminal, with a line break of its own, in place of the Enter
# that ends what a person types; so the answer goes at the end of that
# line. <counts> gets "<questions> <answers>": the same number, when
# every question was answered and no answer was left.
with_answers() {
  tr -d '\r' <"$1" | awk -v counts="$3" '
    NR == FNR { answer[++n] = $0; next }
    /: $/ { k++; print $0 answer[k]; next }
    { print }
    END { print k + 0, n + 0 >counts }' <(tr -d '\r' <"$2") -
}

# The answers of the newcomer, fixed (docs/NEWCOMER_PRECHECK.md). An
# empty one is Enter, which takes the answer the script suggests.
NEWCOMER_FIRST_RUN=(tool-share 'Tool Share' 'Lets neighbours lend each other tools.' '' '' web '' '' mit '' '' '' '' q)
NEWCOMER_SECOND_RUN=(yes)

test_the_screen_of_the_setup_a_newcomer_meets_is_written_for_the_precheck() {
  # PBI-1.30. Two runs of the built script, as on Windows in Git Bash,
  # starting where the README leaves a newcomer, with Node.js not
  # installed: the first shows the Windows guide for Node.js and stops at
  # its pause with q; the second, started with the command that stop
  # shows, in a new window with npm present, goes through. The files
  # written to BOOTSTRAP_NEWCOMER_SCREEN (a folder of your choice; if it
  # is not set, a folder of this test) are what the persona is given.
  local d dest cmd line a b c
  d="$(tmpdir)"
  dest="${BOOTSTRAP_NEWCOMER_SCREEN:-$d/screen}"
  mkdir -p "$dest" || die "cannot make the folder $dest"
  dest="$(cd "$dest" && pwd)"
  on_os "$d" windows
  working_git "$d"
  missing "$d" npm
  use_built "$d"
  prepare "$d"
  # A question asked at the terminal would read this empty file, never
  # the terminal of whoever runs the test, and counts as one with no
  # answer below.
  : >"$d/tty"
  # README step 1 saves the script in the folder the newcomer is in and
  # runs it there with bash bootstrap-project.sh, so the screen shows
  # that form (and so does the command to start again).
  cp "$RUN_SCRIPT" "$d/cwd/bootstrap-project.sh"

  # The capture keeps the order of stdout and stderr: a line printed to
  # stderr between two printed to stdout stays between them.
  three_lines() { echo one; echo two >&2; echo three; }
  in_one_stream "$d" "$d/in" "$d/order" three_lines
  [ "$(tr '\n' ' ' <"$d/order")" = "one two three " ] \
    || { cat "$d/order" >&2; die "stdout and stderr are not one stream in the order printed"; }

  # The first run: every question answered, then the guide, and q.
  printf '%s\n' "${NEWCOMER_FIRST_RUN[@]}" >"$d/in"
  in_one_stream "$d" "$d/in" "$d/stream1" "$BASH" bootstrap-project.sh
  [ "$RC" -eq 3 ] || { cat "$d/stream1" >&2; die "the first run ended with $RC, want 3"; }
  grep -qxF 'npm (part of Node.js) is not installed.' "$d/stream1" || { cat "$d/stream1" >&2; die "the first run shows no Node.js guide"; }
  # The lines printed to stderr come after the ones printed to stdout
  # before them: the command to start again, then what happened.
  a="$(first_line_of "$d/stream1" 'To start again, run this command:')"
  b="$(first_line_of "$d/stream1" 'What happened: npm (part of Node.js) is not installed.')"
  c="$(first_line_of "$d/stream1" 'What to do next: ')"
  [ "$((a + 1))" -lt "$b" ] && [ "$b" -lt "$c" ] \
    || { cat "$d/stream1" >&2; die "the stop is not in the order printed"; }
  [ -z "$(calls_from_create "$d")" ] || { cat "$d/gh.log" >&2; die "the project was created in the first run"; }
  cmd="$(sed -n "$((a + 1))p" "$d/stream1")"
  # The form the README shows (step 1 saves the script in the folder
  # the newcomer is in, and runs it there): the folder after cd is the
  # only part that comes from the test.
  # The folder is the one the script was started in, as pwd writes it
  # (not as $d is written: macOS's TMPDIR ends in a /, so $d has a //).
  [ "$cmd" = "    cd '$(cd "$d/cwd" && pwd)' && bash bootstrap-project.sh --again" ] \
    || { cat "$d/stream1" >&2; die "the command to start again is not the one the README shows: $cmd"; }

  # The second run: a new window (npm is there now), the command shown.
  rm "$d/npm-fails"
  fake_tool "$d" npm 10.9.2
  printf '%s\n' "${NEWCOMER_SECOND_RUN[@]}" >"$d/in2"
  bash() { "$BASH" "$@"; }
  in_one_stream "$d" "$d/in2" "$d/stream2" eval "$cmd"
  [ "$RC" -eq 0 ] || { cat "$d/stream2" >&2; die "the second run ended with $RC, want 0"; }
  grep -qxF 'The setup is finished.' "$d/stream2" || { cat "$d/stream2" >&2; die "the second run did not finish the setup"; }
  [ "$(calls_from_create "$d" | sed -n 1p)" = 'repo create octo-user/tool-share --template factoincognito/ai-project-bootstrap --public --description Lets neighbours lend each other tools.' ] \
    || { cat "$d/gh.log" >&2; die "the project was not created from the answers"; }

  # The two texts the persona is given: the screen of both runs, each
  # answer after its question, and the README the build wrote.
  printf '%s\n' "${NEWCOMER_FIRST_RUN[@]}" >"$d/answers1"
  with_answers "$d/stream1" "$d/answers1" "$d/counts1" >"$d/shown1"
  with_answers "$d/stream2" "$d/in2" "$d/counts2" >"$d/shown2"
  [ "$(cat "$d/counts1")" = "${#NEWCOMER_FIRST_RUN[@]} ${#NEWCOMER_FIRST_RUN[@]}" ] \
    || { cat "$d/stream1" >&2; die "the first run asked $(cut -d' ' -f1 <"$d/counts1") questions, with ${#NEWCOMER_FIRST_RUN[@]} answers given (a question at the terminal needs its answer in the test too)"; }
  [ "$(cat "$d/counts2")" = "${#NEWCOMER_SECOND_RUN[@]} ${#NEWCOMER_SECOND_RUN[@]}" ] \
    || { cat "$d/stream2" >&2; die "the second run asked $(cut -d' ' -f1 <"$d/counts2") questions, with ${#NEWCOMER_SECOND_RUN[@]} answers given"; }
  {
    cat "$d/shown1"
    printf '\n%s\n\n' '----- The first window is closed. In a new Git Bash window, opened from the Start menu, the command above is run: -----'
    cat "$d/shown2"
  } >"$dest/screen.txt"
  cp "$BUILT/.github/README.md" "$dest/README.md"
  [ -s "$dest/screen.txt" ] || die "screen.txt was not written to $dest"
  [ -s "$dest/README.md" ] || die "README.md was not written to $dest"

  # Each question is followed by its answer; an Enter leaves the end of
  # the line as the script printed it.
  for line in \
    'Project name: tool-share' \
    'Display name [tool-share]: Tool Share' \
    'Description: Lets neighbours lend each other tools.' \
    'Owner [octo-user]: ' \
    'Language pack (type the number or the name): web' \
    'Add the publishing files? (yes or no) [no]: ' \
    'Licence (type the number or the name): mit' \
    'Folder [./tool-share]: ' \
    'Press Enter to check again, or type q to stop: q' \
    'Proceed? (yes or no) [no]: yes'; do
    [ "$(grep -cxF -- "$line" "$dest/screen.txt")" -eq 1 ] \
      || { cat "$dest/screen.txt" >&2; die "the screen lacks, once, the line: $line"; }
  done
  # Both runs are in the file, from their own streams.
  grep -qxF 'npm (part of Node.js) is not installed.' "$dest/screen.txt" || { cat "$dest/screen.txt" >&2; die "the screen lacks the Node.js guide"; }
  grep -qxF 'The setup is finished.' "$dest/screen.txt" || { cat "$dest/screen.txt" >&2; die "the screen lacks the end of the second run"; }
}

# ---------- run ----------

TESTS=$(declare -F | awk '{print $3}' | grep '^test_')
# by_duration <file> <column> <i> <n>: reads the tests on stdin, in the
# list's order, and prints those of shard i of n by measured duration
# (see BOOTSTRAP_TEST_WEIGHTS above), in the list's order. A carriage
# return at the end of any line of the file is ignored. Weights are
# compared in hundredths of a second; a weight of 0 means no time was
# measured, and it and every test the file does not list weigh the
# median of the measured ones (the lower middle one). Total ties go to
# the shard with fewer tests, then the lower shard. Prints "refused:
# <why>" instead, and nothing else, when the file has no header naming
# the column, no data line or a value that is not a number (an empty
# file is refused before, where the setting is read).
by_duration() {
  LC_ALL=C awk -v col="$2" -v want="$3" -v n="$4" '
    NR == FNR {
      sub(/\r$/, "")
      if (FNR == 1) {
        if ($1 != "test") { bad = "its first line is not a header starting with test"; next }
        for (k = 2; k <= NF; k++) if ($k == col) c = k
        if (!c) bad = "it has no column " col
        next
      }
      if (bad || NF == 0) next
      if ($c !~ /^[0-9]+(\.[0-9]+)?$/) { bad = "line " FNR " has no number in column " col; next }
      rows++
      x = int($c * 100 + 0.5)
      if (x > 0) { w[$1] = x; v[++nv] = x }
      next
    }
    { name[++m] = $0 }
    END {
      if (!bad && !rows) bad = "it has no line of times"
      if (bad) { print "refused: " bad; exit }
      for (i = 2; i <= nv; i++) { x = v[i]; j = i - 1; while (j > 0 && v[j] > x) { v[j + 1] = v[j]; j-- } v[j + 1] = x }
      med = nv ? v[int((nv + 1) / 2)] : 1
      for (i = 1; i <= m; i++) { wt[i] = (name[i] in w) ? w[name[i]] : med; ord[i] = i }
      # Longest first; equal weights in the order of the list.
      for (i = 2; i <= m; i++) {
        x = ord[i]; j = i - 1
        while (j > 0 && (wt[ord[j]] < wt[x] || (wt[ord[j]] == wt[x] && ord[j] > x))) { ord[j + 1] = ord[j]; j-- }
        ord[j + 1] = x
      }
      for (k = 1; k <= n; k++) { tot[k] = 0; cnt[k] = 0 }
      for (i = 1; i <= m; i++) {
        best = 1
        for (k = 2; k <= n; k++) if (tot[k] < tot[best] || (tot[k] == tot[best] && cnt[k] < cnt[best])) best = k
        tot[best] += wt[ord[i]]; cnt[best]++; shard[ord[i]] = best
      }
      for (i = 1; i <= m; i++) if (shard[i] == want) print name[i]
    }' "$1" -
}
ALL_COUNT=0
for t in $TESTS; do ALL_COUNT=$((ALL_COUNT + 1)); done
if [ -n "$WEIGHTS_FILE" ]; then
  TESTS="$(printf '%s\n' $TESTS | by_duration "$WEIGHTS_FILE" "$WEIGHTS_COL" "$SHARD_I" "$SHARD_N")" \
    || weights_refused "the split failed"
  case "$TESTS" in "refused: "*) weights_refused "${TESTS#refused: }" ;; esac
fi
if [ -n "$MANIFEST" ]; then
  mkdir -p "$(dirname "$MANIFEST")"
  : >"$MANIFEST"
fi
k=0
for t in $TESTS; do
  # Split by duration: TESTS holds this shard's tests only.
  if [ -n "$WEIGHTS_FILE" ] || [ $((k % SHARD_N)) -eq $((SHARD_I - 1)) ]; then
    if [ "${BOOTSTRAP_TEST_LIST:-}" = 1 ]; then
      printf '%s\n' "$t"
    else
      run_test "$t"
      if [ -n "$MANIFEST" ]; then printf '%s\n' "$t" >>"$MANIFEST"; fi
    fi
  fi
  k=$((k + 1))
done
[ "${BOOTSTRAP_TEST_LIST:-}" != 1 ] || exit 0
if [ $((PASSED + FAILED)) -eq 0 ]; then
  echo "This run ran no test: shard $SHARD_I of $SHARD_N selects none of the $ALL_COUNT tests." >&2
  exit 1
fi

echo
if [ -n "$SKIPPED_LIST" ]; then
  echo "Skipped here (counted as passed):"
  printf '%s' "$SKIPPED_LIST"
fi
echo "$PASSED passed, $FAILED failed"
if [ "$FAILED" -ne 0 ]; then
  printf '  %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
