# Optional gameplay help checks

Run Python bridge tests with `python3 -m unittest discover -s tests/player_help -v`.
All storage is temporary and HTTP is an injected transport; no remote Ollama calls.
The transport deadline test verifies the child-process timeout contract, not a
network benchmark. Cases cover identity reuse, no replay, disabled/failure,
bounded answers, no source metadata and exclusive worker ownership.

Run `run.py --byond-bin <516.1681-bin>` and repeat with
`--negative-control escaping`, `heartbeat`, and `identity`. These compile the
actual production DM help service with minimal process/global adapters and no
normal world startup. The native fixture verifies heartbeat startup/expiry,
malformed files, escaped HTML, request identity and disconnected-slot cleanup.
It closes its port immediately and uses isolated disk files.

There are no authenticated clients in this fixture: actual input/browser delivery
and client timeout notification are source-reviewed, not graphical acceptance.
No remote endpoint, deployed bridge or model knowledge is tested. Game compilation
is separate; screenshots are unnecessary for these file/protocol contracts.

CI selects this suite when its executable tests are newly introduced by this PR,
or when extensive regressions are explicitly enabled. Ordinary future edits do
not enable existing regressions automatically.

The native probe checks season/time, asking-human condition, active fire and detached fresh snapshots. `--negative-control player-context` replaces real health with a constant and must be rejected. Bridge tests verify the final prompt carries projected context while excluding identities, diagnoses, unrecognized effects, booleans used as numbers and nonfinite values. These are production-path fixtures with minimal human/area adapters, not client or complete-world acceptance.

The combined inventory budget probe counts entry and child visits in a generated
copy of production code. A bag with 70 non-item children must stop at exactly 64
combined inspections; `--negative-control inventory-budget` restores the faulty
doubled-child counter and must fail that boundary assertion.
