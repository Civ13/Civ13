# Food toxin log

Checks the logging that explains why an eater got food poisoning or another
toxin: source item, amounts, route and recorded cause.

- `python3 tests/food_toxin_log/test_source.py` checks the wiring (swallow hook,
  raw-food bite roll, contamination sites, origin carried by transfers, agent
  `logs` kind `food`).
- `python3 tests/food_toxin_log/run.py --output <dir> --byond-bin <bin>` compiles
  the unchanged production `food_toxin_log.dm` with small stubs and runs it in
  DreamDaemon (cause text, dedup, bounded ring, log line contents).

Not covered: a real meal in a full world; that needs a native game run.
