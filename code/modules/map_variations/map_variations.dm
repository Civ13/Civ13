// Per-round battle map variations.
//
// The idea comes from CM-SS13's "nightmare" map inserts
// (https://github.com/cmss13-devs/cmss13, code/modules/nightmare/, AGPL-3.0):
// a battle map keeps its compiled layout, and before each round a few marked
// rectangles ("slots") are swapped for one of several small insert maps.
// This is a Civ13 reimplementation; no CM code was copied.
//
// Data lives next to the maps, not in the map metadata:
//   maps/zones/variations/<lowercase map ID>/variations.json
//   maps/zones/variations/<lowercase map ID>/<insert>.dmm
// The JSON lists slots, each with a bottom-left origin and weighted variants.
// A variant without "file" leaves the slot as built. Insert DMMs use the plain
// (non-TGM) format with one grid and no areas. A cell whose model is exactly
// MAP_VARIATION_KEEP is left alone; any other cell loses its structures and
// items (and its floor covers when the model brings covers) before the model
// is placed. A model turf replaces the ground; without one the ground stays.
// tests/map_variations/build_inserts.py generates the shipped inserts and
// tests/map_variations/test_map_variations.py checks them against the maps.

#define MAP_VARIATION_DIR "maps/zones/variations/"
#define MAP_VARIATION_KEEP "/obj/effect/map_variation_keep"

var/global/map_variations_applied = FALSE
var/global/list/map_variation_choices = list() // slot id => variant id
var/global/list/map_variation_notes = list() // player-facing lines for this round

// Marker path used only inside insert files; never placed by the loader.
/obj/effect/map_variation_keep
	name = "map variation keep marker"
	icon = 'icons/mob/screen/effects.dmi'
	icon_state = "x2"
	invisibility = 101
	anchored = TRUE
	simulated = FALSE

/obj/effect/map_variation_keep/New()
	..()
	qdel(src)

/proc/map_variation_folder(map_id)
	return "[MAP_VARIATION_DIR][lowertext(map_id)]/"

/proc/map_variation_config(map_id)
	if (!map_id)
		return null
	var/path = "[map_variation_folder(map_id)]variations.json"
	if (!fexists(path))
		return null
	var/list/data = json_decode(file2text(path))
	if (!islist(data) || !islist(data["slots"]))
		log_game("Map variations: [path] is not a valid variation list.")
		return null
	return data

// Parsed insert: list("width", "height", "models" = key => model text, "rows"
// = top-to-bottom row strings, "key_len"), or a text reason it was refused.
/proc/map_variation_parse(dmm_text)
	if (!dmm_text)
		return "empty file"
	var/grid_marker = findtext(dmm_text, "\n\n(1,1,1) = {\"\n")
	if (!grid_marker)
		return "no (1,1,1) grid"
	var/grid_start = grid_marker + length("\n\n(1,1,1) = {\"\n")
	var/grid_end = findtext(dmm_text, "\n\"}", grid_start)
	if (!grid_end)
		return "unterminated grid"
	if (findtext(dmm_text, " = {\"", grid_end))
		return "more than one grid"
	var/key_len = length(copytext(dmm_text, 2, findtext(dmm_text, "\"", 2)))
	if (key_len < 1)
		return "bad key width"
	var/list/models = list()
	for (var/line in splittext(copytext(dmm_text, 1, grid_marker), "\n"))
		if (!length(line))
			continue
		var/key = copytext(line, 2, findtext(line, "\"", 2))
		if (length(key) != key_len)
			return "mixed key widths"
		var/model = copytext(line, findtext(line, "=") + 3, length(line))
		if (findtext(model, "/area"))
			return "inserts may not carry areas"
		models[key] = model
	var/list/rows = splittext(copytext(dmm_text, grid_start, grid_end), "\n")
	if (!rows.len)
		return "empty grid"
	var/row_len = length(rows[1])
	if (row_len < key_len || row_len % key_len)
		return "ragged grid"
	for (var/row in rows)
		if (length(row) != row_len)
			return "ragged grid"
		for (var/column = 1 to row_len / key_len)
			if (!(copytext(row, (column - 1) * key_len + 1, column * key_len + 1) in models))
				return "grid uses an undefined key"
	return list("width" = row_len / key_len, "height" = rows.len, "models" = models, "rows" = rows, "key_len" = key_len)

/proc/map_variation_cleared(obj/O, clear_covers)
	if (istype(O, /obj/structure) || istype(O, /obj/item))
		return TRUE
	return clear_covers && istype(O, /obj/covers)

/proc/map_variation_clear_cell(turf/T, model)
	var/clear_covers = findtext(model, "/obj/covers") ? TRUE : FALSE
	for (var/obj/O in T)
		if (!map_variation_cleared(O, clear_covers))
			continue
		// Never delete a mob together with its container.
		for (var/mob/M in O.contents)
			M.forceMove(T)
		qdel(O)

// dmm_suite applies a model's vars after New(). Barriers set their layer from
// dir inside New() and never call the atom/New() that clears the turf's
// preloader, so finish both here.
/proc/map_variation_settle_cell(turf/T)
	if (!T)
		return
	T.dmm_preloader = null
	for (var/obj/structure/window/barrier/B in T)
		switch (B.dir)
			if (NORTH)
				B.layer = MOB_LAYER - 1.01
			if (SOUTH)
				B.layer = MOB_LAYER + 2
			if (EAST, WEST)
				B.layer = MOB_LAYER - 0.05

// Places a parsed insert with its bottom-left corner at (x1, y1, z). No sleep
// between cells, so nothing else sees a half-placed slot.
/proc/map_variation_place(list/insert, x1, y1, z)
	var/dmm_suite/suite = new()
	var/list/models = insert["models"]
	var/list/rows = insert["rows"]
	var/key_len = insert["key_len"]
	var/placed = 0
	for (var/row_index = 1 to rows.len)
		var/row = rows[row_index]
		var/y = y1 + rows.len - row_index
		for (var/column = 1 to length(row) / key_len)
			var/model = models[copytext(row, (column - 1) * key_len + 1, column * key_len + 1)]
			if (model == MAP_VARIATION_KEEP)
				continue
			var/turf/T = locate(x1 + column - 1, y, z)
			if (!T)
				continue
			map_variation_clear_cell(T, model)
			suite.parse_grid(model, T.x, T.y, T.z)
			map_variation_settle_cell(locate(T.x, T.y, T.z))
			placed++
	return placed

// Applies one slot. Returns the chosen variant entry, or null if it was skipped.
/proc/map_variation_apply_slot(list/slot, map_id, forced_variant = null)
	var/slot_id = slot["id"]
	var/list/variants = slot["variants"]
	if (!slot_id || !islist(variants) || !variants.len)
		return null
	var/list/by_id = list()
	var/list/weights = list()
	for (var/list/variant in variants)
		if (!islist(variant) || !variant["id"])
			continue
		by_id[variant["id"]] = variant
		weights[variant["id"]] = max(1, text2num("[variant["weight"]]") || 1)
	if (!weights.len)
		return null
	var/choice = forced_variant && (forced_variant in by_id) ? forced_variant : pickweight(weights)
	var/list/variant = by_id[choice]
	var/file_name = variant["file"]
	if (file_name)
		var/x1 = text2num("[slot["x"]]")
		var/y1 = text2num("[slot["y"]]")
		var/z = text2num("[slot["z"]]") || 1
		var/list/insert = map_variation_parse(file2text("[map_variation_folder(map_id)][file_name]"))
		if (!islist(insert))
			log_game("Map variations: [map_id] slot [slot_id] variant [choice] refused: [insert].")
			return null
		if (!x1 || !y1 || z > world.maxz || x1 + insert["width"] - 1 > world.maxx || y1 + insert["height"] - 1 > world.maxy)
			log_game("Map variations: [map_id] slot [slot_id] variant [choice] does not fit the map.")
			return null
		map_variation_place(insert, x1, y1, z)
	map_variation_choices[slot_id] = choice
	if (variant["desc"])
		map_variation_notes += variant["desc"]
	return variant

// forced = slot id => variant id, for admins and tests.
/proc/apply_map_variations(list/forced = null)
	if (map_variations_applied)
		return FALSE
	map_variations_applied = TRUE
	if (!map || persistence_round_active() || (map_storage && map_storage.round_restored))
		return FALSE
	var/list/data = map_variation_config(map.ID)
	if (!data)
		return FALSE
	for (var/list/slot in data["slots"])
		if (!islist(slot))
			continue
		map_variation_apply_slot(slot, map.ID, forced ? forced[slot["id"]] : null)
	if (map_variation_choices.len)
		var/list/summary = list()
		for (var/slot_id in map_variation_choices)
			summary += "[slot_id]: [map_variation_choices[slot_id]]"
		log_game("Map variations for [map.ID]: [jointext(summary, ", ")].")
	return TRUE

/proc/map_variation_announcement()
	if (!map_variation_notes.len)
		return null
	return "<span class='notice'><b>The battlefield has changed this round:</b> [jointext(map_variation_notes, " ")]</span>"

/proc/announce_map_variations(target = world)
	var/text = map_variation_announcement()
	if (text)
		to_chat(target, text)

/hook/roundstart/proc/map_variations_roundstart()
	announce_map_variations()
	return TRUE

/client/proc/map_variation_report()
	set name = "Map Variations"
	set category = "Debug"
	set desc = "Show which battle map variations were picked this round."
	if (!check_rights(R_MOD))
		return
	if (!map_variation_choices.len)
		to_chat(src, "No map variations were applied this round.")
		return
	for (var/slot_id in map_variation_choices)
		to_chat(src, "[slot_id]: <b>[map_variation_choices[slot_id]]</b>")

/client/add_admin_verbs()
	..()
	if (holder && (holder.rights & R_MOD))
		verbs += /client/proc/map_variation_report

/client/remove_admin_verbs()
	..()
	verbs -= /client/proc/map_variation_report

#undef MAP_VARIATION_KEEP
