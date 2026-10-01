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
| [SUPERSEDED] | No longer needed; the reason is given inline |

---

## Phase 1 — Language packs and bootstrap wizard

**Goal:** Make v2 a fully usable template — clone it, run the wizard,
get a working project in any supported language.

- **[DONE] PBI-1.1** (2026-09-30, PR #65) — Port Python language pack from v1
  (`languages/python/`) — ci.yml, code-standards.md, pyproject.toml,
  requirements.txt, requirements-dev.txt, pre-commit-config.yaml,
  gitignore, vscode settings, placeholder test. Adapt to v2 structure.
  Also create `docs/DEV_INFRASTRUCTURE.md` covering:
  - **Done 2026-09-30 (#57): the template root now has this
    `.gitattributes`, which new projects inherit.** Original text:
    **`.gitattributes` with an explicit line-ending policy (e.g.
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

- **[DONE] PBI-1.2** — Port Node/TypeScript language pack from v1
  (`languages/node/`) — ci.yml, code-standards.md, package.json,
  tsconfig.json, biome.json, gitignore, vscode settings, placeholder
  test. Adapt to v2 structure.

- **[DONE] PBI-1.3** (2026-09-30, PR #66) — Port React Native / Expo language pack from v1
  (`languages/react-native/`) — ci.yml, code-standards.md, package.json,
  app.json, tsconfig.json, biome.json, gitignore, vscode settings,
  placeholder test. Adapt to v2 structure.

- **[LATER] PBI-1.4** — Write the v2 bootstrap wizard (`BOOTSTRAP.md`)
  — guided setup via Claude chat, branches on new project vs migration
  from existing project, generates all project files for chosen language,
  produces Crog setup prompt. Migration branch must ask: source repo,
  Adam's WHAT call on v1 backlog items, sequencing (spec first, then
  tests, then src).

- **[DONE] PBI-1.5** (2026-09-30, PR #64) — Write `languages/README.md` — how to add a
  new language pack to v2.

- **[DONE] PBI-1.6** (2026-09-30, PR #63; Node 26 and TypeScript 7 left for a later refresh) — Refresh the Node pack's tool versions.
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

- **[DONE] PBI-1.7** (2026-09-30, PRs #45, #46) — Write the web pack (`languages/web/`) for static
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

- **[DONE] PBI-1.9** (2026-09-30) — Fix the README setup steps, which still say to
  "Create a Cowork project" (README.md lines 19-27 and 48-53, plus the
  Team table). Cowork is now part of Claude itself. Keep what still
  holds: one project per repository, and the repo files are Clead's
  memory. Docs only.

- **[NOW] PBI-1.10** (pipeline built in PR #60; done once the v2.1.0
  publish passes the "Done when" checks below) — Build pipeline that
  produces the bootstrapper.
  Intent approved by Adam in chat, 2026-09-30 (recorded on PR #58).

  **Why.** A project bootstrapped from this repo must not inherit the
  template's own working files (backlog, changelog, decisions, session
  notes, release notes); it should only record which template version
  it came from. This repo stays the development repo; a pipeline builds
  a clean bootstrapper from it and publishes it to a separate repo,
  `sugose/ai-project-bootstrap`, which is marked as a GitHub template
  repository. Projects are bootstrapped from there ("Use this
  template"), never from this repo and never by forking.

  **Manifest.** `bootstrap/manifest.txt` lists every path copied from
  this repo as is. Format: one path per line, relative to the repo root;
  blank lines and lines starting with `#` are ignored; no globs; a path
  that is a directory is copied recursively with everything in it; a
  listed path that does not exist is a build error. Initial content:
  `CLAUDE.md`, `.gitattributes`, `.gitignore`,
  `.github/PULL_REQUEST_TEMPLATE.md`, `.github/workflows/ci.yml`,
  `.github/workflows/review.yml`, `.github/workflows/changelog.yml`
  (workflows listed by file, so template-only workflows never ship),
  `memory/roles.md`, `memory/standards.md`, `docs/CROG_ONBOARDING.md`,
  `docs/ROUTINES.md`, `docs/SPEC.md`,
  `docs/decisions/0001-rebuild-workflow.md`, `languages`. When the
  bootstrap wizard (PBI-1.4, `BOOTSTRAP.md`) exists, it is added here.

  **Stubs.** `bootstrap/stubs/` mirrors the output layout and holds the
  clean starting version of each file that must not ship with this
  repo's content: `README.md` (placeholders plus the after-bootstrap
  steps: copy in a language pack, turn on branch protection including
  any extra required checks, fill in placeholders, delete the steps),
  `CHANGELOG.md`, `docs/BACKLOG.md`, `docs/NEXT_SESSION.md`,
  `memory/context.md`, `memory/decisions.md`, `memory/project.md`. A
  stub may not have the same path as a manifest entry or sit inside a
  manifest directory (build error: ambiguous source).

  **Version stamp.** The stub `CHANGELOG.md` contains the exact
  placeholders `{{TEMPLATE_VERSION}}` and `{{TEMPLATE_COMMIT}}`; the
  build replaces them with the release tag (e.g. `v2.1.0`) and the full
  40-character commit SHA it was built from. That entry is the only link
  back to this repo.

  **Build.** `bootstrap/build.sh <out-dir> <version> <commit>` writes
  the bootstrapper into `<out-dir>` (which must be empty or absent) and
  exits non-zero with a clear message if: a manifest path is missing; a
  stub overlaps a manifest path; `<version>` is not `vMAJOR.MINOR.PATCH`
  or `<commit>` is not 40 hex characters; a `{{TEMPLATE_` placeholder
  remains anywhere in the output; the output contains
  `docs/RELEASE_NOTES.md` or anything under `bootstrap/`; or any output
  file contains one of these exact strings: `trig_`, `(PR #`,
  `PBI-[0-9]` (regex), `open question [0-9]` (regex). The output
  contains exactly the manifest paths plus the stubs, nothing else.
  Shipped files must therefore be self-contained: where they need to
  refer to this repo's backlog or decisions, they link to this repo by
  URL instead (`docs/ROUTINES.md` does not yet, and is fixed in its own
  PR before the first release).

  **Tests.** Tests for `build.sh` (including each failure case above)
  run in a separate workflow, `.github/workflows/bootstrapper.yml`,
  which is not in the manifest (the shipped `ci.yml` must not reference
  `bootstrap/`, since bootstrapped projects have none). It runs on every
  PR and push, and its check is added to the required checks on `main`
  once it has run green once.

  **Publish.** The same workflow, on a pushed tag `v*`: runs the tests,
  builds, then makes the default branch of `sugose/ai-project-bootstrap`
  match the build output exactly (files not in the output are deleted),
  as one new commit per release (history kept there) with message
  `Bootstrapper <version> from sugose/ai-project-template-v2@<commit>`,
  and pushes the same tag there. If the bootstrap repo is empty, that
  commit is its first. If the tag already exists there, the publish
  fails rather than overwriting. It authenticates with the Actions
  secret `BOOTSTRAP_PUSH_TOKEN`.

  **Setup by Adam (cannot be done by an agent here).** Create
  `sugose/ai-project-bootstrap` (public, empty, no README) and tick
  "Template repository". Create a fine-grained token with access to that
  repo only and permissions **Contents: read and write** and **Workflows:
  read and write** (GitHub rejects pushes that add or change files in
  `.github/workflows/` without the latter), and save it as the secret
  `BOOTSTRAP_PUSH_TOKEN` in this repo. Fine-grained tokens expire: Adam
  sets the expiry and renews it; an expired token makes the publish
  fail visibly, nothing else breaks.

  **Known limitation.** The shipped process docs (CLAUDE.md,
  memory/roles.md and others) still name Adam as the product owner
  throughout; making them product-owner-neutral is a
  separate item ("De-Adamify", docs/NEXT_SESSION.md item 4).

  **Done when.** Tagging `v2.1.0` publishes a bootstrapper whose file
  list is exactly the manifest plus stubs, whose CHANGELOG names v2.1.0
  and its commit, and from which "Use this template" creates a repo
  with no template history.

- **[IDEA] PBI-1.11** (pinned by Adam, 2026-10-01) — Backlog visualiser:
  a way to see `docs/BACKLOG.md` as a backlog list and as a kanban board
  (columns by marker: NOW, NEXT, LATER, and so on). Open questions, not
  yet decided: where it runs (a generated page, a script, or an artifact),
  and whether `BACKLOG.md` stays the only source of truth, which it must,
  per the Memory rule in CLAUDE.md.

- **[IDEA] PBI-1.12** (pinned by Adam, 2026-10-01) — Delegation level as
  a bootstrapper option: when a project is bootstrapped, the product
  owner chooses how much control or delegation the processes give them.
  Adam's own setting today: merges, code-change reviews and more are
  delegated to Clead and Crog, while Adam still gives intent approval for
  architecture. A product owner who is a very skilled programmer might
  want to be involved in many more decisions. Open questions, not yet
  decided: whether the options can go further in the delegating
  direction than today's setting, and which rules in CLAUDE.md the option
  would change (review gates, merge delegation, intent approval).

---

## Phase 2 — Validate unproven pieces

**Goal:** Prove the two load-bearing assumptions before claiming full
autonomy. Use a real project as the pilot: acuteping (decided
2026-09-30; previously python-blackjack-v2, see Phase 3).

- **[SUPERSEDED] PBI-2.1** (the connector was written off 2026-06-28;
  Clead now uses git and the GitHub API, see memory/decisions.md; also
  duplicated PBI-4.3) — Confirm GitHub connector write access: verify
  that Cowork's GitHub connector can post PR comments, not just fetch
  diffs. The `review.yml` workflow posts a marker comment — confirm
  this fires correctly and Clead can read it to trigger review.

- **[LATER] PBI-2.2** — Start Clead's review automatically when a PR
  opens, instead of Clead having to notice it. Reworded 2026-09-30:
  the original premise (confirm the GitHub connector can write) is
  superseded; see PBI-2.3's findings. Possible mechanism, not built or
  tested: a Clead review Routine with **GitHub triggers** on
  `pull_request` (one trigger per action, or all actions with filters:
  base branch `main`, not draft), whose saved prompt is the Review
  Standard and which posts its verdict on the PR. Open design points
  for Adam's intent approval before building:
  - **Independence would be by prompt only.** A Routine clones the
    whole repo on every run, `memory/` included, so "reads only the
    diff, `docs/SPEC.md` and `memory/standards.md`" would be an
    instruction, not a structural limit as `memory/standards.md` §7
    requires.
  - **Identity.** A Routine acts on GitHub as its owner, so verdicts
    would be posted under Adam's account, as all PR activity already is.
  Setup it needs from Adam: install the Claude GitHub App on the repo
  and create the Routine (web, Desktop app or CLI `/schedule`; GitHub
  triggers from the CLI need Claude Code v2.1.225 or later). Fallback
  channel note, still valid: when Clead reads PR pages through Chrome,
  it appends an incrementing cache-busting parameter (`?i=1`,
  `?i=2`...) to each fetch, because GitHub can serve a stale cached
  view. Git and the API do not need this.

- **[DONE] PBI-2.3** (research, 2026-09-30) — Confirm whether Routines
  can use a secret without exposing it. Findings from the current
  Claude Code docs (code.claude.com/docs/en/routines and
  /cloud-environments; Routines are in research preview, so this can
  change):
  - **API credentials** (Pro and Max plans, not Team or Enterprise
    yet): a key stored on a cloud environment is attached by
    Anthropic's agent proxy to requests for the hosts you list; "the
    key never reaches Claude, the commands it runs, or the session's
    environment variables". **But the proxy never attaches a credential
    to requests for `api.anthropic.com`**, which is where a Routine's
    `/fire` endpoint lives. So API credentials do **not** let a Clead
    Routine fire Crog's Routine with a hidden token; dead ends B and C
    (memory/decisions.md, open question 2) still stand for that. API
    credentials only help with third-party APIs.
  - **Triggers:** schedule, API (`/fire` with a per-routine bearer
    token), and **GitHub events** (pull requests and releases, with
    filters; needs the Claude GitHub App on the repo). A GitHub trigger
    starts a Routine without any token held by Claude, so it is a
    documented, untested alternative both for starting reviews
    (PBI-2.2) and for starting Crog, e.g. on a label.
  - **Limits are hourly now, not 15 per day:** scheduled runs 100 per
    hour per account; Run now and API fires together 30 per hour per
    routine; API fires 100 per hour per account (counted separately
    from Run now); GitHub events have per-routine and per-account
    hourly caps without published numbers. Runs draw on subscription
    usage like interactive sessions.
  - Environment variables, unlike API credentials, are readable by
    anyone using the environment, so they are not for secrets.
  Next step (Adam's call): whether to try GitHub-triggered Routines for
  reviews (PBI-2.2) or for starting Crog (PBI-4.4).

---

## Phase 3 — python-blackjack-v2 migration

**Goal:** Migrate python-blackjack from v1 to v2.

**Status:** undated. No longer the template's pilot; acuteping took
that role on 2026-09-30.

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

- **[SUPERSEDED] PBI-4.3** (duplicate of PBI-2.1, superseded the same
  way) — Verify GitHub connector write access.
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

- **[DONE] PBI-P.1** (2026-09-30, CLAUDE.md "Change execution model") — Document the explicit change-control model Adam
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
| 2026-06-27 | ~~python-blackjack-v2 as pilot project~~ — superseded 2026-09-30 | Originally: real, complex, known codebase. acuteping became the pilot instead; see memory/decisions.md. |
| 2026-06-27 | Doc-only changes owned by Cowork-Clead, no review gate | Cowork is both author and reviewer for its own memory writes — review adds no value. Review gate reserved for src changes where Crog implements and Clead reviews independently. |
| 2026-06-27 | Copi reactivated as Layer 3 only for complex src PRs | Copi's value is cross-file consistency on large/complex changes. Default reviewer role removed — called in deliberately by Clead's judgment. |
| 2026-06-27 | ~~Session-end autonomous write via Cowork schedule skill~~ — superseded 2026-06-28 | Originally: inactivity timeout as primary trigger. Superseded by the PBI-4.2 reframe — event-driven memory writes replace the inactivity model; the schedule-skill investigation is deprioritised. See PBI-4.2. |

---

## Explicitly out of scope for Phase 1

- C# language pack — planned in v1, not yet built, not a Phase 1 priority
- Elixir language pack — same
- Automated merge — Adam merges, always
