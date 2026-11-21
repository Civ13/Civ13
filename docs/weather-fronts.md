# Lows, highs and fronts

`code/modules/1713/weather_fronts.dm` gives the sky a reason for its storms.
Pressure centres drift across the map with the wind and shape the
[air grid](weather-air.md); the storms in [weather-systems.md](weather-systems.md)
form where the air calls for them. Nothing here is saved.

## Centres

A `/datum/weather_centre` is a **low** or a **high**: a heart, a radius (a
quarter to half of the map's longer side, plus 40 tiles), a depth of 10 to 30
hPa for a low or 8 to 20 for a high, and a life of 30 to 60 minutes. It forms
on the upwind edge and drifts at 0.6 times the storms' speed. It deepens over
its first five minutes and fills over its last five. Up to three exist at
once. When the sky has none, the weather tick forms one at once; otherwise
there is a 2% chance a tick while fewer than three exist. Lows are favoured in
winter, spring and the wet season (65%), highs in summer and the dry season
(65%). A map whose `valid_weather_types` has no wet weather forms none.

Each centre adds to the air grid's targets, falling off with distance as
e^-(d/r)^2:

- **Pressure:** minus the depth at a low's heart, plus it at a high's.
- **Temperature:** round a low, up to 2 C warmer ahead of it (downwind) and up
  to 4 C colder behind its cold front (upwind). Highs add none.

## Storms

The season roll (`change_weather_somehow()` and the map policy) still decides
how often a storm comes. A wet or extreme result now calls
`weather_front_storm()`: the storm is aimed at a point on the deepest low's
front, 0.4 radii ahead of its heart and up to half a radius to either side of
its course. With no low about, a low forms and brings the storm. A low 25 hPa
deep or more makes a storm severe 30% of the time.

**Heat waves:** in summer or the dry season, a fully grown high at least
15 hPa deep has a 1% chance each tick of stalling into a heat wave over its
heart, when no heat wave exists. The old summer roll and admin heat waves
still work.

**Thunderstorms:** at Midday and in the Afternoon, with fewer storms than the
map holds, there is a 3% chance each tick that the warmest land cell at 24 C or
more, at least 65% humidity and under half cloud throws up a storm in place.
It is 18 to 32 tiles across, lasts 10 to 20 minutes and is at full strength,
so heavy rain and lightning reach its core. It is severe when the cell is
30 C or more with a dew point of 20 C or more. The map policy must allow wet
weather.

## Admin tools

The Admin Map draws each low as a red **L** and each high as a blue **H**,
with a dashed ring at its radius and its current depth in hPa.

## Tests

```sh
python3 tests/ecology_spawning/run_linux.py . tests/weather_fronts/probe.dm
```
