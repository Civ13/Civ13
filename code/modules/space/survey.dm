// Space settlement phase 1: unmanned survey probes.
//
// A probe never visits a real level (decision D1): the mission console shows a
// coarse survey map of the barren world, generated offline by
// `python3 -m tools.procedural_maps survey` into config/space/survey/<region>.json.
// Each file is keyed by the destination region and records the ir_sha256 of
// the bundle it came from, so a later crewed launch can check that the
// surveyed sites match the real region (survey_map_matches_bundle).
// The player drives the probe across that map, photographs sites and takes
// samples; the ascent stage brings the samples home as real items.
//
// Saves: the mission lives in the console's ordinary vars (position, battery,
// revealed cells, carried samples). The only clock is a tmp var, so a restart
// never replays recharge for the time the server was down.

#define SURVEY_MAP_DIR "config/space/survey/"
#define SURVEY_DEFAULT_REGION "barren"
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
// A probe aimed at a cell lands on a plain within this many cells of it.
#define SURVEY_LANDING_SCATTER 2

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
	var/region = ""
	var/ir_sha256 = "" // the source bundle's IR hash, for survey_map_matches_bundle
	var/list/rows = list() // rows[1] is the southern edge
	var/rows_digest = null
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
	ir_sha256 = istext(data["ir_sha256"]) ? lowertext(data["ir_sha256"]) : ""
	error = null
	return TRUE

// Identifies the terrain itself; cached because rows never change after load.
/datum/survey_map/proc/digest()
	if (!rows_digest)
		rows_digest = md5(jointext(rows, ""))
	return rows_digest

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

// Loaded survey maps by region id.
var/global/list/space_survey_maps = list()

// Region ids name files, so only lowercase letters and digits pass.
/proc/survey_region_ok(region)
	return istext(region) && length(region) >= 1 && length(region) <= 32 && ckey(region) == region

/proc/get_space_survey_map(region = SURVEY_DEFAULT_REGION)
	if (!survey_region_ok(region))
		return null
	if (space_survey_maps[region])
		return space_survey_maps[region]
	var/path = "[SURVEY_MAP_DIR][region].json"
	if (!fexists(path))
		return null
	var/datum/survey_map/M = new
	if (!M.load_text(file2text(path)))
		log_debug("space survey: [path] rejected ([M.error])")
		return null
	M.region = region
	space_survey_maps[region] = M
	return M

// TRUE when a bundle manifest (seed.manifest.json text) is the bundle the
// survey map was drawn from. Phase 2 refuses a crewed launch otherwise.
/proc/survey_map_matches_manifest(datum/survey_map/M, manifest_text)
	if (!M || !length(M.ir_sha256) || !istext(manifest_text))
		return FALSE
	var/list/data = null
	try
		data = json_decode(manifest_text)
	catch
		return FALSE
	if (!islist(data) || !islist(data["generation_result"]))
		return FALSE
	var/list/result = data["generation_result"]
	return istext(result["ir_sha256"]) && lowertext(result["ir_sha256"]) == M.ir_sha256

/proc/survey_map_matches_bundle(region, bundle_dir)
	var/datum/survey_map/M = get_space_survey_map(region)
	var/path = "[bundle_dir]/seed.manifest.json"
	if (!M || !fexists(path))
		return FALSE
	return survey_map_matches_manifest(M, file2text(path))

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
	var/dropout_chance = 8 // percent per move that the relay drops a command
	var/dust_chance = 3 // percent per move that dust halves recharge for the sortie

/obj/item/space_probe/advanced
	name = "advanced survey probe"
	desc = "A survey lander with a bigger battery, a stronger relay, a wide camera and room for five samples. Load it on a launch rail."
	color = "#e8d9a8"
	battery_max = 160
	comms_range = 18
	sample_capacity = 5
	sight_range = 2
	dropout_chance = 0 // the hardened relay never drops a command

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
	desc = "A lattice tower that sends a survey probe on its way. Load a probe, fill it with 60 units of rocket propellant, and fly it from a mission console nearby."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "radio_powered"
	anchored = TRUE
	density = TRUE
	var/obj/item/space_probe/loaded = null
	var/fuel = 0
	var/destination = SURVEY_DEFAULT_REGION // survey region id; admins may change it
	var/target_x = null // aimed landing cell, or null for anywhere flat
	var/target_y = null

/obj/structure/launch_rail/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Probe: [loaded ? loaded.name : "none"]. Fuel: [fuel]/[SURVEY_FUEL_UNITS]. Target: [isnum(target_x) ? "[target_x],[target_y] (lands within [SURVEY_LANDING_SCATTER] cells)" : "anywhere flat"]."))

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
			to_chat(user, SPAN_WARNING("\The [src] burns only rocket propellant."))
		return
	return ..()

/obj/structure/launch_rail/proc/add_fuel(datum/reagents/R)
	var/amount = min(SURVEY_FUEL_UNITS - fuel, R.get_reagent_amount("rocket_propellant"))
	if (amount <= 0)
		return 0
	R.remove_reagent("rocket_propellant", amount)
	fuel += amount
	return amount

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
	var/choice = WWinput(user, "Launch \the [loaded]?", "Launch rail", "Cancel", list("Launch", "Aim", "Cancel"))
	if (!in_range(src, user) || user.incapacitated())
		return
	if (choice == "Aim")
		aim(user)
		return
	if (choice != "Launch")
		return
	var/result = launch()
	if (result)
		to_chat(user, SPAN_WARNING(result))
		return
	visible_message(SPAN_DANGER("\The [src] roars as a probe climbs away on a column of smoke!"))

/obj/structure/launch_rail/proc/aim(mob/user)
	var/datum/survey_map/M = get_space_survey_map(destination)
	if (!M)
		to_chat(user, SPAN_WARNING("There is no survey map of the destination to aim at."))
		return
	var/x = input(user, "Landing cell, west to east (1-[M.width]). Cancel to clear the aim.", "Aim the probe") as null|num
	if (isnull(x))
		target_x = null
		target_y = null
		to_chat(user, SPAN_NOTICE("The probe will land anywhere flat."))
		return
	var/y = input(user, "Landing cell, south to north (1-[M.height]).", "Aim the probe") as null|num
	if (isnull(y) || !in_range(src, user))
		return
	x = round(x)
	y = round(y)
	if (!M.cell(x, y))
		to_chat(user, SPAN_WARNING("That cell is off the survey map."))
		return
	target_x = x
	target_y = y
	to_chat(user, SPAN_NOTICE("Aimed at [x],[y]; the probe lands on flat ground within [SURVEY_LANDING_SCATTER] cells."))

// Returns null on success, or the reason the launch failed. With no cell given
// the rail's aim is used, scattered by up to `scatter` cells.
/obj/structure/launch_rail/proc/launch(lx = null, ly = null, scatter = SURVEY_LANDING_SCATTER)
	if (!loaded || fuel < SURVEY_FUEL_UNITS)
		return "The rail is not ready."
	var/obj/structure/survey_console/C = find_console()
	if (!C)
		return "No idle mission console in range."
	var/datum/survey_map/M = get_space_survey_map(destination)
	if (!M)
		return "The console has no survey map of the target world."
	if (isnull(lx) && isnum(target_x))
		lx = target_x
		ly = target_y
	var/obj/item/space_probe/P = loaded
	if (!C.begin_mission(P, M, lx, ly, scatter))
		return "There is no flat ground to land on near the aimed cell."
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
	var/list/analysed_kinds = list() // sample kinds this console has analysed
	var/map_region = ""
	var/map_digest = "" // md5 of the rows the record was made from: a rebuilt map with the same seed still differs
	var/dropout_chance = 0
	var/dust_chance = 0
	var/dusty = FALSE // dust on the panels halves recharge for this sortie
	var/tmp/last_recharge = null

// Picks the landing cell: anywhere flat with no aim, else a plain within
// `scatter` cells of the aim (the aim itself only when scatter is 0).
/proc/survey_landing_cell(datum/survey_map/M, lx, ly, scatter)
	if (isnull(lx) || isnull(ly))
		return pick(M.plain_cells())
	if (scatter <= 0)
		return M.cell(lx, ly) == SURVEY_PLAIN ? list(lx, ly) : null
	var/list/options = list()
	for (var/y = ly - scatter to ly + scatter)
		for (var/x = lx - scatter to lx + scatter)
			if (M.cell(x, y) == SURVEY_PLAIN)
				options += list(list(x, y))
	return options.len ? pick(options) : null

/obj/structure/survey_console/proc/begin_mission(obj/item/space_probe/P, datum/survey_map/M, lx = null, ly = null, scatter = 0)
	if (mission || !istype(P) || !M)
		return FALSE
	var/list/site = survey_landing_cell(M, lx, ly, scatter)
	if (!site)
		return FALSE
	lx = site[1]
	ly = site[2]
	if (map_region != M.region || map_seed != M.seed || map_digest != M.digest() || map_width != M.width || map_height != M.height || length(revealed) != M.width * M.height)
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
	dropout_chance = P.dropout_chance
	dust_chance = P.dust_chance
	dusty = FALSE
	samples = list()
	landing_sites |= "[lx],[ly]"
	reveal_around(probe_x, probe_y)
	last_recharge = world.time
	return TRUE

// Forgets the survey record: only when the survey map was replaced.
/obj/structure/survey_console/proc/reset_survey(datum/survey_map/M)
	map_region = M.region
	map_digest = M.digest()
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
	dusty = FALSE
	last_recharge = null

// The map the mission flies over; null (and the mission is lost) when the
// survey map was replaced since launch.
/obj/structure/survey_console/proc/mission_map()
	var/datum/survey_map/M = get_space_survey_map(map_region)
	if (!M || M.seed != map_seed || M.digest() != map_digest || M.width != map_width || M.height != map_height || length(revealed) != map_width * map_height)
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
	var/step = SURVEY_RECHARGE_SECONDS * 10 * (dusty ? 2 : 1)
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
	if (prob(dropout_chance))
		battery -= 1
		return "Static: the relay dropped the command. Try again."
	battery -= cost
	probe_x = nx
	probe_y = ny
	reveal_around(nx, ny)
	. = "The probe crosses onto [survey_cell_name(cell)]."
	if (!dusty && prob(dust_chance))
		dusty = TRUE
		. += " A dust gust coats the solar panels: recharge is halved for the rest of this sortie."

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

// How much a sample is worth as notes (a multiple of ordinary notes): ice
// tells most about the world, loose regolith least, and the first sample of
// each kind a console analyses counts half again, so players explore.
/proc/survey_sample_value(kind, first)
	var/value = 1
	switch (kind)
		if ("ice")
			value = 1.5
		if ("rock")
			value = 1.25
		if ("regolith")
			value = 0.75
	return round(value * (first ? 1.5 : 1), 0.01)

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
	var/first = !(S.kind in analysed_kinds)
	analysed_kinds |= S.kind
	book.boost_scale = survey_sample_value(S.kind, first)
	book.name = "research notes: [N.name]"
	book.title = "Notes on a [S.kind] sample"
	book.desc = "Console analysis of a [first ? "first " : ""][S.kind] sample from another world, worth [book.boost_scale]x ordinary notes. A research bench studying [N.name] can use them to speed up its work."
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
			html += "<p>[probe_name] at [probe_x],[probe_y] ([survey_cell_name(M.cell(probe_x, probe_y))]). Battery [battery]/[battery_max][dusty ? " (dusty panels)" : ""]. Samples [samples.len]/[sample_capacity]. Relay range [comms_range] cells from L.</p>"
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
