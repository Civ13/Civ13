# Severe gusts and land tornadoes

This first pass builds on the air grid, local wind and moving storms described
in [weather-wind.md](weather-wind.md) and [weather-fronts.md](weather-fronts.md).
It does not change the rate of ordinary storms.

## What produces a tornado

- A Persistence map must allow extreme weather. Only a mature, severe
  **convective** storm over land can parent a tornado. Heavy snow, dust
  storms and pinned zone weather do not directly create one.
- Its projected touchdown needs a heavy storm band, at least 24 °C and a dew
  point of at least 16 °C. The surface wind must have at least 3 m/s across
  the storm's track and differ from estimated steering flow by at least
  12 m/s. The existing air grid has no upper-air column, so this is a
  **low-level shear proxy**, not a numerical atmosphere model.
- After three consecutive qualifying weather samples (10-second ticks), the
  parent has a 3% chance per qualifying tick. A parent forms at most one,
  the map holds at most one, and another cannot form for 30 minutes. The
  first pass does not spawn waterspouts.
- A 45-second lead gives players near the projected touchdown time to move.
  The track travels with the parent storm's heading and speed, and the
  warning follows a corridor, not the whole map. The vortex lasts up to
  105 seconds after touchdown; it dissipates on leaving land, losing its
  parent, weakening weather, or a persistence hold. Nothing about a
  tornado or its timers is saved or replayed after restart.

The game rule is inspired by warm, humid inflow and the rotating updraft
in severe thunderstorms. Real tornadoes are not predicted by these fixed
thresholds; see [NOAA's tornado overview](https://www.noaa.gov/education/resource-collections/weather-atmosphere/tornadoes).

## What players experience

- An exposed land tile in a severe convective storm gets a pulsing directional
  gust. Wind instruments read the effective wind, while background advection
  and the air model keep reading the undisturbed grid. Under a live funnel,
  local wind includes rotating flow and inflow rather than merely becoming
  a stronger version of the background wind.
- Once the funnel is on the ground, a local dust/gust marker reuses an
  existing Civ13 asset. Strong gusts can push and knock down an exposed
  character or displace small loose items by one tile. No forced teleports,
  projectiles or vehicle damage. Terrain collision still applies; water,
  open floors and shafts are not valid push destinations.
- The tight core can kill exposed crops and scuff thatch or palm roofs.
  The damage is repairable; the tornado cannot collapse those roofs.
  An enclosed solid shelter with a roof or a proper underground level
  protects occupants. Open doors, glass and an unsupported or fragile
  covering are not treated as solid shelter. Effects are bounded per pulse
  and target, and do not modify a world while saves or loads hold it.

## Verification

The existing weather-fronts fixture includes deterministic tornadogenesis,
warning geometry, shelter, movement, crop/roof damage and cleanup:

    python3 tests/ecology_spawning/run_linux.py . tests/weather_fronts/probe.dm 300

Visual clarity and frequency still need live balance review.
