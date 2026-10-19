# Linked building levels

Run with pinned BYOND 516.1681:

```
<verified-python> tests/building_levels/run.py --byond-bin <bin> --output <empty-directory>
<verified-python> tests/building_levels/run.py --byond-bin <bin> --negative-control pair --output <empty-directory>
<verified-python> tests/building_levels/run.py --byond-bin <bin> --negative-control support --output <empty-directory>
```

The offline native world runs production slab allocation, roof/covers constructors,
support resolution, paired removal, wall/door support removal, save-overlap
collapse retry, and per-level disk entry saves/restores.
Normal map/controller startup is disabled. The probes close the native port in
world.New(); this does not provide OS network isolation or prevent the native
listener before world.New(). The probe is not a connected-player test,
full-map performance benchmark, or fresh-process expanded
world restoration test. The latter depends on the saved-dimension bootstrap work.
Do not enable this feature on a persistent public host before that dependency is
merged and its full restart contract passes.

A roof builder adds a linked floor on the level above. Floor covers placed over
open air add the matching roof below. Ground-level floor finishes retain their
existing behavior. Existing mapped roofs and tent canopies are not converted.
Grounded wood supports permit two storeys, stone/clay four, concrete six, and
metal eight; all supporting levels must have sufficient strength. Wall reach is
one tile, stone pillar/wall turf two, timber roof pillars three, and doors support
their own tile. Removing a support schedules the normal roof collapse check;
removing either slab face removes its partner and exposes the floor opening.

New levels are open air, with no broken-floor render registry. Expansion is
bounded to 32 total levels, eight added levels, and two million cells per added
level. Native BYOND allocates the default turf synchronously; replacement is
budgeted across ticks. These bounds do not establish low latency on large maps.

The focused lighting-gravity mode uses actual lighting startup, native turf
replacement, and production forceMove/Entered. It records the replacement
callback separately from the explicit entry challenge. An ordinary anchored
item and an ordinary mob must still fall. The mutation removes only the renderer
exemption; it must fail on renderer entry, with the physical payload checks intact.

```
<verified-python> tests/building_levels/run.py --source-check --lighting-gravity
<verified-python> tests/building_levels/run.py --lighting-gravity --byond-bin <bin> --output <empty-directory>
<verified-python> tests/building_levels/run.py --lighting-gravity --negative-control lighting-gravity --byond-bin <bin> --output <different-empty-directory>
```

This mode does not establish first-roof allocation timing, missing-corner repair,
duplicate-overlay cleanup, torch behavior, or client rendering. A passing explicit
entry check must not be described as proof of the incident's natural trigger.

The separate first-roof probe starts at z1, calls production lighting startup,
constructs the actual supported roof to allocate z2, checks every ground tile
for one overlay, then switches an actual torch on/off through update_icon and
drains the production light queues. It records upper renderer/corner state
without claiming the gravity fix supplies missing upper corners.

```
<verified-python> tests/building_levels/run.py --lighting-roof --byond-bin <bin> --output <empty-directory>
<verified-python> tests/building_levels/run.py --lighting-roof --allocation-interleave --byond-bin <bin> --output <different-empty-directory>
<verified-python> tests/building_levels/run.py --lighting-roof --allocation-interleave --negative-control lighting-gravity --byond-bin <bin> --output <different-empty-directory>
```

The explicit allocation-interleave adapter pauses for six ticks immediately
after native maxz expansion so real delayed lighting can run before replacement.
This proves or rejects that scheduling path; it is not evidence that a tiny
unadapted allocation naturally yields for that duration. The controls neither
inject a black renderer nor replace Entered or the turf.New content loop.

The existing linked-building CI step runs all five lighting profiles when this
suite is selected. New executable tests select the suite on pull requests;
existing-suite reruns also remain available through the existing regression inputs.
