# Crown inlay

Setting a diamond into a gold or silver crown (`code/modules/1713/apparel_medieval.dm`).

    python3 -m unittest tests/crown_inlay/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/crown_inlay/probe.dm

The probe checks that a cut diamond and a refined diamond sheet both turn a
plain crown into an inlaid one (one stone used, held crowns stay in hand), a
rough diamond is refused without being used, other stones fall through to
chisel gem setting, and a crown already set with a stone is not inlaid.
