<!--
The format and upkeep of this file are set by Process P-9 § 6. Keep the
headings as they are: the product owner's overview of all projects reads
them.
-->

# Status

Last update: 2026-11-23

## Phase
Build and release. v2.10.0 is prepared ([#510](https://github.com/factoincognito/ai-project-template-v2/pull/510)); the last tag, v2.9.4 (2026-11-23, tag on `f3a598c`), ships the Rules editions of 2026-11-19. v2.10.0 ships the `csharp` pack in the setup script and `bootstrap/e2e-check.sh` ([#502](https://github.com/factoincognito/ai-project-template-v2/pull/502), [#504](https://github.com/factoincognito/ai-project-template-v2/pull/504), [#507](https://github.com/factoincognito/ai-project-template-v2/pull/507)) and four Rules editions of 2026-11-23.

## Current focus
PBI-1.23 part 2 in [`docs/BACKLOG.md`](https://github.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG.md): the spec is approved by Adam ([#501](https://github.com/factoincognito/ai-project-template-v2/pull/501)) and its three PRs are merged ([#502](https://github.com/factoincognito/ai-project-template-v2/pull/502), [#504](https://github.com/factoincognito/ai-project-template-v2/pull/504), [#507](https://github.com/factoincognito/ai-project-template-v2/pull/507)). Open: its "Done when, part 2" (c), one end-to-end run of the setup with `--pack csharp` on a throwaway repository, which is Adam's call. Then the rest of PBI-1.54, in the same file.

## Next step
The product owner's decision on tagging v2.10.0: [#510](https://github.com/factoincognito/ai-project-template-v2/pull/510) is merged last, after the newcomer pre-check on `main`, and the tag follows, nothing merging in between. Then the product owner runs the setup with `--pack csharp` on a throwaway repository (PBI-1.23 "Done when, part 2" (c)). After that, PBI-1.73 in [`docs/BACKLOG.md`](https://github.com/factoincognito/ai-project-template-v2/blob/main/docs/BACKLOG.md), due 2026-11-30: the one condition of the conditional accept after the incremental audit of 2026-11-23.

## Blockers
acuteping no longer waits for run 5; what else it waits for is kept in the product office.
