# Game CI and opt-in regressions

Game compilation remains automatic for source, maps, assets, config, shared CI
and unknown changes. Documentation-only PRs skip compilation. Missing comparisons
still compile; failed selection fails the build rather than silently skipping.
Workflow syntax, security analysis, documentation builds and publication validation
remain automatic. Compilation and publication validation are not regression suites.

Existing regression suites are opt-in, including game runtime, offline evidence,
atlas, resource inventory, MCP protocol, comment collector and changelog tests.
In Actions, select **CI**, **Run workflow**, and enable **extensive_regressions**
to run all game/offline suites. The option defaults to false. For MCP, comment
review, changelog, environment sweeps, component tools or trains, manually run
that named workflow to opt in to its tests. No production game is launched.

A PR introducing executable integration tests runs the corresponding registered
suite automatically. `scripts/select-ci.py` compares the PR base and exact head,
using added files with rename detection. New `.dm`, `.py`, `.ps1` or `.sh` files
under `tests/<suite>/`, standalone `tests/test_*.py`, or `.test.mjs`/`.test.js`
files under `tools/<tool>/` select only their corresponding suite. README edits,
existing test edits, moved tests, ordinary game edits, pushes and missing/failed
comparisons do not auto-select regressions. After merge, that coverage becomes
opt-in on subsequent PRs. Adding a helper alongside new coverage selects its
suite too; this is file-based selection, not a claim about a PR's intent.

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
