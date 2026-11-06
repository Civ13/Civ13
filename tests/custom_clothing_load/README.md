# Custom clothing across a world save/load

`python3 tests/custom_clothing_load/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and runs Save_World, ClearMap and
Load_World on a 6x4x1 world with a dyed toga, a dyed three-part dress, a dyed
officer cap, an undyed dress, a dress an older restore had already reset, and a
tunic with a scarf and a holster attached.

Dyeable clothing marks itself ready to dye (`uncolored`/`uncolored1` TRUE) five
ticks after it is made, and dyeing sets the flag back to FALSE. That timer ran
in `New()`, so it also ran on every restore; the saver omits the FALSE default,
so each load turned dyed clothing back to "undyed" and the worn sprite lost its
colour layers (Gaia, 2026-11-06). The timer now runs in `on_runtime_spawn()`
and `after_load()` repairs garments a save already recorded in that state.

Verbs are not saved, so a restored garment also lost "Remove Accessory" (and the
holster and sheath verbs), leaving its accessories stuck. `after_load()` rebuilds
them from the saved accessories list.

Negative controls, each must fail: `--negative-control dye-flag-in-new`,
`no-dye-repair` and `no-verb-rebuild`.
