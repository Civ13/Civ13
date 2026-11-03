---
name: github-workflow-troubleshooting
description: Diagnose GitHub pull-request, branch, permission, and Actions failures when merge readiness or CI evidence is ambiguous. Use for stale stacked PRs, interrupted pushes, misleading green checks, and workflow dispatch or artifact problems; not as a substitute for code review or a security audit.
---

# GitHub workflow troubleshooting

Resolve the specific workflow problem using current repository evidence. Separate source defects, workflow defects, missing evidence, policy holds, permissions, and transient transport failures before choosing a remedy.

## Establish the actual state

Record the repository, PR and base/head refs, exact head SHA, workflow run and attempt, event type, checked-out SHA, and relevant job conclusions. Read repository instructions and the user's current authorization before making changes. Refresh mutable state immediately before a push, PR creation, branch update, or merge.

A green summary is not proof that the requested work ran. Inspect individual jobs and matrix cells, their conditions, and the artifacts they produced. Distinguish **passed**, **failed**, **skipped**, **pending**, and **not observed**; report coverage gaps plainly.

Use one monitoring owner per PR. Reuse a shared record of the exact head,
workflow/run/attempt and job outcomes while those identities remain unchanged;
refresh on meaningful state changes and immediately before an authorized external
action. Keep independent authorized work moving while a particular action is
blocked, carrying scope, authorization limits and blocker state as CODEX.md
describes. This does not authorize extra workers or bypass confirmations.

Read only the reference needed:

- [PR, branch, and permission problems](references/pr-and-permissions.md): stacked bases, interrupted pushes, merge gates, reviews, and permission failures.
- [Actions and evidence problems](references/actions-and-evidence.md): wrong commits, skipped coverage, first pushes, manual dispatch, toolchains, and artifacts.

## Authorization and retries

This skill supplies procedures, not permission. Do not embed standing approvals or turn a past approval into authority for a future action. Apply current user instructions and platform permissions to the exact action and target. Permission to merge is distinct from permission to submit a formal approving review; neither implies permission to change protection rules or security settings.

For a transient timeout or connection failure, first reconcile state through permitted read operations. Retry only an authorized, still-needed action, with a risk-appropriate bound; never create duplicate PRs or blindly repeat uncertain writes.

For an explicit denial, stop that action. Do not switch accounts, tokens, tools, API routes, transports, or privilege modes to bypass it. Reconsider only the exact denied action and target when materially new, relevant approval or evidence legitimately changes its authorization. For a known-unexecuted operation, retry at most once per such change; never repeat attempts on the same evidence. If denied again, stop unless another material authorization change occurs. A continuing authorization blocker is not a transient transport problem.

## Close the loop

Verify the remedy against the current head and the intended checks, not merely against a successful command exit. For a requested finish or monitoring task, continue permitted work until its stated outcome, a real blocker, or the user's stopping condition is reached. Report useful findings promptly without claiming completion early.

If blocked, state the exact action, target, reason, and whether it is **denied**, **pending approval**, or **uncertain**. Describe what is already verified and the smallest authorized next step. Avoid exposing credentials or copying private logs into reports or this skill.
