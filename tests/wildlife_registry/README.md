# Wildlife registry retirement source contract

Separate companion to the farm-only #3051 correction. Eight existing death and
Destroy hooks intersect the bear/bison/wolf registries with their retiring owner,
discarding other members. Replace only those operators with owner subtraction.
Parent calls, constructors, AI, reproduction, population limits, save fields and
revival are unchanged. No complete population-cap or revival repair is claimed.

Scope: bear death/Destroy, bison and bisonbull death/Destroy, wolf death/Destroy.
One-time review against master 5bf351248de6050876fe5b53f91209a970cc5668 verifies
only eight production operators change. The separate farm patch is not included.
All-state PR searches for bear_count, bison_count and wolf_count found no prior
repair; current file history still contains the original intersections.

Run offline with the Python standard library:

    python -m unittest discover -s tests/wildlife_registry -v

Five source-contract tests check all eight bounded hook bodies, parent calls,
wrong-registry/clear-all/missing-parent mutations, individual reversions and an
all-intersection control. Unrelated source additions are allowed. No Git history
is required. These are textual checks, not execution or emulation of DM semantics.
No native compiler/runtime, save/load or connected gameplay acceptance is claimed.
No CI workflow change, deployment or external publication is included.

Native acceptance should exercise production hooks with several peer identities,
repeated death, Destroy without death, death then Destroy and unregistered owner
removal, verifying parent execution and preservation of all other members. Broader
lifecycle and reproduction issues remain outside this operator correction.

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
There are 28 cases per run. `--all-controls` compiles/runs the baseline followed
by all 8 exact single-target restorations of `&=`. A control must fail exactly
its three direct cases and, where present, its type's death/Destroy sequence.
Unexpected failures, missing/duplicate cases, or a surviving control fail closed.

Prepare packets without any native execution:

    python tests/wildlife_registry/run_native.py --prepare-only --all-controls --output /tmp/wildlife-registry-sources

Run on an authorized Linux host with BYOND 516.1681 already available:

    python tests/wildlife_registry/run_native.py --byond-bin /path/to/byond/bin --all-controls --output /tmp/wildlife-registry-native

The output directory must be new. For one control use, for example,
`--negative-control hostile/bear/death`; with neither selector only baseline runs.
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
