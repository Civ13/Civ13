# Wind field

`code/modules/1713/weather_wind.dm` gives every cell of the air grid
([weather-air.md](weather-air.md)) its own wind, in metres a second toward the
east and the north. The wind on a tile blends the four cells round it.

## What makes the wind

Each weather tick (10 seconds) a cell's wind closes a quarter of the gap to
the sum of:

- **The map's wind.** `map.winddirection` and `map.windspeedvar` stay the
  large-scale flow that carries storms and pressure centres. Strengths 0 to 4
  are 0, 3, 6, 11 and 18 m/s. The wind now veers through eight headings, an
  eighth of a turn at a time, and never reverses. A diagonal wind moves storms
  and centres at the same speed as a straight one.
- **The pressure field.** Air flows down the pressure slope between cells,
  2 m/s for each hPa of difference across a cell, at most 25 m/s, turned
  60 degrees by the Earth's spin. Round a low it circles anticlockwise in the
  northern hemisphere and clockwise in the southern, spilling a little inward.
  A map whose `sun_latitude` is below 0 is southern; every other map is
  northern. Storm cells and the lows of [weather-fronts.md](weather-fronts.md)
  both lower the pressure, so wind picks up round them.
- **Sea and land breezes.** Cells on a shore (land next to water or water next
  to land) get a breeze toward the land of up to 4 m/s at Midday and in the
  Afternoon, and toward the water of up to 2 m/s at Night, Dark Night and
  Early Morning. Cloud weakens both; overcast stops them.
- **Terrain**, on maps with a height sidecar. A cell's height is the mean of
  nine points across it. Cells above their neighbours are windier (15% a
  level, at most 1.6 times), cells below them sheltered (at least half). A
  valley cell at least a level below its neighbours turns half the wind along
  its floor. On clear nights cold air drains downhill, 1.5 m/s a level of
  slope across a cell, at most 4 m/s.

A storm overhead still raises the wind as before: a gale under a severe storm's
heavy core.

## Readers

| Proc | Answer |
| --- | --- |
| `weather_wind_at(atom)` | 0 (calm) to 4 (gale), the old scale, now from the local wind |
| `weather_wind_vector_at(atom)` | list(east, north) in m/s, before storm gusts |
| `weather_wind_ms_at(atom)` | speed in m/s, with storm gusts |
| `weather_wind_beaufort_at(atom)` | Beaufort force 0 to 12 |
| `weather_wind_dir_at(atom)` | the BYOND dir the wind blows from; a calm keeps the map's heading |
| `weather_wind_heading(dir)` | "north-east" and so on |

Before the air grid exists, and on a flat, dry map under even pressure, every
reader gives the map's wind exactly as before.

Sailing (step time, sail push, the craft's report and the outrigger canoe),
drifting hulls, windmills, wind generators, the weather vane and sea state all
read the local wind. The vane has four arrow sprites, so a diagonal wind shows
its east or west half; its examine text names all eight headings.

## Admin tools

The Admin Map has a **Wind** switch that draws an arrow per cell (white
below 8 m/s, yellow to 14, red above), and the air tooltip gives the cell's
wind speed.

## Tests

```sh
python3 tests/ecology_spawning/run_linux.py . tests/weather_wind/probe.dm
```

The probe checks the scales, the old readers on flat ground, eight headings
and diagonal drift, the circulation round a low in both hemispheres, sea and
land breezes, sheltered valleys, valley steering and night drainage, how fast
a new wind builds, and the Admin Map data.
