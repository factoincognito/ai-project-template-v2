#!/usr/bin/env bash
# e2e-check.sh: checks a finished end-to-end run of bootstrap-project.sh
# against the spec's "Done when", item by item, and prints the command to
# delete the throwaway project. It only reads: GET calls through gh api,
# git commands that read, and the files of the copy. It never writes to
# GitHub or to the copy, and never deletes anything.
# Spec: docs/BACKLOG.md, PBI-1.14, Testing ("End to end") and "Done when".
#
# Template-only: bootstrap/ is not in bootstrap/manifest.txt, so this file
# never ships to the bootstrapper or to projects. Tests:
# bootstrap/test-e2e-check.sh.
#
# Usage: bash bootstrap/e2e-check.sh OWNER/NAME DIR
#   OWNER/NAME  the project the run made on GitHub
#   DIR         the copy of it on this computer that the run made
# Exit codes: 0 every check passed (or was skipped), 1 a check failed,
# 2 usage error.
#
# Runs on bash 3.2 (macOS /bin/bash), Linux and Git for Windows bash: no
# associative arrays, no mapfile, CRs dropped from everything gh and git
# print, no leading / on API paths (Git Bash would rewrite them).
#
# Sourcing this file defines its functions and runs nothing (the tests
# compare its tables with the script's that way).
set -euo pipefail

# ---------- what a finished run leaves (from the spec and the script) ----------
# These restate bootstrap-project.sh on purpose: the checker judges the
# release Adam ran, not the script in this checkout. The tests keep them
# equal to the script's.

BOOTSTRAPPER=factoincognito/ai-project-bootstrap
SETUP_BRANCH=bootstrap-setup
SETUP_HEADING="## After bootstrapping (delete this section when done)"
UNPROTECTED_ROW_KEY="| The main version (main) is not protected |"
KEY_PATTERN_CLASSIC='gh[pousr]_[A-Za-z0-9]{20,}'
KEY_PATTERN_FINE='github_pat_[A-Za-z0-9_]{20,}'
POLYFORM_KEY=polyform-noncommercial-1.0.0
POLYFORM_TEXT=licenses/PolyForm-Noncommercial-1.0.0.md
# Step 16: the protection as read back, and what the spec wants.
READBACK_JQ='"contexts=\(.required_status_checks.contexts // [] | join(","))", "strict=\(.required_status_checks.strict)", "enforce_admins=\(.enforce_admins.enabled)", "approvals=\(.required_pull_request_reviews.required_approving_review_count)", "restrictions=\(.restrictions)", "allow_force_pushes=\(.allow_force_pushes.enabled)", "allow_deletions=\(.allow_deletions.enabled)"'
REQUIRE_READBACK="contexts=build strict=false enforce_admins=true approvals=0 restrictions=null allow_force_pushes=false allow_deletions=false"
PACKS="node web python react-native"
TEMPLATE_URL=https://github.com/factoincognito/ai-project-template-v2

# The other GitHub answers read, through gh's --jq.
REPO_JQ='"\(.full_name)|\(.private)|\(.template_repository.full_name // "-")|\(.delete_branch_on_merge)|\(.allow_squash_merge)"'
PULLS_JQ='.[] | "\(.number) \(.state) \(.merged_at // "-") \(.merge_commit_sha // "-") \(.head.sha)"'
RUNS_JQ='.check_runs[] | select(.name == "build") | "\(.status) \(.conclusion // "-")"'
SHA_JQ='.commit.sha'
COMMITS_JQ='.[] | "\(.sha) \(.parents | length)"'
BODY_JQ='.body'

NL='
'
CR="$(printf '\r')"
TAB="$(printf '\t')"

# placeholder_rows <pack> <with deploy: yes or empty>: the fill table of
# step 8, one "<file>|<text>" per line (a line break inside a text is
# written <NL>), plus the two texts of a GitHub licence in LICENSE (step
# 10). Kept pack files are not rows: they keep their texts (step 12).
placeholder_rows() {
  local f
  for f in README.md CLAUDE.md CHANGELOG.md docs/SPEC.md docs/BACKLOG.md docs/NEXT_SESSION.md memory/project.md; do
    printf '%s|[PROJECT NAME]\n' "$f"
  done
  printf '%s\n' 'README.md|[PO NAME]' 'docs/BACKLOG.md|[PO NAME]' 'memory/project.md|[OWNER/REPO]' \
    'docs/SPEC.md|[DATE]' 'docs/NEXT_SESSION.md|[DATE]' \
    'README.md|[One or two sentences: what this project is and who it is for.]' \
    'memory/project.md|[What the project is, who it is for, and what problem<NL>it solves.]' \
    'LICENSE|[year]' 'LICENSE|[fullname]'
  case "$1" in
    node | web | react-native) printf '%s\n' 'package.json|[project-description]' 'package.json|[project-name]' ;;
  esac
  case "$1" in
    web)
      printf '%s\n' 'index.html|[project-name]'
      [ "${2:-}" != yes ] || printf '%s\n' 'wrangler.jsonc|[project-name]'
      ;;
    react-native) printf '%s\n' 'app.json|[PROJECT NAME]' 'app.json|[project-slug]' ;;
  esac
}

# pack_targets <pack> <with deploy>: where step 6 lays out the pack's
# files, one per word; a folder ends in /.
pack_targets() {
  local common=".github/workflows/ci.yml .gitignore .vscode/settings.json .vscode/extensions.json"
  local ts="package.json tsconfig.json biome.json"
  case "$1" in
    node) echo "$common $ts src/placeholder.test.ts" ;;
    web)
      if [ "${2:-}" = yes ]; then
        echo "$common $ts index.html vite.config.mts playwright.config.ts src/ e2e/ .github/workflows/deploy.yml wrangler.jsonc"
      else
        echo "$common $ts index.html vite.config.mts playwright.config.ts src/ e2e/"
      fi
      ;;
    python) echo "$common pyproject.toml requirements.txt requirements-dev.txt .pre-commit-config.yaml src/" ;;
    react-native) echo "$common $ts app.json src/" ;;
  esac
}

# pack_kept <pack> <with deploy>: the pack's files that stay in
# languages/<pack>/ (step 9).
pack_kept() {
  if [ "$1" = web ] && [ "${2:-}" != yes ]; then
    echo "code-standards.md deploy.yml wrangler.jsonc"
  else
    echo "code-standards.md"
  fi
}

# ---------- output ----------

N_PASS=0 N_FAIL=0 N_SKIP=0
# result <PASS|FAIL|SKIP> <id> <reason>: one line per check.
result() {
  printf '%s %s: %s\n' "$1" "$2" "$3"
  case "$1" in
    PASS) N_PASS=$((N_PASS + 1)) ;;
    FAIL) N_FAIL=$((N_FAIL + 1)) ;;
    *) N_SKIP=$((N_SKIP + 1)) ;;
  esac
}

usage() {
  printf '%s\n' "Usage: bash bootstrap/e2e-check.sh OWNER/NAME DIR" \
    "Run with --help for what it checks."
}

show_help() {
  cat <<'EOF'
Usage: bash bootstrap/e2e-check.sh OWNER/NAME DIR

Checks a finished end-to-end run of bootstrap-project.sh against the
spec's "Done when" (docs/BACKLOG.md, PBI-1.14): OWNER/NAME is the project
the run made on GitHub, DIR its copy on this computer.

It only reads: GitHub through gh (GET calls only), the copy through git
commands that read and its files. It changes nothing on GitHub or in DIR
and deletes nothing. gh must be signed in (gh auth status).

Each check prints one line: PASS, FAIL or SKIP, its name and a reason.
SKIP is only for what a finished run cannot show. Exit code 0 when no
check failed, 1 when one did, 2 for a usage error.

Run it straight after the run, before anything else is merged into the
project, such as the red-then-Test-exempt change of the end-to-end list:
main must hold exactly two commits (GitHub's template commit and the
setup).

The language pack and the licence are read from the lines the run wrote
into CHANGELOG.md, so a wrong choice written there consistently is not
caught: compare them with what you chose (the PASS lines name both).

At the end it prints the commands to delete the project and its copy,
for you to run yourself: the project's only for a name that starts with
bootstrap-e2e-, the folder's only when the copy check passed.
EOF
}

# ---------- reading GitHub ----------

API_STATUS="" API_BODY=""
# api_get <endpoint> [jq]: gh api -i, as the script reads it: API_STATUS
# (empty when no answer came) and API_BODY (CRs dropped).
api_get() {
  local out line part=status
  API_STATUS="" API_BODY=""
  if [ "$#" -ge 2 ]; then
    out="$(GH_PROMPT_DISABLED=1 gh api -i "$1" --jq "$2" </dev/null 2>/dev/null)" || true
  else
    out="$(GH_PROMPT_DISABLED=1 gh api -i "$1" </dev/null 2>/dev/null)" || true
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//$CR/}"
    case "$part" in
      status)
        case "$line" in
          HTTP/*) API_STATUS="${line#* }"; API_STATUS="${API_STATUS%% *}"; part=headers ;;
          *) part=body; API_BODY="$line$NL" ;;
        esac
        ;;
      headers) [ -n "$line" ] || part=body ;;
      *) API_BODY="$API_BODY$line$NL" ;;
    esac
  done <<<"$out"
  API_BODY="${API_BODY%"$NL"}"
  case "$API_STATUS" in [0-9][0-9][0-9]) ;; *) API_STATUS="" ;; esac
}

# api_problem: PROBLEM is the plain words for the last answer that was not 200.
PROBLEM=""
api_problem() {
  case "$API_STATUS" in
    "") PROBLEM="gh got no answer from GitHub; check that gh is signed in (gh auth status) and that this computer is online" ;;
    401) PROBLEM="GitHub did not accept gh's sign-in (HTTP 401); sign in again and check with gh auth status" ;;
    403) PROBLEM="GitHub refused to show it (HTTP 403); gh's sign-in may lack a permission, or a rate limit was hit" ;;
    404) PROBLEM="GitHub says it does not exist, or gh's sign-in cannot see it (HTTP 404)" ;;
    *) PROBLEM="GitHub answered with HTTP $API_STATUS instead of the expected answer" ;;
  esac
}

# ---------- reading the copy ----------

DIR_ABS=""
COPY_READABLE=""
# COPY_PASSED: the copy check passed (DIR is the top folder of a clean
# copy of OWNER/NAME on main); only then is the folder removal shown.
COPY_PASSED=""
COPY_PROBLEM=""
TRACKED=""
# Every git call of the checker: --no-optional-locks (git status would
# otherwise refresh the index), core.fsmonitor=false (a setting in the
# copy's own git settings cannot make it run a command), gc.auto=0 and
# maintenance.auto=false (git never starts its own maintenance, which
# writes into the copy).
in_git() { git -C "$DIR" --no-optional-locks -c core.fsmonitor=false -c gc.auto=0 -c maintenance.auto=false "$@"; }

# read_copy: whether DIR is the top folder of a git copy (COPY_READABLE),
# and its tracked files (TRACKED, one per line).
read_copy() {
  local inside prefix
  if [ ! -e "$DIR" ]; then COPY_PROBLEM="the folder $DIR does not exist"; return 0; fi
  if [ ! -d "$DIR" ]; then COPY_PROBLEM="$DIR is not a folder"; return 0; fi
  inside="$(in_git rev-parse --is-inside-work-tree 2>/dev/null | tr -d '\r')" || inside=""
  if [ "$inside" != true ]; then COPY_PROBLEM="$DIR is not a copy of a project made by git"; return 0; fi
  prefix="$(in_git rev-parse --show-prefix 2>/dev/null | tr -d '\r')" || prefix="?"
  if [ -n "$prefix" ]; then COPY_PROBLEM="$DIR is a folder inside a copy, not the copy's own top folder"; return 0; fi
  TRACKED="$(in_git -c core.quotePath=false ls-files 2>/dev/null | tr -d '\r')" || TRACKED=""
  COPY_READABLE=1
}

is_tracked() { case "$NL$TRACKED$NL" in *"$NL$1$NL"*) return 0 ;; esac; return 1; }

# file_text <path in the copy>: TEXT is the file's content, exactly.
TEXT=""
file_text() { TEXT="$(cat "$DIR/$1"; printf x)"; TEXT="${TEXT%x}"; }

# no_copy <id>: the check cannot run without a readable copy.
no_copy() { result FAIL "$1" "The copy could not be read, so this was not checked (see copy)."; }
# no_pack <id>
no_pack() { result FAIL "$1" "The language pack is not known, because CHANGELOG.md does not name it (see changelog)."; }

# join_words <separator> <words...>
join_list() { local sep="$1" out="" w; shift; for w in "$@"; do out="${out:+$out$sep}$w"; done; printf '%s' "$out"; }

# ---------- the checks on GitHub ----------

REPO_OK="" REPO_PROBLEM="" R_PRIVATE="" R_TEMPLATE="" R_DELETE="" R_SQUASH=""
read_repo() {
  local full
  api_get "repos/$OWNER/$NAME" "$REPO_JQ"
  if [ "$API_STATUS" != 200 ]; then api_problem; REPO_PROBLEM="$PROBLEM"; return 0; fi
  IFS='|' read -r full R_PRIVATE R_TEMPLATE R_DELETE R_SQUASH <<<"$API_BODY"
  REPO_OK=1
}

check_project() {
  local vis=public
  if [ -z "$REPO_OK" ]; then result FAIL project "The project $OWNER/$NAME could not be read: $REPO_PROBLEM."; return 0; fi
  [ "$R_PRIVATE" != true ] || vis=private
  result PASS project "The project $OWNER/$NAME is on GitHub, and it is $vis."
}

check_template() {
  if [ -z "$REPO_OK" ]; then result FAIL template "The project could not be read: $REPO_PROBLEM."; return 0; fi
  case "$R_TEMPLATE" in
    "$BOOTSTRAPPER") result PASS template "GitHub records it as made from $BOOTSTRAPPER." ;;
    - | null | "") result FAIL template "GitHub does not record it as made from a template; the run should make it from $BOOTSTRAPPER." ;;
    *) result FAIL template "GitHub records it as made from $R_TEMPLATE, not from $BOOTSTRAPPER." ;;
  esac
}

check_merge_settings() {
  local off=""
  if [ -z "$REPO_OK" ]; then result FAIL merge-settings "The project could not be read: $REPO_PROBLEM."; return 0; fi
  [ "$R_DELETE" = true ] || off="deleting a line of work after its merge"
  [ "$R_SQUASH" = true ] || off="${off:+$off and }merging a change as one (squash)"
  if [ -n "$off" ]; then
    result FAIL merge-settings "These project settings are off, and the run turns them on: $off."
  else
    result PASS merge-settings "Deleting a line of work after its merge and merging as one change (squash) are both on."
  fi
}

# The setup change: the proposed change from bootstrap-setup that the run
# merged (when exactly one is merged; else the only one, if there is one).
PULLS_OK="" PULLS_PROBLEM="" PULL_LINES="" PR_NUM="" PR_MERGE_SHA="" PR_HEAD_SHA="" PR_STATE="" PR_MERGED_AT=""
read_pulls() {
  local n=0 merged=0 line num state at msha hsha
  api_get "repos/$OWNER/$NAME/pulls?state=all&head=$OWNER:$SETUP_BRANCH&per_page=100" "$PULLS_JQ"
  if [ "$API_STATUS" != 200 ]; then api_problem; PULLS_PROBLEM="$PROBLEM"; return 0; fi
  PULLS_OK=1
  PULL_LINES="$API_BODY"
  while read -r num state at msha hsha; do
    [ -n "$num" ] || continue
    n=$((n + 1))
    if [ "$at" != - ]; then
      merged=$((merged + 1))
      [ "$merged" -ne 1 ] || { PR_NUM="$num" PR_STATE="$state" PR_MERGED_AT="$at" PR_MERGE_SHA="$msha" PR_HEAD_SHA="$hsha"; }
    fi
  done <<<"$PULL_LINES"
  if [ "$merged" -gt 1 ]; then PR_NUM="" PR_MERGE_SHA="" PR_HEAD_SHA=""; fi
  if [ "$merged" -eq 0 ] && [ "$n" -eq 1 ]; then
    read -r PR_NUM PR_STATE PR_MERGED_AT PR_MERGE_SHA PR_HEAD_SHA <<<"$PULL_LINES"
  fi
  PULL_COUNT="$n"
  MERGED_COUNT="$merged"
}
PULL_COUNT=0
MERGED_COUNT=0

pull_list() { printf '%s\n' "$PULL_LINES" | awk 'NF { printf "%s#%s", (n++ ? ", " : ""), $1 }'; }

check_setup_change() {
  if [ -z "$PULLS_OK" ]; then result FAIL setup-change "The proposed changes from $SETUP_BRANCH could not be read: $PULLS_PROBLEM."; return 0; fi
  if [ "$PULL_COUNT" -eq 0 ]; then
    result FAIL setup-change "GitHub has no proposed change from $SETUP_BRANCH; the run proposes the setup as one."
  elif [ "$PULL_COUNT" -gt 1 ]; then
    result FAIL setup-change "GitHub has $PULL_COUNT proposed changes from $SETUP_BRANCH ($(pull_list)); a run, resumed or not, proposes exactly one."
  elif [ "$MERGED_COUNT" -eq 1 ]; then
    result PASS setup-change "The one proposed change from $SETUP_BRANCH, #$PR_NUM, was merged."
  else
    result FAIL setup-change "The one proposed change from $SETUP_BRANCH, #$PR_NUM, is $PR_STATE and was not merged."
  fi
}

check_build() {
  local runs bad n
  if [ -z "$PULLS_OK" ]; then result FAIL build "The proposed changes could not be read: $PULLS_PROBLEM."; return 0; fi
  if [ -z "$PR_HEAD_SHA" ]; then result FAIL build "There is no single setup change whose check could be looked at (see setup-change)."; return 0; fi
  api_get "repos/$OWNER/$NAME/commits/$PR_HEAD_SHA/check-runs?per_page=100" "$RUNS_JQ"
  if [ "$API_STATUS" != 200 ]; then api_problem; result FAIL build "The checks of #$PR_NUM could not be read: $PROBLEM."; return 0; fi
  runs="$(printf '%s\n' "$API_BODY" | grep -c . || true)"
  bad="$(printf '%s\n' "$API_BODY" | awk 'NF && $0 != "completed success" { printf "%s%s", (n++ ? ", " : ""), ($1 == "completed" ? $2 : $1) }')"
  if [ "$runs" -eq 0 ]; then
    result FAIL build "No check named build ran on the last commit of #$PR_NUM."
  elif [ -n "$bad" ]; then
    result FAIL build "The check build on the last commit of #$PR_NUM did not pass every time it ran (other results: $bad)."
  else
    n=time; [ "$runs" -eq 1 ] || n=times
    result PASS build "The check build passed on the last commit of #$PR_NUM ($runs $n)."
  fi
}

MAIN_SHA="" MAIN_PROBLEM=""
read_main() {
  api_get "repos/$OWNER/$NAME/branches/main" "$SHA_JQ"
  if [ "$API_STATUS" = 200 ] && [ -n "$API_BODY" ]; then MAIN_SHA="$API_BODY"; else api_problem; MAIN_PROBLEM="$PROBLEM"; fi
}

short() { printf '%s' "$1" | cut -c1-7; }

check_history() {
  local lines n first fp second sp
  if [ -z "$MAIN_SHA" ]; then result FAIL history "main could not be read: $MAIN_PROBLEM."; return 0; fi
  api_get "repos/$OWNER/$NAME/commits?sha=main&per_page=3" "$COMMITS_JQ"
  if [ "$API_STATUS" != 200 ]; then api_problem; result FAIL history "The history of main could not be read: $PROBLEM."; return 0; fi
  lines="$API_BODY"
  n="$(printf '%s\n' "$lines" | grep -c . || true)"
  read -r first fp <<<"$(printf '%s\n' "$lines" | sed -n 1p)"
  read -r second sp <<<"$(printf '%s\n' "$lines" | sed -n 2p)"
  if [ "$n" -ne 2 ]; then
    result FAIL history "main has $( [ "$n" -ge 3 ] && echo "3 or more changes" || echo "$n change(s)" ), not two (GitHub's template change and the setup merged as one); a run, resumed or not, adds exactly one. The usual cause is a change merged after the run, such as the red-then-Test-exempt one: run this check before merging anything else."
  elif [ "$sp" != 0 ] || [ "$fp" != 1 ]; then
    result FAIL history "main's last change has $fp parents and the one before it $sp; the setup merged as one change has one, GitHub's template change none."
  elif [ "$first" != "$MAIN_SHA" ]; then
    result FAIL history "GitHub gave two different answers for the last change of main ($(short "$first") and $(short "$MAIN_SHA"))."
  elif [ -z "$PR_MERGE_SHA" ] || [ "$PR_MERGE_SHA" = - ]; then
    result FAIL history "There is no merged setup change to compare main with (see setup-change)."
  elif [ "$PR_MERGE_SHA" != "$MAIN_SHA" ]; then
    result FAIL history "main is at $(short "$MAIN_SHA"), but #$PR_NUM was merged as $(short "$PR_MERGE_SHA")."
  else
    result PASS history "main holds GitHub's template change and one more, #$PR_NUM merged as one change ($(short "$MAIN_SHA"))."
  fi
}

check_setup_branch() {
  local where=""
  api_get "repos/$OWNER/$NAME/branches/$SETUP_BRANCH" "$SHA_JQ"
  case "$API_STATUS" in
    404) ;;
    200) where="on GitHub" ;;
    *) api_problem; result FAIL setup-branch "Whether $SETUP_BRANCH is still on GitHub could not be read: $PROBLEM."; return 0 ;;
  esac
  if [ -n "$COPY_READABLE" ] && in_git rev-parse -q --verify "refs/heads/$SETUP_BRANCH" >/dev/null 2>&1; then
    where="${where:+$where and }in the copy"
  fi
  if [ -n "$where" ]; then
    result FAIL setup-branch "The line of work $SETUP_BRANCH is still there $where; the run deletes it after the merge."
  elif [ -n "$COPY_READABLE" ]; then
    result PASS setup-branch "The line of work $SETUP_BRANCH is gone, on GitHub and in the copy."
  else
    result PASS setup-branch "The line of work $SETUP_BRANCH is gone on GitHub (the copy could not be read; see copy)."
  fi
}

PROTECTED=""
plan_refusal() {
  case "$API_BODY" in *"Upgrade to GitHub Pro"* | *"make this repository public"*) return 0 ;; esac
  return 1
}
check_protection() {
  local got diff="" want w g field
  api_get "repos/$OWNER/$NAME/branches/main/protection" "$READBACK_JQ"
  if [ "$API_STATUS" = 404 ]; then
    PROTECTED=no
    result FAIL protection "main is not protected (GitHub: not found); the run protects it and requires the check build."
    return 0
  fi
  # GitHub's message for a plan without protection (as the script's tests
  # have it; unverified): only then is a private project's 403 the
  # --allow-unprotected path, not a missing permission or a rate limit.
  if [ "$API_STATUS" = 403 ] && [ "$R_PRIVATE" = true ] && plan_refusal; then
    PROTECTED=plan
    result FAIL protection "GitHub refused to show the protection of main (HTTP 403). For a private project this is expected when its GitHub plan cannot protect it, the path of --allow-unprotected; the end-to-end runs use public projects, so it fails here. Check the project's plan, and that memory/decisions.md records the choice (see decision-row)."
    return 0
  fi
  if [ "$API_STATUS" != 200 ]; then
    PROTECTED=unknown
    api_problem
    result FAIL protection "The protection of main could not be read: $PROBLEM."
    return 0
  fi
  PROTECTED=yes
  got="$(printf '%s\n' "$API_BODY" | tr '\n' ' ')"
  got="${got% }"
  for w in $REQUIRE_READBACK; do
    field="${w%%=*}"
    g="$(printf '%s\n' "$API_BODY" | awk -v f="$field" 'index($0, f "=") == 1 { print substr($0, length(f) + 2); exit }')"
    [ "$g" = "${w#*=}" ] || diff="${diff:+$diff; }$field is ${g:-empty}, want ${w#*=}"
  done
  want="$REQUIRE_READBACK"
  if [ -n "$diff" ] || [ "$got" != "$want" ]; then
    result FAIL protection "The protection of main is not as specified: ${diff:-the fields differ}."
  else
    result PASS protection "main is protected as specified: the check build is required, no approvals, admins included, no force pushes or deletion."
  fi
}

check_decision_row() {
  local row=""
  if [ -z "$COPY_READABLE" ]; then no_copy decision-row; return 0; fi
  if [ ! -f "$DIR/memory/decisions.md" ]; then result FAIL decision-row "The copy has no memory/decisions.md."; return 0; fi
  ! grep -qF -- "$UNPROTECTED_ROW_KEY" "$DIR/memory/decisions.md" || row=1
  case "$PROTECTED:$row" in
    yes:) result PASS decision-row "memory/decisions.md does not say main is unprotected, and it is protected." ;;
    yes:1) result FAIL decision-row "memory/decisions.md says main is not protected, but GitHub reports it protected." ;;
    no:1) result PASS decision-row "main is not protected, and memory/decisions.md records that choice." ;;
    no:) result FAIL decision-row "main is not protected, and memory/decisions.md has no row saying so." ;;
    plan:1) result PASS decision-row "This private project's plan most likely cannot protect main, and memory/decisions.md records the choice to go on without protection." ;;
    plan:) result FAIL decision-row "This private project's plan most likely cannot protect main, and memory/decisions.md has no row saying so." ;;
    *) result FAIL decision-row "Whether main is protected is not known, so the row in memory/decisions.md could not be judged (see protection)." ;;
  esac
}

# ---------- the checks of the copy ----------

check_copy() {
  local problems="" url want_path p branch status n head
  if [ -z "$COPY_READABLE" ]; then result FAIL copy "${COPY_PROBLEM}; the run leaves a clean copy on main there."; return 0; fi
  url="$(in_git remote get-url origin 2>/dev/null | tr -d '\r')" || url=""
  p="$url"
  p="${p%/}"; p="${p%.git}"
  case "$p" in
    https://github.com/* | http://github.com/*) p="${p#*://github.com/}" ;;
    git@github.com:*) p="${p#git@github.com:}" ;;
    ssh://git@github.com/*) p="${p#ssh://git@github.com/}" ;;
    *) p="" ;;
  esac
  want_path="$OWNER/$NAME"
  if [ "$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')" != "$(printf '%s' "$want_path" | tr '[:upper:]' '[:lower:]')" ]; then
    problems="it is a copy of ${url:-no project on GitHub}, not of $want_path"
  fi
  branch="$(in_git symbolic-ref -q --short HEAD 2>/dev/null | tr -d '\r')" || branch=""
  if [ -z "$branch" ]; then
    problems="${problems:+$problems; }it is on no line of work (a detached commit), not on main"
  elif [ "$branch" != main ]; then
    problems="${problems:+$problems; }it is on $branch, not on main"
  fi
  status="$(in_git status --porcelain --untracked-files=all 2>&1 | tr -d '\r')" || status="git status failed"
  if [ -n "$status" ]; then
    n="$(printf '%s\n' "$status" | grep -c . || true)"
    problems="${problems:+$problems; }$n file(s) changed or not saved: $(printf '%s\n' "$status" | head -n 5 | awk '{ $1 = ""; sub(/^ /, ""); printf "%s%s", (n++ ? ", " : ""), $0 }')"
  fi
  head="$(in_git rev-parse -q --verify HEAD 2>/dev/null | tr -d '\r')" || head=""
  if [ -z "$MAIN_SHA" ]; then
    problems="${problems:+$problems; }it could not be compared with main on GitHub: $MAIN_PROBLEM"
  elif [ "$head" != "$MAIN_SHA" ]; then
    problems="${problems:+$problems; }it is at $(short "${head:-none}"), but main on GitHub is at $(short "$MAIN_SHA")"
  fi
  if [ -n "$problems" ]; then
    result FAIL copy "The copy in $DIR is not clean on main: $problems."
  else
    COPY_PASSED=1
    result PASS copy "The copy in $DIR is on main, at GitHub's main ($(short "$MAIN_SHA")), with nothing unsaved."
  fi
}

PACK="" DEPLOY="" LICENCE="" BAD_LICENCE=""
check_changelog() {
  local section missing="" line p
  if [ -z "$COPY_READABLE" ]; then no_copy changelog; return 0; fi
  if [ ! -f "$DIR/CHANGELOG.md" ]; then result FAIL changelog "The copy has no CHANGELOG.md."; return 0; fi
  section="$(tr -d '\r' <"$DIR/CHANGELOG.md" | awk '$0 == "## Project created" { on = 1; next } on && /^## / { on = 0 } on')"
  while IFS= read -r line; do
    case "$line" in
      "- Language pack: web, with the files that publish the website.") PACK=web DEPLOY=yes ;;
      "- Language pack: "*.)
        p="${line#- Language pack: }"; p="${p%.}"
        case " $PACKS " in *" $p "*) PACK="$p" ;; esac
        ;;
      "- Licence: "*.) LICENCE="${line#- Licence: }"; LICENCE="${LICENCE%.}" ;;
    esac
  done <<<"$section"
  # The licence name goes into a gh api path: a licence key only
  # (lowercase letters, digits, . and -, not starting with . or -).
  case "$LICENCE" in
    "") ;;
    *[!a-z0-9.-]* | [.-]*) BAD_LICENCE="$LICENCE"; LICENCE="" ;;
  esac
  [ -n "$PACK" ] || missing="- Language pack: <pack>."
  if [ -n "$BAD_LICENCE" ]; then
    missing="${missing:+$missing, }- Licence: <licence> (it names \"$BAD_LICENCE\", which is not a licence key: lowercase letters, digits, . and -)"
  elif [ -z "$LICENCE" ]; then
    missing="${missing:+$missing, }- Licence: <licence>."
  fi
  case "$NL$section$NL" in *"$NL- Set up by bootstrap-project.sh.$NL"*) ;; *) missing="${missing:+$missing, }- Set up by bootstrap-project.sh." ;; esac
  if [ -n "$missing" ]; then
    result FAIL changelog "The section \"## Project created\" of CHANGELOG.md lacks: ${missing%.}."
  else
    result PASS changelog "CHANGELOG.md names the pack ($PACK${DEPLOY:+, with the deploy files}), the licence ($LICENCE) and the setup script."
  fi
}

check_pack() {
  local t missing=""
  if [ -z "$COPY_READABLE" ]; then no_copy pack; return 0; fi
  if [ -z "$PACK" ]; then no_pack pack; return 0; fi
  for t in $(pack_targets "$PACK" "$DEPLOY"); do
    case "$t" in
      */) case "$NL$TRACKED" in *"$NL$t"*) ;; *) missing="${missing:+$missing, }$t" ;; esac ;;
      *) is_tracked "$t" || missing="${missing:+$missing, }$t" ;;
    esac
  done
  if [ -n "$missing" ]; then
    result FAIL pack "The $PACK pack's files are not all in the project; missing: $missing."
  else
    result PASS pack "The $PACK pack's files${DEPLOY:+, with the deploy files,} are in the project."
  fi
}

check_lockfile() {
  if [ -z "$COPY_READABLE" ]; then no_copy lockfile; return 0; fi
  if [ -z "$PACK" ]; then no_pack lockfile; return 0; fi
  case "$PACK" in
    python)
      if is_tracked package-lock.json || [ -e "$DIR/package-lock.json" ]; then
        result FAIL lockfile "The python pack has no npm lockfile, but the project has package-lock.json."
      else
        result PASS lockfile "The python pack needs no package-lock.json, and there is none."
      fi
      ;;
    *)
      if is_tracked package-lock.json; then
        result PASS lockfile "package-lock.json is in the project (the green build ran npm ci with it on Linux)."
      else
        result FAIL lockfile "The $PACK pack needs package-lock.json, and the project does not have it."
      fi
      ;;
  esac
}

check_placeholders() {
  local row file text left="" missing=""
  if [ -z "$COPY_READABLE" ]; then no_copy placeholders; return 0; fi
  if [ -z "$PACK" ]; then no_pack placeholders; return 0; fi
  while IFS= read -r row; do
    file="${row%%|*}"; text="${row#*|}"; text="${text//<NL>/$NL}"
    if [ ! -f "$DIR/$file" ]; then
      [ "$file" = LICENSE ] || case " $missing " in *" $file "*) ;; *) missing="${missing:+$missing }$file" ;; esac
      continue
    fi
    file_text "$file"
    case "$TEXT" in *"$text"*) left="${left:+$left; }${text//$NL/ } in $file" ;; esac
  done <<<"$(placeholder_rows "$PACK" "$DEPLOY")"
  if [ -n "$missing" ]; then
    result FAIL placeholders "Files the setup fills in are missing: ${missing// /, }${left:+; also left: $left}."
  elif [ -n "$left" ]; then
    result FAIL placeholders "Texts the setup fills in are still there: $left."
  else
    result PASS placeholders "No text of the fill table is left in the files it lists."
  fi
}

check_readme_section() {
  local found
  if [ -z "$COPY_READABLE" ]; then no_copy readme-section; return 0; fi
  if [ ! -f "$DIR/README.md" ]; then result FAIL readme-section "The copy has no README.md."; return 0; fi
  found="$(tr -d '\r' <"$DIR/README.md" | grep -c '^## After bootstrapping' || true)"
  if [ "$found" -gt 0 ]; then
    result FAIL readme-section "README.md still has a section headed \"## After bootstrapping\"; the run removes \"$SETUP_HEADING\"."
  else
    result PASS readme-section "README.md has no section \"## After bootstrapping\"."
  fi
}

check_languages() {
  local f want="" extra="" missing="" got
  if [ -z "$COPY_READABLE" ]; then no_copy languages; return 0; fi
  if [ -z "$PACK" ]; then no_pack languages; return 0; fi
  for f in $(pack_kept "$PACK" "$DEPLOY"); do want="$want${NL}languages/$PACK/$f"; done
  got="$(printf '%s\n' "$TRACKED" | grep '^languages/' || true)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$want$NL" in *"$NL$f$NL"*) ;; *) extra="${extra:+$extra, }$f" ;; esac
  done <<<"$got"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$NL$got$NL" in *"$NL$f$NL"*) ;; *) missing="${missing:+$missing, }$f" ;; esac
  done <<<"$want"
  if [ -n "$extra" ] || [ -n "$missing" ]; then
    result FAIL languages "languages/ should hold only $(pack_kept "$PACK" "$DEPLOY" | sed 's/ /, /g') of the $PACK pack${extra:+; it also has: $extra}${missing:+; it lacks: $missing}."
  else
    result PASS languages "languages/ holds only the $PACK pack's files that were not laid out."
  fi
}

check_pack_links() {
  local p bad=""
  if [ -z "$COPY_READABLE" ]; then no_copy pack-links; return 0; fi
  if [ -z "$PACK" ]; then no_pack pack-links; return 0; fi
  if [ ! -f "$DIR/docs/DEV_INFRASTRUCTURE.md" ]; then result FAIL pack-links "The copy has no docs/DEV_INFRASTRUCTURE.md."; return 0; fi
  file_text docs/DEV_INFRASTRUCTURE.md
  for p in $PACKS; do
    [ "$p" != "$PACK" ] || continue
    case "$TEXT" in *"\`languages/$p/code-standards.md\`"*) bad="${bad:+$bad, }languages/$p/code-standards.md" ;; esac
  done
  if [ -n "$bad" ]; then
    result FAIL pack-links "docs/DEV_INFRASTRUCTURE.md still points into the project for packs it no longer has: $bad (the run points them to $TEMPLATE_URL)."
  else
    result PASS pack-links "docs/DEV_INFRASTRUCTURE.md points to the template on GitHub for the other packs' code standards."
  fi
}

# licence_matches <expected text>: LICENSE (stdin) is the text, line by
# line, with each [year] and [fullname] filled in by text that is not
# empty, not only spaces and not a placeholder; trailing blank lines are
# ignored.
licence_matches() {
  LM_WANT="$1" awk '
    function filled(t) { return t ~ /[^ \t]/ && index(t, "[year]") == 0 && index(t, "[fullname]") == 0 }
    BEGIN { n = split(ENVIRON["LM_WANT"], want, "\n"); while (n > 0 && want[n] == "") n-- }
    { sub(/\r$/, ""); got[++m] = $0 }
    END {
      while (m > 0 && got[m] == "") m--
      if (m != n) exit 1
      for (i = 1; i <= n; i++) {
        w = want[i]; g = got[i]
        if (index(w, "[year]") == 0 && index(w, "[fullname]") == 0) { if (w != g) exit 1; continue }
        if (index(g, "[year]") || index(g, "[fullname]")) exit 1
        # The literal pieces around the placeholders, in order, with text
        # between each two of them.
        gsub(/\[fullname\]/, "\001", w); gsub(/\[year\]/, "\001", w)
        k = split(w, piece, "\001")
        if (substr(g, 1, length(piece[1])) != piece[1]) exit 1
        rest = substr(g, length(piece[1]) + 1)
        for (j = 2; j < k; j++) {
          if (piece[j] == "") exit 1
          p = index(rest, piece[j])
          if (p < 2 || !filled(substr(rest, 1, p - 1))) exit 1
          rest = substr(rest, p + length(piece[j]))
        }
        if (length(rest) < length(piece[k])) exit 1
        if (substr(rest, length(rest) - length(piece[k]) + 1) != piece[k]) exit 1
        if (!filled(substr(rest, 1, length(rest) - length(piece[k])))) exit 1
      }
    }'
}

check_licence() {
  local notice body
  if [ -z "$COPY_READABLE" ]; then no_copy licence; return 0; fi
  if [ -z "$LICENCE" ]; then result FAIL licence "The licence chosen is not known, because CHANGELOG.md does not name it (see changelog)."; return 0; fi
  case "$LICENCE" in
    none)
      if is_tracked LICENSE || is_tracked NOTICE || [ -e "$DIR/LICENSE" ]; then
        result FAIL licence "The licence chosen was none, but the project has a LICENSE or NOTICE file."
      else
        result PASS licence "The licence chosen was none, and there is no LICENSE file."
      fi
      ;;
    "$POLYFORM_KEY")
      if ! is_tracked LICENSE || [ ! -f "$DIR/$POLYFORM_TEXT" ]; then
        result FAIL licence "The licence chosen was $POLYFORM_KEY, but LICENSE or $POLYFORM_TEXT is missing."
      elif [ "$(tr -d '\r' <"$DIR/LICENSE")" != "$(tr -d '\r' <"$DIR/$POLYFORM_TEXT")" ]; then
        result FAIL licence "LICENSE is not the text of $POLYFORM_TEXT."
      elif ! is_tracked NOTICE; then
        result FAIL licence "The licence chosen was $POLYFORM_KEY, but there is no NOTICE naming the copyright holder."
      else
        notice="$(tr -d '\r' <"$DIR/NOTICE")"
        case "$notice" in
          "Required Notice: Copyright "?*) result PASS licence "LICENSE is the PolyForm Noncommercial text, and NOTICE names the copyright holder." ;;
          *) result FAIL licence "NOTICE does not hold \"Required Notice: Copyright <holder>\"." ;;
        esac
      fi
      ;;
    *)
      if ! is_tracked LICENSE; then result FAIL licence "The licence chosen was $LICENCE, but the project has no LICENSE file."; return 0; fi
      api_get "licenses/$LICENCE" "$BODY_JQ"
      if [ "$API_STATUS" != 200 ] || [ -z "$API_BODY" ]; then
        api_problem
        result FAIL licence "GitHub's text of the licence $LICENCE could not be read to compare with LICENSE: $PROBLEM."
        return 0
      fi
      body="$API_BODY"
      if licence_matches "$body" <"$DIR/LICENSE"; then
        result PASS licence "LICENSE is GitHub's text of $LICENCE, with the year and the copyright holder filled in."
      else
        result FAIL licence "LICENSE is not GitHub's text of $LICENCE with the year and the copyright holder filled in."
      fi
      ;;
  esac
}

check_no_script() {
  local found
  if [ -z "$COPY_READABLE" ]; then no_copy no-script; return 0; fi
  found="$(printf '%s\n' "$TRACKED" | awk -F / '$NF == "bootstrap-project.sh"' | tr '\n' ' ')"
  if [ -n "$found" ] || [ -e "$DIR/bootstrap-project.sh" ]; then
    result FAIL no-script "The setup script is still in the project: ${found:-bootstrap-project.sh}"
  else
    result PASS no-script "bootstrap-project.sh is not in the project."
  fi
}

check_line_endings() {
  local out bad rc=0
  if [ -z "$COPY_READABLE" ]; then no_copy line-endings; return 0; fi
  out="$(in_git -c core.quotePath=false ls-files --eol 2>/dev/null | tr -d '\r')" || rc=$?
  if [ "$rc" -ne 0 ]; then result FAIL line-endings "git could not list the line endings of the project's files."; return 0; fi
  bad="$(printf '%s\n' "$out" | awk -F '\t' '$1 ~ /^i\/(crlf|mixed)/ { printf "%s%s", (n++ ? ", " : ""), $2 }')"
  if [ -n "$bad" ]; then
    result FAIL line-endings "Files saved with CR LF line endings, which the run never saves: $bad."
  else
    result PASS line-endings "Every file of the project is saved with LF line endings."
  fi
}

check_no_keys() {
  local out rc=0
  if [ -z "$COPY_READABLE" ]; then no_copy no-keys; return 0; fi
  out="$(in_git -c core.quotePath=false grep -l -I -E -e "$KEY_PATTERN_CLASSIC" -e "$KEY_PATTERN_FINE" HEAD -- 2>/dev/null | tr -d '\r')" || rc=$?
  case "$rc" in
    1) result PASS no-keys "No file of the project holds what looks like a GitHub sign-in key." ;;
    0) result FAIL no-keys "What looks like a GitHub sign-in key is in: $(printf '%s\n' "$out" | sed 's/^HEAD://' | awk 'NF { printf "%s%s", (n++ ? ", " : ""), $0 }') (the key is not shown here)." ;;
    *) result FAIL no-keys "git could not search the project's files for sign-in keys." ;;
  esac
}

# ---------- what a finished run cannot show ----------

skip_the_rest() {
  result SKIP resume "Done when 4 asks that an interrupted run finishes with --resume; the result cannot show whether this run was interrupted (setup-change and history show no second change or commit)."
  result SKIP docs "Done when 5 (docs updated, PBI-1.4 and PBI-1.8 dispositions, one layout table) is about the template, not something this project shows."
  result SKIP guides "Done when 6 (each guided check prints its steps and passes on re-check) shows only in the terminal during the run."
  result SKIP unaided "Done when 7 (someone new sets up a project from the README alone) only the person doing it can tell; record it on the PBI."
  result SKIP ci-gate "Done when 8 (bootstrapper-test as one required check, packs.yml's lockfile command) is the template's own CI, not something this project shows."
  result SKIP exempt-pr "The e2e item \"a change to src/ without a test goes red, then green with a Test-exempt: trailer\" is made by hand after the run; only its page on GitHub shows it."
  result SKIP bot-comments "Whether the review and changelog workflows' comments on the setup change are harmless is only visible on the change's page on GitHub."
}

# ---------- the delete command ----------

# shell_quote <text>: the text in single quotes, for a shell command line.
shell_quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

delete_hint() {
  local abs=""
  echo
  case "$NAME" in
    bootstrap-e2e-*) ;;
    *)
      echo "No delete command is shown: $OWNER/$NAME is not named bootstrap-e2e-..., so it may not be a throwaway project."
      return 0
      ;;
  esac
  echo "To delete this throwaway project when you are done, run these yourself (this check deleted nothing):"
  echo "    gh auth refresh -h github.com -s delete_repo"
  echo "    gh repo delete $OWNER/$NAME --yes"
  # A symbolic link gets no removal line: rm -rf would remove only the
  # link, and the folder it points to is not checked to be the one meant.
  if [ -n "$COPY_PASSED" ] && [ -d "$DIR" ] && [ ! -L "${DIR%/}" ]; then
    abs="$(CDPATH='' cd -- "$DIR" && pwd)" || abs=""
  fi
  if [ -n "$abs" ]; then
    echo "    rm -rf -- $(shell_quote "$abs")"
  elif [ ! -e "$DIR" ]; then
    echo "No command to remove the folder is shown: $DIR does not exist, so there is nothing to remove there."
  elif [ -L "${DIR%/}" ]; then
    echo "No command to remove the folder is shown, because $DIR is a symbolic link: removing it would leave the copy. Look at the folder it points to yourself before you delete it."
  else
    echo "No command to remove the folder is shown, because the copy check did not pass (see copy): $DIR may not be this project's copy, or it holds unsaved work. Look at the folder yourself before you delete anything there."
  fi
}

# ---------- main ----------

OWNER="" NAME="" DIR=""
main() {
  case "${1:-}" in
    -h | --help) show_help; return 0 ;;
  esac
  if [ "$#" -ne 2 ]; then usage >&2; return 2; fi
  if ! printf '%s\n' "$1" | grep -qE '^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+$' || [ "$(printf '%s\n' "$1" | wc -l | tr -d ' ')" != 1 ]; then
    echo "Not a project name of the form OWNER/NAME: $1" >&2
    usage >&2
    return 2
  fi
  if [ -z "$2" ]; then usage >&2; return 2; fi
  OWNER="${1%%/*}" NAME="${1#*/}" DIR="$2"
  # git reads only: no optional locks (git status would otherwise refresh
  # the index), and the copy's own git folder, not one from the
  # environment.
  export GIT_OPTIONAL_LOCKS=0
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
  echo "Checking the end-to-end run: $OWNER/$NAME on GitHub, its copy in $DIR."
  read_copy
  read_repo
  read_pulls
  read_main
  check_project
  check_template
  check_merge_settings
  check_setup_change
  check_build
  check_history
  check_setup_branch
  check_protection
  check_decision_row
  check_copy
  check_changelog
  check_pack
  check_lockfile
  check_placeholders
  check_readme_section
  check_languages
  check_pack_links
  check_licence
  check_no_script
  check_line_endings
  check_no_keys
  skip_the_rest
  echo
  echo "Result: $N_PASS passed, $N_FAIL failed, $N_SKIP skipped."
  delete_hint
  [ "$N_FAIL" -eq 0 ] || return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
