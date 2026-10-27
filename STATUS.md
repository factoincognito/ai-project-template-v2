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
Getting the bootstrapper through Adam's end-to-end runs, which must pass before acuteping, the first real project, is created. Run 1 on v2.7.0 (2026-10-27) passed `e2e-check.sh` but had three findings: input typed ahead answered the run offer, and two colour wishes (`docs/NEXT_SESSION.md`, Adam's to-do 2). Their fixes are #247 (in review) and #248 (being built).

## Next step
Clead merges #247 and #248 after review and CI, prepares v2.8.0, and Adam tags it; then Adam repeats run 1 on v2.8.0.

## Blockers
Product Owner: the end-to-end runs (run 1 once more on v2.8.0, then runs 2 to 4, and run 5 with someone new to the terminal). PBI-1.17 stays `[NEXT]` and acuteping waits until they pass.
