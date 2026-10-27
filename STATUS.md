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
Build and release: the turn-key bootstrap script is built (v2.4.0); v2.5.0, with the fixes for end-to-end run 1, is released (2026-10-26) and published to the bootstrapper.

## Current focus
Getting the bootstrapper through Adam's end-to-end runs, which must pass before acuteping, the first real project, is created. v2.5.0 carries the fixes for all eleven findings of run 1; the repeated run shows whether they hold (`docs/NEXT_SESSION.md`, Adam's to-do 2).

## Next step
Adam repeats end-to-end run 1 on v2.5.0, as written in `docs/NEXT_SESSION.md` (Adam's to-do 2), and gives Clead the output of `bootstrap/e2e-check.sh`; Clead reads it and records the findings.

## Blockers
Product Owner: intent approval for `bootstrapper-test` to pass a pull request that changes only files no test reads without running the suites (PBI-1.22 part 1, #228, reviewed and green; `docs/NEXT_SESSION.md`, Adam's to-do 6).
Product Owner: whether tests of the test harness's own helpers may be added to `bootstrap/test-bootstrap-project.sh` by the CI speed-up (PBI-1.22, escalated on #224 after 3 review rounds; `docs/NEXT_SESSION.md`, Adam's to-do 5). #224 and #225 wait for the answer.
Product Owner: the end-to-end runs (run 1 repeated on v2.5.0, then runs 2 to 4, and run 5 with someone new to the terminal). PBI-1.17 stays `[NEXT]` and acuteping waits until they pass.
