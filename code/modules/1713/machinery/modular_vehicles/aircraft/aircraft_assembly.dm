// Hand-built aircraft (craft/vehicle_assembly.dm): the same frames-and-axis
// assembly as cars and boats. A builder lays crafted airframe sections in a
// rectangle 3 sections wide and 3 to 6 long (or 5 wide and 4 to 6 long for a
// twin), stands the parts on them (an engine, a fuel tank,
// a pilot's seat, wheels on the four corners, passenger seats anywhere) and
// sets the airframe controls down on any section. Assembling turns every
// section into the piece of plane its place calls for, counted from the front
// the builder chose: the nose row, the wing row with the cockpit where the
// pilot sits, the fuselage rows and the tail row, so a hand-built plane looks,
// flies, hangars and saves like a hangar-built one. Taking it apart leaves the
// shaped pieces, which assemble again into any shape.

// The airframe pieces are drawn for a three-section wingspan: a nose, a wing
// each side of the cockpit and a tail. Length runs from 3 to
// AIRCRAFT_MAX_LENGTH (a nose, a wing row, fuselage rows and a tail). The
// twin-engine pieces (aircraft_twin.dm) make a five-section wingspan, 4 to
// AIRCRAFT_MAX_LENGTH long: the fuselage row repeats, as in the airliner.
#define AIRCRAFT_ASSEMBLY_SPAN 3
#define AIRCRAFT_TWIN_SPAN 5
#define AIRCRAFT_TWIN_LENGTH 4

// What a twin's wings bear: the twin-engine plane's 1400 at 4 long and 100
// more for each cabin row, the airliner's 1600 at 6.
/proc/aircraft_twin_wing_load(length)
	return 1400 + 100 * clamp(length - AIRCRAFT_TWIN_LENGTH, 0, AIRCRAFT_MAX_LENGTH - AIRCRAFT_TWIN_LENGTH)

/obj/structure/vehicleparts/frame/car/aircraft/section
	name = "airframe section"
	desc = "A light metal airframe section. Lay them in a rectangle and stand airframe controls on one to assemble a plane; each takes the shape of the nose, wing, cockpit, fuselage or tail its place calls for."

/obj/structure/vehicleparts/axis/aircraft/airframe
	name = "airframe controls"
	desc = "Control runs, trim and instruments for a hand-built aircraft. Lay airframe sections in a rectangle 3 sections wide and 3 to 6 long (or 5 wide and 4 to 6 long for a twin-engine plane), stand an engine, a fuel tank, a pilot's seat and corner wheels on them, set this down on any section and click it to assemble."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	anchored = FALSE

// A crafted pilot's seat can be dragged onto its frame before assembly.
/obj/structure/bed/chair/drivers/aircraft/loose
	anchored = FALSE

// Airframe sections only join airframe controls, and submarine hull sections
// only submarine controls, and the reverse.
/proc/vehicle_assembly_kind_matches(obj/structure/vehicleparts/frame/F, obj/structure/vehicleparts/axis/A)
	if (istype(F, /obj/structure/vehicleparts/frame/car/aircraft) != istype(A, /obj/structure/vehicleparts/axis/aircraft))
		return FALSE
	return istype(F, /obj/structure/vehicleparts/frame/ship/steel/submarine) == istype(A, /obj/structure/vehicleparts/axis/ship/submarine)

/obj/structure/vehicleparts/axis/proc/assembly_refusal(datum/vehicle_survey/S)
	return null

/obj/structure/vehicleparts/axis/aircraft/assembly_refusal(datum/vehicle_survey/S)
	if (aircraft_airframe_size_ok(S.width, S.height) || aircraft_airframe_size_ok(S.height, S.width))
		return null
	return "the airframe is [S.width] by [S.height] sections; a plane is [AIRCRAFT_ASSEMBLY_SPAN] sections wide (a wing each side of the cockpit) and [AIRCRAFT_ASSEMBLY_SPAN] to [AIRCRAFT_MAX_LENGTH] long, or a twin-engine plane [AIRCRAFT_TWIN_SPAN] wide and [AIRCRAFT_TWIN_LENGTH] to [AIRCRAFT_MAX_LENGTH] long"

// An airframe's longest side: the airliner's length.
/obj/structure/vehicleparts/axis/aircraft/assembly_max_size()
	return max(..(), AIRCRAFT_MAX_LENGTH)

// The longest twin's airframe: five sections across, as the airliner.
/obj/structure/vehicleparts/axis/aircraft/assembly_max_frames()
	return max(..(), AIRCRAFT_TWIN_SPAN * AIRCRAFT_MAX_LENGTH)

// TRUE when an airframe may be span sections across the wings and length
// from nose to tail: a single-engine plane or a twin (craft/vehicle_draught.dm
// draws the same sizes).
/proc/aircraft_airframe_size_ok(span, length)
	if (span == AIRCRAFT_ASSEMBLY_SPAN)
		return length >= AIRCRAFT_ASSEMBLY_SPAN && length <= AIRCRAFT_MAX_LENGTH
	if (span == AIRCRAFT_TWIN_SPAN)
		return length >= AIRCRAFT_TWIN_LENGTH && length <= AIRCRAFT_MAX_LENGTH
	return FALSE

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
		var/path = cols == AIRCRAFT_TWIN_SPAN ? aircraft_twin_section_type(row, col, cockpit, rows) : aircraft_section_type(row, rows, col, cols, cockpit)
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
	var/sections_long = (facing & (NORTH | SOUTH)) ? S.height : S.width
	// Only a twin's airframe is more than three sections across either way.
	var/twin = min(S.width, S.height) > AIRCRAFT_ASSEMBLY_SPAN
	// Two engines on the wings are the later, all-metal design (aircraft_model_node()).
	var/mob/living/human/builder = usr
	if (twin && istype(builder) && map && !research_node_known(builder, aircraft_model_node("Twin-engine plane")))
		var/datum/research_node/N = get_research_node(aircraft_model_node("Twin-engine plane"))
		return "a twin-engine airframe needs [N ? N.name : "more"] research"
	if (!aircraft_airframe_size_ok(span, sections_long))
		return twin ? "its wings would be [span] sections across; a twin-engine plane's wings run along the 5-section side" : "its wings would be [span] sections across; point the nose along the airframe's long side"
	shape_airframe(S, facing)
	. = ..(facing)
	if (.)
		return
	// A bigger airframe needs a longer roll: one more runway tile for every two
	// sections past the light plane's twelve.
	var/extra = max(0, round((frames().len - 12) / 2))
	takeoff_roll = initial(takeoff_roll) + extra
	rough_takeoff_roll = initial(rough_takeoff_roll) + extra * 2
	// Two engines lift a twin's weight, as the hangar's twin-engine plane; a
	// longer cabin's wings bear more, up to the airliner's.
	if (twin)
		maxpower = max(maxpower, aircraft_twin_wing_load(sections_long))
	finish_airframe_parts()
	for (var/obj/O in components)
		O.update_icon()

// A twin's wing engines and their tanks come loose with the rest.
/obj/structure/vehicleparts/axis/aircraft/take_apart()
	var/list/loose = wing_engines()
	..()
	for (var/obj/structure/engine/internal/E in loose)
		E.on = FALSE
		E.anchored = FALSE
		E.key_axis = null
		if (E.fueltank)
			E.fueltank.anchored = FALSE
			E.fueltank = null
		E.update_icon()

/obj/structure/vehicleparts/axis/aircraft/fit_parts()
	. = ..()
	finish_airframe_parts()

// The engines and tanks sit inside the airframe like the hangar's planes.
// The first engine is the pilot's; any others (a twin's) run with it.
/obj/structure/vehicleparts/axis/aircraft/proc/finish_airframe_parts()
	if (!engine)
		return
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (F.axis != src)
			continue
		for (var/obj/structure/engine/internal/E in get_turf(F))
			E.key_axis = src
			E.engineclass = "carengine"
			E.icon = 'icons/obj/vehicles/vehicleparts.dmi'
			E.anchored = TRUE
			E.density = FALSE
	link_fuel_tanks()
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (F.axis != src)
			continue
		for (var/obj/structure/engine/internal/E in get_turf(F))
			E.update_icon()
	if (engine.fueltank)
		engine.fueltank.icon_state = "fueltank_incar"

#undef AIRCRAFT_ASSEMBLY_SPAN
#undef AIRCRAFT_TWIN_SPAN
#undef AIRCRAFT_TWIN_LENGTH
