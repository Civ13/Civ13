// Routing relay for a region group (scripts/gaia-host/relay.py). With it, a
// group needs only two public ports: the gate region's own port (the mainland
// by default), which players join directly, and the relay's port. Every other
// region's port stays closed on the router.
//
// The relay cannot tell who connects, only from where, so a world that knows
// the player (the gate at login, or the region a traveller leaves) writes a
// route for the player's address on the relay's loopback control port and then
// links the player to the relay, which pipes that address to the routed region.
// A region reached through the relay sees the player with no address (a local
// connection); it asks the relay for the address it routed for that key, so
// bans, logs and the alt check keep the player's real address.
//
// Off unless config/shard_region.json names relay, relay_control and gate and
// config/relay-token.txt holds the group's token (written by shard_group.py).

/datum/shard_group/var/relay = null          // public host:port players are linked to
/datum/shard_group/var/relay_control = null  // 127.0.0.1:port, Topic framing, token required
/datum/shard_group/var/relay_token = null
/datum/shard_group/var/gate = null           // region id players join directly

/client/var/relay_address = null   // the address the relay routed for this key, when relayed
/client/var/relay_checked = FALSE  // TRUE once the relay was asked (or there is none)

/proc/region_relay_hex(value)
	if(!istext(value) || length(value) < 32 || length(value) > 128)
		return FALSE
	for(var/i = 1, i <= length(value), i++)
		var/c = text2ascii(value, i)
		if(!((c >= 48 && c <= 57) || (c >= 97 && c <= 102)))
			return FALSE
	return TRUE

// A plain IPv4 or IPv6 address as the relay reports it (digits, a-f, dots and colons).
/proc/region_relay_ip_valid(value)
	if(!istext(value) || !length(value) || length(value) > 45)
		return FALSE
	for(var/i = 1, i <= length(value), i++)
		var/c = text2ascii(value, i)
		if(!((c >= 48 && c <= 58) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70) || c == 46))
			return FALSE
	return TRUE

// TRUE for an IPv4 address on a private network (10/8, 172.16/12, 192.168/16),
// carrier-grade NAT (100.64/10) or loopback: one a router hides behind its own.
/proc/region_relay_ip_private(value)
	if(!istext(value))
		return FALSE
	var/list/parts = splittext(value, ".")
	if(length(parts) != 4)
		return FALSE
	var/a = text2num(parts[1])
	var/b = text2num(parts[2])
	if(!isnum(a) || !isnum(b))
		return FALSE
	return a == 10 || a == 127 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168) || (a == 100 && b >= 64 && b <= 127)

// TRUE for a loopback address: how a player the relay brought here appears.
/proc/region_relay_ip_loopback(value)
	return value == "127.0.0.1" || value == "::1"

// The address to route a player's next connection for, from the address this
// world sees for them and its own internet address. A player on the host's
// network (a LAN address) reaches the relay from the router's public address,
// so that address is routed. A player the relay brought here appears from
// loopback: that is passed on as it is, and the relay keeps the route it holds
// for the player's own address. Rewriting loopback to the host's public address
// moved the route off the player, who then arrived unrouted (TDM Barracks to
// Battle behind the gateway, 2026-11-21).
/proc/region_relay_route_ip(public, internet)
	if(region_relay_ip_private(public) && !region_relay_ip_loopback(public) && region_relay_ip_valid(internet) && !region_relay_ip_private(internet))
		return internet
	return public

/datum/shard_group/proc/configure_relay(list/settings)
	relay = null
	relay_control = null
	relay_token = null
	gate = null
	if(isnull(settings["relay"]))
		return FALSE
	var/token = fexists("config/relay-token.txt") ? trim(file2text("config/relay-token.txt")) : null
	var/target = settings["gate"]
	if(!shard_address_valid(settings["relay"]) || !shard_address_valid(settings["relay_control"]) || copytext(settings["relay_control"], 1, 11) != "127.0.0.1:" \
		|| !region_relay_hex(token) || !(target == region || peers[target]))
		world.log << "Region group: the routing relay settings are not valid; players are sent to region ports directly."
		return FALSE
	relay = settings["relay"]
	relay_control = settings["relay_control"]
	relay_token = token
	gate = target
	return TRUE

/datum/shard_group/proc/relay_on()
	return enabled && relay && relay_token

// The answer of one control request, or null.
/datum/shard_group/proc/ask_relay(query)
	if(!relay_on())
		return null
	return shard_local_query(relay_control, "[query]&token=[relay_token]")

// The address players use to join the gate region.
/datum/shard_group/proc/gate_address()
	if(gate == region)
		return address
	var/list/peer = peers[gate]
	return peer ? peer["address"] : null

// A link that sends the player to region id: through the relay when there is
// one (a Topic of this world writes the route first), else straight to its port.
/datum/shard_group/proc/player_href(id)
	var/list/peer = peers[id]
	if(!peer)
		return ""
	if(relay_on())
		return "byond://?region_go=[url_encode(id)]"
	return "byond://[peer["address"]]"

// Sends a client to region id. Through the relay this needs the player's real
// address; a local client (the host) is linked to the region's port directly.
// Sleeps (the relay and, with wake, the doorman are asked). TRUE when linked.
/datum/shard_group/proc/send_player(client/C, id, wake = TRUE, expected_slot = 0)
	var/list/peer = peers[id]
	if(!C || !peer || !peer["address"])
		return FALSE
	// This query can only make the receiving world deny a stale handoff.
	var/slot_check = region_gateway_roster_enabled(C) && isnum(expected_slot) && expected_slot == round(expected_slot) && expected_slot >= 1 && expected_slot <= character_slots_max ? "?character_expected_slot=[expected_slot]" : ""
	var/public = C.public_address()
	if(!relay_on())
		C << link("byond://[peer["address"]][slot_check]")
		return TRUE
	// The gate's own port is public and players join it directly; going
	// through the relay there left players from a relayed region waiting for a
	// manual reconnect (North America to Gaia after Gaia became the gate,
	// 2026-11-16). The gate checks their home again at login.
	if(id == gate)
		C << link("byond://[peer["address"]]")
		return TRUE
	// The relay sent the gateway a login it had no route for (a player who
	// rejoined the relay's port straight from BYOND's reconnect or recent servers
	// list, 2026-11-23). No route ever names the gateway, so a non-local player
	// here from loopback came that way; a route for them would name loopback (or
	// an old address the relay still holds for their key) and they would come
	// back unrouted again. The gateway's own public port sees their address:
	// they join that, and are sent on from there.
	if(kind == "GATEWAY" && gate == region && (!C.address || region_relay_ip_loopback(C.address)) && !C.local_connection() && gate_address())
		to_chat(C, SPAN_NOTICE("Reconnecting you through the front door..."))
		var/roster = slot_check ? "?character_lobby=1" : ""
		C << link("byond://[gate_address()][roster]")
		return TRUE
	if(!public)
		// Region ports are closed to the internet behind a relay; only a true
		// local connection (the host) can use one directly.
		if(C.local_connection())
			C << link("byond://[peer["address"]][slot_check]")
			return TRUE
		to_chat(C, SPAN_WARNING("The way to [html_encode(peer["name"])] cannot be found from here. Reconnect through [html_encode(gate_address())] and try again."))
		return FALSE
	if(wake && peer["state"] != "UP")
		// A land the doorman can wake or start is asked through it: a direct poll of one
		// in cold storage or stopped fails and read it as down, which turned the player away.
		// The doorman is asked first: the state here may be an old failed poll.
		if(!peer_wakeable(id))
			refresh_peer(id)
		if(peer["state"] != "UP")
			var/why = wake_peer(id, C.mob)
			if(why)
				if(C) to_chat(C, SPAN_WARNING(why))
				return FALSE
	if(!C)
		return FALSE
	var/port = shard_address_port(peer["address"])
	// A player on the host's own network reached this world from a LAN address,
	// but their link to the relay goes out through the router and comes back
	// from its public address (Val, Join to Gaia, 2026-11-15): route that one.
	public = region_relay_route_ip(public, world.internet_address)
	var/route = "route=1&ip=[url_encode(public)]&ckey=[url_encode(C.ckey)]&port=[port]"
	var/list/reply = ask_relay(route)
	if(reply && !reply["ok"] && C)
		// A relay started before this region joined the group refuses its port
		// (South America, 2026-11-15). The port is the group's own, from
		// shard_region.json: teach it to the relay and try once more.
		var/list/taught = ask_relay("add_port=1&port=[port]")
		if(taught && taught["ok"] && C)
			log_game("Region relay: the relay did not know [id]'s port [port]; added it.")
			reply = ask_relay(route)
	if(!reply || !reply["ok"])
		log_game("Region relay: could not route [C.ckey] to [id].")
		if(C) to_chat(C, SPAN_WARNING("The way to [html_encode(peer["name"])] is closed right now. Try again in a minute or ask an admin."))
		return FALSE
	if(!C)
		return FALSE
	C << link("byond://[relay][slot_check]")
	return TRUE

// send_player without waking, without holding up the caller (a departure or reset).
/datum/shard_group/proc/send_player_soon(client/C, id)
	set waitfor = FALSE
	send_player(C, id, FALSE)

// The address the relay routed for this client's key into this world, or null.
/datum/shard_group/proc/relay_lookup(client/C)
	var/list/reply = ask_relay("lookup=1&ckey=[url_encode(C.ckey)]")
	if(!reply || !reply["ok"] || reply["port"] != shard_address_port(address) || !region_relay_ip_valid(reply["ip"]))
		return null
	return reply["ip"]

// The player's real address: their own, or the one the relay routed for them.
// Null only for a local connection (the host).
/client/proc/public_address()
	if(relay_address && (!address || region_relay_ip_loopback(address)))
		return relay_address
	return address || relay_address

// A connection from this machine that the relay did not bring here. The relay
// arrives with no address too, so with a relay a local client is one the relay
// has no route for. Defence in depth for local-only operator verbs.
/client/proc/local_connection()
	if(address && address != "127.0.0.1" && address != "::1")
		return FALSE
	if(relay_address)
		return FALSE
	// With a relay, a lookup that found nothing may still be a relayed player:
	// only the host's own key counts as local then.
	return !shard_group.relay_on() || (relay_checked && world.host && key == world.host)

/client/New(TopicData)
	if(istext(TopicData) && length(TopicData) <= 4096)
		var/list/options = params2list(TopicData)
		if(region_gateway_here())
			gateway_character_lobby = options["character_lobby"] == "1"
			gateway_public_overview = options["world_overview"] == "1" && region_gateway_overview_allowed(src)
		else if("character_expected_slot" in options)
			var/expected = options["character_expected_slot"]
			gateway_expected_slot = (expected in list("1", "2", "3", "4")) ? text2num(expected) : -1
	// Before the bans and the login log read the address.
	// The relay's connections arrive from loopback (or with no address at all).
	if((!address || region_relay_ip_loopback(address)) && shard_group.relay_on())
		relay_address = shard_group.relay_lookup(src)
	relay_checked = TRUE
	return ..()

// Join, Go there and Refresh links of the Regions panel and the home notice.
/client/Topic(href, href_list, hsrc)
	if(href_list["gateway_tab"])
		var/mob/new_player/gateway_lobby = mob
		if(usr != mob || !istype(gateway_lobby) || !region_gateway_overview_allowed(src) || next_gateway_tab > world.time)
			return
		next_gateway_tab = world.time + 5
		if(href_list["gateway_tab"] == "overview")
			region_gateway_show_overview(gateway_lobby)
		else if(href_list["gateway_tab"] == "characters" && !region_gateway_overview_session(src))
			region_gateway_show_roster(gateway_lobby)
		return
	// A public overview connection grants no gateway routes or private UI.
	if(region_gateway_overview_session(src))
		return
	if(href_list["gateway_character_slot"])
		var/mob/new_player/lobby = mob
		if(usr != mob || !istype(lobby) || !region_gateway_roster_enabled(src) || next_region_go > world.time)
			return
		next_region_go = world.time + 50
		region_gateway_choose_character(lobby, text2num(href_list["gateway_character_slot"]))
		return
	if(href_list["region_go"])
		if(usr != mob || !shard_group.enabled)
			return
		var/id = href_list["region_go"]
		if(!shard_group.peers[id])
			return
		if(next_region_go > world.time)
			return
		next_region_go = world.time + 50
		shard_group.send_player(src, id)
		return
	// The gateway's Try again link (region_gateway.dm).
	if(href_list["gateway_retry"])
		if(!region_gateway_here() || !istype(mob, /mob/new_player) || usr != mob)
			return
		if(next_region_go > world.time)
			return
		next_region_go = world.time + 50
		region_gateway_forward(mob)
		return
	// The gateway's practice rooms link while a land cannot be reached (region_gateway.dm).
	if(href_list["gateway_practice"])
		if(!region_gateway_here() || !istype(mob, /mob/new_player) || usr != mob)
			return
		var/practice = tutorial_region_peer()
		if(practice)
			tutorial_region_send(src, practice)
		return
	// The Regions panel's Refresh: ask the regions again and redraw it in place.
	if(href_list["region_refresh"])
		if(usr != mob || !shard_group.enabled)
			return
		if(next_region_refresh > world.time)
			return
		next_region_refresh = world.time + 30
		shard_group.refresh_now()
		view_regions()
		return
	return ..()

/client/var/tmp/next_gateway_tab = 0
/client/var/next_region_go = 0
/client/var/next_region_refresh = 0

// The gate: a player whose character lives in another land is sent there at
// once. Admins stay (they may have work here) and are told how to go.
/mob/new_player/Login()
	. = ..()
	if(QDELETED(src) || !client || client.mob != src)
		return
	// The front door routes normal connections; an explicit Characters
	// connection first shows its authenticated player's private roster.
	if(region_gateway_here())
		var/link = region_gateway_overview_link()
		if(link && !client.gateway_character_lobby && !region_gateway_overview_session(client))
			to_chat(src, SPAN_NOTICE("Browse the Persistence [link] by connecting through that link."))
		region_gateway_forward(src)
	else if(shard_group.relay_on() && shard_group.region == shard_group.gate)
		region_gate_forward(src)

/proc/region_gate_forward(mob/new_player/lobby)
	set waitfor = FALSE
	var/client/C = lobby ? lobby.client : null
	if(!C || IsGuestKey(C.key) || !C.public_address() || !region_home_enabled())
		return FALSE
	// The same question Join asks (without custody); only an account that
	// already lives elsewhere moves on.
	var/list/result = transfer_bridge.request("/account", list("ckey" = C.ckey, "op" = "claim"))
	result = (result && result["ok"] && islist(result["result"])) ? result["result"] : null
	if(!result || result["verdict"] != "ELSEWHERE" || !shard_group.peers[result["home"]])
		return FALSE
	if(!lobby || lobby.client != C)
		return FALSE
	var/list/peer = shard_group.peers[result["home"]]
	if(C.holder)
		to_chat(C, SPAN_NOTICE("Your character lives in [html_encode(peer["name"])]. <a href='[shard_group.player_href(result["home"])]'>Go there</a>"))
		return FALSE
	to_chat(C, SPAN_NOTICE("Your character lives in [html_encode(peer["name"])]. Taking you there..."))
	return shard_group.send_player(C, result["home"])
