# Project

**Name:** ai-project-template-v2
**Repo:** factoincognito/ai-project-template-v2
**Description:** A second-generation template for AI-assisted software
development using the Clead + Crog workflow. Built from scratch to replace
ai-project-template (v1), which accumulated complexity proportional to
workarounds rather than to the underlying problem.

**Goals:**
- Everything needed to run the workflow (human or agent) is in this
  repo and in the product office whose Rules it is bound to. Each
  project made from it gets its own copy of the Rules (the public
  edition), so a made project is self-contained.
- Adam's involvement reduced to the WHAT: describe the PBI, and make
  the decisions only he can make. Reviews and merges are delegated;
  he can stop any merge.
- No scaffolding inherited from constraints that no longer exist
- A workflow that a new Clead instance can cold-start from this repo
  and the product office, without Adam providing orientation

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
