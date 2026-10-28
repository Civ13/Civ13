# Civ13 task completion

<!-- 2026-10-28: explicit PR finish line -->
## Completing a PR task

Done means: the change is committed and pushed, local checks were run and
reported, a dated PR comment is posted, and CI on the new head is checked.
Analysis alone is not done. If you found a valid issue in scope, fix it in
this turn.

Triage each review finding into exactly one of:

- valid: fix it, add or adjust a test that fails without the fix
- partly valid: apply the cheap defensive version, say why it is not a
  confirmed bug, and move on (do not wait for a reproducer)
- invalid: reply with a one-line reason and leave the code alone

Do not hold a finding for more evidence unless the fix itself is risky.

CI failures: read the failed job log before reacting. If the failure is
infrastructure (checkout or fetch timeout, runner cancelled, artifact
missing because an earlier step was cancelled), say so and push or rerun.
Do not change code for it.

Merge conflicts: when both sides add independent code in the same spot,
keep both and state the order you chose. Ask only when the two sides
actually contradict each other.

Tests must not depend on Git history (`git show <sha>`). Freeze any
historical source a test needs as a checked-in fixture, and prefer focused
behavior checks over whole-file equality.

Verification order: compile, then the focused tests for the touched area,
then push. Report the exact commands and results. Say plainly what was not
verified (native, in-game, save/load) and stop there. Unverified gameplay
is a note in the report, not a reason to block.

Ask the user only for decisions that are genuinely theirs: merging,
deploying, restarting servers, changing scope. Committing and pushing to
the PR branch you were assigned does not need approval.

For documentation-only work, mark compilation and gameplay checks not applicable,
run focused documentation checks, and report their exact commands and results.
Check the CI status and jobs for the pushed head; distinguish pending, failed,
skipped and passed checks. A pending check is not a pass.

## Task stopping rule

Start each task with one sentence naming its scope, deliverable and stopping
point. Respect any narrower or broader authority the user has explicitly given.
Example: "Shorten the agent guide, preserve the scoped notes, push a draft PR,
post a dated verification comment, and stop after checking CI on its head."
This example grants no merge or deployment authority.

Use this task template:

- Scope: paths, findings and behavior covered by this task.
- Stopping rule: one sentence stating the authorized finish line.
- Verification report: exact commands/results, CI head/status, and unverified items.
- Blocker, only if one remains: one decision question with a recommended answer.

Finish independent authorized work before raising a blocker. If genuinely blocked,
ask exactly one actionable question, include your recommended answer, then stop.

## Permissions and evidence

Operational restrictions govern actions: live-server changes, merging, deployment,
server restarts, held native runners, feature activation, credentials and security
settings retain their existing authorization boundaries. A source-fix task does
not itself authorize those operations. Use authorization already given in the
conversation; do not ask again for routine actions within that scope.

Evidence describes what was verified. Unverified native, in-game, graphical or
save/load behavior goes in the report; it never blocks a source fix or creates
a new approval requirement. Preserve real operational restrictions and report
missing evidence plainly without expanding either into unrelated work.
