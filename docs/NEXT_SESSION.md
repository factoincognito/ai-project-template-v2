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

### 8. PBI-1.14 build plan: 17 slices, first slice ready — new (2026-10-02)

**What this is:** a design draft by an Opus agent (read-only, from the approved spec and the repo as of PBI-1.17 done). Its repo claims come from reading files and are re-checked per slice; the spec is not changed by it.
**Slices (one PR each, test-first, each shown red before the implementation):**
- S1 layout table moves into `bootstrap/stubs/bootstrap-project.sh` (`layout-pack` subcommand); `tools/layout-pack.sh` becomes a wrapper. Ships.
- S2 `build.sh` stamps the script version and commit, in place (the current `sed > tmp; mv` drops the executable bit). Ships.
- S3 `packs.yml` uses the script's lockfile command (independent; touches `packs.yml` and `tools/test-layout-pack.sh`).
- S4 test harness `bootstrap/test-bootstrap-project.sh`, test hooks, message helpers, wired into `bootstrapper-test`.
- S5 `bootstrapper-test` becomes one aggregate check over an OS matrix (ubuntu, macOS, Windows).
- S6 inputs and validation. S7 guided preflight, local checks. S8 guided preflight, GitHub checks. S9 create and protect. S10 local tree. S11 fill placeholders. S12 lockfile, licence, CHANGELOG. S13 self-check, commit, push, PR. S14 wait, require `build`, merge, finish, report. S15 resume, failures, private repos.
- S16 `bootstrap/e2e-check.sh` (read-only checker for Adam's end-to-end runs). S17 docs and process, last.
**Critical path:** S1, S2, S4, S6 to S15, S17. S3 can start now; S5 after S4; S16 after S5.
**Cannot be verified in CI (Adam's end-to-end runs only):** GitHub timing and error texts after create, the protection PUT shape, private-repo clone and push, Git Bash prompts, `winget`, a lockfile made on Windows or macOS under `npm ci` on Linux, the unaided README run, and the red-then-`Test-exempt` PR in a real project.
**Spec meets changed repo (to fix in the slice named):** the placement-table tests in `bootstrap/test.sh` pin both READMEs (S17); `test_workflow_bootstrapper_test_runs_the_require_test_change_tests` conflicts with the aggregate design (S5); the setup PR's tree must keep `.github/scripts/require-test-change.sh` (S10); stamps from releases before the org move name the old owner, so older repos cannot be resumed (S15).
**First slice:** S1. Tests first: the layout table lives only in the script; the script's `layout-pack` output equals the wrapper's for every pack; non-empty target refused; usage and unknown pack exit 2; the real build ships the script at the root, executable and LF; the script is bash 3.2 compatible and mentions no template-only path.
**Questions for Adam (neither blocks S1):**
1. `--resume` on a repo stamped by an older bootstrapper version (including repos already made with "Use this template"): refuse, or finish with the current script's tables? Blocks only S15.
2. No release tag before S15 merges (a tag would publish a half-built script as the latest). Is that acceptable? It means acuteping waits for PBI-1.14 or is set up by hand.
**Not started:** no slice is built yet.

---

## Items that do not change

- Every change goes through a PR; reviews follow the kind of change; merges are delegated to Crog once review passes and CI is green (CLAUDE.md, "Change execution model").
- Clead works with git and the GitHub API; the Chrome web editor is the fallback. From Clead's cloud session, branch deletion returns 403 and a tag push was refused (2026-09-30); Adam creates release tags from the Releases page.
