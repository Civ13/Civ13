# Small boat upkeep

Code: `code/modules/naval/small_boat_upkeep.dm`. Probe: `python3 tests/ecology_spawning/run_linux.py . tests/dugout_canoe/probe.dm`
(`canoe_upkeep_checks`). Constants are in `code/__defines/naval.dm` (`BOAT_*`).

Wear comes only from `boat_wear()`, called for every tile a raft-type boat makes under her own
crew (`raft/do_move` in small_craft_leaks.dm). A boat left alone never changes; this is the rule
big hulls already follow. Fresh water adds 0.05 a tile, salt water 0.1, on a 0 to 100 scale. All of
it is saved except the drying clock.

| What | Who | Effect | Cure |
| --- | --- | --- | --- |
| `lash_wear` | Raft, outrigger canoe | 50: 2 slower a tile. 75: ships water like a damaged boat (30 in 100 a tile). Never worse | 1 rope used on her, empty and out of deep water |
| `soak` | Dugout canoe, outrigger canoe | 50: 1 slower a tile. 80: 3 slower | Dries 10 a minute ashore. Animal fat or tarred oakum used on her ashore dries her at once |
| `dressing` | The same | 600 tiles of half-rate soaking after a dressing | - |
| `sail_torn` | Outrigger canoe with her sail set | Wind 3: 2 in 100 a tile, gale: 6 in 100. A torn sail drives nothing | 2 cloth or wool cloth used on her. Furled, a sail never tears |

- A raft is crafted in one step and starts at `BOAT_RAFT_NEW_WEAR` (40): she is bound with bark
  and vines until someone re-lashes her with rope. The recipe is unchanged so that nomad parties
  and the autopilot (`tools/agent-control/boats.py`) still build rafts from wood alone.
- Drying: `came_ashore()` and `took_water()` are called from the hauling `Move()` when a boat
  crosses the waterline. `ashore_since` is a `tmp` world.time stamp, so a load restarts the clock.
  `dry_out()` is applied on a look and on launching.
- A torn sail has to be mended before the mast is struck.
- `upkeep_text()` adds her state to a look.
