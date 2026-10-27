# Bark sprite attribution

`bark.dmi`, state `bark`, is distributed under **Creative Commons
Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0)**:
https://creativecommons.org/licenses/by-sa/3.0/

Credit: **LEEROY-2 and the Dwarf-Fortress-13 / Pocket Stronghold 13 contributors**.
Git history identifies LEEROY-2 as the contributor who introduced this bark
state in commit
[`ffb8fbfa5d2f277f179fd3fcd03a83dba6b4f60b`](https://github.com/Valgorithms/Pocket-Stronghold-13/commit/ffb8fbfa5d2f277f179fd3fcd03a83dba6b4f60b)
on 2022-08-16. Its pixels are unchanged through the source revision below.
This credit identifies the recorded contribution; it does not imply endorsement.

Source: [Pocket Stronghold 13, `dwarfs/icons/items/components.dmi`](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/dwarfs/icons/items/components.dmi),
commit `2bfb1906a9a68f58c5e5da25383f83dd495bf138`, state `bark`.
The source item references that resource and state in
[`dwarfs/code/modules/carpentry/planks.dm`](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/dwarfs/code/modules/carpentry/planks.dm).

The [source repository's license notice](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/README.md#license)
applies /tg/station's licenses unless otherwise specified. The
[/tg/station asset license notice](https://github.com/tgstation/tgstation/blob/87b933384df4700bf98c2f7af821c0a730b7c3bb/README.md#license)
licenses icons and sounds under CC BY-SA 3.0 unless otherwise indicated.
No different license or attribution notice was found for this bark state in
the source tree or its contributing history. Keep this attribution and license
with copies of the extracted asset; adaptations remain subject to ShareAlike.

Changes for Civ13: extracted only the `bark` state into its own DMI and added
embedded attribution. No sprite pixels were redrawn, recolored, or rescaled.
The unrelated states from the source spritesheet were not imported.

Extraction and validation:

- Source PNG: 256 by 224 pixels; DMI version 4.0, 32 by 32 cells.
- Source cell: zero-based index 39, rectangle `(224, 128, 256, 160)`.
- Destination: 32 by 32 pixels, exactly one state named `bark`.
- Preserved state metadata: `dirs = 1`, `frames = 1`; no animation timing,
  loop, movement, or hotspot attributes were present on the source state.
- The DMI `Description` remains a compressed PNG `zTXt` chunk.
- Source PNG SHA-256:
  `027094b8d22a7a112f20bee964559a3932b7f74eeb9464ef3a53ad622a8f9f55`.
- Source and destination decoded row-major RGBA pixel SHA-256:
  `ef301f0b516cdc27e874127c10e748873b5cb4fd60039beaf142a084fefe9dbe`.

The existing Civ13 asset audit at
`1650445ede7924070698de31d34e8e8afb913d29` parsed 378 tracked DMI files
containing 23,328 named states, found no bark-named state or pixel-identical
frame, and visually checked the existing wood/material candidates.
PNG decoding, nonempty transparency bounds, state metadata, and exact RGBA
pixel parity were checked offline. This asset-only import adds no gameplay
behavior. BYOND compilation, native tests, and live-game checks were not run.
