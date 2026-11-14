# Expedition slots

Boat expeditions ([plan](https://claude.ai/artifact/61LciJHKi6eKEUsYMfFgwE))
send crews to lands generated from the world chart ([world chart](world-chart.md),
[expedition lands](expedition-lands.md)). A land runs in an **expedition slot**:
a region of kind `EXPEDITION` in the group config that holds one land at a time.
No ship sails to a slot yet; for now the host operator gives slots their lands.

## The group config

```json
{ "id": "far1", "name": "Far Land 1", "kind": "EXPEDITION", "port": 1751,
  "transfer_port": 1851, "map": "maps/expedition/slot.dmm" }
```

`map` is the placeholder a free slot compiles: open sea over bedrock, 32 x 32.
A slot cannot be the mainland or the relay gate, and no region may be called
`expeditions` (the slots keep their lands in that folder of the group root).
The plan proposes four slots, `far1` to `far4`; the group limit is 16 regions.

## A slot's life

| State | Meaning |
| --- | --- |
| `FREE` | no land; it compiles the placeholder map |
| `LAND` | it holds a land; its next update compiles that land |

1. **Give it a land** (the slot stopped, free, and with no saved world):
   `shard_group.py --config group.json expedition-land --region far1 --template tile.json --key 24,16`.
   The template is a world-chart template, or a tile as the chart prints it
   (`{"template": {...}}`). The land is generated into
   `<root>/expeditions/lands/far1-<time>/` (about 11 s for a tiny land and 29 s
   for a small one in the cloud).
2. **Compile it**: `update-offline --region far1`. The region's map becomes
   `maps/regions/far1.dmm` (a copy of the land), and the host writes
   `config/expedition_land.json` for the world: biome, land type, size, seed and
   the ore kinds, rare finds and game animals the slot world will place.
3. **Start it** as any region. The world's map is **A New Land (tiny desert
   coastal plain)**; it starts its round on its own and saves like any land.
4. **Archive it** when the land is abandoned (the slot stopped):
   `expedition-archive --region far1` moves `map_saves`, `map_backups`,
   `map_rollback` and a cold record to `<root>/expeditions/archive/far1-<time>/`
   with the slot record, and frees the slot. Update it again before starting it,
   so it compiles the placeholder.

`expedition-status` lists every slot's state, land and when it got it. Each
slot's record is `<root>/expeditions/slots/<id>.json` and keeps its last 50
events.

## In game

- The Regions panel calls a slot "land across the sea" and has no Join link for it.
- Trails never lead to a slot; a trail set to one says only a ship can reach it.

## Not done yet

- The voyage over the world chart and the coordinator asking the host for a
  land (later steps of the plan). Ships already cross to a slot that holds a
  land and back ([ship crossing](ship-crossing.md)).
- Placing the template's ore kinds, rare finds and game in the slot world.
- What happens to characters still homed in a slot when it is archived
  (settle, claim and abandon step).

Tests: `python3 -B tests/gaia_host/test_expedition_slots.py`.
