# Airship sheets

## `probe.dm`

A native probe for `code/modules/naval/air_draught.dm`, `air_draught_checks.dm`
and `airship_yard.dm`. It checks that the three ready-made sheets pass their
checks and read back from their design codes, and that bad codes are refused
(an unknown deck, a tile off the sheet, an engine too big, a sheet too wide).
The sheet must be a draught kind with a pasted-code name. Each `air_sheet`
check must fire: no helm, a deck in pieces, no gas cells, too big a crew, an
engine with no tank, and a tank with no engine. Every key needs a part
description. The airship yard is gated on Lighter-than-Air Flight, refuses an
engine sheet without the Combustion Engine, takes plastic and holds 1200
cloth. It lays and commissions the scout airship facing north, with all of
her deck, empty cells, the engine connected to an empty tank and its stock
spent. Her deck blocks the next build, and her lines draw back onto a sheet
tile for tile.

    python3 tests/ecology_spawning/run_linux.py . tests/airship_sheets/probe.dm 300
