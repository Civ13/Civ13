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

`mood_drift()` runs once per life tick and moves mood toward the resting level
from either side, stopping exactly on it. Sleep discards the fade and every
other loss (`set_mood`); gains still apply.

| Where mood is | Change per tick |
| --- | --- |
| below the resting level | +`MOOD_RECOVER` (0.03) |
| up to `MOOD_BOOST_BAND` (10) above it | -`MOOD_FADE` (0.015) |
| further above it | -`MOOD_BURN` (0.07) |

So a lift of 10 lasts about eleven minutes, while anything stacked above the
band, including a drug high, burns off at the old fast rate. Repeating a small
pleasure cannot hold mood above the band: music gives at most +3 every two
minutes, far less than the burn.

Earlier the resting point was 40, the bottom edge of Neutral, where overlapping
ranges applied the Bad effects while the icon still showed Neutral, and every
lift faded at 0.07 a tick.

## Resting level

`mood_resting_level()` is `MOOD_REST` (50) plus the lasting conditions, limited
to `MOOD_REST_MIN`..`MOOD_REST_MAX` (30 to 75). It is refreshed every
`MOOD_REST_CHECK` (10 seconds) by `refresh_mood_rest()`, which calls
`collect_mood_rest_parts(parts)`; each override adds `parts[condition] = change`.
The parts are listed when the player clicks the mood icon, and a new part is
announced in chat at most once every five minutes.

Conditions change where mood settles, never mood itself, so they cannot be
farmed and they stop mattering the moment they end.

| Condition (hunger-enabled maps) | Change |
| --- | --- |
| Extroverted with company within 3 tiles / alone | +5 / -8 |
| Introverted alone / with company | +5 / -8 |
| Wanderer settled within 20 tiles for 45 minutes | -6 |
| Recluse Scholar with 3 or more people within 3 tiles | -6 |
| Rallying Voice with nobody within 3 tiles | -6 |

## Tests

`python3 -B -m unittest discover -s tests/mood_sleep -p 'test_*.py'` projects
the real helpers offline. `tests/movement_check/probe.dm` checks in a real
world that mood 40 adds no movement delay.
