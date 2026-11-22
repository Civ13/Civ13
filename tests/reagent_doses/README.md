# Reagent dose probe

Native probe, run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/reagent_doses/probe.dm

- #6295: an overdose handler receives the amount metabolized this tick, so
  a crack overdose causes dose-scaled brain damage.
- #6310: iced beer cools by its rate (310 K to 280 K) and stops at 270 K.
- #6312: one unit of charcoal binds three units of poison in total across
  every toxin, not three of each.
- #6335: eye-slot goggles that cover the eyes keep pepper spray out.
- #6738: the same goggles also keep a dropper out of the eyes.

One check for each issue fails on the unfixed source. `test_sources.py` is
the offline contract.
