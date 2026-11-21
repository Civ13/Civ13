# Fog, mist, dew and frost

`code/modules/1713/weather_fog.dm` gives every air cell
([weather-air.md](weather-air.md)) a fog density from 0 to 1, and reads dew
and frost off the open ground.

## The air behind it

The air grid's dew point comes from the climate's normal humidity at the
day's **mean** temperature. The moisture stays as the air cools at night, so
on a clear night in a humid climate the air reaches its dew point by dawn,
while the dry desert never does. Under rain the dew point follows the air
itself, which the rain keeps near saturation. By night, saturated air no
longer turns into grey cloud; it lies on the ground as fog.

## Fog

Each weather tick a cell's fog moves toward its target, a tenth of the gap
when it thickens and a fifth when it clears.

- **Radiation fog:** at Night, Dark Night and Early Morning (and 70% of it in
  the Morning), under less than 40% cloud and a wind below 4 m/s, when the air
  is within 2 C of its dew point. It is `1 - spread / 2`, scaled down from
  1 m/s to 4 m/s of wind; valleys (cells a level or more below their
  neighbours) get 0.25 more.
- **Sea fog:** over water cells and the shore beside them, by day or night,
  when the air is within 1 C of its dew point and the wind is under 7 m/s;
  60% of it on the shore and half of it at Midday and in the Afternoon.
- **Clearing:** none from Midday to Evening except sea fog, none in a wind of
  7 m/s or more, and rain (cloud above 40%) washes it out.

| Density | Level | Effect |
| --- | --- | --- |
| 0.3 or more | mist | haze from about 5 tiles, 60% by about 9 |
| 0.65 or more | fog | clear only within about 4 to 5 tiles, solid grey by 9 |

## What it does

- **The view:** each drawing step (2 s), a living player out of doors in mist
  or fog gets a soft haze over the screen, drawn by Fable 5.2 with
  `tests/sprites/create_weather_fog.py` (`icons/effects/weather_fog.dmi`,
  `mist_view` and `fog_view`, 128 px scaled six times for mist and ten for
  fog about the player). It is on `CHAT_PLANE` under chat text and the HUD,
  tinted dimmer at dusk and nearly black at night (it is drawn above the
  lighting), and fades over 1.5 s, or 5 s when only the light changes.
  Indoors and under roofs there is none.
- **At sea:** mist takes 15 tiles from a lookout's range and fog 25, on top of
  rain or storm (`sea_murk_at()`), and the helm names it.
- **Rain barrels:** an open barrel catches 2 units of dew where dew forms
  (below), 3 in fog. Before the air grid exists any clear night still gives 2.
- **Naturalists** can record mist, fog and hoarfrost as weather finds.
- **Admin Map:** the Air layer has a fog option, and the tooltip gives the
  fog in a cell.

## Dew and frost

`weather_dew_at()` and `weather_frost_at()` need the open ground cooling under
a clear, calm sky: Night to Morning, no rain, under 50% cloud and a wind
below 4 m/s. Then the ground has frost when the air (less hill cooling) is at
1 C or below, and dew when it is warmer but within 3 C of its dew point. Frost nips back tender crops unless they are covered ([crop-frost.md](crop-frost.md)).

## Readers

| Proc | Answer |
| --- | --- |
| `weather_fog_at(atom)` | fog density 0 to 1 outdoors, 0 indoors or with no air grid |
| `weather_fog_level(atom)` | `""`, `"mist"` or `"fog"` |
| `weather_dew_at(atom)` | TRUE where dew lies on the open ground |
| `weather_frost_at(atom)` | TRUE where frost whitens the open ground |

## Tests

```sh
python3 tests/ecology_spawning/run_linux.py . tests/weather_fog/probe.dm
```
