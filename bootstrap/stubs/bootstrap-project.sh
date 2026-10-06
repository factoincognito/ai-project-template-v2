#!/usr/bin/env bash
# bootstrap-project.sh: sets up a new project from this bootstrapper.
# Spec: "Turn-key bootstrap script" in
# https://github.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG.md
#
# Built so far: the inputs (options, questions, checks and defaults), the
# guided checks of this computer (bash, git, gh, npm, the git name and
# email, the target folder), the guided checks on GitHub (signed in, the
# current version of this script, the permissions gh has, the project
# name still free) and the layout-pack subcommand. After those checks the
# script stops: the setup steps come in later parts.
#
# Usage:
#   bash bootstrap-project.sh [options]
#     Asks for each answer not given as an option, then checks them all.
#     --help lists the options; --non-interactive asks nothing.
#   bash bootstrap-project.sh layout-pack <node|web|python|react-native> <target-dir>
#     Lays out a language pack in <target-dir>, which must be empty or
#     absent. The packs are read from PACKS_DIR, by default the
#     languages/ folder next to this script.
#
# Exit codes: 0 done, 1 failed, 2 usage error, unknown pack, or an input
# that is missing or cannot be used, 3 a check of this computer or on
# GitHub did not pass: its steps were shown, with the command to start
# again.
# Runs on bash 3.2 (macOS /bin/bash): no associative arrays, no mapfile,
# no ${var,,}.
#
# Test hooks (environment variables the tests set; users leave them unset):
#   BOOTSTRAP_GH   the gh command to run (default: gh on the PATH).
#   BOOTSTRAP_RUN  a command that replaces the runner of the install and
#                  login commands the script offers. It gets the command
#                  as one argument, so the tests never install anything.
#   BOOTSTRAP_TTY  the terminal the yes to an offered command is read from
#                  (default: /dev/tty), never stdin.
#   BOOTSTRAP_OS_RELEASE  the Linux release file (default: /etc/os-release).
#
# Sourcing this file defines its functions and runs nothing (the tests
# load it that way); running it with bash runs the main part at the end.
set -euo pipefail

# The bootstrapper version and commit this script ships with. The build
# stamps both values in place; in the template the script is unstamped
# and these hold the placeholders. These two lines are the only place a
# placeholder may appear: the build refuses any left in its output, so
# code compares against these variables, never a literal placeholder.
SCRIPT_VERSION='{{TEMPLATE_VERSION}}'
SCRIPT_COMMIT='{{TEMPLATE_COMMIT}}'

# ---------- messages ----------
# Everything the script shows the user goes through these helpers, and
# nothing outside this block writes to the terminal by itself, so the
# tests can check every user-facing string for plain words (see
# "Ease-of-use requirements" in the spec). Only say_command may print
# any word: it shows an exact command for the user to copy.

usage() {
  printf '%s\n' "usage: bootstrap-project.sh layout-pack <node|web|python|react-native> <target-dir>" \
    "   or: bootstrap-project.sh [options]   (run it with --help to see them)" >&2
  exit 2
}

# show_help: the options, on stdout.
show_help() {
  printf '%s\n' \
    "usage: bootstrap-project.sh [options]" \
    "       bootstrap-project.sh layout-pack <node|web|python|react-native> <target-dir>" \
    "" \
    "Sets up a new project on GitHub. It asks a question for each answer" \
    "that is not given as an option below." \
    "" \
    "  --name <name>              the short name of the project on GitHub (needed)" \
    "  --owner <account>          the GitHub account or organisation that owns it" \
    "                             (default: your own account)" \
    "  --project-name <text>      the name people see (default: the short name)" \
    "  --description <text>       one line that says what the project is for (needed)" \
    "  --po-name <text>           the product owner's name (default: your GitHub" \
    "                             profile name, or your account name)" \
    "  --pack <pack>              node, web, python or react-native (needed)" \
    "  --with-deploy              web only: also add the files that publish the website" \
    "  --public, --private        who can see the project (default: public)" \
    "  --license <licence>        none, mit, apache-2.0, gpl-3.0, bsd-3-clause," \
    "                             polyform-noncommercial-1.0.0, or another licence" \
    "                             name from choosealicense.com (needed)" \
    "  --copyright-holder <text>  the name written in the licence (default: the" \
    "                             product owner's name)" \
    "  --dir <folder>             where to put the copy of the project on this" \
    "                             computer (default: ./<name>)" \
    "  --git-name <text>          your name, which git writes into each saved change" \
    "                             (default: the name already set in git)" \
    "  --git-email <address>      your email address, written next to your name" \
    "                             (default: the address already set in git)" \
    "  --ci-timeout <minutes>     how long to wait for the project's checks (default: 20)" \
    "  --non-interactive          ask nothing: every needed option must be given" \
    "  --yes                      do not ask \"Proceed?\" before creating anything" \
    "  --dry-run                  check everything and show the plan, create nothing" \
    "  --resume                   continue a setup that stopped part way" \
    "  --help                     show this text" \
    "" \
    "An option takes its value after a space or after =, as in --name=my-app."
}

# say <text>: one line of information.
say() { printf '%s\n' "$*"; }

# say_command <command>: a command for the user to copy, indented.
say_command() { printf '    %s\n' "$*"; }

# step_start <what>, step_end <result>: the first and last line of a step.
step_start() { printf '==> %s\n' "$*"; }
step_end() { printf '    Done. %s\n' "$*"; }

# show_error <what happened> <what to do next> [raw text]: an error in
# plain words with the next action, on stderr. Raw text (an error from a
# tool or from GitHub) is never shown alone: it comes below, for support.
show_error() {
  local what="${1:-}" next="${2:-}" raw="${3:-}"
  [ -n "$what" ] || what="Something unexpected happened."
  [ -n "$next" ] || next="Run the script again. If the same thing happens, ask for help and show the details below."
  {
    printf 'What happened: %s\n' "$what"
    printf 'What to do next: %s\n' "$next"
    [ -z "$raw" ] || details_block "$raw"
  } >&2
}

# details_block <raw text>: raw text (an error from a tool or from
# GitHub), indented below a line that says it is for support. It never
# comes alone: show_error and guide_details put it under a plain message.
details_block() {
  local line
  printf 'Details for support (you can ignore these):\n'
  printf '%s\n' "$1" | tr -d '\r' | while IFS= read -r line; do
    printf '    %s\n' "$line"
  done
}

# fail <exit code> <what happened> <what to do next> [raw text]
fail() {
  local code="$1"
  shift
  show_error "$@"
  exit "$code"
}

# Texts used by more than one message. They live here so the tests
# check them with the rest.
LP_PACK_NEXT="Choose one of the packs: node, web, python or react-native."
LP_BROKEN_NEXT="This copy of the bootstrapper is incomplete. Download it again; if that does not help, report it to the bootstrapper's maintainers."
ASK_NO_DEFAULT="There is no default, because only you can choose it."
ASK_RETRY="Please try again."
ASK_NEEDED="An answer is needed here."
OPTIONS_NEXT="To see every option, run the script with --help."

# ask <explanation> <question> <default> [choice...]: shows the
# explanation (why the question is asked, in a sentence), the choices,
# then the question with its default, and reads one answer from stdin
# into ANSWER: the spaces around it (a carriage return from Windows
# among them) are removed, and an empty answer takes the default. Returns 1 when stdin has no more
# answers. When stdin is not a terminal (answers given in a file or
# pipe), a line break follows the question, as typing one would.
ask() {
  local why="$1" question="$2" default="$3" got=""
  shift 3
  printf '%s\n' "$why"
  [ "$#" -eq 0 ] || printf '  %s\n' "$@"
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$question" "$default"
  else
    printf '%s: ' "$question"
  fi
  if ! IFS= read -r got && [ -z "$got" ]; then
    printf '\n'
    return 1
  fi
  [ -t 0 ] || printf '\n'
  trim_into "$got"
  ANSWER="${TRIMMED:-$default}"
}

# wait_for_enter: the pause of a guide. Returns 1 when the user types q
# (or stop) or stdin has no more lines, else 0 (check again).
wait_for_enter() {
  local got=""
  printf 'Press Enter to check again, or type q to stop: '
  if ! IFS= read -r got && [ -z "$got" ]; then
    printf '\n'
    return 1
  fi
  [ -t 0 ] || printf '\n'
  trim_into "$got"
  case "$(lower "$TRIMMED")" in
    q | quit | stop) return 1 ;;
  esac
  return 0
}

# ask_terminal <explanation> <question>: a yes-or-no question whose
# answer is read from the terminal, never from stdin (the spec: answers
# piped into the script must not approve an install). The default is no.
# Returns 0 for yes, 1 for any other answer, an empty one, or when there
# is no terminal to read from. A terminal that cannot be read is a no at
# once, with the question line ended. One that can be read but not opened
# (/dev/tty with no terminal attached) is a no too: the redirection
# fails, the read does not run, got stays empty, and that is not a yes.
ask_terminal() {
  local tty="${BOOTSTRAP_TTY:-/dev/tty}" got=""
  printf '%s\n%s [no]: ' "$1" "$2"
  if [ ! -r "$tty" ]; then
    printf '\n'
    return 1
  fi
  if ! { IFS= read -r got; } 2>/dev/null <"$tty" && [ -z "$got" ]; then
    printf '\n'
    return 1
  fi
  [ -c "$tty" ] || printf '\n'
  trim_into "$got"
  case "$(lower "$TRIMMED")" in
    y | yes) return 0 ;;
  esac
  return 1
}

# A guide: guide_begin <title> <why>, then guide_step <text> for each
# numbered step (with say_command for a command to copy), then guide_end
# <what the user sees when it worked> <what to do otherwise> <how the
# script checks it>.
GUIDE_TITLE=""
GUIDE_N=0
guide_begin() {
  GUIDE_TITLE="$1"
  GUIDE_N=0
  printf '%s\n' "$1" "Why this is needed: $2"
}
guide_step() {
  GUIDE_N=$((GUIDE_N + 1))
  printf '  %s. %s\n' "$GUIDE_N" "$*"
}
guide_end() {
  printf '%s\n' "When it has worked: $1" "If you see something else: $2" "How the script checks it: $3"
}
# guide_details <raw text>: after guide_end, the raw text of what went
# wrong (gh's or GitHub's own words), for support; nothing when empty.
guide_details() {
  [ -z "$1" ] || details_block "$1"
}

# ---------- end of messages ----------

# ---------- test hooks ----------

# run_gh <args...>: runs gh, or $BOOTSTRAP_GH, with gh's own prompts
# turned off. They misbehave in Git Bash's terminal, so the script asks
# its own questions.
run_gh() {
  GH_PROMPT_DISABLED=1 "${BOOTSTRAP_GH:-gh}" "$@"
}

# run_offered <command>: runs a fixed command that the script offered and
# the user approved (an install or a login), or hands it to
# $BOOTSTRAP_RUN. gh's prompts stay on: a login needs them.
# The argument runs through bash -c, so it must be a fixed string written
# in this script, never built from user input or any variable (the spec:
# "never built from user input"); the tests refuse a $ in it.
run_offered() {
  (
    unset GH_PROMPT_DISABLED
    if [ -n "${BOOTSTRAP_RUN:-}" ]; then
      "$BOOTSTRAP_RUN" "$1"
    else
      bash -c "$1"
    fi
  )
}

# ---------- layout-pack ----------

# The layout table: "<pack path> <project path>". A path ending in / is
# a folder, copied with everything in it. The optional deploy files
# (web: deploy.yml, wrangler.jsonc) and code-standards.md are not laid
# out. Every other pack file must be in the table, so a new pack file
# cannot be silently left out.
cmd_layout_pack() {
  [ "$#" -eq 2 ] || usage
  local pack="$1" out="$2"
  local here packs_dir common typescript table not_laid_out src
  local from to f covered skip

  # CDPATH is cleared: a user's CDPATH could send cd to another folder of
  # the same name, or make it print the folder into $here.
  here="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  packs_dir="${PACKS_DIR:-$here/languages}"

  common="ci.yml .github/workflows/ci.yml
gitignore .gitignore
vscode-settings.json .vscode/settings.json
vscode-extensions.json .vscode/extensions.json"
  typescript="package.json package.json
tsconfig.json tsconfig.json
biome.json biome.json"

  case "$pack" in
    node)
      table="$common
$typescript
placeholder.test.ts src/placeholder.test.ts"
      not_laid_out="code-standards.md"
      ;;
    web)
      table="$common
$typescript
index.html index.html
vite.config.mts vite.config.mts
playwright.config.ts playwright.config.ts
starter/src/ src/
starter/e2e/ e2e/"
      not_laid_out="code-standards.md deploy.yml wrangler.jsonc"
      ;;
    python)
      table="$common
pyproject.toml pyproject.toml
requirements.txt requirements.txt
requirements-dev.txt requirements-dev.txt
pre-commit-config.yaml .pre-commit-config.yaml
starter/src/ src/"
      not_laid_out="code-standards.md"
      ;;
    react-native)
      table="$common
$typescript
app.json app.json
starter/src/ src/"
      not_laid_out="code-standards.md"
      ;;
    *)
      fail 2 "layout-pack: unknown pack: $pack (expected node, web, python or react-native)" "$LP_PACK_NEXT"
      ;;
  esac

  src="$packs_dir/$pack"
  [ -d "$src" ] || fail 1 "layout-pack: pack folder not found: $src" \
    "Check that the languages folder is next to this script, or set PACKS_DIR to the folder that holds the packs."

  if [ -e "$out" ] && [ -n "$(ls -A "$out")" ]; then
    fail 1 "layout-pack: target dir is not empty: $out" "Choose a folder that is empty or does not exist yet."
  fi

  # Every table source must exist.
  while read -r from _; do
    if [ "${from%/}" != "$from" ]; then
      [ -d "$src/$from" ] || fail 1 "layout-pack: missing from the pack: $from" "$LP_BROKEN_NEXT"
    else
      [ -f "$src/$from" ] || fail 1 "layout-pack: missing from the pack: $from" "$LP_BROKEN_NEXT"
    fi
  done <<<"$table"

  # Every pack file must be in the table or in not_laid_out.
  while IFS= read -r f; do
    covered=""
    for skip in $not_laid_out; do
      [ "$f" = "$skip" ] && covered=1
    done
    while read -r from _; do
      if [ "$f" = "$from" ]; then covered=1; fi
      case "$from" in */) case "$f" in "$from"*) covered=1 ;; esac ;; esac
    done <<<"$table"
    [ -n "$covered" ] || fail 1 "layout-pack: not in the layout table: $f" "$LP_BROKEN_NEXT"
  done < <(cd "$src" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)

  mkdir -p "$out"
  while read -r from to; do
    if [ "${from%/}" != "$from" ]; then
      mkdir -p "$out/$to"
      cp -R "$src/$from." "$out/$to"
    else
      mkdir -p "$(dirname "$out/$to")"
      cp "$src/$from" "$out/$to"
    fi
  done <<<"$table"

  say "Laid out the $pack pack in $out"
}

# ---------- inputs ----------
# Each input comes from an option or, without --non-interactive, from a
# question read with plain `read` (gh's own prompts misbehave in Git
# Bash's terminal). parse_args reads the options; collect_inputs checks
# them, asks for the missing ones or takes their defaults, and checks
# those too. The answers end up in the IN_ variables.

IN_NAME="" IN_OWNER="" IN_PROJECT_NAME="" IN_DESCRIPTION="" IN_PO_NAME=""
IN_PACK="" IN_WITH_DEPLOY="" IN_VISIBILITY="" IN_LICENSE="" IN_COPYRIGHT_HOLDER=""
IN_DIR="" IN_CI_TIMEOUT="" IN_SLUG="" IN_GIT_NAME="" IN_GIT_EMAIL=""
OPT_NON_INTERACTIVE="" OPT_YES="" OPT_DRY_RUN="" OPT_RESUME=""
SEEN_PUBLIC="" SEEN_PRIVATE=""
PROBLEMS=""
CR="$(printf '\r')"
NL='
'
# Letters and digits written out: a range such as A-Z can match accented
# letters in some locales.
ALNUM='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
LOWER_ALNUM='abcdefghijklmnopqrstuvwxyz0123456789'

# trim_into <text>: TRIMMED is the text without spaces around it.
trim_into() {
  TRIMMED="$1"
  TRIMMED="${TRIMMED#"${TRIMMED%%[![:space:]]*}"}"
  TRIMMED="${TRIMMED%"${TRIMMED##*[![:space:]]}"}"
}

# lower <text>: prints it in lowercase (ASCII letters only).
lower() { LC_ALL=C tr '[:upper:]' '[:lower:]' <<<"$1"; }

# slug_of <name>: the name lowercased with each . made a -, used where
# npm and Expo need a slug.
slug_of() { lower "${1//./-}"; }

parse_args() {
  local arg val has_val
  while [ "$#" -gt 0 ]; do
    arg="$1"
    shift
    val=""
    has_val=""
    case "$arg" in
      --*=*) val="${arg#*=}"; arg="${arg%%=*}"; has_val=1 ;;
    esac
    case "$arg" in
      --name | --owner | --project-name | --description | --po-name | --pack | --license | \
        --copyright-holder | --dir | --ci-timeout | --git-name | --git-email)
        if [ -z "$has_val" ]; then
          [ "$#" -gt 0 ] || fail 2 "The option $arg needs a value after it." \
            "Put the value after the option (in quotes if it has spaces) and run the script again. $OPTIONS_NEXT"
          val="$1"
          shift
        fi
        [ -n "$val" ] || fail 2 "The option $arg needs a value after it, and it is empty." \
          "Put the value after the option (in quotes if it has spaces) and run the script again. $OPTIONS_NEXT"
        case "$arg" in
          --name) IN_NAME="$val" ;;
          --owner) IN_OWNER="$val" ;;
          --project-name) IN_PROJECT_NAME="$val" ;;
          --description) IN_DESCRIPTION="$val" ;;
          --po-name) IN_PO_NAME="$val" ;;
          --pack) IN_PACK="$val" ;;
          --license) IN_LICENSE="$val" ;;
          --copyright-holder) IN_COPYRIGHT_HOLDER="$val" ;;
          --dir) IN_DIR="$val" ;;
          --ci-timeout) IN_CI_TIMEOUT="$val" ;;
          --git-name) IN_GIT_NAME="$val" ;;
          --git-email) IN_GIT_EMAIL="$val" ;;
        esac
        ;;
      --with-deploy | --public | --private | --non-interactive | --yes | --dry-run | --resume | --help)
        [ -z "$has_val" ] || fail 2 "The option $arg does not take a value." \
          "Remove the = and what follows it, and run the script again. $OPTIONS_NEXT"
        case "$arg" in
          --with-deploy) IN_WITH_DEPLOY=yes ;;
          --public) SEEN_PUBLIC=1; IN_VISIBILITY=public ;;
          --private) SEEN_PRIVATE=1; IN_VISIBILITY=private ;;
          --non-interactive) OPT_NON_INTERACTIVE=1 ;;
          --yes) OPT_YES=1 ;;
          --dry-run) OPT_DRY_RUN=1 ;;
          --resume) OPT_RESUME=1 ;;
          --help) show_help; exit 0 ;;
        esac
        ;;
      -*)
        fail 2 "The option $arg is not one this script knows." \
          "Check its spelling and run the script again. $OPTIONS_NEXT"
        ;;
      *) usage ;;
    esac
  done
}

# ---- checks ----
# check_<input> <value>: on success sets CHECKED to the value as it will
# be used (trimmed, and lowercased where noted) and returns 0; otherwise
# sets PROBLEM to what is wrong, in a sentence, and returns 1.

# check_text <value>: rules for every name value (spec: they go into JSON
# and HTML): not empty, one line, no control characters, and none of
# " \ < > & or a backtick.
check_text() {
  trim_into "$1"
  case "$TRIMMED" in
    "") PROBLEM="It cannot be empty."; return 1 ;;
    *[[:cntrl:]]*)
      PROBLEM="It must be one line, with no tabs or other invisible characters."
      return 1
      ;;
    *'"'* | *'\'* | *'<'* | *'>'* | *'&'* | *'`'*)
      PROBLEM='It cannot contain any of these characters: " \ < > & or a backtick (`).'
      return 1
      ;;
  esac
  CHECKED="$TRIMMED"
}

# check_table_text <value>: a name value that also goes into a table in
# the README, where a | would start a new column.
check_table_text() {
  check_text "$1" || return 1
  case "$CHECKED" in
    *'|'*) PROBLEM="It cannot contain a | (a vertical bar), because it goes into a table."; return 1 ;;
  esac
}

check_name() {
  local slug
  trim_into "$1"
  case "$TRIMMED" in
    "") PROBLEM="It cannot be empty."; return 1 ;;
    [!$ALNUM]* | *[!$ALNUM._-]*)
      PROBLEM="Use only letters, digits, dots (.), dashes (-) and underscores (_), with no spaces, and start with a letter or a digit."
      return 1
      ;;
  esac
  slug="$(slug_of "$TRIMMED")"
  if [ "${#slug}" -gt 214 ]; then
    PROBLEM="It is too long: use at most 214 characters."
    return 1
  fi
  if [ "$slug" = node_modules ]; then
    PROBLEM="That name is kept for the project's own tools; choose another one."
    return 1
  fi
  CHECKED="$TRIMMED"
}

check_owner() {
  trim_into "$1"
  case "$TRIMMED" in
    "") PROBLEM="It cannot be empty."; return 1 ;;
    [!$ALNUM]* | *[!$ALNUM-]*)
      PROBLEM="Use the name of a GitHub account or organisation: letters, digits and dashes (-), starting with a letter or a digit."
      return 1
      ;;
  esac
  CHECKED="$TRIMMED"
}

# check_pack: lowercased.
check_pack() {
  trim_into "$1"
  CHECKED="$(lower "$TRIMMED")"
  case "$CHECKED" in
    node | web | python | react-native) return 0 ;;
  esac
  PROBLEM="Choose one of the packs: node, web, python or react-native."
  return 1
}

# check_license: lowercased. "none", a listed licence, or any key of
# GitHub's licence list; whether that key exists is checked with GitHub
# before anything is created, not here.
check_license() {
  trim_into "$1"
  CHECKED="$(lower "$TRIMMED")"
  case "$CHECKED" in
    "" | [!$LOWER_ALNUM]* | *[!$LOWER_ALNUM.-]*)
      PROBLEM="Use none, one of the listed licences, or the short name of a licence from choosealicense.com (such as agpl-3.0): letters, digits, dots and dashes."
      return 1
      ;;
  esac
}

# check_ci_timeout: whole minutes from 1 to 9999, leading zeros dropped.
check_ci_timeout() {
  trim_into "$1"
  case "$TRIMMED" in
    "" | *[!0123456789]*) PROBLEM="Use a whole number of minutes, from 1 to 9999."; return 1 ;;
  esac
  CHECKED="${TRIMMED#"${TRIMMED%%[!0]*}"}"
  if [ -z "$CHECKED" ] || [ "${#CHECKED}" -gt 4 ]; then
    PROBLEM="Use a whole number of minutes, from 1 to 9999."
    return 1
  fi
}

# check_dir: a ~ at the start stands for the home folder, as the shell
# would read it (a typed answer or a --dir=~/x option does not go through
# the shell). Another account's ~name is refused.
check_dir() {
  trim_into "$1"
  case "$TRIMMED" in
    "") PROBLEM="It cannot be empty."; return 1 ;;
    *[[:cntrl:]]*) PROBLEM="It must be one line, with no tabs or other invisible characters."; return 1 ;;
    "~" | "~/"*)
      [ -n "${HOME:-}" ] || { PROBLEM="Your home folder is not known here, so ~ cannot be used: write the folder's full path."; return 1; }
      CHECKED="$HOME${TRIMMED#"~"}"
      return 0
      ;;
    "~"*)
      PROBLEM="A ~ at the start can only stand for your own home folder, as in ~/projects/app: write the folder's full path instead."
      return 1
      ;;
  esac
  CHECKED="$TRIMMED"
}

# check_email: one line with no spaces, something before and after a
# single @. Whether the address works is not checked.
check_email() {
  check_text "$1" || return 1
  case "$CHECKED" in
    *[[:space:]]*) PROBLEM="Use an email address with no spaces, as in ada@example.com."; return 1 ;;
    *@*@* | @* | *@) PROBLEM="Use an email address with one @ and text on both sides, as in ada@example.com."; return 1 ;;
    *@*) return 0 ;;
  esac
  PROBLEM="Use an email address with one @ and text on both sides, as in ada@example.com."
  return 1
}

# Answers to a question with choices may also be the choice's number.
check_pack_answer() {
  case "$1" in
    1) set -- node ;;
    2) set -- web ;;
    3) set -- python ;;
    4) set -- react-native ;;
  esac
  check_pack "$1"
}

check_license_answer() {
  case "$1" in
    1) set -- none ;;
    2) set -- mit ;;
    3) set -- apache-2.0 ;;
    4) set -- gpl-3.0 ;;
    5) set -- bsd-3-clause ;;
    6) set -- polyform-noncommercial-1.0.0 ;;
    *[!0123456789]*) ;;
    *) PROBLEM="Choose a number from 1 to 6, or type the licence's name."; return 1 ;;
  esac
  check_license "$1"
}

check_visibility_answer() {
  CHECKED="$(lower "$1")"
  case "$CHECKED" in
    1 | public) CHECKED=public ;;
    2 | private) CHECKED=private ;;
    *) PROBLEM="Choose public or private."; return 1 ;;
  esac
}

check_yes_no() {
  CHECKED="$(lower "$1")"
  case "$CHECKED" in
    y | yes) CHECKED=yes ;;
    n | no) CHECKED=no ;;
    *) PROBLEM="Answer yes or no."; return 1 ;;
  esac
}

# add_problem <option> <problem>: one line of the list shown when the
# options cannot be used.
add_problem() {
  PROBLEMS="$PROBLEMS$NL    - $1: $2"
}

# stop_if_problems: shows every problem found so far, exit 2.
stop_if_problems() {
  [ -z "$PROBLEMS" ] || fail 2 "Some options are missing or cannot be used:$PROBLEMS" \
    "Correct the options listed above and run the script again. $OPTIONS_NEXT"
}

# check_given <option> <checker> <value>: checks an input given as an
# option; an empty value (not given) passes. On success CHECKED is the
# value to use.
check_given() {
  CHECKED="$3"
  [ -n "$3" ] || return 0
  "$2" "$3" && return 0
  add_problem "$1" "$PROBLEM"
  return 1
}

# prompt_for <checker> <explanation> <question> <default> [choice...]:
# asks until the answer passes the checker; the result is in CHECKED.
# A question without a default needs an answer.
prompt_for() {
  local check="$1"
  shift
  while :; do
    ask "$@" || fail 2 "The script stopped because a question got no answer." \
      "Run the script again and type an answer to each question, or give every answer as an option with --non-interactive. $OPTIONS_NEXT"
    if [ -z "$ANSWER" ]; then
      say "$ASK_NEEDED $ASK_RETRY"
    elif "$check" "$ANSWER"; then
      return 0
    else
      say "$PROBLEM $ASK_RETRY"
    fi
  done
}

# answer <option> <checker> <default> <explanation> <question> [choice...]:
# an input not given as an option. Asked as a question, with the default
# offered; with --non-interactive, the default is taken and checked like
# an answer (a missing required input has an empty default). CHECKED is
# the value, also when it was refused.
answer() {
  local opt="$1" check="$2" default="$3" why="$4" question="$5"
  shift 5
  if [ -z "$OPT_NON_INTERACTIVE" ]; then
    prompt_for "$check" "$why" "$question" "$default" "$@"
    return 0
  fi
  CHECKED="$default"
  if [ -z "$default" ]; then
    add_problem "$opt" "It is missing. It has no default, so it must be given."
    return 1
  fi
  "$check" "$default" && return 0
  add_problem "$opt" "$PROBLEM (This was the default; give the option to choose another value.)"
  CHECKED="$default"
  return 1
}

# check_options: the options given are checked first, all of them, so
# one run lists every problem; with --non-interactive the missing ones
# are listed too. cmd_setup runs it before the checks of this computer
# and of GitHub (#148 review, finding 5), so a run with a wrong option
# and a missing tool reports the option at once; collect_inputs runs it
# when it has not run yet.
OPTIONS_CHECKED=""
check_options() {
  [ -z "$OPTIONS_CHECKED" ] || return 0
  OPTIONS_CHECKED=1
  check_given --name check_name "$IN_NAME" && IN_NAME="$CHECKED"
  check_given --owner check_owner "$IN_OWNER" && IN_OWNER="$CHECKED"
  check_given --project-name check_table_text "$IN_PROJECT_NAME" && IN_PROJECT_NAME="$CHECKED"
  check_given --description check_text "$IN_DESCRIPTION" && IN_DESCRIPTION="$CHECKED"
  check_given --po-name check_table_text "$IN_PO_NAME" && IN_PO_NAME="$CHECKED"
  check_given --pack check_pack "$IN_PACK" && IN_PACK="$CHECKED"
  check_given --license check_license "$IN_LICENSE" && IN_LICENSE="$CHECKED"
  check_given --copyright-holder check_text "$IN_COPYRIGHT_HOLDER" && IN_COPYRIGHT_HOLDER="$CHECKED"
  check_given --dir check_dir "$IN_DIR" && IN_DIR="$CHECKED"
  check_given --ci-timeout check_ci_timeout "$IN_CI_TIMEOUT" && IN_CI_TIMEOUT="$CHECKED"
  check_given --git-name check_text "$IN_GIT_NAME" && IN_GIT_NAME="$CHECKED"
  check_given --git-email check_email "$IN_GIT_EMAIL" && IN_GIT_EMAIL="$CHECKED"
  if [ -n "$SEEN_PUBLIC" ] && [ -n "$SEEN_PRIVATE" ]; then
    add_problem --private "Give either --public or --private, not both."
  fi
  check_deploy_pack
  if [ -n "$OPT_NON_INTERACTIVE" ]; then
    # Missing required inputs are reported before GitHub is asked for
    # any default.
    [ -n "$IN_NAME" ] || add_problem --name "It is missing. It has no default, so it must be given."
    [ -n "$IN_DESCRIPTION" ] || add_problem --description "It is missing. It has no default, so it must be given."
    [ -n "$IN_PACK" ] || add_problem --pack "It is missing. It has no default, so it must be given."
    [ -n "$IN_LICENSE" ] || add_problem --license "It is missing. It has no default, so it must be given."
    # The git name and email default to git's own settings; without
    # them they are missing too. Those settings can be read only when
    # git is installed: without git, the git check shows its guide
    # first, and a missing name or email is reported after it.
    if check_git; then
      read_git_identity
      [ -n "$IN_GIT_NAME" ] || [ -n "$GIT_CFG_NAME" ] \
        || add_problem --git-name "It is missing, and git on this computer has no name set, so it must be given."
      [ -n "$IN_GIT_EMAIL" ] || [ -n "$GIT_CFG_EMAIL" ] \
        || add_problem --git-email "It is missing, and git on this computer has no email address set, so it must be given."
    fi
  fi
  stop_if_problems
}

collect_inputs() {
  check_options

  # Then each one not given, in the order of the questions.
  if [ -z "$IN_NAME" ]; then
    answer --name check_name "" \
      "The short name of your project on GitHub, also used in its web address: letters, digits, dots, dashes and underscores, no spaces. $ASK_NO_DEFAULT" \
      "Project name" || true
    IN_NAME="$CHECKED"
  fi
  IN_SLUG="$(slug_of "$IN_NAME")"
  if [ -z "$IN_PROJECT_NAME" ]; then
    answer --project-name check_table_text "$IN_NAME" \
      "The name people see at the top of the project's documents; it may have spaces and capital letters." \
      "Display name" || true
    IN_PROJECT_NAME="$CHECKED"
  fi
  if [ -z "$IN_DESCRIPTION" ]; then
    answer --description check_text "" \
      "One sentence that says what the project is for; it goes at the top of the project's documents. $ASK_NO_DEFAULT" \
      "Description" || true
    IN_DESCRIPTION="$CHECKED"
  fi
  if [ -z "$IN_OWNER" ]; then
    need_github_account
    answer --owner check_owner "$GH_LOGIN" \
      "The GitHub account or organisation that will own the project; press Enter to use your own account." \
      "Owner" || true
    IN_OWNER="$CHECKED"
  fi
  if [ -z "$IN_PO_NAME" ]; then
    need_github_account
    answer --po-name check_table_text "${GH_PROFILE_NAME:-$GH_LOGIN}" \
      "The name of the product owner, the person who decides what the project should do (usually you)." \
      "Product owner name" || true
    IN_PO_NAME="$CHECKED"
  fi
  if [ -z "$IN_PACK" ]; then
    answer --pack check_pack_answer "" \
      "The kind of project, which sets the programming language and the tools that check the work. $ASK_NO_DEFAULT" \
      "Language pack (type the number or the name)" \
      "1) node: a program or service that runs on a computer or server, written in TypeScript" \
      "2) web: a website or web app that people open in their browser" \
      "3) python: a program written in Python, for example for data work or automation" \
      "4) react-native: a mobile app for phones and tablets (iPhone and Android)" || true
    IN_PACK="$CHECKED"
    check_deploy_pack
    stop_if_problems
  fi
  if [ "$IN_PACK" = web ] && [ -z "$IN_WITH_DEPLOY" ]; then
    answer --with-deploy check_yes_no no \
      "Also add the files that publish the website on Cloudflare (a hosting service); you can add them later." \
      "Add the publishing files? (yes or no)" || true
    IN_WITH_DEPLOY="$CHECKED"
  fi
  [ -n "$IN_WITH_DEPLOY" ] || IN_WITH_DEPLOY=no
  if [ -z "$IN_VISIBILITY" ]; then
    answer --public check_visibility_answer public \
      "Who can see the project on GitHub; the protection this setup turns on is free for public projects, but needs a paid GitHub plan for private ones." \
      "Visibility (type the number or the name)" \
      "1) public: anyone can see the project and its code" \
      "2) private: only you and the people you invite can see it" || true
    IN_VISIBILITY="$CHECKED"
  fi
  if [ -z "$IN_LICENSE" ]; then
    answer --license check_license_answer "" \
      "The licence tells others what they may do with your code. $ASK_NO_DEFAULT" \
      "Licence (type the number or the name)" \
      "1) none: no licence, so nobody else may copy, change or share the code" \
      "2) mit: anyone may use, change and share the code, also in paid products, if they keep your name in it" \
      "3) apache-2.0: like mit, and it also gives users the rights to any patents in the code" \
      "4) gpl-3.0: anyone may use and change the code, but what they share must be open under the same licence" \
      "5) bsd-3-clause: like mit, and others may not use your name to promote their work" \
      "6) polyform-noncommercial-1.0.0: anyone may use and change the code, but not to make money with it" \
      "Or type the short name of another licence from choosealicense.com, such as agpl-3.0." || true
    IN_LICENSE="$CHECKED"
  fi
  if [ -z "$IN_COPYRIGHT_HOLDER" ]; then
    if [ "$IN_LICENSE" = none ]; then
      # No licence text, so the holder is not asked for.
      CHECKED="$IN_PO_NAME"
    else
      answer --copyright-holder check_text "$IN_PO_NAME" \
        "The name written in the licence as the owner of the code: a person or a company." \
        "Copyright holder" || true
    fi
    IN_COPYRIGHT_HOLDER="$CHECKED"
  fi
  if [ -z "$IN_DIR" ]; then
    answer --dir check_dir "./$IN_NAME" \
      "Where to put the copy of your project on this computer; the folder must be new or empty." \
      "Folder" || true
    IN_DIR="$CHECKED"
  fi
  read_git_identity
  if [ -z "$IN_GIT_NAME" ]; then
    answer --git-name check_text "$GIT_CFG_NAME" \
      "Your name, which git (the tool that keeps the history of your project's files) writes next to each change you save; anyone who can see the project can see it." \
      "Your name for git" || true
    IN_GIT_NAME="$CHECKED"
  fi
  if [ -z "$IN_GIT_EMAIL" ]; then
    answer --git-email check_email "$GIT_CFG_EMAIL" \
      "Your email address, which git writes next to your name on each change you save; anyone who can see the project can see it." \
      "Your email address for git" || true
    IN_GIT_EMAIL="$CHECKED"
  fi
  [ -n "$IN_CI_TIMEOUT" ] || IN_CI_TIMEOUT=20
  stop_if_problems
}

# read_git_identity: GIT_CFG_NAME and GIT_CFG_EMAIL, the name and email
# in git's global settings (empty when not set), read once. They are
# only read here: they are written into the new project's own settings
# after it is copied to this computer, never into the global ones.
GIT_CFG_NAME=""
GIT_CFG_EMAIL=""
GIT_CFG_READ=""
read_git_identity() {
  [ -z "$GIT_CFG_READ" ] || return 0
  GIT_CFG_READ=1
  GIT_CFG_NAME="$(git config --global --get user.name 2>/dev/null)" || GIT_CFG_NAME=""
  GIT_CFG_EMAIL="$(git config --global --get user.email 2>/dev/null)" || GIT_CFG_EMAIL=""
  GIT_CFG_NAME="${GIT_CFG_NAME//$CR/}"
  GIT_CFG_EMAIL="${GIT_CFG_EMAIL//$CR/}"
}

# check_deploy_pack: --with-deploy is for the web pack only.
check_deploy_pack() {
  if [ "$IN_WITH_DEPLOY" = yes ] && [ -n "$IN_PACK" ] && [ "$IN_PACK" != web ]; then
    case "$PROBLEMS" in
      *"- --with-deploy:"*) ;;
      *) add_problem --with-deploy "It is only for the web pack." ;;
    esac
  fi
}


# ---------- preflight: checks on this computer ----------
# Before anything is created the script checks this computer (spec:
# "Preflight (guided)"). A check that fails shows a guide: numbered steps
# for this OS, why the step is needed, what the user sees when it worked,
# what to do otherwise and how the script checks it. Then it waits for
# Enter and checks again, until the check passes or the user stops; on
# stop it shows the command to start again and exits 3. With
# --non-interactive it shows the guide and exits 3 at once. Where the
# script can run the fix itself (an install), the guide sets OFFER and the
# script offers the command once, running it only after a yes typed at
# the terminal (ask_terminal): never from stdin, never because of --yes.
#
# guided_check <check> <guide> is the loop; the GitHub checks reuse it.
# A check returns 0 when it passes; a guide prints through guide_begin,
# guide_step, say_command and guide_end, and may set OFFER.

OS_KIND=""
LINUX_PM=""
OFFER=""
RESTART_CMD=""
RESTART_ARGS=""
NO_RECHECK=""
DQ='"'
SQ="'"

# detect_os: OS_KIND is macos, linux, windows (Git Bash, MSYS or Cygwin)
# or other, from uname -s. On Linux, LINUX_PM is the package manager
# (apt, dnf, pacman or zypper) read from the release file, or empty.
detect_os() {
  local kind="" f line id="" like="" w
  kind="$(uname -s 2>/dev/null)" || kind=""
  kind="${kind//$CR/}"
  case "$kind" in
    Darwin) OS_KIND=macos ;;
    Linux) OS_KIND=linux ;;
    MINGW* | MSYS* | CYGWIN*) OS_KIND=windows ;;
    *) OS_KIND=other ;;
  esac
  LINUX_PM=""
  [ "$OS_KIND" = linux ] || return 0
  f="${BOOTSTRAP_OS_RELEASE:-/etc/os-release}"
  [ -r "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//$CR/}"
    case "$line" in
      ID=*) id="${line#ID=}" ;;
      ID_LIKE=*) like="${line#ID_LIKE=}" ;;
    esac
  done <"$f"
  id="${id//$DQ/}"
  id="${id//$SQ/}"
  like="${like//$DQ/}"
  like="${like//$SQ/}"
  for w in $id $like; do
    case "$w" in
      debian | ubuntu) LINUX_PM=apt ;;
      fedora | rhel | centos) LINUX_PM=dnf ;;
      arch) LINUX_PM=pacman ;;
      suse | sles | opensuse*) LINUX_PM=zypper ;;
      *) continue ;;
    esac
    break
  done
}

# quote_word <word>: QUOTED is the word as it must be typed in a shell to
# reach the script unchanged.
quote_word() {
  local esc="'\\''"
  case "$1" in
    "") QUOTED="''" ;;
    *[!${ALNUM}_./=:,@%+-]*) QUOTED="'${1//$SQ/$esc}'" ;;
    *) QUOTED="$1" ;;
  esac
}

# remember_command <options...>: RESTART_CMD is the command the user ran
# (without its leading "bash"), to show when they stop at a guide.
remember_command() {
  local script="${BASH_SOURCE[0]:-}" arg
  if [ -z "$script" ] || [ -n "$SCRIPT_PIPED" ]; then script=bootstrap-project.sh; fi
  RESTART_ARGS=""
  for arg in "$@"; do
    quote_word "$arg"
    RESTART_ARGS="$RESTART_ARGS $QUOTED"
  done
  quote_word "$script"
  RESTART_CMD="$QUOTED$RESTART_ARGS"
}

# stop_at_guide: the user stopped at a guide, or --non-interactive (or a
# check that cannot pass in this run) showed it: exit 3 with the command
# to start again.
stop_at_guide() {
  [ -n "$RESTART_CMD" ] || remember_command
  say "To start again, run this command:"
  say_command "bash $RESTART_CMD"
  fail 3 "$GUIDE_TITLE The script stopped here, and nothing was created." \
    "Follow the steps above, then run the command shown to start again."
}

# offered <offer> show|run: the fixed command of each offer, shown for the
# user to copy, or run (through run_offered) after their yes. Each one is
# written twice on its line, and a test checks that what runs is what
# was shown.
offered() {
  case "$1" in
    xcode) if [ "$2" = run ]; then run_offered "xcode-select --install"; else say_command "xcode-select --install"; fi ;;
    winget-git) if [ "$2" = run ]; then run_offered "winget install --id Git.Git -e --source winget"; else say_command "winget install --id Git.Git -e --source winget"; fi ;;
    brew-gh) if [ "$2" = run ]; then run_offered "brew install gh"; else say_command "brew install gh"; fi ;;
    brew-gh-upgrade) if [ "$2" = run ]; then run_offered "brew upgrade gh"; else say_command "brew upgrade gh"; fi ;;
    winget-gh) if [ "$2" = run ]; then run_offered "winget install --id GitHub.cli -e --source winget"; else say_command "winget install --id GitHub.cli -e --source winget"; fi ;;
    winget-gh-upgrade) if [ "$2" = run ]; then run_offered "winget upgrade --id GitHub.cli -e --source winget"; else say_command "winget upgrade --id GitHub.cli -e --source winget"; fi ;;
    gh-refresh-workflow) if [ "$2" = run ]; then run_offered "gh auth refresh -h github.com -s workflow"; else say_command "gh auth refresh -h github.com -s workflow"; fi ;;
    gh-refresh-public) if [ "$2" = run ]; then run_offered "gh auth refresh -h github.com -s public_repo,workflow"; else say_command "gh auth refresh -h github.com -s public_repo,workflow"; fi ;;
    gh-refresh-repo) if [ "$2" = run ]; then run_offered "gh auth refresh -h github.com -s repo,workflow"; else say_command "gh auth refresh -h github.com -s repo,workflow"; fi ;;
    *) return 1 ;;
  esac
}

# offer_command: offers the command of the guide just shown (OFFER).
# Returns 0 when it ran (the check runs again straight away), 1 when the
# user did not say yes.
offer_command() {
  say "The script can run this command for you:"
  offered "$OFFER" show
  if ask_terminal "It runs only if you type yes; Enter or any other answer skips it, and you can run it yourself." \
    "Run it now? (yes or no)"; then
    if offered "$OFFER" run; then
      say "The command finished. Checking again."
    else
      say "The command stopped with an error (its messages are above). Checking again."
    fi
    return 0
  fi
  say "Not run. Follow the steps above yourself."
  return 1
}

# guided_check <check> <guide>: see the top of this section. A guide
# whose check cannot pass again in this run (a new script or a new
# terminal window is needed) sets NO_RECHECK: it stops at once, as with
# --non-interactive.
guided_check() {
  local check="$1" guide="$2" offered_once=""
  while ! "$check"; do
    OFFER=""
    NO_RECHECK=""
    "$guide"
    [ -z "$OPT_NON_INTERACTIVE" ] && [ -z "$NO_RECHECK" ] || stop_at_guide
    if [ -n "$OFFER" ] && [ -z "$offered_once" ]; then
      offered_once=1
      offer_command && continue
    fi
    wait_for_enter || stop_at_guide
  done
}

# ---- bash ----

check_bash_version() {
  [ "$1" -gt 3 ] || { [ "$1" -eq 3 ] && [ "$2" -ge 2 ]; }
}

guide_bash_old() {
  guide_begin "This bash is too old for the script: it needs version 3.2 or later." \
    "bash is the program that runs this script, and the script uses features that older versions do not have."
  case "$OS_KIND" in
    macos)
      guide_step "Start the script with the bash that comes with macOS: type /bin/bash in place of bash in the command shown below."
      ;;
    windows)
      guide_step "Open https://git-scm.com/download/win in your browser and install the current Git for Windows, which comes with a newer bash."
      guide_step "Close this window, open Git Bash again from the Start menu, and start the script there."
      ;;
    *)
      guide_step "Install a newer bash with your system's software installer, or with this command, which asks for your computer password:"
      case "$LINUX_PM" in
        apt) say_command "sudo apt install bash" ;;
        dnf) say_command "sudo dnf install bash" ;;
        pacman) say_command "sudo pacman -S bash" ;;
        zypper) say_command "sudo zypper install bash" ;;
        *) say "    (your system's own install command, followed by the word bash)" ;;
      esac
      guide_step "Open a new terminal window and start the script there."
      ;;
  esac
  guide_end "the script starts with \"Done. bash 3.2 is new enough.\" or a later version." \
    "ask someone who manages this computer to install bash 3.2 or later." \
    "it reads the version of the bash that runs it. It cannot check again in this run, so it stops here."
}

# preflight_bash [major minor]: the version of the bash running the
# script (the arguments are for the tests).
preflight_bash() {
  local major="${1:-${BASH_VERSINFO[0]}}" minor="${2:-${BASH_VERSINFO[1]}}"
  step_start "Checking that bash (the program that runs this script) is new enough"
  if ! check_bash_version "$major" "$minor"; then
    guide_bash_old
    stop_at_guide
  fi
  step_end "bash $major.$minor is new enough."
}

# ---- git ----

check_git() { git --version >/dev/null 2>&1; }

guide_git() {
  guide_begin "git is not installed." \
    "git keeps the history of your project's files, and the script needs it to put a copy of your project on this computer."
  case "$OS_KIND" in
    macos)
      guide_step "Run this command; it starts Apple's installer for its command line developer tools, which include git:"
      offered xcode show
      OFFER=xcode
      guide_step "A window opens and offers to install the tools. Click Install, then Agree, and wait until it says that the software was installed (this can take several minutes)."
      guide_step "Come back to this window."
      guide_end "the window says \"The software was installed\", and the script says \"Done. git is installed.\"" \
        "if no window opens, open https://git-scm.com/download/mac in your browser and follow the steps there." \
        "it runs git --version, which works only when git is installed."
      ;;
    windows)
      if command -v winget >/dev/null 2>&1; then
        guide_step "Run this command; it installs Git for Windows, which includes git:"
        offered winget-git show
        OFFER=winget-git
      else
        guide_step "Open https://git-scm.com/download/win in your browser, download Git for Windows and run the installer, keeping the default choices."
      fi
      guide_step "Close this window, open Git Bash again from the Start menu, and start the script there, so that it finds git."
      guide_end "the script says \"Done. git is installed.\"" \
        "if the script still says that git is not installed, check that you opened Git Bash again after the install." \
        "it runs git --version, which works only when git is installed."
      ;;
    *)
      case "$LINUX_PM" in
        apt | dnf | pacman | zypper)
          guide_step "Run this command in another terminal window; it asks for your computer password, because installing needs it:"
          case "$LINUX_PM" in
            apt) say_command "sudo apt install git" ;;
            dnf) say_command "sudo dnf install git" ;;
            pacman) say_command "sudo pacman -S git" ;;
            zypper) say_command "sudo zypper install git" ;;
          esac
          ;;
        *)
          if [ "$OS_KIND" = linux ]; then
            guide_step "Open https://git-scm.com/download/linux in your browser and run the install command it shows for your system."
          else
            guide_step "Open https://git-scm.com/downloads in your browser and follow the steps for your system."
          fi
          ;;
      esac
      guide_step "Come back to this window."
      guide_end "the script says \"Done. git is installed.\"" \
        "if the install command says that it cannot find git, update your system's list of software first, then try again." \
        "it runs git --version, which works only when git is installed."
      ;;
  esac
}

preflight_git() {
  step_start "Checking that git is installed"
  guided_check check_git guide_git
  step_end "git is installed."
}

# ---- gh ----

# check_gh: gh runs, and its create command offers --template (the
# feature check: no version number is compared). GH_PROBLEM says which
# part failed: missing or old.
GH_PROBLEM=""
check_gh() {
  local help=""
  if ! run_gh --version >/dev/null 2>&1; then
    GH_PROBLEM=missing
    return 1
  fi
  # The command in quotes is not a message: the marker keeps it out of
  # the banned-words check.
  help="$(run_gh repo create --help 2>&1)" || help="" # not-a-message
  case "$help" in
    *--template*) return 0 ;;
  esac
  GH_PROBLEM=old
  return 1
}

guide_gh() {
  case "$GH_PROBLEM" in
    old) guide_gh_old ;;
    *) guide_gh_missing ;;
  esac
}

guide_gh_missing() {
  guide_begin "The GitHub command-line tool (gh) is not installed." \
    "The script uses gh to talk to GitHub for you: to create your project there and to check it."
  gh_install_steps install
  guide_end "the script says \"Done. gh is installed and can create a project from a template.\"" \
    "if the script still says that gh is not installed, close this window, open a new one, and start the script again there." \
    "it runs gh --version, which works only when gh is installed."
}

guide_gh_old() {
  guide_begin "The GitHub command-line tool (gh) on this computer is too old." \
    "The script needs a gh that can create a project from a template, which older versions of gh cannot do."
  gh_install_steps upgrade
  guide_end "the script says \"Done. gh is installed and can create a project from a template.\"" \
    "if the script still says that gh is too old, close this window, open a new one, and start the script again there." \
    "it checks that gh's command for creating a project offers the --template option."
}

# gh_install_steps install|upgrade: the steps both gh guides share.
gh_install_steps() {
  case "$OS_KIND" in
    macos)
      if command -v brew >/dev/null 2>&1; then
        guide_step "Run this command; it uses Homebrew, the installer already on this Mac:"
        if [ "$1" = upgrade ]; then offered brew-gh-upgrade show; OFFER=brew-gh-upgrade; else offered brew-gh show; OFFER=brew-gh; fi
      else
        guide_step "Open https://cli.github.com in your browser, click Download for Mac, open the downloaded file and follow the installer."
      fi
      guide_step "Come back to this window."
      ;;
    windows)
      if command -v winget >/dev/null 2>&1; then
        guide_step "Run this command; it uses winget, the installer that comes with Windows:"
        if [ "$1" = upgrade ]; then offered winget-gh-upgrade show; OFFER=winget-gh-upgrade; else offered winget-gh show; OFFER=winget-gh; fi
      else
        guide_step "Open https://cli.github.com in your browser, click Download for Windows, and run the downloaded installer, keeping the default choices."
      fi
      guide_step "Close this window, open Git Bash again from the Start menu, and start the script there, so that it finds the new gh."
      ;;
    linux)
      guide_step "Open https://github.com/cli/cli/blob/trunk/docs/install_linux.md in your browser and follow the steps for your system; the gh in your system's own software list may be too old."
      guide_step "Come back to this window."
      ;;
    *)
      guide_step "Open https://cli.github.com in your browser and follow the steps for your system."
      guide_step "Come back to this window."
      ;;
  esac
}

preflight_gh() {
  step_start "Checking that the GitHub command-line tool (gh) is installed and new enough"
  guided_check check_gh guide_gh
  step_end "gh is installed and can create a project from a template."
}

# preflight_tools: the checks that need no answer, run before the first
# question and before anything is read from GitHub.
preflight_tools() {
  preflight_bash
  preflight_git
  preflight_gh
}

# ---- npm (node, web and react-native packs) ----

check_npm() { npm --version >/dev/null 2>&1; }

guide_npm() {
  guide_begin "npm (part of Node.js) is not installed." \
    "The node, web and react-native packs use npm to record the exact versions of the tools your project uses, so that its checks on GitHub can install the same ones."
  guide_step "Open https://nodejs.org in your browser and download the version marked LTS (the one with long-term support)."
  case "$OS_KIND" in
    macos) guide_step "Open the downloaded file and follow the installer, then come back to this window." ;;
    windows)
      guide_step "Run the downloaded installer, keeping the default choices."
      guide_step "Close this window, open Git Bash again from the Start menu, and start the script there, so that it finds npm."
      ;;
    *)
      guide_step "On the download page choose your system and follow the steps shown there; the Node.js in your system's own software list may be older than the one your project's checks use."
      guide_step "Come back to this window."
      ;;
  esac
  guide_end "the script says \"Done. npm is installed.\"" \
    "if the script still says that npm is not installed, close this window, open a new one, and start the script again there." \
    "it runs npm --version, which works only when npm is installed."
}

preflight_npm() {
  case "$IN_PACK" in
    node | web | react-native) ;;
    *) return 0 ;;
  esac
  step_start "Checking that npm is installed (the $IN_PACK pack needs it)"
  guided_check check_npm guide_npm
  step_end "npm is installed."
}

# ---- the target folder ----

# check_target_dir: IN_DIR does not exist, or is an empty folder; with
# --resume a folder with files is allowed too (it may hold the copy of
# the project from the run that stopped). DIR_PROBLEM: file or not-empty.
DIR_PROBLEM=""
DIR_DONE=""
check_target_dir() {
  local entries=""
  DIR_DONE="The folder is new or empty."
  if [ -d "$IN_DIR" ]; then
    entries="$(ls -A "$IN_DIR" 2>/dev/null)" || entries=unreadable
    [ -n "$entries" ] || return 0
    if [ -n "$OPT_RESUME" ]; then
      DIR_DONE="The folder has files in it, which --resume allows."
      return 0
    fi
    DIR_PROBLEM=not-empty
    return 1
  fi
  if [ -e "$IN_DIR" ] || [ -L "$IN_DIR" ]; then
    DIR_PROBLEM=file
    return 1
  fi
  return 0
}

guide_dir() {
  case "$DIR_PROBLEM" in
    file) guide_dir_is_file ;;
    *) guide_dir_not_empty ;;
  esac
}

guide_dir_not_empty() {
  guide_begin "The folder $IN_DIR already has files in it." \
    "The script puts the copy of your project in a new or empty folder, so that it never mixes it with files that are already there, and it never deletes them."
  guide_step "Choose another folder: start the script again and give it with --dir, followed by a folder that is new or empty, such as --dir ./my-new-project."
  guide_step "Or, if the files in the folder are not needed, move them somewhere else yourself; then come back to this window."
  guide_step "If you are continuing a setup that stopped part way in this folder, start the script again with --resume added."
  guide_end "the script says \"Done. The folder is new or empty.\"" \
    "if the folder looks empty but the script still says it has files, it holds hidden files (their names start with a dot); show hidden files to find them." \
    "it looks inside the folder and counts what is there, hidden files included."
}

guide_dir_is_file() {
  guide_begin "The chosen folder $IN_DIR is a file, not a folder." \
    "The copy of your project needs a folder of its own, and a file already has that name in that place."
  guide_step "Choose another folder: start the script again and give it with --dir, followed by a folder that is new or empty, such as --dir ./my-new-project."
  guide_step "Or rename or move the file yourself; then come back to this window."
  guide_end "the script says \"Done. The folder is new or empty.\"" \
    "if you cannot find the file, look for it in the folder where you started the script." \
    "it looks at what is at that place on this computer: nothing, an empty folder, or something else."
}

preflight_target_dir() {
  step_start "Checking the folder for the copy of your project: $IN_DIR"
  guided_check check_target_dir guide_dir
  step_end "$DIR_DONE"
}

# ---------- preflight: checks on GitHub ----------
# After the checks of this computer, with the same guided loop: gh is
# signed in (which also gives the defaults for the owner and product
# owner name, and the permissions gh has) and this is the current
# published version of the script, both before the first question. After
# the questions, which give the visibility, the owner and the name: gh
# has the permissions the setup needs, and OWNER/NAME does not exist yet.
#
# Every GitHub call goes through api_call (gh api -i), so an error is read
# from the HTTP status and the message in the answer's JSON body, not
# from gh's own error text, which is not stable (spec, "Ease-of-use
# requirements"). Without an answer, gh's exit code tells "not signed
# in" (4, gh's documented code for it) from "GitHub not reached". An
# answer that has no guide stops through api_fail: a plain message, the
# next action, the command to start again, and the raw text below it for
# support (exit 1).

BOOTSTRAPPER=factoincognito/ai-project-bootstrap
SIGN_IN_COMMAND_NEXT="Sign in to GitHub with gh as in step 0 of the README, with the command gh auth login -h github.com -p https -w -s workflow, then start the script again."

API_RC=0 API_STATUS="" API_HEADERS="" API_BODY="" API_MESSAGE="" API_ERR="" API_RAW=""

# api_call <args...>: runs gh api -i <args> and reads its answer: API_RC
# (gh's exit code), API_STATUS (the HTTP status; empty when no answer
# came), API_HEADERS (one "Name: value" per line), API_BODY, API_MESSAGE
# (the "message" of a JSON body, as GitHub sends with an error) and
# API_ERR (gh's own error text). Carriage returns are removed.
api_call() {
  local out err line part=status
  out="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  err="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  API_RC=0
  run_gh api -i "$@" >"$out" 2>"$err" || API_RC=$?
  API_STATUS="" API_HEADERS="" API_BODY="" API_MESSAGE=""
  API_ERR="$(tr -d '\r' <"$err")"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//$CR/}"
    case "$part" in
      status)
        case "$line" in
          HTTP/*)
            API_STATUS="${line#* }"
            API_STATUS="${API_STATUS%% *}"
            part=headers
            ;;
          *) part=body; API_BODY="$line$NL" ;;
        esac
        ;;
      headers)
        if [ -z "$line" ]; then part=body; else API_HEADERS="$API_HEADERS$line$NL"; fi
        ;;
      *) API_BODY="$API_BODY$line$NL" ;;
    esac
  done <"$out"
  rm -f "$out" "$err"
  case "$API_STATUS" in
    [0-9][0-9][0-9]) ;;
    *) API_STATUS="" ;;
  esac
  case "$API_BODY" in
    *"${DQ}message${DQ}"*)
      API_MESSAGE="${API_BODY#*${DQ}message${DQ}}"
      API_MESSAGE="${API_MESSAGE#*:}"
      trim_into "$API_MESSAGE"
      API_MESSAGE="${TRIMMED#"$DQ"}"
      API_MESSAGE="${API_MESSAGE%%"$DQ"*}"
      ;;
  esac
}

# api_raw: API_RAW is the raw text of the last answer, for support: the
# HTTP status and GitHub's message, then gh's own error text.
api_raw() {
  API_RAW=""
  [ -z "$API_STATUS" ] || API_RAW="HTTP $API_STATUS: ${API_MESSAGE:-(no message)}"
  [ -z "$API_ERR" ] || API_RAW="${API_RAW:+$API_RAW$NL}$API_ERR"
  [ -n "$API_RAW" ] || API_RAW="gh stopped with exit code $API_RC and no message."
}

# stop_with_error <what happened> <what to do next> <raw text>: a GitHub
# check that cannot go on: the command to start again, then the error
# (exit 1).
stop_with_error() {
  [ -n "$RESTART_CMD" ] || remember_command
  say "To start again, run this command:"
  say_command "bash $RESTART_CMD"
  fail 1 "$1" "$2" "$3"
}

# api_fail <what the script was doing, as "read your GitHub account">:
# stops with the plain message for the last answer (exit 1).
api_fail() {
  local doing="$1" what="" next=""
  case "$API_STATUS" in
    "")
      if [ "$API_RC" -eq 4 ]; then
        what="gh (the GitHub command-line tool) is not signed in to your GitHub account, so the script could not $doing."
        next="$SIGN_IN_COMMAND_NEXT"
      else
        what="The script could not reach GitHub to $doing."
        next="Check that this computer is connected to the internet, then start the script again."
      fi
      ;;
    401)
      what="GitHub no longer accepts the sign-in that gh has on this computer, so the script could not $doing."
      next="$SIGN_IN_COMMAND_NEXT"
      ;;
    403)
      case "$(lower "$API_MESSAGE")" in
        *"rate limit"*)
          what="GitHub has paused answering your account for a while, because it was asked too often, so the script could not $doing."
          next="Wait an hour, then start the script again."
          ;;
        *)
          what="GitHub refused to let the script $doing."
          next="Check that your GitHub account may do this; for an organisation, one of its owners may have to allow it. Then start the script again."
          ;;
      esac
      ;;
    404)
      what="GitHub did not find what the script needed to $doing."
      next="Check the names you gave, then start the script again."
      ;;
    5[0-9][0-9])
      what="GitHub had a problem of its own, so the script could not $doing."
      next="Wait a few minutes, then start the script again; https://www.githubstatus.com shows whether GitHub has a known problem."
      ;;
  esac
  api_raw
  stop_with_error "$what" "$next" "$API_RAW"
}

# ---- signed in ----

# check_github_account: gh api -i user works. Sets GH_LOGIN and
# GH_PROFILE_NAME (empty when the profile has none), and GH_SCOPES (the
# X-OAuth-Scopes header without spaces, as repo,workflow) with
# GH_SCOPES_SEEN set when that header came (a fine-grained token sends
# none). ACCOUNT_PROBLEM: signed-out (gh's exit 4), expired (401),
# offline (no answer) or other.
GH_LOGIN=""
GH_PROFILE_NAME=""
GH_SCOPES=""
GH_SCOPES_SEEN=""
ACCOUNT_PROBLEM=""
check_github_account() {
  local rest h
  ACCOUNT_PROBLEM=""
  api_call user --jq '.login, (.name // "")'
  if [ "$API_RC" -ne 0 ] || [ "$API_STATUS" != 200 ]; then
    case "$API_STATUS" in
      "") if [ "$API_RC" -eq 4 ]; then ACCOUNT_PROBLEM=signed-out; else ACCOUNT_PROBLEM=offline; fi ;;
      401) ACCOUNT_PROBLEM=expired ;;
      *) ACCOUNT_PROBLEM=other ;;
    esac
    return 1
  fi
  GH_LOGIN="${API_BODY%%"$NL"*}"
  rest="${API_BODY#*"$NL"}"
  GH_PROFILE_NAME="${rest%%"$NL"*}"
  if [ -z "$GH_LOGIN" ]; then
    ACCOUNT_PROBLEM=other
    return 1
  fi
  GH_SCOPES=""
  GH_SCOPES_SEEN=""
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    if [ "$(lower "${h%%:*}")" = x-oauth-scopes ]; then
      GH_SCOPES_SEEN=1
      GH_SCOPES="${h#*:}"
      GH_SCOPES="${GH_SCOPES// /}"
    fi
  done <<<"$API_HEADERS"
}

guide_github_account() {
  case "$ACCOUNT_PROBLEM" in
    other) api_fail "read your GitHub account" ;;
    offline) guide_github_offline; return 0 ;;
    expired)
      guide_begin "GitHub no longer accepts the sign-in that gh (the GitHub command-line tool) has on this computer." \
        "The script works on GitHub as you, through gh, and GitHub no longer accepts that sign-in: it may have run out or been withdrawn."
      ;;
    *)
      guide_begin "gh (the GitHub command-line tool) is not signed in to your GitHub account." \
        "The script works on GitHub as you, through gh, so gh has to be signed in to your account."
      ;;
  esac
  guide_step "Open a second terminal window and run this command there; it is the sign-in command from step 0 of the README:"
  say_command "gh auth login -h github.com -p https -w -s workflow"
  guide_step "When gh asks \"Authenticate Git with your GitHub credentials?\", answer Yes."
  guide_step "gh shows a one-time code (eight letters and digits, such as ABCD-1234) and asks you to press Enter: copy the code, then press Enter. Your browser opens GitHub's device page: paste the code, click Continue, then approve with the green Authorize button."
  guide_step "Come back to this window."
  guide_end "gh says \"Logged in as\" with your account name, and the script says \"Done. gh is signed in to GitHub as\" with your account name." \
    "if the browser does not open, open https://github.com/login/device yourself and type the code there." \
    "it asks GitHub which account gh is signed in to (gh api user), which works only when gh is signed in."
  api_raw
  guide_details "$API_RAW"
}

guide_github_offline() {
  guide_begin "The script could not reach GitHub." \
    "The script checks your GitHub account and creates your project there, so this computer has to reach GitHub over the internet."
  guide_step "Check that this computer is connected to the internet: open https://github.com in your browser."
  guide_step "If GitHub opens in the browser but the script still cannot reach it, open https://www.githubstatus.com to see whether GitHub has a known problem, and wait until it is solved."
  guide_step "Come back to this window."
  guide_end "the script says \"Done. gh is signed in to GitHub as\" with your account name." \
    "if you are on an office or school network, ask the person who manages it whether it lets gh reach GitHub." \
    "it asks GitHub which account gh is signed in to, which needs a connection to GitHub."
  api_raw
  guide_details "$API_RAW"
}

preflight_github_account() {
  step_start "Checking that gh is signed in to GitHub"
  guided_check check_github_account guide_github_account
  step_end "gh is signed in to GitHub as $GH_LOGIN."
}

# need_github_account: the account, read once. cmd_setup reads it before
# the questions; this is for an input default asked for without it.
need_github_account() {
  [ -n "$GH_LOGIN" ] || preflight_github_account
}

# ---- the current version of this script ----

# read_published_version <text of CHANGELOG.md>: PUBLISHED_VERSION is the
# version the bootstrapper's CHANGELOG.md was stamped with: the text
# before ", built from" (its "Project created" entry reads "<version>,
# built from <template>@<commit>."). Returns 1 when there is none. The
# unstamped stub in the template holds the same placeholder as the
# unstamped script, so the two match there; the build stamps both.
PUBLISHED_VERSION=""
read_published_version() {
  local line
  PUBLISHED_VERSION=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//$CR/}"
    case "$line" in
      *", built from"*)
        trim_into "${line%%, built from*}"
        PUBLISHED_VERSION="$TRIMMED"
        [ -z "$PUBLISHED_VERSION" ] || return 0
        ;;
    esac
  done <<<"$1"
  return 1
}

# check_published_version: the bootstrapper's CHANGELOG.md on GitHub (its
# default branch, which "gh repo create --template" copies) names the
# version this script was stamped with. VERSION_PROBLEM: old, unreadable
# (no version in it) or api.
VERSION_PROBLEM=""
check_published_version() {
  VERSION_PROBLEM=""
  api_call -H "Accept: application/vnd.github.raw+json" "repos/$BOOTSTRAPPER/contents/CHANGELOG.md"
  if [ "$API_RC" -ne 0 ] || [ "$API_STATUS" != 200 ]; then
    VERSION_PROBLEM=api
    return 1
  fi
  if ! read_published_version "$API_BODY"; then
    VERSION_PROBLEM=unreadable
    return 1
  fi
  [ "$PUBLISHED_VERSION" = "$SCRIPT_VERSION" ] && return 0
  VERSION_PROBLEM=old
  return 1
}

guide_published_version() {
  case "$VERSION_PROBLEM" in
    old) guide_old_script ;;
    unreadable)
      stop_with_error "The bootstrapper's CHANGELOG.md file on GitHub does not say which version is current, so the script cannot check that it is the current version." \
        "Start the script again later. If the same thing happens, report it to the bootstrapper's maintainers and show them the details below." \
        "No line with \", built from\" in $BOOTSTRAPPER CHANGELOG.md. Its first lines:$NL$(sed -n 1,5p <<<"$API_BODY")"
      ;;
    *) api_fail "read the current version of the bootstrapper" ;;
  esac
}

# guide_old_script: a re-check in this run cannot change the script that
# runs, so it stops (NO_RECHECK), and the command to start again runs the
# downloaded copy in this folder with the same options.
guide_old_script() {
  guide_begin "This copy of the script is not the current version: it is $SCRIPT_VERSION, and the current one is $PUBLISHED_VERSION." \
    "GitHub always copies the current files of the bootstrapper into a new project, so only the current version of the script fits them."
  guide_step "Download the current version into this folder with this command; it replaces the file bootstrap-project.sh here:"
  say_command 'gh api repos/factoincognito/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh'
  guide_step "Start the new copy with the command shown below; it asks again for any answer you did not give as an option."
  guide_end "the new copy says \"Done. This is the current version of the script\" and goes on." \
    "if the download command says that gh is not signed in, sign in as in step 0 of the README, then download again." \
    "it reads the version written in the bootstrapper's CHANGELOG.md file on GitHub and compares it with its own. It cannot check again in this run, so it stops here."
  NO_RECHECK=1
  RESTART_CMD="bootstrap-project.sh$RESTART_ARGS"
}

preflight_published_version() {
  step_start "Checking that this is the current version of the script"
  guided_check check_published_version guide_published_version
  step_end "This is the current version of the script ($SCRIPT_VERSION)."
}

# ---- the permissions gh has ----

# check_github_permissions: gh has what the setup needs (from a fresh
# read of the account, so a refresh shows at once): workflow, because the
# setup changes the file that runs the project's checks, and repo, or
# public_repo for a public project. PERM_MISSING lists what is missing.
# Without the X-OAuth-Scopes header (a fine-grained token) the
# permissions cannot be seen: it passes, and the step warns.
PERM_PROBLEM=""
PERM_MISSING=""
check_github_permissions() {
  PERM_PROBLEM=""
  PERM_MISSING=""
  if ! check_github_account; then
    PERM_PROBLEM=account
    return 1
  fi
  [ -n "$GH_SCOPES_SEEN" ] || return 0
  case ",$GH_SCOPES," in
    *,repo,*) ;;
    *,public_repo,*) [ "$IN_VISIBILITY" = public ] || PERM_MISSING=repo ;;
    *) if [ "$IN_VISIBILITY" = public ]; then PERM_MISSING=public_repo; else PERM_MISSING=repo; fi ;;
  esac
  case ",$GH_SCOPES," in
    *,workflow,*) ;;
    *) PERM_MISSING="${PERM_MISSING:+$PERM_MISSING }workflow" ;;
  esac
  [ -n "$PERM_MISSING" ] || return 0
  PERM_PROBLEM=missing
  return 1
}

guide_github_permissions() {
  local p list=""
  if [ "$PERM_PROBLEM" = account ]; then
    guide_github_account
    return 0
  fi
  for p in $PERM_MISSING; do
    case "$p" in
      workflow) p="workflow (to add and change the files that run your project's checks)" ;;
      repo) p="repo (to create your project and change its files)" ;;
      public_repo) p="public_repo (to create a public project and change its files)" ;;
    esac
    list="${list:+$list; }$p"
  done
  guide_begin "gh is signed in, but it does not have every permission on GitHub that the setup needs." \
    "GitHub gives gh each permission separately, and the setup needs these, which gh does not have yet: $list."
  if [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
    # gh auth refresh cannot change a token from the environment, and a
    # new one is read only when the script starts again.
    guide_step "gh signs in with a key (a token) set in GH_TOKEN or GITHUB_TOKEN on this computer, so gh cannot ask GitHub for more permissions itself."
    guide_step "Open https://github.com/settings/tokens in your browser, make a new token (classic), and tick the boxes named after the permissions listed above."
    guide_step "Put the new token in GH_TOKEN (or GITHUB_TOKEN) in place of the old one, open a new terminal window, and start the script again there with the command shown below."
    guide_end "the script says \"Done. gh has the permissions on GitHub that the setup needs.\"" \
      "if you did not set GH_TOKEN or GITHUB_TOKEN yourself, ask the person who set up this computer." \
      "it asks GitHub which permissions gh has (gh api -i user). It cannot check again in this run, because the key is read when the script starts, so it stops here."
    NO_RECHECK=1
    return 0
  fi
  guide_step "Run this command; it asks GitHub to give gh the missing permissions:"
  case "$PERM_MISSING" in
    workflow) offered gh-refresh-workflow show; OFFER=gh-refresh-workflow ;;
    public_repo*) offered gh-refresh-public show; OFFER=gh-refresh-public ;;
    *) offered gh-refresh-repo show; OFFER=gh-refresh-repo ;;
  esac
  guide_step "gh shows a one-time code (eight letters and digits, such as ABCD-1234) and asks you to press Enter: copy the code, then press Enter."
  guide_step "Your browser opens https://github.com/login/device: paste the code, click Continue, then approve with the green Authorize button."
  guide_step "Come back to this window."
  guide_end "gh says that it is done, and the script says \"Done. gh has the permissions on GitHub that the setup needs.\"" \
    "if the browser does not open, open https://github.com/login/device yourself and type the code there." \
    "it asks GitHub which permissions gh has (gh api -i user)."
}

preflight_github_permissions() {
  step_start "Checking that gh has the permissions on GitHub that the setup needs"
  guided_check check_github_permissions guide_github_permissions
  if [ -n "$GH_SCOPES_SEEN" ]; then
    step_end "gh has the permissions on GitHub that the setup needs."
    return 0
  fi
  say "GitHub does not say which permissions this sign-in has, as with a fine-grained token (a key made on GitHub with chosen permissions)."
  say "The setup needs these permissions, each set to \"Read and write\": Administration, Contents, Workflows and Pull requests; and your account must be allowed to create repositories (new projects on GitHub)."
  say "If one of them is missing, a later step stops and says so."
  step_end "Carrying on without checking the permissions."
}

# ---- the project name is free ----

# check_project_absent: GitHub has no project OWNER/NAME (404). With
# --resume one that exists passes too (only the allowance: continuing it
# comes in a later part). PROJECT_PROBLEM: exists, or api.
PROJECT_PROBLEM=""
PROJECT_DONE=""
check_project_absent() {
  PROJECT_PROBLEM=""
  api_call "repos/$IN_OWNER/$IN_NAME"
  case "$API_STATUS" in
    404)
      PROJECT_DONE="No project named $IN_OWNER/$IN_NAME exists on GitHub yet."
      return 0
      ;;
    200)
      if [ -n "$OPT_RESUME" ]; then
        PROJECT_DONE="The project $IN_OWNER/$IN_NAME exists on GitHub, which --resume allows."
        return 0
      fi
      PROJECT_PROBLEM=exists
      ;;
    *) PROJECT_PROBLEM=api ;;
  esac
  return 1
}

guide_project() {
  case "$PROJECT_PROBLEM" in
    exists) guide_project_exists ;;
    *) api_fail "check whether the name $IN_OWNER/$IN_NAME is free on GitHub" ;;
  esac
}

guide_project_exists() {
  guide_begin "A project named $IN_OWNER/$IN_NAME already exists on GitHub." \
    "The setup creates a new project, and it never changes or deletes one that is already there."
  guide_step "To see it, open https://github.com/$IN_OWNER/$IN_NAME in your browser."
  guide_step "Choose another name: start the script again and give it with --name, such as --name $IN_NAME-2."
  guide_step "If you are continuing a setup of this project that stopped part way, start the script again with --resume added."
  guide_step "Or, if the project on GitHub is not needed, rename or delete it there yourself (in its Settings); then come back to this window."
  guide_end "the script says \"Done. No project named $IN_OWNER/$IN_NAME exists on GitHub yet.\"" \
    "if the page shows a project with another name, the project was renamed and GitHub still sends the old name to it; choose another name." \
    "it asks GitHub for a project at that address, and GitHub answers that there is none."
}

preflight_project_absent() {
  step_start "Checking that the name $IN_OWNER/$IN_NAME is free on GitHub"
  guided_check check_project_absent guide_project
  step_end "$PROJECT_DONE"
}

# cmd_setup <options...>: the setup. Built so far: the checks of this
# computer and on GitHub, and the inputs. The options are checked first,
# then the checks that need no answer (the tools, the GitHub sign-in and
# the current version), so that nothing is asked in vain; the npm,
# folder, permission and name checks need answers, so they follow the
# questions.
cmd_setup() {
  parse_args "$@"
  if [ -n "$SCRIPT_PIPED" ] && [ -z "$OPT_NON_INTERACTIVE" ]; then
    fail 2 "The script was piped into bash, so it cannot ask its questions: they would read the script itself." \
      "Run the command from the README, which saves the script to a file first and then runs that file."
  fi
  remember_command "$@"
  detect_os
  check_options
  preflight_tools
  preflight_github_account
  preflight_published_version
  collect_inputs
  preflight_npm
  preflight_target_dir
  preflight_github_permissions
  preflight_project_absent
  fail 1 "This version of the script stops after its checks of this computer and of GitHub: setting up the project is not built yet. Nothing was created." \
    "Use a released version of the bootstrapper to set up a project."
}

# ---------- main ----------

main() {
  case "${1:-}" in
    layout-pack) shift; cmd_layout_pack "$@" ;;
    *) cmd_setup "$@" ;;
  esac
}

# Run unless sourced. Piped into bash there is no BASH_SOURCE: run too,
# and remember it (the questions cannot read stdin then).
SCRIPT_PIPED=""
if [ -z "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_PIPED=1
  main "$@"
elif [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
