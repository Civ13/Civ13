# Punch injury tests

Bare-knuckle punches can hurt the puncher's hand unless gloves or hand wraps
protect it (`code/game/mob/living/carbon/human/punch_injury.dm`).

- `python3 tests/punch_injury/test_sources.py` - offline suite `punch_injury`:
  punch and animal hooks, wrap materials, jewellery protection.
- `python3 tests/punch_injury/run.py --byond-bin <bin>` - native probe on the
  committed sources (`git archive HEAD`): protection order across gloves, chance
  by zone, force and armour, bruised and broken hands, wrapping and unwinding
  cloth and leather, stand-in icon states.
