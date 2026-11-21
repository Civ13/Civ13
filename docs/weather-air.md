# The air grid

`code/modules/1713/weather_air.dm` keeps a coarse field of air over the map:
temperature, dew point, pressure and cloud cover. It is the base the later
meteorology steps build on (fronts in [weather-fronts.md](weather-fronts.md), the wind field in
[weather-wind.md](weather-wind.md), then fog, dew and frost).
Players feel its wind; its temperature waits: `get_temp()` still comes from
[climate-normals.md](climate-normals.md).

## Cells

The grid has one cell per 16 x 16 tiles, one grid for the whole sky like the
weather systems. Gaia (500 x 350) has 32 x 22 cells. When the grid is built,
each cell takes the most common climate at nine points across it, read from the
highest open-sky ground there, and is marked as water when most of those
points are open water. The grid is not saved: after a restart it is built
straight at the values below, so there is nothing to spin up.

## Each weather tick

`weather_air_step()` runs from `weather_systems_step()` every 10 seconds. Each
cell moves part of the way toward its target:

| Value | Target | Share closed per tick |
| --- | --- | --- |
| Temperature | climate mean for the season's progress plus the daily offset (halved over water, a third under thick cloud), 2 C colder under a storm, 6 C warmer under a heat system, plus the warm and cold sides of a low | 10% |
| Dew point | from the climate's normal humidity (`climate_humidity`), 10 points wetter over water, toward 97% under a storm, 20 points drier under heat | 8% |
| Pressure | 1013 hPa, down to 995 under a storm (983 severe), up to 1023 under a heat system, plus the lows and highs of [weather-fronts.md](weather-fronts.md) | 15% |
| Cloud | the storm's strength, or a grey sky when humidity passes 90% | 20% |

The dew point never rises above the temperature.

## Readers

Each reader blends the four nearest cells, so values change smoothly:

| Proc | Answer |
| --- | --- |
| `weather_air_temp_at(atom)` | open-sky air temperature, C |
| `weather_dew_point_at(atom)` | dew point, C |
| `weather_humidity_at(atom)` | relative humidity, % |
| `weather_pressure_at(atom)` | sea-level pressure, hPa |
| `weather_cloud_at(atom)` | cloud cover, 0 to 1 |

`weather_dew_point(temp, rh)` and `weather_relative_humidity(temp, dew)` use
the Magnus formula.

## Admin tools

The **Admin Map** has an *Air* menu that shades every cell by temperature,
humidity, pressure or cloud. Clicking a spot or a player also lists the air
there.

## Tests

```sh
python3 tests/ecology_spawning/run_linux.py . tests/weather_air/probe.dm
```

The probe checks the formulas, the starting values, gradual cooling at night,
pressure, cloud and humidity under a storm and a heat system, water cells,
the map data and the weather-tick hook. 200 settles of 24 cells take about
0.06 s, so Gaia's 704 cells cost a few milliseconds every 10 seconds.
