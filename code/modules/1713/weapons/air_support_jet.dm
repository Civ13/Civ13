// ============================================================
// Air support you can see
// ------------------------------------------------------------
// A called-in airstrike (turf/try_airstrike) used to be only a sound and a
// chat line. This draws the jet itself: it crosses the map along the attack
// direction, high above roofs and trees, with its shadow on the ground, and
// passes the release point just as the payload leaves it. Rockets leave a
// short smoke trail on their way in.
//
// Appearance only: nothing here decides whether a strike happens, where the
// payload lands or what it hits. Aircraft without art fly unseen as before.
// ============================================================

#define AIR_SUPPORT_JET_STEP 3          // Tiles per step.
#define AIR_SUPPORT_JET_STEP_TIME 2     // Ticks per step (15 tiles a second).
#define AIR_SUPPORT_JET_ALTITUDE 96     // How far above its shadow the jet is drawn, in pixels.
#define AIR_SUPPORT_JET_SHADOW_SHIFT 24 // The sun puts the shadow a little to the side.
#define AIR_SUPPORT_RELEASE_LEAD 12     // Payloads leave the jet this many tiles short of the target (turf/airstrike).
#define AIR_SUPPORT_JET_OVERRUN 30      // Tiles flown past the target before the jet leaves.

// The aircraft.dmi state drawn for an aircraft, or null when it has no art.
/proc/air_support_jet_state(aircraft_name)
	switch (aircraft_name)
		if ("F-16")
			return "f16"
		if ("Su-25")
			return "su25"
	return null

// Tiles the jet travels before it reaches the release point, when the
// payload leaves it in release_in ticks.
/proc/air_support_jet_lead(release_in)
	return AIR_SUPPORT_RELEASE_LEAD + round(max(release_in, 0) / AIR_SUPPORT_JET_STEP_TIME) * AIR_SUPPORT_JET_STEP

// Sends a visible jet over target heading in direction ("NORTH", "EAST"...),
// timed so that it reaches the release point in release_in ticks.
// Returns the jet, or null when the aircraft has no art or the call is bad.
/proc/air_support_jet_pass(turf/target, direction, aircraft_name, release_in)
	var/state = air_support_jet_state(aircraft_name)
	var/heading = text2dir(direction)
	if (!state || !istype(target) || !(heading in cardinal))
		return null
	var/obj/effect/air_support_jet/J = new
	J.plan(target, heading, state, release_in)
	return J

/obj/effect/air_support_jet
	name = "jet"
	icon = 'icons/obj/vehicles/aircraft.dmi'
	icon_state = "f16"
	mouse_opacity = 0
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	should_save = FALSE
	// Above the game plane, so roofs and tree canopies never hide it.
	plane = ROOF_PLANE
	layer = 20
	pixel_x = -128
	pixel_y = -128 + AIR_SUPPORT_JET_ALTITUDE
	var/head_x = 0
	var/head_y = 0
	var/steps_left = 0
	var/turf/start_turf
	var/obj/effect/air_support_jet_shadow/shadow
	var/tmp/fly_timer
	var/tmp/launch_timer

/obj/effect/air_support_jet_shadow
	name = "shadow"
	icon = 'icons/obj/vehicles/aircraft.dmi'
	mouse_opacity = 0
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	should_save = FALSE
	color = "#000000"
	alpha = 70
	plane = FLOOR_PLANE
	layer = TURF_LAYER + 0.06
	pixel_x = -128 + AIR_SUPPORT_JET_SHADOW_SHIFT
	pixel_y = -128 - AIR_SUPPORT_JET_SHADOW_SHIFT

// Works out where the jet starts and how long it flies. A start point beyond
// the map edge becomes a later launch from the edge, so the timing holds.
/obj/effect/air_support_jet/proc/plan(turf/target, heading, state, release_in)
	icon_state = state
	dir = heading
	head_x = (heading == EAST) - (heading == WEST)
	head_y = (heading == NORTH) - (heading == SOUTH)
	var/lead = air_support_jet_lead(release_in)
	var/room = air_support_room(target, -head_x, -head_y, lead)
	var/delay = round((lead - room) / AIR_SUPPORT_JET_STEP) * AIR_SUPPORT_JET_STEP_TIME
	start_turf = locate(target.x - head_x * room, target.y - head_y * room, target.z)
	var/total = room + air_support_room(target, head_x, head_y, AIR_SUPPORT_JET_OVERRUN)
	steps_left = max(1, round(total / AIR_SUPPORT_JET_STEP))
	if (delay > 0)
		launch_timer = addtimer(CALLBACK(src, PROC_REF(launch)), delay, TIMER_STOPPABLE)
	else
		launch()

// Tiles available from T in direction (sx, sy), up to want, inside the map.
/proc/air_support_room(turf/T, sx, sy, want)
	var/room = want
	if (sx > 0)
		room = min(room, world.maxx - T.x)
	else if (sx < 0)
		room = min(room, T.x - 1)
	if (sy > 0)
		room = min(room, world.maxy - T.y)
	else if (sy < 0)
		room = min(room, T.y - 1)
	return max(room, 0)

/obj/effect/air_support_jet/proc/launch()
	launch_timer = null
	if (QDELETED(src) || !start_turf)
		return
	forceMove(start_turf)
	shadow = new(start_turf)
	shadow.icon_state = icon_state
	shadow.dir = dir
	fly_timer = addtimer(CALLBACK(src, PROC_REF(fly)), AIR_SUPPORT_JET_STEP_TIME, TIMER_LOOP | TIMER_STOPPABLE)

// One step: move a few tiles and draw it as one smooth slide.
/obj/effect/air_support_jet/proc/fly()
	if (QDELETED(src))
		return
	var/turf/here = get_turf(src)
	if (!here || steps_left <= 0)
		qdel(src)
		return
	steps_left--
	var/turf/next = locate(here.x + head_x * AIR_SUPPORT_JET_STEP, here.y + head_y * AIR_SUPPORT_JET_STEP, here.z)
	if (!next)
		qdel(src)
		return
	forceMove(next)
	glide_slide(src, head_x * AIR_SUPPORT_JET_STEP, head_y * AIR_SUPPORT_JET_STEP, AIR_SUPPORT_JET_STEP_TIME)
	if (shadow)
		shadow.forceMove(next)
		glide_slide(shadow, head_x * AIR_SUPPORT_JET_STEP, head_y * AIR_SUPPORT_JET_STEP, AIR_SUPPORT_JET_STEP_TIME)

/obj/effect/air_support_jet/Destroy()
	if (fly_timer)
		deltimer(fly_timer)
		fly_timer = null
	if (launch_timer)
		deltimer(launch_timer)
		launch_timer = null
	if (shadow)
		qdel(shadow)
		shadow = null
	start_turf = null
	return ..()

// ------------------------------------------------------------
// Rocket smoke trail
// ------------------------------------------------------------

#define AIR_SUPPORT_TRAIL_PUFFS 6   // Puffs left along a rocket's path.
#define AIR_SUPPORT_TRAIL_FADE 12   // Ticks a puff takes to fade.

/obj/effect/air_support_smoke
	name = "smoke"
	icon = 'icons/effects/96x96.dmi'
	icon_state = "smoke"
	mouse_opacity = 0
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	should_save = FALSE
	plane = ROOF_PLANE
	layer = 19
	pixel_x = -32
	pixel_y = -32
	alpha = 150

/obj/effect/air_support_smoke/New(loc, px = 0, py = 0)
	..()
	pixel_x += px
	pixel_y += py
	var/matrix/M = matrix()
	M.Scale(0.35)
	transform = M
	animate(src, alpha = 0, transform = matrix() * 0.6, time = AIR_SUPPORT_TRAIL_FADE)
	QDEL_IN(src, AIR_SUPPORT_TRAIL_FADE)

// Leaves puffs along a rocket's path from its start offset (sx, sy, in
// pixels) to its target turf T, as the rocket covers it in time ticks.
/proc/air_support_smoke_trail(turf/T, sx, sy, time)
	if (!istype(T))
		return
	for (var/i = 1 to AIR_SUPPORT_TRAIL_PUFFS)
		var/at = round(time * (i - 1) / AIR_SUPPORT_TRAIL_PUFFS)
		var/left = 1 - (i - 1) / AIR_SUPPORT_TRAIL_PUFFS
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(air_support_smoke_puff), T, round(sx * left), round(sy * left)), max(at, 1))

// One puff at offset (px, py) pixels from T, placed on the nearest turf so it
// is drawn wherever that part of the path is in view.
/proc/air_support_smoke_puff(turf/T, px, py)
	if (!istype(T))
		return
	var/tx = round(px / world.icon_size)
	var/ty = round(py / world.icon_size)
	var/turf/at = locate(clamp(T.x + tx, 1, world.maxx), clamp(T.y + ty, 1, world.maxy), T.z)
	if (!at)
		return
	new /obj/effect/air_support_smoke(at, px - (at.x - T.x) * world.icon_size, py - (at.y - T.y) * world.icon_size)

#undef AIR_SUPPORT_TRAIL_PUFFS
#undef AIR_SUPPORT_TRAIL_FADE
