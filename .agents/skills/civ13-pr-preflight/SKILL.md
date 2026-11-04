---
name: civ13-pr-preflight
description: Pre-push checks for Civ13 PRs that avoid the CI failures agents keep repeating - byte-pinned source tests, stale generated crafting files, skipped offline suites, no local compiler, known flaky native jobs, infrastructure-only CI failures and the documented local-build admin merge, registry merge conflicts and stale wiki pins. Use before the first push of any Civ13 source or config change and whenever CI goes red.
---

# Civ13 PR preflight

Run these before the first source or config push. Documentation-only changes
use the focused documentation checks in AGENTS.md. Reuse recorded passing local
checks while their tested inputs and dependencies are unchanged; inspect hosted
results for each new head, including any documented local-build exception below.
Inspect existing branch ownership and use
CODEX.md's handoff rules if an action is blocked.

## 1. Compile locally, even in a cloud session

Cloud sessions can compile. Do not report "BYOND unavailable" without trying:

```bash
bash scripts/cloud_byond_setup.sh                  # once per container, ~1 min
source "$HOME/byond-516.1688/byond/bin/byondsetup"  # once per shell
DreamMaker -max_errors 0 civ13.dme                 # ~20 s, expect "0 errors, 0 warnings"
rm -f civ13.dmb civ13.rsc civ13.int                # build outputs stay out of commits
```

The script installs i386 libraries and fetches the pinned archive from the
repository-release mirror, which the agent proxy allows. On Windows use
`dm.exe civ13.dme`. A local compile is still not hosted CI evidence.
If the hosted build fails for a verified infrastructure reason, that local
result may satisfy compilation evidence under the [shared policy](../../../CODEX.md#local-build-after-a-hosted-infrastructure-failure)
and [evidence procedure](../github-workflow-troubleshooting/references/actions-and-evidence.md#local-build-evidence-after-infrastructure-failure).
Document the exact clean revision and equivalent full build; keep GitHub's
failure visible. Do not hold an otherwise authorized push or source PR solely
for that hosted build failure. Other required checks and permissions still apply.

## 2. Find tests that pin the files you touched

Many offline tests compare production `.dm` files byte for byte or by hash
(telephone.dm, transports.dm, farming.dm, click.dm, converters.dm, the
collision manifest and others). A comment or typo fix is enough to break them.

```bash
python3 scripts/agent_preflight.py pins
```

It lists every test, manifest and fixture that names each changed file and the
offline suites CI will select. For a pinned file, either leave it untouched
(best for cosmetic sweeps) or update the fixture or hash in the same commit and
say so in the PR. Never loosen the test. `tests/movement_save_chunks/collision_overrides.json`
is refreshed with `collision_manifest.py --write`.

## 3. Regenerate generated crafting files

Any change to `config/crafting/*.txt`, recipe constructors or atlas metadata
can leave these stale, and CI fails on them:

- `UI/crafting-atlas.json` (built by `scripts/build-crafting-atlas.py --catalog-only`)
- `docs/crafting-recipe-audit-index.json` (counts from `scripts/audit-crafting-recipes.py --summary`)

```bash
python3 scripts/agent_preflight.py generated --write
```

On a merge conflict in either file, never hand-merge JSON. Take either side,
then rerun the command above on the merged tree and commit the result.

## 4. Run the offline suites exactly as CI does

```bash
python3 scripts/agent_preflight.py suites            # all suites, ~2 min
python3 scripts/agent_preflight.py suites --affected # only what CI maps to your diff
```

This calls `scripts/ci_baseline.py unit --suite <name>` for every registered
suite and sets `LOS_EVENT_BASE`/`LOS_EVENT_HEAD`, so `los_context` passes
locally too. Prefer it to bare `pytest tests`, which hits module-name
collisions. If a suite fails, rerun it on master before blaming your change.
Any unmapped path makes CI run every suite, so run them all for broad edits.

### Verify hosted selection as well as local execution

For the exact base/head diff, inspect `docs/ci-selection.md`,
`.github/workflows/ci-selection.yml` and the workflow containing the intended
test. `agent_preflight.py pins` reports offline impact; it does not prove a
native/manual job will be admitted. Confirm the event, paths, inputs and job
conditions select the regression you intend. If not, report the gap and use
only an already authorized focused workflow or local runner; do not broaden
native admission or bypass a held runner to obtain a green check.

After pushing, the assigned PR owner checks selection receipts and actual
test/job outcomes for the new head and run attempt. Record what ran and why
other jobs skipped. A local pass, green aggregate, pending job or another
head's run cannot establish that a specific hosted regression executed.

## 5. Known red jobs that are not your fault

After pushing to a PR, wait for the `agent-ci-digest` comment for the new head
instead of polling runs and logs. It gives the verdict (`green`, `infra-only`,
`known-only`, `needs-fix`), the failed step and a log excerpt per job, and it
has already rerun infrastructure-only failures once. If no digest for the head
appears about 10 minutes after CI finishes, read CI directly as before. See
[docs/agent-ci-digest.md](../../../docs/agent-ci-digest.md).

- `isolated-native` / "Bounded moving-save correctness and memory"
  (`.github/workflows/moving-save-chunks.yml`). It runs when `code/predefines.dm`,
  persistence files or BYOND tooling change. `benchmark.py --run-native` fails
  with "Moving save chunk exceeded its capture budget" on master too, because
  its per-tick CPU budget depends on runner load. Check the compile step is
  clean, note the failure in the PR as pre-existing with the run link, and do
  not change gameplay code for it.
- CodeRabbit skips PRs over 100 files and rate-limits to about one review an
  hour. Split broad mechanical sweeps so review is possible; do not wait on it.
- For verified infrastructure failures (checkout or fetch timeout, cancelled
  runner, a missing selection artifact caused by that failure, or BYOND setup
  prevented by runner infrastructure), retain the failed logs and use an
  authorized bounded rerun or the documented exact-revision local-build
  exception. Do not change source code merely to make infrastructure green.

### When hosted CI is down: documented local build

A GitHub build that fails for infrastructure reasons is not a hard merge
blocker (maintainer policy, 2026-11-03). Rerun the failed jobs once. If they
fail the same way before any test ran, post a dated PR comment that documents
the local evidence for the exact head SHA:

- the `DreamMaker -max_errors 0 civ13.dme` result (pinned version, "0 errors");
- the `python3 scripts/agent_preflight.py all --write` result;
- any push-event CI run that passed on that head;
- the failing job, its log line and why it is infrastructure.

Apply the [exact-revision evidence procedure](../github-workflow-troubleshooting/references/actions-and-evidence.md#local-build-evidence-after-infrastructure-failure).
Local compilation covers compilation only. Baseline and selector tests require
their own results; report failures, skips and unrun checks without calling them
passed. A local compile is not their substitute.

With that comment and the user's merge authorization, the PR may be
admin-merged. This covers infrastructure failures only. A compile error, test
failure or other failure that reproduces locally is still yours to fix, and
this policy does not add merge authority the user has not given.

## 6. Merge conflicts in shared registries

`scripts/ci_baseline.py` `SUITES` gains an entry in most PRs (66 commits
touched it in the last week), so it conflicts often. Keep both sides' entries,
in master's order with yours appended, then run `python3 scripts/agent_preflight.py suites --affected`.

## 7. Player Help wiki pins

`scripts/player_help_bridge.py` pins civ13-wiki guides by LF-normalized
SHA-256 and silently drops a page whose hash changes. After any civ13-wiki
merge that edits a pinned guide, re-pin in Civ13:

```bash
python3 scripts/agent_preflight.py wiki-pins --wiki-root ../civ13-wiki --write
```

Review the changed guides, then commit with the new revision.

## 8. Report

Keep the PR comment short: what changed, the exact commands above and their
results, the CI run link, and what stays unverified. Do not restate unchanged
"not run" items in every comment.
