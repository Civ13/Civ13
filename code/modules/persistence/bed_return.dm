// Local world ownership only; this is not a cross-shard custody authority.
/proc/persistence_bed_return_enabled()
	return map && map.uses_durable_metadata()

// Scalar ownership avoids a spatial reference from a character to another level.
/obj/structure/bed/var/persistence_bed_owner_ckey

/proc/persistence_character_turf_safe(turf/T, mob/living/human/H)
	if(!istype(T, /turf/floor) || T.density || is_protected_sleep_location(T)) return FALSE
	if(istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/lava)) return FALSE
	for(var/atom/movable/A in T)
		if(A != H && (A.density || istype(A, /mob/living))) return FALSE
	return TRUE

/obj/structure/bed/proc/valid_character_bed(mob/living/human/H)
	return !gc_destroyed && !gcDestroyed && anchored && buckle_lying && isturf(loc) && (!buckled_mob || buckled_mob == H) && persistence_character_turf_safe(loc, H)

/mob/living/human/proc/enter_saved_bed_sleep()
	if(!persistence_bed_return_enabled() || persistence_sleep_transfer_blocked() || map_storage.character_recovery_unready() || stat == DEAD || inducedSSD || !client || IsGuestKey(client.key)) return FALSE
	var/obj/structure/bed/bed
	for(var/obj/structure/bed/B in loc)
		if(B.valid_character_bed(src) && (!B.persistence_bed_owner_ckey || B.persistence_bed_owner_ckey == client.ckey))
			if(bed) return FALSE
			bed = B
	if(!bed || !isturf(loc) || (buckled && buckled != bed)) return FALSE
	// No prompt/wait or inventory drop between admission and scalar claim changes.
	for(var/obj/structure/bed/B in world)
		if(B != bed && B.persistence_bed_owner_ckey == client.ckey) B.persistence_bed_owner_ckey = null
	bed.persistence_bed_owner_ckey = client.ckey
	record_persistence_owner()
	lastx = x
	lasty = y
	lastz = z
	sleeping = 66
	inducedSSD = TRUE
	sleep_update()
	return TRUE

/map_storage/proc/character_return_turf(mob/living/human/H)
	var/obj/structure/bed/bed
	var/ambiguous = FALSE
	for(var/obj/structure/bed/B in world)
		if(B.persistence_bed_owner_ckey != H.persistence_owner_ckey) continue
		if(bed) ambiguous = TRUE
		bed = B
	if(!ambiguous && bed && bed.valid_character_bed(H)) return get_turf(bed)
	var/turf/fallback = get_turf(H)
	if(persistence_character_turf_safe(fallback, H)) return fallback
	// Old sleep-zone residents retain their existing, validated return position.
	if(H.inducedSSD)
		fallback = locate(H.lastx, H.lasty, H.lastz)
		if(persistence_character_turf_safe(fallback, H)) return fallback
	return null

/map_storage/proc/prepare_character_return(mob/living/human/H)
	if(!persistence_bed_return_enabled()) return TRUE
	if(character_recovery_unready()) return FALSE
	// The restored-body claim is consumed only after successful key handoff.
	// Keep persistence_restored for delayed customization suppression; it does
	// not mean that this body's first return is still pending. Ordinary bed sleep
	// is not a teleport request either. Legacy physical zone residents must exit.
	var/list/registered = persistence_restored_bodies[H.persistence_owner_ckey]
	var/pending_return = registered && (H in registered)
	if(!pending_return && !is_protected_sleep_location(H)) return TRUE
	// Do not extract a saved passenger/driver from an external spatial owner.
	// Those relationships require their ordinary dismount/unload reconciliation.
	if(!isturf(H.loc) || H.riding || H.driver || H.driver_vehicle || H.riding_mob) return FALSE
	var/turf/destination = character_return_turf(H)
	if(!destination) return FALSE
	if(H.loc != destination)
		if(!H.release_protected_sleep_buckle() || character_recovery_unready()) return FALSE
		if(!H || !destination || !persistence_character_turf_safe(destination, H)) return FALSE
		H.forceMove(destination)
	if(!H || H.loc != destination || !persistence_character_turf_safe(destination, H) || character_recovery_unready()) return FALSE
	return TRUE

/map_storage/proc/local_character_bodies(account)
	var/list/bodies = list()
	for(var/mob/living/human/H in world)
		if(H.persistence_owner_ckey == account) bodies |= H
	return bodies

/map_storage/proc/character_recovery_unready()
	var/final_import = persistence_active_operation && persistence_active_operation.current(src, "load") && persistence_active_operation.restoring_players
	if(persistence_active_operation && !final_import) return TRUE
	if(player_restoration_blocked() || persistence_load_recovery_required || dimension_recovery_required || dimension_budget_hold) return TRUE
	if(persistence_player_restore_ready) return FALSE
	var/list/save_artifacts = flist("map_saves/")
	return fexists("map_saves/map.txt") || fexists("map_saves/save_complete.txt") || fexists("map_saves/round.json") || save_artifacts.len

// TRUE means preserve the lobby, even if reclaim cannot yet succeed. Dead-only
// ownership permits the existing death/respawn policy; never revive that body.
/map_storage/proc/character_return_pending(account)
	if(!persistence_bed_return_enabled()) return FALSE
	if(character_recovery_unready() || persistence_active_operation || persistence_player_claims[account]) return TRUE
	var/list/bodies = local_character_bodies(account)
	var/list/registered = persistence_restored_bodies[account]
	if(registered && registered.len && (registered.len != 1 || bodies.len != 1 || registered[1] != bodies[1])) return TRUE
	if(bodies.len > 1) return TRUE
	if(bodies.len == 1)
		var/mob/living/human/H = bodies[1]
		return H.stat != DEAD
	return FALSE

/map_storage/proc/allow_new_character(mob/new_player/lobby)
	if(!persistence_bed_return_enabled()) return TRUE
	if(!lobby || !lobby.client || lobby.client.mob != lobby) return FALSE
	if(reclaim_saved_player(lobby)) return FALSE
	if(!lobby.client || lobby.client.mob != lobby) return FALSE
	if(character_return_pending(lobby.client.ckey))
		to_chat(lobby, SPAN_WARNING("Your existing character or world recovery is not ready. No new character was created. Retry Join after recovery; ask an administrator if the hold persists."))
		return FALSE
	return TRUE

/map_storage/proc/return_player_eligible(mob/living/human/H, account)
	var/list/registered = persistence_restored_bodies[account]
	if(registered && registered.len && (registered.len != 1 || registered[1] != H)) return FALSE
	return H && H.persistence_owner_ckey == account && !H.gc_destroyed && !H.gcDestroyed && H.stat != DEAD && !H.client && !H.key && get_turf(H)

/map_storage/proc/finish_character_return(mob/living/human/H)
	if(persistence_bed_return_enabled() && H && H.inducedSSD && !is_protected_sleep_location(H) && !character_recovery_unready())
		H.inducedSSD = FALSE
		H.sleeping = 0
