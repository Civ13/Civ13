# Agent boats fixture

```bash
source <BYOND>/bin/byondsetup
python3 tests/agent_boats/run.py --byond-bin <BYOND>/bin
```

The runner compiles the production sources with maps and ordinary start-up
removed, then runs `probe.dm` on a 40 x 40 outdoor level with a river (one
shallow column, four deep ones) using the pinned BYOND build. It needs every
assertion to pass and no runtime errors.

Covered: deep and shallow water classes; `character_route` needing a boat with
the launch, landing and walk/boat/walk legs, the raft recipe, and walking a
bridge instead when one exists; a goal off the map clamped to its edge; an
agent character boarding a raft, steering it five tiles across, being refused
onto land, disembarking, stepping ashore and the moored raft being offered for
the way back; nearby boats in `character_observe`; boarding twice refused; a
motor boat's stall reasons (no fuel, engine off) and its fuel and cargo row;
dragging a crate onto a boat's deck, and refusing a drag out of reach.

Not covered: sail and engine-in-gear movement loops, wind, and boats crossing
map areas that block rafts (the Caribbean sea).
