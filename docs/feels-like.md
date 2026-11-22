# Feels-like temperature

`code/modules/1713/feels_like.dm` turns the air's temperature (`get_temp()`,
[climate-normals.md](climate-normals.md)) into what a person out of doors
actually feels, and `handle_environment()` in `human_life.dm` warms or chills
the body toward that. Indoors, under a roof and on barren worlds with their
own air, nothing changes. The thermometer still reads the air.

| Effect | When | How much |
| --- | --- | --- |
| Wind chill | air at 10 C or below, wind 1.3 m/s or more | the Canadian/US wind chill formula, from the local wind ([weather-wind.md](weather-wind.md)) with storm gusts |
| Heat index | air at 27 C or above, humidity 40% or more | Rothfusz's regression, from the air grid's humidity ([weather-air.md](weather-air.md)) |
| Sun | air at 20 C or above, Midday or Afternoon, under 40% cloud and no rain | +3 C |

So -2 C in an 11 m/s wind feels like about -10 C, and 32 C at 70% humidity
like about 40 C.

## Gear

- **Wind resistance** (`wind_resist`, percent) on the suit and uniform and the
  capes over them stacks as independent layers, capped at 90%. A plain suit
  keeps off 20%, a coat 50%, fur and leather coats 60-70%, oilskins and rain
  coats 70-80%, a chemical poncho 90%, capes 30-40%.
- **Sun shade** (`sun_shade`, percent): brimmed or draped hats (straw hat 60,
  rice hat 70, sombrero 80, cowboy hat 50, pith helmet 70, keffiyeh 50, turban
  40) and light robes (Arabic robes 50, tunics and togas 30, kimono 20) add
  together against the sun. A loose robe also lets out half its shade's share
  of the humid heat.

Every 5 minutes at most, someone losing 5 C or more to the wind, or gaining
4 C or more from humid heat and sun, is told so and what would help.

## Readers

| Proc | Answer |
| --- | --- |
| `weather_feels_like_at(atom)` | the feels-like temperature for bare skin |
| `feels_like_parts(turf, temp)` | list(wind chill, heat index, sun) in C |
| `human.feels_like_temperature(temp)` | the same, after what they wear |

## Tests

```sh
python3 tests/ecology_spawning/run_linux.py . tests/feels_like/probe.dm
```
