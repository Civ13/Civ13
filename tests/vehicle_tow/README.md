# Tow lines between vehicles

`probe.dm` is a native probe for `code/modules/craft/vehicle_tow.dm`: two
premade cars in line, the hitch and its refusals, the towed car rolling and
turning where the tug did, the tug pulling both weights, a blocked tow paying
out and snapping, no reversing with a line out, casting off with the rope
returned, and a destroyed car letting go.

    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_tow/probe.dm 300

It expects `"failures": 0`. No client connects, so the rope click, its timed
action and the right-click verb are not exercised; the probe calls
`hitch_tow()` and `part()` directly.
