# Game CI, bounded offline baseline and opt-in regressions

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
checkout, with diagnostic/source receipts retained even on failure. It does not deploy or replace
a running server. Outside the ordinary subscriptions above, the request selects
compilation plus the bounded offline baseline, with no introduced-test or extensive/native regression suites.
PR title or description edits requesting `build:` evaluate the base/head diff
without admitting introduced/native suites. Other recognized title or description
edits reuse existing checks, and the separate changelog workflow still validates
the PR description. A base retarget fails the required context until an ordinary
PR run validates the new base, because existing native gates exclude edited events.
Unrecognized edit metadata also fails selection. Unprefixed feature-branch pushes skip compilation and the
CI baseline/evidence jobs. Ordinary PRs still select newly
introduced suites according to the policy below.

The selector publishes `skip_duplicate=true` only after validating an edited
event's title/body change and matching its head and base SHAs to the workflow
inputs. Missing or unrecognized metadata cannot produce this skip. Workflow
syntax is linted once by the main CI caller for admitted work; the standalone
changelog manual run retains its own syntax check.

The selector reads titles/messages as JSON data from `GITHUB_EVENT_PATH`, never
as shell code. Missing, malformed or potentially truncated push metadata selects
compilation conservatively, with no extra regression admission. GitHub caps the
[push commit list at 2048](https://docs.github.com/en/webhooks/webhook-events-and-payloads#push);
a list reaching that cap or a reported size exceeding the list triggers this
fallback. No workflow can act on an event GitHub does not deliver.
Missing PR action/base/title or push ref cannot classify the event's check scope:
the selector fails without publishing outputs, retaining failed gating contexts.

The cheap offline baseline below runs on ordinary PR and master-push CI, explicit
build requests and manual CI runs. Unforced feature pushes skip it. Other existing
regression suites remain opt-in, including game runtime, atlas, resource
inventory, MCP protocol, comment collector and changelog tests.
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
files under `tools/<tool>/` select only their corresponding suite. This legacy
admission does not expand native/costly coverage for README edits, existing test
edits, moved tests, ordinary game edits, pushes or missing comparisons. The
reviewed offline impact registry separately covers affected existing tests and
helpers. After merge, other coverage becomes opt-in on subsequent PRs.
Adding a helper alongside new coverage selects its
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

## Reviewed offline baseline

`scripts/ci_baseline.py` owns the exact unittest file allowlist, impact mapping,
30-second per-suite deadline, execution counts and receipt validation. Selector
policy tests run unconditionally in the reusable selector and again as part of
the baseline. The baseline job has a six-minute wall-clock limit. No wildcard
discovery admits future test files automatically.

| ID | Reviewed files/effects | Admission |
|---|---|---|
| policy | Four named `test_ci_*.py` files; temporary Git repos, mocked outcomes, source reads | Always |
| bootstrap | `test_byond_bootstrap.py` and `test_byond_toolchain.py`; Bash syntax, stub commands, strict pin validation and injected archive/receipt controls only | Always |
| progress | `world_save/test_progress_sources.py`; AST dispatch, source preparation and temporary files | Always |
| research | `research_scheduler/test_resume.py`; restricted source traces and one immutable `git show` | Research source/shared scheduler or suite/helper edits |
| ping | `ping_scheduler/test_resume.py`; restricted source traces and one immutable `git show` | Ping/shared process source or suite/helper edits |
| year | `persistence_year/test_floor.py`; source projections, save-schema/fixture text only | Persistence/setup source or persistence-year/world-save helper edits |
| evidence | `test_game_evidence.py`; synthetic temporary bundles and two offline checker Python subprocesses | Evidence checker or its tests |

All imports/call paths of these files were inspected before registration. They
do not launch BYOND, .NET, clients, process inventories or live services. In
particular, the year entry does **not** discover `test_native.py`. Direct mappings
include modified/deleted production inputs and modified tests, not just additions.
If an executable/shared path has no mapping, or the comparison is unavailable,
the receipt lists the reason and selects all seven reviewed suites. It still
does not select unreviewed/native tests. Prose-only changes retain the three
mandatory suites and skip game compilation unless `build:` requests it.
The offline prose exemption is limited to reviewed documentation formats
(`.md`, `.rst`, `.html`, `.css`, listed image/font formats and `.pdf`) plus the
exact existing search-script and diagnostic-text assets. Other scripts/configs
under `docs/`, including `.py`, `.sh`, arbitrary `.js`, `.json`, `.yaml`, `.toml`
and dependency `.txt` files, use the visible unknown-impact fallback. The existing
compiler selector's documentation/generator optimization is unchanged.

Ping's registered test reads only current `ping_track.dm`, shared `_process.dm`
and an immutable historical ping source through Git. Its dispatch is a Python
adapter; it does not consume `__processScheduler.dm`. That production scheduler
is read by the research suite's wiring checks, so its mapping selects research
without claiming ping scheduler coverage. The policy tests audit these direct
ping source inputs; native scheduler behavior remains separate acceptance.

When registering another automatic suite, inspect every import/helper and
subprocess, document its cost/effects, name exact files, map production inputs
and helper/test directories, and add impact/failure controls. Unknown dependencies
use the same visible bounded fallback. Native smoke remains a proposal until
its separate admission/resource holds are resolved; compiled core_boot variants
are not a native smoke pass.

## Receipts and required aggregate

`build` and `CI required aggregate` are reserved for the existing full ordinary
PR scopes (opened/synchronize/reopened against the two CI bases) and master pushes.
Edited PRs, other-base PRs, feature pushes and manual runs use `CI informational
build` and `CI informational aggregate`, even if `build:` forces a real compile.
Unforced title or description edits that leave the base unchanged skip these
informational jobs; they do not create a replacement gating result. Their
native/introduced admission is unchanged, so their success cannot replace
an earlier compiler or native failure under the gating names. This keeps the
original gating names without changing branch protections or Actions permissions.

Job identity depends on a successful selector and its nonempty, explicit `gating=0`
output, not on compilation selection or success. A selector failure, missing
output or invalid output falls back to the gating names and fails validation;
it must not turn into a harmless informational success. Job IDs and aggregate
dependency checks remain unchanged. Informational outcomes still require their
own selected tests/compile receipts to succeed; they certify only that event's
admitted work. Metadata success is not acceptance of omitted native coverage.
The workflow output uses `1` for gating and `0` for informational (the receipt
keeps JSON booleans). Numeric tokens avoid
[case-folded string comparison in GitHub expressions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#operators);
values such as `false`, `False` or `00` are invalid and fail.

Seven-day artifacts use `ci-{selection,baseline,compile,aggregate}-<head>-<run>-<attempt>`.
The selector, baseline and aggregate use depth-one exact-head checkouts and
fetch only the exact event comparison commit when needed. The ping and research
historical negative controls use checked-in, hash-verified source fixtures, so
the baseline does not need unrelated repository history. A non-manual build
also uses a depth-one checkout and exact comparison when no introduced suite
is selected and the PR has no labels. Selected suites, any PR label, uncertain
label metadata and manual runs retain the existing full-history build checkout
with a 12-minute checkout limit. Evidence-checker retains full history. These
exceptions keep historic fixture dependencies and label-based admission intact;
they do not prove that full history is inherently necessary.
Each producer names its artifact with the attempt it actually ran in. A re-run
of failed jobs reuses earlier successful jobs, so baseline, build and the
aggregate download by the producing job's `attempt` output, not their own
attempt. Receipts keep the selection's `run_attempt` and digest and add
`job_attempt`; the aggregate requires selection <= job <= current attempt and
the declared job attempt. A reused receipt still records the earlier attempt
and does not erase any failed attempt.
They retain exact checked-out head, resolved base (or null plus requested base),
run/attempt, event action/ref, separate compile/native/gating eligibility reasons,
selection digest, changed paths, fallback/skip reasons, suite commands,
deadlines, exit codes, counts and logs. Baseline receipts include the committed
Git source tree and before/after tested patches. The runner and aggregate require
the same clean committed head before and after tests; a tracked mutation, changed
HEAD (even an empty commit), or missing post-test evidence fails. These boundary
snapshots do not establish that no temporary mutation was restored mid-run.
Compiler diagnostics include setup output, combined stdout/stderr, Git source
tree and before/after patches (the atlas catalog is generated before compilation).
Baseline uploads run after an attempted baseline step; a cancelled or failed
checkout has no baseline artifact. The aggregate records an explicit failed
baseline verdict instead of treating that absence as the primary failure.
Compilation receipts and uploads run only after the chosen checkout and its
comparison preparation succeed. An unsuccessful build produces an explicit
aggregate failure verdict before artifact downloads.
Runner loss or cancellation can still prevent artifact delivery, which cannot
become a passing aggregate.

The admitted gating or informational aggregate runs with `always()`. It requires successful selection,
baseline, evidence-checker and build jobs, and extraction when that job is
selected. It verifies baseline/compile receipt source/run/selection identity,
required suite rows and nonzero test counts, and rejects missing receipts,
failed/cancelled/skipped required jobs and unittest skips. A selected compiler
step must actually succeed even when the build job would otherwise be green.
An intentional documentation compilation skip has a reason and `status: skipped`;
that is neither a compiler pass nor native/runtime acceptance. The aggregate
does not expand or independently certify each legacy native fixture's oracle;
inspect those existing runner artifacts when admitted. Branch protection is
unchanged; adopting this aggregate as a required protection is an owner decision.

The hosted bootstrap reads the active BYOND target from the central manifest,
resolves paths from its own script,
uses `pipefail` plus the zero-error/zero-warning summary, and bounds package,
download, install, catalog and compiler stages. The compiler step has a 15-minute
limit. It uses `libgcc-s1:i386`, matching the existing hosted standalone lane.
The active job explicitly selects the reviewed community mirror and verifies its
archive against the unchanged previously observed official hash/size. Archive-only
cache keys include OS/version/hash, without prefix restores. Hits are verified
before fresh extraction and still require actual compilation. Cache metadata
preserves official/community upstream provenance and is not authenticated history.
Compiler and aggregate receipts reject missing/mismatched acquisition records.
Observed official hashes establish exact bytes, not vendor-authenticated checksums.
Historical manual native fixture lanes keep their explicit 516.1681 contract.

Cloud-only workers run the inspected offline tests and syntax checks available
to them, recording unavailable local native checks as `not_run`. After review and
an authorized branch push, inspect the exact current-head hosted aggregate and
its compiler/test artifacts. A previous green SHA or a missing local compiler is
not acceptance. Do not install native tools or run held smoke just to fill this
gap. Publication, deployment and merge remain separate authorization decisions.

Local policy acceptance:

```powershell
& '<verified-python-path>' -B scripts/ci_baseline.py unit --suite policy --output .ci/local-policy.json
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

The default compiler target now comes from `tools/byond/version.json` (516.1688);
selected success receipts require the matching installed-version record and clean
compiler banner. Historical native fixture lanes remain explicit 516.1681
exceptions. See [the upgrade disposition and acceptance matrix](byond-5161688.md).
