# Home comfort

Code: `code/game/mob/living/carbon/human/home_comfort.dm`. Native probe:
`python3 tests/ecology_spawning/run_linux.py . tests/home_comfort/probe.dm`.

When a character falls asleep, the roofed room around them is judged once.
The room is a flood fill over cardinal neighbours that are inside (`AREA_INSIDE`)
and not bounded by a solid turf, a built wall (`/obj/covers` with `wall`), a door
or a window; it stops at 150 tiles. Each category counts once, so variety and
upkeep matter, not quantity.

| Category | Counts when |
| --- | --- |
| A covered floor | at least half the tiles have a non-wall cover, carpet or wood floor |
| Finished walls | at least half the built walls report `home_finished()` (whitewash, plaster, paint) |
| A light | any lamp, brazier, torch stand, fireplace, flashlight-type lamp, or anything lit |
| A bed, a seat and a table | all three in the room; a bedroll is not a bed |
| A work of art | anything `mood_is_art()` accepts, in the room or on its walls |
| A living plant | a filled plant pot, a crop or flowers |
| A named house | a custom sign given a name, in the room or on its walls |
| A clean room | at most 2 stains or bits of rubbish |
| Sound walls | no bordering built wall below half health |

| Points | Tier | Resting mood | Resting cap | Well rested |
| --- | --- | --- | --- | --- |
| 0 to 2 | Bare | the roof, +3 | 75 | no |
| 3 to 4 | Cosy | +4 | 75 | no |
| 5 to 6 | Comfortable | +5 | 75 | 30 minutes |
| 7 to 8 | Fine | +6 | 77 | 45 minutes |
| 9 | Splendid | +8 | 79 | 60 minutes |

The tier (`home_comfort`) is saved with the body and counts from waking until
the next sleep, like `sleep_comfort`; the home part replaces the plain shelter
part. The cap stays below 80, so living conditions alone never reach Excellent.
Well rested (`well_rested_until`, runtime only) adds a quarter to stamina
recovery and slows hunger and thirst to 85 percent. On waking the player is told
the tier and what the room lacks; the IC verb **Judge This Room** shows the same
for the room they stand in. Battle maps ignore all of it (`mood_needs_mode()`).

Upkeep costs comfort, not belongings: rubbish and stains drop "clean" and
weathered walls (see `docs/seasonal-construction.md`) drop "sound".
