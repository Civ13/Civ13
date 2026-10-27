# Farm registry retirement source contract

Narrow correction for the population-accounting slice of issue #3051. Fifteen
existing farm-animal death/Destroy hooks intersect their registry with `src`
using `&=`. That removes every other member and can retain the retiring member;
an unregistered male boar's death can empty the boar registry. Replace only those
operators with `-=` to remove the retiring member without clearing its peers.

## Scope

- Cows and bulls: death and Destroy (four hooks).
- Pig gilts and boars: death and Destroy (four hooks).
- Wild boar gilt: death and Destroy; wild male boar: death (three hooks).
- Goat and sheep base types: death and Destroy (four hooks).

Each existing hook remains unconditional and still calls its parent afterward.
No live/dead check, constructor, revival, birth, yield, food cost, save field,
registry creation, population cap or callback changes. Repeated removal is
intended to be idempotent; native execution has not been performed here.

Existing constructors register cows/bulls, pig gilts/boars, female wild boars,
and goat/sheep base types, without checking consciousness. Thus these registries
are not filtered snapshots of conscious animals. Death/Destroy retire entries.
The global conception gates inspect registry length: under 30 for cow/pig/boar,
under 35 for goat/sheep. Nearby mate and population checks require CONSCIOUS and
reject local counts above five. Already-pregnant animals continue their existing
birth countdown; this patch does not impose a hard birth-time population cap.

Known separate lifecycle gaps are deliberately not repaired:
- Male wild boars have no New registration or Destroy hook in this file.
- Goat/sheep female Life guards milk with CONSCIOUS but does not early-return
  before reproduction, unlike cow/pig/boar.
- Base simple-animal Life can revive a dead animal whose health becomes positive;
  this path updates living/dead mob lists, not these farm registries.
- Bear/bison/wolf registries elsewhere also contain intersection retirements.

## Offline check

Run from the repository root:

    python -m unittest discover -s tests/animal_registry -v

Five source-contract tests check all 15 exact hook bodies without requiring Git
history. Synthetic restoration of all intersection operators and each individual
reversion are rejected; unrelated source additions remain allowed. One-time review
against master 5bf351248de6050876fe5b53f91209a970cc5668 verified that the production
diff changes only these 15 operators (not a permanent whole-file test constraint). Missing-parent, wrong-registry and clear-all mutations are rejected for
every hook. These are textual contract checks, not a DM interpreter or evidence
of native list semantics, compile success, save/load, reproduction, graphical
acceptance or whole-game performance. No workflow change or external publication
is included.

Before native acceptance, exercise production hooks with multiple retained peer
identities: death, repeated death, Destroy without death, death then Destroy, and
unregistered owner removal; assert only that owner disappears and parent runs.
Keep native compiler/runtime and connected-client results separate.

## Duplicate review

Read-only GitHub all-state PR searches for cow_count, animal registry, livestock,
husbandry, and farm death plus the recent 200 PR bodies and this file's Git history
found no existing repair. Merged #3126 concerns animal health/attack dispatch,
#3080 harvesting, and #3133 drying preservation, not these retirement operators.
This correction does not complete the broader #3051 husbandry milestone.

## Isolated native production-hook runner

`run_native.py` builds only the exact 15 production hook declarations/bodies and
an inert fixture, not Civ13 or its startup adapters. Native `/mob` identities and
native lists are used. Parent death/Destroy hooks only record invocation and
observe that removal happened before the parent call. Generated registry getters
read the authoritative global after every operation; setters give each scenario
a fresh list, so compound-assignment alias behavior cannot fool the oracle.

Each hook checks registered removal, repeated removal, and an unregistered owner,
always retaining two distinct peer identities. Every type with both hooks also
checks death followed by Destroy. Destroy-only cases do not call death first.
There are 52 cases per run. `--all-controls` compiles/runs the baseline followed
by all 15 exact single-target restorations of `&=`. A control must fail exactly
its three direct cases and, where present, its type's death/Destroy sequence.
Unexpected failures, missing/duplicate cases, or a surviving control fail closed.

Prepare packets without any native execution:

    python tests/animal_registry/run_native.py --prepare-only --all-controls --output /tmp/farm-registry-sources

Run on an authorized Linux host with BYOND 516.1681 already available:

    python tests/animal_registry/run_native.py --byond-bin /path/to/byond/bin --all-controls --output /tmp/farm-registry-native

The output directory must be new. For one control use, for example,
`--negative-control cattle/cow/death`; with neither selector only baseline runs.
The runner writes generated source hashes, production source hash, native binary
hashes, stdout/stderr, runtime logs, process receipts and a fail-closed summary.
No repository source is modified during preparation or execution.

Maintainer-required `-trusted` is used, not an OS or network sandbox. The fixture
imports no game constructors, shell/export hooks, paid services or client code.
It rejects clients and Topic requests, disables hub visibility at compile time,
refuses every OpenPort request except closing. Native evidence showed BYOND opens
an ephemeral loopback listener before world/New, then the fixture immediately
closes it. The runner requires exactly one startup binding on 127.0.0.1 matching
the reported initial port, an ordered closure diagnostic, final port zero and
refused reopening. Any non-loopback binding or persistent/reopened port fails.
The official DM reference documents that an overridden OpenPort cannot open a
port unless its parent is called:
https://www.byond.com/docs/ref/info.html#/world/proc/OpenPort
The CLI explicitly binds only to 127.0.0.1 and disables web clients. This accepts
only the engine's transient startup listener in ephemeral CI, not public hosting.
It does not claim zero sockets ever or external socket-monitoring evidence.
No speculative no-port CLI argument or persistent-listener fallback is used.

Children have 30-second wall and 20-second CPU bounds, 512 MiB address space,
2 MiB per-file size, no core dumps, and process-group cleanup even on failure.
The full lane has a 600-second deadline. All three runtime output streams are
scanned for diagnostics; runtime.log alone is the canonical completion marker,
so an echoed marker on stdout does not create a false duplicate. The compiler
must report exactly the pinned version and zero errors/warnings. Native runtime
version/build are also checked inside the fixture before tests execute.

The additional Python tests use generated sources, synthetic result objects,
injected runners, and bounded Python child processes only. Passing them or
`--prepare-only` does not establish native compilation/list semantics, game
startup, save/load, reproduction, visual acceptance or performance. Native
acceptance remains pending until this runner actually succeeds on BYOND.

## Poultry suite (2026-10-27)

`birds.dm` had the same defect in twelve hooks across two registries. Chick,
chicken and rooster death/Destroy ran `chicken_count &= src`; turkey chick, tom
(`turkey_m`) and hen (`turkey_f`) death/Destroy ran `turkey_count &= src`. Each
type registers in `New()`, and each registry's length gates egg hatching
(`chicken_count.len < 50`, `turkey_count.len < 35`). The first death or chick
growth (which qdels the chick) collapsed that registry to at most the retiring
bird, so its hatching cap stopped limiting hatching. Only those twelve operators
become `-=`. Other birds in the file have no registry. The cap values, the
5-bird chicken local check, egg laying, growth and saves are untouched.

`test_source_contract.py` exposes `POULTRY_SOURCE`/`POULTRY_HOOKS` and a `SUITES`
map; `violations()` takes an optional hook map. `test_poultry_contract.py` holds
the poultry source contracts and offline preparation/verdict tests. The native
runner takes `--suite farm|poultry` (default `farm`, so existing commands keep
their meaning); a poultry run has 42 cases (three per hook plus six
death-then-Destroy pairs) and twelve single-hook controls:

    python tests/animal_registry/run_native.py --suite poultry --byond-bin /path/to/byond/bin --all-controls --output /tmp/poultry-registry-native

Known remaining instance outside this suite: `deer.dm` retires `deer_count` with
the same `&= src` pattern in two hooks.

CI runs both suites in the existing registry step. On Windows the existing
`test_injected_compiler_runtime_and_diagnostics` errors because the runner is
Linux-only; master's copy fails identically there, so it is not a regression.
Isolated hook evidence does not establish hatching rates, population balance,
save/load or connected-client gameplay.

## Engine version selection (2026-10-27)

The runner was written for 516.1681, but the main workflow's compiler now targets
516.1688 (docs/byond-5161688.md). Its first CI run since then (this PR) compiled the
farm baseline cleanly on 1688 and then failed closed at the pinned-version check.
Following that doc's rule against relabeling, the default stays strict 516.1681.
`--expected-byond-version 516.1688` must be passed explicitly; it then pins the
compiler banner, the in-fixture `byond_build` check and the result version together.
CI passes it for both suites. 1688 native results are separate from the historical
1681 run 39363090396 and do not retroactively re-verify it.
