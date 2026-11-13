# Ides of March probe

`run.py` checks the Ides of March TDM map and mode.

- Map source: `maps/313bc/ides_of_march.dmm` must equal what
  `tools/ides_of_march/make_map.py` writes, with the map metadata, both sides'
  spawn landmarks, the Curia doorway invisible walls and an entry in the
  pre-firearms vote list. Change the layout in the generator, not the map.
- Mode: compiles the production game plus `probe.dm` and checks the jobs
  (map, spawn landmark, side), the Latin-speaking conspirators, the pocketable
  pugio and the win check `caesar_fallen()`.

```sh
python3 tests/ides_of_march/run.py --byond-bin /path/to/byond/bin
python3 tests/ides_of_march/run.py --byond-bin /path/to/byond/bin --negative-control immortal-caesar   # must fail
```
