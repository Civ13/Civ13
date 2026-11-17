# Stack count probe

Headless checks for the count shown on stacked items in inventory slots
(`code/modules/storage_window/stack_count.dm`): the figures for each count,
when a number is shown or cleared, shared badges, the full-stack colour, the
immediate hooks, the per-tick sweep and that nothing of it is saved.

```
python3 tests/ecology_spawning/run_linux.py . tests/stack_count/probe.dm
```

The glyph sheet is checked with `python3 tests/sprites/create_stack_count.py --check`.
