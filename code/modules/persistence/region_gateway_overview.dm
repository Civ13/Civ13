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
		characters = overview ? "<a href='byond://?gateway_tab=characters'>Characters</a>" : "<strong aria-current='page'>Characters</strong>"
	var/atlas = overview ? "<strong aria-current='page'>World Overview</strong>" : "<a href='byond://?gateway_tab=overview'>World Overview</a>"
	return "<div class='gw-tabs'>[characters][atlas]</div>"

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

// The tone of a public state. Every tone is also spelled out in the table.
/proc/region_gateway_public_tone(state)
	switch(state)
		if("Online") return "gw-good"
		if("Asleep") return "gw-info"
		if("Starting") return "gw-warn"
	return ""

// The atlas's own additions to the gateway look (layout by Fable): a sea
// chart with one numbered pin per region, round for a land and square for an
// ocean, and the same numbers down the table.
/proc/region_gateway_overview_style()
	return {"<style>
		.gw-chart{position:relative;height:340px;margin:0 0 6px;border:1px solid #66513b;border-radius:4px;overflow:hidden;background-color:#18283a;background-image:linear-gradient(#22364b 1px,transparent 1px),linear-gradient(90deg,#22364b 1px,transparent 1px);background-size:34px 34px}
		.gw-north{position:absolute;right:8px;top:6px;font-size:10px;letter-spacing:.1em;color:#8fa6bd}
		.gw-place{position:absolute;white-space:nowrap;font-size:11px;line-height:16px;color:#e8eef5;transform:translateY(-50%)}
		.gw-place.gw-left{transform:translate(-100%,-50%)}
		.gw-place.gw-left .gw-pin{margin:0 0 0 5px}
		.gw-place.gw-sea{font-style:italic;color:#a9c4de}
		.gw-pin{display:inline-block;vertical-align:top;box-sizing:border-box;width:16px;height:16px;margin-right:5px;border:1px solid #a99b87;border-radius:8px;background:#443623;color:#eee5d3;font-style:normal;font-size:10px;line-height:14px;text-align:center}
		.gw-sea .gw-pin{border-radius:3px}
		.gw-pin.gw-good{border-color:#6caa68;background:#253b25;color:#c4e8c0}
		.gw-pin.gw-info{border-color:#6fb3e0;background:#1f3342;color:#cfe6f7}
		.gw-pin.gw-warn{border-color:#c77a39;background:#3d2a18;color:#f3c79a}
		.gw-key{color:#bfae96;font-size:11.5px;margin:0 0 12px}
		.gw-key .gw-pin{margin:0 4px 0 12px}
		.gw-key>.gw-pin:first-child{margin-left:0}
		.gw-list{background:#30271e;border:1px solid #66513b;border-radius:4px;padding:6px 12px}
		.gw-table{width:100%;border-collapse:collapse;text-align:left}
		.gw-table th{font-size:10px;font-weight:normal;letter-spacing:.1em;text-transform:uppercase;color:#bfae96;padding:5px 6px;border-bottom:1px solid #66513b}
		.gw-table td{padding:5px 6px;border-bottom:1px solid #54432f}
		.gw-table tr:last-child td{border-bottom:0}
		.gw-table td.gw-dim{color:#a99b87}
		.gw-table .gw-pill{margin-left:0}
		.gw-table .gw-pin{margin-right:7px}
		</style>"}

/proc/region_gateway_overview_html(client/C)
	var/list/lines = list("<html><head><title>World Overview</title>[region_gateway_style()][region_gateway_overview_style()]</head><body><div class='gw'>[region_gateway_tabs(C, TRUE)]<div class='gw-eyebrow'>Public &middot; no characters shown</div><h1>World Overview</h1><p class='gw-lede'>The public lands and oceans, with north at the top. The chart shows where they lie, not how far apart they are.</p>")
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
		var/shape = kind == "Land" ? "" : " gw-sea"
		var/state = region_gateway_public_state(peer, world.time)
		var/tone = region_gateway_public_tone(state)
		var/players = region_gateway_public_players(peer, state)
		var/epoch = kind == "Land" ? region_gateway_public_epoch(peer, state) : "&mdash;"
		var/settlement = kind == "Land" ? html_encode(land_stage_column(id, "SURFACE")) : ""
		count++
		var/pin = "<span class='gw-pin [tone]'>[count]</span>"
		// Near the east edge the name goes to the left of its pin.
		markers += at_x > 70 ? "<div class='gw-place gw-left[shape]' style='left:[at_x]%;top:[at_y]%'>[name][pin]</div>" : "<div class='gw-place[shape]' style='left:[at_x]%;top:[at_y]%'>[pin][name]</div>"
		rows += "<tr[shape ? " class='gw-sea'" : ""]><td>[pin]<b>[name]</b></td><td>[kind]</td><td><span class='gw-pill [tone]'>[state]</span></td><td[players == "&mdash;" ? " class='gw-dim'" : ""]>[players]</td><td[epoch == "&mdash;" ? " class='gw-dim'" : ""]>[epoch]</td><td[settlement ? "" : " class='gw-dim'"]>[settlement ? capitalize(settlement) : "&mdash;"]</td></tr>"
	if(count)
		lines += "<div class='gw-chart' aria-label='Public world schematic'><span class='gw-north'>N &uarr;</span>[jointext(markers, "")]</div>"
		lines += "<p class='gw-key'><span class='gw-pin'>1</span>Land<span class='gw-sea'><span class='gw-pin'>2</span></span>Ocean<span class='gw-pin gw-good'>&nbsp;</span>Online<span class='gw-pin gw-info'>&nbsp;</span>Asleep<span class='gw-pin gw-warn'>&nbsp;</span>Starting<span class='gw-pin'>&nbsp;</span>Offline or unknown</p>"
		lines += "<div class='gw-list'><table class='gw-table'><tr><th>Region</th><th>Type</th><th>Status</th><th>Players</th><th>Epoch</th><th>Settlement</th></tr>[jointext(rows, "")]</table></div>"
		lines += "<p class='gw-note'>Status is sampled every so often. A dash means the figure is unknown or does not apply; 0 means nobody is online. Looking here never wakes a land. <a href='byond://?gateway_tab=overview'>Refresh</a></p>"
	else
		lines += "<p class='gw-lede'>No public lands or oceans are set up for this group.</p>"
	if(region_gateway_overview_session(C))
		lines += "<p class='gw-note'>This connection is read-only. To play, reconnect through the usual address.</p>"
	lines += "</div></body></html>"
	return jointext(lines, "")

/proc/region_gateway_show_overview(mob/new_player/lobby)
	var/client/C = lobby?.client
	if(!C || C.mob != lobby || !region_gateway_overview_allowed(C))
		return FALSE
	show_browse(C, region_gateway_overview_html(C), "window=gateway_characters;size=680x720")
	return TRUE

#undef GATEWAY_PUBLIC_STATUS_AGE
