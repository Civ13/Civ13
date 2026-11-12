# Moving weather systems

Random weather is a set of weather systems that cross the map, not one value
for the whole server. This page describes the code in
`code/modules/1713/weather_systems.dm` (the sky), `weather_chunks.dm` (the
drawing) and `code/processes/weather.dm` (the rolls).

## What a system is

A `/datum/weather_system` is an oval of cloud: a centre, two radii (25 to 90
tiles), a course, a peak strength and a lifetime of 15 to 40 minutes. Its
place is worked out from the time whenever it is asked for, so nothing loops
over tiles and nothing moves on the map. At most `WEATHER_SYSTEM_MAX` (6)
exist at once. Systems are the same sky over every level, and they are never
saved: a restart begins with a clear sky.

A system forms off the upwind edge of the map and travels with the wind, a
tile every 2.5 to 8 seconds by wind strength. When the wind changes it comes
round to the new course a little each weather tick. It grows for its first
minute, fades over its last two, and is removed when it has faded or left
the map.

Two kinds exist. A **storm** brings precipitation; a **severe** storm has a
core of extreme weather. A **heat** system brings no precipitation: under it
people thirst faster, crops dry faster, barrels collect no dew, and wells and
puddles are dry.

## The weather on a tile

Everything that asks about the weather asks for a tile:

| Proc | Answer |
| --- | --- |
| `weather_at(atom)` | `WEATHER_NONE`, `WEATHER_WET`, `WEATHER_EXTREME` or `WEATHER_SMOG` |
| `weather_look_at(atom)` | what is falling: `""`, `rain1` to `rain3`, `monsoon`, `snow1`, `snow2`, `snow_storm`, `sandstorm` |
| `weather_intensity_at(atom)` | 0 in clear weather, 1 to 3 otherwise |
| `weather_heat_at(atom)` | TRUE under a heat system |
| `weather_wind_at(atom)` | wind strength 0 to 4, raised under a storm |
| `weather_anywhere()` | cheap gate: any storm or pinned zone weather at all |

Do not read `area.weather` or `area.icon_state` for gameplay: an area is a
whole climate zone and a storm covers part of it.

The strength of the strongest storm over the tile picks a band: light
(intensity 1), steady (2) or heavy (3). Only a severe storm's heavy band is
extreme. `climate_weather_state(climate, class, intensity)` then says what
that is in the tile's climate and the current season, so one storm rains on
temperate ground, snows on tundra and raises sand over dry desert. That table
is the one zone weather has always used; the Farmer's Almanac test reads it.
Roofed areas are always `WEATHER_NONE`.

## Rolls and events

The weather process still rolls the season's pool through
`change_weather_somehow()` and the per-map policy in
[weather-policy.md](weather-policy.md). A wet or extreme result now calls
`weather_roll()`, which sends one storm across the map instead of changing
every zone. Wide maps are rolled more often and hold more storms at once
(`weather_system_capacity()`: one per 40,000 tiles, at most 6).

The scripted blizzard, sandstorm and heat wave timers are gone, along with
their saved callbacks. `map.triggered_blizzard` and `map.triggered_sandstorm`
call down a severe storm, and `map.triggered_heatwave` a heat system, each
arriving from upwind in about a minute. Summer still brings heat waves by
itself. Nobody gets a world announcement: players in a storm's path are told
it is coming, with its bearing, and players under a heat system are told when
it arrives and when it has passed.

## Pinned zone weather

`change_weather(class)` still paints every zone at once. It is for map
scripts that fix a look (Antarctica) and for tests. A storm overhead and
pinned zone weather are compared per tile and the worse one wins. A clear
roll lifts pinned weather, as it always did.

## Drawing

`weather_chunks_step()` runs every two seconds while any storm exists. For
each client it covers the view, plus a margin, with images four tiles on a
side from `icons/effects/weather_chunks.dmi`. Clients near each other share
the same images. An image takes its look from the climate under it and its
opacity from the storm's strength there, so the edge of the rain is a line on
the ground that moves with the storm. Images are client-side only: they are
in no turf's contents and are never saved.

Roofed areas (`location == AREA_INSIDE`) draw `icons/effects/weather_roof.dmi`
on `WEATHER_ROOF_PLANE`, which is never shown. The weather plane (plane 3)
has an inverse alpha mask filter from it, so weather is cut away over roofs.
The mask is drawn almost clear and made solid by its plane master, so a
client without that plane master sees nothing of it.

Both icons are built from the existing weather sheet, with no new art:

```sh
python3 tools/weather/make_chunks.py            # rewrite both icons
python3 tools/weather/make_chunks.py --check    # exit 1 if either is stale
```

## Admin tools

- **Weather Map** (Admin tab): a live map of a level with every system, its
  course, the wind and the players. Click a spot to send a storm, a severe
  storm or a heat wave there; click a system to end it; or clear the sky.
- **Randomly Change the Weather** (Debug): one roll of the season's pool.

## Tests

```sh
python3 tests/ecology_spawning/run_linux.py . tests/weather_systems/probe.dm
python3 -m unittest tests/weather_systems/test_icons.py
```

The native probe walks storms over temperate, tundra, desert and roofed
areas and checks the per-tile answers, rolls, called-down events, pinned zone
weather, wind veering and retirement. It has no client, so it does not check
what is drawn.

## Not yet done

Cloud shadows and lightning, moisture gained over water and lost over high
ground, wind in eight directions, and rough seas under a storm. Lightning
will start no fires until firefighting tools exist.
