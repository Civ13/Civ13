# Civ13 task completion

<!-- 2026-10-28: explicit PR finish line -->
## Completing a PR task

Done means: the change is committed and pushed, local checks were run and
reported, a dated PR comment is posted, and CI on the new head is checked.
Analysis alone is not done. If you found a valid issue in scope, fix it in
this turn.

Publish completed work that is ready for review and merge as a regular PR.
Reserve drafts for unfinished work or actual unresolved blockers. Pending CI
alone does not require draft status; required checks still apply before merging.
Unverified native/in-game testing is a report note, not by itself a reason for
a draft or a merge hold. This PR-status preference does not expand merge,
deployment or live-server authority.

Triage each review finding into exactly one of:

- valid: fix it, add or adjust a test that fails without the fix
- partly valid: apply the cheap defensive version, say why it is not a
  confirmed bug, and move on (do not wait for a reproducer)
- invalid: reply with a one-line reason and leave the code alone

Do not hold a finding for more evidence unless the fix itself is risky.

CI failures: read the failed job log before reacting. If the failure is
infrastructure (checkout or fetch timeout, runner cancelled, artifact
missing because an earlier step was cancelled, BYOND download or compile
prevented by runner infrastructure), say so and push or rerun. Do not change
code for it. Apply the documented local-build exception below when successful
equivalent compilation is available.
Such a GitHub build failure is not a hard blocker: when a rerun fails the same
way, document the local compile and preflight results for the exact head in
the PR comment, and an authorized merge may then proceed as an admin merge
(see the `civ13-pr-preflight` skill). Real test or compile failures still block.

Merge conflicts: when both sides add independent code in the same spot,
keep both and state the order you chose. Ask only when the two sides
actually contradict each other.

Tests must not depend on Git history (`git show <sha>`). Freeze any
historical source a test needs as a checked-in fixture, and prefer focused
behavior checks over whole-file equality.

Verification order: compile, then the focused tests for the touched area,
then `python3 scripts/agent_preflight.py all --write`, then push. Report the exact commands and results. Say plainly what was not
verified (native, in-game, save/load) and stop there. Unverified gameplay
is a note in the report, not a reason to block.

Ask the user only for decisions that are genuinely theirs: merging,
deploying, restarting servers, changing scope. Committing and pushing to
the PR branch you were assigned does not need approval.

For documentation-only work, mark compilation and gameplay checks not applicable,
run focused documentation checks, and report their exact commands and results.
Check the CI status and jobs for the pushed head; distinguish pending, failed,
skipped and passed checks. A pending check is not a pass.

PR comments: one dated comment per pushed head, in plain sentences, ideally
under 150 words. Give the change, the commands and results, the CI run link
and what is unverified. Do not repeat unchanged "not run" lists or internal
review-process narration in every comment.

## Local build after a hosted infrastructure failure

<!-- 2026-11-03: exact-revision local compilation can replace unavailable hosted build evidence -->
A verified GitHub infrastructure failure, such as an unavailable BYOND download,
does not by itself block an otherwise authorized push or source-PR readiness
when a documented successful local build covers the exact revision and intended
build target. Read the failed job log first; an unknown failure is not an
infrastructure exception. Follow the [evidence procedure](.agents/skills/github-workflow-troubleshooting/references/actions-and-evidence.md#local-build-evidence-after-infrastructure-failure).

Record the exact clean commit, pinned compiler version, OS, build target,
configuration and generated inputs, full command/log, exit status and diagnostic
counts. Explain any platform or build-input differences and what the local
build actually covers. Preserve the failed GitHub run/job/attempt and its cause;
report "hosted build failed; local compilation passed" rather than marking CI
passed. A fixture compile cannot replace a required full-game build.

This exception covers compilation evidence only. Source/compiler/test failures,
checksum or toolchain-integrity failures, conflicts, other required checks,
reviews and explicit holds still apply. This evidence exception alone grants no
merge, deployment, history-rewriting force-push, security-setting or
branch-protection authority.
If a protected gate requires an override, use only an already authorized action
permitted by the environment and its action-time requirements; otherwise report
that gate. Never bypass an approval denial or manufacture a successful check.

## Task stopping rule

Start each task with one sentence naming its scope, deliverable and stopping
point. Respect any narrower or broader authority the user has explicitly given.
Example: "Shorten the agent guide, preserve the scoped notes, open a regular PR,
post a dated verification comment, and stop after checking CI on its head."
This example grants no merge or deployment authority.

Use this task template:

- Scope: paths, findings and behavior covered by this task.
- Stopping rule: one sentence stating the authorized finish line.
- Verification report: exact commands/results, CI head/status, and unverified items.
- Blocker, only if one remains: one decision question with a recommended answer.

Finish independent authorized work before raising a blocker. If a user decision
is required, ask one actionable question with a recommended answer. Stop the
dependent action while continuing independent work within the authorized scope.

## Ownership, handoffs and blockers

<!-- 2026-11-03: avoid idle lanes and duplicate monitoring -->
Keep one owner per branch/PR, including its push and CI follow-up. Before editing,
inspect the checkout, branch and existing task ownership; preserve unrelated work.
Use a separate checkout if another worker owns the branch. Do not spawn workers
or expand the roadmap merely because an action is blocked.

For a handoff, record the repository/worktree, owner, branch/PR, exact base/head
SHAs, changed paths, stopping rule, completed checks and next dependency. Carry
the relevant user authorization with its exact action, target and limits, plus
remaining action-time confirmations or holds. Authorization in a handoff is
context, not a new permission grant or a substitute for required confirmation.

Track each blocker separately: action/target, reason, denied/pending/uncertain
state, completed work, and the evidence or decision needed to resume. A blocked
publication or native test need not stop independent implementation, review or
offline checks. Follow the existing denial/retry rules; reconcile an uncertain
outcome before retrying and never route around a denial.

Keep a compact CI record per PR: head, workflow/run/attempt, selected jobs and
latest outcomes. One owner checks an unchanged run; share that record rather
than repeating checks in multiple tasks. Recheck when the head, run attempt,
job state or required policy changes, and refresh immediately before an
authorized external action. Preserve failed evidence and intentional skip reasons.

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
