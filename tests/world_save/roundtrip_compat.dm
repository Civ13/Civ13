// Current loader dependencies for the ordinary roundtrip world only.
// Shared stubs remain independent; receipts bind their actual versioned bytes.
// Shared stubs supply roof-area and clear-ground declarations. There are no
// roof objects/climate simulation here; actual topology restoration is refused.
// Only the roundtrip storage subtype admits null validated_zone_state before
// inspecting operation ownership, like production. Every present state still
// delegates to the shared parent refusal, including an empty topology list.

// Match the production registry's ordinary (non-topology-restore) membership.
// The fixture uses immediate del(), not the game's qdel/Destroy lifecycle.
// Explicit empty instances must remain discoverable by the real roof finder.
/area/New()
	..()
	area_list |= src
/area/Del()
	area_list -= src
	..()

/map_storage/roundtrip_fixture/begin_zone_restore(datum/persistence_world_operation/operation)
	if(isnull(validated_zone_state)) return
	return ..()
