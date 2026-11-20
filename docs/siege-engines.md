# Siege engines and castle defences

Code: `code/modules/1713/siege/siege_engines.dm` (the trebuchet extends
`catapult.dm`). Art: `icons/obj/siege_engines.dmi`, `icons/obj/trebuchet.dmi`
and `icons/obj/siege_tower.dmi` from `tests/sprites/create_siege_engines.py`.
Probe: `tests/siege_engines/probe.dm`.

Siege Engines (313 B.C.) unlocks the ram, the ballista and its bolts, and the
siege tower. Fortifications (1013) unlocks the trebuchet, the portcullis, the
drawbridge, the gate winch and the murder hole. On TDM maps they work only once
the sides may cross (`siege_can_fight`).

- **Battering ram** (30 wood): push it up to a gate, door, barricade, castle
  gate or built wall and face it there. A swing takes 3 s and does 60 damage
  for each able person standing beside it, up to four (240). A gate (600) falls
  in three full-crew swings.
- **Ballista** (25 wood, bolts 2 wood): fasten with a hammer, load a bolt and
  loose it. The bolt flies straight along the facing for up to 24 tiles, does
  90 damage and passes through two targets.
- **Siege tower** (60 wood): push it against a wall and face it there. Lowering
  the drop bridge takes 3 s; then anyone beside the tower climbs it and lands on
  the first clear tile beyond the wall after 2 s. The tower is opaque, so the
  defenders can't see who is massing behind it. Moving or turning it raises the
  bridge.
- **Trebuchet** (80 wood): a catapult with a 30 to 140 tile range, a bigger
  blast and a 6 s wind-up.
- **Portcullis** (12 wood) and **drawbridge** (15 wood): castle gates that can't
  be moved by hand. A **gate winch** (8 wood) raises (4 s) or drops (1.5 s)
  every portcullis and drawbridge within two tiles. A shut portcullis stops men
  but not arrows; a raised drawbridge blocks sight as well. Both have 900
  health and take ram, explosive and weapon damage.
- **Arched iron gates** also work with a gate winch: build it within two tiles
  of any section of a continuous straight run. The winch moves the entire run,
  keeping the existing arched art, animation and separate gate control. If the
  winch only serves arched iron gates, it opens any mixed run first so one more
  pull can close every section. These gates do not gain portcullis crush damage.
- **Murder hole** (3 stone): pour a container through it, or drop anything
  else, onto the level below (or, on a single level, the tile it faces). The
  level below shows through the hole. See "Pouring and dropping" below.

Moats need no new object: dig a ditch next to the wall and flood it with the
existing river and flood mechanics, then span it with a drawbridge.

**Undermining.** When a tile is dug or mined open on a level directly under a
wall, gate, door or barricade on the level above, the wall falls 30 s later
unless a mine support stands within one tile of that tunnel tile. Pulling out
or burning the prop brings it down at once. Natural rock walls are not
affected. Defenders countermine by digging toward the tunnel.

## Castle defences

Code: `code/modules/1713/siege/castle_defences.dm`. Art:
`icons/obj/castle_defences.dmi` from `tests/sprites/create_castle_defences.py`.
Probe: `python3 tests/castle_defences/run.py --byond-bin <BYOND bin>`.

- **Arrow slits and gun loops.** On help intent, use a chisel on a built stone,
  clay or timber wall (a hatchet also works on timber) while standing right
  against it, square on. Your side becomes the inside and the far side the
  outside. It takes 15 s, needs Fortifications for an arrow slit and Gunpowder
  for a gun loop, and costs the wall 20% of its health. Straw walls, paper
  screens, unfinished walls and archways can't take one.
- Whoever stands on the tile right behind the opening shoots out through it:
  95% of shots pass, straight out or up to 45 degrees either side. Anyone
  further back gets the usual wall block. Shots from outside hit the stone 95%
  of the time; the rest fly on and can hit the defender behind the slit.
  The wall stays solid but can be seen through.
- **Shutters.** Two planks used on a slit from the tile right behind it (3 s)
  fit a wooden shutter. Clicking the wall from that tile with an empty hand
  shuts or opens it. Shut, the slit is opaque and stops every shot both ways.
  Filling the slit in gives the planks back.
- Fill an opening in again with one piece of the wall's own material on help
  intent (5 s); the wall gets its health back.
- **Battlements.** A crenelated stone or sandstone wall built by a player
  covers the side the builder faced while building it. Whoever stands behind it
  shoots out over it freely; shots from outside are stopped 85% of the time,
  and always when the person behind it is lying down. Crenelated walls placed
  on maps keep the old two-way cover.
- **Parapets** (4 stone or 4 sandstone, Fortifications) are the edge version of
  a battlement for a wall walk: built facing out like a sandbag wall, they run
  along the outside edge of the builder's own tile, so a one-tile walkway on top
  of a wall keeps its walkway. The same rule applies (`parapet_verdict()`): shots
  crossing it outward pass, shots crossing inward are stopped 85% of the time
  and always when someone on its tile is lying down, and sideways shots ignore
  it. Nobody walks or vaults over it, so it also keeps defenders from stepping
  off the wall walk. Harm intent takes it down for the stone.

## Pouring and dropping

Code: `code/modules/1713/siege/castle_pour.dm` (the murder hole stays in
`siege_engines.dm`). Probe: `tests/castle_defences` (same runner).

- **Heating.** Hold an open container over a lit brazier, hearth, campfire or
  stove on grab intent: water 5 s, oil 8 s, pitch 10 s, sand 6 s, lead 20 s.
  It stays hot for 2 minutes (not across a reload). Quicklime needs no heat.
- **Solids.** Sand, lead sheets and quicklime (into a dry container) go in as
  10 units a piece.
- **Openings.** Murder hole (Fortifications, 3 stone), **machicolation**
  (Fortifications, 8 stone) and **hoarding** (Siege Engines, 12 wood). Build a
  machicolation or hoarding on the wall walk facing out: it pours and drops one
  tile out and one level down, onto the foot of the wall. Pour a container (any
  intent but harm) or drop any other held item through it.
- **Spread.** Under 60 units hits the one tile; 60 or more also splashes the 8
  tiles around at half strength.

| Poured | Effect on each person hit |
| --- | --- |
| Cold water | wet, puts out fire |
| Hot water (or any other hot liquid) | 8-12 burn |
| Hot oil (corn, olive, fat) | 20-30 burn, leaves a slick |
| Hot pitch | 15-25 burn and sets them alight, leaves a slick |
| Hot sand | 10-15 burn that ignores armour |
| Quicklime | 5-10 burn (double if the container also holds water), blinds 10 s |
| Molten lead | 35-45 burn; solid lead won't pour |

Liquid burns are halved by melee armour on the zone hit (except sand).

- **Slicks** of oil or pitch last a minute. A lit torch (harm or help) or a fire
  arrow or bolt landing on the tile sets them alight.
- **Falling items.** Anything that falls through open air, or is dropped
  through an opening, hits the first standing person on the tile it lands on:
  stone and ore 15-25 brute to the head, wood and huge items 25-35 and a
  knockdown, large items 15-25, normal 5-10, small 0-5. A helmet takes its share.
- **Hoardings** burn: a lit torch on harm intent, fire, or a fire arrow or bolt
  landing at the foot of the wall under it (40%) sets one alight. It loses 25
  health every 2 s until it falls; 10 units of water put it out.
- **Tar kiln** (6 stone, Stone Masonry): load 10 wood, light it with a torch,
  and two minutes later it holds 40 units of pitch to draw into a container.

## Gateway traps

Code: `code/modules/1713/siege/castle_traps.dm`; probe `tests/castle_defences`.

- **Drop trapdoor** (6 wood, Fortifications; not the lockable trapdoor between
  levels in `structures/trapdoors.dm`) is an item fitted over an open pit
  (dig one with a pit cover and a shovel; stake it for worse) or over open air
  on an upper floor with a level below. Shut, it is floor: nothing falls
  (`castle_trapdoor_holds()` is checked by `/turf/sky/building/Entered` and
  `/turf/floor/broken_floor/Entered`).
- **Trap lever** (3 wood, Fortifications): pulling it (0.5 s) drops every
  trapdoor within 3 tiles on its own level and the level below. Over a pit,
  everyone on it falls in (pit fall damage and stakes; the first is held in
  the pit, the rest are hurt but free) and anyone walking onto it while open
  falls in too. Over open air, people and items fall a level with the usual
  fall damage. Pushing the lever back (3 s) shuts them.
- **Crushing portcullis**: a portcullis dropping onto someone does 30-40 brute
  (melee armour applies) to the head, chest or an arm and knocks them down.
- **Caltrops** (1 iron, Bronze Working): use in hand to scatter where you
  stand, or drop or throw them. Stepping on them does 5-10 brute to a foot
  (halved by boots) and costs 1.5 s. A horse that treads on them takes 5-10
  brute, is lamed for 30 s (double ride delay) and throws its rider half the
  time. Picking them up takes 2 s.
- **Ladder fork** (3 wood, Siege Engines): used on a deployed siege ladder
  (a spear, pike or halberd works too) it pushes the ladder off the wall in 3 s.
  The ladder lands on the far side; anyone mid-climb falls with it (5-15
  brute, knocked down).
- **Pit traps** belong to the digger's civilization, or their side on a team
  map; that side never falls in (docs/stone-age-traps.md).
