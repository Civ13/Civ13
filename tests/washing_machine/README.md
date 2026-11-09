# Washing machine probe

Native probe for issue #4215: a completed washing machine cycle clears clothing
fleas the way washing at a sink does.

Run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/washing_machine/probe.dm

Checks: infested and uninfested clothing after a completed cycle, and clothing
removed or destroyed before the cycle finishes. The `start` verb also returns
without finishing the cycle when the machine itself was destroyed mid-wash.
