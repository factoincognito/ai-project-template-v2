#!/usr/bin/env bash
# Tests for bootstrap/e2e-check.sh, the read-only checker for Adam's
# end-to-end runs of bootstrap-project.sh (spec: docs/BACKLOG.md, PBI-1.14,
# Testing, "End to end", and "Done when" 3 to 8).
# Usage: bash bootstrap/test-e2e-check.sh [test_name ...]
#
# Template-only: bootstrap/ is not in bootstrap/manifest.txt, so neither
# this file nor the checker ships. Runs on bash 3.2 as well as newer bash:
# no associative arrays, no mapfile, temp dirs from mktemp (never
# $RANDOM), one temp dir per test, names with a space in them.
#
# The finished run each test checks is made by the real bootstrap-project.sh
# functions (layout, tidy-up, fill, lockfile, licence, CHANGELOG and the
# self-check before the commit) over a real build.sh output, saved as two
# changes (GitHub's template change, then the setup merged as one change)
# in a local bare repo, and copied into a folder whose name has a space.
# GitHub is a stub gh that answers from JSON files shaped as GitHub's REST
# docs show them, through jq (so the checker's --jq expressions really
# run); git is the real one behind a logging wrapper. Every check run
# then proves the checker read only: no gh call but a GET, no git command
# that writes, and the folder unchanged byte for byte.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
CHECK="$HERE/e2e-check.sh"
SCRIPT="$HERE/stubs/bootstrap-project.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/test-e2e-check.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0
FAILED_NAMES=()

OWNER=octo-user
NAME=bootstrap-e2e-node-2026-10-15
SHA0=0123456789abcdef0123456789abcdef01234567
HEAD_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

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

# A fresh temp dir per call; its name has a space on purpose.
tmpdir() { mktemp -d "$WORK/t m p.XXXXXX"; }

command -v jq >/dev/null 2>&1 || { echo "These tests need jq (the stub gh runs the checker's --jq expressions with it)." >&2; exit 1; }

REAL_GIT="$(command -v git)"
# Tests run with a clean git environment: no global settings of the
# person running them.
export GIT_CONFIG_NOSYSTEM=1
HOME_DIR="$WORK/home"
mkdir -p "$HOME_DIR"
: >"$HOME_DIR/.gitconfig"
export HOME="$HOME_DIR"
unset XDG_CONFIG_HOME GIT_CONFIG_GLOBAL GH_TOKEN GITHUB_TOKEN GIT_DIR GIT_WORK_TREE
# Settings passed in the environment (GIT_CONFIG_COUNT and its keys, as
# some sandboxes set url.*.insteadOf with them) would change what git
# reports, such as the copy's remote.
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
G() { "$REAL_GIT" -c user.name=Tester -c user.email=tester@example.invalid -c init.defaultBranch=main "$@"; }

# The real bootstrapper, built once (build.sh is tested in bootstrap/test.sh).
BUILT="$WORK/built"
bash "$HERE/build.sh" "$BUILT" v9.9.9 "$SHA0" >/dev/null

MIT_BODY='MIT License

Copyright (c) [year] [fullname]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
'

# ---------- stub gh, git wrapper ----------
# gh: every call is logged to <d>/gh.log, one line, arguments separated by
# a tab. Only "api -i <endpoint>" and "api -i <endpoint> --jq <expr>" are
# answered, from <d>/github/<endpoint with / ? & = : made _>.json (200,
# the body through jq -r), or <same>.status ("<code> <message>": GitHub's
# error, raw JSON body, exit 1), else 404. STUB_GH_CR=1 ends each body line
# in CR LF (Windows); STUB_GH_OFFLINE=1 fails every call as gh does
# without a connection. Anything else exits 64, so a call the stub does
# not know never passes.
make_stub_gh() {
  cat >"$1/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
d="$(cd "$(dirname "$0")/.." && pwd)"
{ for a in "$@"; do printf '\t%s' "$a"; done; printf '\n'; } >>"$d/gh.log"
# <d>/during-check: a test's command, run once at the first gh call, so
# it lands while the checker runs (as git's background maintenance can).
if [ -x "$d/during-check" ] && [ ! -e "$d/during-check.done" ]; then
  : >"$d/during-check.done"
  "$d/during-check" >/dev/null 2>&1 || true
fi
if [ "${1:-}" != api ] || [ "${2:-}" != -i ]; then echo "stub gh: no emulation for: $*" >&2; exit 64; fi
ep="${3:-}"
expr=""
if [ "$#" -eq 5 ] && [ "$4" = --jq ]; then expr="$5"; elif [ "$#" -ne 3 ]; then echo "stub gh: no emulation for: $*" >&2; exit 64; fi
if [ -n "${STUB_GH_OFFLINE:-}" ]; then
  printf '%s\n' 'error connecting to api.github.com' 'check your internet connection or https://githubstatus.com' >&2
  exit 1
fi
key="$(printf '%s' "$ep" | tr '/?&=:' '_____')"
f="$d/github/$key.json"
err() {
  printf 'HTTP/2.0 %s %s\r\nContent-Type: application/json; charset=utf-8\r\n\r\n' "$1" "$2"
  printf '{"message":"%s","documentation_url":"https://docs.github.com/rest","status":"%s"}' "$2" "$1"
  printf 'gh: %s (HTTP %s)\n' "$2" "$1" >&2
  exit 1
}
if [ -f "$d/github/$key.status" ]; then
  read -r code msg <"$d/github/$key.status"
  err "$code" "$msg"
fi
[ -f "$f" ] || err 404 'Not Found'
printf 'HTTP/2.0 200 OK\r\nContent-Type: application/json; charset=utf-8\r\n\r\n'
if [ -n "$expr" ]; then
  jq -r "$expr" "$f" | tr -d '\r' | while IFS= read -r line || [ -n "$line" ]; do printf '%s%s\n' "$line" "${STUB_GH_CR:+$(printf '\r')}"; done
else
  cat "$f"
fi
STUB
  chmod +x "$1/bin/gh"
}

# git: a wrapper that logs every call to <d>/git.log (arguments separated
# by a tab), then runs the real git.
make_git_wrapper() {
  cat >"$1/bin/git" <<EOF
#!/usr/bin/env bash
{ for a in "\$@"; do printf '\t%s' "\$a"; done; printf '\n'; } >>"$1/git.log"
exec "$REAL_GIT" "\$@"
EOF
  chmod +x "$1/bin/git"
}

# ---------- the GitHub side ----------

gh_file() { printf '%s/github/%s.json' "$1" "$(printf '%s' "$2" | tr '/?&=:' '_____')"; }
# gh_set <d> <endpoint> <json>
gh_set() { mkdir -p "$1/github"; printf '%s\n' "$3" >"$(gh_file "$1" "$2")"; }
# gh_error <d> <endpoint> <code> <message>
gh_error() { local f; f="$(gh_file "$1" "$2")"; printf '%s %s\n' "$3" "$4" >"${f%.json}.status"; }
# gh_jq <d> <endpoint> <jq program>: changes the answer in place.
gh_jq() { local f t; f="$(gh_file "$1" "$2")"; t="$f.new"; jq "$3" "$f" >"$t"; mv "$t" "$f"; }

P="repos/$OWNER/$NAME"
PULLS_EP() { printf 'repos/%s/%s/pulls?state=all&head=%s:bootstrap-setup&per_page=100' "$OWNER" "$NAME" "$OWNER"; }
RUNS_EP() { printf 'repos/%s/%s/commits/%s/check-runs?per_page=100' "$OWNER" "$NAME" "$1"; }
COMMITS_EP() { printf 'repos/%s/%s/commits?sha=main&per_page=3' "$OWNER" "$NAME"; }

# sync_github <d>: the answers about main, its history and the setup
# change follow the bare repo (after a test changes it).
sync_github() {
  local d="$1" bare="$1/remotes/$OWNER/$NAME.git" main list
  main="$(G --git-dir="$bare" rev-parse refs/heads/main)"
  gh_set "$d" "$P/branches/main" "{\"name\":\"main\",\"commit\":{\"sha\":\"$main\"},\"protected\":true}"
  list="$(G --git-dir="$bare" rev-list --parents -n 3 refs/heads/main | awk '{
      printf "%s{\"sha\":\"%s\",\"parents\":[", (NR > 1 ? "," : ""), $1
      for (i = 2; i <= NF; i++) printf "%s{\"sha\":\"%s\"}", (i > 2 ? "," : ""), $i
      printf "]}"
    }')"
  gh_set "$d" "$(COMMITS_EP)" "[$list]"
  gh_set "$d" "$(PULLS_EP)" "[{\"number\":1,\"state\":\"closed\",\"title\":\"Set up $NAME\",\"merged_at\":\"2026-10-15T10:00:00Z\",\"merge_commit_sha\":\"$main\",\"head\":{\"ref\":\"bootstrap-setup\",\"sha\":\"$HEAD_SHA\"},\"base\":{\"ref\":\"main\"}}]"
}

# ---------- a finished run ----------

# finished <d> <pack> <licence> [yes: with deploy] [name]: the state a
# finished run leaves, in <d>: the project on "GitHub" (<d>/github and the
# bare repo <d>/remotes/OWNER/NAME.git) and its copy in "<d>/my copy".
finished() {
  local d="$1" pack="$2" lic="$3" deploy="${4:-}" name="${5:-$NAME}"
  local work="$d/work" bare npm
  NAME="$name"
  P="repos/$OWNER/$NAME"
  bare="$d/remotes/$OWNER/$NAME.git"
  mkdir -p "$d/bin" "$d/github" "$work"
  make_stub_gh "$d"
  make_git_wrapper "$d"
  : >"$d/gh.log"
  : >"$d/git.log"
  # GitHub's template change: the bootstrapper's files, as one commit.
  cp -R "$BUILT/." "$work/"
  G init -q "$work"
  G -C "$work" add -A
  G -C "$work" -c user.name=GitHub -c user.email=noreply@github.com commit -q -m "Initial commit"
  # The setup, by the script's own functions, then its self-check.
  npm="$d/fake-npm"
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "%s\n" "{\"name\":\"x\",\"lockfileVersion\":3,\"requires\":true,\"packages\":{}}" >package-lock.json' >"$npm"
  chmod +x "$npm"
  (
    set --
    # shellcheck source=/dev/null
    . "$SCRIPT"
    WORK_DIR="$(mktemp -d "$d/script-temp.XXXXXX")"
    IN_DIR="$work" IN_PACK="$pack" IN_WITH_DEPLOY="$deploy" IN_NAME="$NAME" IN_OWNER="$OWNER"
    IN_PROJECT_NAME="E2E App" IN_DESCRIPTION="A throwaway project for the end-to-end run."
    IN_PO_NAME="Octo User" IN_LICENSE="$lic" IN_COPYRIGHT_HOLDER="Octo User" IN_VISIBILITY=public
    IN_SLUG="$(slug_of "$NAME")"
    LICENCE_TEXT="${MIT_BODY%"$NL"}" LICENCE_TEXT_OF=mit
    export BOOTSTRAP_NPM="$npm"
    layout_into "$IN_PACK" "$IN_DIR/languages" "$IN_DIR" overlay "$IN_WITH_DEPLOY"
    tidy_up
    fill_placeholders
    make_lockfile
    add_licence
    note_setup_in_changelog
    self_check
  ) >"$d/setup.out" 2>&1 || { cat "$d/setup.out" >&2; die "the script's setup functions failed"; }
  G -C "$work" commit -q -m "Set up $NAME (#1)"
  G init -q --bare "$bare"
  G --git-dir="$bare" symbolic-ref HEAD refs/heads/main
  G -C "$work" push -q "$bare" main
  # The copy on this computer, as gh repo clone makes it.
  G clone -q "$bare" "$d/my copy"
  G -C "$d/my copy" remote set-url origin "https://github.com/$OWNER/$NAME.git"
  # GitHub's answers.
  gh_set "$d" "$P" "{\"id\":1,\"name\":\"$NAME\",\"full_name\":\"$OWNER/$NAME\",\"private\":false,\"visibility\":\"public\",\"default_branch\":\"main\",\"delete_branch_on_merge\":true,\"allow_squash_merge\":true,\"allow_merge_commit\":true,\"template_repository\":{\"id\":2,\"name\":\"ai-project-bootstrap\",\"full_name\":\"factoincognito/ai-project-bootstrap\"}}"
  # GET .../branches/main/protection, shaped as the REST doc's example
  # (restrictions left out, as for a project of a personal account).
  gh_set "$d" "$P/branches/main/protection" '{"url":"https://api.github.com/repos/o/n/branches/main/protection",
 "required_status_checks":{"strict":false,"contexts":["build"],"checks":[{"context":"build","app_id":15368}]},
 "required_pull_request_reviews":{"dismiss_stale_reviews":false,"require_code_owner_reviews":false,"required_approving_review_count":0},
 "required_signatures":{"enabled":false},"enforce_admins":{"enabled":true},
 "required_linear_history":{"enabled":false},"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false},
 "block_creations":{"enabled":false},"required_conversation_resolution":{"enabled":false},"lock_branch":{"enabled":false}}'
  # The check runs on the setup change's last commit: build from the push
  # and from the pull request; another workflow's check failed, which does
  # not count.
  gh_set "$d" "$(RUNS_EP "$HEAD_SHA")" '{"total_count":3,"check_runs":[
 {"id":1,"name":"build","head_sha":"'"$HEAD_SHA"'","status":"completed","conclusion":"success"},
 {"id":2,"name":"review","head_sha":"'"$HEAD_SHA"'","status":"completed","conclusion":"failure"},
 {"id":3,"name":"build","head_sha":"'"$HEAD_SHA"'","status":"completed","conclusion":"success"}]}'
  jq -n --arg body "$MIT_BODY" '{key:"mit",name:"MIT License",spdx_id:"MIT",body:$body}' >"$(gh_file "$d" licenses/mit)"
  sync_github "$d"
}

COPY() { printf '%s/my copy' "$1"; }

# change_setup <d> <shell code>: runs the code in the copy, then makes the
# result the setup change (amended), on GitHub and in the copy, so only
# what the code changed differs from a finished run.
change_setup() {
  local d="$1" bare="$1/remotes/$OWNER/$NAME.git" c
  c="$(COPY "$d")"
  (CDPATH='' cd "$c" && eval "$2")
  G -C "$c" add -A
  G -C "$c" commit -q --amend --no-edit
  G -C "$c" push -q -f "$bare" main
  G -C "$c" fetch -q "$bare" "+refs/heads/main:refs/remotes/origin/main"
  sync_github "$d"
}

# ---------- running the checker ----------

# snapshot <dir>: every path and the checksum of every file.
snapshot() {
  (CDPATH='' cd "$1" && find . -print | LC_ALL=C sort && find . -type f -exec cksum {} + | LC_ALL=C sort)
}

# run_check <d> [args...]: runs the checker (default arguments: the
# project and its copy) with the stub gh and the git wrapper first on
# PATH; output in <d>/out, exit code in <d>/rc. Then requires that it
# only read.
run_check() {
  local d="$1" rc=0
  shift
  [ "$#" -gt 0 ] || set -- "$OWNER/$NAME" "$(COPY "$d")"
  [ ! -d "$(COPY "$d")" ] || snapshot "$(COPY "$d")" >"$d/before"
  : >"$d/marker"
  PATH="$d/bin:$PATH" bash "$CHECK" "$@" >"$d/out" 2>&1 </dev/null || rc=$?
  echo "$rc" >"$d/rc"
  assert_read_only "$d"
}

# assert_read_only <d>: the logged calls hold no write, and the copy is as
# it was.
TAB="$(printf '\t')"
show() { printf '%s' "$1" | tr '\t' ' '; }

assert_read_only() {
  local d="$1" line sub
  if [ -s "$d/gh.log" ]; then
    while IFS= read -r line; do
      case "$line" in
        "${TAB}api${TAB}-i${TAB}"*) ;;
        *) die "gh call that is not a plain GET: $(show "$line")" ;;
      esac
      case "$line$TAB" in
        *"${TAB}-X"* | *"${TAB}--method"* | *"${TAB}-f${TAB}"* | *"${TAB}-F${TAB}"* | *"${TAB}--field"* | *"${TAB}--raw-field"* | *"${TAB}--input"*)
          die "gh call that could write: $(show "$line")" ;;
      esac
    done <"$d/gh.log"
  fi
  if [ -s "$d/git.log" ]; then
    while IFS= read -r line; do
      sub="$(printf '%s\n' "$line" | awk -F '\t' '{
          for (i = 2; i <= NF; i++) {
            if ($i == "-C" || $i == "-c") { i++; continue }
            if ($i ~ /^--no-optional-locks$|^--no-pager$|^--git-dir=|^--work-tree=/) continue
            print $i; exit
          }
        }')"
      case "$sub" in
        rev-parse | symbolic-ref | ls-files | rev-list | cat-file | log) ;;
        status)
          case "$line$TAB" in *"${TAB}--no-optional-locks${TAB}"*) ;; *) die "git status without --no-optional-locks (it may rewrite the index): $(show "$line")" ;; esac
          ;;
        grep)
          case "$line$TAB" in *"${TAB}-O"* | *"${TAB}--open-files-in-pager"*) die "git grep that opens files: $(show "$line")" ;; esac
          ;;
        remote)
          case "$line$TAB" in *"${TAB}remote${TAB}get-url${TAB}"*) ;; *) die "git remote other than get-url: $(show "$line")" ;; esac
          ;;
        *) die "git command that may write: $(show "$line")" ;;
      esac
    done <"$d/git.log"
  fi
  if [ -f "$d/before" ]; then
    [ -d "$(COPY "$d")" ] || die "the copy was removed"
    snapshot "$(COPY "$d")" >"$d/after"
    diff "$d/before" "$d/after" >&2 || die "the copy changed while the checker ran"
    [ -z "$(find "$(COPY "$d")" -newer "$d/marker" -print)" ] || die "files in the copy written while the checker ran: $(find "$(COPY "$d")" -newer "$d/marker" -print)"
  fi
}

rc_of() { cat "$1/rc"; }
expect_rc() { [ "$(rc_of "$1")" = "$2" ] || { cat "$1/out" >&2; die "exit code $(rc_of "$1"), want $2"; }; }

# result_of <d> <id>: PASS, FAIL or SKIP, from the line "<STATUS> <id>: <reason>".
result_of() { awk -v id="$2" '$2 == id ":" { print $1; exit }' "$1/out"; }

# expect_result <d> <id> <STATUS>: and the reason is not empty.
expect_result() {
  local got
  got="$(result_of "$1" "$2")"
  [ "$got" = "$3" ] || { cat "$1/out" >&2; die "$2 is '$got', want $3"; }
  grep -qE "^$3 $2: [^ ]" "$1/out" || { cat "$1/out" >&2; die "$2 has no reason"; }
}

# expect_only_fail <d> <id>: that check, and no other, failed; exit 1.
expect_only_fail() {
  local fails
  expect_rc "$1" 1
  fails="$(awk '$1 == "FAIL" { sub(/:$/, "", $2); print $2 }' "$1/out" | tr '\n' ' ')"
  [ "$fails" = "$2 " ] || { cat "$1/out" >&2; die "failed checks: '$fails', want only $2"; }
}

reason_of() { grep -E "^[A-Z]+ $2: " "$1/out" | sed -E "s/^[A-Z]+ $2: //"; }

GITHUB_CHECKS="project template merge-settings setup-change build history setup-branch protection decision-row"
LOCAL_CHECKS="copy changelog pack lockfile placeholders readme-section languages pack-links licence no-script line-endings no-keys"
SKIP_CHECKS="resume docs guides unaided ci-gate exempt-pr bot-comments"

# expect_all_pass <d>
expect_all_pass() {
  local id
  expect_rc "$1" 0
  for id in $GITHUB_CHECKS $LOCAL_CHECKS; do expect_result "$1" "$id" PASS; done
  for id in $SKIP_CHECKS; do expect_result "$1" "$id" SKIP; done
}

# ---------- usage ----------

test_help_prints_usage_and_exits_0() {
  local d
  d="$(tmpdir)"; mkdir -p "$d/bin"; make_stub_gh "$d"; make_git_wrapper "$d"
  run_check "$d" --help
  expect_rc "$d" 0
  grep -qF 'e2e-check.sh OWNER/NAME DIR' "$d/out" || { cat "$d/out" >&2; die "no usage line"; }
  grep -qi 'read' "$d/out" || die "help does not say it only reads"
  # Review round 2, items 3 and 8.
  grep -qF 'Test-exempt' "$d/out" && grep -qF 'exactly two commits' "$d/out" \
    || { cat "$d/out" >&2; die "help does not say to run it before the Test-exempt change is merged"; }
  grep -qF 'CHANGELOG' "$d/out" || die "help does not say the pack and licence are read from CHANGELOG.md"
  [ ! -s "$d/gh.log" ] && [ ! -s "$d/git.log" ] || die "--help called gh or git"
}

test_wrong_argument_count_exits_2() {
  local d
  d="$(tmpdir)"; mkdir -p "$d/bin"; make_stub_gh "$d"; make_git_wrapper "$d"
  run_check "$d" only-one
  expect_rc "$d" 2
  grep -qF 'e2e-check.sh OWNER/NAME DIR' "$d/out" || die "no usage on one argument"
  run_check "$d" a/b c d
  expect_rc "$d" 2
  [ ! -s "$d/gh.log" ] && [ ! -s "$d/git.log" ] || die "a usage error called gh or git"
}

test_bad_owner_name_exits_2() {
  local d n
  d="$(tmpdir)"; mkdir -p "$d/bin"; make_stub_gh "$d"; make_git_wrapper "$d"
  for n in noslash a/b/c '/name' 'owner/' 'ow ner/name' 'owner/na;me' '-x/y'; do
    run_check "$d" "$n" "$d"
    expect_rc "$d" 2
  done
  [ ! -s "$d/gh.log" ] || die "a bad name reached gh"
}

# ---------- finished runs pass ----------

test_finished_node_run_passes_every_check() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  run_check "$d"
  expect_all_pass "$d"
  grep -qE '^Result: 21 passed, 0 failed, 7 skipped\.$' "$d/out" || { cat "$d/out" >&2; die "summary line"; }
  # The checker did look at GitHub and at the copy.
  [ -s "$d/gh.log" ] && [ -s "$d/git.log" ] || die "no gh or git calls logged"
}

test_finished_runs_of_every_pack_and_licence_pass() {
  local d spec pack lic dep
  for spec in "web polyform-noncommercial-1.0.0 yes" "web none" "python none" "react-native mit" "node polyform-noncommercial-1.0.0"; do
    set -- $spec
    pack="$1" lic="$2" dep="${3:-}"
    echo "case: $spec"
    d="$(tmpdir)"; finished "$d" "$pack" "$lic" "$dep"
    run_check "$d"
    expect_all_pass "$d"
  done
}

test_answers_with_cr_lf_pass() {
  # gh on Windows may end lines with CR LF.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  STUB_GH_CR=1 run_check "$d"
  expect_all_pass "$d"
}

test_every_line_of_a_check_has_one_status_and_a_plain_reason() {
  local d n
  d="$(tmpdir)"; finished "$d" web mit
  run_check "$d"
  n="$(grep -cE '^(PASS|FAIL|SKIP) [a-z-]+: [^ ].*[.)]$' "$d/out")"
  [ "$n" = 28 ] || { cat "$d/out" >&2; die "$n check lines in the form '<STATUS> <id>: <reason>.', want 28"; }
  # No raw tool text: no HTTP status lines, JSON or gh's own words.
  ! grep -nE 'HTTP/|\{"|^gh: |fatal:' "$d/out" >&2 || die "raw tool text in the output"
}

# ---------- read-only ----------

test_the_read_only_guard_catches_writes() {
  # The guard every run goes through must fail on a write, or the tests
  # above prove nothing about it.
  local d bad
  d="$(tmpdir)"; mkdir -p "$d/bin"
  for bad in $'\tapi\t-i\t-X\tPUT\trepos/o/n/branches/main/protection' $'\tapi\t-i\trepos/o/n/issues\t-f\ttitle=x' \
             $'\tapi\t-i\t--method\tDELETE\trepos/o/n' $'\trepo\tdelete\to/n\t--yes' $'\tapi\t-i\trepos/o/n\t--input\t-' \
             $'\tpr\tmerge\t1'; do
    printf '%s\n' "$bad" >"$d/gh.log"; : >"$d/git.log"
    ! (assert_read_only "$d") 2>/dev/null || die "guard let through gh: $bad"
  done
  : >"$d/gh.log"
  for bad in $'\t-C\t/x\tfetch' $'\t-C\t/x\tstatus\t--porcelain' $'\t-C\t/x\tcheckout\tmain' $'\t-C\t/x\tremote\tset-url\torigin\tx' \
             $'\t-C\t/x\tbranch\t-D\tx' $'\t-C\t/x\tconfig\tuser.name\tx' $'\t-C\t/x\tgc' $'\t-C\t/x\tpull'; do
    printf '%s\n' "$bad" >"$d/git.log"
    ! (assert_read_only "$d") 2>/dev/null || die "guard let through git: $bad"
  done
  printf '%s\n' $'\t-C\t/x\t--no-optional-locks\tstatus\t--porcelain' $'\t-C\t/x\trev-parse\tHEAD' $'\t-C\t/x\tremote\tget-url\torigin' >"$d/git.log"
  (assert_read_only "$d") || die "guard refused plain reads"
  # A file changed in the copy.
  d="$(tmpdir)"; finished "$d" node mit
  : >"$d/gh.log"; : >"$d/git.log"
  snapshot "$(COPY "$d")" >"$d/before"; : >"$d/marker"
  printf 'x\n' >>"$(COPY "$d")/README.md"
  ! (assert_read_only "$d") 2>/dev/null || die "guard missed a changed file"
}

test_failing_run_is_read_only_too() {
  # The failure paths read only as well.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$(PULLS_EP)" '.[0].merged_at = null | .[0].state = "open"'
  gh_error "$d" "$P/branches/main/protection" 404 'Branch not protected'
  printf 'stray\n' >"$(COPY "$d")/stray.txt"
  run_check "$d"
  expect_rc "$d" 1
}

# ---------- the delete command ----------

test_delete_command_is_printed_and_never_run() {
  local d abs
  d="$(tmpdir)"; finished "$d" node mit
  run_check "$d"
  abs="$(CDPATH='' cd "$(COPY "$d")" && pwd)"
  grep -qxF "    gh auth refresh -h github.com -s delete_repo" "$d/out" || { cat "$d/out" >&2; die "no refresh line"; }
  grep -qxF "    gh repo delete $OWNER/$NAME --yes" "$d/out" || die "no delete line"
  grep -qxF "    rm -rf -- '$abs'" "$d/out" || { cat "$d/out" >&2; die "no folder removal line for '$abs'"; }
  # The delete hint comes after every check.
  [ "$(grep -nF 'gh repo delete' "$d/out" | cut -d: -f1)" -gt "$(grep -nE '^Result: ' "$d/out" | cut -d: -f1)" ] || die "delete hint before the result"
  ! grep -qF $'\trepo\t' "$d/gh.log" || die "gh repo was called"
  [ -d "$(COPY "$d")" ] || die "the copy is gone"
}

test_delete_command_quotes_a_folder_with_a_quote() {
  local d c
  d="$(tmpdir)"; finished "$d" node mit
  c="$d/it's here"
  mv "$(COPY "$d")" "$c"
  run_check "$d" "$OWNER/$NAME" "$c"
  grep -qxF "    rm -rf -- '$d/it'\\''s here'" "$d/out" || { cat "$d/out" >&2; die "folder not quoted for the shell"; }
}

test_delete_command_printed_when_checks_fail() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_error "$d" "$P/branches/main/protection" 404 'Branch not protected'
  run_check "$d"
  expect_rc "$d" 1
  grep -qxF "    gh repo delete $OWNER/$NAME --yes" "$d/out" || die "no delete line after a failure"
}

test_other_names_are_checked_but_get_no_delete_command() {
  local d
  d="$(tmpdir)"; finished "$d" node mit "" my-app
  run_check "$d" "$OWNER/my-app" "$(COPY "$d")"
  expect_all_pass "$d"
  ! grep -qF 'gh repo delete' "$d/out" || die "delete command shown for a name that is not bootstrap-e2e-*"
  ! grep -qF 'rm -rf' "$d/out" || die "folder removal shown for a name that is not bootstrap-e2e-*"
  grep -qF 'bootstrap-e2e-' "$d/out" || die "no line saying why there is no delete command"
}

# ---------- each check fails on its own ----------

test_project_missing_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_error "$d" "$P" 404 'Not Found'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" project FAIL
}

test_project_not_made_from_the_bootstrapper_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$P" '.template_repository = null'
  run_check "$d"; expect_only_fail "$d" template
  gh_jq "$d" "$P" '.template_repository = {"full_name":"someone/other-template"}'
  run_check "$d"; expect_only_fail "$d" template
}

test_merge_settings_fail() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$P" '.delete_branch_on_merge = false'
  run_check "$d"; expect_only_fail "$d" merge-settings
  gh_jq "$d" "$P" '.delete_branch_on_merge = true | .allow_squash_merge = false'
  run_check "$d"; expect_only_fail "$d" merge-settings
}

test_no_setup_change_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_set "$d" "$(PULLS_EP)" '[]'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" setup-change FAIL
}

test_two_setup_changes_fail() {
  # Done when 4: no duplicate proposed change.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$(PULLS_EP)" '. + [.[0] | .number = 2 | .state = "closed" | .merged_at = null | .merge_commit_sha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"]'
  run_check "$d"; expect_only_fail "$d" setup-change
}

test_setup_change_not_merged_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$(PULLS_EP)" '.[0].merged_at = null | .[0].state = "open"'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" setup-change FAIL
}

test_build_not_green_fails() {
  local d prog
  for prog in '.check_runs[0].conclusion = "failure"' '.check_runs[2].status = "in_progress" | .check_runs[2].conclusion = null' \
              '.check_runs |= map(select(.name != "build"))' '.check_runs[0].conclusion = "skipped"'; do
    d="$(tmpdir)"; finished "$d" node mit
    gh_jq "$d" "$(RUNS_EP "$HEAD_SHA")" "$prog"
    echo "case: $prog"
    run_check "$d"; expect_only_fail "$d" build
  done
}

test_build_answer_missing_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_error "$d" "$(RUNS_EP "$HEAD_SHA")" 403 'Resource not accessible by personal access token'
  run_check "$d"; expect_only_fail "$d" build
}

test_main_not_the_merged_change_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$(PULLS_EP)" '.[0].merge_commit_sha = "cccccccccccccccccccccccccccccccccccccccc"'
  run_check "$d"; expect_only_fail "$d" history
}

test_extra_commit_on_main_fails() {
  # Done when 4: no duplicate change. The setup arrived as two changes.
  local d bare
  d="$(tmpdir)"; finished "$d" node mit
  bare="$d/remotes/$OWNER/$NAME.git"
  G -C "$(COPY "$d")" commit -q --allow-empty -m "Set up again"
  G -C "$(COPY "$d")" push -q "$bare" main
  G -C "$(COPY "$d")" fetch -q "$bare" "+refs/heads/main:refs/remotes/origin/main"
  sync_github "$d"
  run_check "$d"; expect_only_fail "$d" history
  reason_of "$d" history | grep -qF '3 or more changes' || { cat "$d/out" >&2; die "the reason does not count the changes"; }
  reason_of "$d" history | grep -qF 'Test-exempt' || die "the reason does not name the usual cause (a change merged after the run)"
}

test_merge_with_two_parents_fails() {
  local d bare c side
  d="$(tmpdir)"; finished "$d" node mit
  bare="$d/remotes/$OWNER/$NAME.git"; c="$(COPY "$d")"
  # main = a merge commit of the template change and the setup.
  side="$(G -C "$c" rev-parse HEAD)"
  G -C "$c" reset -q --hard HEAD~1
  G -C "$c" merge -q --no-ff -m "Merge pull request #1" "$side"
  G -C "$c" push -q -f "$bare" main
  G -C "$c" fetch -q "$bare" "+refs/heads/main:refs/remotes/origin/main"
  sync_github "$d"
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" history FAIL
  # Two changes on main, the last with two parents (the other one a
  # second root, which no setup makes): only the parent count can tell.
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$(COMMITS_EP)" '.[0].parents += [{"sha":"dddddddddddddddddddddddddddddddddddddddd"}]'
  run_check "$d"; expect_only_fail "$d" history
}

test_setup_branch_left_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_set "$d" "$P/branches/bootstrap-setup" "{\"name\":\"bootstrap-setup\",\"commit\":{\"sha\":\"$HEAD_SHA\"}}"
  run_check "$d"; expect_only_fail "$d" setup-branch
  d="$(tmpdir)"; finished "$d" node mit
  G -C "$(COPY "$d")" branch -q bootstrap-setup
  run_check "$d"; expect_only_fail "$d" setup-branch
}

test_setup_branch_answer_other_than_404_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_error "$d" "$P/branches/bootstrap-setup" 500 'Server Error'
  run_check "$d"; expect_only_fail "$d" setup-branch
}

test_protection_not_as_specified_fails() {
  local d prog
  for prog in '.required_pull_request_reviews.required_approving_review_count = 1' \
              '.required_status_checks.contexts = []' '.required_status_checks = null' \
              '.required_status_checks.contexts = ["build","lint"]' '.required_status_checks.strict = true' \
              '.enforce_admins.enabled = false' '.allow_force_pushes.enabled = true' '.allow_deletions.enabled = true' \
              '.restrictions = {"users":[],"teams":[],"apps":[]}' 'del(.required_pull_request_reviews)'; do
    d="$(tmpdir)"; finished "$d" node mit
    gh_jq "$d" "$P/branches/main/protection" "$prog"
    echo "case: $prog"
    run_check "$d"; expect_only_fail "$d" protection
  done
}

test_main_not_protected_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_error "$d" "$P/branches/main/protection" 404 'Branch not protected'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" protection FAIL
  # Without the decision row, that row's check fails too.
  expect_result "$d" decision-row FAIL
}

test_unprotected_with_its_decision_row_still_fails_protection() {
  # --allow-unprotected writes the row; the e2e runs are public projects,
  # and "Done when" asks for protection, so protection still fails.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'printf "%s\n" "| 2026-10-15 | The main version (main) is not protected | because. |" >>memory/decisions.md'
  gh_error "$d" "$P/branches/main/protection" 404 'Branch not protected'
  run_check "$d"
  expect_only_fail "$d" protection
  expect_result "$d" decision-row PASS
}

test_private_project_refused_protection_says_it_is_expected() {
  # Review round 2, item 2: GitHub answers 403 for the protection of a
  # private project on a plan without protection (the text is GitHub's
  # as the script's tests have it; unverified). That is the
  # --allow-unprotected path: still FAIL for the e2e runs, in the right
  # words, and the decision row then counts.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$P" '.private = true | .visibility = "private"'
  change_setup "$d" 'printf "%s\n" "| 2026-10-15 | The main version (main) is not protected | because. |" >>memory/decisions.md'
  gh_error "$d" "$P/branches/main/protection" 403 'Upgrade to GitHub Pro or make this repository public to enable this feature.'
  run_check "$d"
  expect_only_fail "$d" protection
  reason_of "$d" protection | grep -qF 'expected' || { cat "$d/out" >&2; die "the reason does not say a 403 is expected here"; }
  reason_of "$d" protection | grep -qF 'private' || die "the reason does not name the private project"
  reason_of "$d" protection | grep -qF -- '--allow-unprotected' || die "the reason does not name --allow-unprotected"
  expect_result "$d" decision-row PASS
  # A public project refused the same way: a permission, not the plan.
  d="$(tmpdir)"; finished "$d" node mit
  gh_error "$d" "$P/branches/main/protection" 403 'Resource not accessible by personal access token'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" protection FAIL
  ! reason_of "$d" protection | grep -qF 'expected' || die "a public project's 403 is called expected"
}

test_unreadable_protection_is_never_called_protected() {
  # Review round 2, item 4 (mutant M04).
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_error "$d" "$P/branches/main/protection" 500 'Server Error'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" protection FAIL
  expect_result "$d" decision-row FAIL
  ! reason_of "$d" decision-row | grep -qF 'it is protected' || { cat "$d/out" >&2; die "decision-row claims main is protected"; }
  reason_of "$d" decision-row | grep -qF 'not known' || die "decision-row does not say it is not known"
}

test_decision_row_while_protected_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'printf "%s\n" "| 2026-10-15 | The main version (main) is not protected | because. |" >>memory/decisions.md'
  run_check "$d"; expect_only_fail "$d" decision-row
}

test_copy_not_clean_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  printf 'x\n' >>"$(COPY "$d")/docs/SPEC.md"
  run_check "$d"; expect_only_fail "$d" copy
  d="$(tmpdir)"; finished "$d" node mit
  printf 'x\n' >"$(COPY "$d")/notes.txt"
  run_check "$d"; expect_only_fail "$d" copy
}

test_copy_not_on_main_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  G -C "$(COPY "$d")" checkout -q -b other
  run_check "$d"; expect_only_fail "$d" copy
  d="$(tmpdir)"; finished "$d" node mit
  G -C "$(COPY "$d")" checkout -q --detach
  run_check "$d"; expect_only_fail "$d" copy
  reason_of "$d" copy | grep -qF 'on no line of work' || { cat "$d/out" >&2; die "the reason does not say the copy is detached"; }
}

test_copy_behind_github_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  G -C "$(COPY "$d")" reset -q --hard HEAD~1
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" copy FAIL
}

test_copy_of_another_project_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  G -C "$(COPY "$d")" remote set-url origin "https://github.com/$OWNER/other.git"
  run_check "$d"; expect_only_fail "$d" copy
}

test_copy_that_accepts_other_origin_forms() {
  # gh repo clone may give the remote with or without .git; ssh too.
  local d u
  for u in "https://github.com/$OWNER/$NAME" "git@github.com:$OWNER/$NAME.git"; do
    d="$(tmpdir)"; finished "$d" node mit
    G -C "$(COPY "$d")" remote set-url origin "$u"
    echo "case: $u"
    run_check "$d"; expect_all_pass "$d"
  done
}

test_folder_missing_or_not_a_copy_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  run_check "$d" "$OWNER/$NAME" "$d/nowhere"
  expect_rc "$d" 1
  expect_result "$d" copy FAIL
  expect_result "$d" project PASS
  expect_no_folder_removal "$d"
  mkdir "$d/plain"
  run_check "$d" "$OWNER/$NAME" "$d/plain"
  expect_rc "$d" 1
  expect_result "$d" copy FAIL
  expect_no_folder_removal "$d"
  # A folder inside the copy is not the copy.
  run_check "$d" "$OWNER/$NAME" "$(COPY "$d")/docs"
  expect_rc "$d" 1
  expect_result "$d" copy FAIL
  expect_no_folder_removal "$d"
}

# expect_no_folder_removal <d>: no rm line, a sentence saying why, and
# the project's delete command still shown (it depends on the name only).
expect_no_folder_removal() {
  ! grep -qF 'rm -rf' "$1/out" || { cat "$1/out" >&2; die "a folder removal command is shown for a folder that is not the project's copy"; }
  grep -qF 'No command to remove the folder is shown' "$1/out" || { cat "$1/out" >&2; die "no sentence saying why the folder removal is not shown"; }
  grep -qxF "    gh repo delete $OWNER/$NAME --yes" "$1/out" || { cat "$1/out" >&2; die "the project's delete command is gone"; }
}

test_no_folder_removal_unless_the_copy_check_passed() {
  # Review round 2, blocking 1: the rm line only for a folder that passed
  # the copy check. Another project's copy (as with "." run from inside
  # the template's own checkout), and a copy of this project that is not
  # clean, get a sentence instead.
  local d other
  d="$(tmpdir)"; finished "$d" node mit
  other="$d/template checkout"
  G clone -q "$d/remotes/$OWNER/$NAME.git" "$other"
  G -C "$other" remote set-url origin "https://github.com/factoincognito/ai-project-template-v2.git"
  run_check "$d" "$OWNER/$NAME" "$other"
  expect_result "$d" copy FAIL
  expect_no_folder_removal "$d"
  ( CDPATH='' cd "$other" && run_check "$d" "$OWNER/$NAME" . )
  expect_result "$d" copy FAIL
  expect_no_folder_removal "$d"
  # The right project, but not clean.
  printf 'x\n' >"$(COPY "$d")/stray.txt"
  run_check "$d"
  expect_only_fail "$d" copy
  expect_no_folder_removal "$d"
}

test_changelog_lines_missing_fail() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'grep -vxF -- "- Set up by bootstrap-project.sh." CHANGELOG.md >c.tmp; mv c.tmp CHANGELOG.md'
  run_check "$d"; expect_only_fail "$d" changelog
}

test_unknown_pack_fails_the_checks_that_need_it() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'grep -vxF -- "- Language pack: node." CHANGELOG.md >c.tmp; mv c.tmp CHANGELOG.md'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" changelog FAIL
  expect_result "$d" pack FAIL
  expect_result "$d" placeholders FAIL
  expect_result "$d" languages FAIL
}

test_pack_file_missing_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'git rm -q tsconfig.json'
  run_check "$d"; expect_only_fail "$d" pack
  d="$(tmpdir)"; finished "$d" web mit
  change_setup "$d" 'git rm -q -r e2e'
  run_check "$d"; expect_only_fail "$d" pack
}

test_web_deploy_files_follow_the_changelog() {
  # Without deploy the deploy files stay in languages/web; with it they
  # are laid out. A run without deploy whose CHANGELOG says "with" fails.
  local d
  d="$(tmpdir)"; finished "$d" web mit
  change_setup "$d" 'awk '"'"'{ if ($0 == "- Language pack: web.") print "- Language pack: web, with the files that publish the website."; else print }'"'"' CHANGELOG.md >c.tmp; mv c.tmp CHANGELOG.md'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" pack FAIL
  expect_result "$d" languages FAIL
}

test_lockfile_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'git rm -q package-lock.json'
  run_check "$d"; expect_only_fail "$d" lockfile
  d="$(tmpdir)"; finished "$d" python none
  change_setup "$d" 'printf "{}\n" >package-lock.json'
  run_check "$d"; expect_only_fail "$d" lockfile
}

test_placeholder_left_fails() {
  local d spec pack file text dep
  for spec in "node|docs/SPEC.md|[PROJECT NAME]" "node|memory/project.md|[OWNER/REPO]" "node|docs/SPEC.md|[DATE]" \
              "node|package.json|[project-name]" "node|README.md|[PO NAME]" \
              "node|README.md|[One or two sentences: what this project is and who it is for.]" \
              "web|index.html|[project-name]" "react-native|app.json|[project-slug]" "web yes|wrangler.jsonc|[project-name]"; do
    pack="${spec%%|*}"; file="${spec#*|}"; text="${file#*|}"; file="${file%%|*}"
    d="$(tmpdir)"
    # "web yes": the pack and deploy. (No case inside $( ): bash 3.2
    # cannot parse its ")".)
    dep=""
    [ "${pack#* }" = yes ] && dep=yes
    finished "$d" "${pack%% *}" mit "$dep"
    change_setup "$d" "printf '%s\n' '$text' >>'$file'"
    echo "case: $spec"
    run_check "$d"; expect_only_fail "$d" placeholders
    reason_of "$d" placeholders | grep -qF "$file" || { cat "$d/out" >&2; die "$spec: the reason does not name $file"; }
  done
}

test_fill_table_file_missing_fails() {
  # Review round 2, item 4 (mutant M20).
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'git rm -q docs/NEXT_SESSION.md'
  run_check "$d"; expect_only_fail "$d" placeholders
  reason_of "$d" placeholders | grep -qF docs/NEXT_SESSION.md || { cat "$d/out" >&2; die "the reason does not name the missing file"; }
}

test_licence_with_an_empty_holder_or_year_fails() {
  # Review round 2, item 5: each placeholder must be filled with text.
  local d line
  for line in 'Copyright (c) 2026 ' 'Copyright (c)  Octo User' 'Copyright (c) 2026  '; do
    echo "case: '$line'"
    d="$(tmpdir)"; finished "$d" node mit
    LINE="$line" change_setup "$d" 'awk '"'"'NR == 3 { print ENVIRON["LINE"]; next } { print }'"'"' LICENSE >l.tmp; mv l.tmp LICENSE'
    run_check "$d"; expect_only_fail "$d" licence
  done
}

test_licence_name_from_the_changelog_is_checked_before_use() {
  # Review round 2, item 6: the name goes into a gh api path only when it
  # looks like a licence key.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'awk '"'"'{ if ($0 == "- Licence: mit.") print "- Licence: ../user?x={owner}."; else print }'"'"' CHANGELOG.md >c.tmp; mv c.tmp CHANGELOG.md'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" changelog FAIL
  expect_result "$d" licence FAIL
  ! grep -F 'licenses/' "$d/gh.log" | grep -qF '..' || die "the name reached gh"
  ! grep -qF '{owner}' "$d/gh.log" || die "the name reached gh"
}

test_placeholder_over_two_lines_left_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'printf "%s\n%s\n" "[What the project is, who it is for, and what problem" "it solves.]" >>memory/project.md'
  run_check "$d"; expect_only_fail "$d" placeholders
}

test_placeholders_kept_where_the_spec_keeps_them_pass() {
  # [DATE] is a format token in memory/roles.md and docs/CROG_ONBOARDING.md;
  # kept pack files keep theirs (the finished runs above prove the
  # react-native and web ones).
  local d
  d="$(tmpdir)"; finished "$d" node mit
  grep -qF '[DATE]' "$(COPY "$d")/memory/roles.md" || die "fixture: roles.md has no [DATE]; the test checks nothing"
  run_check "$d"; expect_all_pass "$d"
}

test_licence_placeholders_left_fail() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'printf "%s\n" "Copyright (c) [year] [fullname]" >>LICENSE'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" placeholders FAIL
}

test_readme_section_left_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'printf "\n%s\n\nSteps.\n" "## After bootstrapping (delete this section when done)" >>README.md'
  run_check "$d"; expect_only_fail "$d" readme-section
}

test_languages_not_pruned_fails() {
  local d cmd
  for cmd in 'mkdir -p languages/python && printf "x\n" >languages/python/code-standards.md' \
             'printf "x\n" >languages/README.md' 'git rm -q languages/node/code-standards.md' \
             'printf "x\n" >languages/node/extra.md'; do
    d="$(tmpdir)"; finished "$d" node mit
    change_setup "$d" "$cmd"
    echo "case: $cmd"
    run_check "$d"; expect_only_fail "$d" languages
  done
  d="$(tmpdir)"; finished "$d" web mit
  change_setup "$d" 'git rm -q languages/web/deploy.yml'
  run_check "$d"; expect_only_fail "$d" languages
}

test_other_pack_links_not_rewritten_fail() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'printf "%s\n" "See \`languages/python/code-standards.md\`." >>docs/DEV_INFRASTRUCTURE.md'
  run_check "$d"; expect_only_fail "$d" pack-links
}

test_licence_not_as_chosen_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'git rm -q LICENSE'
  run_check "$d"; expect_only_fail "$d" licence
  reason_of "$d" licence | grep -qF 'no LICENSE file' || { cat "$d/out" >&2; die "the reason does not say LICENSE is missing"; }
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'printf "%s\n" "Some other text." >LICENSE'
  run_check "$d"; expect_only_fail "$d" licence
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'awk '"'"'NR == 5 { print "changed line" ; next } { print }'"'"' LICENSE >l.tmp; mv l.tmp LICENSE'
  run_check "$d"; expect_only_fail "$d" licence
  d="$(tmpdir)"; finished "$d" node none
  change_setup "$d" 'printf "x\n" >LICENSE'
  run_check "$d"; expect_only_fail "$d" licence
  d="$(tmpdir)"; finished "$d" node polyform-noncommercial-1.0.0
  change_setup "$d" 'git rm -q NOTICE'
  run_check "$d"; expect_only_fail "$d" licence
  d="$(tmpdir)"; finished "$d" node polyform-noncommercial-1.0.0
  change_setup "$d" 'printf "x\n" >>LICENSE'
  run_check "$d"; expect_only_fail "$d" licence
}

test_licence_text_unreadable_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_error "$d" licenses/mit 404 'Not Found'
  run_check "$d"; expect_only_fail "$d" licence
}

test_script_left_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'printf "#!/bin/sh\n" >bootstrap-project.sh'
  run_check "$d"; expect_only_fail "$d" no-script
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'mkdir -p tools && printf "#!/bin/sh\n" >tools/bootstrap-project.sh'
  run_check "$d"; expect_only_fail "$d" no-script
}

test_cr_lf_file_fails() {
  local d
  d="$(tmpdir)"; finished "$d" node mit
  # The project's .gitattributes would make it LF; this file opts out.
  change_setup "$d" 'printf "docs/notes.md -text\n" >.git/info/attributes; printf "a\r\nb\r\n" >docs/notes.md'
  run_check "$d"; expect_only_fail "$d" line-endings
}

test_key_in_a_file_fails_and_is_never_shown() {
  local d key
  key="ghp_$(printf 'A%.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36)"
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" "printf 'token: %s\n' '$key' >>docs/SPEC.md"
  run_check "$d"; expect_only_fail "$d" no-keys
  reason_of "$d" no-keys | grep -qF docs/SPEC.md || die "the reason does not name the file"
  ! grep -qF "$key" "$d/out" || die "the key was shown"
  key="github_pat_$(printf 'B%.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22)"
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" "printf 'token: %s\n' '$key' >>README.md"
  run_check "$d"; expect_only_fail "$d" no-keys
  ! grep -qF "$key" "$d/out" || die "the fine-grained key was shown"
}

test_github_unreachable_fails_every_github_check_plainly() {
  local d id
  d="$(tmpdir)"; finished "$d" node mit
  STUB_GH_OFFLINE=1 run_check "$d"
  expect_rc "$d" 1
  for id in $GITHUB_CHECKS; do
    [ "$(result_of "$d" "$id")" = FAIL ] || { [ "$id" = decision-row ] && [ "$(result_of "$d" "$id")" = PASS ]; } \
      || { cat "$d/out" >&2; die "$id is $(result_of "$d" "$id") with GitHub unreachable"; }
  done
  expect_result "$d" copy FAIL
  reason_of "$d" project | grep -qF 'gh auth status' || { cat "$d/out" >&2; die "no next step for an unreachable GitHub"; }
  ! grep -nE 'error connecting|githubstatus' "$d/out" >&2 || die "gh's own words in the output"
}

test_git_settings_in_the_copy_run_no_command() {
  # Review round 2, item 7: core.fsmonitor in the copy's settings names a
  # command that git status would run.
  local d h
  d="$(tmpdir)"; finished "$d" node mit
  # git runs the setting through a shell: a folder without a space.
  h="$(mktemp -d "$WORK/hook.XXXXXX")"
  printf '#!/bin/sh\n: >"%s/RAN"\nexit 1\n' "$h" >"$h/hook.sh"
  chmod +x "$h/hook.sh"
  G -C "$(COPY "$d")" config core.fsmonitor "$h/hook.sh"
  run_check "$d"
  [ ! -e "$h/RAN" ] || die "a command named in the copy's git settings ran"
  expect_all_pass "$d"
}

# ---------- git's own maintenance (review round 3) ----------
# CI's newer git started its automatic maintenance (gc --auto, detached)
# after a command of the harness, and it wrote into the copy while the
# checker ran: the snapshot differed. Every repo the tests build turns
# it off in its own settings, and the checker turns it off on every git
# call it makes.

# aggressive_home: in this (sub)shell, global git settings that make
# gc --auto act on any project with two packs.
aggressive_home() {
  local h
  h="$(mktemp -d "$WORK/home.XXXXXX")"
  printf '[gc]\n\tauto = 1\n\tautoPackLimit = 1\n\tautoDetach = false\n[maintenance]\n\tauto = true\n[receive]\n\tautogc = true\n' >"$h/.gitconfig"
  export HOME="$h"
}

test_harness_repos_turn_off_gits_own_maintenance() {
  local d r v
  d="$(tmpdir)"; finished "$d" node mit
  for r in "$(COPY "$d")/.git" "$d/remotes/$OWNER/$NAME.git" "$d/work/.git"; do
    v="$("$REAL_GIT" --git-dir="$r" config --local --get gc.auto || true)"
    [ "$v" = 0 ] || die "gc.auto is '$v' in $r"
    v="$("$REAL_GIT" --git-dir="$r" config --local --get maintenance.auto || true)"
    [ "$v" = false ] || die "maintenance.auto is '$v' in $r"
    v="$("$REAL_GIT" --git-dir="$r" config --local --get receive.autogc || true)"
    [ "$v" = false ] || die "receive.autogc is '$v' in $r"
  done
}

test_gits_own_maintenance_during_a_check_changes_nothing() {
  # The race, made certain: gc --auto runs in the copy at the checker's
  # first gh call, with global settings under which it repacks.
  local d c
  aggressive_home
  d="$(tmpdir)"; finished "$d" node mit
  c="$(COPY "$d")"
  # A second pack, so gc --auto has work under gc.autoPackLimit = 1.
  printf '%s\n' "$(G -C "$c" rev-parse HEAD)" | G -C "$c" pack-objects -q --revs "$c/.git/objects/pack/pack" >/dev/null
  [ "$(find "$c/.git/objects/pack" -name '*.pack' | wc -l | tr -d ' ')" -ge 2 ] || die "fixture: no second pack"
  printf '#!/bin/sh\nexec "%s" -C "%s" gc --auto --quiet\n' "$REAL_GIT" "$c" >"$d/during-check"
  chmod +x "$d/during-check"
  run_check "$d"
  [ -e "$d/during-check.done" ] || die "the maintenance did not run during the check; the test checks nothing"
  expect_all_pass "$d"
}

test_every_git_call_of_the_checker_turns_off_what_could_write() {
  # The checker itself: gc.auto=0, maintenance.auto=false and
  # core.fsmonitor=false as -c settings, and --no-optional-locks, on
  # every git call.
  local d line want
  d="$(tmpdir)"; finished "$d" node mit
  run_check "$d"
  expect_all_pass "$d"
  [ -s "$d/git.log" ] || die "no git calls logged"
  while IFS= read -r line; do
    for want in "${TAB}-c${TAB}gc.auto=0${TAB}" "${TAB}-c${TAB}maintenance.auto=false${TAB}" \
                "${TAB}-c${TAB}core.fsmonitor=false${TAB}" "${TAB}--no-optional-locks${TAB}"; do
      case "$line$TAB" in *"$want"*) ;; *) die "git call without $(show "$want"): $(show "$line")" ;; esac
    done
  done <"$d/git.log"
}

# ---------- review round 2, non-blocking 1 to 3 ----------

test_folder_removal_names_the_absolute_folder_for_a_relative_dir() {
  # M56: pasted from another folder, a relative path would delete the
  # wrong one.
  local d abs
  d="$(tmpdir)"; finished "$d" node mit
  abs="$(CDPATH='' cd "$(COPY "$d")" && pwd)"
  ( CDPATH='' cd "$d" && run_check "$d" "$OWNER/$NAME" "my copy" )
  expect_all_pass "$d"
  grep -qxF "    rm -rf -- '$abs'" "$d/out" || { cat "$d/out" >&2; die "no absolute folder in the removal line"; }
}

test_no_folder_removal_for_a_symbolic_link() {
  # Item 2: rm -rf on a link removes only the link. The safer choice:
  # no removal line for a link, and a sentence saying so.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  ln -s "$(COPY "$d")" "$d/link"
  [ -L "$d/link" ] || die "fixture: no symbolic link here"
  run_check "$d" "$OWNER/$NAME" "$d/link"
  expect_all_pass "$d"
  expect_no_folder_removal "$d"
  grep -qF 'symbolic link' "$d/out" || { cat "$d/out" >&2; die "the sentence does not say it is a link"; }
}

test_folder_sentences_say_what_is_wrong() {
  # Item 3: a missing folder, and a copy with unsaved work.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  run_check "$d" "$OWNER/$NAME" "$d/nowhere"
  grep -F 'No command to remove the folder is shown' "$d/out" | grep -qF 'does not exist' \
    || { cat "$d/out" >&2; die "missing folder: the sentence does not say it does not exist"; }
  printf 'x\n' >"$(COPY "$d")/stray.txt"
  run_check "$d"
  grep -F 'No command to remove the folder is shown' "$d/out" | grep -qF 'unsaved work' \
    || { cat "$d/out" >&2; die "dirty copy: the sentence does not name unsaved work"; }
}

test_near_miss_names_get_no_delete_command() {
  # M04: only names that start with bootstrap-e2e- (with the dash).
  local d n
  for n in bootstrap-e2e bootstrap-x bootstrap-e2ex-1; do
    echo "case: $n"
    d="$(tmpdir)"; finished "$d" node mit "" "$n"
    run_check "$d" "$OWNER/$n" "$(COPY "$d")"
    expect_all_pass "$d"
    ! grep -qF 'gh repo delete' "$d/out" || die "$n: delete command shown"
  done
}

test_licence_name_with_a_slash_is_refused() {
  # M13: a / alone must be refused too.
  local d n
  for n in ../user a/b; do
    echo "case: $n"
    d="$(tmpdir)"; finished "$d" node mit
    N="$n" change_setup "$d" 'awk '"'"'{ if ($0 == "- Licence: mit.") print "- Licence: " ENVIRON["N"] "."; else print }'"'"' CHANGELOG.md >c.tmp; mv c.tmp CHANGELOG.md'
    run_check "$d"
    expect_result "$d" changelog FAIL
    expect_result "$d" licence FAIL
    ! grep -qF 'licenses/' "$d/gh.log" || die "$n reached gh"
  done
}

test_private_refusal_without_the_row_fails_the_row() {
  # M09.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$P" '.private = true | .visibility = "private"'
  gh_error "$d" "$P/branches/main/protection" 403 'Upgrade to GitHub Pro or make this repository public to enable this feature.'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" protection FAIL
  expect_result "$d" decision-row FAIL
}

test_private_refusal_for_another_reason_is_not_called_expected() {
  # Item 3: only GitHub's plan message is the --allow-unprotected path.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$P" '.private = true | .visibility = "private"'
  gh_error "$d" "$P/branches/main/protection" 403 'API rate limit exceeded for user ID 1.'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" protection FAIL
  ! reason_of "$d" protection | grep -qF 'expected' || { cat "$d/out" >&2; die "a rate limit is called the plan case"; }
  reason_of "$d" decision-row | grep -qF 'not known' || die "decision-row should not judge the row"
}

test_private_protected_project_passes() {
  # M06: a private project on a plan with protection.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$P" '.private = true | .visibility = "private"'
  run_check "$d"
  expect_all_pass "$d"
}

test_template_of_the_same_name_elsewhere_fails() {
  # M34.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$P" '.template_repository = {"full_name":"someone/ai-project-bootstrap"}'
  run_check "$d"; expect_only_fail "$d" template
}

test_mixed_line_endings_fail() {
  # M44.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  change_setup "$d" 'printf "docs/notes.md -text\n" >.git/info/attributes; printf "a\r\nb\n" >docs/notes.md'
  run_check "$d"; expect_only_fail "$d" line-endings
}

test_two_merged_setup_changes_leave_nothing_to_judge() {
  # M54: with two merged changes neither is taken as the setup.
  local d
  d="$(tmpdir)"; finished "$d" node mit
  gh_jq "$d" "$(PULLS_EP)" '. + [.[0] | .number = 2]'
  run_check "$d"
  expect_rc "$d" 1
  expect_result "$d" setup-change FAIL
  expect_result "$d" build FAIL
  expect_result "$d" history FAIL
}

test_notice_with_other_text_fails() {
  # M57.
  local d
  d="$(tmpdir)"; finished "$d" node polyform-noncommercial-1.0.0
  change_setup "$d" 'printf "Copyright someone\n" >NOTICE'
  run_check "$d"; expect_only_fail "$d" licence
}

# ---------- what it cannot see ----------

test_skips_only_what_it_cannot_see_and_says_why() {
  local d id ids
  d="$(tmpdir)"; finished "$d" node mit
  run_check "$d"
  ids="$(awk '$1 == "SKIP" { sub(/:$/, "", $2); print $2 }' "$d/out" | tr '\n' ' ')"
  [ "$ids" = "$SKIP_CHECKS " ] || die "skipped: '$ids', want '$SKIP_CHECKS '"
  for id in $SKIP_CHECKS; do
    reason_of "$d" "$id" | grep -qiE 'cannot|only|not visible|not something' || { cat "$d/out" >&2; die "$id: the reason does not say why it cannot be seen"; }
  done
}

# ---------- the checker's tables match the script ----------
# The checker states the fill table, the layout, the read-back, the
# decision row, the README heading and the key patterns again (it must
# not depend on the script of the release Adam ran being the one in this
# checkout). These tests keep the two in step.

# load_check: sources the checker, defining its functions only.
load_check() { set --; . "$CHECK"; }
load_script() { set --; . "$SCRIPT"; }

test_checker_can_be_sourced_without_running() {
  local out
  # && not ;: errexit does not reach into $( ) on bash before 4.4.
  out="$(load_check 2>&1 && echo loaded)" || die "sourcing failed"
  [ "$out" = loaded ] || die "sourcing printed: $out"
}

test_fill_table_matches_the_script() {
  local pack dep a b
  for pack in node web python react-native; do
    for dep in "" yes; do
      [ "$pack" = web ] || [ -z "$dep" ] || continue
      a="$(load_script; fill_rows "$pack" "$dep"; while read -r f k; do fill_text "$k"; printf '%s|%s\n' "$f" "${FILL_TEXT//$NL/<NL>}"; done <<<"$FILL_ROWS"; fill_text year; printf 'LICENSE|%s\n' "$FILL_TEXT"; fill_text fullname; printf 'LICENSE|%s\n' "$FILL_TEXT")"
      b="$(load_check; placeholder_rows "$pack" "$dep")"
      [ "$(printf '%s\n' "$a" | LC_ALL=C sort)" = "$(printf '%s\n' "$b" | LC_ALL=C sort)" ] \
        || { diff <(printf '%s\n' "$a" | LC_ALL=C sort) <(printf '%s\n' "$b" | LC_ALL=C sort) >&2; die "fill table differs for $pack $dep"; }
    done
  done
}

test_layout_matches_the_script() {
  local pack dep t kept_s targets_s kept_c targets_c f covered x
  for pack in node web python react-native; do
    for dep in "" yes; do
      [ "$pack" = web ] || [ -z "$dep" ] || continue
      t="$(tmpdir)"
      read -r kept_s <<<"$(load_script; layout_into "$pack" "$REPO/languages" "$t/out" strict "$dep" >/dev/null; printf '%s\n' "$LP_KEPT")"
      targets_s="$(load_script; layout_into "$pack" "$REPO/languages" "$t/out2" strict "$dep" >/dev/null; printf '%s\n' $LP_TARGETS)"
      kept_c="$(load_check; pack_kept "$pack" "$dep")"
      targets_c="$(load_check; pack_targets "$pack" "$dep")"
      [ "$(printf '%s\n' $kept_s | LC_ALL=C sort)" = "$(printf '%s\n' $kept_c | LC_ALL=C sort)" ] || die "$pack $dep: kept files '$kept_c', script '$kept_s'"
      # Every file the script lays out is a target of the checker (a
      # folder target, ending in /, covers the files in it), and every
      # target of the checker is laid out.
      for f in $targets_s; do
        covered=""
        for x in $targets_c; do
          case "$x" in */) case "$f" in "$x"*) covered=1 ;; esac ;; *) [ "$f" != "$x" ] || covered=1 ;; esac
        done
        [ -n "$covered" ] || die "$pack $dep: the script lays out $f, which the checker does not check"
      done
      for x in $targets_c; do
        covered=""
        for f in $targets_s; do
          case "$x" in */) case "$f" in "$x"*) covered=1 ;; esac ;; *) [ "$f" != "$x" ] || covered=1 ;; esac
        done
        [ -n "$covered" ] || die "$pack $dep: the checker expects $x, which the script does not lay out"
      done
    done
  done
}

test_readback_and_other_texts_match_the_script() {
  local s c
  s="$(load_script; printf '%s\n' "$READBACK_JQ" "$REQUIRE_READBACK" "$UNPROTECTED_ROW_KEY" "$SETUP_HEADING" "$KEY_PATTERN_CLASSIC" "$KEY_PATTERN_FINE" "$SETUP_BRANCH" "$BOOTSTRAPPER" "$POLYFORM_KEY" "$POLYFORM_TEXT")"
  c="$(load_check; printf '%s\n' "$READBACK_JQ" "$REQUIRE_READBACK" "$UNPROTECTED_ROW_KEY" "$SETUP_HEADING" "$KEY_PATTERN_CLASSIC" "$KEY_PATTERN_FINE" "$SETUP_BRANCH" "$BOOTSTRAPPER" "$POLYFORM_KEY" "$POLYFORM_TEXT")"
  [ "$s" = "$c" ] || { diff <(printf '%s\n' "$s") <(printf '%s\n' "$c") >&2; die "the checker's texts differ from the script's"; }
}

test_checker_avoids_bash4_constructs() {
  # A partial static scan (the real proof is running these tests under
  # bash 3.2): the constructs bash 3.2 lacks that are easiest to slip in.
  local code="$WORK/code.e2e"
  bash -n "$CHECK" || die "syntax error"
  grep -nvE '^[[:space:]]*#' "$CHECK" >"$code" || true
  ! grep -nE '(declare|local|typeset)[[:space:]]+-[a-zA-Z]*A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)|&>>|\|&|;;&' "$code" >&2 \
    || die "bash 4+ construct in the checker"
}

# ---------- run ----------

# With arguments, only the tests named.
TESTS=$(declare -F | awk '{print $3}' | grep '^test_')
[ "$#" -eq 0 ] || TESTS="$*"
for t in $TESTS; do
  run_test "$t"
done

echo
echo "$PASSED passed, $FAILED failed"
if [ "$FAILED" -ne 0 ]; then
  printf '  %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
