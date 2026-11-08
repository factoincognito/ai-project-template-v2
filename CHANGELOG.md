# Changelog

All notable changes to ai-project-template-v2 are documented here.
Releases from v2.1.0 on are tagged in git; v2.0.0 predates tagging.
A bootstrapped project records the tag it was built from.

## [Unreleased]

### Added
- Rules edition `2026-11-07-4fdfd54`: session startup gains a paragraph on the startup report (PR #410)
- Backlog: PBI-1.55, bootstrap options for an umbrella, and the decision that the concept is developed in this template (PR #411)
- Backlog: PBI-1.56 to PBI-1.58, template work that the product office's backlog held until now (PR #417)
- Backlog: PBI-1.55, the paths for existing repositories (PR #418)
- Backlog: PBI-1.59, the bootstrapper's README lists what it can set up (PR #419)
- Rules edition `2026-11-08-9239d41`: a new edition id, the text unchanged (PR #422)

## [2.9.1] — 2026-11-07

### Added
- Recorded the newcomer pre-check on v2.9.0, findings p2.9.0-a to -c; `STATUS.md` after the tag (PR #376)
- Backlog: PBI-1.41 spec, approved by Adam (PR #378)
- Backlog: the findings of the product office's audit of 2026-11-06, PBI-1.42 to PBI-1.53 (PR #380)
- NEXT_SESSION: Adam's input for the p2.9.0-b and -c fixes (PR #383)
- CHANGELOG: PRs #376 to #383 (PR #384)
- Backlog: PBI-1.41 part (a) done, and the follow-ups from its review (PR #385)
- NEXT_SESSION: for p2.9.0-c, the first message is a pre-written one (PR #387), and the steps on Android (PR #388)
- CHANGELOG: PRs #384 to #388 (PR #390)
- CHANGELOG: PRs #389 to #391 (PR #394)
- Backlog: PBI-1.41 part (b) done, and the follow-ups from its review (PR #395)
- Backlog: the PBI-1.41 spec counts the copies of the scripts the tests run, approved by Adam (PR #396)
- The test harnesses keep the script copies they ran when `BOOTSTRAP_TEST_KEEP_COPIES=1`, for the coverage run (PBI-1.41 part (c1)) (PR #393)
- `THIRD-PARTY-NOTICES.md`: bashcov and simplecov (PR #397), then ShellCheck and shfmt (PR #404)
- CHANGELOG: PRs #393 to #396 (PR #398)
- Backlog: PBI-1.41 part (c1) done (PR #399); review inputs outside P-3 § 2, and Adam's decision that the merged four get no new reviews (PR #401, PR #402)
- Backlog: PBI-1.41 done, and PBI-1.54 for the tests of the lines no test reaches and the review follow-ups; `STATUS.md` (PR #405)
- CHANGELOG: PRs #397 to #404 (PR #406)
- NEXT_SESSION: for p2.9.0-c, where the new-session button is on Android (PR #408)

### Changed
- The Rules edition: 2026-11-06-643aba6 (PR #377), then 2026-11-06-d0973c4 (PR #382), then 2026-11-06-7b6a5b5 (PR #391)
- `build` lints the template's own scripts with shellcheck 0.11.0, pinned by its hash, and fails on any finding; `.shellcheckrc` turns off three checks the scripts break on purpose (PBI-1.41 part (a)) (PR #379)
- The bootstrapper's README and the setup's closing screen say to choose all files when adding the GitHub project to the Claude Project, how to start a chat in it on a computer and on an Android phone, and give the first message as text to copy: the start line of the Rules edition's P-1 § 2 (5), filled in with the project's owner and name on the screen (newcomer pre-check findings p2.9.0-b and -c) (PR #407)
- `bootstrapper-test` gates the line coverage of the template's own scripts at 80%: the Ubuntu test jobs run under bashcov 4.0.2 and simplecov 1.3.2, pinned by their hashes, keep the script copies the tests ran, and upload their results; the gate maps each true copy onto its script (`bootstrap/coverage.sh`, `bootstrap/coverage.rb`, `.simplecov`) (PBI-1.41 part (c2)) (PR #397)
- `RULES.md` L § 7 (3): the dated condition of the sign-off is replaced by the override that puts the coverage gate in `bootstrapper-test` (PR #403)
- Three tests that failed under coverage tracing now pass under it; two of them now give the gate step the environment GitHub gives it, so their failing cases fail for the right reason (PBI-1.41 part (c1)) (PR #393)
- The template's 21 scripts are formatted with `shfmt -i 2 -ci` (shfmt 3.14.1), with no change in behaviour (PBI-1.41 part (b)) (PR #386)
- `build` checks the format of the template's own scripts with shfmt 3.14.1 (`-i 2 -ci -d`), pinned by its hash, and fails on any difference (PBI-1.41 part (b)) (PR #389)

## [2.9.0] — 2026-11-06

### Added
- Release prep for v2.8.5 (PR #322)
- Recorded in NEXT_SESSION that the newcomer pre-check passed on the v2.8.5 candidate (PR #323)
- Recorded v2.8.5 as released and verified; run 5 next (PR #324)
- Backlog: PBI-1.34, several nightly persona runs when what a newcomer reads has changed (PR #325)
- Backlog: PBI-1.35, keep the clean-session checklist, drop `..wrap` and pins (PR #326)
- `CLAUDE.md`: every reply to the product owner ends with a "For you" block (PBI-1.32) (PR #327)
- Backlog: PBI-1.25 progress, parts 1 and 2 merged (PR #331)
- Backlog: PBI-1.25 part 4 measured, outside scope for its target (PR #332)
- PBI-1.26 spec: exclude macOS as a supported platform for now (PR #333)
- Backlog: PBI-1.25 part 4 dropped (PR #335)
- Backlog: PBI-1.25 done, part 3 dropped (PR #336)
- Backlog legend: the MOVED marker (PR #338)
- NEXT_SESSION: follow-ups from the review of PBI-1.26 PR 1 (PR #339)
- The bash 3.2 leg of the Bootstrapper tests on Linux: GNU bash 3.2.57 built from source by `bootstrap/bash32.sh`, cached by `bash32-cache.yml`, run in 8 shards, judged by the shard gate (PBI-1.26 PR 1) (PR #337)
- `CLAUDE.md`: "Both agents: third-party code and IP", the product office rule on using code, firmware, designs and assets the project did not write (PR #345)
- Backlog: PBI-1.26 done; PBI-1.27's scope names #340 (PR #341)
- CHANGELOG: PRs #331 to #340 (PR #342)
- NEXT_SESSION: item 19, points 1 and 5 answered (PR #343)
- Backlog header: link to vizi's backlog format spec (PR #344)
- CHANGELOG: PR #345 (PR #346)
- Backlog: PBI-1.36, harden the bash 3.2 leg of the Bootstrapper tests (PR #347)
- Notes: PBI-1.36 done, item 19 resolved; CHANGELOG for PRs #341 to #350 (PR #351)
- NEXT_SESSION: to-do 5 done (PR #352)
- Backlog: PBI-1.37, follow-ups to PBI-1.36; NEXT_SESSION item 20 resolved (PR #353)
- `CLAUDE.md`: text the product owner is to paste is given as a code block (PR #355)
- `.github/scripts/check-rules-edition.sh`, the check that a copy of the Rules edition is an unchanged build output, run by the template's `build` in template mode (PR #357)
- Backlog: PBI-1.38, ship the Rules edition to new projects (PR #360)
- Backlog: PBI-1.39, follow-ups to the Rules edition check (PR #362)
- The Rules edition, the public edition of the product office's Rules, in `bootstrap/stubs/rules/`: edition 2026-11-06-b9a15ae (PR #365), replaced by 2026-11-06-5b3a7bb (PR #372) and 2026-11-06-821d361 (PR #374)
- The `build` check of every new project checks its copy of the Rules edition against its `EDITION` (PR #361)
- `bootstrap/e2e-check.sh` checks the Rules edition in the made project (PR #367)
- Backlog: PBI-1.38 done, and PBI-1.40, its follow-ups (PR #368)
- Backlog: PBI-1.41, lint, format and line coverage gates for this repository's own scripts, due 2026-11-13 (PR #370)

### Changed
- CI and the pack checks run on pull requests and on pushes to `main` only, not twice per branch push; a check in the `build` job keeps it so (PBI-1.25 part 2) (PR #329)
- The Bootstrapper tests run in a shard count per OS (ubuntu 4, macOS 5, Windows 8), with measured durations for every test; the Windows leg's wall time fell from about 23 to about 12.5 minutes (PBI-1.25 part 1) (PR #328)
- On a Mac the setup stops at once with a plain message, before it changes anything, and the macOS leg and the macOS steps in the READMEs are out of the Bootstrapper tests and docs: macOS is not supported for now (PBI-1.26 PR 2; PBI-1.27 brings it back) (PR #340)
- The Bootstrapper's bash 3.2 leg is split and held to the shard-time limit by its own measured durations (a new `ubuntu-bash32` column), not ubuntu's; the fixed floor of 8 shards is gone (PBI-1.36 part 1) (PR #348)
- `bootstrap/bash32.sh` takes no hash from the environment: the `BASH32_SHA256` test hook is gone, and the tests fake the hasher instead (PBI-1.36 part 2) (PR #349)
- Time limits on getting bash 3.2: `curl --max-time` on each download, and `timeout-minutes` on the "Get bash 3.2" steps and on the jobs that run them (PBI-1.36 part 3) (PR #350)
- The template's `build` fails a change that deletes the Rules edition folder (PR #358)
- New projects get a `CLAUDE.md` entry point that points to the Rules edition and a `RULES.md` for their local rules, which opens with the project's sign-off to the Rules; they no longer get `memory/roles.md`, `memory/standards.md`, `docs/CROG_ONBOARDING.md`, `docs/ROUTINES.md` or `docs/decisions/0001-rebuild-workflow.md` (PBI-1.38) (PR #363)
- The backlog, `STATUS.md` and README stubs give the formats the Rules edition points to (PBI-1.38) (PR #364)
- Shipped files point to the Rules edition instead of restating its rules (PBI-1.38) (PR #366)
- The template itself is bound to the product office's Rules: `RULES.md` holds its sign-off and its local rules, `CLAUDE.md` is a short entry point, and `memory/roles.md`, `memory/standards.md`, `docs/CROG_ONBOARDING.md` and `docs/ROUTINES.md` are gone (PR #369)
- `memory/project.md`: the goals follow the cutover (PR #371)
- `STATUS.md` after the cutover (PR #373)

## [2.8.5] — 2026-10-30

### Added
- Release prep for v2.8.4 (PR #312)
- `STATUS.md`: the newcomer persona pre-check comes before run 5; the run 5 tester is no longer a blocker (PR #313)
- PBI-1.30 spec: the newcomer persona pre-check (PR #314)
- Recorded in NEXT_SESSION and `STATUS.md` that v2.8.4 is released and verified, with GitHub showing the bootstrapper's own README (PR #316)
- The newcomer persona pre-check (PBI-1.30): `docs/NEWCOMER_PRECHECK.md` (the persona, its fixed instruction, the procedure, the stand-in values, the pass rule) and the harness test that writes the screen of the setup a newcomer meets (PR #315)
- Recorded in NEXT_SESSION the pre-check on v2.8.4, findings p2.8.4-a to -d (PR #317)
- Recorded in NEXT_SESSION that p2.8.4-c is fixed and p2.8.4-e found; the PBI-1.30 entry follows #318's wording (PR #320)

### Changed
- On Windows, the guide for a missing Node.js says to type `q` at the pause and copy the command it shows, then close the window, open Git Bash from the Start menu and run that command; the README says the same (p2.8.4-c) (PR #318)
- After the setup, the README and the script's closing lines say how to create a Claude Project and add the GitHub project to it, with links to Claude's help pages (p2.8.4-a, p2.8.4-d) (PR #319)
- On Windows, the guides for a missing git and a missing or old gh end the same way as the Node.js guide (p2.8.4-e) (PR #321)

## [2.8.4] — 2026-10-30

### Added
- Release prep for v2.8.3 (PR #297)
- Recorded in NEXT_SESSION that winget stays in the script's gh guide (r3b) (PR #298)
- Recorded in NEXT_SESSION and `STATUS.md` that v2.8.3 is released and verified; run 3 next on it (PR #299)
- Recorded run 3 on v2.8.3 as passed; PBI-1.17 done; run 5 next (PR #300)
- Backlog: PBI-1.29, the bootstrapper needs nothing from the template (PR #301)
- NEXT_SESSION: Adam rehearses run 5 first, on v2.8.3 (PR #302)
- Recorded the run 5 rehearsal findings r5r-a to r5r-g; PBI-1.29 widened to the bootstrapper's own README (PR #303)
- PBI-1.29 spec, confirmed by Adam, and the draft of the bootstrapper's own README; the template README's setup part marked for the build to copy and ordered for a newcomer; "Working from another computer" in the README a new project starts with; backlog PBI-1.31, the Claude parts of a project as an add-on (`[LATER]`) (PR #304)
- Backlog: PBI-1.30, a newcomer persona as a pre-check before human runs (PR #305)
- The bootstrapper gets its own README: the release build writes `.github/README.md` from `bootstrap/bootstrapper-README.md` with the template README's setup part copied in, so the steps exist in one place; `languages/README.md` no longer ships (PBI-1.29) (PR #306)
- Backlog: PBI-1.32, the product office's "For you" rule in `CLAUDE.md` for every bootstrapped project, and PBI-1.33, a regular check for new versions of the language packs' components (PR #307)
- Backlog: PBI-1.33, Adam's WHAT and the path for urgent updates (PR #308)
- The setup section of the README a new project starts with is headed "Finishing the setup", with nothing asking the reader to delete it; the setup removes `.github/README.md`; `e2e-check.sh` checks that it is gone (PBI-1.29) (PR #309)
- What ships no longer points to the template outside the record of origin: `docs/DEV_INFRASTRUCTURE.md` and `docs/ROUTINES.md` lose their template pointers, and the setup removes the other packs' sections from `docs/DEV_INFRASTRUCTURE.md` instead of linking them to the template (PBI-1.29) (PR #310)
- Recorded in NEXT_SESSION that the run 5 rehearsal findings r5r-a to r5r-g are addressed by PBI-1.29, with r5r-d's leftover in the project README kept for later (PR #311)

## [2.8.3] — 2026-10-29

### Added
- Release prep for v2.8.2 (PR #270)
- Recorded in NEXT_SESSION, `STATUS.md` and CHANGELOG that v2.8.2 is released and verified (PR #272)
- The C# base language pack, part 1 (PBI-1.23): `languages/csharp/`, a class library, a console app and an xUnit v3 test project on .NET 10, with `dotnet format`, a build with nullable reference types and every warning an error, and an 80% line coverage gate over every project under `src/`; its job in `packs.yml` and its rows in the layout table. The setup does not offer it yet (part 2) (PR #271)
- Backlog: PBI-1.23 part 1 merged, review note N8 kept for part 2 (PR #273)
- Backlog: PBI-1.23 blocked while part 2 waits on the end-to-end runs (PR #275)
- A check that `STATUS.md` and the shipped stub keep the headings the product owner's overview reads (`tools/check-status.sh`, run in the `build` job; NEXT_SESSION item 15) (PR #276)
- The README and the stub README that ships to projects have a section "Working without Claude": what works without Claude, what does not, and how a team of people works with the project (product office PO-62) (PR #277)
- Backlog: PBI-1.24, a setup option for whether a project includes Claude support (PR #278)
- Backlog: PBI-1.25, CI that costs less per change without loosening the testing requirement (PR #279)
- Backlog: PBI-1.26, exclude macOS for now while keeping its code working, and PBI-1.27, re-enable it (PR #281)
- Backlog: PBI-1.28, the setup checks that the computer meets the minimum versions of everything it needs to finish (PR #282)
- Backlog: PBI-1.27 brings macOS back together with PBI-1.28's minimum-version checks (PR #284)
- End-to-end run 3 moves from macOS to Windows (Git Bash) in NEXT_SESSION and `STATUS.md`; backlog: PBI-1.26 does not wait for the end-to-end runs (PR #285)
- Backlog: PBI-1.25 to NEXT, in the unattended batch; it does not wait for the end-to-end runs (PR #286)
- Recorded end-to-end runs 3 and 4 on v2.8.2 in NEXT_SESSION and `STATUS.md`: run 3 (python, Windows, Git Bash) stopped at finding r3f, the python project's `build` failing; run 4 (react-native, `--non-interactive`) passed (PR #287)
- End-to-end run 3, r3f: the chain test (`packs.yml`) builds each pack's project with the files the setup keeps in `languages/<pack>/`, as the setup does, and the python pack's `code-standards.md` now passes ruff's format check, which failed `build` in every python project set up with v2.8.2 (PR #288)
- Recorded in NEXT_SESSION that r3f is fixed on main (PR #289)
- End-to-end run 3, r3d: a no at "Proceed?" stops like every other stop: it saves the answers and shows the command to start again with `--again` (with `--resume`, the command to continue), so an Enter by accident no longer means typing every answer again (PR #291)
- End-to-end run 3, r3e: the note under the wait for the project's checks says on its own what the limit is ("The script waits at most 20 minutes for build to pass. ...") (PR #292)
- End-to-end run 4, r4a: on Windows the npm guide says why Git Bash must be opened again from the Start menu: a window opened from an existing one keeps the old list of folders where programs are found, so it would not find the new npm (PR #293)
- End-to-end run 3, r3a: README step 0 says every choice of the Git for Windows installer is kept as it is, the editor (Vim) included, Next on each screen and Install on the last one; the setup script never opens that editor (PR #294)
- End-to-end run 3, r3b: README step 0 and the script's gh guide (Windows without winget) name the option cli.github.com shows: Download MSI, not WinGet (PR #295)
- Recorded in NEXT_SESSION what was checked in the script for r3c (the Git Bash window that stopped responding at the git check); no cause found, left open (PR #296)

## [2.8.2] — 2026-10-28

### Added
- Release prep for v2.8.1 (PR #258)
- Recorded in NEXT_SESSION, `STATUS.md` and CHANGELOG that v2.8.1 is ready to tag, with the plan for the tablet and Mac runs (PR #259)
- Recorded in NEXT_SESSION and `STATUS.md` that v2.8.1 is released and verified (PR #260)
- Recorded end-to-end run 2 repeated on a Windows tablet with nothing installed, its result and findings r2f to r2l, in NEXT_SESSION and `STATUS.md` (PR #261)
- End-to-end run 2 repeated, r2h: README step 0 and the script's sign-in guides say that GitHub may first ask you to sign in, before the page for the code (PR #262)
- End-to-end run 2 repeated, r2i and r2j: on Linux and in WSL the npm guide says to choose Linux on nodejs.org and, after the install, to start the script again in a new window, where the new npm is found (PR #263)
- End-to-end run 2 repeated, r2f and r2g: README step 0 has a step for Linux on Windows (WSL): `wsl --install -d Ubuntu`, what to do when Ubuntu does not appear, the first start, the user name and password (PR #264)
- Recorded in NEXT_SESSION and `STATUS.md` that r2f to r2j are fixed, with the reviews' notes (PR #265)
- End-to-end run 2 repeated, r2k: the README says a physical keyboard is recommended, not required, and that Ctrl-Q wakes a window that stopped after text was selected in it (PR #266)
- End-to-end run 2 repeated, r2l: at a stop the script saves the answers next to itself and shows a short command, `cd <folder> && bash bootstrap-project.sh --again`, which works from a new window too (PR #267)
- Recorded in NEXT_SESSION and `STATUS.md` that r2k is done and r2l decided (PR #268)
- Backlog: PBI-1.23, the C# base language pack, built in two parts so it cannot delay acuteping (PR #269)

## [2.8.1] — 2026-10-28

### Added
- Release prep for v2.8.0 (PR #251)
- Recorded in NEXT_SESSION, `STATUS.md` and CHANGELOG that v2.8.0 is released and verified, with the Git Bash check of r1f (PR #253)
- Recorded end-to-end run 2 (Linux through WSL), its result and findings r2c to r2e, in NEXT_SESSION and `STATUS.md` (PR #254)
- End-to-end run 2, r2c: the README says to open https://github.com/login/device yourself when gh cannot open a browser, as in WSL (PR #256)
- End-to-end run 2, r2d: README step 1's folder example makes the folder first, so it works on every system (PR #257)
- End-to-end run 2, r2e: in WSL, an npm on a Windows drive (the Windows one, reached through WSL) counts as no npm, and a guide says how to install Node.js inside Linux (PR #255)

## [2.8.0] — 2026-10-27

### Added
- Release prep for v2.6.0; it was left out of the 2.7.0 section (PR #230)
- Release prep for v2.7.0 (PR #244)
- Recorded in NEXT_SESSION, `STATUS.md` and CHANGELOG that v2.7.0 is released and verified (PR #245)
- Run 2 of the end-to-end runs is on Linux, through WSL (PR #246)
- Recorded run 1 on v2.7.0, its result and findings r1f to r1i, in NEXT_SESSION and `STATUS.md` (PR #249)
- Run 1 is not repeated again; run 2 is interactive and checks the fixes for r1f to r1i (PR #250)
- End-to-end run 1, r1f: keys typed while the script works are dropped before the run offer, "Proceed?" and the guide pause, so a stray Enter no longer answers them; a Ctrl-C there leaves the terminal as it was (PR #247)
- End-to-end run 1, r1g to r1i: questions, the lines that explain them, commands and the log each have their own colour, with a four-line colour key; the stars of the wait are not dim and stand on a line of their own; a blank line separates questions from the log that follows (PR #248)
- End-to-end run 1, r1g: the lines that explain a question are bold magenta, not yellow, which is hard to read on a light background (Adam's choice) (PR #252)

## [2.7.0] — 2026-10-27

### Added
- PBI-1.22: the harness's stand-ins start with fewer processes (PR #224)
- PBI-1.22: the every-guide test runs with far fewer processes (PR #225)
- PBI-1.22: the OS matrix runs only when a PR touches what the tests read (PR #228)
- Recorded the product owner's answers on #224, #225 and #228 (PR #231)
- Recorded in NEXT_SESSION and `STATUS.md` that v2.6.0 is released and verified (PR #232)
- PBI-1.22: refreshed the measured test durations after #224 and #225 (PR #233)
- Fixed a flaky test: the failing fake awk reads its input before it fails (PR #234)
- Recorded the repeated end-to-end run 1 on v2.6.0, its result and findings, in NEXT_SESSION (PR #238)
- PBI-1.22 marked done with the measured result (PR #241)
- `bootstrap-project.sh --version` prints the version of the script and the commit it was built from (PR #240)
- End-to-end run 1, r1c: after a no at a guided check, the script offers the command again (PR #236)
- Added CHANGELOG entries for PRs #224, #225, #228, #231, #233, #234 and #241 (PR #242)
- End-to-end run 1, r1d: the instruction and the command to run are in two colours, the progress log is dim, and a colour key opens a run with colour (PR #237)
- Recorded the v2.7.0 handoff in NEXT_SESSION (PR #243)
- End-to-end run 1, r1b: every guide, stop message and README step that has the user run `gh auth login` or `gh auth refresh` says to answer Yes when gh asks "Authenticate Git with your GitHub credentials?" (PR #235)
- End-to-end run 1, r1e: `--without-deploy` carries a no to "Add the publishing files?" in the continue command; a resumed run past the pack step takes the choice from the setup's change, and the copy's check works in Git Bash on Windows (PR #239)

## [2.6.0] — 2026-10-27

### Added
- Tests: no `grep -q` at the end of a pipe under pipefail, which made tests flaky through SIGPIPE; a lint keeps it out (PR #208)
- Release prep for v2.5.0 (PR #212)
- Added PBI-1.21: the release tag created by merging the release prep, for the template and every bootstrapped project (PR #213)
- An empty `STATUS.md` stub ships with every bootstrapped project (PR #214)
- Added the template's own `STATUS.md` (PR #215)
- Recorded NEXT_SESSION item 15's status: `STATUS.md` as the contract the product office reads, and its follow-ups (PR #216)
- Recorded in NEXT_SESSION that v2.5.0 is released and verified (PR #217)
- Added CHANGELOG entries for PRs #208, #212-#214, #217 (PR #218)
- `STATUS.md`: a blocker that waits on the product owner starts with "Product Owner:", in the shipped stub and the template's own file (PR #219)
- Added PBI-1.22: make the template's CI faster without losing coverage (PR #220)
- CLAUDE.md: parallel sessions coordinate through the repo (claim PRs, listing open PRs, merging instead of rebasing) (PR #222)
- CLAUDE.md: the `STATUS.md` rule for both agents (PR #223)
- Parked two PBI-1.22 questions for the product owner in NEXT_SESSION and STATUS.md, and the lesson to batch doc-only changes (PR #226)
- PBI-1.22: the bootstrap test shards of each OS leg are split by measured test duration (`bootstrap/test-durations.txt`, made by `bootstrap/durations-from-logs.sh`); `bootstrapper-test` still fails unless every test ran exactly once (PR #227)
- Added CHANGELOG entries for PRs #220, #226 and #227 (PR #229)

## [2.5.0] — 2026-10-26

### Added
- Added PBI-1.18: shorten the Windows leg of `bootstrapper-test` (PR #177)
- Recorded in NEXT_SESSION that the release prep merged (#176), the PBI-1.18 state and what waits for Adam (PR #179)
- Staged the product office overview idea as NEXT_SESSION item 15 (PR #180)
- Recorded the decision to release v2.4.0 with the tag straight after the release prep (PR #181)
- Staged the multi-agent bootstrapped project idea as NEXT_SESSION item 16 (PR #182)
- Added PBI-1.19: make the setup command short enough to type (PR #183)
- PBI-1.18: the bootstrap script's tests run in 4 shards per OS leg; `bootstrapper-test` also fails when a shard is missing or a test ran twice or not at all (PR #178)
- Added CHANGELOG entries for PRs #177-#183 (PR #184)
- Recorded in NEXT_SESSION the verified v2.4.0 release, Adam's answer on #178 and the end-to-end run plan (PR #185)
- Marked PBI-1.18 done (PR #186)
- Added CHANGELOG entries for PRs #184-#186 (PR #187)
- Dated the 2.4.0 entry by its release, 2026-10-23 (PR #188)
- Recorded the decision that a release is dated by the day its tag and GitHub release are created (PR #189)
- Added CHANGELOG entries for PRs #187-#189 (PR #190)
- Staged Adam's unanswered question on saved setup answers as NEXT_SESSION item 17 (PR #191)
- CLAUDE.md: sessions delete their fired one-shot scheduled tasks (PR #192)
- CLAUDE.md: ground rule against loose ends (PR #193)
- Recorded the findings of end-to-end run 1 in NEXT_SESSION (PR #194)
- README step 0 says how to open Git Bash (run-1 finding 1) (PR #195)
- Added PBI-1.20: the user journey from an itch to a project (PR #196)
- Staged rolling back a bad release by re-tagging as NEXT_SESSION item 18 (PR #197)
- The bootstrap script says why the default answer to "Proceed?" is no (run-1 finding 5) (PR #198)
- The product owner question says where its default comes from (run-1 finding 4) (PR #199)
- `changelog.yml` posts no reminder on a PR that already changed CHANGELOG.md, such as a project's setup PR (run-1 finding 11) (PR #200)
- Added the bootstrapper's tagline to PBI-1.20 (PR #201)
- The bootstrap script sets its questions, the plan, its stops and the closing "What to do next" apart from its progress log: one blank line before each, and one restrained colour on the lines to act on when writing to a terminal (`NO_COLOR` and `TERM=dumb` turn it off) (run-1 finding 8) (PR #202)
- The bootstrap script prints the command to continue before its first change on GitHub, so a stop that runs no trap (Ctrl-C in Git Bash) still leaves it (run-1 finding 6) (PR #203)
- While it waits for `build`, the bootstrap script shows a `*` per second and a "Checking the build status" line with the time waited against the limit, gives the checks page link, and says that the minutes are a limit and what happens then (run-1 finding 9) (PR #204)
- A `--resume` run shows the six steps of the plan, with the steps done and the next one marked (run-1 finding 7) (PR #205)
- The closing text says to create a Claude Project for the project and chat inside it, and its last line says Clead is there to help when stuck; the READMEs match (run-1 finding 10) (PR #206)
- A `--resume` run that first misses the project keeps `--resume` in the command it shows once the project is found (PR #207)
- `e2e-check.sh` no longer stops with exit 141 when the copy has thousands of unsaved files (PR #209)
- The PBI-1.14 spec text in the backlog follows the run-1 fixes (PR #210)
- Recorded the status of every run-1 finding, the open review notes and what waits for v2.5.0 in NEXT_SESSION (PR #211)

## [2.4.0] — 2026-10-23

### Added
- Prepared the 2.3.0 changelog (PR #126)
- Closed NEXT_SESSION item 7 after the verified v2.3.0 release (PR #127)
- Marked PBI-1.16 Part 1 (protection of the bootstrapper's `main`) done in the backlog (PR #128)
- Recorded Adam's PBI-1.14 decision that `--resume` refuses a repo stamped by an older bootstrapper version, and his go for slices S1 and S3 (PR #129)
- PBI-1.14 S3: `packs.yml` creates the lockfile with `npm install --package-lock-only`, the command the bootstrap script will use (PR #130)
- PBI-1.14 S1: the pack layout table moved into `bootstrap/stubs/bootstrap-project.sh` (`layout-pack` subcommand); `tools/layout-pack.sh` is a wrapper; the script ships at the bootstrapper root, executable and LF (PR #131)
- Recorded PBI-1.14 S1 and S3 done in NEXT_SESSION, with the deferred review notes (PR #132)
- PBI-1.14 S2: `build.sh` stamps the version and commit into the script as well as `CHANGELOG.md`, in place, keeping the executable bit (PR #133)
- Added CHANGELOG entries for PRs #126-#133 (PR #134)
- Recorded PBI-1.14 S2 done in NEXT_SESSION (PR #135)
- PBI-1.14 S4: the bootstrap script's test harness (`bootstrap/test-bootstrap-project.sh`), the `BOOTSTRAP_GH` and `BOOTSTRAP_RUN` test hooks and the message helpers in `bootstrap-project.sh`; `bootstrapper-test` runs the harness (PR #136)
- Recorded PBI-1.14 S4 done in NEXT_SESSION and parked its review notes (PR #137)
- Recorded the temporary arrangement until 2026-10-05 13:00 UTC: Clead runs in a Claude Code cloud session and starts Crog as subagents; added NEXT_SESSION item 12 (PR #138)
- Corrected the evidence behind the 2026-10-01 decision on Crog sessions in `memory/decisions.md`; the decision stands (PR #139)
- Added Adam's token-use hypothesis and Clead's data to NEXT_SESSION item 12 (PR #140)
- Added CHANGELOG entries for PRs #136-#140 (PR #141)
- Staged the template's value and target user in NEXT_SESSION item 13 (PR #142)
- Recorded Adam's answer on PBI-1.14 in NEXT_SESSION item 13 (PR #143)
- Staged Adam's entry-point idea in NEXT_SESSION item 13 (PR #144)
- Reworded NEXT_SESSION item 13 question 3 to Adam's one-path model (PR #145)
- PBI-1.14 S6: the bootstrap script's inputs and their validation (PR #146)
- Session handoff in NEXT_SESSION: S6 done, item 5 audit, items 13 and 14 (PR #147)
- PBI-1.14 S7: guided checks on this computer before setup (PR #148)
- PBI-1.14 S8: guided GitHub checks before setup (PR #149)
- PBI-1.14 S9: the plan, then create the project and protect `main` (PR #150)
- Recorded PBI-1.14 S7 to S9 and their review notes in NEXT_SESSION (PR #151)
- PBI-1.14 S10: the copy on this computer, its line of work, the pack and the tidy-up (PR #152)
- PBI-1.14 S11: fill the placeholders from one fixed table (PR #153)
- PBI-1.14 S12: lockfile, licence and CHANGELOG (PR #154)
- PBI-1.14 S13: self-check, commit, push and setup PR (PR #155)
- PBI-1.14 S13a: check the licence in the preflight and Actions after protect (PR #156)
- Recorded PBI-1.14 S10 to S13a and their review notes in NEXT_SESSION (PR #157)
- PBI-1.14 S14: wait for build, require it, merge, finish and report (PR #158)
- PBI-1.14 S15: resume, failures and private repos (PR #159)
- Recorded PBI-1.14 S14 and S15 and their review notes in NEXT_SESSION (PR #160)
- PBI-1.14 S5: `bootstrapper-test` as one aggregate check over an OS matrix (PR #161)
- Recorded PBI-1.14 S5 and its review notes in NEXT_SESSION (PR #162)
- CI: run the bootstrapper workflow once per PR push and cancel superseded runs (PR #163)
- PBI-1.14 S16: `bootstrap/e2e-check.sh`, the read-only checker for the end-to-end runs (PR #164)
- Recorded S16 merged and the #163 and S16 review notes in NEXT_SESSION (PR #165)
- PBI-1.14 S17: docs and process (PR #166)
- Recorded the handover of the Clead role (app and cloud Claude Code) in NEXT_SESSION (PR #167)
- Recorded S17 merged (#166), the handover state, and S18 as next in NEXT_SESSION (PR #168)
- PBI-1.14 S18a: refuse a CRLF README or CHANGELOG before anything is written (PR #169)
- PBI-1.14 S18b: gh preflight, bare-word message, help and plan wording (PR #171)
- Recorded S18 merged (#169, #171), follow-ups and deferred items in NEXT_SESSION (PR #172)
- Handed the Clead role back to the Claude app in NEXT_SESSION (PR #173)
- PBI-1.14 S19: README steps for the bootstrap script (PR #174)
- Recorded S19 merged (#174), the deferred review notes and the unverified items in NEXT_SESSION (PR #175)

## [2.3.0] — 2026-10-02

### Added
- Prepared the 2.2.0 changelog: renamed the Unreleased section and listed PRs #73-#75 (PR #76)
- Removed the two Routine trigger IDs from `memory/decisions.md`; they stay in git history (PR #77)
- Aligned the branch-prefix docs with practice: `feat/`, `fix/`, `docs/` (PR #78)
- Recorded Adam's decisions on PBI-1.4 (stays LATER), PBI-2.2 (not approved as written) and PBI-4.2 (closed as done) (PR #79)
- Added PBI-1.11 (backlog visualiser) and PBI-1.12 (delegation level option for the bootstrapper) as ideas (PR #80)
- Added PBI-1.13: the next tool refresh, as a dated LATER item (PR #81)
- Resolved NEXT_SESSION item 8 after Adam's decisions; only his branch-cleanup click remains (PR #82)
- Added CHANGELOG entries for PRs #76-#82 (PR #83)
- Removed NEXT_SESSION item 8: the head-branch setting is on and the merged branches are deleted (PR #84)
- Added "Model and effort" to CLAUDE.md: Sonnet at High by default, Opus agents for reviews and architecture design, Clead recommends switches it cannot make itself (PR #85)
- Made `..wrap` the end-of-session check instead of a memory flush, with the graduation rule folded in; recorded in decisions.md (PR #86)
- Removed NEXT_SESSION item 7 as obsolete (PR #87)
- Added "Working unattended" to CLAUDE.md and graduated NEXT_SESSION item 9 (PR #88)
- Applied the reviewers' wording notes from #85, #86 and #88 to CLAUDE.md and the decisions row (PR #89)
- Added CHANGELOG entries for PRs #83-#89 (PR #90)
- Staged the four wording notes from the #89 review as NEXT_SESSION item 6 (PR #91)
- Recorded that the Clead and Crog Routines were deleted (PR #92)
- Recorded two decisions in `memory/decisions.md`: the licence, and Crog agents staying inside Clead's session (PR #93)
- Added the 2026-10-01 session to `memory/context.md` (PR #94)
- Added CHANGELOG entries for PRs #90-#94 (PR #95)
- Named this repo's README after the repo (PR #96)
- Proposed PBI-1.14, the turn-key bootstrap script (spec) (PR #97)
- Recorded Adam's approval of PBI-1.14 (PR #98)
- Added PBI-1.15 and PBI-1.16 to the backlog (PR #99)
- Gated the acuteping bootstrap on a verified toolchain (PR #100)
- Tested the chain: build the bootstrapper, make a project from it, run each pack (PBI-1.15) (PR #101)
- Fixed the Python code block spacing that ruff 0.16.9 reformats (PR #102)
- Said that cleaning up `languages/` is required, not optional (PR #103)
- Recorded how test-first applies in this template repo (PR #104)
- Added PBI-1.17: test-first applies by default at every level (PR #105)
- Specified PBI-1.17 (PR #106)
- PBI-1.17 PR 1: added the require-test-change check and its tests (PR #107)
- PBI-1.17 PR 2: the template build runs the test-first check; the stub `ci.yml` moved to stubs (PR #108)
- PBI-1.17 PR 3: each pack's CI runs the test-first check; a chain test proves it (PR #110)
- Made PBI-1.11 (backlog visualiser) a pointer: it is its own project, not a template feature (PR #111)
- Pointed the template and bootstrapper paths at the `factoincognito` org (PR #112)
- Added CHANGELOG entries for PRs #95-#112 (PR #113)
- Marked PBI-1.15 done in the backlog (PR #114)
- Staged the repo-move handoff in NEXT_SESSION (PR #115)
- PBI-1.17 PR 4: the test-first rule in the docs (PR #116)
- Staged the PBI-1.14 build plan in NEXT_SESSION (PR #117)
- Consolidated the parallel sessions' pending work in NEXT_SESSION (PR #118)
- Added Adam's to-do list to NEXT_SESSION (PR #119)
- Recorded in NEXT_SESSION how a Clead cloud session reaches GitHub (PR #120)
- Added the "what waits for what" table and the product-office handoff to NEXT_SESSION (PR #121)
- Recorded the move to the `factoincognito` org and the rule never to recreate the old names under `sugose` in `memory/decisions.md` (PR #122)
- Added the 2026-10-01 evening and 2026-10-02 entry to `memory/context.md` (PR #123)
- Added CHANGELOG entries for PRs #113-#123 (PR #124)
- Recorded the decision to release v2.3.0 before PBI-1.14, with no further tag until its slice S15 merges (PR #125)

## [2.2.0] — 2026-10-01

### Added
- Marked PBI-1.10 [NOW] until the first bootstrapper publish is verified, and corrected its known-limitation wording (PR #62)
- Refreshed both packs' tool versions (Node 24, TypeScript 6, Jest 30, Biome 2 with `--error-on-warnings`, Playwright 1.63, actions v7), and added a template-only workflow that tests every pack on GitHub's runners (PBI-1.6) (PR #63)
- Wrote `languages/README.md`: what a pack contains, the rules it must meet, how to add one (PBI-1.5) (PR #64)
- Added the Python pack (Python 3.14, Ruff, mypy strict, pytest with an 80% gate) and `docs/DEV_INFRASTRUCTURE.md` (PBI-1.1) (PR #65)
- Added the React Native / Expo pack (Expo SDK 57, jest-expo, React Native Testing Library, 80% gate; no device builds in CI) (PBI-1.3) (PR #66)
- Recorded research on Routines (API credentials, GitHub triggers, hourly limits) and reworded PBI-2.2 (PBI-2.3) (PR #67)
- Marked PBI-1.1, 1.3, 1.5 and 1.6 done in the backlog (PR #68)
- Added CHANGELOG entries for PRs #62-#67 (PR #69)
- Recorded the 2026-09-30 session: three decisions, a context section, and NEXT_SESSION items 8 and 9 plus a proposal for item 6 (PR #70)
- Stated only the observed tag-push refusal in NEXT_SESSION (PR #71)
- Added CHANGELOG entries for PRs #68-#71 (PR #72)
- Added the "Public repo" rule to CLAUDE.md: private information never goes into this public repository (PR #73)
- Stated in CLAUDE.md that Clead starts Crog as a separate agent without asking Adam first, and that this relaxes no review, CI or intent-approval rule (PR #74)
- Licensed the files the bootstrapper ships under the PolyForm Noncommercial License 1.0.0: the text and a Required Notice go in `licenses/` (not a root `LICENSE`), the stub README has a step for each project to choose its own licence, and a test pins the licence text (PR #75)

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
