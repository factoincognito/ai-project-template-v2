# Process P-5. Refusals by Claude's permission check, and missing capabilities

P-5 § 1 Missing capabilities
(1) Before calling something unavailable, a session checks its own tool list.
(2) If a capability is really missing, the session says so plainly and uses the standard route; where no standard route exists, it stops that step in accordance with § 15 (3).

P-5 § 2 (C) Refused merges
(1) Keeping the product owner out of the merge route is Claude's responsibility. A session shall not ask the product owner to merge, or to delegate a merge, while a route under P-5 § 3 (1) remains untried.
(2) When every merge route the session has is refused, the session shall not leave the merge to a later run. It asks the product owner to delegate the merge in chat, with a one-line prompt it writes, naming the PRs, given as a code block.
(3) Only where the merge is still refused after that delegation does the session give the product owner the exact steps to merge themselves.

P-5 § 3 Handling a refused merge
(1) A session whose merge, or a step of whose merge route, is refused retries through the route and looks up how merges went through before, in the project's staging file.
(2) It records each refusal and what it tried in the project's staging file.
(3) If the merge still cannot be made, it proceeds in accordance with P-5 § 2 (2) and (3).

P-5 § 4 Refused changes that are delegated
(1) A refused change that these Rules already delegate is not put to the product owner while a route for it remains untried. The session retries it through the route and records the refusal and what it tried in accordance with P-5 § 3 (1) and (2).
(2) When every route the session has for that change is refused, the session proceeds as for a refused merge, in accordance with P-5 § 2 (2) and (3).

P-5 § 5 Refused changes that are not delegated
(1) For a refused change that these Rules do not delegate, the session gives the product owner, in the For you block, first the option to delegate it with a one-line prompt the session writes for that change, modelled on "I approve of the change you want to apply and I am delegating to you to apply it", given as a code block; and, as the fallback, the exact text or steps to make the change themselves.
(2) The session then retries once.

P-5 § 6 Refused startup attach
(1) A refused attach at startup is handled in accordance with Process P-1 § 2 (2) and (6).
