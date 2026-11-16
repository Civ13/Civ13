# Water quality and washing

Code: `code/modules/1713/water_quality.dm`. Test: `tests/water_quality`.

## Germ level of open water

A water tile's `sickness` is its kind (fresh 1, jungle river and flooded
riverbed 2, swamp 3). Everything that draws, drinks or bathes in open water
asks `water_germ_level()` instead:

| Water | Germ level |
| --- | --- |
| River with a current (flow sidecar) | half its kind: fresh 0.5, jungle 1 |
| Still fresh water, air 27 C or hotter | 1.5 |
| Other still fresh water, salt water | its kind |
| Swamp, flooded riverbed | its kind, moving or not |

A bucket fill carries 5% cholera germs per germ level; drinking straight from
the water rolls cholera at 15% per level. Boiling kills all of it. Looking at
the water from two tiles or closer says which kind it is ("The water runs clear
and quick", "The water lies still and warm, green at the edges").

## Washing

- Soap counts only once its four-second wash finishes.
- Showers and tubs raise a bather to their cleanliness and never lower them
  (`raise_hygiene()`).

## Fleas and typhus

Worn clothes over 90 dirt pick up fleas at `FLEA_INFEST_CHANCE` (0.03%) a
second, about an hour on average. One infestation in ten
(`FLEA_TYPHUS_SHARE`) carries typhus; only those pass it, at
`FLEA_TYPHUS_RATE` (0.01%) a second, scaled by `infection_chance_scale()`.
Washing the clothes clears the fleas.
