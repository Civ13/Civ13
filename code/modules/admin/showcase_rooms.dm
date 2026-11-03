// Showcase/demo build only. This file is not part of civ13.dme or the live
// game: scripts/build_showcase_dme.py generates showcase.dme, which defines
// CIV13_SHOWCASE_BUILD and includes it. Never run that build alongside, or as,
// a persistent world such as Gaia.
#ifndef CIV13_SHOWCASE_BUILD
#error showcase_rooms.dm belongs to the separate showcase build; generate showcase.dme with scripts/build_showcase_dme.py.
#endif

// Furnished showcase rooms: small DMM templates in maps/zones/showcase/ that
// stage a working gameplay station (smithy, kitchen, tavern, workshop, farm
// shed, infirmary) with starter materials and a guide note. Templates carry
// no areas, so a loaded room keeps the area of the ground it is placed on.

#define SHOWCASE_ROOM_DIR "maps/zones/showcase/"

/proc/showcase_room_names()
	. = list()
	for (var/entry in flist(SHOWCASE_ROOM_DIR))
		if (copytext(entry, -4) == ".dmm")
			. += copytext(entry, 1, -4)

// Returns list(width, height) of the single z-level grid, or null when the
// text is not a template this loader understands.
/proc/showcase_room_dimensions(dmm_text)
	if (!dmm_text)
		return null
	var/start = findtext(dmm_text, "\n\n(1,1,1) = {\"\n")
	if (!start)
		return null
	var/grid_start = start + length("\n\n(1,1,1) = {\"\n")
	var/grid_end = findtext(dmm_text, "\n\"}", grid_start)
	if (!grid_end)
		return null
	// The reader loads every grid block on consecutive z-levels; the verb only
	// clears and bounds-checks one, so refuse templates with a second grid.
	if (findtext(dmm_text, " = {\"", grid_end))
		return null
	var/list/rows = splittext(copytext(dmm_text, grid_start, grid_end), "\n")
	var/key_len = length(copytext(dmm_text, 2, findtext(dmm_text, "\"", 2)))
	if (!rows.len || key_len < 1)
		return null
	var/row_len = length(rows[1])
	if (row_len < key_len || row_len % key_len)
		return null
	for (var/row in rows)
		if (length(row) != row_len)
			return null
	return list(row_len / key_len, rows.len)

// Every mob anywhere inside an atom, at any depth (closets, crates, carried
// holders), so no occupant is deleted along with its container.
/proc/showcase_room_nested_mobs(atom/A, list/found, list/seen)
	if (!found)
		found = list()
	if (!seen)
		seen = list()
	for (var/atom/movable/AM in A.contents)
		if (seen[AM])
			continue
		seen[AM] = TRUE
		if (ismob(AM))
			found += AM
		if (AM.contents.len)
			showcase_room_nested_mobs(AM, found, seen)
	return found

/proc/showcase_room_cleared(obj/O)
	return istype(O, /obj/structure) || istype(O, /obj/item) || istype(O, /obj/covers) || istype(O, /obj/roof)

// Returns why the footprint cannot be replaced now, or null. Persistence and
// level allocation must be idle, and nothing in the footprint may belong to a
// paired building level: deleting one half deletes its partner on the next or
// previous z-level and drops whatever stands there, outside this footprint.
/proc/showcase_room_mutation_blocker(x1, y1, x2, y2, z)
	if (persistence_round_active())
		return "Showcase rooms are for disposable demo rounds only and refuse persistent worlds."
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return "A world save or load is running or awaiting recovery. Try again when it finishes."
	if (map_storage && (map_storage.dimension_recovery_required || map_storage.dimension_budget_hold))
		return "World level recovery is pending. Try again when it finishes."
	if (world_z_budget.active || building_allocating_z)
		return "A new level is being allocated. Try again shortly."
	for (var/turf/T in block(locate(x1, y1, z), locate(x2, y2, z)))
		for (var/obj/roof/R in T)
			if (R.building_pair_id)
				return "The roof at ([T.x],[T.y]) carries a building floor on the level above. Pick a spot away from multi-level buildings."
		for (var/obj/covers/C in T)
			if (C.building_pair_id)
				return "The floor at ([T.x],[T.y]) is an upper building level. Pick a spot away from multi-level buildings."
	return null

/proc/showcase_room_clear_footprint(x1, y1, x2, y2, z, turf/evacuate_to)
	for (var/turf/T in block(locate(x1, y1, z), locate(x2, y2, z)))
		for (var/mob/M in T)
			M.forceMove(evacuate_to)
		for (var/obj/O in T)
			if (!showcase_room_cleared(O))
				continue
			for (var/mob/M in showcase_room_nested_mobs(O))
				M.forceMove(evacuate_to)
			qdel(O)

// Same model and grid rules as dmm_suite/read_map, without its sleep(-1)
// yields, so a save cannot be admitted partway through the replacement. The
// text was already validated by showcase_room_dimensions.
/proc/showcase_room_place(dmm_text, x1, y1, z)
	var/dmm_suite/suite = new()
	var/key_len = length(copytext(dmm_text, 2, findtext(dmm_text, "\"", 2)))
	var/grid_marker = findtext(dmm_text, "\n\n(1,1,1) = {\"\n")
	var/list/models = list()
	for (var/line in splittext(copytext(dmm_text, 1, grid_marker), "\n"))
		var/key = copytext(line, 2, findtext(line, "\"", 2))
		models[key] = copytext(line, findtext(line, "=") + 3, length(line))
	var/grid_start = grid_marker + length("\n\n(1,1,1) = {\"\n")
	var/list/rows = splittext(copytext(dmm_text, grid_start, findtext(dmm_text, "\n\"}", grid_start)), "\n")
	for (var/row_index = 1 to rows.len)
		var/row = rows[row_index]
		var/y = y1 + rows.len - row_index
		for (var/column = 1 to length(row) / key_len)
			var/key = copytext(row, (column - 1) * key_len + 1, column * key_len + 1)
			suite.parse_grid(models[key], x1 + column - 1, y, z)

/client/proc/load_showcase_room()
	set name = "Load Showcase Room"
	set category = "Debug"
	set desc = "Place a furnished room that shows off a gameplay station, with its door just north of you."

	if (!check_rights(R_SPAWN))
		return
	if (persistence_round_active())
		WWalert(usr, "Showcase rooms are for disposable demo rounds only and refuse persistent worlds.", "Showcase Room")
		return
	if (persistence_save_in_progress)
		WWalert(usr, "A world save is in progress. Try again when it finishes.", "Showcase Room")
		return
	var/turf/origin = get_turf(mob)
	if (!origin)
		return

	var/list/rooms = showcase_room_names()
	if (!rooms.len)
		WWalert(usr, "No showcase rooms were found in [SHOWCASE_ROOM_DIR].", "Showcase Room")
		return
	var/choice = WWinput(usr, "Which room? It loads directly north of you, with its door on your tile's north side. Everything already in that space is removed.", "Showcase Room", rooms[1], rooms + "Cancel")
	if (!choice || choice == "Cancel" || !(choice in rooms))
		return

	var/dmm_text = file2text("[SHOWCASE_ROOM_DIR][choice].dmm")
	var/list/size = showcase_room_dimensions(dmm_text)
	if (!size)
		WWalert(usr, "[choice] is not a valid showcase template.", "Showcase Room")
		return
	var/width = size[1]
	var/height = size[2]
	var/x1 = origin.x - round(width / 2)
	var/y1 = origin.y + 1
	var/x2 = x1 + width - 1
	var/y2 = y1 + height - 1
	var/z = origin.z
	if (x1 < 1 || y1 < 1 || x2 > world.maxx || y2 > world.maxy)
		WWalert(usr, "There is not enough room here: [choice] needs [width]x[height] tiles north of you.", "Showcase Room")
		return

	var/roof = WWinput(usr, "Add a wooden roof? A roof makes the room indoors (shelter from weather and a roofed area).", "Showcase Room", "Yes", list("Yes", "No"))
	if (!roof)
		return

	// The admin may have moved while the prompts were open.
	origin = get_turf(mob)
	if (!origin || origin.x != x1 + round(width / 2) || origin.y != y1 - 1 || origin.z != z)
		WWalert(usr, "You moved. Stand where you want the door and try again.", "Showcase Room")
		return

	var/blocker = showcase_room_mutation_blocker(x1, y1, x2, y2, z)
	if (blocker)
		WWalert(usr, blocker, "Showcase Room")
		return

	// No sleep, input, callback or tick check from the admission check above
	// until the room and its roof are complete: a save can only be admitted
	// while this proc yields, so it cannot overlap the replacement.
	showcase_room_clear_footprint(x1, y1, x2, y2, z, origin)
	showcase_room_place(dmm_text, x1, y1, z)

	if (roof == "Yes")
		for (var/turf/T in block(locate(x1, y1, z), locate(x2, y2, z)))
			if (!istype(T, /turf/wall))
				new /obj/roof/wood(T)

	log_admin("[key_name(usr)] loaded the [choice] showcase room at ([x1],[y1],[z])-([x2],[y2],[z]).")
	message_admins("[key_name_admin(usr)] loaded the [choice] showcase room at ([x1],[y1],[z]).")

/client/add_admin_verbs()
	..()
	if (holder && (holder.rights & R_SPAWN))
		verbs += /client/proc/load_showcase_room

/client/remove_admin_verbs()
	..()
	verbs -= /client/proc/load_showcase_room

#undef SHOWCASE_ROOM_DIR
