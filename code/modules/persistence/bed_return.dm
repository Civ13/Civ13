// Local world ownership only; this is not a cross-shard custody authority.
/proc/persistence_bed_return_enabled()
	return map && map.uses_durable_metadata()

// Scalar ownership avoids a spatial reference from a character to another level.
/obj/structure/bed/var/persistence_bed_owner_ckey

// One unread notice per owner per region; this is not part of the character
// save or custody ledger. The marker survives ordinary world restarts.
/proc/persistence_bed_notice_path(owner)
	if (!istext(owner) || !length(owner) || length(owner) > 64 || !persistence_owner_valid(owner) || IsGuestKey(owner_key_account(owner)))
		return null
	return "data/persistence-bed-notices/bed-[owner].pending"

/obj/structure/bed/proc/persistence_bed_notice_recipient(mob/user)
	var/client/actor = user?.client
	var/owner = persistence_bed_owner_ckey
	if (!persistence_bed_return_enabled() || !actor || actor.mob != user || !actor.ckey || IsGuestKey(actor.key) || actor.owner_key() == owner)
		return null
	return persistence_bed_notice_path(owner) ? owner : null

/proc/persistence_queue_bed_notice(owner, actor_name)
	var/path = persistence_bed_notice_path(owner)
	if (!path || fexists(path))
		return
	// Store the hour at dismantle time, not at delivery. UTC avoids ambiguous
	// clock changes, and using text preserves the hour across restarts.
	var/hour_utc = time2text(world.realtime, "YYYY-MM-DD hh:00", 0)
	var/list/details = list()
	details["hour_utc"] = hour_utc
	details["actor_name"] = actor_name
	if (!text2file(json_encode(details), path))
		log_world("Could not queue a registered bed destruction notice.")

/proc/persistence_bed_notice_message(record)
	var/who = "Another player"
	var/when_text = ""
	// A legacy "1" marker has neither detail. Invalid data still tells the
	// owner that their bed was lost, without guessing who or when.
	if (istext(record) && length(record))
		try
			var/list/details = json_decode(record)
			if (islist(details))
				var/hour_utc = details["hour_utc"]
				var/actor_name = details["actor_name"]
				if (istext(actor_name) && length(actor_name))
					who = html_encode(actor_name)
				if (istext(hour_utc) && length(hour_utc))
					when_text = " during the hour starting " + html_encode(hour_utc) + " UTC"
		catch
			return "Another player destroyed your assigned bed in this region."
	return who + " destroyed your assigned bed in this region" + when_text + "."

/proc/persistence_deliver_bed_notice(client/recipient)
	if (!persistence_bed_return_enabled() || !recipient || !recipient.key || IsGuestKey(recipient.key))
		return
	var/path = persistence_bed_notice_path(recipient.owner_key())
	if (!path || !fexists(path))
		return
	to_chat(recipient, SPAN_WARNING(persistence_bed_notice_message(file2text(path))))
	if (!fdel(path))
		log_world("Could not clear a registered bed destruction notice.")

// Tiles around a restored body searched for a safe return when its own is unsafe.
#define PERSISTENCE_RETURN_SEARCH_RANGE 7

// The floor itself can hold a character: solid, dry and outside the old sleep zone.
/proc/persistence_character_floor_usable(turf/T)
	// An upper storey is open air under a floor cover (tile_occupancy.dm).
	if(!tile_has_floor(T) || T.density || is_protected_sleep_location(T)) return FALSE
	if(istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/lava)) return FALSE
	return TRUE

/proc/persistence_character_turf_safe(turf/T, mob/living/human/H)
	if(!persistence_character_floor_usable(T)) return FALSE
	for(var/atom/movable/A in T)
		if(A != H && (A.density || istype(A, /mob/living))) return FALSE
	return TRUE

/obj/structure/bed/proc/valid_character_bed(mob/living/human/H)
	return !gc_destroyed && !gcDestroyed && anchored && buckle_lying && isturf(loc) && !sleep_occupant(H) && persistence_character_turf_safe(loc, H)

// Someone other than H actually lying in this bed. A one-sided buckled_mob left
// behind by a save/load, a deleted body or a body that has left the tile is not.
/obj/structure/bed/proc/sleep_occupant(mob/living/human/H)
	var/mob/living/M = buckled_mob
	if(!M || M == H || M.gc_destroyed || M.gcDestroyed || M.buckled != src || get_turf(M) != loc) return null
	return M

// Sleep admission: the sleeper already lies here, so only the bed and the floor
// matter. Whatever else shares the tile (an animal, a corpse, a crate) is the
// return's concern, and the return falls back to the nearest safe tile.
/obj/structure/bed/proc/valid_sleep_bed(mob/living/human/H)
	return !gc_destroyed && !gcDestroyed && anchored && buckle_lying && isturf(loc) && !sleep_occupant(H) && persistence_character_floor_usable(loc)

// One account per bed: another account's assignment blocks Sleep there.
/obj/structure/bed/proc/assigned_to_other(ckey)
	return persistence_bed_owner_ckey && persistence_bed_owner_ckey != ckey

/obj/structure/bed/examine(mob/user, distance = -1)
	. = ..()
	if(!persistence_bed_owner_ckey || !persistence_bed_return_enabled() || !user || !user.client) return
	if(persistence_bed_owner_ckey == user.client.owner_key())
		to_chat(user, SPAN_NOTICE("This is your assigned bed."))
	else
		to_chat(user, SPAN_WARNING("This bed is assigned to someone else."))

// TRUE when every bed on this turf is assigned to another account.
/mob/living/human/proc/saved_bed_taken_here()
	if(!client) return FALSE
	var/found = FALSE
	for(var/obj/structure/bed/B in get_turf(src))
		if(!B.assigned_to_other(client.owner_key())) return FALSE
		found = TRUE
	return found

// Where this account's current bed is: "here", "elsewhere" or null.
/mob/living/human/proc/saved_bed_assignment()
	if(!client) return null
	var/turf/T = get_turf(src)
	var/where = null
	for(var/obj/structure/bed/B in world)
		if(B.persistence_bed_owner_ckey != client.owner_key()) continue
		if(get_turf(B) != T) return "elsewhere"
		where = "here"
	return where

// The bed on this tile that Sleep assigns: this account's own bed first, then a free one.
/mob/living/human/proc/saved_sleep_bed()
	if(!client || !isturf(loc)) return null
	var/obj/structure/bed/free
	for(var/obj/structure/bed/B in loc)
		if(!B.valid_sleep_bed(src)) continue
		if(B.persistence_bed_owner_ckey == client.owner_key()) return B
		if(!B.persistence_bed_owner_ckey && !free) free = B
	return free

// Why Sleep cannot assign a bed here, as the message for the player; null when it can.
/mob/living/human/proc/saved_bed_sleep_refusal()
	if(persistence_sleep_transfer_blocked()) return "Wait for the world save or load to finish, then try Sleep again."
	if(map_storage.character_recovery_unready()) return "The world is still finishing its recovery after a restart. Try Sleep again in a few minutes."
	if(stat == DEAD || !client || IsGuestKey(client.key)) return "You cannot claim a bed right now."
	if(!isturf(loc)) return "Get out of what you are in, then try Sleep again."
	var/obj/structure/bed/bed = saved_sleep_bed()
	if(!bed)
		for(var/obj/structure/bed/B in loc)
			if(B.assigned_to_other(client.owner_key())) return "This bed is assigned to someone else. Sleep in an unassigned bed or your own."
			if(B.sleep_occupant(src)) return "Someone else is lying in this bed."
			if(!B.anchored || !B.buckle_lying) return "This bed is not fastened to the floor. Use a stationary bed."
		return "This bed is not on solid, dry floor. Use a bed on solid ground."
	if(buckled && buckled != bed) return "Get up from where you are sitting, then try Sleep again."
	return null

/mob/living/human/proc/enter_saved_bed_sleep()
	if(!persistence_bed_return_enabled() || inducedSSD || saved_bed_sleep_refusal()) return FALSE
	var/obj/structure/bed/bed = saved_sleep_bed()
	if(!bed) return FALSE
	// No prompt/wait or inventory drop between admission and scalar claim changes.
	for(var/obj/structure/bed/B in world)
		if(B != bed && B.persistence_bed_owner_ckey == client.owner_key()) B.persistence_bed_owner_ckey = null
	var/owner = client.owner_key()
	if(bed.persistence_bed_owner_ckey != owner) bed.persistence_bed_assigned_at = death_legacy_now()
	bed.persistence_bed_owner_ckey = owner
	record_persistence_owner()
	accolade_meet_mob(src, "settled")
	lastx = x
	lasty = y
	lastz = z
	sleeping = 66
	inducedSSD = TRUE
	offline_sleep_protection_lifted = FALSE
	if(s_active) s_active.close(src)
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
	// The body's own tile can fail only for a while or for a harmless reason (an
	// animal or another body on it, shallow water, a crate pushed onto it): take
	// the nearest safe floor close by instead of holding the account's Join.
	var/turf/origin = get_turf(H)
	if(!origin || is_protected_sleep_location(origin)) return null
	var/turf/nearest
	var/nearest_distance
	for(var/turf/T in orange(PERSISTENCE_RETURN_SEARCH_RANGE, origin))
		var/distance = get_dist(origin, T)
		if(nearest && distance >= nearest_distance) continue
		if(!persistence_character_turf_safe(T, H)) continue
		nearest = T
		nearest_distance = distance
	return nearest

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
		// A body queued for deletion (cleared before a load) is not a second character.
		if(H.persistence_owner_ckey == account && !H.gc_destroyed && !H.gcDestroyed) bodies |= H
	return bodies

/map_storage/proc/character_recovery_unready()
	var/final_import = persistence_active_operation && persistence_active_operation.current(src, "load") && persistence_active_operation.restoring_players
	if(persistence_active_operation && !final_import) return TRUE
	if(player_restoration_blocked() || persistence_load_recovery_required || dimension_recovery_required || dimension_budget_hold) return TRUE
	if(persistence_player_restore_ready) return FALSE
	var/list/save_artifacts = flist("map_saves/")
	return fexists("map_saves/map.txt") || fexists("map_saves/save_complete.txt") || fexists("map_saves/round.json") || save_artifacts.len

// TRUE only when every registered entry is gone: nulled by deletion or queued for it.
/map_storage/proc/restored_bodies_destroyed(list/registered)
	for(var/entry in registered)
		var/mob/living/human/H = entry
		if(H && !H.gc_destroyed && !H.gcDestroyed) return FALSE
	return TRUE

// TRUE means preserve the lobby, even if reclaim cannot yet succeed. Dead-only
// ownership permits the existing death/respawn policy; never revive that body.
/map_storage/proc/character_return_pending(account)
	if(!persistence_bed_return_enabled()) return FALSE
	if(character_recovery_unready() || persistence_active_operation || persistence_player_claims[account]) return TRUE
	var/list/bodies = local_character_bodies(account)
	var/list/registered = persistence_restored_bodies[account]
	// A restored body destroyed later (for example, decayed into remains) leaves only
	// null or deleted registry entries. With no owned body left there is nothing to
	// return, so drop the registration and let the ordinary death/respawn policy apply.
	if(registered && registered.len && !bodies.len && restored_bodies_destroyed(registered))
		persistence_restored_bodies.Remove(account)
		registered = null
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
	if(character_return_pending(lobby.client.owner_key()))
		to_chat(lobby, SPAN_WARNING("Your existing character or world recovery is not ready. No new character was created. Retry Join after recovery; ask an administrator if the hold persists."))
		note_character_return_hold(lobby)
		return FALSE
	return TRUE

/map_storage/proc/note_character_return_hold(mob/new_player/lobby)
	var/owner = lobby.client ? lobby.client.owner_key() : lobby.ckey
	var/reason = character_return_hold_reason(owner)
	log_game("Join held for [owner]: [reason]")
	message_admins("Join held for [key_name(lobby)]: [reason]")

// Why character_return_pending holds this account, for the log and admins.
/map_storage/proc/character_return_hold_reason(account)
	if(character_recovery_unready()) return "world recovery is not ready"
	if(persistence_active_operation) return "a save or load is running"
	if(persistence_player_claims[account]) return "another lobby is claiming this character"
	var/list/bodies = local_character_bodies(account)
	var/list/registered = persistence_restored_bodies[account]
	if(bodies.len != 1) return "[bodies.len] owned bodies"
	var/mob/living/human/H = bodies[1]
	if(registered && registered.len && (registered.len != 1 || registered[1] != H)) return "restored registration does not match the owned body [H.real_name]"
	var/where = H.loc ? "[H.loc.type]" : "nowhere"
	var/turf/T = get_turf(H)
	if(T) where += " at [T.x],[T.y],[T.z]"
	if(H.client || H.key) return "[H.real_name] is controlled by [H.key ? H.key : "another client"] ([where])"
	if(!isturf(H.loc) || H.riding || H.driver || H.driver_vehicle || H.riding_mob) return "[H.real_name] is inside or riding something ([where])"
	if(!character_return_turf(H)) return "[H.real_name] has no safe tile within [PERSISTENCE_RETURN_SEARCH_RANGE] ([where])"
	return "[H.real_name] could not be handed back ([where])"

/map_storage/proc/return_player_eligible(mob/living/human/H, account)
	var/list/registered = persistence_restored_bodies[account]
	if(registered && registered.len && (registered.len != 1 || registered[1] != H)) return FALSE
	return H && H.persistence_owner_ckey == account && !H.gc_destroyed && !H.gcDestroyed && H.stat != DEAD && !H.client && !H.key && get_turf(H)

// A player who chose to sleep stays asleep on reconnect until they use Wake Up.
// The refresh loop did not survive the save, so restart it here.
/map_storage/proc/finish_character_return(mob/living/human/H)
	if(H && H.inducedSSD && H.stat != DEAD)
		H.sleep_update()
