# Constructed boat movement regressions

Player-built hulls use `/obj/structure/vehicleparts/axis/ship`, ship frames, a ship wheel and the modular vehicle rotation code. The separate legacy small-boat controllers and train movement are not replaced here.

## Confirmed baseline failures

Against master `0d38999d5f9f987a944493f11c456537f39ac2f6` on Windows with BYOND 516.1681, the fixture completes with 15 failed assertions. It confirms:

- A 2x3 hull acquires placeholders across the full 5x5 assembler range rather than its 3x3 turning square.
- Rotation includes off-deck objects and destroys onboard cargo and the helm because its carried-object list is stale.
- Shoreline and foreign-frame turns proceed; earlier scenery can be deleted before a later blocking destination is found.
- Map-edge movement/rotation changes some parts while losing others into null.
- An injected movement callback during a turn splits the hull. This is an isolated callback reproduction, not a claim that a particular production callback caused the report.

The patch retains the existing square pivot, quarter-turn tables, supported size limit and collision/crushing rules. Boat rotation snapshots contain deck occupants and owned parts. All destinations are checked before obstacle deletion or movement, hull destinations must be navigable water, and nested boat transforms are rejected. Assembly and existing boats discard only surplus owned invisible placeholders. The helm propagates rejection and foreign frames do not become cargo.

## Run

PowerShell 7 is required. Supply the exact BYOND compiler/runtime used by the build:

```powershell
./tests/boat_movement/run.ps1 -ByondBin '<BYOND-bin>'
./tests/boat_movement/run.ps1 -ByondBin '<BYOND-bin>' -Revision 0d38999d5f9f987a944493f11c456537f39ac2f6 -Baseline
```

`-Revision` extracts production procedures from that revision; fixture and adapters come from this checkout. The default reads working files. The runner compiles a temporary 40x40x1 water world, starts only its own daemon with `-safe`, and bounds it to 15 wall seconds, 5 CPU seconds and 256 MiB. It verifies completion, process exit and runtime/assertion failures; logs remain at the printed temporary path. It never reads a production map or save. Linux CI reuses the existing pinned BYOND installation after the full-game compile.

The 168 passing patch assertions cover production assembly and wheel steering, 2x2/2x3/5x5 hulls, eight quarter turns in each direction, every heading reached through actual turns, forward/reverse displacement, passengers/cargo/mast/helm/cannon, independent cannon aim, shore/solid obstacles/foreign frames, failed-turn atomicity, map edges, reentrant movement, cargo deletion during callbacks, existing-placeholder normalization, unsupported oversized-turn rejection, ordinary shared vehicle rotation and movement-loop shutdown.

Adapters provide no-op icon/audio/chat effects, a fixed adequate engine/weight check, empty faction block rules and isolated movement callbacks. Propulsion/fuel/wind balance, arbitrary irregular hulls, full-game Crossed/Entered behavior, graphical overlays and live-server behavior are not established by this fixture. The full-game compile uses `civ13.dme` and its configured `maps/nomads/nomads.dmm`; the fixture uses its generated world rather than that map.

## Safe gameplay replication and capture

Use an isolated game built from the PR head, with no production storage or service configuration. Record the exact commit, BYOND version and map with captures.

1. Build six wooden ship frames in a 2x3 rectangle, facing NORTH, on open water. Put the ship rudder in the northwest frame, a mast/sail and ship wheel on frames, then assemble. Verify the helm remains attached.
2. Put a passenger on the northwest frame, a loose cargo item and a cannon on deck. Put a separate item at the southeast corner of the 3x3 turning square, outside the 2x3 deck. That corner stays outside the hull after a right turn.
3. Lift the anchor, enable valid propulsion and turn right while moving. Repeat four turns and then four left turns. The passenger, cargo and fixture must remain with the hull; the outside item must stay on its original water tile, and a full rotation must preserve relative positions and cannon aim.
4. Repeat with 2x2 and 5x5 hulls, every heading and reverse. Observe movement as well as stationary positions after each quarter turn.
5. Place shore/ice or another vehicle frame under a proposed hull destination. Attempt the turn: no heading, hull, passenger, cargo or obstacle should change. Repeat near a map edge. Place a destructible item in an earlier destination and a solid cover in a later destination to verify rejection does not first delete scenery.
6. Stop movement and remove a cargo item, then resume and turn again. Verify no stale reference or missing hull part. Compare the separate automated callback/edge cases in the fixture log; ordinary gameplay cannot directly invoke its injected callbacks.

Capture genuine before/after screenshots of membership and rejected turns, plus video of repeated movement/quarter turns/full rotations. Fixture output and compilation are not substitutes for this full-game evidence. Generated media belongs in verified PR attachments, not in Git.
