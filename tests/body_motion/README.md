# Body motion tests

Whole-body motion (`code/game/mob/living/carbon/human/body_motion.dm`) animates
only the human's transform, on top of the posture transform.

- `python3 tests/body_motion/test_sources.py` - offline suite `body_motion`:
  transform-only channel, parallel animations, tmp state, the posture
  handshake in `update_posture_transform()`, recoil hooks, config line and
  Fable's timing budgets.
- `python3 tests/body_motion/run.py --byond-bin <bin>` - native probe on the
  committed sources (`git archive HEAD`): feet pivot, first draw snaps, eased
  fall and stand-up, redraws during a motion, recoil standing and lying,
  priorities and the gap, unwatched bodies, config levels, dead bodies and
  untouched pixel channels.

Neither proves how a motion looks in Dream Seeker; that needs a client capture.
