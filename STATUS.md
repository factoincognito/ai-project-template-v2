<!--
How to keep this file. A session that changes what a field below says
updates this file in the same PR as that change, and sets "Last update"
to that day. Forward-looking only: where the project is, what comes next
and what stops it. History lives in Git, the backlog and the changelog,
not here. Keep the headings as they are: the product owner's overview of
all projects reads them.
-->

# Status

Last update: 2026-11-07

## Phase
Build and release. v2.9.0 is tagged (2026-11-06): new projects get the public edition of the product office's Rules as their rule set (PBI-1.38), and the template itself is bound to those Rules (#369). On `main` since then, not yet released: lint and format gates in `build` and a line coverage gate at 80% in `bootstrapper-test` for this repository's own scripts (PBI-1.41).

## Current focus
The two defects that the newcomer pre-check found on v2.9.0 (p2.9.0-b and -c in `docs/NEXT_SESSION.md`): the steps in the Claude app after the setup. Then PBI-1.54: tests for the lines no test reaches, and the follow-ups of PBI-1.41's reviews.

## Next step
Fix p2.9.0-b and -c in a release Adam tags, then run the pre-check again on it. Run 5 comes after that: someone who has never used a terminal or gh sets up a project from the bootstrapper's README alone.

## Blockers
None. acuteping waits until run 5 passes.
