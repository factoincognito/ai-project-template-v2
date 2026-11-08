# ai-project-template-v2 backlog: done entries

The `DONE` entries of `docs/BACKLOG.md` (`RULES.md` L § 2 (1)), under the section headings they had there. The entries done by 2026-11-08 were moved here that day, unchanged. A citation written before then as "`docs/BACKLOG.md` PBI-n" for one of these entries means its entry here.

---

## Phase 1 — Language packs and bootstrap wizard

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

- **[DONE] PBI-1.9** (2026-09-30) — Fix the README setup steps, which still say to
  "Create a Cowork project" (README.md lines 19-27 and 48-53, plus the
  Team table). Cowork is now part of Claude itself. Keep what still
  holds: one project per repository, and the repo files are Clead's
  memory. Docs only.

- **[DONE] PBI-1.14** (proposed 2026-10-01 by Clead from Adam's request; spec reviewed by Crog and intent approved by Adam in chat, 2026-10-01, with every open decision answered as recommended; recorded on PR #97; supersedes PBI-1.4 for new projects and absorbs PBI-1.8; built in slices S1-S19 (last: #174), to be tagged v2.4.0; the end-to-end runs are PBI-1.17) — Turn-key bootstrap script.

  **Why.**
  Adam: "the bootstrap script should be the only thing you need to run in order for the bootstrapped project to be created. Turn-key." Today a new project takes five manual README steps after "Use this template": copy a pack, turn on protection, fill placeholders, choose a licence and delete the section. Each one can go wrong without anyone noticing.

  **Goal and non-goals.**
  **Goal.** Run one script and get a GitHub repo that is created from `factoincognito/ai-project-bootstrap`, laid out with one language pack, has its placeholders filled and its own licence, has protected `main` with a green `build`, and has a clean local clone. The setup itself arrives through a PR like every other change.
  **Non-goals.** It does not write the project's content: goals, SPEC sections and the first PBI are for Clead in the first session. It does not migrate from an existing repo (the migration part of PBI-1.4). It does not set up the Claude app or project, Cloudflare deploy secrets, or a delegation level (PBI-1.12). It never deletes a repo.

  **Obtaining and starting it.**
  The script is `bootstrap-project.sh` at the root of the public bootstrapper repo. It is fetched with `gh api`, which refuses to run until `gh` is installed and logged in (read from the gh source, `pkg/cmd/api/api.go`: no auth-check exemption; not run), so installing `gh`, logging in and, on Windows, installing Git for Windows (which provides Git Bash and `git`) are README step 0, done by hand before the script exists. The command is the same in Git Bash, macOS and Linux:
  ```
  gh api repos/factoincognito/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh && bash bootstrap-project.sh
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
  - `OWNER/NAME` must not exist yet; with `--resume` it must exist (see re-runs). The target directory must be absent or empty; with `--resume`, a directory that is not empty must be this project's own clone (the top folder of a git repo whose `origin` is `OWNER/NAME`). Its parent must exist, the directory (or its parent, when the directory does not exist yet) must be writable, and it must not be inside another git repo.
  - The licence key is checked before anything is created: `gh api licenses/<key>` must answer 200 (`none` and `polyform-noncommercial-1.0.0` need no call). A key GitHub does not know exits 2, listed with the other option problems, when it came from `--license` or in `--non-interactive` mode, and is explained and asked again when it was typed at the prompt. Step 10 keeps its own handling of the 404.

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
  | Web deploy files laid out | `--with-deploy` / `--without-deploy` (web only) | off |
  | Visibility | `--public` / `--private` | public |
  | Project licence | `--license none\|mit\|apache-2.0\|gpl-3.0\|bsd-3-clause\|polyform-noncommercial-1.0.0\|<any GitHub licence key>` | none offered as a default |
  | Copyright holder | `--copyright-holder` | PO name |
  | Target dir | `--dir` | `./<name>` |
  | CI wait | `--ci-timeout <min>` | 20 |

  - `--non-interactive` never reads stdin. Any missing required input (name, description, pack or licence) exits 2, listing every input that is missing.
  - `--yes` skips the final "Proceed?" confirmation.
  - `--dry-run` runs the preflight and prints the plan.
  - `--resume` continues an existing repo (see re-runs).
  - `--version` (Adam, 2026-10-27) prints one line, the stamped version and the template commit the script was built from (`bootstrap-project.sh vX.Y.Z, built from factoincognito/ai-project-template-v2@<commit>`; the unstamped script in the template says it is not a release), and exits 0 before any check, prompt, network or gh call. Like `--help`, it is read where it stands: the options after it are not read, and a wrong option before it is refused as in any run. `--help` lists it.
  - Name values may not contain control characters, `"`, `\`, `<`, `>`, `&` or backtick, because they go into JSON and HTML. The description must be one line. A `|` in the PO name or display name is rejected (it breaks the README table). A `.` in the repo name becomes `-` in the `[project-name]`/`[project-slug]` values, which must be valid npm and Expo slugs.

  **Steps.**
  The numbers name the steps in the script, its tests and the rest of this spec. The script runs them in this order: 1 to 5, a check that the clone has every file the setup changes and that the licence text can be had (before anything is changed), then 6, 9, 8, 7, then 10 to 19. The tidy-up (9) runs before the fill (8), so the README's setup section (matched by its whole heading line) is removed before a description equal to that heading could be taken for it; the lockfile (7) runs after the fill, so it names the project, not `[project-name]`. The Actions check (see "Guided steps") runs right after step 3; when step 3 hit the plan limit on a private repo and the run continues with `--allow-unprotected`, the decision row is written after step 11.
  1. **Preflight and confirmation** (above). It prints the full plan.
  2. **Create** with `gh repo create OWNER/NAME --template factoincognito/ai-project-bootstrap --public|--private --description "…"`. GitHub makes the repo's first commit, a single commit of the template content (the "Creating a repository from a template" doc). Template content can land after creation, so the script then polls `repos/OWNER/NAME/branches/main` and the contents API for `CHANGELOG.md` for up to 60 s, retrying on 404, before touching protection.
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
     - **Left for the first Clead session** (the script lists them at the end): `[PHASE NAME]`, `[Goal]`, the SPEC section prompts, the rest of `memory/project.md`, `memory/context.md` and `STATUS.md` (shipped as the stub, filled in by Clead).
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
      - the next step: in the Claude app, create a Claude Project for the project, add the GitHub project to it, and start a chat inside it. `CLAUDE.md` does the rest. The very last line says that Clead is there to help whenever the user feels stuck (run-1 finding 10, #206).

  **The order problem.**
  `CLAUDE.md` says every change goes through a PR. The protection order itself needs no exception:
  - GitHub's template generation makes `main`'s only commit.
  - `main` is protected at step 3, before anything else is pushed.
  - The setup arrives as a PR that must pass `build`.
  - The cost is a few minutes of CI wait, and it proves the project is "green on day one".

  It does need one exception, though, which is Decision 2: the script itself merges the setup PR, which departs from rule 3 (review by the role that did not write the change) and rule 4 (Crog merges), with CI as the only gate. The setup PR is not the released template's own tested output: the lockfile is resolved at run time (transitive dependencies float), it is made with a different command than `packs.yml` used before this change, and the PR carries values the user typed and a licence fetched from the API. Also, `review.yml` fires on the setup PR because the starters add `src/**`, and `changelog.yml` commented after the merge although the PR already updated the CHANGELOG. Both comments are noise in a project with no session yet. Run 1 (2026-10-26) found them harmless; since #200, `changelog.yml` posts nothing for a PR that already changes CHANGELOG.md, so the setup PR gets only the `review.yml` comment.

  The alternative is to push the setup straight to `main` before protection and record it as the one documented exception. That is faster, but it breaks the rule and leaves `build` unproven until the first real PR. **Open decision 1.**

  **Refusals, warnings, re-runs, failures.**
  - **Private repo, no protection possible.** Protection is free only on public repos; private repos need Pro, Team or Enterprise (branch protection REST doc). Rulesets have the same availability (About rulesets). Reading `/user` `plan` needs `read:user`, which gh's minimum scopes lack, so the script cannot check the plan before creating. Instead it warns before creating, and if step 3 returns 403 it stops at once (a post-create guide: it does not retry in the same run). At that point the repo holds only the template commit. The script prints plain-language steps for three options and the exact `--resume` command:
    - upgrade the plan, then run with `--resume`;
    - `gh repo edit --visibility public --accept-visibility-change-consequences`, then `--resume`; this changes the repo's visibility, so it runs only after its own explicit yes, which `--yes` does not cover;
    - `--resume --allow-unprotected`, which merges unprotected and adds a decision row to the project's `memory/decisions.md` saying `main` is unprotected and why. **Open decision 5.**
  - **Existing repo.** Refused unless `--resume` is given; with `--resume`, a repo that does not exist is refused too (the script never creates a repo when asked to continue one). With `--resume`, the script works out where to continue from GitHub and the clone, not from any state file:
    - a repo whose `CHANGELOG.md` is missing or does not carry a bootstrapper version stamp is refused;
    - a repo stamped by a bootstrapper version other than the script's own is refused, with steps to set up a fresh repo under another name instead (Adam's decision of 2026-10-02, `memory/decisions.md`): each version sets a project up by its own tables, and finishing an older one with the current tables could leave it half old, half new. Repos from releases before the org move carry the old owner in their stamp and are older versions anyway;
    - no sign of the setup on GitHub (no setup line in the CHANGELOG, no `bootstrap-setup` PR or branch, the README setup section still there) and no clone in the target directory: continue from step 3;
    - no sign of the setup on GitHub, with the project's own clone in the target directory holding none of the setup's changes: continue from step 3, then use that clone (on its `bootstrap-setup` branch if it has one);
    - a local `bootstrap-setup` commit that was never pushed (local branch ahead of origin, no remote branch): continue from step 13, with the push;
    - a `bootstrap-setup` branch pushed with no PR: continue from step 14;
    - an open `bootstrap-setup` PR: continue from step 15;
    - with no clone in the target directory, the branch and PR cases above first clone the repo and check out GitHub's `bootstrap-setup`;
    - the web deploy files: in the two step 3 cases the choice is still open, so the deploy question (unless `--with-deploy` or `--without-deploy` is given) is asked once the state is worked out; in the commit, branch and PR cases the setup commit decides (whether it has `.github/workflows/deploy.yml`, read from the clone, or from GitHub's `bootstrap-setup` when there is no clone), and a `--with-deploy` or `--without-deploy` that contradicts it is refused (exit 2) before anything changes. The command to continue carries a no as `--without-deploy`, so it never asks again;
    - already set up (the CHANGELOG line "Set up by bootstrap-project.sh", a merged `bootstrap-setup` PR, or no setup section and no script): only read protection back (it stops, changing nothing, when protection is missing or differs from the step 16 body; the only exception is no protection at all on a private repo with `--allow-unprotected`), bring a clone in the target directory up to date (step 18), and report. Protection is never set on such a repo, so a project set up by hand from the current release keeps its own;
    - a repo that is not set up, still has the script, and whose README no longer has the setup section heading: refused before anything is written;
    - a local clone with uncommitted changes: refused, with steps to move the folder away or make it match GitHub (the script never discards work);
    - a local clone that does not match GitHub: refused, changing nothing in either. That is: GitHub has `bootstrap-setup` and the clone does not, or has another commit on it; the clone's `origin/main` is not GitHub's `main` (the no-sign-of-setup and unpushed-commit cases); or the clone's `bootstrap-setup` is not the single commit "Set up <name>" (the unpushed-commit, branch and PR cases).

    Because of this, `--resume` also completes a repo made with the "Use this template" button from the current release; one made from an older release is refused as above.
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
    - After each run, and before deleting anything, run the template-only `bootstrap/e2e-check.sh OWNER/NAME DIR`. It only reads (GitHub through GET calls, the clone through git commands that read) and checks the finished run against "Done when", so run it after the run ends, not before. It prints the delete commands for Adam to run: `gh repo delete` only for names starting `bootstrap-e2e-`, and an `rm -rf` line for the clone only when the clone check passed.
    - Delete them afterwards with `gh repo delete` (after `gh auth refresh -s delete_repo`) or in Settings.
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
  - Every prompt explains its choice in one short line (a sentence or two) and offers a default where one is safe; required choices (project name, description, pack, licence) have none, and the prompt says why. The pack prompt describes each pack in plain words (what kind of project it is for), the licence prompt says in one line what each licence means, and neither asks the user to know the term beforehand.
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
  - Post-create (the repo exists; print steps, exit, `--resume`): a token missing a permission that first shows at step 3; Actions turned off in the org or repo, detected by a check right after step 3 (`repos/OWNER/NAME/actions/permissions`, UNVERIFIED) so it fails before the push, not as a timeout at step 15. This one is also re-checked in the same run when interactive: the script waits for Enter and checks again, as in the preflight; with `--non-interactive` it prints the steps and exits with the `--resume` command. A 403 or 404 from that call gives a warning and the run goes on. Actions that are on but allow only the repo's own actions (`allowed_actions: local_only`) pass that check and fail `build` at step 15; the script then reads `allowed_actions`, shows the same settings guide with a step to re-run `build`, and stops with the `--resume` command; the credential-helper fallback at step 13 (`gh auth setup-git`, with its own yes); and a private repo on a plan without protection (a menu: upgrade steps, switch to public, or `--allow-unprotected`).
  README only, because the script cannot exist or run without it: step 0 (install `gh`, log in, and on Windows install Git for Windows then close and reopen Git Bash so `gh` is on the PATH; one copy-paste block per OS with what the user will see after each. The login command is one exact line that already asks for the `workflow` scope, `gh auth login -h github.com -p https -w -s workflow`, with the instruction to answer Yes to "Authenticate Git". The flags exist per the gh manual; that they avoid every other prompt is UNVERIFIED); what to do after the script finishes (in the Claude app, create a Claude Project for the new repo, add the repo to it and start a chat inside it, and, if the GitHub App is limited to selected repos, add the repo in GitHub settings, UNVERIFIED); org-admin and billing settings in more detail; deleting a throwaway repo. The README also lists every guide so a user can read them before running the script. The maintainer's release tag is not in the user README; it stays in `memory/decisions.md`.

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

- **[DONE] PBI-1.15** (2026-10-01, PRs #101 and #102; Adam, promoted to NEXT the same day because acuteping waits for a verified toolchain) — Test the whole chain before publishing:
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
  **Built (PR #101).** Each pack job in `packs.yml` builds the bootstrapper,
  makes a project from that output and runs the pack's CI steps; on a `v*`
  tag `publish` needs the `packs` call. The first run found a real bug (the
  Python block in `docs/DEV_INFRASTRUCTURE.md`, fixed in PR #102). **Not yet
  exercised:** the `packs` call on a real tag run, which needs a release.

- **[DONE] PBI-1.17** (done 2026-10-29: Done when 4 met in end-to-end run 3 on v2.8.3, `sugose/bootstrap-e2e-python-20261029b` #2: red on a code change without a test, CI run 40930999396, then green with a `Test-exempt:` trailer, CI run 40931122667; see `docs/NEXT_SESSION.md`. Earlier: Adam, 2026-10-01; the WHAT is his, the HOW is Clead's; spec reviewed by Crog (two rounds) and intent approved by Adam, 2026-10-01; PRs 1 to 3 merged (#107, #108, #110), PR 4 is the docs; the throwaway PR #109 went red on `build` as specified and was closed unmerged; Adam's end-to-end runs are still to do) — Test first, and nothing claimed as working without a check that has run, by default at every level: the template, the bootstrapper and a bootstrapped project.

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
  - Split the stub from the template's CI: move today's checkout-only `ci.yml` to `bootstrap/stubs/.github/workflows/ci.yml` (shipped byte for byte as now) and drop `.github/workflows/ci.yml` from the manifest. The template's own `.github/workflows/ci.yml` becomes template-only; its `build` job (already required here) gets the checkout with `fetch-depth: 0` and the check. The check's own tests stay in `bootstrapper-test` (also required), which runs `bash tools/test-require-test-change.sh`; `build` does not. Without the split, any template-specific step would ship to every project that still has the stub.
  - Code: `'*.sh' 'bootstrap/*' 'tools/*' '.github/workflows/*' '.github/scripts/*' 'languages/*' '.gitattributes' '.gitignore'` (the two dotfiles ship, and the setup script relies on `.gitattributes`). Tests: `'bootstrap/test.sh' 'bootstrap/test-*.sh' 'tools/test-*.sh' 'languages/*.test.ts' 'languages/*.test.tsx' 'languages/*.spec.ts' 'languages/*.spec.tsx' 'languages/*__tests__/*' 'languages/*/src/tests/*' 'languages/*/test_*.py' 'languages/*.e2e.ts'` (a pack's own tests, including its `src/tests/__init__.py`, are tests, as in the pack). Ignored, i.e. prose: `'*.md' 'bootstrap/stubs/licenses/*'` (this includes `CLAUDE.md`, docs, memory and `bootstrap/stubs/CHANGELOG.md`, whose stamping `bootstrap/test.sh` covers anyway). Anything else is "not code". So a pack version refresh with no test change needs a `Test-exempt:` reason ("proven by the pack chain run"), which is the point: the exception is stated.
  - Workflows cannot run locally. A workflow change needs a wiring assertion that fails against the old file (in `bootstrap/test.sh` or `tools/test-*.sh`, as the existing `test_workflow_*` tests do) plus the real run on GitHub, linked in the PR.
  - Exempt by path: prose. Exempt by statement: the trailer. Both show in the job summary, so no exemption is silent.

  **Level (b), the bootstrapper (`factoincognito/ai-project-bootstrap`).**
  Confirmed: it is generated, never edited. `build.sh` writes exactly the manifest plus stubs; `publish.sh` makes the repo's default branch match the build output (files not in it are deleted), so any edit there is lost at the next release. What ships today: `CLAUDE.md`, the stub `ci.yml`, `review.yml`, `changelog.yml`, the PR template, the process docs, `languages/` and the stubs. Its verification runs in the template: `build.sh`'s own checks, `bootstrap/test.sh` (real-build tests, which also assert that no `tools/`, `bootstrap/`, `packs.yml` or `bootstrapper.yml` ships; `build.sh` itself bans only `bootstrap/` and `docs/RELEASE_NOTES.md`), and the chain test in `packs.yml` (merged in #101), which on every push and PR and before every publish builds the bootstrapper, makes a project from it and runs each pack's CI. A copy of the bootstrapper gets the script file and `CLAUDE.md`'s rule, but its stub `ci.yml` does not run the script, and it has no harness for the bootstrapper itself. Options:
  1. **Change it through the template (rec).** A copy of the bootstrapper is a copy of a release, like a copied binary. To change it, change (or fork) the template, where the harness, the check and the chain test all apply; the published artifact is then verified by checks that ran before publishing. Cost: one line in the stub README ("This repo is generated from <template URL>; change it there"), which every project carries until the setup script deletes that README section; someone who edits a bootstrapper copy directly has no tests, by design.
  2. Ship the harness in the bootstrapper and have the setup script delete it. Cost: breaks `build.sh`'s `bootstrap/` ban and the `tools/` test, or moves the harness to a new shipped path; every "Use this template" project without the script keeps it; the harness depends on template-only fixtures and `languages/` source.
  3. A workflow guarded by `if: github.repository == 'factoincognito/ai-project-bootstrap'`. It runs only in the published repo (the post-publish idea in PBI-1.16), never in copies or projects, so it does not answer this question. Every project still inherits an inert file.

  **How the check is tested (test-first, strictly).**
  New `tools/test-require-test-change.sh` in the `bootstrap/test.sh` style (`run_test`, `die`, a temp `WORK`). Fixture: a local bare repo as `origin` with `main`, a clone, branches and commits made by the test, and the GitHub variables set per case. Written and shown red (the script does not exist) before the script:
  - code without test fails and names the file; code with test passes; docs only passes; test only passes; code plus a deleted test fails; code deleted only passes; a rename counts;
  - precedence: `src/x.test.ts` is a test, not code; `--ignore` beats `--code` but not `--test`; `src/*` matches `src/a/b.ts`; a path with a space works;
  - trailer with a reason passes and prints the reason; `Test-exempt:` with no reason fails; a trailer on a commit already on `main` does not count;
  - `pull_request`: a detached merge commit of the branch into `origin/main`, with `main` moved after the branch started, attributes only the branch's files; `push` to a branch compares with `origin/main`; `push` to `main` passes with a notice; a shallow clone exits 2 with the fetch-depth message; missing `--code` or `--test` exits 2;
  - the summary file is written when `GITHUB_STEP_SUMMARY` is set;
  - per pack: the exact `run:` line read from `languages/<pack>/ci.yml`, run in a fixture whose `main` is the stub tree and whose branch adds that pack's layout (`tools/layout-pack.sh`) passes (the setup PR); then a source change without a test fails, and with one passes;
  - template: the exact `run:` line from the template `ci.yml`: a `bootstrap/build.sh` change alone fails, with `bootstrap/test.sh` passes; `languages/node/package.json` alone fails; `languages/node/code-standards.md` alone passes; `.github/workflows/packs.yml` alone fails.
  Wiring assertions, each shown failing against today's files first: every pack `ci.yml` has `fetch-depth: 0` and the check as its first `run:`; the template `ci.yml` `build` job has both (`fetch-depth: 0` and the check; the check's own test file runs in `bootstrapper-test`, not in `build`); `bootstrap/test.sh`: the real build ships the script byte-identical, its `ci.yml` is byte-identical to the stub, the stub mentions no `tools/`, `bootstrap/` or the script, and the manifest no longer lists `.github/workflows/ci.yml`; `packs.yml` has the steps below.
  **End to end.** In each `packs.yml` pack job, after the project is made from the bootstrapper output: a step makes it a git repo (`git init -b main`) with the bootstrapper output (before the pack is laid out) committed on `main` and the pack layout, `languages/` removed, committed on a branch `setup` (runners have no git identity: `git -c user.name=ci -c user.email=ci@example.invalid commit`); the existing "Create the project" step is split so `main` can be committed before the pack is overlaid; the pack's check step runs verbatim there with `env: TEST_FIRST_BASE: main`, so it checks the real setup change and must pass; then `setup` is merged into `main` and a third step commits a `src/` change on a branch and requires the project's own check command, read from its `ci.yml`, to fail. The drift tests stay valid: the step is a single-line `run:`, and `test_packs_workflow_runs_every_pack_ci_step` then requires it in `packs.yml` (it finds 19 `run:` lines today and 23 after this change; 17 in the test is only a sanity floor). What `packs.yml` cannot simulate is a real `pull_request` event (GitHub's merge commit, `GITHUB_BASE_REF`, the checkout's remote refs). That is proven in two places: in the template by its own `build` on every real PR, plus one deliberate throwaway PR that changes `bootstrap/build.sh` alone, which must go red and is then closed unmerged; and in a real project only by Adam's PBI-1.14 end-to-end runs, which gain one item: in one throwaway project, a PR that changes `src/` without a test shows a red `build` and cannot be merged, then goes green after an empty commit with a `Test-exempt:` trailer.

  **What changes, file by file.**
  - `.github/scripts/require-test-change.sh` (new, shipped) and `tools/test-require-test-change.sh` (new, template-only).
  - `bootstrap/manifest.txt`: add the script; remove `.github/workflows/ci.yml`. `bootstrap/stubs/.github/workflows/ci.yml`: today's stub, moved. `bootstrap/stubs/README.md`: the "generated, change the template" line (option 1). `build.sh`: no change (the moved stub is covered by its stub and exact-list checks; the new script must pass the forbidden-string checks). `bootstrap/test.sh`: the assertions above; `test_shipped_ci_does_not_reference_bootstrap` reads the stub.
  - `.github/workflows/ci.yml` (template): becomes template-only as above. `.github/workflows/packs.yml`: the three steps per pack. `tools/test-layout-pack.sh`: the count. The test that the template `ci.yml` is not in the manifest is in `bootstrap/test.sh` (`test_template_ci_is_not_in_the_manifest`).
  - Pack `ci.yml` ×4 and `code-standards.md` ×4; `languages/README.md` "Rules for a pack": every pack's `ci.yml` runs the check with its own patterns.
  - `CLAUDE.md`, `docs/CROG_ONBOARDING.md`, `memory/roles.md`, `.github/PULL_REQUEST_TEMPLATE.md`, as above. `memory/standards.md` section 4 gains: "Was the red run shown before the implementation? If not, ask for it." "A green test-change check only proves some test file changed: do the changed tests exercise the changed code?" "Each `Test-exempt:` reason: is it true, and is there really nothing a test could check?" `docs/DEV_INFRASTRUCTURE.md` section 5: a CI rule "A code change comes with a test change", and the template paragraph says its `build` runs the check.

  **Known limitation (what cannot be done).**
  No tool proves the test was written before the code: commit order is lost in a squash merge and is easy to fake, so the check does not read it. The check sees file names, not meaning: a trivial edit to any test file (a comment, a space) satisfies it, as does a test change unrelated to the code, and a false `Test-exempt:` reason passes CI. Review covers these (`memory/standards.md` section 4, and the red run in the PR description). Config changes in projects are not checked for a test, and neither are `ci.yml` and other workflows there. A project PR can delete or weaken the check and break the rule in the same PR (its run uses the PR's own workflow): only review catches it. Pushes to `main` are not checked, and until branch protection is on nothing stops a direct push. A project with no language pack yet (stub `ci.yml`) has no check, and neither has a copy of the bootstrapper. GitHub's docs warn that duplicate check names are ambiguous for branch protection but do not say which of two same-name runs on one commit wins; the design makes the push and pull_request runs agree instead of depending on it. With the default squash setting, a multi-commit PR's squash message lists its commit messages, so a trailer also lands in `main`'s history as text; with another repo setting it stays only on the PR's commits.

  **Done when.**
  1. The script and its tests are merged, each test shown red first, and the tests run in the template's required `bootstrapper-test` (the template's `build` runs only the check).
  2. The template's `build` runs the check on every PR; the throwaway PR above went red and is linked on this PBI.
  3. A release ships the script, the unchanged stub `ci.yml` and four pack `ci.yml` files with the check; the chain test is green on the setup step and red-as-required on the simulated change, for all four packs.
  4. The docs above are changed and the decision row is added; Adam's PBI-1.14 end-to-end runs include the red-then-exempt PR, and it behaved as specified.

  **Order, and dependency on PBI-1.14.** One PR, one fix, each PR's tests run in a required check before it merges: (1) the script, its generic tests (everything in the list above that needs no pack or template `ci.yml`: edge cases, precedence, trailer, events, shallow and non-ASCII cases) and one new step in the template-only `bootstrapper-test` job (required) that runs `bash tools/test-require-test-change.sh`, so the tests are gated from this PR on (with a wiring assertion in `bootstrap/test.sh`, shown failing against the old `bootstrapper.yml`; PR (2) keeps that step on purpose, so a release run also runs the tests, and does not add the test to `build`, which only runs the check: decided in PR 2); (2) the template `ci.yml` split and wiring, with the template-pattern cases and the wiring assertions for it; (3) the four pack `ci.yml` files, `packs.yml` and the drift count, with the per-pack cases and wiring assertions; (4) the docs, last, so no doc claims a check that does not exist yet. (1) to (3) land before PBI-1.14's build PRs, so its expected per-pack trees include `.github/scripts/` and the new pack `ci.yml`, its tidy step keeps `.github/scripts/`, and its setup-PR wait (step 15) already includes the check. PBI-1.14 also gains the end-to-end item above.

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

- **[DONE] PBI-1.18** (2026-10-23, PR #178: option 1, 4 shards per OS leg; Adam, 2026-10-23: intent approval not needed. Windows leg measured on #178's runs: 23.3, 22.7 and 19.1 min, against about 73 before; the check `bootstrapper-test` keeps its name and fails when a shard is missing or a test ran twice or not at all. Earlier note: Clead, 2026-10-18, on Adam's request; the WHAT is Adam's wish for a faster Windows check, the HOW is Clead's) — Shorten the Windows leg of `bootstrapper-test`.

  **Why.**
  Every pull request that touches the bootstrapper waits for the Windows leg of `bootstrap-project-test`, the slowest of the three OS legs. From the timestamps in the logs of the last completed run (head `020a3f5`, run 39070866362): the test step took 18.9 min on ubuntu, 24.3 min on macOS and 72.5 min on Windows. In that run all 294 tests were slower on Windows (median ratio about 14 times); the 15 slowest tests were only 32% of the Windows total, so no single test explains it. A Windows leg of 70 to 76 minutes was seen on #175 and #176.

  **Cause, as far as measured.**
  Counting process launches (`execve`) on Linux for three slow tests gave 1,933, 2,791 and 8,991 launches. Dividing their Windows times by those counts gives 36, 28 and 24 ms per launch, roughly constant across tests with different command mixes (Linux: about 2 ms). So the time follows the number of processes started. Contributors seen in the harness: each test runs the real script through many small commands (`grep`, `mktemp`, `tr`, `rm`, `cat`); `fake_tool` puts a bash wrapper in front of every `git` call (it starts bash, logs, then execs the real `git`); the "every guide says why, how, what you see…" test alone launches `grep` 2,106 times and `mkdir` 2,031 times. Not measured: why a launch costs more on Windows (Git Bash's process emulation is the usual suspect), and the Windows runner itself.

  **Options.**
  1. Shard the Windows leg (or all legs) into 3 or 4 parallel jobs by test index, for example `BOOTSTRAP_TEST_SHARD=i/n` read by `bootstrap/test-bootstrap-project.sh`. No test changes. Expected wall time about 20 to 25 min for Windows if the shards balance (an estimate, not measured). Costs more runner minutes, not more total time. Things to settle: the one-off cost of building the bootstrapper in each shard; the required check `bootstrapper-test` must stay one aggregate check named as today and must fail if any shard fails or is missing; a test that proves the shards together run every test exactly once.
  2. Cut process launches in the harness: replace the `git` wrapper with something cheaper, use shell builtins instead of `tr`, `cat` and `rm`, batch the `grep`s in the guide test. Payoff real but unmeasured, more work, and it touches many tests.
  3. Both, option 1 first.

  **Done when.**
  - The Windows leg of a pull request that changes the bootstrapper finishes in 30 min or less on the same kind of runner, measured from the check-run timestamps of at least two runs.
  - `bootstrapper-test` still has the same name, still requires all OS legs, and still fails when any shard fails or does not run.
  - A check, red before the change, proves that no test is skipped or run twice across the shards.

  **Rules that apply.**
  A change to the workflow or the harness is code and config: test-first, reviewed by the role that did not write it (an Opus reviewer). It does not need Adam's intent approval unless the required check's name or meaning changes.

- **[DONE] PBI-1.22** (2026-10-27: #227 shards by duration, #228 matrix only when a PR touches what the tests read (Adam's intent approval 2026-10-27), #224 and #225 fewer processes in the harness (Adam allowed the helper tests 2026-10-27), #233 refreshed durations, #234 a flake fix; measured below. Earlier note: Clead, 2026-10-27, on Adam's request of 2026-10-26, from the product office (PO-58); the WHAT is Adam's, the HOW is Clead's) — Make the template's CI faster without losing coverage.

  **Result (job timestamps, minutes; merged-state runs 40466996231, 40469146376, 40480220727 against the baseline above).** A pull request that changes only files no test reads now finishes `bootstrapper-test` in under half a minute (run 40466863089: 17 s), instead of 18 to 37 min and 120 to 135 runner-minutes. For a code pull request: wall time 19.8 / 19.8 / 40.4 (the last with 26 min of queue behind other PRs); longest shard ubuntu 5.8 / 5.4 / 5.8 (was 6.3 to 7.5), macOS 9.0 / 8.3 / 9.0 (was 9.9 to 13.0), Windows 17.9 / 19.2 / 19.0 (was 17.2 to 23.2); Windows shard sums 60.1 / 65.1 / 70.2 (was 64.3 to 75.7). On Windows the gain is within the run-to-run spread of about ±7 min, so it is not shown; ubuntu and macOS shards are even. On Linux the harness starts 22,120 fewer processes (130,906 to 108,786) plus 8,564 fewer in the every-guide test, which on Windows went from about 170 s to 22 s. Next lever, not done: forks in the script under test (`api_call`'s `mktemp`/`tr`/`rm`), which a fit of the Windows times puts at about 36 ms each.

  **Why.** A Bootstrapper run takes 18 to 37 min wall time; the Windows shards take 13 to 23 min each and are split unevenly; queue waits reach 15 min when several PRs run; doc-only PRs (#215, #216) ran the full three-OS matrix. PBI-1.18's option 2 (cut process launches in the harness) was never done, only the sharding of #178.

  **Baseline (from job timestamps, minutes; runs 40411892511 / 40408171782 / 40404043345).** Wall time of the run 17.9 / 19.2 / 36.9. Per OS, longest shard run time and sum of the four shards' run times: ubuntu 6.3/7.5/7.5, sum 17.2/19.4/21.2; macOS 10.2/9.9/13.0, sum 35.1/33.7/35.1; Windows 17.2/18.8/23.2, sum 64.8/64.3/75.7. Run 40404043345 had queue waits of up to 12 min per shard.

  **Scope (Adam, 2026-10-26), in this order, each part as its own PR or PRs.**
  1. Part 4, the main lever: make the tests faster. Measure process launches per test on Linux, rank the tests, and cut launches in the biggest hot spots a few per PR (a cheaper `git` stand-in, builtins instead of external commands, batching repeated `grep`/`mkdir`). Same tests, same assertions, passing on ubuntu, macOS (bash 3.2) and Windows.
  2. Part 2: split the shards by measured duration instead of evenly, keeping the guarantee that every test runs exactly once across shards and that `bootstrapper-test` fails when a shard is missing.
  3. Part 1: run the three-OS matrix only when a PR touches something the tests read, while `bootstrapper-test` still reports on every PR. The path list comes from what the tests actually read (some read `README.md` and docs), with a test that fails if a file the tests read is outside the list. If this cannot be done without changing the required check's meaning, it stops for Adam's intent approval instead of merging.
  4. Part 3, a working practice: batch doc-only changes; one line with the measured cost in `docs/NEXT_SESSION.md`, "Test and CI lessons to keep".

  **Done when.**
  - A before/after table (Adam's request) from job timestamps: for the baseline and for at least two Bootstrapper runs of the final merged state, the run's wall time and, per OS, the longest shard's run time, the longest shard including its queue wait, and the sum of the four shards' run times; plus the per-test launch counts before and after for the top 10 hot spots.
  - Every test that ran before still runs, with the same assertions, on all three OS legs.
  - `bootstrapper-test` keeps its name and meaning.

  **Rules that apply.** Harness, test and workflow changes are code and config: test-first (red run in the PR), reviewed by Crog on Opus. A change to the name or meaning of the required check `bootstrapper-test` needs Adam's intent approval.

- **[DONE] PBI-1.25** (done 2026-11-03: part 1 #328 and part 2 #329 merged; parts 3 and 4 dropped by Adam the same day, after measurement showed small gains; Adam, 2026-10-29, from a product office session; Adam chose Clead's recommendation; `NEXT` and in the unattended batch the same day (Adam, on Clead's recommendation); the WHAT is Adam's, the HOW is Clead's; not yet specced or reviewed) — Make the template's CI cost less per change, without loosening the testing requirement. Follows PBI-1.22.

  **Why (Adam, 2026-10-29).** Even the smallest change to the template runs a lot of testing. The requirement on testing stays as strict as it is; the process gets more efficient.

  **Measured (an analysis agent on Opus, 2026-10-29, read-only; the per-test dependency counts come from a static scan of `bootstrap/test-bootstrap-project.sh` and are estimates).**
  - The repo is public, so runner minutes are not billed (run 40855454812 shows 0 billable ms). The cost is waiting: a full `bootstrapper-test` took 23.5 to 25 min in runs 40777072695, 40755402152 and 40740684097, and the slowest Windows shard sets that time.
  - Selection is all or nothing (`bootstrap/changed-inputs.sh`): the matrix is skipped only when every changed file is in `bootstrap/not-read-by-tests.txt` (8 files). Any other change runs all 388 tests on ubuntu, macOS and Windows. PR #277 changed `README.md` and `bootstrap/stubs/README.md`, which about 58 tests read.
  - 63 of the 388 tests have no entry in `bootstrap/test-durations.txt`, so the duration split weights them at the median.
  - Windows takes about 7.7 times as long as ubuntu per test. The 50 slowest Windows tests take 66% of the Windows total.
  - Each new push to a PR cancels the running Bootstrapper run: on #277, 4 runs were cancelled, about 240 job-minutes.

  **Scope (Clead's recommendation, chosen by Adam), in this order, each part as its own PR or PRs.**
  1. Rebalance the shards. Add the missing durations and give each OS the number of shards its total needs (Windows more than ubuntu). Expected: wall time about 12 min instead of about 24 for every PR, at about the same total runner time.
  2. Run `ci.yml` and `packs.yml` on pull requests and on pushes to `main`, not on every branch push, which runs them twice per push today (about 3 Linux minutes each time).
  3. Per-test selection. Record mechanically which files each test reads (as PBI-1.22 part 1 did per file), run on all three OS legs only the tests that read a changed file, and run the whole suite when the record is out of date and at every `v*` tag. A test fails when a test reads a file that the record does not list. Expected for a change like #277: about 3 to 4 min instead of about 24.
  4. Speed up the 50 slowest Windows tests: fewer processes, shared fixtures where state cannot leak between tests. Expected: 20 to 30% off the Windows total.

  **Not done, because it would loosen the requirement or cannot work here.** Running macOS and Windows only for "OS-sensitive" files (text handling differs between the systems, as the line-ending tests show). A merge queue (it needs GraphQL, which sessions cannot use, so merges by Crog would break).

  **Order (Adam, 2026-10-29, on Clead's recommendation).** It does not wait for the end-to-end runs: it changes CI, the tests and the shards, none of which ship in the bootstrap script, so it does not change what the runs test. It is part of the unattended batch (product office `DECISIONS.md`, 2026-10-29). Parts 1, 2 and 4 go ahead; part 3 goes ahead once Adam has approved its spec.

  **Done when.**
  - A before/after table from job timestamps, as in PBI-1.22: wall time, and per OS the longest shard and the sum of shard times, for a doc-only change that tests read (like #277) and for a script change.
  - Every test still runs on all three OS legs for every change it reads, and the full suite runs at every `v*` tag.

  **Part 1 (Crog agent, PR #328; ubuntu 4, macOS 5, Windows 8 shards, durations for all tests).** Windows leg wall time 23.2 min to 12.5 min. Still open for "Done when": the before/after table for a doc-only change that tests read (like #277) against a script change; today every change runs all tests, so both look the same until part 3.

  **Progress 2026-11-03 (Clead, unattended batch).** Part 2 merged: #329 (`30abdee`), CI and the pack checks run on pull requests and pushes to `main` only; the first push to `main` after it started both. Part 1 merged: #328 (`f4e8335`). Both reviewed by an Opus agent in the Clead review role and approved (#328 in round 2; its red run is a local one, reproduced by the reviewer, since the CI red run was cancelled by the next push). Part 4 is being built. Part 3's spec was written (#334) and showed per-test selection saves about 7% on most changes, since 139 of the 402 tests read almost every file; Adam dropped part 3 on 2026-11-03 (22:41, in chat), on Clead's recommendation, and #334 was closed unmerged.

  **Part 4, measured 2026-11-03 (Crog agent; no PR, nothing changed).** Process counts per test on Linux (strace, execve and fork) for the slowest Windows tests: 62 to 79% of the processes are started by the bootstrap script under test (`bootstrap/stubs/bootstrap-project.sh`), not by the tests or their stand-ins; in the slowest test, `mktemp`, `tr -d '\r'` and `rm` inside the script are 39% of all processes. Within part 4's scope (tests and harness only) the estimate is 3 to 6% off the Windows total, not 20 to 30%: fixtures cannot be shared (the slow tests change state across failure modes), and dropping the fake git's logging would let tests that assert absence pass for no reason. Windows seconds per process were not measured, only Linux counts. The 20 to 30% would plausibly come from replacing those calls with bash builtins in the script, which changes shipped code and so what the end-to-end runs test; that is outside PBI-1.25. Dropped by Adam, 2026-11-03 20:54 (in chat), on Clead's recommendation: part 4 is not done, and the script change does not become a PBI of its own.

  **Rules that apply.** Harness, test and workflow changes are code and config: test-first (red run in the PR), reviewed by Crog on Opus. Part 3 changes which tests the required check `bootstrapper-test` runs, so it needs Adam's intent approval of its spec before it merges.

- **[DONE] PBI-1.26** (done 2026-11-04: PR 1 #337, `09a198a`, and PR 2 #340, `9f9167d`, merged; Adam, 2026-10-29, from a product office session; Adam chose Clead's recommendation; the WHAT is Adam's, the HOW is Clead's; specced in PR #333, Adam's intent approval 2026-11-03 recorded there) — Exclude macOS as a supported platform for now, keeping the macOS code working so it can come back (PBI-1.27).

  **Why (Adam, 2026-10-29).** Mac users are out of scope for now. Facts behind it (Clead, checked 2026-10-29): the macOS leg does not set CI's wall time (the slowest Windows shard does), but it has failed runs when GitHub had no free macOS runner (PR #197 on 2026-10-26; run 40716513430, three full attempts). On macOS, the Claude desktop app and Claude Code need macOS 13 or later, and Node.js 24 needs 13.5 or later (code.claude.com/docs/en/setup, support.claude.com article 10065433, Node's v24.x `BUILDING.md`).

  **Scope (Clead's recommendation, chosen by Adam).**
  1. The way in closes: on a real Mac (`uname -s` is `Darwin`), the setup script stops at once with a plain message that macOS is not supported, before it changes anything.
  2. The macOS code stays and is maintained: the macOS branches of the script (the Homebrew and bash guides among them) and their tests, which already fake `uname` and so keep running on the other OS legs. New script changes keep them passing, as for Linux and Windows.
  3. bash 3.2 compatibility stays and is checked: a CI leg runs the suite under bash 3.2 on Linux. First check that bash 3.2 builds and runs there; if it cannot, this part stops for Adam.
  4. The macOS leg leaves the Bootstrapper matrix and `check-shards.sh`, and the macOS steps leave the README, the stub README and the docs, which say macOS is not supported.
  5. The end-to-end run plan (`docs/NEXT_SESSION.md`, Adam's to-do 2, run 3) no longer names macOS (done 2026-10-29: Adam moved run 3 to Windows).
  6. The removal is one PR, so its diff is the exact list for PBI-1.27.

  **Not covered while macOS is out.** Behaviour only a real Mac shows, mainly where Apple's command-line tools differ from Linux's. PBI-1.27 finds it when the macOS leg returns.

  **Order (Adam, 2026-10-29, on Clead's recommendation).** It does not wait for the end-to-end runs: it changes nothing on Windows or Linux, where the runs now take place. It is part of the unattended batch (product office `DECISIONS.md`, 2026-10-29); its spec still needs Adam's intent approval.

  **Open (for the spec).** How it fits PBI-1.25 part 1 (shards per OS). Answered in the spec, item 6.

  **Rules that apply.** Script, test and workflow changes are code: test-first (red run in the PR), reviewed by Crog on Opus. Removing the macOS leg changes what the required check `bootstrapper-test` covers, so the spec needs Adam's intent approval.

  **Spec (Clead's spec writer agent, 2026-11-03, PR #333; waiting for Adam's intent approval; checked on main at `59a6536`).** Anything marked "proposal" is Clead's, not decided; Adam can change it.

  **In plain words (for Adam).**
  - **What a Mac user sees.** Someone who starts the setup on a Mac gets a short message straight away: this computer runs macOS, which the setup does not support for now; nothing was changed; use a computer with Windows or Linux instead. Nothing is created on GitHub or on the Mac. The READMEs say the same before anyone starts.
  - **What stays maintained.** The parts of the setup written for Macs (how to install git, gh and Node.js on a Mac, and the check of the older bash that Macs come with) stay in the script. Their tests keep running on every change, on Linux and Windows, which pretend to be a Mac for those tests. The older bash (version 3.2) stays supported, and a new test run on Linux uses exactly that version.
  - **What is no longer covered.** Nothing is tested on a real Mac any more. A problem that only a real Mac shows, mainly where Apple's own command-line tools behave differently from Linux's, is not found until macOS comes back (PBI-1.27). The checks also stop waiting for GitHub's Mac machines, which have made runs fail when none was free.

  **For the implementer.**

  1. **Two PRs, in this order.**
     - **PR 1, the bash 3.2 leg** (scope 3): added while the macOS leg is still there, so bash 3.2 is never untested. It stays when macOS returns, so it is not part of the list for PBI-1.27.
     - **PR 2, the removal** (scope 1, 2, 4, 6): the stop, the macOS leg out, and the README and doc lines, in one PR. The stop and the leg cannot be split: the whole-run tests on the real macOS runner see the real `uname` (`Darwin`), so with the stop in place every one of them would stop there and the macOS leg would fail. PR 2's diff, apart from the stop and its tests, is what PBI-1.27 puts back; PBI-1.27 removes the stop and its tests (its scope 1).
     - PR 2 waits for PR 1 to be merged. If PR 1 stops for Adam (item 4), PR 2 waits for him too, since it would remove the only bash 3.2 check (proposal; question 5 in item 12).

  2. **The stop on a real Mac (PR 2, scope 1).**
     - **Where.** A new function `stop_on_macos` in `bootstrap/stubs/bootstrap-project.sh`, called in `cmd_setup` straight after `detect_os`, before `check_options`, `show_colour_key` and every `preflight_*`. All three ways in reach it: the plain command, `--again` (`main` runs `read_again`, then `cmd_setup`) and `--resume`. The name does not start with `guide_` or `refuse_`, so `test_template_readme_lists_every_guide_in_its_group` does not ask for it in the README's list of guides; the README says it in step 0 instead (item 7).
     - **What runs before it, and changes nothing.** `catch_stops` (a temporary folder under `TMPDIR`, deleted on the way out by `leave_script`); `parse_args` (reads the options; `--help` and `--version` print and exit 0, so they still work on a Mac, and a mistyped option stops first with its own message, exit 2); the piped-into-bash check; `remember_command` (in memory only); for `--again`, `find_again_dir` and `read_again` (read only). `fail` does not call `save_again`, so no `--again` file is written or changed. Nothing touches GitHub, the target folder or a copy of a project.
     - **How.** `[ "$OS_KIND" != macos ] || fail 1 "$MACOS_WHAT" "$MACOS_NEXT"`, with the two texts as variables next to the other shared texts (after `fail`), so the tests compare them whole. Exit 1, "failed or stopped" in the header comment (proposal): exit 3 promises the command to start again, which does not help on a Mac. No command to start again is shown, and no colour key (it comes later).
     - **The message (proposal; question 2 in item 12).** On stderr, as every stop, through `show_error`:

       > What happened: This computer runs macOS, which the setup does not support for now. Nothing was changed.
       > What to do next: Set up the project on a computer with Windows or Linux. Step 0 of the README says how to prepare it.

       It passes the banned-word check (`banned_hits`).
     - **Not stopped (proposal; question 6 in item 12).** The `layout-pack` subcommand: it is not the setup, no README sends a user to it, and `tools/test-layout-pack.sh` runs it. `uname` values other than `Darwin` (`OS_KIND=other`, for example FreeBSD) are unchanged: outside scope.
     - **No way around it.** No option and no test hook skips the stop: a hook could be set by a user as well. No test needs one: checked on main, no test runs the whole script (`whole`) with a faked `Darwin`; the macOS tests load the functions (`pre`) and call them one at a time.

  3. **The macOS code and its tests stay and keep passing (PR 2, scope 2).**
     - **Unchanged in the script:** the `Darwin` branch of `detect_os`; the macOS branches of `guide_bash_old` (`/bin/bash`), `guide_git` (Apple's command line developer tools, `xcode-select --install`), `gh_install_steps` (Homebrew, or the cli.github.com download) and `guide_npm_missing`; the offered commands `xcode`, `brew-gh` and `brew-gh-upgrade`; the comments on how macOS behaves (`/var` is `/private/var`, no `sed -i`, bash 3.2); the two line-ending messages that say "(as on macOS and Linux)", which describe line endings, not a supported platform, and are shown on every system (proposal).
     - **Unchanged tests** (they fake `uname` as `Darwin` through `on_os` or `fake_tool`, and so run on every leg that is left): `test_non_interactive_prints_the_guide_and_exits_3_without_waiting`, `test_an_offered_command_runs_after_yes_through_the_runner`, `test_answering_no_or_nothing_to_an_offer_runs_nothing`, `test_the_yes_to_an_offer_is_read_from_the_terminal_not_from_stdin`, `test_the_yes_option_does_not_approve_an_install`, `test_a_command_is_offered_once_per_check`, `test_an_accidental_no_is_offered_again_and_a_yes_then_runs_it`, `test_answering_no_every_time_reads_input_on_every_round`, `test_a_command_that_ran_is_offered_again_only_after_enter`, `test_not_run_says_where_to_run_the_command`, `test_each_offered_command_is_the_one_shown_in_the_guide`, `test_the_git_and_gh_guides_on_windows_have_you_type_q_first`, `test_no_offer_without_brew_or_winget_and_never_on_linux`, `test_the_npm_guide_on_macos_and_windows_keeps_its_steps`, `test_every_guide_says_why_how_what_you_see_and_how_it_is_checked`, `test_the_os_is_read_from_uname_and_the_linux_release_file` and `test_wsl_is_read_from_the_kernel_release_on_linux_only`. Because `pre` runs `detect_os` and then the function, never `cmd_setup`, they also guard the place of the stop: put inside `detect_os`, it would fail them.
     - **New script changes** keep these tests passing, as for Linux and Windows; the review checks that a change to a guide changes its macOS branch where the other branches change.

  4. **The bash 3.2 leg on Linux (PR 1, scope 3).**
     - **First check, done locally (2026-11-03, this spec writer, not on a GitHub runner).** In this cloud session (Ubuntu 24.04.5, gcc 13.3.0; whether the `ubuntu-latest` runner image has the same gcc was not checked): GNU's `bash-3.2.57.tar.gz` from https://ftp.gnu.org/gnu/bash/ downloaded, `./configure --without-bash-malloc` and `make` both succeeded (with compiler warnings); the built bash reports `GNU bash, version 3.2.57(2)-release (x86_64-unknown-linux-gnu)`, `BASH_VERSINFO` 3.2, and arrays and `${var//a/b}` work. The build without `--without-bash-malloc` was not tried. The whole suite, `bootstrap/test-bootstrap-project.sh` at `7901762` (main's `59a6536` plus an empty commit), started with that bash and with it first on `PATH`, as two shards (`BOOTSTRAP_TEST_SHARD` 1/2 and 2/2, ubuntu's weights): 202 and 200 passed, 0 failed, 0 skipped, so all 402 tests. What ran on 3.2: the harness and the script under test, which the harness starts with `"$BASH"`, the bash running the harness. Not on 3.2: a plain `bash` started inside a test run, since `in_env` sets `PATH` to `$d/bin:$GIT_ONLY_DIR:/usr/bin:/bin`, where `/usr/bin/bash` is the runner's own bash (5.x on ubuntu). On a Mac that `bash` is `/bin/bash`, itself 3.2; on the Linux leg it is not. The script under test runs on 3.2 either way, which is what scope 3 asks.
     - **First check on the runner.** PR 1's first CI run is that check. If bash 3.2 does not build or the suite cannot run under it on `ubuntu-latest`, PR 1 stops there for Adam (scope 3), with what failed recorded on the PR and in `docs/NEXT_SESSION.md`. A test that fails under bash 3.2 because the script or a test uses something newer than 3.2 is a real finding: it is fixed test first, in its own PR, before PR 1 merges.
     - **The build (proposal).** A new template-only script, `bootstrap/bash32.sh <folder>`: downloads `bash-3.2.57.tar.gz` from https://ftp.gnu.org/gnu/bash/, and from https://ftpmirror.gnu.org/gnu/bash/ (GNU's mirror redirector; it answered here with a redirect) when the first fails; refuses (with an `::error::` line, exit 1, nothing left in `<folder>`) unless the file's SHA-256 is the pinned value; builds it with `CFLAGS="-g -O2 -std=gnu89" ./configure --without-bash-malloc` and `make`; installs it as `<folder>/bash`; and fails unless that bash reports 3.2. Each failure says which it was: no download from either server, another hash, a failed build, or another version. The SHA-256 of the file downloaded here was `3fa9daf85ebf35068f090ce51283ddeeb3c75eb5bc70b1a4a7cb05868bfe06a4` (reproduced by Crog's review); it was not checked against GNU's signature (`bash-3.2.57.tar.gz.sig`), so the builder checks the signature before pinning it. `-std=gnu89`: bash 3.2.57 is pre-C99 code, and newer gcc versions turn its implicit function declarations into errors (gcc 14) or default to C23 (gcc 15); with gcc 13.3.0 here, the build succeeded both with and without it.
     - **Where the built bash comes from (proposal).** A cache saved by a pull request run can be restored only by later runs of that pull request; runs of any pull request can restore a cache saved on `main` (GitHub's documented cache scoping, as Crog's review states it; not re-read in this session). The Bootstrapper workflow never runs on `main`, so a cache it saves helps only the next pushes to the same PR. So: a new template-only workflow, `.github/workflows/bash32-cache.yml`, on pushes to `main` and `workflow_dispatch`, restores the key `bash-3.2.57-<pinned hash>-${{ runner.os }}-${{ steps.image.outputs.image }}-gcc${{ steps.image.outputs.gcc }}`, and on a miss runs `bootstrap/bash32.sh` and saves the bash under that key (`actions/cache/restore`, `actions/cache/save`), with the same `path` as the shards (the cache's version is made from `path`, so another path would make every restore a miss). The key's last two parts come from a step with `id: image` in both workflows, which reads `$ImageOS` (the runner's image name, for example `ubuntu24`) and `gcc -dumpfullversion` in the shell and writes them to `$GITHUB_OUTPUT` as `image` and `gcc`, and fails with `::error::` if either is empty. Not `${{ env.ImageOS }}`: the `env` context holds only variables the workflow sets, not those the runner inherits, so it is empty there (Crog's round 2, from GitHub's contexts reference). `bootstrapper.yml`'s triggers stay as `test_workflow_bootstrapper_runs_on_pull_requests_to_main_and_v_tags_only` pins them. The bash 3.2 shards restore the same key and build only on a miss. What the key detects: a change of the image's name (a new Ubuntu release) or of the gcc version builds again, so a build that a newer gcc breaks shows at once at "Get bash 3.2" instead of being hidden by an old cache. What it does not: any other change within the same image name and gcc version (glibc, other tools); the bash built on the older image is then reused until the cache is evicted. That bash still runs the whole suite, so a change that breaks running it still shows; one that would only break building it shows at the next miss.
     - **The cost, stated as it is.** On a miss, each bash 3.2 shard of that run downloads 2.5 MB and builds bash: about 2 minutes on 2 cores here, not measured on the runner. A miss happens before the first push to `main` after PR 1 (PR 1's own runs always build), after the cache has gone unused for GitHub's eviction period (documented as 7 days; not re-read here), and after a new image name or gcc version on the runner. Not checked yet: that a pull request run really restores the cache saved on `main`; the first PR after PR 1's merge shows it in its bash 3.2 shards' logs ("Cache restored"), and if it does not, Clead records it in `docs/NEXT_SESSION.md` and the leg keeps building on every run.
     - **A failed download is not a test failure.** Getting bash is its own step, "Get bash 3.2", before the test step; when it fails, its `::error::` line names the cause and the test step does not run, so the failing step's name and line say which it was. `bootstrapper-test` is red all the same (that shard did not succeed): the pull request waits until a re-run of the failed jobs, which works with the shard gate (#199 and #204).
     - **The matrix.** Each `include:` entry gets a `leg` field, first, in the one-line form `- { leg: <leg>, os: <os>, shard: <i>, of: <n> }`: `- { leg: ubuntu-latest, os: ubuntu-latest, shard: 1, of: 4 }` and so on, and the new leg `- { leg: ubuntu-bash32, os: ubuntu-latest, shard: <i>, of: <n> }`. `runs-on` stays `${{ matrix.os }}`; the manifest becomes `shard-list/${{ matrix.leg }}-${{ matrix.shard }}-of-${{ matrix.of }}.txt` and the artifact `bootstrap-tests-${{ matrix.leg }}-${{ matrix.shard }}`, so the two Linux legs do not collide; `BOOTSTRAP_TEST_WEIGHTS` stays `bootstrap/test-durations.txt:${{ matrix.os }}`, so the bash 3.2 leg is split by ubuntu's measured times. The call of `check-shards.sh` names the legs: `ubuntu-latest ubuntu-bash32 macos-latest windows-latest` (until PR 2). `check-shards.sh` itself needs no change: it judges whatever legs it is given, each by the count in its manifests' names.
     - **The steps.** `if: matrix.leg == 'ubuntu-bash32'`: "Get bash 3.2" restores the cache or runs `bootstrap/bash32.sh`; the test step puts that folder first on `PATH`, prints and checks the version, and runs `bash bootstrap/test-bootstrap-project.sh`, so the harness and the script under test (started with `"$BASH"`) run on 3.2, as the macOS step does with `/bin/bash`; a plain `bash` inside a test run is the runner's own (item 4, first check). The step for the other legs gets the condition `if: runner.os != 'macOS' && matrix.leg != 'ubuntu-bash32'` (in PR 2: `if: matrix.leg != 'ubuntu-bash32'`).
     - **Not changed.** `bootstrap/test.sh` and the other scripts' tests stay on ubuntu's own bash (`scripts-test`). `docs/NEXT_SESSION.md` (S5) records that a bash 3.2.57 run of `bootstrap/test.sh` failed `test_publish_second_release_mirrors_output_and_keeps_history`; that is outside this PBI.

  5. **The macOS leg leaves (PR 2, scope 4).**
     - **`.github/workflows/bootstrapper.yml`:** the five `macos-latest` lines of `include:`; the step "Test bootstrap-project.sh with macOS /bin/bash 3.2"; `runner.os != 'macOS'` in the other step's condition; `macos-latest` in the call of `check-shards.sh`; the header comment ("macOS (Apple's /bin/bash 3.2)", "5 on macOS"), which then names the bash 3.2 leg instead.
     - **`bootstrap/test.sh`:** `test_workflow_macos_bash_check_passes_on_3_2_and_fails_on_5` and `test_workflow_macos_leg_runs_the_tests_with_bin_bash_3_2` are removed (PBI-1.27 takes them back from the diff); the lists of legs in `test_workflow_matrix_cannot_drop_an_os`, `test_workflow_bootstrap_project_tests_run_on_ubuntu_macos_and_windows` (renamed for the legs it checks), `test_workflow_every_os_leg_is_sharded_and_records_what_it_ran`, `test_workflow_shard_counts_keep_every_legs_slowest_shard_short`, `gate_fixture` and `test_workflow_bootstrapper_test_fails_when_a_shard_or_leg_did_not_report` become ubuntu-latest, ubuntu-bash32 and windows-latest; a new test fails while the matrix has a `macos-latest` leg.
     - **The durations (proposal).** `bootstrap/test-durations.txt` keeps its `macos-latest` column and `bootstrap/durations-from-logs.sh` keeps reading macOS logs, for PBI-1.27's first split. `test_durations_file_has_a_time_for_every_test_on_every_os` checks the columns of the legs in the matrix only: without macOS logs, a test added later has 0 there, which the harness weighs as the median. New tests' times are added as lines to the existing file, as in #328, not by running `durations-from-logs.sh` over the whole file again: that writes all three columns and puts 0 wherever it has no log, so a full regeneration without macOS logs would set the whole macOS column to 0. The tests over every column (`test_harness_shards_by_duration_*`) are unchanged.

  6. **Shards, and how it fits PBI-1.25 part 1 (the "Open" item).** Part 1's counts stay for the legs that stay: ubuntu 4, Windows 8. macOS's 5 shards go with its leg. The bash 3.2 leg follows part 1's rule, `test_workflow_shard_counts_keep_every_legs_slowest_shard_short` (the slowest shard at most 660 s of tests by the durations): by ubuntu's column that gives 4 shards, as for ubuntu (ubuntu's column sums to 1865 s, about 466 s a shard; the test computes the actual split). The leg's times under bash 3.2, and the time to restore or build bash on each shard, are not measured: after PR 1's first green run the builder compares its slowest shard with ubuntu's, and gives it more shards in the same PR if it is above about 12 min wall time. Wall time stays set by Windows (about 12.5 min after part 1). Runner time: the macOS shards (52.8 min summed in part 1's after-run) go; the bash 3.2 leg adds about ubuntu's (27.9 min) plus the bash build. PBI-1.25 part 3 (spec in PR #334) speaks of "all three OS legs": after this PBI those are the legs of the matrix, ubuntu, the bash 3.2 leg and Windows; said on #334.

  7. **README and doc lines (PR 2, scope 4).**
     - **`README.md`, step 0** (inside the part the build copies into the bootstrapper's README): the bullet "**macOS:** open the Terminal app. If you have Homebrew, run `brew install gh`; otherwise open https://cli.github.com, click Download for Mac, open the downloaded file and follow the installer." becomes "**macOS:** not supported for now: the setup stops on a Mac. Use a computer with Windows or Linux." (proposal; question 3 in item 12, which covers every new README line here).
     - **`README.md`, "What the script guides you through":** "a bash that is too old (Windows: install the current Git for Windows; macOS: use /bin/bash);" becomes "a bash that is too old (Windows: install the current Git for Windows);". The phrase `test_template_readme_lists_every_guide_in_its_group` looks for ("a bash that is too old") stays.
     - **`bootstrap/bootstrapper-README.md`:** "**A computer** with Windows, macOS or Linux." becomes "**A computer** with Windows or Linux. macOS is not supported for now: the setup stops on a Mac."; "**On macOS and Linux: Git.**" becomes "**On Linux: Git.**".
     - **`bootstrap/stubs/README.md`,** the setup section, so that it too says macOS is not supported (scope 4 names the stub README): "in Git Bash (Windows) or a terminal (macOS, Linux)" becomes "in Git Bash (Windows) or a terminal (Linux; the setup does not support macOS for now)" (proposal; the wording is question 3 in item 12). It stays one line of text, so the section stays three lines (`test_stub_readme_setup_section_is_three_lines_with_the_resume_command`). It ships.
     - **`docs/NEXT_SESSION.md`,** the "CI shape" line (macOS about 26 min) loses the macOS figure; the history entries stay as they are.
     - **Not changed (proposal; question 4 in item 12):** `languages/python/code-standards.md` and `docs/DEV_INFRASTRUCTURE.md` (`# macOS / Linux` before the venv commands), and the Xcode notes in `languages/react-native/code-standards.md` and `docs/DEV_INFRASTRUCTURE.md`: they are about working in a project after the setup, not the setup, and they are true. Nor are the history in this backlog, `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, or the comments in `bootstrap/e2e-check.sh` and the tests that say they run on bash 3.2.

  8. **One removal PR, the list for PBI-1.27 (scope 6).** PR 2 holds nothing else. Its description lists every file it changes and, for each, what PBI-1.27 puts back and what it drops (the stop and its tests). Once it has merged, a backlog PR adds its number to PBI-1.27's scope 2 and 3. The release after PR 2 carries the stop to users; until it is tagged, v2.8.5 still runs on a Mac, untested.

  9. **Test first.** Each PR has a test commit first, with its red run (CI, or a local run the reviewer reproduces, as for #328), then the change; reviewed by the role that did not write it (Crog on Opus for a Clead change).
     - **PR 1, in `bootstrap/test.sh`:**
       - `wf_legs` prints one `<leg> <os> <shard> <of>` line per entry of the form `- { leg: <leg>, os: <os>, shard: <i>, of: <n> }` (sed: `s/^          - \{ leg: ([a-z0-9-]+), os: ([a-z0-9-]+), shard: ([0-9]+), of: ([0-9]+) \}[[:space:]]*$/\1 \2 \3 \4/p`), and its comment says so.
       - Its users follow the new fields: `test_workflow_matrix_cannot_drop_an_os` (field 1, the leg; ubuntu-bash32 added to its list); `test_workflow_shard_counts_keep_every_legs_slowest_shard_short` (loops over legs, takes the count from field 4, and weighs each leg by its `os` column, field 2); `test_workflow_every_os_leg_is_sharded_and_records_what_it_ran` (per leg; the include-line pattern becomes the form above; the manifest is pinned as `shard-list/${{ matrix.leg }}-${{ matrix.shard }}-of-${{ matrix.of }}.txt` and the artifact as `bootstrap-tests-${{ matrix.leg }}-${{ matrix.shard }}`); `test_workflow_bootstrap_project_tests_run_on_ubuntu_macos_and_windows` (the legs are exactly ubuntu-latest, ubuntu-bash32, macos-latest, windows-latest; `runs-on` still `${{ matrix.os }}`); `test_workflow_shards_split_by_the_durations_of_their_os` (unchanged: weights by `matrix.os`).
       - `test_workflow_macos_leg_runs_the_tests_with_bin_bash_3_2`: its search for the other legs' step matches `if: runner.os != 'macOS'` exactly; it changes to the new condition, `if: runner.os != 'macOS' && matrix.leg != 'ubuntu-bash32'`.
       - `gate_fixture` and `test_workflow_bootstrapper_test_fails_when_a_shard_or_leg_did_not_report` include ubuntu-bash32 manifests and a missing one.
       - New: the bash 3.2 test step puts the folder of "Get bash 3.2" first on `PATH`, checks for 3.2 and runs the suite with it; "Get bash 3.2" comes before it, restores the key above and runs `bootstrap/bash32.sh` only on a miss.
       - New, `bootstrap/bash32.sh` with fake downloads and a fake build (as the macOS step's test uses a fake `ln`): the first server fails and the mirror is used; both fail and the `::error::` line names the download; a file with another hash is refused with `::error::` and leaves no bash; a built bash that reports 5.2 fails; one that reports 3.2 passes.
       - New: `bash32-cache.yml` runs on pushes to `main` and `workflow_dispatch` only, and saves under exactly the key the bash 3.2 shards restore, with the same `path`. In both workflows the key holds `steps.image.outputs.image` and `steps.image.outputs.gcc`, from a step with `id: image` that comes before the cache step; neither workflow uses `env.ImageOS`. The `image` step's run block, run with `ImageOS` unset or a fake `gcc` that prints nothing, fails with `::error::`; with both set, it writes `image=` and `gcc=` lines to a fake `$GITHUB_OUTPUT`.
     - **PR 2, in `bootstrap/test-bootstrap-project.sh`:** `test_the_setup_stops_on_macos_before_it_changes_anything`: whole runs with `on_os "$d" macos` and the stub gh, for the plain command, `--non-interactive --yes` with every answer given, `--resume --owner o --name n`, and `--again` with a saved file: exit 1; stderr has exactly the two lines above; the stub gh and the fake git logged no call; the folder it ran in is empty; no `--again` file is written, and the saved one is unchanged; no colour key on stdout. `test_help_and_version_still_work_on_macos` (exit 0, their usual output). `test_the_macos_stop_is_not_shown_on_linux_or_windows` (the same `--non-interactive` run with `uname` `Linux` and `MINGW64_NT-10.0-19045` does not print it). A README test: the three READMEs (`README.md`, `bootstrap/bootstrapper-README.md`, `bootstrap/stubs/README.md`) each say that macOS is not supported for now, with the lines in item 7, and none of them has "brew install gh", "Download for Mac", "/bin/bash" or "Terminal app". The new tests get measured times in `bootstrap/test-durations.txt` from the PR's run, as in #328, since every test needs a time in each column the matrix uses. In `bootstrap/test.sh`: the changes in item 5.

  10. **Risks.**
     - Linux's bash 3.2 is GNU's, not Apple's: Apple's patches, and the BSD tools a Mac has (`sed`, `awk`, `mktemp`, `stty`, `dd`, `readlink`), are not covered. That is the "Not covered while macOS is out" above.
     - On a cache miss (item 4) the bash 3.2 leg needs ftp.gnu.org or a GNU mirror; while neither can be reached, `bootstrapper-test` fails at "Get bash 3.2" until a re-run. The cache filled on `main` and the mirror narrow this; they do not remove it.
     - A newer runner image with gcc 14 or 15 can break the build of bash 3.2.57. `-std=gnu89` is meant to prevent it; only gcc 13.3.0 was tried. The image's name and the gcc version in the cache key make such a break show at once (item 4, what the key detects).
     - On the Linux leg, a plain `bash` started inside a test run is the runner's bash 5, not 3.2 (item 4); on a Mac it was 3.2. So what a test starts as plain `bash`, other than the script under test, is no longer run on 3.2 anywhere.
     - The macOS branches can drift in ways the faked tests cannot see (a new guide step that only a real Mac would show to be wrong). PBI-1.27 finds it, with its human-run end-to-end run on a Mac.
     - The required checks keep their names (`bootstrapper-test`, `build`); only the matrix jobs' names change, and they are not required checks, so branch protection is unchanged. Not re-read from the protection settings here.
     - A Mac user who stopped part way with an earlier version cannot continue with the new one; `--resume` already refuses a project made by another version, so that is no new case.

  11. **Done when.**
     - On a faked `Darwin`, every way in stops with the message and changes nothing (the tests in item 9), on every leg.
     - The macOS tests in item 3 pass on every leg that is left.
     - `bootstrapper-test` is green with the legs ubuntu (4 shards), bash 3.2 on Linux (its count from item 6) and Windows (8), and `check-shards.sh` judges exactly those three.
     - The three READMEs say macOS is not supported for now, and a test pins it.
     - PR 2 is merged and its number is in PBI-1.27.

  12. **Open questions for Adam, each with the spec's recommendation** (all in one list, to answer in one go).
     1. **Intent approval.** Do you approve this spec? Removing the macOS leg changes what the required check `bootstrapper-test` covers. Recommendation: approve.
     2. **The message on a Mac** (item 2): "What happened: This computer runs macOS, which the setup does not support for now. Nothing was changed." and "What to do next: Set up the project on a computer with Windows or Linux. Step 0 of the README says how to prepare it." Recommendation: use these texts.
     3. **The new README lines** (item 7): the template README's step 0 bullet, its bash line, the two lines of the bootstrapper's README, and the stub README's line "in Git Bash (Windows) or a terminal (Linux; the setup does not support macOS for now)". Recommendation: use the lines in item 7.
     4. **What "not supported" covers.** Only the setup, or also working on a project on a Mac afterwards (the projects' `# macOS / Linux` commands in `languages/python/code-standards.md` and `docs/DEV_INFRASTRUCTURE.md`)? Recommendation: the setup only, and those lines stay.
     5. **If bash 3.2 cannot be built or run on GitHub's runner** (item 4), PR 1 stops for you (scope 3). Does PR 2, the removal, wait for you too? Recommendation: yes, since it would remove the only bash 3.2 check.
     6. **`layout-pack` on a Mac** (item 2). Does that subcommand stay usable on a Mac? Recommendation: yes; it is not the setup and no README sends anyone to it.

- **[DONE] PBI-1.32** (Adam, 2026-10-29, product office PO-64; the WHAT is Adam's, the HOW is Clead's; done 2026-11-02: `CLAUDE.md` "Both agents: reply format", reviewed by Crog) — The product office's "For you" rule in `CLAUDE.md`, so it reaches every bootstrapped project: every reply from a session ends with a "For you" block (each item marked Now, When you have time or Later; "For you: nothing" when there is nothing), and instructions for the product owner appear only there.

  **Why (Adam, 2026-10-29).** A code session's task list (steps with empty circles) read to Adam as choices he had to make. A "For you" block says plainly when something is for him. The product office owns the rule (its `CLAUDE.md`, "Reply format"); the template carries it to new projects, as with the ground rule against loose ends (product office PO-47).

  **Rules that apply.** A change to `CLAUDE.md` that carries out a rule the product owner has decided: reviewed by Crog.

- **[DONE] PBI-1.36** (done 2026-11-04: part 1 #348 `2b708e5`, part 2 #349 `0fd60ca`, part 3 #350 `b5d8932`, each with a Crog approval at its merged head and `build` and `bootstrapper-test` green there, merges verified through the API; Clead, 2026-11-04, from `docs/NEXT_SESSION.md` item 19, points 2 to 4: optional points B, C and D of Crog's review of #337, comment 6617962290; put in scope by Adam's night-shift instruction of 2026-11-04; the HOW is Clead's) — Harden the bash 3.2 leg of the Bootstrapper tests (PBI-1.26 PR 1): its shard guard, its pinned hash and its download. Three parts, each its own PR.

  1. **The shard-time guard covers the bash 3.2 leg.** Today the leg is split, and `test_workflow_shard_counts_keep_every_legs_slowest_shard_short` checks it, by ubuntu's column of `bootstrap/test-durations.txt`, and `test_workflow_bash32_leg_has_the_shards_its_measured_time_needs` pins a fixed floor of 8 shards that does not grow as tests are added. Measured (Clead, 2026-11-04, job logs of the run on #340's head `c79be7c`): the 8 bash 3.2 shards took 318 to 610 s of test time, each predicted at 233 s by ubuntu's column, so 1.36 to 2.62 times as long, and unevenly. How: a measured `ubuntu-bash32` column in the durations file, made from those logs by `bootstrap/durations-from-logs.sh` (which learns the leg); each shard is weighed by its leg's column (`matrix.leg`; the other legs are named as their OS); the shard-time test weighs each leg by its own column, so the 660 s rule holds for the bash 3.2 leg and fails when added tests need more shards; the fixed-floor test goes.
  2. **No test hook bypasses the pinned hash.** `BASH32_SHA256` lets an environment variable replace the hash in `bootstrap/bash32.sh`. It goes; the tests put a fake `sha256sum` (and `shasum`) first on `PATH`, as they already fake `curl`. A test shows that setting `BASH32_SHA256` no longer changes what is built.
  3. **Time limits on getting bash 3.2.** `curl` in `bash32.sh` has `--connect-timeout` but no `--max-time`, and the jobs that run it have no `timeout-minutes`, so a stalled download holds a shard until GitHub's default job timeout (6 hours). How: `--max-time` on each download, and `timeout-minutes` on the "Get bash 3.2" steps and on the jobs that run them (`bootstrap-project-test`, `bash32-cache`). The values and their reasons are in the PR.

  **Done when.** Each part is merged with a Crog approval at its merged head and a green `build` and `bootstrapper-test` on that head, each merge verified through the GitHub API; item 19 has its disposition.

  **Rules that apply.** Script, test and workflow changes are code and config: test first (red, then green), reviewed by a Crog agent on Opus. None changes which tests the required check `bootstrapper-test` runs, so no intent approval is needed (Clead's reading of the change execution model; part 1 changes how the bash 3.2 leg's tests are spread over its shards, not which run).

  **Done (2026-11-04, unattended).** Each part red in CI first (runs 41861041577, 41862143581, 41862656903, `scripts-test`), then green; each reviewed in round 1 by its own Crog agent on Opus (APPROVE, no required fixes; comments 6635347264, 6636174845, 6636321060); merged by a merge-only agent on Sonnet. Part 1: the bash 3.2 leg's slowest shard is 493 s of tests by its own column with 8 shards (was 610 s measured under ubuntu's split); the new split has not run on a runner yet, the first pull request run after #348 shows it. On #349's head `pack-web` failed once at `npx playwright install --with-deps chromium` (the runner's package install), outside the PR; its re-run passed. The reviews' optional points are in `docs/NEXT_SESSION.md` item 20.

- **[DONE] PBI-1.38** (Clead, 2026-11-06, from the design of the public Rules edition, whose intent the product owner approved on 2026-11-05; the HOW is Clead's; done 2026-11-06: (a) #363 `b0d4ee0`, (b) #364 `e977da7`, (c) #366 `d960e2e`, (d) #367 `d3c709a`, each with a Clead review approval at its merged head and `build` green there, merges verified through the API) — New projects get the Rules edition in `rules/` as their rule set, with a slim entry point and a `RULES.md` of local rules, and the old rule files stop shipping.

  **Status: Adam approved 2026-11-06** (in chat, 09:31: "I approve the intent of the template PBI-1.38 spec as written in #360.").

  **Why.** The edition (`bootstrap/stubs/rules/`, taken by its own PR) holds the rules that today are spread over `CLAUDE.md`, `memory/roles.md`, `memory/standards.md`, `docs/CROG_ONBOARDING.md` and `docs/ROUTINES.md`. Shipping both would give a new project two rule sets that differ. Each new project signs off to the edition by its setup PR (edition Process P-7 § 5).

  **Scope.**
  1. **New stubs.**
     - `bootstrap/stubs/CLAUDE.md`, the entry point: the title with `[PROJECT NAME]`; before any work, read `rules/RULES.md` in full, Process P-1 and carry out its startup, the processes the work needs, and `RULES.md`; Clead and Crog are the roles `rules/RULES.md` § 4 defines. Nothing else: no rule text.
     - `bootstrap/stubs/RULES.md`, the local rules: `L § 1 (C)` "This project is bound by the Rules in `rules/`, in the edition `rules/EDITION` names.", with the line "Adopted: the product owner, by the setup that created this project" (no PR number, so the setup leaves the file unchanged); `L § 2` names the project's files (backlog, decisions, `STATUS.md`, the staging file, `memory/`) and says that `§ n` and `P-n § m` refer to `rules/`; `L § 3` Clead reads `memory/context.md` at session start.
  2. **Stop shipping** (`bootstrap/manifest.txt`): the root `CLAUDE.md` (the stub replaces it), `memory/roles.md`, `memory/standards.md`, `docs/CROG_ONBOARDING.md`, `docs/ROUTINES.md` and `docs/decisions/0001-rebuild-workflow.md`. The template keeps them for itself until its own move to the edition.
  3. **What the edition points to, in the stubs.** The README stub names the product owner (edition § 4 (1)). The backlog stub's header is the format specification (P-9 § 2 (3)): the markers `NOW`, `NEXT`, `LATER`, `DONE` and `BLOCKED` (P-9 § 2 (2); today's stub also has `IDEA` and `SUPERSEDED`), and a section "Waiting for the product owner" (P-9 § 3 (1)). The `STATUS.md` stub's header is its format specification (P-9 § 6 (6)), with the blocker prefix "Product Owner:".
  4. **Pointers, not copies.** `docs/DEV_INFRASTRUCTURE.md`: rule text becomes pointers to Process P-11 by number; the how-to stays (a new machine, the starting files, the runbook the script cites, CI), and Part 2 is unchanged (the script edits it). `languages/*/code-standards.md`: lines that restate P-11 § 5 (2) become pointers. The README stub, the template README's shipped part, and the `memory/context.md` and `memory/decisions.md` stubs point to `rules/` and `RULES.md` instead of the files that stop shipping.
  5. **Tests, red first.**
     - `bootstrap/test.sh`: a build from the real tree contains `rules/EDITION` and passes `check-rules-edition.sh rules`; `CLAUDE.md` in the output is the stub; none of the files in 2 is in the output.
     - `bootstrap/test-bootstrap-project.sh`: the `[DATE]` token assertions on `roles.md` and `CROG_ONBOARDING.md` go; the "never touched by the setup" examples become `rules/RULES.md` and `rules/EDITION` (which also asserts that the setup leaves the edition alone); the expected-change rows add `RULES.md` and `rules/RULES.md` as not changed by the setup; the fill table keeps its `CLAUDE.md` row.
     - `bootstrap/e2e-check.sh` and its tests: a new `rules-edition` check runs the shipped script in the made project; the `roles.md` fixture goes.
     - `bootstrap/not-read-by-tests.txt`: updated where it names a removed file.

  **Out of scope.** The template's own `CLAUDE.md`, `memory/` files and staging file (its own move to the edition comes after this PBI); the edition's text (it is built elsewhere and only taken whole); a release.

  **Order and release.** This PBI is built after the edition PR and the edition step in the projects' CI, prepared together with them so that the edition PR merges only once these PRs are ready for review. From the edition PR's merge to this PBI's last merged PR, `main` ships two rule sets that differ, so no `v*` tag is created in that window; each PR in it leaves `build` green. Clead's proposed split, one fix each: (a) items 1 and 2 with their tests; (b) item 3; (c) item 4; (d) the `e2e-check.sh` check.

  **Done when.** A project made from `main` has `rules/` (passing its CI check), the stub `CLAUDE.md` and `RULES.md`, and none of the files in 2; every shipped file that pointed to a removed one points to `rules/` or `RULES.md` instead; the test suites are green on every leg.

  **Rules that apply.** Script, test and stub changes: test first, reviewed on Opus by the role that did not write them (process and rules content included); one PR per part. (Corrected 2026-11-06: the first wording named a Crog reviewer; Crog wrote the four PRs, so Clead review agents reviewed them.)

  **As built, beyond the scope above.** `L § 2` of the `RULES.md` stub also names `docs/SPEC.md`, the specification the edition's P-1 § 1 (2) names (#363). Part (c) also points the `docs/NEXT_SESSION.md` stub, the setup script's `fill_rows` comment and the five `code-standards.md` test-first lines to the edition, as "Done when" asks, and drops `..wrap` from the README and `memory/context.md` stubs (the edition has no stop word) (#366). The `roles.md` fixture in the e2e tests went in part (a), not (d), to keep the suites green (#363). The edition check in made projects' CI and the shipping of `check-rules-edition.sh` came with #361 and #358, before this PBI. Follow-ups: PBI-1.40.

- **[DONE] PBI-1.41** (Adam, 2026-11-06 16:40, a dated condition of the template's sign-off to the product office's Rules; due 2026-11-13; the HOW is Clead's; specced and approved 2026-11-06 21:03, amended 2026-11-07 07:41; done 2026-11-07: (a) #379, (b) #386 and #389, (c1) #393, (c2) #397, (d) #403. The Done-when is met in the form the approved spec gives it: lint and format fail `build`, coverage fails `bootstrapper-test` below 80% (94.2% at `bcd5056`), and `RULES.md` L § 7 (3) is replaced by the override that placement needs, not removed. Part (c3) and the review follow-ups moved to PBI-1.54) — `build` fails on lint, formatting and line coverage below 80% of this repository's own scripts, as P-11 § 2 (2) asks; until then `RULES.md` L § 7 (3) overrides it.

  **Scope.** A lint check (shellcheck) and a format check of the template's own scripts (`bootstrap/`, `tools/`, `.github/scripts/`), and a line coverage measurement of them under the existing test suites (kcov or bashcov; which one, and how it copes with the tests' subshells, `sh -c` and the Windows and bash 3.2 legs, is settled in the spec), then a gate at 80%. Measure first: where coverage is short, tests are added test first. Each tool is recorded under the third-party policy before it is used.

  **Done when.** `build` fails a PR whose scripts fail shellcheck or the format check, or whose line coverage of the template's own scripts is below 80%, with a red run shown for each; `RULES.md` L § 7 (3) is removed in the same PR or the next.

  **Rules that apply.** Script, test and CI changes: test first, reviewed on Opus by the role that did not write them; one PR per part.

  **Spec (Clead, 2026-11-06, PR #378; measured on `main` at `9241dab`).** Approved: Adam, 2026-11-06 21:03 ("Apyr"), as written, with the coverage gate in `bootstrapper-test` and the one-time reformat.
  - *Files.* Lint and format cover all 21 scripts in `bootstrap/`, `tools/` and `.github/scripts/`, the tests included. Coverage counts the 13 scripts the tests test (every one of those files whose name does not start with `test`) and not the tests themselves.
  - *Tools* (third-party record on PR #378, versions pinned exactly, P-11 § 2 (5)): shellcheck 0.11.0 (GPL-3.0, a CI and local tool only, never copied or shipped; Adam allowed it 2026-11-06 20:02), shfmt 3.14.1 (BSD-3-Clause), bashcov 4.0.2 with simplecov 1.3.2 (MIT). kcov is not used (GPL-2.0).
  - *Lint, measured.* shellcheck at its default level gives 969 findings: 3 errors, 72 warnings and 894 notes. 944 of them are in the tests, and 823 are of three kinds that the scripts do on purpose: SC2030 and SC2031 (a variable changed in a subshell) and SC2016 (`$` in single quotes). The fix: a `.shellcheckrc` turns off only checks the scripts break on purpose, each with its reason on the line before it; every other finding is fixed, or turned off on its own line with a reason. `build` then runs `shellcheck` on all 21 files and fails on any finding.
  - *Format, measured.* `shfmt -i 2 -ci` is closest to the scripts' style: 17 of 21 files change, about 2,800 lines, mostly one-line functions and `case` branches written out. One PR reformats every file and changes nothing else, and every suite and leg runs on it. `build` then runs `shfmt -i 2 -ci -d` and fails on any difference. Who wants the scripts' current one-line style kept instead has to drop the format check, since shfmt has no option for it.
  - *Coverage, measured.* bashcov, run under every suite on Linux with bash 5.2, merged across the two halves of the setup script's tests: 71.5% (3,034 of 4,246 lines) of 11 scripts. Per script: `bootstrap/stubs/bootstrap-project.sh` 63.8% (2,012 of 3,152); every other one 81.6% or more. Not yet counted: the two scripts in `.github/scripts/`, which the measurement left out; part (c) makes it count them. Under tracing, three tests fail that pass without it (two in `bootstrap/test.sh` about the `bootstrapper-test` gate, one about a broken pipe in `bootstrap/test-bootstrap-project.sh`), so they are made to pass under tracing too. To reach 80%, about 400 more lines of the setup script need tests, more if the `.github/scripts/` pair comes in lower.
  - *Coverage, counted (amended 2026-11-07).* Most tests of the setup script run a copy of it (`whole` copies it per test, `use_built` runs the built copy), and `bootstrap/test.sh` runs copies of `bootstrap/build.sh`; the harness deletes them before bashcov reads them, so the measurement above counted only the tests that source a script (Crog, #393, 2026-11-07: 72.7% of all 13 scripts at `12d65a9`, the setup script 64.1%). The coverage is therefore counted with the copies: under a setting only the coverage run sets, the harness keeps its copies until bashcov has read them, and the merge maps each copy line for line back onto its script (stamping substitutes in place, so lines match). Measured that way in an experiment: the setup script 95.4% (3,084 of 3,234), all 13 scripts about 94.6%. The gate stays at 80% of the counted lines in total. The about 150 lines of the setup script that no test reaches (the largest pieces in `resume_read_github`, `layout_into`, `check_changed_paths`, `check_license_answer` and `api_call`) get tests of their own, after the gate if time before 2026-11-13 is short. `.github/scripts/` counts through a committed simplecov configuration that drops simplecov's hidden-directory filter. Approved: Adam, 2026-11-07 07:41 ("Apyr").
  - *Where the gates run.* Lint and format run in `build` (`ci.yml`). Coverage runs where the suites run: each test job of the Bootstrapper workflow on Ubuntu (`scripts-test` and the Ubuntu shards of `bootstrap-project-test`) uploads its bashcov result, and `bootstrapper-test`, already a required check, merges them and fails below 80% of the counted lines in total. It also prints the figure per script. The Windows, macOS and bash 3.2 legs run as today, without coverage. When the workflow's `changes` job skips the tests, the gate does not run either. Running the gate in `bootstrapper-test` rather than `build` keeps the Done-when's aim, that the merge is blocked, and keeps the suites from running twice.
  - *Parts, one PR each, test first, reviewed on Opus.* (a) lint: the `.shellcheckrc`, the fixes and the `build` step; (b) format: the reformat, then the `build` step; (c) coverage, amended 2026-11-07: (c1) the three tests that fail under tracing fixed and the harness setting that keeps the copies, (c2) the simplecov configuration, the result uploads, the copy mapping and the gate in `bootstrapper-test`, (c3) tests for the lines no test reaches; (d) `RULES.md` L § 7 (3) removed and this item marked done. Each gate's red run is shown on a PR made for it: a finding, a format difference, or coverage under 80%. That PR is closed unmerged.
  **Progress.** Part (a) is done: #379 (`b7c67bc`), built by Crog and approved by a Clead review agent (Opus) at `f0761b8`. shellcheck finds 0 of the 969 findings. The gate's red run was #381, closed unmerged.
  Follow-ups from the review of #379 (non-blocking), for after part (c): (1) SC2030 and SC2031 are off for the whole repository, but their reason covers only the tests: turn them off per test file instead, so the other scripts are still checked for them. (2) `.shellcheckrc` is not in the test-change check's `--code` patterns, so a PR that only turns a check off needs no test change: add it. (3) The pinned SHA-256 of the shellcheck archive is trust-on-first-use; no upstream signature is checked. Recorded here, nothing to change for now.
  Part (b) is done: the reformat in #386 (`241f8e2`), with code unchanged under bash 5.2 and 3.2, and the format step in #389 (`2bc0e3f`), approved after one fix round. The gate's red run was #392, closed unmerged.
  Follow-ups from the review of #389 (non-blocking), for after part (c): (4) a `shell:` key on the lint or the format step would pass the tests, because they run the step's script with `bash -e`, while GitHub without `-e` would not stop on a wrong hash: forbid `shell:` in both steps' tests, or start both scripts with `set -euo pipefail`. (5) A failed download is not tested on its own; `curl -f` and the hash check cover it today. (6) #389's description says shfmt passes with no input; the reviewer found that shfmt 3.14.1 fails then. The empty-selection guard stays right.
  Part (c1) is done: #393 (`dbed38e`), approved with no required fixes. Follow-ups from its review (non-blocking), for after part (c3): (7) the setup harness's deletion of empty folders under `BOOTSTRAP_TEST_KEEP_COPIES=1` is not tested; (8) "any other value than `1` deletes the work folder" is documented but not tested in either harness; (9) the gate tests' failing cases do not assert why they fail (the reviewer checked each by hand).
  Deviation found 2026-11-07 (the review of #397 pointed it out): the Clead session's prompts for the reviews of #379, #386, #389 (both rounds) and #393, all merged, and the first review of #397 told the review agents to read the whole PR description, which P-3 § 2 (3) excludes (the author's reasoning). Each reviewer reports having checked the claims itself. #397 gets a new review within P-3 § 2 before it merges. Adam, 2026-11-07 11:50 ("Apyr"): the merged four get no new reviews.

## Phase 2 — Validate unproven pieces

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

## Phase 4 — Autonomous PR loop and Copi reactivation

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

## Process & team documentation

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
