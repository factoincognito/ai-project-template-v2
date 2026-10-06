#!/usr/bin/env bash
# bootstrap-project.sh: sets up a new project from this bootstrapper.
# Spec: "Turn-key bootstrap script" in
# https://github.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG.md
#
# Built so far: the inputs (options, questions, checks and defaults), the
# guided checks of this computer (bash, git, gh, npm, the git name and
# email, the target folder), the guided checks on GitHub (signed in, the
# current version of this script, the permissions gh has, the project
# name still free), the plan and its "Proceed?" question, creating the
# project on GitHub and protecting its main version, the copy of the
# project on this computer (with the git name and email, the line of work
# bootstrap-setup, the language pack laid out, the tidy-up and the
# placeholders filled in), and the layout-pack subcommand. After the
# placeholders the script stops: the later setup steps (nothing is saved
# or sent yet) come in later parts.
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
# Exit codes: 0 done (or a --dry-run that passed its checks), 1 failed or
# stopped, 2 usage error, unknown pack, or an input that is missing or
# cannot be used, 3 a check of this computer or on GitHub did not pass, or
# a step on GitHub was refused: its steps were shown, with the command to
# start again (or, once the project exists, to continue with --resume).
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
#   BOOTSTRAP_SLEEP  the command that waits between two checks of GitHub
#                  (default: sleep). It gets the seconds as its argument.
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
SETUP_BROKEN_NEXT="The project was made from the current bootstrapper, so downloading the script again does not help. Report it to the bootstrapper's maintainers and show them the details below."
ASK_NO_DEFAULT="There is no default, because only you can choose it."
ASK_RETRY="Please try again."
ASK_NEEDED="An answer is needed here."
OPTIONS_NEXT="To see every option, run the script with --help."
START_AGAIN_INTRO="To start again, run this command:"
CONTINUE_INTRO="To continue the setup, run this command:"

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
# out, except the deploy files with --with-deploy. Every other pack file
# must be in the table, so a new pack file cannot be silently left out.
#
# layout_into <pack> <packs dir> <target> <strict|overlay> [yes]: lays
# out the pack from <packs dir>/<pack> into <target>. LP_KEPT lists the
# pack's files that were not laid out (the setup keeps them).
#   strict: the layout-pack subcommand; the target must be empty or
#     absent.
#   overlay: the setup (spec step 6), over the copy of the project: the
#     pack's ci.yml replaces the stub, the pack's gitignore lines are added
#     to .gitignore when it lacks them, and any other target that is there
#     already is an error, found before anything is written. A fifth
#     argument "yes" (--with-deploy, web) lays out the deploy files too.
LP_MODE=""
LP_KEPT=""
layout_into() {
  local pack="$1" packs_dir="$2" out="$3" deploy="${5:-}"
  local common typescript table not_laid_out src from to f covered skip broken="$LP_BROKEN_NEXT"
  LP_MODE="$4"
  # In the setup the packs come from the project GitHub made (#152 review,
  # finding 2): downloading the script again would not change them.
  [ "$LP_MODE" != overlay ] || broken="$SETUP_BROKEN_NEXT"

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
      if [ "$deploy" = yes ]; then
        table="$table
deploy.yml .github/workflows/deploy.yml
wrangler.jsonc wrangler.jsonc"
        not_laid_out="code-standards.md"
      fi
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
  LP_KEPT="$not_laid_out"

  src="$packs_dir/$pack"
  if [ ! -d "$src" ]; then
    if [ "$LP_MODE" = strict ]; then
      lp_fail "pack folder not found: $src" \
        "Check that the languages folder is next to this script, or set PACKS_DIR to the folder that holds the packs."
    fi
    lp_fail "pack folder not found: $src" "$broken" "Not a folder: $src"
  fi

  if [ "$LP_MODE" = strict ] && [ -e "$out" ] && [ -n "$(ls -A "$out")" ]; then
    lp_fail "target dir is not empty: $out" "Choose a folder that is empty or does not exist yet."
  fi

  # Every table source must exist.
  while read -r from _; do
    if [ "${from%/}" != "$from" ]; then
      [ -d "$src/$from" ] || lp_fail "missing from the pack: $from" "$broken" "Not in $src: $from"
    else
      [ -f "$src/$from" ] || lp_fail "missing from the pack: $from" "$broken" "Not in $src: $from"
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
    [ -n "$covered" ] || lp_fail "not in the layout table: $f" "$broken" "In $src but not in the table: $f"
  done < <(cd "$src" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)

  # Overlay: the targets other than ci.yml and .gitignore must not be
  # there yet. All are checked before the first one is written.
  if [ "$LP_MODE" = overlay ]; then
    while read -r from to; do
      case "$to" in .github/workflows/ci.yml | .gitignore) continue ;; esac
      if [ -e "$out/$to" ] || [ -L "$out/$to" ]; then
        lp_fail "The copy of the project on this computer already has $to, which the $pack pack would add." \
          "This version of the bootstrapper cannot set up a $pack project, because its own files and the pack's overlap. Report it to the bootstrapper's maintainers and show them the details below." \
          "Already there: $out/$to"
      fi
    done <<<"$table"
  fi

  mkdir -p "$out"
  while read -r from to; do
    if [ "${from%/}" != "$from" ]; then
      mkdir -p "$out/$to"
      cp -R "$src/$from." "$out/$to"
    elif [ "$LP_MODE" = overlay ] && [ "$to" = .gitignore ]; then
      add_missing_lines "$src/$from" "$out/$to"
    else
      mkdir -p "$(dirname "$out/$to")"
      cp "$src/$from" "$out/$to"
    fi
  done <<<"$table"
}

# as_operand <path>: OPERAND is the path as a file operand for awk: awk
# reads an operand of the form name=value as a variable setting, so a
# path that does not start with / gets ./ in front (#152 review, finding
# 1). The other helpers that run awk on a file read it from stdin.
as_operand() {
  case "$1" in
    /*) OPERAND="$1" ;;
    *) OPERAND="./$1" ;;
  esac
}

# lp_fail <what happened> <what to do next> [raw text]: a layout error.
# The subcommand names itself and exits 1; in the setup the copy and the
# project exist, so it shows the command to continue (stop_with_error).
lp_fail() {
  [ "$LP_MODE" != overlay ] || stop_with_error "$1" "$2" "${3:-}"
  fail 1 "layout-pack: $1" "$2"
}

# add_missing_lines <from> <to>: adds to the file <to> each line of <from>
# that <to> lacks, in order, skipping empty lines and lines already
# added; <to>'s own lines stay as they are, and its last line is ended
# first. Carriage returns do not count when lines are compared.
add_missing_lines() {
  local tmp from to
  tmp="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  [ -f "$2" ] || : >"$2"
  as_operand "$1"; from="$OPERAND"
  as_operand "$2"; to="$OPERAND"
  awk 'FILENAME == ARGV[1] { print; sub(/\r$/, ""); have[$0] = 1; next }
    { sub(/\r$/, "") }
    $0 != "" && !($0 in have) { have[$0] = 1; print }' "$to" "$from" >"$tmp"
  cat "$tmp" >"$2"
  rm -f "$tmp"
}

cmd_layout_pack() {
  [ "$#" -eq 2 ] || usage
  local here packs_dir
  # CDPATH is cleared: a user's CDPATH could send cd to another folder of
  # the same name, or make it print the folder into $here.
  here="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  packs_dir="${PACKS_DIR:-$here/languages}"
  as_operand "$2"
  layout_into "$1" "$packs_dir" "$OPERAND" strict
  say "Laid out the $1 pack in $2"
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
  # GitHub's limit ("Creating a new repository" doc: at most 100
  # characters) is stricter than npm's 214 for the slug, which has the
  # same length as the name.
  if [ "${#TRIMMED}" -gt 100 ]; then
    PROBLEM="It is too long: GitHub allows at most 100 characters."
    return 1
  fi
  slug="$(slug_of "$TRIMMED")"
  if [ "$slug" = node_modules ]; then
    PROBLEM="That name is kept for the project's own tools; choose another one."
    return 1
  fi
  CHECKED="$TRIMMED"
}

# check_owner: an account of an Enterprise Managed User has an _ before
# its enterprise's short code, as in mona-cat_octo (GitHub's "Username
# considerations for external authentication" doc), so _ is allowed.
check_owner() {
  trim_into "$1"
  case "$TRIMMED" in
    "") PROBLEM="It cannot be empty."; return 1 ;;
    [!$ALNUM]* | *[!${ALNUM}_-]*)
      PROBLEM="Use the name of a GitHub account or organisation: letters, digits, dashes (-) and underscores (_), starting with a letter or a digit."
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
  # A relative folder gets ./ in front (#152 review, finding 1): awk reads
  # an operand such as my=app/README.md as a variable setting, not a file,
  # and gh, git, ls and rm read one starting with - as an option. A
  # Windows drive path (C:/... or C:\...) is not relative.
  case "$TRIMMED" in
    /* | ./* | ../* | . | .. | [A-Za-z]:/* | [A-Za-z]:\\*) CHECKED="$TRIMMED" ;;
    *) CHECKED="./$TRIMMED" ;;
  esac
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
# Once the project exists on GitHub (CREATED_NOTE set), the command shown
# continues the setup with --resume, and the stop says what exists.
stop_at_guide() {
  [ -n "$RESTART_CMD" ] || remember_command
  if [ -n "$CREATED_NOTE" ]; then
    say "$CONTINUE_INTRO"
    say_command "bash $RESTART_CMD"
    fail 3 "$GUIDE_TITLE The script stopped here. $CREATED_NOTE" \
      "Follow the steps above, then run the command shown to continue the setup."
  fi
  say "$START_AGAIN_INTRO"
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
# the project from the run that stopped; whether it is this project's
# own copy is checked when --resume continues). The folder that holds
# IN_DIR must exist; the script must be able to write in IN_DIR (when it
# is there) or in that folder (when not); and that folder must not be
# inside a git project, so the copy is never a project within another
# (#148 review, finding 7). DIR_PROBLEM: file, not-empty, no-parent,
# not-writable (DIR_UNWRITABLE: the folder) or in-git (DIR_OUTER: where
# that project starts, when git says).
DIR_PROBLEM=""
DIR_DONE=""
DIR_UNWRITABLE=""
DIR_OUTER=""
check_target_dir() {
  local entries="" parent
  DIR_DONE="The folder is new or empty."
  if [ -d "$IN_DIR" ]; then
    entries="$(ls -A "$IN_DIR" 2>/dev/null)" || entries=unreadable
    if [ -n "$entries" ]; then
      if [ -z "$OPT_RESUME" ]; then
        DIR_PROBLEM=not-empty
        return 1
      fi
      DIR_DONE="The folder has files in it, which --resume allows."
    fi
  elif [ -e "$IN_DIR" ] || [ -L "$IN_DIR" ]; then
    DIR_PROBLEM=file
    return 1
  fi
  parent="$(dirname -- "$IN_DIR")"
  if [ ! -d "$parent" ]; then
    DIR_PROBLEM=no-parent
    return 1
  fi
  if [ -d "$IN_DIR" ]; then DIR_UNWRITABLE="$IN_DIR"; else DIR_UNWRITABLE="$parent"; fi
  if [ ! -w "$DIR_UNWRITABLE" ]; then
    DIR_PROBLEM=not-writable
    return 1
  fi
  if git -C "$parent" rev-parse --git-dir >/dev/null 2>&1; then
    DIR_OUTER="$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null)" || DIR_OUTER=""
    DIR_OUTER="${DIR_OUTER//$CR/}"
    DIR_PROBLEM=in-git
    return 1
  fi
  return 0
}

guide_dir() {
  case "$DIR_PROBLEM" in
    file) guide_dir_is_file ;;
    no-parent) guide_dir_no_parent ;;
    not-writable) guide_dir_not_writable ;;
    in-git) guide_dir_in_git ;;
    *) guide_dir_not_empty ;;
  esac
}

guide_dir_no_parent() {
  local parent
  parent="$(dirname -- "$IN_DIR")"
  guide_begin "The folder $parent, which would hold the folder $IN_DIR, does not exist." \
    "The script makes the folder for the copy of your project only inside a folder that is already there, so that a typing mistake in the path does not make folders in the wrong place."
  guide_step "Check the path for a typing mistake. To use another folder, start the script again and give it with --dir, followed by the folder, such as --dir ./my-new-project."
  guide_step "Or, if the path is right, make the folder $parent yourself (for example in your file manager); then come back to this window."
  guide_end "the script says \"Done. The folder is new or empty.\"" \
    "if you made the folder and the script still does not find it, check that its name and place match the path above letter for letter." \
    "it looks whether the folder $parent is there."
}

guide_dir_not_writable() {
  guide_begin "The script may not write in the folder $DIR_UNWRITABLE." \
    "The copy of your project is written there, and this computer does not let your account add files to that folder."
  guide_step "Choose a folder in your own home folder instead: start the script again and give it with --dir, such as --dir ~/my-new-project."
  guide_step "Or ask the person who manages this computer to let your account write in $DIR_UNWRITABLE; then come back to this window."
  guide_end "the script says \"Done. The folder is new or empty.\"" \
    "try to make a new file in that folder yourself; if this computer refuses that too, choose another folder." \
    "it asks this computer whether your account may write in that folder."
}

guide_dir_in_git() {
  guide_begin "The folder $IN_DIR is inside another project that git keeps track of${DIR_OUTER:+ (the one in $DIR_OUTER)}." \
    "The copy of your project keeps its own history with git. Inside another git project the two would get mixed up: the other project would see your project's files as its own."
  guide_step "Choose a folder outside that project: start the script again and give it with --dir, such as --dir ~/my-new-project."
  guide_end "the script says \"Done. The folder is new or empty.\"" \
    "if you do not know where that other project starts, look for a hidden folder named .git in the folders above $IN_DIR; that project starts in the folder that holds it." \
    "it asks git whether the folder that would hold $IN_DIR belongs to a git project."
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
SIGN_IN_CONTINUE_NEXT="Sign in to GitHub with gh as in step 0 of the README, with the command gh auth login -h github.com -p https -w -s workflow, then continue the setup with the command shown above."

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
# check or step that cannot go on: the command to start again (or, once
# the project exists, to continue the setup), then the error (exit 1).
stop_with_error() {
  [ -n "$RESTART_CMD" ] || remember_command
  if [ -n "$CREATED_NOTE" ]; then say "$CONTINUE_INTRO"; else say "$START_AGAIN_INTRO"; fi
  say_command "bash $RESTART_CMD"
  fail 1 "${1:-Something unexpected happened.}${CREATED_NOTE:+ $CREATED_NOTE}" "$2" "$3"
}

# api_fail <what the script was doing, as "read your GitHub account">
# [next action for a 404]: stops with the plain message for the last
# answer (exit 1). What a 404 means depends on the call, so each call
# that can get one gives its own next action (#149 review, finding 3).
# A status with no arm of its own is "Something unexpected happened"
# with what the script was doing (#150 review, finding 1). Once the
# project exists, the next action is to continue the setup with the
# command shown, never to start again (#150 review, finding 2).
api_fail() {
  local doing="$1" not_found_next="${2:-}" what="" next="" again="start the script again" sign_in="$SIGN_IN_COMMAND_NEXT"
  if [ -n "$CREATED_NOTE" ]; then
    again="continue the setup with the command shown above"
    sign_in="$SIGN_IN_CONTINUE_NEXT"
  fi
  case "$API_STATUS" in
    "")
      if [ "$API_RC" -eq 4 ]; then
        what="gh (the GitHub command-line tool) is not signed in to your GitHub account, so the script could not $doing."
        next="$sign_in"
      else
        what="The script could not reach GitHub to $doing."
        next="Check that this computer is connected to the internet, then $again."
      fi
      ;;
    401)
      what="GitHub no longer accepts the sign-in that gh has on this computer, so the script could not $doing."
      next="$sign_in"
      ;;
    403 | 429)
      # 429 is GitHub's answer for its secondary rate limit.
      case "$API_STATUS $(lower "$API_MESSAGE")" in
        429* | *"rate limit"*)
          what="GitHub has paused answering your account for a while, because it was asked too often, so the script could not $doing."
          next="Wait an hour, then $again."
          ;;
        *)
          what="GitHub refused to let the script $doing."
          next="Check that your GitHub account may do this; for an organisation, one of its owners may have to allow it. Then $again."
          ;;
      esac
      ;;
    404)
      what="GitHub did not find what the script needed to $doing."
      next="${not_found_next:-Wait a few minutes, then $again. If the same thing happens, ask for help and show the details below.}"
      ;;
    5[0-9][0-9])
      what="GitHub had a problem of its own, so the script could not $doing."
      next="Wait a few minutes, then $again; https://www.githubstatus.com shows whether GitHub has a known problem."
      ;;
    *)
      what="Something unexpected happened, so the script could not $doing."
      next="Wait a few minutes, then $again. If the same thing happens, ask for help and show the details below."
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
    *)
      api_fail "read the current version of the bootstrapper" \
        "Download the script again with the command from the README, then start it. If the same thing happens, report it to the bootstrapper's maintainers and show them the details below."
      ;;
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

# ---------- the plan, create and protect ----------
# The end of spec step 1 (the plan, and "Proceed?" unless --yes; a
# --dry-run stops after the plan), then step 2 (create the project from
# the bootstrapper and wait until GitHub has copied its files) and step 3
# (protect main straight away, then the merge settings). Nothing is
# created before the "Proceed?" answer. Once the project exists, every
# stop shows the command to continue with --resume (continue_after_create).

# The spec's protection body for step 3, field for field. Step 16 later
# adds the required check with a second PUT.
PROTECT_BODY='{"required_status_checks":null,"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":0},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}'
# Waiting for the template's files: up to POLL_TRIES waits of POLL_DELAY
# seconds (60 s in all), retrying only on 404.
POLL_TRIES=30
POLL_DELAY=2
GIVEN_NAME=""
GIVEN_OWNER=""
CREATED_NOTE=""
CREATE_ERR=""
PROTECT_PROBLEM=""

# pause_for <seconds>: waits, or hands the wait to $BOOTSTRAP_SLEEP.
pause_for() {
  "${BOOTSTRAP_SLEEP:-sleep}" "$1"
}

show_plan() {
  local vis licence deploy=""
  if [ "$IN_VISIBILITY" = private ]; then
    vis="private (only you and the people you invite can see it)"
  else
    vis="public (anyone can see it and its code)"
  fi
  if [ "$IN_LICENSE" = none ]; then
    licence="none (no licence file, so nobody else may copy, change or share the code)"
  else
    licence="$IN_LICENSE, in the name of $IN_COPYRIGHT_HOLDER"
  fi
  [ "$IN_WITH_DEPLOY" != yes ] || deploy=", with the files that publish the website"
  say "Here is the plan. Nothing has been created yet."
  say "The project:"
  say "    On GitHub: $IN_OWNER/$IN_NAME, $vis"
  say "    Its page: https://github.com/$IN_OWNER/$IN_NAME"
  say "    Display name: $IN_PROJECT_NAME"
  say "    Description: $IN_DESCRIPTION"
  say "    Product owner: $IN_PO_NAME"
  say "    Language pack: $IN_PACK$deploy"
  say "    Licence: $licence"
  say "    Copy on this computer: $IN_DIR"
  say "    Your name and email for git: $IN_GIT_NAME, $IN_GIT_EMAIL"
  say "    Waiting for the project's checks: up to $IN_CI_TIMEOUT minutes"
  say "The steps, in this order:"
  say "  1. Create the project on GitHub, with the bootstrapper's files in it."
  say "  2. Protect its main version, so that from then on every change comes as a proposed change, not straight into it."
  say "  3. Make a copy of the project on this computer, in $IN_DIR."
  say "  4. Add the language pack's files, fill in the project's names and description, and add the licence."
  say "  5. Send these changes to GitHub as one proposed change, wait for the project's checks to pass, then add the change to the main version."
  say "  6. Show what was made, and the one thing to do next."
  if [ "$IN_VISIBILITY" = private ]; then
    # Spec, "Private repo, no protection possible": the plan cannot be
    # read before creating (it needs a permission gh lacks), so it warns.
    say "Warning: protection for a private project needs a paid GitHub plan (Pro, Team or Enterprise); on the free plan GitHub protects only public projects. The script cannot see your plan before it creates the project, so on the free plan it stops right after creating it and shows what you can do then: upgrade the plan, make the project public, or carry on without protection."
  fi
}

# confirm_plan: "Proceed?", unless --yes. The default is no; a no stops
# with nothing created (exit 1). --non-interactive without --yes never
# gets here: cmd_setup refuses it with the other option problems.
confirm_plan() {
  [ -z "$OPT_YES" ] || return 0
  prompt_for check_yes_no \
    "If you answer yes, the script creates the project on GitHub and carries out the plan above; if you answer no, it stops and creates nothing." \
    "Proceed? (yes or no)" no
  [ "$CHECKED" != yes ] || return 0
  fail 1 "You answered no, so the script stopped, and nothing was created." \
    "To set up the project, start the script again and answer yes."
}

# continue_after_create: the project exists now. From here on, the
# command shown at a stop continues the setup: the command the user ran
# with --resume, and --owner and --name when they were answered rather
# than given as options. --resume itself is built in a later part.
continue_after_create() {
  local extra=""
  [ -n "$RESTART_CMD" ] || remember_command
  [ -n "$OPT_RESUME" ] || extra=" --resume"
  if [ -z "$GIVEN_OWNER" ]; then
    quote_word "$IN_OWNER"
    extra="$extra --owner $QUOTED"
  fi
  if [ -z "$GIVEN_NAME" ]; then
    quote_word "$IN_NAME"
    extra="$extra --name $QUOTED"
  fi
  RESTART_CMD="$RESTART_CMD$extra"
  CREATED_NOTE="The project $IN_OWNER/$IN_NAME exists on GitHub, with only the bootstrapper's files in it."
}

# create_project: spec step 2, gh repo create from the bootstrapper. gh
# repo create gives no HTTP status, so a failure is read from gh's exit
# code, then from GitHub itself (does the project exist now?), and only
# the two cases the spec guides at this step are told apart by gh's
# text: the name is taken, or the account may not create it.
create_project() {
  local out err rc=0
  step_start "Creating the project $IN_OWNER/$IN_NAME on GitHub"
  out="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  err="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  run_gh repo create "$IN_OWNER/$IN_NAME" --template "$BOOTSTRAPPER" "--$IN_VISIBILITY" --description "$IN_DESCRIPTION" >"$out" 2>"$err" || rc=$?
  CREATE_ERR="$(tr -d '\r' <"$err")"
  rm -f "$out" "$err"
  if [ "$rc" -eq 0 ]; then
    continue_after_create
    step_end "The project $IN_OWNER/$IN_NAME was created: https://github.com/$IN_OWNER/$IN_NAME"
    return 0
  fi
  [ -n "$CREATE_ERR" ] || CREATE_ERR="gh stopped with exit code $rc and no message."
  if [ "$rc" -eq 4 ]; then
    stop_with_error "gh (the GitHub command-line tool) is not signed in to your GitHub account, so the script could not create the project. Nothing was created." \
      "$SIGN_IN_COMMAND_NEXT" "$CREATE_ERR"
  fi
  case "$(lower "$CREATE_ERR")" in
    *"already exists"*)
      guide_create_taken
      stop_at_guide
      ;;
    *"not accessible"* | *permission* | *forbidden* | *"http 403"*)
      guide_create_refused
      stop_at_guide
      ;;
  esac
  api_call "repos/$IN_OWNER/$IN_NAME"
  if [ "$API_STATUS" = 200 ]; then
    continue_after_create
    stop_with_error "gh (the GitHub command-line tool) reported an error while it created the project." \
      "Continue the setup with the command shown above. If the same thing happens, ask for help and show the details below." \
      "$CREATE_ERR"
  fi
  stop_with_error "gh (the GitHub command-line tool) could not create the project $IN_OWNER/$IN_NAME on GitHub." \
    "Open https://github.com/$IN_OWNER/$IN_NAME in your browser. If the project is not there, start the script again with the command shown above; if it is there, add --resume to that command. If the same thing happens again, ask for help and show the details below." \
    "$CREATE_ERR"
}

# guide_create_taken: the name check saw no project, but GitHub says the
# name is taken (#149 review, finding 7): most likely a private project
# the account cannot see. Nothing exists, so it is a plain new run.
guide_create_taken() {
  guide_begin "GitHub says that a project named $IN_OWNER/$IN_NAME already exists." \
    "The setup creates a new project, and GitHub gives each name to one project only. The check before could not see this one, so it is probably a private project that your account cannot see."
  guide_step "Choose another name: start the script again with the command shown below, with the name after --name changed (or --name and a new name added), such as --name $IN_NAME-2."
  guide_step "If the project is yours, sign in to GitHub in your browser with the account that owns it and open https://github.com/$IN_OWNER/$IN_NAME to see it."
  guide_end "the script says \"Done. The project\" with the new name and \"was created\"." \
    "if you do not know who owns the name, choose another one." \
    "it asks GitHub to create the project, and GitHub answers whether the name is free. It cannot check again in this run, so it stops here."
  guide_details "$CREATE_ERR"
}

# guide_create_refused: the account, or the key gh signs in with, may not
# create the project (spec, "Failed at create, step 2"). It keeps the
# promise of the fine-grained token warning: this step says so.
guide_create_refused() {
  guide_begin "GitHub did not let your account create the project $IN_OWNER/$IN_NAME." \
    "The setup starts by creating the project on GitHub, and GitHub refused: the account or the key that gh signs in with may not create projects there."
  if [ "$IN_OWNER" != "$GH_LOGIN" ]; then
    guide_step "The project would belong to the organisation $IN_OWNER. Ask one of its owners to let members create projects (on GitHub, in the organisation's Settings, under Member privileges), or to give you a role that may."
  fi
  if [ -z "$GH_SCOPES_SEEN" ]; then
    guide_step "gh signs in with a fine-grained token (a key made on GitHub with chosen permissions). Open https://github.com/settings/personal-access-tokens, edit that token, give it access to All repositories (every project of the account), and set Administration, Contents, Workflows and Pull requests to \"Read and write\"."
  fi
  guide_step "To see GitHub's own reason, open https://github.com/new in your browser and try to create a project for $IN_OWNER there."
  guide_step "Then start the script again with the command shown below."
  guide_end "the script says \"Done. The project $IN_OWNER/$IN_NAME was created\"." \
    "ask the person who manages your GitHub account or organisation, and show them the details below." \
    "it asks GitHub to create the project, and GitHub answers whether your account may. It cannot check again in this run, so it stops here."
  guide_details "$CREATE_ERR"
}

# wait_for_files: GitHub can copy the template's files after the project
# exists, so main and CHANGELOG.md are read until both are there,
# retrying only on 404, for up to POLL_TRIES waits of POLL_DELAY seconds.
wait_for_files() {
  local tries=0 what
  step_start "Waiting for GitHub to put the bootstrapper's files into the project"
  for what in branches/main contents/CHANGELOG.md; do
    while :; do
      api_call "repos/$IN_OWNER/$IN_NAME/$what"
      if [ "$API_RC" -eq 0 ] && [ "$API_STATUS" = 200 ]; then
        break
      fi
      [ "$API_STATUS" = 404 ] || api_fail "check that the project's files are there"
      if [ "$tries" -ge "$POLL_TRIES" ]; then
        api_raw
        stop_with_error "GitHub has not finished putting the bootstrapper's files into the project $IN_OWNER/$IN_NAME after a minute." \
          "Wait a few minutes, then continue the setup with the command shown above; https://www.githubstatus.com shows whether GitHub has a known problem." \
          "$API_RAW"
      fi
      [ "$tries" -gt 0 ] || say "GitHub is still copying the files; the script checks again every $POLL_DELAY seconds, for up to a minute."
      tries=$((tries + 1))
      pause_for "$POLL_DELAY"
    done
  done
  step_end "The project's files are there."
}

# protect_main: spec step 3, straight after the files are there. A 403 is
# told apart by GitHub's message (the spec: not by the status alone): the
# plan (a private project on a plan without protection) or the key's
# permission; one that fits neither gets both explanations. Each stops at
# once with its guide, before anything else changes.
protect_main() {
  step_start "Protecting the main version of the project"
  api_call -X PUT "repos/$IN_OWNER/$IN_NAME/branches/main/protection" --input - <<<"$PROTECT_BODY"
  if [ "$API_RC" -eq 0 ] && [ "$API_STATUS" = 200 ]; then
    step_end "Its main version is protected: from now on every change comes as a proposed change, not straight into it."
    return 0
  fi
  if [ "$API_STATUS" = 403 ]; then
    case "$(lower "$API_MESSAGE")" in
      *"rate limit"*) PROTECT_PROBLEM="" ;;
      *upgrade* | *"github pro"*) PROTECT_PROBLEM=plan ;;
      *"not accessible"* | *"access token"* | *integration*) PROTECT_PROBLEM=token ;;
      *) PROTECT_PROBLEM=unknown ;;
    esac
    if [ -n "$PROTECT_PROBLEM" ]; then
      guide_protect
      stop_at_guide
    fi
  fi
  api_fail "protect the main version of the project" \
    "Open https://github.com/$IN_OWNER/$IN_NAME in your browser and check that the project has its files and that your account is one of its admins (who may change its settings); then continue the setup with the command shown above."
}

# guide_protect: the 403 at step 3, by PROTECT_PROBLEM (plan, token or
# unknown). It cannot be fixed in this run, so it stops (spec: a
# post-create guide that does not retry); the three ways on for a plan
# without protection are those of the spec, and --resume and
# --allow-unprotected are only shown here: they are built in a later part.
guide_protect() {
  local title why
  case "$PROTECT_PROBLEM" in
    plan)
      title="GitHub cannot protect the main version of $IN_OWNER/$IN_NAME: protection for a private project needs a paid GitHub plan."
      why="Protection makes every change come as a proposed change, and GitHub offers it for private projects only on the Pro, Team and Enterprise plans."
      ;;
    token)
      title="GitHub did not let gh protect the main version of $IN_OWNER/$IN_NAME: the key that gh signs in with lacks a permission."
      why="Turning on protection needs the Administration permission set to \"Read and write\", and the fine-grained token (a key made on GitHub with chosen permissions) that gh signs in with does not have it."
      ;;
    *)
      title="GitHub refused to protect the main version of $IN_OWNER/$IN_NAME, and its message does not say why."
      why="Protection makes every change come as a proposed change. GitHub refuses it for one of two reasons, and the steps cover both: a private project on a plan without protection, or a key without the Administration permission."
      ;;
  esac
  guide_begin "$title" "$why"
  if [ "$PROTECT_PROBLEM" = unknown ]; then
    guide_step "If the project is private: protection for a private project needs a paid GitHub plan, so choose one of the next three steps."
  fi
  if [ "$PROTECT_PROBLEM" != token ]; then
    guide_step "Upgrade your GitHub plan to Pro (or Team, for an organisation): open https://github.com/settings/billing, or the organisation's Settings and then Billing and plans. Then continue the setup with the command shown below."
    guide_step "Or make the project public, which needs no paid plan: anyone can then see the project and its code. This command does it; then continue the setup with the command shown below:"
    say_command "gh repo edit $IN_OWNER/$IN_NAME --visibility public --accept-visibility-change-consequences"
    guide_step "Or carry on without protection: changes could then go straight into the main version, and the setup writes that decision into the project. Continue with this command:"
    say_command "bash $RESTART_CMD --allow-unprotected"
  fi
  if [ "$PROTECT_PROBLEM" != plan ]; then
    guide_step "If gh signs in with a fine-grained token: open https://github.com/settings/personal-access-tokens in your browser, edit that token, and set Administration, Contents, Workflows and Pull requests to \"Read and write\"; for an organisation's project, one of its owners may have to approve the change. Then continue the setup with the command shown below."
  fi
  guide_end "the script says \"Done. Its main version is protected\" when you continue the setup." \
    "if you changed the plan or the token and still see this, wait a few minutes and continue again; if it goes on, ask for help and show the details below." \
    "it asks GitHub to turn on the protection, and GitHub answers whether it may. It cannot check again in this run, so it stops here."
  api_raw
  guide_details "$API_RAW"
}

# set_merge_settings: the end of step 3, gh repo edit: proposed changes
# are added as one change, and their line of work is deleted after.
set_merge_settings() {
  local out err rc=0 raw
  step_start "Setting how proposed changes are added to the project"
  out="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  err="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  run_gh repo edit "$IN_OWNER/$IN_NAME" --delete-branch-on-merge --enable-squash-merge >"$out" 2>"$err" || rc=$?
  raw="$(tr -d '\r' <"$err")"
  rm -f "$out" "$err"
  if [ "$rc" -ne 0 ]; then
    [ -n "$raw" ] || raw="gh stopped with exit code $rc and no message."
    stop_with_error "GitHub did not take the project's settings for adding proposed changes." \
      "Check on https://github.com/$IN_OWNER/$IN_NAME that your account is one of the project's admins (who may change its settings), then continue the setup with the command shown above. If the same thing happens, ask for help and show the details below." \
      "$raw"
  fi
  step_end "Each proposed change will be added as one change, and the line of work it was made on is deleted afterwards."
}

# ---------- the copy on this computer ----------
# Spec steps 4, 5, 6 and 9: the copy (gh repo clone) and its version
# check, the git name and email in the copy's own settings, the line of
# work bootstrap-setup, the pack laid out over the copy (layout_into
# overlay, with the packs of the copy itself: the script the user runs
# sits alone, not next to them), and the tidy-up. Nothing is saved
# (committed) or sent (pushed) here; that is step 13.

SETUP_BRANCH=bootstrap-setup
TEMPLATE_URL=https://github.com/factoincognito/ai-project-template-v2
PACKS="node web python react-native"

# clone_project: spec step 4. gh repo clone gives no HTTP status, so a
# failure is read from gh's exit code (4: not signed in); anything else
# is told plainly with gh's and git's text below. Then origin/main must
# hold CHANGELOG.md stamped with this script's version.
clone_project() {
  local out err rc=0 raw changelog
  step_start "Making a copy of the project on this computer, in $IN_DIR"
  out="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  err="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  run_gh repo clone "$IN_OWNER/$IN_NAME" "$IN_DIR" >"$out" 2>"$err" || rc=$?
  raw="$(cat "$out" "$err" | tr -d '\r')"
  rm -f "$out" "$err"
  if [ "$rc" -ne 0 ]; then
    [ -n "$raw" ] || raw="gh stopped with exit code $rc and no message."
    if [ "$rc" -eq 4 ]; then
      stop_with_error "gh (the GitHub command-line tool) is not signed in to your GitHub account, so the script could not make a copy of the project on this computer." \
        "$SIGN_IN_CONTINUE_NEXT" "$raw"
    fi
    stop_with_error "The script could not make a copy of the project on this computer, in $IN_DIR." \
      "Check that this computer is connected to the internet and that https://github.com/$IN_OWNER/$IN_NAME opens in your browser, then continue the setup with the command shown above. If the same thing happens, ask for help and show the details below." \
      "$raw"
  fi
  CREATED_NOTE="The project $IN_OWNER/$IN_NAME exists on GitHub, with only the bootstrapper's files in it, and a copy of it is on this computer in $IN_DIR."

  err="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  rc=0
  changelog="$(git -C "$IN_DIR" show origin/main:CHANGELOG.md 2>"$err")" || rc=$?
  raw="$(tr -d '\r' <"$err")"
  rm -f "$err"
  if [ "$rc" -ne 0 ] || ! read_published_version "$changelog"; then
    [ -n "$raw" ] || raw="No line with \", built from\" in CHANGELOG.md. Its first lines:$NL$(sed -n 1,5p <<<"$changelog")"
    stop_with_error "The copy of the project on this computer does not say which version of the bootstrapper it came from: its CHANGELOG.md file is missing or has no version in it." \
      "Open https://github.com/$IN_OWNER/$IN_NAME in your browser and check that the project has a CHANGELOG.md file. If it has none, the project was not made from the bootstrapper: ask for help and show the details below." \
      "$raw"
  fi
  if [ "$PUBLISHED_VERSION" != "$SCRIPT_VERSION" ]; then
    stop_with_error "The copy of the project on this computer is from version $PUBLISHED_VERSION of the bootstrapper, but this script is version $SCRIPT_VERSION." \
      "A new version of the bootstrapper came out while the script ran. Download the current script with the command from the README, then continue the setup with the command shown above." \
      "CHANGELOG.md in the copy: $(grep -F ', built from' <<<"$changelog" | sed -n 1p)"
  fi
  step_end "The copy is in $IN_DIR, with the files of version $SCRIPT_VERSION of the bootstrapper."
}

# in_copy <what the script was doing> <git arguments...>: runs git in the
# copy; a failure stops plainly, with git's text below.
in_copy() {
  local doing="$1" err rc=0 raw
  shift
  err="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  git -C "$IN_DIR" "$@" >/dev/null 2>"$err" || rc=$?
  raw="$(tr -d '\r' <"$err")"
  rm -f "$err"
  [ "$rc" -ne 0 ] || return 0
  [ -n "$raw" ] || raw="git stopped with exit code $rc and no message."
  stop_with_error "git could not $doing in the copy of the project on this computer." \
    "Continue the setup with the command shown above. If the same thing happens, ask for help and show the details below." \
    "$raw"
}

# set_git_identity: right after the copy (spec, "Git identity"), the name
# and email from the questions go into the copy's own settings, never
# into the global ones.
set_git_identity() {
  step_start "Writing your name and email into the copy's own git settings"
  in_copy "write your name" config user.name "$IN_GIT_NAME"
  in_copy "write your email address" config user.email "$IN_GIT_EMAIL"
  step_end "git writes $IN_GIT_NAME, $IN_GIT_EMAIL into each change saved in this copy, and only in this copy; your other git settings are unchanged."
}

# start_setup_branch: spec step 5, from origin/main, following nothing on
# GitHub (the push in step 13 names where it goes).
start_setup_branch() {
  step_start "Starting a separate line of work for the setup, named $SETUP_BRANCH"
  in_copy "start the line of work $SETUP_BRANCH" checkout -q --no-track -b "$SETUP_BRANCH" origin/main
  step_end "The setup's changes go on the line of work $SETUP_BRANCH, not straight into the main version."
}

# lay_out_pack: spec step 6, with the packs of the copy itself.
lay_out_pack() {
  step_start "Adding the $IN_PACK language pack's files to the copy"
  layout_into "$IN_PACK" "$IN_DIR/languages" "$IN_DIR" overlay "$IN_WITH_DEPLOY"
  step_end "The $IN_PACK pack's files are in place, among them the file that runs the project's checks on GitHub."
}

# remove_setup_section <README.md>: deletes the section from its
# "## After bootstrapping" heading up to the next "## " heading (or the
# end of the file). Returns 1, changing nothing, when there is none.
remove_setup_section() {
  local tmp
  grep -q '^## After bootstrapping' <"$1" || return 1
  tmp="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  awk '/^## After bootstrapping/ { skip = 1; next }
    skip && /^## / { skip = 0 }
    !skip' <"$1" >"$tmp"
  cat "$tmp" >"$1"
  rm -f "$tmp"
}

# replace_text <file> <text> <new text>: replaces every <text> in the file
# with <new text>, literally (awk index(), values passed through ENVIRON:
# never read as a pattern, and no sed -i, which differs on macOS).
replace_text() {
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  RT_FROM="$2" RT_TO="$3" awk 'BEGIN { from = ENVIRON["RT_FROM"]; to = ENVIRON["RT_TO"] }
    {
      out = ""; line = $0
      while ((i = index(line, from)) > 0) {
        out = out substr(line, 1, i - 1) to
        line = substr(line, i + length(from))
      }
      print out line
    }' <"$1" >"$tmp"
  cat "$tmp" >"$1"
  rm -f "$tmp"
}

# tidy_up: spec step 9. The README's setup section goes; languages/ keeps
# only the chosen pack's files that were not laid out (LP_KEPT); the
# links in docs/DEV_INFRASTRUCTURE.md to the other packs' code-standards.md
# point to the template on GitHub; the script's own copy goes; licenses/
# and everything else stay.
tidy_up() {
  local keep f p
  step_start "Removing what only the setup needed from the copy"
  if ! remove_setup_section "$IN_DIR/README.md"; then
    stop_with_error "The file README.md in the copy of the project has no section that starts with \"## After bootstrapping\", which the setup removes." \
      "$SETUP_BROKEN_NEXT" "No line starting with \"## After bootstrapping\" in $IN_DIR/README.md."
  fi
  keep="$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  for f in $LP_KEPT; do
    mv "$IN_DIR/languages/$IN_PACK/$f" "$keep/$f"
  done
  rm -rf "$IN_DIR/languages"
  mkdir -p "$IN_DIR/languages/$IN_PACK"
  for f in $LP_KEPT; do
    mv "$keep/$f" "$IN_DIR/languages/$IN_PACK/$f"
  done
  rmdir "$keep"
  for p in $PACKS; do
    [ "$p" != "$IN_PACK" ] || continue
    replace_text "$IN_DIR/docs/DEV_INFRASTRUCTURE.md" "\`languages/$p/code-standards.md\`" \
      "$TEMPLATE_URL/blob/main/languages/$p/code-standards.md"
  done
  rm -f "$IN_DIR/bootstrap-project.sh"
  step_end "The setup section of README.md, the other language packs and the setup script itself are gone from the copy."
}

# ---------- filling in the placeholders ----------
# Spec step 8. The fill table is in one place: fill_rows (which file holds
# which text, per pack), fill_text (the exact text) and fill_value (what
# it becomes). The self-check before the commit (step 12) can reuse
# fill_rows and fill_text. The fill runs after the tidy-up (step 9): the
# result is the same, and the README's setup section is then removed
# before a description that starts with "## After bootstrapping" could
# be taken for it.

FILL_DATE=""

# fill_rows <pack> <with deploy: yes or empty>: FILL_ROWS is the table for
# that pack, one row per line, "<file> <key>", the file relative to the
# copy. Only the files named here are filled in: in memory/roles.md and
# docs/CROG_ONBOARDING.md [DATE] is a format token and stays, and the
# kept languages/<pack>/ files keep their texts (react-native
# code-standards.md, the web wrangler.jsonc without --with-deploy).
FILL_ROWS=""
fill_rows() {
  FILL_ROWS="README.md name
README.md po
README.md readme-description
CLAUDE.md name
CHANGELOG.md name
docs/SPEC.md name
docs/SPEC.md date
docs/BACKLOG.md name
docs/BACKLOG.md po
docs/NEXT_SESSION.md name
docs/NEXT_SESSION.md date
memory/project.md name
memory/project.md owner-and-name
memory/project.md project-description"
  case "$1" in
    node | web | react-native) FILL_ROWS="$FILL_ROWS${NL}package.json package-description${NL}package.json package-name" ;;
  esac
  case "$1" in
    web)
      FILL_ROWS="$FILL_ROWS${NL}index.html title"
      [ "${2:-}" != yes ] || FILL_ROWS="$FILL_ROWS${NL}wrangler.jsonc package-name"
      ;;
    react-native) FILL_ROWS="$FILL_ROWS${NL}app.json name${NL}app.json slug" ;;
  esac
}

# fill_text <key>: FILL_TEXT is the exact text the key stands for. The
# description in memory/project.md is two lines, matched as one text.
fill_text() {
  case "$1" in
    name) FILL_TEXT='[PROJECT NAME]' ;;
    po) FILL_TEXT='[PO NAME]' ;;
    owner-and-name) FILL_TEXT='[OWNER/REPO]' ;;
    date) FILL_TEXT='[DATE]' ;;
    readme-description) FILL_TEXT='[One or two sentences: what this project is and who it is for.]' ;;
    project-description) FILL_TEXT="[What the project is, who it is for, and what problem${NL}it solves.]" ;;
    package-description) FILL_TEXT='[project-description]' ;;
    package-name | title) FILL_TEXT='[project-name]' ;;
    slug) FILL_TEXT='[project-slug]' ;;
    *) return 1 ;;
  esac
}

# fill_value <key>: FILL_VALUE is what the key's text becomes. The npm
# name and the Expo slug are the slug of the project name (lowercase, a
# . made a -); the web page title is the display name.
fill_value() {
  case "$1" in
    name | title) FILL_VALUE="$IN_PROJECT_NAME" ;;
    po) FILL_VALUE="$IN_PO_NAME" ;;
    owner-and-name) FILL_VALUE="$IN_OWNER/$IN_NAME" ;;
    date) FILL_VALUE="$FILL_DATE" ;;
    readme-description | project-description | package-description) FILL_VALUE="$IN_DESCRIPTION" ;;
    package-name | slug) FILL_VALUE="$IN_SLUG" ;;
    *) return 1 ;;
  esac
}

# fill_file <file> <key...>: replaces the texts of the keys given in the
# file, literally and in one pass over the whole file (so a text over two
# lines is found, and a value holding another key's text is not filled
# in again): awk index() and substr(), the values passed through
# ENVIRON (never read as a pattern; no sed -i, which differs on macOS),
# bytes compared as bytes (LC_ALL=C). The file is read from stdin, never
# as an awk operand (a path such as a=b/x would be read as a setting).
# Line endings stay as they are (a CR is part of its line), a file
# without a newline at the end stays without, and the file keeps its
# mode (it is rewritten in place).
fill_file() {
  local file="$1" tmp n=0 key ends_nl=""
  shift
  [ -n "$(tail -c 1 <"$file")" ] || ends_nl=yes
  tmp="$(mktemp "${TMPDIR:-/tmp}/bootstrap-project.XXXXXX")"
  (
    for key in "$@"; do
      n=$((n + 1))
      fill_text "$key"
      fill_value "$key"
      export "FILL_FROM_$n=$FILL_TEXT" "FILL_TO_$n=$FILL_VALUE"
    done
    export FILL_N="$n" FILL_NL="$ends_nl"
    LC_ALL=C awk 'BEGIN {
        n = ENVIRON["FILL_N"] + 0
        for (k = 1; k <= n; k++) { from[k] = ENVIRON["FILL_FROM_" k]; to[k] = ENVIRON["FILL_TO_" k] }
      }
      { s = (NR == 1) ? $0 : s "\n" $0 }
      END {
        out = ""
        while (1) {
          best = 0
          for (k = 1; k <= n; k++) {
            i = index(s, from[k])
            if (i > 0 && (best == 0 || i < best)) { best = i; bk = k }
          }
          if (best == 0) break
          out = out substr(s, 1, best - 1) to[bk]
          s = substr(s, best + length(from[bk]))
        }
        ORS = ""
        print out s
        if (NR > 0 && ENVIRON["FILL_NL"] == "yes") print "\n"
      }' <"$file" >"$tmp"
  )
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

# fill_placeholders: spec step 8 over the copy. Every file of the table
# must be there before the first one is changed; a missing one means the
# project GitHub made does not fit this script.
fill_placeholders() {
  local rows file f key keys files="" missing=""
  step_start "Filling in the project's name, description and product owner in its files"
  FILL_DATE="$(date +%Y-%m-%d)"
  fill_rows "$IN_PACK" "$IN_WITH_DEPLOY"
  rows="$FILL_ROWS"
  while read -r file key; do
    case " $files " in *" $file "*) continue ;; esac
    files="$files $file"
    [ -f "$IN_DIR/$file" ] || missing="$missing $file"
  done <<<"$rows"
  if [ -n "$missing" ]; then
    missing="${missing# }"
    stop_with_error "The copy of the project on this computer has no ${missing// /, }, in which the setup fills in the project's name and other details." \
      "$SETUP_BROKEN_NEXT" "Missing in $IN_DIR: $missing"
  fi
  for file in $files; do
    keys="$(while read -r f key; do [ "$f" != "$file" ] || printf '%s ' "$key"; done <<<"$rows")"
    # shellcheck disable=SC2086 # the keys are single words
    fill_file "$IN_DIR/$file" $keys
  done
  step_end "The name $IN_PROJECT_NAME, the description, the product owner $IN_PO_NAME, the project's place on GitHub ($IN_OWNER/$IN_NAME) and today's date $FILL_DATE are filled in where the files asked for them."
}

# say_left_for_clead: the texts the setup leaves for the first session
# with Clead (spec step 8), for the report at the end (step 19).
say_left_for_clead() {
  say "These parts of the project are left for your first session with Clead (Claude, the project's Tech Owner), who writes them with you:"
  say "  - the name of the first phase, [PHASE NAME], in docs/BACKLOG.md;"
  say "  - the goals, [Goal], and the rest of memory/project.md;"
  say "  - the questions in square brackets in the sections of docs/SPEC.md;"
  say "  - memory/context.md."
}

# cmd_setup <options...>: the setup. Built so far: the checks of this
# computer and on GitHub, the inputs, the plan, and steps 2 to 6, 9 and 8
# (in that order: see "filling in the placeholders"). The
# options are checked first, then the checks that need no answer (the
# tools, the GitHub sign-in and the current version), so that nothing is
# asked in vain; the npm, folder, permission and name checks need
# answers, so they follow the questions.
cmd_setup() {
  parse_args "$@"
  GIVEN_NAME="$IN_NAME"
  GIVEN_OWNER="$IN_OWNER"
  if [ -n "$SCRIPT_PIPED" ] && [ -z "$OPT_NON_INTERACTIVE" ]; then
    fail 2 "The script was piped into bash, so it cannot ask its questions: they would read the script itself." \
      "Run the command from the README, which saves the script to a file first and then runs that file."
  fi
  remember_command "$@"
  detect_os
  if [ -n "$OPT_NON_INTERACTIVE" ] && [ -z "$OPT_YES$OPT_DRY_RUN" ]; then
    add_problem --yes "With --non-interactive the script asks nothing, so it cannot ask \"Proceed?\" before it creates the project: add --yes to go ahead, or --dry-run to only see the plan."
  fi
  check_options
  preflight_tools
  preflight_github_account
  preflight_published_version
  collect_inputs
  preflight_npm
  preflight_target_dir
  preflight_github_permissions
  preflight_project_absent
  if [ -n "$OPT_RESUME" ]; then
    fail 1 "Continuing a setup that stopped part way (--resume) is not built yet in this version of the script. Nothing was changed." \
      "Use a released version of the bootstrapper to continue the setup."
  fi
  show_plan
  if [ -n "$OPT_DRY_RUN" ]; then
    say "This was a dry run (--dry-run): the checks passed, and nothing was created."
    exit 0
  fi
  confirm_plan
  create_project
  wait_for_files
  protect_main
  set_merge_settings
  clone_project
  set_git_identity
  start_setup_branch
  lay_out_pack
  tidy_up
  fill_placeholders
  say "$CONTINUE_INTRO"
  say_command "bash $RESTART_CMD"
  fail 1 "The project $IN_OWNER/$IN_NAME was created on GitHub and its main version is protected. Its copy on this computer, in $IN_DIR, has the $IN_PACK pack's files, ready for the next steps. This version of the script stops here: the next steps of the setup are not built yet." \
    "Use a released version of the bootstrapper to set up a project. The project stays on GitHub and its copy stays in $IN_DIR: the command shown above continues the setup once a version of the script has the next steps. If you do not need them, delete the project on GitHub, in its Settings, and delete the folder $IN_DIR."
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
