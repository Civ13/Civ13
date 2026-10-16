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
Normal map/controller startup and networking are disabled. The probe is not a
connected-player test, full-map performance benchmark, or fresh-process expanded
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
