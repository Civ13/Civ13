# Precipitation types

`code/modules/1713/weather_precip.dm` decides what a storm drops on each tile.
The climate table (`climate_weather_state()` in `weather.dm`) still says how
much a storm drops over a climate in a season. The air on the tile now says
what it is: the air grid's temperature ([weather-air.md](weather-air.md)) less
hill cooling ([climate-normals.md](climate-normals.md)).

| Air on the tile | What falls |
| --- | --- |
| 3 C and above | rain, or drizzle when it is light and the air is 90% humid or more |
| 1 to 3 C | sleet |
| below 1 C | snow; a heavy core under a severe storm is a blizzard |
| 0 C or below, in the warm air ahead of a low ([weather-fronts.md](weather-fronts.md)) | freezing rain |
| 10 C or above, the heavy core of a severe thunderstorm | hail |

So a temperate winter storm snows at night and may rain on a mild afternoon,
and a cold spell in fall turns rain to snow. Thunderstorms that build on hot
afternoons are the only ones that hail.

## What it does

- **Sleet, drizzle, freezing rain and hail** look and act like rain to the
  existing readers: floods, rain barrels, rain gear, mud and the rain sound.
  **Snow** looks like snow, so snow on the ground builds up wherever it falls.
- **Freezing rain** glazes the open ground in its air cell for ten minutes,
  and the ice lasts while the air stays at 1 C or colder. Glazed ground is ice
  for footwear (`footwear_ice_turf()`), so running on it can slip without good
  ice grip.
- **Hail** hits everyone out under it about every other weather tick for
  1 to 3 brute damage to the head. Any helmet, or a hat with melee armour of
  20 or more, stops it.
- **Hills:** on maps with heights, a storm drops more where the wind blows up
  a slope and less in the rain shadow behind it. The factor is 1 + 0.04 x wind
  (m/s) x slope (levels a cell) per cell, between 0.6 and 1.5. It scales the
  storm strength, so the drawing, lightning and readers all agree.

## Readers

| Proc | Answer |
| --- | --- |
| `weather_precip_at(atom)` | `""`, `"rain"`, `"drizzle"`, `"sleet"`, `"freezing_rain"`, `"snow"` or `"hail"` |
| `weather_glazed_at(turf)` | TRUE where freezing rain has iced the ground |
| `weather_orographic_at(x, y)` | the hill factor, 1 on flat maps |
| `weather_hail_proof(human)` | TRUE when the headgear stops hail |

Before the air grid exists, the climate table decides alone, as it did
before.

## Drawing

Sleet and hail have their own falling art, drawn by Fable 5.2 with
`tests/sprites/create_weather_precip.py` (`sleet1`, `sleet2`, `hail` in
`icons/effects/weather.dmi`, cut into chunks by `tools/weather/make_chunks.py`).
`weather_precip_draw_look()` picks them for the chunk drawing; the readers
still answer the rain looks. A `glaze` overlay for iced ground is in the
sheet but not drawn yet.

## Not yet done

Drawing the glaze on iced ground, hail damage to crops and animals.

## Tests

```sh
python3 tests/ecology_spawning/run_linux.py . tests/weather_precip/probe.dm
```
