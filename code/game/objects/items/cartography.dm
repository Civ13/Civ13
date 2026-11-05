// Player cartography: a blank map that players fill in by surveying.
//
// A map charts one level of one world, chosen the first time it records
// anything. Nothing is drawn while walking: the holder stops and sketches
// (stands still for CARTOGRAPHY_SKETCH_TIME, in ample light), and only the
// tiles they can see at that moment, in line of sight and light enough to make
// out (moonlight will do), go onto the map. The chart is one character per
// cell of CARTOGRAPHY_CELL x CARTOGRAPHY_CELL tiles (a few kilobytes of text
// for a whole level), so maps stay cheap to keep, save and restore. Reading the map draws the chart
// client-side on a canvas.

#define CARTOGRAPHY_CELL 4 // smallest cell edge, in tiles
#define CARTOGRAPHY_MAX_CELLS 160 // largest chart edge, in cells
#define CARTOGRAPHY_SKETCH_TIME 40 // deciseconds standing still per sketch
#define CARTOGRAPHY_MIN_LIGHT 0.05 // darker tiles cannot be made out beyond arm's reach (moonlight is enough)
#define CARTOGRAPHY_SKETCH_LIGHT 0.3 // light needed where the sketcher stands to draw at all
#define CARTOGRAPHY_UNKNOWN "0"

/obj/item/weapon/cartography_map
	name = "blank map"
	desc = "A sheet of paper ruled for map-making. Stop and use it in hand to sketch the land you can see; read it with Read Map."
	icon = 'icons/obj/decals.dmi'
	icon_state = "portable_areamap"
	item_state = "map"
	throwforce = WEAPON_FORCE_HARMLESS
	force = WEAPON_FORCE_HARMLESS
	w_class = ITEM_SIZE_TINY
	flags = FALSE
	// Saved: the chart and the land it belongs to.
	var/chart = "" // one character per cell, row by row from the south
	var/chart_land = "" // world and level the chart belongs to, see cartography_land_key()
	var/chart_label = "" // readable name of that land, for examine
	var/chart_cell = 0 // tiles per cell edge
	var/chart_cols = 0
	var/chart_rows = 0

// The land a turf belongs to: this world (its region in a shard group, else
// the map) and the level. Charts never mix two lands.
/proc/cartography_land_key(turf/T)
	var/world_id = shard_group && shard_group.enabled && shard_group.region ? shard_group.region : (map ? map.ID : "world")
	return "[world_id]:[T.z]"

// A readable name for the land at T, such as "Gaia" or "the Gaia caves".
/proc/cartography_land_label(turf/T)
	var/world_name = shard_group && shard_group.enabled && shard_group.name ? shard_group.name : null
	if (!world_name && map)
		world_name = map.title || map.ID
		// "Nomads (Gaia)" reads as "Gaia".
		var/open = findtext(world_name, "(")
		var/close = findtext(world_name, ")", open + 1)
		if (open && close > open + 1)
			world_name = copytext(world_name, open + 1, close)
	if (!world_name)
		world_name = "these lands"
	if (istype(get_area(T), /area/caribbean/void/caves))
		return "the [world_name] caves"
	return world_name

/proc/cartography_cell_size()
	return max(CARTOGRAPHY_CELL, CEILING(max(world.maxx, world.maxy) / CARTOGRAPHY_MAX_CELLS, 1))

// One map character for a turf.
/proc/cartography_terrain(turf/T)
	if (!T)
		return CARTOGRAPHY_UNKNOWN
	for (var/obj/covers/C in T)
		if (istype(C, /obj/covers/road) || istype(C, /obj/covers/roads) || istype(C, /obj/covers/romanroad) || istype(C, /obj/covers/cobblestone))
			return "r"
		return "b"
	for (var/obj/structure/wild/W in T)
		if (istype(W, /obj/structure/wild/tree) || istype(W, /obj/structure/wild/jungle) || istype(W, /obj/structure/wild/palm))
			return "f"
	if (istype(T, /turf/wall))
		if (istype(T, /turf/wall/rockwall))
			return "m"
		return "b"
	if (istype(T, /turf/floor/beach/water))
		if (istype(T, /turf/floor/beach/water/ice))
			return "i"
		if (istype(T, /turf/floor/beach/water/deep))
			return "W"
		return "w"
	if (istype(T, /turf/floor/lava))
		return "l"
	if (istype(T, /turf/floor/beach/sand))
		return "s"
	if (istype(T, /turf/floor/winter))
		return "n"
	if (istype(T, /turf/floor/grass))
		return "g"
	if (istype(T, /turf/floor/plating/road) || istype(T, /turf/floor/plating/cobblestone))
		return "r"
	if (istype(T, /turf/floor/wood) || istype(T, /turf/floor/carpet) || istype(T, /turf/floor/plating))
		return "b"
	return "d"

// The turfs user can make out right now: inside their screen, in line of
// sight (view() respects opacity) and lit, except right beside them.
/proc/cartography_visible_turfs(mob/user)
	var/list/seen = list()
	var/turf/here = get_turf(user)
	if (!here)
		return seen
	var/half_x = world.view
	var/half_y = world.view
	if (user.client)
		var/client_view = user.client.view
		if (isnum(client_view))
			half_x = client_view
			half_y = client_view
		else if (istext(client_view))
			var/cross = findtext(client_view, "x")
			if (cross)
				half_x = round((text2num(copytext(client_view, 1, cross)) - 1) / 2)
				half_y = round((text2num(copytext(client_view, cross + 1)) - 1) / 2)
	for (var/turf/T in view(max(half_x, half_y), user))
		if (T.z != here.z || abs(T.x - here.x) > half_x || abs(T.y - here.y) > half_y)
			continue
		if (get_dist(T, here) > 1 && T.get_lumcount() < CARTOGRAPHY_MIN_LIGHT)
			continue
		seen += T
	return seen

// Binds a blank (or stale) map to the land at T.
/obj/item/weapon/cartography_map/proc/start_chart(turf/T)
	chart_cell = cartography_cell_size()
	chart_cols = CEILING(world.maxx / chart_cell, 1)
	chart_rows = CEILING(world.maxy / chart_cell, 1)
	var/list/row = list()
	for (var/i = 1 to chart_cols)
		row += CARTOGRAPHY_UNKNOWN
	var/row_text = jointext(row, "")
	var/list/rows = list()
	for (var/i = 1 to chart_rows)
		rows += row_text
	chart = jointext(rows, "")
	chart_land = cartography_land_key(T)
	chart_label = cartography_land_label(T)
	if (name == initial(name))
		name = "map of [chart_label]"

/obj/item/weapon/cartography_map/proc/chart_valid()
	return chart_cell > 0 && chart_cols > 0 && chart_rows > 0 && length(chart) == chart_cols * chart_rows

// Draws the seen turfs onto the chart. Each touched cell becomes the most
// common terrain among its seen tiles; built-up land and roads count double so
// narrow tracks and huts still show. Returns the number of cells redrawn, or
// -1 when the turfs belong to another land than this map.
/obj/item/weapon/cartography_map/proc/record_turfs(turf/here, list/seen)
	if (!chart_land)
		start_chart(here)
	else if (chart_land != cartography_land_key(here))
		return -1
	else if (!chart_valid())
		start_chart(here) // the world was resized since this map was drawn
	var/list/votes = list() // cell index = list(terrain = votes)
	for (var/turf/T in seen)
		var/i = (CEILING(T.y / chart_cell, 1) - 1) * chart_cols + CEILING(T.x / chart_cell, 1)
		var/c = cartography_terrain(T)
		var/list/cell_votes = votes["[i]"]
		if (!cell_votes)
			cell_votes = list()
			votes["[i]"] = cell_votes
		cell_votes[c] = (cell_votes[c] || 0) + ((c == "b" || c == "r") ? 2 : 1)
	var/changed = 0
	for (var/key in votes)
		var/list/cell_votes = votes[key]
		var/best = CARTOGRAPHY_UNKNOWN
		var/best_votes = 0
		for (var/c in cell_votes)
			if (cell_votes[c] > best_votes)
				best = c
				best_votes = cell_votes[c]
		var/i = text2num(key)
		if (copytext(chart, i, i + 1) != best)
			chart = copytext(chart, 1, i) + best + copytext(chart, i + 1)
			changed++
	return changed

/obj/item/weapon/cartography_map/proc/explored_percent()
	if (!chart_valid())
		return 0
	var/known = 0
	for (var/i = 1 to length(chart))
		if (text2ascii(chart, i) != 48) // "0"
			known++
	return round(100 * known / length(chart))

/obj/item/weapon/cartography_map/examine(mob/user)
	..()
	if (!chart_land)
		to_chat(user, "It is still blank.")
	else
		to_chat(user, "It charts [chart_label]; about [explored_percent()]% of it is drawn in.")

// Using the map in hand sketches what the holder can see, then shows it.
/obj/item/weapon/cartography_map/attack_self(mob/user)
	sketch(user)

/obj/item/weapon/cartography_map/proc/sketch(mob/user)
	var/turf/here = get_turf(user)
	if (!user || !here || loc != user)
		return
	if (chart_land && chart_land != cartography_land_key(here))
		to_chat(user, SPAN_WARNING("This map shows [chart_label], not the land you are in."))
		return
	if (here.get_lumcount() < CARTOGRAPHY_SKETCH_LIGHT)
		to_chat(user, SPAN_WARNING("It is too dark to draw. Find some light first."))
		return
	to_chat(user, SPAN_NOTICE("You stop and start sketching the land around you..."))
	if (!do_after(user, CARTOGRAPHY_SKETCH_TIME, src))
		to_chat(user, SPAN_WARNING("You stop sketching."))
		return
	here = get_turf(user)
	if (!here || QDELETED(src) || loc != user)
		return
	if (here.get_lumcount() < CARTOGRAPHY_SKETCH_LIGHT)
		to_chat(user, SPAN_WARNING("It grew too dark to draw."))
		return
	var/list/seen = cartography_visible_turfs(user)
	if (length(seen) <= 9)
		to_chat(user, SPAN_WARNING("You can hardly see anything here to draw."))
		if (!chart_land)
			return
	var/changed = record_turfs(here, seen)
	if (changed < 0)
		to_chat(user, SPAN_WARNING("This map shows [chart_label], not the land you are in."))
		return
	to_chat(user, SPAN_NOTICE(changed ? "You sketch what you can see onto the map." : "The map already shows everything you can see from here."))
	read_map(user)

/obj/item/weapon/cartography_map/verb/read_map_verb()
	set name = "Read Map"
	set category = null
	set src in usr
	read_map(usr)

/obj/item/weapon/cartography_map/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/weapon/pen))
		var/title = input(user, "What should this map be called?", "Title the map", name) as text|null
		title = sanitize(title, MAX_NAME_LEN)
		if (!title || QDELETED(src) || !user.Adjacent(src))
			return
		name = title
		to_chat(user, SPAN_NOTICE("You title the map \"[title]\"."))
		return
	return ..()

/obj/item/weapon/cartography_map/proc/read_map(mob/user)
	if (!user || !user.client)
		return
	if (!chart_valid())
		to_chat(user, SPAN_NOTICE("The map is still blank. Stop somewhere with a view and use it in hand to sketch."))
		return
	user << browse(map_html(get_turf(user)), "window=cartography_map;size=[min(900, chart_cols * map_scale() + 60)]x[min(900, chart_rows * map_scale() + 190)]")

/obj/item/weapon/cartography_map/proc/map_scale()
	return clamp(round(640 / max(chart_cols, chart_rows)), 2, 8)

/obj/item/weapon/cartography_map/proc/map_html(turf/T)
	var/px = 0
	var/py = 0
	var/here = "You cannot place yourself on this map."
	if (T && chart_land == cartography_land_key(T))
		px = CEILING(T.x / chart_cell, 1)
		py = CEILING(T.y / chart_cell, 1)
		here = "The red mark is where you stand."
	var/scale = map_scale()
	var/list/html = list("<html><head><meta charset='utf-8'><title>[html_encode(name)]</title><style>")
	html += "body{background:#3b2f22;color:#e8dcc0;font-family:Georgia,serif;margin:12px}canvas{border:3px solid #6b4f2e;image-rendering:pixelated;display:block}"
	html += ".k{display:inline-block;width:10px;height:10px;margin:0 3px 0 8px;border:1px solid #222}</style></head><body>"
	html += "<b>[html_encode(name)]</b> - [html_encode(chart_label)], [explored_percent()]% drawn. [here] North is up.<br><br>"
	html += "<canvas id='m' width='[chart_cols * scale]' height='[chart_rows * scale]'></canvas><div style='margin-top:8px;font-size:12px'>"
	var/list/legend = list("g" = "grass", "f" = "woods", "d" = "bare earth", "s" = "sand", "n" = "snow", "w" = "water", "W" = "deep water", "i" = "ice", "m" = "rock", "l" = "lava", "r" = "road", "b" = "buildings")
	var/list/colors = cartography_colors()
	for (var/c in legend)
		html += "<span class='k' style='background:[colors[c]]'></span>[legend[c]]"
	html += "</div><script>"
	var/list/js_colors = list()
	for (var/c in colors)
		js_colors += "'[c]':'[colors[c]]'"
	html += "var C={[jointext(js_colors, ",")]},s='[chart]',w=[chart_cols],h=[chart_rows],k=[scale],px=[px],py=[py];"
	html += "var g=document.getElementById('m').getContext('2d');"
	html += "for(var y=0;y<h;y++){for(var x=0;x<w;x++){g.fillStyle=C\[s.charAt(y*w+x)\]||C\['0'\];g.fillRect(x*k,(h-1-y)*k,k,k);}}"
	html += "if(px>0){g.fillStyle='#d0202a';g.fillRect((px-1)*k-k,(h-py)*k-k,k*3,k*3);g.fillStyle='#fff';g.fillRect((px-1)*k,(h-py)*k,k,k);}"
	html += "</script></body></html>"
	return jointext(html, "")

/proc/cartography_colors()
	var/static/list/colors = list(
		"0" = "#d9c9a3", "g" = "#7fa65a", "f" = "#3f6b35", "d" = "#a88b60", "s" = "#e3cf8f",
		"n" = "#f2f4f6", "w" = "#4f86b8", "W" = "#2d5482", "i" = "#bfe0ef", "m" = "#7a756d",
		"l" = "#c4421a", "r" = "#5c4a3a", "b" = "#8e3b2f")
	return colors

#undef CARTOGRAPHY_CELL
#undef CARTOGRAPHY_MAX_CELLS
#undef CARTOGRAPHY_SKETCH_TIME
#undef CARTOGRAPHY_MIN_LIGHT
#undef CARTOGRAPHY_SKETCH_LIGHT
#undef CARTOGRAPHY_UNKNOWN
