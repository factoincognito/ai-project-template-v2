# AI project bootstrapper

This sets up a new software project for you, ready to be built
together with Claude. You answer a few questions; a script does the
rest. You do not need to have typed commands before: this page gives
every command to copy.

## What you get

At the end you have a project on GitHub (a website that keeps your
project's files and every change to them) and a copy of it on your
computer. In it:

- The starting files for the kind of software you choose: a website or
  web app, a program in TypeScript, a program in Python, or a mobile
  app for phones and tablets.
- Checks that GitHub runs on every proposed change, and a main version
  that only takes a change once its checks have passed.
- Files where Claude keeps the plan, the decisions and the status of
  the project, so nothing depends on a chat being remembered.

Then the work goes like this: you say what you want, in a chat in the
Claude app. Claude plans it and asks you to confirm it. Claude Code (a
version of Claude that writes code) builds it, writing the test first,
and each change is reviewed by the other Claude before it goes in. You
decide what gets built and can stop any change. The project's files
call these two roles Clead (the one that plans and reviews) and Crog
(the one that writes the code).

## What you need, and what it costs

To set up the project (step 0 below installs the tools):

- **A computer** with Windows, macOS or Linux.
- **A GitHub account.** Free. Make one at https://github.com/signup.
  On a free account, a public project gets full protection of its main
  version; a private one cannot, and the script then offers you three
  ways on.
- **On Windows: Git for Windows.** Free. It gives you Git, which keeps
  track of every change to the project's files, and Git Bash, the
  window where you type the commands from this page.
- **On macOS and Linux: Git.** Free, and often there already. If it is
  missing, the script says so and shows how to install it.
- **gh, GitHub's tool for the command line.** Free. The script uses it
  to create the project on GitHub for you, signed in as you.
- **Only for a website, a TypeScript program or a mobile app: Node.js.**
  Free. If it is missing, the script says so and shows how to install
  it.

To work on the project with Claude afterwards:

- **A paid Claude plan.** Claude Code, which writes the code, is not in
  the Free plan. The cheapest plan with it is Pro: 17 US dollars a
  month when paid for a year at once (200 dollars), or 20 dollars a
  month when paid monthly (prices as https://claude.com/pricing showed
  them on 2026-10-29).
- **The Claude app** (https://claude.ai), where you plan and decide.
- Later, if you want to watch or run the coding part yourself: VS Code
  (a free program for editing code) with its Claude Code extension.
  Not needed to start.

## Start here

Do step 0 once on each computer. Then step 1 sets up a project; do it
again for each new project.

{{TEMPLATE_README_SETUP}}

## A project whose setup has not finished

This page also shows on a project that was made with the
**Use this template** button on this page, until its setup has
finished. To finish that setup, do step 0 if you have not, then run
this command in the same window, with OWNER and NAME taken from the
project's web address, https://github.com/OWNER/NAME:

```
gh api repos/factoincognito/ai-project-bootstrap/contents/bootstrap-project.sh -H "Accept: application/vnd.github.raw+json" > bootstrap-project.sh && bash bootstrap-project.sh --resume --owner OWNER --name NAME
```

If a setup you started with step 1 stopped, use the command the script
printed instead.

## Without Claude

The project also works without Claude, as an ordinary, well set-up
project: the setup itself does not use Claude, and the checks run on
GitHub alone. The project's own README says what works without Claude
and what does not.
