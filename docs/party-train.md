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
- The office cannot be crushed by vehicles or blown up, since it holds the
  delivered materials. A renamed faction keeps its project or train.
- The party is the player's current faction: a solo player who finishes a
  train and then joins a faction boards as that faction, not as themselves.
- When the last material is in, the office opens boarding. Members of the
  party board the train there; it travels to the first region of kind
  `RAILYARD` in the group, like a trail (`region_travel.dm`). The trip moves
  the player's home world to the yard (`region_home.dm`).

Code: `code/modules/persistence/party_train.dm`. Tests:
`tests/transfer_storage/test_party_train.py`.

## The rail yard

- Generate the yard map and point the group's `RAILYARD` region at it:
  `python3 -m tools.rail_yard --berths 96 --columns 4 --out yard.dmm`.
  The default 96 berths make a 151x227 map, about the size of a generated
  surface region; up to 162 berths fit in 6 columns (225x254). The tool
  refuses layouts over 255 tiles on a side.
- Each **berth** is a numbered platform marker beside a three-car walk-in
  train: a locomotive cab, a common car with tables and racks, and a sleeper
  with ten beds and crates. Carriage walls are indestructible and the doors
  open only for the berth's party and cannot be forced. Beds can be claimed
  as usual, so a member who sleeps aboard keeps the yard as home.
- The first member of a party to arrive gets the lowest free berth for the
  party; later members arrive at the same berth. The berth is saved with the
  yard world. When the yard is full, the arrival lands on the arrival
  platform and the admins are told.
- Using the berth marker travels back to the land the party last came from,
  arriving at the party's finished station. Only party members may use it.
- Party trips carry the party and the land they left from in the travel
  payload. A faction's party is named with its land (`civ:<land>:<name>`),
  so factions with the same name in two lands never share a train. Factions
  do not travel: in the yard a member's party is kept on the body, and a
  member coming home rejoins the faction if it still exists. At home only
  the current faction counts, so someone who left the faction cannot board.
- A party that has never ridden its train cannot board while the yard reports
  no free berth, so nobody is stranded in a full yard. A solo party's trip is
  refused unless the traveller is that player.
- Starting a project needs the region group, since a party is named after
  its land.

Code: `code/modules/persistence/party_train.dm`, map generator
`tools/rail_yard/`. Freeing a berth whose party is gone, or moving a berth to
a faction's new name after a rename, is an admin edit for now.
