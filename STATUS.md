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
Build and release: the turn-key bootstrap script is built (v2.4.0); the fixes for end-to-end run 1 are released (v2.5.0, 2026-10-26), and v2.6.0 (2026-10-27, `STATUS.md` in every new project) is published to the bootstrapper.

## Current focus
Getting the bootstrapper through Adam's end-to-end runs, which must pass before acuteping, the first real project, is created. v2.6.0 carries the fixes for all eleven findings of run 1; the repeated run (2026-10-27) finished and showed Done when 4 and 6, with five new findings (`docs/NEXT_SESSION.md`, Adam's to-do 2).

## Next step
Clead: fix the five findings of the repeated run 1 (2026-10-27; #235, #236, #237 and the r1e PR) and release them; then Adam repeats run 1 once more on that release (`docs/NEXT_SESSION.md`, Adam's to-do 2).

## Blockers
Product Owner: the end-to-end runs (run 1 repeated once more after the fixes, then runs 2 to 4, and run 5 with someone new to the terminal). PBI-1.17 stays `[NEXT]` and acuteping waits until they pass.
