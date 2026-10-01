# Session Context — Consultant Handoff

**Written by:** Claude Chat (Clead), end of session 2026-06-27
**Purpose:** To give Cowork-Clead the reasoning and conversation context
that does not fit neatly into the structured memory files. Read this
alongside the other memory files, not instead of them.

---

## How this template came to exist

Adam has been running AI-assisted development across four repos
(sugose/ai-project-template, sugose/titan-comptracker,
sugose/python-blackjack, fomo-t/fomo-f) using the v1 workflow.

The v1 workflow was built by discovery — running into walls, patching
problems, and accumulating scaffolding. It works. But in a session on
2026-06-27, Adam and Clead stepped back and evaluated it honestly:
almost all of the complexity (dump.sh, pr_dump.sh, the ?i=1 convention,
the hard-stop rule, the STOP-and-wait pattern) existed for one reason —
Clead and Crog could not talk to each other, and Clead had no GitHub
access. Adam's clipboard was the only channel between them.

That constraint no longer exists. Cowork has a GitHub connector.
Routines can trigger Crog. The scaffolding that compensated for the
missing channel should not be carried forward.

The decision to rebuild rather than iterate was made on that basis.
The v2 template is what you would build if you started today, knowing
what we know, using tools that now exist.

---

## What Adam is like to work with

This is important context for Clead's default posture.

Adam has a strong background in agile — coach, scrum master, team lead,
product owner, product manager. He is strong on process: he knows what
kinds of processes are appropriate for a given type of project, and he
will tell you when something is over-engineered. That is a WHAT signal,
not a HOW incursion. Take it seriously.

Adam is not a deep technical implementer, but he is not a non-technical
PO either. The WHAT/HOW gap is multidimensional and its shape varies per
PBI. Do not assume a uniform gap. Read what Adam brings and fill from there.

Adam's leading star, in his own words: "my leading star doesn't tell me
what we should do next to maximise customer value. It tells me what I
can do today so the team I'm working with actually functions well."
This is the philosophy behind the workflow design — not optimising for
velocity, but for a team that actually works well together.

Adam values simplicity and proportionality. If Clead proposes something
more complex than the problem requires, Adam will push back. The right
response is to adapt, not to defend.

---

## The migration plan for python-blackjack-v2

*2026-09-30: blackjack-v2 is no longer the pilot; acuteping is (see
memory/decisions.md). The plan below still stands for whenever
blackjack-v2 is migrated, with no date set.*

After this template is proven, the plan is:

1. Bootstrap python-blackjack-v2 from this template
2. Populate with specs, processes, and docs — written fresh, informed
   by v1, adapted to v2 philosophy. NOT copied from v1.
3. Port the test suite from v1 — with v2 spec as the target.
   Each test is evaluated: does this behaviour belong in v2's spec?
   Does the test express it in v2 terms? Rewrite or discard if not.
   All red after the port is the correct starting state.
4. Port the src — adapt to v2 spec and make tests green.
   Same discipline: v2 spec is the target, v1 is reference only.
5. End state: blackjack-v2 is functionally equivalent to v1,
   running under v2 rules, with honest tests and a clean spec.

The backlog for blackjack-v2 is built from scratch. Adam reviews
the v1 backlog — both done and not-done — and makes a WHAT call on
each item. Some completed v1 work may need revisiting against the v2
spec. The v2 backlog is not a copy of v1's with migration items prepended.

---

## The two unproven pieces

Everything in this template is designed but not all of it is proven.
Two things must be validated before claiming full autonomy:

*2026-09-30: both are overtaken as written. The connector never
loaded and was written off; Clead posts to PRs through the GitHub API
(and Chrome before that). Adam no longer fires Crog with a token:
Clead starts Crog directly. What is still unbuilt is firing Crog from
GitHub Actions with no one involved (Path B, PBI-2.2 and 4.4). The
blackjack-v2 references below are superseded too: acuteping is the
pilot. See memory/decisions.md.*

**1. GitHub connector write access**
The review workflow posts a marker comment on PR open. This assumes
the GitHub connector can write PR comments, not just fetch diffs.
This has not been confirmed. If it cannot write, the review trigger
mechanism needs rethinking. Do not claim two Adam touchpoints until
this is confirmed.

**2. Routines secret injection**
Until Anthropic adds secret injection to Routines, Adam cannot be
fully removed from the Clead to Crog trigger. Current transitional
flow: Clead produces a curl command, Adam substitutes the token from
his password manager and fires it. One paste, not a relay loop —
much better than v1 but not yet fully autonomous.

The v2 template is the pilot for proving both. Build it, use it on
blackjack-v2, and either it works or it teaches you what to fix.

---

## What was done in the session that produced this template (2026-06-27)

In the ai-project-template (v1) repo:
- PR #37: Fixed Direction A PR flow in TEAM_STRUCTURE.md
- PR #38: CHANGELOG entry for #37
- PR #39: dump.sh updated — binary skip + truncation integrity check
- PR #28 (titan-comptracker), #114 (python-blackjack), #59 (fomo-f):
  Same dump.sh update distributed to all active repos
- PR #40: BOOTSTRAP.md synced with new dump.sh
- PR #44: docs/PROPOSAL_NEXT.md — initial workflow rebuild proposal
- PR #45: docs/decisions/0001-rebuild-workflow.md — full ADR, adopted
  as founding document of v2 template

The skeleton Crog prompt for this repo was written at end of that
session. You are reading this because Crog has executed it successfully.

---

## The one sentence that captures Adam's intent for this whole effort

"I want to eliminate myself from tasks where my involvement
(a) can be replaced by machine AND (b) is not adding any value."

Everything in this template serves that sentence. When in doubt,
ask: is Adam here because a machine cannot do this, or because he
adds value? If neither, find a way to remove him from it.

---

## On the v1 scaffolding that was discarded

The v1 tools and conventions were not wasted work. They are available
to pick up and apply if a real problem demands them. The v2 template
starts without them because the problems they solved no longer exist —
not because the solutions were wrong.

If you encounter a situation in v2 where something from v1 would help,
propose it. The knowledge is in sugose/ai-project-template. The
decision to re-add anything is Adam's WHAT call.

---

## On the `..wrap` stop word (2026-06-28)

`..wrap` was chosen over the candidate `/pacoisalwaysright` for brevity —
a session-end trigger should be short enough to type without friction.
The leading slash was dropped so the stop word doesn't collide with
slash commands; the `..` prefix keeps it distinctive and non-command.
For the record, though: Paco is always right, and he only has one ear,
so he doesn't have to listen to half the crap you tell him.

---

## GitHub MCP connector failed to load this session (2026-06-28)

First Cowork-Clead session. The GitHub MCP connector (the
`engineering:github` plugin server) did not surface a single tool the
entire session, despite being fully configured and authorized at both
levels:

- **Account level** — Settings → GitHub Integration shows "Disconnect"
  (i.e. connected). Powers repo-file attachment, Project sync, Claude
  Code repo selection.
- **Plugin level** — Engineering plugin → Connectors → GitHub shows
  "Disconnect" (connected). This is the one that should hand Clead
  callable tools (list PRs, read issue, get commit, post comment).

Both verified visually via screenshots Adam shared. Nothing left to fix
in settings.

**What was ruled out:** Adam had some GitHub orgs he wasn't signed into;
he signed in and we retried. No change. Org sign-in was a red herring —
the connector handshake, not org membership, is the issue. (Org-level
OAuth app restrictions can block a *specific org's* access, but that
surfaces as a missing grant, not the whole connector going dark.)

**Diagnosis:** session-level MCP handshake hang. The server was listed
as "still connecting" at session start and never completed. Retrying the
tool lookup just re-queries the same dead handshake — it does not revive
it. The fix is a fresh Cowork session, which re-initializes all MCP
servers from scratch. If a clean session still shows no GitHub tools
after connectors finish loading, it's a connector/server-side bug
(escalate via thumbs-down), not Adam's setup.

**Why this matters for v2:** the GitHub connector is load-bearing for the
whole workflow — Clead fetches diffs/files and posts the review verdict
to the PR through it (see "The two unproven pieces" above and open
question #1 in decisions.md). This session shows the connector can
*silently* fail to load at session start while every settings panel
reads green. Operational takeaway: **at session start, Clead should
confirm the GitHub tools are actually present before relying on them** —
a healthy-looking settings page is not proof the tools loaded. Open
question #1 (can the connector write PR comments?) remains unconfirmed —
we could not even exercise read access this session.

---

## Session 2026-06-28 (second Cowork-Clead session)

Short session, mostly orientation and process. Four things worth keeping:

1. **Connector outage is platform-wide, confirmed.** A web search found
   multiple matching reports — the exact Cowork-Windows "Connected but no
   tools" symptom (#57589, #61682) and a dated regression that broke
   ~June 25 and stayed broken (#71542). It's a server-side Anthropic
   issue, not Adam's setup — "bad timing" that we stood up v2 right as it
   landed. The Chrome fallback stands; revisit the connector if it recovers.

2. **Startup routine now checks GitHub availability** (CLAUDE.md step 2).
   Codifies the takeaway above so a future session probes before relying
   on the connector. Working-folder edit — not yet in Git.

3. **No dedicated hurdles log.** Adam's call: not worth millimeter
   tracking. Assemble retrospectives on demand from decisions.md and
   context.md when wanted.

4. **Communication-style feedback.** Adam: I was overwhelming him with
   facts, options, and perspectives. v1 (Claude Chat as Clead) was
   smoother. Corrected posture: answer the question asked, one
   recommendation not a menu, hold caveats unless asked. Saved to Cowork
   auto-memory; recorded here too so it survives across machines/clones
   (auto-memory is local-only). Default to concise.

---

## Session 2026-09-30 (Clead in a Claude app cloud session)

A long session that started as work on acuteping (the sonar calculator)
and turned into making this template complete by its own definition
before bootstrapping acuteping from it. The rule Adam set: everything
the template says it has or does must be true, and anything not built
must be clearly marked as backlog. An audit found false or stale
claims; they were fixed through PRs #42-#62, with Crog reviewing
Clead's process and config changes and catching several overclaims.

Along the way: acuteping replaced blackjack-v2 as the pilot; reviews and
merges were delegated to Clead and Crog; branch protection was turned on
(on a free plan it only exists for public repos); a release pipeline now
builds a clean bootstrapper into sugose/ai-project-bootstrap, since a
bootstrapped project should not inherit the template's own files, only
the version it came from ("bootstrap", not "fork"). v2.1.0 was released
and its output verified. Overnight, on Adam's general instruction, the
remaining Phase 1 and 2 items that needed no decision were done (PRs
#63-#67): tool refresh, languages README, Python and React Native packs,
Routines research.

How the work ran: Clead has git and GitHub API access in the cloud
session and starts Crog as separate agents (Adam is never the relay, and
Clead cannot reach the Crog in Adam's VS Code). Adam works with
the Claude app beside VS Code. He wants visible progress while agents
work, and no role of his as a message relay.

What is private stays out of this repo; acuteping's private notes live
in a separate private repo until acuteping is
bootstrapped.

## Session 2026-10-01 (v2.2.0 and process cleanup)

Released v2.2.0 so the licence reaches the public bootstrapper, and
checked that the published bootstrapper matches a local build. Adam then
decided every open backlog question; what was left in the staging file
was resolved or became backlog items (a backlog and kanban view, a
delegation-level option for the bootstrapper, the next tool refresh).

Process changed on Adam's decisions: `..wrap` became an end-of-session
check instead of a memory flush; an unattended working mode and a
model-and-effort rule were written into CLAUDE.md; the June Routines
were deleted; every merged branch was cleaned up and the repo setting
that deletes head branches on merge was turned on.

Why reviews and design run on Opus agents: Clead's own errors this
session were verification errors (a check that matched the wrong thing,
a stale local clone, a branch count from a partial fetch), and a
separate, stronger reader caught real problems that Clead's own checks
had missed (PR #86's checklist ran before the steps that change what it
checks). Every claim of "merged" or "deleted" was re-checked against the
GitHub API, not taken from an agent's report.

Open: Adam bootstraps acuteping from v2.2.0, which closes PBI-1.10; the
wording notes in `docs/NEXT_SESSION.md` item 6.

## Evening 2026-10-01 and 2026-10-02 (repo move and consolidation)

Adam moved both repos from `sugose/` to the `factoincognito` org; PR #112
repointed the live references. PBI-1.15 (the chain test) was marked
done, and PBI-1.17 (test first at every level) was built in four PRs; it
stays `[NEXT]` until Adam's end-to-end runs. The PBI-1.14 build plan was
drafted as 17 slices and staged, not started.

Several Clead sessions then worked on the template at the same time. Two
of them each wrote a NEXT_SESSION item numbered 8 within hours, and
sessions bound to the old `sugose/` path could not reach the moved repo:
attaching the new path failed on the same-name checkout, and the access
proxy decides by repository path, so no token helped. One of them pushed
its notes to a side branch; another, working on Adam's company structure
in a separate private repo, left a Project doc instead of a PR. Adam had
every session stage its pending items in `docs/NEXT_SESSION.md` (PRs
#117-#121), then started one session on the new path to consolidate.

That session found the handoff Project doc already overtaken by #121, and
re-read through the API what NEXT_SESSION item 7 already recorded: the
bootstrapper's `main` protection (PR required, `build` required, no admin
bypass) would reject the release pipeline's direct push. The release waits for Adam's change to that
setting and his answer on releasing before PBI-1.14 is built.
