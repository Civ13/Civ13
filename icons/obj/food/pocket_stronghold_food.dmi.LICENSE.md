# Pocket Stronghold food sprite attribution

`pocket_stronghold_food.dmi`, states `intestines`, `crab_meat_roasted` and
`food_ruined`, is distributed under **Creative Commons Attribution-ShareAlike
3.0 Unported (CC BY-SA 3.0)**: https://creativecommons.org/licenses/by-sa/3.0/

Credit: **Pocket Stronghold 13 / Dwarf Fortress 13 contributors**. Git history
records these contributors for the selected states:

- `intestines`: LEEROY-2, commit [`140cef6`](https://github.com/Valgorithms/Pocket-Stronghold-13/commit/140cef6), 2022-06-07.
- `food_ruined`: LEEROY-2, commit [`b59b2a0`](https://github.com/Valgorithms/Pocket-Stronghold-13/commit/b59b2a0), 2022-06-20.
- `crab_meat_roasted`: ArtofWASD2, commit [`b9e5431`](https://github.com/Valgorithms/Pocket-Stronghold-13/commit/b9e5431) (#33), 2023-05-30.

This identifies the recorded contributions, not who drew each pixel, and does
not imply endorsement.

Source: [Pocket Stronghold 13, `dwarfs/icons/items/food.dmi`](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/dwarfs/icons/items/food.dmi),
commit `2bfb1906a9a68f58c5e5da25383f83dd495bf138`.
The [source repository's license notice](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/README.md#license)
applies /tg/station's licenses unless otherwise specified, and /tg/station
licenses icons under CC BY-SA 3.0 unless otherwise indicated. No different
notice was found for these states. Keep this attribution with copies of the
asset; adaptations remain subject to ShareAlike.

Changes for Civ13: the three states were extracted into their own DMI with
their upstream names. `intestines` keeps the upstream pixels. `crab_meat_roasted`
and `food_ruined` were redrawn for Civ13 as hand-placed pixels from a fixed
palette by `tests/sprites/create_orchard.py` (a crab shell of roasted meat and a
spoiled, mouldy heap); they replace the upstream drawings under the same state
names and are distributed under the same CC BY-SA 3.0 terms so the file keeps
one licence. No generated art is used.
`tools/art_ports/sources/pocket_stronghold_food/manifest.json` pins the source
file and per-state RGBA hashes (`source_rgba_sha256` for the upstream pixels of a
redrawn state); `tools/art_ports/pocket_stronghold_food.py`
rebuilds and verifies the DMI. The inventory of every upstream food state and
why it was imported or left out is in `docs/pocket-stronghold-food.md`.
