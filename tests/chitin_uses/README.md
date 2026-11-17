# Chitin uses

Crabs, trilobites and phosphor beetles drop chitin when butchered (a small crab
one, a full-grown crab or trilobite two, a beetle one; hunting skill scales it).
Chitin crafts the existing mask, helmet, armor and shields in the global
catalog, plus a chitin harpoon, chitin beads and crushed shell. Crushed shell
fertilises dirt one handful at a time and burns to quicklime in a lime kiln.

- `python3 -m unittest tests/chitin_uses/test_chitin_uses.py`: offline catalog, research
  gate and source wiring checks (registered as `chitin_uses`).
- `python3 tests/ecology_spawning/run_linux.py . tests/chitin_uses/probe.dm`:
  native probe for drops, the kiln charge and sprites. Expect
  `"failures": 0` and no runtime error. It does not exercise clicks, waits or
  connected clients.
