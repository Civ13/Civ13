# Roofs after a world load

`python3 tests/roof_support_load/run.py --byond-bin <BYOND-bin>` compiles the
production game types and persistence code with normal startup disabled and
runs a synthetic 12x8x2 world through Save_World, ClearMap and Load_World.

Roof support: plain roofs at the edge of a wood support, stone pillar and wall
cover, a roof read before its support, constructed roofs paired with an upper
floor, and a second storey all still stand after the load. A roof saved without
support still collapses, and a new roof next to a restored support is buildable.

Roof visibility: roof overlays are client images. A restored body used to keep
`roofs_removed = FALSE` from the client it had at save time, so a reconnecting
player outdoors never received any roof images and every roof looked gone. The
probe drives `sync_static_roofs` with a fresh viewer and image list.
`--negative-control viewer` removes the new-viewer reset and must fail with
`reconnected viewer outdoors sees restored roofs (0/N)`.

Not covered: a real connected client, rendering, or the live image added to
outdoor players when a new roof is built.
