# Wildlife sub-tile restore probe

Native probe for issue #4207. An animal that free movement admitted
automatically (a player was near) is saved between two tiles through the real
save codec, then loaded and checked:

- the offset restores and the automatic admission comes back with it;
- with nobody near, it walks back onto its tile, releases free movement and
  takes ordinary tile steps again;
- with a player near, it keeps moving freely;
- a blocked offset restores aligned and the animal still walks;
- no admission or watch cache is written to the save.

Run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/wildlife_restore/probe.dm

Without the fix, nine of the thirteen checks fail: the restored animal never
moves again.
