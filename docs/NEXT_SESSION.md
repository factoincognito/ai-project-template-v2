# [PROJECT NAME] — Next Session Planning

**Last Updated:** 2026-10-20
**Author:** Clead (Tech Owner)
**Purpose:** Staging area for reasoning, revised assumptions, and plan-adaptation thoughts that aren't yet mature enough to be a PBI, a decision, a strategy update, or a vision-doc change. Complements `docs/BACKLOG.md` — it does not replace it. Discrete, scoped, actionable work belongs in the backlog as a PBI, not here.

**The rule that keeps this useful, not a junk drawer:** every entry below must get a disposition each session it's touched — promoted to a PBI, a decision, or a formal doc update; re-affirmed as still-next; or deleted as resolved/obsolete. This file is read and triaged at the start of every session (see `CLAUDE.md` session-start routine). It is not a substitute for the backlog — it's where things live before they're ready to become backlog items.

---

## Handover: the Clead role moves between Claude app and Claude Code in the cloud (2026-10-15) — HANDED BACK to the Claude app, evening of 2026-10-15

**Why:** Adam's weekly credits in the Claude app ran out; his Claude Code cloud credits are available. Adam's instruction: the next prompt goes to Claude Code in the cloud, and when those credits run out the Claude app session takes the project back with no loss. The state below is what both sides read first. Nothing here is private; keep it that way.

**Who does what while the Clead role runs in Claude Code (cloud):** the session acts as **Clead** (Tech Owner), following CLAUDE.md "If you are Clead" in full: startup steps, change execution model, working unattended, `..wrap`. Crog work is done by separate agents the session starts (Opus implementer, a separate Opus reviewer that never wrote the change, a Sonnet merge-only agent), exactly as in item 8 and the PBI-1.14 slices. The CLAUDE.md line "If you are Crog (Claude Code)" is about the implementer agent, not about this session. Never commit to `main`. Merges are verified against the GitHub API by the Clead session, not taken from a relay.

**Hand-back state, evening of 2026-10-15, after #172 merged at 19:47 UTC (re-derive from GitHub before trusting; this is a snapshot). The cloud Claude Code session that ran the Clead role listed these from GitHub just before handing back:**
- Open PRs: none. Branches other than `main`: only `claude/wizardly-rubin-ozdtl0`, which belongs to another session and was not touched. `main` is at `f7457df` (#172). The cloud session's own branch `claude/quirky-ptolemy-sxf801` is deleted by the repo after each merge and was recreated from `main` for each notes PR; this Handover PR (the one that merges this text) is the last thing it opened.
- In the middle of: nothing. No agent is running, no check-in is scheduled, nothing is half-built. The cloud session built S18a/S18b by the PR loop (Opus implementer test-first, a separate Opus reviewer, Sonnet merge-only agent) and verified each merge through the API.
- Needs from Adam: the two answers below, and his list (the to-do section further down). Nothing else is parked.
- Questions for Adam: both answered 2026-10-17. The README steps are their own slice, S19, built before the tag (merged as #174); the tag follows the release prep PR with nothing merged in between (see "Notes from S19" in item 8).

**Earlier snapshot (state at 2026-10-15 ~11:10 Stockholm time, kept for the record):**
- PBI-1.14 slices S1 to S18 are merged, all verified through the API on 2026-10-15: S17 = #166 (`ca3b2c8`), S18b = #171 (`6ed3290`), S18a = #169 (`be9d72e`). #165, #167 and #168 (notes) are merged too. The script is built; what is left is the open question in step 3, the release prep (step 4) and Adam's end-to-end runs.
- (#166 merged after two Opus review rounds, last verdict APPROVE at head `59991d1`.)
- CI shape: the Bootstrapper workflow runs once per PR push; the Windows leg takes 54 to 72 minutes (macOS about 26, ubuntu about 16). Do not poll in short loops; check every 10 to 15 minutes, or work on something else.

**Next steps, in order:**
1. Done 2026-10-15: #167, #165 and #166 merged through a Sonnet merge-only agent and verified through the API (merged true, merge commits `f0d41d2`, `498e47a`, `ca3b2c8`, expected changed files).
2. Done 2026-10-15 (S18 = #169 and #171; scope and what was deferred are in item 8, "Notes from S18"). Before: graduate NEXT_SESSION entries after #166: S17 is done; its not-done list (in the #166 description, "Not done here, needs a script slice") becomes the input for one new script slice, **S18**, before the release tag. At minimum S18 holds the CRLF-README overwrite risk (item 8, "fix it before the release tag") and the other script-behaviour notes tagged S15 or S17. Decide the S18 scope in a short plan, then build it by the PR loop (Opus implementer test-first, Opus review).
3. Done 2026-10-17: Adam decided the README steps are their own slice, S19, before the tag. Built by the PR loop as #174 (squash `09bcb10`; two review rounds; Windows green on the exact head), verified through the API. Deferred review notes and what is unverified: item 8, "Notes from S19".
4. Release prep PR (version heading over Unreleased, as #76 and #126 did), then Adam creates the tag from the Releases page; Clead verifies the release through the API (tag run green including `publish` and the pack chain, bootstrapper `main` has the new commit, tag on both repos). Also update `memory/decisions.md` (the 2026-10-02 row says the spec is fixed "in slice S15") and mark PBI-1.14 in `docs/BACKLOG.md` when it is built (it still says `[NEXT]`, not yet built). Those two edits are prose; PBI status is Clead's call.
5. Adam's end-to-end runs on throwaway repos use `bootstrap/e2e-check.sh OWNER/NAME DIR` afterwards (read-only; prints delete commands, never runs them).

**What a cloud Claude Code session could do (learned 2026-10-15; the app session may differ):** GitHub through the `mcp__github__*` tools, not `gh` (no `gh` CLI): list and read PRs, comments and check runs, job logs (`get_job_logs`), merge with `expectedHeadSha`, comments, create PRs; `git push` to the designated branch worked. Subagents (Agent tool, `model: opus` or `sonnet`, `isolation: worktree`) see the same tools, and a finished agent can be resumed with `SendMessage` to keep its context (used for review deltas and for fix rounds). Check-ins were scheduled with `send_later` (a one-shot message into the same session); do not poll. The MCP servers disconnected and reconnected several times without losing anything. Worktrees land under `.claude/worktrees/` inside the clone; exclude them locally in `.git/info/exclude` (not in the repo) or the Stop hook complains about untracked files. Branch deletion and tags are still Adam's.

**How the PR loop ran, and what it cost (2026-10-15):** each new head needs a new review of the delta; an approval at an older head does not carry over; merge only after the Windows leg is green on that exact head (the merge agent re-checks head, checks and the approval comment). S18a needed four review rounds and two extra Windows CI rounds (about 80 minutes each) because the tests' own CR checks failed on Windows; the lesson is in "Test and CI lessons". The merge agent's report is a relay: verify merged, merge sha and changed files through the API yourself.

**Access facts that cost time before:** GitHub through REST only, `gh api repos/factoincognito/ai-project-template-v2/...`; GraphQL and `gh pr` returned 403 in the app's cloud workspace; branch deletion, tag pushes and Actions/secrets endpoints were blocked (the repo deletes merged remote branches itself). Actions job logs are readable through `gh api repos/.../actions/jobs/<check-run id>/logs`. A cloud Claude Code session may have different access: verify by use at startup (CLAUDE.md startup step 3) and say what differs. Review clones, scratch worktrees and a self-built bash 3.2.57 lived under `/home/claude/` in the app workspace and will not exist in the cloud Claude Code workspace; the reviewers' bash 3.2 runs there need a rebuild (`bash-3.2.57` from the GNU mirror, or rely on the macOS CI leg, which runs the real Apple 3.2).

**Test and CI lessons to keep (from S5, S16 and S18a):** on Windows (Git for Windows) `grep` does not find a CR in a file, and `$( )` drops a final CR LF; check for a CR with `od -A n -c` and look for the two characters `\r` (the helper `has_cr` in `bootstrap/test-bootstrap-project.sh`), and test the check itself with a known `a\r\n` file first; a test that passes on Linux can fail only on the Windows leg, which takes 55 to 80 minutes, so reason from the logs before pushing; put a private git-wrapper dir first on the test PATH; use `mktemp -d`, not `$RANDOM` (bash 3.2 subshell reseed); per-test work dir; Windows and macOS path and CR LF differences; any test that snapshots a tree must switch git maintenance off in the repo it snapshots (`gc.auto=0`, `maintenance.auto=false`, `receive.autogc=false`).

**Model and effort:** the model rules in CLAUDE.md ("Model and effort") apply. In Claude Code the session cannot change its own model either; ask Adam which to select before reviews and design work, and start reviewer agents on Opus.

**Handing the role back to the Claude app (done 2026-10-15; kept as the procedure):** before the cloud session ends or the credits run out, it (1) lists open PRs and non-main branches from GitHub, (2) opens a notes PR that updates this Handover section: what merged (verified), what is open and why, what it was in the middle of, what it needs from Adam, (3) tells Adam in chat what to say to the app session. The app session starts by reading this section, then CLAUDE.md startup steps 1 to 6, and treats every claim above as a snapshot to re-check.

**Adam's side:** to resume in Claude Code in the cloud, the next prompt can be: "Read CLAUDE.md and the Handover section at the top of docs/NEXT_SESSION.md, act as Clead, and continue." To hand back to the Claude app: "Read the Handover section in docs/NEXT_SESSION.md and continue as Clead."

---

## Adam's to-do (things only Adam can do)

Written 2026-10-02 so nothing depends on anyone remembering. **Each Clead session lists this to Adam in its first reply and removes each line when Adam confirms it is done.** Agents cannot do these: the access proxy returns 403 on branch deletion, tag pushes and the Actions and secrets settings, and branch protection and tokens are GitHub account settings.

1. **Decide** (item 10) whether CLAUDE.md should say that only one Clead session works on the template at a time, and that every session starts by listing open PRs and non-main branches.
2. **Now: the end-to-end runs** on throwaway public repos `bootstrap-e2e-<pack>-<date>`, one at a time, in this order (agreed 2026-10-23). After each, run `bash bootstrap/e2e-check.sh OWNER/NAME DIR` from a template clone and give Clead its output; delete only after that.
   1. Windows, Git Bash, interactive, web pack. Log in first without the `workflow` scope so the guided scope refresh runs; press Ctrl-C during the CI wait and continue with the printed `--resume` command. **Stop until this run is clean**; a defect is fixed and released before the other runs.
   2. node pack, `--non-interactive`, any OS.
   3. python pack, interactive, on macOS if available (`/bin/bash` 3.2), with PBI-1.17's red-then-`Test-exempt` pull request in that project (PBI-1.17 stays `[NEXT]` until then).
   4. react-native pack, interactive, any OS.
   5. Separately, now: someone who has never used `gh` or a terminal sets up a project from the README alone (PBI-1.14 Done when 7). Where they get stuck is a defect and evidence for PBI-1.19; repeat it if PBI-1.19 changes step 1.
4. **If an agent has to change files in your connected PC folder,** it asks for delete permission once per session (a failed pull left a stale `.git/index.lock` last time). Your PC clone of the template is behind main and its `origin` points at the org; the session fast-forwards it after you grant that.

---

## What waits for what

Written 2026-10-02 so the order does not have to be re-derived. "Clead" is the next Clead session.

| Step | Who | Blocked by |
|---|---|---|
| Rest of PBI-1.14: none. The README steps were built as S19, merged as #174 on 2026-10-17 | done | S1 to S19 merged |
| Release prep PR for v2.4.0 | done: #176, merged 2026-10-18 (`7dd7fd0`) | |
| Release tag `v2.4.0` | done: Adam, 2026-10-23, at `7dd7fd0` | |
| Release verified | done 2026-10-23: tag run 39920156317 green including `publish`; bootstrapper `main` and its tag `v2.4.0` at `b93a395`, with `bootstrap-project.sh` at its root (executable, LF) | |
| #177 (PBI-1.18 spec), then #178 (the sharding) | done: #177 merged 2026-10-23 (`e22bd39`); #178 merged 2026-10-23 (`31de9e9`) after Adam answered that intent approval is not needed (recorded on #178). Windows leg 19.1 min on its last run (was about 73) | |
| End-to-end runs on throwaway repos; PBI-1.17 to `[DONE]` | Adam runs, in the order of to-do 2; Clead reads the `e2e-check.sh` output | Nothing; open now |
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
every level. PBI-1.14 (the turn-key bootstrap script) is being built in 17
slices plus S18 (script behaviour left by S17, built as S18a and S18b); S1 to S18 are merged as of 2026-10-15 (item 8). Adam's order: PBI-1.14, with no tag until
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

### 5. Process simplifications: audit done 2026-10-02, fixes pending

**What this is:** a read-only audit of `origin/main` at 944f34b (CLAUDE.md, ROUTINES, roles, standards, CROG_ONBOARDING, DEV_INFRASTRUCTURE, decisions, review.yml, changelog.yml). Line numbers refer to that commit. Removing a shipped file needs the bootstrap manifest tests run first (test-first). Not in scope: the temporary arrangement until 2026-10-05, and items 12 and 13.
**Stale or contradicted (Clead's to fix, process PRs reviewed by Crog), most important first:**
1. `docs/ROUTINES.md` ships to every project but describes deleted Routines (decisions row 2026-10-01), an unapproved Path B (PBI-2.2), a review-Routine input contract that duplicates `standards.md` section 7, and a prompt delimiter for pasting. Delete it; remove it from the CLAUDE.md table and `bootstrap/manifest.txt`; keep the delimiter as 3 lines in `roles.md` only if Adam still pastes prompts.
2. `.github/workflows/review.yml` posts `<!-- clead-review-ready -->`, which nothing reads; it never fires in the template and is noise in projects. Delete it, drop it from the manifest and from `CROG_ONBOARDING.md:61-62`; reinstate with PBI-2.2.
3. `changelog.yml` and the docs say a CHANGELOG PR after every merge (one PR behind); practice is batched (#83, #113, #124, #134, #141). State the real rule once and drop or keep the workflow (see C2).
4. `CLAUDE.md:90-92` still names the Chrome web-editor path as a fallback; decisions row 2026-09-30 says it is no longer needed. Delete the sentence (also `NEXT_SESSION` "Items that do not change"); mark the old rows superseded. (Startup step 3's Chrome fallback is left for item 12.)
5. `memory/decisions.md` open question 2 (about 320 lines on Routines, fire URLs, tokens, Adam firing curl) is superseded by the rows of 2026-09-30 and 2026-10-01. Replace it with a short "resolved" note, or move it to a dated archive in `docs/decisions/`.
6. `memory/standards.md` is titled "Clead Review Standard"; since 2026-09-30 Crog reviews too. Retitle to "Review Standard", say "the reviewer", and add which sections apply to process and docs reviews.
7. `CROG_ONBOARDING.md:75-77` (act only on a Clead fix prompt on the PR thread) and `:58-62` (report the PR to Clead; the dead marker) are out of date. Reword.
8. ADR 0001 (ships to projects) still describes Routines dispatch. Add a "partly superseded" status header.
9. Wording: `decisions.md` rows citing `tools/pr_dump.sh` (no longer exists); open question 4's premise (the GitHub connector); `CLAUDE.md:221-223` mentions fomo-f in a file that ships to every project.
**Duplicated (consolidate into one home, pointers elsewhere):** the graduation rule (5 places), pin disposition (3), the 3-rounds escalation (6; home: `standards.md` section 6), the test coverage table (3; home: the PR template), the approval ceremony (`roles.md` vs `CROG_ONBOARDING.md`), merge authority (5; `CROG_ONBOARDING.md:33-34` is narrower than rule 3).
**Needs Adam (process rules he set):**
- C1. One PR in three records status after the work (e.g. #137, #142-#145), each with CI and a Crog merge run. Options: fold "slice done" into the next slice PR; let Clead merge its own no-review-gate PRs; record "slice done" in the slice PR itself.
- C2. CHANGELOG as a per-PR list repeats `git log`. Option: write it per release from user-visible changes at release prep; this would drop the batch CHANGELOG PRs and clean-end condition 5.
- C3. Item 8's deferred review notes are backlog items in a staging file; graduate them into the PBI-1.14 slice list. "What waits for what" overlaps item 8.
- C4. "Working unattended" in CLAUDE.md mostly restates rules 1-4; shorten with item 6's nits.
**Also:** item 6's nits are repeated in item 10; fold them into the CLAUDE.md edit for 4 and 9.

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
- S5 `bootstrapper-test` becomes one aggregate check over an OS matrix (ubuntu, macOS, Windows). **Done: #161, 2026-10-14** (three CI rounds; the first real runs on macOS and Windows found a git-not-on-PATH harness bug that failed 95 Windows tests, CR LF lost when names are filled in, two macOS path-comparison tests, and a test PATH that let brew leak in).
- S6 inputs and validation. **Done: #146, 2026-10-02.** S7 guided preflight, local checks. **Done: #148, 2026-10-06.** S8 guided preflight, GitHub checks. **Done: #149, 2026-10-06.** S9 create and protect. **Done: #150, 2026-10-06** (it also prints the plan and asks "Proceed?"; `--non-interactive` needs `--yes` or `--dry-run`). S10 local tree. **Done: #152, 2026-10-06.** S11 fill placeholders. **Done: #153, 2026-10-06.** S12 lockfile, licence, CHANGELOG. **Done: #154, 2026-10-06.** S13 self-check, commit, push, PR. **Done: #155, 2026-10-06.** S13a (unplanned: unknown licence key checked in the preflight, Actions checked after protect). **Done: #156, 2026-10-07.** S14 wait, require `build`, merge, finish, report. **Done: #158, 2026-10-13.** S15 resume, failures, private repos. **Done: #159, 2026-10-14** (three review rounds; round 1 found `--allow-unprotected` accepted on a public project, an unprotected merge without the decision row, and a hand-made project's protection overwritten; round 2 found the same overwrite again through a removed README heading with the script kept).
- S16 `bootstrap/e2e-check.sh` (read-only checker for Adam's end-to-end runs; template-only, not in `bootstrap/manifest.txt`). **Done: #164, 2026-10-15** (three review rounds; round 1 changes requested, round 2 approved, round 3 fixed a CI flake and was approved as a delta; details below). S17 docs and process. **Done: #166, 2026-10-15** (two review rounds; spec text, `languages/README.md`, #163 notes N1, N2, N4 and N6; no script behaviour changed). S18 is the last slice: the script-behaviour notes that S17 left (list in the #166 description), scoped in a plan before it is built.
**Critical path:** S1, S2, S4, S6 to S15, S17. S3 can start now; S5 after S4; S16 after S5.
**Cannot be verified in CI (Adam's end-to-end runs only):** GitHub timing and error texts after create, the protection PUT shape, private-repo clone and push, Git Bash prompts, `winget`, a lockfile made on Windows or macOS under `npm ci` on Linux, the unaided README run, and the red-then-`Test-exempt` PR in a real project.
**Spec meets changed repo (to fix in the slice named):** the placement-table tests in `bootstrap/test.sh` pin both READMEs (S17); `test_workflow_bootstrapper_test_runs_the_require_test_change_tests` conflicts with the aggregate design (S5); the setup PR's tree must keep `.github/scripts/require-test-change.sh` (S10); stamps from releases before the org move name the old owner, so older repos cannot be resumed (S15).
- S18a CRLF in README or CHANGELOG on GitHub is refused before anything is written. **Done: #169, 2026-10-15** (four review rounds; round 1 found a 4 to 5 s cost on every `--resume`, rounds 3 and 4 followed two Windows CI failures of the tests' own CR checks). S18b gh feature preflight, bare-word message, help and plan wording. **Done: #171, 2026-10-15** (one review round, approved).
**Next slice:** none. S19 is merged (#174, 2026-10-17) and the release prep PR is merged (#176, 2026-10-18). Next: the tag `v2.4.0` (Adam, from the Releases page), then Adam's end-to-end runs.
**Questions for Adam (neither blocks S1):**
1. Answered by Adam, 2026-10-02 (`memory/decisions.md`): `--resume` refuses a repo stamped by an older bootstrapper version and tells the user to create a fresh repo; a repo stamped by the current version, including one made with "Use this template" from the current release, still resumes. The spec text is corrected in S15.
2. Answered by Adam, 2026-10-02: v2.3.0 is released before S1 (nothing of PBI-1.14 ships in it), then no tag until S15 merges. acuteping waits for PBI-1.14 and the end-to-end runs either way (decision of 2026-10-01).
**Started 2026-10-02:** Adam answered question 1 and said go. S1 (#131) and S3 (#130) merged the same day, then S2 (#133); each was built test-first by an Opus Crog and approved by an Opus review (S1 and S2 after a second round that fixed tests which could not fail).
**Review notes deferred to later slices (non-blocking):**
- Still open after S2 and S4, no slice assigned: the S3 test in `tools/test-layout-pack.sh` only sees `npm install` in single-line `run:` steps; one inside a `run: |` block passes unnoticed (#130 review).
- Any slice that adds `say_command` calls: the command-argument check sees only the first call on a line and only the first word of its argument (#136 review, B).
- S13 (only if a real heredoc hits it): heredoc body lines still go through the per-line checks, so a quiet heredoc whose text says "printf" is flagged, and a body line cannot carry the opt-out marker. It fails loudly (#146 review).
- Whichever slice touches the usage text, or S17: a bare positional word gets the plain usage text, not the What happened / What to do next format (#146 review).
- S17: the expected-paths list in `tools/test-layout-pack.sh` (the per-file layout test) is a deliberate third statement of the placement table, next to the script and the README tables; change it together with the README tables (#131 review). `languages/README.md` still says the table lives in `tools/layout-pack.sh` (also S17). **Done in S17 (#166).**
- Any slice that touches the script's usage text: run through the wrapper, the usage message names `bootstrap-project.sh layout-pack`, not the command the user typed (#131 review, cosmetic).
- S5: a real bash 3.2 run in CI. A reviewer ran the built script once under a self-built bash 3.2.57 on Linux (all four packs identical); macOS `/bin/bash` and Git for Windows bash are unverified.
- **Notes from the S7 to S9 reviews (#148, #149, #150), by slice:**
  - S10: `--resume` allows any non-empty folder; check that it is this project's own copy, that the parent folder exists and is writable, and that the target is not inside another git repo (#148, also S15).
  - S12: plan step 4 says "add the licence" even with `--license none` (#150).
  - S13: the spec's check that Actions are turned on, "right after step 3", has no slice yet; the #150 review recommends S13.
  - S15: answers given to the questions are lost on any stop after them, because the start-again command repeats only the command-line options (#148, #149: name taken, token permission; an interactive run could ask for the name again). The continue commands: `--allow-unprotected`, `--private` carried after making the project public, the other answers (#150). A rate limit on create is read as "not allowed" (#150, or S17). The make-public command is shown to copy, not run; S15 may run it from inside the local copy (#150).
  - S15 or S17: a renamed project's old name reads as taken, because gh follows the redirect (#149).
  - S17 and Adam's end-to-end runs: on Windows, `winget` does not refresh the open Git Bash's PATH, so the re-check after an install fails; on macOS, `xcode-select --install` returns as soon as its dialog opens, and the `git` shim may open that dialog itself (#148). "Could not reach GitHub" also catches local gh failures (#149). Each offered command is printed twice (#148). `--help` does not say that `--non-interactive` needs `--yes` or `--dry-run` (#150).
  - **Notes from the S10 to S13a reviews (#152 to #156), by slice.** Rounds: S10 and S13 needed a second review round (S10: `=` or `-` in a folder name corrupted awk and option parsing; S13: untested branches of the `git status` check); S11, S12 and S13a passed in one. Other blocking findings are fixed in the PRs.
    - S14: the `build` failure message can name the Actions policy. `enabled: true` is not enough: with `allowed_actions: local_only` the check passes and `build` fails at the first GitHub-owned action; reading `allowed_actions` closes it (#156, also S17 and the e2e list). The re-ask path that ends in `none` or PolyForm has no test for its done line; one `grep -A` like the mit branch (#156). One coverage row ("exists on GitHub") overstates its test (#156). Print `say_left_for_clead` (#153).
    - S15: `remove_setup_section` and its grep match the prefix `^## After bootstrapping`; a filled description such as `## After bootstrapping: …` looks like the setup section to a resume or a second tidy-up; match the full heading (#153). An awk failure in `fill_file` exits silently and leaves the temp file; needs the ERR trap (#153). A missing `CHANGELOG.md` gives bash's own error before the message (#154). Choose whether the CR check reads the index, not the working files, since `eol=lf` makes the saved change LF (#155). The path rules for `src/` and `e2e/` are wide in both directions; compare with the files the layout copied (#155). The self-check relies on `LP_TARGETS` and `LP_KEPT` from `layout_into`; a resume from step 12 or 13 must set them (#155). Any answer other than 200, 403, 404 from the Actions check stops after the project exists; decide with `--resume` whether a warning is enough (#156). The 404 next action ("continue with `--license <right name>`") needs `--resume` to accept a changed `--license` (#154). Also from #152: the checks after the first write, `mv` without framing, `--resume` past step 4, `--dir .` from inside the copy.
    - S17: a global `author.*` or `committer.*` setting overrides the copy's `user.email`, and the identity stop's next action does not name them; either S10 writes them into the copy or the text names them (#155; S15 or S17). The spec lists step 8 before step 9; the code runs 9 then 8 (#153). The spec text also needs: the licence key is checked in the preflight, and the Actions re-check in the same run when interactive (#156); the `none` warning for a public project should also be in the plan's step 4 (#154). Push failures with no mapping: a token without Contents write, an SSH remote (#155). Rare Windows forms (`C:`, `c:foo`, `\\srv\share`) get `./` and are "not supported" (#152). Optional: fold `replace_text` onto `fill_file`'s engine (#153).
    - End-to-end list (Adam's runs): global `commit.gpgsign=true` or `core.hooksPath` during the commit; the helper string and `gh.exe` paths on Windows; gh's real `pr create` texts and a private repo's fallback; real `licenses/<key>` and `actions/permissions` answers (a fine-grained token without Administration read; an org-level disabled state); npm on Windows or macOS writing LF; a user's `.npmrc` mirror ending in the lockfile's `resolved` URLs.
    - Left open with no slice (cosmetic or optional): the messages now show the folder with `./` (#152); `check_license_known` accepts any 200 without comparing `.key` (#156); `filled_as` in the harness puts `$v` unquoted, so an `&` in a value would break under bash 5.2 (#153).
  - Decisions Clead took in S9 (#150, reviewed): step 2 keeps the spec's `gh repo create` and recognises gh's error text for "name taken" and "not allowed"; the REST `generate` call would give a status code instead, if that text proves unreliable in the end-to-end runs.
**Notes from the S14 and S15 reviews (#158, #159), by slice:**
  - S5: a bash 3.2.57 run of `bootstrap/test.sh` fails `test_publish_second_release_mirrors_output_and_keeps_history` (a git push error, then the build fails); it fails the same way on `main` before S14. Fix or exclude it before the 3.2 CI run. S14: the jq-expressions test passes without running anything where `jq` is missing (#158).
  - New slice or S17, script, left by S15: README on GitHub stored with CRLF passes the GitHub heading check but not the local one, so the run resets protection so `build` is no longer required, changes merge settings, makes a copy and stops with a wrong message (#159 round 3, NB1; needs a CRLF README, which the line-ending settings normally prevent, so improvement rather than blocker; it is the same class as the overwrites fixed in rounds 1 and 2, so fix it before the release tag). The B4 refusal names CHANGELOG.md as the check but reads README.md and `bootstrap-project.sh` (wording). Actions answers other than 200, 403 and 404 after create; `--with-deploy=no` is not carried in the continue command; a closed, unmerged proposed change is ignored; a renamed project's old name still reads as taken.
  - S17: `gh` older than the one with `gh pr checks --json` and `gh pr merge --match-head-commit` fails only after the project exists, and the user is told to check the connection; add it to the preflight (#158). The local-only Actions guide says "turned off" when Actions are only limited; `selected` without GitHub's own actions gets the plain stop (#158). Whether the change was merged is read once after the merge; a stale "not merged" answer would be misreported (#158; end-to-end list). The bad-merge-id stop says "added to the main version" and then "proposed there" (#158 round 2). The wait counts tries, not elapsed time (#158).
  - S17, docs: the "Existing repo" spec text in `docs/BACKLOG.md` is not yet corrected (decision of 2026-10-02 says S15 does it; #159 changed no docs). **Done in S17 (#166).**
  - **Notes from the S5 review (#161):**
    - S16 or S17, workflow tests: `continue-on-error: true` on the gate step or the matrix test step, or a matrix `exclude:` for Windows, passes all wiring tests; either `continue-on-error` edit would turn the required check green on a failing leg. Add those assertions (the macOS check's `if false` also survives; its 3.2 check is only matched as text). A few lines of test, no new CI round of its own. **Done in the same PR as the CI-time change below** (the 3.2 check now runs with a fake bash reporting 3.2 and 5.2).
    - S17: the folder name in the "inside another git project" refusal can name a folder that is not a git project (a symlinked path; a `.git` folder or bare repo). Message only; the refusal is right. Test skips are invisible in CI (reason goes to a log printed only on failure); on Windows `ln -s` copies, so the folder-naming test checks a copy there. Other `$RANDOM` collisions remain from before S5 in `tools/test-layout-pack.sh` and `bootstrap/test-bootstrap-project.sh` (one shared temp folder). The merge-folder check compares resolved paths (slightly weaker; accepted for macOS).
    - **For Adam, CI time:** decided by Adam, done in the PR "CI: run the bootstrapper workflow once per PR push and cancel superseded runs": the workflow runs on pull requests to main and `v*` tags only (no branch pushes), and a newer push to a PR cancels the older run (never a tag run). The other options below stay open. Before: the Windows leg takes 54 to 72 minutes (macOS 26, ubuntu 16), and the workflow runs on both every branch push and every pull request, so every PR, docs-only ones included, waits about an hour for the required `bootstrapper-test` and the matrix runs twice per push. The repo is public, so the cost is waiting and runner capacity, not money. Options still open (the first two of the original list, matrix on pull requests and tags only and cancelling superseded runs, are done): split the long test file into parallel jobs; start fewer processes per test on Windows; run Windows and macOS only when `bootstrap/` or the workflow changes (care: a skipped required check counts as passing); Windows nightly and on release tags only (conflicts with Done-when 2).
**Notes from S16 (#164) and the CI-time PR (#163), by slice:**
  - S16, what shipped: `bootstrap/e2e-check.sh OWNER/NAME DIR`, read-only, 82 tests in `bootstrap/test-e2e-check.sh`, wired into `scripts-test`; it is not shipped (a test checks the real build leaves it out). It never runs a delete; it prints `gh repo delete` (only for names starting `bootstrap-e2e-`) and an `rm -rf` line (only when the copy check passed, absolute path, single-quoted) for Adam to run. Run it after the end-to-end run, not before: it expects the history and protection a finished run leaves.
  - S16, a CI flake found by the first real run: git's background auto-maintenance in repos the tests build raced with the before/after tree snapshot in `test_cr_lf_file_fails`. Fixed in round 3: every repo the tests build, and the harness's global config, set `gc.auto=0`, `maintenance.auto=false`, `receive.autogc=false`; every git call of the checker carries `--no-optional-locks -c core.fsmonitor=false -c gc.auto=0 -c maintenance.auto=false`. A deterministic race test runs `git gc --auto` on the copy during the check. Lesson for any later test that snapshots a tree: switch maintenance off in the repo it snapshots.
  - S16, open, non-blocking (round 3 review): the symlink guard strips one trailing slash only, so DIR `link//` or `link/.` still gets an `rm -rf` hint (harmless, `rm` removes the link; testing `-L` on the path `pwd` returns closes it). `test_folder_sentences_say_what_is_wrong` greps a sentence printed for every copy-check failure, so it cannot tell the real reason. The race hook runs with `|| true` and the test asserts that the hook ran, not that `gc` acted. A dangling symlink reads "does not exist". GitHub's real 403 body for a private repo on the free plan is unverified (the checker needs GitHub's plan message to call it the plan case); Adam's end-to-end run is where that gets checked. Real `gh api -i --jq` error-body pass-through is also unchecked.
  - #163 (CI triggers and concurrency), review notes: **N1** after merge `main` is not re-tested by this workflow (`strict: false`, so a PR's merge-ref run can be stale after another PR merged; the `bootstrapper.yml` suites do not run again until a `v*` tag, which still gates publish). Correction found in the #166 review: `ci.yml` and `packs.yml` do run on every push to `main` (the pack chain on the combined tree), so the gap is the bootstrap suites and the OS matrix only; the #163 review note overstated it. S17 docs: one sentence in the `bootstrapper.yml` header and `docs/DEV_INFRASTRUCTURE.md`, scoped that way. Adam's call: turn on "require branches to be up to date" (cost: another hour-long run on open PRs after each merge). **N2** (S17 docs, one line in `docs/DEV_INFRASTRUCTURE.md`) retargeting a stacked PR's base to `main` is an `edited` event, outside the default `pull_request` types; the required check stays missing until a new push or a close and reopen. It fails safe (merge blocked). Unreproduced; from GitHub's documentation. **N3** (release, pre-existing) the `publish` job's own concurrency group, `bootstrapper-publish`, does not cancel a running job, but with three or more `v*` tags reaching publish together the middle pending one is replaced; re-running recovers. **N4** (S17 workflow tests) a quoted key `"continue-on-error": true` passes `test_workflow_no_continue_on_error_in_the_required_check_or_its_needs`; the pattern `["']?continue-on-error["']?[[:space:]]*:` closes it. **N6** (S17, workflow file) the header bullet "- Every pull request:" should read "- Every pull request to main:"; N5 (the done options still listed under CI time) is fixed in this note.
  - Decisions Clead took in the S15 review (not Adam's): `--allow-unprotected` only for a plan limit on a private project; an unprotected merge needs the decision row in the change or it stops; a hand-made project (current release, no setup section, no script) gets protection read and reported, never set. A project with the README heading removed but the script kept is refused before anything is written.


**Notes from S18 (#169, #171), 2026-10-15:**
  - What S18 did: S18a (#169): a README or CHANGELOG stored on GitHub with a CR is refused in `resume_decide` before any write (new `guide_line_endings`); `api_call` keeps the body with its CRs only when called as `API_KEEP_CR=1 api_call ...` (`API_BODY_CR`); `refuse_project` takes its "how the script checks it" text; the B4 refusal names README.md and the script. S18b (#171): `check_gh` also checks `pr checks --help` for `--json` and `pr merge --help` for `--match-head-commit`; a bare word gets "What happened / What to do next" (exit 2); `--help` says `--non-interactive` needs `--yes` or `--dry-run`; the plan warns about a public project with licence `none` (shared `NO_LICENCE_WARNING`); the Actions guide says "turned off or limited". The S18 plan was drafted by an Opus agent against the script at `ca3b2c8`; five notes of the S17 list no longer matched the code (rate limit read as "not allowed", the global `author.*` setting, the prefix match of the setup heading, the missing-CHANGELOG error, the bad-merge-id wording) and were dropped.
  - From the #169 reviews, open and non-blocking: a README whose setup heading is gone, with the script kept and a CR, now gets the line-endings guide first and the "cannot place" refusal on the next `--resume` (nothing is written either way; run the refusal first when neither `GH_HAS_SECTION` nor `GH_SECTION_CR` is set). `resume_read_github` builds the 220 KB `bootstrap-project.sh` body only to read its status (cheap follow-up). The `${line//$CR/}` strips in `resume_read_github` and `read_published_version` do nothing for API answers (`api_call` strips first). Whether GitHub's web editor can change a file's line endings is not verified (the guide does not mention it). A CR on the last line of a body with no line end after it is covered by a test only through `api_call`.
  - From the #171 review, open and non-blocking: the "gh too old" guide says "add a proposed change" for `gh pr merge`, which reads like opening a PR (the script's own words are "add the change to the main version"); `docs/BACKLOG.md` still describes the gh feature check as `--template` only (prose, Clead's); the plan warning has no test for a licence chosen at the prompt (only with `--license none`); the bare-word message echoes control characters as typed (the unknown-option message does too) and an empty argument reads "The word  is not an option"; the line "Done. gh is installed and can create a project from a template." is true but no longer names everything checked. Not verified: which gh version first had the `pr checks --json` fields (`bucket`, `event`) that step 15 uses, so a gh with `--json` but without them passes the preflight.
  - Deferred by the S18 plan, with reasons (take into a later slice only if the end-to-end runs show a need): a CR in any other file stops only at `check_line_endings`, after protection is set; for a project made from the template there is no copy before `protect_main`, so a real fix means cloning before protecting, which reorders the spec steps and their tests (for the resume state `fresh`, a `git grep` for a CR before protecting is cheap). A renamed project's old name reads as taken (`check_project_absent` does not compare `full_name`; the workaround is another name). "Could not reach GitHub" also covers local gh failures. Unmapped push failures (a token without Contents write, an SSH remote). Rare Windows path forms. Optional: fold `replace_text` onto `fill_file`. Merge state is read once after the merge and the wait counts tries, not elapsed time. The "inside another git project" refusal can name a folder that is not a git project. Actions answers other than 200, 403 and 404 after create stop safely (`--resume` continues). `--with-deploy=no` is not carried in the continue command (the option itself is refused). A closed, unmerged proposed change is ignored. `selected` Actions without GitHub's own actions gets the plain stop. The wrapper naming (`bootstrap-project.sh layout-pack` in the usage text) and `usage()`'s `[options]` line, now reached only from `layout-pack`. `winget` PATH and `xcode-select` need Adam's end-to-end runs.

**Notes from S19 (#174), 2026-10-17:**
  - What S19 did: the stub README's setup section is three lines (its heading and the `## Setup` boundary are unchanged, because the script, resume and `e2e-check.sh` match them); the template README has step 0, the one command and the guide list by group; `docs/DEV_INFRASTRUCTURE.md` "Turning it on" says the script does it and keeps the manual steps as the fallback; `languages/README.md` and two header comments (`tools/layout-pack.sh`, `packs.yml`) follow the removed README tables. 11 new checks in `bootstrap/test-bootstrap-project.sh` (section "S19"); the README-table layout test was replaced by one that pins the table to the script. Two review rounds. Round 1 found a banned-word test that skipped every indented list line, and a README claim ("the command always ends with `--resume`") that the script contradicts; round 2 approved.
  - Open, non-blocking (round-2 review): the `--resume` sentence test (`bootstrap/test-bootstrap-project.sh`, about lines 8806-8810) checks one phrase and two forbidden wordings, so a differently worded false sentence passes; the table test (about line 8604) catches a by-hand pack table only when it names certain pack files (a table naming only `tsconfig.json` passed); the banned-word rule lets a word through when a bracketed explanation of three or more words follows it (predates S19); two README conditions ("web pack only", "not asked with no licence") are read from the script and no test pins them.
  - Not verified, for Adam's end-to-end runs: gh's own prompt and output texts that the README quotes ("Authenticate Git...", "Logged in as"); the GitHub Settings path and button names for limiting the Claude GitHub App; the Linux install link; whether someone with no help can follow the README (PBI-1.14 "Done when" 7); bash 3.2 and Git Bash behaviour of the new checks beyond what CI ran.

**Notes from PBI-1.18, the Windows leg (#177 spec, #178 sharding), 2026-10-18 to 2026-10-20:**
- Measured from the logs of run 39070866362: the bootstrap script's tests took 18.9 min on ubuntu, 24.3 on macOS and 72.5 on Windows; all 294 tests were slower on Windows (median about 14 times) and the cost tracks process launches (about 24 to 36 ms each on Windows, about 2 ms on Linux). Not measured: why a launch costs more on Windows.
- #178 shards each OS leg into 4 and keeps the required check `bootstrapper-test`, which now also fails unless every shard of every OS reported and together ran every test exactly once. Two CI runs gave a Windows leg of 23.3 and 22.7 min. Two Opus review rounds: round 1 found an overflowing shard value accepted silently (fixed, red then green), round 2 found the code correct and left only the merge precondition (#177 first, Adam's answer on intent approval).
- Not verified: CI never ran with a shard actually failing or missing (local tests only); how "Re-run failed jobs" resolves earlier attempts' artifacts; the full 19-min harness locally; the new exit paths under a real bash 3.2 binary. Open non-blocking: a one-line fixture for the shard-index length guard in `bootstrap/check-shards.sh`, and two misleading messages there (`0256` reported as a count above 256; an extra manifest still prints "ran all tests").
- Option 2 of PBI-1.18 (cut process launches in the harness: the bash wrapper around every `git` call, many small commands per test) stays open and unmeasured.

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
- **New fact, 2026-10-05:** a Clead session in the Claude app (Cowork) had git, push access and the GitHub REST API once the repo was attached with push access, and started Opus Crog agents for build and review. The main advantage seen in Code is not Code-only. Adam kept this item open; not discussed yet.
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
3. Adam's model, 2026-10-02: one installer and one path, with decision points along the way. Each step is skipped when it already exists or is not needed for what the user is building, and otherwise done, or guided when the script cannot do it. To the user that can look like several entry points. The PBI-1.14 spec already works this way: the guided preflight checks tools, login and scopes and guides only what is missing, packs only check what they need (npm only for node, web and react-native), and `--resume` reads the repo's state and continues from the right step. Not covered: an existing app or a repo with code that wants the process. The spec refuses a repo the bootstrapper did not create, and migration was the superseded PBI-1.4 (close to item 1). In Adam's model that would be one more decision point (existing code found: add only the process). Should it exist, and if so in PBI-1.14 or as its own item?
**Added later the same day:**
- **Adam on the core value:** the template is instant onboarding of an already trained AI colleague. The repo puts the process and practices into every session on demand, with no re-training: a less knowledgeable WHAT person would not bring these practices, and a knowledgeable one would not want to re-train an AI from scratch each time. Examples: write things down as they are decided, `..wrap` as the safety net, the standing rules. Clead's note: Claude Code supplies the mechanism (CLAUDE.md loads automatically); the template supplies the content.
- **Open, for Adam:** measure the template's value instead of judging it (he named the risk of overvaluing his own creation)? Options: fix in advance what would make a feature go; use acuteping as a measurement (per guardrail: real problems caught versus time and tokens spent); a comparison run (the same small app with the template and with plain Claude Code).


### 16. A multi-agent bootstrapped project, and a possible v3 — new (2026-10-21)

**Adam (2026-10-21):** asked whether the package can be expanded so that a bootstrapped project becomes more multi-agentic, and whether that is a step towards something that could be called v3. Asked for the thinking to be kept as an idea for the future.

**Status:** an idea, documented only. Not a PBI, not decided, nothing built. It builds on PBI-4.4 (autonomous PR loop, `[LATER]`) and PBI-4.5 (Copi as a third-layer reviewer, `[LATER]`) and on item 15 (the product office overview).

**Where things stand (verified in the repo, 2026-10-21):** this repo already works multi-agent in practice: one orchestrating Clead session starts an implementer, separate reviewers who never saw the implementation, and merge-only agents. But the template ships only `CLAUDE.md`, `memory/roles.md` (two roles, Clead and Crog) and `docs/ROUTINES.md` (the wiring, in prose). It ships no agent definitions, so which agent runs, on which model, with which inputs is decided by the orchestrating session each time, in ad hoc briefs.

**Clead's first thoughts (not decided).** A multi-agent bootstrapped project would consist of:
1. **A roster as files:** one definition per agent (Claude Code supports project-level agent definitions) with its role, model, tools, the inputs it may receive and what it must never do. Candidates: implementer, reviewer, merger, perhaps researcher or tester.
2. **Briefing contracts:** a template per role for what the orchestrator hands over, for example "the reviewer gets only the diff and `memory/standards.md`", so that independence is built in.
3. **A written protocol:** task, implement test-first (red then green), independent review rounds (cap 3), CI, merge agent, verification against GitHub. Written once, the same in every project.
4. **The repo as the shared channel:** agents do not message each other; they leave PRs, review comments, check runs and handoff notes. No second copy of the state.
5. **Triggers, later:** the loop runs without a session (PBI-4.4). Needs tokens held as secrets, and has cost and permission limits (the proxy refused creating a tag on 2026-10-18).
6. **Hard guardrails:** CI gates and branch protection enforce the rules because agents are fallible (in PBI-1.18 an independent reviewer found a real silent-overflow bug; an implementer once measured a baseline while editing the file it was timing). Every merge and CI result is verified on GitHub, not taken from an agent's report.
7. **A view for Adam:** item 15, the product office querying each project for what happens next.

**Cheap and not cheap:** the roster files, briefing templates and protocol document, with a check that they exist and keep their headings, are cheap and would be one PBI in the template that bootstrapped projects inherit. The triggers are not cheap (secrets, runner minutes, permissions). Not verified: how a freshly bootstrapped project's Claude setup picks up the agent files; to be tested before promising it. More agents also means more cost and more handoffs that can go wrong, so add agents only where independence helps (review, verification).

**On v3 (Clead's judgement, not a rule; the repo has none on versioning):** the roster, briefing contracts and protocol add files and break nothing, so they would still be v2.x minor releases. The step that would justify calling it a new generation is the triggers (the loop runs by itself) or product office becoming the top layer, because they change how Adam operates, not only what the template contains. A practical test: if existing projects cannot adopt it without changes, it is v3.

**Open questions for Adam:**
1. Start with the cheap part as one PBI (roster, contracts, protocol)?
2. Where is the v3 line: the triggers, the product office layer, or the "existing projects cannot simply adopt it" test?
3. Does it extend the Clead and Crog model or replace it? (Replacing would be a break.)

### 14. How Clead reports to Adam — new (2026-10-02)

**Adam:** he does not read every long message. When Clead stops and waits for him, it ends with a short **For you** block: what it recommends and what it needs from him, including any recommendation made earlier in the message. **Action:** put this into CLAUDE.md with the next CLAUDE.md change (item 5), reviewed by Crog; until then every Clead session follows it from here.
### 15. The product office overlooking all projects: one way to ask any project what happens next — new (2026-10-20)

**Adam (2026-10-20):** the private product office (item 11) should sit as the head of product with a link to every project, and he should be able to go there and see what is going on in all projects. "What is going on" means what is going to happen and what is needed to progress, not a report of what has happened. No double storage: all the information about a project stays in that project; product office stores none of it, only queries the projects and reports up to Adam. There should be one unified way for the product office to query the status of the sub projects, and every project is aware of it.

**Status:** an idea, documented only. Not a PBI, not decided, nothing built. Adam asked for this note and nothing more for now.

**Clead's first thoughts (not decided):**
- **Source of truth stays in each project.** The forward view already exists in this repo as "Adam's to-do", "What waits for what" and the `[NEXT]` items in `docs/BACKLOG.md`. Product office keeps only a registry (project, repo, where its forward-looking sections are), and the overview is read from the projects when asked, never copied.
- **The unified way is a contract that the template defines and every bootstrapped project inherits:** stable section headings (and the rule that they hold only forward-looking content) in a file every project has. Which file and which headings is open. A CI check on the headings, like the test-first check, is one way to keep every project to it.
- **Verified from this repo, 2026-10-20:** a bootstrapped project gets `docs/NEXT_SESSION.md` and `docs/BACKLOG.md` (the fill table in `bootstrap/stubs/bootstrap-project.sh`), but the shipped `NEXT_SESSION.md` stub has only "Current situation summary", "What needs adapting" and "Items that do not change". It has no "Adam's to-do" and no "What waits for what", so the contract is not there today.
- **Access:** a session reads a private repo only if that repo is attached to it. This session is bound to this repo only. A product-office session would need each project repo attached, and anything private stays in the product-office repo, never here (item 11).
- **Overlap to settle first:** the backlog visualiser (PBI-1.11, moved to its own project) reads any project's `BACKLOG.md`. The overview could be that project or a sibling of it.

**Open questions for Adam:**
1. The form of the overview: a Claude session in product office that fetches live when asked (no new infrastructure), or a published page.
2. Where it starts: a PBI in the template defining the contract and its check, with the registry written separately in the product-office repo, or something else.
3. Which file and which headings are the contract, and whether it replaces or sits beside "What waits for what".


### 17. Are the setup answers saved to a file? — new (2026-10-25)

**Adam (2026-10-15), unanswered:** are the settings the bootstrap script collects (the answers to its questions) saved to a file; can that file be inspected; and what happens if its contents are changed? The session that was asked ran out of tokens; the next session (2026-10-17) noted the question but moved on to S19, and no later chat or repo file answers it (checked 2026-10-25 from the Claude Project's chats and this repo's `docs/` and `memory/`).

**Status:** open question for Adam to get answered. Clead answers it from `bootstrap/stubs/bootstrap-project.sh` as it is on `main`, checked, not from memory. If the answer shows a gap (for example nothing is saved and a resume needs the answers again), it becomes a PBI.

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
