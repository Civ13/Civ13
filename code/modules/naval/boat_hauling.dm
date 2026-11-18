// ============================================================
// Hauling small boats over land (docs/boat-hauling.md)
// ------------------------------------------------------------
// A raft, a canoe or an inflatable is built ashore and dragged to the water,
// and dragged up the beach again. Afloat she tows easily. On land:
//
// - Nobody and nothing may be aboard: a loaded boat will not budge.
// - A light boat (raft, dugout) slows one person to about half pace.
// - A heavy boat (outrigger, the old plank boats, an inflatable) is very slow
//   for one. Everyone else standing beside her lends a hand: one helper makes
//   her drag like a light boat, two like a crate. An engine counts as one
//   helper fewer.
// - Log rollers slipped under her let one person drag her like a crate. They
//   come out by themselves when she floats.
//
// The drag is the structure drag_delay() hook the movement code already
// asks; the refusal is in Move(), which pulling uses and paddling (forceMove)
// does not.
// ============================================================

/obj/structure/vehicle
	var/on_rollers = FALSE
	var/tmp/image/roller_image = null

/obj/item/boat_rollers
	name = "log rollers"
	desc = "Three short round logs. Slipped under a beached boat, they let one person drag her over land."
	icon = 'icons/obj/vehicles/raft.dmi'
	icon_state = "log_rollers"
	w_class = ITEM_SIZE_LARGE
	force = 5
	flammable = TRUE
	value = 3

// BOAT_HAUL_LIGHT or BOAT_HAUL_HEAVY for a boat, 0 for any other vehicle.
/obj/structure/vehicle/proc/haul_class()
	return takes_water() ? BOAT_HAUL_HEAVY : 0

/obj/structure/vehicle/raft/haul_class()
	return BOAT_HAUL_LIGHT

/obj/structure/vehicle/raft/dugout/outrigger/haul_class()
	return BOAT_HAUL_HEAVY

/obj/structure/vehicle/proc/afloat()
	return istype(loc, /turf/floor/beach/water) || istype(loc, /turf/floor/trench/flooded)

// People beside her, other than whoever drags, fit to lend a hand.
/obj/structure/vehicle/proc/haul_helpers(mob/puller)
	. = 0
	for (var/mob/living/human/H in range(1, src))
		if (H != puller && !H.stat && !H.lying && !H.restrained() && !(H in ontop))
			.++

/obj/structure/vehicle/drag_delay(mob/puller)
	var/class = haul_class()
	if (!class || afloat() || on_rollers)
		return BOAT_DRAG_EASY
	if (class == BOAT_HAUL_LIGHT)
		return BOAT_DRAG_LIGHT
	var/hands = haul_helpers(puller) - (engine ? 1 : 0)
	if (hands >= 2)
		return BOAT_DRAG_EASY
	return hands == 1 ? BOAT_DRAG_LIGHT : BOAT_DRAG_HEAVY

// Why she cannot be dragged from where she lies, or null.
/obj/structure/vehicle/proc/haul_refusal()
	if (!haul_class() || afloat())
		return null
	if (length(ontop) || length(ontop_o))
		return "She will not budge over land with anyone or anything aboard."
	return null

/obj/structure/vehicle/Move(newloc, direct)
	var/mob/puller = pulledby
	if (puller && isturf(loc))
		var/why = haul_refusal()
		if (why)
			to_chat(puller, SPAN_WARNING("[why]"))
			puller.stop_pulling()
			return FALSE
	var/turf/old = loc
	. = ..()
	if (on_rollers && loc != old && afloat())
		shed_rollers(old)
		if (puller)
			to_chat(puller, SPAN_NOTICE("\The [src] floats off her rollers."))

/obj/structure/vehicle/proc/shed_rollers(turf/T)
	if (!on_rollers)
		return
	on_rollers = FALSE
	new /obj/item/boat_rollers(T || get_turf(src))
	dress_rollers()

// The rollers show under her. A canoe's sheet is drawn a tile down and left
// of where she stands, so they are shifted back onto her tile.
/obj/structure/vehicle/proc/dress_rollers()
	if (roller_image)
		underlays -= roller_image
		roller_image = null
	if (on_rollers)
		roller_image = image('icons/obj/vehicles/raft.dmi', "log_rollers")
		roller_image.pixel_x = -pixel_w
		roller_image.pixel_y = -pixel_z
		underlays += roller_image

// Rollers used on a beached, empty boat go under her. TRUE when the click is done with.
/obj/structure/vehicle/proc/take_rollers(obj/item/boat_rollers/R, mob/user)
	if (!istype(R) || !haul_class())
		return FALSE
	if (on_rollers)
		to_chat(user, SPAN_WARNING("\The [src] is on rollers already."))
		return TRUE
	if (afloat())
		to_chat(user, SPAN_WARNING("\The [src] is afloat. Rollers are for dragging her over land."))
		return TRUE
	if (length(ontop) || length(ontop_o))
		to_chat(user, SPAN_WARNING("Empty \the [src] first."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts working rollers under \the [src]."), SPAN_NOTICE("You start working the rollers under \the [src]."))
	if (do_after(user, 40, src) && !on_rollers && !afloat() && !QDELETED(R))
		user.drop_from_inventory(R)
		qdel(R)
		on_rollers = TRUE
		dress_rollers()
		to_chat(user, SPAN_NOTICE("\The [src] sits on her rollers. Drag her where you want her."))
	return TRUE

/obj/structure/vehicle/proc/take_out_rollers(mob/living/human/H)
	if (!istype(H) || H.stat || H.restrained() || get_dist(H, src) > 1)
		return
	if (!on_rollers)
		to_chat(H, SPAN_WARNING("\The [src] is not on rollers."))
		return
	if (do_after(H, 30, src) && on_rollers)
		shed_rollers(get_turf(H))
		to_chat(H, SPAN_NOTICE("You pull the rollers out from under \the [src]."))

/obj/structure/vehicle/raft/verb/raft_rollers_out()
	set name = "Take Out Rollers"
	set category = "Object"
	set src in view(1)
	take_out_rollers(usr)

/obj/structure/vehicle/boat/verb/boat_rollers_out()
	set name = "Take Out Rollers"
	set category = "Object"
	set src in view(1)
	take_out_rollers(usr)

// What a look tells about getting her to the water.
/obj/structure/vehicle/proc/haul_text()
	if (!haul_class() || afloat())
		return null
	if (on_rollers && !roller_image)
		dress_rollers() // After a load.
	if (on_rollers)
		return "She sits on log rollers and drags easily."
	if (haul_class() == BOAT_HAUL_LIGHT)
		return "She is light enough for one person to drag when she is empty. Log rollers under her make it easy."
	return "She is heavy to drag: slow for one person, quicker with others standing beside her to help, and easy on log rollers. She has to be empty."
