<!--
The format and upkeep of this file are set by Process P-9 § 6. Keep the
headings as they are: the product owner's overview of all projects reads
them.
-->

# Status

Last update: 2026-11-23

## Phase
Build and release. the last tag is v2.10.0 (2026-11-23, tag on `b728675`, release prep [#510](https://github.com/factoincognito/ai-project-template-v2/pull/510)); the one before, v2.9.4, shipped the Rules editions of 2026-11-19. v2.10.0 ships the `csharp` pack in the setup script and `bootstrap/e2e-check.sh` ([#502](https://github.com/factoincognito/ai-project-template-v2/pull/502), [#504](https://github.com/factoincognito/ai-project-template-v2/pull/504), [#507](https://github.com/factoincognito/ai-project-template-v2/pull/507)) and four Rules editions of 2026-11-23.

## Current focus
PBI-1.23, the C# pack, is done (moved to [`docs/BACKLOG-DONE.md`](https://github.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG-DONE.md)): its "Done when, part 2" (c) is met: the end-to-end run of the setup with `--pack csharp` passed on v2.10.0 on 2026-11-23 (run 6, `docs/NEXT_SESSION.md`). Then the rest of PBI-1.54, in the same file; and PBI-1.75, the setup's note about the .NET SDK with a minimum SDK version in the pack, whose spec Adam approved on 2026-11-23: it is built, reviewed and merged ([#519](https://github.com/factoincognito/ai-project-template-v2/pull/519)) and waits for the release (the newcomer pre-check on the commit to be released, then Adam's go).

## Next step
PBI-1.73 in [`docs/BACKLOG.md`](https://github.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG.md), due 2026-11-30: the one condition of the conditional accept after the incremental audit of 2026-11-23.

## Blockers
acuteping no longer waits for run 5; what else it waits for is kept in the product office.
