---
name: civ13-pr-completion
description: Finish a Civ13 PR task - task template and stopping rule, review-finding triage, CI failure handling, merge conflicts, the dated PR comment, ownership handoffs and blockers. Use when opening, updating, reviewing or finishing any Civ13 PR.
---

# Completing a Civ13 PR task

Done means: the change is committed and pushed, local checks were run and
reported, a dated PR comment is posted, and CI on the new head is checked.
Analysis alone is not done. If you found a valid issue in scope, fix it in
this turn. Run `civ13-pr-preflight` before the first push; use
`civ13-merge-and-changelog` for the `Changelog:` line and merging.

## Task template

Start each task with one sentence naming its scope, deliverable and stopping
point. Example: "Shorten the agent guide, preserve the scoped notes, open a
regular PR, post a dated verification comment, and stop after checking CI on
its head." The example grants no merge or deployment authority.

- Scope: paths, findings and behavior covered by this task.
- Stopping rule: one sentence stating the authorized finish line.
- Verification report: exact commands/results, CI head/status, and unverified items.
- Blocker, only if one remains: one decision question with a recommended answer.

## PR status

Publish completed work that is ready for review and merge as a regular PR.
Reserve drafts for unfinished work or actual unresolved blockers. Pending CI
or unverified native/in-game testing alone is not a reason for a draft or a
merge hold. PR status does not expand merge, deployment or live-server authority.
Fill the headings of `.github/pull_request_template.md`.

## Review findings

Triage each finding into exactly one of:

- valid: fix it, add or adjust a test that fails without the fix
- partly valid: apply the cheap defensive version, say why it is not a
  confirmed bug, and move on (do not wait for a reproducer)
- invalid: reply with a one-line reason and leave the code alone

Do not hold a finding for more evidence unless the fix itself is risky.

## CI failures

Read the failed job log before reacting. If the failure is infrastructure
(checkout or fetch timeout, runner cancelled, artifact missing because an
earlier step was cancelled, BYOND download or compile prevented by runner
infrastructure), say so and push or rerun; do not change code for it. When a
rerun fails the same way, the documented local build in `civ13-pr-preflight`
(section 5) may stand in for compilation evidence. Real test or compile
failures still block.

Check the CI status and jobs for each pushed head and distinguish pending,
failed, skipped and passed checks. A pending check is not a pass.

## Merge conflicts

When both sides add independent code in the same spot, keep both and state
the order you chose. Ask only when the two sides actually contradict each
other. Generated files and shared registries: see `civ13-pr-preflight`.

## PR comments

One dated comment per pushed head, in plain sentences, ideally under 150
words: the change, the commands and results, the CI run link and what is
unverified. Do not repeat unchanged "not run" lists or internal review-process
narration in every comment.

## Ownership, handoffs and blockers

Keep one owner per branch/PR, including its push and CI follow-up. Before
editing, inspect the checkout, branch and existing task ownership; preserve
unrelated work. Use a separate checkout if another worker owns the branch. Do
not spawn workers or expand the roadmap merely because an action is blocked.

For a handoff, record the repository/worktree, owner, branch/PR, exact
base/head SHAs, changed paths, stopping rule, completed checks and next
dependency. Carry the relevant user authorization with its exact action,
target and limits, plus remaining action-time confirmations or holds.
Authorization in a handoff is context, not a new permission grant or a
substitute for required confirmation.

Track each blocker separately: action/target, reason, denied/pending/uncertain
state, completed work, and the evidence or decision needed to resume. A
blocked publication or native test need not stop independent implementation,
review or offline checks. Follow the existing denial/retry rules; reconcile an
uncertain outcome before retrying and never route around a denial.

Keep a compact CI record per PR: head, workflow/run/attempt, selected jobs and
latest outcomes. One owner checks an unchanged run; share that record rather
than repeating checks in multiple tasks. Recheck when the head, run attempt,
job state or required policy changes, and refresh immediately before an
authorized external action. Preserve failed evidence and intentional skip reasons.

## Permissions and evidence

Operational restrictions govern actions: live-server changes, merging,
deployment, server restarts, held native runners, feature activation,
credentials and security settings keep their existing authorization
boundaries. A source-fix task does not itself authorize those operations. Use
authorization already given in the conversation; do not ask again for routine
actions within that scope.

Evidence describes what was verified. Say plainly what was not verified
(native, in-game, graphical, save/load) and stop there; it never blocks a
source fix or creates a new approval requirement.
