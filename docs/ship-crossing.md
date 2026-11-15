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
   loose things on deck. Items cross as they do for a traveller: allowlisted
   stacks and coins by kind and amount, clothing, tools, sealed food and
   unloaded guns by type, magazines by round count, books by subject. Anything
   else aboard (an engine, a barrel, a table, an animal, a body) keeps her in
   port, and the tiller names what to put ashore. At most 400 loose things;
   chests hold at most 30.
2. **The crew** are everyone standing on her: each must be conscious, not
   restrained, with an account, and carry only what a traveller may carry.
3. She is taken off the water at once (the crew wait aboard, out of reach),
   so nothing aboard can be picked up twice.
4. Each crew member leaves as an ordinary traveller. The first carries the
   ship's record in their payload (up to 48 KB instead of 8 KB); everyone
   carries the voyage id.
5. If nobody could leave, she is built again where she lay and the crew stand
   on her. If she left but someone could not follow, they are put ashore.

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

`tests/naval_carrier/crossing_probe.dm` (run like the other naval probes):
packing and refusals, bad records, payload sizes, stripping her, the anchorage
search, building her again with mast, chest and cargo, and crew arrivals by
voyage. Not covered: two live worlds with the transfer agent between them.
