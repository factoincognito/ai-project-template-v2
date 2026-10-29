<!--
How to keep this file. A session that changes what a field below says
updates this file in the same PR as that change, and sets "Last update"
to that day. Forward-looking only: where the project is, what comes next
and what stops it. History lives in Git, the backlog and the changelog,
not here. Keep the headings as they are: the product owner's overview of
all projects reads them.
-->

# Status

Last update: 2026-10-29

## Phase
Build and release: the turn-key bootstrap script is built (v2.4.0); the fixes for end-to-end run 1 are released (v2.5.0, 2026-10-26), v2.6.0 adds `STATUS.md` to every new project, v2.7.0 (2026-10-27) the fixes for the repeated run 1, `--version` and a colour key, and v2.8.0 (2026-10-27, the fixes for run 1 on v2.7.0: typed-ahead keys dropped, four colours, plain stars, a blank line after questions), and v2.8.1 (2026-10-28) the fixes for run 2: two README steps and the npm check in WSL. v2.8.2 (2026-10-28) the fixes for the tablet run: a WSL step, GitHub's sign-in on a new device, the npm guide on Linux and in WSL, a keyboard note and the short restart command `--again`. v2.8.2 is published to the bootstrapper.

## Current focus
PBI-1.29: the bootstrapper gets its own README and needs nothing from the template. The spec and the full draft of that README are in PR #304 and wait for Adam's confirmation before anything is built. Runs 1 to 4 have passed (run 3 again on v2.8.3, 2026-10-29); run 5 comes after the release of PBI-1.29. The C# base language pack (PBI-1.23): part 1 is done; part 2 (the bootstrap script offers the pack) waits until the end-to-end runs pass.

## Next step
PBI-1.29 (the bootstrapper needs nothing from the template), then a release, then run 5: someone who has never used a terminal or `gh` sets up a project from the README alone. Runs 1 to 4 have passed (run 3 on v2.8.3, 2026-10-29).

## Blockers
Product Owner: confirm the PBI-1.29 spec and the bootstrapper's README draft in PR #304; nothing is built before that.
Product Owner: a tester for run 5, someone new to the terminal. acuteping waits until run 5 passes.
