// The twin-engine plane: a 5-section wingspan, 4 sections long, with an engine
// in a nacelle on each wing (art: tests/sprites/create_twin_plane.py). The
// hangar builds it and a builder can put one together by hand from airframe
// sections (aircraft_assembly.dm). Facing north, col 1 is the plane's left:
//
//   open        engine L    nose        engine R    open
//   wing tip L  nacelle L   cockpit     nacelle R   wing tip R
//   open        fuselage L  fuselage    fuselage R  open
//   tailplane L tail L      tail        tail R      tailplane R
//
// The open corners carry nothing but the wing's landing gear. Every engine
// aboard runs with the one the pilot starts, and they share the load.

// The nose has no propeller of its own: the engines are on the wings.
/obj/structure/vehicleparts/frame/car/aircraft/nose/center/twin
	prop_state = null
	prop_spin_state = null

/obj/structure/vehicleparts/frame/car/aircraft/twin_engine
	name = "engine nacelle"
	desc = "A light metal airframe section with an engine cowling and propeller."
/obj/structure/vehicleparts/frame/car/aircraft/twin_engine/left
	hull_state = "twin_engine_left"
	prop_state = "twin_prop_left"
	prop_spin_state = "twin_prop_spin_left"
	w_front = list("c_armoredfront",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/aircraft/twin_engine/right
	hull_state = "twin_engine_right"
	prop_state = "twin_prop_right"
	prop_spin_state = "twin_prop_spin_right"
	w_front = list("c_armoredfront",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

/obj/structure/vehicleparts/frame/car/aircraft/twin_nacelle
	name = "wing nacelle"
	desc = "A light metal wing section with a bay behind the engine."
/obj/structure/vehicleparts/frame/car/aircraft/twin_nacelle/left
	hull_state = "twin_nacelle_left"
/obj/structure/vehicleparts/frame/car/aircraft/twin_nacelle/right
	hull_state = "twin_nacelle_right"

/obj/structure/vehicleparts/frame/car/aircraft/wing/twin_tip/left
	hull_state = "twin_wing_tip_left"
/obj/structure/vehicleparts/frame/car/aircraft/wing/twin_tip/right
	hull_state = "twin_wing_tip_right"

/obj/structure/vehicleparts/frame/car/aircraft/twin_tail/left
	hull_state = "twin_tail_left"
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/aircraft/twin_tail/right
	hull_state = "twin_tail_right"
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

/obj/structure/vehicleparts/frame/car/aircraft/twin_tailplane
	name = "tailplane"
	desc = "The tip of a light metal tailplane with its fin."
/obj/structure/vehicleparts/frame/car/aircraft/twin_tailplane/left
	hull_state = "twin_tailplane_left"
/obj/structure/vehicleparts/frame/car/aircraft/twin_tailplane/right
	hull_state = "twin_tailplane_right"

// The air beside the nose and fuselage: a frame with nothing drawn, which
// still takes clicks so the plane can be taken apart.
/obj/structure/vehicleparts/frame/car/aircraft/twin_open
	name = "airframe bracing"
	desc = "Bracing under the open air beside the plane's nose or fuselage."
	hull_state = "twin_open"
	noroof = TRUE
	mouse_opacity = 2

// The piece of a 5-wide airframe for row (1 = nose) of rows and column (1 =
// the plane's left); cockpit marks the pilot's tile. Past 4 long the fuselage
// row repeats between the wing row and the tail, as in the airliner.
/proc/aircraft_twin_section_type(row, col, cockpit, rows = 4)
	var/list/pieces = list(
		list(/obj/structure/vehicleparts/frame/car/aircraft/twin_open, /obj/structure/vehicleparts/frame/car/aircraft/twin_engine/left, /obj/structure/vehicleparts/frame/car/aircraft/nose/center/twin, /obj/structure/vehicleparts/frame/car/aircraft/twin_engine/right, /obj/structure/vehicleparts/frame/car/aircraft/twin_open),
		list(/obj/structure/vehicleparts/frame/car/aircraft/wing/twin_tip/left, /obj/structure/vehicleparts/frame/car/aircraft/twin_nacelle/left, /obj/structure/vehicleparts/frame/car/aircraft/cockpit, /obj/structure/vehicleparts/frame/car/aircraft/twin_nacelle/right, /obj/structure/vehicleparts/frame/car/aircraft/wing/twin_tip/right),
		list(/obj/structure/vehicleparts/frame/car/aircraft/twin_open, /obj/structure/vehicleparts/frame/car/aircraft/fuselage/left, /obj/structure/vehicleparts/frame/car/aircraft/fuselage/center, /obj/structure/vehicleparts/frame/car/aircraft/fuselage/right, /obj/structure/vehicleparts/frame/car/aircraft/twin_open),
		list(/obj/structure/vehicleparts/frame/car/aircraft/twin_tailplane/left, /obj/structure/vehicleparts/frame/car/aircraft/twin_tail/left, /obj/structure/vehicleparts/frame/car/aircraft/tail/center, /obj/structure/vehicleparts/frame/car/aircraft/twin_tail/right, /obj/structure/vehicleparts/frame/car/aircraft/twin_tailplane/right),
		)
	if (row < 1 || row > rows || col < 1 || col > 5)
		return null
	if (row == rows)
		row = 4
	else if (row > 2)
		row = 3
	if (row == 2 && col == 3 && !cockpit)
		return /obj/structure/vehicleparts/frame/car/aircraft/fuselage/center
	var/list/R = pieces[row]
	return R[col]

// ---- The engines ----

// Engines aboard besides the one the pilot starts.
/obj/structure/vehicleparts/axis/aircraft/proc/wing_engines()
	. = list()
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (F.axis != src)
			continue
		for (var/obj/structure/engine/internal/E in get_turf(F))
			if (E != engine && E.key_axis == src)
				. += E

// The wing engines run with the pilot's engine while they have fuel.
/obj/structure/vehicleparts/axis/aircraft/proc/sync_wing_engines()
	var/run = engine && engine.on
	for (var/obj/structure/engine/internal/E in wing_engines())
		var/fuelled = E.fueltank && E.fueltank.reagents && E.fueltank.reagents.total_volume > 0
		var/want = run && fuelled && !E.broken
		if (E.on == want)
			continue
		E.on = want
		E.update_icon()
		if (want)
			E.start_running()

// With engines running on the wings they share the load.
/obj/structure/vehicleparts/axis/aircraft/check_engine()
	sync_wing_engines()
	var/power = 0
	for (var/obj/structure/engine/internal/E in wing_engines())
		if (E.on)
			power += E.maxpower * 2
	if (!power || !engine || !engine.fueltank)
		return ..()
	power += engine.maxpower * 2
	var/weight = get_weight()
	if (weight > power || weight > maxpower)
		visible_message(SPAN_WARNING("\The [engine] struggles and stalls!"))
		return FALSE
	if (engine.fueltank.reagents && engine.fueltank.reagents.total_volume <= 0)
		engine.fueltank.reagents.total_volume = 0
		engine.on = FALSE
		sync_wing_engines()
		return FALSE
	return engine.on

// Each engine aboard takes the tank standing with it, or any tank left over.
/obj/structure/vehicleparts/axis/aircraft/proc/link_fuel_tanks()
	var/list/engines = list()
	var/list/tanks = list()
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (F.axis != src)
			continue
		for (var/obj/structure/engine/internal/E in get_turf(F))
			engines += E
		for (var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/K in get_turf(F))
			tanks += K
	for (var/obj/structure/engine/internal/E in engines)
		if (E.fueltank)
			tanks -= E.fueltank
	for (var/obj/structure/engine/internal/E in engines)
		if (E.fueltank)
			continue
		var/turf/here = get_turf(E)
		var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/K = null
		for (var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/T in tanks)
			if (get_turf(T) == here)
				K = T
				break
		if (!K && tanks.len)
			K = tanks[1]
		if (!K)
			continue
		tanks -= K
		E.fueltank = K
		K.anchored = TRUE
		K.icon_state = "fueltank_incar"

// ---- The hangar model ----

/obj/structure/vehicleparts/axis/aircraft/twin_plane
	name = "twin-engine plane"
	desc = "The controls of a twin-engine plane."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	maxpower = 1400
	takeoff_roll = 12
	rough_takeoff_roll = 24

// Built facing south like every hangar plane, so "1,1" is the plane's right.
var/global/list/aircraft_twin_plane_layout = aircraft_twin_plane_layout_table()
/proc/aircraft_twin_plane_layout_table()
	return list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_open, /obj/structure/vehicleparts/movement),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_engine/right, /obj/structure/engine/internal/gasoline/premade/v6/aircraft, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline),
	"3,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/nose/center/twin),
	"4,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_engine/left, /obj/structure/engine/internal/gasoline/premade/v6/aircraft, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline),
	"5,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_open, /obj/structure/vehicleparts/movement),
	"1,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/wing/twin_tip/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_nacelle/right),
	"3,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/cockpit, /obj/structure/bed/chair/drivers/aircraft),
	"4,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_nacelle/left),
	"5,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/wing/twin_tip/left),
	"1,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_open),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/fuselage/right, /obj/structure/bed/chair/carseat/aircraft_cabin),
	"3,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/fuselage/center, /obj/structure/bed/chair/carseat/aircraft_cabin),
	"4,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/fuselage/left, /obj/structure/bed/chair/carseat/aircraft_cabin),
	"5,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_open),
	"1,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_tailplane/right, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_tail/right),
	"3,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/tail/center),
	"4,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_tail/left),
	"5,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/twin_tailplane/left, /obj/structure/vehicleparts/movement/reversed),
	)
