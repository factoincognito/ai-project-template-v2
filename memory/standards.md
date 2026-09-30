# Clead Review Standard

Every PR reviewed by Clead must include all of the following,
without being asked.

## 1. Threat model statement
State the threat model before findings.
Example: "Reviewing this as a game engine — primary risks are incorrect
payout logic, silent state mutation, and non-deterministic test failures."

## 2. Spec compliance check
Check against docs/SPEC.md. Confirm or flag:
- Does the implementation match what the spec says this component must do?
- Does the public interface match the spec contract?
- Does this actually solve the PBI? (First-principles check — distinct
  from spec compliance. A spec can be complied with and still not solve
  the PBI if the spec was wrong.)

## 3. Error handling and type validation — second pass
After the general review, an explicit second pass:
- Every validation function: edge cases handled correctly?
- Every error path: exceptions caught at the right level?
- Every external input: validated before use?
- Any type coercion that could silently accept unexpected values?

## 4. Test quality check
Coverage percentage and test count are necessary but not sufficient.
- Does the PR include a test coverage narrative table? If not, request
  it before approving.
- For each row: does the named test actually assert what the table claims?
- Are all non-trivial error paths and recovery behaviours represented?
- For every error path, is there a test verifying correct recovery —
  not just that a warning was logged?

## 5. What I did not check
Every approval must end with an explicit list of what was not verified.
A claim of "checked" or "confirmed" must come from a check that actually
verifies the specific claim — not a proxy signal (e.g. a keyword or
substring match on a page) that can produce false positives. If the
available check is indirect, either do the direct check instead, or
state the claim with its real uncertainty rather than asserting it
flatly. (Real incident, fomo-f, 2026-07-23: claimed a PR review comment
existed based on a page-text keyword match; it was a false positive from
unrelated content elsewhere on the page. Caught only because the user
asked for clarification — the check itself had not actually confirmed
anything.)

## 6. Verdict discipline
- Verdict posted directly as a PR comment. No relay through Adam.
- Fix prompts posted directly to the PR for Crog to pick up.
- After 3 review cycles without resolution: escalate to Adam.
  This is a safety control, not relay work. The escalation message
  opens with the reason and gives Adam what he needs to decide:
  1. Why he is getting it: "Escalated after 3 review rounds on #N
     without agreement."
  2. What the reviewer and author disagree on, in plain words.
  3. Each side's position, one or two lines each.
  4. The decision needed, as a question he can answer directly.

## 7. Reviewer independence — hard constraint
The review must run as a separate invocation from the implementation
conversation. Inputs: {diff, docs/SPEC.md, memory/standards.md} only.
Do not load design-time memory or implementation conversation history
into the review context. This is structural, not conventional.

## Test coverage narrative table (required on all code PRs)
| Behaviour under test | Test name | What it asserts |
|---|---|---|
| | | |
One row per non-trivial behaviour. Error-path rows mandatory.
Happy-path rows optional.
