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

## Not built yet

- A shared rule for when another party's train or base can be forced (owners
  online, any time, or only in raids). The rail-yard train doors follow the
  answer to that question.
- Turning the extraction maps (such as the zombie city) into raid-world maps
  with a timed reset that sends everyone still inside home without their loot.
- Adding more loot types to the travel allow-list.
