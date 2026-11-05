// Space settlement phase 1: unmanned survey probes.
//
// A probe never visits a real level (decision D1): the mission console shows a
// coarse survey map of the barren world, generated offline by
// `python3 -m tools.procedural_maps survey` into config/space/survey_map.json.
// The player drives the probe across that map, photographs sites and takes
// samples; the ascent stage brings the samples home as real items.
//
// Saves: the mission lives in the console's ordinary vars (position, battery,
// revealed cells, carried samples). The only clock is a tmp var, so a restart
// never replays recharge for the time the server was down.

#define SURVEY_MAP_FILE "config/space/survey_map.json"
#define SURVEY_MAP_SCHEMA "civ13-survey-map/1"
#define SURVEY_PLAIN "."
#define SURVEY_CHANNEL "~"
#define SURVEY_ICE "*"
#define SURVEY_RIDGE "^"
#define SURVEY_FUEL_UNITS 60
#define SURVEY_RAIL_CONSOLE_RANGE 7
// One battery point comes back every this many seconds while a mission flies.
#define SURVEY_RECHARGE_SECONDS 3
#define SURVEY_PHOTO_COST 2
#define SURVEY_SAMPLE_COST 5
#define SURVEY_ANALYSIS_TIME 50
#define SURVEY_NOTES_NODE "planetary_survey"

/proc/survey_move_cost(cell)
	switch (cell)
		if (SURVEY_PLAIN)
			return 1
		if (SURVEY_CHANNEL)
			return 2
		if (SURVEY_ICE)
			return 3
	return 0 // ridges and off-map cells are impassable

/proc/survey_cell_name(cell)
	switch (cell)
		if (SURVEY_PLAIN)
			return "plain"
		if (SURVEY_CHANNEL)
			return "dry channel"
		if (SURVEY_ICE)
			return "ice sheet"
		if (SURVEY_RIDGE)
			return "ridge"
	return "unknown"

// ---------------------------------------------------------------- survey map

/datum/survey_map
	var/width = 0
	var/height = 0
	var/seed = ""
	var/list/rows = list() // rows[1] is the southern edge
	var/error = null

/datum/survey_map/proc/load_text(text)
	var/list/data = null
	try
		data = json_decode(text)
	catch
		data = null
	if (!islist(data) || data["schema"] != SURVEY_MAP_SCHEMA)
		error = "schema"
		return FALSE
	var/list/R = data["rows"]
	if (!islist(R) || R.len < 8 || R.len > 64)
		error = "height"
		return FALSE
	var/w = istext(R[1]) ? length(R[1]) : 0
	if (w < 8 || w > 64)
		error = "width"
		return FALSE
	var/has_plain = FALSE
	for (var/row in R)
		if (!istext(row) || length(row) != w)
			error = "row"
			return FALSE
		for (var/i = 1 to w)
			var/c = copytext(row, i, i + 1)
			if (c == SURVEY_PLAIN)
				has_plain = TRUE
			else if (c != SURVEY_CHANNEL && c != SURVEY_ICE && c != SURVEY_RIDGE)
				error = "cell"
				return FALSE
	if (!has_plain)
		error = "plains"
		return FALSE
	width = w
	height = R.len
	rows = R.Copy()
	seed = "[data["seed"]]"
	error = null
	return TRUE

/datum/survey_map/proc/cell(x, y)
	if (!isnum(x) || !isnum(y) || x < 1 || y < 1 || x > width || y > height)
		return null
	return copytext(rows[y], x, x + 1)

/datum/survey_map/proc/plain_cells()
	. = list()
	for (var/y = 1 to height)
		for (var/x = 1 to width)
			if (cell(x, y) == SURVEY_PLAIN)
				. += list(list(x, y))

var/global/datum/survey_map/space_survey_map_cache = null

/proc/get_space_survey_map()
	if (space_survey_map_cache)
		return space_survey_map_cache
	if (!fexists(SURVEY_MAP_FILE))
		return null
	var/datum/survey_map/M = new
	if (!M.load_text(file2text(SURVEY_MAP_FILE)))
		log_debug("space survey: [SURVEY_MAP_FILE] rejected ([M.error])")
		return null
	space_survey_map_cache = M
	return M

// ---------------------------------------------------------------- items

/obj/item/space_probe
	name = "survey probe"
	desc = "A small lander with a camera mast, a sample drill and a tiny ascent stage. Load it on a launch rail."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "rocketcasing_booster"
	color = "#d9dbe3"
	w_class = ITEM_SIZE_LARGE
	var/battery_max = 100
	var/comms_range = 12
	var/sample_capacity = 3
	var/sight_range = 1

/obj/item/space_probe/advanced
	name = "advanced survey probe"
	desc = "A survey lander with a bigger battery, a stronger relay, a wide camera and room for five samples. Load it on a launch rail."
	color = "#e8d9a8"
	battery_max = 160
	comms_range = 18
	sample_capacity = 5
	sight_range = 2

/obj/item/space_sample
	name = "regolith sample"
	desc = "A sealed canister of dust from another world. A mission console can analyse it into research notes on Planetary Survey."
	icon = 'icons/obj/mining.dmi'
	icon_state = "ore_glass"
	color = "#c98a62"
	w_class = ITEM_SIZE_SMALL
	var/kind = "regolith"
	var/site = ""

/obj/item/space_sample/rock
	name = "rock sample"
	color = "#8f5c45"
	kind = "rock"

/obj/item/space_sample/sediment
	name = "sediment core"
	color = "#a77c5a"
	kind = "sediment"

/obj/item/space_sample/ice
	name = "ice core"
	color = "#d8f0ff"
	kind = "ice"

/proc/survey_sample_type(kind)
	switch (kind)
		if ("rock")
			return /obj/item/space_sample/rock
		if ("sediment")
			return /obj/item/space_sample/sediment
		if ("ice")
			return /obj/item/space_sample/ice
	return /obj/item/space_sample

// ---------------------------------------------------------------- launch rail

/obj/structure/launch_rail
	name = "launch rail"
	desc = "A lattice tower that sends a survey probe on its way. Load a probe, fill it with 60 units of gasoline or diesel, and fly it from a mission console nearby."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "radio_powered"
	anchored = TRUE
	density = TRUE
	var/obj/item/space_probe/loaded = null
	var/fuel = 0

/obj/structure/launch_rail/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Probe: [loaded ? loaded.name : "none"]. Fuel: [fuel]/[SURVEY_FUEL_UNITS]."))

/obj/structure/launch_rail/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/space_probe))
		if (loaded)
			to_chat(user, SPAN_WARNING("A probe is already loaded."))
			return
		user.remove_from_mob(W)
		W.forceMove(src)
		loaded = W
		to_chat(user, SPAN_NOTICE("You load \the [W] onto \the [src]."))
		return
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents)
		var/took = add_fuel(W.reagents)
		if (took > 0)
			to_chat(user, SPAN_NOTICE("You fuel \the [src] ([fuel]/[SURVEY_FUEL_UNITS])."))
		else if (fuel >= SURVEY_FUEL_UNITS)
			to_chat(user, SPAN_WARNING("\The [src] is already fuelled."))
		else
			to_chat(user, SPAN_WARNING("\The [src] burns gasoline or diesel."))
		return
	return ..()

/obj/structure/launch_rail/proc/add_fuel(datum/reagents/R)
	var/took = 0
	for (var/id in list("gasoline", "diesel"))
		var/need = SURVEY_FUEL_UNITS - fuel
		if (need <= 0)
			break
		var/amount = min(need, R.get_reagent_amount(id))
		if (amount > 0)
			R.remove_reagent(id, amount)
			fuel += amount
			took += amount
	return took

/obj/structure/launch_rail/proc/find_console()
	for (var/obj/structure/survey_console/C in range(SURVEY_RAIL_CONSOLE_RANGE, src))
		if (!C.mission)
			return C
	return null

/obj/structure/launch_rail/attack_hand(mob/user as mob)
	if (!ishuman(user))
		return
	if (!loaded)
		to_chat(user, SPAN_WARNING("Load a survey probe first."))
		return
	if (fuel < SURVEY_FUEL_UNITS)
		to_chat(user, SPAN_WARNING("The probe needs [SURVEY_FUEL_UNITS] units of fuel ([fuel] loaded)."))
		return
	if (!find_console())
		to_chat(user, SPAN_WARNING("No idle mission console within [SURVEY_RAIL_CONSOLE_RANGE] tiles to fly the probe."))
		return
	if (WWinput(user, "Launch \the [loaded]?", "Launch rail", "Cancel", list("Launch", "Cancel")) != "Launch")
		return
	if (!in_range(src, user))
		return
	var/result = launch()
	if (result)
		to_chat(user, SPAN_WARNING(result))
		return
	visible_message(SPAN_DANGER("\The [src] roars as a probe climbs away on a column of smoke!"))

// Returns null on success, or the reason the launch failed.
/obj/structure/launch_rail/proc/launch(lx = null, ly = null)
	if (!loaded || fuel < SURVEY_FUEL_UNITS)
		return "The rail is not ready."
	var/obj/structure/survey_console/C = find_console()
	if (!C)
		return "No idle mission console in range."
	var/datum/survey_map/M = get_space_survey_map()
	if (!M)
		return "The console has no survey map of the target world."
	var/obj/item/space_probe/P = loaded
	if (!C.begin_mission(P, M, lx, ly))
		return "The console refused the mission."
	loaded = null
	fuel = 0
	qdel(P)
	return null

/obj/structure/launch_rail/Destroy()
	if (loaded)
		loaded.forceMove(get_turf(src))
		loaded = null
	return ..()

// ---------------------------------------------------------------- mission console

/obj/structure/survey_console
	name = "mission console"
	desc = "Flies survey probes over another world and analyses the samples they bring back."
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer"
	anchored = TRUE
	density = TRUE
	var/mission = FALSE
	var/probe_name = ""
	var/map_seed = ""
	var/map_width = 0
	var/map_height = 0
	var/probe_x = 0
	var/probe_y = 0
	var/land_x = 0
	var/land_y = 0
	var/battery = 0
	var/battery_max = 0
	var/comms_range = 0
	var/sample_capacity = 0
	var/sight_range = 1
	// The survey record outlives each mission (later phases read it to pick
	// landing zones); it resets only when the survey map itself changes.
	var/revealed = "" // one character per cell, "1" once any probe saw it
	var/list/samples = list() // sample kinds aboard
	var/list/sampled = list() // "x,y" cells already drilled, on any mission
	var/list/photographed = list() // "x,y" cells already recorded, on any mission
	var/list/landing_sites = list() // "x,y" of every probe landing
	var/tmp/last_recharge = null

/obj/structure/survey_console/proc/begin_mission(obj/item/space_probe/P, datum/survey_map/M, lx = null, ly = null)
	if (mission || !istype(P) || !M)
		return FALSE
	if (lx == null || ly == null)
		var/list/site = pick(M.plain_cells())
		lx = site[1]
		ly = site[2]
	if (M.cell(lx, ly) != SURVEY_PLAIN)
		return FALSE
	if (map_seed != M.seed || map_width != M.width || map_height != M.height || length(revealed) != M.width * M.height)
		reset_survey(M)
	mission = TRUE
	probe_name = P.name
	land_x = lx
	land_y = ly
	probe_x = lx
	probe_y = ly
	battery_max = P.battery_max
	battery = battery_max
	comms_range = P.comms_range
	sample_capacity = P.sample_capacity
	sight_range = P.sight_range
	samples = list()
	landing_sites |= "[lx],[ly]"
	reveal_around(probe_x, probe_y)
	last_recharge = world.time
	return TRUE

// Forgets the survey record: only when the survey map was replaced.
/obj/structure/survey_console/proc/reset_survey(datum/survey_map/M)
	map_seed = M.seed
	map_width = M.width
	map_height = M.height
	var/list/zeros = list()
	for (var/i = 1 to map_width * map_height)
		zeros += "0"
	revealed = jointext(zeros, "")
	sampled = list()
	photographed = list()
	landing_sites = list()

// Ends a flight. The survey record (revealed, sampled, photographed and
// landing_sites) stays for the next probe.
/obj/structure/survey_console/proc/end_mission()
	mission = FALSE
	probe_name = ""
	samples = list()
	battery = 0
	last_recharge = null

// The map the mission flies over; null (and the mission is lost) when the
// survey map was replaced since launch.
/obj/structure/survey_console/proc/mission_map()
	var/datum/survey_map/M = get_space_survey_map()
	if (!M || M.seed != map_seed || M.width != map_width || M.height != map_height || length(revealed) != map_width * map_height)
		return null
	return M

/obj/structure/survey_console/proc/is_revealed(x, y)
	if (x < 1 || y < 1 || x > map_width || y > map_height)
		return FALSE
	var/i = (y - 1) * map_width + x
	return copytext(revealed, i, i + 1) == "1"

/obj/structure/survey_console/proc/reveal_around(cx, cy)
	for (var/y = cy - sight_range to cy + sight_range)
		for (var/x = cx - sight_range to cx + sight_range)
			if (x < 1 || y < 1 || x > map_width || y > map_height || is_revealed(x, y))
				continue
			var/i = (y - 1) * map_width + x
			revealed = copytext(revealed, 1, i) + "1" + copytext(revealed, i + 1)

/obj/structure/survey_console/proc/revealed_count()
	. = 0
	for (var/i = 1 to length(revealed))
		if (copytext(revealed, i, i + 1) == "1")
			.++

// Solar panels top the battery up while the probe sits on the surface. The
// clock is tmp: after a restart the first use starts counting afresh.
/obj/structure/survey_console/proc/recharge()
	if (!mission)
		return
	if (!isnum(last_recharge) || last_recharge > world.time)
		last_recharge = world.time
		return
	var/step = SURVEY_RECHARGE_SECONDS * 10
	var/gained = round((world.time - last_recharge) / step)
	if (gained <= 0)
		return
	battery = min(battery_max, battery + gained)
	last_recharge = battery >= battery_max ? world.time : last_recharge + gained * step

// Each action returns a line for the operator.
/obj/structure/survey_console/proc/try_move(dir)
	var/datum/survey_map/M = mission_map()
	if (!M)
		return "No signal from the probe."
	recharge()
	var/nx = probe_x
	var/ny = probe_y
	switch (dir)
		if (NORTH)
			ny++
		if (SOUTH)
			ny--
		if (EAST)
			nx++
		if (WEST)
			nx--
		else
			return "Unknown heading."
	var/cell = M.cell(nx, ny)
	if (!cell)
		return "That is past the edge of the survey."
	var/cost = survey_move_cost(cell)
	if (!cost)
		return "The [survey_cell_name(cell)] is too steep to drive."
	if (max(abs(nx - land_x), abs(ny - land_y)) > comms_range)
		return "The relay at the landing site would lose the probe out there."
	if (battery < cost)
		return "The battery is too low; wait for the panels to charge it."
	battery -= cost
	probe_x = nx
	probe_y = ny
	reveal_around(nx, ny)
	return "The probe crosses onto [survey_cell_name(cell)]."

/obj/structure/survey_console/proc/sample_kind_here(datum/survey_map/M)
	var/cell = M.cell(probe_x, probe_y)
	if (cell == SURVEY_CHANNEL)
		return "sediment"
	if (cell == SURVEY_ICE)
		return "ice"
	for (var/d in cardinal)
		var/turn_x = probe_x + (d == EAST ? 1 : d == WEST ? -1 : 0)
		var/turn_y = probe_y + (d == NORTH ? 1 : d == SOUTH ? -1 : 0)
		if (M.cell(turn_x, turn_y) == SURVEY_RIDGE)
			return "rock"
	return "regolith"

/obj/structure/survey_console/proc/take_sample()
	var/datum/survey_map/M = mission_map()
	if (!M)
		return "No signal from the probe."
	recharge()
	if (samples.len >= sample_capacity)
		return "The sample bay is full."
	var/key = "[probe_x],[probe_y]"
	if (key in sampled)
		return "The drill has already cored this site."
	if (battery < SURVEY_SAMPLE_COST)
		return "The drill needs [SURVEY_SAMPLE_COST] battery."
	battery -= SURVEY_SAMPLE_COST
	var/kind = sample_kind_here(M)
	samples += kind
	sampled += key
	return "The drill seals a [kind] sample into the bay."

/obj/structure/survey_console/proc/photograph()
	var/datum/survey_map/M = mission_map()
	if (!M)
		return "No signal from the probe."
	recharge()
	var/key = "[probe_x],[probe_y]"
	if (key in photographed)
		return "This site is already on record."
	if (battery < SURVEY_PHOTO_COST)
		return "The camera needs [SURVEY_PHOTO_COST] battery."
	battery -= SURVEY_PHOTO_COST
	photographed += key
	var/list/lines = list()
	for (var/y = probe_y + 1 to probe_y - 1 step -1)
		var/line = ""
		for (var/x = probe_x - 1 to probe_x + 1)
			var/c = M.cell(x, y)
			line += (x == probe_x && y == probe_y) ? "P" : (c ? c : " ")
		lines += line
	var/obj/item/weapon/paper/record = new(get_turf(src))
	record.name = "survey record ([probe_x],[probe_y])"
	record.info = "<b>Survey record</b><br>Probe: [probe_name]<br>Site: [probe_x],[probe_y] ([survey_cell_name(M.cell(probe_x, probe_y))])<br>Landing site: [land_x],[land_y]<br><tt>[jointext(lines, "<br>")]</tt><br>Key: . plain, ~ dry channel, * ice, ^ ridge, P probe."
	return "The console prints a survey record."

// The ascent stage waits at the landing site and carries the samples home.
/obj/structure/survey_console/proc/ascend()
	if (!mission_map())
		return "No signal from the probe."
	if (probe_x != land_x || probe_y != land_y)
		return "Drive back to the landing site ([land_x],[land_y]) where the ascent stage waits."
	var/count = samples.len
	for (var/kind in samples)
		var/path = survey_sample_type(kind)
		var/obj/item/space_sample/S = new path(get_turf(src))
		S.site = "[land_x],[land_y]"
	end_mission()
	return count ? "The return capsule drops [count] sample[count == 1 ? "" : "s"] beside the console." : "The ascent stage burns up empty; the mission is over."

/obj/structure/survey_console/proc/abandon()
	end_mission()
	return "The probe is left to the dust. The mission is over."

// Turns a sample into research notes on Planetary Survey.
/obj/structure/survey_console/proc/analyse(obj/item/space_sample/S, mob/living/human/H)
	var/datum/research_node/N = get_research_node(SURVEY_NOTES_NODE)
	if (!N)
		return null
	var/obj/item/weapon/book/research/tree_book/book = new(get_turf(src))
	book.subject = SURVEY_NOTES_NODE
	book.written_by_faction = H ? H.civilization : null
	book.written_by = H ? H.real_name : "a mission console"
	book.transfer_type = "notes"
	book.name = "research notes: [N.name]"
	book.title = "Notes on a [S.kind] sample"
	book.desc = "Console analysis of a [S.kind] sample from another world. A research bench studying [N.name] can use them to speed up its work."
	qdel(S)
	return book

/obj/structure/survey_console/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/space_sample) && ishuman(user))
		to_chat(user, SPAN_NOTICE("You feed \the [W] into the analyser..."))
		if (!do_after(user, SURVEY_ANALYSIS_TIME, src))
			return
		if (QDELETED(W) || W.loc != user)
			return
		user.remove_from_mob(W)
		if (analyse(W, user))
			to_chat(user, SPAN_NOTICE("The console prints research notes on the sample."))
		return
	return ..()

/obj/structure/survey_console/attack_hand(mob/user as mob)
	if (!ishuman(user))
		return
	show_ui(user)

/obj/structure/survey_console/proc/map_html(datum/survey_map/M)
	var/list/out = list("<pre style='font-size:12px;line-height:12px;background:#111;padding:4px;display:inline-block'>")
	for (var/y = map_height to 1 step -1)
		var/list/line = list()
		for (var/x = 1 to map_width)
			if (x == probe_x && y == probe_y)
				line += "<span style='color:#ffffff;background:#a03030'>P</span>"
			else if (x == land_x && y == land_y)
				line += "<span style='color:#ffe070'>L</span>"
			else if (!is_revealed(x, y))
				line += "<span style='color:#333'>?</span>"
			else
				var/c = M.cell(x, y)
				var/colour = c == SURVEY_RIDGE ? "#d0a080" : c == SURVEY_ICE ? "#c0e8ff" : c == SURVEY_CHANNEL ? "#9a7050" : "#c98a62"
				line += "<span style='color:[colour]'>[c]</span>"
		out += jointext(line, "")
	out += "</pre>"
	return jointext(out, "\n")

/obj/structure/survey_console/proc/show_ui(mob/user, message = null)
	user << browse(ui_html(message), "window=survey_console;size=560x680")

/obj/structure/survey_console/proc/ui_html(message = null)
	var/list/html = list("<html><head><title>Mission console</title><style>a{color:#8cc8ff;margin-right:4px}a:hover{color:#fff}</style></head><body style='background:#1b1b1b;color:#ddd;font-family:monospace'>")
	if (message)
		html += "<p><b>[message]</b></p>"
	var/datum/survey_map/M = null
	if (!mission)
		html += "<p>No probe in flight. Launch one from a launch rail within [SURVEY_RAIL_CONSOLE_RANGE] tiles.</p><p>Hand the console a sample to analyse it into research notes.</p>"
	else
		M = mission_map()
		if (!M)
			html += "<p>Contact with [probe_name] is lost: the survey map changed.</p><p><a href='?src=\ref[src];survey=abandon'>Close the mission</a></p>"
		else
			recharge()
			html += "<p>[probe_name] at [probe_x],[probe_y] ([survey_cell_name(M.cell(probe_x, probe_y))]). Battery [battery]/[battery_max]. Samples [samples.len]/[sample_capacity]. Relay range [comms_range] cells from L.</p>"
			html += "<p><a href='?src=\ref[src];survey=north'>North</a> <a href='?src=\ref[src];survey=south'>South</a> <a href='?src=\ref[src];survey=west'>West</a> <a href='?src=\ref[src];survey=east'>East</a> | <a href='?src=\ref[src];survey=photo'>Photograph</a> <a href='?src=\ref[src];survey=sample'>Sample</a> | <a href='?src=\ref[src];survey=ascend'>Ascend</a> <a href='?src=\ref[src];survey=abandon'>Abandon</a></p>"
			html += map_html(M)
			html += "<p>Moves cost 1 on plains, 2 in channels and 3 on ice; ridges block. P probe, L landing site.</p>"
	html += "</body></html>"
	return jointext(html, "")

/obj/structure/survey_console/Topic(href, href_list)
	if (!ishuman(usr))
		return
	var/mob/living/human/H = usr
	if (H.stat || !in_range(src, H))
		return
	var/action = href_list["survey"]
	if (!action)
		return
	var/message = null
	if (!mission)
		message = "No probe in flight."
	else
		switch (action)
			if ("north")
				message = try_move(NORTH)
			if ("south")
				message = try_move(SOUTH)
			if ("east")
				message = try_move(EAST)
			if ("west")
				message = try_move(WEST)
			if ("photo")
				message = photograph()
			if ("sample")
				message = take_sample()
			if ("ascend")
				message = ascend()
			if ("abandon")
				message = abandon()
	show_ui(H, message)
