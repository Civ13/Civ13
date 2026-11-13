// Hand-built aircraft (craft/vehicle_assembly.dm): the same frames-and-axis
// assembly as cars and boats. A builder lays crafted airframe sections in a
// rectangle 3 sections wide and 3 to 5 long, stands the parts on them (an engine, a fuel tank,
// a pilot's seat, wheels on the four corners, passenger seats anywhere) and
// sets the airframe controls down on any section. Assembling turns every
// section into the piece of plane its place calls for, counted from the front
// the builder chose: the nose row, the wing row with the cockpit where the
// pilot sits, the fuselage rows and the tail row, so a hand-built plane looks,
// flies, hangars and saves like a hangar-built one. Taking it apart leaves the
// shaped pieces, which assemble again into any shape.

// The airframe pieces are drawn for a three-section wingspan: a nose, a wing
// each side of the cockpit and a tail. Length runs from 3 to the largest
// vehicle (a nose, a wing row, fuselage rows and a tail).
#define AIRCRAFT_ASSEMBLY_SPAN 3

/obj/structure/vehicleparts/frame/car/aircraft/section
	name = "airframe section"
	desc = "A light metal airframe section. Lay them in a rectangle and stand airframe controls on one to assemble a plane; each takes the shape of the nose, wing, cockpit, fuselage or tail its place calls for."

/obj/structure/vehicleparts/axis/aircraft/airframe
	name = "airframe controls"
	desc = "Control runs, trim and instruments for a hand-built aircraft. Lay airframe sections in a rectangle 3 sections wide and 3 to 5 long, stand an engine, a fuel tank, a pilot's seat and corner wheels on them, set this down on any section and click it to assemble."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	anchored = FALSE

// A crafted pilot's seat can be dragged onto its frame before assembly.
/obj/structure/bed/chair/drivers/aircraft/loose
	anchored = FALSE

// Airframe sections only join airframe controls, and the reverse.
/proc/vehicle_assembly_kind_matches(obj/structure/vehicleparts/frame/F, obj/structure/vehicleparts/axis/A)
	return istype(F, /obj/structure/vehicleparts/frame/car/aircraft) == istype(A, /obj/structure/vehicleparts/axis/aircraft)

/obj/structure/vehicleparts/axis/proc/assembly_refusal(datum/vehicle_survey/S)
	return null

/obj/structure/vehicleparts/axis/aircraft/assembly_refusal(datum/vehicle_survey/S)
	if (min(S.width, S.height) != AIRCRAFT_ASSEMBLY_SPAN || max(S.width, S.height) < AIRCRAFT_ASSEMBLY_SPAN)
		return "the airframe is [S.width] by [S.height] sections; a plane is [AIRCRAFT_ASSEMBLY_SPAN] sections wide (a wing each side of the cockpit) and [AIRCRAFT_ASSEMBLY_SPAN] or more long"
	return null

// The airframe piece for a section in row (1 = nose) of rows, column (1 = the
// plane's left) of cols; cockpit marks the pilot's tile in the wing row.
/proc/aircraft_section_type(row, rows, col, cols, cockpit)
	var/side = col == 1 ? "left" : (col == cols ? "right" : "center")
	var/middle = col == round((cols + 1) / 2)
	if (row == 1)
		return text2path("/obj/structure/vehicleparts/frame/car/aircraft/nose/[side]")
	if (row == rows)
		return text2path("/obj/structure/vehicleparts/frame/car/aircraft/tail/[side]")
	if (row == 2)
		if (cockpit)
			return /obj/structure/vehicleparts/frame/car/aircraft/cockpit
		if (middle || (cols % 2 == 0 && col == cols / 2 + 1))
			return /obj/structure/vehicleparts/frame/car/aircraft/fuselage/center
		return col < (cols + 1) / 2 ? /obj/structure/vehicleparts/frame/car/aircraft/wing/left : /obj/structure/vehicleparts/frame/car/aircraft/wing/right
	return text2path("/obj/structure/vehicleparts/frame/car/aircraft/fuselage/[side]")

// Turns each surveyed section into its shaped piece for this facing. Sections
// already of the right type stay; the rest are replaced in place.
/obj/structure/vehicleparts/axis/aircraft/proc/shape_airframe(datum/vehicle_survey/S, facing)
	// Rows count back from the nose, columns from the plane's own left.
	for (var/obj/structure/vehicleparts/frame/F in S.frames)
		var/row
		var/rows
		var/col
		var/cols
		switch (facing)
			if (NORTH)
				row = S.max_y - F.y + 1
				col = F.x - S.min_x + 1
			if (SOUTH)
				row = F.y - S.min_y + 1
				col = S.max_x - F.x + 1
			if (EAST)
				row = S.max_x - F.x + 1
				col = S.max_y - F.y + 1
			if (WEST)
				row = F.x - S.min_x + 1
				col = F.y - S.min_y + 1
		rows = (facing & (NORTH | SOUTH)) ? S.height : S.width
		cols = (facing & (NORTH | SOUTH)) ? S.width : S.height
		var/turf/T = get_turf(F)
		var/cockpit = row == 2 && S.seat && get_turf(S.seat) == T
		var/path = aircraft_section_type(row, rows, col, cols, cockpit)
		if (!path || F.type == path)
			continue
		var/obj/structure/vehicleparts/frame/N = new path(T)
		N.dir = facing
		N.override_color = F.override_color
		if (F.mwheel)
			N.mwheel = F.mwheel
			F.mwheel = null
		F.broken = TRUE
		qdel(F)

/obj/structure/vehicleparts/axis/aircraft/assemble(facing = NORTH)
	if (components.len)
		return "it is assembled already"
	if (!(facing in list(NORTH, SOUTH, EAST, WEST)))
		facing = NORTH
	var/datum/vehicle_survey/S = new(src)
	if (S.refusal)
		return S.refusal
	var/span = (facing & (NORTH | SOUTH)) ? S.width : S.height
	if (span != AIRCRAFT_ASSEMBLY_SPAN)
		return "its wings would be [span] sections across; point the nose along the airframe's long side"
	shape_airframe(S, facing)
	. = ..(facing)
	if (.)
		return
	// A bigger airframe needs a longer roll: one more runway tile for every two
	// sections past the light plane's twelve.
	var/extra = max(0, round((frames().len - 12) / 2))
	takeoff_roll = initial(takeoff_roll) + extra
	rough_takeoff_roll = initial(rough_takeoff_roll) + extra * 2
	finish_airframe_parts()
	for (var/obj/O in components)
		O.update_icon()

/obj/structure/vehicleparts/axis/aircraft/fit_parts()
	. = ..()
	finish_airframe_parts()

// The engine and tank sit inside the airframe like the hangar's planes.
/obj/structure/vehicleparts/axis/aircraft/proc/finish_airframe_parts()
	if (!engine)
		return
	engine.key_axis = src
	engine.engineclass = "carengine"
	engine.density = FALSE
	engine.update_icon()
	if (engine.fueltank)
		engine.fueltank.icon_state = "fueltank_incar"

#undef AIRCRAFT_ASSEMBLY_SPAN
