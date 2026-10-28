# Primitive sawmill

The existing Resource Processing recipe builds the primitive mill from 28 wood.
Hold a sharpened flint and use it on the mill to install a blade. Use a held
ordinary log stack on the anchored mill to cut one log into one plank and one
bark; repeat for the rest of the stack. A blade breaks after 20 completed cuts
and another sharpened flint can be installed. The blade cannot be removed.

The provisional cutting time is 20 deciseconds divided by strength coefficient,
compared with the axe's 80 divided by the same coefficient for two logs into one
plank. The mill does not consume inputs on interruption. An active cut is
cancelled at save and operations are refused during persistence. Blade uses are
durable; the worker and cancellation epoch are runtime-only. Either wrench
anchoring transition invalidates an active cut, even if the mill is reanchored
before its original wait completes.

Ordinary logs use the game's existing wood-to-woodplank mapping. The mill copies
the log stack's custom appearance fields, and rejects other material identities
because no corresponding plank material mapping is defined. Large and powered
mills retain their existing processing behavior.

`tests/sawmill/test_contract.py` checks source ordering and gates offline. It
does not execute DM, reproduce concurrency, or establish a native save/restore
round trip. Those require separately authorized isolated runtime testing.
