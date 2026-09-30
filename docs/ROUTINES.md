# Routines and Trigger Wiring

*Scope note: this document describes how reviews and Crog's work are triggered. Which changes need which review is in CLAUDE.md's "Change execution model" section.*

## Current state (2026-09-30)

1. The author opens the PR (Crog for code, Clead for docs, process and
   its own config changes).
2. Clead starts the review directly. No automation triggers it yet:
   `review.yml` only posts a `<!-- clead-review-ready -->` marker
   comment on PRs that touch `src/`, and nothing reads it.
3. The reviewer posts the verdict on the PR. Fix loop until approved,
   escalating to Adam after 3 rounds.
4. Crog merges once CI is green and the review has passed.
5. `changelog.yml` posts a reminder on every merge to open a CHANGELOG
   PR.

Adam is not in this loop and never relays messages. How Clead reaches
Crog today: by starting Crog as a separate agent from its own session,
with only the diff and `memory/standards.md` as input. Clead cannot
reach a Crog session running in Adam's VS Code (tested 2026-09-30 with
Remote Control from a cloud Clead session: not reachable).

## Target state

- PR opened: a workflow triggers Clead's review without Clead having to
  notice the PR.
- Clead's task comment on a PR triggers Crog (Path B in
  `memory/decisions.md`, open question 2).

Both depend on firing a Routine from GitHub Actions with its token held
as an Actions secret; not yet built or tested (backlog PBI-2.2, 4.4).

## Review Routine — input contract (hard constraint)

The review Routine must receive **only**:
- The PR diff
- `docs/SPEC.md`
- `memory/standards.md`

It must **not** receive:
- The implementation conversation history
- Design-time memory
- Any context from the session that produced the spec

This is a hard constraint. Reviewer independence is structural,
not conventional. Same-session context reset is not sufficient —
the context remains in the window and will influence the review.

## Crog prompt conventions

When Clead hands Crog a prompt, it is wrapped in a delimiter block:

    ========== CROG PROMPT HH:MM #N ==========
    <prompt text>
    ====================================

- **HH:MM** — 24h local time, freshly checked at write time (not
  reused from a prior prompt in the session).
- **#N** — a session-unique ID, starting at `#1` and incrementing by
  one for every subsequent Crog prompt in that same Clead session,
  regardless of which repo or PR the prompt concerns. Clead maintains
  this counter itself — it is not Adam's manual bookkeeping.
- **Purpose** — lets anyone refer back to a specific prompt
  unambiguously (e.g. "see CROG PROMPT 10:47 #1"). Since 2026-09-30
  Clead sends prompts to Crog itself; when Adam chooses to run a task
  in his own Crog tab, the delimiters show him exactly what to paste.
