// Region group (sharded servers). Each region is its own DreamDaemon world
// with its own map and saves; this world learns the other regions of its
// group from config/shard_region.json and shows them to players. It stays off
// while that file is missing or invalid. Built and run by
// scripts/shard-group/shard_group.py; see docs/sharded-worlds.md.

#define SHARD_POLL_INTERVAL 600
// The doorman refreshes every 30 s; an older entry means it lost the world.
#define SHARD_DOORMAN_FRESH_SECONDS 90
#define SHARD_MAX_REGIONS 16

var/global/datum/shard_group/shard_group = new

/proc/shard_id_valid(value)
	if(!istext(value) || !length(value) || length(value) > 32)
		return FALSE
	for(var/i = 1, i <= length(value), i++)
		var/c = text2ascii(value, i)
		if(!((c >= 48 && c <= 57) || (c >= 97 && c <= 122) || c == 45 || c == 95))
			return FALSE
	return TRUE

// host:port with a plain host name or IPv4 address; no scheme, path or query.
/proc/shard_address_valid(value)
	if(!istext(value) || length(value) > 80)
		return FALSE
	var/colon = findlasttext(value, ":")
	if(colon < 2)
		return FALSE
	var/port = text2num(copytext(value, colon + 1))
	if(!isnum(port) || port < 1 || port > 65535 || "[port]" != copytext(value, colon + 1))
		return FALSE
	for(var/i = 1, i < colon, i++)
		var/c = text2ascii(value, i)
		if(!((c >= 48 && c <= 57) || (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c == 45 || c == 46))
			return FALSE
	return TRUE

// The port of a host:port address.
/proc/shard_address_port(address)
	return text2num(copytext(address, findlasttext(address, ":") + 1))

/datum/shard_group
	var/enabled = FALSE
	var/group = null
	var/region = null
	var/name = null
	var/kind = null
	var/address = null
	// The region new characters start in. Every other region follows its epoch.
	var/mainland = null
	// id -> list(name, kind, address, state, players, map, checked)
	var/list/peers = list()
	var/list/order = list()
	var/polling = FALSE
	var/last_error = null
	// Periodic world saves (minutes, 0 = off) and how soon a save follows a
	// departure (seconds). A traveller can only arrive after the region they
	// left has saved without them.
	var/save_minutes = 0
	var/travel_save_seconds = 60
	// A resetting raid world (region_raid_reset.dm): minutes between resets, 0 = never.
	var/reset_minutes = 0
	var/saving_loop = FALSE
	// host:port of the host's doorman (scripts/gaia-host/doorman.py), which knows
	// which regions are asleep. Null when the host runs none. A sleeping peer is
	// never polled directly, because a connection to it wakes it.
	var/doorman = null

/datum/shard_group/New()
	..()
	if(fexists("config/shard_region.json"))
		configure(file2text("config/shard_region.json"))

/datum/shard_group/proc/refuse(reason)
	enabled = FALSE
	peers = list()
	order = list()
	last_error = reason
	world.log << "Region group: [reason]; this world runs on its own."
	return FALSE

/datum/shard_group/proc/configure(text)
	var/list/settings
	try
		settings = json_decode(text)
	catch
		return refuse("config/shard_region.json is not valid JSON")
	if(!islist(settings) || !shard_id_valid(settings["group"]) || !shard_id_valid(settings["region"]) || !islist(settings["regions"]))
		return refuse("config/shard_region.json needs group, region and regions")
	var/list/regions = settings["regions"]
	if(regions.len < 1 || regions.len > SHARD_MAX_REGIONS)
		return refuse("a group has 1 to [SHARD_MAX_REGIONS] regions")
	var/list/found = list()
	var/list/seen_addresses = list()
	var/list/self = null
	for(var/list/entry in regions)
		if(!islist(entry) || !shard_id_valid(entry["id"]) || (entry["id"] in found))
			return refuse("every region needs a unique id")
		if(!istext(entry["name"]) || !length(entry["name"]) || length(entry["name"]) > 64)
			return refuse("region [entry["id"]] needs a name of 1 to 64 characters")
		if(!(entry["kind"] in list("SURFACE", "OCEANIC", "UNDERGROUND", "RAILYARD", "RAID", "ORBIT", "OTHER")))
			return refuse("region [entry["id"]] has an unknown kind")
		if(!shard_address_valid(entry["address"]) || (entry["address"] in seen_addresses))
			return refuse("region [entry["id"]] needs a unique host:port address")
		found += entry["id"]
		seen_addresses += entry["address"]
		if(entry["id"] == settings["region"])
			self = entry
	if(!self)
		return refuse("this region is not in its own region list")
	save_minutes = 0
	if(!isnull(settings["save_minutes"]))
		if(!isnum(settings["save_minutes"]) || settings["save_minutes"] < 0 || settings["save_minutes"] > 1440)
			return refuse("save_minutes must be 0 to 1440")
		save_minutes = round(settings["save_minutes"])
	travel_save_seconds = 60
	if(!isnull(settings["travel_save_seconds"]))
		if(!isnum(settings["travel_save_seconds"]) || settings["travel_save_seconds"] < 10 || settings["travel_save_seconds"] > 3600)
			return refuse("travel_save_seconds must be 10 to 3600")
		travel_save_seconds = round(settings["travel_save_seconds"])
	reset_minutes = 0
	if(!isnull(settings["reset_minutes"]) && settings["reset_minutes"] != 0)
		if(!isnum(settings["reset_minutes"]) || settings["reset_minutes"] < 30 || settings["reset_minutes"] > 1440)
			return refuse("reset_minutes must be 0 or 30 to 1440")
		if(self["kind"] != "RAID")
			return refuse("only a RAID region can reset")
		reset_minutes = round(settings["reset_minutes"])
	doorman = null
	if(!isnull(settings["doorman"]))
		if(!shard_address_valid(settings["doorman"]))
			return refuse("doorman must be a host:port address")
		doorman = settings["doorman"]
	// The mainland defaults to the first region, as shard_group.py does.
	var/list/first = regions[1]
	mainland = first["id"]
	if(!isnull(settings["mainland"]))
		if(!(settings["mainland"] in found))
			return refuse("mainland must be one of the region ids")
		mainland = settings["mainland"]
	group = settings["group"]
	region = self["id"]
	name = self["name"]
	kind = self["kind"]
	address = self["address"]
	peers = list()
	order = list()
	for(var/list/entry in regions)
		if(entry["id"] == region)
			continue
		order += entry["id"]
		peers[entry["id"]] = list("name" = entry["name"], "kind" = entry["kind"], "address" = entry["address"], "state" = "UNKNOWN", "players" = null, "map" = null, "checked" = null)
	// The routing relay (region_relay.dm) is optional; a bad setting turns only it off.
	configure_relay(settings)
	enabled = TRUE
	last_error = null
	return TRUE

// What a peer, the host tool or a player sees of this region.
/datum/shard_group/proc/describe()
	. = list("group" = group, "region" = region, "name" = name, "kind" = kind, "players" = length(clients), "map" = map ? map.title : null)
	// Other regions follow the mainland's epoch (follow_mainland_epoch).
	if(map)
		.["ordinal_age"] = map.ordinal_age
	// Stations ask before sending a new party (party_train.dm).
	if(kind == "RAILYARD")
		.["free_berths"] = party_train_free_berths()
	// Launch offices ask before founding a station (space/orbit_world.dm).
	if(kind == "ORBIT")
		.["free_planes"] = length(orbit_free_planes())

// Reads one peer's answer to the shard_region topic. A world that answers for
// another group or region id is never shown as that region.
/datum/shard_group/proc/record(id, answer, now)
	var/list/peer = peers[id]
	if(!peer)
		return FALSE
	peer["checked"] = now
	var/list/reply = null
	if(islist(answer)) // the doorman's copy of the peer's answer (poll_once)
		reply = answer
	else if(istext(answer))
		try
			reply = json_decode(answer)
		catch
			reply = null
	if(!islist(reply))
		peer["state"] = "DOWN"
		peer["players"] = null
		return FALSE
	if(reply["group"] != group || reply["region"] != id)
		peer["state"] = "MISMATCH"
		peer["players"] = null
		return FALSE
	peer["state"] = "UP"
	peer["players"] = isnum(reply["players"]) ? reply["players"] : null
	peer["free_berths"] = isnum(reply["free_berths"]) ? reply["free_berths"] : null
	peer["free_planes"] = isnum(reply["free_planes"]) ? reply["free_planes"] : null
	peer["map"] = istext(reply["map"]) ? copytext(reply["map"], 1, 65) : null
	if(id == mainland)
		follow_mainland_epoch(reply["ordinal_age"])
	return TRUE

// Every region keeps the mainland's epoch (Val, 2026-11-05): a fresh region
// would otherwise start at the persistence floor (1943) while the mainland is
// further on. The epoch only moves forward, and the region's own save keeps it.
/datum/shard_group/proc/follow_mainland_epoch(ordinal)
	if(!map || region == mainland || !isnum(ordinal) || ordinal != round(ordinal))
		return FALSE
	if(ordinal <= map.ordinal_age || ordinal >= epoch_names.len)
		return FALSE
	if(!map.set_epoch(ordinal))
		return FALSE
	log_game("Region group: following the mainland [mainland] to the epoch [map.age].")
	to_chat(world, "<big>The Epoch has been changed to <b>[map.age]</b>, as on the mainland.</big>")
	return TRUE

// Whether this world starts its round on its own instead of waiting in the
// lobby for an admin: every region except the mainland does, but only after
// any save load has finished. A world holding a save it did not restore waits
// for an admin rather than starting a fresh round over it.
/datum/shard_group/proc/autostarts_round()
	if(!enabled || !region || region == mainland)
		return FALSE
	if(persistence_restart.startup_hold || map_storage.round_restored)
		return FALSE
	if(fexists("map_saves/map.txt") || fexists("map_saves/round.json") || fexists("map_saves/save_complete.txt"))
		log_game("Region group: a save is present but was not restored, so the round waits for an admin.")
		return FALSE
	return TRUE

// Called by the lobby once any restart load has finished. Waits for world
// setup, then lets the round start on the ordinary countdown as if an admin
// had pressed Start Now.
/proc/region_round_autostart(datum/controller/gameticker/T)
	if(!T || !shard_group.autostarts_round())
		return FALSE
	while(!world_setup_finished)
		sleep(10)
	if(!shard_group.autostarts_round())
		return FALSE
	T.admin_started = TRUE
	log_game("Region group: [shard_group.region] starts its round on its own.")
	return TRUE

// A peer the doorman reports as not awake: ASLEEP (frozen), COLD (stopped
// after a power-down, started from its save on wake), WAKING or DOWN.
/datum/shard_group/proc/record_sleeping(id, list/entry, now)
	var/list/peer = peers[id]
	if(!peer)
		return FALSE
	peer["checked"] = now
	peer["players"] = 0
	switch(entry["state"])
		if("asleep")
			peer["state"] = entry["cold"] ? "COLD" : "ASLEEP"
		if("waking")
			peer["state"] = "WAKING"
		else
			peer["state"] = "DOWN"
			peer["players"] = null
	return TRUE

// One GET of a host helper on this machine (the doorman or the routing relay)
// as a list, or null. Over HTTP with rust_g: world.Export("byond://...") opens a
// BYOND world handshake that these Python helpers cannot answer. Sleeps; gives
// up after five seconds.
/proc/shard_local_query(address, query)
	if(!istext(address) || copytext(address, 1, 11) != "127.0.0.1:")
		return null
	var/datum/http_request/R = new
	R.prepare(RUSTG_HTTP_METHOD_GET, "http://[address]/?[query]", "", list())
	R.begin_async()
	var/deadline = world.timeofday + 50
	while(!R.is_complete())
		if(world.timeofday > deadline || world.timeofday < deadline - 100)
			return null
		sleep(1)
	var/datum/http_response/response = R.into_response()
	if(response.error || !istext(response.body))
		return null
	var/list/reply = null
	try
		reply = json_decode(response.body)
	catch
		reply = null
	return islist(reply) ? reply : null

// The doorman's answer as a list, or null when there is none.
/datum/shard_group/proc/ask_doorman(query)
	if(!doorman)
		return null
	return shard_local_query(doorman, query)

// "port" -> the doorman's entry for every world it hosts, or null.
/datum/shard_group/proc/doorman_states()
	var/list/reply = ask_doorman("host_status=1")
	if(!reply || !islist(reply["instances"]))
		return null
	var/list/by_port = list()
	for(var/list/entry in reply["instances"])
		if(isnum(entry["port"]))
			by_port["[entry["port"]]"] = entry
	return by_port

// Where this world reaches a peer. Regions of a group sharing this world's
// public host run on the same machine, so they are asked over loopback: a call
// to the public address arrives from the public address, and world/Topic bans
// any non-loopback caller that asks more than once every two minutes, which a
// once-a-minute poll always does.
/datum/shard_group/proc/peer_address(list/peer)
	var/target = peer ? peer["address"] : null
	if(!istext(target) || !istext(address))
		return target
	var/host = copytext(address, 1, findlasttext(address, ":"))
	if(host == copytext(target, 1, findlasttext(target, ":")))
		return "127.0.0.1:[shard_address_port(target)]"
	return target

// Asks one peer directly; TRUE when it answered as itself.
/datum/shard_group/proc/poll_peer(id)
	var/list/peer = peers[id]
	if(!peer)
		return FALSE
	var/answer = null
	try
		answer = world.Export("byond://[peer_address(peer)]?shard_region=1&format=json")
	catch
		answer = null
	return record(id, answer, world.time)

/datum/shard_group/proc/poll_once()
	var/list/hosted = doorman_states()
	for(var/id in order.Copy())
		var/list/peer = peers[id]
		if(!peer)
			continue
		var/list/entry = hosted ? hosted["[shard_address_port(peer["address"])]"] : null
		// Asleep or stopped: a direct poll would wake it. A waking world is
		// asked directly, so it reads as up as soon as it answers.
		if(islist(entry) && entry["state"] != "awake" && (entry["state"] != "waking" || !poll_peer(id)))
			record_sleeping(id, entry, world.time)
			continue
		// An awake peer on this host: the doorman asked it within the last
		// half minute, so its answer is read from there. world.Export blocks
		// this world for the whole round trip, spawn() or not (2026-11-07).
		if(islist(entry) && entry["state"] == "awake" && islist(entry["region"]) && isnum(entry["cached_age"]) && entry["cached_age"] <= SHARD_DOORMAN_FRESH_SECONDS)
			record(id, entry["region"], world.time)
			continue
		if(!islist(entry) || entry["state"] == "awake")
			poll_peer(id)

// A peer that is asleep but can be woken through the doorman.
/datum/shard_group/proc/peer_wakeable(id)
	var/list/peer = peers[id]
	return doorman && peer && (peer["state"] in list("ASLEEP", "COLD", "WAKING"))

// Wakes a sleeping peer through the doorman and waits until it answers.
// Null once it is up, otherwise why not. Sleeps; notify hears how long.
/datum/shard_group/proc/wake_peer(id, mob/notify = null)
	var/list/peer = peers[id]
	if(!peer)
		return "That land is not known here."
	if(peer["state"] == "UP")
		return null
	if(!peer_wakeable(id))
		return "Nobody seems to be coming back from [peer["name"]] right now."
	var/list/reply = ask_doorman("wake=1&port=[shard_address_port(peer["address"])]")
	if(!reply)
		return "Nobody answers the call to [peer["name"]] right now. Try again in a while."
	if(!reply["ok"])
		log_game("Region travel: waking [id] was refused: [reply["error"]].")
		if(reply["error"] == "low memory")
			return "[peer["name"]] cannot be reached while this land's host is short of memory. Try again later."
		return "[peer["name"]] cannot be woken right now. Ask an admin."
	var/eta = isnum(reply["eta"]) ? Clamp(reply["eta"], 0, 900) : 60
	if(notify)
		to_chat(notify, SPAN_NOTICE(eta >= 60 ? "[peer["name"]] lies quiet. Word is sent ahead; it may take [round(eta / 60) + 1] minutes. Stay by the trail." : "[peer["name"]] lies quiet. Word is sent ahead; stay by the trail."))
	peer["state"] = "WAKING"
	var/deadline = world.time + (eta + 60) * 10
	while(world.time < deadline)
		sleep(20)
		if(poll_peer(id))
			return null
	return "[peer["name"]] did not answer in time. Try again in a while."

/datum/shard_group/proc/start_polling()
	if(!enabled || polling)
		return
	polling = TRUE
	spawn(0)
		while(enabled)
			poll_once()
			sleep(SHARD_POLL_INTERVAL)
		polling = FALSE

// Region saves use the world's own persistence save loop (start_persistence_loop
// in world.dm), only sooner: at most save_minutes apart, and travel_save_seconds
// after a departure. A traveller can only arrive after the region they left has
// saved without them.
/datum/shard_group/proc/start_saving()
	if(!enabled || saving_loop || !save_minutes)
		return
	saving_loop = TRUE
	spawn(0)
		while(enabled && save_minutes)
			// A restart transaction or a running save sets its own schedule.
			if(nextsave && !persistence_restart.busy && !persistence_save_active() && nextsave - world.realtime > save_minutes * 600)
				nextsave = world.realtime + save_minutes * 600
			sleep(100)
		saving_loop = FALSE

// Moves the next save closer after a departure, never later than planned.
/datum/shard_group/proc/request_save_soon()
	if(!enabled || !save_minutes)
		return
	var/soon = world.realtime + travel_save_seconds * 10
	if(!nextsave || nextsave > soon)
		nextsave = soon

/hook/startup/proc/shard_group_startup()
	// The generated rail yard map uses the plain Nomads metadata; name the
	// world for what it is in the server list and the Regions verb.
	if(shard_group.enabled && shard_group.kind == "RAILYARD" && map && map.type == /obj/map_metadata/nomads)
		map.title = "Rail Yard"
	shard_group.start_polling()
	shard_group.start_saving()
	return TRUE

/datum/world_topic/shard_region
	keyword = "shard_region"

/datum/world_topic/shard_region/Run(list/input)
	if(!shard_group.enabled)
		return list("group" = null)
	var/list/answer = shard_group.describe()
	// The host tool asks for the peer view to check that regions see each other.
	if(input["peers"])
		var/list/seen = list()
		for(var/id in shard_group.order)
			var/list/peer = shard_group.peers[id]
			seen[id] = peer["state"]
		answer["peers"] = seen
	return answer

/datum/shard_group/proc/panel_html()
	var/list/lines = list("<h2>[html_encode(name)]</h2>", "<p>Region group <b>[html_encode(group)]</b>. You are in <b>[html_encode(name)]</b> ([lowertext(kind)]).</p>")
	if(!order.len)
		lines += "<p>This is the only region in the group.</p>"
	else
		lines += "<table><tr><th>Region</th><th>Kind</th><th>State</th><th>Players</th><th></th></tr>"
		for(var/id in order)
			var/list/peer = peers[id]
			var/state = peer["state"]
			var/players = isnum(peer["players"]) ? "[peer["players"]]" : "-"
			// Joining a frozen world wakes it at once; a cold one takes minutes, so it is woken from a trail.
			var/join = (state == "UP" || state == "ASLEEP") ? "<a href='[player_href(id)]'>Join</a>" : ""
			lines += "<tr><td>[html_encode(peer["name"])]</td><td>[lowertext(peer["kind"])]</td><td>[shard_state_text(state)]</td><td>[players]</td><td>[join]</td></tr>"
		lines += "</table>"
		lines += "<p>Your character lives in one region. New characters start on the mainland and reach the others by travelling a trail.</p>"
	return jointext(lines, "")

/proc/shard_state_text(state)
	switch(state)
		if("UP") return "up"
		if("ASLEEP") return "asleep, wakes when someone arrives"
		if("COLD") return "asleep, slow to wake"
		if("WAKING") return "waking up"
		if("UNKNOWN") return "not checked yet"
		if("MISMATCH") return "wrong server"
	return "down"

/client/verb/view_regions()
	set name = "Regions"
	set category = "OOC"
	if(!shard_group.enabled)
		to_chat(src, SPAN_NOTICE("This server is not part of a region group."))
		return
	var/html = shard_group.panel_html()
	if(holder)
		html += region_trail_pending_html()
	src << browse(html, "window=shard_regions;size=520x420")

#undef SHARD_POLL_INTERVAL
#undef SHARD_DOORMAN_FRESH_SECONDS
#undef SHARD_MAX_REGIONS
