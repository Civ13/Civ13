# Party trains

A party's first train is built in Persistence and lives in the region group's
rail yard world. Val's direction (2026-11-05): the train becomes available once
the party completes a project at a suitable train station, and it lives in its
own rail-yard world, large enough for many trains and parties.

## Station project (this step)

- A **railway works office** (20 wood, trains section of the crafting menu,
  same research level as rails) is the station. It works only within two tiles
  of a straight run of at least eight rails.
- The first player to use it starts the project for their **party**: their
  faction, or the player alone without one. A party has one project or train
  at a time.
- Anyone can hand over materials until the project has 200 iron, 60 steel,
  150 wood, 30 glass and 40 cloth. Only the missing amount of a stack is taken.
  Progress and the finished train are saved with the office.
- When the last material is in, the office opens boarding. Members of the
  party board the train there; it travels to the first region of kind
  `RAILYARD` in the group, like a trail (`region_travel.dm`). The trip moves
  the player's home world to the yard (`region_home.dm`).

Code: `code/modules/persistence/party_train.dm`. Tests:
`tests/transfer_storage/test_party_train.py`.

## Next: the rail-yard world

A generated yard region with many berths, each holding one party's walk-in
train, assigned to the party on its first arrival and kept with that world's
save; a way back to the station's land; and sizing for many parties within one
32-bit world's memory.
