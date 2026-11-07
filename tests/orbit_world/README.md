# Orbit world

```
python3 tests/orbit_world/run.py --byond-bin <pinned bin> --output <empty directory>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless on an 8 x 8 x 5 vacuum world with the orbit map settings. It
checks the plane registry (made on plane 1, arrival plane owned and never
released), claims taking the lowest free plane, links both ways and refusing
a side already taken, `multiz_level_above/below` following deck links, a
seam moving an item to one tile inside the linked neighbour and leaving it at
an unlinked edge, ladders pairing across linked decks, the sparse save kind
(`orbit` for every plane but the first, with a vacuum baseline), the durable
profile, and release cutting every link.

Not covered: a real save and restore of an orbit world, connected clients and
seams crossed by players.
