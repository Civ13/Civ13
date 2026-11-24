---
name: civ13-art-and-ui
description: Rules and review steps for Civ13 art, sprites, icons, animations, visual effects and UI layout - who makes them, which tools, previews and the sprite-review job. Use for any .dmi or image change, new visuals, or any UI layout change.
---

# Art, sprites and UI

## Who makes it

- All art, sprites, animations, visual graphics and UI layout changes are
  handled by Fable 5.2 or newer. Another model may wire up code that uses the
  result, but never draws sprites or designs the layout itself.
- Reuse and transform existing art assets where possible. Never use image
  generation tools (Stable Diffusion and similar). New art made from scratch
  uses appropriate graphic tools, such as scripted pixel or vector drawing.
- Keep the generator script for new sprites in the repository with the sprites
  (existing ones live under `tests/sprites/`), so they can be regenerated.

## Review

- Attach a preview image of new or changed sprites to the PR when it is cheap
  to make.
- The `Sprite review` workflow (`scripts/sprite_review.py`, byond-devtools
  `icon-diff`) posts before | after | heatmap pictures for every changed `.dmi`.
  Locally:
  `python3 scripts/sprite_review.py --base origin/master --devtools <byond-devtools checkout> --out sprite-review`.
- DMI format, metadata and audits: [Sprites guide](../../../docs/agent-guides/sprites/README.md).
- Game PRs with visible changes need real screenshots, never mock or
  generated evidence ([Verification guide](../../../docs/agent-guides/verification/README.md)).
