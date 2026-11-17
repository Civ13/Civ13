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

## Anchors, mooring and drift

`code/modules/naval/hull_anchors.dm`. A boat or ship needs something to lie to
when her anchor is called down at the helm:

- anchors built on her deck (`/obj/structure/hull_anchor`): a killick holds 40
  tiles of hull, an iron anchor 100; together they must cover her tiles;
- or a mooring post (`/obj/structure/berth/quay`) or bollard within two tiles
  of her bounding box.

The helm order is never refused, so arrivals that call `set_anchor(TRUE)` still
stop her; the crew is told when nothing holds. `held()` is false with the
anchor up or nothing to hold, and `step_drift()` then moves an awake, crewed
hull one tile a ledger step: with `river_current_direction()` at her origin if
there is a current, otherwise downwind in wind 2 or more. An empty hull never
drifts. Small craft and grounded hulls are always held.

A hull whose saved record has no `"old_anchor"` key was afloat before anchors
were things and keeps one that holds all of her (`old_anchor`, saved). Hulls
commissioned from now on save `"old_anchor": 0`.

## Rigging and sail handling

`code/modules/naval/hull_rigging.dm`. A mast standing free on a built hull has
`canvas` (furled 0, reefed 1, full 2, the default) and `torn`. Clicking a
rigged mast offers set, reef and furl, four seconds each; `hull_wait()` lets
the work survive a step of the hull.

- The sail drive is not `ready()` when furled; `push()` is times 0.6 reefed and
  times 0.3 torn.
- `step_rigging()` runs in the ledger step for boats and ships under way: in
  wind 3 and up a full sail has 15 chances in 100 a half minute to tear, and in
  wind 4 a reefed one has 5. It reads her drives; there is no deck walk.
- Two pieces of cloth used on the mast mend a torn sail in six seconds.
- The tiller lists how her sails are carried once any is not plainly full.

Masts fitted to a modular ship's frame are untouched.

## Fouling, scraping and copper

`code/modules/naval/hull_fouling.dm`. Boats and ships only; small craft never
foul.

- `fouling` runs from 0, clean, to 1, foul, and grows in `step_fouling()` in
  the ledger step, so only while she is awake (crewed or under way) and not
  sat on the bottom. A bare bottom takes 86400 seconds of use.
- `foul_weight()` is nothing while she is clean (under a tenth) and then
  `fouling x tiles x 0.4`, rounded; `craft.mass()` adds it with the water and
  the load, so her drives push it.
- Names: clean, slimed (0.1), weedy (0.4), foul (0.75). The crew is told at
  weedy and at foul; the tiller always says.
- Scraping (`hull_scrape()`): a shovel or a knife used, without harm intent,
  on a plank of a hull that is at least slimed. She must lie still and not
  over deep water. Each go of four seconds cleans three tiles.
- Copper (`hull_sheathe()`): copper sheets on a plank of a wooden hull, under
  the same conditions, with a clean bottom and a hammer in the other hand.
  One sheet covers two tiles; `coppered` runs 0 to 1 and a full sheathing
  stops nine tenths of the growth.
- `fouling` and `coppered` are saved with the ledger.

## Stations and the watch

`code/modules/naval/hull_watch.dm`. Nothing forces a crew to man a station; the
helm is told who is where, and a hand in the bow earns the crew a warning.

- "Muster the watch" at the tiller prints `muster_text()`: everyone alive
  aboard and their station from `station_of()` - at the helm (within a tile of
  the tiller she is steered from), at an oar (buckled to a rowing bench), in
  the bow keeping the lookout, at a mast, a pump or the anchor (within a tile),
  or on deck. It needs no helm access.
- The bow is her two foremost rows along her heading (`in_bow()`), on either
  deck. `lookout()` is anyone alive, awake and on their feet there who is not
  at the helm or an oar. Small craft keep no lookout.
- `step_watch()` runs last in the ledger step. Under way with a lookout,
  `sight_ahead()` plans her box up to twelve tiles along her heading and
  returns the first distance that fails with the reason, coordinates cut off.
  The crew is told when it is first sighted, when it is four tiles off or
  less, and again if what is sighted is farther than before (a new course).
  `sighted` is not saved.

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
(`"ledger": {"water", "holes", "patches", "grounded", "seams", "old_anchor", "fouling", "coppered"}`); nothing stores `world.time`.

## Tests

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/bilge_probe.dm 300
