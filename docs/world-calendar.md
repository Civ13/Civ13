# World calendar

Code: `code/modules/1713/world_calendar.dm`. Probe: `tests/world_calendar/probe.dm`
(run with `python3 tests/ecology_spawning/run_linux.py . tests/world_calendar/probe.dm`).

Every region runs as its own DreamDaemon world. Each world used to keep its own day
cycle and season timer, counted from its own boot and save, so neighbouring regions
drifted apart and southern regions had summer at the same time as the north. Maps that
set `world_longitude` now read the time of day and the season from the real clock
(UTC), so every region agrees and stays in step through restarts and handovers. No
messages pass between servers.

## Time of day

- A game day is 2 real hours: six phases of 20 real minutes, 4 game hours each
  (Early Morning 03-07, Morning 07-11, Midday 11-15, Afternoon 15-19, Evening 19-23,
  Night 23-03). Real midnight UTC is game midnight at longitude 0.
- Each region is moved by its time zone, `round(world_longitude / 15)` hours, so Asia
  is ahead of Europe and the Americas are behind.
- The time of day process (`code/processes/time_of_day.dm`) calls
  `world_calendar_tick()` every 10 s. On a synced map it sets `game_hour` (game minutes
  into the phase) and `TOD_ticks` from the calendar and opens the change gate when the
  world shows another phase; `progress_time_of_day()` then jumps straight to the
  calendar's phase.
- `pick_TOD()`, the round start and `restore_durable_world()` (through
  `world_calendar_restore()`) take the calendar's phase, so a restored world never shows
  its saved phase.
- The calendar is off when day/night is off, when the map has `no_time_of_day_cycle`,
  or when its `times_of_day` is not the standard six phases.

`world.realtime` is a 32-bit float, too coarse for minutes, so the clock takes the time
of day from `world.timeofday` moved to UTC with `world.timezone`, and uses `realtime`
only to pick the day.

## Seasons

- Each season lasts `config.season_duration_minutes` (60 by default; keep it the same on
  every region). The northern order is spring, summer, fall, winter, starting a spring
  at UTC midnight on the calendar's start day. Maps with `sun_latitude` below 0 have the
  opposite season. Tropical areas already read winter as the wet season and summer as
  the dry season by their area climate.
- The world keeps its own season transitions (terrain, water, plants, debris decay). The
  calendar only decides when they run: `world_calendar_season_due()` is TRUE when the
  calendar's season differs from the world's, and the tick or the season loop then
  queues one ordinary transition. A world that was down for a while steps through the
  missed seasons one at a time.
- `season_loop_delay()` wakes the loop at the calendar's next season, and
  `season_change_window()` returns the calendar's season window, so the status panel and
  `climate_season_fraction()` follow it.
- Maps with their own `season_cycle`, and the custom Nomads calendars (Mountain, Ice
  Age), stay off the calendar.

## Admin tools

"Change Time of Day" and "Change the Season" still work on a synced map. The change
holds until the calendar's next phase or season, then the world resyncs. "Toggle Time of
Day" and "Toggle Season Change" turn the calendar off for that world as before.

## Regions

| Region | Longitude | Zone | Latitude |
| --- | --- | --- | --- |
| Gaia | 30 W | UTC-2 | 45 N |
| Europe | 10 E | UTC+1 | 50 N |
| Africa | 20 E | UTC+1 | 5 N |
| Asia | 90 E | UTC+6 | 40 N |
| Oceania | 135 E | UTC+9 | 25 S |
| Greenland | 40 W | UTC-3 | 72 N |
| Antarctica | 0 | UTC+0 | 78 S |
| North America | 100 W | UTC-7 | 35 N |
| South America | 60 W | UTC-4 | 20 S |
| Atlantic Ocean | 30 W | UTC-2 | 30 N |
| Pacific Ocean | 165 W | UTC-11 | 15 N |
| Indian Ocean | 75 E | UTC+5 | 15 S |
| Arctic Ocean | 0 | UTC+0 | 78 N |
| Southern Ocean | 0 | UTC+0 | 60 S |

A new region sets `world_longitude` next to its `sun_latitude` in its map metadata and
gets added to the probe's region list. TDM round maps and other maps without a longitude
keep their own clock.

The agent control status (`agent_actions.dm`) reports `calendar`, from
`world_calendar_summary()`.
