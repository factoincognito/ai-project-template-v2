# Release Notes — v2.0.0

> **Corrected 2026-09-30.** Some items below were described as
> delivered but were plans. They are now marked as such, and
> "Status as of 2026-09-30" at the end lists what has changed since.

**Date:** 2026-06-27
**Replaces:** sugose/ai-project-template (v1)

---

## What's new

**Repo-committed memory system (`memory/`)**
Clead's persistent context lives in the repo as committed files.
Cold-start loads automatically via Cowork's working folder. No
dump file, no paste ritual, no orientation script required.

**GitHub Actions event bus**
Three workflows:
- `review.yml` — posts a review-ready marker on PRs touching `src/`
  (nothing reads it yet)
- `changelog.yml` — posts a reminder to update the CHANGELOG on merge
- `ci.yml` — a stub that only checks out the code; lint, format, tests
  and coverage come from a language pack's `ci.yml`

**Session mode router (designed, not built)**
The design: Clead checks Routine credit balance and expected PR
volume at session start and recommends Routine, Hybrid, or CLI mode
for the day, with credit tracking via a GitHub repository variable.
Only the design exists (`memory/decisions.md`, open question 2).

**Three-tier spec approval ceremony**
Ceremony scales with change significance:
- Small PBI — verbal approval in Cowork chat
- Significant change — `Status: Adam approved [DATE]` committed
  to `docs/SPEC.md`
- Architectural change — spec reviewed and merged via PR

**WHAT/HOW collaboration model (explicit)**
Adam owns the WHAT on all axes — domain, process, and technical
knowledge. Clead owns the HOW — fills the gap regardless of width.
The gap is multidimensional; Clead reads its shape and fills
accordingly. Documented in `memory/roles.md` and ADR 0001.

**ADR log (`docs/decisions/`)**
Every significant design decision is documented with rationale.
Controls cannot be silently removed without understanding why
they exist. Starts with ADR 0001 — the founding document.

**Dual-audience `CLAUDE.md`**
Single file serves both Clead (router/index to memory files)
and Crog (stub redirecting to `docs/CROG_ONBOARDING.md`).
No conflation between the two audiences.

**Migration branch in bootstrap wizard (planned — PBI-1.4)**
The setup wizard will branch on "new project vs migration from
existing." Migration path asks for source repo, prompts Adam to
make a WHAT call on each v1 backlog item, and enforces the
correct sequencing: spec first, tests, then src — with v2 spec
as the target throughout.

---

## What changed

**Clead's surface: Chat → Cowork**
Clead moves from Claude Chat to Cowork. Cowork has GitHub
connector access, persistent working folder, and chat in one
surface. No context-switching between tools.

**Review trigger: Adam relay → GitHub Actions marker**
Previously: Adam copied PR URL and pasted it to Clead.
Planned: `review.yml` posts a marker comment and Clead picks it up.
At release nothing read the marker, so Adam still pasted the PR URL
to Clead.

**Fix prompts and verdicts: Adam relay → direct PR comments**
Previously: Clead produced a prompt, Adam copied it, pasted it
to Crog.
Now: Clead posts fix prompts and verdicts directly to the PR
as comments. Crog picks them up from the PR thread.

**Crog→main trigger: Adam paste → Path B (planned)**
Previously: Adam substituted token in Clead's curl and fired it.
Now (transitional): same — one paste per PBI.
Target: GitHub Actions holds Crog's token as an Actions secret
and fires the curl. Adam removed entirely. Pending PBI-2.2.

**CHANGELOG updates: Adam manual → Crog post-merge**
Previously: Adam edited `CHANGELOG.md` after every merge.
Now: `changelog.yml` triggers Crog to update after merge.

**Copi: active reviewer → not present (by default)**
Copi is absent from v2 by deliberate starting position, not
permanent exclusion. In v1, Clead and Copi covered complementary
blind spots (diff-only vs full-file). In v2, Clead fetches diffs
and files directly, which may eliminate the structural reason for
Copi's role. Decision deferred until
Clead's solo review performance is observed on a real project.
See `memory/decisions.md` open question #4.

**Session startup: dump.sh + paste → automatic**
Previously: Adam ran `bash tools/dump.sh`, pasted the output
into a new Claude Chat session as the first message.
Now: Cowork loads `CLAUDE.md` and `memory/` from the working
folder automatically. First message is today's work.

---

## What's removed

| Removed | Reason |
|---|---|
| `tools/dump.sh` | Replaced by repo-committed memory + Cowork auto-load |
| `tools/dump-wrapper.sh` | Same |
| `tools/pr_dump.sh` | Replaced by Clead's direct GitHub fetch. Retained in v1 as non-load-bearing fallback for Chat-only sessions. |
| `docs/TEAM_STRUCTURE.md` | Contained workaround documentation, not principles. Replaced by one-page rules in `docs/CROG_ONBOARDING.md` and `memory/roles.md`. |
| `docs/CLEAD_ONBOARDING.md` | Replaced by `memory/` files |
| `docs/NEXT_SESSION.md` | Replaced by `memory/` files. Reintroduced 2026-07-23 in a new role: a staging area read at session start (PR #22). |
| `?i=1` re-report convention | Existed only to track clipboard relay iterations. Gone with the relay. |
| Hard-stop rule | Existed to gate implementer on Adam between iterations. Gone — Clead communicates directly with Crog via PR comments. Safety function retained as 3-cycle loop cap with escalation to Adam. |
| STOP-and-wait scaffolding | Same root cause as hard-stop rule |
| Copilot label-based review mechanism | Copi not present in v2 by default. The label lifecycle, `ai-review` label, `copilot-review.yml` workflow, and all associated rules are removed. Available to re-add from v1 if Copi is reactivated. |

---

## What's not ready yet

*As of the release. For the current state see "Status as of
2026-09-30" below.*

| Item | Status | PBI |
|---|---|---|
| Python language pack | Not started | 1.1 |
| Node/TypeScript language pack | Not started | 1.2 |
| React Native language pack | Not started | 1.3 |
| Bootstrap wizard | Not started | 1.4 |
| GitHub connector write access confirmed | Unvalidated | 2.1 |
| Clead review invocation wired | Unvalidated | 2.2 |
| Routines secret injection | Blocked on Anthropic | 2.3 |

Until language packs and wizard are complete, project setup from
v2 requires manual configuration. Reference v1's `languages/`
directory and `BOOTSTRAP.md` for the content to adapt.

---

## Known issues

**Routine daily limit constrains sprint pace** *(out of date as of
2026-09-30: Routines now have hourly limits, see docs/BACKLOG.md
PBI-2.3)*
Max plan: 15 Routine executions per day. At 2 executions per PR
(Clead only, Crog as CLI): ~7 PRs/day. At sprint pace (10+ PRs/day)
CLI mode is the only compliant option. Path B (PBI-2.2) may
reduce this to 1 execution per PR (~15 PRs/day) if GitHub Actions
fires Crog instead of a Routine.

**Reviewer independence requires separate invocation**
Clead's review must load only `{diff, SPEC.md, Review Standard}`.
Same-session context reset is insufficient — context remains in
window. Until a dedicated review Routine is wired, reviewer
independence relies on discipline rather than structural enforcement.

**June 15 billing change paused**
Anthropic announced moving Agent SDK and GitHub Actions Claude
usage to a separate monthly credit. This change was paused on
June 15, 2026. Current subscription limits unchanged. Expect it
to land eventually — when it does, Path B (GitHub Actions firing
Crog) will consume from the Agent SDK credit, not the subscription.

---

## Status as of 2026-09-30

- **Language packs:** Node/TypeScript (PBI-1.2) and web (PBI-1.7,
  with an optional Cloudflare deploy) are in `languages/`. Python
  (1.1) and React Native (1.3) are not started. The bootstrap wizard
  (1.4) is not written; packs are copied in by hand.
- **GitHub connector:** written off 2026-06-28. Clead now works through
  git and the GitHub API; Chrome is the fallback. PBI-2.1 is superseded.
- **Review and merge:** delegated by Adam. Clead and Crog review each
  other's work; Crog merges once the review passes and CI is green.
  Adam is not a relay. See CLAUDE.md, "Change execution model".
- **Branch protection:** on for `main` (PR and `build` check required,
  no bypass).
- **Pilot project:** acuteping, replacing python-blackjack-v2.
