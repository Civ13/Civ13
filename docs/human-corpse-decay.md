# Human corpse decay

Implementation in progress. Dead human bodies warn after two natural season changes and become remains after four. Maps without a running seasonal cycle use six and twelve running-server-hours instead. Remains begin a fresh phase with the same thresholds. Forced admin transitions preserve age unless explicitly requested.

Revival clears decay. Real relocation and preservation reset exposure; no-op movement does not. Bodies in containers, carried, pulled, buckled, thrown or in nullspace are protected. Restart preserves elapsed exposure; offline time does not count. Useful released gear is not opted into destruction. Failed native gear release prevents corpse retirement. Existing headed-corpse zombie reanimation is preserved on zombie maps.

Extraction owns its accounting and death-room cleanup. The corpse lifecycle releases actual root items and nested contents without cloning or journal credit, then emits the inert `corpse_retired(body, turf)` hook before retirement.
