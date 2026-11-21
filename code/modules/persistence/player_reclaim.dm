// Durable account ownership is separate from client sessions and login audit data.
/mob/living/human/var/persistence_owner_ckey
/mob/living/human/var/tmp/persistence_restored = FALSE

/mob/living/human/persistence_runtime_var(key)
	return key == "persistence_restored" || key == "laddervision" || ..()

// All restored bodies, including legacy unowned ones, await final world state.
var/global/list/persistence_restored_characters = list()
/datum/proc/finish_character_knowledge_restoration()
	return

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

// Discord account keys (code/modules/accounts/discord_accounts.dm): "d:" and a
// Discord user ID. A ckey holds only a-z and 0-9, so the two never collide.
/proc/is_discord_id(id)
	if(!istext(id)) return FALSE
	var/static/regex/snowflake = regex(@"^[1-9][0-9]{16,19}$")
	if(!snowflake.Find(id)) return FALSE
	return TRUE

/proc/is_account_key(account)
	return istext(account) && copytext(account, 1, 3) == "d:" && is_discord_id(copytext(account, 3))

// A durable character owner: a non-guest ckey (legacy) or an account key.
// An agent character's account, "agent@" + the agent's name as a ckey. No BYOND
// ckey holds "@", so it never names a player (agent_travel.dm).
/proc/is_agent_account(account)
	if(!istext(account) || length(account) < 7 || length(account) > 32 || copytext(account, 1, 7) != "agent@") return FALSE
	var/name = copytext(account, 7)
	return ckey(name) == name

/proc/persistence_owner_valid(account)
	if(!istext(account) || !length(account)) return FALSE
	var/slot = owner_key_slot(account)
	if(!slot) return FALSE
	if(slot > 1) return persistence_owner_valid(owner_key_account(account)) // valid when its account is
	if(is_account_key(account) || is_agent_account(account)) return TRUE
	return ckey(account) == account && !persistence_guest_account(account)

// Character slots (docs/character-slots.md). Slot 1 owns a
// body under the account itself, exactly as before slots; slots 2 to 4 own
// theirs under "@<slot><account>". No ckey, account key or agent account
// starts with "@", so an owner key never names another account, and the key
// still fits the 32 characters of a BYOND ckey plus two.
var/global/const/character_slots_max = 4 // slot 1 plus three more

// The slot an owner key belongs to: 1 for a plain account, 2 to 4 for a slot key, 0 when invalid.
/proc/owner_key_slot(key)
	if(!istext(key) || !length(key)) return 0
	if(copytext(key, 1, 2) != "@") return 1
	var/slot = text2num(copytext(key, 2, 3))
	if(!isnum(slot) || slot < 2 || slot > character_slots_max || length(key) < 4) return 0
	if(copytext(key, 3, 4) == "@") return 0 // slot keys never nest
	return slot

// The account (the person) behind an owner key.
/proc/owner_key_account(key)
	var/slot = owner_key_slot(key)
	if(!slot) return null
	if(slot == 1) return key
	return copytext(key, 3)

/proc/owner_key_for(account, slot = 1)
	if(!istext(account) || !length(account) || owner_key_slot(account) != 1) return null
	if(!isnum(slot) || slot <= 1) return account
	if(slot > character_slots_max) return null
	return "@[round(slot)][account]"

/client/var/tmp/character_slot = 1 // the slot this client plays; only the Characters window changes it

// The owner key this client's character is saved under.
/client/proc/owner_key()
	return owner_key_for(ckey, character_slot) || ckey

/mob/living/human/proc/record_persistence_owner()
	if(!client || !client.ckey)
		return
	if(IsGuestKey(client.key))
		persistence_owner_ckey = null
		return
	var/account = client.owner_key()
	for(var/mob/living/human/H in world)
		if(H != src && H.persistence_owner_ckey == account)
			H.persistence_owner_ckey = null
	persistence_owner_ckey = account
	// Ownership moved to this body, so an older restored-body registration is
	// stale; kept, it would hold Join forever once this body dies.
	var/list/registered = persistence_restored_bodies[account]
	if(registered && !(src in registered))
		persistence_restored_bodies.Remove(account)

/map_storage/proc/prepare_player_ownership()
	// ClearMap retires bodies through qdel; they may remain in world until GC.
	// Only current bodies participate, even when a retired body retains its owner.
	var/list/active = list()
	for(var/mob/living/human/H in world)
		if(QDELETED(H) || H.gcDestroyed) continue
		if(H.client && !IsGuestKey(H.client.key))
			var/account = H.client.owner_key()
			if(!account || active[account])
				throw EXCEPTION("Duplicate or missing authenticated player account")
			active[account] = H
	for(var/mob/living/human/H in world)
		if(QDELETED(H) || H.gcDestroyed) continue
		if(H.client)
			H.persistence_owner_ckey = IsGuestKey(H.client.key) ? null : H.client.owner_key()
		else if(H.persistence_owner_ckey && active[H.persistence_owner_ckey])
			H.persistence_owner_ckey = null
	// Only a living body can be taken back. A body that died keeps its owner's
	// name until something else claims the account; an agent's autospawn could
	// leave a corpse behind that way. It gives the claim up to the living body
	// rather than fail every save.
	var/list/living = list()
	for(var/mob/living/human/H in world)
		if(QDELETED(H) || H.gcDestroyed || H.stat == DEAD || isnull(H.persistence_owner_ckey)) continue
		living[H.persistence_owner_ckey] = H
	var/list/owners = list()
	for(var/mob/living/human/H in world)
		if(QDELETED(H) || H.gcDestroyed) continue
		var/account = H.persistence_owner_ckey
		if(isnull(account)) continue
		if(H.stat == DEAD && !H.client && living[account])
			var/mob/living/human/alive = living[account]
			H.persistence_owner_ckey = null
			log_game("World save: [account]'s dead body [H.real_name] gave up its claim to the living [alive.real_name].")
			continue
		if(!persistence_owner_valid(account) || owners[account])
			var/mob/living/human/first = owners[account]
			log_game("World save: ownership of [account] is invalid or held twice: [H.real_name] at [H.x],[H.y],[H.z][first ? " and [first.real_name] at [first.x],[first.y],[first.z]" : ""].")
			throw EXCEPTION("Invalid or duplicate durable player ownership")
		owners[account] = H

// Makes this body the account's one durable body: any other body, alive or
// dead, gives the claim up. For bodies without a client to log in (agents).
/mob/living/human/proc/take_persistence_ownership(account)
	for(var/mob/living/human/H in world)
		if(H != src && H.persistence_owner_ckey == account)
			H.persistence_owner_ckey = null
	persistence_owner_ckey = account

/map_storage/proc/reset_player_restoration()
	persistence_player_restore_ready = FALSE
	persistence_restored_bodies = list()
	persistence_restored_characters = list()

/map_storage/proc/register_restored_player(datum/D)
	if(!istype(D, /mob/living/human)) return
	var/mob/living/human/H = D
	persistence_restored_characters |= H
	var/account = H.persistence_owner_ckey
	if(isnull(account)) return
	if(!persistence_owner_valid(account))
		throw EXCEPTION("Invalid restored player ownership")
	var/list/bodies = persistence_restored_bodies[account]
	if(!bodies)
		bodies = list()
		persistence_restored_bodies[account] = bodies
	bodies |= H

/map_storage/proc/find_restored_player(account)
	if(!persistence_player_restore_ready || player_restoration_blocked())
		return null
	if(!persistence_owner_valid(account))
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
	var/owner = C.owner_key()
	// Retain saved-body reconnect admission: account bans and recovery readiness.
	// Fresh-character entry locks, round/join gates and role checks are separate.
	// A rejected account leaves both its lobby and the saved claim untouched.
	if(IsGuestKey(C.key) || C.quickBan_isbanned("Playing") || C.quickBan_isbanned("Server"))
		return FALSE
	var/mob/living/human/H = find_restored_player(owner)
	if(persistence_bed_return_enabled())
		if(persistence_player_claims[owner] || character_recovery_unready()) return FALSE
		var/list/bodies = local_character_bodies(owner)
		if(length(bodies) != 1) return FALSE
		H = bodies[1]
		if(!return_player_eligible(H, owner)) return FALSE
	if(!H) return FALSE
	// Reserve before movement/Entered/Login hooks can reenter or yield. A failed
	// return retains the original body claim; release only this lobby's reservation.
	persistence_player_claims[owner] = lobby
	try
		// Movement hooks may yield or change account admission; recheck before handoff.
		if(!prepare_character_return(H) || !H || persistence_player_claims[owner] != lobby || lobby.client != C || C.mob != lobby || H.persistence_owner_ckey != owner || H.client || H.key || H.stat == DEAD || player_restoration_blocked() || (persistence_bed_return_enabled() && !return_player_eligible(H, owner)) || IsGuestKey(C.key) || C.quickBan_isbanned("Playing") || C.quickBan_isbanned("Server"))
			if(persistence_player_claims[owner] == lobby) persistence_player_claims.Remove(owner)
			return FALSE
		// Defend unique local ownership after callbacks, including direct owner changes.
		if(persistence_bed_return_enabled())
			var/list/current_bodies = local_character_bodies(owner)
			if(length(current_bodies) != 1 || current_bodies[1] != H)
				if(persistence_player_claims[owner] == lobby) persistence_player_claims.Remove(owner)
				return FALSE
		lobby.spawning = TRUE
		lobby.close_spawn_windows()
		H.key = C.key
		if(C.mob != H)
			throw EXCEPTION("Saved player body did not receive its authenticated client")
		finish_character_return(H)
		persistence_restored_bodies.Remove(owner)
	catch(var/exception/reclaim_error)
		if(persistence_player_claims[owner] == lobby) persistence_player_claims.Remove(owner)
		if(lobby && lobby.client == C && C.mob == lobby) lobby.spawning = FALSE
		throw reclaim_error
	if(persistence_player_claims[owner] == lobby) persistence_player_claims.Remove(owner)
	qdel(lobby)
	return TRUE

/map_storage/proc/player_restoration_blocked()
	// The import has restored the world before this phase begins. Its operation
	// still owns admission while player callbacks run; no new save/load may enter.
	var/final_import = persistence_active_operation && persistence_active_operation.current(src, "load") && persistence_active_operation.restoring_players
	// A failed save export leaves every body where it was; only load errors hold recovery.
	return (persistence_save_in_progress && !final_import) || persistence_restart.startup_hold || (last_error && last_error != last_export_error)

/map_storage/proc/finish_player_restoration()
	if(player_restoration_blocked())
		return FALSE
	// Metadata and all body fields are restored before the migration snapshot.
	for(var/mob/living/human/H in persistence_restored_characters)
		H.finish_character_knowledge_restoration()
	persistence_restored_characters = list()
	persistence_player_restore_ready = TRUE
	for(var/client/C in clients)
		var/mob/new_player/waiting = C.mob
		if(!istype(waiting)) continue
		// The region home check can wait on the network; the client may leave.
		if(!reclaim_allowed(waiting) || !waiting || !waiting.client || waiting.client.mob != waiting) continue
		reclaim_saved_player(waiting)
	return TRUE

// Whether this lobby may take back a saved body here; a region group narrows
// it to the account's home land (region_home.dm).
/map_storage/proc/reclaim_allowed(mob/new_player/lobby)
	return TRUE

/map_storage/proc/validate_saved_player_owner(savefile/F, ref, list/owners)
	F.cd = entry_path(F, ref)
	if(!("persistence_owner_ckey" in F.dir)) return
	var/value = F["[entry_path(F, ref)]/persistence_owner_ckey"]
	if(isnull(value)) return
	if((F["/format_version"] == 2 || F["/format_version"] == 3))
		value = persistence_saved_scalar(value)
		if(islist(value))
			throw EXCEPTION("Invalid saved player ownership encoding")
	if(isnull(value)) return
	if(!persistence_owner_valid(value) || owners[value])
		throw EXCEPTION("Invalid or duplicate saved player ownership")
	owners[value] = TRUE
