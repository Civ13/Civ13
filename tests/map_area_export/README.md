# Map area export round trip

Checks `code/modules/admin/map_area_export.dm`, the admin tool that writes a
rectangle of the running world as a `.dmm` map.

`run.py` builds a small scene in one world (`stubs.dm` + the real exporter +
`scene.dm`), exports part of it, compiles the exported map with DreamMaker into
a second world (`stubs.dm` + `compiled.dm` + the map) and compares every tile.
Mobs, object contents, renames and runtime objects such as lighting overlays
must be left out and counted in the report.

    python3 -B tests/map_area_export/run.py --byond-bin ~/byond-516.1688/byond/bin

It needs the pinned BYOND compiler and server, downloads nothing and works only
in a temporary directory. CI runs it in the build job when this folder is new
or the run is extensive.
