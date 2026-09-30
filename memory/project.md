# Project

**Name:** ai-project-template-v2
**Repo:** sugose/ai-project-template-v2
**Description:** A second-generation template for AI-assisted software
development using the Clead + Crog workflow. Built from scratch to replace
ai-project-template (v1), which accumulated complexity proportional to
workarounds rather than to the underlying problem.

**Goals:**
- A self-contained repo — clone it and everything needed to run the
  workflow (human or agent) is inside it
- Adam's involvement reduced to two touchpoints: describe the PBI,
  approve the merge
- No scaffolding inherited from constraints that no longer exist
- A workflow that a new Clead instance can cold-start from the repo
  alone, without Adam providing orientation

**Definition of done for this phase:**
The skeleton is committed and a real project has been bootstrapped from
it, proving the template works end to end. The pilot is acuteping
(the sonar calculator, first project created from v2), decided
2026-09-30; it replaced python-blackjack-v2, which stays in the backlog
with no date.

## Migration source
N/A — this is the template repo itself, not a migration.
The reference implementation is sugose/ai-project-template (v1).
v1 is the source of learning, not the source of files.
