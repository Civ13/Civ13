// Public atlas for the Persistence front door. It is a projection of the
// configured fixed-world map and already sampled status, never the expedition
// chart. Viewing it does not contact, wake, join or transfer to another world.

#define GATEWAY_PUBLIC_STATUS_AGE (120 SECONDS)

/client/var/tmp/gateway_public_overview = FALSE // explicit view-only connection

/proc/region_gateway_overview_allowed(client/C)
	return C && region_gateway_here() && !!region_gateway_roster_address()

/proc/region_gateway_overview_session(client/C)
	return C && C.gateway_public_overview

/proc/region_gateway_tabs(client/C, overview = FALSE)
	var/characters = ""
	if(region_gateway_roster_enabled(C) && !region_gateway_overview_session(C))
		characters = overview ? "<a href='byond://?gateway_tab=characters'>Characters</a> | " : "<strong aria-current='page'>Characters</strong> | "
	var/atlas = overview ? "<strong aria-current='page'>World Overview</strong>" : "<a href='byond://?gateway_tab=overview'>World Overview</a>"
	return "<p class='tabs'>[characters][atlas]</p>"

/proc/region_gateway_overview_link()
	var/address = region_gateway_roster_address()
	return address ? "<a href='byond://[address]?world_overview=1'>World Overview</a> (read-only)" : ""

/proc/region_gateway_atlas_position(id, kind)
	if(kind == "SURFACE")
		var/list/land = continent_layout[id]
		return islist(land) ? list(land[1], land[2], "Land") : null
	if(kind == "OCEANIC")
		var/list/ocean = world_oceans[id]
		return islist(ocean) ? list(ocean[4], ocean[5], "Ocean") : null
	return null

/proc/region_gateway_public_state(list/peer, now)
	var/checked = peer["checked"]
	if(!isnum(checked) || checked > now || now - checked > GATEWAY_PUBLIC_STATUS_AGE)
		return "Unknown"
	switch(peer["state"])
		if("UP") return "Online"
		if("ASLEEP", "COLD") return "Asleep"
		if("WAKING") return "Starting"
		if("STOPPED") return "Offline"
	return "Unknown"

/proc/region_gateway_public_players(list/peer, state)
	var/players = peer["players"]
	if(state != "Online" || !isnum(players) || players < 0 || players > 10000 || players != round(players))
		return "&mdash;"
	return "[players]"

/proc/region_gateway_public_epoch(list/peer, state)
	var/age = peer["ordinal_age"]
	if(state != "Online" || !isnum(age) || age != round(age) || !ordinal_age_year(age))
		return "&mdash;"
	return ordinal_age_name(age)

/proc/region_gateway_overview_html(client/C)
	var/list/lines = list("<html><head><title>World Overview</title><style>body{background:#19212b;color:#e7eef5;font-family:sans-serif}a{color:#a1d6ff}.chart{position:relative;height:260px;border:1px solid #52708c;background:#20364a;margin:12px 0}.pin{position:absolute;border:1px solid #edf1f5;border-radius:12px;min-width:18px;line-height:18px;text-align:center;background:#315774;color:#fff;font-size:11px}.land{background:#3f674d}table{width:100%;text-align:left;border-collapse:collapse}th,td{padding:3px 6px;border-bottom:1px solid #364959}</style></head><body>[region_gateway_tabs(C, TRUE)]<h2>World Overview</h2><p>Public lands and oceans, north up. This schematic shows relative positions, not navigable distances.</p>")
	var/list/markers = list()
	var/list/rows = list()
	var/count = 0
	for(var/id in shard_group.order)
		var/list/peer = shard_group.peers[id]
		if(!islist(peer))
			continue
		var/list/place = region_gateway_atlas_position(id, peer["kind"])
		if(!place || !istext(peer["name"]))
			continue
		var/name = html_encode(peer["name"])
		var/at_x = clamp(round(5 + place[1] * 3.45), 4, 92)
		var/at_y = clamp(round(7 + (13 - place[2]) * 4.7), 4, 92)
		var/kind = place[3]
		var/colour = kind == "Land" ? "land" : "ocean"
		var/state = region_gateway_public_state(peer, world.time)
		var/players = region_gateway_public_players(peer, state)
		var/epoch = kind == "Land" ? region_gateway_public_epoch(peer, state) : "&mdash;"
		var/settlement = kind == "Land" ? html_encode(land_stage_column(id, "SURFACE")) : ""
		count++
		markers += "<span class='pin [colour]' style='left:[at_x]%;top:[at_y]%'>[count]</span>"
		rows += "<tr><td>[count]. [name]</td><td>[kind]</td><td>[state]</td><td>[players]</td><td>[epoch]</td><td>[settlement]</td></tr>"
	if(count)
		lines += "<div class='chart' aria-label='Public world schematic'>[jointext(markers, "")]</div>"
		lines += "<table><tr><th>Region</th><th>Type</th><th>Status</th><th>Players</th><th>Epoch</th><th>Settlement</th></tr>[jointext(rows, "")]</table>"
		lines += "<p>Status is sampled periodically. A dash means the count or epoch is unavailable or not applicable. <a href='byond://?gateway_tab=overview'>Refresh view</a>.</p>"
	else
		lines += "<p>No configured public atlas regions are available for this group.</p>"
	if(region_gateway_overview_session(C))
		lines += "<p>This connection is read-only. To play, reconnect through the usual Persistence address.</p>"
	lines += "</body></html>"
	return jointext(lines, "")

/proc/region_gateway_show_overview(mob/new_player/lobby)
	var/client/C = lobby?.client
	if(!C || C.mob != lobby || !region_gateway_overview_allowed(C))
		return FALSE
	show_browse(C, region_gateway_overview_html(C), "window=gateway_characters;size=660x640")
	return TRUE

#undef GATEWAY_PUBLIC_STATUS_AGE
