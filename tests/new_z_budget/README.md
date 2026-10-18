# New-z admission verification

Production has no calibrated memory profile and must reject new growth with
`UNMEASURED` before allocation or material debit. Arithmetic alone does not
admit a production request. Existing planes and matching-dimension imports
remain available. The tests-only `fixture_admission` subclass is compiled only
into isolated fixtures so accepted small-grid paths can still be exercised;
it is not a memory model or a configuration bypass.

Source/offline checks (no BYOND process):

```text
py -3 -m unittest discover -s tests/new_z_budget -p "test_*.py" -v
py -3 tests/new_z_budget/prepare.py --output <new-prepared-directory>
py -3 tests/new_z_budget/prepare.py --control memory-admission --output <new-control-directory>
py -3 tests/world_save/run-dimension-bootstrap.py --prepare-only
```

After exact source review, the authorized sole native executor runs sequentially:

```text
py -3 tests/new_z_budget/run.py --expected-commit <full-commit> --byond-bin <516.1681-bin> --output <new-positive-directory>
py -3 tests/new_z_budget/run.py --expected-commit <full-commit> --byond-bin <516.1681-bin> --control memory-admission --output <new-control-directory>
py -3 tests/new_z_budget/run.py --expected-commit <full-commit> --byond-bin <516.1681-bin> --control cell-limit --output <new-control-directory>
py -3 tests/new_z_budget/run.py --expected-commit <full-commit> --byond-bin <516.1681-bin> --control roof-ceiling --output <new-control-directory>
py -3 tests/world_save/run-dimension-bootstrap.py --byond-bin <516.1681-bin>
py -3 tests/world_save/run-dimension-bootstrap.py --negative-control memory-admission --byond-bin <516.1681-bin>
py -3 tests/world_save/run-dimension-bootstrap.py --negative-control budget-hold --byond-bin <516.1681-bin>
py -3 tests/world_save/run-durable-world.py --dimension-bootstrap --profile europe --byond-bin <516.1681-bin>
```

The prepared full-production DME disables ordinary world/global startup using
the existing fixture adapter. Sources, generated controls and executable hashes
are recorded. The native launcher requires the exact commit with clean tracked
source, pinned 516.1681 compiler and runtime, closed fixture port, zero exit,
no engine diagnostics, complete result flags and a final positive 10x10x9 grid.
Expected control failures are explicit and cannot mask a nonzero exit or an
unrelated diagnostic. All runtime storage is fresh and outside production.

`memory-admission` must fail on `default unmeasured roof preserves paid builder
and grid`; `cell-limit` on `one-over total-cell ceiling blocked`; `roof-ceiling`
on `raising roof allowance rejected`. The disk controls separately remove the
same memory refusal or the admission-hold latch. Whole-target refusal must leave
original generation files byte-identical, retain restart intent, allocate zero
levels and prevent a later save overwrite. Full durable recovery additionally
executes the actual round-v2 restart state machine in unmeasured mode before its
independent fixture-admitted reader.

Positive cases cover production refusal and paid-item preservation first,
existing-plane reuse under that same production policy, then configuration,
Europe/Gaia arithmetic, total and roof ceilings, reserved whole-plane demand,
unknown purposes, competing/stale/completed reservations, policy freeze,
snapshot exclusion and accepted sequential initialization through the explicit
fixture subclass. The class counters do not reconstruct durable instance leases;
there is no merged Dagger/safehouse allocator to integrate in this patch.

Offline tests validate the launcher's evidence oracle without starting a process.
Preparation, unique omission targets and offline success do not establish native
compilation/assertions, client behavior, production memory headroom or OOM safety.
See `docs/new-z-budget.md` for the separate calibrated-profile prerequisite.

The new-z, standalone dimension and full durable runners share the pure
`z_budget_evidence.py` compiler parser. Compiler evidence requires one exact `DM compiler version 516.1681` line and
one exact `probe.dmb - 0 errors, 0 warnings` result (with the bounded native
date/time suffix allowed), in that order, within a 1 MiB log. Prefix/suffix
bait, longer versions, duplicate banners/results, contaminated summaries,
nonzero exits and OOM/out-of-memory/access-violation/crash diagnostics reject
evidence even when a positive or intended-control result exists. Offline tests
exercise these rejection vectors; they do not execute native binaries.

The headless new-z preparation explicitly omits the one production skin.dmf
include before resolving source paths. It makes no UI or client-rendering claim.
`invalid file` rejects compiler evidence even alongside a zero-error summary.
The standalone disk DME has no interface include; the full durable runner keeps
the root-relative skin include and compiles from the repository root. Neither
uses the external absolute DMF include that caused the new-z diagnostic. This
source distinction does not replace checking each actual compiler log.
