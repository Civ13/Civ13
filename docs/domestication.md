# Domestication

Code: `code/modules/1713/domestication.dm`. Tests: `python3 tests/domestication/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/domestication/probe.dm`.

Cattle, goats, sheep and pigs (`domesticable`) come in two states, wild and tame. Wild boar,
horses and every other animal are unchanged.

## Who is wild

- Animals placed by the ecology spawner (`spawn_herd`) and by mob spawners (`spawnTarget`)
  are made wild (`make_wild()`).
- An animal created at runtime (a birth, or the cattle placeholder turning into a cow or bull)
  on a tile holding a living wild animal of its family is wild (`on_runtime_spawn`). Families:
  cattle, goats, sheep, pigs (boar and gilt).
- Everything else starts tame, including animals already in saved worlds when this shipped
  (the field defaults to tame and the saver omits defaults) and admin spawns. A restored animal
  keeps its saved state.

## What a wild animal refuses

Leash, shears, tack (saddle, harness), a plough (hitching) and any glass/bucket container
(milking): the item does nothing and the player is told to tame it first. Breeding, eating and
butchering are unchanged.

## Taming

Feed it by hand with food it already eats (grain or hay for grazers, seeds for pigs). Hay from
the ground or a bale feeds the animal but does not build trust. A
feeding counts toward taming when it is at least 10 real minutes after the last counted one;
6 counted feedings tame it. For each full day without a counted feeding it loses one. Examine
shows wild and wary, wild with progress, or tame. Times are real minutes since 2000 stored as
text (`trap_now_minutes()` from `stone_age_traps.dm`).

The rope leash is now under Basic Toolmaking (era 0) instead of Basic Agriculture, so a tamed
animal can be led from the Stone Age. Shears, saddles, harnesses and ploughs stay where they were.
