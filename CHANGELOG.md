# Changelog

All notable changes to ai-project-template-v2 are documented here.
Releases from v2.1.0 on are tagged in git; v2.0.0 predates tagging.
A bootstrapped project records the tag it was built from.

## [Unreleased]

## [2.1.0] — 2026-09-30

### Added
- Operational lessons from a live fomo-f session folded into docs/BACKLOG.md
  and memory/standards.md: mandatory `.gitattributes` line-ending policy in
  PBI-1.1 scaffolding, Chrome PR-fetch cache-busting note in PBI-2.2, a
  refined PBI-4.1 finding (file writes and git ops are separate
  capabilities), and a Review Standard addition on verifying claims
  directly rather than via proxy signals (PR #14)
- Clarified that the `?i=N` PR-URL cache-busting param is Clead's own
  fetch-time responsibility, not something Crog needs to add when
  reporting URLs (docs/BACKLOG.md wording fix) (PR #16)
- Added PBI-P.1 (document the change-control model Adam stated
  2026-07-23) and PBI-P.2 (fix stale changelog.yml wording) to the
  backlog under a new "Process & team documentation" section (PR #17)
- Fixed the stale "push to main" wording in the automated
  changelog-reminder comment in .github/workflows/changelog.yml (now
  reads "Crog: open a PR updating CHANGELOG.md"); closed PBI-P.2 (PR #18)
- Committed two working-tree-only edits carried over uncommitted from a
  2026-06-28 Cowork-Clead session — a GitHub-connector-availability
  check added to CLAUDE.md's session startup routine, and a matching
  session-notes entry in memory/context.md (PR #19)
- Added the "Clean session end state" checklist to CLAUDE.md — six
  criteria for verifying (not assuming) a session is genuinely closed
  out: no uncommitted changes, every PR resolved and independently
  verified, every follow-up persisted in the repo, direct (not
  pattern-matched) verification, CHANGELOG.md currency, and grounded
  "no open items" claims (PR #21)
- Added docs/NEXT_SESSION.md (staging area for plan-adaptation reasoning
  not yet mature enough to be a PBI, decision, or formal doc update) and
  wired it into CLAUDE.md's session-start routine plus a graduation-rule
  note under "Session end" (PR #22)
- Amended PBI-1.1 to require docs/NEXT_SESSION.md as mandatory day-one
  scaffolding for projects derived from this template, same tier as the
  `.gitattributes` requirement (PR #23)
- Added four raw, unprocessed items to docs/NEXT_SESSION.md's "What
  needs adapting" section, verbatim as Adam gave them, awaiting future
  triage (PR #24)
- Fixed a stale claim in CLAUDE.md's "Clean session end state" section
  (item 3), which incorrectly said this template didn't have a
  NEXT_SESSION.md yet — updated to reference docs/NEXT_SESSION.md now
  that PR #22 added it (PR #25)
- Documented the Crog prompt delimiter convention (CROG PROMPT HH:MM #N
  format, session-unique incrementing ID) in docs/ROUTINES.md (PR #27)
- Closed out the pr_dump-in-PR-comments question in memory/decisions.md —
  confirmed not part of v2's review flow, not reintroduced (PR #28)
- Added "The PIN workflow" section to CLAUDE.md and a new condition 7
  ("Pin list is empty") to the Clean session end state checklist (PR #29)
- Triaged docs/NEXT_SESSION.md's 2026-07-23 raw items — Copi, pr_dump,
  Crog-prompt-indexing, and PIN-workflow questions each given a
  disposition (PR #30)
- Clarified the merge approval/execution split in memory/roles.md — Adam's act of requesting or pasting an already-presented, approved merge prompt is itself the approval; the mechanical click may be delegated to Crog or Clead (PR #31)
- Added CHANGELOG entries for PRs #27-#30 (this entry's own PR) (PR #32)
- Removed the resolved 2026-07-23 triage entries from docs/NEXT_SESSION.md now that all four items had a disposition (PR #33)
- Added a memory/decisions.md entry confirming doc-only changes can be committed directly via Chrome driving GitHub's web editor, with no Crog involvement (PR #34)
- Marked docs/BACKLOG.md PBI-4.1 confirmed — the Chrome-web-editor direct edit/commit/PR/merge path proven end-to-end (PR #35)
- Added an explicit "Change execution model" section to CLAUDE.md distinguishing Clead-direct doc-only changes from Crog-implemented code changes (PR #36)
- Added a "verify live state before asserting routing/authority/process facts" discipline to Clead's role rules in memory/roles.md, ported from local Cowork auto-memory so it persists in the repo (PR #37)
- Added a scope note to docs/ROUTINES.md clarifying it describes the Crog PR flow only, cross-referencing CLAUDE.md's Change execution model section for doc-only changes (PR #38)
- Added CHANGELOG entries for PRs #31-#38 (PR #39)
- Promoted six mid-session pins to docs/NEXT_SESSION.md as untriaged items (PR #40)
- Added item 7 to docs/NEXT_SESSION.md: judgment-call routing between Clead-direct and Crog-delegated execution (PR #41)
- Added the Node/TypeScript language pack (`languages/node/`), ported from v1 and fixed so a fresh project's CI is green on day one; PBI-1.2 done (PR #42)
- Enforced the Node pack's documented strictness: `noImplicitReturns` and `noUncheckedIndexedAccess` in tsconfig, and a `tsc --noEmit` typecheck step in CI (PR #43)
- Added PBI-1.6 (refresh pinned tool versions), PBI-1.7 (web pack), PBI-1.8 (licence choice at project setup) and PBI-1.9 (README setup wording) to the backlog (PR #44)
- Added the web language pack (`languages/web/`) for static single-file web apps: Vite single-file build, Jest, and Playwright against the built file at phone and desktop width in light and dark (PR #45)
- Added an optional Cloudflare deploy workflow (`deploy.yml`, `wrangler.jsonc`) to the web pack; checked with `wrangler deploy --dry-run`, not yet with a real deploy (PR #46)

- Added CHANGELOG entries for PRs #39-#46 (PR #47)
- Recorded the 2026-09-30 decisions: "complete" means every claim is true, acuteping as pilot, Cloudflare, Clead in the Claude app and Crog in Claude Code, Adam never the relay, reviews and merges delegated, branch protection, no Copilot recommendation (PR #48)
- Ignored `.wrangler/` in the web pack's gitignore (PR #49)
- Defined the escalation message format for the 3-round review cap in the Review Standard (PR #50)
- Documented the change-control model in CLAUDE.md; PBI-P.1 done (PR #51)
- Made CROG_ONBOARDING match how PRs actually flow (PR #52)
- Described the review and Crog triggering as it works today in ROUTINES.md (PR #53)
- Rewrote the README setup to match how the template is used; PBI-1.9 done (PR #54)
- Corrected the v2.0.0 release notes, which described planned items as delivered (PR #55)
- Marked stale backlog items and context notes; PBI-2.1 and 4.3 superseded (PR #56)
- Added `.gitattributes` pinning LF line endings (PR #57)
- Specified the bootstrapper pipeline, PBI-1.10 (PR #58)
- Made ROUTINES.md self-contained so it can ship to bootstrapped projects (PR #59)
- Added the bootstrapper pipeline: manifest, stubs, build and publish scripts with tests, and a workflow that publishes a clean bootstrapper to sugose/ai-project-bootstrap on a `v*` tag (PR #60)

## [2.0.0] — 2026-06-27

### Added
- Initial project setup from ai-project-template-v2
- Repo-committed memory system (memory/ directory)
- CLAUDE.md dual-audience router (Clead index + Crog stub)
- docs/decisions/ ADR log — ADR 0001 adopted as founding document
- GitHub Actions workflows: CI, review dispatch, changelog trigger
