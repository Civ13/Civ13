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
/datum/shard_group/proc/send_player(client/C, id, wake = TRUE)
	var/list/peer = peers[id]
	if(!C || !peer || !peer["address"])
		return FALSE
	var/public = C.public_address()
	if(!relay_on())
		C << link("byond://[peer["address"]]")
		return TRUE
	if(!public)
		// Region ports are closed to the internet behind a relay; only a true
		// local connection (the host) can use one directly.
		if(C.local_connection())
			C << link("byond://[peer["address"]]")
			return TRUE
		to_chat(C, SPAN_WARNING("The way to [html_encode(peer["name"])] cannot be found from here. Reconnect through [html_encode(gate_address())] and try again."))
		return FALSE
	if(wake && peer["state"] != "UP")
		poll_peer(id)
		if(peer["state"] != "UP")
			var/why = wake_peer(id, C.mob)
			if(why)
				if(C) to_chat(C, SPAN_WARNING(why))
				return FALSE
	if(!C)
		return FALSE
	var/list/reply = ask_relay("route=1&ip=[url_encode(public)]&ckey=[url_encode(C.ckey)]&port=[shard_address_port(peer["address"])]")
	if(!reply || !reply["ok"])
		log_game("Region relay: could not route [C.ckey] to [id].")
		if(C) to_chat(C, SPAN_WARNING("The way to [html_encode(peer["name"])] is closed right now. Try again in a minute or ask an admin."))
		return FALSE
	if(!C)
		return FALSE
	C << link("byond://[relay]")
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
	// Before the bans and the login log read the address.
	if(!address && shard_group.relay_on())
		relay_address = shard_group.relay_lookup(src)
	relay_checked = TRUE
	return ..()

// Join and Go there links of the Regions panel and the home notice.
/client/Topic(href, href_list, hsrc)
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
	return ..()

/client/var/next_region_go = 0

// The gate: a player whose character lives in another land is sent there at
// once. Admins stay (they may have work here) and are told how to go.
/mob/new_player/Login()
	. = ..()
	if(!QDELETED(src) && client && client.mob == src && shard_group.relay_on() && shard_group.region == shard_group.gate)
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
