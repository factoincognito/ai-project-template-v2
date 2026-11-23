<!--
The format and upkeep of this file are set by Process P-9 § 6. Keep the
headings as they are: the product owner's overview of all projects reads
them.
-->

# Status

Last update: 2026-11-23

## Phase
Build and release. the last tag is v2.11.0 (2026-11-23, tag on `721f49f`, release prep [#524](https://github.com/factoincognito/ai-project-template-v2/pull/524); the Bootstrapper run on the tag succeeded, `publish` included, and the bootstrapper repository carries the script at v2.11.0). v2.11.0 ships the setup's note about the .NET SDK and the pack's minimum SDK version (PBI-1.75, [#519](https://github.com/factoincognito/ai-project-template-v2/pull/519)) and the Rules edition `2026-11-23-b4bccd0`. The tag before it, v2.10.0, shipped the `csharp` pack in the setup script and `bootstrap/e2e-check.sh`.

## Current focus
PBI-1.23, the C# pack, is done (moved to [`docs/BACKLOG-DONE.md`](https://github.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG-DONE.md)): its "Done when, part 2" (c) is met: the end-to-end run of the setup with `--pack csharp` passed on v2.10.0 on 2026-11-23 (run 6, `docs/NEXT_SESSION.md`). PBI-1.75, the setup's note about the .NET SDK with a minimum SDK version in the pack, is done too (built, reviewed and merged in [#519](https://github.com/factoincognito/ai-project-template-v2/pull/519), released in v2.11.0; its two non-blocking follow-ups are PBI-1.76). Then the rest of PBI-1.54, in the same file. Adam is having a C# app designed as a final proof of concept in another session; this repository holds nothing about it.

## Next step
PBI-1.73 in [`docs/BACKLOG.md`](https://github.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG.md), due 2026-11-30: the one condition of the conditional accept after the incremental audit of 2026-11-23.

## Blockers
acuteping no longer waits for run 5; what else it waits for is kept in the product office.
