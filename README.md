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

A physical keyboard is recommended, though not required. On a touch
screen with the on-screen keyboard, typing symbols such as `@` and
copying long commands out of that window is harder. If the window where
you type commands stops reacting after you selected text in it, press
Ctrl-Q (hold Ctrl and press Q).

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
   - **Linux on Windows (WSL):** to work in Linux on a Windows computer,
     do this instead of the Windows step above (not both). First install
     Ubuntu (a Linux):
     1. Right-click the Start button and choose **Terminal (Admin)**. If
        Windows asks whether to allow this app to make changes, choose
        Yes.
     2. Type this line and press Enter:

        ```
        wsl --install -d Ubuntu
        ```

        If it asks you to restart the computer, restart it.
     3. If no Ubuntu window opens by itself, press the Windows key, type
        `Ubuntu` and press Enter. If Ubuntu is not in the list either,
        open **Terminal (Admin)** again as in step 1 and type the same
        line again.
     4. The first start unpacks files and may take a few minutes. Wait
        until Ubuntu asks for a new user name and a password. Choose
        them and remember the password: commands that start with `sudo`
        ask for it again. Nothing shows on the screen while you type it;
        type it and press Enter.
     5. Ubuntu may ask whether to opt in to platform metrics collection.
        Either answer is fine.

     Then follow the Linux step above, and every step after it, in that
     Ubuntu window, not in the Terminal (Admin) window.

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
   If your browser is not signed in to GitHub, GitHub first asks you to
   sign in: your user name or email address, your password, and a
   two-factor code if you use one. Then it shows the page for the code.
   Enter the code on the GitHub page and approve. If the browser does
   not open (as in WSL, the Linux inside Windows), open
   https://github.com/login/device in your browser yourself and enter
   the code there. When it has worked, gh says "Logged in as" and your
   GitHub name, and `gh auth status` shows your account. If you see
   something else, run the line again.

**Step 1: run the setup.** In the same window, go to the folder that
should hold the new project. If you have no such folder yet, this line
makes one named projects in your home folder and goes there; copy it
and press Enter:

```
mkdir -p ~/projects && cd ~/projects
```

Then copy this line and press Enter:

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
keep it until the setup has finished. When it stops by itself, it also
says why and prints the exact command to run next: one that starts
again, or one that continues the setup. If you run the command to
continue and the project was not created yet, the script says so and
prints the command to start again.

The command to continue and the command to start again carry your
answers along, so you are not asked again. The script saves your
answers in a small file next to it, `.bootstrap-project.again`, and the
command it prints reads them back with `--again`. That command also
goes to the folder you started the script in, so it works from any
window, also in a new window, which starts in your home folder. With
the folder of step 1 it reads
`cd ~/projects && bash bootstrap-project.sh --again`. Once the project
exists on GitHub, that command includes `--resume` as well: the saved
answers carry it, and it tells the script to continue the project that
is there instead of creating a new one. Each stop saves the answers
anew, and the first line that `--again` prints names the project they
are for, so a file left from another project is easy to spot. The file
is removed when the setup has finished. When there is nothing to save
yet, or the answers cannot be saved (for example an answer of more
than one line), the script prints the full command instead, after the
same `cd`: the one you ran, with every answer in it.

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
    react-native packs; the guide points to https://nodejs.org). On
    Linux, and in Linux on Windows (WSL), only a window opened after the
    install finds the new npm, so this one does not go on with Enter:
    type `q`, then start the script again in a new window with the
    command it shows;
  - only the Windows npm found in Linux on Windows (WSL): a project in
    Linux should not use it, and the guide shows how to install Node.js
    in Linux, then start again in a new window, as above;
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
  "Authenticate Git with your GitHub credentials?", answer Yes; if the
  browser does not open, open https://github.com/login/device yourself
  and enter the code there, after signing in to GitHub if it asks), then `gh repo delete OWNER/NAME --yes`. The script never deletes a
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

## Working without Claude

Without Claude, a project made from this template is a conventional,
well set-up development project, as development looked before AI became
a tool for writing code. With Claude, the Clead and Crog workflow comes
on top of it.

**What works without Claude.**

- The setup. `bootstrap-project.sh` does not call Claude. It needs bash,
  git and a signed-in `gh`, and Node.js with npm for the node, web and
  react-native packs. Claude appears only in the text it prints at the
  end.
- A green `build` check from the start, and `main` protected: nothing
  merges without a pull request and a green `build`.
- The test-first check in `build`: a pull request that changes code
  without changing a test fails, unless a commit in it has a
  `Test-exempt: <reason>` line.
- A place for everything: the backlog (`docs/BACKLOG.md`), decisions
  (`memory/decisions.md`, and `docs/decisions/` for longer ones), the
  status (`STATUS.md`), the change history (`CHANGELOG.md`), the pull
  request template, and the language pack's code standards.
- The two workflows that post comments, `review.yml` (a hidden marker
  on pull requests that change `src/`) and `changelog.yml` (a reminder
  after a merge that did not change `CHANGELOG.md`), run on GitHub alone.
  The comments are addressed to Clead and Crog.

**What does not work without Claude.**

- Clead and Crog, and everything they do: specs, reviews, merges,
  session start and end, `..wrap` and pins.
- `CLAUDE.md` and the files under `memory/` are instructions for Clead
  and Crog; without them, nobody reads them as instructions.
- The texts the setup leaves for the first session with Clead: the
  phase name in `docs/BACKLOG.md`, `memory/project.md`, the questions in
  `docs/SPEC.md`, `memory/context.md` and `STATUS.md`.
- Crog needs Claude Code, which the Free Claude plan does not include
  (https://claude.com/pricing, checked 2026-10-29).
- Whether other AI tools (such as Copilot or Cursor) read any of the
  project's files has not been checked.

**How to work with the project without Claude.** The rules written for
Clead and Crog, read for a team of people only:

- Every change goes through a pull request; branch protection enforces
  it.
- Write the test first and see it fail. The test-first check fails a
  code change without a test; a change no test can check says why in a
  `Test-exempt:` line.
- Someone other than the author reviews the pull request.
  `memory/standards.md` works as the review checklist.
- Merge once `build` is green and the review has passed.
- Fill in the texts the setup leaves for Clead (listed above) yourself,
  and keep `STATUS.md` up to date by hand.
- The comments from `review.yml` and `changelog.yml` can be ignored, or
  the two workflows deleted.

## Branch protection

`main` in this template repo is protected: nothing merges without a pull
request and a green `build` check, and the rule applies to admins too.
In a project created with the setup script, the script turns this on.
What it enforces, how to check it works, and how to turn it on by hand:
`docs/DEV_INFRASTRUCTURE.md`, "Branch protection runbook".

## Reference implementation

This template was built from the lessons of sugose/ai-project-template.
See `docs/decisions/0001-rebuild-workflow.md` for the full rationale.
