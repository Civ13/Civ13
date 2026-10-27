# Finite hydraulic fracturing

Run `tests/resource_extraction/run.ps1 -ByondBin <516.1681-bin> -Probe tests/hydraulic_fracturing/probe.dm`.

The fixture compiles production sources with ordinary world startup disabled,
uses temporary storage, and closes the runtime port. It checks bounded callback
restarts, 300 cable demand, exact batch costs, permanent terrain conversion,
same-kind turf replacement cancellation, rejected short/contaminated inputs,
native sprite states and disk-backed stopped reload with contained inputs.
It does not establish graphical interaction, full-world persistence or long-term
production memory. BYOND can contact its authentication service before startup
closes the port.

The rig uses the existing conventional mining drill sprites. Hydraulic Fracturing
is a Modern research node requiring Electricity and Modern Construction. The
recipe uses twenty electronics and the inherited twenty-steel drill requirement.
Load one pure-water barrel, one empty or petroleum-only barrel and raw sand.
Anchor adjacent to mineable underground rock and connect 300 cable power.
After two minutes, one batch consumes that rock tile, twenty water and five sand
for fifty petroleum, then stops. Unload Fracking Rig releases contained items.
This terrain-consuming game abstraction is separate from renewable oil springs.
