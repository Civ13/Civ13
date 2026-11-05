# Razor grooming

Offline source checks, run by the `razor_grooming` suite in `scripts/ci_baseline.py`:

    python3 -m unittest tests/razor_grooming/test_razor.py

- The razor grooms on any intent except harm when aimed at the head, eyes or mouth.
  Harm still falls through to the normal knife attack.
- Picking Cancel in a style prompt leaves the current style unchanged.
- `material_recipes_global.txt` has hygiene-gated razor rows (including copper), and
  the razor maps to the root Hygiene research node.

No native world, client or in-game shave is exercised.
