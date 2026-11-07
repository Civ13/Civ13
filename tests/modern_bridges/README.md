# Modern bridges

Steel and concrete bridge spans (`code/modules/1713/bridges.dm`) lay a deck
over any water, including the deep sea where wooden floors sink. Roads and
railway track go on the deck; road vehicles drive over it.

```sh
python3 -B -m unittest discover -s tests/modern_bridges -v
python3 tests/modern_bridges/run.py --byond-bin <pinned bin> --evidence-dir <fresh dir>
```

`run.py` compiles the full DME without maps through the existing
`isolated_startup` adapter and runs `probe.dm` on a 20x8 map with a strip of
deep saltwater: where a span may be built (from the shore or the deck, not
from dry land, diagonally, over an existing cover or while swimming), decks
covering the water without sinking, rails on the deck joining the rail network
to the map edge, track falling into the sea when a deck is destroyed, and
taking a bare deck apart. The `do_after` wrappers, item use and messages are
not driven.
