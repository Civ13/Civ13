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
	var/start = findtext(dmm_text, "(1,1,1) = {\"\n")
	if (!start)
		return null
	var/grid_start = start + length("(1,1,1) = {\"\n")
	var/grid_end = findtext(dmm_text, "\n\"}", grid_start)
	if (!grid_end)
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

/proc/showcase_room_clear_footprint(x1, y1, x2, y2, z, turf/evacuate_to)
	for (var/turf/T in block(locate(x1, y1, z), locate(x2, y2, z)))
		for (var/mob/living/L in T)
			L.forceMove(evacuate_to)
		for (var/obj/O in T)
			if (istype(O, /obj/structure) || istype(O, /obj/item) || istype(O, /obj/covers) || istype(O, /obj/roof))
				qdel(O)

/client/proc/load_showcase_room()
	set name = "Load Showcase Room"
	set category = "Debug"
	set desc = "Place a furnished room that shows off a gameplay station, with its door just north of you."

	if (!check_rights(R_SPAWN))
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

	showcase_room_clear_footprint(x1, y1, x2, y2, z, origin)
	var/dmm_suite/suite = new()
	suite.read_map(dmm_text, x1, y1, z)

	if (roof == "Yes")
		for (var/turf/T in block(locate(x1, y1, z), locate(x2, y2, z)))
			if (!istype(T, /turf/wall))
				new /obj/roof/wood(T)

	log_admin("[key_name(usr)] loaded the [choice] showcase room at ([x1],[y1],[z])-([x2],[y2],[z]).")
	message_admins("[key_name_admin(usr)] loaded the [choice] showcase room at ([x1],[y1],[z]).")

#undef SHOWCASE_ROOM_DIR
