# Expedition slots

Boat expeditions ([plan](https://claude.ai/artifact/61LciJHKi6eKEUsYMfFgwE))
send crews to lands generated from the world chart ([world chart](world-chart.md),
[expedition lands](expedition-lands.md)). A land runs in an **expedition slot**:
a region of kind `EXPEDITION` in the group config that holds one land at a time.
A ship's course opens a land in a free slot by itself (below); the host
operator can also give a slot a land by hand.

## The group config

```json
{ "id": "far1", "name": "Far Land 1", "kind": "EXPEDITION", "port": 1811,
  "transfer_port": 1831, "map": "maps/expedition/slot.dmm" }
```

`map` is the placeholder a free slot compiles: open sea over bedrock, 32 x 32.
A slot cannot be the mainland or the relay gate, and no region may be called
`expeditions` (the slots keep their lands in that folder of the group root).
The plan proposes four slots, `far1` to `far4`; the group limit is 32 regions.

### Adding slots to a running group

1. Add the slots to the group config (`far1` to `far4`: ports 1811-1814,
   transfer ports 1831-1834; each standby port defaults to its port + 10).
   Check `status` first: the group takes at most 32 regions.
2. `setup.bat far1` (and so on) for each: it checks out and compiles the
   placeholder and enrols the slot's agent while the other worlds keep running.
   Do not start the slots: a free slot stays stopped until a ship needs it.
3. Open the slots' ports to players as for the other regions.
4. Within a minute the host service restarts the coordinator with the slots
   (`coordinator.json` keeps the slot list it was started with).
5. Check: `expedition-status` lists each slot `FREE`. In game, a ship off the
   mainland's edge offers **Set out on a voyage**.

## A slot's life

| State | Meaning |
| --- | --- |
| `FREE` | no land; it compiles the placeholder map |
| `LAND` | it holds a land; its next update compiles that land |

1. **Give it a land** (the slot stopped, free, and with no saved world):
   `shard_group.py --config group.json expedition-land --region far1 --template tile.json --key 24,16`.
   The template is a world-chart template, or a tile as the chart prints it
   (`{"template": {...}}`). The land is generated into
   `<root>/expeditions/lands/far1-<time>/` (about 4 s for a tiny land and 7 s
   for a small one in the cloud).
2. **Compile it**: `update-offline --region far1`. The region's map becomes
   `maps/regions/far1.dmm` (a copy of the land), and the host writes
   `config/expedition_land.json` for the world: biome, land type, size, seed and
   the ore kinds, rare finds and game animals the slot world will place.
   It also copies the land's hill, current and flood files to
   `config/expedition_heights.txt`, `.flow.txt` and `.flood.txt`; a free slot's
   update removes them.
3. **Start it** as any region. The world's map is **A New Land (tiny desert
   coastal plain)**; it starts its round on its own and saves like any land.
4. **Archive it** when the land is abandoned (the slot stopped):
   `expedition-archive --region far1` moves `map_saves`, `map_backups`,
   `map_rollback` and a cold record to `<root>/expeditions/archive/far1-<time>/`
   with the slot record, and frees the slot. Update it again before starting it,
   so it compiles the placeholder.

`expedition-status` lists every slot's state, land, phase and any land waiting
for it. Each
slot's record is `<root>/expeditions/slots/<id>.json` and keeps its last 50
events.

## Lands opened for ships

When a ship sets course for a land that has no world yet
([voyages](ship-voyage.md)), the coordinator picks a free slot (no chart tile
names it, its record is `FREE`, nothing waits or failed in it), marks the tile
`LANDED` in that slot and writes `<root>/expeditions/wanted/<slot>.json` with the
tile and its template. The host service's half-minute pass (`supervise`) does
the rest by itself:

1. A free slot running its placeholder is stopped first.
2. A detached worker (`expedition-open --region <slot>`, log in
   `<root>/expeditions/open-<slot>.log`) gives the slot the land, records phase
   `building` and starts `update-offline` for it. Giving a land (and archiving)
   forgets the slot's build record, so the land compiles even at the revision
   the slot already runs.
3. Once the build is installed the pass starts the slot and records phase
   `started`. The coordinator then marks the ship's course `READY`; an idle land
   goes to sleep and wakes when the ship arrives.

### An empty land sleeps on disk

Other regions sleep frozen in memory, to wake in a moment. A land across the
sea is visited seldom, so its host config gets `freeze_cold: true`
(`region_config`): after the idle wait (`freeze_idle_minutes`, 15) with nobody
there and a save newer than the last player, the world is frozen and at once
shut down to its save (`Host.evict`, state `cold`). It costs no memory until a
ship or a returning player wakes it, which starts it from that save (about a
minute for a tiny land; a ship waits off the coast meanwhile). A land nobody
ever played on has no save to start from and stays frozen. Set `freeze_cold`
in the group config to choose for every region alike (`false` keeps lands
frozen in memory).

A land that cannot be opened (the build failed or took over three hours, or the
slot already holds another land) is archived and reported in
`<root>/expeditions/failed/<slot>.json`; the coordinator refuses the waiting
courses, frees the tile (its template stays) and deletes the report. The
coordinator learns the slots and this folder from `--slots` and
`--expeditions`, which `ensure_coordinator` passes when the group has slots.

An abandoned land (by its crew, or after 7 days with nobody there) is
reported in `<root>/expeditions/abandon/<slot>.json`: the pass stops the slot
(it saves first), archives it and frees it. The coordinator has already moved
any home there to the mainland. See [voyages](ship-voyage.md#settle-claim-or-abandon).

An archived save is kept 7 days so an admin can restore it by hand. After
that the host service deletes it, with the land folder it was built from
unless a slot holds that land again (`prune_archives`, each `serve` pass).

## Parked lands

A slot is only needed while a land is awake. When a crew needs a slot and none
is free, the coordinator asks for the land that has stood empty longest to be
parked (`<root>/expeditions/park/<slot>.json`, [chart](world-chart.md#parked-lands)).
The host service's pass:

1. Somebody is there after all: the wish is dropped and the land stays.
2. Otherwise the slot is stopped (it saves first; one asleep on disk is
   stopped already), and `park` moves `map_saves`, `map_backups` and
   `map_rollback` to `<root>/expeditions/parked/<x>-<y>/` with `slot.json` (the
   land folder, map and world summary) and frees the slot.

A wanted land marked `parked` is not generated: `restore` moves the save back
into whichever slot is free, gives the slot record the land again with a new
`placed` stamp, and the land compiles and starts as any other. A restore that
cannot be built parks the land again and reports it `parked` in
`failed/<slot>.json`; a parked land is never archived for a failed build and
never pruned. `expedition-status` lists the parked lands.

Only the coordinator gives a parked land up (an undecided one, 7 days after
anyone was last there): `<root>/expeditions/discard/<x>-<y>.json` moves its
folder to the archive, to be pruned after 7 days like any archived land.

### One land after another in a slot's transfer agent

A slot's transfer agent keeps a ledger that follows the world's saves, and
holds the region when a loaded save is older than it (a rollback). A slot's
next land is another world with its own save history, so the slot world sends
`world` with its load report: the land's chart tile and its `placed` stamp
(`config/expedition_land.json`, set when a land is given or restored). The
agent adopts a world other than the last one it reconciled
(`RegionStore.reconcile_load`); the same placement loading an older save is
still held.

## In game

- The Regions panel calls a slot "land across the sea" and has no Join link for it.
- Trails never lead to a slot; a trail set to one says only a ship can reach it.

## Not done yet

- Placing the template's ore kinds, rare finds and game in the slot world.

Tests: `python3 -B tests/gaia_host/test_expedition_slots.py`.
