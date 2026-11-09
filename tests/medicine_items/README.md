# Pill and syringe probe

Native probe for #4226 and #4227, run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/medicine_items/probe.dm

- A pill used on a full container, or one without room for the whole dose, is
  refused and keeps its dose; a container with room takes all of it.
- A syringe injection stops when the patient moves away during the wait; a
  patient who stays is injected.

Both checks fail on the unfixed source.
