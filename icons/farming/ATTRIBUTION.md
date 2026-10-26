# Pocket Stronghold winter crop art

`pocket_stronghold_turnip.dmi` and `pocket_stronghold_plump_helmet.dmi` are
adapted from **Pocket Stronghold 13 / Dwarf Fortress 13 contributors**, at
revision [`2bfb1906a9a68f58c5e5da25383f83dd495bf138`](https://github.com/Valgorithms/Pocket-Stronghold-13/tree/2bfb1906a9a68f58c5e5da25383f83dd495bf138).

Original files:
- [growing.dmi](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/dwarfs/icons/farming/growing.dmi)
- [growable.dmi](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/dwarfs/icons/farming/growable.dmi)
- [seeds.dmi](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/dwarfs/icons/farming/seeds.dmi)

License: **[Creative Commons Attribution-ShareAlike 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/)**.
The [README at the original farming update](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/42f6fececf238597bd3dea08af0c8d110649a494/README.md)
explicitly applies CC BY-SA 3.0 to assets including icons and sounds unless
otherwise indicated. The current pinned README incorporates tgstation licenses.
No farming-specific exception was found. These derived DMI assets retain CC BY-SA
3.0, independently of Civ13's code license. No endorsement is implied.

Source-history contributors: **Maxsc (daxsc)** for the farming asset commits,
and **LEEROY-2** for later `seeds.dmi` edits. This identifies commit contributors,
not a claim that Git history proves who originally drew each pixel.

Modifications for Civ13: selected turnip and plump-helmet states extracted,
repacked and renamed. Upstream growth stages 2 and 4 are repeated to fit Civ13's
six preharvest stages; stage 5 is the harvest appearance. Pixel colors, dimensions
and transparency are unchanged. No generated art is used.

`pocket_stronghold_turnip.json` pins the shared three original files by SHA-256
and Git blob hash. `tests/winter_crops/assets.py` verifies those hashes before
repacking and checks exact RGBA equality for every adapted state. Its previews
are enlarged actual sprite pixels, **not gameplay screenshots**.

Review previews: [turnip](../../docs/media/winter-crops-turnip.png) and
[plump helmet](../../docs/media/winter-crops-plump-helmet.png). These documentation
images reproduce the attributed sprites at nearest-neighbor 4x, with explanatory
labels; they are not connected-game screenshots and contain no new game artwork.
