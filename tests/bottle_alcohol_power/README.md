# Bottle alcohol-power offline regression

Run `py -3 -m unittest discover -s tests/bottle_alcohol_power -v` on Windows
with a verified Python launcher, or `python3 -m unittest discover -s
tests/bottle_alcohol_power -v` on other systems.

The suite projects both complete production DM procedures using the existing
`tests/save_movement/source_adapter.py` subset with fake reagent/type boundaries.
It checks both holders, missing and empty holders, non-ethanol, strength limits,
volume weighting, input preservation, and sequential accumulation. Two source
mutants confirm that the tests detect a changed lower limit and a dropped rag.
The floating-point order case uses Python arithmetic to expose regrouping; it is
not a claim about BYOND's numeric precision. This is offline source evidence,
not a DM compile, native engine run, gameplay, or server test.
