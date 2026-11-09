// Modular aircraft phase 1: runway takeoff, flight on the level above,
// cruise, landing, crashes, stalls and passengers over open air.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 60
	maxz = 2
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/aircraft_probe/New()
	return
/mob/living/aircraft_probe/New()
	return
/obj/structure/aircraft_probe_wall
	name = "probe wall"
	density = TRUE
	anchored = TRUE
var/aircraft_failures = 0
var/aircraft_runtime_error = FALSE
/proc/aircraft_check(condition, label)
	if (!condition)
		aircraft_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	aircraft_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/aircraft_frames_z(obj/structure/vehicleparts/axis/aircraft/A, z)
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		if (F.z != z)
			return FALSE
	return TRUE

/proc/aircraft_front_y(obj/structure/vehicleparts/axis/aircraft/A)
	. = 1000
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		. = min(., F.y)

// One movement step the way movementloop() takes it.
/proc/aircraft_step(obj/structure/vehicleparts/axis/aircraft/A)
	if (!A.do_vehicle_check())
		return FALSE
	if (!A.do_move())
		return FALSE
	A.after_aircraft_move()
	return TRUE

/proc/aircraft_roll(obj/structure/vehicleparts/axis/aircraft/A, steps)
	A.moving = TRUE
	A.currentspeed = A.speeds
	for (var/i = 1, i <= steps, i++)
		if (A.airborne() || !aircraft_step(A))
			return i - 1
	return steps

/proc/aircraft_repair(obj/structure/vehicleparts/axis/aircraft/A)
	for (var/obj/structure/vehicleparts/movement/W in A.wheels)
		W.broken = FALSE
	A.engine.on = TRUE

// The fixture is 60 tiles tall and every test rolls south: move a grounded
// aircraft back up the map (same level) before another takeoff run.
/proc/aircraft_reset_north(obj/structure/vehicleparts/axis/aircraft/A, front_y = 45)
	var/dy = front_y - aircraft_front_y(A)
	if (dy)
		A.aircraft_shift(A.flight_z(), 0, dy)
	aircraft_lay_runway(A)

// Runway under the aircraft and far enough ahead (south) for a takeoff roll.
/proc/aircraft_lay_runway(obj/structure/vehicleparts/axis/aircraft/A)
	var/min_x = 1000
	var/max_x = 0
	var/min_y = 1000
	var/max_y = 0
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		min_x = min(min_x, F.x)
		max_x = max(max_x, F.x)
		min_y = min(min_y, F.y)
		max_y = max(max_y, F.y)
	for (var/x = min_x, x <= max_x, x++)
		for (var/y = max(1, min_y - A.takeoff_roll - 4), y <= max_y, y++)
			var/turf/T = locate(x, y, 1)
			if (T && !(locate(/obj/covers/roads/modern/runway) in T))
				new /obj/covers/roads/modern/runway(T)

// Every frame casts a shadow on the ground turf straight below it.
/proc/aircraft_shadows_below(obj/structure/vehicleparts/axis/aircraft/A, ground)
	var/list/F = A.frames()
	if (!A.shadows || A.shadows.len != F.len)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/FR in F)
		var/obj/effect/aircraft_shadow/S = A.shadows[FR]
		var/turf/below = locate(FR.x, FR.y, ground)
		if (!S || !(S in below.vis_contents) || S.icon != FR.icon || S.color != "#000000" || S.loc || FR.vis_locs.len)
			return FALSE
	return TRUE

/proc/aircraft_ground_shown(obj/structure/vehicleparts/axis/aircraft/A, turf/T)
	return A.ground_shown(T)

/proc/aircraft_tank_fuel(obj/structure/vehicleparts/axis/aircraft/A)
	var/obj/structure/engine/internal/E = A.engine
	return E.fueltank.reagents.get_reagent_amount(E.fuels[1])

/proc/aircraft_visuals_gone(obj/structure/vehicleparts/axis/aircraft/A, list/old_turfs)
	if (A.shadows || A.ground_view || A.ground_view_far || A.ground_view_anchor)
		return FALSE
	for (var/turf/T in old_turfs)
		for (var/atom/V in T.vis_contents)
			if (istype(V, /obj/effect/aircraft_shadow) || istype(V, /obj/effect/aircraft_ground_view))
				return FALSE
	return TRUE

/proc/aircraft_checks()
	// Ground: dirt-less plain turf on z1, open air over x 1-10 on z2.
	for (var/x = 1, x <= 10, x++)
		for (var/y = 1, y <= 60, y++)
			new /turf/sky/building(locate(x, y, 2))
	for (var/y = 1, y <= 55, y++)
		for (var/x = 3, x <= 5, x++)
			new /obj/covers/roads/modern/runway(locate(x, y, 1))

	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(locate(2, 50, 1))
	aircraft_check(istype(A) && A.frames().len == 12 && A.components.len == 16, "the light plane builds twelve frames in a 4x4 turning square")
	aircraft_check(A.wheels.len == 4 && A.engine && A.engine.fueltank, "four wheels, an engine and a tank are connected")
	aircraft_check(istype(A.wheel, /obj/item/vehicleparts/wheel/modular/aircraft) && A.wheel.control && A.wheel.control.axis == A, "the pilot holds a control column that steers this aircraft")
	aircraft_check(A.on_runway(), "the plane starts on the runway")
	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	E.on = TRUE
	aircraft_check(A.check_engine(), "the fuelled engine runs")
	aircraft_check(A.engine.fueltank in A.transporting, "the fuel tank is known to be aboard from the start")
	A.moving = TRUE
	A.currentspeed = 2
	A.do_vehicle_check()
	aircraft_check(!QDELETED(A.engine.fueltank), "the vehicle check does not crush the tank on its own nose")

	var/mob/living/aircraft_probe/M = new(locate(4, 51, 1))
	var/obj/item/cargo = new /obj/item(locate(3, 52, 1))
	var/mob/living/aircraft_probe/walker = new(locate(5, 52, 1))

	// A slow roll never takes off.
	A.moving = TRUE
	A.currentspeed = 2
	for (var/i = 1, i <= 3, i++)
		aircraft_step(A)
	aircraft_check(!A.airborne() && A.runway_roll == 0 && A.flight_z() == 1, "rolling below full throttle stays on the ground")

	// Full throttle along the runway lifts it to the level above.
	var/rolled = aircraft_roll(A, A.takeoff_roll + 2)
	aircraft_check(A.airborne() && A.flight_state == AIRCRAFT_LOW && rolled == A.takeoff_roll, "a full-throttle roll of [A.takeoff_roll] runway tiles takes off")
	aircraft_check(aircraft_frames_z(A, 2) && A.flight_z() == 2 && E.z == 2, "the whole airframe moves to the level above")
	aircraft_check(M.z == 2 && cargo.z == 2, "the passenger and the cargo ride along instead of falling")
	aircraft_check(A in airborne_aircraft, "the aircraft is listed as airborne")
	aircraft_check(aircraft_shadows_below(A, 1), "each frame casts a shadow on the ground below it")
	var/obj/structure/vehicleparts/frame/nose = A.corners[2]
	aircraft_check(aircraft_ground_shown(A, locate(nose.x, nose.y, 1)) && aircraft_ground_shown(A, locate(nose.x - 3, nose.y - 6, 1)), "the open air shows the ground below and around the aircraft")
	aircraft_check(A.ground_view_anchor && A.ground_view_anchor.z == 2 && (A.ground_view in A.ground_view_anchor.vis_contents) && (A.ground_view_far in A.ground_view_anchor.vis_contents) && !A.ground_view.loc && !A.ground_view_far.loc, "the ground view is drawn through the open air, not placed on the map")
	var/turf/centre = A.footprint_centre()
	aircraft_check(centre && centre.x == nose.x - 1 && (centre.y == nose.y + 1 || centre.y == nose.y + 2), "the ground view is centred on the airframe, not its corner")
	var/turf/near_tile = locate(centre.x, centre.y + 7, 1)
	var/turf/far_tile = locate(centre.x, centre.y + 9, 1)
	aircraft_check((near_tile in A.ground_view.vis_contents) && (far_tile in A.ground_view_far.vis_contents) && !aircraft_ground_shown(A, locate(centre.x, centre.y + 11, 1)), "the ground shows in full to seven tiles, faintly to ten, and not beyond")
	var/list/far_haze = A.ground_view_far.color
	var/list/near_haze = A.ground_view.color
	aircraft_check(istype(A.ground_view_far, /obj/effect/aircraft_ground_view/far) && islist(far_haze) && far_haze[16] < near_haze[16], "the outer ring is fainter than the inner view")
	var/obj/covers/roof_floor = new /obj/covers/wood(locate(nose.x + 3, nose.y - 2, 2))
	A.update_flight_visuals()
	aircraft_check(!aircraft_ground_shown(A, locate(nose.x + 3, nose.y - 2, 1)) && aircraft_ground_shown(A, locate(nose.x + 4, nose.y - 2, 1)), "a floor on the upper level hides the ground under it")
	qdel(roof_floor)
	aircraft_check(A.shadows[nose]:pixel_x == 8, "low flight casts a close shadow")

	// Over open air: aboard is held, overboard falls.
	var/obj/structure/vehicleparts/frame/side = locate(/obj/structure/vehicleparts/frame) in locate(3, aircraft_front_y(A), 2)
	var/obj/item/dropped = new /obj/item(locate(8, 30, 1))
	dropped.forceMove(locate(8, 30, 2))
	aircraft_check(dropped.z == 1, "an item dropped onto open air away from the aircraft falls")
	var/obj/item/held = new /obj/item(locate(8, 31, 1))
	if (side)
		held.forceMove(side.loc)
	aircraft_check(side && held.z == 2, "an item put down on an airborne frame stays aboard")
	aircraft_check(walker.z == 2, "a second passenger rides along")
	walker.forceMove(locate(1, aircraft_front_y(A), 2))
	aircraft_check(walker.z == 1, "a passenger who steps off an airborne aircraft falls")

	// Low flight moves with everything aboard.
	var/y_before = aircraft_front_y(A)
	A.currentspeed = A.speeds
	aircraft_check(aircraft_step(A) && aircraft_front_y(A) == y_before - 1 && M.z == 2 && aircraft_frames_z(A, 2), "low flight moves the aircraft one tile and keeps the passenger aboard")
	aircraft_check(aircraft_shadows_below(A, 1) && !(locate(/obj/effect/aircraft_shadow) in locate(nose.x, nose.y + 4, 1).vis_contents), "the shadows follow the aircraft and leave the tiles behind it")

	// The airframe draws the plane, not a box truck: every section shows its
	// deck from inside, its hull from outside, and the nose its propeller.
	var/art_ok = TRUE
	var/wings = 0
	for (var/obj/structure/vehicleparts/frame/car/aircraft/F in A.components)
		if (F.icon != 'icons/obj/vehicles/lightplane.dmi' || !F.hull_state)
			art_ok = FALSE
		if (F.noroof)
			wings++
			if (F.icon_state != F.hull_state || F.roof.icon_state != "")
				art_ok = FALSE
		else if (F.icon_state != "[F.hull_state]_floor" || F.roof.icon_state != F.hull_state || F.roof.icon != F.icon || F.roof.dir != F.dir)
			art_ok = FALSE
	aircraft_check(art_ok && wings == 2, "every airframe section draws its own piece of the plane")
	var/obj/structure/vehicleparts/frame/car/aircraft/nose_center = locate(/obj/structure/vehicleparts/frame/car/aircraft/nose/center) in A.components
	var/prop_state = ""
	for (var/O in nose_center.overlays)
		var/image/I = O
		if (I.icon_state == "prop" || I.icon_state == "prop_spin")
			prop_state = I.icon_state
	aircraft_check(prop_state == "prop_spin", "the propeller turns while the engine runs")
	A.engine.on = FALSE
	A.engine.update_icon()
	prop_state = ""
	for (var/O in nose_center.overlays)
		var/image/I = O
		if (I.icon_state == "prop" || I.icon_state == "prop_spin")
			prop_state = I.icon_state
	aircraft_check(prop_state == "prop", "the propeller stops with the engine")
	A.engine.on = TRUE
	A.engine.update_icon()
	var/obj/effect/aircraft_shadow/nose_shadow = A.shadows[nose_center]
	aircraft_check(nose_shadow && nose_shadow.icon == 'icons/obj/vehicles/lightplane.dmi' && nose_shadow.icon_state == "nose_center_floor", "the shadow takes the plane's silhouette")

	// Fire from the ground: a shot crossing the turf under a frame's shadow
	// can hit that frame; in low flight any weapon reaches, at cruise only
	// heavy weapons do.
	var/obj/item/projectile/bullet/rifle/round = new(null)
	var/obj/item/projectile/shell/shell = new(null)
	var/turf/under_nose = locate(nose.x, nose.y, 1)
	aircraft_check(A.frame_over(under_nose) == nose && !A.frame_over(locate(nose.x, nose.y + 5, 1)), "the frame over a ground turf is found through its shadow")
	aircraft_check(A.reachable_by(round) && A.reachable_by(shell), "in low flight rifle fire and shells both reach the aircraft")
	var/obj/structure/vehicleparts/frame/body = locate(/obj/structure/vehicleparts/frame/car/aircraft/fuselage/center) in A.components
	var/damage_before = A.airframe_damage
	aircraft_check(A.airframe_hit(body, round) && A.airframe_damage == damage_before + round.damage && A.airborne(), "a hit wears the airframe without bringing it down")
	// Cruise passes over upper storeys and will not descend into them.
	aircraft_check(A.climb(M) && A.flight_state == AIRCRAFT_CRUISE, "climb reaches cruising height")
	aircraft_check(!A.reachable_by(round) && A.reachable_by(shell), "at cruise only heavy weapons reach the aircraft")
	aircraft_check(A.shadows[nose]:pixel_x == 16, "cruise casts a farther shadow")
	aircraft_check(!A.climb(M), "climbing again is refused")
	var/obj/structure/aircraft_probe_wall/W = new(locate(4, aircraft_front_y(A) - 1, 2))
	aircraft_check(aircraft_step(A) && A.flight_state == AIRCRAFT_CRUISE, "cruise flies over an upper storey")
	var/obj/structure/vehicleparts/frame/wing = locate(/obj/structure/vehicleparts/frame/car/aircraft/wing) in A.components
	var/obj/covers/storey_floor = new /obj/covers/wood(get_turf(wing))
	A.update_flight_visuals()
	aircraft_check(wing && !A.shadows[wing] && A.shadows.len == A.frames().len - 1, "a frame over an upper floor throws no shadow on the ground below")
	qdel(storey_floor)
	A.update_flight_visuals()
	aircraft_check(A.shadows[wing], "the shadow returns over open air")
	aircraft_check(!A.descend(M) && A.flight_state == AIRCRAFT_CRUISE, "descending onto an upper storey is refused")
	for (var/i = 1, i <= 4, i++)
		aircraft_step(A)
	qdel(W)
	aircraft_check(A.descend(M) && A.flight_state == AIRCRAFT_LOW, "past it, descend returns to low flight")

	// Landing needs the runway below and approach speed.
	A.currentspeed = A.speeds
	aircraft_check(!A.descend(M) && A.airborne(), "landing too fast is refused")
	A.currentspeed = A.landing_gear
	var/list/shadowed = list()
	for (var/obj/effect/aircraft_shadow/S in A.shadow_turfs)
		shadowed += A.shadow_turfs[S]
	shadowed += A.ground_view_anchor
	aircraft_check(A.descend(M) && !A.airborne() && aircraft_frames_z(A, 1) && M.z == 1, "a slow descent over the runway lands with the passenger")
	aircraft_check(shadowed.len == 13 && aircraft_visuals_gone(A, shadowed), "a landed aircraft leaves no shadow or ground view behind")
	aircraft_check(!(A in airborne_aircraft) && A.currentspeed == 1, "a landed aircraft leaves the airborne list and slows")
	aircraft_check(!A.descend(M), "descending on the ground is refused")

	// Hitting an upper storey in low flight crashes.
	aircraft_roll(A, A.takeoff_roll)
	aircraft_check(A.airborne(), "the aircraft takes off again")
	var/fuel_before = aircraft_tank_fuel(A)
	A.flight_watch_tick()
	aircraft_check(aircraft_tank_fuel(A) < fuel_before && A.stall_seconds == 0, "a second of flight burns fuel from the tank without counting as a stall")
	var/obj/structure/engine/internal/fuel_engine = A.engine
	var/burn_per_second = fuel_engine.fuelefficiency * 2 * 2.5
	aircraft_check(A.engine.fueltank.reagents.maximum_volume / burn_per_second >= 180, "a full tank keeps the plane in low flight for at least three minutes ([A.engine.fueltank.reagents.maximum_volume] u at [burn_per_second] u/s)")
	var/obj/structure/aircraft_probe_wall/W2 = new(locate(4, aircraft_front_y(A) - 1, 2))
	A.currentspeed = A.speeds
	aircraft_check(!aircraft_step(A) && !A.airborne() && aircraft_frames_z(A, 1), "flying into an upper storey in low flight crashes to the ground")
	var/all_broken = TRUE
	for (var/obj/structure/vehicleparts/movement/WH in A.wheels)
		all_broken = all_broken && WH.broken
	aircraft_check(all_broken && !E.on && !A.moving, "a crash breaks the wheels and stops the engine")
	aircraft_check(A.landing_gear_broken(), "the crash leaves the landing gear broken")
	var/obj/structure/vehicleparts/movement/one_wheel = A.wheels[1]
	aircraft_check(one_wheel.axis == A, "each wheel knows its aircraft")
	A.mend_landing_gear()
	aircraft_check(!A.landing_gear_broken(), "mending the landing gear fixes every wheel at once")
	for (var/obj/structure/vehicleparts/movement/WH in A.wheels)
		WH.broken = TRUE
	qdel(W2)

	// Losing lift in the air stalls it.
	aircraft_repair(A)
	aircraft_roll(A, A.takeoff_roll)
	aircraft_check(A.airborne(), "the repaired aircraft takes off again")
	E.on = FALSE
	for (var/i = 1, i <= 3, i++)
		A.flight_watch_tick()
	aircraft_check(!A.airborne() && aircraft_frames_z(A, 1), "with the engine off it stalls and comes down after three watch ticks")

	// Off the runway a landing must be forced with a second Descend.
	aircraft_repair(A)
	aircraft_reset_north(A)
	aircraft_roll(A, A.takeoff_roll)
	aircraft_check(A.airborne(), "the aircraft takes off a fourth time")
	var/west_x = 1000
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		west_x = min(west_x, F.x)
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		if (F.x == west_x)
			for (var/obj/covers/roads/modern/runway/R in locate(F.x, F.y, 1))
				qdel(R)
	A.currentspeed = A.landing_gear
	aircraft_check(A.runway_share(1) > 0.6 && A.runway_share(1) < 0.7 && A.descend(M) && !A.airborne(), "a plane one tile off the strip, with two of three columns on runway, still lands")
	aircraft_repair(A)
	aircraft_reset_north(A)
	aircraft_roll(A, A.takeoff_roll)
	aircraft_check(A.airborne(), "the aircraft takes off a fifth time")
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		for (var/obj/covers/roads/modern/runway/R in locate(F.x, F.y, 1))
			qdel(R)
	aircraft_check(A.rough_ground_below(1) && !A.runway_share(1), "with no runway below, dry open ground is fit to land on")
	A.currentspeed = A.speeds
	aircraft_check(!A.descend(M) && A.airborne() && !A.force_landing_until, "a fast descent over open ground is refused without arming a crash landing")
	A.currentspeed = A.landing_gear
	A.airframe_damage = 0
	aircraft_check(A.descend(M) && !A.airborne() && aircraft_frames_z(A, 1) && M.z == 1, "a slow descent over open ground lands without a runway")
	aircraft_check(A.airframe_damage == 25 && A.currentspeed == 0 && !A.moving && !A.landing_gear_broken() && E.on, "a rough landing strains the airframe and stops the plane, but keeps the gear and engine")
	A.airframe_damage = 80
	aircraft_reset_north(A)
	aircraft_roll(A, A.takeoff_roll)
	aircraft_check(A.airborne(), "the shaken aircraft takes off again")
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		for (var/obj/covers/roads/modern/runway/R in locate(F.x, F.y, 1))
			qdel(R)
	A.currentspeed = A.landing_gear
	aircraft_check(A.descend(M) && !A.airborne() && A.landing_gear_broken() && A.airframe_damage < 150, "a badly shaken airframe lands rough on a broken landing gear")
	A.airframe_damage = 0

	// Water is no place to set down: that still needs a forced crash landing.
	aircraft_repair(A)
	aircraft_reset_north(A)
	aircraft_roll(A, A.takeoff_roll)
	aircraft_check(A.airborne(), "the aircraft takes off a sixth time")
	var/list/flooded = list()
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		var/turf/G = locate(F.x, F.y, 1)
		for (var/obj/covers/roads/modern/runway/R in G)
			qdel(R)
		flooded |= G
	for (var/turf/G in flooded)
		new /turf/floor/beach/water(G)
	A.currentspeed = A.landing_gear
	aircraft_check(!A.rough_ground_below(1), "water below is not ground to land on")
	aircraft_check(!A.descend(M) && A.airborne() && A.force_landing_until > world.time, "descending over water asks for confirmation")
	aircraft_check(A.descend(M) && !A.airborne() && aircraft_frames_z(A, 1), "a second Descend forces a crash landing")
	aircraft_check(aircraft_visuals_gone(A, list()), "a crashed aircraft drops its shadow and ground view")

	// A crash over an obstacle comes down on the nearest clear ground.
	aircraft_repair(A)
	aircraft_reset_north(A)
	aircraft_roll(A, A.takeoff_roll)
	aircraft_check(A.airborne(), "the aircraft takes off a seventh time")
	var/obj/structure/vehicleparts/frame/under = A.corners[2]
	var/obj/structure/aircraft_probe_wall/ground_wall = new(locate(under.x, under.y, 1))
	var/list/offset = A.clear_footprint_offset(1)
	aircraft_check(islist(offset) && (offset[1] || offset[2]) && max(abs(offset[1]), abs(offset[2])) == 1, "a wall under one frame moves the landing one tile over")
	A.currentspeed = A.landing_gear
	A.descend(M)
	aircraft_check(A.descend(M) && !A.airborne() && aircraft_frames_z(A, 1) && !(locate(/obj/structure/vehicleparts/frame) in ground_wall.loc), "the forced landing comes down beside the wall, not in it")
	qdel(ground_wall)

	// With no clear ground within reach the airframe breaks up.
	var/obj/structure/vehicleparts/axis/aircraft/X = build_light_plane(locate(13, 44, 2))
	var/obj/structure/engine/internal/XE = X.engine
	XE.fueltank.reagents.add_reagent(XE.fuels[1], 100, safety = TRUE)
	XE.on = TRUE
	var/mob/living/aircraft_probe/doomed = new(locate(14, 45, 2))
	X.set_flight_state(AIRCRAFT_LOW)
	var/list/rubble_tiles = list()
	for (var/turf/T in block(locate(5, 36, 1), locate(20, 59, 1)))
		if (T.x >= 13 && T.x <= 16 && T.y >= 44 && T.y <= 47)
			rubble_tiles += T
			continue
		new /obj/structure/aircraft_probe_wall(T)
	for (var/turf/T in rubble_tiles)
		if (T.x == 14 && T.y == 45)
			continue
		new /obj/structure/aircraft_probe_wall(T)
	aircraft_check(!X.clear_footprint_offset(1), "no clear footprint is found among the walls")
	var/hurt_before = doomed.getBruteLoss()
	aircraft_check(X.crash_land("the probe") && QDELETED(X), "the aircraft breaks up instead of landing in the walls")
	aircraft_check(doomed.z == 1 && doomed.getBruteLoss() > hurt_before, "the crew fall to the ground, hurt")
	aircraft_check(locate(/obj/structure/barricade/debris) in locate(14, 45, 1), "debris lands on the clear tile under the footprint")
	for (var/obj/structure/aircraft_probe_wall/PW in world)
		if (PW.z == 1 && PW.y >= 36)
			qdel(PW)

	// Holding at the edge of the world counts as losing lift.
	var/obj/structure/vehicleparts/axis/aircraft/edge = build_light_plane(locate(6, 1, 2))
	var/obj/structure/engine/internal/EE = edge.engine
	EE.fueltank.reagents.add_reagent(EE.fuels[1], 100, safety = TRUE)
	EE.on = TRUE
	edge.set_flight_state(AIRCRAFT_LOW)
	edge.moving = TRUE
	edge.currentspeed = edge.speeds
	aircraft_check(!edge.do_vehicle_check() && edge.edge_blocked, "a step off the edge of the world is refused and remembered")
	for (var/i = 1, i <= 3, i++)
		edge.flight_watch_tick()
	aircraft_check(!edge.airborne() && aircraft_frames_z(edge, 1), "holding at the edge stalls the aircraft within three seconds")

	// Saved in flight: after a load the aircraft is set down on the ground.
	var/obj/structure/vehicleparts/axis/aircraft/D = build_light_plane(locate(6, 5, 2))
	aircraft_check(D.aloft_over_open_air() && !D.airborne(), "an aircraft restored over open air is aloft without flight state")
	D.engine.on = TRUE
	aircraft_check(D.set_down_after_restore() && aircraft_frames_z(D, 1) && !D.airborne() && !D.engine.on, "it is set down on the clear ground below with its engine off")
	var/intact = TRUE
	for (var/obj/structure/vehicleparts/movement/DW in D.wheels)
		intact = intact && !DW.broken
	aircraft_check(intact && !D.set_down_after_restore(), "a clear set-down keeps the wheels and happens once")
	new /obj/structure/aircraft_probe_wall(locate(8, 13, 1))
	var/obj/structure/vehicleparts/axis/aircraft/G = build_light_plane(locate(6, 12, 2))
	aircraft_check(G.set_down_after_restore() && aircraft_frames_z(G, 1), "one restored over an obstacle still comes down")
	var/wrecked = TRUE
	for (var/obj/structure/vehicleparts/movement/GW in G.wheels)
		wrecked = wrecked && GW.broken
	aircraft_check(wrecked, "and lands hard, breaking its wheels")
	var/obj/structure/vehicleparts/axis/aircraft/S = build_airstrip(locate(14, 30, 1))
	var/strip = 0
	for (var/turf/RT in block(locate(15, 18, 1), locate(17, 33, 1)))
		if (locate(/obj/covers/roads/modern/runway) in RT)
			strip++
	aircraft_check(istype(S) && S.on_runway() && strip == 48, "the airstrip spawner lays a 3x16 runway with the plane at its north end")
	S.engine.fueltank.reagents.add_reagent(S.engine:fuels[1], 100, safety = TRUE)
	S.engine.on = TRUE
	aircraft_roll(S, S.takeoff_roll)
	aircraft_check(S.airborne() && S.flight_z() == 2, "the plane takes off from the spawned airstrip")
	S.currentspeed = S.landing_gear
	aircraft_check(S.descend(null) && !S.airborne(), "and lands back on it")
	var/obj/structure/vehicleparts/axis/aircraft/P = build_light_plane(locate(11, 30, 1))
	aircraft_check(!P.aloft_over_open_air() && !P.set_down_after_restore(), "an aircraft restored on the ground stays put")

	// Off the runway it takes off from open ground after a longer roll;
	// with no level above it cannot.
	// Beside the runway (x 3-5), under the open air of x 1-10.
	var/obj/structure/vehicleparts/axis/aircraft/B = build_light_plane(locate(6, 56, 1))
	var/obj/structure/engine/internal/BE = B.engine
	BE.fueltank.reagents.add_reagent(BE.fuels[1], 100, safety = TRUE)
	B.engine.on = TRUE
	aircraft_check(!B.on_runway() && B.takeoff_distance() == B.rough_takeoff_roll && B.rough_takeoff_roll > B.takeoff_roll, "off a runway the takeoff roll is longer")
	var/rough_rolled = aircraft_roll(B, B.takeoff_roll + 2)
	aircraft_check(rough_rolled == B.takeoff_roll + 2 && !B.airborne() && B.flight_z() == 1 && B.runway_roll == B.takeoff_roll + 2, "a runway-length roll on open ground stays on the ground")
	aircraft_check(findtext(B.takeoff_hint(), "more tiles of open ground"), "climb on open ground counts the tiles left")
	B.engine.on = FALSE
	aircraft_check(findtext(B.takeoff_hint(), "Start the engine"), "climb with the engine off says to start it")
	B.engine.on = TRUE
	rough_rolled += aircraft_roll(B, B.rough_takeoff_roll)
	aircraft_check(B.airborne() && B.flight_z() == 2 && rough_rolled == B.rough_takeoff_roll, "a full-throttle roll of [B.rough_takeoff_roll] tiles of open ground takes off")
	var/obj/structure/vehicleparts/axis/aircraft/C = build_light_plane(locate(16, 50, 2))
	aircraft_check(!C.try_takeoff() && C.flight_z() == 2 && !C.airborne(), "with no level above there is nowhere to climb")
	aircraft_check(!A.climb(M), "climb on the ground is refused")
	S.engine.on = TRUE
	S.currentspeed = 1
	aircraft_check(!S.airborne() && S.on_runway() && findtext(S.takeoff_hint(), "Throttle up to full"), "climb on the runway below full throttle says to throttle up")
	S.currentspeed = S.speeds
	S.runway_roll = 3
	aircraft_check(findtext(S.takeoff_hint(), "[S.takeoff_roll - 3] more tiles of runway"), "climb at full throttle counts the runway tiles left")
	S.currentspeed = 0
	S.runway_roll = 0

	// The open-air hook only holds what an airborne aircraft carries.
	aircraft_check(!aircraft_holds(locate(8, 8, 2), dropped), "nothing is held once no aircraft is airborne")

	// Players build the light plane at an aircraft hangar once Powered Flight
	// is researched; it leaves the press with an empty tank and keys issued.
	if (!research_nodes.len)
		build_research_tree()
	var/datum/research_node/flight = get_research_node("powered_flight")
	var/datum/research_node/aviation = get_research_node("aviation_rocketry")
	aircraft_check(flight && ("automobiles" in flight.prereqs) && flight.era_tier == 6 && aviation && ("powered_flight" in aviation.prereqs), "Powered Flight follows Automobiles and leads to Aviation & Rocketry (node [flight ? "found" : "missing"])")
	aircraft_check(get_recipe_node_req("/obj/structure/car_workshop/hangar") == "powered_flight", "Powered Flight gates the hangar (got [get_recipe_node_req("/obj/structure/car_workshop/hangar")])")
	for (var/bx = 15, bx <= 18, bx++)
		for (var/by = 3, by <= 6, by++)
			var/turf/BT = locate(bx, by, 1)
			BT.ChangeTurf(/turf/floor/dirt)
	var/obj/structure/car_workshop/hangar/hangar = new(locate(14, 2, 1))
	aircraft_check(hangar.model_size("Light plane") == 4 && hangar.costs("Light plane")["steel"] == 50 && !hangar.costs("SMC Falcon") && !hangar.allowed(null), "the hangar builds only the light plane, after Powered Flight")
	aircraft_check(!hangar.complete_assembly("Light plane"), "an empty hangar builds nothing")
	hangar.stock = list("steel" = 60, "glass" = 10, "cloth" = 10, "cable" = 10, "wheels" = 4)
	var/obj/structure/vehicleparts/axis/aircraft/built = hangar.complete_assembly("Light plane")
	aircraft_check(istype(built), "the hangar builds a light plane in its bay")
	if (istype(built))
		aircraft_check(built.frames().len == 12 && built.engine && built.engine.fueltank && aircraft_tank_fuel(built) == 0, "the built plane is whole with an empty tank ([built.frames().len] frames, fuel [built.engine && built.engine.fueltank ? aircraft_tank_fuel(built) : "none"])")
		aircraft_check(built.keyed_vehicle_id && hangar.stock["steel"] == 10 && hangar.stock["wheels"] == 0, "the hangar issues keys and spends its inputs (key [built.keyed_vehicle_id], steel [hangar.stock["steel"]], wheels [hangar.stock["wheels"]])")
	aircraft_check(!hangar.complete_assembly("Light plane"), "the occupied bay refuses a second build")

	// Enough hits break the airframe up: the plane comes down where it is.
	if (istype(built))
		for (var/bx = 15, bx <= 18, bx++)
			for (var/by = 3, by <= 6, by++)
				new /turf/sky/building(locate(bx, by, 2))
		built.aircraft_shift(2)
		built.set_flight_state(AIRCRAFT_LOW)
		var/obj/structure/vehicleparts/frame/built_nose = locate(/obj/structure/vehicleparts/frame/car/aircraft/nose/center) in built.components
		aircraft_check(built.airborne() && built.frame_over(locate(built_nose.x, built_nose.y, 1)) == built_nose, "a plane lifted into low flight casts a shadow for gunners to aim at")
		built.airframe_damage = 149
		built.airframe_hit(built_nose, shell)
		aircraft_check(!built.airborne() && aircraft_frames_z(built, 1), "airframe failure brings the plane down")
	qdel(round)
	qdel(shell)

/proc/aircraft_run()
	try
		aircraft_checks()
	catch(var/exception/e)
		aircraft_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = aircraft_failures, "runtime_error" = aircraft_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/aircraft_probe
		aircraft_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		aircraft_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		aircraft_run()
