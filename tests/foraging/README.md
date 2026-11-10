# Foraging validation

Offline, no engine or server:

```sh
python3 tests/foraging/test_contract.py
```

After installing the repository-pinned BYOND, compile the whole game first.
The existing fixture executes production helpers with ordinary startup disabled:

```sh
python3 tests/ecology_spawning/run_linux.py . tests/foraging/probe.dm
```

**The runner starts DreamDaemon with `-trusted`; obtain maintainer authorization
before executing it.** It binds no public port. No native execution is claimed
by the offline suite or by this checked-in probe.

Probe covers disabled default, shared and neighboring patches, finite depletion,
terrain replacement, field export, malformed stock and persistence fences. It
is not a full save/load roundtrip or a test of client UI and timed cancellation.
See docs/foraging.md for the mandatory activation matrix and follow-on phases.
