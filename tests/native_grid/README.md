# Native cable graph comparison

Run `./tests/native_grid/run.ps1 -ByondBin <516.1681-bin>` and repeat with
`-Baseline` to compare against `aa675de6dbade0f3740c516dc4b5945c5c9a43c7`.

The runner compiles the production cable graph section with small source and
consumer adapters in unique temporary storage. Instrumentation adds counters
to a generated copy only. A 512-cable cyclic graph checks accepted reservations,
repeated draw work, scalar component identity and retained connection/reservation
entry counts. The fixture rejects listening ports and deletes its world on
completion. It uses no live services or ordinary game startup.

Queue iterations and rebuild calls measure algorithm work. They do not measure
OS memory, full-server tick latency, battery energy integration, map placement,
save reconstruction or client rendering. The existing power fixture covers
split/merge, source shutdown, engine/consumer disposal and movement. Additional
placement and whole-save checks use `./tests/native_grid/run-game.ps1
-ByondBin <516.1681-bin>`. That fixture compiles all production sources with
startup and maps isolated, then executes real inventory, paid placement, cutting,
connector lifecycle, and disk-backed world export/import. It checks current
connector ownership and migration from legacy reference lists. Test actor species
is initialized for the real inventory icon callbacks. No client rendering or
production-server load is measured.
