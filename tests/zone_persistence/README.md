# Zone persistence fixtures and native acceptance

`test_contract.py` runs independent format examples and source checks only.
The existing world-save preparer accepts `--zone-topology --prepare-only` and
refuses zone native execution. That guard and the frozen fixtures remain unchanged.
Native results below belong to an explicit versioned hosted adapter/controller.

`probe.dm` has two successive-generation modes, exercised by that adapter:

- `write-sequence` uses production Save_World three times. It archives complete
  synthetic generations under `zone-fixtures/baseline`, `changed` and `deleted`,
  copying the completion marker last. A manifest records distinct generations
  and both affected area IDs.
- `read-sequence` requires those synthetic archives and manifest in a fresh
  isolated fixture directory. It imports baseline, changed and deleted in that
  order, each twice, using production ticker.loadmap. No production save path
  or runtime installation is an acceptable fixture directory.

Baseline gives each of `latejoin_turfs["target"]`, `newplayer_start`, `latejoin`,
`paradrop_landmarks` and `supplydrop_turfs` one destination on z=1. Changed moves
all five destinations to z=2 and adds one destination to each list. It creates
another named group and a same-type area; the previously saved area's exact ID
moves from (2,3,1) to (2,3,2), with the old turf returned to the base area.
Deleted empties all five lists, removes the old and new named groups, clears
durable aliases and deletes both areas only after their earlier saves exist.
The reader asserts coordinates/counts, old membership removal, area aliases and
list keys, stable instance identity between baseline/changed/repeated loads,
then absence of the deleted area IDs in the final area registry.

Existing `write`, `read`, `legacy-write`, `legacy-read` and malformed-input modes
remain. `absent-zone` now reads the target spawn's exact zone ID, proves positive
membership references to it, removes exactly that ID's inventory row and leaves
both spawn and membership references unchanged. Its temporary
`zone-negative-setup.json` records this proof. The other negatives cover duplicate
spawns/zones, stale IDs, out-of-range z, fractional coordinates and missing or
out-of-range scalar capture indexes. Membership is stored in level savefile
zone_capture records, not a world JSON run list.
Each malformed reader tests sentinel and index preservation before any ClearMap.

The fixtures reject
clients/Topic, refuse port reopening, and require an external listener-closure
acknowledgement before setup. Preparation does not compile or execute the fixture.

`test_revision.py` adds bounded-counter/collision, older-generation divergence,
staging surprise, retirement-failure and unavailable-registry controls. It also
projects the production admission predicate and allocator control flow with
explicit scalar/engine adapters; this is offline evidence, not execution of DM.

## Native Linux 516.1688 acceptance

[Hosted attempt 2](https://github.com/Civ13/Civ13/actions/runs/40165392581) used:

- Source: `8144be445fa0492a515b6bb47b9692e0edc1830b`.
- Source tree: `508e7e0677a8cdc45ab6eed100bcbb0d1fb283f3`.
- Controller: `6895f1079ee0ea2fcc98c16fcdecb2b261a2d881`.
- Adapter: `zone-native-516.1688-v2-jobmaster`.
- Retained artifact: `12588186613`; archive SHA256
  `8172c381ba6b2d38253e435e66fa598bb70dc91f87ee79acb62060ea61cf9720`.

The native compiler reported zero errors and zero warnings. All 14 modes passed,
with 313 assertions and zero failures: write/read (4/13),
write-sequence/read-sequence (77/152), legacy-write/legacy-read (4/5), absent-zone
(9), and duplicate-spawn, duplicate-zone, stale-zone, wrong-z, fractional,
incomplete and overlong (7 each). Source and compiler archive/member checks,
listener-closure census and owned-process cleanup receipts were retained.
Expected negative diagnostics remain visible: rejection reason and count are
checked, with phase binding where markers exist. Markerless auxiliary admin logs
provide reason/count correlation, not independent proof of rejection timing.

The adapter generates a separate probe for 516.1688. Its two syntax corrections
use a typed area local before member access and rename the reserved `spawn`
parameter to `spawn_row`. It also constructs the real
`/datum/controller/occupations` before the ticker, supplying the job controller
normally initialized by full-game startup. It does not bypass production load,
round restoration or `initialize_position_limits()`, nor substitute an override.
The synthetic occupation roster is empty, so this is not job-capacity acceptance.
Readiness/result instrumentation and phased diagnostic oracles are adapter-only;
the original probes and frozen helpers are unchanged. Production resources were
not renamed or aliased to satisfy earlier QEMU-environment case errors.

[Hosted attempt 1](https://github.com/Civ13/Civ13/actions/runs/40165048752) remains
a failed attempt, not relabeled as a pass. Controller
`e128c81a344d53392acadbeb270144364c11cf9b` compiled successfully and passed the
four writer checks, then the reader failed in production restore_round_state at
functions.dm:737 because the synthetic startup omitted job_master. No later modes
ran. Its artifact `12588086390`, archive SHA256
`fcbd0675cc83f1ef64d354d58dd6238836abbb067dd206cc403eb00386c8eb3c`, retains that
failure and both process-cleanup receipts. The v2 initializer addresses that
fixture omission while preserving the real restore path.

These results cover bounded synthetic native save/load, successive generations,
legacy loading and malformed-input preflight. The synthetic Gaia metadata subtype
overrides New; no Gaia map/startup, production saves, players or connected clients
were used. Native roof-format/omission acceptance, constructor-surprise and
retirement-failure injection, lighting/weather correctness, connected-client
behavior, and scale/latency remain unverified. Existing offline failure controls
are not native acceptance of those cases. The separately merged optional elevation
component is independent of native zones; this fixture does not establish combined
nonzero-elevation/topology acceptance. See docs/elevation.md for its own coverage.

Remaining native acceptance is tracked in [#3311](https://github.com/Civ13/Civ13/issues/3311).
Source merge is distinct from deployment or approval to use production saves.
