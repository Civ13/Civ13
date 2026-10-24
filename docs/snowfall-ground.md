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
image has no new depth/edge artwork; native appearance/clipping remains unverified.

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
minting a pile. Snow-covered grass cannot produce grass cuttings, and plough/road
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
constructors, clients or performance. `tests/snowfall_ground/native_probe.dm` is an
uncompiled source probe for a future separately admitted isolated full-game harness.
No local native launch is permitted under the uncertain movement-launch/process-
inventory hold. Parent owns admission and the testing deadline; no sealed packet,
live save/server/config or Gaia cycle is changed by this draft.
