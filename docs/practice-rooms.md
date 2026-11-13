# Practice rooms

A lobby link, **Practice Room**, puts a player in a private 12 x 12 room with a
throwaway "Trainee" body. Nine steps appear in chat one at a time: walk to a
marker, pick up a knife, swap hands, wear a straw hat, open a door, hit a
practice dummy on Harm intent, bandage a small cut, eat a bread slice and walk
onto the exit. Finishing, dying or disconnecting returns the player to the
lobby. To leave early: the "click here to leave" link on the welcome line and
every step, **Leave practice room** in the Esc menu, clicking the blue exit
marker (asks first unless it is the last step), or the **Leave Practice Room**
verb, which heads the IC tab's Practice group with **Practice Instructions**
(repeats the current step).

Design reference: CM-SS13's tutorial rooms (`code/datums/tutorial/`, AGPL-3.0).
This is a reimplementation; no CM code or art is copied.

## Where the rooms live

Rooms are built on one level appended above the world (`world_z_budget`
purpose `practice`) only while someone practises:

- Up to 8 rooms, 14 tiles apart, on a plane of at most 175,000 cells (Gaia's
  500 x 350). Adding a Gaia-sized open-air plane measured 0.3 s and 20 MiB.
- The level is never saved. `begin_persistence_operation` closes every room
  and removes the level before a save; the level is removed as soon as the last player leaves, and every room is rebuilt with fresh turfs when it opens.
- While it exists `world_z_budget` refuses every other new level, so it stays
  `world.maxz` and can be removed whole. Multi-z links, observer spawn,
  landers and the ecology index skip it.
- Maps with instance/safehouse reservations and orbit worlds do not offer it.
- The body has `should_save = FALSE` and never records a persistence owner, so a
  player's saved character is untouched. The room area is an admin-area subtype,
  which keeps the body out of battle reports and spawn picks.

## Tutorial region

A region group can run the rooms on a world of their own, like the TDM
Barracks: a region of kind `TUTORIAL` on the blank map
`maps/special/tutorial.dmm` (116 x 60, up to 32 rooms). Code:
`code/modules/1713/tutorial_region.dm`.

- It never saves: `shard_group.py` gives it `save_minutes` 0 and a config with
  `ALLOWED_GAMEMODES ALL` and `SKIP_PERSISTENCE_SAVING`, whatever the group or an
  overlay says, and `begin_persistence_operation` refuses a save there. The
  host's stop does not ask a non-saving world to save.
- It starts its round on its own with no countdown. Every arrival goes straight
  into a room; Join only points back. Leaving a room sends the player to the
  group's gate (which forwards them to their home land) or, without a relay, to
  the mainland.
- On every other region the lobby's **Practice Room** link sends the player
  there when the tutorial region is up or can be woken, and opens a room on its
  own world otherwise (or when waking fails).
- Nobody has a home there, trails and orbital batteries skip it, and it can be
  neither the mainland nor the gate. A group has at most one.

Add one to a group config like any region, for example
`{"id": "tutorial", "name": "Tutorial", "kind": "TUTORIAL", "port": 1760, "transfer_port": 1770, "map": "maps/special/tutorial.dmm"}`
(`transfer_port` only when the group's other regions have one), then run
`setup --region tutorial` and `start --region tutorial`.

Tests: [tests/practice_rooms](../tests/practice_rooms/README.md).
