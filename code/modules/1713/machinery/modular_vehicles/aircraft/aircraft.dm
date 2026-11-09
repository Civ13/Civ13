// Modular aircraft, phase 1: the flight core.
//
// An aircraft is a modular vehicle whose altitude is the z-level it is on.
// On the ground it taxis like a car. After a takeoff roll at full throttle on
// runway tiles, the whole vehicle moves up to the level above the surface
// (multiz_level_above), which on Gaia is the standing open-air building level.
// There it flies in low flight (it can hit upper storeys) or cruise (it passes
// over them). Descending in low flight at approach speed lands it: smoothly
// over a runway, or in a rough landing over clear, dry open ground, which
// strains the airframe and drags the plane to a stop. Over water, trenches,
// lava or obstacles, or after a stall, it crash-lands.

// AIRCRAFT_GROUND, AIRCRAFT_LOW and AIRCRAFT_CRUISE live in code/__defines/aircraft.dm.
// Seconds without lift (engine off, too slow, stopped) before a stall crash.
#define AIRCRAFT_STALL_SECONDS 3
// A second Descend within this time forces a crash landing off a runway.
#define AIRCRAFT_FORCE_LANDING_WINDOW (5 SECONDS)
// Share of the frames that must be over runway for a landing. A 3-wide plane
// drifting one tile off a 3-wide strip still lands.
#define AIRCRAFT_LANDING_RUNWAY_SHARE 0.5
// How far (in tiles) a crashing or restored aircraft looks for clear ground.
#define AIRCRAFT_CRASH_SEARCH 6
// Extra fuel burnt per second of flight, as a multiple of the engine's full-
// load burn per tick; cruise is leaner than low flight.
#define AIRCRAFT_FLIGHT_BURN_LOW 1.5
#define AIRCRAFT_FLIGHT_BURN_CRUISE 1
// The engine module's FUEL_CONSUMPTION_MODIFIER, which is file-local there.
#define AIRCRAFT_FUEL_MODIFIER 2

var/global/list/airborne_aircraft = list()

/obj/structure/vehicleparts/axis/aircraft
	name = "aircraft"
	desc = "The controls and frame of a light aircraft."
	vehicle_type = "car"
	speeds = 5
	maxpower = 800
	speedlist = alist(1=8,2=6,3=4,4=3,5=2)
	turntimer = 10
	var/flight_state = AIRCRAFT_GROUND
	// Tiles rolled at full throttle on runway before the wheels leave it.
	var/takeoff_roll = 8
	// The same off a runway: open ground works, it just needs a longer roll.
	var/rough_takeoff_roll = 16
	// Lowest gear that keeps the aircraft flying.
	var/stall_gear = 2
	// Highest gear at which it can land on a runway.
	var/landing_gear = 2
	var/tmp/runway_roll = 0
	var/tmp/stall_seconds = 0
	var/tmp/flight_watching = FALSE
	var/tmp/force_landing_until = 0
	var/tmp/no_airspace_warned = FALSE
	// The last step was refused by the edge of the world: no lift either.
	var/tmp/edge_blocked = FALSE

/obj/structure/vehicleparts/axis/aircraft/persistence_runtime_var(key)
	return (key in list("runway_roll", "stall_seconds", "flight_watching", "force_landing_until", "no_airspace_warned", "edge_blocked")) || ..(key)

/obj/structure/vehicleparts/axis/aircraft/proc/airborne()
	return flight_state != AIRCRAFT_GROUND

// The axis sits inside a frame, where its own z reads 0.
/obj/structure/vehicleparts/axis/aircraft/proc/flight_z()
	var/turf/T = get_turf(src)
	return T ? T.z : 0

/obj/structure/vehicleparts/axis/aircraft/Destroy()
	airborne_aircraft -= src
	clear_shadows()
	clear_ground_view()
	return ..()

/obj/structure/vehicleparts/axis/aircraft/proc/pilot_message(text)
	if (driver)
		to_chat(driver, text)

/obj/structure/vehicleparts/axis/aircraft/proc/crew()
	. = list()
	for (var/mob/living/M in transporting)
		. += M

// Open air drops what enters it unless an airborne aircraft carries it.
/proc/aircraft_holds(turf/T, atom/movable/A)
	if (!T)
		return FALSE
	// Mid-climb or mid-move, the tiles an aircraft is transforming are its own.
	if (istype(T.vehicle_transforming, /obj/structure/vehicleparts/axis/aircraft))
		return TRUE
	if (!airborne_aircraft.len)
		return FALSE
	// Standing on an airborne frame holds; stepping off it does not.
	for (var/obj/structure/vehicleparts/frame/F in T)
		var/obj/structure/vehicleparts/axis/aircraft/V = F.axis
		if (istype(V) && V.airborne())
			return TRUE
	return FALSE

// Turf hooks for decks that act as runways without a runway cover, such as
// a carrier's flight deck (code/modules/naval/carrier.dm).
/turf/proc/aircraft_runway()
	return FALSE

// A deck a rolling plane must not leave: the step off it is refused.
/turf/proc/aircraft_deck()
	return FALSE

// Arresting wires: a plane that lands here stops on the spot.
/turf/proc/arrests_aircraft()
	return FALSE

// Ground an aircraft can set down on without a runway: dry, level and solid.
// Obstacles on it are checked separately (obstacle_at).
/turf/proc/aircraft_rough_ground()
	return !density

/turf/sky/aircraft_rough_ground()
	return FALSE

/turf/floor/aircraft_rough_ground()
	return ..() && !watertile && !water_level

/turf/floor/trench/aircraft_rough_ground()
	return FALSE

/turf/floor/lava/aircraft_rough_ground()
	return FALSE

/proc/aircraft_runway_at(turf/T)
	return T && (T.aircraft_runway() || (locate(/obj/covers/roads/modern/runway) in T))

/obj/structure/vehicleparts/axis/aircraft/proc/frames()
	. = list()
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (F.axis == src && !QDELETED(F))
			. += F

/obj/structure/vehicleparts/axis/aircraft/proc/on_runway()
	var/list/F = frames()
	if (!F.len)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/FR in F)
		if (!aircraft_runway_at(get_turf(FR)))
			return FALSE
	return TRUE

// The share of frames that would stand on runway at target_z, 0 to 1.
/obj/structure/vehicleparts/axis/aircraft/proc/runway_share(target_z)
	var/list/F = frames()
	if (!F.len)
		return 0
	var/on = 0
	for (var/obj/structure/vehicleparts/frame/FR in F)
		if (aircraft_runway_at(locate(FR.x, FR.y, target_z)))
			on++
	return on / F.len

// Whether every frame would stand on dry open ground at target_z.
/obj/structure/vehicleparts/axis/aircraft/proc/rough_ground_below(target_z)
	var/list/F = frames()
	if (!F.len)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/FR in F)
		var/turf/T = locate(FR.x, FR.y, target_z)
		if (!T || !T.aircraft_rough_ground())
			return FALSE
	return TRUE

// The first thing at T that an aircraft on that level would fly into.
/obj/structure/vehicleparts/axis/aircraft/proc/obstacle_at(turf/T)
	if (!T)
		return "the edge of the world"
	if (T.density)
		return T
	for (var/obj/covers/C in T)
		if (C.density)
			return C
	for (var/obj/structure/S in T)
		if (!S.density || (S in transporting) || (S in components) || S == src)
			continue
		if (istype(S, /obj/structure/vehicleparts/frame))
			var/obj/structure/vehicleparts/frame/F = S
			if (F.axis == src)
				continue
		return S
	return null

/obj/structure/vehicleparts/axis/aircraft/proc/clear_at_level(target_z, dx = 0, dy = 0)
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/T = locate(F.x + dx, F.y + dy, target_z)
		var/hit = obstacle_at(T)
		if (hit)
			return hit
	return null

// The nearest offset at which the whole footprint fits on target_z without
// hitting anything, searching outward from straight below; null when none
// is within AIRCRAFT_CRASH_SEARCH tiles.
/obj/structure/vehicleparts/axis/aircraft/proc/clear_footprint_offset(target_z)
	if (!clear_at_level(target_z))
		return list(0, 0)
	for (var/r = 1, r <= AIRCRAFT_CRASH_SEARCH, r++)
		for (var/dx = -r, dx <= r, dx++)
			for (var/dy = -r, dy <= r, dy++)
				if (abs(dx) != r && abs(dy) != r)
					continue
				if (!clear_at_level(target_z, dx, dy))
					return list(dx, dy)
	return null

// Moves the whole aircraft and everything aboard to target_z, shifted by
// dx, dy tiles (straight up or down by default).
/obj/structure/vehicleparts/axis/aircraft/proc/aircraft_shift(target_z, dx = 0, dy = 0)
	if (!target_z || transforming_vehicle)
		return FALSE
	add_transporting(FALSE)
	var/list/movers = list()
	var/list/destinations = list()
	var/list/tiles = list()
	for (var/atom/movable/M in (transporting | components))
		if (QDELETED(M) || !isturf(M.loc))
			continue
		var/turf/D = locate(M.x + dx, M.y + dy, target_z)
		if (!D)
			return FALSE
		movers += M
		destinations[M] = D
		tiles |= M.loc
		tiles |= D
	transforming_vehicle = TRUE
	transform_tiles = tiles
	for (var/turf/T in tiles)
		T.vehicle_transforming = src
	try
		// Frames first, so whatever stands on them arrives on a floor.
		for (var/obj/structure/vehicleparts/frame/F in movers)
			F.forceMove(destinations[F])
		for (var/atom/movable/M in movers)
			if (istype(M, /obj/structure/vehicleparts/frame) || QDELETED(M))
				continue
			M.forceMove(destinations[M])
	catch (var/exception/e)
		release_transform_tiles(tiles)
		throw e
	release_transform_tiles(tiles)
	for (var/obj/O in movers)
		O.update_icon()
	refresh_passenger_vision()
	return TRUE

/obj/structure/vehicleparts/axis/aircraft/proc/set_flight_state(state)
	flight_state = state
	if (airborne())
		airborne_aircraft |= src
		flight_watch()
	else
		airborne_aircraft -= src
		stall_seconds = 0
		edge_blocked = FALSE
	update_flight_visuals()

/obj/structure/vehicleparts/axis/aircraft/proc/try_takeoff()
	var/up = multiz_level_above(flight_z())
	if (!up)
		if (!no_airspace_warned)
			no_airspace_warned = TRUE
			pilot_message(SPAN_WARNING("There is no open sky above this place to fly into."))
		return FALSE
	var/hit = clear_at_level(up)
	if (hit)
		pilot_message(SPAN_WARNING("Something above blocks the climb: [hit]."))
		runway_roll = 0
		return FALSE
	if (!aircraft_shift(up))
		return FALSE
	runway_roll = 0
	set_flight_state(AIRCRAFT_LOW)
	visible_message(SPAN_NOTICE("\The [src] lifts off the ground and climbs into the air."))
	return TRUE

// What the pilot still has to do before the wheels leave the ground. Takeoff
// itself is automatic (after_aircraft_move); Climb only works in the air.
/obj/structure/vehicleparts/axis/aircraft/proc/takeoff_hint()
	if (!engine || !engine.on)
		return "Start the engine first: use the control column."
	if (currentspeed < speeds || reverse)
		return "Climb only works in the air. Throttle up to full (gear [speeds]) and roll forward in a straight line: the plane takes off by itself after [takeoff_roll] tiles of runway or [rough_takeoff_roll] tiles of open ground."
	return "Keep rolling: the plane takes off by itself after [max(1, takeoff_distance() - runway_roll)] more tile\s of [on_runway() ? "runway" : "open ground"]."

/obj/structure/vehicleparts/axis/aircraft/proc/climb(mob/user)
	switch (flight_state)
		if (AIRCRAFT_GROUND)
			to_chat(user, SPAN_WARNING(takeoff_hint()))
			return FALSE
		if (AIRCRAFT_CRUISE)
			to_chat(user, SPAN_WARNING("You are already at cruising height."))
			return FALSE
	set_flight_state(AIRCRAFT_CRUISE)
	to_chat(user, SPAN_NOTICE("You climb to cruising height, above the rooftops."))
	return TRUE

/obj/structure/vehicleparts/axis/aircraft/proc/descend(mob/user)
	if (flight_state == AIRCRAFT_GROUND)
		to_chat(user, SPAN_WARNING("You are already on the ground."))
		return FALSE
	if (flight_state == AIRCRAFT_CRUISE)
		var/hit = clear_at_level(flight_z())
		if (hit)
			to_chat(user, SPAN_WARNING("You can't descend here, [hit] is right below you."))
			return FALSE
		set_flight_state(AIRCRAFT_LOW)
		to_chat(user, SPAN_NOTICE("You descend to low flight."))
		return TRUE
	var/down = multiz_level_below(flight_z())
	if (!down)
		to_chat(user, SPAN_WARNING("There is no ground below to land on."))
		return FALSE
	var/runway = runway_share(down) >= AIRCRAFT_LANDING_RUNWAY_SHARE
	var/hit = clear_at_level(down)
	var/rough = !runway && !hit && rough_ground_below(down)
	if (rough && currentspeed <= landing_gear)
		return rough_landing(down)
	if (rough)
		to_chat(user, SPAN_WARNING("Too fast to land: slow to gear [landing_gear] or lower first."))
		return FALSE
	if (runway && !hit && currentspeed <= landing_gear)
		if (!aircraft_shift(down))
			return FALSE
		set_flight_state(AIRCRAFT_GROUND)
		currentspeed = min(currentspeed, 1)
		visible_message(SPAN_NOTICE("\The [src] touches down on the runway."))
		if (on_arresting_wires())
			currentspeed = 0
			moving = FALSE
			visible_message(SPAN_NOTICE("\The [src]'s tailhook catches the arresting wire and it jerks to a halt."))
		return TRUE
	if (runway && !hit)
		to_chat(user, SPAN_WARNING("Too fast to land: slow to gear [landing_gear] or lower first."))
		return FALSE
	if (force_landing_until && world.time <= force_landing_until)
		force_landing_until = 0
		crash_land(runway ? "a hard landing" : "a crash landing")
		return TRUE
	force_landing_until = world.time + AIRCRAFT_FORCE_LANDING_WINDOW
	to_chat(user, SPAN_DANGER("[hit ? "[hit] is in the way below" : "There is no runway or dry open ground below"]. Descend again within five seconds to force a crash landing."))
	return FALSE

// Down to the level below, broken and stopped. The aircraft comes down on the
// nearest clear ground; with nothing clear nearby it breaks up (wreck()).
/obj/structure/vehicleparts/axis/aircraft/proc/crash_land(reason = "a crash")
	if (!airborne())
		return FALSE
	var/down = multiz_level_below(flight_z())
	var/list/offset = down ? clear_footprint_offset(down) : null
	if (down && !offset)
		return wreck(reason)
	if (down)
		aircraft_shift(down, offset[1], offset[2])
	set_flight_state(AIRCRAFT_GROUND)
	moving = FALSE
	currentspeed = 0
	if (engine)
		engine.on = FALSE
		engine.update_icon()
	for (var/obj/structure/vehicleparts/movement/W in wheels)
		W.broken = TRUE
		W.update_icon()
	for (var/mob/living/M in crew())
		M.adjustBruteLoss(rand(10, 25))
		to_chat(M, SPAN_DANGER("\The [src] comes down in [reason]!"))
	visible_message(SPAN_DANGER("\The [src] comes down in [reason]!"))
	playsound(get_turf(src), 'sound/effects/bang.ogg', 70, TRUE)
	return TRUE

// No clear ground within reach: the airframe breaks up over whatever is
// below. The crew and cargo fall to the ground, hurt; the frames become
// debris on the clear tiles under the footprint, and the rest is lost.
/obj/structure/vehicleparts/axis/aircraft/proc/wreck(reason = "a crash")
	var/down = multiz_level_below(flight_z())
	add_transporting(FALSE)
	var/list/F = frames()
	var/turf/here = get_turf(src)
	visible_message(SPAN_DANGER("\The [src] breaks up in [reason]!"))
	if (here)
		playsound(here, 'sound/effects/bang.ogg', 90, TRUE)
	for (var/atom/movable/M in transporting)
		if (QDELETED(M) || (M in components))
			continue
		var/turf/T = down ? locate(M.x, M.y, down) : null
		if (T && !T.density)
			M.forceMove(T)
		if (isliving(M))
			var/mob/living/L = M
			L.adjustBruteLoss(rand(30, 60))
			L.Weaken(5)
			to_chat(L, SPAN_DANGER("\The [src] breaks up in [reason] and you fall!"))
	for (var/obj/structure/vehicleparts/frame/FR in F)
		var/turf/T = down ? locate(FR.x, FR.y, down) : null
		if (T && !T.density && !(locate(/obj/structure) in T))
			new /obj/structure/barricade/debris(T)
	set_flight_state(AIRCRAFT_GROUND)
	moving = FALSE
	currentspeed = 0
	for (var/atom/movable/C in components.Copy())
		if (C != src)
			qdel(C)
	qdel(src)
	return TRUE

// While airborne: no lift for a few seconds means a stall and a crash. One
// addtimer step per second; flight fuel burns here too.
/obj/structure/vehicleparts/axis/aircraft/proc/flight_watch()
	if (flight_watching)
		return
	flight_watching = TRUE
	addtimer(CALLBACK(src, PROC_REF(flight_watch_tick)), 1 SECOND)

/obj/structure/vehicleparts/axis/aircraft/proc/flight_watch_tick()
	if (QDELETED(src) || !airborne())
		flight_watching = FALSE
		return
	burn_flight_fuel()
	if (!moving || edge_blocked || currentspeed < stall_gear || !check_engine())
		stall_seconds++
		if (stall_seconds == 1)
			pilot_message(SPAN_DANGER("The aircraft is losing lift! Throttle up!"))
		if (stall_seconds >= AIRCRAFT_STALL_SECONDS)
			flight_watching = FALSE
			crash_land("a stall")
			return
	else
		stall_seconds = 0
	addtimer(CALLBACK(src, PROC_REF(flight_watch_tick)), 1 SECOND)

// Staying in the air costs more than rolling: a second of flight burns an
// extra share of the engine's full-load consumption from its tank.
/obj/structure/vehicleparts/axis/aircraft/proc/burn_flight_fuel()
	if (!engine || !engine.on || !engine.fueltank || !engine.fueltank.reagents)
		return 0
	var/obj/structure/engine/internal/E = engine
	if (!istype(E))
		return 0
	var/share = flight_state == AIRCRAFT_CRUISE ? AIRCRAFT_FLIGHT_BURN_CRUISE : AIRCRAFT_FLIGHT_BURN_LOW
	var/amount = E.fuelefficiency * AIRCRAFT_FUEL_MODIFIER * share
	for (var/F in E.fuels)
		if (E.fueltank.reagents.has_reagent(F, amount))
			E.fueltank.reagents.remove_reagent(F, amount)
			return amount
	return 0

/obj/structure/vehicleparts/axis/aircraft/do_vehicle_check()
	if (!airborne())
		if (deck_edge_ahead())
			pilot_message(SPAN_WARNING("The deck ends here: the crash barrier stops the plane."))
			moving = FALSE
			currentspeed = 0
			stopmovementloop()
			return FALSE
		return ..()
	if (!check_engine() || currentspeed < stall_gear)
		return FALSE
	var/m_dir = reverse ? OPPOSITE_DIR(dir) : dir
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/T = get_step(F.loc, m_dir)
		// The black ring wall of a bounded flight level is an edge too, at both heights.
		if (!T || istype(T, /turf/wall/indestructable/black))
			if (!edge_blocked)
				pilot_message(SPAN_WARNING("You are at the edge of the world. Turn back or you will stall."))
			edge_blocked = TRUE
			return FALSE
		if (flight_state == AIRCRAFT_CRUISE)
			continue
		var/hit = obstacle_at(T)
		if (hit)
			crash_land("a collision with [hit]")
			return FALSE
	edge_blocked = FALSE
	return TRUE

// The parent loop stops on a broken wheel; in the air the gear is tucked away,
// and a blocked step (the map edge) holds course instead of stopping dead.
/obj/structure/vehicleparts/axis/aircraft/movementloop()
	if (!moving || movement_processes)
		return
	get_weight()
	movement_processes++
	var/airborne_now = airborne()
	if (do_vehicle_check() && currentspeed > 0)
		if (!airborne_now)
			for (var/obj/structure/vehicleparts/movement/W in wheels)
				if (W.broken)
					pilot_message(SPAN_WARNING("The landing gear is broken. Weld any part of the airframe to fix it."))
					moving = FALSE
					movement_processes--
					stopmovementloop()
					return
				W.update_icon()
		do_move()
		after_aircraft_move()
	else if (!airborne() || !moving)
		currentspeed = airborne() ? currentspeed : 0
		moving = FALSE
		movement_processes--
		if (!airborne())
			stopmovementloop()
		return
	addtimer(CALLBACK(src, PROC_REF(next_aircraft_move)), vehicle_m_delay+1)

/obj/structure/vehicleparts/axis/aircraft/proc/next_aircraft_move()
	movement_processes--
	movementloop()

/obj/structure/vehicleparts/axis/aircraft/proc/after_aircraft_move()
	if (airborne())
		update_flight_visuals()
		return
	if (currentspeed >= speeds && !reverse)
		runway_roll++
		if (runway_roll >= takeoff_distance())
			try_takeoff()
	else
		runway_roll = 0

// Full-throttle tiles needed to lift off from where the aircraft is now.
/obj/structure/vehicleparts/axis/aircraft/proc/takeoff_distance()
	return on_runway() ? takeoff_roll : rough_takeoff_roll

// Any frame standing on arresting wires catches the hook.
/obj/structure/vehicleparts/axis/aircraft/proc/on_arresting_wires()
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/T = get_turf(F)
		if (T && T.arrests_aircraft())
			return TRUE
	return FALSE

// On a deck, the step that would take a frame off it is stopped by the
// crash barrier at the deck's edge rather than rolled into the sea.
/obj/structure/vehicleparts/axis/aircraft/proc/deck_edge_ahead()
	var/m_dir = reverse ? OPPOSITE_DIR(dir) : dir
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/here = get_turf(F)
		if (!here || !here.aircraft_deck())
			continue
		var/turf/next = get_step(here, m_dir)
		if (!next || !next.aircraft_deck())
			return TRUE
	return FALSE

#undef AIRCRAFT_FUEL_MODIFIER
#undef AIRCRAFT_FLIGHT_BURN_CRUISE
#undef AIRCRAFT_FLIGHT_BURN_LOW
#undef AIRCRAFT_CRASH_SEARCH
#undef AIRCRAFT_LANDING_RUNWAY_SHARE
#undef AIRCRAFT_FORCE_LANDING_WINDOW
#undef AIRCRAFT_STALL_SECONDS
