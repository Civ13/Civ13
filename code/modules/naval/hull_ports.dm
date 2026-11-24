// ============================================================
// Gun ports, barred gates and cargo hatches (docs/vessel-entries.md, phase 4)
// ------------------------------------------------------------
// A gun port is a gate in her side the full height of a deck, for the side of
// a deck with another deck above it. Shut, it is a wall: nobody climbs over
// it and shots do not pass. Open, her guns fire through it and anyone, crew
// or boarder from a boat or the water, comes through it.
//
// Every gate in her side (gangways and gun ports) can be barred from aboard
// her. A barred gate does not open from outside her: someone there can only
// hammer on it for her crew to hear. Unbar it from aboard to open it.
//
// An open gun port on a deck that is awash ships water, HULL_PORT_PER_MINUTE
// for each, until it is shut (step_ports(), called by the ledger's step).
//
// A cargo hatch stands on her main deck over her hold. Open, crates and
// people go down through it to the hold below; shut, it is deck.
// ============================================================

#define HULL_PORT_PER_MINUTE 4
#define HULL_PORT_KNOCK_COOLDOWN (5 SECONDS)
#define HULL_HATCH_CLIMB_TIME (2 SECONDS)
#define HULL_HATCH_LOWER_TIME (3 SECONDS)

/obj/structure/railing/built/gunwale
	// Gates only: TRUE while barred from aboard.
	var/barred = FALSE
	var/tmp/last_knock = -1000

// TRUE when user stands aboard the craft this piece is part of.
/obj/structure/railing/built/gunwale/proc/user_aboard(mob/user)
	var/turf/here = get_turf(user)
	if (!here)
		return FALSE
	if (here == get_turf(src))
		return TRUE
	var/datum/craft/C = craft_holding(get_turf(src))
	return C && craft_holding(here) == C

/obj/structure/railing/built/gunwale/attack_hand(mob/user)
	if (gate && ishuman(user) && Adjacent(user) && user.a_intent != I_GRAB && user.a_intent != I_HARM)
		var/mob/living/human/H = user
		if (H.travel_held())
			return TRUE
		if (barred)
			if (user_aboard(user))
				to_chat(user, SPAN_WARNING("\The [src] is barred. Unbar it first (right-click it)."))
			else
				gate_knock(user)
			return TRUE
	return ..()

/obj/structure/railing/built/gunwale/proc/gate_knock(mob/user)
	to_chat(user, SPAN_WARNING("\The [src] is barred from inside. You hammer on it for her crew."))
	if (world.time < last_knock + HULL_PORT_KNOCK_COOLDOWN)
		return FALSE
	last_knock = world.time
	playsound(loc, 'sound/effects/clang.ogg', 50)
	var/datum/craft/C = craft_holding(get_turf(src))
	if (C)
		C.crew_message(SPAN_WARNING("Someone hammers on \the [src]."))
	return TRUE

// Bars a shut gate or unbars it. Only from aboard.
/obj/structure/railing/built/gunwale/proc/set_barred(state, mob/user)
	if (!gate)
		return FALSE
	if (state && gate_open)
		if (user)
			to_chat(user, SPAN_WARNING("Shut \the [src] first."))
		return FALSE
	barred = !!state
	playsound(loc, 'sound/effects/door_lock_unlock.ogg', 40)
	if (user)
		user.visible_message(SPAN_NOTICE("[user] [barred ? "bars" : "unbars"] \the [src]."))
	return TRUE

/obj/structure/railing/built/gunwale/verb/toggle_bar()
	set name = "Bar or Unbar"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || !gate || H.incapacitated() || !Adjacent(H))
		return
	if (!user_aboard(H))
		to_chat(H, SPAN_WARNING("You can only bar or unbar \the [src] from aboard her."))
		return
	set_barred(!barred, H)

/obj/structure/railing/built/gunwale/examine(mob/user)
	. = ..()
	if (gate && barred)
		to_chat(user, SPAN_NOTICE("It is barred from inside."))

// ---- Gun ports ----

/obj/structure/railing/built/gunwale/gun_port
	name = "wooden gun port"
	desc = "A full-height section of a ship's planked side with a hinged port lid. Open it to run out a gun or come aboard; shut and bar it against boarders and the sea."
	icon = 'icons/obj/vessel_openings.dmi'
	icon_state = "gunport_wood_gate"
	railing_style = "gunport_wood"
	gate = TRUE
	health = 200
	maxhealth = 200

/obj/structure/railing/built/gunwale/bulwark/gun_port
	name = "steel gun port"
	desc = "A full-height section of a ship's steel side with a hinged armoured port lid. Open it to run out a gun or come aboard; shut and bar it against boarders and the sea."
	icon = 'icons/obj/vessel_openings.dmi'
	icon_state = "gunport_steel_gate"
	railing_style = "gunport_steel"
	gate = TRUE
	health = 500
	maxhealth = 500

/proc/hull_gun_port(obj/O)
	return istype(O, /obj/structure/railing/built/gunwale/gun_port) || istype(O, /obj/structure/railing/built/gunwale/bulwark/gun_port)

// A shut port is a wall: shots do not pass and nobody climbs over it.
/obj/structure/railing/built/gunwale/gun_port/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (density && istype(mover, /obj/item/projectile) && get_dir(loc, target) == dir)
		return FALSE
	return ..()

/obj/structure/railing/built/gunwale/bulwark/gun_port/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (density && istype(mover, /obj/item/projectile) && get_dir(loc, target) == dir)
		return FALSE
	return ..()

/obj/structure/railing/built/gunwale/gun_port/CheckExit(atom/movable/O, target, exit_direction = null)
	if (density && istype(O, /obj/item/projectile) && get_dir(O.loc, target) == dir)
		return FALSE
	return ..()

/obj/structure/railing/built/gunwale/bulwark/gun_port/CheckExit(atom/movable/O, target, exit_direction = null)
	if (density && istype(O, /obj/item/projectile) && get_dir(O.loc, target) == dir)
		return FALSE
	return ..()

/obj/structure/railing/built/gunwale/gun_port/can_climb(mob/living/user, post_climb_check = 0)
	if (density)
		if (user)
			to_chat(user, SPAN_WARNING("\The [src] is a wall when it is shut. Open it to go through."))
		return FALSE
	return ..()

/obj/structure/railing/built/gunwale/bulwark/gun_port/can_climb(mob/living/user, post_climb_check = 0)
	if (density)
		if (user)
			to_chat(user, SPAN_WARNING("\The [src] is a wall when it is shut. Open it to go through."))
		return FALSE
	return ..()

// The cells of these with an open gun port, one entry per port.
/proc/hull_open_ports(list/cells)
	. = list()
	for (var/turf/T in cells)
		for (var/obj/structure/railing/built/gunwale/G in T)
			if (G.loc == T && G.gate_open && hull_gun_port(G))
				. += T

// Open ports on a deck that is awash ship water into their own compartment,
// past awash like a hole (the ledger's step).
/datum/hull_ledger/proc/step_ports(seconds)
	if (!deck_awash())
		return 0
	var/list/ports = hull_open_ports(craft.body.cells())
	for (var/turf/T in ports)
		add_water(HULL_PORT_PER_MINUTE * seconds / 60, capacity(), T)
	return ports.len

// ---- The cargo hatch ----

/obj/structure/cargo_hatch
	name = "cargo hatch"
	desc = "A hatch in a ship's main deck over her hold, its boards battened down. Open, crates and people go down through it to the hold."
	icon = 'icons/obj/vessel_openings.dmi'
	icon_state = "cargo_hatch"
	anchored = TRUE
	density = FALSE
	layer = TURF_LAYER + 0.2
	var/open = FALSE

/obj/structure/cargo_hatch/update_icon()
	icon_state = open ? "cargo_hatch_open" : "cargo_hatch"

/obj/structure/cargo_hatch/after_load()
	..()
	update_icon()

// The hold floor straight below, or null.
/obj/structure/cargo_hatch/proc/hold_below()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/turf/B = locate(T.x, T.y, multiz_level_below(T.z))
	if (!istype(B, /turf/floor/plating/ship_hold) || B.density)
		return null
	return B

/obj/structure/cargo_hatch/proc/set_open(state)
	open = !!state
	playsound(loc, 'sound/effects/lever.ogg', 40, TRUE)
	update_icon()

/obj/structure/cargo_hatch/attack_hand(mob/living/human/H)
	if (!istype(H) || !Adjacent(H) || H.travel_held())
		return ..()
	if (open && get_turf(H) == get_turf(src))
		climb_down(H)
		return
	set_open(!open)
	H.visible_message(SPAN_NOTICE("[H] [open ? "knocks out the battens and opens" : "lays the boards back on and battens down"] \the [src]."))

/obj/structure/cargo_hatch/proc/climb_down(mob/living/human/H)
	var/turf/B = hold_below()
	if (!B)
		to_chat(H, SPAN_WARNING("There is no hold under \the [src]."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] starts climbing down through \the [src]."))
	if (!do_after(H, HULL_HATCH_CLIMB_TIME, src) || !open || H.travel_held() || get_turf(H) != get_turf(src) || hold_below() != B)
		return FALSE
	H.forceMove(B)
	return TRUE

// An escape path only through an actual opening on the matching commissioned
// hull. Recheck at completion: a ship can move or its hatch can be shut meanwhile.
/obj/structure/cargo_hatch/proc/up_destination(mob/living/human/H)
	if (!open || !H || H.restrained() || H.travel_held())
		return null
	var/turf/T = get_turf(src)
	var/turf/B = hold_below()
	if (!B || !T || T.density || H.loc != B || multiz_level_above(B.z) != T.z)
		return null
	var/datum/hull_ledger/L = hull_ledger_at(T)
	var/datum/craft_body/built/body = L?.craft?.body
	if (!istype(body) || body.z != T.z || !body.contains(T) || !body.carries(B) || !persistence_movement_allowed(H, T))
		return null
	for (var/atom/movable/A in T)
		if (A.density)
			return null
		if (istype(A, /obj/covers))
			var/obj/covers/C = A
			if (C.wall)
				return null
	return T

/obj/structure/cargo_hatch/proc/climb_up(mob/living/human/H)
	var/turf/T = up_destination(H)
	if (!T)
		to_chat(H, SPAN_WARNING("You cannot climb up through \the [src] from here."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] starts climbing up through \the [src]."))
	if (!do_after(H, HULL_HATCH_CLIMB_TIME, src) || QDELETED(src) || up_destination(H) != T)
		return FALSE
	H.forceMove(T)
	return TRUE

// Lowers a crate or anything loose dragged onto the open hatch to the hold.
/obj/structure/cargo_hatch/proc/lower(atom/movable/A, mob/living/human/H)
	var/turf/B = hold_below()
	if (!open || !B || A.anchored || ismob(A))
		return FALSE
	if (H)
		H.visible_message(SPAN_NOTICE("[H] lowers \the [A] down through \the [src]."))
		if (!do_after(H, HULL_HATCH_LOWER_TIME, src) || !open || hold_below() != B || A.anchored || !A.Adjacent(src))
			return FALSE
	A.forceMove(B)
	return TRUE

/obj/structure/cargo_hatch/MouseDrop_T(atom/movable/A, mob/living/human/H)
	if (!istype(H) || !istype(A) || !Adjacent(H) || H.travel_held())
		return ..()
	if (!open)
		to_chat(H, SPAN_WARNING("Open \the [src] first."))
		return
	lower(A, H)

/obj/structure/cargo_hatch/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE("It is [open ? "open: drag crates onto it to lower them, stand on it and click it to climb down, or click the hold floor directly below it to climb up" : "battened down"]."))

#undef HULL_PORT_PER_MINUTE
#undef HULL_PORT_KNOCK_COOLDOWN
#undef HULL_HATCH_CLIMB_TIME
#undef HULL_HATCH_LOWER_TIME
