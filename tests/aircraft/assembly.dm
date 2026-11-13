// Hand-built aircraft (aircraft_assembly.dm): airframe sections laid out by
// hand and assembled from airframe controls, like a car or a boat. Runs on a
// clean patch before the flight cases and removes everything it builds.

/proc/aircraft_lay_sections(x1, y1, x2, y2)
	for (var/x = x1, x <= x2, x++)
		for (var/y = y1, y <= y2, y++)
			new /obj/structure/vehicleparts/frame/car/aircraft/section(locate(x, y, 1))

/proc/aircraft_frame_type_at(x, y)
	var/obj/structure/vehicleparts/frame/F = locate(/obj/structure/vehicleparts/frame) in locate(x, y, 1)
	return F ? F.type : null

/proc/aircraft_clear_patch(x1, y1, x2, y2, z = 1)
	for (var/turf/T in block(locate(x1, y1, z), locate(x2, y2, z)))
		for (var/atom/movable/M in T)
			if (!istype(M, /atom/movable/lighting_overlay))
				if (istype(M, /obj/structure/vehicleparts/frame))
					var/obj/structure/vehicleparts/frame/F = M
					F.broken = TRUE
				qdel(M)

// Clears what stands on z1 in the box, keeping roads and runway covers.
/proc/aircraft_clear_ground(x1, y1, x2, y2)
	for (var/turf/T in block(locate(x1, y1, 1), locate(x2, y2, 1)))
		for (var/obj/O in T)
			if (istype(O, /obj/covers))
				continue
			if (istype(O, /obj/structure/vehicleparts/frame))
				var/obj/structure/vehicleparts/frame/F = O
				F.broken = TRUE
			qdel(O)

/proc/aircraft_assembly_checks()
	// A 3-wide, 4-long airframe at x 12-14, y 10-13; its front will be south.
	aircraft_lay_sections(12, 10, 14, 13)
	new /obj/structure/engine/internal/gasoline/premade/v6/aircraft(locate(13, 10, 1))
	new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline(locate(13, 10, 1))
	for (var/list/C in list(list(12, 10), list(14, 10), list(12, 13), list(14, 13)))
		new /obj/structure/vehicleparts/movement(locate(C[1], C[2], 1))
	new /obj/structure/bed/chair/carseat(locate(13, 12, 1))

	// A car's axis does not take airframe sections, nor a car seat fly a plane.
	var/obj/structure/vehicleparts/axis/car/car_axis = new(locate(13, 12, 1))
	var/datum/vehicle_survey/S = new(car_axis)
	aircraft_check(S.refusal && findtext(S.refusal, "must stand on one of the vehicle's frames"), "a car axis does not take airframe sections ([S.refusal])")
	qdel(car_axis)
	var/obj/structure/bed/chair/drivers/car_seat = new(locate(13, 11, 1))
	var/obj/structure/vehicleparts/axis/aircraft/airframe/A = new(locate(13, 12, 1))
	S = new(A)
	aircraft_check(!S.refusal && S.frames.len == 12 && ("a pilot's seat" in S.missing()), "the airframe surveys twelve sections and asks for a pilot's seat, not a driver's ([S.refusal] / [english_list(S.missing())])")
	qdel(car_seat)
	new /obj/structure/bed/chair/drivers/aircraft/loose(locate(13, 11, 1))
	S = new(A)
	aircraft_check(!S.refusal && !S.missing().len && S.movers.len == 4, "with a pilot's seat it has everything a plane needs ([english_list(S.missing())])")

	// Assembled facing south: every section takes its place's shape.
	aircraft_check(isnull(A.assemble(SOUTH)) && A.hand_built && A.frames().len == 12 && A.wheels.len == 4, "the airframe controls assemble a hand-built plane")
	aircraft_check(aircraft_frame_type_at(13, 10) == /obj/structure/vehicleparts/frame/car/aircraft/nose/center && aircraft_frame_type_at(14, 10) == /obj/structure/vehicleparts/frame/car/aircraft/nose/left && aircraft_frame_type_at(12, 10) == /obj/structure/vehicleparts/frame/car/aircraft/nose/right, "the front row becomes the nose, left and right as the plane sees them")
	aircraft_check(aircraft_frame_type_at(13, 11) == /obj/structure/vehicleparts/frame/car/aircraft/cockpit && aircraft_frame_type_at(14, 11) == /obj/structure/vehicleparts/frame/car/aircraft/wing/left && aircraft_frame_type_at(12, 11) == /obj/structure/vehicleparts/frame/car/aircraft/wing/right, "the second row becomes the wings, with the cockpit under the pilot")
	aircraft_check(aircraft_frame_type_at(13, 12) == /obj/structure/vehicleparts/frame/car/aircraft/fuselage/center && aircraft_frame_type_at(13, 13) == /obj/structure/vehicleparts/frame/car/aircraft/tail/center, "the rows behind become fuselage and tail")
	aircraft_check(!(locate(/obj/structure/vehicleparts/frame/car/aircraft/section) in block(locate(12, 10, 1), locate(14, 13, 1))), "no plain section is left in the airframe")
	aircraft_check(istype(A.wheel, /obj/item/vehicleparts/wheel/modular/aircraft) && A.wheel.control && A.wheel.control.axis == A, "the pilot's seat holds a control column that flies this plane")
	aircraft_check(A.engine && A.engine.fueltank && A.engine.engineclass == "carengine" && A.engine.key_axis == A && A.takeoff_roll == 8 && A.rough_takeoff_roll == 16, "the engine and tank are fitted inside the airframe and it rolls like a light plane")
	var/obj/structure/vehicleparts/frame/nose = locate(/obj/structure/vehicleparts/frame/car/aircraft/nose/center) in locate(13, 10, 1)
	A.engine.on = TRUE
	A.engine.update_icon()
	var/spinning = FALSE
	for (var/O in nose.overlays)
		var/image/I = O
		if (I.icon_state == "prop_spin")
			spinning = TRUE
	aircraft_check(spinning, "the propeller turns on the nose while the engine runs")

	// It taxis and steers like the hangar's planes.
	A.moving = TRUE
	A.currentspeed = 1
	aircraft_check(aircraft_step(A) && aircraft_taxi_turn(A, "left") && A.dir == EAST, "the hand-built plane taxis and steers")
	A.moving = FALSE
	A.currentspeed = 0
	A.engine.on = FALSE

	// Taken apart, the shaped pieces assemble again facing another way.
	aircraft_check(isnull(A.take_apart_refusal(null)), "its builder may take it apart ([A.take_apart_refusal(null)])")
	A.take_apart()
	A.name = initial(A.name)
	S = new(A)
	aircraft_check(!S.refusal && S.frames.len == 12 && !S.missing().len, "the loose pieces survey as an airframe again")
	// It was left facing east, so it lies 4 across and 3 down: north would
	// put 4 sections in the wing row, west turns it round.
	aircraft_check(A.assemble(NORTH) && !A.components.len, "reassembling with the nose across the long side is refused")
	aircraft_check(isnull(A.assemble(WEST)) && A.dir == WEST, "and reassembles facing west")
	var/front_x = 1000
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		front_x = min(front_x, F.x)
	var/obj/structure/vehicleparts/frame/new_nose = null
	for (var/obj/structure/vehicleparts/frame/car/aircraft/nose/center/N in A.frames())
		new_nose = N
	aircraft_check(new_nose && new_nose.x == front_x, "the nose is now the west row")
	for (var/atom/movable/part in A.components.Copy())
		if (part != A)
			qdel(part)
	qdel(A)
	aircraft_clear_patch(11, 7, 20, 16)

	// Too narrow for wings, and a bigger airframe with a longer roll.
	aircraft_lay_sections(12, 10, 13, 13)
	var/obj/structure/vehicleparts/axis/aircraft/airframe/narrow = new(locate(12, 10, 1))
	S = new(narrow)
	aircraft_check(S.refusal && findtext(S.refusal, "3 sections wide"), "a 2-wide airframe is refused ([S.refusal])")
	qdel(narrow)
	aircraft_clear_patch(11, 7, 20, 16)
	aircraft_lay_sections(12, 10, 15, 13)
	var/obj/structure/vehicleparts/axis/aircraft/airframe/wide = new(locate(12, 10, 1))
	S = new(wide)
	aircraft_check(S.refusal && findtext(S.refusal, "3 sections wide"), "a 4 by 4 airframe is refused: the wings are drawn for a 3-section span ([S.refusal])")
	qdel(wide)
	aircraft_clear_patch(11, 7, 20, 16)
	// A 3-wide, 5-long transport: a second fuselage row and a longer roll.
	aircraft_lay_sections(12, 10, 14, 14)
	new /obj/structure/engine/internal/gasoline/premade/v6/aircraft(locate(13, 14, 1))
	new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline(locate(13, 14, 1))
	new /obj/structure/bed/chair/drivers/aircraft/loose(locate(13, 13, 1))
	for (var/list/C in list(list(12, 10), list(14, 10), list(12, 14), list(14, 14)))
		new /obj/structure/vehicleparts/movement(locate(C[1], C[2], 1))
	var/obj/structure/vehicleparts/axis/aircraft/airframe/big = new(locate(13, 12, 1))
	var/why = big.assemble(EAST)
	aircraft_check(why && findtext(why, "long side") && !big.components.len, "pointing the nose across the long side is refused ([why])")
	aircraft_check(isnull(big.assemble(NORTH)) && big.frames().len == 15, "a 3-wide, 5-long airframe assembles facing north")
	var/wings = 0
	var/fuselage = 0
	for (var/obj/structure/vehicleparts/frame/car/aircraft/wing/W in big.frames())
		wings++
	for (var/obj/structure/vehicleparts/frame/car/aircraft/fuselage/F in big.frames())
		fuselage++
	aircraft_check(wings == 2 && fuselage == 6 && big.takeoff_roll == 9 && big.rough_takeoff_roll == 18, "it has two wings, two fuselage rows and a longer takeoff roll ([wings] wings, [fuselage] fuselage, roll [big.takeoff_roll]/[big.rough_takeoff_roll])")
	for (var/atom/movable/part in big.components.Copy())
		if (part != big)
			qdel(part)
	qdel(big)
	aircraft_clear_patch(11, 7, 20, 16)
