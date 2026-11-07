# Berries across a world save/load

`python3 tests/berry_load/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled, picks tinto, amar, majo and azul
berries under one berry configuration on a 4x1x1 world, runs Save_World, swaps
in a different configuration (a restart's fresh map controller rolls one before
the save is read), then runs ClearMap and Load_World.

Each world rolls which berry is poisonous, a drug, healing, tasty or disgusting
when its map controller is made. The world save keeps that roll
(`berryeffects` in the durable map metadata), but objects load before the
metadata, so a picked berry that applied the roll in `New()` took the fresh
boot roll on every restart: a neutral berry could come back tasty. Restored
berries now keep what they were picked with.

The smell notes in Character Notes compare a hash of the configuration. The
metadata graph gives each restored row entry a null association, so the hash
changed after every restart and every note read "the world's berry
configuration has changed". The hash now uses plain copies of the rows.

Negative controls, each must fail: `--negative-control effect-on-restore` and
`context-from-raw-rows`.
