// Hand-built submarines (craft/vehicle_assembly.dm): the same frames-and-axis
// assembly as cars, boats and planes. A builder floats crafted submarine hull
// sections on the water in a rectangle 3 sections wide and 5 or 7 long, stands
// the parts on them (a ship's wheel, an engine and its fuel tank, a ballast and
// periscope station, and if they like a battery bank, an air bank, lockers and
// berths) and sets the submarine controls down on any section. Assembling turns
// every section into the piece of hull its place calls for, counted from the
// bow the builder chose: the Scout's plan for 5 sections, the Explorer's for 7
// (submarine_layouts), with the glass bow, bulkheads, watertight doors,
// lock-out hatches and stern tanks where the pen would put them. So a hand-built
// boat looks, dives, docks and saves like a pen-built one. Taking it apart
// leaves the shaped pieces, which assemble again facing any way.

// The hull art is drawn for a three-section beam and the two pen lengths.
#define SUBMARINE_ASSEMBLY_BEAM 3

/obj/structure/vehicleparts/frame/ship/steel/submarine/section
	name = "submarine hull section"
	desc = "A riveted steel pressure hull section. Float them in a rectangle 3 sections wide and 5 or 7 long and stand submarine controls on one to assemble a boat; each takes the shape of the bow, hatch, bulkhead or stern its place calls for."

/obj/structure/vehicleparts/axis/ship/submarine/controls
	name = "submarine controls"
	desc = "Rudder, dive planes, ballast valves and the control runs for a hand-built submarine. Float submarine hull sections in a rectangle 3 sections wide and 5 (a Scout) or 7 (an Explorer) long, stand a ship's wheel, an engine, a fuel tank and a ballast and periscope station on them, set this down on any section and click it to assemble."
	anchored = FALSE

// Crafted fittings can be dragged onto their sections before assembly.
/obj/structure/vehicleparts/sub_station/loose
	anchored = FALSE

/obj/structure/vehicleparts/sub_fitting/battery/loose
	anchored = FALSE

/obj/structure/vehicleparts/sub_fitting/air/loose
	anchored = FALSE

// Which pen plan a hull of this many sections takes, or null.
/proc/submarine_class_for_length(length)
	switch (length)
		if (5)
			return "scout"
		if (7)
			return "explorer"
	return null

// The Explorer is 7 long, turning in the largest square a vehicle has.
/obj/structure/vehicleparts/axis/ship/submarine/assembly_max_size()
	return VEHICLE_MAX_TURNING_SQUARE

/obj/structure/vehicleparts/axis/ship/submarine/assembly_refusal(datum/vehicle_survey/S)
	var/beam = min(S.width, S.height)
	var/length = max(S.width, S.height)
	var/datum/sub_draught/D = sheet()
	if (D)
		var/wanted = D.length
		var/plan = D.name
		qdel(D)
		if (beam != SUBMARINE_ASSEMBLY_BEAM || length != wanted)
			return "the hull is [S.width] by [S.height] sections; the [plan] is drawn [SUBMARINE_ASSEMBLY_BEAM] sections wide and [wanted] long"
	else if (beam != SUBMARINE_ASSEMBLY_BEAM || !submarine_class_for_length(length))
		return "the hull is [S.width] by [S.height] sections; a submarine is [SUBMARINE_ASSEMBLY_BEAM] sections wide and 5 (a Scout) or 7 (an Explorer) long, or as long as the submarine sheet given to her controls"
	for (var/obj/structure/vehicleparts/frame/F in S.frames)
		if (sea_layer_cell(get_turf(F)))
			return "a submarine is put together on the surface, not under the sea"
	return null

// Turns each surveyed section into its piece of the pen's plan for this
// facing: the hull type, its art tile and its walls. Rows count back from
// the bow, columns from the boat's starboard side, as submarine_layouts does.
/obj/structure/vehicleparts/axis/ship/submarine/proc/shape_hull(datum/vehicle_survey/S, facing, hull, list/layout = null, length = 0)
	if (!layout)
		layout = submarine_layouts[hull]
	for (var/obj/structure/vehicleparts/frame/F in S.frames.Copy())
		var/row
		var/col
		switch (facing)
			if (NORTH)
				row = S.max_y - F.y + 1
				col = S.max_x - F.x + 1
			if (SOUTH)
				row = F.y - S.min_y + 1
				col = F.x - S.min_x + 1
			if (EAST)
				row = S.max_x - F.x + 1
				col = F.y - S.min_y + 1
			if (WEST)
				row = F.x - S.min_x + 1
				col = S.max_y - F.y + 1
		var/list/entry = layout["[col],[row]"]
		if (!entry)
			continue
		var/obj/structure/vehicleparts/frame/ship/steel/submarine/N = F
		var/path = entry[1]
		if (F.type != path)
			N = new path(get_turf(F))
			N.override_color = F.override_color
			F.broken = TRUE
			qdel(F)
		N.hull_tile = length ? submarine_art_tile(length, col, row) : "[hull]_[col]_[row]"
		N.w_front = list("",FALSE,FALSE,0,0,FALSE,FALSE,FALSE)
		N.w_back = list("",FALSE,FALSE,0,0,FALSE,FALSE,FALSE)
		N.w_left = list("",FALSE,FALSE,0,0,FALSE,FALSE,FALSE)
		N.w_right = list("",FALSE,FALSE,0,0,FALSE,FALSE,FALSE)
		N.set_hull_walls(entry[2])

/obj/structure/vehicleparts/axis/ship/submarine/assemble(facing = NORTH)
	if (components.len)
		return "it is assembled already"
	if (!(facing in list(NORTH, SOUTH, EAST, WEST)))
		facing = NORTH
	var/datum/vehicle_survey/S = new(src)
	if (S.refusal)
		return S.refusal
	var/beam = (facing & (NORTH | SOUTH)) ? S.width : S.height
	if (beam != SUBMARINE_ASSEMBLY_BEAM)
		return "she would be [beam] sections across; point the bow along the hull's long side"
	var/length = (facing & (NORTH | SOUTH)) ? S.height : S.width
	var/hull = submarine_class_for_length(length)
	var/datum/sub_draught/D = sheet()
	if (D)
		// A boat drawn on a sheet: its plan, and the art of the hull of her
		// length (submarine_art_tile()). She handles as the pen's boat of
		// the nearest length.
		hull = length >= 6 ? "explorer" : "scout"
		shape_hull(S, facing, hull, D.layout(), length)
		qdel(D)
	else
		shape_hull(S, facing, hull)
	. = ..(facing)
	if (.)
		return
	hull_class = hull
	battery = min(battery, battery_capacity())
	air_bank = min(air_bank, air_capacity())
	// The longer boat is the Explorer, as slow as the pen's.
	speedlist = hull == "explorer" ? alist(1=18,2=14,3=11) : alist(1=16,2=12,3=9)
	for (var/obj/O in components)
		O.update_icon()

// ---- Building from a submarine sheet (naval/sub_draught.dm) ----

/obj/structure/vehicleparts/axis/ship/submarine
	// The submarine sheet she was assembled from, as its design code, or "".
	// Saved: her plan (hull_layout()) and what the controls shape next time.
	var/sheet_code = ""

/obj/structure/vehicleparts/axis/ship/submarine/proc/sheet()
	return sheet_code ? sub_draught_from_code(sheet_code) : null

// The art tile for a section of a boat this long. Every length has a hull
// drawn for it (scripts/draw_submarine_hull.py): the Coaster's for 4, the
// Scout's for 5, the Cruiser's for 6 and the Explorer's for 7, row for row.
/proc/submarine_art_tile(length, col, row)
	var/art
	switch (length)
		if (4)
			art = "coaster"
		if (5)
			art = "scout"
		if (6)
			art = "cruiser"
		else
			art = "explorer"
			length = 7
	return "[art]_[col]_[clamp(row, 1, length)]"

// Handing the controls a submarine sheet: the hull floated for them is shaped
// to that plan when they assemble her.
/obj/structure/vehicleparts/axis/ship/submarine/controls/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/ship_draught))
		return ..()
	var/obj/item/ship_draught/S = W
	var/datum/sub_draught/D = S.sub_draught()
	if (!D)
		to_chat(user, SPAN_WARNING("That sheet does not show a submarine."))
		return TRUE
	if (components.len)
		to_chat(user, SPAN_WARNING("\The [src] are fitted to a boat already. Take her apart to build to another plan."))
		qdel(D)
		return TRUE
	var/list/P = D.problems()
	if (P.len)
		to_chat(user, SPAN_WARNING("The [D.name] cannot be assembled as drawn: [jointext(P, " ")]"))
		qdel(D)
		return TRUE
	// Clipping a new sheet over another must not swap her plan by a misclick.
	var/datum/sub_draught/old = sheet()
	if (old)
		var/old_name = old.name
		qdel(old)
		if (S.draught_code != sheet_code && WWinput(user, "Clip the sheet of the [D.name] to \the [src]? It replaces the sheet of the [old_name] clipped there now.", name, "No", list("Yes", "No")) != "Yes")
			qdel(D)
			return TRUE
		if (QDELETED(S) || S.loc != user || get_dist(user, src) > 1 || components.len)
			qdel(D)
			return TRUE
	sheet_code = S.draught_code
	to_chat(user, SPAN_NOTICE("You clip the sheet of the [D.name] to \the [src]. Float [SUBMARINE_ASSEMBLY_BEAM * D.length] hull sections [SUBMARINE_ASSEMBLY_BEAM] wide and [D.length] long, stand her fittings where the sheet shows them, and assemble her."))
	qdel(D)
	return TRUE

// What the controls will build, for the assembly sheet.
/obj/structure/vehicleparts/axis/ship/submarine/controls/examine(mob/user)
	. = ..()
	var/datum/sub_draught/D = sheet()
	if (D)
		to_chat(user, SPAN_NOTICE("The sheet of the [D.name] is clipped to them: [SUBMARINE_ASSEMBLY_BEAM] sections wide and [D.length] long."))
		qdel(D)

// The station and gauges standing on the hull are bolted down with the rest.
/obj/structure/vehicleparts/axis/ship/submarine/fit_parts()
	. = ..()
	for (var/obj/structure/vehicleparts/frame/F in frames())
		for (var/obj/structure/vehicleparts/sub_station/station in get_turf(F))
			if (!station.anchored)
				station.anchored = TRUE
				station.dir = dir
				.++
		for (var/obj/structure/vehicleparts/sub_fitting/fitting in get_turf(F))
			if (!fitting.anchored)
				fitting.anchored = TRUE
				fitting.dir = dir
				.++

/obj/structure/vehicleparts/axis/ship/submarine/take_apart_refusal(mob/living/human/H)
	if (submerged)
		return "she must be on the surface"
	return ..()

/obj/structure/vehicleparts/axis/ship/submarine/take_apart()
	end_all_periscopes()
	var/list/hull = frames()
	..()
	// The crafted fittings come loose with the hull; the pen's stay bolted.
	for (var/obj/structure/vehicleparts/frame/F in hull)
		for (var/obj/structure/vehicleparts/sub_station/loose/station in get_turf(F))
			station.anchored = FALSE
		for (var/obj/structure/vehicleparts/sub_fitting/battery/loose/battery in get_turf(F))
			battery.anchored = FALSE
		for (var/obj/structure/vehicleparts/sub_fitting/air/loose/air in get_turf(F))
			air.anchored = FALSE

#undef SUBMARINE_ASSEMBLY_BEAM
