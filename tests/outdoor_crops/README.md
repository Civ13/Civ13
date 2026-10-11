# Outdoor crop regressions

Run `pwsh -NoProfile -File tests/outdoor_crops/run.ps1 -ByondBin <516.1681-bin>`.
Use `-Revision 9e44a2eb25945281979453b8aa060a9b1bad044b -Baseline` to reproduce
Europe's unfiltered seed dispatch and rain overflow in the prior production code.

The runner compiles the actual seed definitions and wild-seed selection/watering
procs in unique temporary storage, with minimal area/map/turf adapters. The only
instrumentation records the biome argument received by seed selection. It does
not rewrite filtering, capacity, salinity or range behavior. Seed icons and map
constants are copied from the checkout; all temporary outputs are removed.

Coverage: all eight supported biome catalogs, six climate-restricted Nomads map
IDs, fixed-era generic seed access, herbs pseudo-seed exclusion, bounded rain,
temperate/arid/heat-wave costs, freshwater/saltwater and two-tile range, empty and
flooded fresh/salt channels/trenches, storm death and mushroom water exemption.

This is not a complete gameplay bootstrap proof: it does not establish reachable
bushes, ploughs or water on every map, research/era progression, player inventory
or seasonal survival. Natural water remains an unlimited irrigation source in
the current model. Crop storage is finite; channel source volume is not modeled.
The test does not exercise channel propagation or whole-game memory performance.
