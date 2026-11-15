# One floor and one wall per tile

A tile holds at most one floor cover and one wall piece (wall cover, door,
window frame or wall frame). Builders are refused while the tile is taken and
pay nothing; a floor comes up with a hammer. A wall may stand on a floor, and a
door may hang once in a doorway or archway. The rule lives in
`code/game/objects/tile_occupancy.dm`.

```
python3 -m unittest tests/tile_occupancy/test_sources.py
python3 tests/tile_occupancy/run.py --byond-bin <dir with DreamMaker/DreamDaemon>
```

`run.py` compiles the committed sources (`git archive HEAD`) with the probe and
runs it in DreamDaemon. The probe builds through the real crafting path
(`produce_recipe`) with research gates passing, and lays brick, cement, dirt and
snow wall foundations. It is not a connected-player or save/load test; mapped
tiles that already hold two floors are left as they are.
