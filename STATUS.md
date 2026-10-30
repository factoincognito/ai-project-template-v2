<!--
How to keep this file. A session that changes what a field below says
updates this file in the same PR as that change, and sets "Last update"
to that day. Forward-looking only: where the project is, what comes next
and what stops it. History lives in Git, the backlog and the changelog,
not here. Keep the headings as they are: the product owner's overview of
all projects reads them.
-->

# Status

Last update: 2026-10-30

## Phase
Build and release: the turn-key bootstrap script is built (v2.4.0); the fixes for end-to-end run 1 are released (v2.5.0, 2026-10-26), v2.6.0 adds `STATUS.md` to every new project, v2.7.0 (2026-10-27) the fixes for the repeated run 1, `--version` and a colour key, and v2.8.0 (2026-10-27, the fixes for run 1 on v2.7.0: typed-ahead keys dropped, four colours, plain stars, a blank line after questions), and v2.8.1 (2026-10-28) the fixes for run 2: two README steps and the npm check in WSL. v2.8.2 (2026-10-28) the fixes for the tablet run: a WSL step, GitHub's sign-in on a new device, the npm guide on Linux and in WSL, a keyboard note and the short restart command `--again`. v2.8.2 is published to the bootstrapper.

## Current focus
PBI-1.29 is built and merged (#306, #309, #310): the bootstrapper has its own README, the setup removes that README and the other packs' sections from each new project, and nothing that ships points to the template outside the record of origin. Release prep for v2.8.4 is done; after the tag, check that GitHub shows the bootstrapper's own README on its page. Runs 1 to 4 have passed. The C# base language pack (PBI-1.23): part 1 is done; part 2 (the bootstrap script offers the pack) waits until the end-to-end runs pass.

## Next step
Adam tags v2.8.4, then run 5.

## Blockers
Product Owner: a tester for run 5, someone new to the terminal. acuteping waits until run 5 passes.
