# [PROJECT NAME] — Next Session Planning

**Last Updated:** 2026-10-02
**Author:** Clead (Tech Owner)
**Purpose:** Staging area for reasoning, revised assumptions, and plan-adaptation thoughts that aren't yet mature enough to be a PBI, a decision, a strategy update, or a vision-doc change. Complements `docs/BACKLOG.md` — it does not replace it. Discrete, scoped, actionable work belongs in the backlog as a PBI, not here.

**The rule that keeps this useful, not a junk drawer:** every entry below must get a disposition each session it's touched — promoted to a PBI, a decision, or a formal doc update; re-affirmed as still-next; or deleted as resolved/obsolete. This file is read and triaged at the start of every session (see `CLAUDE.md` session-start routine). It is not a substitute for the backlog — it's where things live before they're ready to become backlog items.

---

## Adam's to-do (things only Adam can do)

Written 2026-10-02 so nothing depends on anyone remembering. **The next Clead session lists this to Adam in its first reply and removes each line when Adam confirms it is done.** Agents cannot do these: the access proxy returns 403 on branch deletion and on the Actions and secrets settings, and branch protection and tokens are GitHub account settings.

1. **Start the new Clead session with `factoincognito/ai-project-template-v2` as its source, with push access.** A session bound to the old `sugose/` path cannot reach the moved repo. (The session attaches `factoincognito/ai-project-bootstrap` itself.)
2. **Answer two questions** (item 8): (a) `--resume` on a repo stamped by an older bootstrapper: refuse, or finish with the current script's tables? (b) Is holding every release tag until PBI-1.14's slice S15 merges acceptable (acuteping then waits for PBI-1.14, or is set up by hand)? Say "go" after answering and S1 and S3 start.
3. **Fix the bootstrapper's `main` protection** (item 7). In `factoincognito/ai-project-bootstrap`: Settings, Branches, the rule for `main`, Edit. Untick "Require a pull request before merging". Untick "Require status checks to pass before merging". Untick "Do not allow bypassing the above settings". Keep "Allow force pushes" and "Allow deletions" unticked (that is what blocks them). Save. Then tell the session; it re-reads the rule through the API. Why: the release publishes with one direct push of a new commit and the tag to `main`, which the current settings would reject.
4. **Confirm the publish token** (item 7). GitHub, your profile, Settings, Developer settings, Fine-grained tokens, open the token. Check: resource owner is `factoincognito`; repository access includes `ai-project-bootstrap`; Contents and Workflows are both read and write; it has not expired; if the org requires approval for tokens, an org owner has approved it. The menu names are from memory of GitHub's UI and were not checked against its docs. Agents cannot read the token, so seeing it work needs a real push: the first release, or the optional token-check job in item 7 (Adam decides whether he wants it).
5. **Delete two branches** in the template repo (Branches page, trash icon): `throwaway-red-check-pr` and `docs/next-session-old-clead-pending` (its content is in item 9, its PR was never opened).
6. **Decide two small things** (item 10): whether CLAUDE.md should say that only one Clead session works on the template at a time (and that every session starts by listing open PRs and non-main branches); and, for PBI-1.16, whether the setting changes (recommended, step 3) or the backlog text does.
7. **Later, when PBI-1.14 is built:** the end-to-end runs on throwaway repos, including PBI-1.17's red-then-`Test-exempt` pull request in a real project (PBI-1.17 stays `[NEXT]` until then); and pushing the release tag, which agents cannot do. No tag before items 3 and 4 are done.
8. **If an agent has to change files in your connected PC folder,** it asks for delete permission once per session (a failed pull left a stale `.git/index.lock` last time). Your PC clone of the template is behind main and its `origin` points at the org; the session fast-forwards it after you grant that.
9. **After the first release has published successfully (not before):** delete the old publish token `bootstrap-publish` in your GitHub token settings (the product-office session told you to wait for a successful release; which token that is was not checked), and tell the product-office session that the release is out. It waits for it and has no access to this repo's state except through you or this file (item 11).

---

## What waits for what

Written 2026-10-02 so the order does not have to be re-derived. "Clead" is the next Clead session.

| Step | Who | Blocked by |
|---|---|---|
| PBI-1.14 slices S1 and S3 | Clead (Opus Crog implementer) | Adam's two answers and "go" (to-do 2) |
| Rest of PBI-1.14, S15 last | Clead | S1 and S3 merged; each slice follows the PR loop |
| Bootstrapper `main` protection fixed | Adam | Nothing (to-do 3); Clead re-reads it through the API afterwards |
| Publish token confirmed | Adam | Nothing (to-do 4); only a real push proves it |
| Release prep PR (rename Unreleased, date it, add #113 to #120 and later) | Clead | Nothing, but write it just before the tag so it is complete |
| Release tag `v*` | Adam, from the Releases page | Release prep merged; to-do 3 and 4 done; **and Adam's answer to question 2(b)**: his 2026-10-01 order held the tag until PBI-1.14 is built, while the product-office session's handoff recommends releasing sooner. Do not pick between them. |
| Release verified | Clead, through the API: the workflow run succeeded, bootstrapper `main` has the new commit, the tag exists | The tag. An auth error in the publish step means the token: fix that before anything else is built on the pipeline. |
| Old token deleted, product-office session told | Adam | A verified release (to-do 9) |
| End-to-end runs on throwaway repos; PBI-1.17 to `[DONE]` | Adam runs, Clead reads the results | PBI-1.14 built (to-do 7) |
| acuteping created | Adam | The end-to-end runs |

---

## Current situation summary

As of 2026-10-02: v2.1.0 and v2.2.0 are released. Both repos live under
`factoincognito/` (item 7). The four language packs are tested on GitHub's
runners on every PR; reviews and merges are delegated (CLAUDE.md, "Change
execution model"). The test-first rule is in force at every level: the
shared check, the template's `build`, the pack CIs and the docs are all
merged. PBI-1.14 (the turn-key bootstrap script) is planned in 17 slices
and not built (item 8). Adam's order: PBI-1.14, then acuteping; no release
tag until item 7 closes. Several sessions worked on the template in
parallel on 2026-10-01 and 2026-10-02; Adam consolidates them into one new
session, which starts by reading this file, the open PRs and the branches.
Items below are open staging entries; resolved ones are removed as they
graduate (see the rule above).

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
**Update 2026-10-02 (Clead session on the moved repo, by API):**
- Adam reported (item 9, from another session) that `BOOTSTRAP_PUSH_TOKEN` is set and Actions is enabled on both repos. No agent can read either setting (the access proxy returns 403 on the Actions and secrets endpoints), so this stays Adam-reported. Whether the token can push is proven only by a push: `publish` runs only on a pushed `v*` tag and has no manual trigger. A failed push there is safe (`publish.sh` stops with "nothing was published").
- **The bootstrapper's `main` protection, as Adam set it on 2026-10-01 evening, would reject that push.** Read through the API: a pull request is required (0 approvals), the status check `build` is required, admins cannot bypass, force-push and deletion are blocked. `publish.sh` makes one atomic push of a new commit and the tag straight to `main`, which a required PR or a required check rejects when admins cannot bypass. Not tested by an actual push. PBI-1.16 Part 1 asked for only the force-push and deletion blocks, with no PR requirement. Fix, by Adam in that repo's branch settings: untick "Require a pull request before merging", untick "Require status checks to pass", untick the admin-bypass block; keep the force-push and deletion blocks. Then re-read it through the API. Also: the `build` job there is the stub CI, which has no steps, so requiring it protects nothing.
- A way to prove the token without a release: a manually run job in `bootstrapper.yml` that pushes a throwaway branch to the bootstrapper repo with the secret and deletes it. A small code PR, test-first, Crog reviews. Not started; Adam has not decided whether he wants it.
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
**Not started:** no slice is built yet. Adam answers the two questions and says go; then S1 and S3 start (S3 is independent), with an Opus Crog as implementer and an Opus reviewer for the code.


### 9. Pending from the previous Clead session (PBI-1.17 build), staged on Adam's request — new (2026-10-02)

**Why this exists:** Adam, 2026-10-02: too many parallel sessions work on the template, so every session stages what it has pending here and one new session consolidates. The session that wrote this was bound to the old `sugose/` path and cannot reach the moved repo's API, so it pushed this as a branch and could not open the PR.
**Already done, so not pending (checked against `main` d5c0f76, 2026-10-02):** #113 (CHANGELOG for #95 to #112), #114 (PBI-1.15 marked done), #116 (PBI-1.17 PR 4: the docs, the spec text fix and the decision row).
**Still pending:**
- **Item 7 can close.** Adam reported on 2026-10-02 that `BOOTSTRAP_PUSH_TOKEN` is set and Actions is enabled on both repos. That settles the first two conditions. The third (the token can still push to the bootstrapper repo) is only proven by the first publish: publish runs only on a pushed `v*` tag and has no manual trigger. Whoever closes item 7 lifts the hold, and looks at the first publish run before calling the token good.
- **Release prep.** `CHANGELOG.md` Unreleased does not list #113 to #120 (see item 10) or anything later. At release time, rename it to the next version and date it, as was done for 2.2.0. Clead's proposal is 2.3.0 (minor: bootstrapped projects gain the check and the pack CIs run it). The tags v2.1.0 and v2.2.0 exist, and publish refuses an existing tag. Agreed order (Adam, 2026-10-01): PBI-1.14 build, then Adam cuts the release tag, then Adam's end-to-end runs on throwaway repos, then acuteping.
- **PBI-1.17 stays `[NEXT]`** until Adam's end-to-end runs show the red-then-exempt PR behaving as specified (see its "Done when").
- **Not proven by any run yet (nothing claimed until one has run):** a real `pull_request` inside a bootstrapped project; the tag-push and `workflow_call` path of `packs.yml` (first release-tag run); real bash 3.2 and macOS/Windows git; the rendered job summary. The backlog already lists the first, third and fourth; the tag-push path is not in the backlog yet.
- **By Adam, by hand** (agent sessions get 403 on both): delete the branch `throwaway-red-check-pr` (from the closed #109), and push the release tag. PBI-1.16 Part 1 (protect `main` on the bootstrapper repo) is still open.
- **Process fact:** a session bound to the old owner path cannot attach the moved repo (same-name checkout clash), and the access proxy ignores any token it is given. Start a new session with `factoincognito/ai-project-template-v2` as its source.

### 10. Pending from the Clead session that built PBI-1.17 PR 4 and the PBI-1.14 plan — new (2026-10-02)

Written on Adam's request to consolidate parallel sessions. Item 9 is the other session's list; nothing here repeats it.
- **CHANGELOG Unreleased** lists nothing after #112. Missing: #113 to #120 (checked against the GitHub API on 2026-10-02: #113 added the entries up to #112 and, by the one-PR-behind rule, is not listed itself; #115, #117, #118, #119 and #120 only changed this file; #114 and #116 changed the backlog and the docs), and whatever merges after. See item 9 for the release plan.
- **Item 6** (the four CLAUDE.md wording nits) is still open; fold it into the next change that touches those sections. Two more non-blocking notes from Crog's review of #116, to fold into the next docs change: the decisions row says the script is "the first step of `build`" (it is the first step after the checkout), and one edited line in `docs/DEV_INFRASTRUCTURE.md` runs past the wrap width.
- **PBI-1.16 text** in the backlog says Part 1 needs "no pull-request requirement". Adam's actual protection differs (item 7). Either the setting changes (recommended) or the text does; decide when item 7 is dealt with.
- **PBI-1.14 spec meets the changed repo** in the places listed in item 8; the spec text itself is not corrected yet. Fix it in the slice that touches each place, not in a bulk edit.
- **Adam's PC clone** of the template was fast-forwarded to `01d39e4` on 2026-10-01 and is now behind; its `origin` points at the org. Agents cannot delete files in his connected folder unless he grants it per session: a failed pull left a stale `.git/index.lock` that needed that grant. Clean-up needed next time: fast-forward again.
- **Stale branches Adam deletes by hand** (agents get 403): `throwaway-red-check-pr` and `docs/next-session-old-clead-pending` (its content is in item 9; its PR was never opened).
- **Process question for Adam:** two sessions each wrote an item numbered 8 within hours, and a session on the old path wrote to a side branch. Does he want a rule in CLAUDE.md that only one Clead session works on the template at a time, and that every session starts by listing open PRs and non-main branches? Not written; his call.
- **Working practice that held up, kept as a reminder for the next session:** Crog agents on Opus review process, code and config changes and also merge; Sonnet Crog agents do merge-only runs; every merge is re-verified against the GitHub API by Clead, not taken from the agent's report.

### 11. From the product-office session's handoff, folded in — new (2026-10-02)

**Why this exists:** a Clead session that works on Adam's company structure (in a separate private repo, "product-office") left a handoff as a Project doc, `claude/HANDOFF-2026-10-02-consolidation.md`, not as a PR, because it was bound to the old `sugose/` path and could not write to this repo. The new Clead session can read that doc in the Project. It was written before #116 to #120 merged and it checked less than this file does. **Where it disagrees with this file, this file wins.** Its content that is not elsewhere here:
- **The boundary between sessions.** The product-office session works only in its own repo and learns template state from Adam or from this file. The template session owns the template and the bootstrapper. Private information (company structure, ideas, token expiry, library repos) stays in the product-office repo and never enters this public repo.
- **After a release, in this order:** verify it through the API (the table above), report the result to Adam, then Adam deletes the old token and tells the product-office session (to-do 9). That session's next steps depend on the release; Clead cannot reach it.
- **Its claim that this file's item 7 says the bootstrapper's `main` is not protected is out of date:** item 7 already records the protection as Adam set it, and why it would reject the release push. The facts in item 7 stand; to-do 3 is what changes it.
- **It recommends 2.3.0** for the release, the same number as item 9. Whether to cut it before PBI-1.14 is built is Adam's open question 2(b), not decided.
- **The gate for acuteping** is PBI-1.14 built plus Adam's end-to-end runs; the product-office repo has its own step for that.
- **Disposition of the Project doc:** once this item is triaged, the new session tells Adam the Project doc can be deleted from the Project. Agents do not delete it unasked.

---

## Items that do not change

- Every change goes through a PR; reviews follow the kind of change; merges are delegated to Crog once review passes and CI is green (CLAUDE.md, "Change execution model").
- Clead works with git and the GitHub API; the Chrome web editor is the fallback. From Clead's cloud session, branch deletion returns 403 and a tag push was refused (2026-09-30); Adam creates release tags from the Releases page.
- **Reaching GitHub from a Clead cloud session (all seen on 2026-10-02):**
  - Access is per attached repository. The session's source repo is attached at the start; any other (for example `factoincognito/ai-project-bootstrap`) is attached with the `add_repo` tool, then cloned. The `GH_TOKEN` in the environment is invalid by itself (`gh auth status` fails) and no token pasted into chat helps; the access proxy decides by repository path.
  - REST only. `gh pr list` and anything else that uses GraphQL returns 403; use `gh api repos/OWNER/REPO/pulls`, `…/commits/SHA/check-runs` and so on. Draft and ready-for-review, review threads and auto-merge have `…/ccr/…` routes (the 403 message lists them).
  - The proxy also returns 403 for the Actions and secrets endpoints, for branch deletion and for tag pushes. Those are Adam's, by hand.
  - Clones are shallow. The test-first check run locally exits 2 on a shallow clone; deepen with `git fetch --depth=400 origin main BRANCH` first. At most two git operations may run against a repo at once, so clone inline, never in parallel.
  - Crog agents: review of process, code and config runs in an agent started with `model: opus`; merge-only runs use the default model. The agent that merges re-checks CI first, and Clead re-verifies every merge against the API.
