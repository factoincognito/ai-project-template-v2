<!--
How to keep this file. A session that changes what a field below says
updates this file in the same PR as that change, and sets "Last update"
to that day. Forward-looking only: where the project is, what comes next
and what stops it. History lives in Git, the backlog and the changelog,
not here. Keep the headings as they are: the product owner's overview of
all projects reads them.
-->

# Status

Last update: 2026-10-27

## Phase
Build and release: the turn-key bootstrap script is built (v2.4.0); the fixes for end-to-end run 1 are released (v2.5.0, 2026-10-26), v2.6.0 adds `STATUS.md` to every new project, and v2.7.0 (2026-10-27, the fixes for the repeated run 1, `--version`, a colour key) is published to the bootstrapper.

## Current focus
Getting the bootstrapper through Adam's end-to-end runs, which must pass before acuteping, the first real project, is created. The repeated run 1 (2026-10-27) finished and showed Done when 4 and 6; v2.7.0 carries the fixes for its five findings (`docs/NEXT_SESSION.md`, Adam's to-do 2).

## Next step
Adam repeats run 1 once more on v2.7.0 (`docs/NEXT_SESSION.md`, Adam's to-do 2) and gives Clead the output of `e2e-check.sh`; Clead records the findings.

## Blockers
Product Owner: the end-to-end runs (run 1 repeated once more on v2.7.0, then runs 2 to 4, and run 5 with someone new to the terminal). PBI-1.17 stays `[NEXT]` and acuteping waits until they pass.
