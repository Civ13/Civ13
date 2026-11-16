# Storage window probe

Headless checks for the storage window's server side
(`code/modules/storage_window/storage_window.dm`): move times, what the window
lists, the lock hook, moves between the floor and a basket, the timed queue,
Take All and searching.

```
python3 tests/ecology_spawning/run_linux.py . tests/storage_window/probe.dm
```

The screen itself is covered by `tgui/src/interfaces/StorageWindow.test.tsx`
(`cd tgui && npm run check`).
