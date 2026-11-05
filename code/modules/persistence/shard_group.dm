// Region group (sharded servers). Each region is its own DreamDaemon world
// with its own map and saves; this world learns the other regions of its
// group from config/shard_region.json and shows them to players. It stays off
// while that file is missing or invalid. Built and run by
// scripts/shard-group/shard_group.py; see docs/sharded-worlds.md.

#define SHARD_POLL_INTERVAL 600
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

/datum/shard_group
	var/enabled = FALSE
	var/group = null
	var/region = null
	var/name = null
	var/kind = null
	var/address = null
	// id -> list(name, kind, address, state, players, map, checked)
	var/list/peers = list()
	var/list/order = list()
	var/polling = FALSE
	var/last_error = null

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
		if(!(entry["kind"] in list("SURFACE", "OCEANIC", "UNDERGROUND", "OTHER")))
			return refuse("region [entry["id"]] has an unknown kind")
		if(!shard_address_valid(entry["address"]) || (entry["address"] in seen_addresses))
			return refuse("region [entry["id"]] needs a unique host:port address")
		found += entry["id"]
		seen_addresses += entry["address"]
		if(entry["id"] == settings["region"])
			self = entry
	if(!self)
		return refuse("this region is not in its own region list")
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
	enabled = TRUE
	last_error = null
	return TRUE

// What a peer, the host tool or a player sees of this region.
/datum/shard_group/proc/describe()
	return list("group" = group, "region" = region, "name" = name, "kind" = kind, "players" = length(clients), "map" = map ? map.title : null)

// Reads one peer's answer to the shard_region topic. A world that answers for
// another group or region id is never shown as that region.
/datum/shard_group/proc/record(id, answer, now)
	var/list/peer = peers[id]
	if(!peer)
		return FALSE
	peer["checked"] = now
	var/list/reply = null
	if(istext(answer))
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
	peer["map"] = istext(reply["map"]) ? copytext(reply["map"], 1, 65) : null
	return TRUE

/datum/shard_group/proc/poll_once()
	for(var/id in order.Copy())
		var/list/peer = peers[id]
		if(!peer)
			continue
		var/answer = null
		try
			answer = world.Export("byond://[peer["address"]]?shard_region=1&format=json")
		catch
			answer = null
		record(id, answer, world.time)

/datum/shard_group/proc/start_polling()
	if(!enabled || polling)
		return
	polling = TRUE
	spawn(0)
		while(enabled)
			poll_once()
			sleep(SHARD_POLL_INTERVAL)
		polling = FALSE

/hook/startup/proc/shard_group_startup()
	shard_group.start_polling()
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
			var/join = state == "UP" ? "<a href='byond://[peer["address"]]'>Join</a>" : ""
			lines += "<tr><td>[html_encode(peer["name"])]</td><td>[lowertext(peer["kind"])]</td><td>[state == "UP" ? "up" : (state == "UNKNOWN" ? "not checked yet" : (state == "MISMATCH" ? "wrong server" : "down"))]</td><td>[players]</td><td>[join]</td></tr>"
		lines += "</table>"
		lines += "<p>Joining another region starts a new character there. Characters and their belongings stay in the region where they live.</p>"
	return jointext(lines, "")

/client/verb/view_regions()
	set name = "Regions"
	set category = "OOC"
	if(!shard_group.enabled)
		to_chat(src, SPAN_NOTICE("This server is not part of a region group."))
		return
	src << browse(shard_group.panel_html(), "window=shard_regions;size=520x360")

#undef SHARD_POLL_INTERVAL
#undef SHARD_MAX_REGIONS
