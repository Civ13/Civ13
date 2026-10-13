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
