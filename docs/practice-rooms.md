# Practice rooms

A lobby link, **Practice Room**, puts a player in a private 12 x 12 room with a
throwaway "Trainee" body. Nine steps appear in chat one at a time: walk to a
marker, pick up a knife, swap hands, wear a straw hat, open a door, hit a
practice dummy on Harm intent, bandage a small cut, eat a bread slice and walk
onto the exit. Finishing, dying, disconnecting or the **Leave Practice Room**
verb returns the player to the lobby. **Practice Instructions** repeats the
current step.

Design reference: CM-SS13's tutorial rooms (`code/datums/tutorial/`, AGPL-3.0).
This is a reimplementation; no CM code or art is copied.

## Where the rooms live

Rooms are built on one level appended above the world (`world_z_budget`
purpose `practice`) only while someone practises:

- Up to 8 rooms, 14 tiles apart, on a plane of at most 175,000 cells (Gaia's
  500 x 350). Adding a Gaia-sized open-air plane measured 0.3 s and 20 MiB.
- The level is never saved. `begin_persistence_operation` closes every room
  and removes the level before a save; an idle level is removed after 5 minutes.
- While it exists `world_z_budget` refuses every other new level, so it stays
  `world.maxz` and can be removed whole. Multi-z links, observer spawn,
  landers and the ecology index skip it.
- Maps with instance/safehouse reservations and orbit worlds do not offer it.
- The body has `should_save = FALSE` and never records a persistence owner, so a
  player's saved character is untouched. The room area is an admin-area subtype,
  which keeps the body out of battle reports and spawn picks.

Tests: [tests/practice_rooms](../tests/practice_rooms/README.md).
