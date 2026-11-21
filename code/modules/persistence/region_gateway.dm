// Gateway region (shard kind GATEWAY): a small world that stays up on the group's
// public port and hosts no play. Players and the BYOND hub only ever see this
// world, so the listing never depends on a game world's restarts or standby
// handovers (a standby that takes over a port with world.OpenPort is not listed
// again). Every player who joins is sent on through the routing relay
// (region_relay.dm) to the land their character lives in, or to the start
// region when they have none. Nobody plays, saves or starts a character here.
//
// The gateway asks its own transfer agent the same question a land's Join check
// asks (/account claim without a body). For a world that is neither the
// account's home nor the start region that question never claims anything: it
// answers ELSEWHERE with the home (or the start region), PENDING or TRAVELLING.
// The destination still makes its own admission check when the player arrives.
// See scripts/shard-group/README.md, "Gateway world".

// How long a player is kept trying before they are offered a manual retry.
#define GATEWAY_FORWARD_WAIT (2 MINUTES)
#define GATEWAY_RETRY_DELAY (5 SECONDS)
#define GATEWAY_STATUS_INTERVAL (1 MINUTES)

/obj/map_metadata/gateway
	dig_down_underground = FALSE
	building_levels = 0
	ID = MAP_GATEWAY
	title = "Gateway"
	description = "The way in: every player is sent on to their land."
	lobby_icon = "icons/lobby/football.png"
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

// Where the gateway sends the player with this key next: list("home" = region
// id), or list("wait" = what to tell them) while the answer is not ready. Sleeps.
/proc/region_gateway_destination(key)
	var/account = ckey(key)
	// Guests own no character and cannot travel: they start where new players do.
	if(IsGuestKey(key) || !transfer_bridge || !transfer_bridge.enabled())
		return list("home" = shard_group.start_region)
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
	if(!C || lobby.gateway_forwarding)
		return FALSE
	lobby.gateway_forwarding = TRUE
	var/deadline = world.time + GATEWAY_FORWARD_WAIT
	var/told = null
	var/offered = FALSE
	var/sent = FALSE
	while(lobby && C && lobby.client == C)
		var/list/where = region_gateway_destination(C.key)
		if(!lobby || !C || lobby.client != C)
			break
		var/home = where["home"]
		if(home)
			var/list/peer = shard_group.peers[home]
			var/name = peer ? peer["name"] : home
			if(told != home)
				told = home
				to_chat(C, SPAN_NOTICE("Taking you to [html_encode(name)]... If nothing happens, <a href='byond://?gateway_retry=1'>try again</a>."))
			if(shard_group.send_player(C, home))
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
		sleep(GATEWAY_RETRY_DELAY)
	if(lobby)
		lobby.gateway_forwarding = FALSE
	return sent

// Players across every land of the group: this world's clients and each peer's
// last answer (asleep lands count as empty).
/proc/region_gateway_players()
	. = length(clients)
	for(var/id in shard_group.peers)
		var/list/peer = shard_group.peers[id]
		if(islist(peer) && isnum(peer["players"]))
			. += peer["players"]

// The hub lists the gateway, so its entry describes the group: the mainland's
// map and everyone playing in any land, not this empty world.
/proc/region_gateway_hub_status()
	var/list/mainland = shard_group.peers[shard_group.mainland]
	var/title = islist(mainland) && istext(mainland["map"]) ? mainland["map"] : null
	. = ""
	if(title)
		. += "<b>Mainland:</b> [hub_status_text(title)]<br>"
	. += "<b>Players:</b> [region_gateway_players()] across the lands<br>"

// The peers' player counts change without anyone logging in here.
/proc/region_gateway_status_loop()
	set waitfor = FALSE
	while(region_gateway_here())
		sleep(GATEWAY_STATUS_INTERVAL)
		world.update_status()

/hook/startup/proc/region_gateway_startup()
	if(region_gateway_here())
		region_gateway_status_loop()
	return TRUE

#undef GATEWAY_FORWARD_WAIT
#undef GATEWAY_RETRY_DELAY
#undef GATEWAY_STATUS_INTERVAL
