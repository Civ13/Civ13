# Sprinting

`python3 tests/sprint/run.py --byond-bin <BYOND bin>` compiles the committed
game sources with normal startup disabled and, on a 12x12 world with real
humans, checks `code/game/mob/living/carbon/human/sprint.dm` and its defines in
`code/__defines/sprint.dm`:

- a sprint starts from a walk, run or crawl only with stamina above
  `SPRINT_START_FRACTION` and not while legcuffed; it is a run (`m_intent`
  stays `"run"`), the stat panel says "sprint" and Check Movement reports the
  faster pace;
- it drops back to a run below `SPRINT_STOP_FRACTION`, and a stale flag never
  makes a walker sprint;
- sprinting into someone standing can knock them over, the sprinter too, or
  neither; every collision ends the sprint, costs stamina and has a cooldown;
  strength and dexterity tilt the odds and the ramming force
  (`code/game/mob/physical_contest.dm`); people already down are skipped;
- a door that would open is left to open the ordinary way; one that will not
  is rammed and damaged; barricades are rammed as building parts; a fixed
  obstacle head-on stops the sprinter, a glancing one does not; a loose locker
  is shoved a tile;
- no runtime errors.

The stamina and food cost of each sprint step and the step delay live in
`/client/Move` (`code/game/mob/mob_movement.dm`). Random outcomes are retried
until they happen. It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
