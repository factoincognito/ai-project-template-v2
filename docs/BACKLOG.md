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

- **[SUPERSEDED] PBI-1.4** (2026-10-01: superseded for new projects by PBI-1.14, the turn-key bootstrap script, approved by Adam; if the migration branch is still wanted it becomes its own IDEA. Earlier note: Adam, 2026-10-01, keep LATER; the bootstrapper plus
  `tools/layout-pack.sh` cover most of it, and a small "lay out pack X"
  step in the bootstrapper could replace the wizard) — Write the v2 bootstrap wizard (`BOOTSTRAP.md`)
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

- **[SUPERSEDED] PBI-1.8** (2026-10-01: folded into PBI-1.14, which has the licence choice) — Licence choice at project setup: the template
  offers a set of licences (PolyForm Noncommercial among them) and the
  project picks one at start. Depends on the wizard (PBI-1.4), unless
  the licence texts are first added as files under `licenses/`.

- **[DONE] PBI-1.9** (2026-09-30) — Fix the README setup steps, which still say to
  "Create a Cowork project" (README.md lines 19-27 and 48-53, plus the
  Team table). Cowork is now part of Claude itself. Keep what still
  holds: one project per repository, and the repo files are Clead's
  memory. Docs only.

- **[NOW] PBI-1.10** (pipeline built in PR #60; done once the v2.1.0
  publish passes the "Done when" checks below. Adam, 2026-10-01: acuteping is not created until the whole toolchain is verifiably working, meaning PBI-1.15 is done and PBI-1.14 is built with Adam's end-to-end runs passed; see PBI-1.14 "Done when") — Build pipeline that
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

- **[NEXT] PBI-1.14** (proposed 2026-10-01 by Clead from Adam's request; spec reviewed by Crog and intent approved by Adam in chat, 2026-10-01, with every open decision answered as recommended; recorded on PR #97; supersedes PBI-1.4 for new projects and absorbs PBI-1.8; not yet built) — Turn-key bootstrap script.

  **Why.**
  Adam: "the bootstrap script should be the only thing you need to run in order for the bootstrapped project to be created. Turn-key." Today a new project takes five manual README steps after "Use this template": copy a pack, turn on protection, fill placeholders, choose a licence and delete the section. Each one can go wrong without anyone noticing.

  **Goal and non-goals.**
  **Goal.** Run one script and get a GitHub repo that is created from `sugose/ai-project-bootstrap`, laid out with one language pack, has its placeholders filled and its own licence, has protected `main` with a green `build`, and has a clean local clone. The setup itself arrives through a PR like every other change.
  **Non-goals.** It does not write the project's content: goals, SPEC sections and the first PBI are for Clead in the first session. It does not migrate from an existing repo (the migration part of PBI-1.4). It does not set up the Claude app or project, Cloudflare deploy secrets, or a delegation level (PBI-1.12). It never deletes a repo.

  **Obtaining and starting it.**
  The script is `bootstrap-project.sh` at the root of the public bootstrapper repo. It is fetched with `gh api`, which refuses to run until `gh` is installed and logged in (read from the gh source, `pkg/cmd/api/api.go`: no auth-check exemption; not run), so installing `gh`, logging in and, on Windows, installing Git for Windows (which provides Git Bash and `git`) are README step 0, done by hand before the script exists. The command is the same in Git Bash, macOS and Linux:
  ```
  gh api repos/sugose/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh && bash bootstrap-project.sh
  ```
  - Only the latest release can be bootstrapped: `gh repo create --template` always copies the bootstrapper's default branch, so the script refuses to run unless it is the current published version (see Preflight). There is no version pinning.
  - There is no leading `/` on the API path. In Git Bash, MSYS rewrites `/repos/...` into a Windows path (cli/cli#6415).
  - `curl … | bash` is not supported, because the prompts read stdin.

  **Who this is for.** The target user may be a product person with no knowledge of git, GitHub or a terminal (Adam, 2026-10-01: ease of use is imperative; "a true WHAT person without HOW skills"). Every message, prompt and guide in the script and the README is written for that reader; see "Ease-of-use requirements".

  **Preflight (guided).** Before the repo exists, nothing is created until every preflight check passes. Adam's rule (2026-10-01): when something is needed that the script cannot do itself, the script guides the user through it step by step; what cannot be in the script at all is documented in the README. So a failed check does not just exit. For each one the script prints numbered steps for the user's OS (what to do, the link to open, what to expect), waits for "press Enter when done", re-runs the check, and repeats until it passes or the user quits. On quit it prints the exact command to start again. In `--non-interactive` mode it never waits: it prints the same steps and exits 3. Where the script can do the action itself (an install command or `gh auth refresh -s workflow`), it prints the command and runs it only after the user answers yes; `--yes` does not approve installs or logins. The guides live in the script, and each one names how the script verifies it.
  - Tools (guide per OS, with the install command offered where one exists; whether `winget` is present on a given Windows is UNVERIFIED): `bash` 3.2 or later, `git`, and `gh`. For node, web and react-native it also needs `npm` (see the lockfile step). The script checks for features, not version numbers: `gh repo create --help` must list `--template`.
  - Git identity: the script asks for the user's name and email in the preflight (defaults from the global git config when set; flags `--git-name` and `--git-email` in non-interactive mode), writes them with `git config` (no `--global`) right after the clone in step 4, and checks them before the commit in step 13.
  - `gh api user` must succeed. The script reads the `X-OAuth-Scopes` header from `gh api -i user` and needs `repo` (or `public_repo` for a public repo). It also needs `workflow`, because the setup commit changes `.github/workflows/ci.yml` (the OAuth scopes doc).
    - Login itself is README step 0, so the script cannot count on the scopes an interactive login adds; the `workflow` guide below covers the scope.
    - If a scope is missing, the script offers to run `gh auth refresh -h github.com -s workflow` and walks through the browser step (open the page, enter the one-time code, approve), then re-checks. Whether gh's own login prompts work in Git Bash's default terminal is UNVERIFIED.
    - A fine-grained token (`GH_TOKEN=github_pat_…`) sends no scopes header. The script then warns which permissions it needs (Administration, Contents, Workflows and Pull requests: write; Repository creation) and carries on.
  - The template's published version, read from `CHANGELOG.md` on the bootstrapper's `main` via the contents API, must equal the version stamped into the script. Otherwise the script says to download the current one.
  - `OWNER/NAME` must not exist yet (see re-runs), and the target directory must be absent or empty (except with `--resume`, which may reuse the existing clone).

  **Inputs.**
  Each input comes from a flag, or from a prompt read with plain `read` in bash. The script never relies on gh's own prompts, which misbehave in mintty, Git Bash's default terminal (cli/cli discussion #7893). It sets `GH_PROMPT_DISABLED=1` for every gh call, except the one guided login or scope-refresh command, which runs with it unset because that command needs gh's own prompt (whether it works in mintty is UNVERIFIED until the Git Bash e2e run).

  | Input | Flag | Default |
  |---|---|---|
  | Repo name | `--name` | none; must match `^[A-Za-z0-9][A-Za-z0-9._-]*$` |
  | Owner (user or org) | `--owner` | the `gh api user` login |
  | Display name | `--project-name` | repo name |
  | One-line description | `--description` | none; required (one line, not empty), so no placeholder is left |
  | Product owner name | `--po-name` | gh profile name, else the login |
  | Language pack | `--pack node\|web\|python\|react-native` | none |
  | Web deploy files laid out | `--with-deploy` (web only) | off |
  | Visibility | `--public` / `--private` | public |
  | Project licence | `--license none\|mit\|apache-2.0\|gpl-3.0\|bsd-3-clause\|polyform-noncommercial-1.0.0\|<any GitHub licence key>` | none offered as a default |
  | Copyright holder | `--copyright-holder` | PO name |
  | Target dir | `--dir` | `./<name>` |
  | CI wait | `--ci-timeout <min>` | 20 |

  - `--non-interactive` never reads stdin. Any missing required input (name, description, pack or licence) exits 2, listing every input that is missing.
  - `--yes` skips the final "Proceed?" confirmation.
  - `--dry-run` runs the preflight and prints the plan.
  - `--resume` continues an existing repo (see re-runs).
  - Name values may not contain control characters, `"`, `\`, `<`, `>`, `&` or backtick, because they go into JSON and HTML. The description must be one line. A `|` in the PO name or display name is rejected (it breaks the README table). A `.` in the repo name becomes `-` in the `[project-name]`/`[project-slug]` values, which must be valid npm and Expo slugs.

  **Steps, in order.**
  1. **Preflight and confirmation** (above). It prints the full plan.
  2. **Create** with `gh repo create OWNER/NAME --template sugose/ai-project-bootstrap --public|--private --description "…"`. GitHub makes the repo's first commit, a single commit of the template content (the "Creating a repository from a template" doc). Template content can land after creation, so the script then polls `repos/OWNER/NAME/branches/main` and the contents API for `CHANGELOG.md` for up to 60 s, retrying on 404, before touching protection.
  3. **Protect `main` straight away** with `PUT repos/OWNER/NAME/branches/main/protection`, body `required_status_checks:null, enforce_admins:true, required_pull_request_reviews:{required_approving_review_count:0}, restrictions:null, allow_force_pushes:false, allow_deletions:false`.
     - A 403 is not read as "private repo on Free" by status code alone: a fine-grained token without Administration write also gets 403. The script classifies by the response message; if it cannot, it prints the raw message with both explanations (plan or token permission) and stops. The exact message text is UNVERIFIED.
     - It also sets `gh repo edit --delete-branch-on-merge --enable-squash-merge`.
  4. **Clone** with `gh repo clone OWNER/NAME DIR`, then check that `origin/main` holds `CHANGELOG.md` and that its stamp equals the script's version. Whether `git clone` and `git push` authenticate on a private repo without `gh auth setup-git` is UNVERIFIED, so the credential-helper fallback (a post-create guide at step 13) also applies to the clone.
  5. **Branch** `bootstrap-setup`.
  6. **Lay out the pack** using the table and checks from `tools/layout-pack.sh`, moved into the script as the single source (see "Shipping").
     - Overlay mode: `ci.yml` replaces the stub. The pack's `gitignore` lines are appended to `.gitignore` when they are missing. Any other target that already exists is an error.
     - `--with-deploy` also lays out `deploy.yml` to `.github/workflows/deploy.yml` and `wrangler.jsonc` to the root.
  7. **Lockfile (npm packs).** `npm install --package-lock-only --no-audit --no-fund` creates `package-lock.json` without `node_modules`. Without it, the pack's `npm ci` fails and the setup PR can never go green. `packs.yml` is changed to use this same command, so the path the script takes is the path CI tests. A lockfile made on Windows or macOS and run with `npm ci` on Linux (platform packages of Biome, Rollup) is UNVERIFIED and goes into the e2e list.
  8. **Fill placeholders** from a fixed table of (file, exact text, value). Replacement is literal: awk `index()`/`substr()` with the values passed via `ENVIRON`. It is not `sed`, which treats the values as regex and needs `sed -i` (which differs on macOS).
     - `[PROJECT NAME]` becomes the display name in `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `docs/SPEC.md`, `docs/BACKLOG.md`, `docs/NEXT_SESSION.md`, `memory/project.md` and react-native `app.json`.
     - `[PO NAME]` becomes the PO name in `README.md` and `docs/BACKLOG.md`.
     - `[OWNER/REPO]` becomes the repo's `OWNER/NAME` in `memory/project.md`.
     - `[DATE]` becomes today's date (ISO) in `docs/SPEC.md` and `docs/NEXT_SESSION.md` only. In `memory/roles.md` and `docs/CROG_ONBOARDING.md`, `[DATE]` is a format token and stays.
     - The README line `[One or two sentences: …]` and the two-line description in `memory/project.md` become the description. The second is read as a whole file, not line by line. `[project-description]` becomes the description in `package.json` (node, web, react-native).
     - `[project-name]` becomes an npm-safe slug (the lowercased repo name, `.` replaced by `-`; Cloudflare Worker name limits such as `_` and length are not verified) in `package.json` and web `wrangler.jsonc`, and the display name in web `index.html` `<title>`. `[project-slug]` becomes the slug in `app.json`.
     - **Left for the first Clead session** (the script lists them at the end): `[PHASE NAME]`, `[Goal]`, the SPEC section prompts, the rest of `memory/project.md` and `memory/context.md`.
     - **Never touched:** the BACKLOG markers, `[Unreleased]`, the ADR's `[If approved]` and `licenses/`.
  9. **Tidy up.**
     - Delete the README section from `## After bootstrapping` up to the next `## ` heading.
     - Delete `languages/README.md` (it explains how to add a pack to the template and points at the script) and the other packs. Keep the chosen pack's files that were not laid out (`code-standards.md`, plus the web deploy files when `--with-deploy` is off). The `docs/DEV_INFRASTRUCTURE.md` links to the other packs' `code-standards.md` are rewritten to the template's URL, as that doc's own fallback already does.
     - Delete `bootstrap-project.sh` itself.
     - Keep `licenses/`.
  10. **Licence.**
      - A GitHub key: `gh api licenses/<key> --jq .body` goes to `LICENSE`, with `[year]` and `[fullname]` filled (choosealicense.com placeholders).
      - `polyform-noncommercial-1.0.0`: the text is copied from `licenses/` to `LICENSE`, and a root `NOTICE` gets `Required Notice: Copyright <holder>`.
      - `none`: no file, with a warning if the repo is public.
  11. **CHANGELOG.** Append the pack, the licence and "set up by bootstrap-project.sh" under "Project created".
  12. **Self-check before commit.**
      - No fill-table text remains, checked per (file, text) pair: kept files document the same text (`languages/react-native/code-standards.md` has `[project-slug]`, and the kept web `wrangler.jsonc` still has `[project-name]` without `--with-deploy`).
      - `git status` shows only the expected paths.
      - The staged diff has no `gh[pousr]_…` or `github_pat_` strings.
      - Every file is LF.
  13. **Commit and push.** Commit "Set up <name>", then push the branch. Git uses gh as a credential helper for these commands only, via `-c`, with no global config change. The exact helper string is UNVERIFIED. Fallback guide: `gh auth setup-git`, which changes the user's global git config, so it runs only after an explicit yes and with a sentence saying so.
  14. **PR.** `gh pr create --base main --head bootstrap-setup --title … --body-file …`. Giving a title and body makes it non-interactive.
  15. **Wait for `build`.** Poll `gh pr checks <n> --json` until the check named `build` appears and finishes, up to `--ci-timeout`; only `build` is watched, not the review workflow. A push and a pull_request run both report `build`; the script accepts the pull_request run (the `event` field of the `--json` output is UNVERIFIED) or, failing that, any `build` run on the head commit. If it fails, stop and leave the PR open with its link.
  16. **Add the required check.** PUT protection again with the full body (a PUT replaces the whole object): the step 3 body with `required_status_checks:{strict:false, contexts:["build"]}`. The REST docs mark `contexts` as required; whether `checks:[{context:"build"}]` alone is accepted is UNVERIFIED and is settled by the GET read-back, which is compared field by field. Every pack's `ci.yml` has one job, `build`, and a test enforces this. Doing it after `build` has run avoids the rule that "a required status check must have completed successfully … during the past seven days" (the troubleshooting doc).
  17. **Merge** with `gh pr merge <n> --squash --delete-branch --match-head-commit <sha>`. This runs under protection, so a successful merge also shows the gate accepted it.
  18. **Finish.** Idempotent: `gh pr merge --delete-branch` may already have switched to `main` and deleted the local branch, so each action is guarded. Then `git pull`, check `git status` is clean and HEAD equals the merge commit.
  19. **Report.** The script prints:
      - repo URL, local path, PR URL, pack and licence;
      - protection as read back;
      - the placeholders left for Clead;
      - the next step: open the Claude app, give it the new repo, and start a chat. `CLAUDE.md` does the rest.

  **The order problem.**
  `CLAUDE.md` says every change goes through a PR. The protection order itself needs no exception:
  - GitHub's template generation makes `main`'s only commit.
  - `main` is protected at step 3, before anything else is pushed.
  - The setup arrives as a PR that must pass `build`.
  - The cost is a few minutes of CI wait, and it proves the project is "green on day one".

  It does need one exception, though, which is Decision 2: the script itself merges the setup PR, which departs from rule 3 (review by the role that did not write the change) and rule 4 (Crog merges), with CI as the only gate. The setup PR is not the released template's own tested output: the lockfile is resolved at run time (transitive dependencies float), it is made with a different command than `packs.yml` used before this change, and the PR carries values the user typed and a licence fetched from the API. Also, `review.yml` fires on the setup PR because the starters add `src/**`, and `changelog.yml` comments after the merge although the PR already updated the CHANGELOG. Both comments are noise in a project with no session yet; that they are harmless is not verified and is part of the e2e check.

  The alternative is to push the setup straight to `main` before protection and record it as the one documented exception. That is faster, but it breaks the rule and leaves `build` unproven until the first real PR. **Open decision 1.**

  **Refusals, warnings, re-runs, failures.**
  - **Private repo, no protection possible.** Protection is free only on public repos; private repos need Pro, Team or Enterprise (branch protection REST doc). Rulesets have the same availability (About rulesets). Reading `/user` `plan` needs `read:user`, which gh's minimum scopes lack, so the script cannot check the plan before creating. Instead it warns before creating, and if step 3 returns 403 it stops at once (a post-create guide: it does not retry in the same run). At that point the repo holds only the template commit. The script prints plain-language steps for three options and the exact `--resume` command:
    - upgrade the plan, then run with `--resume`;
    - `gh repo edit --visibility public --accept-visibility-change-consequences`, then `--resume`; this changes the repo's visibility, so it runs only after its own explicit yes, which `--yes` does not cover;
    - `--resume --allow-unprotected`, which merges unprotected and adds a decision row to the project's `memory/decisions.md` saying `main` is unprotected and why. **Open decision 5.**
  - **Existing repo.** Refused unless `--resume` is given. With `--resume`, the script works out where to continue from GitHub and the clone, not from any state file:
    - a repo not stamped by this bootstrapper is refused;
    - the template commit only: continue from step 3;
    - an open `bootstrap-setup` PR: continue from step 15;
    - a local `bootstrap-setup` commit that was never pushed (local branch ahead of origin, no remote branch): continue from step 13;
    - a `bootstrap-setup` branch pushed with no PR: continue from step 14;
    - a local clone with uncommitted setup edits: refused, with a message to commit or discard them (the script never discards work);
    - already set up (no setup section, no script): only re-check protection and report.

    Because of this, `--resume` also completes a repo made with the "Use this template" button.
  - **Failure midway.** An `ERR` trap prints what exists (repo, branch, PR, local dir) and the exact `--resume` command. A local dir the script created is removed if it fails before the clone completes.
    - The script never deletes a repo. That needs the `delete_repo` scope; the script prints `gh auth refresh -s delete_repo && gh repo delete OWNER/NAME --yes` as a hint only.
  - **No secrets.** The script never prints, stores or writes tokens into files, remotes or git config. Step 12 blocks a commit that contains one.
  - **Portability.**
    - bash 3.2: no associative arrays, `mapfile` or `${x,,}`. macOS `/bin/bash` is 3.2 (UNVERIFIED here, but tested on the macOS runner).
    - `\r` is stripped from all captured output.
    - It uses `gh --jq` instead of `jq`, and no `sed -i`.
    - API paths have no leading `/`.

  **Shipping, and what changes in the build.**
  - **Source.** `bootstrap/stubs/bootstrap-project.sh`. Stubs mirror the output layout, so it ships at the bootstrapper root. It is LF (`.gitattributes`) and executable (`git update-index --chmod=+x`, with a test: `.gitattributes` cannot set the mode). It must pass the existing forbidden-string checks (no PBI ids or PR refs), so its header links the spec by URL.
  - **`build.sh`.** Stamps `{{TEMPLATE_VERSION}}` and `{{TEMPLATE_COMMIT}}` in the script as well as `CHANGELOG.md`: today it stamps only the CHANGELOG, so the stamping becomes a loop over both stubs, with `test.sh` cases for the new stub (missing placeholder, stamped output). The existing "placeholder left" check catches a missed stamp, so the script's own version check must not contain a literal `{{TEMPLATE_…}}` string, which the stamp would rewrite. The ban on a `bootstrap/` folder and the forbidden strings stay.
  - **`manifest.txt`.** No change; `languages` still ships.
  - **Layout table: one source.** The table and its checks move from `tools/layout-pack.sh` into the script, which gets a `layout-pack <pack> <dir>` subcommand that keeps the strict "target must be empty" error (asserted by `tools/test-layout-pack.sh`). `tools/layout-pack.sh` becomes a thin wrapper that passes `PACKS_DIR`, because the script sits in `bootstrap/stubs/` in the template but at the root in the bootstrapper. `packs.yml` and its drift test keep working.
  - **In projects.** The script is in GitHub's template commit (step 2) and is deleted by the setup PR, so it leaves no clutter after setup. The alternative, publishing it as a release asset on the bootstrapper, would keep it out of project history entirely, but `publish.sh` would have to create releases. **Open decision 3.**

  **Testing.**
  - **Unit tests.** A new file, `bootstrap/test-bootstrap-project.sh`, in the `bootstrap/test.sh` style. It runs on ubuntu, macOS (invoking `/bin/bash`) and Windows (`shell: bash` is Git for Windows' bash, workflow-syntax doc). `docs/DEV_INFRASTRUCTURE.md` makes `bootstrapper-test` a required check, and a matrix renames its checks (`bootstrapper-test (ubuntu-latest)`, …), which would leave the required name never reporting and block every PR. So the matrix runs in a separate job and `bootstrapper-test` stays a single job named so, which `needs:` the matrix and uses `if: always()`, failing unless every matrix job's result is `success`. Without that, a failed matrix job would skip the aggregate job, and GitHub reports a skipped job as success, which would make the required check green on failing tests (documented in the troubleshooting doc; the dependency-failure case is not tested here). `bootstrap/test.sh` stays in the ubuntu leg. `publish` already `needs: bootstrapper-test`, so a macOS or Windows flake would also block a release; that is accepted.
    - `gh` is a stub, selected with `BOOTSTRAP_GH`. It logs every call and emulates `repo create --template` (a local bare repo seeded from a real `build.sh` output), `repo clone`, `api` (user, scopes header, licences, protection PUT/GET), `pr create/checks/merge` and `repo edit`. `git` is real, against local bare repos, as in the `publish.sh` tests.
    - **Cases:**
      - each guided check: the steps print, the re-check loop passes after the simulated fix, and quitting prints the resume command; the user answers No to an offered command and nothing runs; a stub `BOOTSTRAP_RUN` replaces every install and login command so CI never installs anything; `--non-interactive` prints the steps and exits 3 without waiting; `--yes` does not run an install or login;
      - the 404 race (main not there yet) retries, and a 403 is classified by message;
      - each preflight failure creates nothing;
      - every pack's final tree is exactly what is expected;
      - no fill-table text is left;
      - the README section is gone and `languages/` is pruned;
      - each licence variant;
      - the exact protection bodies, and their order relative to the merge;
      - non-interactive mode works with `</dev/null`, and missing inputs give exit 2;
      - a resume from each phase;
      - a CI failure leaves the PR open;
      - a 403 on protection stops before any push;
      - the fake token never appears in output or files;
      - the real build ships the script stamped, LF and executable.
  - **End to end.** Agents cannot do this run: repo deletion returns 403, and this cloud session's proxy refuses non-repo-scoped GitHub API calls ("sessions are bound to their configured repositories"). **Adam runs it** after the release.
    - Create throwaway public repos named `bootstrap-e2e-<pack>-<date>`: all four packs, at least one interactive in Git Bash on Windows and one `--non-interactive`. Ctrl-C one run during the CI wait, then `--resume` it. At least one run walks a real guided path: the `workflow` scope refresh in Git Bash on Windows. One run is made by someone who follows only the README, with no help (see Done when).
    - Delete them afterwards with `gh repo delete` (after `gh auth refresh -s delete_repo`) or in Settings.
    - A template-only `bootstrap/e2e-check.sh OWNER/NAME DIR` checks a finished run against "Done when" and prints the delete command.
    - Automating this in CI later needs a sandbox owner and a token with Administration write. **Open decision 8.**

  **What changes in the existing manual README steps.**
  - **Stub `README.md`.**
    - The five steps and the table become a three-line section: "If you see this, setup has not run: `<one command> --resume --owner … --name …`".
    - "Branch protection" drops "(step 2 above)" and points to `docs/DEV_INFRASTRUCTURE.md`.
    - "Use this template" is no longer the documented path, but it still works via `--resume`.
  - **Template `README.md`.** "Creating a project from the template" becomes step 0 (install `gh`, log in, and on Windows install Git for Windows), the one command, and the list of what the script guides and what only the README covers. The stale "does not exist until…" text goes.
  - **`languages/README.md`.** "Every file has a place" points to the script's layout table, not the README tables.
  - **`docs/DEV_INFRASTRUCTURE.md`.** "Turning it on in a new project" says the script does this, and keeps the manual steps as the fallback.
  - **Backlog.**
    - PBI-1.4 is **superseded** for new projects. If Adam still wants the migration branch, it becomes its own IDEA.
    - PBI-1.8 (licence choice) is folded into this PBI.
    - PBI-1.12 stays a possible future script option.

  **Rules for commands the script offers to run.**
  - Each is a fixed string in the script, never built from user input; the full command is printed before the question, and the default answer is No.
  - The answer is read from the terminal, not from piped stdin.
  - The script never runs `sudo`: on Linux it prints the package-manager line for the user to run.
  - It uses only the OS package manager (`winget`, `brew`), never a vendor `curl | sh` installer.
  - No token is echoed. The script itself is fetched from the bootstrapper's `main` with no integrity check: the version check only proves it is the latest release, not that its content is genuine.

  **Ease-of-use requirements.**
  - Plain language, no jargon without a one-line explanation (say "a copy of your project on this computer", not "clone"; "approval step" or "check", not "scope" or "required status check").
  - Every guide says why the step is needed, shows the exact text to copy or the page to open, says what the user will see when it worked, and what to do if they see something else. The script verifies each step itself and says so ("Done, git is installed").
  - Every prompt explains its choice in one sentence and offers a default where one is safe; required choices (project name, description, pack, licence) have none, and the prompt says why. The pack prompt describes each pack in plain words (what kind of project it is for), the licence prompt says in one line what each licence means, and neither asks the user to know the term beforehand.
  - Errors say what happened and the next action, never a raw API message alone (the raw text is shown below it for support).
  - Progress is visible: each of the steps prints one line when it starts and when it ends.
  - The finish report says in plain words what was created and the one thing to do next.
  - Checked by unit tests: every prompt carries a one-line explanation, every step prints a start and an end line, an error never shows raw text alone, the finish report has its fields, and a list of banned words (clone, scope, status check, PR, repo, branch, API) is checked against every user-facing string unless the word comes with its explanation. "Plain language" beyond that is judged by the unaided run in Done when.
  - Errors are mapped from the HTTP status and the API message read from the JSON body (`gh api -i`, `--jq`), not from gh's stderr, which is not stable. A generic fallback covers unknown errors: "Something unexpected happened", the raw text, and the exact `--resume` command. The OS is detected with `uname -s` (Darwin, Linux, MINGW/MSYS) and `/etc/os-release`.
  - The README is written for the same reader: copy-paste blocks, no assumed tools, screenshots-free text that still names every button.

  **Guided steps in the script, and what only the README can cover.**
  Guided in the script, in three groups by when the failure shows:
  - Preflight (before anything exists; fix, re-check, continue): installing `git` (on macOS the `git` shim starts the Apple command-line tools install; on Linux the package-manager line is printed, never run with `sudo`), installing Node/npm for npm packs (the guide points to nodejs.org, because a distro's Node may be older than the one CI uses), the `workflow` scope refresh, and the git name and email.
  - Failed at create, step 2 (nothing exists; print steps, exit, plain re-run, not `--resume`): an org that refuses repo creation, and a token missing a permission.
  - Post-create (the repo exists; print steps, exit, `--resume`): a token missing a permission that first shows at step 3; Actions turned off in the org or repo, detected by a check right after step 3 (`repos/OWNER/NAME/actions/permissions`, UNVERIFIED) so it fails before the push, not as a timeout at step 15; the credential-helper fallback at step 13 (`gh auth setup-git`, with its own yes); and a private repo on a plan without protection (a menu: upgrade steps, switch to public, or `--allow-unprotected`).
  README only, because the script cannot exist or run without it: step 0 (install `gh`, log in, and on Windows install Git for Windows then close and reopen Git Bash so `gh` is on the PATH; one copy-paste block per OS with what the user will see after each. The login command is one exact line that already asks for the `workflow` scope, `gh auth login -h github.com -p https -w -s workflow`, with the instruction to answer Yes to "Authenticate Git". The flags exist per the gh manual; that they avoid every other prompt is UNVERIFIED); what to do after the script finishes (open the Claude app, add the new repo and start a chat, and, if the GitHub App is limited to selected repos, add the repo in GitHub settings, UNVERIFIED); org-admin and billing settings in more detail; deleting a throwaway repo. The README also lists every guide so a user can read them before running the script. The maintainer's release tag is not in the user README; it stays in `memory/decisions.md`.

  **Not possible without action outside the script (for Adam to accept).** Each of these is guided by the script or documented in the README, as above; none is done for the user.
  1. Installing `gh` and Git for Windows (README step 0), and `git` on macOS and Linux and Node/npm for npm packs (guided).
  2. `gh auth login` (README step 0) and `gh auth refresh -s workflow` (guided). Both are a browser device-code step, although the script tells the user what to type.
  3. Private repos on GitHub Free: protection needs a paid plan (billing in the browser), or making the repo public.
  4. Org-owned repos: the org must allow repo creation and Actions, which only an org admin can change.
  5. Giving Claude access to the new repo: the Claude app, a new Claude project, and, if the GitHub App is limited to selected repos, adding the repo in GitHub settings. The last part is UNVERIFIED.
  6. Deleting a repo from a failed run or an e2e test (`delete_repo` scope or Settings).

  **Known limitation.**
  The shipped process docs still name "Adam" as the product owner. The script fills only `[PO NAME]` placeholders and does not rewrite "Adam". That is "De-Adamify" (`docs/NEXT_SESSION.md` item 4); once those become placeholders, the fill table picks them up.

  **Done when.**
  1. A release publishes a bootstrapper whose root has `bootstrap-project.sh`, stamped with that version and commit, LF and executable, and whose file list is the manifest plus stubs.
  2. The unit tests pass on ubuntu, macOS `/bin/bash` and Windows Git Bash in `bootstrapper-test`.
  3. Adam's e2e runs (above) each end with:
     - the repo created;
     - the setup PR squash-merged on a green `build`;
     - protection read back as specified;
     - no fill-table placeholders left;
     - no README setup section, `languages/` pruned, `LICENSE` as chosen, and no script in the tree;
     - the local clone clean on `main`.
  4. An interrupted run completes with `--resume`, with no duplicate PR or commit.
  5. The docs above are updated, PBI-1.4 and PBI-1.8 have their dispositions, and the layout table exists once.
  6. Each guided check prints its steps and passes on re-check, and the README lists them and the README-only steps.
  7. Someone who has never used `gh` or a terminal sets up a project by following only the README and the script's own messages, without help. Adam, or anyone he names, does this once and the result is recorded on the PBI; any step they could not finish unaided is a defect.
  8. `bootstrapper-test` still reports as one required check, and goes red when any matrix leg fails, and `packs.yml` uses the lockfile command of step 7.

  **Open decisions for Adam (my recommendation first).**
  1. **Order.** Protect first and put the setup through a PR (rec), or push the setup directly as a documented exception?
  2. **Setup PR review.** The script merges the setup PR on a green `build` with no Clead or Crog review. This is an exception to rules 3 and 4 of the change execution model, with CI as the only gate (see "The order problem"). Recommended: name it as an exception in `CLAUDE.md`. The alternative is that the script stops after the PR is green and leaves the review and merge to Crog in the first session, which breaks "turn-key".
  3. **Delivery.** Script at the bootstrapper root, deleted by the setup PR (rec), or as a release asset?
  4. **`languages/` after setup.** Keep only the chosen pack's files that were not laid out, delete `languages/README.md` and the other packs, and point the other doc links at the template URL (rec); or delete all of `languages/` and rewrite every link; or keep it all?
  5. **Private repo on Free.** Stop, but allow `--allow-unprotected` with a recorded decision (rec)? Or always refuse?
  6. **Licence.** Required with no default (rec)? List: none, MIT, Apache-2.0, GPL-3.0, BSD-3-Clause, PolyForm Noncommercial, or any GitHub licence key.
  7. **Repo settings.** Also turn on delete-branch-on-merge and squash merge (rec yes; agents cannot delete branches)?
  8. **E2E.** Manual by Adam now (rec), with CI automation using a sandbox token as a later IDEA?
  9. **Protection type.** Classic branch protection, as in the decisions log and `DEV_INFRASTRUCTURE` (rec), or a ruleset? Both have the same plan availability and the same rules.
  10. **Lockfile.** Require npm locally for npm packs (rec), or let the PR go red and leave the fix to the user?
  11. **Running commands for the user.** The script runs installs and logins only after a yes, with the rules above, and `--yes` does not cover them (rec); or it only prints them and never runs them? Given the target reader, running them is the easier path.

  **Sources checked by the drafting agent.**

  - gh manual: https://cli.github.com/manual/gh_repo_create , gh_repo_clone , gh_repo_edit , gh_pr_create , gh_pr_checks , gh_pr_merge , gh_api , gh_auth_login , gh_auth_refresh , gh_auth_setup-git , gh_auth_status , gh_help_environment (all under https://cli.github.com/manual/).
  - gh source (cli/cli, trunk): `pkg/cmd/repo/create/create.go` (`cloneWithRetry`), `pkg/cmd/auth/shared/git_credential.go`, `internal/authflow/flow.go`, `pkg/cmd/auth/status/status.go`.
  - GitHub docs: REST branch protection, About protected branches, Troubleshooting required status checks (seven-day rule), About rulesets, REST rules, REST create a repository using a template, Creating a repository from a template, permissions for fine-grained tokens, Scopes for OAuth apps, REST users, REST contents, REST licenses, workflow syntax (`shell: bash` on Windows).
  - https://github.com/github/choosealicense.com/blob/gh-pages/README.md (`[year]`, `[fullname]`), https://docs.npmjs.com/cli/v11/commands/npm-install (`--package-lock-only`), https://github.com/cli/cli/issues/6415 (MSYS leading slash), https://github.com/cli/cli/discussions/7893 (mintty prompts).

  **Not verified.**

  - Whether the branch-protection API accepts a required check that has never run (the design avoids depending on it).
  - Whether `contexts` may be omitted when `checks` is given.
  - Whether `gh pr merge --delete-branch` also switches branch and deletes the local branch.
  - Whether `git clone` and `git push` on a private repo work without `gh auth setup-git`.
  - The exact text of the 403 for a private repo on Free.
  - The exact `credential.helper` string for gh as a per-command helper.
  - The npm shim, `/dev/tty` and process substitution in Git Bash.
  - Whether a stub `gh` on PATH beats `gh.exe` on the Windows runner (the design uses `BOOTSTRAP_GH`).
  - macOS `/bin/bash` being 3.2.
  - Durations of the CI waits.
  - Whether the Claude GitHub App needs the new repo added by hand.
  - Whether `winget` (Windows) is present, and whether gh's login prompts work in mintty.
  - Whether fine-grained tokens can create repos without "All repositories" access.
  - Nothing was run against real GitHub: agents cannot create or delete repos.

  **Checked by Clead against the repo (2026-10-01).**

  Confirmed (and, after the Crog review, also `[project-description]` in three `package.json` files, `[project-name]` in `wrangler.jsonc`, `bootstrapper-test` as a required check in `docs/DEV_INFRASTRUCTURE.md`, and `review.yml` firing on `src/**`): `npm ci` in the node, web and react-native `ci.yml`; every pack's `ci.yml` has a single job `build`; `[DATE]` is a real placeholder in `docs/SPEC.md` and the stub `docs/NEXT_SESSION.md`, and a format token in `memory/roles.md` and `docs/CROG_ONBOARDING.md`; `docs/DEV_INFRASTRUCTURE.md` links `languages/<pack>/code-standards.md`; the stub README says "(step 2 above)"; `tools/layout-pack.sh` has the layout table and leaves out `code-standards.md` and the web deploy files; `bootstrapper-test` runs on `ubuntu-latest` only today (the spec adds a matrix); "Adam" is hard-coded in the shipped docs.

- **[NEXT] PBI-1.15** (Adam, 2026-10-01; promoted to NEXT the same day because acuteping waits for a verified toolchain) — Test the whole chain before publishing:
  build the bootstrapper, instantiate it, and prove the instance works.
  **Why.** Today the template's CI tests `build.sh` output (shape only) and
  the packs (laid out from the template checkout, not from the build
  output). Nothing builds the bootstrapper and then creates a project from
  that output, so a bad release could be published. **What.** A job in the
  template's CI builds the bootstrapper into a temp folder, lays out each
  pack from that output (`tools/layout-pack.sh`, or the script's layout
  subcommand once PBI-1.14 exists), and runs the pack's CI steps, replacing
  the template-checkout layout in `packs.yml`. The `publish` job needs it.
  If it becomes a required check, the existing required-check rules apply
  (a matrix renames checks; see PBI-1.14). **Done when.** A change that
  breaks a shipped pack file or the layout fails CI before any tag is
  published.

- **[LATER] PBI-1.16** (Adam, 2026-10-01; he reports `main` on
  `sugose/ai-project-bootstrap` is not protected) — Protect the
  bootstrapper repo's default branch. **What.** Part 1, to do by Adam in
  that repo's settings: block force-pushes and deletion on `main`, with no
  pull-request requirement, so release history stays intact and the direct
  publish push still works. Part 2, research first: whether a ruleset or a
  bypass allowance can limit writes to the publish token on a user-owned
  repo. The docs say push `restrictions` are organisation-only; whether
  `bypass_pull_request_allowances` or a ruleset works on a user-owned repo
  is not verified. If neither works, PBI-1.15 carries the verification.
  Optional later layer: a post-publish check inside the bootstrapper repo,
  which would have to be guarded
  (`if: github.repository == 'sugose/ai-project-bootstrap'`) so projects do
  not inherit a failing or pointless job.

- **[NEXT] PBI-1.17** (Adam, 2026-10-01; the WHAT is his, the HOW is Clead's; spec drafted 2026-10-01, needs Crog review and Adam's intent approval before any build) — Test first, and nothing claimed as working without a check that has run, by default at every level: the template, the bootstrapper and a bootstrapped project.

  **Why.**
  Adam: "regardless if you work on the template, the bootstrapper or a bootstrapped project". Today the rule is only Crog's "TDD rules" in `docs/CROG_ONBOARDING.md` and one line in `memory/roles.md` (both ship). Nothing checks it: no workflow compares changed files, and the template's own required `build` check runs a checkout and nothing else, because the template's `.github/workflows/ci.yml` is the stub that ships to projects. The 2026-10-01 decision row on test-first in this repo says the onboarding rule "stays unchanged"; this PBI replaces that part.

  **The philosophy, in plain words (for the product owner).**
  Before anyone changes how something behaves, they first write a check that fails because the new behaviour is missing, and run it to see it fail. Then they make the change and run the check again to see it pass. Nobody says "done", "works" or "fixed" unless a check that tests exactly that claim has run and passed, and they name the check. This applies to everything that behaves: code, scripts, CI workflows, and settings that change what gets built. Plain text (docs, backlog, decisions, notes) is exempt. Any other exception is written down with a reason, never silent. A robot check in CI catches the most common skip (code changed, no test changed); reviewers catch the rest.

  **Where it lives (in force by default everywhere).**
  - `CLAUDE.md` ships as is to the bootstrapper and to every project, and both agents read it first. A new short section goes above the two role sections: "## Both agents: test first". The intro line "Read your section only" becomes "Read this section and your own". Proposed text (no backlog ids or PR refs, which `build.sh` forbids in shipped files): "Test first, and nothing is claimed as working without a check that has run. Before changing behaviour, write a check that fails without the change and run it to see it fail; then make it pass. Say 'done', 'works' or 'fixed' only after a check that tests that exact claim has run and passed, and name it. This covers code, scripts, CI workflows and config that changes what is built; prose (docs, backlog, decisions, notes) is exempt. Any other exception is stated in a commit message line `Test-exempt: <reason>`, which CI shows and the reviewer judges. Once a language pack's CI is in place, its `build` fails a pull request that changes code (in a project, `src/`) without changing a test; what counts as code and as a test is listed in that step of `.github/workflows/ci.yml`. Details: `docs/CROG_ONBOARDING.md` (TDD rules), `memory/standards.md` (review)."
  - `docs/CROG_ONBOARDING.md` "TDD rules" keeps its three bullets and gains three: the rule covers every change with behaviour, not only `src/`; the PR description shows the red run (command and failing output, or the red CI run's link) from before the implementation; `Test-exempt:` is only for a change no test can check, never for a test that is hard to write.
  - `memory/roles.md` Crog line becomes "Implements test-first (see CLAUDE.md, Both agents: test first): red, green, refactor". Clead's list gains "Writes test-first too: a script or workflow change by Clead follows the same rule".
  - On approval, a new `memory/decisions.md` row records this and states that it replaces "stays unchanged there" in the 2026-10-01 test-first row; the rest of that row (the template's kinds of change) is folded into this spec.

  **The shared check: `.github/scripts/require-test-change.sh`.**
  One bash script, shipped through `bootstrap/manifest.txt` (listed by file), used by the template's `build` and by every pack's `build`. It cannot live in `tools/` or `bootstrap/`, which never ship, nor in `languages/`, which the setup script prunes.
  - Usage: `require-test-change.sh --code PAT... --test PAT... [--ignore PAT...]`, each flag repeatable. Patterns are bash `case` patterns on repo-relative paths, where `*` also matches `/`. Precedence: a path matching `--test` is a test; else matching `--ignore` is exempt; else matching `--code` is code; anything else is "not code".
  - Changed files: `git diff -z --name-only --diff-filter=ACMR <base>...HEAD` (`-z`, NUL-separated, because without it git quotes non-ASCII names such as `src/é.ts` as `"src/\303\251.ts"`, which matches no pattern and would pass silently) (three dots: from the merge base). Deleted files count for neither side, and neither does a type change (`T`, a file turned into a symlink), which `ACMR` leaves out: a change that only deletes code passes; deleting a test does not count as changing one. A rename counts as a change.
  - Base: `$TEST_FIRST_BASE` if set (tests and the chain test); on `pull_request`, `origin/$GITHUB_BASE_REF` (set only for pull_request events; the checkout is the test merge commit, so `origin/main...HEAD` is exactly what the PR adds, even if `main` moved since); on `push` to a branch other than `main`, `origin/main`, so a branch push and its PR give the same verdict (two `build` runs on one commit must not disagree: see Known limitation); on `push` to `main`, pass with a notice, because `main` only changes through PRs that this check already gated. Any other event (`workflow_dispatch`, `merge_group`, a local run with no `GITHUB_*` variables) needs `TEST_FIRST_BASE`, else exit 2 naming it; a local run is `TEST_FIRST_BASE=origin/main bash .github/scripts/require-test-change.sh ...`. Any git failure is exit 2, never a pass: a base ref that does not exist, a shallow history (`git rev-parse --is-shallow-repository` is true) or no merge base, saying "checkout needs fetch-depth: 0"; and a failing `git diff` or `git log`.
  - Opt-out: a non-empty `Test-exempt: <reason>` trailer in any commit of `<base>..HEAD`, read with `git log --format='%(trailers:key=Test-exempt,valueonly)'`. A trailer with no reason does not count.
  - Result: no code changed, pass; code and a test changed, pass; code without a test and with a trailer, pass with a `::notice::` quoting the reason; otherwise fail with `::error::`, the list of code files, and the two ways out (add a test, or `git commit --allow-empty -m "Test-exempt: <reason>" --trailer "Test-exempt: <reason>"`). Every run writes the code, test, exempt and not-code lists and any reason to `$GITHUB_STEP_SUMMARY` when it is set.
  - Why `git diff` and not `gh pr diff --name-only`: it works on push and pull_request alike, needs no token or `pull-requests` permission, has no API file-count limit to reason about, and runs offline against a fixture repo in tests.

  **Level (c), a bootstrapped project.**
  - It must be a step of the existing `build` job. Branch protection requires checks by name, Actions reports each job as a check named after it, and projects require only `build` (`docs/DEV_INFRASTRUCTURE.md`, PBI-1.14 step 16). A separate job would report a check called something else that nothing requires: red, but mergeable. A separate workflow filtered by `paths:` would be worse: where it is skipped, a required check stays "Pending" and blocks that PR.
  - Each pack's `ci.yml`: the checkout gets `with: fetch-depth: 0` (default is 1: only the tip commit), and the check is the first step after it, before any install, so it fails in seconds and needs only bash and git. One single-line `run:` per pack:

    | Pack | `--code` | `--test` | From the pack's layout and `code-standards.md` |
    |---|---|---|---|
    | node | `'src/*'` | `'src/*.test.ts' 'src/*.spec.ts' 'src/*__tests__/*'` | Jest runs `*.test.ts`, `*.spec.ts` and `__tests__/` by default; coverage counts the rest of `src/` |
    | web | `'src/*' 'index.html'` | `'src/*.test.ts' 'src/*.spec.ts' 'src/*__tests__/*' 'e2e/*'` | `src/main.ts` and the page are covered by the Playwright tests in `e2e/` |
    | python | `'src/*'` | `'src/tests/*'` | tests live in `src/tests/` as `test_*.py`; `conftest.py` and helpers there count as tests |
    | react-native | `'src/*'` | `'src/*.test.ts' 'src/*.test.tsx' 'src/*.spec.ts' 'src/*.spec.tsx' 'src/*__tests__/*'` | tests sit next to the code; the patterns follow what jest-expo runs by default |

    For example: `run: bash .github/scripts/require-test-change.sh --code 'src/*' --test 'src/*.test.ts'`. Config (`package.json`, `pyproject.toml`, `tsconfig.json`, `ci.yml`) is not code for this check; the type check, lint and tests still run on it.
  - Docs-only PRs pass ("no code changed"). The setup PR from PBI-1.14 passes in all four packs because each starter adds its tests with its code (node adds only `src/placeholder.test.ts`); a unit test proves it per pack. The stub `ci.yml` (no pack yet) has no check: with no pack there is no `src/` definition.
  - Opt-out per change: the trailer. Opt-out for the whole project: a PR that removes the step, reviewed as a config change (rule 3), with a row in the project's `memory/decisions.md`. No setup-script flag for now; a delegation option may add one later (PBI-1.12).
  - Each pack's `code-standards.md` also lists the local form of the check among its local commands (`git fetch origin && TEST_FIRST_BASE=origin/main bash .github/scripts/require-test-change.sh <the pack's flags>`), because the CI line alone exits 2 outside CI. Each pack's `code-standards.md` gets one bullet after the testing bullet, wording per pack, e.g. node: "**Test first** — write the failing test in `src/*.test.ts` and run it red before the code; `build` fails a pull request that changes `src/` without changing a test (see `CLAUDE.md`, Both agents: test first)."
  - `.github/PULL_REQUEST_TEMPLATE.md` (ships, also used here): under "Test coverage narrative", a line "**Red run before the change:** the command and its failing output, or a link to the red CI run" and "**Test-exempt reason, if any:**".

  **Level (a), this template repo.**
  - Split the stub from the template's CI: move today's checkout-only `ci.yml` to `bootstrap/stubs/.github/workflows/ci.yml` (shipped byte for byte as now) and drop `.github/workflows/ci.yml` from the manifest. The template's own `.github/workflows/ci.yml` becomes template-only; its `build` job (already required here) gets the checkout with `fetch-depth: 0`, the check, and `bash tools/test-require-test-change.sh`. Without the split, any template-specific step would ship to every project that still has the stub.
  - Code: `'*.sh' 'bootstrap/*' 'tools/*' '.github/workflows/*' '.github/scripts/*' 'languages/*' '.gitattributes' '.gitignore'` (the two dotfiles ship, and the setup script relies on `.gitattributes`). Tests: `'bootstrap/test*.sh' 'tools/test-*.sh' 'languages/*.test.ts' 'languages/*.test.tsx' 'languages/*.spec.ts' 'languages/*.spec.tsx' 'languages/*__tests__/*' 'languages/*/src/tests/*' 'languages/*/test_*.py' 'languages/*.e2e.ts'` (a pack's own tests, including its `src/tests/__init__.py`, are tests, as in the pack). Ignored, i.e. prose: `'*.md' 'bootstrap/stubs/licenses/*'` (this includes `CLAUDE.md`, docs, memory and `bootstrap/stubs/CHANGELOG.md`, whose stamping `bootstrap/test.sh` covers anyway). Anything else is "not code". So a pack version refresh with no test change needs a `Test-exempt:` reason ("proven by the pack chain run"), which is the point: the exception is stated.
  - Workflows cannot run locally. A workflow change needs a wiring assertion that fails against the old file (in `bootstrap/test.sh` or `tools/test-*.sh`, as the existing `test_workflow_*` tests do) plus the real run on GitHub, linked in the PR.
  - Exempt by path: prose. Exempt by statement: the trailer. Both show in the job summary, so no exemption is silent.

  **Level (b), the bootstrapper (`sugose/ai-project-bootstrap`).**
  Confirmed: it is generated, never edited. `build.sh` writes exactly the manifest plus stubs; `publish.sh` makes the repo's default branch match the build output (files not in it are deleted), so any edit there is lost at the next release. What ships today: `CLAUDE.md`, the stub `ci.yml`, `review.yml`, `changelog.yml`, the PR template, the process docs, `languages/` and the stubs. Its verification runs in the template: `build.sh`'s own checks, `bootstrap/test.sh` (real-build tests, which also assert that no `tools/`, `bootstrap/`, `packs.yml` or `bootstrapper.yml` ships; `build.sh` itself bans only `bootstrap/` and `docs/RELEASE_NOTES.md`), and the chain test in `packs.yml` (merged in #101), which on every push and PR and before every publish builds the bootstrapper, makes a project from it and runs each pack's CI. A copy of the bootstrapper gets the script file and `CLAUDE.md`'s rule, but its stub `ci.yml` does not run the script, and it has no harness for the bootstrapper itself. Options:
  1. **Change it through the template (rec).** A copy of the bootstrapper is a copy of a release, like a copied binary. To change it, change (or fork) the template, where the harness, the check and the chain test all apply; the published artifact is then verified by checks that ran before publishing. Cost: one line in the stub README ("This repo is generated from <template URL>; change it there"), which every project carries until the setup script deletes that README section; someone who edits a bootstrapper copy directly has no tests, by design.
  2. Ship the harness in the bootstrapper and have the setup script delete it. Cost: breaks `build.sh`'s `bootstrap/` ban and the `tools/` test, or moves the harness to a new shipped path; every "Use this template" project without the script keeps it; the harness depends on template-only fixtures and `languages/` source.
  3. A workflow guarded by `if: github.repository == 'sugose/ai-project-bootstrap'`. It runs only in the published repo (the post-publish idea in PBI-1.16), never in copies or projects, so it does not answer this question. Every project still inherits an inert file.

  **How the check is tested (test-first, strictly).**
  New `tools/test-require-test-change.sh` in the `bootstrap/test.sh` style (`run_test`, `die`, a temp `WORK`). Fixture: a local bare repo as `origin` with `main`, a clone, branches and commits made by the test, and the GitHub variables set per case. Written and shown red (the script does not exist) before the script:
  - code without test fails and names the file; code with test passes; docs only passes; test only passes; code plus a deleted test fails; code deleted only passes; a rename counts;
  - precedence: `src/x.test.ts` is a test, not code; `--ignore` beats `--code` but not `--test`; `src/*` matches `src/a/b.ts`; a path with a space works;
  - trailer with a reason passes and prints the reason; `Test-exempt:` with no reason fails; a trailer on a commit already on `main` does not count;
  - `pull_request`: a detached merge commit of the branch into `origin/main`, with `main` moved after the branch started, attributes only the branch's files; `push` to a branch compares with `origin/main`; `push` to `main` passes with a notice; a shallow clone exits 2 with the fetch-depth message; missing `--code` or `--test` exits 2;
  - the summary file is written when `GITHUB_STEP_SUMMARY` is set;
  - per pack: the exact `run:` line read from `languages/<pack>/ci.yml`, run in a fixture whose `main` is the stub tree and whose branch adds that pack's layout (`tools/layout-pack.sh`) passes (the setup PR); then a source change without a test fails, and with one passes;
  - template: the exact `run:` line from the template `ci.yml`: a `bootstrap/build.sh` change alone fails, with `bootstrap/test.sh` passes; `languages/node/package.json` alone fails; `languages/node/code-standards.md` alone passes; `.github/workflows/packs.yml` alone fails.
  Wiring assertions, each shown failing against today's files first: every pack `ci.yml` has `fetch-depth: 0` and the check as its first `run:`; the template `ci.yml` `build` job has both and runs the new test file; `bootstrap/test.sh`: the real build ships the script byte-identical, its `ci.yml` is byte-identical to the stub, the stub mentions no `tools/`, `bootstrap/` or the script, and the manifest no longer lists `.github/workflows/ci.yml`; `packs.yml` has the steps below.
  **End to end.** In each `packs.yml` pack job, after the project is made from the bootstrapper output: a step makes it a git repo (`git init -b main`) with the bootstrapper output (before the pack is laid out) committed on `main` and the pack layout, `languages/` removed, committed on a branch `setup` (runners have no git identity: `git -c user.name=ci -c user.email=ci@example.invalid commit`); the existing "Create the project" step is split so `main` can be committed before the pack is overlaid; the pack's check step runs verbatim there with `env: TEST_FIRST_BASE: main`, so it checks the real setup change and must pass; then `setup` is merged into `main` and a third step commits a `src/` change on a branch and requires the project's own check command, read from its `ci.yml`, to fail. The drift tests stay valid: the step is a single-line `run:`, and `test_packs_workflow_runs_every_pack_ci_step` then requires it in `packs.yml` (it finds 19 `run:` lines today and 23 after this change; 17 in the test is only a sanity floor). What `packs.yml` cannot simulate is a real `pull_request` event (GitHub's merge commit, `GITHUB_BASE_REF`, the checkout's remote refs). That is proven in two places: in the template by its own `build` on every real PR, plus one deliberate throwaway PR that changes `bootstrap/build.sh` alone, which must go red and is then closed unmerged; and in a real project only by Adam's PBI-1.14 end-to-end runs, which gain one item: in one throwaway project, a PR that changes `src/` without a test shows a red `build` and cannot be merged, then goes green after an empty commit with a `Test-exempt:` trailer.

  **What changes, file by file.**
  - `.github/scripts/require-test-change.sh` (new, shipped) and `tools/test-require-test-change.sh` (new, template-only).
  - `bootstrap/manifest.txt`: add the script; remove `.github/workflows/ci.yml`. `bootstrap/stubs/.github/workflows/ci.yml`: today's stub, moved. `bootstrap/stubs/README.md`: the "generated, change the template" line (option 1). `build.sh`: no change (the moved stub is covered by its stub and exact-list checks; the new script must pass the forbidden-string checks). `bootstrap/test.sh`: the assertions above; `test_shipped_ci_does_not_reference_bootstrap` reads the stub.
  - `.github/workflows/ci.yml` (template): becomes template-only as above. `.github/workflows/packs.yml`: the three steps per pack. `tools/test-layout-pack.sh`: the count, and a test that the template `ci.yml` is not in the manifest.
  - Pack `ci.yml` ×4 and `code-standards.md` ×4; `languages/README.md` "Rules for a pack": every pack's `ci.yml` runs the check with its own patterns.
  - `CLAUDE.md`, `docs/CROG_ONBOARDING.md`, `memory/roles.md`, `.github/PULL_REQUEST_TEMPLATE.md`, as above. `memory/standards.md` section 4 gains: "Was the red run shown before the implementation? If not, ask for it." "A green test-change check only proves some test file changed: do the changed tests exercise the changed code?" "Each `Test-exempt:` reason: is it true, and is there really nothing a test could check?" `docs/DEV_INFRASTRUCTURE.md` section 5: a CI rule "A code change comes with a test change", and the template paragraph says its `build` runs the check.

  **Known limitation (what cannot be done).**
  No tool proves the test was written before the code: commit order is lost in a squash merge and is easy to fake, so the check does not read it. The check sees file names, not meaning: a trivial edit to any test file (a comment, a space) satisfies it, as does a test change unrelated to the code, and a false `Test-exempt:` reason passes CI. Review covers these (`memory/standards.md` section 4, and the red run in the PR description). Config changes in projects are not checked for a test, and neither are `ci.yml` and other workflows there. A project PR can delete or weaken the check and break the rule in the same PR (its run uses the PR's own workflow): only review catches it. Pushes to `main` are not checked, and until branch protection is on nothing stops a direct push. A project with no language pack yet (stub `ci.yml`) has no check, and neither has a copy of the bootstrapper. GitHub's docs warn that duplicate check names are ambiguous for branch protection but do not say which of two same-name runs on one commit wins; the design makes the push and pull_request runs agree instead of depending on it. With the default squash setting, a multi-commit PR's squash message lists its commit messages, so a trailer also lands in `main`'s history as text; with another repo setting it stays only on the PR's commits.

  **Done when.**
  1. The script and its tests are merged, each test shown red first, and the tests run in the template's required `build`.
  2. The template's `build` runs the check on every PR; the throwaway PR above went red and is linked on this PBI.
  3. A release ships the script, the unchanged stub `ci.yml` and four pack `ci.yml` files with the check; the chain test is green on the setup step and red-as-required on the simulated change, for all four packs.
  4. The docs above are changed and the decision row is added; Adam's PBI-1.14 end-to-end runs include the red-then-exempt PR, and it behaved as specified.

  **Order, and dependency on PBI-1.14.** One PR, one fix, each PR's tests run in a required check before it merges: (1) the script, its generic tests (everything in the list above that needs no pack or template `ci.yml`: edge cases, precedence, trailer, events, shallow and non-ASCII cases) and one new step in the template-only `bootstrapper-test` job (required) that runs `bash tools/test-require-test-change.sh`, so the tests are gated from this PR on (with a wiring assertion in `bootstrap/test.sh`, shown failing against the old `bootstrapper.yml`; PR (2) keeps that step on purpose, so a release run also runs the tests, and adds the test to `build` only if the template's `build` should show it too: decide there); (2) the template `ci.yml` split and wiring, with the template-pattern cases and the wiring assertions for it; (3) the four pack `ci.yml` files, `packs.yml` and the drift count, with the per-pack cases and wiring assertions; (4) the docs, last, so no doc claims a check that does not exist yet. (1) to (3) land before PBI-1.14's build PRs, so its expected per-pack trees include `.github/scripts/` and the new pack `ci.yml`, its tidy step keeps `.github/scripts/`, and its setup-PR wait (step 15) already includes the check. PBI-1.14 also gains the end-to-end item above.

  **HOW decisions (Clead's call, Adam does not decide these; each can be challenged in review).**
  1. The rule lives in `CLAUDE.md` (ships, both agents read it), plus Crog's onboarding and the review standard.
  2. The opt-out is a `Test-exempt: <reason>` commit trailer: it is in git, so the push run and the pull_request run of `build` agree, it needs no extra workflow triggers, and it forces a written reason. A PR label or a note in the PR description is invisible to push runs, so the two `build` runs could disagree.
  3. The template's own CI is split from the shipped stub, so the template's `build` does real work and no template-only step ships to projects.
  4. Switching the check off for a whole project is a reviewed PR that removes the step, plus a decision row; no setup-script option now (PBI-1.12 may add one).
  5. The bootstrapper is changed only through the template; no test harness ships in it (option 1).
  6. In a project, "code" is `src/` (plus `index.html` for web); config files are not, because that would make every dependency bump need a test or an exemption.
  7. Branch pushes are checked against `origin/main` so the branch run and the PR run agree; pushes to `main` are skipped.

  **For Adam's intent approval (the WHAT).**
  - The rule itself (test first, nothing claimed as working without a check that has run) is stated once, in `CLAUDE.md`, and applies at every level: both agents follow it everywhere. That part is a rule people follow and review enforces; no tool can prove it.
  - What a robot blocks, by default: in this template, a pull request that changes scripts, workflows, the bootstrapper's file list, non-prose language-pack files or the two shipped dotfiles without changing a test. In a new project that has a language pack, a pull request that changes `src/` (and `index.html` for the web pack) without changing a test. A blocked pull request cannot be merged until a test changes or the author writes down why no test is possible.
  - What the robot does not block: prose (docs, backlog, decisions, notes); in a project, config files, `ci.yml` and other workflows (review judges those); and projects with no language pack yet.
  - Cost: a refactor with no test change, and a version bump in a pack, need a written reason each time. The reviewer judges the reason; CI only checks that one exists.
  - The bootstrapper repo gets no test support for itself, by design: it is generated from the template and changed only there, where the tests and the chain test run. Someone who edits a copy of it directly works without them.
  - Honest limit: the check cannot prove the test came first, or that it is a good one. Review covers that.

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

- **[DONE] PBI-4.2** (Adam, 2026-10-01: closed as done; CLAUDE.md already requires
  event-based writes — "persist when a decision is made and when a PR
  opens" under Session end — plus the `..wrap` flush) — Implement event-driven memory writes in CLAUDE.md.

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
