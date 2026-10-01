# [PROJECT NAME] — Next Session Planning

**Last Updated:** 2026-10-01
**Author:** Clead (Tech Owner)
**Purpose:** Staging area for reasoning, revised assumptions, and plan-adaptation thoughts that aren't yet mature enough to be a PBI, a decision, a strategy update, or a vision-doc change. Complements `docs/BACKLOG.md` — it does not replace it. Discrete, scoped, actionable work belongs in the backlog as a PBI, not here.

**The rule that keeps this useful, not a junk drawer:** every entry below must get a disposition each session it's touched — promoted to a PBI, a decision, or a formal doc update; re-affirmed as still-next; or deleted as resolved/obsolete. This file is read and triaged at the start of every session (see `CLAUDE.md` session-start routine). It is not a substitute for the backlog — it's where things live before they're ready to become backlog items.

---

## Current situation summary

As of the end of 2026-09-30: v2.1.0 is released and the bootstrapper is
published to sugose/ai-project-bootstrap (verified identical to a local
build). The template has four language packs (node, web, python,
react-native), each tested on GitHub's runners on every PR. Reviews and
merges are delegated (CLAUDE.md, "Change execution model"). Apart from the PR
carrying this update, no PRs are open. The next big step is Adam bootstrapping acuteping, which also
closes PBI-1.10. Items below are open staging entries; resolved ones are
removed as they graduate (see the rule above).

---

## What needs adapting

### 1. Apply v2 workflows and rules on all other projects — new

**Previous assumption:** n/a — new idea.
**Revised assessment:** not yet evaluated.
**Impact on plan:** unknown — could mean porting CLAUDE.md/memory structure, the PIN workflow, the Change execution model, etc. to other repos.
**Action:** discuss scope with Adam — which projects, which parts of the v2 workflow, and whether "apply" means copy-once or keep-in-sync.

### 2. What can be done from the mobile phone — new

**Previous assumption:** n/a — new idea.
**Revised assessment:** not yet evaluated.
**Impact on plan:** unknown — likely about Cowork/Claude mobile access to this workflow, not a repo change per se.
**Action:** clarify with Adam what "done" means here (read-only checks? approvals? full sessions?) before scoping any work.

### 3. Can the AI portions of v2 be ported to another AI than Claude (Cowork/Code) — new

**Previous assumption:** n/a — new idea.
**Revised assessment:** not yet evaluated.
**Impact on plan:** could affect how much of CLAUDE.md/roles.md is Claude-specific vs. portable; potentially a significant scoping question.
**Action:** discuss with Adam what's driving this (contingency planning? vendor flexibility?) before analyzing portability.

### 4. De-Adamify the v2 end-product — new

**Previous assumption:** n/a — new idea.
**Revised assessment:** not yet evaluated.
**Impact on plan:** would mean genericizing Adam-specific references (roles.md, CLAUDE.md, etc.) into a productized template component.
**Action:** clarify scope with Adam — is this about this template repo specifically, or a downstream product? What stays as example content vs. becomes configurable?

### 5. Simplifications to process due to no longer needed workflows/workflow steps — new

**Previous assumption:** n/a — new idea.
**Revised assessment:** not yet evaluated. Likely prompted by this session's discovery that some process steps (e.g. routing doc-only changes through Crog) were unnecessary/obsolete once the Chrome-direct path was proven.
**Action:** next session, audit CLAUDE.md/docs/ROUTINES.md for other steps that may now be redundant given the Change execution model split.

### 6. CLAUDE.md wording nits from the #89 review — new (2026-10-01)

**What happened:** the Opus review of #89 approved it and listed four small notes that were not fixed there.
**Notes:**
- `..wrap` step 2 names only the three memory files as destinations; a pin promoted to a backlog item or a NEXT_SESSION entry has no named destination.
- "Model and effort" does not say which model a Crog agent started for an implementation task uses; "the default model" is defined only for Clead sessions (this gap predates #89).
- In "Working unattended", "Work that does not depend on it carries on": "it" is ambiguous after the longer list.
- Rule 3 says "System, process and architecture changes"; the model wording says "process and architecture" and drops "system".
**Action:** fold these into the next change that touches those CLAUDE.md sections, or drop them if Adam judges them not worth a PR. Delete this item when done.

### 7. Repo move to the `factoincognito` org: publish setup not yet verified — new (2026-10-01)

**What happened:** both repos moved from `sugose/` to `factoincognito/` on 2026-10-01 (`ai-project-template-v2` and `ai-project-bootstrap`). GitHub redirects the old paths. All live references were repointed in PR #112. `sugose/ai-project-template` (v1) did not move.
**Verified through the GitHub API on 2026-10-01:** template `main` protection survived (PR required; `build` and `bootstrapper-test` required; applies to admins; no force-push or deletion); "delete head branches on merge" is on; the bootstrapper is still a template repository with identical refs (`main` 567ed2e, tags v2.1.0 and v2.2.0); the bootstrapper's `main` is not protected (it was not before the move; PBI-1.16 Part 1).
**Not verified (Clead's session cannot read Actions settings or secrets):**
- the Actions secret `BOOTSTRAP_PUSH_TOKEN` exists on the template repo, and its token can still push to `factoincognito/ai-project-bootstrap`. PR #112 says a new token was to be created for the new path; Adam checks the token's own settings.
- Actions is enabled on both repos.
**Hold until those are confirmed:** the next release tag (a pushed `v*` tag runs publish against the bootstrapper repo), Adam's end-to-end runs on throwaway repos, and creating acuteping.
**Do not** create a repository under `sugose` named `ai-project-template-v2` or `ai-project-bootstrap`: GitHub deletes the redirect permanently.
**Action:** when Adam confirms the token and Actions, record it here and delete this item. If the token cannot push, fix it before any tag.

---

## Items that do not change

- Every change goes through a PR; reviews follow the kind of change; merges are delegated to Crog once review passes and CI is green (CLAUDE.md, "Change execution model").
- Clead works with git and the GitHub API; the Chrome web editor is the fallback. From Clead's cloud session, branch deletion returns 403 and a tag push was refused (2026-09-30); Adam creates release tags from the Releases page.
