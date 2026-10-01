# [PROJECT NAME]

[One or two sentences: what this project is and who it is for.]

A project run with the Clead + Crog workflow: a product owner decides
what gets built, Clead (Claude, Tech Owner) owns how, and Crog (Claude
Code, Senior Developer) implements. Everything the agents need lives in
this repo: `CLAUDE.md` is the entry point.

## After bootstrapping (delete this section when done)

This repo was created from the bootstrapper with "Use this template".
The template version it came from is recorded in `CHANGELOG.md`. Do
these steps once, then delete this whole section.

The files you got here are generated from the template at
https://github.com/factoincognito/ai-project-template-v2. To change the
bootstrapper itself, change the template there. A change made in the
bootstrapper repo is overwritten at the next release, and one made in a
copy never reaches it; neither has tests.

1. **Copy in a language pack** from `languages/` (`node`, `web`,
   `python` or `react-native`). A bootstrap wizard that does this for
   you is planned but not written yet, so by hand:

   | Pack file | Goes to |
   |---|---|
   | `ci.yml` | `.github/workflows/ci.yml` (replaces the stub, which only checks out the code) |
   | `gitignore` | `.gitignore` (merge with the template's) |
   | `vscode-settings.json`, `vscode-extensions.json` | `.vscode/settings.json`, `.vscode/extensions.json` |
   | node, web, react-native: `package.json`, `tsconfig.json`, `biome.json` | project root |
   | node: `placeholder.test.ts` | `src/` |
   | web: `index.html`, `vite.config.mts`, `playwright.config.ts` | project root |
   | web: `starter/src/`, `starter/e2e/` | `src/`, `e2e/` |
   | web, optional: `deploy.yml`, `wrangler.jsonc` | `.github/workflows/deploy.yml`, project root |
   | python: `pyproject.toml`, `requirements.txt`, `requirements-dev.txt` | project root |
   | python: `pre-commit-config.yaml` | `.pre-commit-config.yaml` |
   | python: `starter/src/` | `src/` |
   | react-native: `app.json` | project root |
   | react-native: `starter/src/` | `src/` |

   Then follow the pack's `code-standards.md` ("First-time setup"). Once
   the pack is in place, clean up `languages/`: delete the other packs,
   and in the pack you used delete everything except `code-standards.md`
   (for the web pack, copy the deploy files out first if you want them).
   This is required: left as it is, the folder breaks the project's own
   CI, because Biome stops on the nested pack configs and Jest runs the
   other packs' tests.
2. **Turn on branch protection** for `main` (Settings, Branches): require
   a pull request with **no** required approvals (every PR is opened
   under your own account, and GitHub does not let authors approve their
   own PRs), require the `build` status check plus any other check your
   CI adds that must pass before merging, and do not allow bypassing. On
   GitHub's free plan this is only available for public repos.
3. **Fill in the placeholders**: `[PROJECT NAME]`, `[PO NAME]` and the
   description in this README, `CLAUDE.md`, `CHANGELOG.md`, `docs/SPEC.md`,
   `docs/BACKLOG.md`, `docs/NEXT_SESSION.md` and `memory/project.md`.
   Search the repo for `[` followed by a capital letter to find them
   (ignore the `licenses/` folder, whose text has a few such links).
4. **Choose your project's licence.** The template's own files are
   licensed under the PolyForm Noncommercial License 1.0.0 (see
   `licenses/`); keep that folder for as long as any template file
   remains in your project. It does not license your project: add your
   own `LICENSE` file at the root.
5. **Delete this section** and commit the result through a pull request.

## Setup

### Prerequisites
- The Claude app, for Clead (the chat where you plan and decide)
- VS Code with the Claude Code extension, for Crog (optional: Clead can
  also start Crog itself)
- A GitHub account, and git

### Working setup
Run the Claude app next to VS Code. In the Claude app, start a chat for
this repo and give it access to the repo when asked; `CLAUDE.md` loads
from the repo. Before the first task, ask Clead to summarise
`memory/context.md` and `memory/project.md`: if it can describe the
project and its goals, it is oriented. In VS Code, open your clone and
use a Claude Code tab if you want to run Crog yourself.

Keep one Claude project per repo, so what Clead learns in one project
never mixes with another (`docs/decisions/0001-rebuild-workflow.md`,
§6, "Cowork project setup"; written for Cowork, the reasoning is the
same).

### Starting later sessions
Start a new chat and give it the repo. Clead follows the session
startup steps in `CLAUDE.md`. The first thing you say is the first thing
that matters.

## The team

| Role | Who | Surface |
|---|---|---|
| Product Owner | [PO NAME] | Claude app |
| Tech Owner / Reviewer | Clead (Claude) | Claude app |
| Senior Developer / Implementer | Crog (Claude Code) | VS Code, or an agent Clead starts |

## Workflow

The product owner describes the next PBI. Clead specs it; the product
owner confirms it captures the intent. Crog implements, test first.
Reviews and merges are delegated: Clead reviews Crog's code, Crog
reviews Clead's code, config and process changes, and Crog merges once
the review passes and CI is green. After 3 review rounds without
agreement, the product owner decides. The product owner is never used to
pass messages between Clead and Crog. Details: `CLAUDE.md`, "Change
execution model".

## Branch protection

`main` is protected: nothing merges without a pull request and a green
`build` check, and the rule applies to admins too (step 2 above).
