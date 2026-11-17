# Sun and shadows

`code/modules/1713/sun_shadows.dm` gives continent maps a sun that moves through the day.

## The sun's path

The day already runs in phases (`code/__defines/time_of_day.dm`). Each daylight phase draws the sun at a fixed share of the local day, from sunrise (0) to sunset (1):

| Phase | Share of the day |
| --- | --- |
| Early Morning | 0.1 |
| Morning | 0.3 |
| Midday | 0.5 |
| Afternoon | 0.7 |
| Evening | 0.9 |

Night has no sun. The sun's azimuth and elevation come from standard solar geometry (`sun_position`), using:

- the map's `sun_latitude` (degrees, south negative);
- the season's declination (`sun_declination`). Summer and the wet season give the local midsummer sun (23.44 degrees toward the local pole's side), winter and the dry season give the midwinter sun, and spring and autumn give the equinox.

So the sun rises in the east and sets in the west everywhere, stands south of overhead at noon in the northern hemisphere and north of it in the southern one, climbs higher in summer, and may not rise at all in a polar winter. A sun lower than 2 degrees counts as no sun. `sun_angles()` caches the answer per latitude, season and phase.

Continent latitudes:

| Region | `sun_latitude` |
| --- | --- |
| North America | 35 |
| South America | -20 |
| Gaia | 45 |
| Europe | 50 |
| Desert | 25 |
| Jungle | 2 |
| Asia | 40 |

Other maps leave `sun_latitude` null and keep the old grey daylight with no sun shadows. `sun_latitude` is map data and is never saved.

## What the sun changes

- **Daylight colour.** `sun_daylight_tint()` multiplies the daylight term per colour channel by `sun_elevation_tint()`: white with the sun 40 degrees or more up, warming toward 1.18 / 1.00 / 0.78 at the horizon, so a low winter noon is a little warm too. Night is slightly cool (0.84 / 0.93 / 1.14); a daylight phase with no sun keeps plain grey. Both daylight paths use it: the server's overlay matrix (`lighting_overlay.dm`) and the client's light-mask plane master (`plane_master.dm`, live servers with `DAYNIGHT_CLIENT_TINT`).
- **Tree shadows.** Trees, jungle trees and palms register in `sun_shadow_casters` and wear one shared overlay image (`icons/effects/sun_shadow.dmi`, drawn by `tests/sprites/create_sun_tree_shadow.py`) on the floor plane, below every object and never clickable. A matrix turns it away from the sun and stretches it by `1 / tan(elevation)`, capped at 2.2 times the tree's height. A soft contact pool at the trunk foot, strongest under a high sun, keeps noon shade visible. Images are shared per shape, size, trunk position and sun, so a phase change is one overlay swap per tree. Shadows go at night.
- **Hills.** On maps with a height file the slope shading is lit from the sun and higher ground casts shadows (`sun_hills.dm`). The shadow's edge is soft: the march toward the sun reads the ground between corners along grid lines, and a corner darkens by how far the ground stands above the sun's ray (`SUN_PENUMBRA` levels for full shadow, more for a far blocker), so edges do not follow the tile grid and half-level bumps cast nothing. The terrace lines are lit from the sun's side of the compass (see [terrain height](terrain-height.md)).
- **Ambient shadow.** The game plane's soft drop shadow leans away from the sun.

`sun_shadows_phase()` runs when the time of day settles (`apply_time_of_day_effects`). A season change takes effect at the next phase.

## Cost

Measured on Gaia (about 3,000 casters): about 60 ms of CPU per phase change for the tree shadows, spread over a few ticks, and under 1 MB of memory. The tint costs nothing on the client-tint path.

## Tests

`python3 tests/sun_shadows/run.py --byond-bin <BYOND bin>` compiles the full game with an isolated probe that checks the sun's path on every continent and season, polar night and midnight sun, the sunless default, and tree shadow sharing, swapping, night removal and registry clean-up.
