# [PROJECT NAME] — Next Session Planning

**Last Updated:** 2026-11-18
**Author:** Clead (Tech Owner)
**Purpose:** Staging area for reasoning, revised assumptions, and plan-adaptation thoughts that aren't yet mature enough to be a PBI, a decision, a strategy update, or a vision-doc change. Complements `docs/BACKLOG.md` — it does not replace it. Discrete, scoped, actionable work belongs in the backlog as a PBI, not here.

**The rule that keeps this useful, not a junk drawer:** every entry below must get a disposition each session it's touched — promoted to a PBI, a decision, or a formal doc update; re-affirmed as still-next; or deleted as resolved/obsolete. This file is read and triaged at the start of every session (Process P-1 § 4 (3); dispositions: Process P-8 § 4). It is not a substitute for the backlog — it's where things live before they're ready to become backlog items.

---

## Handover (2026-11-17)

This file was cut from 134,970 bytes to a short handover (2026-11-17). What was finished is removed: Git has it. What was open is kept in the entries below, or in the backlog entry PBI-1.63, which points at the whole former text, [`docs/NEXT_SESSION.md` at `070efd6`](https://github.com/factoincognito/ai-project-template-v2/blob/070efd632f10c9fc73d235c9159627ea0d736d45/docs/NEXT_SESSION.md).

- **State of the project:** derive it from Git, not from this file: tags and `CHANGELOG.md` for releases (the last tag read on 2026-11-17 is v2.9.2, `8d5ee3b`), `STATUS.md`, `docs/BACKLOG.md`, the open PRs.
- **Who does what in a session:** `RULES.md` and the Rules it names.
- **Open work in the backlog:** PBI-1.54 (tests for the script lines that no test reaches) and PBI-1.63 (triage of the notes this file used to hold).

---

## Adam's to-do (things only Adam can do)

2. **Now: end-to-end run 5, on v2.9.3 (Adam, 2026-11-18 22:35).** Someone who has never used `gh` or a terminal sets up a project from the bootstrapper's README alone (PBI-1.14 "Done when" 7). After each run, `RULES.md` L § 12 (2) applies (`bash bootstrap/e2e-check.sh OWNER/NAME DIR` from a template clone), and the template's sessions record the run and its findings here (L § 12 (4)). Where the person gets stuck is a defect.
   - **Runs 1 to 4 are done:** run 1 (web pack, Windows, Git Bash; three attempts, 2026-10-26 and 2026-10-27), run 2 (node pack, Linux in WSL; twice, 2026-10-27 and 2026-10-28), run 3 (python pack, Windows, Git Bash; twice, 2026-10-29) and run 4 (react-native pack, `--non-interactive`, 2026-10-29). Their findings, r1a to r4a, were fixed and released in v2.5.0 to v2.8.3, except r2a (cosmetic, not fixed), r2b (fixed in [#445](https://github.com/factoincognito/ai-project-template-v2/pull/445), not released yet) and r3c (a Git Bash window that stopped responding at the git check; not reproduced; nothing changed). Their texts are in the former file (link above), under "Adam's to-do".
   - **Before run 5:** Adam's rehearsal of 2026-10-29 on v2.8.3 is done; its findings were addressed by PBI-1.29 (v2.8.4). The newcomer pre-check (PBI-1.30, `docs/NEWCOMER_PRECHECK.md`) passed on v2.8.5, v2.9.1 and v2.9.2 by Clead's verdicts and did not pass on v2.9.0 (fixed in [#407](https://github.com/factoincognito/ai-project-template-v2/pull/407)); on the v2.9.3 candidate it passed by Clead's verdicts (below). The newcomer was found; run 5 ran on 2026-11-22 (the bullet "Run 5 on v2.9.3" below).
   - **Newcomer pre-check on the v2.9.3 candidate, 2026-11-18 (passed, by Clead's verdicts; texts made on `main` at `a6a6d36`, after the release prep [#470](https://github.com/factoincognito/ai-project-template-v2/pull/470) and [#472](https://github.com/factoincognito/ai-project-template-v2/pull/472); persona on Haiku at low effort; both quotes found in the texts, so the run is kept; it got to the end of the screen).** A first run on the same texts was discarded: Clead mis-copied two lines of the screen into its prompt. Clead copied the texts into the repeated run's prompt again by hand and could not compare that prompt with the files, so a copying slip there cannot be ruled out; the quotes of its stops are in the texts.
     - **p2.9.3-a (README "What only this README covers", "After the script"):** "To create a Claude Project: \"How can I create and manage projects?\", https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects" gives only a link, no steps. Verdict: not a defect, as p2.9.0-a (links instead of steps were the fix chosen for p2.8.4-a, in the former file, link above). Not checked again on the live help page: the page fetch of this session needed an approval that was not given.
     - **p2.9.3-b (the screen's closing "What to do next"):** "in the Claude app, create a Claude Project for this project (how: https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects)" is the same link. Verdict: not a defect, for the same reason.
   - **Run 5 on v2.9.3, 2026-11-22 (result so far).** The newcomer ran the setup from the bootstrapper's README on the product owner's GitHub account; by 22:36 it had finished and made the public project [sugose/run5-1](https://github.com/sugose/run5-1) (web pack; the setup change [#1](https://github.com/sugose/run5-1/pull/1) merged). The product owner reported at 22:40 that the newcomer finished unaided, without asking for help and without getting stuck, so the run itself gives no finding against the README or the script (his report; the session did not watch the run, and did not check which environment it ran in). `bash bootstrap/e2e-check.sh sugose/run5-1 <fresh clone>` from template `main` at `1c436ac`, run from a cloud session at 22:38: 20 passed, 3 failed, 7 skipped. The 3 failures (the protection of `main`, the decision row that depends on it, the licence text) are reads that GitHub refused to the session (HTTP 403), not findings about the project; none of the three is checked. The check ran on a fresh clone, not on the newcomer's copy. Open: those three reads, on a computer whose `gh` can make them, and the decision whether run 5 counts as passed.
   - **acuteping is created with the setup script only after run 5 passes** (`RULES.md` L § 12 (1)).

---

## What needs adapting

Entries 1 to 4, 16, 17 and 18 are kept with their numbers, because other files cite them. The other entries (5, 6, 8 to 15) are in the former file, listed in PBI-1.63.

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

### 16. A multi-agent bootstrapped project, and a possible v3 — new (2026-10-21)

**Adam (2026-10-21):** asked whether the package can be expanded so that a bootstrapped project becomes more multi-agentic, and whether that is a step towards something that could be called v3. Asked for the thinking to be kept as an idea for the future.

**Status:** an idea, documented only. Not a PBI, not decided, nothing built. It builds on PBI-4.4 (autonomous PR loop, `[LATER]`) and PBI-4.5 (Copi as a third-layer reviewer, `[LATER]`) and on item 15 (the product office overview).

The full text, with Clead's first thoughts, is in the former file (link above), lines 444 to 468.

**Open questions for Adam:**
1. Start with the cheap part as one PBI (roster, contracts, protocol)?
2. Where is the v3 line: the triggers, the product office layer, or the "existing projects cannot simply adopt it" test?
3. Does it extend the Clead and Crog model or replace it? (Replacing would be a break.)

### 17. Are the setup answers saved to a file? — new (2026-10-25)

**Adam (2026-10-15), unanswered:** are the settings the bootstrap script collects (the answers to its questions) saved to a file; can that file be inspected; and what happens if its contents are changed? The session that was asked ran out of tokens; the next session (2026-10-17) noted the question but moved on to S19, and no later chat or repo file answers it (checked 2026-10-25 from the Claude Project's chats and this repo's `docs/` and `memory/`).

**Status:** open question for Adam to get answered. Clead answers it from `bootstrap/stubs/bootstrap-project.sh` as it is on `main`, checked, not from memory. If the answer shows a gap (for example nothing is saved and a resume needs the answers again), it becomes a PBI.

### 18. Rolling back a bad release — new (2026-10-26)

**Adam (2026-10-26):** fine with restoring the code of an earlier tag under a new tag ("feature-wise they are identical").

**What Clead read (2026-10-26, `main`, not tried):** the script runs only when its version equals the one the bootstrapper's `main` CHANGELOG.md names, and `gh repo create --template` copies the bootstrapper's `main`; so running an older script is refused, and what users get is whatever is on the bootstrapper's `main`. `bootstrap/require-on-main.sh` accepts any commit that is an ancestor of the template's `main`. So a rollback is: Adam tags the earlier release's template commit (v2.4.0: `7dd7fd0`) with a new, higher version; the tag run rebuilds that content, stamps it with the new version and publishes it as the bootstrapper's `main`. The other route is reverting the bad PRs in the template and releasing again.

**Status:** untested. Unchecked: whether anything refuses a tag on an older commit or a version lower than the published one, and whether a tag run on an old commit uses that commit's workflow and still has the secret it needs. Projects already made from a bad release are not changed by a rollback. Once tested, or when a rollback is first needed, this goes into `docs/DEV_INFRASTRUCTURE.md` as the procedure.

---

## Items that do not change

The standing rules are the product office's Rules and `RULES.md`, which `CLAUDE.md` points to; they are not repeated here. What this section kept on reaching GitHub from a cloud session is in Process P-1 § 2 (3) (access per attached repository), P-2 §§ 3 (3) and 8 (REST only; clones), P-4 § 5 (2) (branch deletion) and § 11 (1) (release tags are Adam's), and on agents in Process P-1 § 6 and P-4 § 3.

- Draft and ready-for-review, review threads and auto-merge have `…/ccr/…` routes (the 403 message for GraphQL lists them).
