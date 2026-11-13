// Huey cases, run by probe.dm before the plane cases. They use the
// fixture's east strip (x 11-20), give it open air for the flight and put the
// plain turfs back afterwards, so the plane cases find the fixture as before.

/proc/huey_frames_z(obj/structure/vehicleparts/axis/aircraft/A, z)
	return aircraft_frames_z(A, z)

/proc/huey_rotor_state(obj/structure/vehicleparts/frame/car/aircraft/F)
	. = ""
	for (var/O in F.overlays)
		var/image/I = O
		if (I.icon == 'icons/obj/vehicles/huey_rotor.dmi')
			return I.icon_state

/proc/huey_lift(obj/structure/vehicleparts/axis/aircraft/helicopter/A, mob/M)
	A.engine.on = TRUE
	A.moving = FALSE
	A.currentspeed = 0
	if (!A.climb(M))
		return FALSE
	return A.finish_spool()

// Hover ticks until the helicopter is within landing clearance of the ground.
/proc/huey_sink(obj/structure/vehicleparts/axis/aircraft/helicopter/A, mob/M)
	A.descend(M)
	for (var/i = 1, i <= 6 && A.clearance() > AIRCRAFT_LANDING_CLEARANCE, i++)
		A.flight_watch_tick()
	return A.clearance() <= AIRCRAFT_LANDING_CLEARANCE

/proc/huey_checks()
	for (var/x = 11, x <= 20, x++)
		for (var/y = 1, y <= 60, y++)
			new /turf/sky/building(locate(x, y, 2))

	// Build: 21 sections in a 7x7 turning square.
	var/obj/structure/vehicleparts/axis/aircraft/helicopter/A = build_huey(locate(12, 40, 1))
	aircraft_check(istype(A) && A.frames().len == 21 && A.components.len == 49, "the Huey builds twenty-one frames in a 7x7 turning square")
	if (!istype(A))
		return
	aircraft_check(A.wheels.len == 4 && A.engine && A.engine.fueltank && istype(A.engine, /obj/structure/engine/internal/diesel/premade/v6/turboshaft), "four skids, a turboshaft engine and a tank are connected")
	aircraft_check(istype(A.wheel, /obj/item/vehicleparts/wheel/modular/aircraft/helicopter) && A.wheel.control && A.wheel.control.axis == A, "the pilot holds a cyclic that flies this helicopter")
	var/seats = 0
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		for (var/obj/structure/bed/chair/seat in F.loc)
			seats++
	aircraft_check(seats == 7, "a pilot's seat, a co-pilot's seat and five cabin seats ([seats] seats)")

	// Art: every section draws its piece of the Huey; the tail is roofless.
	var/art_ok = TRUE
	var/open_sections = 0
	for (var/obj/structure/vehicleparts/frame/car/aircraft/F in A.components)
		if (F.icon != 'icons/obj/vehicles/huey_airframe.dmi' || !findtext(F.hull_state, "huey_"))
			art_ok = FALSE
		if (F.noroof)
			open_sections++
			if (F.icon_state != F.hull_state)
				art_ok = FALSE
		else if (F.icon_state != "[F.hull_state]_floor" || F.roof.icon_state != F.hull_state)
			art_ok = FALSE
	aircraft_check(art_ok && open_sections == 9, "every section draws its own piece of the Huey and the tail rows are roofless")
	var/obj/structure/vehicleparts/frame/car/aircraft/huey/aft/mast/mast = locate() in A.components
	aircraft_check(mast && mast.engine_section && (A.engine in mast.loc), "the engine sits under the rotor mast, an engine section")
	var/obj/structure/vehicleparts/frame/car/aircraft/huey/nose/center/nose = locate() in A.components
	aircraft_check(nose && !nose.engine_section, "a hit on the Huey's nose does not reach the engine")
	aircraft_check(huey_rotor_state(mast) == "rotor", "the rotor stands still while the engine is off")

	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	var/mob/living/aircraft_probe/M = new(locate(17, 42, 1))

	// Climb with the engine off says what is missing.
	aircraft_check(!A.climb(M) && !A.spooling && !A.airborne(), "Climb with the engine off is refused")

	// Skids: the throttle does not taxi it.
	E.on = TRUE
	E.update_icon()
	aircraft_check(huey_rotor_state(mast) == "rotor_spin", "the rotor turns while the engine runs")
	var/y_before = aircraft_front_y(A)
	A.moving = TRUE
	A.currentspeed = 2
	aircraft_check(!A.do_vehicle_check() && !A.moving && A.currentspeed == 0 && aircraft_front_y(A) == y_before, "on its skids the helicopter can't taxi")

	// Vertical takeoff: Climb spools up, then the whole airframe lifts straight up.
	aircraft_check(A.climb(M) && A.spooling && !A.airborne(), "Climb with the engine running spools the rotor up first")
	aircraft_check(!A.climb(M), "a second Climb while spooling is refused")
	aircraft_check(A.finish_spool() && A.airborne() && A.flight_state == AIRCRAFT_LOW && !A.spooling, "once spooled up it lifts off without a takeoff roll")
	aircraft_check(huey_frames_z(A, 2) && E.z == 2 && M.z == 2 && aircraft_front_y(A) == y_before, "the airframe, its engine and the passenger rise straight up to the level above")
	aircraft_check(A.altitude == 2 && A.target_altitude == 6, "the skids leave the ground two levels up, climbing on toward six")

	// Hover: stopped is not stalled, and the height still follows the target.
	A.moving = FALSE
	A.currentspeed = 0
	A.flight_watch_tick()
	aircraft_check(A.airborne() && A.stall_seconds == 0 && A.altitude == 4, "hovering is no stall, and it keeps climbing toward the target")
	A.flight_watch_tick()
	A.edge_blocked = TRUE
	for (var/i = 1, i <= 4, i++)
		A.flight_watch_tick()
	aircraft_check(A.airborne() && A.stall_seconds == 0 && A.altitude == 6, "holding at the edge of the world or hovering for seconds never stalls it")
	A.edge_blocked = FALSE

	// It pivots on the spot while hovering.
	var/obj/item/vehicleparts/wheel/modular/aircraft/helicopter/cyclic = A.wheel
	cyclic.lastdirchange = -1
	var/old_dir = A.dir
	aircraft_check(cyclic.turndir(null, "left") && A.dir != old_dir && !A.moving && A.currentspeed == 0 && huey_frames_z(A, 2), "a hovering helicopter turns on the spot and keeps hovering")

	// The secondary action at a standstill does not cut the engine in the air.
	cyclic.secondary_attack_self(M)
	aircraft_check(E.on && A.airborne(), "a hovering pilot can't switch the engine off")

	// Landing: too fast is refused, then it settles on plain ground, no runway.
	aircraft_check(huey_sink(A, M), "Descend brings the hovering helicopter down near the ground")
	A.moving = TRUE
	A.currentspeed = 4
	aircraft_check(!A.descend(M) && A.airborne(), "setting down too fast is refused")
	A.moving = FALSE
	A.currentspeed = 0
	aircraft_check(A.descend(M) && !A.airborne() && huey_frames_z(A, 1) && M.z == 1 && A.airframe_damage == 0 && !A.landing_gear_broken(), "at a hover it sets down gently on plain ground with the passenger")
	aircraft_check(!(A in airborne_aircraft), "it leaves the airborne list on landing")

	// Water under the skids: no landing there. (Just off the ground, Descend lands at once.)
	aircraft_check(huey_lift(A, M) && A.airborne() && A.clearance() <= AIRCRAFT_LANDING_CLEARANCE, "it lifts off again from where it landed")
	var/turf/wet = locate(mast.x, mast.y, 1)
	new /turf/floor/beach/water(wet)
	aircraft_check(!A.descend(M) && A.airborne(), "over water it won't set down")
	new /turf(wet)

	// Engine out with forward speed: an autorotation and a hard landing.
	A.target_altitude = A.altitude
	E.on = FALSE
	A.moving = TRUE
	A.currentspeed = 2
	for (var/i = 1, i <= 8 && A.airborne(), i++)
		A.flight_watch_tick()
	aircraft_check(!A.airborne() && huey_frames_z(A, 1) && !QDELETED(A) && A.airframe_damage == 25 && !A.landing_gear_broken(), "an engine failure with forward speed autorotates down to a hard landing")

	// Engine out at a hover: a crash that breaks the skids.
	A.airframe_damage = 0
	aircraft_check(huey_lift(A, M) && A.airborne(), "it lifts off once more")
	for (var/i = 1, i <= 4 && A.airborne(), i++)
		A.flight_watch_tick()
	E.on = FALSE
	A.moving = FALSE
	A.currentspeed = 0
	var/ticks = 0
	for (var/i = 1, i <= 8 && A.airborne(), i++)
		A.flight_watch_tick()
		ticks++
	aircraft_check(!A.airborne() && huey_frames_z(A, 1) && A.landing_gear_broken() && !E.on && ticks > 1, "an engine failure at a hover sinks for [ticks] seconds and crashes, breaking the skids")
	E.on = TRUE
	aircraft_check(!A.climb(M) && !A.spooling, "bent skids keep it on the ground until they are welded")

	// Leave the fixture as the plane cases expect it: the airframe, its seats,
	// skids, engine, tank and the passenger gone, and plain turfs again.
	var/list/leftovers = list(A) | A.components
	for (var/z = 1, z <= 2, z++)
		for (var/turf/T in block(locate(11, 30, z), locate(20, 56, z)))
			for (var/atom/movable/AM in T)
				leftovers |= AM
	for (var/atom/movable/AM in leftovers)
		AM.loc = null
		qdel(AM)
	for (var/x = 11, x <= 20, x++)
		for (var/y = 1, y <= 60, y++)
			new /turf(locate(x, y, 2))
	aircraft_check(!airborne_aircraft.len, "no helicopter is left airborne for the plane cases")
