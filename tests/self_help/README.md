# Self-help when hurt

```
python3 tests/self_help/run.py --byond-bin <pinned bin>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless. It checks pushing yourself back up from a knockdown (who can, how
long it takes, the cooldown, and that it really stands you up), holding a
bleeding wound with a free hand (the aimed limb, falling back to the worst
reachable bleed, one bleed per hand, moving a hand, letting go when the hand
fills) and makeshift rope or twine tourniquets (they only slow bleeding unless
a hand holds the wound, slip loose after a while and can be replaced by a
proper gauze tourniquet).

Timed actions that need a client progress bar (tying a tourniquet) are not
covered; the get-up attempt runs without one.
