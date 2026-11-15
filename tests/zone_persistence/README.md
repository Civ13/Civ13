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
were used. Roof, constructor, retirement, weather/lighting and late-join cases
were added later; see "Native runner (#3311)" below. The separately merged optional elevation
component is independent of native zones; this fixture does not establish combined
nonzero-elevation/topology acceptance. See docs/elevation.md for its own coverage.

Source merge is distinct from deployment or approval to use production saves.

## Native runner (#3311)

`run_native.py` compiles the prepared fixture once with the pinned compiler and
runs every mode in its own DreamDaemon process and directory. A reader gets only
the disk files its writer left. The `moving-save-chunks.yml` isolated-native job
runs it with `--all-controls` on every PR that touches zone persistence:

```
source <byond>/bin/byondsetup
python3 -B tests/zone_persistence/run_native.py --byond-bin <byond>/bin --all-controls
```

Each case must reach its exact assertion count. Preflight rejections must give
their named reason, leave the sentinel, registries and saved file hashes
unchanged, and raise no recovery hold. Cases added for #3311:

- Roofs under topology schema 2: `roof-write`/`roof-read` restore switched and
  disabled roofs with the same zone identities, settings, aliases and overlays,
  twice, then roof destruction restores the base type. `roof-omitted-settings`
  (no `switch_area`) and `roof-absent-base` (base type not a saved zone) reject.
- Unique base type: a switched roof's `current_area_type` must name exactly one
  saved zone. `ambiguous-base-write` shows a save with a second explicit
  same-type base is refused ("Ambiguous saved roof base zone"), the previous
  generation stays the backup, and saving works again once the ambiguity is
  gone. `ambiguous-base-read` rejects a saved topology with two such zones.
- Constructors and retirement: `surprise-read` arms an unrequested area
  constructor during staging; `retire-read` keeps a stale startup zone alive with
  `QDEL_HINT_LETMELIVE`. Both fail after ClearMap, so they must hold recovery,
  publish no registry or spawns, refuse registry readers, weather sweeps, saves
  and a second load, and leave saved files unchanged. There is no in-memory
  rollback; the cleared world stays cleared. `admission` shows ClearMap-time
  areas are quarantined and retired, the registry epoch renews, only saved zones
  are published, and a zone made after load gets a fresh restored-namespace ID.
- Weather and lighting: `weather-read` restores per-zone weather, intensity,
  icon state, `dynamic_lighting`, `location` and luminosity on a lit startup map,
  builds or clears each turf's overlay to match, then shows ordinary area changes
  and the next weather sweep still work after publication.
- Late join: `latejoin-read` shows `job_master.relocate` refuses an empty or
  removed saved group without inventing a fallback, admits a saved group, and
  uses a spawn point an administrator places after load.
- Formats: `unsupported-schema` and `unsupported-topology` reject schema 3.

Omission controls rebuild with one production step removed and must fail at a
named assertion: `roof-projection` (schema-2 roof validation), `roof-ambiguity`
(unique-base check), `zone-fields` (zone field restore), `lighting-import`
(overlay clearing) and `retire-check` (retirement verification).

First run, 2026-11-04, Linux 516.1688 in a cloud container: 29 cases and five
controls passed in 2m15s. This is synthetic 8x8x2 evidence. Real-map scale and
memory are measured by `real_map.py` below.

The `write` fixture puts an item on the moved spawn's turf (3,3,2). An empty
ground turf is saved as a plain cell, named only by a template, so without the
item the zone had no membership record of its own and `absent-zone` had nothing
to remove a zone from under.

## Real maps (#3590)

`real_map.py` compiles the whole game with one production map and
`real_map_probe.dm`, then runs fresh DreamDaemon processes in their own
directories. It never reads a server's `map_saves/`: every save is one the run
made, and each later process gets a copy.

```
source <byond>/bin/byondsetup
bash tools/savestream/build.sh linux        # optional: the stream helper a host uses
python3 -B tests/zone_persistence/real_map.py --byond-bin <byond>/bin \
    --map maps/nomads/nomads_americas_north.dmm --output <fresh dir> \
    --savestream-bin tools/savestream/bin/linux
```

- `write`: a fresh Persistence world. The probe starts the round, builds one
  supported roof on solid ground in every climate zone of every level, adds an
  empty and a one-turf spawn group, saves with `ticker.savemap()` and records
  every zone's identity and membership (cells and two position sums per zone
  and level), the roofs and the five spawn registries.
- `read`: a copy of that save. Startup restores it, then `ticker.loadmap()` runs
  again in the same process (three loads by default) and the world is saved a
  second time. Every load must give the saved inventory back unchanged, with the
  same area count and `area_list` length each time.
- `reject`: a copy whose `world_state.schema` is 3. Startup must hold it
  unresolved for "Unsupported zone metadata revision", never call `ClearMap`,
  and leave every file byte-identical.
- Spawn groups after the third load: the emptied group is still empty and
  `job_master.relocate` refuses it without inventing a destination, the kept
  group places the body on its saved turf, and a spawn point an administrator
  places afterwards is used.

`summary.json` holds the timings, the memory of each phase, each zone proc's
share of the profile, the save's file sizes, the roof base-type counts and any
engine loop warnings from `code/`.

Measured 2026-11-15 on master `97a5a94` plus this change, BYOND 516.1688, Linux
DreamDaemon in a cloud container, stream saves on, no players. The two maps ran
side by side on one four-core machine, so times are a little long.

| | Gaia 500 x 350, 3 levels | North America 1132 x 920, 2 levels |
| --- | --- | --- |
| Fresh world before the save | 562 MB | 1036 MB |
| Save (`World save: total`) | 23.5 s | 68.7 s |
| Save, zone procs | 1.0 s (4.4% of proc time) | 3.6 s (4.5%) |
| Startup restore (`loadmap`) | 53 s | 186 s |
| Reload in the same process, 2nd and 3rd | 50 s, 49 s | 177 s, 172 s |
| Load, zone procs | 3.1 s (5 to 6%) | 14.3 to 14.7 s (6.1 to 6.6%) |
| Memory after the 1st, 2nd and 3rd load | 694, 710, 723 MB | 1474, 1540, 1544 MB |
| Peak for the whole process | 733 MB | 1582 MB |
| Areas in the world / `area_list` after each load | 21 / 20 every time | 20 / 19 every time |
| Saved zones, roofs built | 20, 11 | 19, 8 |
| `round.json` | 71 KB | 141 KB |
| Level files (`<z>.sav` + `<z>.stream.sav`) | 31 KB + 1 KB, 1.87 MB + 3.11 MB, 1 KB + 0 KB | 5.57 MB + 6.69 MB, 1 KB + 0 KB |
| Second save after three loads | 32.5 s | 82.6 s |
| Schema 3 copy | refused, 0 map clears, files identical | refused, 0 map clears, files identical |

The largest zone costs on North America are `restore_zone_topology` (15 s a
load), `prepare_saved_zones` (3.4 s a save or load) and `verify_zone_topology`
(3.1 s a load). Memory grows by under 2% between the second and third load;
the limit is 3072 MB. One
more area exists in the world than in `area_list` after any load, and the
number does not grow. No zone type was saved more than once on either map, so
no switched roof stands on an ambiguous base. No runtime errors on either map.

The first North America run found two costs that grow with the map:

- `durable_nomads_lava_active` looked through the whole world for lava once a
  second while a save waited for the world to settle: 35 calls, 9.7 s of one
  save. It now reads a register of lava turfs (0.01 s for 31 calls).
- BYOND's loop check ("Infinite loop suspected--switching proc to background")
  fired in loops that pass a million cells without a yield. The plain-cell
  expansion, the zone grid's unsaved-cell path, the prospective area check and
  the validator's turf grid now yield. Still firing, and left alone because a
  yield there would change the order of a restore or a capture:
  `load_world_contents` (the `after_load` pass), `ClearMap`,
  `save_world_contents` and `seed_the_map`.

Not covered: a schema-1 save (none exists any more; a schema-2 save rewritten as
schema 1 is refused before the map is cleared, and `legacy-read` covers the
reader), a world with players, vehicles and buildings in it, Windows, and a
connected client seeing the late-join refusal. New nomads on Gaia and both
Americas maps start on random ground (`uses_random_new_player_spawn`), so that
refusal is only reachable there by a job with a named spawn group.
