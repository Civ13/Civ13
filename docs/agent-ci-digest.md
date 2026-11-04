# Agent CI digest

`.github/workflows/agent-ci-digest.yml` replaces the loop agents used to run by
hand after every push: list a PR's workflow runs, list their jobs, fetch each
failed log, decide whether the failure is infrastructure, rerun it, and check
again. The PR gets a comment for its head instead.

## What it does

1. Each time a workflow with a `pull_request` trigger completes (the
   `workflows:` list; an offline test keeps it complete), a short pass starts
   from the default branch. It never checks out or runs PR code.
2. If any GitHub Actions check on the head SHA is still running, the pass exits
   at once. It never holds a runner waiting, so it costs about 20 seconds and a
   few API calls per completed workflow. The pass that sees everything finished
   reports. Checks from other apps (CodeRabbit) are ignored.
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
4. If every failure is `infra` on its first attempt, it calls
   `rerun-failed-jobs` once for those runs and posts a `rerunning` digest. It
   never reruns twice, never reruns `real`/`unknown` failures and never merges.
5. It posts a comment for the head. A new verdict posts a new comment, which
   wakes subscribed agents; the same verdict with new details edits in place.
   The job summary gets the same text.

Verdicts: `green`, `infra-only` (the local-build admin-merge policy in the
`civ13-pr-preflight` skill applies), `known-only` (note the pre-existing failure
with its run link), `needs-fix`, `rerunning`, and `pending` (manual runs only).

## How a thread uses it

- After pushing to a PR, do not poll CI. If the session is subscribed to the PR,
  the digest comment arrives as a PR comment event: one wake with the verdict,
  the failed step and the log excerpt. Without a subscription, read the PR's
  comments once and take the last one starting with
  `<!-- agent-ci-digest sha=<head> `.
- Only trust a digest whose `sha=` equals the PR's current head.
- For machine use, parse the last line of the comment:
  `<!-- agent-ci-digest-json {...} -->`. Fields: `sha`, `verdict`, `counts`
  (`success`, `skipped`, `failed`), `pending`, `reruns` (run IDs it reran) and
  `failed[]` with `workflow`, `job`, `run_id`, `job_id`, `attempt`, `step`,
  `class`, `reason` and `url`. Use `job_id` with `get_job_logs` when the
  excerpt is not enough.
- `needs-fix`: reproduce locally (preflight skill) and fix. `infra-only` after
  the automatic rerun: post the documented local compile and preflight for the
  exact head, then admin-merge if authorized. Keep the failed run link.

## Fallback: no digest

Civ13 uses GitHub's free plan, so a digest can be missing: the API rate limit
(1,000 requests an hour for the workflow token), the concurrent-job limit
queueing the pass, an outage, an unlisted workflow finishing last, or a rerun
that GitHub does not report back (runs started by the workflow token may not
trigger another pass). The digest fails safe: any API error exits 0 with the
log line `AGENT-CI-DIGEST verdict=unavailable`, and nothing turns the PR red.

When the PR's CI result event has arrived and no digest for the current head
appears within about 10 minutes, or the last digest says `rerunning` and the
reruns have finished, check CI by hand as before: `pull_request_read`
(`get_check_runs`), then `get_job_logs` with `failed_only` for the failed run,
and classify with the table above. A missing digest is never a CI failure.

The digest stores nothing in artifacts (cloud sessions cannot download them,
and artifact storage counts against the free quota).

## Running it by hand

Use this for a head whose digest is missing, or to refresh one:

```
mcp__github__actions_run_trigger method=run_workflow owner=Civ13 repo=Civ13
  workflow_id=agent-ci-digest.yml ref=master
  inputs={"sha": "<40-char head>", "pr": "<number or empty>", "rerun": false}
```

A manual run reports even while checks are running (`pending`). Without `pr`
it only writes the job summary and the log, whose last line is
`AGENT-CI-DIGEST verdict=<verdict> sha=<sha> sig=<signature>`; read it with
`get_job_logs` (`tail_lines` 5).

## Limits

- `workflow_run` workflows run from the default branch, so changes to this
  workflow or `scripts/ci_digest.py` take effect only after they merge.
- `workflow_run` needs workflow names written out, so the trigger list is
  generated: `python3 scripts/agent_preflight.py generated --write` (or
  `python3 scripts/ci_digest.py sync-workflows --write`) adds every workflow
  with a `pull_request` trigger. The `agent_ci_digest` suite runs for every
  workflow change and fails while the list is stale. A missed workflow only
  costs a digest (agents fall back), never a check.
- Fork PRs may not resolve to a PR number; then no comment is written.
- The classifier is a heuristic. `unknown` means read the excerpt yourself, and
  a `real` verdict on a job that also fails on master is still worth comparing
  with master before changing code.
- Offline tests: `python3 -B scripts/ci_baseline.py unit --suite agent_ci_digest`.
