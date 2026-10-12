# Human corpse decay

Dead human bodies eventually leave human remains. Each exposed phase warns after two natural season changes and retires after four. Maps without an active seasonal cycle use six and twelve running-server-hours. Bones begin a fresh phase when the corpse retires, then disappear on the same schedule. Offline time does not count. Forced admin season changes preserve decay progress unless the admin explicitly advances it.

The warning leaves a recovery/revival window. Revival or rejuvenation immediately clears the corpse clock. Real relocation resets exposure; a movement callback that leaves the body in the same place does not. Bodies and bones inside any container or mob are protected, including morgues, coffins, closets and vehicles. Pulled/thrown bodies and buckled bodies are protected when checked. Protection grants fresh exposure; bones containing any objects are also protected. Bodies in nullspace do not expire. The process checks at most 32 registered candidates every 30 seconds, so a large backlog may delay cleanup; it never advances expiration.

## Gear preservation

Retirement uses normal inventory removal on the same actual root items. Bags retain their contents, guns retain attachments/ammunition, and item identity/raid/insurance metadata is not cloned or changed. Removing a uniform can release its dependent pockets, belt and ID through the existing native cascade; those roots are not dropped twice. Useful gear does not become abandoned waste merely because its carrier dies.

A body remains intact if any root is nodrop, anchored, blocked by its native nodrop check, a non-gear passenger, or a loose organ outside its own anatomy lists. Bodies with more than 256 direct contents are retained to keep each retirement bounded. A later native drop failure, revival, relocation or cancellation aborts retirement before the body is deleted. Some already released gear may remain outside a body when a native callback cancels the operation. Body deletion only begins after every non-anatomy root has left.

## Restart and special outcomes

Saved corpses retain dead state, damage, elapsed hours/season progress and nested inventory. Saved bones retain their phase progress. The loader rejuvenates live humans as before, but does not rejuvenate saved DEAD humans or replay death hooks. Runtime registry entries and old timer/counter epochs are excluded from saves and rebuilt after loading. Missing/corrupt dead-state values follow the existing live rejuvenation path and do not create death from elapsed-age fields.

On zombie maps, a headed corpse outside the Caribbean admin area keeps its existing zombie reanimation outcome at retirement instead of producing bones. Headless corpses produce bones. Static decorative remains are excluded from expiration; only remains created by human retirement opt in. The old delayed crow/second-rot timers are replaced by the warning and retirement phases.

## Integration and verification

`do_rotting()` is idempotent for a DEAD human. Successful gear release emits the optional `corpse_retired(body, turf)` hook immediately before normal mob retirement. Listeners observe this physical event; it does not settle an extraction journal, credit a loadout, or return insurance. Extraction owns its session/accounting cleanup and must delegate physical corpse cleanup instead of deleting a loaded corpse on a separate timer.

[Native regression and bones sprite preview](../tests/human_corpse_decay/README.md) covers real production human/inventory/revival/death/persistence/GC paths in an isolated 4x4 world using BYOND 516.1681. It tests dropped-root identity/nested metadata and an inert retirement listener. Full extraction account/insurance settlement belongs to its separate integration tests. These bounded fixtures do not prove connected-client ghost transfer, production behavior or long-running full-game memory stability.
