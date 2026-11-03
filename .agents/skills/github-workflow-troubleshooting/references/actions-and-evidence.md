# Actions and evidence problems

## Check the code actually tested

Compare the current PR head SHA with the workflow event SHA and checked-out commit. A PR run may test a synthetic merge commit rather than the literal head; establish its parents and base before calling that a mismatch. A successful run for an earlier head is historical evidence, not confirmation of the current change. Re-run or trigger checks only when authorized and appropriate to the event and workflow.

## Green summaries with missing coverage

Before publication, compare the exact diff and intended regression with the
repository's selector and the test job's event/path/input conditions. Local
offline impact output is only one part of that check. After publication,
inspect the selection receipt and actual test results for the current head,
run and attempt. Record any unselected regression explicitly; request only
an authorized focused run and preserve separate native execution holds.

Inspect native-build, extraction, integration, and matrix jobs rather than trusting a summary badge. A skipped job may be intentional, but is not a passing test. Identify the condition that skipped it and whether the requested validation actually requires it.

For PHP, a green version-policy check does not establish that every supported runtime installs dependencies or passes tests. Examine installation and test results for every intended matrix cell, including the selected PHP version, extensions, package-manager version, lockfile, and dependency resolution. Diagnose the first meaningful failure, not only the final summary.

Classify docs-only changes from the full diff and the repository's CI rules, including renames and deletions. Workflow files, build scripts, executable examples, generated inputs, and extraction fixtures may affect runtime or validation even when adjacent to documentation. Do not label a change docs-only just to make expensive or failing checks disappear.

## Local build evidence after infrastructure failure

Apply the [repository policy](../../../../CODEX.md#local-build-after-a-hosted-infrastructure-failure)
when GitHub cannot obtain or run the toolchain for a verified infrastructure
reason and successful equivalent local compilation is available:

1. Read and retain the failed run/job/attempt log. Identify the first failing
   operation and its cause, such as a BYOND download outage or runner loss.
   Do not infer infrastructure from a red badge, a missing artifact alone or
   a local pass. Compiler diagnostics, test/assertion failures, checksum/version
   mismatches and unknown causes are not covered by this exception.
2. Bind the local build to the exact PR head (or explicitly identified proposed
   revision), with tracked source matching that clean commit before and after.
   Use the current pinned compiler and equivalent build target, flags, configs,
   dependencies and generated inputs. Record OS/platform differences; local
   Windows compilation does not establish Linux packaging or runtime behavior.
   A dirty tree, old revision, stubbed compiler or fixture-only compile cannot
   establish a successful full-game build of the current head.
3. Retain the command, actual compiler/version banner, complete sanitized log,
   exit status and error/warning counts. Require the normal successful build
   criteria, including zero errors/warnings where required. Document the evidence
   and its limits in the PR update before relying on it. Do not copy credentials
   or private operational data into public logs.
4. State both outcomes: hosted build failed for the verified reason; local
   compilation passed for the named revision and target. That hosted failure
   alone need not block an otherwise authorized push or source-PR readiness.
   Preserve actual failed CI/aggregate statuses and any dependent checks that
   did not run. Do not claim tests or native behavior from compilation.

Other required checks, source/test failures, conflicts, reviews, holds and
action-time requirements retain their force. This evidence exception does not
authorize a merge, history rewrite, protection/security change or a new override.
If an existing protected gate still prevents the requested action, report it
or use only an independently authorized override permitted by the environment.
Apply the skill's denial and uncertain-outcome rules without changing routes.

## All-zero before SHA on first branch push

A first-push event can supply an all-zero `before` SHA. It is a sentinel, not a valid commit for `git diff`. Inspect the event and choose a baseline that matches the check's purpose:

- For changes introduced by a feature branch, fetch the intended base as permitted and compute a justified merge base with the head.
- If the check requires the complete new tree, compare against an empty tree only when that interpretation is correct.

Verify that the chosen commits exist and that checkout depth contains the needed history. Do not use `HEAD~1` blindly, ignore a bad diff exit status, or convert the failure into an empty change list that skips validation. If no justified baseline is available, fail clearly or run the appropriate conservative checks rather than claim no changes.

## New manual workflows and branch-update modes

For a newly added `workflow_dispatch` workflow, check whether its definition is present on the repository's default branch and recognized by Actions. A feature-branch file alone may not make the workflow available for dispatch. Do not repeatedly dispatch an unregistered workflow or merge it merely to work around registration without merge authority.

Keep preparation separate from native execution: a preparation mode may validate inputs or generate a plan, but it must not be reported as a successful native workflow run. Verify default-branch registration after an authorized merge, then use the intended ref and inputs for an authorized dispatch.

For branch-update automation, inspect automatic mode and branch selection before execution. Native auto-selection must respect explicit repository/branch allowlists, version or range bounds, requested mode, and authorization. If selection cannot satisfy those constraints, fail clearly or prepare a reviewable plan; never silently broaden scope or select a mutating mode.

## Reproducible artifacts and retained failures

Tie each result to the exact source commit, workflow revision, run attempt, inputs, dependency/lockfile state, toolchain versions, and artifact hashes. Hash the actual produced or downloaded bytes; do not treat an artifact filename or a successful upload as an integrity check. Separate reproducible local preparation from platform-native execution evidence.

When fixing a workflow, preserve diagnostically useful logs and artifacts from failed runs as well as successful ones, within repository retention and access policies. Check that upload/cleanup conditions do not discard evidence on failure. Keep secrets out of artifacts and redact sensitive material from reports. Do not publish private logs or weaken access controls to improve retention.
