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
     Windows and run that installer too. Then open **Git Bash**: press
     the Windows key, type `Git Bash` and press Enter (or click the
     Start button and choose Git Bash from the list of apps). A window
     opens with a line that ends in `$`; you type every command below
     in that window. If Git Bash was already open, close it and open it
     again, so it finds `gh`.
   - **macOS:** open the Terminal app. If you have Homebrew, run
     `brew install gh`; otherwise open https://cli.github.com, click
     Download for Mac, open the downloaded file and follow the installer.
   - **Linux:** open a terminal and follow the steps for your system at
     https://github.com/cli/cli/blob/trunk/docs/install_linux.md.

   When it has worked, this command prints a version number:

   ```
   gh --version
   ```

   If it says "command not found", close the window, open a new one and
   try again.
2. Sign in to GitHub. Copy this line into the window and press Enter:

   ```
   gh auth login -h github.com -p https -w -s workflow
   ```

   If gh asks "Authenticate Git with your GitHub credentials?", answer
   Yes: type y and press Enter, or just press Enter. Then gh shows a
   one-time code and opens your browser (press Enter if it asks first).
   Enter the code on the GitHub page and approve. When it has worked, gh says "Logged in as" and your GitHub name, and
   `gh auth status` shows your account. If you see something else, run
   the line again.

**Step 1: run the setup.** In the same window, go to the folder that
should hold the new project (for example `cd ~/Documents`), then copy
this line and press Enter:

```
gh api repos/factoincognito/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh && bash bootstrap-project.sh
```

The first part downloads the script into that folder; the second part
starts it. It asks, one question at a time, for each answer you did not
give as an option: Project name, Display name, Description, Owner,
Product owner name, Language pack, Add the publishing files (web pack
only), Visibility, Licence, Copyright holder (not asked when you choose
no licence), Folder, Your name for git and Your email address for git.
Each question says what it is for, and where a default is safe, Enter
accepts it. Then the script shows its plan and waits for your yes. Each
step prints a line when it starts and when it ends, and at the end it
says what it created and what to do next.

Right after your yes, before it changes anything on GitHub, it prints
the command to continue the setup if it stops before it finishes, for
any reason (also Ctrl-C or a closed window). Copy that command and
keep it until the setup has finished. That command includes
`--resume`, which tells the script to continue the project that is
there instead of creating a new one; if you run it and the project was
not created yet, the script says so and prints the command to start
again. When it stops by itself, it also says why and prints the exact
command to run next: one that starts again, or one that continues the
setup. The command to continue and the command to start again carry
your answers along, so you are not asked again. At a stop before the
project exists, that command is
the one you ran. Once the project exists on GitHub, that command
includes `--resume` as well.

**What the script guides you through.** When something is missing, the
script prints numbered steps for your system (what to do, the page to
open, what you will see when it has worked). You can read the guides
here first:

- Before anything is created, the script checks again and goes on once
  you have fixed it (press Enter):
  - git not installed;
  - gh not installed;
  - gh installed, but too old for the script;
  - Node.js and npm not installed (only for the node, web and
    react-native packs; the guide points to https://nodejs.org);
  - gh signed out, or its sign-in no longer accepted;
  - gh signed in without the `workflow` permission (the right to change
    the files that run the project's checks): the script offers to run
    `gh auth refresh -h github.com -s workflow` and walks you through
    the browser step;
  - your name and email for git, which it asks for;
  - GitHub not reachable from this computer;
  - a project with that name that already exists on GitHub;
  - a folder for the new project that does not exist, or that
    is not empty, or that is a file, or that cannot be written to, or
    that is inside another project that git keeps track of.
- Before anything is created, the script stops and you start it again
  with the command it prints, because it cannot check again in the same
  run:
  - a bash that is too old (Windows: install the current Git for
    Windows; macOS: use /bin/bash);
  - an older version of the script (it shows the command to download
    the current one);
  - gh signs in with a key (a token) set in GH_TOKEN or GITHUB_TOKEN
    that lacks a permission: make a new key, put it there, and open a
    new window.
- When GitHub refuses to create the project (nothing exists yet; fix it
  and start the script again with the command it prints): the name is
  taken by a project your account cannot see, or your account may not
  create projects there (an organisation's setting, or the permissions
  of the key gh signs in with).
- After the project exists (fix it, then continue with the command the
  script prints):
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
- Only when you continue a setup with `--resume`:
  - there is no project with that name to continue (the command it
    prints then starts a new one);
  - the project was not made by this version of the bootstrapper, or
    not by the bootstrapper at all, or its README lost the setup
    section: the script will not continue it, and suggests a new
    project under another name;
  - README.md or CHANGELOG.md on GitHub has Windows line endings (a
    carriage return): save it with LF line endings, then continue;
  - the folder is not a copy of this project: give the right folder
    with `--dir`, or choose a new or empty one;
  - the copy on this computer does not match GitHub (unsaved changes,
    or another version): move the folder away, or make it match, then
    continue. The script never deletes your work.

**What only this README covers.**

- Step 0 above: the script cannot download or start without `gh`.
- After the script: in the Claude app, create a Claude Project for the
  new GitHub project, add the GitHub project to that Claude Project, and
  start a chat inside the Claude Project; `CLAUDE.md` does the rest. If
  the Claude GitHub App on your account is limited to selected projects,
  add the new one on GitHub first: your picture, top right, then
  Settings, Applications, Configure next to the Claude app, and add the
  project under the choice
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
  `gh auth refresh -h github.com -s delete_repo` once (if gh asks
  "Authenticate Git with your GitHub credentials?", answer Yes), then
  `gh repo delete OWNER/NAME --yes`. The script never deletes a
  project.

A project can also be made with the "Use this template" button on the
bootstrapper's GitHub page. Its README then has a short section, near
the top, that gives the same command with `--resume`, which finishes the setup.

### Working setup
Run the Claude app next to VS Code. In the Claude app, create a Claude
Project for this repo, add the repo to that Claude Project (give it
access when asked), and start a chat inside the Claude Project;
`CLAUDE.md` loads from the repo. Before the first task, ask Clead to
summarise `memory/context.md`: if it can describe the project, the
decisions made and the open questions, it is oriented. In VS Code, open
your clone and use a Claude Code tab if you want to run Crog yourself.

Keep one Claude Project per repo, so what Clead learns in one project
never mixes with another (`docs/decisions/0001-rebuild-workflow.md`,
§6, "Cowork project setup"; written for Cowork, the reasoning is the
same).

### Starting later sessions
In the Claude app, start a new chat inside the project's Claude Project
(it already has the repo). Clead follows the session startup steps in
`CLAUDE.md`. The first thing you say is the first thing
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
