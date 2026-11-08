L § 1 (C) This project is bound by the Rules and Processes of factoincognito, product-office.
Adopted: Adam, 2026-11-05, the sign-off of the product office's projects, recorded in the product office; signed off at this project's cutover

Pointer: the product office is the repository `factoincognito/product-office` (private). Its Rules are its `RULES.md` and `processes/`, its entry point its `CLAUDE.md`. This project's status is in `STATUS.md`.

L § 2 Files and citations
(1) `docs/BACKLOG.md` is the project's backlog, `docs/SPEC.md` its specification, `memory/decisions.md` its decisions file (longer records in `docs/decisions/`), `STATUS.md` its status, `docs/NEXT_SESSION.md` its staging file, `CHANGELOG.md` its change history, and `memory/` holds the memory files Clead maintains: `project.md` the purpose and goals, `context.md` the session context. `docs/NEWCOMER_PRECHECK.md` is a local process (L § 13). `docs/BACKLOG-DONE.md` holds the backlog's entries marked `DONE`, moved there in the PR that marks them, under the heading of their section; an entry ID is used once across both files, and a new ID is checked against both.
(2) What ships to the projects the template makes is what `bootstrap/manifest.txt` lists and what `bootstrap/stubs/` holds. Every other file is the template's own.
(3) No hurdles or retrospective log is kept. A retrospective is put together when it is wanted, from `memory/decisions.md` and `memory/context.md`.
(4) In this file and the project's other files, `§ n` and `P-n § m` refer to the Rules and Processes of the product office, and `L § n` to this file.
Adopted: (1) not recorded, carried over from `CLAUDE.md` "Where everything is", and `docs/BACKLOG-DONE.md` Adam, 2026-11-08 04:03, "Apyr on backlog done", product-office DECISIONS.md, wording by Clead under product-office `RULES.md` § 3 (4); (2) carried over from `bootstrap/manifest.txt` (PBI-1.10); (3) Adam, 2026-06-28, `memory/context.md` ("Adam's call") and `memory/decisions.md`; (4) by Clead at the cutover, as the `RULES.md` stub's L § 2 (2)

L § 3 Session start
(1) At session start, Clead also reads `memory/context.md`.
Adopted: not recorded; carried over from `CLAUDE.md` "Session startup" 1 and the header of `memory/context.md`

L § 4 What the template claims
(1) The template is complete only when everything it says it has or does is there and works. What is not built is marked as backlog.
Adopted: Adam, 2026-09-30, `memory/decisions.md`

L § 5 Test first by kind of change
(1) A workflow change gets a wiring assertion that fails against the old file. A real run on GitHub is the proof that the workflow works.
(2) Before a shipped file is removed, the build's tests (`bootstrap/test.sh`) are run, and any of them that pin the file are changed first.
(3) What the `build` check counts as code and as a test is listed in its test-change step in `.github/workflows/ci.yml`.
Adopted: (1) Clead, 2026-10-01, `memory/decisions.md` ("In this template repo, test-first applies by kind of change"), made the default at every level by Adam, 2026-10-01 (PBI-1.17), `memory/decisions.md`; (2) not recorded, carried over from `docs/NEXT_SESSION.md` item 5; (3) carried over from `CLAUDE.md` "Both agents: test first"

L § 6 The test harness
(1) A test that looks for a carriage return reads the file with `od -A n -c` and looks for `\r` (the helper `has_cr` in `bootstrap/test-bootstrap-project.sh`): on Windows, `grep` does not find it and `$( )` drops a final CR LF. The check itself is first tested on a known `a\r\n` file.
(2) A private folder of git wrappers comes first on the tests' `PATH`.
(3) Each test has its own work folder. A name that must be unique across subshells comes from `mktemp -d`, not from `$RANDOM` (bash 3.2's subshell reseed).
(4) A test that snapshots a tree switches git maintenance off in the repository it snapshots (`gc.auto=0`, `maintenance.auto=false`, `receive.autogc=false`).
Adopted: not recorded; carried over from `docs/NEXT_SESSION.md` "Test and CI lessons to keep" (S5, S16 and S18a, 2026-10-15)

L § 7 This repository's checks
(1) `ci.yml` and `packs.yml` run on pull requests to `main` and on pushes to `main`, not on pushes to other branches, where they would run twice for every push to a pull request; `tools/test-ci-triggers.sh` checks it.
(2) `main` requires two checks, `build` and `bootstrapper-test`. The `pack-<name>` jobs of `packs.yml`, which lay each language pack out in a made project and run its checks, ship nothing and are not required checks.
(3) The line coverage of this repository's own scripts is gated in `bootstrapper-test`, not in `build`: the suites that measure it run in the Bootstrapper workflow, and when they run, `bootstrapper-test` fails below 80% of the counted lines.
Overrides P-11 §§ 2 (1) and 3 (1) ((1) and (2)) and P-11 § 2 (2) ((3)).
Adopted: (1) Adam, 2026-10-29, on Clead's recommendation, `docs/BACKLOG.md` PBI-1.25 part 2; (2) decider not recorded, 2026-09-30, `memory/decisions.md` ("Language packs are tested on GitHub's runners…"); (3) wording by Clead under § 3 (4), carrying out Adam, 2026-11-06 21:03, approving the PBI-1.41 spec in `docs/BACKLOG.md` (the gate in `bootstrapper-test`), and 2026-11-07 07:41, its amendment; it replaces the dated condition of 2026-11-06 16:40, recorded in the product office, whose gates merged in #379, #389 and #397, the coverage gate in `bootstrapper-test` as the spec has it

L § 8 The Rules edition
(1) The copy of the Rules that § 21 (5) names is `bootstrap/stubs/rules/`, the edition. A new edition replaces it whole.
(2) A PR that changes `bootstrap/stubs/rules/` changes nothing else. Its branch is `chore/rules-edition-<id>` and its title `chore(rules): take Rules edition <id>`; its branch, title, description and squash commit message carry only the edition id and what changed, in general words. The `build` check (`check-rules-edition.sh --template`) fails such a PR when it changes another file too, or when the folder does not match its `EDITION`.
(3) Such a PR merges on a green `build`, without a review. Overrides § 28 (1)(b) for these PRs only.
Adopted: Adam, 2026-11-05, intent approval of the design of the edition, with its decisions as recommended ((3): decision 5), recorded in the product office

L § 9 The bootstrapper
(1) Projects are made from the bootstrapper, `factoincognito/ai-project-bootstrap`, which the release pipeline (`bootstrapper.yml`) builds from this repository at each `v*` tag. A project is bootstrapped, never forked: it records the template version and commit it came from in its `CHANGELOG.md`, and gets neither this repository's history nor the template's own files (L § 2 (2)). The term is "bootstrap", not "fork".
(2) The bootstrapper has no test harness of its own and is changed only through this repository.
(3) The setup script merges the setup PR it opens in a new project on a green `build`, without a review. The merge is the script's act, run by whoever runs the setup, not a session's.
(4) No repository named `ai-project-template-v2` or `ai-project-bootstrap` is created under `sugose`: it would remove GitHub's redirect from the old path.
Adopted: (1) Adam, 2026-09-30, `memory/decisions.md`; (2) Adam, 2026-10-01 (PBI-1.17, intent approved on #106), `memory/decisions.md`; (3) Adam, 2026-10-01 (PBI-1.14), `memory/decisions.md`; (4) recorded 2026-10-01, decider not recorded, `memory/decisions.md`

L § 10 Licence
(1) The repository stays public and has no licence of its own. The files the bootstrapper ships are licensed under PolyForm Noncommercial 1.0.0, with the licensor its NOTICE names; the licence text and NOTICE are kept in `bootstrap/stubs/licenses/`, never as a root `LICENSE`. Each project adds its own `LICENSE`. A test pins the licence text.
Adopted: Adam, 2026-10-01, `memory/decisions.md`

L § 11 Releases
(1) The release prep PR, which puts the version heading over "Unreleased" in `CHANGELOG.md`, is the last merge before the tag; nothing merges in between.
(2) A release's date in `CHANGELOG.md` is the date its tag and GitHub release are created. The release prep PR writes the heading; if the tag comes on a later day, a prose PR corrects the date.
Adopted: (1) Adam, 2026-10-17 and 2026-10-18, `memory/decisions.md` 2026-10-18; (2) Adam, 2026-10-23, `memory/decisions.md`

L § 12 End-to-end runs
(1) acuteping is created with the setup script only after the end-to-end runs on throwaway repositories (`docs/NEXT_SESSION.md`, "Adam's to-do" 2) have passed.
(2) After each run, `bootstrap/e2e-check.sh OWNER/NAME DIR` is run on the made project and Clead reads its output. The throwaway repository is deleted only after that.
(3) Any point in a run where the person running it has to ask Claude for help is a failure of the README or the setup script. It is recorded with the date and the step, and addressed before the release.
(4) The template's own sessions record each run, its findings and their fixes in this repository (`docs/NEXT_SESSION.md`, "Adam's to-do" 2); the product office reads them from here.
Adopted: (1) Adam, 2026-10-01, `memory/decisions.md`, and 2026-10-26, recorded in the product office; (2) not recorded, carried over from `docs/NEXT_SESSION.md` "Adam's to-do" 2; (3) Adam, 2026-10-26, `docs/NEXT_SESSION.md` "Adam's to-do" 2; (4) not recorded, carried over from the product office's backlog, 2026-10-27

L § 13 Newcomer pre-check
(1) Before each human end-to-end run, Clead runs the newcomer pre-check on the commit to be released, in accordance with the local process `docs/NEWCOMER_PRECHECK.md`. It does not replace the human run.
Adopted: Adam, 2026-10-29, on Clead's recommendation, `docs/BACKLOG.md` PBI-1.30; the persona Adam's, confirmed 2026-10-29, `docs/NEWCOMER_PRECHECK.md`
