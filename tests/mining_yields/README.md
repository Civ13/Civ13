# Destructive and renewable yield comparison

Run the resource extraction launcher with `-Probe tests/mining_yields/probe.dm`
and an explicit BYOND 516.1681 bin directory. The launcher substitutes only the
production mining procedure's random calls with deterministic fixture adapters;
its branch bodies, era/map/climate gates, item creation and terrain conversion
remain production code. Both random endpoints are checked across eras 0-8.

Coverage includes copper/tin, era-gated iron and four fuels, silver/gold/diamond,
icy fossils, sandstone and surface desert, general and semiarid marble, jungle
obsidian, fallback stone, Antarctic fuel exclusion and special-cave examples.
The separate extraction fixtures establish renewable one-unit manual and two-unit
powered batches. Destructive overlapping mineral batches exceed those traces;
fossils explicitly yield one (or two in special caves) and are not a renewable
resource. This is branch coverage, not a probability/distribution benchmark.
It does not launch ordinary game systems or establish graphical acceptance.
