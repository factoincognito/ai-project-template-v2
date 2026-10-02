#!/usr/bin/env bash
# Lays out a language pack in a project directory, exactly as the README
# table "Creating a project from the template", step 2, says to by hand.
# Usage: bash tools/layout-pack.sh <node|web|python|react-native> <target-dir>
#
# Template-only: tools/ is not in bootstrap/manifest.txt. Used by
# .github/workflows/packs.yml to test each pack on a fresh project.
#
# A thin wrapper: the layout table and its checks live in one place, the
# layout-pack subcommand of bootstrap/stubs/bootstrap-project.sh, which
# ships at the bootstrapper root and reads the packs from languages/ next
# to it. In the template it sits in bootstrap/stubs/, so this wrapper
# points it at the template's languages/ folder.
# PACKS_DIR overrides where the packs are read from (for tests, and for
# laying out from a built bootstrapper).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKS_DIR="${PACKS_DIR:-$HERE/../languages}"
export PACKS_DIR

exec bash "$HERE/../bootstrap/stubs/bootstrap-project.sh" layout-pack "$@"
