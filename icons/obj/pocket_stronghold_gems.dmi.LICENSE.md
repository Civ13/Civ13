# Pocket Stronghold gemstone sprite attribution

`pocket_stronghold_gems.dmi`, states `ruby`, `ruby_uncut`, `sapphire`,
`sapphire_uncut` and `diamond`, is distributed under **Creative Commons
Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0)**:
https://creativecommons.org/licenses/by-sa/3.0/

Credit: **Pocket Stronghold 13 / Dwarf Fortress 13 contributors**. Git history
records these contributors for the selected states (the first commit holding
the current pixels, under any state name):

- `ruby`, `sapphire`: Biomekmann, commit [`f29cd06`](https://github.com/Valgorithms/Pocket-Stronghold-13/commit/f29cd06), 2022-03-09.
- `diamond`: Biomekmann, commit [`5c36135`](https://github.com/Valgorithms/Pocket-Stronghold-13/commit/5c36135), 2022-03-09.
- `ruby_uncut`, `sapphire_uncut`: LEEROY-2, commit [`73b2c77`](https://github.com/Valgorithms/Pocket-Stronghold-13/commit/73b2c77), 2022-04-19.

Later commits by Maxsc renamed states without changing these pixels. This
identifies the recorded contributions, not who drew each pixel, and does not
imply endorsement.

Source: [Pocket Stronghold 13, `dwarfs/icons/items/ores_gems.dmi`](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/dwarfs/icons/items/ores_gems.dmi),
commit `2bfb1906a9a68f58c5e5da25383f83dd495bf138`.
The [source repository's license notice](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/README.md#license)
applies /tg/station's licenses unless otherwise specified, and /tg/station
licenses icons under CC BY-SA 3.0 unless otherwise indicated. No different
notice was found for these states. Keep this attribution with copies of the
asset; adaptations remain subject to ShareAlike.

Changes for Civ13: the five states were extracted into their own DMI with
their upstream names. No pixels were redrawn, recoloured or rescaled.
`tools/art_ports/sources/pocket_stronghold_gems/manifest.json` pins the source
file and per-state RGBA hashes; `tools/art_ports/pocket_stronghold_gems.py`
rebuilds and verifies the DMI. Left out: the upstream rough diamond (Civ13's
mined diamonds keep their own art), the fantasy glowing gem, and the plain ore
and rock states Civ13 already has.
