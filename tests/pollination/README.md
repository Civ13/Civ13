# Pollination probe

Native probe for `code/modules/1713/pollination.dm`: crops that need insects
(fruit, beans, cotton, flax and the like) roll for one extra crop at harvest
when an occupied bee colony is within five tiles. Kept hives count by their
strength, occupied wild nests as a middling colony, and the frame apiary by its
bee count. Grains, grapes and olives never gain anything.

Run after a fresh compile:

    python3 tests/ecology_spawning/run_linux.py . tests/pollination/probe.dm 300

The probe checks the crop list, the no-bees case, colony reach and strength,
the chance curve, the farmer's examine notes, the extra apple rate from a full
colony, the stacked cotton portion and the empty wild nest case.
