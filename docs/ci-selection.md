# Game CI and opt-in regressions

On pushes to `master` and opened/reopened/synchronized PRs targeting `master` or
`help-markdown-byond-html`, game compilation remains automatic for source, maps,
assets, config, shared CI and unknown changes. Documentation-only PRs skip compilation. Missing comparisons
still compile; failed selection fails the build rather than silently skipping.
Workflow syntax, security analysis, documentation builds and publication validation
remain automatic. Compilation and publication validation are not regression suites.

Start a commit's first line or a PR title with the exact, case-sensitive `build:`
prefix to force a fresh `.dmb` compilation, including documentation-only changes.
CI accepts pushes to every branch and PRs targeting every base for this request.
Every commit represented in a push is checked, so a request need not be the head
commit. PR title edits are included; adding `build:` to an existing title starts
a build. `Build:`, leading whitespace and `build:` in a commit body do not match.
PR events use the PR title; push events use the pushed commit messages.

The request uses the existing Ubuntu BYOND compiler job on a fresh hosted
checkout, with the existing logs/artifact behavior. It does not deploy or replace
a running server. Outside the ordinary subscriptions above, the request selects
compilation only, with no introduced-test or extensive/native regression suites.
Other PR edits and unprefixed feature-branch pushes skip compilation. Ordinary
PRs still select newly introduced suites according to the policy below.

The selector reads titles/messages as JSON data from `GITHUB_EVENT_PATH`, never
as shell code. Missing, malformed or potentially truncated push metadata selects
compilation conservatively, with no extra regression admission. GitHub caps the
[push commit list at 2048](https://docs.github.com/en/webhooks/webhook-events-and-payloads#push);
a list reaching that cap or a reported size exceeding the list triggers this
fallback. No workflow can act on an event GitHub does not deliver.

Existing regression suites are opt-in, including game runtime, offline evidence,
atlas, resource inventory, MCP protocol, comment collector and changelog tests.
In Actions, select **CI**, **Run workflow**, and enable **extensive_regressions**
to run all game/offline suites. The option defaults to false. For MCP, comment
review, changelog, environment sweeps, component tools or trains, manually run
that named workflow to opt in to its tests. No production game is launched.

For the isolated world serializer, durable graph and expanded-level restart
fixtures, enable **world_save_regressions** on **CI** with
**extensive_regressions** disabled. This supports focused verification of stacked
draft branches whose PR base is not `master`; use `build:` for compilation alone
on those PRs, or the focused manual input for native evidence. The native transaction
state-machine suite retains its separate **restart_transaction_regressions** flag.

For the paid drying-rack owning-turf save fixture, enable **rack_save_regressions**
on **CI** and leave **extensive_regressions** disabled for focused coverage.
This manual option runs the positive rack-save probe and the coverage, runtime,
storage, stale-wait, duplicate and conversion mutation controls independently.
Each control must reach its existing named failed assertion; a compile error,
runtime error or timeout fails the check. Logs, source manifests and per-case
results are retained in the exact-head `rack-save-<SHA>` artifact for seven days.
This fixture does not establish full-world saves or player/map acceptance.

For the standalone extraction instance model, enable
**extraction_instance_regressions** on **CI** with **extensive_regressions** off.
Its separate Ubuntu job installs BYOND 516.1681 without compiling or starting the
game. It runs 35 authored assertions against committed source, then four generated
mutations: overlapping private-home z intervals and stale-generation admission
for home acquire, home release and berth release, each in an isolated registry.
Each mutation must fail its exact named assertion; compile/runtime errors,
missing assertions and timeouts are failures, not successful negative controls.
Only the named target may fail for an accepted control. Additional failed
assertions are retained as collateral with `needs_review`; the overall run fails
until the complete failure set is causally reviewed and an updated oracle approved.
The job has a 12-minute limit, five-minute setup and six-minute test steps;
the runner additionally bounds compiler/runtime CPU, memory, output and wall time.
Seven-day `extraction-instances-<SHA>` artifacts retain source manifests, binary
hashes, generated cases and logs. The fixture rejects clients and reopened ports;
it exercises no full game, map loading, physical travel, account I/O or disk save.
The PR selector groups new files under `tests/extraction`. This foundation
registers only the standalone instance job for that group; the broader legacy
extraction runner is not copied into master. The focused manual input does not
turn on extensive regressions. This workflow is source preparation until
reviewed and run; offline runner tests are not a
native BYOND pass.

A PR introducing executable integration tests runs the corresponding registered
suite automatically. `scripts/select-ci.py` compares the PR base and exact head,
using added files with rename detection. New `.dm`, `.py`, `.ps1` or `.sh` files
under `tests/<suite>/`, standalone `tests/test_*.py`, or `.test.mjs`/`.test.js`
files under `tools/<tool>/` select only their corresponding suite. README edits,
existing test edits, moved tests, ordinary game edits, pushes and missing/failed
comparisons do not auto-select regressions. After merge, that coverage becomes
opt-in on subsequent PRs. Adding a helper alongside new coverage selects its
suite too; this is file-based selection, not a claim about a PR's intent.

The explicitly registered `scripts/opendream/bounded_build/test_guard.py` and
`test_windows.py` also select their injected adapter suite when introduced.
These offline tests do not exercise native Windows containment or launch builds.

When introducing a new suite, add a guarded step/job using the reusable
`ci-selection.yml` output. Example for a game suite:

```yaml
if: needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests), 'tests/new_suite')
```

New standalone workflows must expose `workflow_dispatch` and use the same
introduced-test guard on their test job. The detector does not execute arbitrary
new tests: a reviewed workflow step must register the suite runner. Grouped
runners execute the registered group when one member introduces coverage.

Local policy acceptance:

```powershell
& '<verified-python-path>' -m unittest discover -s tests -p 'test_ci*.py' -v
```

These checks cover real Git additions, edits, renames, post-merge comparisons,
manual opt-in, failed comparisons and suite guards. A skipped suite is not
regression or gameplay evidence; run relevant checks locally or explicitly opt
in before making an acceptance claim. Publication remains master-only.

The manual `persistence_integration_regressions` input selects the existing
world-save, restart-transaction, lighting recovery, linked-building and continuous-round
suites together, including their mutation controls. It does not select unrelated extensive regressions. The suites
retain native logs as artifacts; fixture success is separate from full-map
save/reboot/recovery and public supervisor acceptance.
