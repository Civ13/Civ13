// Durable account ownership is separate from client sessions and login audit data.
/mob/living/human/var/persistence_owner_ckey

var/global/list/persistence_restored_bodies = list()
var/global/persistence_player_restore_ready = FALSE

/mob/living/human/proc/record_persistence_owner()
	if(!client || !client.ckey)
		return
	var/account = client.ckey
	for(var/mob/living/human/H in world)
		if(H != src && H.persistence_owner_ckey == account)
			H.persistence_owner_ckey = null
	persistence_owner_ckey = account

/map_storage/proc/prepare_player_ownership()
	var/list/active = list()
	for(var/mob/living/human/H in world)
		if(H.client)
			var/account = H.client.ckey
			if(!account || active[account])
				throw EXCEPTION("Duplicate or missing authenticated player account")
			active[account] = H
	for(var/mob/living/human/H in world)
		if(H.client)
			H.persistence_owner_ckey = H.client.ckey
		else if(H.persistence_owner_ckey && active[H.persistence_owner_ckey])
			H.persistence_owner_ckey = null
	var/list/owners = list()
	for(var/mob/living/human/H in world)
		var/account = H.persistence_owner_ckey
		if(isnull(account)) continue
		if(!istext(account) || !length(account) || ckey(account) != account || owners[account])
			throw EXCEPTION("Invalid or duplicate durable player ownership")
		owners[account] = H

/map_storage/proc/reset_player_restoration()
	persistence_player_restore_ready = FALSE
	persistence_restored_bodies = list()

/map_storage/proc/register_restored_player(datum/D)
	if(!istype(D, /mob/living/human)) return
	var/mob/living/human/H = D
	var/account = H.persistence_owner_ckey
	if(isnull(account)) return
	if(!istext(account) || !length(account) || ckey(account) != account)
		throw EXCEPTION("Invalid restored player ownership")
	var/list/bodies = persistence_restored_bodies[account]
	if(!bodies)
		bodies = list()
		persistence_restored_bodies[account] = bodies
	bodies |= H

/map_storage/proc/find_restored_player(account)
	if(!persistence_player_restore_ready || persistence_save_in_progress || last_error)
		return null
	if(!istext(account) || !length(account) || ckey(account) != account)
		return null
	var/list/bodies = persistence_restored_bodies[account]
	// Ambiguous ownership never falls back to a name, position or iteration order.
	if(!bodies || bodies.len != 1) return null
	var/mob/living/human/H = bodies[1]
	if(!H || !get_turf(H) || H.persistence_owner_ckey != account || H.stat == DEAD || H.client || H.key)
		return null
	return H

/map_storage/proc/reclaim_saved_player(mob/new_player/lobby)
	if(!lobby || !lobby.client || lobby.client.mob != lobby) return FALSE
	var/client/C = lobby.client
	var/mob/living/human/H = find_restored_player(C.ckey)
	if(!H) return FALSE
	// No waits between eligibility, reservation and the normal Login path.
	persistence_restored_bodies.Remove(C.ckey)
	lobby.spawning = TRUE
	lobby.close_spawn_windows()
	H.key = C.key
	if(C.mob != H)
		throw EXCEPTION("Saved player body did not receive its authenticated client")
	qdel(lobby)
	return TRUE

/map_storage/proc/finish_player_restoration()
	persistence_player_restore_ready = TRUE
	for(var/client/C in clients)
		if(istype(C.mob, /mob/new_player))
			reclaim_saved_player(C.mob)

/map_storage/proc/validate_saved_player_owner(savefile/F, ref, list/owners)
	var/value = F["[entry_path(F, ref)]/persistence_owner_ckey"]
	if(isnull(value)) return
	if(F["/format_version"] == 2)
		if(!islist(value) || value["kind"] != "value")
			throw EXCEPTION("Invalid saved player ownership encoding")
		value = value["value"]
	if(isnull(value)) return
	if(!istext(value) || !length(value) || ckey(value) != value || owners[value])
		throw EXCEPTION("Invalid or duplicate saved player ownership")
	owners[value] = TRUE
