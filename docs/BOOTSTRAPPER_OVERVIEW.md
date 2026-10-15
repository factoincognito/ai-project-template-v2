# Bootstrapper: product overview

**As of:** 2026-10-15

For prospective users. This is a short description of what the Bootstrapper is
designed to do, not the full specification (the specification is PBI-1.14 in
[`BACKLOG.md`](BACKLOG.md)). Template-only: it is not copied into projects.

The Bootstrapper turns one command into a ready-to-work GitHub project: a
repository with your chosen language starter, your project's name and
description filled in, a licence, a protected main branch and a passing build,
all set up through a pull request like every later change.

## What you get

You answer a few questions (or pass them as options) and the script builds the
project on GitHub and on your computer. When it finishes you have:

- A new GitHub repository, public or private, created from the official project
  template.
- One language starter laid out and ready: Node, Web, Python or React Native.
  Each comes with its own tests, formatting and build check.
- Your project name, description and product-owner name filled in across the
  documents, so no placeholder text is left to find later.
- The licence you chose: none, MIT, Apache 2.0, GPL 3.0, BSD 3-clause,
  PolyForm Noncommercial 1.0.0, or any other licence GitHub offers.
- A protected main branch. Changes need a pull request, the `build` check must
  pass, and nobody can bypass it, not even the owner.
- A clean copy of the project on your computer, up to date with GitHub.
- The working method built in: the project is set up for the Clead and Crog way
  of working, where you decide what gets built, Claude in the Claude app
  (Clead) owns how, and Claude Code (Crog) writes the code. The rules and
  templates live in the repository, so every session starts from the same
  place.

## The way of working that comes with it

The project is not just files. It is set up to be run by one fixed method,
written into the repository so that you, Claude in the Claude app and Claude
Code all follow the same rules from the first session.

| Practice | What it means in your project |
| --- | --- |
| Clear roles | You are the product owner and decide what gets built. Clead (Claude in the Claude app) is the tech owner and decides how, plans the work and reviews it. Crog (Claude Code) implements. |
| Source control | Everything lives in git on GitHub. Plans, decisions, notes and code are all in the repository, which is the single source of truth. Nothing important is left only in a chat. |
| Every change by pull request | Nobody commits straight to main, and nobody can bypass that, because GitHub enforces it. One pull request makes one change. |
| Test first | Before behaviour changes, a check is written and shown failing, then the change makes it pass. "Done" is only said after a named check has passed. A shared check fails any pull request that changes code without changing a test, unless the commit gives a stated reason that the reviewer judges. |
| Continuous integration | Every pull request must pass the `build` check of your language starter before it can merge. |
| Review by the other role | Code and configuration are reviewed by the role that did not write them, against a written review standard. Changes to the method itself, such as process or architecture, get a review too. Architecture decisions also need your explicit approval. |
| Delegated merging | Crog merges once the build is green and any required review is in place. You do not approve every pull request, and you can stop any merge. |
| Continuity between sessions | A backlog, a decision log, a changelog and a session-handoff note are kept in the repository. Each session starts by reading them and ends with a check that nothing is left uncommitted or unrecorded. |

## The life-cycle of a project

The Bootstrapper creates the starting point. After that, every piece of work,
from a first feature to a bug fix, goes around the same loop.

| Step | What happens | Why |
| --- | --- | --- |
| 1. Set up | The Bootstrapper creates the repository, lays out the starter, protects main and merges a setup pull request that passes the build. | The project starts green and protected, so the rules apply from the first change. |
| 2. First session | You open the Claude app on the new repository. Clead reads the project's rules and, with you, fills in the goals, the specification and the first backlog item. | The script does not write your project. This is where it becomes yours. |
| 3. Say what you want | You describe the outcome you want, in your own words. Clead turns it into a backlog item with a specification and a definition of done. | You own the "what". Clead owns the "how" and bridges the gap, whatever your technical background. |
| 4. Approve the intent | You confirm that the plan matches what you meant. The ceremony scales with the change: a spoken "approved" for a small item, a recorded approval for a significant one, and a reviewed specification with your explicit approval for an architectural one. | Building starts only when the intent is agreed, so nobody builds the wrong thing well. |
| 5. Build, test first | Crog works on one branch for one item. A check that fails is written first, then the change that makes it pass. The pull request shows the failing run and a table of what is tested. | The tests prove the change does what was asked, and a reviewer can see it did. |
| 6. Automatic checks | The `build` check runs on the pull request. | A broken change cannot be merged. |
| 7. Independent review | The role that did not write the change reviews it, working from the diff, the specification and the written review standard only. It posts a verdict on the pull request. If changes are needed, they go back and forth, and after three rounds the question comes to you. | A fresh view catches what the author misses, and you are not left to settle disagreements by default. |
| 8. Merge | When the build is green and the review is approved, Crog merges. Clead reports what was merged. You can stop any merge. | You get the benefit of review and speed without approving every pull request yourself. |
| 9. Record | The changelog, the backlog and the decision log are updated in the repository. | The history stays accurate and nothing depends on anyone's memory. |
| 10. Close the session | At the end of a session, a check confirms that nothing is uncommitted, every open pull request is resolved or knowingly left open, and every follow-up is written down. Loose ideas go in a handoff note for next time. | The next session, possibly with a different Claude instance, picks up exactly where this one stopped. |

Then back to step 3 with the next item.

## Who it is for

It is written first for a product person with no background in git, GitHub or
the terminal: someone who knows what they want built and not how. Every message
and prompt in the script is meant for that reader. When something is missing, it
does not just stop. It prints numbered steps for your operating system, waits
until you press Enter, checks again, and repeats until the check passes.

It is equally useful to anyone who wants every new project to start the same,
checked way instead of repeating five manual setup steps and hoping none was
missed.

## How it works

1. **Prepare once, by hand.** Install the GitHub command-line tool (`gh`) and
   log in. On Windows, also install Git for Windows, which provides the
   terminal the script runs in. The script cannot do this for you, because it
   is downloaded with `gh`.
2. **Run one command.** The same command works in Git Bash, macOS and Linux:

   ```bash
   gh api repos/factoincognito/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh && bash bootstrap-project.sh
   ```

3. **Answer a few questions.** Project name, one-line description, your name,
   language starter, public or private, licence. Each can also be given as an
   option, so the whole run can be unattended.
4. **Let it check your setup.** Before anything is created, it checks your
   tools, your GitHub login and permissions, and that the name is free.
   Anything missing is explained step by step. Where the script can fix
   something itself, such as an install or a login permission, it shows the
   command and runs it only after you say yes.
5. **Review the plan and confirm.** It prints everything it is about to do and
   asks "Proceed?".
6. **It builds the project.** It creates the repository, protects main right
   away, makes a local copy, lays out the starter, fills in your details, adds
   the licence, and opens a pull request.
7. **It waits for the build, then merges.** The setup pull request must pass the
   project's own `build` check, which proves the project is green from day one.
   The script then requires that check on main and merges the pull request. The
   default wait is up to 20 minutes.
8. **It reports.** You get the repository link, the local folder, the
   protection as GitHub reports it, and a short list of what is left to fill
   in. The next step is to open the Claude app, give it the new repository and
   start a chat. The project's `CLAUDE.md` takes it from there.

## What it does not do

- **It does not write your project.** Goals, the specification, the backlog and
  the first work item are for your first session with Claude. The script lists
  exactly what it left open.
- **It does not take over an existing repository or codebase.** It sets up new
  projects only. Adding this way of working to existing code is out of scope.
- **It does not set up the Claude app or project for you,** and it does not set
  up Cloudflare deployment secrets or how much you delegate to Claude.
- **It never deletes a repository.** If a run fails or you give up, the
  repository stays. The script prints a delete command as a hint, for you to run
  if you want.
- **It does not install software or log you in on its own.** It offers the
  command and runs it only if you say yes. A general "yes to everything" option
  does not cover installs or logins.
- **It does not store or print your access tokens,** and it refuses to commit
  anything that looks like one.
- **It does not support older versions or version pinning.** Only the latest
  release can be used. An older script refuses to run and tells you to download
  the current one.
- **It does not run through `curl | bash`.** The script asks you questions and
  needs to read your answers.

## What you need before you start

| Need | Detail |
| --- | --- |
| GitHub account | Free is enough for public projects. |
| Computer | Windows with Git Bash, macOS or Linux. The script needs bash 3.2 or later, which macOS already has. |
| `git` | Installed. The script asks for your name and email for commits. |
| `gh` (GitHub CLI) | Installed and logged in, with permission to create repositories and change workflows. If a permission is missing, the script walks you through adding it. |
| `npm` | Only for the Node, Web and React Native starters. |
| Internet | Throughout, including the wait for the build. |

## Good to know

- **Public by default.** Choose private with an option. Branch protection on a
  private repository needs a paid GitHub plan (Pro, Team or Enterprise). If you
  do not have one, the script stops right after creating the repository and
  gives three choices: upgrade, make the repository public, or continue without
  protection. The last choice is recorded in the project's decision log.
- **Safe to restart.** If a run stops, for example when you press Ctrl-C or your
  connection drops, the script prints what already exists and the exact command
  to continue. Continuing works out where to pick up from GitHub and your local
  folder, and it never discards local work. It only continues projects made by
  the same script version.
- **Preview or automate.** A dry run shows the plan without creating anything. A
  non-interactive mode runs from options alone and lists every missing option at
  once.
- **A few minutes of waiting.** Most of the run is the setup pull request's
  build, which must finish before the merge.
- **Starters are starting points.** Each one has a small placeholder app or test
  so the build has something to check. They are not finished products.

## Availability

The Bootstrapper is being finished and is not released yet. Until then, a new
project is created by the manual steps in the template's README. This overview
describes the product as it is designed to work at release.
