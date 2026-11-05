// Player cartography: a blank map fills in with the land its holder explores.
//
// A map charts one level of one world, chosen the first time it records
// anything. The chart is one character per cell of CARTOGRAPHY_CELL x
// CARTOGRAPHY_CELL tiles (a few kilobytes of text for a whole level), so maps
// stay cheap to keep, save and restore. Charting runs on the object process
// only while a living mob carries the map, and only when the holder reaches a
// new cell. Reading the map draws the chart client-side on a canvas.

#define CARTOGRAPHY_CELL 4 // smallest cell edge, in tiles
#define CARTOGRAPHY_MAX_CELLS 160 // largest chart edge, in cells
#define CARTOGRAPHY_SIGHT 2 // cells charted around the holder, each way
#define CARTOGRAPHY_UNKNOWN "0"

/obj/item/weapon/cartography_map
	name = "blank map"
	desc = "A sheet of paper ruled for map-making. Carry it while you explore and it fills in with the land you pass through."
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
	var/tmp/last_cell = 0 // cell index the holder was last charted from

/obj/item/weapon/cartography_map/New()
	..()
	processing_objects |= src

/obj/item/weapon/cartography_map/Destroy()
	processing_objects -= src
	return ..()

/obj/item/weapon/cartography_map/persistence_runtime_var(key)
	return key == "last_cell" || ..()

/obj/item/weapon/cartography_map/pickup(mob/user)
	..()
	processing_objects |= src

/obj/item/weapon/cartography_map/equipped(mob/user, slot)
	..()
	processing_objects |= src

/obj/item/weapon/cartography_map/on_exit_storage(obj/item/weapon/storage/S)
	..()
	processing_objects |= src

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

// The character for one cell: a vote of four sample tiles. Built-up land and
// roads count double so narrow tracks and huts still show.
/obj/item/weapon/cartography_map/proc/sample_cell(cx, cy, z)
	var/list/votes = list()
	var/lo = max(1, round(chart_cell / 4))
	var/hi = max(1, chart_cell - lo)
	var/x0 = (cx - 1) * chart_cell
	var/y0 = (cy - 1) * chart_cell
	for (var/dy in list(lo, hi))
		for (var/dx in list(lo, hi))
			var/turf/T = locate(min(world.maxx, x0 + dx), min(world.maxy, y0 + dy), z)
			var/c = cartography_terrain(T)
			votes[c] = (votes[c] || 0) + ((c == "b" || c == "r") ? 2 : 1)
	var/best = CARTOGRAPHY_UNKNOWN
	var/best_votes = 0
	for (var/c in votes)
		if (votes[c] > best_votes)
			best = c
			best_votes = votes[c]
	return best

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
	last_cell = 0

/obj/item/weapon/cartography_map/proc/chart_valid()
	return chart_cell > 0 && chart_cols > 0 && chart_rows > 0 && length(chart) == chart_cols * chart_rows

// The living mob carrying this map, through bags and pockets.
/obj/item/weapon/cartography_map/proc/chart_holder()
	var/atom/A = loc
	for (var/depth = 1 to 4)
		if (!A || isturf(A))
			return null
		if (ismob(A))
			var/mob/living/L = A
			if (!istype(L) || L.stat == DEAD)
				return null
			return L
		A = A.loc
	return null

/obj/item/weapon/cartography_map/process()
	var/mob/living/L = chart_holder()
	if (!L)
		last_cell = 0
		return PROCESS_KILL
	var/turf/T = get_turf(L)
	if (!T)
		return
	chart_around(T)

// Charts the cells around T. Returns TRUE when anything changed.
/obj/item/weapon/cartography_map/proc/chart_around(turf/T)
	if (!chart_land)
		start_chart(T)
	else if (chart_land != cartography_land_key(T))
		return FALSE // another world or level
	else if (!chart_valid())
		start_chart(T) // the world was resized since this map was drawn
	var/cx = CEILING(T.x / chart_cell, 1)
	var/cy = CEILING(T.y / chart_cell, 1)
	var/here = (cy - 1) * chart_cols + cx
	if (here == last_cell)
		return FALSE
	last_cell = here
	var/changed = FALSE
	for (var/y = max(1, cy - CARTOGRAPHY_SIGHT) to min(chart_rows, cy + CARTOGRAPHY_SIGHT))
		for (var/x = max(1, cx - CARTOGRAPHY_SIGHT) to min(chart_cols, cx + CARTOGRAPHY_SIGHT))
			// Round off the corners of the sighted square.
			if (abs(x - cx) == CARTOGRAPHY_SIGHT && abs(y - cy) == CARTOGRAPHY_SIGHT)
				continue
			var/i = (y - 1) * chart_cols + x
			var/c = sample_cell(x, y, T.z)
			if (copytext(chart, i, i + 1) != c)
				chart = copytext(chart, 1, i) + c + copytext(chart, i + 1)
				changed = TRUE
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

/obj/item/weapon/cartography_map/attack_self(mob/user)
	read_map(user)

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
	var/turf/T = get_turf(user)
	if (T && chart_holder() == user)
		chart_around(T)
	if (!chart_valid())
		to_chat(user, SPAN_NOTICE("The map is still blank. Carry it while you explore to fill it in."))
		return
	user << browse(map_html(T), "window=cartography_map;size=[min(900, chart_cols * map_scale() + 60)]x[min(900, chart_rows * map_scale() + 190)]")

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
#undef CARTOGRAPHY_SIGHT
#undef CARTOGRAPHY_UNKNOWN
