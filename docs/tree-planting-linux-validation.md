# Tree planting: Linux BYOND 516.1688 evidence

On 2026-10-25, the separately reviewed Linux one-shot fixture passed on the exact
integrated tree source. This is bounded native engine evidence, not a live-world
or connected-player test. [Earlier Windows failures](tree-planting-native-validation.md)
remain unchanged and are not relabeled as passes.

## Exact source and retained evidence

- Production commit: [`e773c2fae4b196ad6c7afc025235e90f488f7db8`](https://github.com/Civ13/Civ13/commit/e773c2fae4b196ad6c7afc025235e90f488f7db8).
- Production tree: `4800aac2e81b45b6fb215bcf23f8ed3761186fe3`.
- Complete 5,057-file source manifest SHA256:
  `704d909c090602627b123139dd7365673d4f2745153306133025dcd86d0d2d57`.
- Native run: [40199671191](https://github.com/Civ13/Civ13/actions/runs/40199671191).
- Separate controller commit: [`22215eab2ff0f4e86472f5f94740adf252421930`](https://github.com/Civ13/Civ13/commit/22215eab2ff0f4e86472f5f94740adf252421930).
- Adapter: `tree-linux-516.1688-e773-v2`; engine/compiler: Linux BYOND 516.1688.
- Downloaded artifact ZIP SHA256:
  `2c60464d209fcb425b257027183a3ec197f30cc3230d310029684aecec90c6f2`.
- Artifact contents: 186 retained files plus `retention.json`; no rejected files.
  Optional absent artifacts are listed separately in that manifest, not silently
  counted as completed phases. Hosted retention was configured for seven days.

The controller verified actual checkout HEAD/tree, clean status and every tracked
blob before preparation and again at phase checkpoints. It independently bound
compiler/runtime members to archive SHA256
`16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9`.
Readiness and result records bind the source, adapter, version, variant and phase.
Retained records include preparation/source identity, controller/runtime hashes,
phase inputs, compile/runtime logs, assertion results, listener census and owned
process/cleanup receipts. Final status is `passed`; all compiler and daemon
attempted/started/completed flags are true.

[Ordinary CI 40197583582](https://github.com/Civ13/Civ13/actions/runs/40197583582)
also passed on this production commit, including full-game BYOND 516.1688
compilation with zero errors/warnings, 14 tree regression tests and Atlas catalog
checks. The native lane additionally ran the unchanged exact-source tree tests
and standard Atlas freshness command before starting native phases. These checks
are distinct from the synthetic native assertions below.

## Native results

All four fixture compilations—baseline, clock, duration and payment—reported
**zero errors and zero warnings**. All ten compiler/runtime phases exited cleanly
and retained successful owned-process cleanup receipts. No cleanup retry was
needed; no failed or uncertain phase was accepted as a control result.

| Phase | Result | Checked assertions |
| --- | --- | ---: |
| Baseline round trip | Passed | 20 |
| Baseline writer | Passed | 3 |
| Fresh baseline reader | Passed | 25 |
| Clock-serialization control | Exact intended assertion rejected | 9 |
| Duration-reset control | Exact intended assertion rejected | 10 |
| Free-seed control | Exact intended assertion rejected | 2 |

The baseline total is **48 ordered assertion evaluations**, including repeated
production-dispatch checks. The control counts are assertion prefixes ending at
the intended failure, not additional passing baseline checks. Exact failures were:

- Clock: `runtime clock is absent on disk`.
- Duration: `disk round trip preserves scalar growth state`.
- Payment: `planting creates seedling and spends exactly one seed`.

The real production paths covered successful one-seed planting, occupied/indoor
rejection, late obstruction, watering/irrigation, winter pause, partial growth
remaining on disk, runtime-clock exclusion, repeated registration without
duplication, maturity into the existing live-tree type, ordinary seven-log
destruction and drought retirement. The production object dispatcher serviced the
freshly loaded tree, checking old-clock rejection, no first-service reset/charge,
partial-duration resume, same-tick duplicate protection, active save/load holds
and exactly one mature tree. Only fixed synthetic save/entry files crossed from
the validated, cleaned writer into a new reader process.

Four appearance checks validated engine `icon_state` and resource-state membership:
constructor, explicitly assigned stage-3 save snapshot, and production-dispatch
stages 5 and 6. The stage-3 snapshot was fixture-assigned, not organic growth;
no appearance mutation control or connected-client screenshot was supplied.

## Isolation, cleanup and retention contract

The world was synthetic 8×4×1 with normal/global startup disabled, no map DMM,
clients and Topic rejected, webhooks disabled and port reopening refused. Every
runtime phase supplied its 150 exact manifest-bound name-table files. Before
fixture setup, zero-port readiness required an owned-process TCP/TCP6 listener
census and acknowledgement. The Linux contract permits a single loopback startup
bind followed by closure; it is not the older Windows no-socket-from-start rule,
a network sandbox or proof of continuous absence of transient sockets.

Limits were compiler 180 seconds wall/150 seconds CPU/2 GiB address space and
daemon 45 seconds wall/30 seconds CPU/1 GiB, with a 1,200-second aggregate deadline
and cleanup reserve. Output, descriptor and private-HOME bounds remained enforced.
The retained-leader controller recorded actual starts, termination, reaping,
absent owned process groups/descendants and restored signal handlers. This is
owned-process evidence, not a host-wide process or socket census.

After successful cleanup and immutable verification, exact reconstructable source
copies and daemon DMB/RSC copies were retired with hash ledgers to stay within the
unchanged 2 GiB scratch bound. Original compile pairs, logs, hashes and synthetic
saves remained in runner scratch until teardown. The bounded uploaded artifact
intentionally excludes binaries, savefiles, archive bytes and private HOME data;
it retains their applicable hashes/receipts, not those payloads. Artifact replay
validates retained assertions and receipts; it cannot reopen an omitted savefile.

## What this does not establish

Fixture-owned timers were accelerated and object dispatch was invoked explicitly.
The pass does not establish natural scheduler cadence, complete climate/admission
coverage, full-world fresh-process recovery, scale/performance or connected-client
planting/maturation pixels. It does not validate a later gameplay change without
an appropriate source-bound rerun. No production save, live server, Gaia world,
OpenDream installation or player session was used or changed by this lane.

See [tree planting behavior and compatibility](tree-planting.md). Merge/readiness
and any broader acceptance remain separate decisions; this record does not grant
permission to rerun a consumed one-shot attempt or weaken either platform's guard.
