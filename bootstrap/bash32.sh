#!/usr/bin/env bash
# Builds GNU bash 3.2.57 from source and installs it as <folder>/bash
# (spec: docs/BACKLOG.md, PBI-1.26). The Bootstrapper workflow's bash 3.2
# leg runs the bootstrap script's tests with it on Linux, so the script
# stays checked against the bash that macOS ships (Apple's /bin/bash is
# 3.2) while the macOS leg is out of the matrix.
#
# Usage: bash bootstrap/bash32.sh <folder>
#
# Template-only: bootstrap/ is not in bootstrap/manifest.txt.
#
# Every failure prints one ::error:: line that says which it was (no
# download from either server, another hash, a failed build, another
# version) and exits 1 with nothing left in <folder>: the bash is
# installed only after the built one reports 3.2.
#
# Test hook: BASH32_SHA256 replaces the pinned hash, so the tests can
# serve a fake tarball. The workflows never set it.
set -euo pipefail

VERSION=3.2.57
# SHA-256 of bash-3.2.57.tar.gz. Checked against GNU's signature
# (bash-3.2.57.tar.gz.sig, made by Chet Ramey, key BB5869F064EA74AB in
# https://ftp.gnu.org/gnu/gnu-keyring.gpg) on 2026-11-03 before it was
# pinned here.
SHA256="${BASH32_SHA256:-3fa9daf85ebf35068f090ce51283ddeeb3c75eb5bc70b1a4a7cb05868bfe06a4}"
# GNU's server first, then its mirror redirector.
SERVERS="https://ftp.gnu.org/gnu/bash https://ftpmirror.gnu.org/gnu/bash"

fail() {
  echo "::error::$*"
  exit 1
}

if [ $# -ne 1 ]; then
  echo "usage: bash bootstrap/bash32.sh <folder>" >&2
  exit 2
fi
FOLDER="$1"
# The build runs in another folder, so keep a relative path usable.
case "$FOLDER" in /*) ;; *) FOLDER="$PWD/$FOLDER" ;; esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# The version a bash reports, as major.minor.
version_of() {
  "$1" -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'
}

# Download. --max-time caps each attempt (PBI-1.36): the file is 2.5 MB,
# so 120 s is far above a normal download, and a stalled one is given up
# instead of holding the job. With --retry 2 that is at most three
# attempts per server.
got=""
for server in $SERVERS; do
  if curl -fsSL --retry 2 --connect-timeout 30 --max-time 120 -o "$WORK/bash.tar.gz" "$server/bash-$VERSION.tar.gz"; then
    got=1
    break
  fi
  echo "Download from $server failed."
done
[ -n "$got" ] || fail "No download of bash-$VERSION.tar.gz from ftp.gnu.org or from its mirror ftpmirror.gnu.org."

# Only the file with the pinned hash is built.
actual="$(sha256_of "$WORK/bash.tar.gz")"
if [ "$actual" != "$SHA256" ]; then
  fail "The downloaded bash-$VERSION.tar.gz has SHA-256 $actual, not the pinned $SHA256; it was not built."
fi

# Build. -std=gnu89: bash 3.2.57 is pre-C99 code, which newer gcc versions
# reject (implicit function declarations are errors from gcc 14, and gcc 15
# compiles as C23 by default). It is part of CC, not only of CFLAGS: bash's
# build tools (support/bashversion.c, mkbuiltins.c) are compiled with
# CC_FOR_BUILD, which takes CC and not CFLAGS.
tar -xzf "$WORK/bash.tar.gz" -C "$WORK" || fail "The build failed: bash-$VERSION.tar.gz does not unpack."
cd "$WORK/bash-$VERSION" || fail "The build failed: no bash-$VERSION folder in the download."
if ! CC="gcc -std=gnu89" CFLAGS="-g -O2 -std=gnu89" ./configure --without-bash-malloc >"$WORK/configure.log" 2>&1; then
  tail -n 40 "$WORK/configure.log"
  fail "The build failed: ./configure."
fi
if ! make >"$WORK/make.log" 2>&1; then
  tail -n 40 "$WORK/make.log"
  fail "The build failed: make."
fi
[ -x ./bash ] || fail "The build failed: make made no bash."

got_version="$(version_of ./bash)" || fail "The built bash does not run."
if [ "$got_version" != "3.2" ]; then
  fail "The built bash reports version $got_version, not 3.2."
fi

mkdir -p "$FOLDER"
cp ./bash "$FOLDER/bash"
chmod +x "$FOLDER/bash"
echo "Built $("$FOLDER/bash" --version | sed -n 1p) into $FOLDER/bash."
