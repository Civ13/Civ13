# Worn tools

Tools built into wearable gear (`code/modules/1713/worn_tools.dm`).

    python3 -m unittest tests/worn_tools/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/worn_tools/probe.dm

The probe checks reaching a worn tool (other hand, belt pouch, never a
backpack), the striker sparking from a worn flint with the other hand full,
which garments take boot and sleeve sheaths, the small-knife rule, drawing a
knife by clicking the worn boot, and old hidden boot knives dropping on load.
