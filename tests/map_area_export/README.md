# Map area export round trip

Checks `code/modules/admin/map_area_export.dm`, the admin tools that write a
rectangle of the running world (Export Map Area), or every level of it (Export
Whole World), as a `.dmm` map.

`run.py` builds a small scene in one world (`stubs.dm` + the real exporter +
`scene.dm`), exports part of it, compiles the exported map with DreamMaker into
a second world (`stubs.dm` + `compiled.dm` + the map) and compares every tile.
Mobs, object contents, renames and runtime objects such as lighting overlays
must be left out and counted in the report. It then does the same for a
whole-world export of both levels of the scene.

A Gaia-sized stub world (500x350, two levels, 70,000 objects) exported in about
6 seconds with DreamDaemon peaking at 45 MB, and DreamMaker compiled the
result with 0 errors (2026-11-04).

    python3 -B tests/map_area_export/run.py --byond-bin ~/byond-516.1688/byond/bin

It needs the pinned BYOND compiler and server, downloads nothing and works only
in a temporary directory. CI runs it in the build job when this folder is new
or the run is extensive.
