// Fire doors and fire behaviour of doors (Val, 2026-11-16).
//
// A fire door is a complete assembly, not a door that waits for a fire: a rated
// leaf in a frame set in a masonry wall, a closer that can't be taken off, a
// latch that catches whenever it shuts, and edge seals. It is shut at all times
// and closes itself after every passage. It only counts as fire-rated while the
// whole assembly is intact: shut, closer fitted, seals whole, not wedged, and
// set between masonry, stone, brick or concrete walls. A rated door stops fire
// crossing it and takes only a small share of the heat until its minutes run
// out; then it burns like its material. A fusible link may hold it open: the
// link melts when fire comes within two tiles and the door swings shut.
// Any door can also take a panic bar on its inner side, which opens it from
// that side even when it is locked or bolted.
// Ordinary doors now burn by material: wood burns, stone and metal barely do.

#define FIRE_RATING_IRON 18000		// ds: 30 minutes
#define FIRE_RATING_STEEL 36000		// ds: 60 minutes
#define FIRE_EXPOSURE_TICK 50		// ds of rating spent per fire tick next to it

/obj/structure/simple_door
	var/panic_bar_side = 0			// the side a panic bar is fitted on
	var/fire_link_holding = FALSE	// a fusible link holds the door open

/obj/structure/simple_door/key_door/anyone/fire_door
	name = "iron-clad fire"
	desc = "A heavy timber door sheathed in iron, hung in a rated frame with a closer, a latch and edge seals. It shuts itself after every passage. Set in a masonry wall and kept whole, it holds back fire for half an hour."
	icon = 'icons/obj/doors/fire_doors.dmi'
	icon_state = "firedoor_iron"
	material = "iron"
	unique_door_name = "fire"
	override_material = TRUE
	door_closer = "spring"
	var/fire_rating_full = FIRE_RATING_IRON
	var/fire_rating_left = FIRE_RATING_IRON
	var/fire_heat_share = 0.1			// share of fire damage it takes while rated
	var/fire_seals_intact = TRUE

/obj/structure/simple_door/key_door/anyone/fire_door/steel
	name = "steel fire"
	desc = "A steel fire door with a mineral core and a wired-glass vision panel, hung in a rated frame with a closer, a latch and edge seals. It shuts itself after every passage. Set in a masonry wall and kept whole, it holds back fire for an hour."
	icon_state = "firedoor_steel"
	material = "steel"
	fire_rating_full = FIRE_RATING_STEEL
	fire_rating_left = FIRE_RATING_STEEL
	fire_heat_share = 0.05

/obj/structure/simple_door/key_door/anyone/fire_door/New(_loc, _material = null)
	..(_loc, initial(material))
	basic_icon = initial(icon_state)
	if (!door_closer)
		door_closer = "spring"

// ---- the rating -------------------------------------------------------------------

/obj/structure/simple_door/proc/is_fire_door()
	return FALSE

/obj/structure/simple_door/key_door/anyone/fire_door/is_fire_door()
	return TRUE

// A wall that keeps fire out: masonry, stone, brick, concrete or metal.
/proc/fire_rated_wall(turf/T)
	if (!T)
		return FALSE
	if (istype(T, /turf/wall))
		return !istype(T, /turf/wall/wood)
	for (var/obj/covers/C in T)
		if (C.wall && !C.incomplete && structure_material_resistance(C.material) >= 2.5)
			return TRUE
	return FALSE

// The frame is set in a rated wall on both sides of the doorway.
/obj/structure/simple_door/proc/door_in_rated_wall()
	var/turf/T = get_turf(src)
	if (!T)
		return FALSE
	var/across = turn(door_passage_axis(), 90)
	return fire_rated_wall(get_step(T, across)) && fire_rated_wall(get_step(T, turn(across, 180)))

// Why a fire door is not rated right now, or null when it is.
/obj/structure/simple_door/key_door/anyone/fire_door/proc/fire_rating_fault()
	if (fire_rating_left <= 0)
		return "its rating is spent"
	if (!fire_seals_intact)
		return "its seals are burnt"
	if (!door_closer)
		return "its closer is gone"
	if (door_wedge)
		return "it is wedged open"
	if (state && !fire_link_holding)
		return "it is standing open"
	if (!door_in_rated_wall())
		return "it is not set in a masonry, stone, brick or concrete wall"
	return null

/obj/structure/simple_door/proc/fire_door_rated()
	return FALSE

// Rated only while shut; a door held by its fusible link is rated but open.
/obj/structure/simple_door/key_door/anyone/fire_door/fire_door_rated()
	return !state && !fire_rating_fault()

/obj/structure/simple_door/key_door/anyone/fire_door/examine(mob/user, distance = -1)
	. = ..()
	if (!user || get_dist(user, src) > 3)
		return
	var/fault = fire_rating_fault()
	if (fault)
		to_chat(user, SPAN_WARNING("It is not fire-rated: [fault]."))
	else
		to_chat(user, SPAN_NOTICE("It is fire-rated for [round(fire_rating_left / 600)] minutes[fire_link_holding ? ", held open by a fusible link" : ""]."))

// A tile fire can't spread onto: a shut, rated fire door.
/proc/fire_blocked_at(turf/T)
	if (!T)
		return FALSE
	for (var/obj/structure/simple_door/D in T)
		if (D.fire_door_rated())
			return TRUE
	return FALSE

// ---- fire against doors -----------------------------------------------------------

// The share of a fire's heat a door takes, by what it is made of.
/obj/structure/simple_door/proc/door_fire_share()
	switch (lowertext("[get_material_name()]"))
		if ("wood", "bamboo", "paper", "cloth", "leather", "log", "hide", "thatch")
			return 1
		if ("stone", "sandstone", "marble", "brick", "concrete", "cement")
			return 0.05
	return 0.2

/obj/structure/simple_door/key_door/anyone/fire_door/door_fire_share()
	if (fire_door_rated())
		return fire_heat_share
	return ..()

// Each fire tick beside a rated fire door spends some of its rating; once it
// is spent the seals have burnt away and the door burns like its material.
/obj/structure/simple_door/proc/fire_door_exposure()
	return

/obj/structure/simple_door/key_door/anyone/fire_door/fire_door_exposure()
	if (!fire_door_rated())
		return
	fire_rating_left = max(0, fire_rating_left - FIRE_EXPOSURE_TICK)
	if (fire_rating_left <= 0)
		fire_seals_intact = FALSE
		visible_message(SPAN_DANGER("The seals of \the [src] blacken and fail!"))
		update_fitting_overlays()

// Fire nearby: links within two tiles melt, rated doors next to it spend rating.
/proc/fire_nearby_doors(obj/effect/fire/F)
	for (var/obj/structure/simple_door/D in range(2, F))
		if (D.fire_link_holding)
			D.fire_link_melt()
		if (get_dist(D, F) <= 1)
			D.fire_door_exposure()

// ---- fusible link -------------------------------------------------------------------

/obj/structure/simple_door/proc/fit_fire_link(obj/item/fusible_link/L, mob/living/human/user)
	if (isSwitchingStates)
		to_chat(user, SPAN_WARNING("\The [src] is moving. Wait until it is fully open."))
		return FALSE
	if (!state)
		to_chat(user, SPAN_WARNING("Open \the [src] first: the link holds it open."))
		return FALSE
	if (!door_closer)
		to_chat(user, SPAN_WARNING("\The [src] has no closer for the link to hold back."))
		return FALSE
	if (fire_link_holding || door_wedge)
		to_chat(user, SPAN_WARNING("Something already holds \the [src] open."))
		return FALSE
	fire_link_holding = TRUE
	close_token++
	user.drop_from_inventory(L)
	qdel(L)
	var/obj/item/door_hold/hold = door_held()
	if (hold)
		hold.release(TRUE)
	user.visible_message(SPAN_NOTICE("[user] hooks \the [src] open on a fusible link."), SPAN_NOTICE("You hook the door open on the fusible link. Fire nearby will melt it and let the door shut."))
	update_fitting_overlays()
	return TRUE

/obj/structure/simple_door/proc/unhook_fire_link(mob/living/human/user)
	if (!fire_link_holding)
		return FALSE
	fire_link_holding = FALSE
	var/obj/item/fusible_link/L = new(get_turf(user ? user : src))
	if (user)
		user.put_in_hands(L)
		user.visible_message(SPAN_NOTICE("[user] unhooks the fusible link from \the [src]."), SPAN_NOTICE("You unhook the link and let the door go."))
	update_fitting_overlays()
	door_schedule_close(10)
	return TRUE

/obj/structure/simple_door/proc/fire_link_melt()
	if (!fire_link_holding)
		return
	fire_link_holding = FALSE
	visible_message(SPAN_WARNING("The fusible link on \the [src] melts and the door swings shut!"))
	update_fitting_overlays()
	if (state && !door_doorway_blocked())
		Close()
	else
		door_schedule_close(10)

// ---- panic bar ----------------------------------------------------------------------

// From the panic bar's side, pushing the bar draws that side's bolt and opens
// any lock. Returns TRUE when it released something.
/obj/structure/simple_door/proc/door_panic_release(mob/user)
	if (!panic_bar_side || state || !user || door_side_of(user) != panic_bar_side)
		return FALSE
	. = FALSE
	if (door_bolt_side == panic_bar_side && door_bolt_shot)
		door_bolt_shot = FALSE
		. = TRUE
	if (door_lock && door_lock.kind != "seal" && door_lock.blocks())
		door_lock.locked = FALSE
		if (door_lock.kind == "catch")
			door_lock.learn_catch(user)
		. = TRUE
	if (locked && !istype(src, /obj/structure/simple_door/key_door/faction_door))
		locked = FALSE
		. = TRUE
	if (.)
		playsound(get_turf(src), 'sound/effects/door_lock_unlock.ogg', 60)
		user.visible_message(SPAN_NOTICE("[user] pushes the panic bar of \the [src]."), SPAN_NOTICE("You push the panic bar and the door unlatches."))
		update_fitting_overlays()

/obj/structure/simple_door/proc/fit_panic_bar(obj/item/panic_bar/P, mob/living/human/user)
	var/side = door_side_of(user)
	if (!side)
		to_chat(user, SPAN_WARNING("Stand on the side of \the [src] the bar should go on."))
		return FALSE
	if (panic_bar_side)
		to_chat(user, SPAN_WARNING("\The [src] already has a panic bar."))
		return FALSE
	if (!door_tool_in_hands(user, TOOL_SCREWDRIVER))
		to_chat(user, SPAN_WARNING("Hold a screwdriver in your other hand to fit \the [P]."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts fitting \the [P] to \the [src]."), SPAN_NOTICE("You start fitting the panic bar to your side of \the [src]."))
	if (!do_after(user, 80, src))
		return FALSE
	if (QDELETED(src) || QDELETED(P) || panic_bar_side || user.get_active_hand() != P || door_side_of(user) != side)
		return FALSE
	panic_bar_side = side
	user.drop_from_inventory(P)
	qdel(P)
	playsound(get_turf(src), 'sound/items/Screwdriver.ogg', 60, TRUE)
	user.visible_message(SPAN_NOTICE("[user] fits a panic bar to \the [src]."), SPAN_NOTICE("You fit the panic bar. From your side, pushing it opens the door even when it is locked."))
	update_fitting_overlays()
	return TRUE

/obj/structure/simple_door/proc/remove_panic_bar(obj/item/W, mob/living/human/user)
	user.visible_message(SPAN_NOTICE("[user] starts taking the panic bar off \the [src]."), SPAN_NOTICE("You start taking the panic bar off."))
	if (!do_after(user, 40, src))
		return TRUE
	if (QDELETED(src) || !panic_bar_side || user.get_active_hand() != W || door_side_of(user) != panic_bar_side)
		return TRUE
	panic_bar_side = 0
	user.put_in_hands(new /obj/item/panic_bar(get_turf(user)))
	update_fitting_overlays()
	return TRUE

// ---- items on doors -------------------------------------------------------------------

// Fire door items, the panic bar and taking the panic bar off. TRUE when handled.
/obj/structure/simple_door/proc/fire_door_attackby(obj/item/W, mob/living/human/user)
	if (istype(W, /obj/item/fusible_link))
		fit_fire_link(W, user)
		return TRUE
	if (istype(W, /obj/item/panic_bar))
		fit_panic_bar(W, user)
		return TRUE
	if (istype(W, /obj/item/fire_seals))
		var/obj/structure/simple_door/key_door/anyone/fire_door/F = src
		if (!istype(F))
			to_chat(user, SPAN_WARNING("Only a fire door takes fire seals."))
			return TRUE
		return F.replace_fire_seals(W, user)
	if (panic_bar_side && user.a_intent != I_HARM && is_tool(W, TOOL_SCREWDRIVER) && door_side_of(user) == panic_bar_side)
		return remove_panic_bar(W, user)
	return FALSE

/obj/structure/simple_door/key_door/anyone/fire_door/proc/replace_fire_seals(obj/item/fire_seals/S, mob/living/human/user)
	if (fire_seals_intact && fire_rating_left >= fire_rating_full)
		to_chat(user, SPAN_NOTICE("The seals of \the [src] are whole."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts pressing new seals into the frame of \the [src]."), SPAN_NOTICE("You start replacing the seals."))
	if (!do_after(user, 60, src))
		return TRUE
	if (QDELETED(src) || QDELETED(S) || user.get_active_hand() != S)
		return TRUE
	fire_seals_intact = TRUE
	fire_rating_left = fire_rating_full
	user.drop_from_inventory(S)
	qdel(S)
	to_chat(user, SPAN_NOTICE("You replace the seals. The door is good for its full rating again."))
	update_fitting_overlays()
	return TRUE

// A fire door's closer is part of the rated assembly and stays on.
/obj/structure/simple_door/proc/door_closer_fixed()
	return FALSE

/obj/structure/simple_door/key_door/anyone/fire_door/door_closer_fixed()
	return TRUE

// ---- display and wreckage ----------------------------------------------------------

/obj/structure/simple_door/proc/fire_door_overlay_states()
	. = list()
	if (state && fire_link_holding)
		. += "fusible_link"
	if (!state && panic_bar_side)
		. += "panic_bar"

/obj/structure/simple_door/key_door/anyone/fire_door/fire_door_overlay_states()
	. = ..()
	if (!fire_seals_intact)
		. += "seals_burnt"

/obj/structure/simple_door/proc/fire_door_examine(mob/user)
	if (panic_bar_side)
		to_chat(user, SPAN_NOTICE("It has a panic bar [door_side_words(panic_bar_side, user)]."))
	if (fire_link_holding && state)
		to_chat(user, SPAN_NOTICE("A fusible link holds it open."))

/obj/structure/simple_door/proc/fire_door_parts_returned(turf/T)
	if (!T)
		return
	if (panic_bar_side)
		new /obj/item/panic_bar(T)
		panic_bar_side = 0
	if (fire_link_holding)
		new /obj/item/fusible_link(T)
		fire_link_holding = FALSE

/obj/item/fusible_link
	name = "fusible link"
	desc = "A hold-open arm joined by a link of low-melting solder. Hook it to an open door with a closer: the door stays open until fire comes near, then the link melts and the door shuts."
	icon = 'icons/obj/doors/fire_doors.dmi'
	icon_state = "item_fusible_link"
	w_class = ITEM_SIZE_SMALL

/obj/item/panic_bar
	name = "panic bar"
	desc = "A push bar for the inside of an exit door. Fitted with a screwdriver on the side you stand on, it opens the door from that side even when the door is locked or bolted."
	icon = 'icons/obj/doors/fire_doors.dmi'
	icon_state = "item_panic_bar"
	w_class = ITEM_SIZE_NORMAL

/obj/item/fire_seals
	name = "fire seals"
	desc = "A coil of seal strip that swells shut in heat. Press it into the frame of a fire door to replace burnt seals and restore its rating."
	icon = 'icons/obj/doors/fire_doors.dmi'
	icon_state = "item_fire_seals"
	w_class = ITEM_SIZE_SMALL

#undef FIRE_RATING_IRON
#undef FIRE_RATING_STEEL
#undef FIRE_EXPOSURE_TICK
