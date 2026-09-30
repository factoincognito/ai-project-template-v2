# Development Infrastructure

How a project made from this template is set up, built and checked: a
new machine, CI, branch protection, commits, and the setup for each
language pack. The rules for code in each language live in the pack's
`code-standards.md`; this file covers everything around the code.

Part 1 applies to every project. Part 2 has one section per language
pack.

---

## Part 1: Every project

### 1. Principles

- **Automate what is mechanical, keep judgment human.** Formatting,
  linting, type checks, tests and the coverage gate run in CI and block
  the merge when they fail. Design and spec questions go to review.
- **A new machine is productive in minutes.** Clone, run the pack's
  "First-time setup", done. Nothing depends on one person's machine.
- **Nothing reaches `main` without a pull request and a green CI run.**
  GitHub enforces this, not convention (section 4).
- **Only what the project needs.** Every tool here earns its place;
  more is added when the project needs it (section 7).

### 2. New machine setup

1. Install git and VS Code. For Crog, install the Claude Code extension
   in VS Code.
2. Install the runtime for the project's language pack (Part 2):
   Node.js 24 for `node`, `web` and `react-native`, Python 3.14 for
   `python`.
3. Clone the repo and open the folder in VS Code. Accept the
   recommended extensions when VS Code offers them
   (`.vscode/extensions.json`, from the pack).
4. Run the pack's "First-time setup" (Part 2), then its full CI command
   list once. If everything passes, the machine is ready.

No git line-ending settings are needed on any OS: `.gitattributes`
handles it (section 3).

### 3. Scaffolding every project has from day one

Both of these ship with every project made from the template. They are
part of the starting files, not something to add later.

**`.gitattributes`** at the repo root sets `* text=auto eol=lf`: LF line
endings in the repo and in every checkout, on every OS. Why it is
mandatory: in an earlier project, an editor set to "auto" line endings
silently rewrote whole files between LF and CRLF when edits made on
Windows and elsewhere touched the same file. It happened three separate
times on one pull request, and the fix came only after the damage.
With the policy pinned from the first commit, that class of bug cannot
happen. Do not remove it or override it per file without a
reason recorded in `memory/decisions.md`.

**`docs/NEXT_SESSION.md`** is the staging area for reasoning, revised
assumptions and plan changes that are not yet ready to be a backlog
item, a decision or a doc change. It is wired into the session routine
in `CLAUDE.md`: Clead reads and triages it at every session start, and
every entry touched in a session is promoted, re-affirmed or deleted
(the graduation rule) before the session counts as clean. Why it is
mandatory: in an earlier project the same kind of file was added
mid-project, never wired into the session start, and went unread for
nearly a month. The file and its wiring come together; one without the
other does not work.

### 4. Branch protection runbook

**What it enforces.** On `main`: every change arrives through a pull
request, the required CI checks must pass before it can merge, and
nobody can bypass it, admins included. The pull request needs **no**
approvals: every PR is opened under the owner's own GitHub account, and
GitHub does not let authors approve their own PRs. Review happens as a
verdict comment instead (see `CLAUDE.md`, "Change execution model").

**Turning it on in a new project** (repo owner, once, after the first
push of the pack's `ci.yml`):

1. Push a branch and let CI run once. The required-checks picker only
   offers checks that have run in the repo recently.
2. Settings, Branches, add a branch protection rule for `main`.
3. Tick "Require a pull request before merging" and set required
   approvals to 0.
4. Tick "Require status checks to pass before merging" and add `build`,
   plus any other check your CI adds that must pass. Every pack's
   `ci.yml` has one job, named `build`, so `build` alone covers it.
5. Tick "Do not allow bypassing the above settings".
6. Save.

On GitHub's free plan this is only available for public repositories.

**Checking that it works.** Open a pull request with a deliberately
failing test: the merge button must stay blocked until the check is
green. Then close it without merging. A setting that shows as "on" is
not proof on its own.

**In the template repo.** The template's own `main`
(https://github.com/sugose/ai-project-template-v2) is protected the
same way, with two required checks: `build` and `bootstrapper-test`.
The second tests the template's release pipeline, which projects do not
have. A project sets its own required checks and does not copy the
template's.

### 5. CI/CD

**CI runs on every push to any branch and on every pull request to
`main`** (GitHub Actions, `.github/workflows/ci.yml`). A new project
starts with a stub `ci.yml` that only checks out the code; the language
pack's `ci.yml` replaces it.

The rules every pack's CI follows:

- **One job, named `build`.** Branch protection requires a check by
  that name. Rename the job and every pull request waits for a `build`
  check that never arrives, until the required check is changed too.
- **Green on day one.** A fresh project passes its own CI with no
  changes; each pack ships a placeholder or starter test for that.
- **CI enforces what a tool can check.** Where `code-standards.md`
  states a rule a tool can check (types, lint, formatting, the 80% line
  coverage gate), CI fails when it is broken. Rules no tool checks are
  for review.
- **The same checks locally and in CI.** Each pack's
  `code-standards.md` gives the commands to run the checks locally.
  Before pushing, run the same steps as the project's `ci.yml`, in
  order.
- **Pinned versions.** Tool versions are pinned exactly and refreshed
  together, in one change, with a full CI run.

**CD.** None by default. The `web` pack ships an optional workflow that
deploys to Cloudflare on every push to `main`; it does not re-run the
tests, so it is only safe once branch protection requires `build`.

### 6. Commits, branches and pull requests

- **One PR, one change.** Unrelated changes never share a PR.
- **Branch names:** `feature/<short-description>` or
  `fix/<short-description>`, e.g. `feature/udp-listener`,
  `fix/multicast-join-error`.
- **Commit messages:** imperative, present tense, specific. Say what the
  commit does, not what you did. Good: `Add configurable UDP listener
  with multicast support`. Bad: `Added stuff`, `WIP`, `fix`.
- **Squash merge.** A PR lands on `main` as one commit, titled after the
  PR, so the PR title follows the same convention. Delete the branch
  after the merge, or turn on "Automatically delete head branches" in
  the repo settings (Settings, General, Pull Requests) so GitHub does
  it.

### 7. Deliberately left out

Added when a project needs them, not before: Docker, continuous
deployment beyond the web pack's optional workflow, CI matrix builds
across OSes, automated dependency updates, status badges, secrets
management (until there is a secret).

---

## Part 2: Per language

Each pack's `code-standards.md` is the reference for its rules and
commands. It sits in `languages/<pack>/` in a new project; if that
folder has been deleted after setup, the same file is in the template
repo at https://github.com/sugose/ai-project-template-v2/tree/main/languages.

### Python (`python` pack)

**Version.** Python 3.14. CI uses the latest 3.14 release that
`actions/setup-python` offers; use the same minor version locally.

**Virtual environment.** Always work in `.venv`, never in the system
Python. Once per clone:

```bash
# macOS / Linux
python3.14 -m venv .venv
source .venv/bin/activate

# Windows
py -3.14 -m venv .venv
.venv\Scripts\activate
```

Activate it again in every new terminal.

**Install, then the pre-commit hook.**

```bash
pip install -r requirements.txt -r requirements-dev.txt
pre-commit install
```

`requirements.txt` holds what the application needs to run;
`requirements-dev.txt` holds Ruff, mypy, pytest, pytest-cov and
pre-commit. Both pin every entry exactly. There is no lockfile, so the
dependencies of those packages are not pinned; add a lock tool if the
project needs fully repeatable installs. After `pre-commit install`,
every `git commit` runs Ruff on the staged files and stops the commit
on any problem. Problems Ruff can fix are fixed in the files; stage
them and commit again.

**The checks, as CI runs them.**

```bash
ruff check .                          # lint
ruff format --check .                 # formatting
mypy                                  # strict type check of src/
pytest --cov=src --cov-fail-under=80  # tests and the coverage gate
```

**Run as a module, from the project root.** Always
`python -m src.<module>.main`, never `python src/<module>/main.py`. Run
as a script, the imports `from src.<module> import ...` fail with
`ModuleNotFoundError: No module named 'src'`, on every OS.

**Gotcha: `MagicMock(spec=...)` inside `patch`.** Building
`MagicMock(spec=socket.socket)` inside `with patch("socket.socket"):`
raises `InvalidSpecError: Cannot spec a Mock object`, because the patch
has already replaced `socket.socket` with a mock. Build the mock before
the patch and hand it in:

```python
mock_sock = MagicMock(spec=socket.socket)   # before the patch
with patch("socket.socket", return_value=mock_sock):
    ...
```

It is often described as a Python 3.14 problem; it is not. Python 3.11
and 3.14 both fail the same way.

Details: `languages/python/code-standards.md`.

### Node.js and TypeScript (`node` pack)

Node.js 24, Biome, TypeScript strict mode, Jest with an 80% line
coverage gate. The first `npm install` creates `package-lock.json`,
which the project commits, because CI installs with `npm ci`. Setup and
commands: `languages/node/code-standards.md`.

### Static web page (`web` pack)

Everything in the `node` pack, plus a Vite build into one
self-contained HTML file and Playwright browser tests. Setup, commands
and the optional Cloudflare deploy: `languages/web/code-standards.md`.

### Mobile app (`react-native` pack)

Expo SDK 57 with React Native 0.86 and React 19.2, TypeScript strict
mode, Biome, and Jest through the `jest-expo` preset with React Native
Testing Library for components, under an 80% line coverage gate. The
first `npm install` creates `package-lock.json`, which the project
commits. The Expo, React, React Native, Jest and TypeScript versions
move together with the SDK: add libraries with `npx expo install`, and
upgrade the SDK as one change.

CI checks only what runs in Node on a Linux runner: lint and format,
the type check, and the tests. It does not build the app for Android
or iOS, run it on a device or simulator, or use EAS, which need
platform tooling (Xcode needs macOS) or an Expo account. Try changes
the tests cannot see on a phone with Expo Go. Setup, commands and the
full list of what CI does not check:
`languages/react-native/code-standards.md`.
