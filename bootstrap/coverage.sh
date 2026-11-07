#!/usr/bin/env bash
# coverage.sh: line coverage of the template's own scripts (PBI-1.41 c2).
# The Bootstrapper workflow's Ubuntu test jobs run their suites under
# bashcov with it, and bootstrapper-test gates the merged results.
#
# Usage:
#   bash bootstrap/coverage.sh install <dir>
#       Installs bashcov and simplecov, pinned (below), into <dir>, with
#       <dir>/bin/bashcov to start it; each gem's download is checked
#       against its SHA-256 before anything is installed. Needs Ruby 3.3
#       or later (simplecov's minimum): ruby on PATH, else the newest in
#       the runner's tool cache ($RUNNER_TOOL_CACHE/Ruby).
#   bash bootstrap/coverage.sh run <results> <name> <suite> [<arg>...]
#       Runs the suite under bashcov ($BASHCOV, default bashcov on PATH)
#       from the root of this checkout, with BOOTSTRAP_TEST_KEEP_COPIES=1
#       (the harnesses keep the copies of the scripts they ran) and a
#       TMPDIR of its own, which it removes afterwards. It writes
#       <results>/<name>.json: the lines of each counted script, with
#       each copy bashcov traced outside the checkout added onto its
#       script, then exits as the suite did.
#   bash bootstrap/coverage.sh gate <minimum> <results> <name>...
#       Merges <results>/<name>.json of each name, prints the line
#       coverage of each counted script and in total, and fails (exit 1)
#       below <minimum> percent of the counted lines in total, or when a
#       result is missing, not expected, or not one run wrote, or a
#       counted script has no result.
#
# The counted scripts: every .sh in bootstrap/, tools/ and .github/scripts/
# whose name does not start with test. A file outside the checkout is a
# copy of the counted script of the same name when it has as many lines,
# each the script's line or that line with {{TEMPLATE_VERSION}} and
# {{TEMPLATE_COMMIT}} stamped as bootstrap/build.sh stamps them; any other
# file of that name is left out. A line counts once it is run in any
# result; a line no result marks as code is not counted, nor one past the
# script's end (bashcov reports some).
# The JSON is read by bootstrap/coverage.rb, with the ruby on PATH.
# Exit codes: 0 done, 1 failed, 2 usage.
#
# Template-only: bootstrap/ is not in bootstrap/manifest.txt.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# BOOTSTRAP_COVERAGE_ROOT: the checkout to measure; unset, the one this
# script is in. The tests set it to a fixture, so that they run this
# script itself and the coverage run counts what they run of it.
ROOT="$(cd "${BOOTSTRAP_COVERAGE_ROOT:-$HERE/..}" && pwd)"

# Pinned exactly (P-11 § 2 (5)); the SHA-256 of each .gem as rubygems.org
# publishes it.
BASHCOV_VERSION=4.0.2
BASHCOV_SHA256=ca055e53a15268e5541102e58b5e08fda17b243327160ceabb54fcc76a2c9ade
SIMPLECOV_VERSION=1.3.2
SIMPLECOV_SHA256=2a22ec1759f1b8db60881a2e038758956fc69ef93ed669be0bde0678de6d0e85

usage() {
  cat >&2 <<'EOF'
usage: bash bootstrap/coverage.sh install <dir>
       bash bootstrap/coverage.sh run <results> <name> <suite> [<arg>...]
       bash bootstrap/coverage.sh gate <minimum> <results> <name>...
EOF
  exit 2
}

die() {
  local rc="$1"
  shift
  echo "coverage.sh: $*" >&2
  exit "$rc"
}

# check_name <name>: a result's name is a plain file name.
check_name() {
  case "$1" in
    "" | *[!A-Za-z0-9._-]* | .*) die 2 "a result's name is letters, digits, '.', '_' and '-', not starting with '.'; got '$1'" ;;
  esac
}

# counted_scripts: the counted scripts, relative to the root, one per line.
counted_scripts() {
  local d
  for d in bootstrap tools .github/scripts; do
    [ ! -d "$ROOT/$d" ] || (cd "$ROOT" && find "$d" -type f -name '*.sh' ! -name 'test*')
  done | LC_ALL=C sort
}

# remove <dir>: deletes it, also when a test left a folder read-only.
remove() {
  chmod -R u+w "$1" 2>/dev/null || true
  rm -rf "$1"
}

# find_ruby: prints the path of a Ruby 3.3 or later: ruby on PATH, else the
# newest in the tool cache; prints nothing if there is none. The list is
# made in full before the search: a search that stops at the first fit
# while the list is still being written breaks the writer's pipe (with
# SIGPIPE ignored, as on GitHub's runners, the writer then fails).
find_ruby() {
  local r p v list
  list="$(
    command -v ruby 2>/dev/null || true
    for p in "${RUNNER_TOOL_CACHE:-/opt/hostedtoolcache}"/Ruby/*/x64/bin/ruby; do
      [ -x "$p" ] || continue
      v="${p%/x64/bin/ruby}"
      printf '%s %s\n' "${v##*/}" "$p"
    done | sort -t. -k1,1nr -k2,2nr -k3,3nr | cut -d' ' -f2-
  )"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    if "$r" -e 'exit((RUBY_VERSION.split(".").map(&:to_i) <=> [3, 3]) >= 0)' 2>/dev/null; then
      printf '%s\n' "$r"
      return 0
    fi
  done <<<"$list"
}

sha256_ok() {
  if command -v sha256sum >/dev/null 2>&1; then
    echo "$1  $2" | sha256sum -c - >/dev/null 2>&1
  else
    echo "$1  $2" | shasum -a 256 -c - >/dev/null 2>&1
  fi
}

cmd_install() {
  [ "$#" -eq 1 ] || usage
  local dir="$1" ruby g f v
  ruby="$(find_ruby || true)"
  [ -n "$ruby" ] ||
    die 1 "installing bashcov $BASHCOV_VERSION with simplecov $SIMPLECOV_VERSION needs Ruby 3.3 or later (simplecov's minimum); there is none on PATH or in ${RUNNER_TOOL_CACHE:-/opt/hostedtoolcache}/Ruby."
  echo "Ruby: $ruby"
  mkdir -p "$dir/download"
  for g in "simplecov $SIMPLECOV_VERSION $SIMPLECOV_SHA256" "bashcov $BASHCOV_VERSION $BASHCOV_SHA256"; do
    # shellcheck disable=SC2086 # three words: name, version, SHA-256
    set -- $g
    f="$dir/download/$1-$2.gem"
    curl -fsSL --retry 3 --max-time 120 -o "$f" "https://rubygems.org/downloads/$1-$2.gem" || die 1 "could not download $1 $2"
    sha256_ok "$3" "$f" || die 1 "the download of $1 $2 does not have the pinned SHA-256 $3"
  done
  GEM_HOME="$dir/gems" GEM_PATH="$dir/gems" "${ruby%/ruby}/gem" install --local --no-document --ignore-dependencies \
    "$dir/download/simplecov-$SIMPLECOV_VERSION.gem" "$dir/download/bashcov-$BASHCOV_VERSION.gem" >/dev/null
  mkdir -p "$dir/bin"
  printf '#!/usr/bin/env bash\nexport GEM_HOME=%q GEM_PATH=%q\nexec %q %q "$@"\n' \
    "$dir/gems" "$dir/gems" "$ruby" "$dir/gems/bin/bashcov" >"$dir/bin/bashcov"
  chmod +x "$dir/bin/bashcov"
  v="$("$dir/bin/bashcov" --version)"
  [ "$v" = "bashcov $BASHCOV_VERSION" ] || die 1 "installed bashcov says '$v', not bashcov $BASHCOV_VERSION"
  v="$(GEM_HOME="$dir/gems" GEM_PATH="$dir/gems" "$ruby" -e "gem 'simplecov', '= $SIMPLECOV_VERSION'; require 'simplecov'; print SimpleCov::VERSION")"
  [ "$v" = "$SIMPLECOV_VERSION" ] || die 1 "installed simplecov says '$v', not $SIMPLECOV_VERSION"
  echo "Installed bashcov $BASHCOV_VERSION with simplecov $SIMPLECOV_VERSION: $dir/bin/bashcov"
}

cmd_run() {
  [ "$#" -ge 3 ] || usage
  local out="$1" name="$2" tmp rc=0
  shift 2
  check_name "$name"
  mkdir -p "$out"
  out="$(cd "$out" && pwd)"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/coverage-run.XXXXXX")"
  mkdir "$tmp/tmp" "$tmp/result"
  (
    cd "$ROOT"
    TMPDIR="$tmp/tmp" BOOTSTRAP_TEST_KEEP_COPIES=1 BOOTSTRAP_COVERAGE_DIR="$tmp/result" \
      "${BASHCOV:-bashcov}" --root "$ROOT" --command-name "$name" -- "$@"
  ) || rc=$?
  if [ ! -s "$tmp/result/.resultset.json" ]; then
    remove "$tmp"
    die 1 "bashcov wrote no result for $name (the suite exited $rc)"
  fi
  # The copies are still in the suite's TMPDIR: they are read here.
  # shellcheck disable=SC2046 # one counted script per word; their names have no spaces
  ruby "$HERE/coverage.rb" map "$ROOT" "$tmp/result/.resultset.json" "$out/$name.json" "$name" $(counted_scripts) || {
    remove "$tmp"
    rm -f "$out/$name.json"
    die 1 "could not map the result of $name"
  }
  remove "$tmp"
  return "$rc"
}

cmd_gate() {
  [ "$#" -ge 3 ] || usage
  local min="$1" dir="$2" n
  shift 2
  case "$min" in
    [0-9] | [1-9][0-9] | 100) ;;
    *) die 2 "the minimum must be a whole number from 0 to 100; got '$min'" ;;
  esac
  for n in "$@"; do check_name "$n"; done
  # shellcheck disable=SC2046 # one counted script per word; their names have no spaces
  ruby "$HERE/coverage.rb" gate "$min" "$dir" "$ROOT" "$#" "$@" $(counted_scripts)
}

case "${1:-}" in
  install)
    shift
    cmd_install "$@"
    ;;
  run)
    shift
    cmd_run "$@"
    ;;
  gate)
    shift
    cmd_gate "$@"
    ;;
  *) usage ;;
esac
