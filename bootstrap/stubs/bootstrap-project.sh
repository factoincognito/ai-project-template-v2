#!/usr/bin/env bash
# bootstrap-project.sh: sets up a new project from this bootstrapper.
# Spec: "Turn-key bootstrap script" in
# https://github.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG.md
#
# Built so far: the inputs (options, questions, checks and defaults) and
# the layout-pack subcommand. After the questions the script stops: the
# setup steps come in later parts.
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
# that is missing or cannot be used.
# Runs on bash 3.2 (macOS /bin/bash): no associative arrays, no mapfile,
# no ${var,,}.
#
# Test hooks (environment variables the tests set; users leave them unset):
#   BOOTSTRAP_GH   the gh command to run (default: gh on the PATH).
#   BOOTSTRAP_RUN  a command that replaces the runner of the install and
#                  login commands the script offers. It gets the command
#                  as one argument, so the tests never install anything.
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
  local what="${1:-}" next="${2:-}" raw="${3:-}" line
  [ -n "$what" ] || what="Something unexpected happened."
  [ -n "$next" ] || next="Run the script again. If the same thing happens, ask for help and show the details below."
  {
    printf 'What happened: %s\n' "$what"
    printf 'What to do next: %s\n' "$next"
    if [ -n "$raw" ]; then
      printf 'Details for support (you can ignore these):\n'
      printf '%s\n' "$raw" | tr -d '\r' | while IFS= read -r line; do
        printf '    %s\n' "$line"
      done
    fi
  } >&2
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
IN_DIR="" IN_CI_TIMEOUT="" IN_SLUG=""
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
        --copyright-holder | --dir | --ci-timeout)
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

check_dir() {
  trim_into "$1"
  case "$TRIMMED" in
    "") PROBLEM="It cannot be empty."; return 1 ;;
    *[[:cntrl:]]*) PROBLEM="It must be one line, with no tabs or other invisible characters."; return 1 ;;
  esac
  CHECKED="$TRIMMED"
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

# read_github_user: GH_LOGIN and GH_PROFILE_NAME (empty when the profile
# has none) of the signed-in GitHub account, read once.
GH_LOGIN=""
GH_PROFILE_NAME=""
read_github_user() {
  [ -z "$GH_LOGIN" ] || return 0
  local out="" raw err_file
  err_file="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  if ! out="$(run_gh api user --jq '.login, (.name // "")' 2>"$err_file")"; then
    raw="$(cat "$err_file")"
    rm -f "$err_file"
    fail 1 "Could not read your GitHub account, which gives the default owner and product owner name." \
      "Check that you are signed in to GitHub (step 0 in the README), then run the script again. Or give --owner and --po-name yourself." \
      "$raw"
  fi
  rm -f "$err_file"
  out="${out//$CR/}"
  GH_LOGIN="${out%%"$NL"*}"
  case "$out" in
    *"$NL"*) GH_PROFILE_NAME="${out#*"$NL"}"; GH_PROFILE_NAME="${GH_PROFILE_NAME%%"$NL"*}" ;;
  esac
  [ -n "$GH_LOGIN" ] || fail 1 "Could not read your GitHub account, which gives the default owner and product owner name." \
    "Check that you are signed in to GitHub (step 0 in the README), then run the script again. Or give --owner and --po-name yourself." \
    "$out"
}

collect_inputs() {
  # The options given are checked first, all of them, so one run lists
  # every problem.
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
  fi
  stop_if_problems

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
    read_github_user
    answer --owner check_owner "$GH_LOGIN" \
      "The GitHub account or organisation that will own the project; press Enter to use your own account." \
      "Owner" || true
    IN_OWNER="$CHECKED"
  fi
  if [ -z "$IN_PO_NAME" ]; then
    read_github_user
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
  [ -n "$IN_CI_TIMEOUT" ] || IN_CI_TIMEOUT=20
  stop_if_problems
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

# cmd_setup <options...>: the setup. Built so far: the inputs.
cmd_setup() {
  parse_args "$@"
  if [ -n "$SCRIPT_PIPED" ] && [ -z "$OPT_NON_INTERACTIVE" ]; then
    fail 2 "The script was piped into bash, so it cannot ask its questions: they would read the script itself." \
      "Run the command from the README, which saves the script to a file first and then runs that file."
  fi
  collect_inputs
  fail 1 "This version of the script stops after the questions: setting up the project is not built yet. Nothing was created." \
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
