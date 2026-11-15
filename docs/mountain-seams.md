# Mountain seams

On the Americas maps the ground where a mountain stood stays a mine, so mining
never runs out when the mountain rock is gone. Both maps are one surface level
with no cave level below (a cave plane would double their cells; see
[americas-regions.md](americas-regions.md)), and their mountain rock is finite:
47,944 rock tiles in the north and 40,669 in the south.

Source: `code/modules/1713/mountain_seams.dm`. Tests:
`tests/mountain_seams/test_source.py` (map facts, source contract) and
`tests/mountain_seams/native.py --byond-bin DIR` (DreamDaemon fixture).
Plan and decisions: project file `mining-loop/plan.md` (approved 2026-11-15).

## Where

A map opts in with `mountain_seams = TRUE` (`americas_north`,
`americas_south` and `asia`, the one-level lands with mountains and no cave). Seam ground is open `/turf/floor/dirt` (not standing rock)
on z 1 inside `/area/caribbean/void/caves`, with no road or floor cover and no
dense anchored structure. On both maps that area holds exactly the mountain
rock, and mining swaps the turf but keeps the area, so seam ground is the
mined-out mountain footprint. `test_source.py` checks this on the committed
maps. Shovel-excavated rock counts too.

Asia is hand-drawn rather than generated: its caves area is mountain rock plus
about 140 tiles of open cave floor, which are seam ground from the first day.

## What a pickaxe gets

Working seam ground takes `480 / strength / pickaxe speed`, twice a rock wall.

| Tile | Per load | Fresh rock wall, for comparison |
| --- | --- | --- |
| Bedrock (11 tiles in 12) | 6-10 stone, never runs out | 16-24 stone |
| Copper, tin, iron, zinc seam | 4-8 ore + 4-6 stone | 12-24 ore with the full roll |
| Coal seam | 8-12 coal + 4-6 stone | 24-32 |
| Saltpeter, sulphur, lead seam | 3-4 + 4-6 stone | 8 |
| Silver, gold seam | 1-2 + 4-6 stone | 4 |

A seam holds 6 loads, and one comes back every 20 minutes. A worked-out seam
gives bedrock stone. Stocks are runtime only and restart full with the server,
as flint rocks and obsidian outcrops do.

Seam or bedrock is fixed by position: 16 bits of `md5("x,y,map ID")`, a seam
when that is a multiple of 12. The ore is fixed per 12x12 block (a district):
copper 22, tin 16, iron 30, zinc 6, coal 10, saltpeter 4, sulphur 4, lead 4,
silver 3, gold 1, out of 100. Age gates match `mining_proc`: iron and zinc
from age 1, coal, saltpeter, sulphur and lead from age 2. A seam whose ore is
not open yet gives bedrock stone and says so on examine.

Gems, flint, obsidian, diamonds, bauxite, uranium and expedition lodes stay
fresh-rock only. `mining_proc` and its balance are unchanged.

## How it shows

Mining the rock over a seam prints "A vein of copper runs on down into the
floor here." An exposed seam carries a faded, small copy of its ore sprite
(existing art from `icons/obj/mining.dmi`). Examine names the ore and whether
it is rich, thinning or worked out; bedrock says stone can still be quarried.
Markers are runtime overlays: a start pass re-adds them once the world is ready
(`building_standing_ready()`), and logs "Mountain seams: N exposed seams marked."

## Persistence and memory

Nothing is saved and no turf, object or level is added. Seam, ore and marker
come from position; stocks and busy flags live in global tables keyed by
"x,y,z". At most about 7,400 small stock datums exist, one per seam worked.

## Later

- Era upgrades: a timbered shaft head on a seam (more loads), a windlass
  (faster loads), a pump (faster regrowth); rockwall cores as deep seams for
  diamonds and uranium.
- [multi-depth-mining.md](multi-depth-mining.md): a seam becomes the shaft head
  of a deep mine column; districts carry over.
- A measured lower level for the Americas would bring both a seabed for diving
  and deep mining.
- Proper seam art (Fable).
