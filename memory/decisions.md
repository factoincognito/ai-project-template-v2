# Key Architectural Decisions

Key decisions, newest at the bottom of the table. The founding
decisions (2026-06-27) have their full rationale in
docs/decisions/0001-rebuild-workflow.md.

| Date | Decision | Rationale |
|---|---|---|
| 2026-06-27 | Rebuild from scratch rather than iterate on v1 | v1 complexity was proportional to workarounds, not to the problem |
| 2026-06-27 | Memory files are repo-committed, not Cowork-local | Self-contained vision + single source of truth rule. A fresh clone must find Clead fully oriented. Local Cowork memory breaks this. |
| 2026-06-27 | Do not store derivable state in memory | Current PBI derives from open PRs + BACKLOG.md. Memory holds only what cannot be derived. |
| 2026-06-27 | GitHub Actions drives the review loop | Chat sessions cannot poll. Actions is consistent with single-source-of-truth and keeps the PR thread as the coordination log. |
| 2026-06-27 | Reviewer runs as separate invocation with scoped inputs | Structural isolation required. Same-session context reset explicitly rejected — context remains in window and will influence review. |
| 2026-06-27 | Loop cap at 3 review cycles, then escalate to Adam | Safety control re-added. The v1 hard-stop rule carried this function as a side effect. Discarding relay mechanics must not discard the safety function. |
| 2026-06-27 | Cowork is the primary Clead surface | Cowork has GitHub connector, persistent working folder, and chat. Covers both execution and thinking sessions. |
| 2026-06-27 | CLAUDE.md serves both Clead and Crog with clear demarcation | Crog auto-loads CLAUDE.md via Claude Code. File must serve both audiences without conflating them. |
| 2026-06-27 | Bootstrap wizard branches on migration vs new project | Any team migrating from a previous workflow hits the same questions. Baked into wizard so it gets asked every time. |
| 2026-06-27 | Ported code is subject to v2 review standard | v2 spec is the target; source repo is reference only. Porting is not copying. |
| 2026-06-27 | pr_dump.sh retained as non-load-bearing fallback | May be useful for Chat-only sessions. Not load-bearing infrastructure in v2. |
| 2026-06-28 | `..wrap` is the session-end stop word that triggers a memory flush | Clead gets no automatic session-end signal — it only acts inside turns. A single explicit, unambiguous stop word is the most reliable trigger. One canonical phrase beats a vocabulary of synonyms (no fuzzy-matching). Wired into CLAUDE.md as a 5-step routine; event-based writes remain the backstop since `..wrap` only fires if Adam remembers to type it. Changed from `/wrap` to `..wrap` on 2026-06-28 — a leading slash collides with slash commands; the `..` prefix stays distinctive and non-command. |
| 2026-06-28 | GitHub connector parked as a write-off; Chrome extension is the review-loop channel | The `engineering:github` connector failed to surface any tools across two consecutive clean Cowork sessions (2026-06-28) despite reading "connected" at both account and plugin level. Treated as broken, not a transient handshake hang. The Claude-in-Chrome extension was validated end-to-end the same day: read (PR list + diff) and **write** (posted the PR #11 review verdict as a real comment). Chrome is now the channel for fetching PRs and posting verdicts/fix prompts until the connector is fixed or replaced. Trade-off: Chrome is slower than an API connector and requires the extension to be running and connected at session start. |
| 2026-06-28 | Connector outage confirmed platform-wide, not local | Web search surfaced multiple matching reports — Cowork-Windows "Connected but no tools" (anthropics/claude-code #57589, #61682) and a dated regression that broke ~June 25 2026 and stayed broken (#71542). Server-side, not Adam's config. Reinforces the write-off; revisit the connector only if/when the outage lifts. |
| 2026-06-28 | GitHub availability check added as startup step 2 in CLAUDE.md | A green "Connected" is not proof tools loaded. Probe for actual GitHub tools at session start; if none, fall back to Chrome and tell Adam. Catches a silent connector failure before relying on it. (CLAUDE.md working-folder edit — still needs to land in Git via Crog/Chrome.) |
| 2026-06-28 | No dedicated hurdles/retrospective log | Proportionality call. Hurdles already land where they fit (decisions.md dead-ends + write-offs, context.md narrative). Assemble a retrospective list on demand from existing docs rather than maintaining a third synced file. |
| 2026-07-23 | Chrome-fetched PR pages need a cache-busting query param on every fetch | Confirmed live in fomo-f (v1 workflow, same GitHub-connector-write-off + Chrome-fallback situation as v2): GitHub PR pages fetched via Claude-in-Chrome can serve a stale cached view — an old commit/diff shown as current — without an incrementing `?i=N` param. Directly applicable to v2's own Chrome fallback channel (PBI-2.1/4.3). Folded into PBI-2.2's implementation note in docs/BACKLOG.md. |
| 2026-07-23 | `.gitattributes` line-ending policy is mandatory in initial scaffolding, not an add-later item | fomo-f hit three separate rounds of full-file CRLF/LF corruption on a single PR (2026-07-23) from VS Code's `files.eol: auto` silently rewriting whole files on save whenever a Cowork-side edit and a Windows-side edit touched the same file. Reactive fix, after real content risk. Folded into PBI-1.1 (DEV_INFRASTRUCTURE.md scope) so v2 ships with this pinned from day one. |
| 2026-07-23 | Cowork-Clead direct file writes and git operations should be verified as two separate capabilities, not one bundled question | Informal finding from fomo-f (not a formal v2 test, but a directly relevant real-world data point): Cowork-Clead writing files to a connected/mounted folder worked cleanly with no issues. Git operations were a separate, real hazard — a Cowork-initiated `git status` hit `unable to unlink '.git/index.lock': Operation not permitted` while Crog was mid-operation on the same working directory. Refines PBI-4.1: confirm file-write and git-operation capabilities independently, and check for an active lockfile before any Cowork-initiated git action when Crog may be concurrently active on the same repo. |
| 2026-07-23 | Verdict-posting and merge-triggering must be a single atomic handoff, not two separately sequenced prompts | fomo-f incident: Clead's review verdict and the merge instruction were given to Crog as two separate prompts in sequence; Crog merged the PR before the verdict comment was posted, requiring a retroactive fix to get the review record onto the PR. V2's Review Standard (memory/standards.md item 6) already reduces this risk structurally — Clead posts the verdict directly to the PR itself, no Adam-relay step to desynchronize — but the underlying lesson generalizes: whatever action posts the verdict must happen before or atomically with whatever action triggers merge, never as a separate follow-up step that can be skipped. |
| 2026-07-23 | pr_dump-in-PR-comments confirmed not part of v2 review flow; not reintroduced | v1's convention of pasting pr_dump.sh output into PR comments existed solely because Clead had no GitHub read access. v2's review flow (Clead fetches PR diffs/files directly via GitHub connector when available, Chrome extension as the confirmed-working fallback since 2026-06-28) already replaces that need. tools/pr_dump.sh remains only as a non-load-bearing fallback for Chat-only sessions (per the 2026-06-27 decision above) — it is not, and will not be, an input to the review path. Confirmed via repo search 2026-07-23: no workflow, PR template, or onboarding doc references pr_dump as required. Raised again as a question in docs/NEXT_SESSION.md this session — this entry closes it so it doesn't recur. |
| 2026-07-23 | Doc-only changes are committed directly by Clead via Chrome driving GitHub's web editor (edit, commit to a new branch, open PR) — not routed through Crog | Session drift: every doc-only change this session was routed through a CROG PROMPT relay despite this being Clead's own call since the 2026-06-27 decision above. Confirmed 2026-07-23 that Chrome can drive the full edit-commit-PR flow end-to-end with no local git and no Crog involvement, closing PBI-4.1's direct-write question for the Chrome-web-editor path specifically (local sandbox git push remains separately unconfirmed/hazard-prone — see the git-lock finding same day). |
| 2026-09-30 | "Complete" means every claim is true | The template is complete by its own definition when everything it says it has or does is actually there and works. Things not built yet are fine if they are clearly marked as backlog. Adam's call; it scopes the cleanup before bootstrapping acuteping instead of building every planned feature first. |
| 2026-09-30 | acuteping is the pilot project, replacing python-blackjack-v2 | acuteping (the sonar calculator) is the first project created from v2, so it is the real test. blackjack-v2 stays in the backlog with no date. project.md's definition of done updated accordingly. |
| 2026-09-30 | Web pack deploys to Cloudflare | acuteping is hosted on Cloudflare (acuteping.com). The web pack's deploy workflow uploads `dist/` as static assets of a Worker via wrangler-action; GitHub Pages dropped. |
| 2026-09-30 | Surfaces: Clead in the Claude app, Crog in Claude Code | Adam runs the Claude app beside VS Code. Clead works in a Claude app session with git and the GitHub API (clones, pushes branches, opens PRs, posts comments), so the Chrome web-editor path is no longer needed. Crog is Claude Code: either Adam's VS Code tab or a separate Crog agent that Clead starts. |
| 2026-09-30 | Adam is never the message relay | Adam should not pass messages between Clead and Crog. Tested: Remote Control does not let Clead's cloud session reach Adam's VS Code Crog. Working route: Clead starts Crog as a separate agent, given only the diff and memory/standards.md, which keeps reviewer independence. |
| 2026-09-30 | Reviews and merges are delegated | Adam delegates reviewing and merging. Clead reviews Crog's and other sessions' code; Crog reviews Clead-authored code and config; once a PR's review passes and CI is green, Crog posts its verdict and squash-merges via the API. Clead reports merges to Adam; no per-PR merge cards. Adam keeps the final say and can revoke this. Supersedes the per-PR chat approval in roles.md. |
| 2026-09-30 | Branch protection on `main` | Requires a PR and the `build` check, no approving reviews (all PRs are opened under Adam's GitHub account, and authors cannot approve their own), no bypass for admins. Free on public repos; on a free plan private repos cannot have it. Not required: branches up to date before merge. |
| 2026-09-30 | Language packs do not recommend Copilot | v2 does not use Copilot by default, so the packs' VS Code extension lists no longer suggest it. |
| 2026-09-30 | Branch deletion is blocked from Clead's and Crog's cloud sessions | `git push --delete` returns 403 there, while merging via the API works. Merged branches stay until deleted in GitHub, or the repo setting "Automatically delete head branches" is turned on. |
| 2026-09-30 | Projects are bootstrapped from a built bootstrapper, not forked | Adam: a project should not inherit the template's history or working files, only record the template version. A release pipeline builds a clean bootstrapper from this repo and publishes it to `sugose/ai-project-bootstrap` (a GitHub template repository); the version and commit are stamped into the new project's CHANGELOG. "Bootstrap" is the term, not "fork" (a GitHub fork keeps history and a link back). Spec: PBI-1.10. |
| 2026-09-30 | Release tags are created by Adam from GitHub's Releases page | A tag push from Clead's cloud session was refused on 2026-09-30, like branch deletion. A release created there makes the tag, which starts the bootstrapper publish; v2.1.0 was released this way and verified. |
| 2026-09-30 | Language packs are tested on GitHub's runners by a template-only workflow (`packs.yml`, with `tools/layout-pack.sh`) | Packs are inert files in the template, so nothing ran them before. Each pack is laid out in a fresh project and runs its own CI on every PR. Not shipped to projects. The pack jobs are not required checks; `build` and `bootstrapper-test` are. |
| 2026-09-30 | Adam can hand Clead and Crog an autonomous batch with a scope rule | First used overnight: "Phase 1 and 2 items that need no decision, until stuck". Clead posts progress as it goes, runs the normal review and merge loop, and parks anything needing Adam in docs/NEXT_SESSION.md instead of guessing. |
| 2026-10-01 | `..wrap` is the end-of-session check, with the graduation rule folded in; it is no longer a memory flush | Adam accepted Clead's 2026-09-30 proposal. Decisions are committed as they are made, so nothing is left to flush. `..wrap` now gives every touched NEXT_SESSION entry a disposition and resolves open pins, opens PRs for anything agreed but unwritten, runs the Clean session end state checklist last, and reports clean or what is open. Replaces the flush part of the 2026-06-28 decision; the `..wrap` stop word itself stands. |
| 2026-10-01 | The Clead and Crog Routines and their API tokens are deleted | Adam deleted both at claude.ai/code/routines after the 2026-09-30 decision made them unused (Clead starts Crog as an agent). Their trigger IDs remain in older git history but now point at nothing, so no history rewrite is needed. Verified against the account's Routine list the same day. |
| 2026-10-01 | The template stays public with no licence of its own; the files the bootstrapper ships are licensed under PolyForm Noncommercial 1.0.0, licensor Adam personally | Adam does not want the work used commercially. A private template would lose branch protection, so the repo stays public and the licence goes on what the bootstrapper ships. The licence text and NOTICE live under `licenses/`, never as a root `LICENSE`, because "Use this template" copies the root into each new project, where it would silently become that project's licence. Each project adds its own `LICENSE` (README step). A test pins the licence text. |
| 2026-10-01 | Crog agents keep running inside Clead's session; Crog is not started as a separate cloud session | Tested: an agent started with remote isolation ran in the same workspace as Clead (same hostname and working directory), so Crog agents run as part of the Clead session. Starting Crog as its own cloud session would make Adam the message relay again, which the 2026-09-30 decision rules out. Adam decided not to pursue running Crog outside the Clead session. |
| 2026-10-01 | A turn-key bootstrap script replaces the manual setup steps (PBI-1.14) | Adam: the script should be the only thing a user runs, for users with no technical skills ("a true WHAT person without HOW skills"). It creates the repo from the bootstrapper, protects `main` first and sets the project up through a PR, and guides the user step by step through anything it cannot do itself; what cannot be in a script is documented in the README. Adam approved the spec as recommended, including the one exception: the script merges the setup PR on a green `build` with no Clead or Crog review (to be named in CLAUDE.md rules 3 and 4 when the script is built). |
| 2026-10-01 | acuteping is created only after the whole toolchain is verifiably working | Adam: before the pilot project exists, the chain template, bootstrapper, instantiated project must be verified, not assumed. Order: the chain test before publishing (PBI-1.15), then the turn-key script (PBI-1.14) with Adam's end-to-end runs on throwaway repos, then acuteping is created with the script. Replaces the earlier plan to bootstrap acuteping by hand from the template button. |
| 2026-10-01 | In this template repo, test-first applies by kind of change | The TDD rule in `docs/CROG_ONBOARDING.md` is written for project source code and stays unchanged there. For the template's own work (Clead's call, the HOW): scripts with a test harness (`build.sh`, `publish.sh`, `layout-pack.sh`, the planned bootstrap script) are strictly test-first, failing tests shown red before the implementation, and Crog's review checks for it; workflows get a wiring assertion that fails against the old file plus a real run on GitHub, which is the actual proof; docs, backlog and decision records are exempt; every bug fix is preceded by a failing test (the chain test going red on `pack-python` before its fix is an example). PBI-1.15 was done red-after, not test-first: the tests were written after the workflow change and then shown to fail against the old files. |

## Open questions (unresolved as of 2026-06-27)
1. ~~Can the GitHub connector write PR comments, or only fetch diffs?~~
   **Resolved 2026-06-28 — superseded.** The connector won't load at all
   in Cowork (two clean sessions, no tools surfaced), so its write
   capability is moot. Channel question re-answered via the Chrome
   extension instead: read AND write both proven (PR #11 verdict posted
   as a real comment). See the 2026-06-28 connector/Chrome decision row
   above. Reframes PBI-2.1/4.3 from "confirm connector write access" to
   "Chrome is the channel; revisit connector only if it starts working."
2. Clead→Crog direct firing — full findings, dead ends documented,
   one viable path remaining. Complete history below so future Clead
   can execute without reconstructing the reasoning.

   ## What was built and confirmed working

   Two Claude Code Routines exist at claude.ai/code/routines:

   **Clead Routine (Tech Owner)**
   - Fire URL: kept out of this public repo (see the private notes)
   - NO repositories attached — mandatory, see Dead End A below
   - Standing prompt: includes ADAM-AUTH verification, task drafting,
     curl production, and "never attempt outbound HTTP POST" rule
     (see Dead End B below — this rule exists for a reason)

   **Crog Routine (Task Executor)**
   - Fire URL: kept out of this public repo (see the private notes)
   - All sugose repos attached
   - Token: regenerated multiple times — always store current token
     in password manager immediately; regenerating invalidates previous

   **Correct curl format — mandatory single line, -s flag in Git Bash:**
   ```bash
   curl -s -X POST "https://api.anthropic.com/v1/claude_code/routines/<ROUTINE_ID>/fire" -H "Authorization: Bearer <TOKEN>" -H "anthropic-version: 2023-06-01" -H "anthropic-beta: experimental-cc-routine-2026-04-01" -H "Content-Type: application/json" -d "{\"text\": \"<TASK>\"}"
   ```
   Multiline curl with backslash continuation fails silently in Git Bash.
   Payload field is "text" not "prompt".

   **ADAM-AUTH scheme:**
   Adam fires Clead with "ADAM-AUTH" in the text field. Clead
   verifies before acting. Without it, Clead rejects as untrusted.

   ---

   ## Current working state (the only compliant option today)

   1. Adam fires Clead Routine via curl with ADAM-AUTH + task in text
   2. Clead produces task spec and curl with <CROG_TOKEN> placeholder
   3. Adam substitutes real token from password manager, fires Crog CLI
      (not Routine — see Execution Model below)
   4. Crog implements, opens PR
   5. Adam pastes PR URL to Clead in Cowork
   6. Clead reviews, posts verdict to PR
   7. Adam merges

   Note: Crog runs as Claude Code CLI in steps 3-4, not as a Routine.
   This is important — see Execution Model section below.

   ---

   ## Execution model: Routine vs CLI for Crog

   Crog can run in two modes:

   **Routine mode:** Crog fired via curl POST to Routine endpoint.
   Counts against 15/day Routine limit (Max plan). Autonomous once
   fired — no Adam involvement.

   **CLI mode:** Adam opens Claude Code terminal, pastes task prompt.
   No Routine invocation. No daily limit. Requires Adam's presence
   to start but zero constraints after that.

   **The daily limit reality (confirmed from Anthropic docs):**
   Max plan: 15 Routine executions per day total across all Routines.
   Pro plan: 5/day. Team/Enterprise: 25/day.
   Extra executions available via "extra usage" — pricing unconfirmed.
   Reset cadence: daily (exact reset time and timezone unconfirmed —
   needs verification; Adam is in Stockholm/CEST which is UTC+2).

   **At 4 Routine executions per PR (Clead task + Crog implement +
   Clead review + Crog changelog), Max plan allows 3-4 PRs/day.**
   bj-v1 ran ~14 PRs/day during active sprints. Incompatible.

   **At 2 Routine executions per PR (Clead only, Crog runs as CLI),
   Max plan allows ~7 PRs/day.** More viable for normal cadence.
   Still below sprint pace.

   **At 1 Routine execution per PR (Clead review only, everything
   else CLI or Actions), Max plan allows 15 PRs/day.** Matches
   bj-v1 sprint pace. Requires Path B (see below).

   ---

   ## Dead ends — evaluated and non-compliant with our setup

   ### Dead End A — Repos attached to Clead Routine
   Attaching repos to Clead's Routine caused CLAUDE.md files to
   auto-load and override Clead's standing prompt identity. Clead
   started rejecting its own legitimate tasks as prompt injection.
   **Fix confirmed:** Clead Routine must have NO repos attached. Ever.
   Crog Routine has all repos attached. This separation is mandatory.

   ### Dead End B — Token in Clead standing prompt
   Embedding Crog's bearer token in Clead's standing prompt caused
   security failure: token travelled in forwarded context, Crog
   flagged it as prompt injection, token exposed in transcript,
   had to be rotated immediately.
   **Status:** Dead end. Token removed from standing prompt entirely.
   "Never attempt outbound HTTP POST" rule added as safety measure.

   ### Dead End C — Token in task payload (curl-in-prompt)
   Proposed workaround: pass Crog's token to Clead via Adam's text
   field at fire time. Clead extracts and uses once. Never persists.
   **Blocked by two independent problems:**
   1. Clead's standing prompt explicitly forbids outbound HTTP POST
      calls (rule added after Dead End B). The rule exists for a
      reason — do not remove without solving the network problem first.
   2. Routine network policy: Default environment blocks outbound
      requests to arbitrary domains with 403/host_not_allowed.
      api.anthropic.com is not in the default allowed list. Clead's
      Routine cannot POST to Crog's Routine endpoint unless
      api.anthropic.com is added to allowed domains in Routine config.
      This has not been tested. Worth trying — but even if it works,
      Dead End B's security concern remains.
   3. Crog's own security posture: confirmed in live test that Crog
      blocks payloads containing embedded bearer tokens as prompt
      injection, regardless of how they arrive.
   **Status:** Dead end unless all three problems are solved
   simultaneously. Do not attempt without addressing all three.

   ### Dead End D — Routines as primary execution model at sprint pace
   At 4 Routine executions per PR and 15/day Max limit: 3-4 PRs/day
   maximum. bj-v1 ran ~14 PRs/day. Factor of ~4 short of sprint pace.
   Even with secrets support this doesn't change — the limit is on
   Routine invocations, not on token security.
   **Status:** Non-compliant with sprint pace. Routines suitable for
   low-cadence work only unless daily limit is raised or extra usage
   pricing makes it viable.

   ---

   ## Billing context (important — read before investing in Routines)

   **Routines daily limit:** 15/day on Max plan. Shared across all
   Routines (Clead + Crog combined). Not per-Routine.

   **June 15 billing change:** Anthropic announced moving Agent SDK,
   headless Claude Code, Claude Code GitHub Actions, and third-party
   agents to a separate monthly credit ($200 for Max 20x) billed at
   API rates. **This change was paused on June 15, 2026 — it is not
   currently in effect.** Subscription limits unchanged as of session
   date. Anthropic will give advance notice before any future change.
   However: when it does land, GitHub Actions firing Crog (Path B)
   would consume from the Agent SDK credit, not the subscription.
   Plan accordingly.

   **Shared pool:** Interactive sessions (Cowork, Claude Code CLI,
   Claude chat) and Routines draw from the same subscription pool.
   Heavy Routine use competes with Cowork sessions.

   **No API endpoint for remaining credits:** Anthropic does not
   expose remaining Routine credit via API. Only option is checking
   the console manually or maintaining a counter.

   ---

   ## Credit tracking — proposed mechanism

   Since no API endpoint exists, tracking requires cooperation between
   Clead and Crog. Both agents increment a shared counter at the start
   of every execution.

   **The counter must NOT live in Git** — a commit per Routine
   execution pollutes git history with meaningless noise and requires
   direct main access.

   **Options for storage (in order of preference):**
   1. GitHub repository variable (via GitHub API) — both agents can
      read/write, no git commits, persists across sessions, Adam can
      check in GitHub UI. Recommended.
   2. Private GitHub Gist — both agents can read/write via GitHub API,
      persists, no git commits. Fallback if repo variables don't work.
   3. Manual — Adam checks Anthropic console at session start and
      tells Clead the starting count.

   **What to track:**
   ```
   Daily limit: 15 (Max plan)
   Reset time: [TBC — confirm exact UTC time and verify in Stockholm/CEST]
   Today's date: [DATE]
   Executions used today: [N]
   Executions remaining: [15-N]
   Last updated by: [Clead|Crog]
   Last updated at: [TIMESTAMP]
   ```

   **Reset time matters:** If close to reset, use remaining credits
   rather than switching to CLI. If far from reset and credits low,
   switch to CLI mode for the session. Adam is in Stockholm (CEST =
   UTC+2, CET = UTC+1 in winter). Reset time needs to be expressed
   in Stockholm local time for this to be actionable.

   ---

   ## The session mode router

   At the start of each session, Clead checks available Routine
   credits and recommends a mode for the day. This is a per-session
   decision, not per-PR, to avoid cognitive overhead of switching
   mid-session.

   **Router logic:**
   ```
   inputs:
     credits_remaining: N  (from counter or Adam's console check)
     prs_expected_today: M  (Adam provides at session start)
     time_to_reset: T  (calculated from reset time in Stockholm TZ)
     path_b_confirmed: true/false

   if T < 30 minutes:
     → use remaining credits now, full reset imminent
     → announce: "Reset in [T] mins — using Routine mode for
       current PRs, full credits available after reset"

   if path_b_confirmed AND credits_remaining >= M:
     → Routine mode: 1 execution per PR (Clead review only)
     → announce: "Routine mode — [N] credits, [M] PRs expected,
       sufficient headroom"

   if NOT path_b_confirmed AND credits_remaining >= M × 2:
     → Hybrid mode: Clead as Routine, Crog as CLI
     → 2 executions per PR (Clead task + Clead review)
     → announce: "Hybrid mode — Crog runs as CLI, [N] credits
       for [M] PRs"

   if credits_remaining < threshold:
     → CLI mode: Crog as CLI, Clead as Cowork (no Routine firing)
     → 0 Routine executions per PR
     → announce: "CLI mode — credits low ([N] remaining),
       all PRs via manual flow today"
   ```

   Clead announces the mode at session start and Adam knows what
   to expect for the day.

   ---

   ## Path B — the one viable path to reducing Routine executions

   **What it is:** GitHub Actions holds Crog's token as an Actions
   secret and fires the curl when triggered by a specific PR comment
   marker from Clead. Clead never touches the token. Crog receives
   a clean task with no embedded credentials. Crog runs as a Routine
   triggered by Actions HTTP call — but this counts as an Actions
   workflow call, not a Routine invocation against the daily limit.

   **Why it avoids the dead ends:**
   - Token never in Clead context → no Dead End B
   - Token never in task payload → no Dead End C problem 3
   - Actions makes the HTTP call, not Clead → no Dead End C problem 1/2
   - Crog receives clean task → no prompt injection flag

   **What it enables:**
   - If Path B confirmed: 1 Routine execution per PR (Clead review
     only) → 15 PRs/day on Max plan → matches bj-v1 sprint pace
   - Crog's token stored as GitHub Actions secret → never in any
     Claude context ever

   **What needs validating:**
   1. GitHub Actions can successfully POST to Crog's Routine fire
      endpoint (api.anthropic.com) — no network restriction on
      Actions side
   2. Crog's security posture accepts tasks arriving via Actions
      POST without flagging as injection (should be fine since no
      embedded credentials in the task text)
   3. Clead can post a marker comment to a PR via GitHub connector
      (the write access question — open question #1)

   **How to test:** Create a simple GitHub Actions workflow that
   POSTs a test task to Crog's fire URL using a stored secret.
   Check whether Crog accepts and executes. This is PBI-2.2 in
   the backlog.

   **Billing note:** When the June 15 Agent SDK credit split
   eventually lands, GitHub Actions firing Crog will consume from
   the Agent SDK credit ($200/month on Max 20x), not the
   subscription. At API rates this is still likely affordable for
   development pace — but confirm before relying on it.

   ---

   ## Operational lessons (hard-won, do not re-learn these)

   - Clead Routine: NO repos attached. Ever. Non-negotiable.
   - Crog Routine: all relevant repos attached.
   - Tokens shown once on generation — store immediately in
     password manager. Regenerating invalidates previous token.
   - Single-line curl only in Git Bash. -s flag mandatory.
   - anthropic-beta header required: experimental-cc-routine-2026-04-01
   - Payload field is "text" not "prompt"
   - 15 Routine runs per day on Max plan — shared across all Routines
   - Routine network policy blocks outbound HTTP to arbitrary domains
     by default — api.anthropic.com not in default allowlist
   - Crog's security posture blocks embedded credentials in payloads
   - Branch deletion via git push origin --delete returns 403 in
     Routine environments — use gh pr merge --delete-branch instead
   - Interactive CLI sessions (Cowork, Claude Code terminal) do not
     count against Routine daily limit
   - June 15 billing change paused — current subscription limits
     unchanged, but expect it to land eventually

   ---

   ## Summary — what to do next

   1. Confirm Routine reset time and express in Stockholm/CEST
   2. Implement credit counter as GitHub repository variable
   3. Test Path B: GitHub Actions → Crog Routine fire endpoint
   4. If Path B works: implement session mode router in Clead
   5. If Path B fails: CLI mode is the default, Routines for
      low-cadence work only
   *Note added 2026-09-30: the limits in this section are out of date
   (current docs give hourly limits, not 15 per day). Environment API
   credentials do not help here: the proxy never attaches them to
   api.anthropic.com, so dead ends B and C still stand. Routines can now
   also start on GitHub pull-request events, with no token held by
   Claude; untested. See docs/BACKLOG.md PBI-2.3.*
3. Spec-author blind spot: Clead writes the spec and reviews against it.
   A flawed spec passes compliance invisibly. Adam's intent gate helps
   but does not fully resolve this. Tracked as open.
4. Copilot's role in v2 — Copilot is absent from the v2 skeleton by
   deliberate starting position, not permanent exclusion. In v1, Clead
   and Copilot covered different blind spots: Clead reviewed from the
   diff only (pr_dump.sh constraint), Copilot read full files. In v2,
   Clead fetches diffs and files directly via GitHub connector, which
   may eliminate the structural reason for Copilot's complementary role.
   Question to answer on a real project: what does Copilot catch that
   Clead misses in v2? If Clead can fetch full files on demand, the
   blind spot may not exist. If it does, the v1 label-based model is
   documented in sugose/ai-project-template/docs/COPILOT_LIMITATIONS.md
   and ready to pick up. Decision deferred until Clead's solo review
   performance is observed on a real v2 project.
