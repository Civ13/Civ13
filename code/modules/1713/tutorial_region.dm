// Tutorial region (shard kind TUTORIAL): a small world of its own that only runs
// the practice rooms (practice_rooms.dm), like the TDM Barracks is a world of its
// own. It never saves. A lobby on any other region of the group sends a player
// there instead of opening a room on its own world; the tutorial world puts each
// arrival straight into a room and sends them back to the group's gate (or the
// mainland) when they leave. Without an awake or wakeable tutorial region the
// lobby falls back to the in-world practice rooms. See docs/practice-rooms.md.

// How long an arrival waits for the round to start before giving up.
#define TUTORIAL_START_WAIT (2 MINUTES)

/obj/map_metadata/tutorial
	ID = MAP_TUTORIAL
	title = "Tutorial"
	description = "Guided practice rooms for new players."
	lobby_icon = "icons/lobby/football.png"
	no_winner = "The tutorial never closes."
	faction_organization = list(CIVILIAN)
	roundend_condition_sides = list(list(CIVILIAN) = /area/caribbean/tutorial)
	age = "1713"
	ordinal_age = 2
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "tutorial"
	mission_start_message = ""
	faction1 = CIVILIAN
	is_singlefaction = TRUE
	gamemode_vote = FALSE
	gamemode = "Tutorial"
	no_time_of_day_cycle = TRUE
	valid_weather_types = list(WEATHER_NONE)
	has_hunger = FALSE
	research_active = FALSE

/obj/map_metadata/tutorial/cross_message(faction)
	return ""

/obj/map_metadata/tutorial/reverse_cross_message(faction)
	return ""

// The tutorial round never ends.
/obj/map_metadata/tutorial/update_win_condition()
	return TRUE

/area/caribbean/tutorial
	name = "Tutorial"
	icon_state = "green1"
	location = AREA_INSIDE
	artillery_integrity = INFINITY
	dynamic_lighting = FALSE

/proc/tutorial_region_here()
	return shard_group && shard_group.enabled && shard_group.kind == "TUTORIAL"

// The group's tutorial region a lobby here can send players to, or null. Only
// one that is up or can be woken counts; anything else means the in-world rooms.
/proc/tutorial_region_peer()
	if(!shard_group || !shard_group.enabled || shard_group.kind == "TUTORIAL")
		return null
	for(var/id in shard_group.order)
		var/list/peer = shard_group.peers[id]
		if(islist(peer) && peer["kind"] == "TUTORIAL" && peer["address"] && (peer["state"] == "UP" || shard_group.peer_wakeable(id)))
			return id
	return null

// Where a player goes when they leave the tutorial: the gate behind a relay
// (it forwards them to their home land), otherwise the mainland.
/proc/tutorial_region_return_id()
	if(!tutorial_region_here())
		return null
	var/id = shard_group.relay_on() ? shard_group.gate : shard_group.mainland
	return id && id != shard_group.region && shard_group.peers[id] ? id : null

/proc/tutorial_region_return_name()
	var/id = tutorial_region_return_id()
	var/list/peer = id ? shard_group.peers[id] : null
	return peer ? peer["name"] : "the game"

// Lobby Practice Room link: the tutorial region when there is one, else a room here.
/proc/practice_room_available()
	return tutorial_region_peer() || (ticker && !practice_rooms.entry_error())

/proc/practice_room_open(mob/new_player/lobby)
	if(!istype(lobby) || !lobby.client)
		return FALSE
	var/id = tutorial_region_peer()
	if(!id)
		return practice_rooms.enter(lobby)
	tutorial_region_send(lobby.client, id)
	return TRUE

/proc/tutorial_region_send(client/C, id)
	set waitfor = FALSE
	if(!C || C.next_region_go > world.time)
		return
	C.next_region_go = world.time + 50
	var/list/peer = shard_group.peers[id]
	to_chat(C, SPAN_NOTICE("Taking you to the practice rooms. You come back here when you leave them."))
	if(peer["state"] != "UP")
		shard_group.poll_peer(id)
	if(C && peer["state"] != "UP")
		var/why = shard_group.wake_peer(id, null)
		if(why)
			// The practice rooms of this world still work.
			if(C && istype(C.mob, /mob/new_player))
				to_chat(C, SPAN_WARNING("The practice rooms are not answering right now, so one opens here instead."))
				practice_rooms.enter(C.mob)
			return
	if(C)
		shard_group.send_player(C, id, FALSE)

// ---- The tutorial world itself ----

/mob/new_player/var/tutorial_returning = FALSE

// Every arrival goes straight into a room. A lobby made for someone leaving
// one (tutorial_returning) does not.
/mob/new_player/Login()
	. = ..()
	if(!QDELETED(src) && client && client.mob == src && tutorial_region_here() && !tutorial_returning)
		tutorial_region_arrive(src)

/proc/tutorial_region_arrive(mob/new_player/lobby)
	set waitfor = FALSE
	var/deadline = world.time + TUTORIAL_START_WAIT
	while(lobby && !QDELETED(lobby) && lobby.client && (!ticker || ticker.current_state < GAME_STATE_PLAYING || !world_setup_finished))
		if(world.time > deadline)
			to_chat(lobby, SPAN_WARNING("The practice rooms are still getting ready. [tutorial_region_home_link("Go back to [tutorial_region_return_name()]")] or wait and use Practice Room."))
			return
		sleep(10)
	if(!lobby || QDELETED(lobby) || !lobby.client || lobby.tutorial_returning)
		return
	if(!practice_rooms.enter(lobby))
		to_chat(lobby, SPAN_NOTICE("[tutorial_region_home_link("Go back to [tutorial_region_return_name()]")]."))

/proc/tutorial_region_home_link(label)
	return "<a href='byond://?tutorial_home=1'>[label]</a>"

// Sends a player who left their room back to the group; TRUE when they were sent.
/proc/tutorial_region_send_home(client/C)
	var/id = tutorial_region_return_id()
	if(!C || !id)
		return FALSE
	return shard_group.send_player(C, id)

/client/Topic(href, href_list, hsrc)
	if(href_list["tutorial_home"])
		if(usr == mob && istype(mob, /mob/new_player) && tutorial_region_here() && next_region_go <= world.time)
			next_region_go = world.time + 50
			tutorial_region_send_home(src)
		return
	return ..()

// Nobody plays a character in the tutorial world: Join only points back.
/proc/tutorial_region_refuse_join(mob/new_player/lobby)
	if(!tutorial_region_here())
		return FALSE
	to_chat(lobby, SPAN_NOTICE("This server only runs the practice rooms. [tutorial_region_home_link("Go back to [tutorial_region_return_name()]")] to play."))
	return TRUE

#undef TUTORIAL_START_WAIT
