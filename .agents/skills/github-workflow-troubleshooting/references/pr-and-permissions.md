# PR, branch, and permission problems

## Stale stacked bases

After an upstream PR merges, inspect each dependent PR's actual base, ancestry, and remaining diff. Do not assume GitHub retargeted every stack member, or that merge, squash, and rebase merges preserve identical ancestry. Determine the intended surviving base and verify that retargeting or updating the branch will neither drop unique changes nor reintroduce merged work. Perform only authorized changes, then re-read the diff and run checks for the new head. Avoid rewriting shared history without authority.

Being behind the default branch alone does not require synchronization. Inspect the actual default-branch delta and any strict up-to-date requirement before updating. Avoid unnecessary branch churn and duplicate CI for disjoint changes when repository policy permits the current branch state.

## Interrupted or uncertain pushes

A lost response does not prove a push failed. Compare the intended local commit with the remote branch SHA and ancestry through an authorized read path. Check for an existing PR for the exact repository/head/base before creating another.

- Remote already has the intended commit: do not push or create another PR merely to obtain a clean response.
- Remote is behind and the update is still authorized and fast-forward: retry the narrow push.
- Remote diverged, advanced unexpectedly, or cannot be read: preserve local work, investigate or report uncertainty; do not force-push to make the state match.

Treat a transport failure differently from a server or policy denial. Apply the entrypoint's denial rule before considering any alternate access path.

## Merge gates versus conflicts

Inspect mergeability, required checks, review requirements, draft state, explicit holds, and source defects separately. A `BLOCKED` status can mean a missing review rather than a content conflict. Do not resolve it by changing source files or protections without evidence.

A `403` while reading branch protection means those settings are unknown to the current identity. It does not prove that protections are absent, that administrative bypass is permitted, or that a different route should be tried to circumvent the denial. Use already available permitted evidence; report the unknown when it prevents a sound decision.

Reconcile review evidence by reviewer, state, time, and commit. A review service's quota warning, queued request, or incomplete run is not a completed review. Comments and a narrative assessment are not a formal approval. Never manufacture an approving review to satisfy a gate merely because merging is authorized.

Before an authorized merge, refresh the head SHA, relevant required checks, conflicts, and holds. Use an existing administrator override only when explicitly authorized for that action and allowed by the environment. Do not change security settings. After merging, verify the resulting PR state and merged commit; update dependent PRs only within scope.
