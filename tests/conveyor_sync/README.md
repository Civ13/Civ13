# Conveyor line sync

`test_sync.py` checks offline that a belt placed or replaced on a linked line takes its switch's run state, and that a hydroponics tray can be drained in place.

The native probe places linked belts beside a running, reversed and stopped switch and replaces a straight belt with a corner on a running line:

```bash
python3 tests/ecology_spawning/run_linux.py . tests/conveyor_sync/probe.dm
```

Drain behaviour runs natively in `tests/hydroponics/probe.dm`.
