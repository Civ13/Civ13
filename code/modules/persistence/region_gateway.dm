// Gateway region (shard kind GATEWAY): a small world that stays up on the group's
// public port and hosts no play. Players and the BYOND hub only ever see this
// world, so the listing never depends on a game world's restarts or standby
// handovers (a standby that takes over a port with world.OpenPort is not listed
// again). Every player who joins is sent on through the routing relay
// (region_relay.dm) to the land their character lives in, or to the start
// region when they have none. An optional, private Characters screen helps
// choose where to continue; it cannot change slots or claim a body. Nobody
// plays, saves or starts a character here.
//
// Ordinary automatic routing asks the local agent about the client's active
// character. The opt-in chooser instead uses a read-only coordinator lookup,
// refuses incomplete answers and wakes only a confirmed destination after a
// click. The destination still makes its own admission check on arrival.
// See scripts/shard-group/README.md, "Gateway world".

// How long a player is kept trying before they are offered a manual retry.
#define GATEWAY_FORWARD_WAIT (2 MINUTES)
#define GATEWAY_RETRY_DELAY (5 SECONDS)
#define GATEWAY_ROSTER_RETRY_DELAY (2 SECONDS)
#define GATEWAY_STATUS_INTERVAL (1 MINUTES)
// The shard board polls once a minute; allow a delayed poll but not a stuck cache.
#define GATEWAY_POPULATION_MAX_AGE (3 MINUTES)

/obj/map_metadata/gateway
	dig_down_underground = FALSE
	building_levels = 0
	ID = MAP_GATEWAY
	title = "Gateway"
	description = "The way in: every player is sent on to their land."
	// The gateway fronts the group, so players see the start region's art (Gaia's volcano).
	lobby_icon = 'icons/lobby/gaia_volcano.dmi'
	lobby_icon_wide = 'icons/lobby/gaia_volcano_wide.dmi'
	no_winner = "The gateway never closes."
	faction_organization = list(CIVILIAN)
	roundend_condition_sides = list(list(CIVILIAN) = /area/caribbean/gateway)
	age = "1713"
	ordinal_age = 2
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "gateway"
	mission_start_message = ""
	faction1 = CIVILIAN
	is_singlefaction = TRUE
	gamemode_vote = FALSE
	gamemode = "Gateway"
	no_time_of_day_cycle = TRUE
	valid_weather_types = list(WEATHER_NONE)
	has_hunger = FALSE
	research_active = FALSE

/obj/map_metadata/gateway/cross_message(faction)
	return ""

/obj/map_metadata/gateway/reverse_cross_message(faction)
	return ""

// The gateway round never ends.
/obj/map_metadata/gateway/update_win_condition()
	return TRUE

/area/caribbean/gateway
	name = "Gateway"
	icon_state = "green1"
	location = AREA_INSIDE
	artillery_integrity = INFINITY
	dynamic_lighting = FALSE

/proc/region_gateway_here()
	return shard_group && shard_group.enabled && shard_group.kind == "GATEWAY"

/mob/new_player/var/tmp/gateway_forwarding = FALSE
/client/var/tmp/gateway_character_lobby = FALSE // UI preference from the connection, not admission
/client/var/tmp/gateway_expected_slot = 0 // untrusted assertion; may only refuse a handoff

// The public front door of a Persistence group, not a TDM waiting room.
/proc/region_gateway_roster_address()
	if(!shard_group || !shard_group.enabled || !shard_group.gate || !shard_group.start_region)
		return null
	var/list/front = shard_group.peers[shard_group.gate]
	var/list/start = shard_group.peers[shard_group.start_region]
	if(!islist(front) || front["kind"] != "GATEWAY" || !islist(start) || start["kind"] != "SURFACE" || region_gateway_battle_peer())
		return null
	return shard_group.gate_address()

// Requested only as a UI hint. Never pass a slot, owner key, or route on a
// connect URL; the new world derives those from the authenticated client.
/proc/region_gateway_open_roster(client/C)
	var/address = region_gateway_roster_address()
	if(!accolade_client_ckey(C) || !address || character_lobby_departure_refusal(C))
		return FALSE
	C << link("byond://[address]?character_lobby=1")
	return TRUE

/proc/region_gateway_roster_enabled(client/C)
	return region_gateway_here() && C && C.gateway_character_lobby && accolade_client_ckey(C) && region_gateway_roster_address()

/proc/region_gateway_roster_choice_allowed(client/C, list/state, slot)
	return isnum(slot) && slot == round(slot) && slot >= 1 && slot <= character_slots_max && character_slot_open(state, slot) && (slot == 1 || character_slots_verified(C))

/proc/region_gateway_active_slot(client/C, list/state)
	var/slot = state?["active"]
	return region_gateway_roster_choice_allowed(C, state, slot) ? slot : 1

// Never adopt the slot from a URL. The destination still independently
// restores and verifies its record; a stale copy may not embody another slot.
/proc/region_gateway_expected_slot_ok(client/C)
	if(!C || !C.gateway_expected_slot)
		return TRUE
	var/account = accolade_client_ckey(C)
	return region_home_enabled() && account && C.character_slot == C.gateway_expected_slot && region_gateway_active_slot(C, character_slot_state(account)) == C.gateway_expected_slot

/proc/region_gateway_show_roster(mob/new_player/lobby)
	var/client/C = lobby?.client
	if(!C || C.mob != lobby || !region_gateway_roster_enabled(C))
		return FALSE
	var/account = accolade_client_ckey(C)
	var/list/state = character_slot_state(account)
	var/active = region_gateway_active_slot(C, state)
	var/list/names = state["names"]
	var/list/cards = list("<html><head><title>Characters</title></head><body>[region_gateway_tabs(C)]<h2>Your characters</h2><p>Choose how to continue. You can only switch after the land you are leaving checks your current character. No body wakes up on the gateway.</p>")
	for(var/slot = 1 to character_slots_max)
		if(slot != active && !character_slot_open(state, slot))
			continue
		var/list/entry = names["[slot]"]
		var/name = islist(entry) && istext(entry[1]) ? html_encode(entry[1]) : "Character [slot]"
		var/action = ""
		if(slot == active)
			action = "Current character. <a href='byond://?gateway_character_slot=[slot]'>Continue to their land</a>."
		else if(character_slot_return_wait(state, slot))
			action = "Not ready to play again yet. Check the switch cooldown in your current land."
		else if(region_gateway_roster_choice_allowed(C, state, slot))
			action = "Another slot. <a href='byond://?gateway_character_slot=[slot]'>Switch on your current land</a>."
		else
			action = "Unavailable until you verify your account."
		cards += "<h3>Slot [slot]: [name]</h3><p>[action]</p>"
	cards += "<p>New characters are created through Join at the destination, not here.[region_gateway_practice_link()]</p></body></html>"
	show_browse(C, jointext(cards, ""), "window=gateway_characters;size=510x430")
	return TRUE

/proc/region_gateway_choose_character(mob/new_player/lobby, slot)
	var/client/C = lobby?.client
	if(!C || C.mob != lobby || !region_gateway_roster_enabled(C) || lobby.gateway_forwarding)
		return FALSE
	var/list/state = character_slot_state(accolade_client_ckey(C))
	if(!region_gateway_roster_choice_allowed(C, state, slot) || (slot != region_gateway_active_slot(C, state) && character_slot_return_wait(state, slot)))
		region_gateway_show_roster(lobby)
		return FALSE
	// An alternate choice sends the active character to their own land
	// first, where the existing Characters panel can check sleep, custody,
	// cooldown and injury. The gateway deliberately writes no switch record.
	lobby.gateway_character_choice = slot
	region_gateway_forward(lobby)
	return TRUE

/mob/new_player/var/tmp/gateway_character_choice = 0

// Where the gateway sends the player with this key next: list("home" = region
// id), or list("wait" = what to tell them) while the answer is not ready. Sleeps.
/proc/region_gateway_destination(key, slot = 1, roster = FALSE)
	var/account = owner_key_for(ckey(key), slot)
	// Guests own no character and cannot travel: they start where new players do.
	if(IsGuestKey(key))
		return list("home" = shard_group.start_region)
	if(!account || !transfer_bridge || !transfer_bridge.enabled())
		if(roster || slot > 1)
			return list("wait" = "The character directory is unavailable. No character has been selected or moved.")
		return list("home" = shard_group.start_region)
	if(roster)
		var/list/reply = transfer_bridge.request("/lobby/home", list("ckey" = account))
		var/list/status = reply?["ok"] && islist(reply["result"]) ? reply["result"] : null
		switch(status?["state"])
			if("HOME", "NO_HOME")
				var/home = status["region"]
				if(istext(home) && home != shard_group.region && shard_group.peers[home] && (status["state"] != "NO_HOME" || home == shard_group.start_region))
					return list("home" = home)
			if("PARKED")
				var/home = status["home"]
				if(region_home_parked_land(home))
					return list("parked" = home)
			if("PENDING")
				return list("wait" = "Checking your character's land. Please wait...")
			if("TRAVELLING")
				return list("wait" = "Your character is still on its way between lands. It is safe; you are sent on once it arrives.")
		return list("wait" = "The character directory cannot confirm your land yet. No character has been selected or moved.")
	var/list/answer = transfer_bridge.request("/account", list("ckey" = account, "op" = "claim"))
	var/list/result = (answer && answer["ok"] && islist(answer["result"])) ? answer["result"] : null
	if(!result)
		return list("wait" = "The world directory is not answering yet. Waiting for it...")
	switch(result["verdict"])
		if("ELSEWHERE")
			var/home = result["home"]
			if(region_home_parked_land(home))
				if(region_home_summon(account, home))
					return list("wait" = "Your character is on a land across the sea whose harbour was laid up while nobody was there. It is being made ready now, which takes a few minutes.")
				return list("wait" = "Your character is on a land across the sea that is laid up, and no word can be sent to make it ready yet. Trying again...")
			if(istext(home) && shard_group.peers[home])
				return list("home" = home)
			log_game("Gateway: [account]'s home [home] is not a region of this group.")
			return list("wait" = "Your land is not known here. Ask an admin.")
		if("PENDING")
			return list("wait" = "Your account is being settled. Waiting for the world directory...")
		if("TRAVELLING")
			return list("wait" = "Your character is still on its way between lands. It is safe; you are sent on once it arrives.")
		if("HOME")
			// Nobody can live in the gateway (shard_group.py refuses it as a start
			// region); a home here is a mistake an admin must fix.
			log_game("Gateway: the coordinator gave [account] a home in the gateway.")
			message_admins("[account]'s home is recorded as the gateway [shard_group.region], where nobody can play. Send them to a land.")
			return list("wait" = "Your home land could not be worked out. An admin has been told.")
	return list("wait" = "The world directory gave no answer yet. Waiting...")

// The practice rooms link a waiting player is offered, or "" without a tutorial
// region that is up or can be woken (tutorial_region.dm).
/proc/region_gateway_practice_link()
	return tutorial_region_peer() ? " While you wait, <a href='byond://?gateway_practice=1'>try the practice rooms</a>; you come back here when you leave them." : ""

// Sends a lobby on to the account's land, trying again until it works or
// GATEWAY_FORWARD_WAIT passes. Admins go too: there is no work to do here.
// While the land cannot be reached the player is offered the practice rooms
// (Val, 2026-11-21: the tutorial stays available when the lands are not), and
// leaving them brings the player back here to be sent on again.
/proc/region_gateway_forward(mob/new_player/lobby)
	set waitfor = FALSE
	var/client/C = lobby ? lobby.client : null
	if(!C || C.mob != lobby || lobby.gateway_forwarding)
		return FALSE
	if(region_gateway_overview_session(C))
		return region_gateway_show_overview(lobby)
	var/roster = region_gateway_roster_enabled(C)
	var/choice = lobby.gateway_character_choice
	if(roster && !choice)
		return region_gateway_show_roster(lobby)
	var/persistence_front = !!region_gateway_roster_address()
	var/account = persistence_front ? accolade_client_ckey(C) : null
	var/slot = account ? region_gateway_active_slot(C, character_slot_state(account)) : 1
	lobby.gateway_forwarding = TRUE
	var/deadline = world.time + GATEWAY_FORWARD_WAIT
	var/told = null
	var/offered = FALSE
	var/sent = FALSE
	while(lobby && C && lobby.client == C && C.mob == lobby)
		var/list/where = region_gateway_destination(C.key, slot, roster)
		if(!lobby || !C || lobby.client != C || C.mob != lobby)
			break
		var/list/state = account ? character_slot_state(account) : null
		var/slot_changed = persistence_front && (account != accolade_client_ckey(C) || slot != region_gateway_active_slot(C, state))
		var/choice_refused = roster && (!region_gateway_roster_enabled(C) || !region_gateway_roster_choice_allowed(C, state, choice) || (choice != slot && character_slot_return_wait(state, choice)))
		if(slot_changed || choice_refused)
			lobby.gateway_character_choice = 0
			to_chat(C, SPAN_WARNING("Your character selection changed. Recheck your Characters screen or reconnect."))
			if(roster)
				region_gateway_show_roster(lobby)
			break
		var/home = where["home"]
		var/parked = where["parked"]
		if(roster && parked)
			var/owner = owner_key_for(account, slot)
			where["wait"] = region_home_summon(owner, parked) ? "Your character is on a laid-up land. Its harbour is being made ready; this can take a few minutes." : "Your character is on a laid-up land. Nobody could wake it yet; trying again."
			if(lobby?.client != C || C.mob != lobby)
				break
		if(home)
			var/list/peer = shard_group.peers[home]
			var/name = peer ? peer["name"] : home
			if(told != home)
				told = home
				if(roster && choice != slot)
					to_chat(C, SPAN_NOTICE("After arrival, use OOC > Characters to switch. Your current character must satisfy the land's switching rules."))
				to_chat(C, SPAN_NOTICE("Taking you to [html_encode(name)]... If nothing happens, <a href='byond://?gateway_retry=1'>try again</a>."))
			if(roster && shard_group.relay_on() && peer && peer["state"] != "UP")
				// Waking may take minutes. Ask the directory again on the
				// next pass rather than using this answer after the wait.
				if(!shard_group.peer_wakeable(home))
					shard_group.refresh_peer(home)
				if(lobby?.client != C || C.mob != lobby)
					break
				if(peer["state"] != "UP")
					var/why = shard_group.wake_peer(home, lobby)
					if(why && lobby?.client == C && C.mob == lobby)
						to_chat(C, SPAN_WARNING(why))
			else if(shard_group.send_player(C, home, !roster, roster ? slot : 0))
				sent = TRUE
				break
		else if(where["wait"] != told)
			told = where["wait"]
			to_chat(C, SPAN_NOTICE(told))
		if(!C || lobby.client != C)
			break
		if(!offered)
			var/practice = region_gateway_practice_link()
			if(practice)
				offered = TRUE
				to_chat(C, SPAN_NOTICE(trim(practice)))
		if(world.time >= deadline)
			to_chat(C, SPAN_WARNING("Your land could not be reached yet. <a href='byond://?gateway_retry=1'>Try again</a>, or reconnect in a few minutes.[region_gateway_practice_link()]"))
			break
		sleep(roster ? GATEWAY_ROSTER_RETRY_DELAY : GATEWAY_RETRY_DELAY)
	if(lobby)
		lobby.gateway_forwarding = FALSE
	return sent

// Count connected clients in the regions behind the gateway, not clients
// waiting to be forwarded here. Reuse the shard board's observations; this
// must not make network requests or wake sleeping regions.
/proc/region_gateway_population()
	var/players = 0
	var/unknown = 0
	for(var/id in shard_group.peers)
		var/list/peer = shard_group.peers[id]
		var/checked = peer["checked"]
		if(!isnum(checked) || world.time - checked > GATEWAY_POPULATION_MAX_AGE)
			unknown++
			continue
		// The doorman has confirmed these regions cannot host clients.
		if(peer["state"] in list("ASLEEP", "COLD", "STOPPED"))
			continue
		var/count = peer["players"]
		if(peer["state"] != "UP" || !isnum(count) || isnan(count) || isinf(count) || count < 0 || count != round(count))
			unknown++
			continue
		players += count
	return list("players" = players, "unknown" = unknown)

/proc/region_gateway_battle_peer()
	for(var/id in shard_group.peers)
		var/list/peer = shard_group.peers[id]
		if(islist(peer) && peer["kind"] == "BATTLE")
			return peer
	return null

// BYOND's built-in count is for the listed world itself. Use its status text
// for the region-wide population: the known sum as a plain number, or no line
// while no region has reported yet.
/proc/region_gateway_hub_status()
	var/list/mainland = shard_group.peers[shard_group.mainland]
	var/label = "Mainland"
	var/title = islist(mainland) && istext(mainland["map"]) ? mainland["map"] : null
	// A TDM group's front door shows the battle being fought, not the waiting room.
	var/list/battle = region_gateway_battle_peer()
	if(battle)
		label = "Battle"
		title = istext(battle["map"]) ? battle["map"] : null
	var/list/population = region_gateway_population()
	var/players = population["players"]
	var/unknown = population["unknown"]
	. = ""
	if(!unknown || unknown < length(shard_group.peers))
		. += "<b>Players across regions:</b> [players]<br>"
	// After the total: the hub keeps only the start of a status (world.dm).
	if(title)
		. += "<b>[label]:</b> [hub_status_text(title)]<br>"

// The peers' player counts change without anyone logging in here.
// Every minute it also tells the routing relay its own port: a player who joins
// the relay's port straight away (BYOND's reconnect or recent servers list keep
// it after a redirect) has no route there, and was dropped with "Connection
// failed during handshake" (2026-11-23). The relay sends such a login here.
/proc/region_gateway_status_loop()
	set waitfor = FALSE
	while(region_gateway_here())
		region_gateway_tell_relay()
		sleep(GATEWAY_STATUS_INTERVAL)
		world.update_status()

/proc/region_gateway_tell_relay()
	if(!shard_group.relay_on() || shard_group.gate != shard_group.region)
		return FALSE
	var/list/reply = shard_group.ask_relay("gate=1&port=[shard_address_port(shard_group.address)]")
	return reply && reply["ok"]

/hook/startup/proc/region_gateway_startup()
	if(region_gateway_here())
		region_gateway_status_loop()
	return TRUE

#undef GATEWAY_FORWARD_WAIT
#undef GATEWAY_RETRY_DELAY
#undef GATEWAY_ROSTER_RETRY_DELAY
#undef GATEWAY_STATUS_INTERVAL
#undef GATEWAY_POPULATION_MAX_AGE
