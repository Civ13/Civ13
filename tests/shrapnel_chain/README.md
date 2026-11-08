# Shrapnel chains and lag capture

`python3 tests/shrapnel_chain/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and checks that:

- a frag grenade struck by five fragments explodes and throws its fragment ring
  once (master before this fix went off once per hit, five rings);
- an AP mine ignores projectiles, and a mine clearer setting it off twice gives
  one explosion and one fragment ring;
- sustained time dilation saves one proc profile to `data/profile/`, and a second
  spike inside the cooldown saves none.

Explosions are counted through a stub `callproc` queue, so no blast runs. The
run takes about 20 seconds after compilation.
