# The hull ledger

Every hull the players built and commissioned on the water keeps one record of
her condition (`code/modules/naval/hull_ledger.dm`, `/datum/hull_ledger` on
`/datum/craft`). It is plain numbers, like a submarine's air ledger: no water
lies on any tile. Airships and turf-built vessels have none.

## Size classes

| Class | Tiles of hull | Seams |
| --- | --- | --- |
| Small craft | up to 12 | never seep |
| Boat | 13 to 40 | seep when built of wood |
| Ship | 41 and up | seep when built of wood |

A plank of steel, iron or aluminium lets nothing through; a tile counts as wood
unless one of those lies on it. The class and the count are surveyed when she is
commissioned, refitted and loaded.

## Bilge water

- She holds 4 bucketfuls a tile and is awash at half of that. Seams and patches
  never fill her past awash; only holes do.
- A wooden boat or ship takes 0.045 bucketfuls a tile a minute under way and
  half that lying still: left alone she is awash in about 45 minutes, and half an
  hour's seepage is two minutes' bailing for one person.
- She only changes while she is awake: under way, or with a living player on
  her deck. A moored or anchored hull with nobody aboard keeps what she has.
- Past a damp bilge (a tenth full) the water weighs on her drives as more tiles
  of hull (`craft.mass()`), so a sail that made half ahead may only make slow.
- The tiller reads the depth: dry, damp, ankle deep, knee deep, awash. The crew
  is told once as each of the last three is reached.

## Bailing

Stand on her deck and use an empty bucket on one of her planks. Each bucketful
takes three seconds; the bailer carries on until the bilge is dry, they move or
they put the bucket away. A step of the hull does not stop them.

## Holes, patches and foundering

- A tile of her hull with no floor left is a hole, whatever her class or
  planking: shot away, blown out, cut out by her crew, or broken by a reef or
  storm strike on a plank already battered to a quarter of its health
  (`hazard_damage`). Walls aboard do not count. The ledger hears of it from
  `/obj/covers/Destroy()`.
- Each open hole lets in 25 bucketfuls a minute while she is awake, up to the
  brim. One bailer manages 20.
- Three quarters full she lists: slow ahead at best (`craft.max_speed()`).
- A patch: from her deck beside the hole, hammer in the other hand, use wood (2
  pieces, 6 seconds) on the open water of the hole. It lays
  `/obj/covers/repairedfloor/ship/patch`, which weeps 1 bucketful a minute.
- A holed hull cannot be refitted, or the survey would drop the tile.
- Full over mostly deep water she founders. Every 30 seconds the crew is warned;
  after four she goes down unless the water is back under 98%. The tiller is
  struck, floors, structures and machinery on her tiles are deleted, and mobs,
  items and closets are left on the water. The sinking is logged and admins are
  told.
- Full over mostly shallow water she is grounded: no speed, no turn. She floats
  again when no hole is open and she is bailed below awash.

## Seams and caulking

`code/modules/naval/hull_caulking.dm`. The ledger carries `seams`, the wear of
her caulking from 0 (tight) to 1 (open). A hull starts sound at one third,
where she seeps at the plain rate; the rate is times `0.5 + 1.5 * seams`, so
tight seams seep half and open seams twice. Only time under way wears them:
four hours take her from tight to open. Her crew is told when they work loose
(0.6) and when they are open (0.9), and the tiller names their state.

- Tarred oakum (`/obj/item/stack/tarred_oakum`): rope used on an open container
  holding pitch from a tar kiln. One coil and ten units make three twists.
- Caulking: oakum used on one of her planks from her own deck, a chisel or a
  hammer in the other hand, while she lies still and is not awash. One twist
  takes four seconds and tightens three tiles of hull.
- On deep water caulking stops at sound (one third). Lying mostly over shallow
  water she is caulked down to tight.
- Small craft and plated hulls have no seams: nothing wears and nothing can be
  caulked. `seams` is saved with the rest of the ledger.

## Bilge pumps

`code/modules/naval/hull_pumps.dm`. The cellar pumps of
`code/modules/1713/flood_pumps.dm` pump the bilge of the hull whose deck they
stand on (`hull_ledger_at()`, either deck). Ashore they are unchanged.

| Pump | Aboard a hull |
| --- | --- |
| Lever pump | worked by hand: two bucketfuls a three-second stroke, until dry |
| Steam mine pump | 80 bucketfuls a minute while on and fuelled |
| Sump pump | 40 a minute on cable power or battery, only while there is water |

`step_ledger()` calls `pump_bilge()` after the water comes in, so powered pumps
run, and burn fuel or battery, only while the hull is awake. Their own
`cellar_minute()` runs only on a flood cellar level and never aboard. The
tiller counts the pumps on her deck.

## Load and ballast

`code/modules/naval/hull_load.dm`. Everything on the deck of a boat or ship has
a weight in tiles of hull (`/atom/movable/proc/hull_load()`): a person 0.2, a
dense structure 0.5, a crate 0.5 plus its contents, a cannon 1.5, an engine 1,
a mast 0.5, a wall built aboard 0.3, an item 0.02 (0.1 if large), a stack 0.02
a piece. `fit_drives()` adds it up in the deck walk it already makes before
every hop; a hull lying still is counted in her ledger step and when the tiller
is read.

- Burden: half a tile of weight a tile of hull, carried for nothing.
- Deep laden, past her burden: each tile over it is one more tile in `mass()`.
- Overladen, past twice her burden: under way she ships a bucketful a minute
  for each tile over that mark, up to awash.
- Crank: a ship (41 tiles and up) wants a twentieth of her tiles in weight for
  each rigged mast. Short of it, under sail in wind 3 or more she ships ten
  bucketfuls a minute, up to awash.

Small craft are left out. Nothing here is saved.

## One-object craft: rafts, canoes, outriggers, inflatables

These are single objects with no ledger (`code/modules/naval/small_craft_leaks.dm`).
A sound one never leaks. Below half her `health` she ships a bucketful on some
of her moves: a 30 in 100 chance just under half, rising to nearly every move
for a hulk. Ten bucketfuls swamp her and she will not move until she is bailed;
nothing is deleted and nobody is thrown out.

- Damage comes from a weapon of force 10 or more swung with harm intent, and
  from a shot that hits her (a quarter of its damage). It stops at 1 health.
- An empty bucket used on her bails three bucketfuls every three seconds.
- Wood or planks used on her (cloth on an inflatable) give back a quarter of
  her strength a piece, five seconds each.
- There is no timer: water comes in only on a move. It is not saved.

The hooks chain on `do_move`, `do_vehicle_check`, `attackby`, `bullet_act` and
`examine` of `/obj/structure/vehicle/raft` and `/obj/structure/vehicle/boat`, so
the pinned `transports.dm` is untouched.

## Cost and saves

One looping timer (`hull_ledgers_tick`, every 30 seconds) steps the ledgers that
are awake. Players are matched to hulls from the client list with one keyed
lookup a hull, so empty hulls cost no deck walk. Nothing runs during a world
save. The tiller saves the ledger inside its `hull_state` record
(`"ledger": {"water", "holes", "patches", "grounded", "seams"}`); nothing stores `world.time`.

## Tests

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/bilge_probe.dm 300
