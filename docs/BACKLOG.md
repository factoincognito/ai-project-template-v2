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
| [MOVED] | Tracked elsewhere from now on; where is given inline |

The format of this file, and what a backlog visualiser can read from it, is
set out in vizi's format spec:
https://github.com/factoincognito/vizi/blob/main/docs/BACKLOG-FORMAT.md
(linked, not copied).

---

## Phase 1 — Language packs and bootstrap wizard

**Goal:** Make v2 a fully usable template — clone it, run the wizard,
get a working project in any supported language.

- **[SUPERSEDED] PBI-1.4** (2026-10-01: superseded for new projects by PBI-1.14, the turn-key bootstrap script, approved by Adam; if the migration branch is still wanted it becomes its own IDEA. Earlier note: Adam, 2026-10-01, keep LATER; the bootstrapper plus
  `tools/layout-pack.sh` cover most of it, and a small "lay out pack X"
  step in the bootstrapper could replace the wizard) — Write the v2 bootstrap wizard (`BOOTSTRAP.md`)
  — guided setup via Claude chat, branches on new project vs migration
  from existing project, generates all project files for chosen language,
  produces Crog setup prompt. Migration branch must ask: source repo,
  Adam's WHAT call on v1 backlog items, sequencing (spec first, then
  tests, then src).

- **[SUPERSEDED] PBI-1.8** (2026-10-01: folded into PBI-1.14, which has the licence choice) — Licence choice at project setup: the template
  offers a set of licences (PolyForm Noncommercial among them) and the
  project picks one at start. Depends on the wizard (PBI-1.4), unless
  the licence texts are first added as files under `licenses/`.

- **[NOW] PBI-1.10** (pipeline built in PR #60; done once the v2.1.0
  publish passes the "Done when" checks below. Adam, 2026-10-01: acuteping is not created until the whole toolchain is verifiably working, meaning PBI-1.15 is done and PBI-1.14 is built with Adam's end-to-end runs passed; see PBI-1.14 "Done when") — Build pipeline that
  produces the bootstrapper.
  Intent approved by Adam in chat, 2026-09-30 (recorded on PR #58).

  **Why.** A project bootstrapped from this repo must not inherit the
  template's own working files (backlog, changelog, decisions, session
  notes, release notes); it should only record which template version
  it came from. This repo stays the development repo; a pipeline builds
  a clean bootstrapper from it and publishes it to a separate repo,
  `factoincognito/ai-project-bootstrap`, which is marked as a GitHub template
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
  `memory/context.md`, `memory/decisions.md`, `memory/project.md`,
  `STATUS.md` (added 2026-10-26: the fixed-format status file the
  product office's overview of all projects reads; its update rule is
  an HTML comment at its top, not in `CLAUDE.md`). A
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
  builds, then makes the default branch of `factoincognito/ai-project-bootstrap`
  match the build output exactly (files not in the output are deleted),
  as one new commit per release (history kept there) with message
  `Bootstrapper <version> from factoincognito/ai-project-template-v2@<commit>`,
  and pushes the same tag there. If the bootstrap repo is empty, that
  commit is its first. If the tag already exists there, the publish
  fails rather than overwriting. It authenticates with the Actions
  secret `BOOTSTRAP_PUSH_TOKEN`.

  **Setup by Adam (cannot be done by an agent here).** Create
  `factoincognito/ai-project-bootstrap` (public, empty, no README) and tick
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

- **[LATER] PBI-1.13** (Adam, 2026-10-01: leave as a dated LATER) — Next
  tool refresh of the language packs, not before 2026-10-28, when Node 26
  is expected to become LTS (date not verified; check before starting).
  Also: TypeScript 7 once ts-jest supports it, and the Expo SDK's Jest
  version for the react-native pack. Follows the PBI-1.6 method: update,
  then run every pack's CI on GitHub's runners.

- **[MOVED] PBI-1.11** (pinned by Adam, 2026-10-01; decided the same day) — Backlog visualiser: a way to see a project's `BACKLOG.md` as a backlog list and as a kanban board. It is a project of its own, bootstrapped from this template, and not a template feature, so it is tracked in the owner's private product office and not here. Nothing is built in this template.

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

- **[LATER] PBI-1.16** (Adam, 2026-10-01; he reports `main` on
  `factoincognito/ai-project-bootstrap` is not protected) — Protect the
  bootstrapper repo's default branch. **What.** Part 1 (done 2026-10-02):
  Adam set `main` in that repo's settings to block force-pushes and
  deletion, with no pull-request or status-check requirement; Clead read
  the rule back through the API, and the v2.3.0 publish push went through
  it. Part 2, research first (written when the repo was user-owned; it is
  now in the `factoincognito` organisation, so the organisation-only
  options below may apply; not re-checked): whether a ruleset or a
  bypass allowance can limit writes to the publish token on a user-owned
  repo. The docs say push `restrictions` are organisation-only; whether
  `bypass_pull_request_allowances` or a ruleset works on a user-owned repo
  is not verified. If neither works, PBI-1.15 carries the verification.
  Optional later layer: a post-publish check inside the bootstrapper repo,
  which would have to be guarded
  (`if: github.repository == 'factoincognito/ai-project-bootstrap'`) so projects do
  not inherit a failing or pointless job.

- **[LATER] PBI-1.19** (Clead, 2026-10-23, on Adam's request; the WHAT is Adam's, the HOW is Clead's; not yet specced, reviewed or intent-approved) — Make the setup command short enough to type by hand.

  **Why.**
  Adam, 2026-10-23: typing in the step 1 command line "is a recipe for failure". A user at home on the command line pastes it; one who is not may type it. The line is 175 characters with a quoted header and a redirect, and one wrong character (a space for the hyphen in `bootstrap-project.sh`, a dropped quote) makes it fail with an error that user cannot read. The goal is to remove that risk, not to save keystrokes.

  **Proposed HOW (to be specced): a gh extension.**
  - A public repo `factoincognito/gh-bootstrap-project` holding an executable `gh-bootstrap-project` (the setup script). The gh manual (`gh extension`) requires the repo name to start with `gh-` and to contain an executable of the same name.
  - README step 0 gains one line after the login: `gh extension install factoincognito/gh-bootstrap-project`. Step 1 becomes `gh bootstrap-project`.
  - gh forwards all arguments to the extension (gh manual), so `--resume` and the options work as today. gh checks for a new version every 24 hours and shows an upgrade notice (gh manual); `gh extension upgrade bootstrap-project` updates it.
  - Rejected: a `gh alias set` line in step 0 (the alias line is as long as today's command, and has no update path); `curl … | bash` from a short URL (still a URL to type, and it skips the gh login check that the `gh api` download gives for free).

  **To settle in the spec.**
  1. Publishing: the release pipeline (`bootstrap/publish.sh`, `.github/workflows/bootstrapper.yml`) also publishes the script to the extension repo at the same version, or the extension is a thin launcher that downloads the script from the bootstrapper repo (one copy, but two downloads). Decide which.
  2. Versions: the script checks the bootstrapper's version stamp at step 4, and `--resume` refuses a repo stamped by an older version. An outdated installed extension must stop with a message naming `gh extension upgrade bootstrap-project`, not a refusal the user cannot act on. How `install` and `upgrade` fetch a script extension (a clone of the default branch, or a release) is UNVERIFIED.
  3. Windows: whether gh runs a bash script extension from Git Bash, and from cmd or PowerShell, is UNVERIFIED; it needs a real run on each OS, macOS `/bin/bash` 3.2 included. If it works only from Git Bash, the README still says so.
  4. Messages: the commands the script prints to restart or continue, its usage text and the stub README's setup section give the download line and `bash bootstrap-project.sh`. Each must give the command that works for the user.
  5. Whether the README keeps today's line as a fallback, or gives one way only.
  6. Trust: gh states that extensions are not verified by GitHub. The trust is the same as for today's downloaded script; the README says so plainly.

  **Done when.**
  - On Windows (Git Bash), macOS and Linux, a project is set up with README step 0 plus `gh bootstrap-project`, typed by hand: an end-to-end run on each OS.
  - Every restart or continue command the script prints works as printed when the script runs as the extension (a test).
  - An outdated installed extension stops with a message naming `gh extension upgrade bootstrap-project` (a test).

  **Rules that apply.**
  Script, workflow and release-pipeline changes are code and config: test-first, reviewed by the role that did not write it. The spec needs Adam's intent approval, because it adds a public repo and changes the command every user types.

- **[LATER] PBI-1.20** (Clead, 2026-10-26, from Adam's questions after end-to-end run 1; the WHAT is Adam's, the HOW is Clead's; not yet designed, specced or reviewed) — The user journey from an itch to a project being built.

  **Adam's WHAT (2026-10-26).**
  - "All the user knows is that I want to do something. That something may be more or less crisp, or just an itch. The user has been told there is an AI package you can use to help you do all this, you just need to describe WHAT and it fixes the rest."
  - "From the user's perspective there must be a clear entry point and a solid process to get there, initially by use of the bootstrapper." v2.4.0 is solid but covers only part of the journey.
  - The user bootstraps the idea, not the project. The product office is Adam's own; it does not exist in the user's world. (This is about Adam's own product office; an umbrella bootstrapped for someone else is PBI-1.55, Adam, 2026-11-07, `memory/decisions.md`.)
  - **The test for every HOW decision:** it fits the journey of the intended user, who never needs to be aware of technical setup details. Wherever the user needs technical knowledge or help, that is a defect (the rule of the end-to-end runs).
  - The bootstrapper's tagline (Adam, 2026-10-26): "Have an itch? Solve it with a project!"
  - Adam's stance on the trial (2026-10-26): not sure a proposal covers the gaps, so it is tried and tested, and what the test shows decides what stays.

  **The journey and what covers it today (Clead, read from `main` 2026-10-26).**
  1. Finding the entry point: not covered; the README starts with installing tools.
  2. Installing the tools: README step 0 (with the run-1 findings).
  3. Creating the project: the script, v2.4.0; solid in run 1.
  4. Turning the itch into a clear WHAT: not covered.
  5. Design, and the HOW choices (the pack and others): not covered; the script asks the user for the pack up front.
  6. Starting work with Clead: partly (run-1 finding 10).
  7. The build loop (specs, PRs, reviews): the template's workflow.

  **Clead's candidate HOW (not decided): bootstrap the idea.** The script asks only WHAT questions (name, the idea in a sentence or two, licence, owner) and creates the project with no pack; the first Clead session in the project shapes the idea into `memory/project.md` and a high-level design in `docs/SPEC.md`, asking one question at a time; when the design settles, Clead picks the pack, explains why in plain words, and adds it through a PR. Known HOW problem, unchecked: protection requires a green `build`, which comes with the pack today, so a project without a pack needs a basic check until then. An earlier candidate (a planning chat outside the project, a planning guide and a `--design-note` file) was dropped the same day: it needs the user to plan before the entry point.

  **Next.** A design draft of the whole journey (CLAUDE.md, "Model and effort": written on Opus, reviewed by Crog), checked stage by stage against the test above; then Adam's intent approval; then the spec. Not part of the run-1 fix batch.

  **Done when.**
  - Someone with only an itch, who has never used a terminal, goes from the entry point to a project with a first spec and its pack, following only what the journey gives them; every point where they needed technical knowledge or help is recorded as a finding and fixed.

  **Rules that apply.**
  Script, workflow and release changes are code and config: test-first, reviewed by the role that did not write it. README and first-session changes are process: reviewed by Crog. The design needs Adam's intent approval, because it changes what every user does.

- **[LATER] PBI-1.21** (Clead, 2026-10-26, agreed with Adam in chat; the WHAT is Adam's, the HOW is Clead's; not yet specced or reviewed) — The release tag is created by merging the release prep PR, not by hand.

  **Why.** Today Adam creates every `v*` tag from the Releases page, because the access proxy refuses tag and release writes from a Clead session (checked again 2026-10-26: `POST git/refs` and `POST releases` both return 403 from the proxy, nothing created). Adam does not want a release to depend on him being at his computer or on its browser (2026-10-26).

  **Candidate HOW (not decided).** A workflow on `main` creates the `v*` tag at the merge commit when a merged PR from a `release/*` branch adds a new version heading to `CHANGELOG.md`, using the existing publish token (a tag pushed with the default `GITHUB_TOKEN` does not start the tag run). The tag run then tests and publishes as today. The trigger stays narrow, so a stray CHANGELOG edit can never release; the token's added scope is checked in the design.

  **Scope (Adam, 2026-10-26).** Built for every bootstrapped project, not only for the template: the workflow and a short release section in the shipped docs go into `bootstrap/manifest.txt`, so a new project releases the same way from day one. The template's own extra steps (publishing to `ai-project-bootstrap`, stamping the script) stay template-only. Existing projects get it only through NEXT_SESSION item 1 (applying v2 workflows to other projects), which is still open. The product office does not hold the procedure; at most it asks each project whether a release waits for Adam's go (NEXT_SESSION item 15).

  **Conditions (Adam, 2026-10-26).**
  - Adam's go stays the gate: a release prep PR merges only with his explicit yes in chat, recorded on the PR. It replaces his click on Publish.
  - Built after NEXT_SESSION item 18 (rolling back by re-tagging) has been tried once, because releasing on merge makes a known way back more important.

  **Done when.** Merging a release prep PR, with Adam's recorded yes, creates the tag at its merge commit, the tag run is green including `publish`, and a PR without that branch name or heading creates no tag (tested in the workflow tests). A freshly bootstrapped project has the same workflow and doc, and a release prep PR there creates its tag (checked in an end-to-end run).

  **Rules that apply.** A release-process change: the workflow is code (test-first, reviewed by Crog), the process change needs Adam's intent approval, and CLAUDE.md, `docs/DEV_INFRASTRUCTURE.md` and the release decision rows are updated with it.

- **[BLOCKED] PBI-1.23** (Adam, 2026-10-28; out of the product office's `NOW` slot the same evening while part 2 waits on the end-to-end runs (product office PO-60); the WHAT is Adam's, the HOW is Clead's; part 1 specced and built by Crog, merged 2026-10-28 in PR #271; part 2 not started, waits until the end-to-end runs pass) — C# base language pack.

  **Why (Adam, 2026-10-28).** Give users C# capabilities in their own projects. Out of scope for Phase 1 until now ("planned in v1, not yet built").

  **Scope (Adam, 2026-10-28).** A base pack: a class library, a console app and an xUnit test project, with the same kind of gates as the other packs. Not in scope: web (ASP.NET), desktop (WPF, WinForms) and mobile (MAUI). Each of those could later become a pack of its own on top of this one, the way `web` builds on `node`.

  **Candidate HOW (Clead's, not decided).** Folder `languages/csharp/`. `dotnet format` for lint and formatting; nullable reference types with warnings as errors; xUnit with coverlet for the 80% line coverage gate; `actions/setup-dotnet` with the SDK version pinned; no lockfile step in the bootstrap script, as for the Python pack. Versions and tools are checked when specced, not taken from this line.

  **Spec as built, part 1 (Crog, 2026-10-28, PR #271; checked against the candidate HOW).** Folder `languages/csharp/`: `Project.slnx` with a class library (`src/Example/`), a console app (`src/Example.App/`) and an xUnit v3 test project (`tests/Example.Tests/`); `Directory.Build.props` (`net10.0`, nullable, `TreatWarningsAsErrors`, `AnalysisLevel` `10.0-recommended`, `EnforceCodeStyleInBuild`, XML docs required on public members); `Directory.Packages.props` (central package management, every version exact); `.editorconfig` (the code style rules, at warning). CI: `dotnet restore`, `dotnet format --verify-no-changes`, `dotnet build`, `dotnet test` with an 80% total line coverage gate. Test-first patterns: code `src/*`, tests `tests/*`, `src/*.csproj` ignored as config. Where it differs from the candidate HOW:
  - **coverlet.MTP, not coverlet's MSBuild or VSTest collector.** xUnit v3 (4.0.2) runs on Microsoft.Testing.Platform, and the .NET 10 SDK refuses `dotnet test` in VSTest mode for it ("Testing with VSTest target is no longer supported by Microsoft.Testing.Platform on .NET 10 SDK"), so `global.json` turns on the new runner and coverlet.MTP (10.1.0) gives the gate. Proven: under 80% `dotnet test` exits 14, which is `CoverageThresholdFailed` in Microsoft.Testing.Platform 2.5.1. `dotnet test` does not show the numbers; `code-standards.md` gives the command that does.
  - **The SDK is pinned to the 10.0.1xx feature band, not to one patch.** `global.json` says `10.0.100` with `rollForward: latestPatch`, and `actions/setup-dotnet@v6` installs the newest 10.0.1xx from it, as the Python pack takes the newest 3.14. An exact patch would refuse every other SDK on a developer's computer. The analyzer rules are fixed to 10.0, so a newer patch does not add rules. The packages are pinned exactly.

  **Order (Clead, 2026-10-28), so the pack cannot delay acuteping.** The bootstrapper's end-to-end runs (`docs/NEXT_SESSION.md`, Adam's to-do 2) are the gate for acuteping, and the runs test the bootstrap script. Part 1, now: the `languages/csharp/` folder, its job in `packs.yml`, `tools/layout-pack.sh` and `tools/test-layout-pack.sh`, and the README tables. Part 2, only after the end-to-end runs have passed: the bootstrap script offers the pack, and `bootstrap/e2e-check.sh` checks it. Part 1 adds nothing the runs exercise; part 1's change to `bootstrap/stubs/bootstrap-project.sh` (the layout table lives there) is kept to the layout rows, and its PR merges only after the release prep for the version Adam runs next is merged, so it is not in that release.

  **Open for part 2 (review note N8 on #271, non-blocking).** The test project references every project under `src/` through a glob, so each one must be a project the `net10.0` test project can reference: a `net10.0-windows` project, for example, would break restore on Linux CI. Outside part 1's scope (no desktop, web or mobile); part 2 says so in `code-standards.md` or narrows the glob.

  **Done when.** The pack meets "Rules for a pack" and "Adding a pack" in `languages/README.md`: green on day one on a scratch project, each rule CI enforces proven by a deliberate violation, a job in `.github/workflows/packs.yml`, its files in the bootstrap script's layout table and in `tools/test-layout-pack.sh`, both README tables, and the pack offered by the bootstrap script and checked by `bootstrap/e2e-check.sh`.

  **Rules that apply.** Code and config: test-first, reviewed by the role that did not write it.

- **[LATER] PBI-1.24** (Adam, 2026-10-29, from a product office session on PO-62; the WHAT is Adam's, the HOW is Clead's; not yet specced, reviewed or intent-approved) — A setup option for whether a project includes Claude support.

  **Why (Adam, 2026-10-29).** The person setting up a project chooses whether the AI files are included in the GitHub project. A project without Claude support is the conventional development project that "Working without Claude" in the README describes (PO-62, PR #277).

  **Approach (Adam chose Clead's recommendation, 2026-10-29).** Files that a project needs either way are written in role-neutral wording, so one version works with and without Claude. The option then only leaves out the files that exist only for Claude. There are not two versions of each file.

  **Facts (Clead, checked 2026-10-29 at main e9fa8cd).**
  - Files that exist only for Claude, so the option can leave them out: `CLAUDE.md`, `memory/roles.md`, `memory/context.md`, `docs/CROG_ONBOARDING.md`, `docs/ROUTINES.md`, `docs/NEXT_SESSION.md`, `.github/workflows/review.yml`, `.github/workflows/changelog.yml`.
  - Files a project needs either way that name Claude, Clead or Crog, so they need role-neutral wording: `README.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `memory/standards.md`, `docs/SPEC.md`, `docs/BACKLOG.md`, `docs/DEV_INFRASTRUCTURE.md`, `docs/decisions/0001-rebuild-workflow.md`, `CHANGELOG.md`, `licenses/NOTICE`, `languages/README.md`, every pack's `code-standards.md`, and the script's closing messages (`say_left_for_clead` and the "What to do next" text).
  - The script already removes files at setup: `tidy_up` drops the README's setup section and every pack but the chosen one. Leaving out more files uses the same step.
  - What it touches beyond that: the fill table, the answer file that `--again` and `--resume` read, `bootstrap/e2e-check.sh`, the tests in `bootstrap/test-bootstrap-project.sh`, and the end-to-end run plan, which gets a second variant.

  **Open (Clead, for the spec).** The option's name and default, and how the interactive question words it. What "Working without Claude" says in a project set up without Claude support. Whether a project set up without Claude support can add it later, and how.

  **Order (Clead's proposal, not decided).** After the end-to-end runs (`docs/NEXT_SESSION.md`, Adam's to-do 2) have passed, because the option changes the bootstrap script that the runs test.

  **Rules that apply.** The spec needs Adam's intent approval. Script, test and workflow changes are code: test-first, reviewed by Crog on Opus. Wording changes to process documents are reviewed by Crog.

  **Done when.** Written when specced.

- **[LATER] PBI-1.27** (Adam, 2026-10-29, from a product office session; the WHAT is Adam's, the HOW is Clead's; not yet specced or reviewed) — Re-enable macOS as a supported platform, after PBI-1.26.

  **Scope (Clead's recommendation, chosen by Adam).**
  1. Open the way in again: remove PBI-1.26's stop.
  2. Put the macOS leg back in the Bootstrapper matrix and `check-shards.sh`, and fix what it finds that the faked-`uname` tests and the bash 3.2 leg could not. PBI-1.26's removal PR is #340 (`9f9167d`): its diff is the list of what goes back (the matrix entries, the macOS step, the two removed workflow tests, the leg lists in `bootstrap/test.sh`).
  3. Put the macOS steps back in the README, the stub README and the docs, starting from what PBI-1.26's removal PR (#340, `9f9167d`) took out.
  4. A human-run end-to-end run on a Mac with macOS 13.5 or later (Node.js 24's minimum).

  **Together with PBI-1.28 (Adam, 2026-10-29).** macOS returns with PBI-1.28's minimum-version checks in place, so the setup on any Mac goes ahead with what that computer can run and says what it cannot (for example: Node.js 24, and so the node, web and react-native packs, needs macOS 13.5 or later). PBI-1.28 is done first, or in the same step.

  **Rules that apply.** As for PBI-1.26; adding the leg back changes what `bootstrapper-test` covers, so the spec needs Adam's intent approval.

- **[LATER] PBI-1.28** (Adam, 2026-10-29, from a product office session; the WHAT is Adam's, the HOW is Clead's; not yet specced or reviewed) — Before it changes anything, the setup checks that this computer meets the minimum versions of everything the setup itself needs to finish.

  **Why (Adam, 2026-10-29).** The check is not about a minimum operating system version as such: it is whether the platform the setup runs on has what the setup needs to complete successfully.

  **Where things stand (Clead, checked on main 2026-10-29).** `bootstrap-project.sh` checks bash for version 3.2 or later. It checks gh by the options it uses (`repo create --template`, `pr checks --json`, `pr merge --match-head-commit`), not by version. It checks only that git and npm are installed (and, in WSL, that npm is not the Windows one), with no version. It runs `npm install --package-lock-only` on the user's computer for the node, web and react-native packs, while the packs' CI uses Node.js 24; what an older Node.js does at that step is not checked. Node.js 24 needs macOS 13.5 or later (Node's v24.x `BUILDING.md`).

  **Scope (for the spec).** For each tool the setup runs on the user's computer: its minimum version, how the script reads it, and a guide when it is too old, as gh has today. Where a minimum depends on the operating system (as Node.js 24 does on macOS), the guide says so.

  **Rules that apply.** Script and test changes are code: test-first (red run in the PR), reviewed by Crog on Opus.

- **[NEXT] PBI-1.29** (Adam, 2026-10-29, from a product office session; Adam chose Clead's recommendation; the WHAT is Adam's, the HOW is Clead's; specced in PR #304; spec and README draft confirmed by Adam 2026-10-29, recorded on #304; part 2 being built) — The bootstrapper and the projects it makes need nothing from the template to work.

  **Why (Adam, 2026-10-29).** Someone about to bootstrap a project meets the bootstrapper, not the template, which is our development repo. Adam questioned whether the deliverable should depend on the template project at all.

  **Where things stand (Clead, checked in the published bootstrapper v2.8.3, `d7f0fc0`).** It refers to the template in three ways:
  1. Needed to finish the setup: the README's "After bootstrapping" section sends the user to step 0 of the template's README to install gh and sign in.
  2. Pointers in a created project to the template's content: `docs/DEV_INFRASTRUCTURE.md` (the other packs' code standards, which the setup rewrites to links into the template, and the template's own CI and protection), `languages/README.md` (how the template tests its packs), `docs/ROUTINES.md` (the "Path B" design kept in the template). Nothing breaks without them.
  3. Where it came from: the project's `CHANGELOG.md` and the script's `--version` name the template commit it was built from (PBI-1.10).

  **Scope (Clead's recommendation, chosen by Adam).** Keep 3, as a record of origin. Make 1 self-contained: the release build copies step 0 from the template's README into the bootstrapper's README, so the steps exist in one place and cannot drift apart. For each pointer in 2: bring the content in or drop the pointer, decided in the spec, item by item.

  **Widened (Adam, 2026-10-29, on Clead's recommendation, from his run 5 rehearsal, `docs/NEXT_SESSION.md` r5r-a to r5r-g).** The bootstrapper gets its own README, written for someone who knows what they want but not how: what the bootstrapper is and does for them, where to start (the command that starts a new setup), what each prerequisite is for and what it costs (a paid Claude plan for Claude Code; Git for Windows and gh on Windows), in plain words, with what a newcomer does not need first left out or placed later. The README a new project starts with stays a separate file; its placeholders are fine, since the setup fills them. Rule (Adam): the user is never required to edit a README in any way, so no heading or text asks the reader to change or delete part of it.

  **Order.** Before end-to-end run 5, because it changes what the newcomer reads; released, then run 5 on that release.

  **Rules that apply.** Build-script and test changes are code: test first, reviewed by the role that did not write it. Changes to process documents that ship are reviewed by Crog.

  **Spec (Clead, 2026-10-29, PR #304; approved by a Crog agent in review rounds 2 and 3; confirmed by Adam 2026-10-29, with the open points as proposed).**

  1. **Two READMEs.**
     - **The bootstrapper's own README.** Its source is `bootstrap/bootstrapper-README.md`, in the template only (`bootstrap/` does not ship). The release build writes it to `.github/README.md` in the bootstrapper. GitHub shows a README in `.github/` before one at the root (GitHub's documented order: `.github/`, the root, `docs/`). Not re-read in this session: docs.github.com is not reachable from the cloud session. It is the first check of part 2 (see "Checks"); if it does not hold, the fallback is the swap below.
     - **The README a new project starts with** stays `bootstrap/stubs/README.md`, at the root, with its placeholders. GitHub copies both files into every new project, whether the script makes it (`gh repo create --template`) or the "Use this template" button does. The setup's tidy-up deletes `.github/README.md`, as it deletes `bootstrap-project.sh`, and the setup PR's "Removed:" line names it. A set-up project then shows its own README. Until then (a project made with the button, or a setup that stopped before its PR was merged) its GitHub page shows the bootstrapper's README, whose section "A project whose setup has not finished" gives the `--resume` command.
     - **Why not swap the two at the root.** The `--resume` checks read the setup section of the root `README.md` (the heading, the carriage-return checks, the "set up already" state). With the project's README left at the root they stay as they are; the `.github/` file only needs the build to write it and the tidy-up to delete it. The swap (the bootstrapper's README at the root, the project's README shipped under another name and moved into place by the setup) changes those checks too, so it is only the fallback.

  2. **The build copies the steps, so they exist in one place (r5r-a).**
     - The template's `README.md` marks the part that ships with two lines, `<!-- bootstrapper-readme: start -->` and `<!-- bootstrapper-readme: end -->`. The marked part: the keyboard note, step 0, step 1, "If the setup stops", "What only this README covers" and "What the script guides you through" (the order is explained below).
     - That is wider than step 0 alone, which Adam named; Adam to confirm. Why: the script's messages send the reader to "step 0 of the README" and "step 1 of the README", so the bootstrapper's README needs both, with what follows them, and the template's README tests (S19 in `bootstrap/test-bootstrap-project.sh`: every guide in its group, every question, the commands the script prints, the banned words) already pin exactly this part. Copying all of it keeps one copy, and those tests guard what ships.
     - The draft has one line `{{TEMPLATE_README_SETUP}}`. The build replaces it with the marked lines (without the two marker lines) and writes the result to `.github/README.md` in its output. It fails, writing nothing, when the source is missing, the placeholder is not on exactly one line of its own, the markers are not each there exactly once on a line of their own with start before end, or the marked part is empty. It also fails when a manifest path or a stub would already put a file at `.github/README.md`, so nothing is overwritten unnoticed. The existing checks then apply to the new file too: no `{{TEMPLATE_` left, the forbidden strings, and the output list (which adds `.github/README.md`). There is no stub at `bootstrap/stubs/.github/README.md`.
     - Done in this PR, as prose: the markers; the order of the marked part changed for a newcomer: step 0, step 1, "If the setup stops" (the paragraph on how the command to continue saves the answers, which was in step 1), "What only this README covers" (which says what to do after the script), and last "What the script guides you through", the reference list; "Claude Project" explained where it is first used (r5r-d). `test_help_and_readme_name_the_short_command` reads step 1 up to "What the script guides you through", so "If the setup stops" stays before that list.
     - In part 2: the template README's paragraph on the "Use this template" button (outside the marked part) says that such a project's page shows the bootstrapper's README until its setup has finished.

  3. **The project's README (r5r-g).** The setup section's heading becomes `## Finishing the setup`, with no "(delete this section when done)": no README asks the reader to change or delete any part of it (Adam's rule). The setup still removes the section by itself. Not done in this PR, though Adam's request put it here; Adam to confirm: the heading is matched whole by the script (`SETUP_HEADING`, `remove_setup_section`, the `--resume` checks), by `bootstrap/e2e-check.sh` and by about ten tests, so changing it is a code change, made test first in part 2 (b); changed in the stub alone, it would stop every setup at `check_setup_section`. With it: `SETUP_HEADING` in the script and in `bootstrap/e2e-check.sh`; the e2e check `readme-section`, which today matches the literal prefix `## After bootstrapping`, matches `SETUP_HEADING` instead (with a test in `bootstrap/test-e2e-check.sh` that plants the new heading); the lookalike-heading tests and the comment in the fill section of the script that use the old prefix. Projects made by an older version need no handling: `--resume` already refuses a project made by another version. The section's text becomes:

     > If you see this, the setup of this project has not finished. Until it has, this project's GitHub page shows the bootstrapper's README (the file `.github/README.md`): do its step 0 to install gh and sign in, then run the command below in Git Bash (Windows) or a terminal (macOS, Linux), with OWNER and NAME taken from this project's web address, https://github.com/OWNER/NAME:
     >
     > (the same `--resume` command as now)
     >
     > The setup then finishes, and removes this section and `.github/README.md`.

     Besides that, the project's README gets one new section, "Working from another computer" (Adam, 2026-10-29): see 7. Nothing else in it is changed by this PBI.

  4. **Each pointer to the template in what ships** (checked on main at `b98f48e`):
     - **The project README's step 0 line** ("step 0 in the README of https://github.com/factoincognito/ai-project-template-v2"): the content is brought in. The line points to `.github/README.md` in the same project, which holds step 0 until the setup has run (text in 3).
     - **The bootstrapper README's step 0 pointer:** the content is brought in, by the build (2).
     - **`docs/DEV_INFRASTRUCTURE.md`** (one file serves the template and every project, shipped unchanged):
       - Section 4, "(see the README of https://github.com/factoincognito/ai-project-template-v2)": dropped. In a project the setup has already run, and the steps by hand follow in the same section.
       - Section 4, the paragraph "In the template repo." (the template's two required checks and its release workflow): dropped from the shipped file and moved to the "Branch protection" section of the template's `README.md`, which does not ship. Projects do not have that pipeline.
       - Section 5, the sentence "In the template repository itself `ci.yml` is not the stub ...": moved the same way, for the same reason.
       - Part 2's opening, "if that folder has been deleted after setup, the same file is in the template repo at ...": dropped. The setup keeps the pack's `code-standards.md` in `languages/<pack>/`.
       - Part 2's links to the other packs' `code-standards.md`, which the setup now rewrites to links into the template: dropped, with the sections around them. The setup removes Part 2's section of each pack the project does not use: from its `### ... (\`<pack>\` pack)` heading up to the next line that starts with `### ` or `## ` outside a fenced block, or the end of the file (the python section has `#` lines inside a code block, and the react-native section is the last one). Tests cut python from a node project and react-native from a python project. A project has one pack; those sections describe nothing in it. The check `pack-links` in `bootstrap/e2e-check.sh` becomes: no section and no link for another pack. `TEMPLATE_URL` in the script and in `e2e-check.sh` is then unused and goes.
       - "made from this template" (the opening) and "made from the template" (section 3): reworded to "made with the bootstrapper". Not pointers, but they read as the template in a project.
     - **`languages/README.md`:** not shipped, so its pointers go with it. Checked: the setup already deletes it from every project (`tidy_up`), so it is read only in the bootstrapper and in a copy before the setup. It is for whoever adds or changes a pack, which is work in the template, and the script does not read it. The manifest gets a line `exclude languages/README.md`; the build fails when an excluded path does not exist or is not inside a listed folder, and checks that it is not in the output.
     - **`docs/ROUTINES.md`**, "The design, the dead ends already investigated and the related backlog items are in the template repo: ... (`memory/decisions.md`, "Path B")": the pointer is dropped; "Neither is built or tested yet." stays. Building it is work in the template and would reach projects with a later release; a project's own `memory/decisions.md` never had "Path B". In the template, `CLAUDE.md`'s table leads to `memory/decisions.md`.
     - **Kept, as the record of origin:** the project's `CHANGELOG.md` ("built from factoincognito/ai-project-template-v2@<commit>"), the script's `--version`, and the spec link in the script's header comment. Also checked and left, as they link nowhere: "Project just bootstrapped from the template." in the stub `docs/NEXT_SESSION.md`, the history in `docs/decisions/0001-rebuild-workflow.md`, and `licenses/NOTICE` ("The files this template ships", "covers the template's files only"), which is licence text, so its wording is Adam's to change.

  5. **No README asks to be edited (r5r-g).** Checked on main: the stub's setup heading is the only such text in the template README, the stub README and the draft. Part 2 adds a test that none of the three asks the reader to delete, remove or edit part of it.

  6. **The bootstrapper's README (r5r-b to r5r-f).** The draft is `bootstrap/bootstrapper-README.md` in PR #304: what the bootstrapper is and what the reader gets (r5r-c), where to start (r5r-c), what each tool is for and what it costs (r5r-e), the two roles named once in plain words (r5r-d), a section for a project whose setup has not finished, and a short "Without Claude". "Start here" sets up one computer only (Adam, 2026-10-29: do not bring several computers into the setup): step 0 prepares the computer, step 1 sets up the project; step 0's heading no longer says "(once per computer)". Its part on how to go on ("What only this README covers", "After the script") points to the new project's "Working from another computer". Branch protection, the team table and the details of working without Claude stay in the project's own README and are not on the bootstrapper's page (r5r-f). Its prose passes the same banned-word check as the README setup text, and its `--resume` command is the one command with ` --resume --owner OWNER --name NAME` added, the same as the stub's (part 2 adds both tests, so the two copies cannot drift apart). The placeholders of the project's README no longer show on the bootstrapper's page (r5r-b).

  7. **Working from another computer (Adam, 2026-10-29).** The README a new project starts with (`bootstrap/stubs/README.md`) gets a section "Working from another computer", under "Setup", as written steps, not a guided installer: (1) step 0 of the bootstrapper's README on that computer, and never its step 1, which creates a new project; (2) `gh repo clone OWNER/NAME` in a projects folder, for a copy of the existing project; (3) `git config user.name` and `git config user.email` in that copy, because the setup writes them only into the first computer's copy (`in_copy ... config user.name`), so commits from a new copy would otherwise fail, or carry another name; (4) the Claude app as usual, which needs nothing else on that computer. It says that another computer gives another place to work from, not more capacity or parallel work.
     - Step 0 is linked (the bootstrapper's page), not copied into every project's README; Adam to confirm. Why: it keeps each project's README short, and the bootstrapper is what ships, not the template, so "nothing from the template" still holds. The other way: the build copies step 0 into the stub too, by the same markers.
     - It also says that someone who works only in the Claude app needs only step 4, and points a copy used in VS Code to `docs/DEV_INFRASTRUCTURE.md`, "New machine setup" (the language runtime and the pack's first-time setup); both from Crog's round 3 review.
     - Done in this PR, as prose (the stub ships unchanged by the build). Its link to "Start here" holds only once part 2 (a) is released, so there is no release between this PR's merge and part 2 (a). Part 2 adds tests: the section names step 0 and `gh repo clone`, does not hold the one command of step 1, and passes the banned-word check.

  8. **Not in this PBI.** The project's README still names "Cowork" and `docs/decisions/0001-rebuild-workflow.md` §6 in "Working setup" (r5r-d saw them on the bootstrapper's page, which they leave); recorded in `docs/NEXT_SESSION.md` with the r5r entries in part 2.

  9. **Part 2, in this order, each PR test first with a red run, reviewed by the role that did not write it:** (a) the build writes `.github/README.md` and leaves out `languages/README.md` (`bootstrap/test.sh`), with the template README's "Use this template" paragraph; (b) the script: the tidy-up deletes `.github/README.md`; the setup's own check of what it changed (`expected_change`) accepts `D .github/README.md` (in `test_expected_change_accepts_exactly_the_changes_the_setup_makes`, with its refused variants, and in the exception list of the test that compares the built tree with the copy); the setup PR's "Removed:" line names it; the new heading and section text (3); `refuse_project`'s step "do the steps that are still open; the README of the bootstrapper lists them", which no README does, points instead to `docs/DEV_INFRASTRUCTURE.md`, "Branch protection runbook", the steps written down for finishing by hand; in `bootstrap/e2e-check.sh` a new check that the copy has no `.github/README.md` (in `LOCAL_CHECKS` of its tests); and the tests for the section in 7; (c) the pointers in 4 (`docs/DEV_INFRASTRUCTURE.md`, `docs/ROUTINES.md`, the template README, the setup's Part 2 cut, `pack-links`). Then the CHANGELOG, the r5r entries in `docs/NEXT_SESSION.md`, and the release prep for v2.8.4.

  10. **Checks.** Before (a) is built: GitHub's README order, from GitHub's documentation or by looking at a page that has both files. After the release: the bootstrapper's page shows its own README with steps 0 and 1; a project made by the script shows its own README and has no `.github/README.md`; `e2e-check.sh` passes with its new checks; run 5 is then done from the bootstrapper's page alone.

- **[NEXT] PBI-1.30** (Adam, 2026-10-29, from a product office session; Adam chose Clead's recommendation; the WHAT is Adam's, the HOW is Clead's; not yet specced or reviewed) — A newcomer persona, run on a small AI model, as a pre-check before each human end-to-end run.

  **Why (Adam, 2026-10-29).** Adam asked whether an AI persona with limited intelligence, run on a simple model at low effort and told exactly how to be and act, could do run 5.

  **What it is and is not (Clead, 2026-10-29; Adam chose this).** A standing pre-check, run before each human run, not run 5 itself: run 5 stays with a person who has never used gh or a terminal (PBI-1.14 Done when 7). Reasons: a model still knows what a terminal, git and gh are and fills gaps from that knowledge, which are exactly the gaps run 5 looks for; a weak model fails differently from a newcomer (it misreads or invents rather than getting stuck where a person would); and it cannot do the physical part (installing on Windows, the browser sign-in with a code, a window that freezes), where run 3 showed people get stuck.

  **The persona (confirmed by Adam, 2026-10-29), as one fixed file used the same way every time:**
  - Role: someone with an idea for a small app who wants a project set up to build it.
  - Qualities: uses Windows, a browser and email daily; reads carefully; follows written steps one at a time.
  - Lacks: has never used a terminal, git, gh or GitHub; does not know words like repo, branch, PR or CI; does not know what Claude Code is.
  - Rules of behaviour: uses only what is written on the page or printed by the script; stops at every word or step it cannot follow and reports it with the exact text; never fills a gap from its own knowledge.

  **What it reads:** the bootstrapper's README (from PBI-1.29 on, its own README) and every message the setup script prints, in the order a newcomer meets them. Its findings are recorded like a human run's, in `docs/NEXT_SESSION.md`.

  **Spec (Clead, 2026-10-30; the persona above is Adam's and unchanged; rounds 2 and 3 after Crog's review on #314).** The open points are HOW, settled here.
  - **Where it lives.** One template-only file, `docs/NEWCOMER_PRECHECK.md` (not in `bootstrap/manifest.txt`, so it never ships; listed in `bootstrap/not-read-by-tests.txt`). It holds, word for word and used the same way every time: the persona as above; the instruction the persona is given with its two texts; and the procedure below.
  - **Model.** The smallest model Clead's agent tool offers (Haiku today), at low effort (Adam's question of 2026-10-29: a simple model at low effort), started as a fresh agent that has seen nothing of the work. A bigger model knows more and fills more gaps, which is what the check must not do.
  - **What it is given, and nothing else.** Two texts, both from one build of the commit being checked, and both made by the test below: (1) the bootstrapper's README as the build writes it (`.github/README.md`), as Markdown text; (2) the screen of the interactive setup as a newcomer meets it, with the script from that same build (two runs, see "The screen"). The instruction tells the persona to use no tools and nothing but these texts; the agent tool cannot enforce that, so Clead discards a run whose findings quote anything that is not in the two texts.
  - **Which script.** The pre-check runs on the commit that is or will be released: after the release prep, before the tag, so the persona checks what will ship. For a release already tagged (v2.8.4 now), it runs on `main` when `git diff <tag> main`, apart from the new test and its durations line, touches nothing that the build ships or that the test uses; otherwise on a branch from the tag with the test added. Either way the test uses the harness's build, so these are stand-in values, named in the procedure: the version `v9.8.7`, the harness's fake commit, the harness's fake date, the owner `octo-user` and the stub gh's version.
  - **The screen.** A new test in `bootstrap/test-bootstrap-project.sh`: an interactive run of the built script, as on Windows in Git Bash, with the harness's stand-ins for gh and the CI run, starting where the README leaves a newcomer: Node.js not installed. So the screen has two runs, as a newcomer meets them: the first run, with npm missing, shows the Windows Node.js guide; at its pause the test types `q`, as the guide says (since #318, the fix for p2.8.4-c: type `q` and copy the command it shows, then close the window, open Git Bash again from the Start menu and run that command there); the second run, in a new window with npm present, is started with that command and goes through. Each answer is given where the script reads it: stdin (`<dir>/in`) for the questions, "Proceed?" and the guides' pauses, the terminal (`<dir>/tty`) for the questions the script asks there. The answers, fixed in the test: project name `tool-share`; display name `Tool Share`; description `Lets neighbours lend each other tools.`; language pack `web`; licence `mit`; at every other question the script's suggested answer (Enter), and yes at "Proceed?". If the script needs another answer that has no suggestion, the builder adds it here in the test and the spec is updated in the same PR. The test checks that the second run finishes the setup. When `BOOTSTRAP_NEWCOMER_SCREEN=<folder>` is set, it also writes `screen.txt` (both runs; in each, stdout and stderr as one stream, in the order printed, with each answer shown after its question as a terminal would echo it) and `README.md` (the build's `.github/README.md`) to that folder; the test asserts the order of a line printed to stderr between two printed to stdout, and that each question is followed by its answer. Test first: the check that the files are written fails before the change. If the CI shards need it, the test gets its line in `bootstrap/test-durations.txt`.
  - **The procedure (in the file).** Clead makes the two texts with the test, starts the persona with the fixed instruction and the two texts, and asks it to go through them in order, as the persona, and report every place it stops: the exact text, and what it did not understand or could not do. Clead records each stop in `docs/NEXT_SESSION.md` like a human run's findings (`p<version>-a`, `-b`, …), with Clead's verdict: a defect to fix, a stand-in artefact, or not a defect, with the reason. Stand-in artefacts besides the values above: the screen has no colours though the script's colour key names them; the README is Markdown text, not the page as GitHub shows it.
  - **Pass.** Every stop is fixed, or recorded as a stand-in artefact or not a defect with its reason. A run whose findings quote text that is not in the two texts is discarded and repeated; the pass needs a run that was not discarded. Fixes go out in a release (one more tag from Adam per round of fixes), and the check runs again on it, before the human run.
  - **Not covered, by design.** What only a person meets: installing programs, GitHub's sign-in in a browser, a window that freezes. Those stay with the human run.

  **Order.** After PBI-1.29 is released and before run 5: the persona checks that release first.

  **Rules that apply.** The persona file and its prompt are process documents: reviewed by Crog. Any script or test that runs it is code: test first, reviewed by the role that did not write it.

- **[LATER] PBI-1.31** (Adam, 2026-10-29, during the PBI-1.29 spec session; not specced) — The Claude parts of a bootstrapped project become an add-on.

  **Why (Adam, 2026-10-29).** A bootstrapped project's instructions are built around Claude. Without Claude, the project is still a well set-up project with GitHub's checks and balances (the project README's "Working without Claude"). For a WHAT person like Adam that is never enough; for someone with a lot of HOW knowledge it may well be, and bring value. "The more I think about it, the more I see the Claude parts of a bootstrapped project as an add-on."

  **For now (Adam, 2026-10-29).** The setup script keeps its Claude parts built in as they are. Done iteratively, when there is value in it; nothing is built until Adam takes it up.

- **[LATER] PBI-1.33** (Adam, 2026-10-29, from a product office session; the WHAT is Adam's, the HOW is Clead's; not yet specced or reviewed) — A regular check for new versions of the language packs' components (tools, libraries, GitHub Actions, the SDKs and runtimes they pin), so that updates are brought into the template.

  **Why (Adam, 2026-10-29).** The packs pin exact versions; nothing tells us when they fall behind. PBI-1.6 refreshed the node pack's versions once, by hand.

  **The WHAT (Adam, 2026-10-29).** The template's components are updated regularly when updates are available. The mechanism and the timing are Clead's to decide (HOW).

  **Urgent updates (Adam asked, 2026-10-29; Clead's answer).** Yes, they need their own path: an update that fixes a security vulnerability (a GitHub security advisory or a CVE against a pinned version) goes in at once, with its own release, not with the monthly batch. A bug fix that is not about security but breaks something the packs use is treated the same way when it affects the template or new projects; otherwise it waits for the batch.

  **Clead's thoughts (2026-10-29; the spec settles them):**
  - Cadence: check weekly, bring updates in as one PR per pack about once a month, and a security fix at once. Each update runs the full CI and needs a release before projects get it, and the packs pin exact versions on purpose.
  - Tool: GitHub's Dependabot can find new versions and open the PRs without Claude and without using Adam's usage (npm, pip, NuGet and GitHub Actions). Whether it handles the packs' layout (`languages/<pack>/`) is not checked. A Claude scheduled task adds judgement where it is needed: major versions, release notes, breaking changes, and the runtimes and SDKs Dependabot does not cover. Possibly both: Dependabot finds, a session judges and bundles.
  - Not in scope unless Adam says so: bringing the updates into projects already bootstrapped.

  **Rules that apply.** Workflow and config changes are code: test first, reviewed by the role that did not write it.

- **[LATER] PBI-1.34** (Adam, 2026-10-30, from a product office session; the WHAT is Adam's, the HOW is Clead's; not yet specced or reviewed) — The newcomer pre-check (PBI-1.30) runs several times, nightly, whenever what a newcomer reads has changed.

  **Why (Adam, 2026-10-30).** The persona is not consistent: a run can read past something that the next run stops at (seen on 2026-10-30: the second run stopped at five lines the first read past). Several runs per change lower the risk of a skipped stop.

  **The WHAT (Adam, 2026-10-30).** A scheduled task is started every night. Its control step first checks whether anything has changed that a persona test would touch; only then does it run the persona test several times (Adam's 5 or 10 are examples, not decided).

  **Clead's thoughts (2026-10-30; the spec settles them):**
  - The control step compares against the last commit the persona checked, recorded with its results, not against the previous night, so a missed night loses nothing. What it compares: the files that make the two texts (the template README's setup part, `bootstrap/bootstrapper-README.md`, the setup script). Nothing changed: the task ends at once, at little cost.
  - Changed: the two texts are made once, then N persona runs on Haiku at low effort, in parallel; N starts at 5 and is raised if the last runs still add new stops, lowered if they never do.
  - The persona agents read the prompt from a file, so the session that runs the task does not paste it N times; the instruction's "use no tools" allows that one read, and the quote check stays (a procedure change to `docs/NEWCOMER_PRECHECK.md`, reviewed by Crog).
  - The stops of all runs are merged into one list, with how many runs hit each one (a signal of how likely a person is to stop there); each quote is checked against the texts; the findings, with Clead's verdicts, go into `docs/NEXT_SESSION.md` through a PR.
  - The same N runs become the pre-check before each release tag.
  - Limits: more runs lower random misses, not a blind spot that every run of the same model shares; the human run stays.
  - Not checked: how much of Adam's plan usage a scheduled task's session draws; measured on the first runs and reported.

  **Rules that apply.** The procedure is a process document: reviewed by Crog. Any script, workflow or test is code: test first, reviewed by the role that did not write it. The scheduled task's prompt follows the product office's rules for scheduled tasks (it runs without asking for approval; its setting is reported).

- **[LATER] PBI-1.35** (Adam, 2026-10-30, from a product office session: "as per your recommendation"; the WHAT is Adam's, the HOW is Clead's; not yet specced or reviewed) — Keep the clean-session checklist, drop the `..wrap` ritual and the PIN workflow.

  **Why (2026-10-30).** Adam has not used `..wrap` in a long time. Decisions are now written to the repo through a PR when they are made, the stop hook flags uncommitted and unpushed work after each turn, and the weekly loose-ends sweep catches what is left across the repos; `..wrap` rarely finds anything those missed. Pins live only in a chat and are not used.

  **The WHAT (Adam, 2026-10-30, Clead's recommendation).** The seven conditions of "Clean session end state" stay. A session checks them itself whenever it reports work as done, or when Adam says he is stopping, in any words; no stop word is needed. `..wrap` and the PIN workflow come out of `CLAUDE.md`, in the template and so in every new project.

  **For the spec.** Where `CLAUDE.md` names `..wrap` or pins (the "Session end" section, the graduation rule, the PIN workflow, condition 7) and any other file that does (search the repo, `bootstrap/stubs/` included); whether projects already bootstrapped get the change (not in scope unless Adam says so); the product office's own `CLAUDE.md` and memory notes that mention `..wrap`, through the product office.

  **Rules that apply.** A process change to `CLAUDE.md`: reviewed by Crog. Any check or test that pins the text is code: test first.

- **[LATER] PBI-1.37** (Adam, 2026-11-05: "as per your recommendation", Clead's grouping of `docs/NEXT_SESSION.md` item 20; the HOW is Clead's; not yet built) — Follow-ups to PBI-1.36 from the optional points of its reviews (#348 comment 6635347264, #349 comment 6636174845, #350 comment 6636321060).

  **Scope.**
  1. **The shard-time test reads the legs from the workflow** (#348 N3): `test_workflow_shard_counts_keep_every_legs_slowest_shard_short` loops over `wf_legs`, not three hard-coded names, so a leg added later (macOS, PBI-1.27) is held to the limit without another test pinning the list.
  2. **The pin itself is tested** (#349 N1): a test that `bootstrap/bash32.sh` has the literal `SHA256=<pinned value>`, so a hash override under any variable name fails, not only `BASH32_SHA256`.
  3. **A failing hasher says why** (#349 N3): when `sha256sum`/`shasum` fails, `bash32.sh` prints an `::error::` line naming it and exits 1, as for its other failures. Older than PBI-1.36.
  4. **Durations are timed from the test step** (#348 N1): `bootstrap/durations-from-logs.sh` starts a log's first test time at the test step, not at the first non-action step, so a cache-miss bash build or other set-up is not counted as the first test's time. Older than PBI-1.36; the current column came from a run where every bash 3.2 shard hit the cache.

  **Folded in where these PRs touch the same lines** (wording, no behaviour): test names and the comment that still say OS for leg (`..._for_each_os`, `..._on_every_os`, the comment of `test_durations_from_logs_reads_the_times_between_result_lines`; #348 N2); the `bootstrapper.yml` header comment that explains the 8 bash 3.2 shards by the old 4-shard times (#348 N4); the loop over workflow files in `test_bash32_script_takes_no_hash_from_the_environment` fails when a file is missing (#349 N4).

  **Dropped (Adam, 2026-11-05, on Clead's recommendation), with the reason.** #349 N2: wording of a merged PR's description, nothing left to change. #350 N1: the fake curl's exit code (22, not curl's timeout 28) changes no result. #350 N2: `--max-time 120` also stops a slow but moving download; the value stands unless a slow mirror trips it. #350 N3: the other Bootstrapper jobs keep GitHub's 6-hour default; they download nothing, so the stall PBI-1.36 addressed cannot happen there. The single-run sample behind the `ubuntu-bash32` column: later runs are averaged in when the durations are next measured.

  **Rules that apply.** Script, test and workflow changes: test first (red, then green), reviewed by a Crog agent on Opus, one PR per scope point.

- **[LATER] PBI-1.39** (Clead, 2026-11-06, from the non-blocking notes of the Crog review of #358, comment 6681037733; the HOW is Clead's; not yet built) — Follow-ups to the Rules edition check (`.github/scripts/check-rules-edition.sh`).

  **Scope.**
  1. **A push to `main` that deletes the folder** (N1): it passes, by design, since `main` changes only through pull requests, which are checked; but it prints "no edition taken yet". Compare a push with its parent, or say in the message that a push is not compared.
  2. **A failed lookup is not "absent"** (N2): `git cat-file -e … 2>/dev/null` reads any lookup error as "the folder was not there". Tell "not there" from "could not look", and exit 2 on the second.
  3. **The guard is tested** (N3): no test fails when the `-n "$MERGE_BASE"` guard is removed, and the `die2` after `git merge-base` cannot be reached by a test. Add a test for each, or drop what cannot happen.
  Also from the review of #357 (notes 2 and 3, still open): extra file names that hold a newline are reported in pieces (`find -print0` would keep them whole); a `pull_request` event without `GITHUB_BASE_REF`, a failing `git diff` and a missing `find` or `git` have no test, and the last exits 127, not 2.

  **Rules that apply.** Script and test changes: test first, reviewed by a Crog agent on Opus.

- **[LATER] PBI-1.40** (Clead, 2026-11-06, from the non-blocking notes of the Clead reviews of #363, #364, #366 and #367 and the author's runs; the HOW is Clead's; not yet built) — Follow-ups to PBI-1.38.

  **Scope.**
  1. **The stub-path check** in `bootstrap/test.sh` only matches paths ending in `/`, `.md` or `EDITION`; a pointer to a `.sh` or `.yml` file in the stubs is not checked to exist (#363 N4).
  2. **"No rule text" in the `CLAUDE.md` stub** is checked as at most 15 non-empty lines, which catches growth but not one rule sentence in the existing lines (#363 N5).
  3. **The `CLAUDE.md`-section pointer pattern** still passes three forms no shipped file uses (`` `CLAUDE.md` § … ``, "`CLAUDE.md`, under …", "`CLAUDE.md` (…)"); the citation test checks paragraphs, not subsections; Part 1's per-paragraph check passes when any subsection of a paragraph is cited; its empty-parse message can mislead (#366 notes).
  4. **`e2e-check.sh`**: `--help` still says the checker only reads, though the new `rules-edition` check runs the copy's own script; the exit-2 path (the script cannot run) has no test (#367 N1, N3).
  5. **Possibly flaky:** `test_ctrl_c_during_the_discard_puts_the_terminal_mode_back` and `test_keys_typed_before_a_question_are_discarded_at_a_real_terminal` failed once in shard 4 on a 2-core machine shared with other suites, and passed three times out of three alone. Watch CI; give them a timing margin if they fail there.

  **Rules that apply.** Test and script changes: test first, reviewed on Opus by the role that did not write them; one PR per point.

---

## Phase 2 — Validate unproven pieces

**Goal:** Prove the two load-bearing assumptions before claiming full
autonomy. Use a real project as the pilot: acuteping (decided
2026-09-30; previously python-blackjack-v2, see Phase 3).

- **[NEXT] PBI-1.54** (Clead, 2026-11-07, from PBI-1.41: part (c3) of its spec and the follow-ups of its reviews; the HOW is Clead's) — tests for the lines of the template's scripts that no test reaches, and the follow-ups the reviews of PBI-1.41 left.

  **Scope.** (1) Tests for the about 150 lines of `bootstrap/stubs/bootstrap-project.sh` that no test reaches (the largest pieces in `resume_read_github`, `layout_into`, `check_changed_paths`, `check_license_answer` and `api_call`), and for the lines `bootstrap/coverage.sh` leaves untested; each test checks an outcome and is shown to fail when its line is broken. (2) PBI-1.41's follow-ups (1) to (9) as listed there. (3) From the review of #397: an interrupted coverage run leaves its temporary folder (no trap); `.simplecov` is not in the test-change check's code patterns; `coverage.rb` matches only a lower-case hex commit; the copy check's stamp patterns are not tested on the negative side; the coverage download has no `always()`.

  **Done when.** Each item is fixed, test first, or recorded as not worth fixing with a reason.

  **Rules that apply.** Script, test and CI changes: test first, reviewed on Opus by the role that did not write them, within P-3 § 2; one PR per item or small group.

- **[LATER] PBI-1.55** (Adam, 2026-11-07, in a product office session; the WHAT is Adam's, the HOW is Clead's; not yet specced, reviewed or intent-approved) — Bootstrap options beyond a single project: an umbrella, an umbrella with its first project, and a project into an existing umbrella.

  **Adam's WHAT (2026-11-07).** What the bootstrapper can set up:
  - A. A project, with Claude support (A1) or without it (A2). Already PBI-1.24 (the setup option) and PBI-1.31 (the Claude parts as an add-on); not repeated here.
  - B. An umbrella bootstrap, only with Claude support.
  - C. B and A1 together.
  - D. A1 into an umbrella that already exists.

  **Paths for existing repositories (Adam's questions, 2026-11-08 00:10; the list is Clead's proposal, recorded at Adam's "apyr", 00:12).** None is covered by the bootstrapper today: the setup script refuses a repository it did not create, and the migration branch of PBI-1.4 was superseded on 2026-10-01 without becoming an item of its own.
  - E1. An existing repository becomes a standalone project with Claude support.
  - E2. An existing repository into a project with Claude support under an existing umbrella. Done by hand so far: fomo-f and acuteping's interim repository, both repositories without the template's files, were brought in line and signed off to the product office's Rules by a session in each, at the 2026-11-05 cutover.
  - E3. An existing repository into a project with Claude support under a new umbrella: C with an existing repository in place of a new one.
  - E4. An A1 project made by the bootstrapper joins an umbrella later, new or existing; its own copy of the Rules gives way to the umbrella's. Done by hand so far: vizi, made by the bootstrapper on 2026-11-04 and signed off to the product office's Rules on 2026-11-05.
  - E5. A pre-project inside an umbrella: a folder in the umbrella's repository, with its own status and rules, that later moves into a repository of its own.
  - Left out: an existing repository into a project without Claude support. It would add only branch protection, CI and the test-change check, which the owner it suits can set up without the bootstrapper (Adam and Clead, 2026-11-08).
  - Already open elsewhere: an A2 project adding Claude support later (PBI-1.24, "Open").

  **What an umbrella is (Clead's reading, to be confirmed when specced).** A repository above several projects, like the product office is for Adam's own: the single entry point for work with Claude, the home of the rules and processes the projects sign off to, the list of projects, the ideas, and the view of each project's status read from its `STATUS.md`. In D, the new project is listed in the umbrella and signs off to its rules instead of carrying its own copy of them.

  **Adam's question, Clead's answer (2026-11-07, not confirmed by Adam).** Adam asked whether an umbrella without Claude support would make sense. Clead: no. Its rules bind sessions, and its sign-offs, audits, status view and list of what waits for the owner are carried out by sessions; without them it is a folder of documents that nobody keeps to. For the same reason Clead does not propose an A2 project under an umbrella.

  **Settled (Adam, 2026-11-07 23:27 and 23:28, `memory/decisions.md`).** The concept is not private, even though Adam's own product office is: an umbrella bootstrapped for someone else is developed and shipped by this template. PBI-1.20's "The product office is Adam's own; it does not exist in the user's world" is about his own office and does not rule it out.

  **Order (Clead's proposal, not decided).** After PBI-1.24, since C and D build on A1 and that option, and after the end-to-end runs, because both change the setup script the runs test.

  **Rules that apply.** The spec needs Adam's intent approval. Script, test and workflow changes are code: test first, reviewed by the role that did not write them. Wording changes to process documents are reviewed by Crog.

  **Done when.** Written when specced.

- **[LATER] PBI-1.59** (Adam, 2026-11-08 00:14; the WHAT is Adam's, the HOW is Clead's; not yet specced; when it is built is not decided) — The bootstrapper's README says which kinds of setup it supports, which are not supported but planned, and, where relevant, which are not supported and not planned.

  **Why (Adam, 2026-11-08).** A reader should see from the README what the bootstrapper can set up today and what not, before starting.

  **Facts (Clead, checked 2026-11-08 at `main`).** The README is `bootstrap/bootstrapper-README.md`, built into the bootstrapper's `.github/README.md` (`bootstrap/build.sh`). The setup script supports one kind of setup: a new project with Claude support, with the node, web, python or react-native pack (`--pack`), and continuing a stopped setup (`--resume`, `--again`). The C# pack is laid out by `layout-pack` but not offered by the setup (PBI-1.23 part 2). Planned: PBI-1.24 (without Claude support), PBI-1.55 (umbrellas and existing repositories), PBI-1.23 part 2. Not planned: the paths PBI-1.55 leaves out.

  **Open (Clead, for the spec).** Where the list sits in the README, and how a planned item's line stays true when its PBI changes status (a test against the backlog, or a step in each PBI's "Done when").

  **Rules that apply.** The README is shipped and its prose is checked by `bootstrap/test.sh`; a README change and its tests: test first, reviewed by Crog. The spec is approved by Adam in chat (§ 29 (2)).

  **Done when.** Written when specced.
- **[SUPERSEDED] PBI-2.1** (the connector was written off 2026-06-28;
  Clead now uses git and the GitHub API, see memory/decisions.md; also
  duplicated PBI-4.3) — Confirm GitHub connector write access: verify
  that Cowork's GitHub connector can post PR comments, not just fetch
  diffs. The `review.yml` workflow posts a marker comment — confirm
  this fires correctly and Clead can read it to trigger review.

- **[LATER] PBI-2.2** (Adam, 2026-10-01: not approved as written; both
  design points below stay unresolved, so nothing is built) — Start Clead's review automatically when a PR
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

---

## Moved from the product office (2026-11-08)

Template work that the product office's backlog held until the product owner decided, on 2026-11-08, that a project's work lives in its own backlog. Each entry names the product office entry it came from, which now points here.

- **[LATER] PBI-1.56** (Adam, 2026-10-01; moved 2026-11-08 from the product office's PO-12) — Renew the bootstrapper's publish token `fi-bootstrap-publish` before it expires on 2027-10-02.
  Create a new token with the same permissions (Contents and Workflows, read and write, only `factoincognito/ai-project-bootstrap`), update the `BOOTSTRAP_PUSH_TOKEN` secret in this repository, and delete the old token. Adam does all three; a session cannot. A calendar reminder goes in around 2027-09-18. The setup this token belongs to is described under PBI-1.10.

- **[LATER] PBI-1.57** (Clead, 2026-10-26, from Adam's decision that the template propagates the product office's rules to new projects; moved 2026-11-08 from the product office's PO-56, part 2) — A check that the purpose and goal in a made project's `memory/project.md` are filled in once its setup phase is over. The bootstrapper already leaves them for the first Clead session; after that phase the check fails CI.
  Part 1 of the product office entry, the `STATUS.md` stub, is done (`bootstrap/stubs/STATUS.md`, checked 2026-11-08). Part 3, the product office's reader skill flagging a project whose purpose or goal is missing, belongs to the product office and stays there.

- **[LATER] PBI-1.58** (Clead, 2026-10-26, a HOW decision Adam delegated in chat; moved 2026-11-08 from the product office's PO-51) — Skills and subagents in the template, so that made projects inherit them. One PBI each, in this order:
  1. Crog as fixed subagent definitions (`.claude/agents/`): a reviewer on Opus whose only input is the diff, `docs/SPEC.md` and `memory/standards.md`, and a merger on Sonnet (verdict comment first, then squash-merge). This replaces briefing Crog afresh in every Clead session. Not checked: how a made project's Claude setup picks up agent files; test it before promising it. The product office entry pointed to `docs/NEXT_SESSION.md` item 13 for the "roster" part; no such item was found there on 2026-11-08.
  2. A handover skill (`.claude/skills/`) carrying the procedure for handing a session's role back, so it runs when a session is told to hand over.
  Whether the inputs in item 1 still match the review inputs of the Rules (P-3 § 2) is checked when the PBI is specced.

## Audit findings (2026-11-06)

The findings of the product office's audit of this project (Process P-6 § 8 (2)). Adam's decision: conditional accept, 2026-11-06.

- **[NEXT] PBI-1.42** (audit of 2026-11-06, finding F1, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 4): the template's own `STATUS.md` comment, lines 1 to 8, restates P-9 § 6 (2) to (4) without citing them.
- **[NEXT] PBI-1.43** (audit of 2026-11-06, finding F2, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 4): `docs/NEXT_SESSION.md` lines 26, 35, 37, 192 and 396 restate P-4 § 4, P-3 § 5 (3), P-4 §§ 1 (3), 2 (3), 3 (1) and P-2 § 2 (2) as standing instructions.
- **[NEXT] PBI-1.44** (audit of 2026-11-06, finding F3, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 4): `memory/context.md` lines 205 to 208 and 235 to 238 restate P-1 § 3 (1) and § 36 (1) and (2) as directives.
- **[NEXT] PBI-1.45** (audit of 2026-11-06, finding F4, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 4): shipped files restate paragraphs: `docs/DEV_INFRASTRUCTURE.md` lines 57 to 62, 94, 96 to 98, 102 to 103; `bootstrap/stubs/docs/NEXT_SESSION.md` line 7; `.github/workflows/changelog.yml` line 34.
- **[BLOCKED] PBI-1.46** (audit of 2026-11-06, finding F5, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; a question for the product office's Rules, not this project's to fix; waits for Adam's decision there) — (§ 4): the shipped edition `bootstrap/stubs/rules/`, which § 21 (5) requires, is not among P-6 § 4 (2)'s exceptions; not counted against the entity.
- **[NEXT] PBI-1.47** (audit of 2026-11-06, finding F6, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 5): L § 8 (2) limits edition PR descriptions against P-2 § 3 (1) and P-2 § 4 (1) without citing them; #372 names no session.
- **[BLOCKED] PBI-1.48** (audit of 2026-11-06, finding F7, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; a question for the product office's Rules, not this project's to fix; waits for Adam's decision there) — (§ 5): L § 9 (1)'s release pipeline commits directly to `ai-project-bootstrap`'s default branch (`bootstrap/publish.sh` line 88), and no paragraph settles this against § 26 (1) (C).
- **[NEXT] PBI-1.49** (audit of 2026-11-06, finding F8, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 7): P-2 § 4 (5): #375 and #376 merge comments give the session ID without the link; #372 names no session; commits `ca2925b` and `bc2954d` lack a `Session-ID:` trailer.
- **[NEXT] PBI-1.50** (audit of 2026-11-06, finding F9, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 7): P-4 § 5 (1): `CHANGELOG.md` is updated in batches at release prep (#375 for #351 to #374); #376 is not in it and no open PR updates it.
- **[NEXT] PBI-1.51** (audit of 2026-11-06, finding F10, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 7): P-9 § 2 (2) and (3): `docs/BACKLOG.md` uses markers `IDEA`, `SUPERSEDED`, `MOVED` (legend lines 15, 18, 19; six entries) and names vizi's format spec.
- **[NEXT] PBI-1.52** (audit of 2026-11-06, finding F11, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 7): `docs/BACKLOG.md` shows PBI-1.29 and PBI-1.30 as `[NEXT]` (lines 1008, 1078) while `docs/NEXT_SESSION.md` lines 215 and 216 record both done on 2026-10-30.
- **[NEXT] PBI-1.53** (audit of 2026-11-06, finding F12, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 7): P-8 § 4 (1) and § 27 (4): `docs/NEXT_SESSION.md` items 5 and 14, named by #369 as needing a disposition, are unchanged at `9241dab`.

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

- ~~C# language pack~~ — moved into Phase 1 as PBI-1.23 (Adam, 2026-10-28), as a base pack
- Elixir language pack — planned in v1, not yet built, not a Phase 1 priority
- Automated merge — Adam merges, always

The entries marked `DONE` are in [`docs/BACKLOG-DONE.md`](BACKLOG-DONE.md) (`RULES.md` L § 2 (1)).

<!-- vizi:include BACKLOG-DONE.md -->
