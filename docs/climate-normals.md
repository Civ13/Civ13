# Climate normals (outdoor temperature)

`get_temp()` starts from the climate's air at this point in the year and the
day, then applies the weather overhead, hills, shelter, cellars and fires.
The first part lives in `code/modules/1713/climate_normals.dm`.

## Normals

Each climate in `climate_normals` has a cold-season mean, a warm-season mean
and a daily swing, in degrees C:

| Climate | Cold season | Warm season | Daily swing |
| --- | --- | --- | --- |
| temperate | -2 | 20 | 10 |
| sea | 5 | 17 | 5 |
| taiga | -18 | 15 | 12 |
| tundra | -28 | 8 | 8 |
| semiarid | 5 | 26 | 15 |
| desert | 13 | 34 | 18 |
| savanna | 22 | 28 | 12 |
| jungle | 26 | 28 | 8 |

An unknown climate stays at 20 C.

## The year

`climate_mean_at(climate, season, fraction)` follows a smooth curve through
the season's progress (`map.season_change_window()`; mid-season when seasons
are off). On the four-season cycle it is warmest at mid-summer and coldest at
mid-winter, with spring and fall at the annual mean, so nothing jumps when the
season changes. On the wet and dry cycle the wet season is the cooler half and
the dry season the warmer, half the four-season range either side of the mean.
The Farmer's Almanac prints each season's middle (`climate_season_mean()`).

## The day

`climate_daily_offset()` adds a share of half the daily swing: -1 at Early
Morning, -0.3 Morning, +0.6 Midday, +1 Afternoon, +0.2 Evening, -0.6 Night and
-0.8 Dark Night. Under any precipitation only a third of the swing applies,
because cloud keeps the sun out by day and the heat in by night. The offset is
added, never multiplied, so nights are colder in every climate.

## Weather, hills and shelter

`climate_weather_offset()` adds to the air: rain or snow takes off its
intensity (1 to 3 C), a monsoon 3 C, a blizzard 10 C, and a heat system adds
6 C. Hills from a map's terrain height file are colder at 6.5 C per km, with
a hill level standing for 50 metres (`terrain_temperature_drop()`, about 10 C
at the top level); authored geographic elevation still needs the map's lapse
rate ([elevation.md](elevation.md)). Roofs, rooms, cellars and fires then work
as before (`cool_cellars.dm`, `building_insulation.dm`).

## Tests

```sh
python3 tests/ecology_spawning/run_linux.py . tests/elevation_climate/probe.dm
python3 -m unittest tests/farmers_almanac/test_farmers_almanac.py
```
