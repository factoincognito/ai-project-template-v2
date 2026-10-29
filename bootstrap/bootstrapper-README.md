# AI project bootstrapper

**For people who know what they want built, but not how to build it.**

You bring the what: the idea, what it should do, what matters most.
Claude brings the how: it turns your idea into a plan, writes the
code and tests it. You stay in charge: nothing is built until you have
said yes to the plan, and you can stop any change.

For that to work, the project has to be set up the way a careful
developer would set it up: checks that catch mistakes before they get
in, rules that stop a change whose checks have not passed, and files
where Claude keeps the plan and the decisions, so it picks up where it
left off next time. Doing that by hand takes knowledge of exactly the how that
you want to leave to Claude. This bootstrapper does it for you: you
answer a few questions, and a script sets everything up. You do not
need to have typed commands before: this page gives every command to
copy. To begin, go to "Start here" below.

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
Claude app. Claude writes it down as a plan and asks you to confirm
it. Claude Code (a version of Claude that writes code) builds it,
writing the test first, and each change is reviewed by the other
Claude before it goes in. The project's files call these two roles
Clead (the one that plans and reviews) and Crog (the one that writes
the code).

## What you need, and what it costs

To set up the project (step 0 below installs the tools):

- **A computer** with Windows, macOS or Linux.
- **A GitHub account.** Free. Make one at https://github.com/signup.
  Anyone can see the files of a public project; only you, and the
  people you invite, can see a private one. On a free account, a public
  project gets full protection of its main version; protecting a
  private one needs a paid GitHub plan (https://github.com/pricing). If
  you choose a private project on a free account, the script offers you
  three ways on.
- **On Windows: Git for Windows.** Free. It gives you Git, which keeps
  track of every change to the project's files, and Git Bash, the
  window where you type the commands from this page.
- **On macOS and Linux: Git.** Free, and often there already. If it is
  missing, the script says so and shows how to install it.
- **gh, GitHub's tool for the command line.** Free. The script uses it
  to create the project on GitHub for you, signed in as you.
- **Only for a website, a TypeScript program or a mobile app: Node.js.**
  Free. It runs the tools these kinds of project are built and checked
  with, and the script uses it to set them up. If it is missing, the
  script says so and shows how to install it.

To work on the project with Claude afterwards:

- **A paid Claude plan.** Claude Code, which writes the code, is not in
  the Free plan. The cheapest plan with it is Pro: 17 US dollars a
  month when paid for a year at once (200 dollars), or 20 dollars a
  month when paid monthly, plus tax where it applies (prices as
  https://claude.com/pricing showed them on 2026-10-29).
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
