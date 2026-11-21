# Crop frost and frost covers

`code/modules/1713/crop_frost.dm` lets the night cold hurt tender crops, and
lets a farmer cover them against it. It reads the air grid
([weather-air.md](weather-air.md)) and the frost reader in
[weather-fog.md](weather-fog.md), so nothing happens before the grid exists.

## Frost

Each growth tick (once a minute, from `water_proc()` in `farming.dm`), an
outdoor crop under open sky checks the air on its tile less hill cooling, plus
the warmth of its cover:

| Cold | When | What it does |
| --- | --- | --- |
| Light frost | a clear, calm night or morning (`weather_frost_at`) with the covered air at 1 C or below | a growing crop loses one growth stage, at most once a night (20 minutes); a ripe crop is unharmed |
| Hard freeze | the covered air at -4 C or below, any weather | the crop dies ("frozen"), young or ripe |

Winter-hardy crops (turnips), trees and mushrooms are not hurt. Crops under a
roof, including a greenhouse's glass, are not either. A blizzard still kills
any crop that is not winter-hardy, as before.

## Covers

| Use on the crop | Cover | Keeps off |
| --- | --- | --- |
| 1 straw or hay | straw mulch (drawn under the crop) | 2 degrees |
| 2 cloth | cloth row cover | 3 degrees |
| 2 glass | glass cloche | 5 degrees |

One cover at a time. An empty hand takes it off and drops what it was made of;
harvesting or uprooting the crop drops it too. Examining the crop names its
cover, says when frost has nipped it back, and gives a skilled farmer a hint
in the cold seasons. The art is by Fable 5.2
(`tests/sprites/create_frost_covers.py`, `icons/obj/frost_covers.dmi`).

## Tests

```sh
python3 tests/ecology_spawning/run_linux.py . tests/crop_frost/probe.dm
```
