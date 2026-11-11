# Protected cultivation

Stage 2 of #3049: greenhouses built from existing materials.

## Rules

Code: `code/modules/ecology/protected_cultivation.dm`.

| Plot | Storms | Rain | Season | Climate |
|---|---|---|---|---|
| Open sky | Blizzards kill crops that are not winter-hardy; sandstorms destroy crops | Waters the crop | Must suit the crop (tropical climates ignore seasons) | Must suit the crop |
| Any roof (wood, clay, thatch, glass...) | Sheltered: a roof makes an indoor area with the same climate | None, water by hand or from fresh water within two tiles | Unchanged | Unchanged |
| Glass roof | Sheltered | None | Out of season the crop still grows, at half speed | Must still suit the crop |

- A glass roof grants nothing else: no water, no soil nutrition and no growth
  in a climate the crop does not suit. Pollution still slows or blocks growth.
- Opaque roofs are unchanged; they shelter from storms but do not extend the
  season.
- Trees keep their open-sky rule. Mushrooms, plump helmets and cave wheat keep
  their own indoor rules.
- Glass roofing is crafted from glass and needs the Imperial Architecture
  research, so greenhouses come after the outdoor farming route rather than
  replacing it.
- Examining a crop that the glass is keeping alive says so. The Farmer's
  Almanac notes the rule.

The hook overrides `advance_stage_if_allowed()`: when ordinary growth is paused
(`allow_stage` FALSE) and the crop is under glass, alive, not a tree, in a
suitable climate and out of season, it gets a 50% chance to advance. The file is
included after `pollution.dm`, so the pollution override still applies.

## Cost compared with outdoor farming

Outdoor plots need only a plough, seed and water, and grow at full speed in
season with free rain. A greenhouse costs glass roofing over every plot, the
research, and hand or channel watering, and grows at half speed. It earns its
keep in winter, when open fields of most crops stand still.

## Verification

`python3 tests/ecology_spawning/run_linux.py . tests/protected_cultivation/probe.dm 300`
runs 13 native checks: winter pause in the open and under an opaque roof,
half-speed winter growth under glass (about 100 of 200 trials), no change in
season, examine text, the climate rule, pollution, the water need, and dead or
display-only crops excluded.

Not verified: connected-client play, rendering, or a whole winter on a live map.
