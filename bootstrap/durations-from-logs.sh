#!/usr/bin/env bash
# durations-from-logs.sh: prints bootstrap/test-durations.txt from the
# Actions job logs of the bootstrap-project-test shards (PBI-1.22), so the
# shards can be split by measured duration.
#
# Usage: bash bootstrap/durations-from-logs.sh <os>=<log> ... >bootstrap/test-durations.txt
#   <os>   the matrix OS of that log (ubuntu-latest, macos-latest,
#          windows-latest); give every shard's log of every OS.
#   <log>  a job log, as gh api repos/OWNER/REPO/actions/jobs/<id>/logs
#          prints it: each line starts with an ISO timestamp.
#
# A test's time is its result line's timestamp ("ok   test_x" or
# "FAIL test_x") minus the timestamp of the result line before it, or of
# the start of the test step ("##[group]Run " for a step that is not an
# action) for the first test of a log (so the first test's time also
# holds the harness's start-up). A test runs once per OS in a run,
# so the logs of several runs can be given: a test's time on one OS is
# the mean over the logs it appears in. Prints a
# header "test <os>...", in the order ubuntu-latest, macos-latest,
# windows-latest, then one line per test, sorted, with tenths of a
# second (0 where an OS has no time: the harness weighs a 0 as the
# median). Exits 1 when a log has no test
# result. Carriage returns are ignored.
#
# Template-only: bootstrap/ is not in bootstrap/manifest.txt.
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "usage: bash bootstrap/durations-from-logs.sh <os>=<log> ..." >&2
  exit 2
fi

for a in "$@"; do
  case "$a" in
    ubuntu-latest=?* | macos-latest=?* | windows-latest=?*) ;;
    *) echo "durations-from-logs: not <os>=<log> with a known OS: $a" >&2; exit 2 ;;
  esac
  [ -r "${a#*=}" ] || { echo "durations-from-logs: cannot read ${a#*=}" >&2; exit 2; }
done

for a in "$@"; do
  printf '%s\t%s\n' "${a%%=*}" "${a#*=}"
done | LC_ALL=C awk -F'\t' '
  # seconds since midnight of a timestamp like 2026-10-26T22:22:18.0000000Z
  # (a run that crosses midnight adds a day: see below).
  function secs(ts,   h, m, s) {
    h = substr(ts, 12, 2) + 0; m = substr(ts, 15, 2) + 0; s = substr(ts, 18) + 0
    return h * 3600 + m * 60 + s
  }
  {
    os = $1; logf = $2; prev = ""; day = ""; n = 0
    while ((getline line < logf) > 0) {
      sub(/\r$/, "", line)
      if (line !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) continue
      sp = index(line, " ")
      ts = substr(line, 1, sp - 1); rest = substr(line, sp + 1)
      t = secs(ts)
      if (day != "" && substr(ts, 1, 10) != day) t += 86400
      if (day == "") day = substr(ts, 1, 10)
      if (prev == "" && rest ~ /^##\[group\]Run / && rest !~ /^##\[group\]Run [A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+@/) { prev = t; continue }
      if (prev != "" && (rest ~ /^ok   test_[A-Za-z0-9_]+$/ || rest ~ /^FAIL test_[A-Za-z0-9_]+$/)) {
        name = substr(rest, 6)
        sum[name, os] += t - prev; cnt[name, os]++
        names[name] = 1; n++
        prev = t
      }
    }
    close(logf)
    if (n == 0) { printf "durations-from-logs: no test results in %s\n", logf > "/dev/stderr"; bad = 1 }
  }
  END {
    if (bad) exit 1
    print "test ubuntu-latest macos-latest windows-latest"
    k = 0
    for (name in names) list[++k] = name
    # insertion sort (no asort in mawk or BSD awk)
    for (i = 2; i <= k; i++) { v = list[i]; j = i - 1; while (j > 0 && list[j] > v) { list[j + 1] = list[j]; j-- } list[j + 1] = v }
    for (i = 1; i <= k; i++) {
      name = list[i]; out = name
      split("ubuntu-latest macos-latest windows-latest", oses, " ")
      for (o = 1; o <= 3; o++) {
        if ((name, oses[o]) in sum) out = out " " sprintf("%.1f", sum[name, oses[o]] / cnt[name, oses[o]])
        else out = out " 0"
      }
      print out
    }
  }'
