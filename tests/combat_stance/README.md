# Combat stance tests

Combat stances make melee attacks pick their own body part
(`code/game/mob/combat_stance.dm`).

- `python3 tests/combat_stance/test_sources.py` - offline suite `combat_stance`:
  every melee path asks the stance, the doll and hotkeys return to Manual, the
  HUD button cycles the stances, examine and agent tools list them.
- `python3 tests/combat_stance/run.py --byond-bin <bin>` - native probe on the
  committed sources (`git archive HEAD`): Manual, help intent and random keep
  their zones; each stance's preferred zone; armour gaps; read skill; weapon
  hand, grab and shove picks; Guarded counters; kicks, shields, missing limbs;
  a real swing recorded on the target.
