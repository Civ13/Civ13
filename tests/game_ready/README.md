# Game-ready offline contracts

Only test_release.py, test_ready.py and test_hooks.py are registered. No wildcard
native discovery or native runner is imported. model.py reads production DM and
the existing private source adapter; all clocks, backend objects, allocation and
Export effects are synthetic. urllib.parse is used only to inspect fake query
strings. No subprocess, HTTP client or live files are used.

The legacy_load_completion.dm fixture is the complete old success tail from
4807504b03f1d620385ae922b9e2e6ab92a545c4. It demonstrates the prior false success
when operation release was rejected. The current completion tail is projected
without omitted instructions, with the global startup observation field mapped
to an injected object. The producer module's complete selected methods and
helpers use the private lexical mappings described in docs/game-ready-webhook.md.
No test reads Git history.

Tests cover disabled defaults, both latch orders, startup token and exact load
ownership, legacy/stale identities, no late manual acquisition, restart/player
completion, consumption-only retry, all recovery holds, duplicate completion,
three-attempt admission and an unresolved/late Export boundary, ACK status/hash
and no body read. Hook mutation controls reject early readiness callbacks.
These results do not establish engine timing, real network or player reachability.

Use the repository's pinned compiler/normal CI after source review. New native
execution or real endpoint activation remains separately held.
