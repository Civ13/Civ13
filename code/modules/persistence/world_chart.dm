// The world chart for boat expeditions (docs/world-chart.md). The group
// coordinator keeps a grid of ocean and land tiles. A land tile gets its
// template (biome, land type, size, coasts, features, resources, seed) the
// first time a ship sees it, and keeps it unless an admin rerolls it. The
// chart never builds a world; a later step builds one from the template when
// a crew sets course for it. For now admins can look at the chart and reroll
// charted tiles from Admin > World Chart; each world reads its agent's copy.

var/global/list/world_chart = list() // the coordinator's last snapshot, decoded
var/global/world_chart_pending = 0 // admin chart requests the coordinator has not decided yet

/proc/world_chart_refresh()
	if(!shard_group.enabled || !transfer_bridge || !transfer_bridge.enabled())
		return FALSE
	var/list/answer = transfer_bridge.request("/chart", list())
	if(!answer || !answer["ok"] || !islist(answer["result"]))
		return FALSE
	var/list/result = answer["result"]
	if(!islist(result["chart"]))
		return FALSE
	world_chart = result["chart"]
	world_chart_pending = islist(result["pending"]) ? length(result["pending"]) : 0
	return TRUE

/proc/world_chart_biome_name(code)
	switch(code)
		if("ICE_SHEET") return "ice sheet"
		if("TUNDRA") return "tundra"
		if("BOREAL") return "boreal forest"
		if("TEMPERATE_FOREST") return "temperate forest"
		if("GRASSLAND") return "grassland"
		if("DESERT") return "desert"
		if("SAVANNA") return "savanna"
		if("RAINFOREST") return "rainforest"
		if("SWAMP") return "swamp"
	return "unknown land"

/proc/world_chart_cell_colour(letter)
	switch(letter)
		if(".") return "#1d3b5c"
		if("@") return "#c0392b"
		if("I") return "#e8f0f4"
		if("T") return "#9aa79a"
		if("B") return "#2f5d3a"
		if("F") return "#3f7f3a"
		if("G") return "#9bbf5a"
		if("D") return "#d9c27a"
		if("S") return "#c9a95a"
		if("R") return "#1f6b2e"
		if("W") return "#5a6b3a"
	return "#333"

// "tiny", "small", ... with the land type, for a charted tile's template.
/proc/world_chart_tile_label(list/template)
	if(!islist(template))
		return "?"
	var/size = istext(template["size"]) ? lowertext(template["size"]) : "?"
	var/kind = istext(template["land_type"]) ? replacetext(lowertext(template["land_type"]), "_", " ") : "?"
	return "[size] [world_chart_biome_name(template["biome"])], [kind]"

/proc/world_chart_admin_html()
	var/list/lines = list()
	var/list/rows = world_chart["rows"]
	if(!islist(rows) || !length(rows))
		return "<p class='note'>The world chart has not been read from the world directory yet.</p>"
	var/list/tiles = islist(world_chart["tiles"]) ? world_chart["tiles"] : list()
	var/height = length(rows)
	lines += "<table class='chart'>"
	for(var/r in 1 to height)
		var/row = rows[r]
		if(!istext(row))
			continue
		var/y = height - r
		lines += "<tr>"
		for(var/x in 0 to length(row) - 1)
			var/letter = copytext(row, x + 1, x + 2)
			var/list/found = tiles["[x],[y]"]
			var/mark = islist(found) ? "<b>&bull;</b>" : ""
			var/tip = islist(found) ? html_encode(world_chart_tile_label(found["template"])) : (letter == "@" ? "mainland" : (letter == "." ? "ocean" : "uncharted land"))
			lines += "<td style='background:[world_chart_cell_colour(letter)]' title='[x],[y]: [tip]'>[mark]</td>"
		lines += "</tr>"
	lines += "</table>"
	lines += "<p class='note'>North is up. Dots are charted lands. Hover a tile for its position.</p>"
	if(length(tiles))
		lines += "<table class='regions'><tr><th>Tile</th><th>Land</th><th>Tiles</th><th>Coasts</th><th>Ore</th><th>Rare</th><th>Game</th><th>State</th></tr>"
		for(var/key in tiles)
			var/list/found = tiles[key]
			if(!islist(found))
				continue
			var/list/template = found["template"]
			if(!islist(template))
				continue
			var/list/resources = islist(template["resources"]) ? template["resources"] : list()
			var/list/ores = islist(resources["ores"]) ? resources["ores"] : list()
			var/list/rare = islist(resources["rare"]) ? resources["rare"] : list()
			var/list/game = islist(resources["game"]) ? resources["game"] : list()
			var/list/coast = islist(template["coast"]) ? template["coast"] : list()
			lines += "<tr><td>[html_encode(key)]</td><td>[html_encode(world_chart_tile_label(template))]</td><td>[template["width"]] x [template["height"]]</td><td>[html_encode(length(coast) ? jointext(coast, " ") : "none (inland)")]</td><td>[html_encode("[resources["ore"]]: [jointext(ores, ", ")]")]</td><td>[html_encode(jointext(rare, ", "))]</td><td>[html_encode(jointext(game, ", "))]</td><td>[html_encode("[found["state"]]")][found["reroll"] ? " (rerolled [found["reroll"]])" : ""]</td></tr>"
		lines += "</table>"
	else
		lines += "<p class='note'>No land has been charted yet: lands are charted when a ship first sees them.</p>"
	if(world_chart_pending)
		lines += "<p class='note'>Waiting for the world directory: [world_chart_pending] change(s).</p>"
	return jointext(lines, "")

// Charted tiles an admin may reroll: "x,y: label" = list(x, y).
/proc/world_chart_reroll_choices()
	var/list/choices = list()
	var/list/tiles = islist(world_chart["tiles"]) ? world_chart["tiles"] : list()
	for(var/key in tiles)
		var/list/found = tiles[key]
		if(!islist(found) || found["state"] != "CHARTED" || found["region"])
			continue
		var/list/xy = splittext(key, ",")
		if(length(xy) != 2)
			continue
		choices["[key]: [world_chart_tile_label(found["template"])]"] = list(text2num(xy[1]), text2num(xy[2]))
	return choices

/datum/admins/proc/world_chart_panel()
	set category = "Admin"
	set name = "World Chart"
	set desc = "See the world chart for boat expeditions and reroll a charted land's template."
	if(!check_rights(R_ADMIN)) return
	var/mob/M = usr
	if(!M || !M.client) return
	if(!shard_group.enabled)
		to_chat(M, SPAN_WARNING("This server is not part of a region group, so it has no world chart."))
		return
	world_chart_refresh()
	var/datum/browser/popup = new(M, "world_chart", "World Chart", 900, 640)
	popup.add_head_content("<style>table.chart{border-collapse:collapse}table.chart td{width:12px;height:12px;padding:0;font-size:8px;text-align:center;color:#000}table.regions{border-collapse:collapse;width:100%;margin-top:8px}table.regions th,table.regions td{padding:2px 5px;text-align:left;border-bottom:1px solid #444}p.note{color:#c96}</style>")
	popup.set_content(world_chart_admin_html())
	popup.open(FALSE)
	var/list/pins = islist(world_chart["pins"]) ? world_chart["pins"] : list()
	var/list/actions = list("Reroll a charted land", "Chart round the mainland (testing)", "Close")
	var/action = WWinput(M, "What do you want to do with the world chart?", "World Chart", "Close", actions)
	if(!action || action == "Close" || !M.client || !check_rights(R_ADMIN)) return
	var/list/body
	if(action == "Reroll a charted land")
		var/list/choices = world_chart_reroll_choices()
		if(!length(choices))
			to_chat(M, SPAN_NOTICE("No charted land can be rerolled: none is charted yet, or each already has a world."))
			return
		var/choice = WWinput(M, "Which land gets a new template? Its old one is gone for good.", "World Chart", "Cancel", choices + "Cancel")
		if(!choice || choice == "Cancel" || !(choice in choices) || !M.client || !check_rights(R_ADMIN)) return
		var/list/xy = choices[choice]
		body = list("op" = "reroll", "x" = xy[1], "y" = xy[2], "admin" = M.ckey)
	else
		var/list/at = pins[shard_group.mainland]
		if(!islist(at) || length(at) != 2)
			to_chat(M, SPAN_WARNING("The mainland is not on the chart yet."))
			return
		body = list("op" = "reveal", "x" = at[1], "y" = at[2], "owner" = "admin", "admin" = M.ckey)
	var/list/answer = transfer_bridge.request("/chart/request", body)
	if(!answer || !answer["ok"])
		to_chat(M, SPAN_WARNING("The world directory refused or did not answer[answer && istext(answer["error"]) ? ": [html_encode(answer["error"])]" : ""]. Nothing changed."))
		return
	log_admin("[key_name(M)] asked the world chart to [body["op"]] tile [body["x"]],[body["y"]].")
	message_admins("[key_name_admin(M)] asked the world chart to [body["op"]] tile [body["x"]],[body["y"]]. Every land sees it within a minute.")
