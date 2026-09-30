# ai-project-template-v2 Product Backlog

**Status:** Living document
**Owner:** Adam with Clead

---

## How to read this backlog

| Marker | Meaning |
|---|---|
| [NOW] | Active — being worked on |
| [NEXT] | Queued — ready to start after current work |
| [LATER] | Confirmed future work, not yet scheduled |
| [IDEA] | Unvalidated — needs discussion |
| [BLOCKED] | Waiting on dependency or decision |
| [DONE] | Completed and merged |

---

## Phase 1 — Language packs and bootstrap wizard

**Goal:** Make v2 a fully usable template — clone it, run the wizard,
get a working project in any supported language.

- **[NEXT] PBI-1.1** — Port Python language pack from v1
  (`languages/python/`) — ci.yml, code-standards.md, pyproject.toml,
  requirements.txt, requirements-dev.txt, pre-commit-config.yaml,
  gitignore, vscode settings, placeholder test. Adapt to v2 structure.
  Also create `docs/DEV_INFRASTRUCTURE.md` covering:
  - **`.gitattributes` with an explicit line-ending policy (e.g.
    `* text=auto eol=lf`), committed as part of initial scaffolding —
    not optional, not added later.** Justification: fomo-f (running v1
    workflow) hit three separate rounds of full-file corruption on the
    same PR (2026-07-23) from VS Code's `files.eol: auto` silently
    rewriting entire files on save when a Cowork-Clead edit and a
    Windows-side edit touched the same file. Root cause confirmed by
    Crog; fix was reactive, after real damage. A pinned `.gitattributes`
    from day one prevents the whole class of bug rather than discovering
    it mid-project.
  - **`docs/NEXT_SESSION.md`, seeded from the template stub, committed as
    part of initial scaffolding for every project derived from this
    template — not optional, not added later.** Justification: fomo-f
    (running v1 workflow) has this exact file, but it was introduced
    reactively mid-project, was never wired into the session-start
    routine, and went stale for nearly a month as a result (confirmed
    2026-07-23: zero references to it anywhere outside the file itself).
    A project bootstrapped from this template should inherit both the
    file and its wiring (session-start read+triage step,
    graduation/expiry rule) from day one, the same way v2 itself now has
    it.
  - Language-agnostic content: new machine setup sequence, CI/CD
    philosophy, branch protection runbook, commit message convention
  - Python-specific content: venv setup (macOS and Windows),
    pip install sequence, pre-commit install, pytest run, ruff check,
    always run as module not script (`python -m src.<module>.main`),
    the MagicMock Python 3.14 gotcha (construct mock before patch
    context, not inside it — see v1 docs/DEV_INFRASTRUCTURE.md
    section 5 for full detail)
  PBIs 1.2 and 1.3 extend DEV_INFRASTRUCTURE.md for their languages.
  Reference: sugose/ai-project-template `docs/DEV_INFRASTRUCTURE.md`
  for the full v1 content to inform (not copy) this document.

- **[NEXT] PBI-1.2** — Port Node/TypeScript language pack from v1
  (`languages/node/`) — ci.yml, code-standards.md, package.json,
  tsconfig.json, biome.json, gitignore, vscode settings, placeholder
  test. Adapt to v2 structure.

- **[NEXT] PBI-1.3** — Port React Native / Expo language pack from v1
  (`languages/react-native/`) — ci.yml, code-standards.md, package.json,
  app.json, tsconfig.json, biome.json, gitignore, vscode settings,
  placeholder test. Adapt to v2 structure.

- **[LATER] PBI-1.4** — Write the v2 bootstrap wizard (`BOOTSTRAP.md`)
  — guided setup via Claude chat, branches on new project vs migration
  from existing project, generates all project files for chosen language,
  produces Crog setup prompt. Migration branch must ask: source repo,
  Adam's WHAT call on v1 backlog items, sequencing (spec first, then
  tests, then src).

- **[LATER] PBI-1.5** — Write `languages/README.md` — how to add a
  new language pack to v2.

- **[LATER] PBI-1.6** — Refresh the Node pack's tool versions.
  PBI-1.2 ported v1's pins unchanged: Biome 1.9.4, Jest 29.7.0,
  @types/jest 29.5.14, ts-jest 29.2.5, TypeScript 5.7.3, Node 22. On
  2026-09-30 npm's latest were Biome 2.5.14, Jest 30.5.2, @types/jest
  30.0.0, ts-jest 29.4.14 and TypeScript 7.0.2. Do not bump blindly:
  test the new combination on a fresh project with the same checks
  PBI-1.2 used (`npm ci`, `biome ci`, jest with the 80% coverage gate,
  `tsc`, and that the strictness flags still reject violations), then
  bump in one PR. Known or unverified points: Biome 2 changes the
  config format (`files.ignore` in `biome.json` moves to
  `files.includes`; `biome migrate` exists for this); whether ts-jest
  supports the new Jest and TypeScript majors is unverified; Node 22's
  remaining support window against the current LTS is unverified.
  Whichever Node version the pack targets must also match `ci.yml`.
  Also covers the web pack's pins (PBI-1.7), notably Playwright 1.56.1
  (npm latest on 2026-09-30: 1.63.0).

- **[NEXT] PBI-1.7** — Write the web pack (`languages/web/`) for static
  single-file web apps; the sonar calculator is its first user. It is
  self-contained like the other packs: the Node pack plus web
  additions, with starter files under `starter/` mirroring the project
  layout (`src/`, `e2e/`). Build: Vite + vite-plugin-singlefile produce
  one `dist/index.html` with no external requests. Checks: Jest for
  pure logic; Playwright against the built file in four projects
  (phone 375px and desktop 1280px, each in light and dark) that fail
  on console or uncaught errors, sideways scroll, a wrong colour
  scheme, or any request beyond the page itself. Verified on a scratch
  project with five deliberate breakages (console error, uncaught
  exception, 600px element, missing dark mode, external image): each
  failed exactly the checks it should. Playwright is pinned at 1.56.1
  because that build's Chromium is the one the verification
  environment can run; refresh under PBI-1.6. Not verified there: the
  CI step that installs the browser (`npx playwright install
  --with-deps chromium`). Deploy workflow: Cloudflare (Adam, 2026-09-30),
  where the calculator will be served as acuteping.com. `deploy.yml`
  uploads `dist/` as the static assets of a Worker configured by
  `wrangler.jsonc`; checked with `wrangler deploy --dry-run` only, a
  real deploy is not yet verified.

- **[LATER] PBI-1.8** — Licence choice at project setup: the template
  offers a set of licences (PolyForm Noncommercial among them) and the
  project picks one at start. Depends on the wizard (PBI-1.4), unless
  the licence texts are first added as files under `licenses/`.

- **[NEXT] PBI-1.9** — Fix the README setup steps, which still say to
  "Create a Cowork project" (README.md lines 19-27 and 48-53, plus the
  Team table). Cowork is now part of Claude itself. Keep what still
  holds: one project per repository, and the repo files are Clead's
  memory. Docs only.

---

## Phase 2 — Validate unproven pieces

**Goal:** Prove the two load-bearing assumptions before claiming full
autonomy. Use a real project (python-blackjack-v2) as the pilot.

- **[LATER] PBI-2.1** — Confirm GitHub connector write access: verify
  that Cowork's GitHub connector can post PR comments, not just fetch
  diffs. The `review.yml` workflow posts a marker comment — confirm
  this fires correctly and Clead can read it to trigger review.

- **[LATER] PBI-2.2** — Wire Clead review invocation: once write access
  is confirmed, replace the manual "Adam pastes PR URL to Clead" step
  with an automated trigger. Clead's review Routine receives the PR
  diff, SPEC.md, and Review Standard as scoped inputs only.
  Implementation note (confirmed in fomo-f, 2026-07-23): when Clead
  fetches PR state via Claude-in-Chrome (the Chrome fallback channel, see
  decisions.md), Clead itself must append an incrementing cache-busting
  query param on every fetch (e.g. `?i=1`, `?i=2`...) — GitHub PR pages
  can otherwise serve a stale cached view, showing an old commit/diff as
  current. This is Clead's own fetch-time responsibility only — Crog does
  NOT need to add this param when reporting a PR URL back; a plain URL is
  fine, Clead appends the cache-buster itself when it fetches. Cross-check
  against local `git log`/`git diff` where a shared working directory is
  available — more reliable than the browser alone.

- **[LATER] PBI-2.3** — Confirm Routines secret injection timeline with
  Anthropic. Once available, wire Clead→Crog trigger so Adam is no
  longer involved in firing Crog.

---

## Phase 3 — python-blackjack-v2 migration

**Goal:** Migrate python-blackjack from v1 to v2, proving the template
works on a real, complex project.

- **[LATER] PBI-3.1** — Bootstrap python-blackjack-v2 from v2 template

- **[LATER] PBI-3.2** — Populate python-blackjack-v2 with specs,
  processes, and docs — written fresh, informed by v1, adapted to v2
  philosophy. Adam reviews v1 backlog (done and not-done) and makes
  WHAT call on each item. Completed v1 work may be revisited.

- **[LATER] PBI-3.3** — Port test suite from python-blackjack v1 with
  v2 spec as target. Each test evaluated: does this behaviour belong in
  v2 spec? Does it express it in v2 terms? Rewrite or discard if not.
  All red is the correct end state.

- **[LATER] PBI-3.4** — Port src from python-blackjack v1 with v2 spec
  as target. Adapt, do not copy. Make tests green.

---

## Phase 4 — Autonomous PR loop and Copi reactivation

**Goal:** Eliminate Adam's remaining manual touchpoints for doc-only
changes and session-end writes, and reactivate Copi as a specialist
third-layer reviewer for complex src PRs.

- **[DONE] PBI-4.1** — Verify Cowork direct file write capability.
  Test whether Cowork-Clead can write files, commit, push, and open
  a PR directly from its working folder without going through Crog.
  If confirmed: doc-only changes (memory files, backlog, CHANGELOG,
  session-end writes) bypass Crog and the review gate entirely.
  Cowork-Clead is both author and committer. Adam merges or,
  once trust is established, Cowork merges directly.

  **Partial finding (fomo-f, 2026-07-23, informal — not a v2 test but a
  directly relevant real-world data point):** Cowork-Clead direct file
  writes to a connected folder work fine — read/write/edit on a mounted
  real repo folder, no issues. But git operations are a separate,
  unresolved hazard: while Crog was mid-git-operation on the same working
  directory, a Cowork-initiated `git status` hit `unable to unlink
  '.git/index.lock': Operation not permitted` — a real collision, not
  theoretical. Conclusion for this PBI: file writes and git operations
  should probably be treated as separately-confirmed capabilities, not
  one bundled "direct write" question. Before Cowork-Clead commits/pushes
  on its own, check for an active `.git/index.lock` (or equivalent) and
  avoid concurrent git access with Crog on the same repo.

  **Confirmed 2026-07-23 (this session):** the Chrome-web-editor path is proven end-to-end. Clead edited memory/decisions.md directly through GitHub's web file editor via Chrome, committed to a new branch, and opened PR #34 with no Crog involvement and no local git — then squash-merged and deleted the branch the same way. Four PRs total (#31-#34) were authored, reviewed (verdicts posted directly on each PR), merged, and cleaned up entirely through Chrome this session. This confirms the practical goal of this PBI (Clead-authored doc-only PRs bypass Crog) via the Chrome-web-editor mechanism specifically. The local-sandbox git push/commit mechanism (via Bash) remains a separate, unconfirmed, hazard-prone capability — see the git-lock finding above — and is intentionally left open; Chrome is the proven default for doc-only changes going forward.

- **[LATER] PBI-4.2** — Implement event-driven memory writes in CLAUDE.md.

  ## Reframe (from Cowork-Clead, 2026-06-27)
  Persistence is never automatic on session end. It only happens if
  something in a turn triggers it:
  - Adam explicitly asks ("update the memory files before we wrap")
  - An instruction in CLAUDE.md tells Cowork-Clead to persist at a
    natural stopping point
  - Cowork-Clead proactively decides a turn produced something worth
    persisting and writes it then and there

  The original framing — "trigger a session-end write on inactivity"
  — is the wrong model. The right model is event-driven writes at the
  moment something worth keeping happens. If every meaningful event
  triggers a write immediately, the session-end problem disappears.
  It doesn't matter if Adam leaves mid-session without saying anything.
  The last write happened when the last meaningful thing happened.

  The football problem resolves itself: if Adam leaves before anything
  was decided or committed, there's nothing worth persisting. The
  conversation was exploratory. It belongs in the chatlog, not the
  memory files.

  ## What we want to achieve
  CLAUDE.md contains explicit event-triggered write rules that
  Cowork-Clead executes turn by turn throughout the session:

  | Event | Write target | What to write |
  |---|---|---|
  | Decision made | `memory/decisions.md` | Decision + rationale, not discussion |
  | PR opened | `memory/context.md` | What changed and why |
  | Spec approved by Adam | `memory/project.md` | Updated scope/goal if changed |
  | Adam makes a WHAT call | `memory/decisions.md` | The call + which axis it came from |
  | Architectural direction set | `memory/decisions.md` | Decision + ADR reference if applicable |

  Rules: never write derivable state (current PBI, PR status). Never
  duplicate what's already there. Write the decision, not the
  discussion.

  ## What needs to be added to CLAUDE.md
  A new section: **Session memory rules** — numbered, explicit,
  event-triggered. Example structure:

  ```
  ## Session memory rules

  Execute these rules turn by turn. Do not wait for session end.

  1. When a decision is made → append to memory/decisions.md
     (decision + why, not the conversation that led there)
  2. When a PR is opened → update memory/context.md
     (what changed, why, current state)
  3. When Adam approves a spec → update memory/project.md
     if scope or goals changed
  4. When Adam makes a WHAT call that changes direction →
     append to memory/decisions.md immediately
  5. When asked "remember this" or "note that" → write to the
     appropriate file immediately
  6. Never write derivable state (current PBI, PR status)
  7. Never duplicate existing content — check before writing
  8. After writing to any memory file → open a PR via Crog
     (or write directly if PBI-4.1 confirmed)
  ```

  ## Implementation plan
  1. Draft the Session memory rules section for CLAUDE.md
  2. Adam reviews and approves the rules (WHAT gate — these are
     Adam's rules about how he wants the system to behave)
  3. Crog adds the section to CLAUDE.md via PR
  4. Cowork-Clead operates under the new rules from next session

  ## What this replaces
  The schedule skill investigation (Investigation A, B, C from the
  original PBI-4.2) is deprioritised. Event-driven writes solve the
  problem more cleanly than inactivity detection. The schedule skill
  may still be useful for other purposes but is not the solution
  to session memory persistence.

  ## Success criteria
  - Adam makes a decision mid-session
  - Without being asked, Cowork-Clead appends it to decisions.md
    and opens a PR (or commits directly if PBI-4.1 confirmed)
  - Next session starts with that decision already in the memory files
  - No gap to bridge, no chatlog to paste, no "where were we"

  ## Prerequisite
  PBI-4.1 (Cowork direct file write) confirms whether Cowork-Clead
  can commit directly or must go through Crog. Either path works —
  the event-driven write rules are the same regardless.

- **[LATER] PBI-4.3** — Verify GitHub connector write access.
  Confirm Cowork's GitHub connector can post PR comments, not just
  fetch diffs. Load-bearing for the autonomous review trigger (PR
  comment as event bus signal). If confirmed, enables Cowork-Clead
  to post verdicts, fix prompts, and approval comments directly to
  PRs without Adam relay. See also memory/decisions.md open
  question #1.

- **[LATER] PBI-4.4** — Wire autonomous src PR loop (Path B).
  GitHub Actions holds Crog's bearer token as an Actions secret.
  Cowork-Clead posts a task marker comment on a PR or sentinel
  location. Actions detects marker, fires Crog with clean task
  (no embedded credentials). Crog implements, opens PR, posts
  pr_done. Actions fires Cowork-Clead review Routine with scoped
  inputs {diff, SPEC.md, Review Standard}. Clead reviews, posts
  approval. Actions fires Crog merge instruction. Adam asleep.
  Prerequisites: PBI-4.1, PBI-4.3 confirmed.
  Reference: memory/decisions.md open question #2 (Path B) for
  full findings and dead ends already investigated.

- **[LATER] PBI-4.5** — Reactivate Copi as Layer 3 reviewer for
  complex src PRs.
  Three-layer review model:
  - Layer 1: Cowork-Clead alone — doc-only, memory writes (no review)
  - Layer 2: Crog implements, Clead reviews — standard src PRs
  - Layer 3: Copi added — large/complex/multi-file src PRs where
    cross-file consistency is the real risk
  Copi invoked by Clead's explicit decision per PR, not by default.
  Label-based trigger model from v1 applies unchanged.
  Reference: sugose/ai-project-template docs/COPILOT_LIMITATIONS.md
  for all operational lessons — do not re-investigate dead ends
  already documented there.
  Decision criteria for Layer 3: multi-file changes, interface
  changes, significant new components, any PR where Clead's
  diff-only review flags uncertainty about cross-file consistency.

---

## Process & team documentation

Committed follow-up work, not raw ideas — tracked here rather than left
to fall out of a chat session.

- **[NEXT] PBI-P.1** — Document the explicit change-control model Adam
  stated on 2026-07-23 in `CLAUDE.md` and/or `memory/decisions.md` — it
  currently exists only in Clead's private cross-session memory, not in
  this repo, which conflicts with the project's own single-source-of-
  truth principle. Model to document:
  1. Every change goes through a PR. No direct commits to main,
     regardless of author, no exceptions — including previously
     narrow documented exceptions (see PBI-P.2 below).
  2. One PR, one fix. Never bundle unrelated changes into a PR just
     because they happened to be made around the same time.
  3. Two categories require peer review (an explicit OK) before
     merge: system/architectural changes (typically Clead-authored,
     Crog's OK required) and code changes of any kind — business
     logic, tests, config, tooling (typically Crog-authored, Clead's
     OK required). The review obligation follows the category, not
     strictly "whoever happened to author it" — if roles are reversed
     for a given change, the review still applies the normal way.
  4. Everything else is Clead's own call — no review gate required,
     but still goes through a PR (rule 1). Matches and generalizes the
     existing 2026-06-27 decision that doc-only Cowork-Clead changes
     skip the review gate.
  5. When Clead lacks the capability to execute something itself
     (e.g. no git push credentials in the Cowork sandbox — confirmed
     repeatedly this session for both this repo and fomo-f), Clead
     writes a prompt for whoever can (Crog or Adam) — an execution
     handoff, not a review handoff.
  6. When genuinely unsure whether to act alone or involve someone
     else, Clead asks Adam directly rather than guessing either way.
  This PBI itself is a doc-only, "everything else" change under the
  model above — no separate review gate needed, but must still go
  through its own PR.

- **[DONE] PBI-P.2** — Fixed stale "push to main" wording in
  `.github/workflows/changelog.yml`. The workflow's automated PR-merge
  reminder comment previously read "Crog: update CHANGELOG.md and push
  to main" — conflicting with the change-control model above (rule 1:
  every change via PR, no exceptions). Confirmed with Adam directly on
  2026-07-23 that there is no exception for this case. Reminder text
  updated to "Crog: open a PR updating CHANGELOG.md."

---

## Decision log (updated)

| Date | Decision | Rationale |
|---|---|---|
| 2026-06-27 | Language packs not carried over in skeleton | Skeleton is workflow structure only. Packs ported as explicit PBIs so each is reviewed against v2 structure. |
| 2026-06-27 | Bootstrap wizard deferred to PBI-1.4 | Language packs must exist before wizard can generate them. |
| 2026-06-27 | python-blackjack-v2 as pilot project | Real, complex, known codebase. Ideal for proving unproven pieces under real PR load. |
| 2026-06-27 | Doc-only changes owned by Cowork-Clead, no review gate | Cowork is both author and reviewer for its own memory writes — review adds no value. Review gate reserved for src changes where Crog implements and Clead reviews independently. |
| 2026-06-27 | Copi reactivated as Layer 3 only for complex src PRs | Copi's value is cross-file consistency on large/complex changes. Default reviewer role removed — called in deliberately by Clead's judgment. |
| 2026-06-27 | ~~Session-end autonomous write via Cowork schedule skill~~ — superseded 2026-06-28 | Originally: inactivity timeout as primary trigger. Superseded by the PBI-4.2 reframe — event-driven memory writes replace the inactivity model; the schedule-skill investigation is deprioritised. See PBI-4.2. |

---

## Explicitly out of scope for Phase 1

- C# language pack — planned in v1, not yet built, not a Phase 1 priority
- Elixir language pack — same
- Automated merge — Adam merges, always
