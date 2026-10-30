# Newcomer pre-check

A check that runs before each human end-to-end run (PBI-1.30): a persona
who is a newcomer, played by a small AI model at low effort, reads the
two texts a newcomer meets, the bootstrapper's README and the screen of
the setup script, and reports every place where it stops. It does not
replace the human run: run 5 stays with a person who has never used gh or
a terminal (PBI-1.14, Done when 7). It cannot do what only a person meets:
installing programs, GitHub's sign-in in a browser, a window that
freezes.

This file is template-only (it is not in `bootstrap/manifest.txt`, so it
never ships; it is listed in `bootstrap/not-read-by-tests.txt`). It holds
what is used the same way every time: the persona, the instruction the
persona is given, the procedure, the stand-in values and the pass rule.
The spec is the PBI-1.30 entry in `docs/BACKLOG.md`. This file is a
process document: Crog reviews changes to it.

## The persona

Adam's, confirmed 2026-10-29. It is copied word for word and never
changed here.

- Role: someone with an idea for a small app who wants a project set up to build it.
- Qualities: uses Windows, a browser and email daily; reads carefully; follows written steps one at a time.
- Lacks: has never used a terminal, git, gh or GitHub; does not know words like repo, branch, PR or CI; does not know what Claude Code is.
- Rules of behaviour: uses only what is written on the page or printed by the script; stops at every word or step it cannot follow and reports it with the exact text; never fills a gap from its own knowledge.

## The instruction the persona is given

Used the same way every time: the text between the two lines of dashes,
with `{{PERSONA}}` replaced by the four lines of the persona above, and
`{{README}}` and `{{SCREEN}}` by the whole of `README.md` and the whole of
`screen.txt` (see the procedure), nothing added and nothing left out.

```
----------------------------------------------------------------------
You are going to act as one person, the persona below, and as nobody
else. Stay that person from the first line to the last.

{{PERSONA}}

Use no tools. Do not open files, web pages or programs, and do not run
anything. Use nothing but the two texts below, TEXT 1 and TEXT 2.

TEXT 1 is the page a newcomer is sent to first: the README of the
bootstrapper. TEXT 2 is everything the newcomer sees in the window while
they use the setup script: it shows what the script prints, and after a
question's colon what the newcomer typed (nothing after it means the
newcomer pressed Enter). A line of dashes in TEXT 2 only marks that the
window was closed and a new one opened; the script did not print it.

Go through TEXT 1 first, and then TEXT 2, in order, from the first line
to the end, as the persona would: read carefully and follow the written
steps one at a time. Where a text tells you to do something outside the
two texts (open a web page, install a program, sign in): if its words
tell you enough to do it, count it as done, with the result the text
says, and go on; if they do not, that is a stop. Never assume a result
the text does not state. Stop where the persona would stop: at every
word or step you cannot follow, or cannot do from what is written. Never
fill a gap from what you know.

When you have gone through both texts, report every stop, in the order
you met them, in exactly this format, and write nothing else:

STOP 1
Where: TEXT 1 or TEXT 2, and the heading, step or question just before it
Text: "the exact words, copied from the text, as few as make the stop clear"
Problem: what you did not understand, or could not do, in one or two sentences, as the persona

STOP 2
...

Last line: "I got to the end of TEXT 2." or, if you could not go on, where you
stopped and why. If you never stopped, write "No stops." and then the last
line.

TEXT 1
{{README}}

TEXT 2
{{SCREEN}}
----------------------------------------------------------------------
```

## The procedure

Clead does this.

1. **Choose the commit to check.** The one that is or will be released:
   after the release prep and before the tag, so the persona checks what
   will ship. For a release already tagged, `main` when
   `git diff <tag> main`, apart from the new test
   (`test_the_screen_of_the_setup_a_newcomer_meets_is_written_for_the_precheck`)
   and its line in `bootstrap/test-durations.txt`, touches nothing that
   the build ships or that the test uses; otherwise a branch from the tag
   with the test added.
2. **Make the two texts** from that commit, in a new folder given as an
   absolute path. Only the one test is run, by the harness's own
   switches: `BOOTSTRAP_TEST_SHARD=i/n` with n the number of tests and i
   the place of this test in the list runs exactly that test (it takes a
   few seconds, the whole harness more than an hour). i changes from commit
   to commit, so work it out each time:

   ```
   T=test_the_screen_of_the_setup_a_newcomer_meets_is_written_for_the_precheck
   n=$(BOOTSTRAP_TEST_LIST=1 bash bootstrap/test-bootstrap-project.sh | wc -l | tr -d ' ')
   i=$(BOOTSTRAP_TEST_LIST=1 bash bootstrap/test-bootstrap-project.sh | grep -n -x "$T" | cut -d: -f1)
   BOOTSTRAP_TEST_SHARD=$i/$n BOOTSTRAP_NEWCOMER_SCREEN=/absolute/path/to/folder \
     bash bootstrap/test-bootstrap-project.sh
   ```

   Check that the run says `1 passed, 0 failed` (an empty `i` or a
   different count means the test was not run).

   The test builds the bootstrapper from the commit with the harness's
   stand-ins, runs the built script twice as a newcomer meets it, and
   writes two files to the folder: `README.md` (the bootstrapper's
   README as the build writes it, `.github/README.md`, Markdown text) and
   `screen.txt`. Both must come from one run of the test on one build. If
   the test fails, nothing is given to the persona.
   - The first run starts where the README leaves a newcomer, on Windows
     in Git Bash with Node.js not installed. The newcomer answers every
     question (project name `tool-share`, display name `Tool Share`,
     description `Lets neighbours lend each other tools.`, language pack
     `web`, licence `mit`; Enter, the script's suggestion, at every
     other question), meets the guide for installing Node.js, and types
     `q` at its pause, the choice the pause line offers.
   - The second run is the command that stop shows, run in a new window
     with npm present; it asks "Proceed?", the newcomer types `yes`, and
     the setup goes through.
3. **Start the persona.** A fresh agent that has seen nothing of the work,
   on the smallest model Clead's agent tool offers (Haiku at the time of
   writing) at low effort, with the instruction above as its whole
   prompt. A bigger model knows more and fills more gaps, which is what
   the check must not do.
4. **Discard or keep the run.** The agent tool cannot stop the persona
   from using what it knows, so every text quoted in its report is
   searched for in `README.md` and `screen.txt`. The README is wrapped
   in lines and the screen is indented, so the quote and the two texts
   are compared with every run of spaces and line breaks made one space
   (`tr -s '[:space:]' ' '`), for example
   `grep -F -- "$(printf '%s' "$quote" | tr -s '[:space:]' ' ')" <(tr -s '[:space:]' ' ' <README.md)`
   (and the same with `screen.txt`). A run whose report quotes anything
   that is in neither is discarded and repeated from step 3; so is a run
   whose report is not in the format.
5. **Record each stop** in `docs/NEXT_SESSION.md`, like the findings of a
   human run: `p<version>-a`, `-b` and so on (the version checked), with
   the exact text, the persona's problem and Clead's verdict: a defect to
   fix, a stand-in artefact (below), or not a defect, with the reason.
6. **Fix and check again.** Fixes go out in a release (one more tag from
   Adam per round of fixes), and the check runs again on it, before the
   human run.

## Stand-in values and artefacts

The test uses the harness's build and stand-ins, so the screen shows
these values; a stop at one of them is a stand-in artefact:

- the version `v9.8.7`, the harness's fake commit
  (`0123456789abcdef0123456789abcdef01234567`) and the harness's fake
  date `2031-02-03`;
- the GitHub account `octo-user` (profile name `Octo User`), which gh is
  signed in to, and the stand-in git name and email in the suggested
  answers (`Test Person`, `test@example.com`);
- the stand-in `gh`, whose version (`0.0.0`) the screen does not show;
- the bash version in the first check, which is the one that ran the
  test;
- the folder after `cd` in the command the script shows to start again
  (`cd '...' && bash bootstrap-project.sh --again`), which is the test's
  temporary folder, not a newcomer's own; it is the only part of that
  command that comes from the test;
- the screen has no colours, though the script's colour key names them;
- the README is Markdown text, not the page as GitHub shows it;
- the checks of GitHub are instant, so the wait for `build` shows no
  signs of life;
- the answers are written after their questions by the test, as a
  terminal would show them; the line of dashes between the two runs is
  the test's.

## The pass rule

The check passes when every stop is fixed, or recorded as a stand-in
artefact or as not a defect with its reason, and the run that shows this
was not discarded. After fixes the check runs again on the release that
holds them (step 6).
