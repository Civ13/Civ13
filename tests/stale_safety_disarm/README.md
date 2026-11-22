# Single-shot safety and stale mine disarms

Covers #6697 (the single-shot `special_check` override skipped the safety, so the
Barrett M99 fired with its safety on) and #6705 (a disarm wait did not track the
mine, so a stale attempt could disarm or trigger a mine that had been moved and
re-armed).

- Native: `python3 tests/ecology_spawning/run_linux.py . tests/stale_safety_disarm/probe.dm 300`
- Offline: `python3 tests/stale_safety_disarm/test_sources.py`
