<!--
How to keep this file. A session that changes what a field below says
updates this file in the same PR as that change, and sets "Last update"
to that day. Forward-looking only: where the project is, what comes next
and what stops it. History lives in Git, the backlog and the changelog,
not here. Keep the headings as they are: the product owner's overview of
all projects reads them.
-->

# Status

Last update: 2026-11-06

## Phase
Build and release. v2.8.5 is the latest release. On `main` since then, not yet released: new projects get the public edition of the product office's Rules as their rule set (PBI-1.38), and the template itself is bound to those Rules (#369).

## Current focus
PBI-1.41, due 2026-11-13: lint, format and line coverage (at least 80%) gates in `build` for this repository's own scripts. It is the dated condition of the template's sign-off to the Rules (`RULES.md` L § 7 (3)).

## Next step
PBI-1.41, then a release of what is on `main` (Adam creates the tag). Run 5 is still to come: someone who has never used a terminal or gh sets up a project from the bootstrapper's README alone.

## Blockers
None. acuteping waits until run 5 passes.
