// Modular aircraft, phase 1: the runway, the airframe, the pilot's controls and
// an admin-spawned light plane.

/obj/covers/roads/modern/runway
	name = "runway"
	desc = "A long, flat strip of tarmac that aircraft take off from and land on."

/obj/structure/vehicleparts/frame/car/aircraft
	name = "aircraft frame"
	desc = "A light metal airframe section."

/obj/structure/vehicleparts/frame/car/aircraft/nose/right
	w_front = list("c_armoredfront",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/aircraft/nose/center
	w_front = list("c_armoredfront",FALSE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/aircraft/nose/left
	w_front = list("c_armoredfront",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

/obj/structure/vehicleparts/frame/car/aircraft/wing
	name = "aircraft wing"
	desc = "A light metal wing."
	noroof = TRUE
/obj/structure/vehicleparts/frame/car/aircraft/cockpit
	name = "cockpit"

/obj/structure/vehicleparts/frame/car/aircraft/fuselage/right
	w_right = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)
/obj/structure/vehicleparts/frame/car/aircraft/fuselage/center
/obj/structure/vehicleparts/frame/car/aircraft/fuselage/left
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

/obj/structure/vehicleparts/frame/car/aircraft/tail/right
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/aircraft/tail/center
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/aircraft/tail/left
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

/obj/structure/bed/chair/drivers/aircraft
	name = "pilot's seat"
	desc = "Where you fly the aircraft from."
	icon_state = "carseat_driver_left"
	anchored = TRUE

/obj/structure/bed/chair/drivers/aircraft/New()
	..()
	if (wheel)
		qdel(wheel)
	wheel = new /obj/item/vehicleparts/wheel/modular/aircraft(src)
	wheel.drivingchair = src

// Throttle and steering work like a car's wheel; Climb and Descend change height.
/obj/item/vehicleparts/wheel/modular/aircraft
	name = "control column"
	desc = "Use it to throttle up, right-click it to throttle down, steer with the arrow keys. Climb and Descend change height: take off by rolling along a runway at full throttle, and land by descending over one at low speed."

/obj/item/vehicleparts/wheel/modular/aircraft/proc/flown_aircraft(mob/user)
	var/obj/structure/vehicleparts/axis/aircraft/A = control && control.axis
	if (!istype(A) || loc != user)
		return null
	if (!A.key_access(user))
		to_chat(user, SPAN_WARNING("A matching vehicle key is required."))
		return null
	return A

/obj/item/vehicleparts/wheel/modular/aircraft/verb/climb_verb()
	set name = "Climb"
	set category = null
	set src in usr
	var/obj/structure/vehicleparts/axis/aircraft/A = flown_aircraft(usr)
	if (A)
		A.climb(usr)

/obj/item/vehicleparts/wheel/modular/aircraft/verb/descend_verb()
	set name = "Descend"
	set category = null
	set src in usr
	var/obj/structure/vehicleparts/axis/aircraft/A = flown_aircraft(usr)
	if (A)
		A.descend(usr)

/obj/item/vehicleparts/wheel/modular/aircraft/examine(mob/user, distance)
	. = ..()
	var/obj/structure/vehicleparts/axis/aircraft/A = control && control.axis
	if (istype(A))
		switch (A.flight_state)
			if (AIRCRAFT_GROUND)
				to_chat(user, "The aircraft is on the ground.")
			if (AIRCRAFT_LOW)
				to_chat(user, "The aircraft is in low flight.")
			if (AIRCRAFT_CRUISE)
				to_chat(user, "The aircraft is at cruising height.")

/obj/structure/vehicleparts/axis/aircraft/light_plane
	name = "light plane"
	desc = "The controls of a single-engine light plane."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"

// A 3-wide, 4-long light plane, built facing south from the bottom-left of a
// 4x4 square. Row 1 is the nose.
var/global/list/aircraft_light_plane_layout = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/nose/right, /obj/structure/vehicleparts/movement),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/nose/center, /obj/structure/engine/internal/gasoline/premade/v6, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline),
	"3,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/nose/left, /obj/structure/vehicleparts/movement),
	"1,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/wing),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/cockpit, /obj/structure/bed/chair/drivers/aircraft),
	"3,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/wing),
	"1,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/fuselage/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/fuselage/center, /obj/structure/bed/chair/carseat),
	"3,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/fuselage/left),
	"1,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/tail/right, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/tail/center),
	"3,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/tail/left, /obj/structure/vehicleparts/movement/reversed),
	)

// Builds an aircraft in one call. origin is the bottom-left turf of the
// size x size turning square; the body sits against its east edge, so the
// front-left corner (south-east) anchors the turning matrix like a car's.
/proc/build_aircraft(turf/origin, axis_type, list/layout, width, size)
	if (!origin || !axis_type || !layout)
		return null
	var/obj/structure/vehicleparts/axis/aircraft/A = new axis_type()
	A.dir = SOUTH
	A.new_number()
	var/list/parts = list()
	var/obj/structure/bed/chair/drivers/D
	for (var/coords in layout)
		var/list/C = splittext(coords, ",")
		var/turf/T = locate(origin.x + size - width + text2num(C[1]) - 1, origin.y + text2num(C[2]) - 1, origin.z)
		if (!T)
			for (var/obj/O in parts)
				qdel(O)
			qdel(A)
			return null
		for (var/partpath in layout[coords])
			var/obj/O = new partpath(T)
			parts += O
			O.dir = SOUTH
			O.anchored = TRUE
			if (istype(O, /obj/structure/vehicleparts/frame))
				var/obj/structure/vehicleparts/frame/F = O
				F.axis = A
				A.components += F
			if (istype(O, /obj/structure/engine/internal))
				A.engine = O
				A.engine.key_axis = A
				A.engine.engineclass = "carengine"
				A.engine.icon = 'icons/obj/vehicles/vehicleparts.dmi'
			if (istype(O, /obj/structure/bed/chair/drivers))
				D = O
	A.check_corners()
	A.loc = A.corners[2]
	D.axis = A
	A.wheel = D.wheel
	A.wheel.control = locate(/obj/structure/vehicleparts/frame) in D.loc
	for (var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/F in parts)
		A.engine.fueltank = F
		F.icon_state = "fueltank_incar"
	for (var/obj/structure/vehicleparts/movement/W in parts)
		var/obj/structure/vehicleparts/frame/F = locate() in W.loc
		W.MouseDrop(F)
	for (var/dx = 0, dx < size, dx++)
		for (var/dy = 0, dy < size, dy++)
			var/turf/T = locate(origin.x + dx, origin.y + dy, origin.z)
			if (T && !(locate(/obj/structure/vehicleparts/frame) in T))
				var/obj/effect/pseudovehicle/P = new(T)
				P.link = A
				P.dir = SOUTH
				A.components += P
	A.check_matrix()
	for (var/obj/O in parts)
		O.update_icon()
	return A

/proc/build_light_plane(turf/origin)
	return build_aircraft(origin, /obj/structure/vehicleparts/axis/aircraft/light_plane, aircraft_light_plane_layout, 3, 4)

// Admin spawn: builds the light plane facing south, with this tile as the
// bottom-left of its 4x4 footprint.
/obj/effect/aircraft_spawner/light_plane
	name = "light plane spawner"
	icon = 'icons/obj/vehicles/vehicleeffects.dmi'
	icon_state = "4x4"
	invisibility = 101

/obj/effect/aircraft_spawner/light_plane/New(loc)
	..()
	addtimer(CALLBACK(src, PROC_REF(build)), 1)

/obj/effect/aircraft_spawner/light_plane/proc/build()
	build_light_plane(get_turf(src))
	qdel(src)

// Admin spawn for testing flight: a 3-wide runway running 16 tiles south from
// this tile's row, with the light plane parked at its north end, facing down it.
/obj/effect/aircraft_spawner/airstrip
	name = "airstrip spawner"
	icon = 'icons/obj/vehicles/vehicleeffects.dmi'
	icon_state = "4x4"
	invisibility = 101

/obj/effect/aircraft_spawner/airstrip/New(loc)
	..()
	addtimer(CALLBACK(src, PROC_REF(build)), 1)

/obj/effect/aircraft_spawner/airstrip/proc/build()
	build_airstrip(get_turf(src))
	qdel(src)

/proc/build_airstrip(turf/origin)
	if (!origin)
		return null
	for (var/dy = -12, dy <= 3, dy++)
		for (var/dx = 1, dx <= 3, dx++)
			var/turf/T = locate(origin.x + dx, origin.y + dy, origin.z)
			if (T && !(locate(/obj/covers/roads/modern/runway) in T))
				new /obj/covers/roads/modern/runway(T)
	return build_light_plane(origin)

