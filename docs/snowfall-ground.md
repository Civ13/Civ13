# Ground snow from precipitation (draft)

Season influences the existing local climate calculation; it does not create a
snow layer. A separate low-priority worker samples actual area snowfall, exposure
and `get_temp(tile)`. Weather configuration/rolls, weather-event lifecycle, season
ordering/counts, year advancement and water/ice conversion are unchanged.

Initial conservative profile:

- Only exact `/turf/floor/dirt` and `/turf/floor/grass` qualify. No implicit subtype
  opt-in: ploughed/flooded/burned/jungle/underground ground, roads, sand, constructed
  floors, water/ice and existing winter/snow terrain are excluded.
- Local weather must be WET or EXTREME, have positive intensity and use the existing
  `snow1`, `snow2` or `snow_storm` area precipitation asset. A radiation `rad_`
  prefix is ignored for this check. Rain, cold clear weather and a season name
  alone cannot create cover.
- Exposed ground must belong to an outdoor Caribbean area and have no roof or
  floor-cover object. This includes canopy/non-area-switching roofs. Connected
  upper physical z-levels must be sky, broken floor or space, with no roof/cover
  above. Unconnected map z-levels are not ceilings. A roof prevents additional
  snowfall; it does not instantly erase existing cold cover.
- At **<=0 C**, eligible snowfall adds one loose-snow unit per candidate visit,
  capped at **2**. At **>2 C**, all generated units melt, regardless of snowfall
  or exposure. Between these thresholds existing cover remains. Refreezing clear
  ground requires new snowfall, not merely a temperature or season change.
- Temperature comes from existing `get_temp`, including its climate/time/weather
  behavior and active braziers/heatsources within 3 tiles and fireplaces/engines
  within 1 tile. Existing heat semantics ignore wall occlusion; no new heat
  diffusion model, ground heat storage or additional fire/torch interface is added.

`weather_snow` is a durable bounded scalar. It does not change turf type, icon,
soil fertility, underlying resource counters or contents. One runtime image uses
the artist-made `icons/turf/snow.dmi` snow state, on the tile's plane. Melting and
harvesting remove only that owned image; the original substrate needs no guessed
restoration. Normal floor-icon rebuilding reapplies cover. An opaque full snow
image has no new depth/edge artwork; client rendering/clipping remains unverified.

`has_snow_cover()` supplies the existing snow movement slowdown, foot cold check,
footstep sounds and shovel/spoon/ant snow collection. Generated units are consumed
separately from authored `available_snow`; the final unit reveals the same soil.
With the initial two-unit cap, up to two successful shovel collections clear a
full generated layer. Dirt turf identity, fertility, loose dirt and contents are
preserved, not reconstructed. A cleared layer yields nothing again until actual
eligible snowfall accumulates. Interrupted actions yield nothing. Authored snow
retains its explicit existing collection/trench terrain changes; the feature does
not invent hidden dirt underneath an authored permanent snow biome.
Completion rechecks current tile/savehold/available units and local melting before
minting a pile. Collection captures generated versus authored source before waiting;
generated collection cannot fall back to legacy stock. The generation changes when
cover starts/disappears, not on positive-to-positive unit changes: two collectors
can each take one of two units, while clear-and-reaccumulate cancels old waits.
Success text and strength rewards follow a successful debit in both handlers.
Snow-covered grass cannot produce grass cuttings, and plough/road
work requires clearing cover first. Seed planting still requires excluded ploughed
soil. Blood footprints remain their existing mechanic; there is no dedicated snow
footprint system. Underlying radiation/soil/vegetation logic is unchanged; foliage
snow coloration, authored winter-grass planting and trench excavation on authored
snow retain their own implementations rather than being cloned onto generated
cover. Generated cover has no water-freezing, snow-wall durability or building-load
effect. Snow walls still use their existing season/climate cleanup.

Save exports include `weather_snow` only when positive. Same-type import resets
this new scalar before field decoding, so old/clear-ground saves cannot inherit
live generated cover. Import excludes image/index/generation fields; after-load clamps the
scalar, registers the eligible tile and rebuilds its image without weather sampling
or accumulation. A runtime scalar generation changes on replacement and reload;
pre-wait collection checks cannot debit a replacement/imported layer. No per-tile
token datum is allocated. No schema/version migration or origin guessing is performed.
Unmarked legacy winter/snow/ice is preserved. New weather has no offline catch-up.

The base worker, Colonia, Pepelsibirsk and Ice Age no longer replace ground with
winter terrain or clear unmarked winter ground in season callbacks. Their weather
calls, phase/loop deadlines, year/age hooks, water/ice and other terrain work remain.
Authored map winter turfs, roof-area base turfs, Ice Age initial foliage and the
Chad-mode adjustment of already-snowy terrain remain authored setup. The existing
season-flow edge exclusions remain; this feature does not authorize new cold-entry
edges. Historical PRs and their evidence are not rewritten.

Scheduling: one process, every **2 seconds**, checks at most **256 candidates** and
stops after a candidate when total tick usage reaches **20%**. It uses a swap-remove
registry of exact eligible ground built by constructors, not repeated world scans.
Both native Del replacement and qdel Destroy unregister. Runtime cursor/deadline
are process-local; duplicate fire calls before the deadline cannot add work/cover.
All saves, active persistence operations and failed-load recovery hold sampling and
harvesting. No per-tile timer or second candidate snapshot is allocated. A full
rotation nominally takes ceil(N/256)*2 seconds, longer under tick pressure; brief
snowfall can be missed between visits. Local heat response can take a rotation.
Registry memory is O(N eligible tiles); native largest-map latency/RAM is pending.
One temperature query/overlay operation is indivisible, not a hard latency bound.

Offline tests project production decisions, heat-tail rules and the bounded
process, with explicit list/location/rendering/temperature-prefix adapters. They
cover no-snow cold, warm snowfall, roofs/upper floors, nearby active heat, threshold
hysteresis, repeated fire, stale tiles, finite harvest and scalar reload. Historical
source controls verify the exact removed snow-only loops and retention of unrelated
calendar/water/weather work. These do not execute BYOND savefiles, callbacks,
constructors, clients or performance. The race control's nonzero legacy stock on ordinary dirt
is injected (ordinary dirt/grass defaults to zero); the former reward-before-debit
ordering could report success even with default stock when final melting rejected.
`tests/snowfall_ground/native_probe.dm` is uncompiled source for a future separately
admitted isolated full-game harness.

## Native module evidence (2026-10-25)

The hosted Linux BYOND **516.1688** [attempt3 run](https://github.com/Civ13/Civ13/actions/runs/40169744620)
passed against source `47d788a306ae6b7e19327a0bdf7d388972d07b94`, tree
`f2393bd7264b5d3b8aae553f80add05fa67e9bf7`. Controller:
`c0d52f9f0f693aad9acb20360f5d14421be407e1`. Verified artifact `12589527408`
has SHA-256 `2436b91622972dc1aea87b88bdb74ccedfc829caf13fc2f242a8bc85b7b72065`.

The baseline in this isolated 18 x 18 x 3 fixture compiled the unchanged production
snow module/process, exact floor `New` and turf runtime-exclusion hooks, and
original snow DMI. Temperature and connected-level topology were explicitly
injected; other game services used minimal stubs. It admitted no clients and
used no real saves or full custom serializer. The original
`tests/snowfall_ground/native_probe.dm` remained unchanged and uncompiled.

All **64 baseline assertions** passed. Six separately compiled causal variants
each failed exactly its intended assertion, covering omitted overlay publication,
melt, debit generation comparison, reload generation invalidation, sampling during
reload, and native `Del` unregistration. All seven compiler/daemon pairs completed
with **14 verified owned-process cleanup receipts** and seven listener-closure
censuses before semantic checks. Native appearance properties/ownership, core
`take_snow`, selected reload hooks and a 300-candidate/256-per-batch fixture now
have bounded native evidence; these are not client-pixel or server-scale results.

Earlier failed attempts remain part of the record:
- [Attempt1](https://github.com/Civ13/Civ13/actions/runs/40168306589) stopped after
  compiler start on engine-created private `home/.byond`; no daemon was attempted.
  Its exception path lost final cleanup observations, so cleanup remains unproven.
- [Attempt2](https://github.com/Civ13/Civ13/actions/runs/40169405056) failed an
  overbroad `/home` test sentinel before toolchain acquisition or native execution.
  Attempt3 corrected that test's fixture-root scope without changing the reviewed
  native controller or DM fixture.

[Acceptance follow-up #3312](https://github.com/Civ13/Civ13/issues/3312) retains
real climate/heater and connected-z integration, full serializer/legacy-import
round trips, actual shovel/spoon/ant action handlers and rewards, client rendering,
seasonal map execution, full floor-icon/qdel/Destroy behavior, and largest-map
memory/latency under the real scheduler. This module pass establishes none of
those broader acceptance results and does not relax existing local holds.

No local native launch is permitted under the uncertain movement-launch/process-
inventory hold. Parent owns admission and the testing deadline; no sealed packet,
live save/server/config or Gaia cycle is changed by this draft.
