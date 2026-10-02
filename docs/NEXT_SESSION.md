# [PROJECT NAME] — Next Session Planning

**Last Updated:** 2026-10-02
**Author:** Clead (Tech Owner)
**Purpose:** Staging area for reasoning, revised assumptions, and plan-adaptation thoughts that aren't yet mature enough to be a PBI, a decision, a strategy update, or a vision-doc change. Complements `docs/BACKLOG.md` — it does not replace it. Discrete, scoped, actionable work belongs in the backlog as a PBI, not here.

**The rule that keeps this useful, not a junk drawer:** every entry below must get a disposition each session it's touched — promoted to a PBI, a decision, or a formal doc update; re-affirmed as still-next; or deleted as resolved/obsolete. This file is read and triaged at the start of every session (see `CLAUDE.md` session-start routine). It is not a substitute for the backlog — it's where things live before they're ready to become backlog items.

---

## Adam's to-do (things only Adam can do)

Written 2026-10-02 so nothing depends on anyone remembering. **Each Clead session lists this to Adam in its first reply and removes each line when Adam confirms it is done.** Agents cannot do these: the access proxy returns 403 on branch deletion, tag pushes and the Actions and secrets settings, and branch protection and tokens are GitHub account settings.

1. **Decide** (item 10) whether CLAUDE.md should say that only one Clead session works on the template at a time, and that every session starts by listing open PRs and non-main branches.
2. **Later, when PBI-1.14 is built:** after S15 merges, the next release tag, which agents cannot do; then the end-to-end runs on throwaway repos, including PBI-1.17's red-then-`Test-exempt` pull request in a real project (PBI-1.17 stays `[NEXT]` until then).
3. **If an agent has to change files in your connected PC folder,** it asks for delete permission once per session (a failed pull left a stale `.git/index.lock` last time). Your PC clone of the template is behind main and its `origin` points at the org; the session fast-forwards it after you grant that.

---

## What waits for what

Written 2026-10-02 so the order does not have to be re-derived. "Clead" is the next Clead session.

| Step | Who | Blocked by |
|---|---|---|
| Rest of PBI-1.14 (S4 next), S15 last | Clead (Opus Crog implementer, Opus review) | Nothing; S1, S2 and S3 merged 2026-10-02. Each slice follows the PR loop |
| Release prep PR for the next release (put the version heading over Unreleased, as #76 and #126 did) | Clead | S15 merged; written just before the tag so it is complete |
| Next release tag `v*` | Adam, from the Releases page | Release prep merged (decision of 2026-10-02: no tag until S15 merges) |
| Release verified | Clead, through the API: the tag run's checks passed, bootstrapper `main` has the new commit, the tag exists on both repos | The tag |
| End-to-end runs on throwaway repos; PBI-1.17 to `[DONE]` | Adam runs, Clead reads the results | PBI-1.14 built and released (to-do 2) |
| acuteping created | Adam | The end-to-end runs |

---

## Current situation summary

As of 2026-10-02: v2.1.0, v2.2.0 and v2.3.0 are released. v2.3.0 is the
first release from the `factoincognito` org; Clead verified it through the
API (tag run green including `publish` and the pack chain, bootstrapper
`main` at the new commit, tag on both repos), which also proved the new
publish token and the tag path of `packs.yml`. The four language packs are
tested on GitHub's runners on every PR; reviews and merges are delegated
(CLAUDE.md, "Change execution model"). The test-first rule is in force at
every level. PBI-1.14 (the turn-key bootstrap script) is planned in 17
slices and not built (item 8). Adam's order: PBI-1.14, with no tag until
S15 merges, then the end-to-end runs, then acuteping. The parallel
sessions of 2026-10-01 and 2026-10-02 were consolidated into one session
on 2026-10-02.
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

### 8. PBI-1.14 build plan: 17 slices, first slice ready — new (2026-10-02)

**What this is:** a design draft by an Opus agent (read-only, from the approved spec and the repo as of PBI-1.17 done). Its repo claims come from reading files and are re-checked per slice; the spec is not changed by it.
**Slices (one PR each, test-first, each shown red before the implementation):**
- S1 layout table moves into `bootstrap/stubs/bootstrap-project.sh` (`layout-pack` subcommand); `tools/layout-pack.sh` becomes a wrapper. Ships. **Done: #131, 2026-10-02.**
- S2 `build.sh` stamps the script version and commit, in place (the current `sed > tmp; mv` drops the executable bit). Ships. **Done: #133, 2026-10-02.**
- S3 `packs.yml` uses the script's lockfile command (independent; touches `packs.yml` and `tools/test-layout-pack.sh`). **Done: #130, 2026-10-02.**
- S4 test harness `bootstrap/test-bootstrap-project.sh`, test hooks, message helpers, wired into `bootstrapper-test`. **Done: #136, 2026-10-02.**
- S5 `bootstrapper-test` becomes one aggregate check over an OS matrix (ubuntu, macOS, Windows).
- S6 inputs and validation. S7 guided preflight, local checks. S8 guided preflight, GitHub checks. S9 create and protect. S10 local tree. S11 fill placeholders. S12 lockfile, licence, CHANGELOG. S13 self-check, commit, push, PR. S14 wait, require `build`, merge, finish, report. S15 resume, failures, private repos.
- S16 `bootstrap/e2e-check.sh` (read-only checker for Adam's end-to-end runs). S17 docs and process, last.
**Critical path:** S1, S2, S4, S6 to S15, S17. S3 can start now; S5 after S4; S16 after S5.
**Cannot be verified in CI (Adam's end-to-end runs only):** GitHub timing and error texts after create, the protection PUT shape, private-repo clone and push, Git Bash prompts, `winget`, a lockfile made on Windows or macOS under `npm ci` on Linux, the unaided README run, and the red-then-`Test-exempt` PR in a real project.
**Spec meets changed repo (to fix in the slice named):** the placement-table tests in `bootstrap/test.sh` pin both READMEs (S17); `test_workflow_bootstrapper_test_runs_the_require_test_change_tests` conflicts with the aggregate design (S5); the setup PR's tree must keep `.github/scripts/require-test-change.sh` (S10); stamps from releases before the org move name the old owner, so older repos cannot be resumed (S15).
**Next slice:** S5 or S6 (S6 is on the critical path).
**Questions for Adam (neither blocks S1):**
1. Answered by Adam, 2026-10-02 (`memory/decisions.md`): `--resume` refuses a repo stamped by an older bootstrapper version and tells the user to create a fresh repo; a repo stamped by the current version, including one made with "Use this template" from the current release, still resumes. The spec text is corrected in S15.
2. Answered by Adam, 2026-10-02: v2.3.0 is released before S1 (nothing of PBI-1.14 ships in it), then no tag until S15 merges. acuteping waits for PBI-1.14 and the end-to-end runs either way (decision of 2026-10-01).
**Started 2026-10-02:** Adam answered question 1 and said go. S1 (#131) and S3 (#130) merged the same day, then S2 (#133); each was built test-first by an Opus Crog and approved by an Opus review (S1 and S2 after a second round that fixed tests which could not fail).
**Review notes deferred to later slices (non-blocking):**
- Still open after S2 and S4, no slice assigned: the S3 test in `tools/test-layout-pack.sh` only sees `npm install` in single-line `run:` steps; one inside a `run: |` block passes unnoticed (#130 review).
- S6 to S8 (the first slice that calls `run_gh`): `bypass_lines` exempts a whole line when anything on it captures or redirects, not just the command. `run_gh pr create --body-file <(…)`, `run_gh pr checks $(…)`, `cat<"$file"` and `relay() { cat; }` pass, and a direct `"${BOOTSTRAP_GH:-gh}"` call is not flagged. Tighten the check or add these to its "Not covered" list (#136 review, A).
- Any slice that adds `say_command` calls: the command-argument check sees only the first call on a line and only the first word of its argument (#136 review, B).
- Any slice that builds messages from variables: a banned word in a one-word variable value, or an unquoted word passed to an unlisted helper, is not seen. The harness header comment should say one-word values are not covered (#136 review, C).
- S8: the literal scan has no opt-out, so matching gh's error text (e.g. `"Repository not found"`) fails the harness. S8 needs an opt-out marker for `literal_strings`, with a self-test, not rewording around the check (#136 review, D).
- S17: the expected-paths list in `tools/test-layout-pack.sh` (the per-file layout test) is a deliberate third statement of the placement table, next to the script and the README tables; change it together with the README tables (#131 review). `languages/README.md` still says the table lives in `tools/layout-pack.sh` (also S17).
- Any slice that touches the script's usage text: run through the wrapper, the usage message names `bootstrap-project.sh layout-pack`, not the command the user typed (#131 review, cosmetic).
- S5: a real bash 3.2 run in CI. A reviewer ran the built script once under a self-built bash 3.2.57 on Linux (all four packs identical); macOS `/bin/bash` and Git for Windows bash are unverified.


### 9. Pending from the previous Clead session (PBI-1.17 build), staged on Adam's request — new (2026-10-02)

**Why this exists:** Adam, 2026-10-02: too many parallel sessions work on the template, so every session stages what it has pending here and one new session consolidates. The session that wrote this was bound to the old `sugose/` path and cannot reach the moved repo's API, so it pushed this as a branch and could not open the PR.
**Already done, so not pending (checked against `main` d5c0f76, 2026-10-02):** #113 (CHANGELOG for #95 to #112), #114 (PBI-1.15 marked done), #116 (PBI-1.17 PR 4: the docs, the spec text fix and the decision row).
**Still pending:**
- **PBI-1.17 stays `[NEXT]`** until Adam's end-to-end runs show the red-then-exempt PR behaving as specified (see its "Done when").
- **Not proven by any run yet (nothing claimed until one has run):** a real `pull_request` inside a bootstrapped project; real bash 3.2 and macOS/Windows git; the rendered job summary. The backlog lists all three. (The tag-push and `workflow_call` path of `packs.yml` ran green in the v2.3.0 release.)
- **Process fact:** a session bound to the old owner path cannot attach the moved repo (same-name checkout clash), and the access proxy ignores any token it is given. Start a new session with `factoincognito/ai-project-template-v2` as its source.

### 10. Pending from the Clead session that built PBI-1.17 PR 4 and the PBI-1.14 plan — new (2026-10-02)

Written on Adam's request to consolidate parallel sessions. Item 9 is the other session's list; nothing here repeats it.
- **Item 6** (the four CLAUDE.md wording nits) is still open; fold it into the next change that touches those sections. Two more non-blocking notes from Crog's review of #116, to fold into the next docs change: the decisions row says the script is "the first step of `build`" (it is the first step after the checkout), and one edited line in `docs/DEV_INFRASTRUCTURE.md` runs past the wrap width.
- **PBI-1.14 spec meets the changed repo** in the places listed in item 8; the spec text itself is not corrected yet. Fix it in the slice that touches each place, not in a bulk edit.
- **Adam's PC clone** of the template was fast-forwarded to `01d39e4` on 2026-10-01 and is now behind; its `origin` points at the org. Agents cannot delete files in his connected folder unless he grants it per session: a failed pull left a stale `.git/index.lock` that needed that grant. Clean-up needed next time: fast-forward again.
- **Process question for Adam:** two sessions each wrote an item numbered 8 within hours, and a session on the old path wrote to a side branch. Does he want a rule in CLAUDE.md that only one Clead session works on the template at a time, and that every session starts by listing open PRs and non-main branches? Not written; his call.
- **Working practice that held up, kept as a reminder for the next session:** Crog agents on Opus review process, code and config changes and also merge; Sonnet Crog agents do merge-only runs; every merge is re-verified against the GitHub API by Clead, not taken from the agent's report.

### 11. From the product-office session's handoff, folded in — new (2026-10-02)

**Why this exists:** a Clead session that works on Adam's company structure (in a separate private repo, "product-office") left a handoff as a Project doc, not as a PR, because it was bound to the old `sugose/` path and could not write to this repo. The consolidation session checked it against GitHub, found it overtaken by this file, and deleted it from the Project on Adam's instruction (2026-10-02). Its content that is not elsewhere here:
- **The boundary between sessions.** The product-office session works only in its own repo and learns template state from Adam or from this file. The template session owns the template and the bootstrapper. Private information (company structure, ideas, token expiry, library repos) stays in the product-office repo and never enters this public repo.
- **The gate for acuteping** is PBI-1.14 built plus Adam's end-to-end runs; the product-office repo has its own step for that.

### 12. Clead in Code for good, or back to Cowork? — new (2026-10-02)

**What this is:** Adam wants to discuss the pros and cons with Clead in Cowork after the temporary period ends (2026-10-05, 13:00 UTC). Until then Clead runs in a Claude Code cloud session (`memory/decisions.md`, 2026-10-02). Input gathered so far:
- **What worked from a Code cloud session:** git, the GitHub API, PRs, a separate review session on Opus, and Crog merge subagents. A subagent hands its result straight back; a separate session does not report back and has to be checked on.
- **Review independence rests on the same rule on both** (`memory/standards.md` section 7: a separate invocation with scoped inputs). A different product does not add to it. A different model for the reviewer may, but only if the author runs on a different model: with Clead on Opus, an Opus reviewer is the same model.
- **CLAUDE.md assigns roles by surface** ("Crog (Claude Code)", "Clead (Claude app)"). Staying on Code needs that wording changed.
- **Tools:** compare what Clead uses in Cowork with what a Code session has. For example, CLAUDE.md names the Chrome extension as Clead's fallback channel.
- **Token use, Adam's open question:** does Code use more or fewer tokens than Cowork for the same task, small or large? Not measured on either side. Two data points for Code, from the sessions' own usage metadata (`get_session`, list price): the first turn of a trivial task read about 48k tokens of context (system prompt, tools, CLAUDE.md) before its first action, and the round-2 Opus review of #136 cost about $1.73. Run the same task in both before deciding.
- **Adam's hypothesis:** Code on Code is likely more token-intensive than Cowork on Code, because Cowork is better at bouncing ideas around, discussion and documentation, which is everyday work here. Not measured.
- **Clead's input, from the Code session of 2026-10-02:** that session was mostly discussion and docs, plus subagents. Over about 2 hours it cost about $9.51 at list price, read about 21M tokens from cache, and ended with about 286k tokens of context (session usage metadata). Most of that cost comes from resending the growing conversation on every turn. That happens on either product, so session length may matter more than the product: shorter sessions per topic, or compacting, cut it on both. Two more points: "better at" (quality of the result) and token use are separate questions; and that session ran on Opus while CLAUDE.md sets Clead's default to Sonnet, so part of its cost is the model, not the product.


### 13. What the template's value is, and for whom — new (2026-10-02)

**Adam, 2026-10-02:** the strong suit is the process support. Even for a process-literate WHAT person who has all the tools installed, bootstrapping from the template beats starting with the processes as a blank sheet. The tooling can be set up by asking Claude: Adam did that for fomo-f from a bare computer, before any template existed.
**Clead's analysis, the same day:**
- **What the template gives:** a fixed way of working (WHAT/HOW roles; spec, backlog item, PR, review, merge); guardrails a non-programmer cannot provide (CI requires a test change with code changes and a green `build`; a separate review; branch protection); memory in the repo; tested language packs.
- **Not unique as parts:** Claude Code now ships Projects (one coordinating conversation that starts parallel cloud sessions; public beta), Code Review, `/code-review`, PR auto-fix, and CLAUDE.md with auto memory. **Unique:** the operating model and the lessons from v1, fomo-f and the football tracker, written down and enforced where possible.
- **Weak spots:** overhead on small changes; some guardrails are instructions only (review independence, test-first order); part of the Clead and Crog coordination overlaps Projects.
**Questions for Adam:**
1. PBI-1.14: since setup is possible by asking Claude, the script's value is a setup that is repeatable, checked and cheap, not one that becomes possible. Keep the 17-slice plan, or build a smaller version (Clead guides the setup and a short script checks the result)? **Answered by Adam, 2026-10-02:** PBI-1.14 stays as planned. Even a knowledgeable WHAT person who could set up alone gains from being guided: it is a safety net.
2. If the process is the strong suit, should effort go first to the process itself (enforcement, less overhead, Projects as the base where it fits) rather than to the setup script?

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
