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
# fails_left <name>: true while the file <name> next to the log holds a
# number above 0, counting it down; a test writes 1 there to make a call
# fail once and then work, as if the user had fixed it in between.
fails_left() {
  local f="${STUB_GH_LOG%/*}/$1" n
  [ -f "$f" ] || return 1
  n="$(cat "$f")"
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
      # after the project was made).
      if [ -n "${STUB_GH_CREATE_FAIL:-}" ] && should_fail create-fails; then
        case "$STUB_GH_CREATE_FAIL" in
          signed-out) emit_failure signed-out ;;
          taken) echo "GraphQL: Name already exists on this account (cloneTemplateRepository)" >&2 ;;
          refused) echo "GraphQL: Resource not accessible by personal access token (cloneTemplateRepository)" >&2 ;;
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
      # With STUB_GH_TEMPLATE set, the project also gets its files, so a
      # later repo clone can copy it (seed_project).
      [ -z "${STUB_GH_TEMPLATE:-}" ] || seed_project "$3"
      printf 'https://github.com/%s\n' "$3"
    elif [ "${2:-}" = clone ]; then
      # gh repo clone OWNER/NAME DIR: a real git clone of the bare repo
      # that repo create seeded; gh passes git's progress to stderr.
      # STUB_GH_CLONE_FAIL makes it fail as signed-out (gh's exit 4) or
      # broken (git's text for a network failure, exit 128, nothing made).
      case "${STUB_GH_CLONE_FAIL:-}" in
        "") ;;
        signed-out) emit_failure signed-out ;;
        broken)
          printf "Cloning into '%s'...\nfatal: unable to access 'https://github.com/%s.git/': Could not resolve host: github.com\n" "$4" "$3" >&2
          exit 128
          ;;
        *) echo "stub gh: unknown failure mode: $STUB_GH_CLONE_FAIL" >&2; exit 64 ;;
      esac
      bare="${STUB_GH_LOG%/*}/remotes/$3.git"
      if [ ! -d "$bare" ]; then
        echo "GraphQL: Could not resolve to a Repository with the name '$3'. (repository)" >&2
        exit 1
      fi
      exec "${STUB_GIT:-git}" clone "$bare" "$4"
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
    # After a project is made, three more calls are emulated:
    #   - api -i repos/OWNER/NAME/branches/main and .../contents/CHANGELOG.md:
    #     404 while the counter file main-missing (or changelog-missing) is
    #     above 0, as while GitHub is still copying the template; else 200.
    #     STUB_GH_BRANCH_FAIL and STUB_GH_FILES_FAIL fail them as <mode>.
    #   - api -i -X PUT repos/OWNER/NAME/branches/main/protection --input -:
    #     the body read from stdin is appended, with a line break, to the
    #     file protection-bodies next to the log; 200, or <mode> with
    #     STUB_GH_PROTECT_FAIL (plan, token, mystery, not-found, ...).
    # And the licence text (step 10):
    #   - api -i licenses/<key> --jq .body: the file <key> in the folder
    #     STUB_GH_LICENSES (the harness writes mit and apache-2.0 from
    #     GitHub's texts), printed as gh prints a string picked by --jq:
    #     as is, plus a line break (so it ends in a blank line); with
    #     STUB_GH_CR each line ends in a carriage return. Any other key is
    #     GitHub's 404. STUB_GH_LICENSE_FAIL fails it as <mode>.
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
      respond 200 OK 'application/json; charset=utf-8'
      printf '{"url":"https://api.github.com/%s"}\n' "$5"
    elif [ "$#" -eq 3 ] && [ "$2" = -i ] && [ "${3#repos/}" != "$3" ]; then
      if [ -n "${STUB_GH_REPO_FAIL:-}" ] && should_fail repo-fails; then emit_failure "$STUB_GH_REPO_FAIL"; fi
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
    elif [ "$#" -eq 5 ] && [ "$2" = -i ] && [ "${3#licenses/}" != "$3" ] && [ "$4 $5" = "--jq .body" ]; then
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

make_stub_npm() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
: "${STUB_NPM_LOG:?stub npm: STUB_NPM_LOG is not set}"
{
  printf '%s' "$PWD"
  for a in "$@"; do printf '\t%s' "$a"; done
  printf '\n'
} >>"$STUB_NPM_LOG"
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
printf '\nup to date in 2s\n'
STUB
  chmod +x "$path"
}

# ---------- safe defaults for the hooks ----------
# Every test runs with the hooks pointing at stubs that refuse: they log
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
make_refuser "$WORK/refuse/npm" BOOTSTRAP_NPM
export BOOTSTRAP_RUN="$WORK/refuse/run" BOOTSTRAP_GH="$WORK/refuse/gh" BOOTSTRAP_NPM="$WORK/refuse/npm"
# The pause between two checks of GitHub (BOOTSTRAP_SLEEP): a stand-in
# that waits for nothing, so no test waits for real. It appends the
# seconds it was asked to wait to $STUB_SLEEP_LOG (default $WORK/sleep.log).
cat >"$WORK/refuse/sleep" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"\${STUB_SLEEP_LOG:-$WORK/sleep.log}"
STUB
chmod +x "$WORK/refuse/sleep"
export BOOTSTRAP_SLEEP="$WORK/refuse/sleep"
# The terminal an offered command's yes is read from: a file that does not
# exist, so no test ever waits on the real terminal and no yes is given
# unless a test writes one.
export BOOTSTRAP_TTY="$WORK/no-terminal"
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

# ---------- fake tools and a fake home ----------
# git is real (its path is kept here); a test that needs git, npm, uname,
# brew or winget to behave otherwise puts a fake one first on PATH.

REAL_GIT="$(command -v git)"
REAL_DATE="$(command -v date)"
# The stub gh seeds and copies projects with the real git.
export STUB_GIT="$REAL_GIT"

# fake_tool <dir> <name> [output]: makes <dir>/bin/<name>. Each call is
# logged to <dir>/tools.log. While <dir>/<name>-fails holds a number above
# 0 it counts it down and fails as a missing command does (exit 127): a
# test writes 1 there for "missing, then installed by the user". Otherwise
# a fake git runs the real git, and any other fake prints [output].
fake_tool() {
  local d="$1" name="$2" out="${3:-}"
  mkdir -p "$d/bin"
  cat >"$d/bin/$name" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$name \$*" >>"$d/tools.log"
f="$d/$name-fails"
if [ -f "\$f" ]; then
  n="\$(cat "\$f")"
  if [ "\$n" -gt 0 ]; then echo \$((n - 1)) >"\$f"; echo "$name: command not found" >&2; exit 127; fi
fi
if [ "$name" = git ]; then exec "$REAL_GIT" "\$@"; fi
printf '%s\n' "$out"
EOF
  chmod +x "$d/bin/$name"
}

# fake_home <dir> [git name] [git email]: a home folder whose global git
# settings hold only the name and email given.
fake_home() {
  mkdir -p "$1"
  : >"$1/.gitconfig"
  [ -z "${2:-}" ] || "$REAL_GIT" config --file "$1/.gitconfig" user.name "$2"
  [ -z "${3:-}" ] || "$REAL_GIT" config --file "$1/.gitconfig" user.email "$3"
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

MSG_HELPERS='say|step_start|step_end|show_error|fail|lp_fail|stop_with_error|ask|ask_terminal|prompt_for|answer|add_problem|guide_begin|guide_step|guide_end'

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
  # remembering the hooks. A test that sets no hook runs no real
  # install, login, gh or npm: the harness defaults each to a stub that
  # refuses loudly (non-zero exit), so the forgetful test fails.
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
  # The lockfile step's npm (BOOTSTRAP_NPM), likewise.
  printf '#!/usr/bin/env bash\ntouch "%s/real-npm-ran"\n' "$d" >"$d/bin/npm"
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
    'needs a paid GitHub plan' 'the next steps of the setup are not built yet' \
    'To continue the setup, run this command' 'Making a copy of the project on this computer' \
    'line of work' 'already has' 'is inside another project that git keeps track of' \
    'The script may not write in the folder' 'does not exist' \
    "Filling in the project's name, description and product owner" 'in which the setup fills in' \
    'left for your first session with Clead'; do
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
  sed -n 1p "$d/err" | grep -q '^What happened: GitHub had a problem of its own' \
    || { cat "$d/err" >&2; die "no plain message first"; }
  sed -n 2p "$d/err" | grep -qE '^What to do next: .*few minutes' || { cat "$d/err" >&2; die "no next action"; }
  sed -n 3p "$d/err" | grep -qF 'Details for support' || { cat "$d/err" >&2; die "raw text not introduced"; }
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
  # --yes (needed with --non-interactive). The steps after the CHANGELOG
  # entry are not built yet: it stops there, with exit 1.
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
  [ "$rc" -eq 1 ] || { cat "$d/err" >&2; die "exit $rc, want 1"; }
  grep -qF 'the next steps of the setup are not built yet' "$d/err" || { cat "$d/err" >&2; die "no stop message"; }
  rm -rf "$d/created" "$d/remotes" "$d/cwd/my-app"
  rc=0
  ( cd "$d/cwd"; use_home "$d/home"; export PATH="$d/bin:$PATH" STUB_GH_LOG="$d/gh.log" BOOTSTRAP_GH="$d/gh" \
      STUB_NPM_LOG="$d/npm.log" BOOTSTRAP_NPM="$d/npm"
    bash "$RUN_SCRIPT" --non-interactive --yes "${REQUIRED_OPTS[@]}" ) <&- >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$d/err" >&2; die "stdin closed: exit $rc, want 1"; }
  grep -qF 'the next steps of the setup are not built yet' "$d/err" || { cat "$d/err" >&2; die "stdin closed: no stop message"; }
  # gh: the two checks on this computer, the GitHub checks (the account,
  # the published version, the name), then creating and protecting the
  # project, making the copy on this computer and reading the licence,
  # every one with gh's own prompts off; the copy is the only thing made
  # on this computer.
  [ "$(cut -f2- "$d/gh.log" | LC_ALL=C sort -u)" = "$(printf '%s\n' '--version' "$(printf 'repo\tcreate\t--help')" \
      "$(printf 'api\t-i\tuser\t--jq\t.login, (.name // "")')" \
      "$(printf 'api\t-i\t-H\tAccept: application/vnd.github.raw+json\trepos/factoincognito/ai-project-bootstrap/contents/CHANGELOG.md')" \
      "$(printf 'api\t-i\trepos/octo-user/my-app')" \
      "$(printf 'repo\tcreate\tocto-user/my-app\t--template\tfactoincognito/ai-project-bootstrap\t--public\t--description\tLends tools to neighbours.')" \
      "$(printf 'api\t-i\trepos/octo-user/my-app/branches/main')" \
      "$(printf 'api\t-i\trepos/octo-user/my-app/contents/CHANGELOG.md')" \
      "$(printf 'api\t-i\t-X\tPUT\trepos/octo-user/my-app/branches/main/protection\t--input\t-')" \
      "$(printf 'repo\tedit\tocto-user/my-app\t--delete-branch-on-merge\t--enable-squash-merge')" \
      "$(printf 'repo\tclone\tocto-user/my-app\t./my-app')" \
      "$(printf 'api\t-i\tlicenses/mit\t--jq\t.body')" | LC_ALL=C sort)" ] \
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
    --yes --dry-run --resume --help --git-name --git-email layout-pack; do
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
# detect_os, with PATH="<dir>/bin:/usr/bin:/bin" (so only the fake tools a
# test makes, plus the system's own, are found: no brew or winget unless
# faked), a stub gh, a stub runner and a stub npm (BOOTSTRAP_NPM, the
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
  mkdir -p "$d/cwd" "$d/bin"
  : >>"$d/run.log"
  : >>"$d/npm.log"
}

# in_env <dir>: the environment of a run, in the current subshell.
in_env() {
  local d="$1"
  cd "$d/cwd"
  use_home "$d/home"
  export PATH="$d/bin:/usr/bin:/bin" STUB_GH_LOG="$d/gh.log" BOOTSTRAP_GH="$d/gh" \
    STUB_RUN_LOG="$d/run.log" BOOTSTRAP_RUN="$d/run" STUB_SLEEP_LOG="$d/sleep.log" \
    STUB_NPM_LOG="$d/npm.log" BOOTSTRAP_NPM="$d/npm"
  # git never looks above the harness's own temp folder for a project,
  # so a test sees only the git projects it made itself.
  export GIT_CEILING_DIRECTORIES="$WORK"
  [ ! -e "$d/tty" ] || export BOOTSTRAP_TTY="$d/tty"
  [ ! -e "$d/os-release" ] || export BOOTSTRAP_OS_RELEASE="$d/os-release"
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

whole() {
  local d="$1"
  shift
  prepare "$d"
  set +e
  ( in_env "$d"; "$BASH" "${RUN_SCRIPT:-$SCRIPT}" "$@" ) <"$d/in" >"$d/out" 2>"$d/err"
  RC=$?
  set -e
}

# Settings for `pre`, run before the function they wrap.
ni() { OPT_NON_INTERACTIVE=1; "$@"; }
yes_opt() { OPT_YES=1; "$@"; }
resume() { OPT_RESUME=1; "$@"; }
with_pack() { IN_PACK="$1"; shift; "$@"; }
with_dir() { IN_DIR="$1"; shift; "$@"; }

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
    grep -qE "^    bash .*bootstrap-project\.sh --name my-app --description 'Lends tools\.' --pack node$" "$d/out" \
      || { cat "$d/out" >&2; die "the command to start again is not the one that was run (input '$input')"; }
    sed -n 1p "$d/err" | grep -qE '^What happened: .*git is not installed' || { cat "$d/err" >&2; die "no plain message"; }
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
  # without a second offer, and waits for Enter.
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
    expect_nothing_ran "$d"
    d="$(tmpdir)"
    fake_tool "$d" npm 10.0.0
    pre "$d" ni with_pack "$p" preflight_npm
    expect_rc 0 "$d"
    expect_out "$d" "    Done. npm is installed."
  done
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

test_resume_allows_a_folder_with_files_but_not_a_file() {
  local d
  d="$(tmpdir)"
  mkdir "$d/full"; touch "$d/full/x"
  pre "$d" ni resume with_dir "$d/full" preflight_target_dir
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
  "$REAL_GIT" init -q "$d/plain/copy"; touch "$d/plain/copy/x"
  pre "$d" ni resume with_dir "$d/plain/copy" preflight_target_dir
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
  # fresh read of the account) and the name. A dry run stops there.
  d="$(tmpdir)"
  working_git "$d"
  fake_tool "$d" npm 10.0.0
  whole "$d" --non-interactive --dry-run "${REQUIRED_OPTS[@]}"
  expect_rc 0 "$d"
  [ "$(awk -F'\t' '{ print $2 " " $NF }' "$d/gh.log")" = "$(printf '%s\n' '--version --version' 'repo --help' \
      'api .login, (.name // "")' 'api repos/factoincognito/ai-project-bootstrap/contents/CHANGELOG.md' \
      'api .login, (.name // "")' 'api repos/octo-user/my-app')" ] \
    || { cat "$d/gh.log" >&2; die "gh calls not in the order: tools, account, version, name"; }
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
  printf '%s\n' guide_git guide_gh_missing guide_gh_old guide_npm guide_dir_not_empty \
    guide_dir_is_file guide_bash_old gg_signed_out gg_expired gg_offline gg_permissions \
    gg_permissions_repo gg_permissions_token gg_old_script gg_project_exists \
    gg_create_taken gg_create_refused gg_protect_plan gg_protect_token gg_protect_unknown \
    guide_dir_no_parent gg_dir_not_writable gg_dir_in_git gg_dir_in_git_unknown
}
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

test_every_guide_says_why_how_what_you_see_and_how_it_is_checked() {
  # Ease-of-use requirements: every guide says why the step is needed,
  # gives numbered steps, what the user sees when it worked, what to do
  # otherwise, and how the script checks it; on every OS, with and without
  # brew or winget. Its output has no banned word.
  local d os g with label hits
  for os in macos linux windows; do
    for with in "" brew winget; do
      for g in $(guide_cases); do
        d="$(tmpdir)"
        on_os "$d" "$os"
        [ -z "$with" ] || fake_tool "$d" "$with"
        pre "$d" with_pack web with_dir "$d/f" "$g"
        label="$os/${with:-none}/$g"
        [ "$RC" -eq 0 ] || { cat "$d/err" >&2; die "$label failed"; }
        sed -n 1p "$d/out" | grep -qE '^[A-Za-z].{10,}\.$' || { cat "$d/out" >&2; die "$label: no one-line title first"; }
        grep -qE '^Why this is needed: ([^ ]+ ){5,}' "$d/out" || { cat "$d/out" >&2; die "$label: no why"; }
        grep -qE '^  1\. .{10,}' "$d/out" || { cat "$d/out" >&2; die "$label: no numbered step"; }
        grep -qE '^When it has worked: .{10,}' "$d/out" || { cat "$d/out" >&2; die "$label: no result"; }
        grep -qE '^If you see something else: .{10,}' "$d/out" || { cat "$d/out" >&2; die "$label: no fallback"; }
        grep -qE '^How the script checks it: .{10,}' "$d/out" || { cat "$d/out" >&2; die "$label: no check named"; }
        hits="$(grep -v '^    ' "$d/out" | awk '{print NR ": " $0}' | banned_hits)"
        [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; die "$label: banned word in the guide"; }
      done
    done
  done
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
  ! printf '%s\n' "$hits" | awk -F'[:\t]' -v f="$from" '$1 == f + 4' | grep -q . \
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
  sed -n 1p "$1/err" | grep -qE "^What happened: $2" || { cat "$1/err" >&2; die "first line is not: $2"; }
  sed -n 2p "$1/err" | grep -qE '^What to do next: .{10,}' || { cat "$1/err" >&2; die "no next action"; }
  sed -n 3p "$1/err" | grep -qxF 'Details for support (you can ignore these):' || { cat "$1/err" >&2; die "raw text not introduced"; }
  [ "$(sed -n '4,$p' "$1/err" | grep -vc '^    ')" -eq 0 ] || { cat "$1/err" >&2; die "raw text not indented below"; }
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
  expect_out "$d" "To start again, run this command:"
  expect_no_out "$d" "Run it now?"
  expect_nothing_ran "$d"
  sed -n 1p "$d/err" | grep -qE '^What happened: gh .* is not signed in' || { cat "$d/err" >&2; die "no plain error"; }
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
  cat >"$d/run" <<'RUN'
#!/usr/bin/env bash
printf '%s|%s\n' "$*" "${GH_PROMPT_DISABLED-<unset>}" >>"$STUB_RUN_LOG"
RUN
  chmod +x "$d/run"
  pre "$d" with_vis public preflight_github_permissions
  expect_rc 0 "$d"
  expect_out "$d" "does not have every permission on GitHub that the setup needs."
  expect_out "$d" "workflow (to add and change the files that run your project's checks)"
  grep -qxF '    gh auth refresh -h github.com -s workflow' "$d/out" || { cat "$d/out" >&2; die "the refresh command is not shown"; }
  expect_out "$d" "https://github.com/login/device"
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
  grep -qxF "    bash bootstrap-project.sh --name my-app --description 'Lends tools.'" "$d/out" \
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
# on this computer" below), after which the script stops: the next steps
# are not built yet (exit 1).

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
CLONE_CALL='repo clone octo-user/my-app ./my-app'
# Step 10, for setup_run's --license mit: the only gh call after the copy.
LICENSE_CALL='api -i licenses/mit --jq .body'
# The spec's body for step 3, field for field.
PROTECT_BODY='{"required_status_checks":null,"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":0},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}'
NOT_BUILT='the next steps of the setup are not built yet'

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
  mkdir -p "$1/dl" "$1/bin"
  cat >"$1/bin/date" <<EOF
#!/usr/bin/env bash
if [ "\$*" = +%Y-%m-%d ]; then echo $FAKE_TODAY; else exec "$REAL_DATE" "\$@"; fi
EOF
  chmod +x "$1/bin/date"
  [ -f "$1/dl/bootstrap-project.sh" ] || cp "$BUILT/bootstrap-project.sh" "$1/dl/bootstrap-project.sh"
  RUN_SCRIPT="$1/dl/bootstrap-project.sh"
  if [ -f "$1/changelog" ]; then STUB_GH_CHANGELOG="$1/changelog"; else STUB_GH_CHANGELOG="$BUILT/CHANGELOG.md"; fi
  export STUB_GH_CHANGELOG STUB_GH_TEMPLATE="${STUB_GH_TEMPLATE:-$BUILT}"
}

# setup_run <dir> <options...>: the whole script, as a user gets it (see
# use_built), with every input given (pack python, so npm is not needed;
# public unless --private is given) and a working git.
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
calls_from_create() {
  awk -F'\t' '$2 == "repo" && $3 == "create" && $4 != "--help" { on = 1 }
    on { out = $2; for (i = 3; i <= NF; i++) out = out " " $i; print out }' "$1/gh.log"
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

# expect_continue_command <dir> <ending>: the command to continue is
# shown under its own line, and ends as given.
expect_continue_command() {
  local line
  line="$(grep -A1 -xF 'To continue the setup, run this command:' "$1/out" | sed -n 2p)"
  case "$line" in
    "    bash "*"$2") ;;
    *) cat "$1/out" >&2; die "no command to continue ending in: $2 (got: $line)" ;;
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
  expect_out "$d" "This was a dry run (--dry-run): the checks passed, and nothing was created."
  expect_no_out "$d" "Proceed?"
  expect_no_out "$d" "needs a paid GitHub plan"
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

test_proceed_is_asked_with_no_as_its_default() {
  local d n why
  # yes: asked once, explained, then the project is created.
  d="$(tmpdir)"
  printf 'yes\n' >"$d/in"
  setup_run "$d"
  expect_rc 1 "$d"
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
    sed -n 1p "$d/err" | grep -q '^What happened: You answered no' || { cat "$d/err" >&2; die "answer [$a]: no plain stop"; }
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

test_yes_skips_proceed_and_non_interactive_needs_yes_or_dry_run() {
  local d
  d="$(tmpdir)"
  setup_run "$d" --yes
  expect_rc 1 "$d"
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
  expect_rc 1 "$d"
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$CLONE_CALL" "$LICENSE_CALL"
  # Byte for byte: the body as sent, then the line break the stub adds
  # (a here-string ends in one too, so two in all).
  printf '%s\n\n' "$PROTECT_BODY" >"$d/want-body"
  cmp -s "$d/want-body" "$d/protection-bodies" || { od -c "$d/protection-bodies" | tail -3 >&2; die "protection body is not the spec's"; }
  [ "$(cut -f1 "$d/gh.log" | LC_ALL=C sort -u)" = GH_PROMPT_DISABLED=1 ] || { cat "$d/gh.log" >&2; die "a gh call ran with prompts on"; }
  [ ! -s "$d/sleep.log" ] || die "it waited although the files were there"
  sed -n 1p "$d/err" | grep -qF "What happened: The project octo-user/my-app was created on GitHub and its main version is protected." \
    || { cat "$d/err" >&2; die "no plain stop after step 3"; }
  grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/err" >&2; die "the stop does not say the next steps are not built"; }
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
  expect_rc 1 "$d"
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
  expect_rc 1 "$d"
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$BRANCH_CALL" "$BRANCH_CALL" "$BRANCH_CALL" \
    "$FILES_CALL" "$FILES_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$CLONE_CALL" "$LICENSE_CALL"
  [ "$(cat "$d/sleep.log")" = "$(printf '2\n2\n2\n2\n2')" ] || { cat "$d/sleep.log" >&2; die "not 5 waits of 2 seconds"; }
  grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/err" >&2; die "did not reach the end of step 3"; }
  # Never there: 30 waits of 2 seconds (60 s), then a plain stop with the
  # command to continue; protection is not touched.
  d="$(tmpdir)"
  echo 9999 >"$d/main-missing"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  [ "$(grep -c . "$d/sleep.log")" -eq 30 ] && [ "$(sort -u "$d/sleep.log")" = 2 ] || { cat "$d/sleep.log" >&2; die "not 30 waits of 2 seconds"; }
  [ "$(calls_from_create "$d" | grep -cxF "$BRANCH_CALL")" -eq 31 ] || { cat "$d/gh.log" >&2; die "not 31 checks"; }
  ! calls_from_create "$d" | grep -qF -- '-X PUT' || { cat "$d/gh.log" >&2; die "protection was touched"; }
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
    expect_calls "$d" "${CREATE_CALL/--public/--private}" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL"
    expect_out "$d" "Details for support (you can ignore these):"
    grep -qE '^    HTTP 403: .' "$d/out" || { cat "$d/out" >&2; die "$mode: GitHub's message not shown below"; }
    expect_continue_command "$d" " --resume"
    expect_no_out "$d" "Press Enter"
    sed -n 1p "$d/err" | grep -q '^What happened: .*octo-user/my-app exists on GitHub' || { cat "$d/err" >&2; die "$mode: the stop does not say the project exists"; }
    expect_no_out "$d" "$NOT_BUILT"
    [ -z "$(ls -A "$d/cwd")" ] || die "$mode: something was made on this computer"
    case "$mode" in
      plan | mystery)
        expect_out "$d" "needs a paid GitHub plan"
        grep -qxF '    gh repo edit octo-user/my-app --visibility public --accept-visibility-change-consequences' "$d/out" \
          || { cat "$d/out" >&2; die "$mode: the command to make it public is not shown"; }
        grep -qE '^    bash .* --resume --allow-unprotected$' "$d/out" || { cat "$d/out" >&2; die "$mode: --allow-unprotected not shown"; }
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
  sed -n '/^==> Protecting/,$p' "$d/out" | grep -qF 'Why this is needed' && { cat "$d/out" >&2; die "rate limit: a guide was shown"; }
  unset STUB_GH_PROTECT_FAIL
  # Interactive too: it stops at once, with no wait.
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=plan
  printf 'yes\n\n\n' >"$d/in"
  setup_run "$d" --private
  expect_rc 3 "$d"
  expect_no_out "$d" "Press Enter"
  ! calls_from_create "$d" | grep -qF "$EDIT_CALL" || die "settings changed after the 403"
}

test_the_continue_command_names_the_owner_and_name_that_were_answered() {
  local d line
  d="$(tmpdir)"
  working_git "$d"
  export STUB_GH_PROTECT_FAIL=plan
  printf '%s\n' my-app "" "Lends tools." "" "" python "" none "" "" "" yes >"$d/in"
  whole "$d"
  expect_rc 3 "$d"
  expect_continue_command "$d" " --resume --owner octo-user --name my-app"
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
  ! calls_from_create "$d" | grep -qF "$EDIT_CALL" || die "settings changed after the 404"
  d="$(tmpdir)"
  export STUB_GH_PROTECT_FAIL=server
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" "GitHub had a problem of its own"
  expect_continue_command "$d" " --resume"
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
  grep -A1 -xF 'To start again, run this command:' "$d/out" | sed -n 2p >"$d/cmd"
  grep -q '^    bash ' "$d/cmd" && ! grep -qF -- '--resume' "$d/cmd" || { cat "$d/out" >&2; die "taken: not a plain new run"; }
  sed -n 1p "$d/err" | grep -q 'nothing was created' || { cat "$d/err" >&2; die "taken: does not say nothing was created"; }
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
  expect_no_out "$d" "$NOT_BUILT"
}

test_resume_stops_before_the_plan_until_it_is_built() {
  local d
  d="$(tmpdir)"
  export STUB_GH_EXISTING="octo-user/my-app"
  setup_run "$d" --non-interactive --yes --resume
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -qF -- '--resume' || { cat "$d/err" >&2; die "the stop does not name --resume"; }
  expect_no_out "$d" "Here is the plan"
  expect_nothing_created "$d"
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
    sed -n 2p "$d/err" | grep -qF 'continue the setup with the command shown above' || { cat "$d/err" >&2; die "$mode: next action is not to continue"; }
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
    sed -n 2p "$d/err" | grep -qF 'continue the setup with the command shown above' || { cat "$d/err" >&2; die "$want: next action is not to continue"; }
    ! grep -qiE 'run the script again|start the script again' "$d/err" || { cat "$d/err" >&2; die "$want: told to start again after create"; }
    unset "STUB_GH_${mode}_FAIL"
  done
  # Before create the same answer still says to start again.
  d="$(tmpdir)"
  export STUB_GH_USER_FAIL=teapot
  pre "$d" ni preflight_github_account
  expect_rc 1 "$d"
  expect_err_shape "$d" "Something unexpected happened, so the script could not read your GitHub account\.\$"
  sed -n 2p "$d/err" | grep -qF 'start the script again' || { cat "$d/err" >&2; die "before create: next action is not to start again"; }
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
# deploy files); then the tidy-up. Nothing is saved (committed) or sent
# (pushed) yet. Then the script stops: the next steps are not built yet
# (exit 1). These runs use the built, stamped script (use_built), and the
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

STEPS_AFTER_SETTINGS='==> Making a copy of the project on this computer, in ./my-app
==> Writing your name and email into the copy'"'"'s own git settings
==> Starting a separate line of work for the setup, named bootstrap-setup
==> Adding the python language pack'"'"'s files to the copy
==> Removing what only the setup needed from the copy
==> Filling in the project'"'"'s name, description and product owner in its files
==> Adding the project'"'"'s licence
==> Noting the setup in CHANGELOG.md, the project'"'"'s list of changes'

test_the_copy_is_made_by_gh_and_checked_against_the_script_version() {
  local d c
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_calls "$d" "$CREATE_CALL" "$BRANCH_CALL" "$FILES_CALL" "$PROTECT_CALL" "$EDIT_CALL" "$CLONE_CALL" "$LICENSE_CALL"
  [ "$(cut -f1 "$d/gh.log" | LC_ALL=C sort -u)" = GH_PROMPT_DISABLED=1 ] || { cat "$d/gh.log" >&2; die "a gh call ran with prompts on"; }
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" rev-parse origin/main)" = "$(in_git --git-dir="$(bare_of "$d")" rev-parse main)" ] \
    || die "the copy is not of the project that was made"
  # The new steps, in order, each with a start and a done line.
  [ "$(grep '^==> ' "$d/out" | sed -n '/^==> Setting how proposed/,$p' | sed 1d)" = "$STEPS_AFTER_SETTINGS" ] \
    || { cat "$d/out" >&2; die "the steps after the settings are not the copy, name, line of work, pack, tidy-up, fill, licence, CHANGELOG"; }
  [ "$(grep -c '^==> ' "$d/out")" -eq "$(grep -c '^    Done\. ' "$d/out")" ] || { cat "$d/out" >&2; die "a step has no done line"; }
  expect_out "$d" "    Done. The copy is in ./my-app, with the files of version $BUILT_VERSION of the bootstrapper."
  # The stop: what exists, that the next steps are not built, and the
  # command to continue.
  sed -n 1p "$d/err" | grep -qF "What happened: The project octo-user/my-app was created on GitHub and its main version is protected. Its copy on this computer, in ./my-app, has the python pack's files, ready for the next steps." \
    || { cat "$d/err" >&2; die "the stop does not say what exists"; }
  grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/err" >&2; die "the stop does not say the next steps are not built"; }
  expect_continue_command "$d" " --resume"
}

test_the_git_name_and_email_are_written_into_the_copy_only() {
  local d c
  d="$(tmpdir)"
  prepare "$d"
  cp "$d/home/.gitconfig" "$d/global-before"
  setup_run "$d" --non-interactive --yes --git-name "Ada Lovelace" --git-email ada@example.com
  expect_rc 1 "$d"
  c="$(copy_of "$d")"
  [ "$(in_git -C "$c" config --local --get user.name)" = "Ada Lovelace" ] || die "the name is not in the copy's settings"
  [ "$(in_git -C "$c" config --local --get user.email)" = ada@example.com ] || die "the email is not in the copy's settings"
  cmp -s "$d/global-before" "$d/home/.gitconfig" || { cat "$d/home/.gitconfig" >&2; die "the global git settings changed"; }
  # Written right after the copy is made, before the line of work starts,
  # and never with --global or --system.
  grep -n 'config user\.name Ada Lovelace' "$d/tools.log" | head -1 | cut -d: -f1 >"$d/n"
  grep -n ' checkout ' "$d/tools.log" | head -1 | cut -d: -f1 >"$d/b"
  [ -s "$d/n" ] && [ -s "$d/b" ] && [ "$(cat "$d/n")" -lt "$(cat "$d/b")" ] || { cat "$d/tools.log" >&2; die "the name was not written before the line of work"; }
  ! grep -E 'config (--global|--system|--file)' "$d/tools.log" | grep -qv -- ' --get ' || { cat "$d/tools.log" >&2; die "git settings outside the copy were written"; }
}

test_the_setup_starts_its_own_line_of_work_and_nothing_is_saved_or_sent() {
  local d c bare
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  c="$(copy_of "$d")"
  bare="$(bare_of "$d")"
  [ "$(in_git -C "$c" symbolic-ref --short HEAD)" = bootstrap-setup ] || die "the copy is not on bootstrap-setup"
  [ "$(in_git -C "$c" rev-parse HEAD)" = "$(in_git --git-dir="$bare" rev-parse main)" ] || die "bootstrap-setup does not start at main"
  [ "$(in_git -C "$c" rev-list --count HEAD)" -eq 1 ] || die "a commit was made"
  ! in_git -C "$c" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || die "bootstrap-setup follows a branch on GitHub"
  [ "$(in_git --git-dir="$bare" for-each-ref --format='%(refname)')" = refs/heads/main ] || die "something was sent to GitHub"
  [ -n "$(in_git -C "$c" status --porcelain)" ] || die "the setup's changes are not in the copy"
  [ "$(calls_from_create "$d" | tail -2)" = "$CLONE_CALL"$'\n'"$LICENSE_CALL" ] || { cat "$d/gh.log" >&2; die "gh was used after the copy for more than the licence"; }
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
  { tree_of "$BUILT" | grep -v '^languages/' | grep -vx 'bootstrap-project.sh'
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
  done < <(tree_of "$BUILT" | grep -v '^languages/' | grep -vx 'bootstrap-project.sh')
  # .gitignore: the bootstrapper's, then the pack's lines it lacked.
  { cat "$BUILT/.gitignore"
    while IFS= read -r f; do grep -qxF -- "$f" "$BUILT/.gitignore" || printf '%s\n' "$f"; done <"$BUILT/languages/$p/gitignore"
  } >"$d/gitignore"
  expect_same "$p$deploy: .gitignore" "$d/gitignore" "$c/.gitignore"
  # README.md: the section from "## After bootstrapping" up to the next
  # heading (## Setup) is gone, nothing else, and the rest filled in.
  grep -q '^## After bootstrapping' "$BUILT/README.md" || die "the built README has no setup section (test is stale)"
  sed '/^## After bootstrapping/,/^## Setup$/{/^## Setup$/!d;}' "$BUILT/README.md" >"$d/readme"
  [ "$(wc -l <"$d/readme")" -lt "$(wc -l <"$BUILT/README.md")" ] || die "the test's README expectation removed nothing"
  expect_filled "$d" "$p" "$deploy" README.md "$d/readme" "$c/README.md"
  # docs/DEV_INFRASTRUCTURE.md: the links to the other packs'
  # code-standards.md point to the template on GitHub; its own stays.
  cp "$BUILT/docs/DEV_INFRASTRUCTURE.md" "$d/dev"
  for other in node web python react-native; do
    [ "$other" != "$p" ] || continue
    grep -qF "\`languages/$other/code-standards.md\`" "$d/dev" || die "the doc has no link to $other (test is stale)"
    sed "s|\`languages/$other/code-standards.md\`|https://github.com/factoincognito/ai-project-template-v2/blob/main/languages/$other/code-standards.md|g" "$d/dev" >"$d/dev2"
    mv "$d/dev2" "$d/dev"
    ! grep -qE "(^|[^/])languages/$other/" "$c/docs/DEV_INFRASTRUCTURE.md" || die "$p$deploy: a link to the removed $other pack is left"
  done
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
    [ ! -f "$c/$f" ] || ! grep -q "$(printf '\r')" "$c/$f" || die "$p$deploy: $f has a carriage return"
  done
  # Every row of the fill table was checked against some file.
  want_fill_rows "$p" "$deploy" | awk -F'|' '{ print $1 "|" $3 }' | LC_ALL=C sort -u >"$d/rows"
  LC_ALL=C sort -u "$d/applied" >"$d/applied-rows"
  expect_same "$p$deploy: the fill rows checked" "$d/rows" "$d/applied-rows"
  # Left for the first session with Clead (spec step 8): not filled in.
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
    expect_rc 1 "$d"
    grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/err" >&2; die "$p$deploy: did not reach the end"; }
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
  sed -n 1p "$d/err" | grep -qF "What happened: The copy of the project on this computer already has tsconfig.json, which the node pack would add." \
    || { cat "$d/err" >&2; die "the existing target is not named"; }
  sed -n 2p "$d/err" | grep -qE '^What to do next: .{10,}' || { cat "$d/err" >&2; die "no next action"; }
  [ ! -e "$out/package.json" ] && [ "$(cat "$out/.github/workflows/ci.yml")" = stub ] && [ "$(cat "$out/.gitignore")" = x ] \
    && [ "$(cat "$out/tsconfig.json")" = '{}' ] || die "something was written before the error"
  # A folder target (python: starter/src/ to src/) that is there already.
  out="$d/copy3"
  mkdir -p "$out/src"
  rc=0
  ( load_script; layout_into python "$REPO/languages" "$out" overlay ) >"$d/out" 2>"$d/err" || rc=$?
  [ "$rc" -eq 1 ] || die "src/ there: exit $rc, want 1"
  sed -n 1p "$d/err" | grep -qF "already has src/, which the python pack would add." || { cat "$d/err" >&2; die "src/ not named"; }
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
  printf '%s\n' '# App' '' 'Intro.' '' '## After bootstrapping (delete this section when done)' '' 'Steps.' \
    '### A smaller heading' '##Not a heading' '' '## Setup' '' 'Run it.' >"$d/a"
  ( load_script; remove_setup_section "$d/a" ) || die "the section was not found"
  printf '%s\n' '# App' '' 'Intro.' '' '## Setup' '' 'Run it.' >"$d/want"
  expect_same "README" "$d/want" "$d/a"
  # The last section: removed up to the end of the file.
  printf '%s\n' '# App' '' '## Setup' 'x' '' '## After bootstrapping' 'y' >"$d/b"
  ( load_script; remove_setup_section "$d/b" ) || die "the last section was not found"
  printf '%s\n' '# App' '' '## Setup' 'x' '' >"$d/want"
  expect_same "README, last section" "$d/want" "$d/b"
  # No such section: the file is left as it is, and the function says so.
  printf '%s\n' '# App' '## Setup' 'After bootstrapping, run it.' >"$d/c"
  cp "$d/c" "$d/c0"
  rc=0
  ( load_script; remove_setup_section "$d/c" ) || rc=$?
  [ "$rc" -eq 1 ] || die "no section: returned $rc, want 1"
  cmp -s "$d/c0" "$d/c" || die "no section: the file changed"
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
  sed -n 1p "$d/err" | grep -qF "What happened: The copy of the project on this computer already has requirements.txt, which the python pack would add. The project octo-user/my-app exists on GitHub, with only the bootstrapper's files in it, and a copy of it is on this computer in ./my-app." \
    || { cat "$d/err" >&2; die "the stop does not name the file and what exists"; }
  sed -n 2p "$d/err" | grep -qE '^What to do next: .{10,}' || { cat "$d/err" >&2; die "no next action"; }
  expect_continue_command "$d" " --resume"
  ! grep -qF "$NOT_BUILT" "$d/err" || die "it went on after the error"
  c="$(copy_of "$d")"
  [ ! -e "$c/pyproject.toml" ] && [ -d "$c/languages/node" ] && [ -f "$c/bootstrap-project.sh" ] || die "something was laid out or removed"
  # A README.md without its setup section: a plain stop.
  d="$(tmpdir)"
  cp -R "$BUILT" "$d/template"
  sed '/^## After bootstrapping/d' "$BUILT/README.md" >"$d/template/README.md"
  export STUB_GH_TEMPLATE="$d/template"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -qF "What happened: The file README.md in the copy of the project has no section that starts with \"## After bootstrapping\", which the setup removes." \
    || { cat "$d/err" >&2; die "the missing section is not explained"; }
  expect_continue_command "$d" " --resume"
  ! grep -qF "$NOT_BUILT" "$d/err" || die "it went on after the error"
  # #152 review, finding 2: these files come from the project GitHub made
  # from the current bootstrapper, so downloading the script again cannot
  # help: the next action is to report it.
  sed -n 2p "$d/err" | grep -qF "Report it to the bootstrapper's maintainers" || { cat "$d/err" >&2; die "README: the next action is not to report it"; }
  ! grep -qF 'Download it again' "$d/err" || { cat "$d/err" >&2; die "README: told to download again"; }
  # A pack file missing from the project's languages/: the same.
  d="$(tmpdir)"
  cp -R "$BUILT" "$d/template"
  rm "$d/template/languages/python/pyproject.toml"
  export STUB_GH_TEMPLATE="$d/template"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -qF "What happened: missing from the pack: pyproject.toml" || { cat "$d/err" >&2; die "the missing pack file is not named"; }
  sed -n 2p "$d/err" | grep -qF "Report it to the bootstrapper's maintainers" || { cat "$d/err" >&2; die "pack file: the next action is not to report it"; }
  ! grep -qF 'Download it again' "$d/err" || { cat "$d/err" >&2; die "pack file: told to download again"; }
  expect_continue_command "$d" " --resume"
  unset STUB_GH_TEMPLATE
}

test_the_awk_helpers_take_a_path_named_like_a_setting() {
  # #152 review, finding 1, second line of defence: even with ./ in front
  # of the folder, the helpers that run awk on a file must read the file
  # itself when its path looks like name=value (here a=b/...), never
  # stdin. stdin holds a line that must not show up anywhere.
  local d
  d="$(tmpdir)"
  mkdir -p "$d/a=b"
  printf '%s\n' '# App' '## After bootstrapping' 'x' '## Setup' 'see languages/node/x' >"$d/a=b/README.md"
  printf '%s\n' 'dist/' >"$d/a=b/gitignore"
  printf '%s\n' 'node_modules/' >"$d/a=b/.gitignore"
  printf '%s\n' 'FROM-STDIN' >"$d/in"
  ( load_script; cd "$d"
    remove_setup_section a=b/README.md
    replace_text a=b/README.md languages/node/x URL
    add_missing_lines a=b/gitignore a=b/.gitignore ) <"$d/in" >"$d/out" 2>"$d/err" || { cat "$d/err" >&2; die "a helper failed"; }
  printf '%s\n' '# App' '## Setup' 'see URL' >"$d/want"
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
    [ "$(cat "$d/rc")" -eq 1 ] || { cat "$d/out" "$d/err" >&2; die "$dir: exit $(cat "$d/rc"), want 1"; }
    grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/err" >&2; die "$dir: did not reach the end"; }
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
  sed -n 2p "$d/err" | grep -qF 'continue the setup with the command shown above' || { cat "$d/err" >&2; die "next action is not to continue"; }
  expect_continue_command "$d" " --resume"
  [ "$(calls_from_create "$d" | tail -1)" = "$CLONE_CALL" ] || { cat "$d/gh.log" >&2; die "gh was used after the failed copy"; }
  [ -z "$(ls -A "$d/cwd")" ] || { ls -A "$d/cwd" >&2; die "something was left on this computer"; }
  ! grep -qF "$NOT_BUILT" "$d/err" || die "it went on after the error"
  # gh signed out in between: the sign-in next action, to continue.
  d="$(tmpdir)"
  export STUB_GH_CLONE_FAIL=signed-out
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
  expect_err_shape "$d" ".*is not signed in"
  sed -n 2p "$d/err" | grep -qF 'continue the setup with the command shown above' || { cat "$d/err" >&2; die "signed out: next action is not to continue"; }
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
# file in expect_setup_tree for every pack). Then the script stops: the
# next steps are not built yet (exit 1).

test_values_with_special_characters_are_copied_literally() {
  # Spec step 8: the replacement is literal (awk index() and substr(),
  # values passed through ENVIRON), so no character of a value is read
  # as part of a pattern or a replacement. The inputs refuse & \ " < > and
  # a backtick (they break JSON and HTML), so this run uses the other
  # characters that sed, awk or bash give a meaning to (. * $ ^ / % [ ]
  # ~ '), spaces and non-ASCII letters, and a dot in the project name,
  # which becomes a - in the slug. The description starts with
  # "## After bootstrapping": the fill runs after the tidy-up, so only the
  # README's real setup section is removed and the description stays.
  local d
  built_bootstrapper
  d="$(tmpdir)"
  fake_tool "$d" npm 10.0.0
  W_DISPLAY="Zoë's Shed *.* \$1 ^a/b\$ ~ [x] 100%s"
  W_PO="Zoë O'Brien \$HOME .* a/b [y]"
  W_DESCRIPTION="## After bootstrapping: lends tools (.*) \$0 a/b ^x\$ to Zoë's street, 100%."
  W_OWNER_AND_NAME=octo-user/Tool.Shed
  W_SLUG=tool-shed
  setup_run "$d" --non-interactive --yes --pack react-native --name Tool.Shed \
    --project-name "$W_DISPLAY" --po-name "$W_PO" --description "$W_DESCRIPTION"
  expect_rc 1 "$d"
  grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/out" "$d/err" >&2; die "did not reach the end"; }
  expect_setup_tree "$d" "$(copy_of "$d")" react-native
  # The values as typed, where a reader looks for them.
  grep -qxF "# $W_DISPLAY" "$(copy_of "$d")/README.md" || die "README.md: the display name is not the heading"
  grep -qxF "$W_DESCRIPTION" "$(copy_of "$d")/README.md" || die "README.md: the description line is not there"
  grep -qF '"slug": "tool-shed"' "$(copy_of "$d")/app.json" || die "app.json: the slug is not tool-shed"
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
  [ -x "$d/a=b/crlf.sh" ] || die "the executable bit was lost"
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
  sed -n 1p "$d/err" | grep -qF "What happened: The copy of the project on this computer has no docs/NEXT_SESSION.md, in which the setup fills in the project's name and other details. The project octo-user/my-app exists on GitHub, with only the bootstrapper's files in it, and a copy of it is on this computer in ./my-app." \
    || { cat "$d/err" >&2; die "the missing file is not named with what exists"; }
  sed -n 2p "$d/err" | grep -qF "Report it to the bootstrapper's maintainers" || { cat "$d/err" >&2; die "the next action is not to report it"; }
  expect_continue_command "$d" " --resume"
  ! grep -qF "$NOT_BUILT" "$d/err" || die "it went on after the error"
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
    memory/project.md docs/SPEC.md memory/context.md; do
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
# "## Project created" section (step 11). Then the script stops: the
# next steps are not built yet (exit 1). npm is the stub npm
# (BOOTSTRAP_NPM), so no test reaches the npm registry.

test_the_npm_packs_get_a_lockfile_made_by_npm_after_the_fill() {
  local d c p
  built_bootstrapper
  for p in node web react-native; do
    d="$(tmpdir)"
    fake_tool "$d" npm 10.0.0
    setup_run "$d" --non-interactive --yes --pack "$p"
    expect_rc 1 "$d"
    grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/out" "$d/err" >&2; die "$p: did not reach the end"; }
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
  expect_rc 1 "$d"
  grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/out" "$d/err" >&2; die "-app: did not reach the end"; }
  printf '%s\tinstall\t--package-lock-only\t--no-audit\t--no-fund\n' "$(cd "$d/cwd/-app" && pwd)" >"$d/want-npm"
  expect_same "-app: the npm calls" "$d/want-npm" "$d/npm.log"
  [ -f "$d/cwd/-app/package-lock.json" ] || die "-app: no lockfile"
  # python: no npm call, no lockfile.
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes
  expect_rc 1 "$d"
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
    sed -n 1p "$d/err" | grep -qF "What happened: npm could not record the exact versions of the node pack's tools in package-lock.json. The project octo-user/my-app exists on GitHub, with only the bootstrapper's files in it" \
      || { cat "$d/err" >&2; die "$mode: the first line does not say what happened"; }
    case "$mode" in
      offline) sed -n 2p "$d/err" | grep -qF "What to do next: Check that this computer is connected to the internet, then continue the setup with the command shown above." \
        || { cat "$d/err" >&2; die "offline: the next action is not to check the connection"; } ;;
      notarget) sed -n 2p "$d/err" | grep -qF "What to do next: Continue the setup with the command shown above. If the same thing happens, ask for help and show the details below." \
        || { cat "$d/err" >&2; die "notarget: the next action is not the plain fallback"; } ;;
    esac
    sed -n 3p "$d/err" | grep -qxF 'Details for support (you can ignore these):' || { cat "$d/err" >&2; die "$mode: no support block"; }
    grep -qxF "    npm error code $( [ "$mode" = offline ] && echo ENOTFOUND || echo ETARGET)" "$d/err" \
      || { cat "$d/err" >&2; die "$mode: npm's own text is not below for support"; }
    expect_continue_command "$d" " --resume"
    ! grep -qF "$NOT_BUILT" "$d/err" || die "$mode: it went on after npm failed"
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
  expect_rc 1 "$d"
  grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/out" "$d/err" >&2; die "did not reach the end"; }
  [ "$(grep -F "$(printf '\tlicenses/')" "$d/gh.log")" = "$(printf 'GH_PROMPT_DISABLED=1\tapi\t-i\tlicenses/mit\t--jq\t.body')" ] \
    || { cat "$d/gh.log" >&2; die "the licence was not read once, with gh's prompts off"; }
  c="$(copy_of "$d")"
  expect_setup_tree "$d" "$c" python
  [ ! -e "$c/NOTICE" ] || die "a NOTICE was made for mit"
  expect_out "$d" "    Done. LICENSE holds the licence mit, in the name of $W_HOLDER."
  d="$(tmpdir)"
  W_LICENSE=apache-2.0 W_HOLDER="Ada L"
  setup_run "$d" --non-interactive --yes --license apache-2.0
  expect_rc 1 "$d"
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
  expect_rc 1 "$d"
  grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/out" "$d/err" >&2; die "did not reach the end"; }
  ! grep -qF 'licenses/' "$d/gh.log" || { cat "$d/gh.log" >&2; die "GitHub was asked for the PolyForm text"; }
  c="$(copy_of "$d")"
  expect_setup_tree "$d" "$c" python
  cmp -s "$BUILT/licenses/NOTICE" "$c/licenses/NOTICE" || die "the template's own licenses/NOTICE changed"
  expect_out "$d" "    Done. LICENSE holds the PolyForm Noncommercial licence, and NOTICE names Ada L as the copyright holder."
}

test_no_licence_adds_no_file_and_warns_only_for_a_public_project() {
  # Spec step 10: none: no file, with a warning if the project is public.
  local d vis warning='Warning: the project is public and has no licence: anyone can see its code, but nobody else may copy, change or share it. To add a licence later, see https://choosealicense.com.'
  built_bootstrapper
  W_LICENSE=none
  for vis in --public --private; do
    d="$(tmpdir)"
    setup_run "$d" --non-interactive --yes --license none $vis
    expect_rc 1 "$d"
    grep -qF "$NOT_BUILT" "$d/err" || { cat "$d/out" "$d/err" >&2; die "$vis: did not reach the end"; }
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
  local d c
  built_bootstrapper
  d="$(tmpdir)"
  setup_run "$d" --non-interactive --yes --license made-up-2.0
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -qF "What happened: GitHub has no licence with the short name made-up-2.0, so the script could not add it. The project octo-user/my-app exists on GitHub" \
    || { cat "$d/err" >&2; die "the unknown licence is not named"; }
  sed -n 2p "$d/err" | grep -qF "https://choosealicense.com/licenses/" || { cat "$d/err" >&2; die "the next action does not say where to find the name"; }
  grep -qxF '    HTTP 404: Not Found' "$d/err" || { cat "$d/err" >&2; die "GitHub's answer is not below for support"; }
  expect_continue_command "$d" " --resume"
  ! grep -qF "$NOT_BUILT" "$d/err" || die "it went on after the 404"
  c="$(copy_of "$d")"
  [ ! -e "$c/LICENSE" ] || die "a LICENSE was written"
  ! grep -qF 'Set up by bootstrap-project.sh' "$c/CHANGELOG.md" || die "CHANGELOG.md was changed"
  d="$(tmpdir)"
  export STUB_GH_LICENSE_FAIL=server
  setup_run "$d" --non-interactive --yes
  unset STUB_GH_LICENSE_FAIL
  expect_rc 1 "$d"
  sed -n 1p "$d/err" | grep -qF "What happened: GitHub had a problem of its own, so the script could not read the text of the licence mit." \
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
  sed -n 1p "$d/err" | grep -qF 'has no section "## Project created"' || { cat "$d/err" >&2; die "no heading: not explained"; }
  sed -n 2p "$d/err" | grep -qF "Report it to the bootstrapper's maintainers" || { cat "$d/err" >&2; die "no heading: the next action is not to report it"; }
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
