# Flashlight eye exam probe

Native probe for #6253, run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/flashlight_eyes/probe.dm

- Shining a lit flashlight in another patient's eyes reports their pupils.
- You cannot read your own pupils.
- A patient without eyes stops the exam with a message, before any eye
  damage is read.

Messages are read through the agent-character capture hook. The first two
checks fail on the unfixed source. `test_sources.py` is the offline contract.
