# [PROJECT NAME]

[One or two sentences: what this project is and who it is for.]

A project run with the Clead + Crog workflow: a product owner decides
what gets built, Clead (Claude, Tech Owner) owns how, and Crog (Claude
Code, Senior Developer) implements. Everything the agents need lives in
this repo: `CLAUDE.md` is the entry point.

## After bootstrapping (delete this section when done)

If you see this, setup has not run. To run it, open Git Bash (Windows) or a terminal (macOS, Linux) and run the command below, with OWNER and NAME taken from this project's web address, https://github.com/OWNER/NAME:

```
gh api repos/factoincognito/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh && bash bootstrap-project.sh --resume --owner OWNER --name NAME
```

It needs gh installed and signed in first (step 0 in the README of https://github.com/factoincognito/ai-project-template-v2); it then finishes the setup and removes this section.

## Setup

### Prerequisites
- The Claude app, for Clead (the chat where you plan and decide)
- VS Code with the Claude Code extension, for Crog (optional: Clead can
  also start Crog itself)
- A GitHub account, and git

### Working setup
Run the Claude app next to VS Code. In the Claude app, create a Claude
Project for this repo, add the repo to that Claude Project (give it
access when asked), and start a chat inside the Claude Project;
`CLAUDE.md` loads from the repo. Before the first task, ask Clead to
summarise `memory/context.md` and `memory/project.md`: if it can
describe the project and its goals, it is oriented. In VS Code, open your clone and
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
`build` check, and the rule applies to admins too. The setup script
turns this on. What it enforces, how to check it works, and how to turn
it on by hand: `docs/DEV_INFRASTRUCTURE.md`, "Branch protection
runbook".
