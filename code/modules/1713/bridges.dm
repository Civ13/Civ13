// Modern bridges (Val, 2026-11-07): steel and concrete bridge decks that can be
// laid over any water, including the deep ocean where wooden floors sink.
// A deck is an ordinary floor cover, so people walk on it, road vehicles drive
// on it (axis.dm lets them onto deep water under a non-dense cover), and roads
// and railway track can be laid on top. Rails on a deck are ordinary
// /obj/structure/rails, so rail_network.dm joins them like any other track.
//
// A span is built from the tile in front of the builder, who must stand on
// firm footing: the shore, shallow water or the bridge built so far.

#define BRIDGE_SPAN_BUILD_TIME 100
#define BRIDGE_SPAN_REMOVE_TIME 150

// The bridge deck on T, or null.
/proc/bridge_deck_at(turf/T)
	return T ? (locate(/obj/covers/bridge) in T) : null

/obj/covers/bridge
	name = "steel bridge deck"
	desc = "A riveted steel bridge deck on piers sunk into the bed below. Roads and railway track can be laid on it."
	icon = 'icons/turf/floors.dmi'
	icon_state = "plating"
	base_icon_state = "plating"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	flammable = FALSE
	layer = 1.99
	health = 400
	explosion_resistance = 4
	material = "Steel"
	hardness = 80
	buildstack = /obj/item/stack/material/steel
	var/span_type = /obj/item/weapon/bridge_span

/obj/covers/bridge/concrete
	name = "concrete bridge deck"
	desc = "A poured concrete bridge deck on piers sunk into the bed below. Roads and railway track can be laid on it."
	icon_state = "concrete6"
	base_icon_state = "concrete6"
	material = "Stone"
	span_type = /obj/item/weapon/bridge_span/concrete

/obj/covers/bridge/fire_act(temperature)
	return

/obj/covers/bridge/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/hammer))
		take_apart(user)
		return TRUE
	return ..()

/obj/covers/bridge/proc/take_apart(mob/user)
	var/turf/T = get_turf(src)
	var/problem = bridge_clear_problem(T)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start taking \the [src] apart..."))
	if (!do_after(user, BRIDGE_SPAN_REMOVE_TIME, src))
		return FALSE
	problem = bridge_clear_problem(T)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	new span_type(get_turf(user))
	user.visible_message(SPAN_NOTICE("[user] takes \the [src] apart."), SPAN_NOTICE("You take \the [src] apart and recover the span."))
	qdel(src)
	return TRUE

// Why the deck on T cannot be taken apart now, or null.
/proc/bridge_clear_problem(turf/T)
	if (!T)
		return "The bridge is gone."
	for (var/obj/covers/C in T)
		if (!istype(C, /obj/covers/bridge))
			return "Take \the [C] off the deck first."
	if (locate(/obj/structure/rails) in T)
		return "Take the railway track off the deck first."
	var/bed_type = text2path("/obj/structure/rail_bed")
	if (bed_type && (locate(bed_type) in T))
		return "Take the railway sleepers off the deck first."
	if (locate(/obj/structure/vehicleparts) in T)
		return "Move the vehicle off the deck first."
	if (locate(/mob/living) in T)
		return "Nobody can stand on the deck while it comes apart."
	return null

// When a deck goes (shelled, blown up), the track on it falls into the water.
/obj/covers/bridge/Destroy()
	var/turf/T = get_turf(src)
	. = ..()
	if (istype(T, /turf/floor/beach/water) && !bridge_deck_at_except(T, src))
		var/bed_type = text2path("/obj/structure/rail_bed")
		for (var/obj/structure/O in T)
			if (istype(O, /obj/structure/rails) || (bed_type && istype(O, bed_type)))
				O.visible_message(SPAN_DANGER("\The [O] falls into the water!"))
				qdel(O)

/proc/bridge_deck_at_except(turf/T, obj/covers/bridge/except)
	for (var/obj/covers/bridge/B in T)
		if (B != except && !QDELETED(B))
			return B
	return null

// The carried span: crafted from steel or clay (concrete), then used on the
// water tile in front of the builder.
/obj/item/weapon/bridge_span
	name = "steel bridge span"
	desc = "Steel girders, deck plates and a pier for one tile of bridge. Use it on the water in front of you; it can cross even the deep sea."
	icon = 'icons/turf/floors.dmi'
	icon_state = "plating"
	w_class = ITEM_SIZE_HUGE
	flammable = FALSE
	force = 10
	throwforce = 5
	value = 0
	var/deck_type = /obj/covers/bridge

/obj/item/weapon/bridge_span/concrete
	name = "concrete bridge span"
	desc = "Precast concrete slabs and a pier for one tile of bridge. Use it on the water in front of you; it can cross even the deep sea."
	icon_state = "concrete6"
	deck_type = /obj/covers/bridge/concrete

/obj/item/weapon/bridge_span/attack_self(mob/user)
	var/turf/T = get_step(user, user.dir)
	if (T)
		build_span(T, user)

/obj/item/weapon/bridge_span/resolve_attack_turf(atom/A, mob/user, icon_x, icon_y)
	var/turf/T = A
	if (!istype(T) || !user.Adjacent(T))
		return ..()
	build_span(T, user)
	return TRUE

/obj/item/weapon/bridge_span/proc/build_span(turf/T, mob/user)
	var/problem = bridge_span_problem(T, user)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/build_time = BRIDGE_SPAN_BUILD_TIME
	if (ishuman(user))
		var/mob/living/human/H = user
		build_time /= H.getStatCoeff("strength")
		build_time /= H.getStatCoeff("crafting")
	user.visible_message(SPAN_NOTICE("[user] starts lowering \the [src] into place."), SPAN_NOTICE("You start lowering \the [src] into place."))
	var/turf/start = get_turf(user)
	if (!do_after(user, build_time, T) || get_turf(user) != start || loc != user)
		return FALSE
	problem = bridge_span_problem(T, user)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/obj/covers/bridge/B = new deck_type(T)
	B.add_fingerprint(user)
	playsound(T, 'sound/items/Ratchet.ogg', 60, TRUE)
	user.visible_message(SPAN_NOTICE("[user] finishes a span of bridge."), SPAN_NOTICE("You finish the span. Roads and railway track can be laid on it."))
	if (ishuman(user))
		var/mob/living/human/H = user
		H.adaptStat("crafting", 3)
	user.drop_from_inventory(src)
	qdel(src)
	return TRUE

// Why a span cannot go on T for user, or null.
/proc/bridge_span_problem(turf/T, mob/user)
	if (!T || !user || get_dist(user, T) != 1 || !(get_dir(user, T) in cardinal) || T.z != user.z)
		return "Face the water you want to bridge."
	if (!istype(T, /turf/floor/beach/water))
		return "Bridge spans go over water. Lay an ordinary floor or road on dry land."
	if (locate(/obj/covers) in T)
		return "Something already covers that water."
	for (var/atom/movable/AM in T)
		if (AM.density || istype(AM, /obj/structure/vehicleparts) || istype(AM, /obj/structure/vehicle))
			return "\The [AM] is in the way."
	var/turf/footing = get_turf(user)
	if (istype(footing, /turf/floor/beach/water/deep) && !footing.iscovered())
		return "You need firm footing: stand on the shore, in the shallows or on the bridge."
	if (istype(footing, /turf/floor/beach/water) && locate(/obj/structure/vehicle) in footing)
		return "You need firm footing: stand on the shore, in the shallows or on the bridge."
	return null

#undef BRIDGE_SPAN_BUILD_TIME
#undef BRIDGE_SPAN_REMOVE_TIME
