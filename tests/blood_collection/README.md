# Blood collection probe

Native probe for #6239, run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/blood_collection/probe.dm

- Blood collects into an empty container and keeps its donor and type.
- A second donor is refused and loses no blood, so held blood is never
  relabelled with another donor's type.
- The same donor can keep filling the container.

The refusal checks fail on the unfixed source. `test_sources.py` is the
offline contract for the guard and the IV drip's refused-collection path.
