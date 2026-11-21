# Hand conditioning tests

Striking a makiwara post, a gravel pail or bare rock toughens the knuckles
(`code/modules/1713/martial_arts/hand_conditioning.dm`) and trains the unarmed
skill; every set risks the hand.

- `python3 tests/hand_conditioning/test_sources.py` - offline suite
  `hand_conditioning`: recipes, research node, punch hooks, skill lists.
- `python3 tests/hand_conditioning/run.py --byond-bin <bin>` - native probe on
  the committed sources (`git archive HEAD`): sets, caps, wraps and boxing
  gloves, fatigue and hurt-hand risk, bruises, splits and breaks, fading,
  the punch injury cut and the unarmed skill (including saves without it).
