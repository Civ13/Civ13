# Wild animal feeding

Source: `code/modules/ecology/wild_feeding.dm`, `check_food()` in
`code/game/mob/living/simple_animal/simple_ai.dm`.

## Why

A 2026-11-18 review of Gaia found wild animals that could not feed away from
farms. Seed eaters (rabbits, turkeys, monkeys, parrots, wild boar,
junglefowl) only ate ground seeds and planted crops, and camels only grazed
grass tiles in a desert habitat. Grazing also turned each eaten grass tile into
dirt for good, because grass regrew only on semiarid dirt once a year.

## Behaviour

- Grazing a grass tile (ordinary, jungle or winter grass) grazes it down for
  20 minutes instead of turning it into dirt. Grazed grass looks unchanged; it
  is not pasture again until it grows back. The timer is a runtime value, so a
  restart lets every tile grow back.
- Seed eaters with no crops nearby forage seeds in pasture, which grazes it down.
- Grazers and seed eaters browse wild plants within one tile: small bushes,
  bushes, tall grass, jungle growth, palms, cacti and flowers. Berry bushes
  stay for people; dead and burned plants feed nothing.
- Hungry animals walk toward pasture or a wild plant within six tiles when
  there is nothing to eat beside them.

## Death tally

Every simple animal that dies (not human NPCs, not player-controlled) is
counted by cause: starvation, predators (an animal bite), people (last hurt by
a person) or other. Starvation and predator bites note the cause the moment
they land; a cause noted in the last minute still counts. The tally is written
to the game log as `Wildlife: ...` once an hour from the ecology cycle, and
Debug > Ecology Spawning Status shows the current hour and the last report.
Nothing is saved.

## Tests

`tests/animal_combat/feeding.dm`, run by `tests/animal_combat/run.py`.
