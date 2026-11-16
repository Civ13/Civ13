# Bee products probe

Native probe for the bee veil and beekeeper suit (`code/modules/1713/bee_gear.dm`
and `bee_sting_chance()` in `wild_bees.dm`), sealing wax
(`code/modules/1713/sealing_wax.dm`) and mead must fermenting in a closed barrel
(`code/modules/1713/mead.dm`).

Run after a fresh compile:

    python3 tests/ecology_spawning/run_linux.py . tests/bee_products/probe.dm 300

It checks the sting chances with each piece of gear, wax colour and uses,
envelopes and paper needing wax for a wax seal (but not for an ink stamp), the
last seal using up the stick, the pitch requirement, honey and water making must
instead of mead, and wild-yeast and yeast fermenting in an open and closed barrel.
The sealing wax colour prompt is not driven here (the probe body has no client).
