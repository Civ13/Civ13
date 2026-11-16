# Razor grooming

Offline source checks, run by the `razor_grooming` suite in `scripts/ci_baseline.py`:

    python3 -m unittest tests/razor_grooming/test_razor.py tests/razor_grooming/test_hair_growth.py

- The razor grooms on any intent except harm when aimed at the head, eyes or mouth.
  Harm still falls through to the normal knife attack.
- Picking Cancel in a style prompt leaves the current style unchanged.
- `material_recipes_global.txt` has hygiene-gated razor rows (including copper), and
  the razor maps to the root Hygiene research node.
- Hair and beards regrow by elapsed world time, not per Life tick: one length step
  takes `HEAD_HAIR_HOURS_PER_STEP` (4) or `FACIAL_HAIR_HOURS_PER_STEP` (3) hours of
  play, and one Life call counts at most 10 seconds.
- Region travel carries `h_growth` and `f_growth` with the styles, so a shaved
  traveller does not snap back to the old body's beard length.

No native world, client or in-game shave is exercised.
