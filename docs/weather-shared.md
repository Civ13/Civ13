# Shared weather across regions

Code: `code/modules/1713/weather_shared.dm`. Probe: `tests/weather_shared/probe.dm`
(run with `python3 tests/ecology_spawning/run_linux.py . tests/weather_shared/probe.dm`).

Each region runs as its own world. Each world used to roll its own lows, highs and storms
([weather-fronts.md](weather-fronts.md), [weather-systems.md](weather-systems.md)), so a
storm at a map edge simply vanished and the next region knew nothing of it. Region maps
on the [world calendar](world-calendar.md) that also set `world_region` now share them,
with no messages between servers:

- **The seed.** A region's lows, highs and storms for each 5-minute calendar slot come
  from `md5` of the region id and the slot, so every world works out the same systems.
  A slot brings a low or high 45% of the time, a low more often in winter and less often
  in summer. Each storm place (one per 40,000 tiles, up to six) brings a storm at 21% of
  the season's wet share: 2/3 in winter and spring, with half of those severe, and 1/2
  in summer and fall. On a large map that comes to about one storm every eight minutes,
  much as before. A storm forms on the front of the region's deepest low, or anywhere if
  there is none. Sizes, depths and lifetimes keep the old ranges.
- **Courses.** Systems drift with the prevailing winds of their latitude: east between
  30 and 60 degrees, west in the tropics and near the poles, 40 degrees either way. They
  keep that course rather than turning with the local wind, so every world draws the same
  path. Centres drift at 0.6 times the storm speed, as before.
- **Edges.** A world takes its own systems and, for every neighbour across an edge in
  `world_links` or `world_sea_links`, the neighbour's systems near that edge. They are
  carried over the edge to the matching stretch of this map, scaled to it, with their
  course kept. A storm heading for the edge rolls on into the next region at the same
  moment and the same age.
- **Islands.** A land inside an ocean (`world_insets`: Gaia and Greenland in the Atlantic)
  takes the ocean's lows and highs, scaled from the inset box to the island, and keeps
  its own rolled storms, because one ocean storm would cover the whole island.
- **What stays local.** Afternoon thunderstorms (`weather_convection_step`), heat waves
  from highs and admin-triggered systems still form in each world. On a world with shared
  storms, `weather_roll()` sends no storm of its own.

`weather_centres_step()` calls `weather_shared_sync()` on a shared map. That keeps the
five strongest lows and highs in `weather_centres` and the shared storms in
`weather_systems` (tagged with `shared_key`, not turned by `weather_systems_step()`). A
storm broken up locally (`weather_disperse`) keeps its shorter life. A map whose
`valid_weather_types` has no wet weather gets no shared centres or storms.

Region frames (`weather_region_frames`): each land's map size and latitude, plus each
ocean's. Update the row when a region's map changes size.
