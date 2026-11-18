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
| [BLOCKED] | Waiting on dependency or decision |
| [DONE] | Completed and merged, or no longer needed or tracked elsewhere; the notes say which |

The format of this file is set by Process P-9 § 2.

The entries marked `DONE` are in [`docs/BACKLOG-DONE.md`](BACKLOG-DONE.md) (`RULES.md` L § 2 (1)).

---

## Phase 1 — Language packs and bootstrap wizard

**Goal:** Make v2 a fully usable template — clone it, run the wizard,
get a working project in any supported language.

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

- **[LATER] PBI-1.12** (unvalidated, needs discussion; pinned by Adam, 2026-10-01) — Delegation level as
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

  **Progress, item (1), 2026-11-08.** Measured from the coverage results of the `v2.9.2` tag run (42504175071, at `8d5ee3b`): 108 of the setup script's 3,248 counted lines are reached by no test. Line numbers below are at `8d5ee3b`.
  - Tests added (#447): the numbered choices and a refused visibility answer (1304, 1313 to 1316, 1333, 1334); `--again` after another option (1094, 1095); the old-bash guide on Fedora, Arch, openSUSE and an unknown Linux (2111 to 2114); the git and gh guides on a system that is not Linux, Windows or macOS (2184, 2310, 2311); the cd to the home folder and an empty word (1720, 1829); a failed move of the saved answers (1924, 1926); `--again` with answers saved as `--option=value` and without a project name (1952, 1953, 1960); an offered command that fails (2027); `--name`, `--owner` and `--dir` given only spaces, which `check_given` passes on and the checkers trim to empty (1160, 1161, 1190, 1191, 1250, 1251; found by the review of #447). Each test was shown to fail with its line broken.
  - Not worth a test, unreachable: `answer`'s missing-default branch (1408, 1409), since `check_options` reports every input without a default under `--non-interactive` and stops before `answer` runs; `offered`'s unknown offer (2009), since `OFFER` is set only to the offers it lists. Not observable: `AGAIN_TMP=""` after the failed move (1925) only keeps `leave_script` from removing the file again.
  - Second group (#450), the other 74 lines of the list, each sorted. Its line numbers are at `e3ba72d`, where #445 has moved the lines of `8d5ee3b` (the script is unchanged since; each line was mapped by a diff of the two):
    - Tests added, each shown to fail with its line broken: `layout-pack` without its words gives only the two usage lines (104, 105, 107); `layout-pack` with no pack folder says where the packs must be (881, 882); at a real terminal, Ctrl-D and Enter each end the question's line once (647, 649); a licence typed by its name (1342); a relative folder inside a git project, its top folder as the shell writes it (2574); an answer from gh with no status line (2749 to 2751); an account answer with no login (2886, 2887); a permissions check whose account read fails, guided to the account (3058, 3059, 3079, 3080); a refused make-public, with gh's answer or without one (3732 to 3734); the git name in the form git saves it (4743); `--resume` without a copy, the publishing files read as absent from GitHub's 404 (5800).
    - Run, but not counted by the coverage tool; an existing test fails with the line broken: inside a command substitution of several lines (646 and 648, `test_the_yes_to_an_offer_is_read_from_the_terminal_not_from_stdin`, which fails when the read turns into a yes, and for 646 also `test_an_accidental_no_is_offered_again_and_a_yes_then_runs_it`, which fails when it turns into no answer; 4549, `test_a_text_left_to_fill_in_stops_the_self_check_but_a_value_holding_one_does_not`); in a run piped into bash, which has no file name to count against (5949, 5950, 6025, 6026, `test_script_piped_into_bash_still_runs_its_main_part`).
    - No command of their own, so the coverage tool counts nothing on them: the lines that close a loop or a group (403, 446, 898, 909, 932, 944, 958, 1722, 2763, 2898, 2977, 4259, 4281, 4300, 4560, 4657, 5002, 5126, 5152, 5598, 5623, 5640) and the second line of a case pattern (1061, shown reached: `test_options_also_take_the_name_equals_value_form` fails with it broken). The case arms made of `;;` alone are reached; each was replaced by `exit 97` and a test failed: 2482, 3063, 3068, 4322 and 5007 (`test_values_holding_texts_of_the_fill_table_get_through_the_whole_setup`), 2573 (`test_the_folder_must_be_in_a_folder_that_exists_and_is_outside_any_git_project`), 2766 (`test_api_call_keeps_carriage_returns_only_when_asked`), 4085 (`test_no_licence_adds_no_file_and_warns_only_for_a_public_project`), 5565, 5609, 5627 and 5649 (`test_ctrl_c_says_what_exists_and_the_resume_finishes_without_duplicates`).
    - Not worth a test, unreachable: `say`'s empty-text arm (346 to 348), since every call passes a text that is not empty; `check_deploy_pack`'s arm for a `--with-deploy` problem already listed (1654), since the only other such problem is added later, by `resume_deploy_choice`, for the web pack only; the unknown key of `fill_text` and `fill_value` (4181, 4202), since both are called only with the keys of `fill_rows` and the two licence keys, each with its arm; `expected_change`'s folder target (4606), since `layout_into` puts each folder of the layout table into `LP_TARGETS` as the files in it, so no target ends with `/`. Not observable: `CLEAN=1` in `usage` (106), since `usage` runs only for `layout-pack`, which sets no stop handling (`catch_stops`); the `printf x` after the file in `fill_texts_left` (4550), which keeps the file's last line breaks, but no text to fill in ends with one.
    - So every line of the setup script that the `v2.9.2` run left unreached is tested or recorded. Three of the tested lines stay on the coverage tool's list, since it cannot count them: 647 and 649 (inside a command substitution of several lines) and 1342 (an arm made of `;;` alone); a later sort of the list should not take them for open lines. Still open in item (1): the lines `bootstrap/coverage.sh` leaves untested.

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

- **[LATER] PBI-1.60** (Crog's note a on #429, 2026-11-08) — Add `docs/BACKLOG-DONE.md` to `bootstrap/not-read-by-tests.txt`, so that a PR which only marks an entry `DONE` does not run the full Bootstrapper test matrix. A change to a CI input, so the test that pins the list's effect comes first.

- **[LATER] PBI-1.61** (Crog's note b on #429, 2026-11-08) — The header of the shipped `bootstrap/stubs/bootstrap-project.sh` (lines 3 and 4) links the PBI-1.14 spec at `docs/BACKLOG.md`, and a test in `bootstrap/test.sh` pins that URL; the entry is now in `docs/BACKLOG-DONE.md`, so a reader following the link does not find it. Point both at the new file.

- **[LATER] PBI-1.62** (Clead, 2026-11-08) — The `build` check downloads shellcheck from `github.com/koalaman/shellcheck/releases` (`.github/workflows/ci.yml`, step "Check the scripts with shellcheck") with `curl --retry 3`, so a GitHub outage on release downloads blocks every merge. Seen on 2026-11-08: from about 09:11 UTC every CI run failed on HTTP 504 for that download (runs 42466069856 on `main`, 42466077633 three attempts until 10:11 UTC, 42468753924, 42469213520); a run at about 09:01 UTC still passed. Possible fixes, to be specced: cache the checked archive between runs (`actions/cache`, keyed on version and SHA-256), or fall back to a second source with the same checksum. The same holds for the shfmt download in the next step.

- **[LATER] PBI-1.63** (Clead, 2026-11-17, from cutting `docs/NEXT_SESSION.md` from 134,970 bytes to a short handover) — Triage the notes the old staging file held. Their whole text is in the file at commit `070efd6` ([link](https://github.com/factoincognito/ai-project-template-v2/blob/070efd632f10c9fc73d235c9159627ea0d736d45/docs/NEXT_SESSION.md)); each group below, by line of that file, still needs a disposition under Process P-8 § 4: still open (its own PBI or an `IDEAS`-style entry), done (drop, with the PR that did it), or obsolete (drop, with the reason). None was checked against the code when the file was cut; the cut removed what the file itself marked as done or released.
  - **Open review notes marked non-blocking or "to keep":** lines 75, 86 to 96, 108, 114, 126, 130 to 131, 134 to 135, 138 to 144 (r3c, not reproduced), 162 (the project README still names "Cowork" and `docs/decisions/0001-rebuild-workflow.md` §6), 173 to 174, 182 and 193 (the wording item left for after run 5: say once what `build` and "line of work" are), 197 (what is left of PBI-1.54), and the notes by slice in 334 to 388 (slices S1 to S19 and PBI-1.18).
  - **Older entries cut as stale or answered; check each for something still open:** entry 5, a process audit of 2026-10-02 (283 to 302); entry 6, `CLAUDE.md` wording nits (304 to 312); entries 9 to 11 (390 to 413); entry 12, Clead in Code or in the Claude app, with an unanswered token-use question (415 to 425); entry 13, the template's value and its open questions (428 to 441); entry 14, answered (470 to 472); entry 15, the status overview, built as `STATUS.md` with two follow-ups left (473 to 496); the hand-back snapshot of 2026-10-15 (11 to 45); to-do 4, Adam's PC clone (204); "What waits for what" and the situation summary of 2026-10-02 (208 to 249).

- **[LATER] PBI-1.64** (Clead, 2026-11-18, from the stub check made for the release prep of v2.9.3, #470) — The header of `bootstrap/stubs/STATUS.md` is the format specification (Process P-9 § 6 (6)), but it does not say what P-9 § 6 (7) requires: in the fields, a reference to a backlog entry, PR, commit, file or repository is written as a Markdown link. Add that to the header. Checked 2026-11-18: every other Rules citation in the stub files resolves in the shipped Rules (`bootstrap/stubs/rules/`). Not checked: the stub files' content beyond their citations.

- **[LATER] PBI-1.65** (Clead's proposal, 2026-11-18, from the release prep of v2.9.3, #470; Adam has not decided it) — Nothing prompts a release when Rules edition PRs merge. The bootstrapper (rebuilt only at a `v*` tag, L § 9 (1)) shipped edition `2026-11-08-9acd383` (v2.9.2) while `main` held `2026-11-18-7dc72e8`: ten days and 17 edition PRs (#452 to #469) behind. Decide whether that needs a rule, a check or nothing, and what it costs.

## Audit findings (2026-11-06)

The findings of the product office's audit of this project (Process P-6 § 8 (2)). Adam's decision: conditional accept, 2026-11-06.

- **[BLOCKED] PBI-1.46** (audit of 2026-11-06, finding F5, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; a question for the product office's Rules, not this project's to fix; waits for Adam's decision there) — (§ 4): the shipped edition `bootstrap/stubs/rules/`, which § 21 (5) requires, is not among P-6 § 4 (2)'s exceptions; not counted against the entity.
- **[NEXT] PBI-1.47** (audit of 2026-11-06, finding F6, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 5): L § 8 (2) limits edition PR descriptions against P-2 § 3 (1) and P-2 § 4 (1) without citing them; #372 names no session.
- **[BLOCKED] PBI-1.48** (audit of 2026-11-06, finding F7, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; a question for the product office's Rules, not this project's to fix; waits for Adam's decision there) — (§ 5): L § 9 (1)'s release pipeline commits directly to `ai-project-bootstrap`'s default branch (`bootstrap/publish.sh` line 88), and no paragraph settles this against § 26 (1) (C).
- **[NEXT] PBI-1.49** (audit of 2026-11-06, finding F8, record `audits/ai-project-template-v2.md` in the product office; Adam's conditional accept, 2026-11-06; due 2026-11-20) — (§ 7): P-2 § 4 (5): #375 and #376 merge comments give the session ID without the link; #372 names no session; commits `ca2925b` and `bc2954d` lack a `Session-ID:` trailer.
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

<!-- vizi:include BACKLOG-DONE.md -->
