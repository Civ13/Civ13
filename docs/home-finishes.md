# Wall and floor finishes

Code: `code/modules/1713/home_finishes.dm`. Native probe:
`python3 tests/ecology_spawning/run_linux.py . tests/home_finishes/probe.dm`.

- **Limewash.** Using a lump of quicklime (lime kiln) on an open container holding
  at least 20 water turns 20 water into limewash: the `paint` reagent in lime
  white `#efe9da`.
- **Tint.** Using a painting pigment on a container with paint tints all of it
  to the pigment's colour (one pigment use; a box of oil paints asks which colour).
- **Coat.** Using a container with at least 5 paint on a built wall or a laid
  floor coats it in 3 seconds. Roads, bridges, carpets, thatch and mats take no
  coat. Walls and stone floors show a wash, wooden floors a stain.
- **Fading.** A coat lasts two weeks of real time (`finish_applied` is
  `world.realtime`), then shows worn patches and no longer counts as finished
  walls for home comfort (`docs/home-comfort.md`). A fresh coat renews it.
- **Saved.** `finish_color` and `finish_applied` save with the cover;
  `after_load` redraws it.

The look is `finish_overlay()`, designed by Fable: one colour matrix on an image
of the cover's own icon state at `layer + 0.005`, under cracks and mold, plus
worn patches from existing effect states when faded. No new sprites.

## Dyed furniture fabric

Code: `code/modules/1713/furniture_fabric_dye.dm`.

- Padding a bed, chair, sofa or stool with cloth asks for a dye; leather padding
  keeps its own colour. Using another cloth sheet on cloth padding re-covers it
  in a new dye for that sheet.
- Using a cloth sheet on a cloth curtain re-dyes it for that sheet.
- The dyes are the tailoring dyes the person knows (`tailoring_known_dyes()`):
  natural dyes with weaving, more with classical dress and fine garments, any
  colour with textile mills.
- `padding_color` saves with the furniture and clears with the padding; the
  existing `_padding` overlay states are tinted, so no new sprites.
