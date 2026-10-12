# Direct nuclear fallout scope

`run.py --byond-bin <BYOND-516.1681-bin>` extracts the current production
`nuke_map`, `radiation_pulse`, turf and human radiation procedures. Native BYOND
executes their range traversal and delayed stages in a 140x4x2 offline world.
Explosion, camera, logging, plant response and turf replacement are isolated
adapters. The fixture closes its listening port and writes only temporary files.

Checks cover contained/null epicenters, near/far same-level fallout, untouched
other-level registries/windows/plants/mobs, the actual human interior/outdoor
dose and SSD exclusion, replacement-turf irradiation, independent repeated
events, and bounded pulse duration/radius/z behavior. Each direct stage applies
once per event. The global +310 remains intentional and is explicitly checked.

Run `--negative-control cross-z` and `--negative-control normalization` to verify
that generated source copies restoring those defects fail fixture assertions.
They never modify production files. The runner requires clean pinned compilation
and rejects runtime errors in every mode. Each negative control requires its
specific ordered assertion failures and a single separate completion marker.
Assertions accumulate rather than deleting the world midway through its startup
procedure. The normalization control finishes at an immediate pre-callback
checkpoint; the cross-level control also checks the repeated event.
`--output-dir <fresh-path>` retains generated source, source hashes, exact HEAD,
compile/runtime logs and successful result metadata outside runtime storage.
Without that option a fresh persistent temporary evidence directory is used.

This checks direct fallout scope, not blast damage, graphical acceptance,
full-server performance or production survival. The real explosion engine can
propagate to adjacent levels and is deliberately replaced here. Terrain RNG,
stage delays, severity conversions, background radiation and same-level mapwide
catastrophe are preserved. No batching or timing changes are introduced.
