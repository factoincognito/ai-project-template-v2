<!--
How to keep this file. A session that changes what a field below says
updates this file in the same PR as that change, and sets "Last update"
to that day. Forward-looking only: where the project is, what comes next
and what stops it. History lives in Git, the backlog and the changelog,
not here. Keep the headings as they are: the product owner's overview of
all projects reads them.
-->

# Status

Last update: 2026-10-28

## Phase
Build and release: the turn-key bootstrap script is built (v2.4.0); the fixes for end-to-end run 1 are released (v2.5.0, 2026-10-26), v2.6.0 adds `STATUS.md` to every new project, v2.7.0 (2026-10-27) the fixes for the repeated run 1, `--version` and a colour key, and v2.8.0 (2026-10-27, the fixes for run 1 on v2.7.0: typed-ahead keys dropped, four colours, plain stars, a blank line after questions), and v2.8.1 (2026-10-28) the fixes for run 2: two README steps and the npm check in WSL. v2.8.1 is published to the bootstrapper.

## Current focus
Getting the bootstrapper through Adam's end-to-end runs, which must pass before acuteping, the first real project, is created. v2.8.0 carries the fixes for run 1's findings; the Git Bash check confirmed the typed-ahead fix on Windows. Run 2 (Linux through WSL, 2026-10-27) passed `e2e-check.sh` with three findings, two README gaps in WSL and the script accepting the Windows npm there, all fixed in v2.8.1 (`docs/NEXT_SESSION.md`, Adam's to-do 2).

## Next step
Adam repeats run 2 in full on his Windows tablet (WSL from scratch, node pack) on v2.8.1, then does run 3 on a Mac.

## Blockers
Product Owner: the end-to-end runs (run 2 repeated on the tablet, runs 3 and 4, and run 5 with someone new to the terminal). PBI-1.17 stays `[NEXT]` and acuteping waits until they pass.
