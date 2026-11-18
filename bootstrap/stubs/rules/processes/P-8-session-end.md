# Process P-8. Session end

P-8 § 1 Writing as the work goes
(1) Records are written when a decision is made and when a PR opens, whether or not the session ends with a check. The end-of-session check catches what was missed.
(2) No stop word is used. There is no automatic end-of-session hook, so the session runs the end-of-session check itself.

P-8 § 2 End-of-session check
Whenever a session reports work as done, and when the product owner says they are stopping, in any words, the session, before replying:
(1) gives every staging-file entry it touched a disposition in accordance with P-8 § 4, and resolves every pin it wrote this session in accordance with Process P-9 § 5;
(2) writes anything agreed in the session and not yet written down, to the container Process P-9 assigns, into the PR that § 18 (1) assigns;
(3) runs the check of P-8 § 3 last, so that it checks the state after (1) and (2);
(4) reports the session clean, or what is open and why, links the PRs from (2), and shows the product owner the diff of every memory file touched.

P-8 § 3 Clean session end state
A session is clean only when each of the following was checked in this session, not assumed from an earlier report:
(1) `git status` is clean in every repository touched, carry-over from earlier sessions included;
(2) every PR opened in the session, a records PR of § 18 (1) included, is merged and verified in accordance with Process P-4 § 3, or left open with the product owner's knowledge and a stated reason;
(3) every follow-up is persisted in the repository, in the container Process P-9 assigns; private memory does not count;
(4) every claim of done or confirmed rests on a direct check of that claim;
(5) `CHANGELOG.md`, where the project keeps one, reflects all merged PRs except the one documenting itself;
(6) "no open items" is checked against the actual threads (uncommitted diffs, unmerged PRs, unchecked claims), not against an empty tracking list;
(7) every pin of the session is in the backlog or has been dropped by the product owner.

P-8 § 4 Graduation of staging entries
(1) Every staging-file entry touched in a session is promoted (to a backlog item, a decision or a document), re-affirmed as still next, or deleted as resolved or obsolete before the session is clean.

P-8 § 5 One task per session
(1) A session does one task; the next task starts in a fresh session.
(2) The handover of what is not finished is written to the repository, in the container Process P-9 assigns, before the session tells the product owner to start a fresh session.
(3) In a session the product owner starts, Clead tells the product owner, when its task is done, to start a fresh session for the next one. In the same reply it gives the product owner, as a **Now** item of its For you block and as one code block, the complete first message for that session. The message holds, in this order: the start line of Process P-1 § 2 (5); the delegation line of Process P-1 § 7 (1); one marker line, `--- End of the generic startup message ---`, which ends the generic startup part (the two lines before it); and, after the marker, the next task where one is open. Where none is open, the message ends at the marker.
(4) A session the product owner starts whose earlier turns have been replaced by a summary (Process P-1 § 1 (3)) is not resumed, also when it works unattended. Once it has read the Rules again as that paragraph requires, it does no further work on its task: it writes the handover as (2) sets out, runs the end-of-session check of P-8 § 2, and tells the product owner in the way (3) sets out, with the task in hand as the next task and the place of its handover in the first message; while the product owner is away, that message goes into the report of Process P-10 § 1 (4). Process P-1 § 1 (3) alone applies to an agent and to a scheduled run.
