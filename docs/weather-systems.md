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

A piece on the storm's edge is not drawn at one strength. The strength is
asked at the piece's four corners, each put on a scale of 0 to 3, and the
piece is cut by the matching fade from `icons/effects/weather_edge.dmi`
(`m<sw><se><nw><ne>`) as an alpha mask filter. A corner is shared by the four
pieces round it, so the rain and the cloud shadow thin out evenly toward the
edge with no step between pieces. A piece whose fade changes is a new image
that fades in over two seconds while the old one fades out.

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

### Cloud shadow

Every drawn piece also carries a cloud shadow from
`icons/effects/weather_storm.dmi`, under the rain. Its opacity follows the
storm's strength and it starts further out than the rain does, so the cloud
is seen arriving before it breaks. The cloud is one field eight tiles on a
side, cut in four pieces, and each drawn piece shows the quarter its place
calls for (`weather_shadow_piece()`), so the pattern repeats every eight
tiles. Its thirty-two frames slide the whole field once round the way the
wind carries the storms, so neighbouring pieces join and the loop has no
jump.

### Lightning and thunder

`weather_lightning_step()` (code/modules/1713/weather_lightning.dm) lets each
rain storm at heavy strength roll for a strike every two seconds: about one
every 20 seconds, or every 8 in a severe storm. Snow and sand throw none.
Players within 90 tiles see a soft white flash (weaker under a roof), see the
bolt if it lands on their screen, and hear thunder after a third of a second
for every ten tiles. **A strike is seen and heard only: it starts no fire and
hurts nobody.** That stays so until firefighting tools exist.

The shadow and the bolts are placed pixel by pixel by a seeded script, and
the two thunder sounds are synthesised noise:

```sh
python3 tools/weather/make_storm_art.py            # rewrite the icons
python3 tools/weather/make_storm_art.py --check    # exit 1 if stale
python3 tools/weather/make_storm_art.py --preview storm.gif
python3 tools/weather/make_thunder.py              # needs numpy and ffmpeg
```

## Forecasting

`weather_forecast(atom, horizon)` (code/modules/1713/weather_forecast.dm) asks
every storm for its strength over a tile at half-minute steps ahead, fifteen
minutes by default, and returns when the next one breaks there, where it is
now, how heavy it will be and when the storm overhead lets up. It supposes
the wind holds, so a storm that veers makes it wrong.

Players read it three ways:

- A **weather vane** (wood, Primitive Construction) points into the wind when
  it stands out of doors. Examined, it gives the wind and whether the sky
  upwind is dark, but not how soon.
- A **barometer** (iron, Optics & Instruments), used in the hand, says
  whether the needle is steady, falling, falling steadily or dropping fast,
  and in how many minutes the weather breaks or passes.
- The **Farmer's Almanac** has an Outlook line with the same forecast, and
  its Sky line now reads the weather over the reader's own tile.

`weather_sea_state(atom)` names the water under the local wind: calm, choppy,
rough or raging. The sprites are drawn by
`tests/sprites/create_weather_instruments.py`.

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

Moisture gained over water and lost over high ground, wind in eight
directions, lightning that starts fires (and poles that draw it away), and
rip tides.
