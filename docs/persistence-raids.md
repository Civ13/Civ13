# Persistence raids

Val's direction (2026-11-05): persistence worlds take part in the extraction
game mode, and factions can board each other's party trains, safe houses and
similar places. This page records the parts that are built.

## Raid worlds

A region of kind `RAID` in a region group (`scripts/shard-group`) is a raid
world. It runs an extraction-style map that persistent characters visit and
then leave again. A `RAID` region can never be the mainland, because nobody
lives in a raid world.

- **Getting in.** Any approved trail gate or admin gate can lead to a raid
  world. A trip into a `RAID` peer records in its payload the land it left
  from (`"from"`). On arrival, that land is kept on the character as
  `raid_origin`.
- **Getting out.** An extraction point (`/obj/structure/region_gate/raid_exit`)
  sends each raider back to their own `raid_origin`, together with what they
  wear and carry. The cap and the item allow-list are the same as for any
  other trip. Arrivals never land on an extraction point.
- **Dying.** A raider who dies in a raid world leaves their body and gear
  there. Their home moves back to the land they came from, not to the
  mainland. The raid world reports this to the coordinator as a `depart` to
  the origin (`region_home_death`). Their next character starts at home under the usual bed rule.

Code: `code/modules/persistence/region_raid.dm`. Tests:
`tests/transfer_storage/test_region_raid.py`, plus the raid death case in
`tests/transfer_storage/test_homes.py`.

## Faction doors

A faction door opens for members of its faction. Outsiders can smash it, breach
it with a shotgun or pick its lock. A picked lock opens the door once; when the
door closes, it is locked to outsiders again.

## Resetting raid worlds

A `RAID` region with `reset_minutes` (`scripts/shard-group`) never saves. Each
boot is a new map (`code/modules/persistence/region_raid_reset.dm`).

- The Status tab counts down. Warnings go out at 15, 5 and 1 minutes.
- At the collapse, everyone still inside loses their body and everything
  they carry. Their home goes back to the land they came from, through a
  `depart` note to the coordinator. The world then confirms the cycle's trips
  with the transfer agent and reboots.
- The next boot sends `fresh` with its `/load`. The agent adopts its ledger
  instead of holding the region for a rollback, and voids anything still
  tentative.
- A crash before the reset skips the confirmation, so the next boot replays
  the journal and rebuilds raiders who were inside, with their gear, at the
  new map's entry.
- Wounds now travel with a character as overall damage, capped so they never
  kill on arrival. A raid exit may therefore let hurt raiders leave without
  healing them on the way.

The travel allow-list also covers untouched packaged food and drink, medicine,
basic tools, unloaded guns and magazines (#3783).

## Not built yet

- A shared rule for when another party's train or base can be forced (owners
  online, any time, or only in raids). The rail-yard train doors follow the
  answer to that question.
- Other extraction maps as raid worlds. The zombie city is the first
  (`docs/zombie-city.md`).
