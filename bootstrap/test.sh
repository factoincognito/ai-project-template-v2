#!/usr/bin/env bash
# Tests for bootstrap/build.sh and bootstrap/publish.sh.
# Usage: bash bootstrap/test.sh
# Each test builds into its own temp dir. Fixture repos are small fake
# source trees with a copy of build.sh in their bootstrap/ folder, so the
# failure cases do not depend on this repo's real content.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
BUILD="$HERE/build.sh"
PUBLISH="$HERE/publish.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SHA="0123456789abcdef0123456789abcdef01234567"
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

# expect_build_fail <fixture> <expected-stderr-substring> <out> <version> <commit>
expect_build_fail() {
  local fx="$1" msg="$2"; shift 2
  local err="$WORK/err.$RANDOM"
  if bash "$fx/bootstrap/build.sh" "$@" 2>"$err" >/dev/null; then
    die "build succeeded, expected failure containing: $msg"
  fi
  grep -qF -- "$msg" "$err" || { cat "$err" >&2; die "stderr lacks: $msg"; }
}

build_ok() {
  local fx="$1"; shift
  bash "$fx/bootstrap/build.sh" "$@" >/dev/null || die "build failed: $*"
}

# Sorted list of all files (and symlinks) under a dir, relative paths.
list_files() {
  (cd "$1" && find . \( -type f -o -type l \) | sed 's|^\./||' | LC_ALL=C sort)
}

# A small fake source repo with build.sh in bootstrap/.
make_fixture() {
  local d
  d="$(mktemp -d "$WORK/fx.XXXXXX")"
  mkdir -p "$d/bootstrap/stubs/docs" "$d/docs" "$d/lang/a" "$d/.github/workflows"
  cp "$BUILD" "$d/bootstrap/build.sh"
  cat >"$d/bootstrap/manifest.txt" <<'EOF'
# comment line, ignored

CLAUDE.md
.gitignore
lang/
.github/workflows/ci.yml
EOF
  echo "entry point" >"$d/CLAUDE.md"
  echo "*.tmp" >"$d/.gitignore"
  echo "x" >"$d/lang/a/x.txt"
  echo "b" >"$d/lang/b.txt"
  echo "hidden" >"$d/lang/.hidden"
  echo "name: CI" >"$d/.github/workflows/ci.yml"
  echo "name: template-only" >"$d/.github/workflows/other.yml"
  echo "release notes" >"$d/docs/RELEASE_NOTES.md"
  echo "not listed" >"$d/unlisted.md"
  printf '# Changelog\n\n## Created from template {{TEMPLATE_VERSION}} ({{TEMPLATE_COMMIT}})\n' \
    >"$d/bootstrap/stubs/CHANGELOG.md"
  printf '# Backlog\n\n## Open questions\n' >"$d/bootstrap/stubs/docs/BACKLOG.md"
  printf '%s\n' '#!/usr/bin/env bash' "SCRIPT_VERSION='{{TEMPLATE_VERSION}}'" \
    "SCRIPT_COMMIT='{{TEMPLATE_COMMIT}}'" 'echo "$SCRIPT_VERSION $SCRIPT_COMMIT"' \
    >"$d/bootstrap/stubs/bootstrap-project.sh"
  chmod 755 "$d/bootstrap/stubs/bootstrap-project.sh"
  echo "$d"
}

# ---------- build.sh: happy path ----------

test_fixture_output_is_exactly_manifest_plus_stubs() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  diff <(list_files "$out") <(printf '%s\n' \
    .github/workflows/ci.yml .gitignore CHANGELOG.md CLAUDE.md \
    bootstrap-project.sh docs/BACKLOG.md lang/.hidden lang/a/x.txt lang/b.txt | LC_ALL=C sort) \
    || die "output file list differs from manifest plus stubs"
}

test_copied_files_are_byte_identical() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  for f in CLAUDE.md .gitignore lang/a/x.txt lang/.hidden .github/workflows/ci.yml; do
    cmp -s "$fx/$f" "$out/$f" || die "$f differs from source"
  done
  cmp -s "$fx/bootstrap/stubs/docs/BACKLOG.md" "$out/docs/BACKLOG.md" \
    || die "stub docs/BACKLOG.md differs"
}

test_placeholders_replaced_with_version_and_commit() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  grep -qF "## Created from template v1.2.3 ($SHA)" "$out/CHANGELOG.md" \
    || { cat "$out/CHANGELOG.md" >&2; die "CHANGELOG not stamped"; }
  ! grep -rqF '{{TEMPLATE_' "$out" || die "placeholder left"
}

test_changelog_stamp_is_byte_for_byte_as_before() {
  # Stamping the script too must not change what the CHANGELOG gets.
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  cmp -s "$out/CHANGELOG.md" <(printf '# Changelog\n\n## Created from template v1.2.3 (%s)\n' "$SHA") \
    || { cat "$out/CHANGELOG.md" >&2; die "CHANGELOG stamp changed"; }
  [ ! -e "$out/CHANGELOG.md.tmp" ] || die "temp file left in output"
}

test_project_script_stub_is_stamped_with_version_and_commit() {
  local fx out f
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  f="$out/bootstrap-project.sh"
  grep -qxF "SCRIPT_VERSION='v1.2.3'" "$f" || { cat "$f" >&2; die "script version not stamped"; }
  grep -qxF "SCRIPT_COMMIT='$SHA'" "$f" || { cat "$f" >&2; die "script commit not stamped"; }
  ! grep -qF '{{TEMPLATE_' "$f" || die "placeholder left in the script"
  [ "$(bash "$f")" = "v1.2.3 $SHA" ] || die "stamped script does not report its stamp"
}

test_stamped_project_script_stays_executable() {
  # Stamping rewrites the file; it must keep the stub's executable bit
  # (a sed-to-temp-then-mv stamp would drop it).
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  [ -x "$out/bootstrap-project.sh" ] || { ls -l "$out" >&2; die "stamping dropped the executable bit"; }
}

test_project_script_stub_without_placeholders_rejected() {
  local fx; fx="$(make_fixture)"
  printf '%s\n' '#!/usr/bin/env bash' "SCRIPT_VERSION='{{TEMPLATE_VERSION}}'" \
    >"$fx/bootstrap/stubs/bootstrap-project.sh"
  expect_build_fail "$fx" "bootstrap-project.sh stub lacks {{TEMPLATE_COMMIT}}" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  printf '%s\n' '#!/usr/bin/env bash' "SCRIPT_COMMIT='{{TEMPLATE_COMMIT}}'" \
    >"$fx/bootstrap/stubs/bootstrap-project.sh"
  expect_build_fail "$fx" "bootstrap-project.sh stub lacks {{TEMPLATE_VERSION}}" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  rm "$fx/bootstrap/stubs/bootstrap-project.sh"
  expect_build_fail "$fx" "bootstrap-project.sh stub not found" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_stamped_stub_that_is_a_symlink_rejected() {
  # Stamping writes in place; through a symlink it would write into
  # whatever the link points at, possibly the source tree. The link is
  # absolute: a relative one would be broken once copied into the
  # build's temp folder, and nothing could be written through it.
  local fx target out err rc
  fx="$(make_fixture)"; out="$WORK/o.$RANDOM"; err="$WORK/err.$RANDOM"
  target="$WORK/outside-changelog.$RANDOM.md"
  mv "$fx/bootstrap/stubs/CHANGELOG.md" "$target"
  ln -s "$target" "$fx/bootstrap/stubs/CHANGELOG.md"
  set +e
  bash "$fx/bootstrap/build.sh" "$out" v1.2.3 "$SHA" >/dev/null 2>"$err"
  rc=$?
  set -e
  grep -qF '{{TEMPLATE_VERSION}}' "$target" || { cat "$target" >&2; die "the link target outside the build was modified"; }
  [ ! -L "$out/CHANGELOG.md" ] || die "CHANGELOG.md shipped as a symlink"
  [ "$rc" -ne 0 ] || die "build succeeded, expected the symlinked stub to be refused"
  grep -qF "CHANGELOG.md stub must be a regular file, not a symlink" "$err" || { cat "$err" >&2; die "stderr lacks the symlink refusal"; }
}

test_build_fails_if_stamping_drops_the_executable_bit() {
  # Pins the output check in build.sh: the fixture's own copy of
  # build.sh is patched so that the stamp step strips the mode, and the
  # build must then refuse. No hook in build.sh; the patch must apply,
  # or this test fails instead of passing on an unchanged copy.
  local fx b
  fx="$(make_fixture)"; b="$fx/bootstrap/build.sh"
  grep -qxF '  cat "$STAMP_TMP" >"$STAGE/$s"' "$b" || die "stamp line not found in build.sh; update this test"
  sed -e 's|^  cat "\$STAMP_TMP" >"\$STAGE/\$s"$|&; chmod a-x "$STAGE/$s"|' "$b" >"$b.new"
  cat "$b.new" >"$b"; rm "$b.new"
  grep -qF 'chmod a-x "$STAGE/$s"' "$b" || die "the patch did not apply"
  expect_build_fail "$fx" "stamping dropped the executable bit of bootstrap-project.sh" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_absent_out_dir_is_created() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/new.$RANDOM/nested"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  [ -f "$out/CLAUDE.md" ] || die "out-dir not created"
}

test_empty_existing_out_dir_is_accepted() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/empty.$RANDOM"; mkdir "$out"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  [ -f "$out/CLAUDE.md" ] || die "nothing written"
}

test_uppercase_hex_commit_is_accepted() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  build_ok "$fx" "$out" v10.0.12 "0123456789ABCDEF0123456789ABCDEF01234567"
}

test_open_questions_heading_is_not_a_false_positive() {
  # "Open questions" (no number) and "PBI-x" (no digit) must pass.
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  printf 'open questions\nPBI-x\nPR #3\ntrig\n' >>"$fx/CLAUDE.md"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
}

test_real_repo_build_matches_manifest_plus_stubs() {
  # Build this repo for real and compare against git-tracked files.
  local out expected
  out="$WORK/real.$RANDOM"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  expected="$WORK/expected.$RANDOM"
  {
    grep -vE '^[[:space:]]*(#|$)' "$REPO/bootstrap/manifest.txt" | while read -r p; do
      p="${p%/}"
      if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$REPO" ls-files -- "$p"
      else
        (cd "$REPO" && find "$p" -type f)
      fi
    done
    (cd "$REPO/bootstrap/stubs" && find . -type f | sed 's|^\./||')
  } | LC_ALL=C sort -u >"$expected"
  diff <(list_files "$out") "$expected" || die "real output differs from manifest plus stubs"
  grep -qF "v2.1.0" "$out/CHANGELOG.md" || die "real CHANGELOG lacks version"
  grep -qF "$SHA" "$out/CHANGELOG.md" || die "real CHANGELOG lacks commit"
  [ ! -e "$out/docs/RELEASE_NOTES.md" ] || die "RELEASE_NOTES shipped"
  [ ! -e "$out/bootstrap" ] || die "bootstrap/ shipped"
  [ ! -e "$out/.github/workflows/bootstrapper.yml" ] || die "bootstrapper.yml shipped"
  [ ! -e "$out/.github/workflows/packs.yml" ] || die "packs.yml shipped"
  [ ! -e "$out/tools" ] || die "tools/ shipped"
}

test_real_build_ships_the_generic_docs() {
  # Generic docs every project needs ship; the template's own do not.
  local out="$WORK/real.$RANDOM"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -f "$out/docs/DEV_INFRASTRUCTURE.md" ] || die "DEV_INFRASTRUCTURE.md not shipped"
  [ -f "$out/languages/python/code-standards.md" ] || die "python pack not shipped"
  cmp -s "$REPO/docs/DEV_INFRASTRUCTURE.md" "$out/docs/DEV_INFRASTRUCTURE.md" \
    || die "DEV_INFRASTRUCTURE.md shipped altered"
}

test_real_build_ships_the_template_licence() {
  # The template's own files are PolyForm Noncommercial 1.0.0. The text
  # must ship unaltered, with a Required Notice line, in licenses/ and
  # never as a root LICENSE (which projects would inherit as their own).
  local out="$WORK/real.$RANDOM" lic="licenses/PolyForm-Noncommercial-1.0.0.md" sum
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -f "$out/$lic" ] || die "$lic not shipped"
  sum="$(sha256sum "$out/$lic" | cut -d' ' -f1)"
  [ "$sum" = "c0ea4a896d2c8c394b29f9427589996db826cd501c512279ff0ed3ef48fabbe5" ] \
    || die "$lic differs from the official PolyForm Noncommercial 1.0.0 text"
  grep -qE '^Required Notice: Copyright .+' "$out/licenses/NOTICE" \
    || die "licenses/NOTICE lacks a Required Notice line"
  [ ! -e "$out/LICENSE" ] || die "root LICENSE shipped"
  [ ! -e "$out/LICENSE.md" ] || die "root LICENSE.md shipped"
}

test_real_stubs_have_no_forbidden_strings() {
  ! grep -rnE 'trig_|PBI-[0-9]|open question [0-9]' "$REPO/bootstrap/stubs" || die "forbidden regex in stubs"
  ! grep -rnF '(PR #' "$REPO/bootstrap/stubs" || die "(PR # in stubs"
}

test_shipped_ci_does_not_reference_bootstrap() {
  # What ships is the stub (the template's own ci.yml does not ship).
  local stub="$REPO/bootstrap/stubs/.github/workflows/ci.yml"
  [ -f "$stub" ] || die "no stub ci.yml at bootstrap/stubs/.github/workflows/ci.yml"
  ! grep -n 'bootstrap/' "$stub" || die "stub ci.yml references bootstrap/"
  ! grep -n 'tools/' "$stub" || die "stub ci.yml references tools/"
  ! grep -n 'require-test-change' "$stub" || die "stub ci.yml runs the check (a project with no pack has no src/ to define)"
}

test_real_build_ships_the_stub_ci_unchanged() {
  local out="$WORK/real.$RANDOM" f=".github/workflows/ci.yml"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  cmp -s "$REPO/bootstrap/stubs/$f" "$out/$f" || die "shipped ci.yml differs from the stub"
  ! grep -q 'require-test-change' "$out/$f" || die "shipped ci.yml runs the template's check"
  grep -qE '^  build:' "$out/$f" || die "shipped ci.yml has no job named build"
}

test_template_ci_is_not_in_the_manifest() {
  ! grep -vE '^[[:space:]]*(#|$)' "$REPO/bootstrap/manifest.txt" | grep -qxF '.github/workflows/ci.yml' \
    || die "the template's own ci.yml is listed in the manifest, so it would ship"
}

# ---------- build.sh: argument errors ----------

test_wrong_arg_count_fails_with_usage() {
  local fx; fx="$(make_fixture)"
  expect_build_fail "$fx" "usage:" "$WORK/o.$RANDOM" v1.2.3
  expect_build_fail "$fx" "usage:" "$WORK/o.$RANDOM" v1.2.3 "$SHA" extra
}

test_bad_version_rejected() {
  local fx v; fx="$(make_fixture)"
  for v in 1.2.3 v1.2 v1.2.3-rc1 V1.2.3 "v1.2.3 " "" v1.2.x; do
    expect_build_fail "$fx" "is not vMAJOR.MINOR.PATCH" "$WORK/o.$RANDOM" "$v" "$SHA"
  done
}

test_bad_commit_rejected() {
  local fx c; fx="$(make_fixture)"
  for c in "${SHA:0:39}" "${SHA}0" "g${SHA:1}" "" "${SHA:0:7}"; do
    expect_build_fail "$fx" "is not a 40-character hex SHA" "$WORK/o.$RANDOM" v1.2.3 "$c"
  done
}

test_non_empty_out_dir_rejected_and_untouched() {
  local fx out; fx="$(make_fixture)"; out="$WORK/full.$RANDOM"
  mkdir "$out"; echo keep >"$out/.existing"
  expect_build_fail "$fx" "is not empty" "$out" v1.2.3 "$SHA"
  [ "$(list_files "$out")" = ".existing" ] || die "out-dir was modified"
}

test_out_dir_that_is_a_file_rejected() {
  local fx out; fx="$(make_fixture)"; out="$WORK/file.$RANDOM"
  echo x >"$out"
  expect_build_fail "$fx" "is not a directory" "$out" v1.2.3 "$SHA"
}

# ---------- build.sh: manifest and stub errors ----------

test_missing_manifest_path_rejected() {
  local fx out; fx="$(make_fixture)"; out="$WORK/o.$RANDOM"
  echo "docs/NOPE.md" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "manifest path does not exist: docs/NOPE.md" "$out" v1.2.3 "$SHA"
  [ ! -e "$out" ] || die "failed build left output behind"
}

test_missing_manifest_file_rejected() {
  local fx; fx="$(make_fixture)"
  rm "$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "manifest not found" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_manifest_path_escaping_repo_rejected() {
  local fx p; fx="$(make_fixture)"
  for p in /etc/passwd ../outside lang/../CLAUDE.md; do
    fx="$(make_fixture)"
    echo "$p" >>"$fx/bootstrap/manifest.txt"
    expect_build_fail "$fx" "must be relative" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  done
}

test_manifest_glob_is_not_expanded() {
  local fx; fx="$(make_fixture)"
  echo "lang/*.txt" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "manifest path does not exist: lang/*.txt" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_stub_same_path_as_manifest_entry_rejected() {
  local fx; fx="$(make_fixture)"
  echo "stub" >"$fx/bootstrap/stubs/CLAUDE.md"
  expect_build_fail "$fx" "stub overlaps manifest path (ambiguous source): CLAUDE.md" \
    "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_stub_inside_manifest_directory_rejected() {
  local fx; fx="$(make_fixture)"
  mkdir -p "$fx/bootstrap/stubs/lang/a"
  echo "stub" >"$fx/bootstrap/stubs/lang/a/new.txt"
  expect_build_fail "$fx" "stub overlaps manifest path (ambiguous source): lang/a/new.txt" \
    "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

# ---------- build.sh: output checks ----------

test_release_notes_in_output_rejected() {
  local fx out; fx="$(make_fixture)"; out="$WORK/o.$RANDOM"
  echo "docs/RELEASE_NOTES.md" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "forbidden path in output: docs/RELEASE_NOTES.md" "$out" v1.2.3 "$SHA"
  [ ! -e "$out" ] || die "failed build left output behind"
}

test_bootstrap_dir_in_output_rejected() {
  local fx; fx="$(make_fixture)"
  echo "bootstrap" >>"$fx/bootstrap/manifest.txt"
  expect_build_fail "$fx" "forbidden path in output: bootstrap/" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_bootstrap_stub_in_output_rejected() {
  local fx; fx="$(make_fixture)"
  mkdir -p "$fx/bootstrap/stubs/bootstrap"
  echo x >"$fx/bootstrap/stubs/bootstrap/x.sh"
  expect_build_fail "$fx" "forbidden path in output: bootstrap/" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_leftover_placeholder_rejected() {
  local fx out; fx="$(make_fixture)"; out="$WORK/o.$RANDOM"
  echo "built on {{TEMPLATE_DATE}}" >>"$fx/lang/b.txt"
  expect_build_fail "$fx" "placeholder left in output: lang/b.txt" "$out" v1.2.3 "$SHA"
  [ ! -e "$out" ] || die "failed build left output behind"
}

test_changelog_stub_without_placeholders_rejected() {
  # The stamp is the only link back to the template; losing it silently
  # would be worse than failing.
  local fx; fx="$(make_fixture)"
  printf '# Changelog\n\n## Created from template {{TEMPLATE_VERSION}}\n' \
    >"$fx/bootstrap/stubs/CHANGELOG.md"
  expect_build_fail "$fx" "CHANGELOG.md stub lacks {{TEMPLATE_COMMIT}}" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
  rm "$fx/bootstrap/stubs/CHANGELOG.md"
  expect_build_fail "$fx" "CHANGELOG.md stub not found" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_placeholder_outside_changelog_not_replaced() {
  # Only the CHANGELOG and script stubs are stamped; the same placeholder
  # anywhere else is left in and therefore fails the build.
  local fx; fx="$(make_fixture)"
  echo "{{TEMPLATE_VERSION}}" >>"$fx/CLAUDE.md"
  expect_build_fail "$fx" "placeholder left in output: CLAUDE.md" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

check_forbidden_in_manifest_file() {
  local s="$1" fx out
  fx="$(make_fixture)"; out="$WORK/o.$RANDOM"
  printf 'line with %s inside\n' "$s" >>"$fx/lang/a/x.txt"
  expect_build_fail "$fx" "in output file: lang/a/x.txt" "$out" v1.2.3 "$SHA"
  [ ! -e "$out" ] || die "failed build left output behind"
}

test_forbidden_trig_rejected()          { check_forbidden_in_manifest_file 'trig_abc123'; }
test_forbidden_pr_ref_rejected()        { check_forbidden_in_manifest_file 'see (PR #58)'; }
test_forbidden_pbi_id_rejected()        { check_forbidden_in_manifest_file 'PBI-1.10'; }
test_forbidden_open_question_rejected() { check_forbidden_in_manifest_file 'open question 3'; }

test_forbidden_string_in_stub_rejected() {
  local fx; fx="$(make_fixture)"
  echo "see PBI-4" >>"$fx/bootstrap/stubs/docs/BACKLOG.md"
  expect_build_fail "$fx" "in output file: docs/BACKLOG.md" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

test_forbidden_string_in_dotfile_rejected() {
  local fx; fx="$(make_fixture)"
  echo "trig_x" >>"$fx/lang/.hidden"
  expect_build_fail "$fx" "in output file: lang/.hidden" "$WORK/o.$RANDOM" v1.2.3 "$SHA"
}

# ---------- publish.sh (against local bare repos) ----------
# Bare repos are created with HEAD on main, like a new empty GitHub repo.

make_bootstrap_output() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/pubout.$RANDOM"
  build_ok "$fx" "$out" "$1" "$SHA"
  echo "$out"
}

test_publish_to_empty_repo_creates_first_commit_and_tag() {
  local remote out clone
  remote="$WORK/remote.$RANDOM.git"; git init -q --bare -b main "$remote"
  out="$(make_bootstrap_output v1.0.0)"
  bash "$PUBLISH" "$out" v1.0.0 "$SHA" "$remote" >/dev/null || die "publish failed"
  clone="$WORK/clone.$RANDOM"; git clone -q "$remote" "$clone"
  [ "$(git -C "$clone" rev-list --count HEAD)" = 1 ] || die "expected exactly one commit"
  [ "$(git -C "$clone" log -1 --format=%s)" = \
    "Bootstrapper v1.0.0 from factoincognito/ai-project-template-v2@$SHA" ] || die "bad commit message"
  [ "$(git -C "$clone" rev-parse "v1.0.0^{commit}")" = "$(git -C "$clone" rev-parse HEAD)" ] \
    || die "tag does not point at the release commit"
  diff <(git -C "$clone" ls-files | LC_ALL=C sort) <(list_files "$out") || die "tree differs"
}

test_publish_second_release_mirrors_output_and_keeps_history() {
  local remote out1 out2 clone
  remote="$WORK/remote.$RANDOM.git"; git init -q --bare -b main "$remote"
  out1="$(make_bootstrap_output v1.0.0)"
  echo "obsolete" >"$out1/obsolete.md"
  bash "$PUBLISH" "$out1" v1.0.0 "$SHA" "$remote" >/dev/null || die "publish 1 failed"
  out2="$(make_bootstrap_output v1.1.0)"
  bash "$PUBLISH" "$out2" v1.1.0 "$SHA" "$remote" >/dev/null || die "publish 2 failed"
  clone="$WORK/clone.$RANDOM"; git clone -q "$remote" "$clone"
  [ "$(git -C "$clone" rev-list --count HEAD)" = 2 ] || die "history not kept"
  [ ! -e "$clone/obsolete.md" ] || die "file not in output was not deleted"
  diff <(git -C "$clone" ls-files | LC_ALL=C sort) <(list_files "$out2") || die "tree differs"
  git -C "$clone" rev-parse -q --verify refs/tags/v1.0.0 >/dev/null || die "v1.0.0 tag gone"
  git -C "$clone" rev-parse -q --verify refs/tags/v1.1.0 >/dev/null || die "v1.1.0 tag missing"
}

test_publish_uses_existing_default_branch() {
  local remote seed out
  remote="$WORK/remote.$RANDOM.git"; git init -q --bare -b main "$remote"
  git -C "$remote" symbolic-ref HEAD refs/heads/trunk
  seed="$WORK/seed.$RANDOM"; git init -q -b trunk "$seed"
  echo seed >"$seed/seed.txt"; git -C "$seed" add .; git -C "$seed" -c user.name=test -c user.email=test@example.invalid commit -qm seed
  git -C "$seed" push -q "$remote" trunk
  out="$(make_bootstrap_output v1.0.0)"
  bash "$PUBLISH" "$out" v1.0.0 "$SHA" "$remote" >/dev/null || die "publish failed"
  [ "$(git -C "$remote" rev-list --count trunk)" = 2 ] || die "did not commit on trunk"
  ! git -C "$remote" rev-parse -q --verify refs/heads/main >/dev/null || die "created a main branch"
}

test_publish_fails_if_tag_exists_and_changes_nothing() {
  local remote out before
  remote="$WORK/remote.$RANDOM.git"; git init -q --bare -b main "$remote"
  out="$(make_bootstrap_output v1.0.0)"
  bash "$PUBLISH" "$out" v1.0.0 "$SHA" "$remote" >/dev/null || die "publish 1 failed"
  before="$(git -C "$remote" for-each-ref)"
  echo changed >"$out/CLAUDE.md"
  if bash "$PUBLISH" "$out" v1.0.0 "$SHA" "$remote" 2>"$WORK/perr" >/dev/null; then
    die "publish succeeded although tag exists"
  fi
  grep -qF "tag v1.0.0 already exists" "$WORK/perr" || { cat "$WORK/perr" >&2; die "bad message"; }
  [ "$(git -C "$remote" for-each-ref)" = "$before" ] || die "remote refs changed"
}

test_publish_rejects_bad_arguments() {
  local remote out
  remote="$WORK/remote.$RANDOM.git"; git init -q --bare -b main "$remote"
  out="$(make_bootstrap_output v1.0.0)"
  ! bash "$PUBLISH" "$out" 1.0.0 "$SHA" "$remote" 2>/dev/null || die "bad version accepted"
  ! bash "$PUBLISH" "$out" v1.0.0 abc "$remote" 2>/dev/null || die "bad commit accepted"
  ! bash "$PUBLISH" "$WORK/nope" v1.0.0 "$SHA" "$remote" 2>/dev/null || die "missing out-dir accepted"
  ! bash "$PUBLISH" "$out" v1.0.0 "$SHA" 2>/dev/null || die "missing remote accepted"
  [ -z "$(git -C "$remote" for-each-ref)" ] || die "remote changed"
}

# ---------- require-on-main.sh ----------
# A tagged commit may only be published if it is on main.

REQUIRE="$HERE/require-on-main.sh"

# A repo with main (two commits) and an unmerged side branch.
make_history_repo() {
  local d
  d="$(mktemp -d "$WORK/hist.XXXXXX")"
  git init -q -b main "$d"
  gc() { git -C "$d" -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }
  echo 1 >"$d/f"; gc add f; gc commit -qm one
  echo 2 >"$d/f"; gc commit -qam two
  gc checkout -q -b side
  echo 3 >"$d/f"; gc commit -qam unmerged
  gc checkout -q main
  echo "$d"
}

test_on_main_commit_on_main_accepted() {
  local d; d="$(make_history_repo)"
  bash "$REQUIRE" "$d" "$(git -C "$d" rev-parse main)" main >/dev/null || die "tip of main rejected"
  bash "$REQUIRE" "$d" "$(git -C "$d" rev-parse main~1)" main >/dev/null || die "older main commit rejected"
}

test_on_main_unmerged_commit_rejected() {
  local d; d="$(make_history_repo)"
  if bash "$REQUIRE" "$d" "$(git -C "$d" rev-parse side)" main 2>"$WORK/rerr" >/dev/null; then
    die "unmerged commit accepted"
  fi
  grep -qF "is not on main" "$WORK/rerr" || { cat "$WORK/rerr" >&2; die "bad message"; }
}

test_on_main_unknown_commit_rejected() {
  local d; d="$(make_history_repo)"
  if bash "$REQUIRE" "$d" "$SHA" main 2>"$WORK/rerr" >/dev/null; then
    die "unknown commit accepted"
  fi
  grep -qF "not found" "$WORK/rerr" || { cat "$WORK/rerr" >&2; die "bad message"; }
}

test_on_main_missing_ref_rejected() {
  local d; d="$(make_history_repo)"
  if bash "$REQUIRE" "$d" "$(git -C "$d" rev-parse main)" origin/main 2>"$WORK/rerr" >/dev/null; then
    die "missing ref accepted"
  fi
  grep -qF "ref origin/main not found" "$WORK/rerr" || { cat "$WORK/rerr" >&2; die "bad message"; }
}

test_on_main_bad_arguments_rejected() {
  local d; d="$(make_history_repo)"
  ! bash "$REQUIRE" "$d" abc main 2>/dev/null || die "bad commit accepted"
  ! bash "$REQUIRE" "$d" "$(git -C "$d" rev-parse main)" 2>/dev/null || die "missing arg accepted"
  ! bash "$REQUIRE" "$WORK/nope" "$SHA" main 2>/dev/null || die "missing repo accepted"
}

test_workflow_publish_requires_commit_on_main() {
  # The publish job must run the check against origin/main with full
  # history, before building or publishing.
  local wf="$REPO/.github/workflows/bootstrapper.yml"
  grep -qF 'fetch-depth: 0' "$wf" || die "publish checkout lacks fetch-depth: 0"
  grep -qE 'bootstrap/require-on-main\.sh .*origin/main' "$wf" || die "publish does not run require-on-main.sh against origin/main"
  awk '/require-on-main\.sh/ { c = NR } /bootstrap\/publish\.sh/ { p = NR } END { exit !(c && p && c < p) }' "$wf" \
    || die "on-main check does not come before publish.sh"
}

test_workflow_test_job_named_bootstrapper_test() {
  grep -qE '^  bootstrapper-test:' "$REPO/.github/workflows/bootstrapper.yml" || die "no bootstrapper-test job"
  grep -qE 'needs: \[bootstrapper-test, packs\]' "$REPO/.github/workflows/bootstrapper.yml" || die "publish does not need bootstrapper-test and packs"
}

test_workflow_publish_needs_the_pack_chain_test() {
  # The chain test (packs.yml) is a reusable workflow called on a tag,
  # and publish needs it, so a bootstrapper whose packs fail in a project
  # made from it is never published.
  local wf="$REPO/.github/workflows/bootstrapper.yml"
  grep -qE '^  packs:' "$wf" || die "no packs job in bootstrapper.yml"
  grep -qF 'uses: ./.github/workflows/packs.yml' "$wf" || die "packs job does not call packs.yml"
  grep -qE '^  workflow_call:' "$REPO/.github/workflows/packs.yml" || die "packs.yml is not callable"
}

test_workflow_bootstrapper_test_runs_the_require_test_change_tests() {
  # The check's own tests must run in a required check from the first PR
  # that adds them: the template-only bootstrapper-test job.
  local wf="$REPO/.github/workflows/bootstrapper.yml"
  awk '/^  bootstrapper-test:/ { inj = 1; next }
       /^  [a-z][a-z-]*:/ { inj = 0 }
       inj && /^ *run: bash tools\/test-require-test-change\.sh *$/ { found = 1 }
       END { exit !found }' "$wf" \
    || die "bootstrapper-test does not run tools/test-require-test-change.sh"
}

test_real_build_ships_the_require_test_change_script() {
  # The shared check ships byte for byte, through the manifest. The
  # tools/ folder that holds its tests does not.
  local out="$WORK/real.$RANDOM" f=".github/scripts/require-test-change.sh"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -f "$out/$f" ] || die "$f not shipped"
  cmp -s "$REPO/$f" "$out/$f" || die "$f shipped altered"
  [ ! -e "$out/tools" ] || die "tools/ shipped"
}

# ---------- bootstrap-project.sh (shipped as a stub) ----------
# The source is bootstrap/stubs/bootstrap-project.sh; stubs mirror the
# output, so it ships at the bootstrapper root, where packs are under
# languages/.

PROJECT_SCRIPT="$HERE/stubs/bootstrap-project.sh"

test_build_preserves_the_executable_bit_of_a_stub() {
  local fx out
  fx="$(make_fixture)"; out="$WORK/out.$RANDOM"
  printf '#!/usr/bin/env bash\necho hi\n' >"$fx/bootstrap/stubs/run.sh"
  chmod 755 "$fx/bootstrap/stubs/run.sh"
  build_ok "$fx" "$out" v1.2.3 "$SHA"
  [ -x "$out/run.sh" ] || die "build dropped the executable bit of a stub"
}

test_real_build_ships_the_project_script_stamped() {
  local out="$WORK/real.$RANDOM" f
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  f="$out/bootstrap-project.sh"
  grep -qxF "SCRIPT_VERSION='v2.1.0'" "$f" || die "shipped script lacks the version stamp"
  grep -qxF "SCRIPT_COMMIT='$SHA'" "$f" || die "shipped script lacks the commit stamp"
  ! grep -qF '{{TEMPLATE_' "$f" || die "placeholder left in the shipped script"
  [ -x "$f" ] || die "shipped script is not executable after stamping"
  ! grep -q $'\r' "$f" || die "shipped script has CR line endings"
}

test_project_script_holds_only_the_two_placeholder_assignments() {
  # The build fails on any {{TEMPLATE_ left in the output, and stamps
  # every one in this file. So the two assignments are the only place
  # the placeholders may appear: later code compares against
  # SCRIPT_VERSION, never against a literal placeholder.
  local f="$PROJECT_SCRIPT"
  [ -f "$f" ] || die "no $f"
  grep -qxF "SCRIPT_VERSION='{{TEMPLATE_VERSION}}'" "$f" || die "no SCRIPT_VERSION placeholder assignment"
  grep -qxF "SCRIPT_COMMIT='{{TEMPLATE_COMMIT}}'" "$f" || die "no SCRIPT_COMMIT placeholder assignment"
  [ "$(grep -oF '{{TEMPLATE_' "$f" | wc -l | tr -d ' ')" -eq 2 ] \
    || { grep -nF '{{TEMPLATE_' "$f" >&2; die "placeholder outside the two assignments"; }
}

test_unstamped_project_script_still_lays_out() {
  # In the template the script is never stamped (tools/layout-pack.sh
  # and packs.yml run it from bootstrap/stubs/), so the placeholder
  # values must not break it.
  local a="$WORK/unstamped.$RANDOM" b="$WORK/wrapper.$RANDOM"
  grep -qF '{{TEMPLATE_VERSION}}' "$PROJECT_SCRIPT" || die "the stub is not unstamped; this test checks nothing"
  PACKS_DIR="$REPO/languages" bash "$PROJECT_SCRIPT" layout-pack node "$a" >/dev/null \
    || die "unstamped script layout-pack failed"
  (unset PACKS_DIR; bash "$REPO/tools/layout-pack.sh" node "$b") >/dev/null || die "wrapper failed"
  diff -r "$a" "$b" >&2 || die "unstamped script and wrapper lay out different trees"
}

test_project_script_is_committed_executable_and_lf() {
  # .gitattributes cannot set the mode, so the index must hold 100755,
  # and the eol attribute must be lf.
  local mode eol
  git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "needs a git checkout"
  mode="$(git -C "$REPO" ls-files -s -- bootstrap/stubs/bootstrap-project.sh | cut -d' ' -f1)"
  [ "$mode" = 100755 ] || die "bootstrap/stubs/bootstrap-project.sh has mode '$mode' in the index, want 100755"
  eol="$(git -C "$REPO" check-attr eol -- bootstrap/stubs/bootstrap-project.sh | sed 's/.*: //')"
  [ "$eol" = lf ] || die "eol attribute is '$eol', want lf"
}

test_real_build_ships_the_project_script_at_the_root() {
  local out="$WORK/real.$RANDOM" f="bootstrap-project.sh"
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  [ -f "$out/$f" ] || die "$f not shipped at the root"
  [ -x "$out/$f" ] || die "$f shipped without the executable bit"
  ! grep -q $'\r' "$out/$f" || die "$f has CR line endings"
  head -n1 "$out/$f" | grep -qxF '#!/usr/bin/env bash' || die "$f has no bash shebang"
}

test_shipped_project_script_lays_out_from_its_own_languages_dir() {
  # At the bootstrapper root the script finds the packs in languages/
  # with no PACKS_DIR, and lays out what the template's wrapper does.
  local out="$WORK/real.$RANDOM" p a b
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  for p in node web python react-native; do
    a="$WORK/shipped.$p.$RANDOM"; b="$WORK/wrapper.$p.$RANDOM"
    (unset PACKS_DIR; cd "$WORK" && bash "$out/bootstrap-project.sh" layout-pack "$p" "$a") >/dev/null \
      || die "shipped script layout-pack $p failed"
    (unset PACKS_DIR; bash "$REPO/tools/layout-pack.sh" "$p" "$b") >/dev/null || die "wrapper $p failed"
    diff -r "$a" "$b" >&2 || die "$p: shipped script and wrapper lay out different trees"
  done
}

test_shipped_project_script_ignores_the_users_cdpath() {
  # The script finds itself with cd. A CDPATH in the user's environment
  # must not change where it looks (a decoy folder of the same name) or
  # make cd print the folder into the captured path, when it is called
  # by a relative path.
  local out="$WORK/real.$RANDOM" parent name decoy a b
  bash "$BUILD" "$out" v2.1.0 "$SHA" >/dev/null || die "real build failed"
  parent="$(dirname "$out")"; name="$(basename "$out")"
  decoy="$WORK/decoy.$RANDOM"; mkdir -p "$decoy/$name"
  b="$WORK/wrapper.$RANDOM"
  (unset PACKS_DIR; bash "$REPO/tools/layout-pack.sh" node "$b") >/dev/null || die "wrapper failed"
  # CDPATH holding the script's own parent: cd would print the folder.
  a="$WORK/cdp1.$RANDOM"
  (unset PACKS_DIR; cd "$parent" && CDPATH="$parent" bash "$name/bootstrap-project.sh" layout-pack node "$a") \
    >/dev/null || die "layout-pack failed with CDPATH set to the script's parent"
  diff -r "$a" "$b" >&2 || die "CDPATH (script's parent) changed the layout"
  # CDPATH holding a decoy folder with the same name: cd would go there.
  a="$WORK/cdp2.$RANDOM"
  (unset PACKS_DIR; cd "$parent" && CDPATH="$decoy" bash "$name/bootstrap-project.sh" layout-pack node "$a") \
    >/dev/null || die "layout-pack failed with CDPATH set to a decoy"
  diff -r "$a" "$b" >&2 || die "CDPATH (decoy) changed the layout"
}

test_project_script_avoids_listed_bash4_constructs() {
  # A partial static scan, not a proof of bash 3.2 compatibility (macOS
  # /bin/bash is 3.2). It refuses the bash 4+ constructs listed below in
  # every line that is not a full-line comment, plus `bash -n`. Anything
  # not listed passes; a real run on bash 3.2 comes with the OS matrix.
  # Each pattern comes with a sample it must match, so a broken pattern
  # fails the test instead of passing.
  local f="$PROJECT_SCRIPT" code="$WORK/code.$RANDOM" i
  local pats=() samples=()
  [ -f "$f" ] || die "no $f"
  bash -n "$f" || die "syntax error in $f"
  pats+=('(declare|local|typeset|readonly)[[:space:]]+-[a-zA-Z]*[Anlu]'); samples+=('local -A map')
  pats+=('(declare|typeset)[[:space:]]+-[a-zA-Z]*g'); samples+=('declare -g x=1')
  pats+=('\[\[?[[:space:]]+(!+[[:space:]]+)?-[vR][[:space:]]'); samples+=('[ -v x ] && :')
  pats+=('\{[A-Za-z_][A-Za-z0-9_]*\}[<>]'); samples+=('exec {fd}>/dev/null')
  pats+=('BASHPID|BASH_COMPAT|BASH_LOADABLES_PATH|READLINE_|COPROC|SRANDOM'); samples+=('echo "$BASHPID"')
  pats+=('%-?[0-9]*\([^)]*\)T'); samples+=("printf '%(%F)T' -1")
  pats+=('(declare|typeset|local)[[:space:]]+-[a-zA-Z]*I'); samples+=('local -I x')
  pats+=('shopt[[:space:]]+-s[[:space:]]+(checkjobs|direxpand|globasciiranges|inherit_errexit|localvar_inherit|assoc_expand_once)'); samples+=('shopt -s inherit_errexit')
  pats+=('\$\{[A-Za-z_][A-Za-z0-9_]*:[0-9]+:-[0-9]+\}'); samples+=('y="${x:2:-1}"')
  pats+=('read[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-[a-zA-Z]*N[[:space:]]'); samples+=('read -N 3 x')
  pats+=('\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?(,,?|\^\^?)'); samples+=('y="${x,,}"')
  pats+=('\$\{[A-Za-z_][A-Za-z0-9_]*@[QEPAaKkUuL]\}'); samples+=('y="${x@Q}"')
  pats+=('(^|[^A-Za-z0-9_])(mapfile|readarray|coproc)([^A-Za-z0-9_]|$)'); samples+=('mapfile -t lines')
  pats+=('&>>'); samples+=('cmd &>>log')
  pats+=('\|&'); samples+=('cmd |& tee log')
  pats+=(';;&|;&$|;&[[:space:]]'); samples+=('a) x ;;&')
  pats+=('shopt[[:space:]]+-s[[:space:]]+(globstar|lastpipe|autocd)'); samples+=('shopt -s globstar')
  pats+=('wait[[:space:]]+-n'); samples+=('wait -n')
  pats+=('read[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-[a-zA-Z]*i'); samples+=('read -e -i default x')
  pats+=('\$\{[A-Za-z_][A-Za-z0-9_]*\[-[0-9]+\]\}'); samples+=('y="${a[-1]}"')
  pats+=('EPOCHSECONDS|EPOCHREALTIME|BASH_ARGV0'); samples+=('t=$EPOCHSECONDS')
  pats+=('\{[0-9]+\.\.[0-9]+\.\.[0-9]+\}'); samples+=('for i in {1..9..2}')
  grep -nvE '^[[:space:]]*#' "$f" >"$code" || true
  [ "$(wc -l <"$code")" -ge 20 ] || die "found almost no code lines; the filter is broken"
  for i in "${!pats[@]}"; do
    printf '%s\n' "${samples[$i]}" | grep -qE -- "${pats[$i]}" \
      || die "pattern ${pats[$i]} misses its sample: ${samples[$i]}"
    ! grep -E -- "${pats[$i]}" "$code" >&2 || die "bash 4+ construct (${pats[$i]}) in $f"
  done
}

test_project_script_mentions_no_template_only_path() {
  # It ships to the bootstrapper and then to projects, where tools/,
  # bootstrap/ and the template-only workflows do not exist.
  local f="$PROJECT_SCRIPT"
  [ -f "$f" ] || die "no $f"
  ! grep -nE '(^|[^A-Za-z0-9_.-])(tools|bootstrap|stubs)/' "$f" >&2 || die "template-only folder named in $f"
  ! grep -nE 'packs\.yml|bootstrapper\.yml|manifest\.txt|test-layout-pack|layout-pack\.sh' "$f" >&2 \
    || die "template-only file named in $f"
}

test_project_script_passes_the_forbidden_string_checks() {
  local f="$PROJECT_SCRIPT"
  [ -f "$f" ] || die "no $f"
  ! grep -nE 'trig_|PBI-[0-9]|open question [0-9]' "$f" >&2 || die "forbidden pattern in $f"
  ! grep -nF '(PR #' "$f" >&2 || die "(PR # in $f"
  grep -qE 'https://github\.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG\.md' "$f" \
    || die "$f header does not link the spec by URL"
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
