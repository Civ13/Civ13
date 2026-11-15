# Rock art

Code: `code/modules/1713/rock_art.dm`, on top of the painting editor in
`code/modules/paintings/`. Tests: `python3 tests/rock_art/test_source.py`; native probe
`python3 tests/ecology_spawning/run_linux.py . tests/rock_art/probe.dm`.

Players paint straight onto natural rock (`/turf/wall/rockwall`, so cave walls and cliffs) with
the ground pigments from `paintings.dm`: charcoal, red ochre (iron ore), yellow ochre (clay)
and bone white, ground in the stone mortar. Nothing else is needed, so it works from the first
day.

- Stand straight in front of the rock and use a pigment on it. This places an
  `/obj/structure/rock_art` on your tile facing that rock, holding an `/obj/item/canvas/rock`
  (32x32, no easel), and opens the editor. Using a pigment there again reopens an unfinished
  one; a finished one has to be scraped off first.
- Only someone standing on that tile can paint it (`painting_can_reach`).
- The canvas base colour (`#887766`) is left transparent, so only the paint shows on the stone,
  at alpha 215 to look worn into the rock.
- Finished rock art counts half a painting toward the region cap and appears in the admin
  Player Art list like any finished canvas. Examining it, or using it with an empty hand, shows
  the full painting.
- A chisel or hammer scrapes it off (8 s, logged).
