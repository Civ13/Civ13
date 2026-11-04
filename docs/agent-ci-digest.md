# Agent CI digest

`.github/workflows/agent-ci-digest.yml` replaces the loop agents used to run by
hand after every push: list a PR's workflow runs, list their jobs, fetch each
failed log, decide whether the failure is infrastructure, rerun it, and check
again. The runner does that waiting, and the PR gets one comment per head.

## What it does

1. When the `CI` workflow finishes for a pull request, the digest job starts
   from the default branch. It never checks out or runs PR code.
2. It waits on the runner (up to 150 minutes) until every GitHub Actions check
   run on the head SHA has finished, including the other workflows such as the
   moving-save native job. Checks from other apps (CodeRabbit) are ignored.
3. For each failed job it reads the first failed step and the log lines just
   before the first `##[error]`, and classifies the failure:

   | Class | Meaning |
   | --- | --- |
   | `infra` | Checkout/setup step, runner shutdown, network, 5xx, rate limit, missing artifact, cancelled |
   | `known` | Documented pre-existing failure (moving-save "capture budget") |
   | `timeout` | The job hit its time limit |
   | `real` | Compile error, unittest failure, Traceback, DM runtime error, native assertion |
   | `unknown` | None of the above; read the excerpt |

   Test or compile evidence wins over incidental network text in the same step.
4. If every failure is `infra` and on its first attempt, it calls
   `rerun-failed-jobs` once for those runs and keeps waiting. It never reruns
   twice, never reruns `real`/`unknown` failures and never merges.
5. It posts one comment on the PR for that head (later reruns of the same head
   edit it in place) and writes the same text to the job summary.

Verdicts: `green`, `infra-only` (the local-build admin-merge policy in the
`civ13-pr-preflight` skill applies), `known-only` (note the pre-existing failure
with its run link), `needs-fix`, and `pending` (checks were still running when
the digest stopped waiting).

## How a thread uses it

- After pushing to a PR, do not poll CI. If the session is subscribed to the PR,
  the digest comment arrives as a PR comment event: one wake with the verdict,
  the failed step and the log excerpt. Without a subscription, read the PR's
  comments once and take the last one starting with
  `<!-- agent-ci-digest sha=<head> `.
- Only trust a digest whose `sha=` equals the PR's current head. A digest for an
  older head is not stopped retroactively, but a digest waiting on a head that
  has moved exits without posting.
- For machine use, parse the last line of the comment:
  `<!-- agent-ci-digest-json {...} -->`. Fields: `sha`, `verdict`, `counts`
  (`success`, `skipped`, `failed`), `pending`, `reruns` (run IDs it reran) and
  `failed[]` with `workflow`, `job`, `run_id`, `job_id`, `attempt`, `step`,
  `class`, `reason` and `url`. Use `job_id` with `get_job_logs` when the
  excerpt is not enough.
- `needs-fix`: reproduce locally (preflight skill) and fix. `infra-only` after
  the automatic rerun: post the documented local compile and preflight for the
  exact head, then admin-merge if authorized. Keep the failed run link.

## Running it by hand

Use this for a branch head without a PR event, or to refresh a digest:

```
mcp__github__actions_run_trigger method=run_workflow owner=Civ13 repo=Civ13
  workflow_id=agent-ci-digest.yml ref=master
  inputs={"sha": "<40-char head>", "pr": "<number or empty>", "rerun": false}
```

Without `pr` it only writes the job summary and the log, whose last line is
`AGENT-CI-DIGEST verdict=<verdict> sha=<sha> sig=<signature>`; read it with
`get_job_logs` (`tail_lines` 5). Artifact downloads are blocked from cloud
sessions, so the digest never relies on artifacts.

## Limits

- `workflow_run` workflows run from the default branch, so changes to this
  workflow or `scripts/ci_digest.py` take effect only after they merge.
- Only `pull_request` CI runs trigger it automatically. Fork PRs may not resolve
  to a PR number; then only the job summary is written.
- The classifier is a heuristic. `unknown` means read the excerpt yourself, and
  a `real` verdict on a job that also fails on master is still worth comparing
  with master before changing code.
- Offline tests: `python3 -B scripts/ci_baseline.py unit --suite agent_ci_digest`.
