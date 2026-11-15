# Mood

Design and implementation notes for the mood number on human characters.
Player-facing guidance lives in the wiki; this file records the rules the code
and tests hold to.

## The scale

Mood is one number from 0 to 120 (`/mob/living/carbon/var/mood`, starting at
100). Every reader goes through the helpers in
`code/game/mob/living/carbon/human/human_needs.dm`, so the stat modifier,
movement delay, HUD icon, mood message, examine text and the in-game Help
category can never disagree. Each boundary value belongs to the higher tier.

| Mood | Tier | Stats (`mood_stat_modifier`) | Movement delay |
| --- | --- | --- | --- |
| below 10 | Horrible | x0.80 | +0.9 |
| 10 up to 20 | Horrible | x0.85 | +0.9 |
| 20 up to 30 | Bad | x0.90 | +0.8 |
| 30 up to 40 | Bad | x0.95 | +0.8 |
| 40 up to 60 | Neutral | x1 | none |
| 60 up to 80 | Good | x1.05 | none |
| 80 up to 90 | Excellent | x1.10 | none |
| 90 and above | Excellent | x1.15 | none |

The sadness flash and its sounds play only in a horrible mood. Neutral carries
no bonus and no penalty of any kind.

## Settling

`mood_drift()` runs once per life tick. Mood moves toward
`mood_resting_level()` (`MOOD_REST`, 50) from either side and stops exactly on
it: `MOOD_FADE` per tick from above, `MOOD_RECOVER` per tick from below. Sleep
discards the fade and every other loss (`set_mood`); gains still apply.

Earlier the resting point was 40, the bottom edge of Neutral, where overlapping
ranges applied the Bad effects while the icon still showed Neutral.

## Tests

`python3 -B -m unittest discover -s tests/mood_sleep -p 'test_*.py'` projects
the real helpers offline. `tests/movement_check/probe.dm` checks in a real
world that mood 40 adds no movement delay.
