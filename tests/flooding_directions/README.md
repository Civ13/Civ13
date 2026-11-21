# Flooding direction reuse

Run `python scripts/ci_baseline.py unit --suite flooding_directions --output .ci/flooding-directions.json` with a verified Python interpreter.

The stdlib-only test projects the two production water-transfer loops with injected turf, registry and direction boundaries. It compares a checked-in pre-change loop fixture against production for bulkheads, doors, four orientations, destroyed and closed openings, owner boundaries and sealed targets. An asymmetric opposite-side layout detects reversed direction order through different water and callback traces. The production loops add water to the receiving tile without draining the source; that behavior is preserved.

Source checks restrict the change to private static storage for the ordered cardinal list. This is offline control-flow evidence, not native BYOND list or flooding acceptance. The pinned full-game compiler checks the static declaration. No native runtime or performance comparison is included. Existing `tests/space_settlement/probe.dm` supplies native bulkhead cases if separately admitted with the required isolation.
