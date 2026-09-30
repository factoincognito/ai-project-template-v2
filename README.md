# [PROJECT NAME]

A project run with the Clead + Crog workflow: a product owner decides
what gets built, Clead (Claude, Tech Owner) owns how, and Crog (Claude
Code, Senior Developer) implements. Everything the agents need lives in
this repo: `CLAUDE.md` is the entry point.

## Setup

### Prerequisites
- The Claude app, for Clead (the chat where you plan and decide)
- VS Code with the Claude Code extension, for Crog (optional: Clead can
  also start Crog itself)
- A GitHub account, and git

### Creating a project from the template
1. Create the repo from `sugose/ai-project-template-v2`. GitHub's
   "Use this template" button only appears once the template repo has
   **Template repository** ticked in its settings; until then, create an
   empty repo and push a copy of the template to it.
2. Copy in the language pack you need from `languages/` (`node` or
   `web`). Each pack's `code-standards.md` says which file goes where;
   its `ci.yml` replaces the stub `.github/workflows/ci.yml`, which only
   checks out the code. The bootstrap wizard that will do this for you
   is not written yet (backlog PBI-1.4).
3. Turn on branch protection for `main` (Settings, Branches): require a
   pull request with **no** required approvals (every PR is opened under
   your own account, and GitHub does not let authors approve their own
   PRs), require the `build` status check, and do not allow bypassing.
   On GitHub's free plan this is only available for public repos.

### Working setup
Run the Claude app next to VS Code. In the Claude app, start a chat for
this repo and give it access to the repo when asked; `CLAUDE.md` loads
from the repo. Before the first task, ask Clead to summarise
`memory/context.md`: if it can describe the project, the decisions made
and the open questions, it is oriented. In VS Code, open your clone and
use a Claude Code tab if you want to run Crog yourself.

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

`main` in this template repo is protected: nothing merges without a pull
request and a green `build` check, and the rule applies to admins too.
A project created from the template has to turn this on itself (step 3
above).

## Reference implementation

This template was built from the lessons of sugose/ai-project-template.
See `docs/decisions/0001-rebuild-workflow.md` for the full rationale.
