# Razor grooming

Offline source checks, run by the `razor_grooming` suite in `scripts/ci_baseline.py`:

    python3 -m unittest discover -s tests/razor_grooming

Run the browser-script test with a lightweight DOM harness (no BYOND server):

    node tests/razor_grooming/test_preview_ui.js

- The razor grooms on any intent except harm when aimed at the head, eyes or mouth.
  Harm still falls through to the normal knife attack.
- Self-grooming previews privately draw the player's current and proposed appearance. Style and
  growth only change after Apply and an uninterrupted timed cut. Cancel, window
  close, dropdown changes, and stale or foreign browser replies cannot commit.
  The self-flow can keep either current style without canceling the whole cut.
- Other-target and clientless grooming keep the classic independent prompts.
- Cut options still use the existing species, gender and hair-growth limits.
  An eligible held razor and target are checked again at completion.
- `material_recipes_global.txt` has hygiene-gated razor rows (including copper),
  and the razor maps to the root Hygiene research node.

- Hair and beards regrow by elapsed world time, not per Life tick: one length step
  takes `HEAD_HAIR_HOURS_PER_STEP` (4) or `FACIAL_HAIR_HOURS_PER_STEP` (3) hours of
  play, and one Life call counts at most 10 seconds.
- Region travel carries `h_growth` and `f_growth` with the styles, so a shaved
  traveller does not snap back to the old body's beard length.

Manual follow-up: on a connected client, change the dropdowns, compare
front and side previews, and close without applying. Reopen, apply,
and check both completion and interruption by putting the razor away. For
barbering, verify that no bare-head preview is shown and that walking out of range
preserves the ordinary cut-wait behavior. The portrait intentionally omits
headwear and is an approximation of unusual in-world face overlays. Offline checks do not exercise BYOND browser delivery.
