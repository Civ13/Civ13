// Durable account ownership is separate from client sessions and login audit data.
/mob/living/human/var/persistence_owner_ckey
/mob/living/human/var/tmp/persistence_restored = FALSE

/mob/living/human/persistence_runtime_var(key)
	return key == "persistence_restored" || key == "laddervision" || ..()

var/global/list/persistence_restored_bodies = list()
var/global/persistence_player_restore_ready = FALSE
var/global/list/persistence_player_claims = list()

/proc/persistence_guest_account(account)
	if(!istext(account) || copytext(account, 1, 6) != "guest") return FALSE
	var/start = copytext(account, 6, 7) == "w" ? 7 : 6
	if(length(account) < start) return FALSE
	for(var/i = start, i <= length(account), i++)
		var/character = text2ascii(account, i)
		if(character < 48 || character > 57) return FALSE
	return TRUE

/mob/living/human/proc/record_persistence_owner()
	if(!client || !client.ckey)
		return
	if(IsGuestKey(client.key))
		persistence_owner_ckey = null
		return
	var/account = client.ckey
	for(var/mob/living/human/H in world)
		if(H != src && H.persistence_owner_ckey == account)
			H.persistence_owner_ckey = null
	persistence_owner_ckey = account

/map_storage/proc/prepare_player_ownership()
	var/list/active = list()
	for(var/mob/living/human/H in world)
		if(H.client && !IsGuestKey(H.client.key))
			var/account = H.client.ckey
			if(!account || active[account])
				throw EXCEPTION("Duplicate or missing authenticated player account")
			active[account] = H
	for(var/mob/living/human/H in world)
		if(H.client)
			H.persistence_owner_ckey = IsGuestKey(H.client.key) ? null : H.client.ckey
		else if(H.persistence_owner_ckey && active[H.persistence_owner_ckey])
			H.persistence_owner_ckey = null
	var/list/owners = list()
	for(var/mob/living/human/H in world)
		var/account = H.persistence_owner_ckey
		if(isnull(account)) continue
		if(!istext(account) || !length(account) || ckey(account) != account || persistence_guest_account(account) || owners[account])
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
	if(!istext(account) || !length(account) || ckey(account) != account || persistence_guest_account(account))
		throw EXCEPTION("Invalid restored player ownership")
	var/list/bodies = persistence_restored_bodies[account]
	if(!bodies)
		bodies = list()
		persistence_restored_bodies[account] = bodies
	bodies |= H

/map_storage/proc/find_restored_player(account)
	if(!persistence_player_restore_ready || player_restoration_blocked())
		return null
	if(!istext(account) || !length(account) || ckey(account) != account || persistence_guest_account(account))
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
	// Retain saved-body reconnect admission: account bans and recovery readiness.
	// Fresh-character entry locks, round/join gates and role checks are separate.
	// A rejected account leaves both its lobby and the saved claim untouched.
	if(IsGuestKey(C.key) || C.quickBan_isbanned("Playing") || C.quickBan_isbanned("Server"))
		return FALSE
	var/mob/living/human/H = find_restored_player(C.ckey)
	if(persistence_bed_return_enabled())
		if(persistence_player_claims[C.ckey] || character_recovery_unready()) return FALSE
		var/list/bodies = local_character_bodies(C.ckey)
		if(length(bodies) != 1) return FALSE
		H = bodies[1]
		if(!return_player_eligible(H, C.ckey)) return FALSE
	if(!H) return FALSE
	// Reserve before movement/Entered/Login hooks can reenter or yield. A failed
	// return retains the original body claim; release only this lobby's reservation.
	persistence_player_claims[C.ckey] = lobby
	try
		// Movement hooks may yield or change account admission; recheck before handoff.
		if(!prepare_character_return(H) || !H || persistence_player_claims[C.ckey] != lobby || lobby.client != C || C.mob != lobby || H.persistence_owner_ckey != C.ckey || H.client || H.key || H.stat == DEAD || player_restoration_blocked() || (persistence_bed_return_enabled() && !return_player_eligible(H, C.ckey)) || IsGuestKey(C.key) || C.quickBan_isbanned("Playing") || C.quickBan_isbanned("Server"))
			if(persistence_player_claims[C.ckey] == lobby) persistence_player_claims.Remove(C.ckey)
			return FALSE
		// Defend unique local ownership after callbacks, including direct owner changes.
		if(persistence_bed_return_enabled())
			var/list/current_bodies = local_character_bodies(C.ckey)
			if(length(current_bodies) != 1 || current_bodies[1] != H)
				if(persistence_player_claims[C.ckey] == lobby) persistence_player_claims.Remove(C.ckey)
				return FALSE
		lobby.spawning = TRUE
		lobby.close_spawn_windows()
		H.key = C.key
		if(C.mob != H)
			throw EXCEPTION("Saved player body did not receive its authenticated client")
		finish_character_return(H)
		persistence_restored_bodies.Remove(C.ckey)
	catch(var/exception/reclaim_error)
		if(persistence_player_claims[C.ckey] == lobby) persistence_player_claims.Remove(C.ckey)
		if(lobby && lobby.client == C && C.mob == lobby) lobby.spawning = FALSE
		throw reclaim_error
	if(persistence_player_claims[C.ckey] == lobby) persistence_player_claims.Remove(C.ckey)
	qdel(lobby)
	return TRUE

/map_storage/proc/player_restoration_blocked()
	// The import has restored the world before this phase begins. Its operation
	// still owns admission while player callbacks run; no new save/load may enter.
	var/final_import = persistence_active_operation && persistence_active_operation.current(src, "load") && persistence_active_operation.restoring_players
	return (persistence_save_in_progress && !final_import) || persistence_restart.startup_hold || last_error

/map_storage/proc/finish_player_restoration()
	if(player_restoration_blocked())
		return FALSE
	persistence_player_restore_ready = TRUE
	for(var/client/C in clients)
		if(istype(C.mob, /mob/new_player))
			reclaim_saved_player(C.mob)
	return TRUE

/map_storage/proc/validate_saved_player_owner(savefile/F, ref, list/owners)
	F.cd = entry_path(F, ref)
	if(!("persistence_owner_ckey" in F.dir)) return
	var/value = F["[entry_path(F, ref)]/persistence_owner_ckey"]
	if(isnull(value)) return
	if((F["/format_version"] == 2 || F["/format_version"] == 3))
		if(!islist(value) || value["kind"] != "value")
			throw EXCEPTION("Invalid saved player ownership encoding")
		value = value["value"]
	if(isnull(value)) return
	if(!istext(value) || !length(value) || ckey(value) != value || persistence_guest_account(value) || owners[value])
		throw EXCEPTION("Invalid or duplicate saved player ownership")
	owners[value] = TRUE
