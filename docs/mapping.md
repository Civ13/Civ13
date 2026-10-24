# Civ13 mapping checklist

Start with the [Civ13-specific mapping guide](https://civ13.github.io/civ13-wiki/developers/Mapping.html)
for the full workflow and troubleshooting. This checklist is for contributors
reviewing an authored map, not authorization to change a running server. Use the
official [BYOND Guide](https://www.byond.com/docs/guide/) and
[DM Reference](https://www.byond.com/docs/ref/) for editor and language basics.

## Plan and register

- Record the donor map, exact game commit, intended mode/factions, era/research
  rules, grid dimensions, and whether the change targets a fresh or saved world.
- Work in an isolated checkout. Follow [map naming and z-size conventions](../maps/README.txt);
  preserve originals in Git and place WIP maps in the WIP folder.
- Review the `.dmm`, placed metadata subtype, ID in
  [`maps.dm`](../code/__defines/maps.dm), metadata DM include and selected DMM
  include in [`civ13.dme`](../civ13.dme) together. Rotation policy in
  [`mapswap.dm`](../code/processes/mapswap.dm) is a separate maintainer decision.
- For example, `maps/nomads/nomads_europe.dmm` uses
  [`/obj/map_metadata/nomads/europe`](../code/game/objects/map_metadata/nomads/nomads_europe.dm),
  which inherits Nomads rules and enables research. Map IDs have consumers beyond
  their title. Avoid stray metadata objects: their initialization assigns `map`.
- Check DMM key lengths, row widths, defined keys, coordinate blocks and placed
  object overrides. A new file alone does not register a playable mode.

## Areas, roofs and travel

- Trace area inheritance in [`areas.dm`](../code/game/area/areas.dm) and
  [`caribbean.dm`](../code/game/area/caribbean.dm). Every turf has one native area;
  biome, nation and room are not independent native layers.
- Check native location/climate plus map season/weather policies separately.
  Mountain uses indoor cave areas and Wet/Dry seasons; it does not provide altitude.
- Inspect the exact ladder/transfer subtype in
  [`multiz`](../code/modules/multiz/structures.dm). Generic helpers use a connection
  bitmask; the `map_data.height` initializer is commented out in
  [`helpers.dm`](../code/modules/multiz/helpers.dm). The `ww2` ladder family pairs by
  assigned IDs using `area_id` and enumeration order. Another z-level alone is not
  a working route. Review both ends and the return path.
- Check the roof's area change and restoration in
  [`roof_stuff.dm`](../code/game/objects/roof_stuff.dm), then any upper-floor
  coordinate/pair contract in [`building_levels.dm`](../code/game/objects/building_levels.dm).
  Read the [world-grid budget](new-z-budget.md): a new plane covers the full grid,
  and production growth is refused while unmeasured. Shelter and a new upper floor
  are separate outcomes.

## Spawns, resources and persistence

- Trace every lobby, job/faction, latejoin, squad or supply route through its actual
  lookup. [`Landmarks`](../code/game/objects/effects/landmarks/normal.dm) treat
  `start`, `JoinLate`, `Paradrop` and ordinary names differently. For Nomads, trace
  `JoinLateCiv` from [jobs](../code/modules/1713/jobs/nomads.dm) through
  [relocation](../code/game/jobs/job_controller.dm). Check exact case and clear
  destinations; an area label does not create a spawn or delivery registry.
- Author initial persistence arrivals on safe, walkable ground at the playable map
  boundary whenever possible. If the edge is water or blocked, choose the nearest
  suitable ground fallback. Identify the surface from the authored layout, not
  `z = 1` or the maximum z-level. This is an authoring rule; automatic enforcement
  is not implemented. Default-arrival changes must preserve existing saved character
  locations and durable custom arrivals.
- Review a reachable water/food/tool/shelter/progression chain for each start and
  faction. The [outdoor bootstrap trace](outdoor-crop-bootstrap.md) and
  [`check-outdoor-bootstrap.py`](../scripts/check-outdoor-bootstrap.py) help with
  six named outdoor maps. Static placed-resource counts do not establish a route,
  research access, season suitability or playability. Do not publish protected
  resource/spawn coordinates.
- A source map edit does not migrate an existing world. The
  [loader](../code/modules/persistence/loading.dm) checks identity/dimensions and
  restores saved terrain. Keep the original generation and record an explicit
  fresh-world or migration plan. Consult the [zone persistence audit](zone-persistence-audit.md)
  for supported roof-area reconstruction and remaining reference limits. Verify
  fresh joins after restore separately from restored players.

## Review and acceptance

Offline review can establish source paths, inheritance, registration, placed keys,
grid structure and documentation links. It cannot establish native rendering,
movement, progression or save/load acceptance. Document the distinction in the PR.

When separately authorized, native validation must use a disposable environment
and exact source/map revisions: fresh spawns, both travel directions, roof lifecycle,
weather/lighting, resource progression and persistence restore. Preserve saves;
never delete them or alter live configuration to make a test pass. Follow the
[save/restart procedure](world-save-restart.md) for separately authorized operations.

`launch_map`/`select_map` edit selection, compile and launch. Map-swap scripts can
perform production operations. None is a read-only documentation check.

Elevation, logical geography, durable zone/spawn-registry changes, seasonal generated
snow, saved-world export and sharded travel require their own accepted implementation
and version prerequisites. This checklist supplies no pending API or automatic
save-to-compiled-map workflow. Keep proposals out of required map dependencies.

Future configurable default arrival routes are planned to use immigration as their
lore framing; this does not describe an existing automatic relocation feature.
