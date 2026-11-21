# Ships between worlds

A player-built ship (a built hull with a tiller, [craft core](craft-core.md))
can leave one world of the region group for another, crew, hold and all. This
is the craft step of boat expeditions
([plan](https://claude.ai/artifact/61LciJHKi6eKEUsYMfFgwE)); code in
`code/modules/naval/ship_crossing.dm`.

## Where a ship can go

The tiller offers **Leave these waters** when the hull lies within 4 tiles of
the map edge and a land is in reach:

- from any world, the lands across the sea: `EXPEDITION` slots that hold a land
  ([expedition slots](expedition-slots.md)) and are up or can be woken;
- from a land across the sea, the mainland.

Trails never lead to a land across the sea. Without such a land in the group
the option does not appear. The voyage over the world chart (time at sea,
discovering tiles) is the next step; for now the crossing is immediate.

## Leaving

The ship must be at all stop, not grappled, with the world not saving. Then:

1. **Packing.** Everything aboard is recorded: each floor (type, facing,
   health), masts (rigged or not), chests and crates with what is in them, and
   loose things on deck. Items cross as they do for a traveller: stacks and
   coins by kind and amount, anything else whole (`region_travel_generic.dm`).
   Animals, the dead and other structures (barrels, tables, troughs, doors)
   cross too (`ship_crossing_cargo.dm`): an animal or structure whole, the way
   a world save keeps it (fields, contents, reagents), a body as who it was,
   how it looked, what it wore and its wounds, laid down dead again on
   arrival. Carts, small boats (rafts, dugouts, outriggers, motorboats),
   bicycles and machines go whole the same way, once unloaded; a canoe or
   motorboat takes the outboard clamped inside her and its tank, and arrives
   with it stopped and coupled again (`crossing_rebuilt()`); living crew riding one get
   off as she leaves. An engine goes whole too ("e" entry), with where its fuel
   barrel stands beside it; it arrives stopped and coupled to that barrel
   again, so an engine ship such as the slipway freighter can cross. Built
   walls keep their health (up to 1000000) so a freighter's wheelhouse passes
   the record check. Ladders between her deck and her hold go as ladders and
   are paired again on arrival. Still refused, and named at the tiller with an
   arrow on deck: an animal a player or agent controls, a ridden animal, a
   loaded cart, a frame vehicle the vehicle codec refuses (see below), anything strapped into a seat that
   is not crew, a body holding a creature, and what only an admin or the map
   places (spawners, traders, money printers, stairs and other level links,
   docks, helms). A barrel holds at most 10000
   units. At most 400 loose things and 40 animals, bodies and structures;
   chests hold at most 30. The animals and dead wait in the crossing gate
   while the crew depart and are removed only once the ship has gone; if
   nobody can take her they are put back aboard the rebuilt ship. A
   structure's contents are removed with it, so a case or workbench that
   drops what it holds when deleted leaves no copy behind.
2. **The crew** are everyone standing on her: each must be conscious, not
   restrained, with an account, and carry only what a traveller may carry.
3. She is taken off the water at once (the crew wait aboard, out of reach),
   so nothing aboard can be picked up twice.
4. The crew leave together as one party: every crew member's payload goes
   in one transfer (`depart_party()` in `region_travel.dm`). The first carries
   the ship's record and the voyage id; the others carry the voyage id only.
   Crew sent one after another used to wait on each other's transfer and
   could be left behind. A crossing over a linked map edge
   ([ocean-regions.md](ocean-regions.md)) also carries where along the edge
   she left.
5. If nobody could leave, she is built again where she lay and the crew stand
   on her. If she left but someone could not follow, they are put ashore.

## Holds and cargo

A ship with a hold (`hull_hold.dm`) packs it too, as `record["hold"]`: one
entry per hold tile, under one of her deck tiles, with the same kinds of
entries as her deck (its floor, ladders, chests, loose things, animals,
structures). The hold's crew are crew like those on deck. Taken off the water,
her hold floors and cargo go with her deck and each hold tile gets back the
ground it was hollowed from. On arrival she is anchored, where she can, over
rock or deep water that takes her hold (never against another hull's floor,
which would join the two); the hold is hollowed out under her
deck and its cargo put back in it. Where no such water is free, she is built
without a hold: what it carried is stowed on the deck tile above, its floor is
lost, and a ladder that would lead to nothing is taken down.

Her upper deck (the upper faces of the roofs over her deck, `built_body.dm`)
packs as `record["upper"]`, one entry per tile over one of her deck tiles. A
roof goes as a `"u"` entry on the tile it stands on, the floor on top of a
roof over her deck as an `"f"` entry, and walls, ladder tops and cargo up there
as on her deck; a tile may be only a ladder's top. A floor on a roof of the
upper deck itself (a third storey) would be left in the air, so it keeps her
in port. Taken off the water, her upper deck goes first, then her deck, and on
each tile what stands there before its floors and roofs, so nothing falls to a
tile already cleared. On arrival she is anchored, where she can, under open
air on the building level above; each face is built on its roof again and
linked to it (`building_link()`). Where a tile has no open air above it, its
roof stays a plain roof and what stood up there is stowed on the deck below.

A car, truck or light plane parked wholly on her main deck crosses whole as
`record["vehicles"]`: one entry per vehicle, its axis's tile from her pivot
and the record a garage or hangar keeps (`extraction/vehicle_codec.dm`:
frames, walls, wheels, engine, tank and its fuel, seats, plate, key binding,
boot cargo). Packing writes nothing: the codec's `should_save` marks are put
back. The vehicle must be stopped with its engine off and nobody in it; one
partly off her deck, on her hold or upper deck, with something loose on its
tiles, or of a kind the codec does not take (a tank's turret, a heavy axis)
keeps her in port with the reason. Taken off the water, its parts and boot
cargo go first. On arrival it is parked again where it stood once her deck is
built, saved like any vehicle; ashore (no anchorage) it is put down at the
first clear ground nearby. At most 8 vehicles.

## Arriving

The crew member carrying the record arrives first: the ship is built off the
far side's edge, as near it as she fits on free deep water, on a land's coast
side first (`config/expedition_land.json`), anchored, with her papers. The rest
of the crew arrive on her deck. With no water to bring her in, what she carried
is put ashore and her hull is lost (admins are told).

A crossing refused by the far side comes back the same way: the ship is built
where she left if that water is still free, otherwise off the nearest edge.
After a reload that lost the departure, the replay takes the ship off the water
again.

## Tests

`tests/naval_carrier/crossing_probe.dm` and `cargo_probe.dm` (holds, upper
decks, cars, carts, boats with outboards and machines; run like the other naval probes):
packing and refusals, bad records, payload sizes, stripping her, the anchorage
search, building her again with mast, chest and cargo, and crew arrivals by
voyage. Not covered: two live worlds with the transfer agent between them.
