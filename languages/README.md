# Language packs

A language pack is a folder of files that turns an empty project into
one with a working build, linting, tests and CI for a given kind of
code, green on the first push. You copy one pack into a new project
once, at the start. After that the files are the project's own, and the
project changes them as it needs to.

## The packs

| Pack | For | Checks in CI |
|---|---|---|
| `node/` | Node.js and TypeScript code: libraries, services, tools | Biome lint and format, TypeScript type check, Jest with an 80% line coverage gate |
| `web/` | A static web page built into one self-contained HTML file | Everything in `node/`, plus a Vite build and Playwright browser tests at phone and desktop width, in light and dark mode |
| `python/` | Python 3.14 code: libraries, services, tools | Ruff lint and format, mypy in strict mode, pytest with an 80% line coverage gate |
| `react-native/` | A mobile app for Android and iOS, built with React Native and Expo | Biome lint and format, TypeScript type check, Jest (jest-expo) unit and component tests with an 80% line coverage gate. No device, simulator or app-store builds |

The web pack also has an optional deploy to Cloudflare (`deploy.yml`,
`wrangler.jsonc`). Where each file goes is listed in the project's
README ("Creating a project from the template", or "After
bootstrapping" in a bootstrapped project), and each pack's
`code-standards.md` explains how to work with it.

## What every pack contains

Every pack follows the same shape. A new pack should too:

| File | Purpose |
|---|---|
| `ci.yml` | The project's CI workflow, replacing the template's stub `.github/workflows/ci.yml`. Its job must be named `build`, because branch protection on `main` requires a check called `build`. |
| `code-standards.md` | The rules for code in this language, with "First-time setup" and "Running the project" sections giving the commands to install and to run the checks locally. It is read in place, not copied into the project layout. |
| `gitignore` | Entries to merge into the project's `.gitignore`. Named without the dot so it doesn't act on the template itself. |
| `vscode-settings.json`, `vscode-extensions.json` | Editor settings and recommended extensions, copied to `.vscode/`. Recommend only what the pack needs. |
| The language's own manifest and config | For example `package.json`, `tsconfig.json` and `biome.json`, or `pyproject.toml` and the `requirements` files. Tool versions are pinned exactly, so every project starts from a known, tested combination. |
| A placeholder or starter test | Keeps the coverage gate green on day one. The project replaces it with its own code and tests. |

## Rules for a pack

- **Green on day one.** A fresh project laid out from the pack must pass
  its own CI without changes. Check it on a scratch project, running
  exactly the commands in `ci.yml`, before calling a pack done.
- **Enforce what CI can check.** Where `code-standards.md` states a
  rule a tool can check (types, lint, formatting, the coverage gate),
  CI must fail when it is broken. Prove it by making a deliberate
  violation and watching CI fail. Rules no tool checks (for example
  "no hardcoded values") are for review.
- **No lockfile in the pack.** The first `npm install` (or the
  language's equivalent) in the project creates it, and the project
  commits it. `code-standards.md` says so under "First-time setup".
  The Python pack has no lockfile step: its requirements files pin the
  direct dependencies, and its `code-standards.md` says what that
  leaves unpinned.
- **Every file has a place.** Each file in a pack except
  `code-standards.md` must appear in the placement table in the README,
  so nothing is copied by guesswork.
- **Nothing project-specific.** Placeholders like `[project-name]`
  instead of project names, service names or domains. Those belong to
  the project.

## Adding a pack

1. Create `languages/<name>/` with the files above, modelled on the
   closest existing pack.
2. Add every file to the placement table in the template repo's
   README and in the bootstrapper's README stub, so projects get it
   too.
3. Lay it out in a scratch project and run its CI commands until they
   pass. Then break one rule on purpose for each thing CI is meant to
   enforce, and check that CI fails.
4. Open a PR. It is code and config, so the reviewer is the role that
   did not write it (see `CLAUDE.md`, "Change execution model").

In the template repository
(https://github.com/sugose/ai-project-template-v2), each pack is also
tested on GitHub's own runners on every pull request, by the
template-only workflow `.github/workflows/packs.yml` and the layout
script `tools/layout-pack.sh`. A new pack gets a job there, and its
files are added to the script's layout table.

## Keeping packs current

Pinned versions age. Refresh them together in one change: check what
the tools support together (for example, which TypeScript versions the
test runner supports), bump, and run the full check again, including on
GitHub's runners.
