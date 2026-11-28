# Razor grooming

Offline source checks, run by the `razor_grooming` suite in `scripts/ci_baseline.py`:

    python3 -m unittest discover -s tests/razor_grooming

Server side of the Haircut window on the pinned engine, without a client:

    python3 tests/ecology_spawning/run_linux.py . tests/razor_grooming/haircut_probe.dm 300

The window's own behaviour is `tgui/src/interfaces/Haircut.test.tsx`.

- The razor grooms on any intent except harm when aimed at the head, eyes or mouth.
  Harm still falls through to the normal knife attack.
- A connected player gets the Haircut window for their own hair or a neighbour's:
  the whole figure from four sides without headwear, every eligible style as a
  picture, and one Start cutting button. Browsing sends nothing. Style and growth
  only change after an uninterrupted timed cut; either style can be kept.
- The window sends one shared style sheet (built once per server run) and one
  figure picture per opening. It closes itself when the razor leaves the hand or
  the two step apart, and has no time limit otherwise.
- Clientless actors keep the classic independent prompts.
- Cut options still use the existing species, gender and hair-growth limits.
  An eligible held razor and target are checked again at completion.
- `material_recipes_global.txt` has hygiene-gated razor rows (including copper),
  and the razor maps to the root Hygiene research node.

- Hair and beards regrow by elapsed world time, not per Life tick: one length step
  takes `HEAD_HAIR_HOURS_PER_STEP` (4) or `FACIAL_HAIR_HOURS_PER_STEP` (3) hours of
  play, and one Life call counts at most 10 seconds.
- Region travel carries `h_growth` and `f_growth` with the styles, so a shaved
  traveller does not snap back to the old body's beard length.

Manual follow-up: on a connected client, open the window on yourself and on a
neighbour, turn the figure, compare Now with After the cut, close without
cutting, then cut and check both completion and interruption by putting the
razor away. Offline checks do not exercise BYOND browser delivery or the
window's drawing in the game client.

The same native probe clicks the character with held cloth on Help intent.
It substitutes the colour prompt only and checks colour knowledge, independent
scalp and facial RGB, material cost and cancellations, including dropping the cloth.
