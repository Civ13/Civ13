// Aircraft crashing into buildings (aircraft_impact.dm): runs on the cleared
// crash patch (x 2-12, y 36-56) after aircraft_checks() and removes what it builds.

/proc/aircraft_impact_plane(turf/origin)
	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(origin)
	if (!istype(A))
		return null
	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	E.on = TRUE
	A.set_flight_state(AIRCRAFT_LOW)
	A.moving = TRUE
	A.currentspeed = A.speeds
	return A

// The tiles straight ahead of A's frames on level z.
/proc/aircraft_impact_lanes(obj/structure/vehicleparts/axis/aircraft/A, z)
	. = list()
	var/m_dir = A.reverse ? OPPOSITE_DIR(A.dir) : A.dir
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		var/turf/T = get_step(F.loc, m_dir)
		if (T)
			T = locate(T.x, T.y, z)
		if (T && !(T in .))
			. += T

/proc/aircraft_building_impact_checks()
	// A light plane at full speed flies into a row of wooden walls.
	var/obj/structure/vehicleparts/axis/aircraft/A = aircraft_impact_plane(locate(3, 36, 2))
	if (!A)
		aircraft_check(FALSE, "the impact probe's light plane builds")
		return
	var/list/wood = list()
	var/list/wood_turfs = list()
	for (var/turf/T in aircraft_impact_lanes(A, 2))
		if (!(locate(/obj/structure/vehicleparts/frame) in T))
			wood += new /obj/covers/wood_wall(T)
			wood_turfs += T
	aircraft_check(wood.len && aircraft_building_at(wood[1].loc), "a wooden wall ahead is a building to fly into")
	var/force = A.impact_force()
	aircraft_check(force > 0, "the plane's blow comes from its frames, load and speed ([force])")
	aircraft_check(!A.do_vehicle_check(), "flying into the walls stops the flight")
	aircraft_check(QDELETED(A), "the plane breaks up where it hit")
	var/broken = 0
	var/burning = FALSE
	for (var/obj/covers/C in wood)
		if (QDELETED(C))
			broken++
	for (var/turf/T in wood_turfs)
		if (locate(/obj/effect/fire) in T)
			burning = TRUE
	aircraft_check(broken == wood.len, "a light plane at full speed breaks through wooden walls ([broken] of [wood.len])")
	aircraft_check(burning, "its fuel sets the wood alight")
	for (var/obj/effect/fire/FI in world)
		if (FI.z == 2)
			qdel(FI)

	// Stone takes the blow and mostly holds.
	var/obj/structure/vehicleparts/axis/aircraft/B = aircraft_impact_plane(locate(3, 48, 2))
	var/list/stone = list()
	for (var/turf/T in aircraft_impact_lanes(B, 2))
		if (!(locate(/obj/structure/vehicleparts/frame) in T))
			stone += new /obj/covers/stone_wall(T)
	B.do_vehicle_check()
	var/standing = 0
	var/damaged = 0
	for (var/obj/covers/C in stone)
		if (!QDELETED(C))
			standing++
			if (C.health < C.maxhealth)
				damaged++
	aircraft_check(QDELETED(B) && standing == stone.len && damaged == stone.len, "stone walls are damaged but stand ([standing] standing, [damaged] damaged)")
	for (var/obj/covers/C in stone)
		qdel(C)

	// Breaking up over a thatched house brings the roof in.
	var/obj/structure/vehicleparts/axis/aircraft/W = aircraft_impact_plane(locate(7, 36, 2))
	var/list/roofs = list()
	for (var/obj/structure/vehicleparts/frame/F in W.frames())
		roofs += new /obj/roof/thatch(locate(F.x, F.y, 1))
	W.currentspeed = 0
	W.wreck("the probe")
	var/caved = 0
	for (var/obj/roof/R in roofs)
		if (QDELETED(R))
			caved++
	aircraft_check(QDELETED(W) && caved == roofs.len, "a plane breaking up over a thatch roof caves it in ([caved] of [roofs.len])")
	for (var/obj/O in world)
		if (O.y >= 36 && O.y <= 56 && O.x <= 12 && (istype(O, /obj/structure/rubble) || istype(O, /obj/structure/barricade/debris) || istype(O, /obj/covers)))
			qdel(O)
