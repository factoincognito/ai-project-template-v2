# ai-project-template-v2

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
You run one command, and a script called `bootstrap-project.sh` does
the setup: it creates the project on GitHub, adds the files for the
kind of code you choose (a language pack), fills in the project's name and description, adds its licence,
protects its `main` line of work and checks that everything is green.
It asks for what it needs and explains each question. First you need
two tools: `gh`, the GitHub command-line tool, and, on Windows, Git for
Windows.

**Step 0: install gh and sign in (once per computer).**

1. Install the tools.
   - **Windows:** open https://git-scm.com/download/win in your browser,
     download Git for Windows and run the installer, keeping the default
     choices. Then open https://cli.github.com, click Download for
     Windows and run that installer too. Open **Git Bash** from the Start
     menu; you type every command below in that window. If Git Bash was
     already open, close it and open it again, so it finds `gh`.
   - **macOS:** open the Terminal app. If you have Homebrew, run
     `brew install gh`; otherwise open https://cli.github.com, click
     Download for Mac, open the downloaded file and follow the installer.
   - **Linux:** open a terminal and follow the steps for your system at
     https://github.com/cli/cli/blob/trunk/docs/install_linux.md.

   When it has worked, this command prints a version number:

       gh --version

   If it says "command not found", close the window, open a new one and
   try again.
2. Sign in to GitHub. Copy this line into the window and press Enter:

       gh auth login -h github.com -p https -w -s workflow

   gh shows a one-time code and opens your browser (press Enter if it
   asks first). Enter the code on the GitHub page and approve. When gh
   asks "Authenticate Git with your GitHub credentials?", answer Yes.
   When it has worked, gh says "Logged in as" and your GitHub name, and
   `gh auth status` shows your account. If you see something else, run
   the line again.

**Step 1: run the setup.** In the same window, go to the folder that
should hold the new project (for example `cd ~/Documents`), then copy
this line and press Enter:

    gh api repos/factoincognito/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh && bash bootstrap-project.sh

The first part downloads the script into that folder; the second part
starts it. The script asks for the project's name, a one-line
description, the language pack and the licence, shows its plan and
waits for your yes. Each step prints a line when it starts and when it
ends, and at the end it says what it created and what to do next. If it
stops, it says why and prints the exact command to continue; the
command always ends with `--resume`.

**What the script guides you through.** When something is missing, the
script stops, prints numbered steps for your system (what to do, the
page to open, what you will see when it has worked), and checks again.
You can read the guides here first:

- Before anything is created (fix it, the script checks again and goes
  on):
  - a bash that is too old (Windows: install the current Git for
    Windows);
  - git not installed;
  - gh not installed, or too old;
  - Node.js and npm not installed (only for the node, web and
    react-native packs; the guide points to https://nodejs.org);
  - gh signed out, or its sign-in no longer accepted;
  - gh signed in without the `workflow` permission (the right to change
    the project's checks): the script offers to run
    `gh auth refresh -h github.com -s workflow` and walks you through
    the browser step;
  - your name and email for git, which it asks for;
  - GitHub not reachable from this computer;
  - an older version of the script (it shows the command to download
    the current one);
  - a project with that name that already exists on GitHub;
  - a folder for the new project that does not exist, is not empty, is
    a file, cannot be written to, or is inside another project that git
    keeps track of.
- When GitHub refuses to create the project (nothing exists yet; fix it
  and start the script again): your account may not create projects in
  that organisation, or gh does not have every permission it needs.
- After the project exists (fix it, then continue with the command the
  script prints, which ends with `--resume`):
  - gh does not have every permission it needs;
  - GitHub Actions (the GitHub service that runs your project's checks)
    is turned off, or allows only the project's own actions;
  - git cannot sign in to GitHub: the script offers to run
    `gh auth setup-git`, which changes your git settings for every
    project, and asks first;
  - a private project on a free GitHub account, which cannot protect
    its `main` line of work: the script offers three ways on (move to a
    paid GitHub plan, make the project public, or go on without
    protection with `--allow-unprotected`, which it records in the
    project's `memory/decisions.md`).

**What only this README covers.**

- Step 0 above: the script cannot download or start without `gh`.
- After the script: open the Claude app, start a Claude project for the
  new GitHub project, give it the project and start a chat; `CLAUDE.md`
  does the rest. If the Claude GitHub App on your account is limited to
  selected projects, add the new one on GitHub first: your picture, top
  right, then Settings, Applications, Configure next to the Claude app,
  and add the project under the choice
  Only select repositories (the projects it may read).
  This last part has not been checked yet.
- Organisation and billing settings: in an organisation, only its
  owners can allow members to create projects (Settings, Member
  privileges) and turn on GitHub Actions (Settings, Actions, General).
  A plan that protects private projects is chosen in your account's
  Settings, Billing and plans.
- Deleting a project you made to try things out: on the project's page,
  Settings, then at the bottom the button
  Delete this repository (GitHub's word for a project).
  Or in the same window, run
  `gh auth refresh -h github.com -s delete_repo` once, then
  `gh repo delete OWNER/NAME --yes`. The script never deletes a
  project.

A project can also be made with the "Use this template" button on the
bootstrapper's GitHub page. Its README then has a short section, near
the top, that gives the same command with `--resume`, which finishes the setup.

### Working setup
Run the Claude app next to VS Code. In the Claude app, start a chat for
this repo and give it access to the repo when asked; `CLAUDE.md` loads
from the repo. Before the first task, ask Clead to summarise
`memory/context.md`: if it can describe the project, the decisions made
and the open questions, it is oriented. In VS Code, open your clone and
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

`main` in this template repo is protected: nothing merges without a pull
request and a green `build` check, and the rule applies to admins too.
In a project created with the setup script, the script turns this on.
What it enforces, how to check it works, and how to turn it on by hand:
`docs/DEV_INFRASTRUCTURE.md`, "Branch protection runbook".

## Reference implementation

This template was built from the lessons of sugose/ai-project-template.
See `docs/decisions/0001-rebuild-workflow.md` for the full rationale.
