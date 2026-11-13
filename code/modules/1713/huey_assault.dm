// ============================================================
// Huey air assault
// ------------------------------------------------------------
// On the Vietnam maps a UH-1 "slick" waits on a pad at the American base.
// Soldiers climb aboard, the pilot is given a landing zone (a soldier on the
// ground pops signal smoke, or a passenger picks a part of the map), and the
// Huey lifts off, flies there over roofs and treetops, settles, puts the
// squad out and flies home for the next one.
//
// The Huey cannot be shot down; it only carries people.
// ============================================================

#define HUEY_SEATS 8
#define HUEY_STEP 2               // Tiles per flight step.
#define HUEY_STEP_TIME 2          // Ticks per step (10 tiles a second).
#define HUEY_ALTITUDE 72          // Pixels above its shadow in flight.
#define HUEY_CLIMB_TIME 20        // Ticks to lift off or settle.
#define HUEY_LIFT_DELAY 150       // Ticks from "lift off" to wheels up.
#define HUEY_UNLOAD_TIME 30       // Ticks on the ground at the LZ.
#define HUEY_SHADOW_SHIFT 20

#define HUEY_PARKED "parked"
#define HUEY_BOARDING "boarding"  // Lift-off called, counting down.
#define HUEY_OUTBOUND "outbound"
#define HUEY_AT_LZ "at_lz"
#define HUEY_RETURNING "returning"

var/global/list/hueys = list()

// The maps the Huey flies on.
/proc/huey_map()
	return map && (map.ID in list(MAP_HUE, MAP_ROAD_TO_DAK_TO, MAP_ONG_THAHN, MAP_COMPOUND))

/obj/structure/huey
	name = "UH-1 Huey"
	desc = "A Bell UH-1 \"slick\": door gunners at the open cargo doors and room for a squad. Climb aboard and the pilot takes you to the landing zone."
	icon = 'icons/obj/vehicles/huey.dmi'
	icon_state = "uh1_landed"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	should_save = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = MOB_LAYER + 2
	pixel_x = -128
	pixel_y = -128
	var/faction = AMERICAN
	var/state = HUEY_PARKED
	var/turf/home
	var/turf/lz
	var/lz_name = ""
	var/list/passengers = list()
	var/obj/effect/huey_shadow/shadow
	var/tmp/fly_timer
	var/tmp/turf/flying_to
	var/tmp/turf/bound_for       // The LZ of the lift in the air.

/obj/effect/huey_shadow
	name = "shadow"
	icon = 'icons/obj/vehicles/huey.dmi'
	icon_state = "uh1_shadow"
	mouse_opacity = 0
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	should_save = FALSE
	plane = FLOOR_PLANE
	layer = TURF_LAYER + 0.06
	pixel_x = -128 + HUEY_SHADOW_SHIFT
	pixel_y = -128 - HUEY_SHADOW_SHIFT

/obj/structure/huey/New()
	..()
	hueys += src
	home = get_turf(src)
	update_icon()

/obj/structure/huey/Destroy()
	hueys -= src
	if (fly_timer)
		deltimer(fly_timer)
		fly_timer = null
	unload(get_turf(src))
	if (shadow)
		qdel(shadow)
		shadow = null
	home = null
	lz = null
	bound_for = null
	flying_to = null
	return ..()

/obj/structure/huey/update_icon()
	overlays.Cut()
	if (state == HUEY_PARKED && !passengers.len)
		icon_state = "uh1_landed"
		return
	icon_state = "uh1"
	overlays += image(icon, "uh1_tailrotor")
	overlays += image(icon, "uh1_rotor")

/obj/structure/huey/proc/airborne()
	return state == HUEY_OUTBOUND || state == HUEY_RETURNING

/obj/structure/huey/examine(mob/user)
	..()
	to_chat(user, status_text())

/obj/structure/huey/proc/status_text()
	var/where = lz ? "Landing zone: [lz_name]." : "No landing zone yet: pop signal smoke on the ground, or climb in and pick one."
	return "[passengers.len] of [HUEY_SEATS] seats taken. [where]"

/obj/structure/huey/attack_hand(mob/living/human/H)
	if (!istype(H) || H.stat || H.restrained() || get_dist(H, src) > 2)
		return
	if (H.faction_text != faction)
		to_chat(H, SPAN_WARNING("The door gunner waves you off with his M60."))
		return
	if (state != HUEY_PARKED && state != HUEY_BOARDING)
		to_chat(H, SPAN_WARNING("The Huey is not on the ground for you."))
		return
	board(H)

/obj/structure/huey/proc/board(mob/living/human/H)
	if (H in passengers)
		return FALSE
	if (passengers.len >= HUEY_SEATS)
		to_chat(H, SPAN_WARNING("Every seat is taken. Wait for the next lift."))
		return FALSE
	if (H.buckled)
		H.buckled.unbuckle_mob()
	H.stop_pulling()
	H.forceMove(src)
	passengers += H
	visible_message(SPAN_NOTICE("[H] climbs aboard \the [src]."))
	to_chat(H, SPAN_NOTICE("You strap in by the door gunner. [status_text()] <a href='byond://?src=\ref[src];pilot=1'>Talk to the pilot</a>."))
	update_icon()
	if (lz && state == HUEY_PARKED)
		call_lift()
	return TRUE

/obj/structure/huey/Topic(href, href_list)
	if (!href_list["pilot"])
		return ..()
	var/mob/living/human/H = usr
	if (!istype(H) || !(H in passengers) || H.loc != src)
		return
	pilot_menu(H)

/obj/structure/huey/proc/pilot_menu(mob/living/human/H)
	var/list/options = list()
	if (state == HUEY_PARKED || state == HUEY_BOARDING)
		if (lz && state == HUEY_PARKED)
			options += "Lift off for [lz_name]"
		options += "Choose a landing zone"
		options += "Get out"
	options += "Cancel"
	var/choice = WWinput(H, status_text(), name, "Cancel", options)
	if (!choice || choice == "Cancel" || !(H in passengers))
		return
	if (choice == "Get out")
		if (state == HUEY_PARKED || state == HUEY_BOARDING)
			drop_off(H, get_turf(src))
		return
	if (choice == "Choose a landing zone")
		var/list/zones = huey_zones()
		if (!zones.len)
			to_chat(H, SPAN_WARNING("The pilot shakes his head: there is nowhere clear to set down."))
			return
		var/pick = WWinput(H, "Where should the pilot set you down?", name, "Cancel", zones + list("Cancel"))
		if (!pick || pick == "Cancel" || !zones[pick] || !(H in passengers) || airborne())
			return
		set_lz(zones[pick], "the [lowertext(pick)] of the map")
		call_lift()
		return
	if (findtext(choice, "Lift off") == 1)
		call_lift()

/obj/structure/huey/proc/set_lz(turf/T, where)
	lz = T
	lz_name = where
	crew_message(SPAN_NOTICE("The pilot: \"Landing zone is [where]. Hang on.\""))

/obj/structure/huey/proc/crew_message(text)
	for (var/mob/M in passengers)
		to_chat(M, text)

// Wheels up after HUEY_LIFT_DELAY, giving the rest of the squad time to run for it.
/obj/structure/huey/proc/call_lift()
	if (state != HUEY_PARKED || !lz || !passengers.len)
		return FALSE
	if (map && !map.game_really_started())
		crew_message(SPAN_WARNING("The pilot: \"We don't fly until the battle starts.\""))
		return FALSE
	state = HUEY_BOARDING
	update_icon()
	playsound(get_turf(src), 'sound/effects/aircraft/uh1.ogg', 100, TRUE, extrarange = 30)
	visible_message(SPAN_DANGER("The Huey's rotors spool up. Lifting off in [HUEY_LIFT_DELAY / 10] seconds: get aboard!"))
	fly_timer = addtimer(CALLBACK(src, PROC_REF(lift_off)), HUEY_LIFT_DELAY, TIMER_STOPPABLE)
	return TRUE

/obj/structure/huey/proc/lift_off()
	fly_timer = null
	if (QDELETED(src) || state != HUEY_BOARDING)
		return FALSE
	if (!passengers.len || !lz)
		state = HUEY_PARKED
		update_icon()
		return FALSE
	state = HUEY_OUTBOUND
	bound_for = lz
	take_air()
	fly_to(lz)
	return TRUE

/obj/structure/huey/proc/take_air()
	update_icon()
	plane = ROOF_PLANE
	layer = 21
	mouse_opacity = 0
	if (!shadow)
		shadow = new(get_turf(src))
	shadow.dir = dir
	animate(src, pixel_y = -128 + HUEY_ALTITUDE, time = HUEY_CLIMB_TIME)
	playsound(get_turf(src), 'sound/effects/aircraft/uh1.ogg', 100, TRUE, extrarange = 70)

/obj/structure/huey/proc/settle()
	animate(src, pixel_y = -128, time = HUEY_CLIMB_TIME)
	if (shadow)
		qdel(shadow)
		shadow = null

/obj/structure/huey/proc/fly_to(turf/T)
	flying_to = T
	if (fly_timer)
		deltimer(fly_timer)
	fly_timer = addtimer(CALLBACK(src, PROC_REF(fly)), HUEY_CLIMB_TIME, TIMER_STOPPABLE)

// One step towards flying_to, drawn as one smooth slide.
/obj/structure/huey/proc/fly()
	fly_timer = null
	if (QDELETED(src) || !flying_to)
		return
	var/turf/here = get_turf(src)
	var/dx = flying_to.x - here.x
	var/dy = flying_to.y - here.y
	if (!dx && !dy)
		arrive()
		return
	var/sx = clamp(dx, -HUEY_STEP, HUEY_STEP)
	var/sy = clamp(dy, -HUEY_STEP, HUEY_STEP)
	dir = abs(dx) >= abs(dy) ? (dx > 0 ? EAST : WEST) : (dy > 0 ? NORTH : SOUTH)
	var/turf/next = locate(here.x + sx, here.y + sy, here.z)
	if (!next)
		arrive()
		return
	forceMove(next)
	glide_slide(src, sx, sy, HUEY_STEP_TIME)
	if (shadow)
		shadow.dir = dir
		shadow.forceMove(next)
		glide_slide(shadow, sx, sy, HUEY_STEP_TIME)
	fly_timer = addtimer(CALLBACK(src, PROC_REF(fly)), HUEY_STEP_TIME, TIMER_STOPPABLE)

/obj/structure/huey/proc/arrive()
	flying_to = null
	settle()
	if (state == HUEY_OUTBOUND)
		state = HUEY_AT_LZ
		fly_timer = addtimer(CALLBACK(src, PROC_REF(touch_down)), HUEY_CLIMB_TIME, TIMER_STOPPABLE)
	else
		fly_timer = addtimer(CALLBACK(src, PROC_REF(park)), HUEY_CLIMB_TIME, TIMER_STOPPABLE)

// On the ground at the LZ: everyone out, then home.
/obj/structure/huey/proc/touch_down()
	fly_timer = null
	plane = initial(plane)
	layer = initial(layer)
	visible_message(SPAN_DANGER("The Huey flares and settles. The door gunner yells: \"Go! Go! Go!\""))
	unload(get_turf(src))
	// A new smoke popped during the flight stays for the next lift.
	if (lz == bound_for)
		lz = null
		lz_name = ""
	bound_for = null
	fly_timer = addtimer(CALLBACK(src, PROC_REF(head_home)), HUEY_UNLOAD_TIME, TIMER_STOPPABLE)

/obj/structure/huey/proc/head_home()
	fly_timer = null
	if (QDELETED(src))
		return
	state = HUEY_RETURNING
	take_air()
	fly_to(home)

/obj/structure/huey/proc/park()
	fly_timer = null
	state = HUEY_PARKED
	plane = initial(plane)
	layer = initial(layer)
	mouse_opacity = initial(mouse_opacity)
	unload(get_turf(src))
	update_icon()
	// A smoke popped while she was away is waiting for the next lift.
	if (lz)
		visible_message(SPAN_NOTICE("The Huey is back. Climb aboard for [lz_name]."))

/obj/structure/huey/proc/unload(turf/T)
	for (var/mob/living/human/H in passengers.Copy())
		drop_off(H, T)

/obj/structure/huey/proc/drop_off(mob/living/human/H, turf/T)
	passengers -= H
	if (QDELETED(H) || H.loc != src)
		update_icon()
		return
	var/list/spots = huey_clear_turfs(T, 2)
	H.forceMove(spots.len ? pick(spots) : T)
	update_icon()

// Turfs a soldier can stand on within r of T.
/proc/huey_clear_turfs(turf/T, r)
	. = list()
	if (!T)
		return
	for (var/turf/D in range(r, T))
		if (huey_turf_clear(D))
			. += D

/proc/huey_turf_clear(turf/D)
	if (!D || D.density || istype(D, /turf/floor/beach/water/deep))
		return FALSE
	for (var/obj/O in D)
		if (O.density)
			return FALSE
	return TRUE

// A place a Huey can set down: outdoors, clear ground around it.
/proc/huey_can_land(turf/T)
	if (!T || !huey_turf_clear(T))
		return FALSE
	var/area/A = get_area(T)
	if (!A || A.location == AREA_INSIDE)
		return FALSE
	if (map && (A.type in map.caribbean_blocking_area_types))
		return FALSE
	var/clear = 0
	for (var/turf/D in range(1, T))
		if (huey_turf_clear(D))
			clear++
	return clear >= 7

// The nearest landing spot to T within r tiles, or null.
/proc/huey_landing_near(turf/T, r = 12)
	if (!T)
		return null
	if (huey_can_land(T))
		return T
	for (var/d = 1 to r)
		for (var/turf/D in orange(d, T))
			if (get_dist(D, T) == d && huey_can_land(D))
				return D
	return null

// Nine parts of the map, each with a place to set down: list(name = turf).
/proc/huey_zones()
	. = list()
	var/z = 1
	for (var/obj/structure/huey/H in hueys)
		z = H.z
		break
	var/list/rows = list("North" = 0.8, "Centre" = 0.5, "South" = 0.2)
	var/list/cols = list("west" = 0.2, "" = 0.5, "east" = 0.8)
	for (var/r in rows)
		for (var/c in cols)
			var/zone_name = r == "Centre" ? (c ? capitalize(c) : "Centre") : (c ? "[r]-[c]" : r)
			var/turf/T = locate(round(world.maxx * cols[c]), round(world.maxy * rows[r]), z)
			var/turf/L = huey_landing_near(T, 15)
			if (L)
				.[zone_name] = L

// A soldier's signal smoke marks the landing zone for the next lift.
/proc/huey_mark_lz(turf/T, mob/living/human/marker)
	var/obj/structure/huey/H = huey_of(marker ? marker.faction_text : AMERICAN)
	if (!H)
		return FALSE
	var/turf/L = huey_landing_near(T, 6)
	if (!L)
		if (marker)
			to_chat(marker, SPAN_WARNING("There is no clear ground near the smoke for a Huey to set down."))
		return FALSE
	H.set_lz(L, "the smoke at [get_area(L)]")
	for (var/mob/living/human/M in player_list)
		if (M.faction_text == H.faction && M.stat != DEAD)
			to_chat(M, SPAN_NOTICE("<b>Radio:</b> \"Smoke is out. The Huey will set down at the smoke: climb aboard at the pad.\""))
	H.call_lift()
	return TRUE

/proc/huey_of(faction)
	for (var/obj/structure/huey/H in hueys)
		if (H.faction == faction)
			return H
	return null

// Puts the Huey on its pad near the American spawn, once per round.
/proc/huey_deploy()
	if (!huey_map() || huey_of(AMERICAN))
		return null
	var/list/starts = latejoin_turfs ? latejoin_turfs["JoinLateRN"] : null
	if (!starts || !starts.len)
		return null
	var/turf/pad = null
	for (var/turf/S in starts)
		pad = huey_landing_near(S, 25)
		if (pad)
			break
	if (!pad)
		return null
	var/obj/structure/huey/H = new(pad)
	return H

/proc/huey_give_note(mob/living/human/H)
	if (!istype(H) || !huey_map() || H.faction_text != AMERICAN)
		return FALSE
	huey_deploy()
	H.add_note("Huey", "A <b>UH-1 Huey</b> waits on the pad at your base. Click it to climb aboard, then <b>Talk to the pilot</b> to pick a landing zone, or have someone pop <b>signal smoke</b> at the LZ. It sets you down and flies back for the next squad.")
	return TRUE

#undef HUEY_SEATS
#undef HUEY_STEP
#undef HUEY_STEP_TIME
#undef HUEY_ALTITUDE
#undef HUEY_CLIMB_TIME
#undef HUEY_LIFT_DELAY
#undef HUEY_UNLOAD_TIME
#undef HUEY_SHADOW_SHIFT
#undef HUEY_PARKED
#undef HUEY_BOARDING
#undef HUEY_OUTBOUND
#undef HUEY_AT_LZ
#undef HUEY_RETURNING
