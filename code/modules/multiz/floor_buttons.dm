// The up and down HUD buttons on foot (_onclick/hud/updown_buttons.dm): the
// way between floors at hand, in the order a player would reach for it.
//
// Up:   a ladder up on or beside you, stairs under you, then a wall or hole
//       rim beside you with a floor on top (Climb Up).
// Down: off a vehicle top or out of a tree, a ladder down on or beside you,
//       then an open edge beside you with ground one storey below (Climb Down).
// In the open sea they Dive and Surface instead (free_diving.dm).
//
// The offer looks at the ground only, so a full hand or a pulled crate does
// not grey a button out: pressing it then says what to change.

// The nearest ladder within reach that leads direction (UP or DOWN): the one
// underfoot first, then a neighbour.
/mob/living/human/proc/updown_ladder(direction)
	var/turf/here = get_turf(src)
	if (!here)
		return null
	var/want_top = direction == DOWN
	for (var/obj/structure/multiz/ladder/L in here)
		if (L.istop == want_top && !QDELETED(L))
			return L
	for (var/obj/structure/multiz/ladder/L in orange(1, here))
		if (L.istop == want_top && !QDELETED(L) && L.z == here.z)
			return L
	return null

// The first side, facing first, a ledge climb (UP) or edge descent (DOWN)
// could use from here, or 0.
/mob/living/human/proc/updown_edge(direction)
	for (var/d in edge_descent_directions(dir))
		if (direction == UP ? ledge_climb_destination(src, d, null, TRUE) : edge_descent_destination(src, d, null, TRUE))
			return d
	return 0

/mob/living/human/updown_offer(mob/living/human/user, direction)
	if (user != src || !isturf(loc))
		return null
	var/sea = sea_updown_offer(direction)
	if (sea)
		return sea
	if (direction == UP)
		var/obj/structure/multiz/ladder/L = updown_ladder(UP)
		if (L)
			return "Climb up \the [L]"
		if (stairs_in(loc))
			return "Climb the stairs"
		if (updown_edge(UP))
			return "Climb up the ledge"
		return null
	if (direction == DOWN)
		if (vehicle_deck)
			return "Climb down from the vehicle"
		if (climbed_tree)
			return "Climb down from the tree"
		var/obj/structure/multiz/ladder/L = updown_ladder(DOWN)
		if (L)
			return "Climb down \the [L]"
		if (updown_edge(DOWN))
			return "Climb down over the edge"
	return null

/mob/living/human/updown_press(mob/living/human/user, direction)
	if (user != src)
		return FALSE
	if (stat || paralysis || stunned || weakened)
		return FALSE
	switch (sea_updown_offer(direction))
		if ("Surface")
			return surface_from_seabed()
		if ("Dive")
			return free_dive()
	if (direction == UP)
		if (vehicle_deck || climbed_tree)
			to_chat(src, SPAN_WARNING("There is no way further up from here."))
			return FALSE
		var/obj/structure/multiz/ladder/L = updown_ladder(UP)
		if (L)
			L.attack_hand(src)
			return TRUE
		var/obj/covers/stairs = stairs_in(get_turf(src))
		if (stairs)
			return climb_stairs(stairs)
		var/d = updown_edge(UP)
		if (d)
			return climb_ledge(d)
		to_chat(src, SPAN_WARNING("There is no way up here. Stand on stairs or by a ladder, or face a wall or rim with a floor on top."))
		return FALSE
	if (direction == DOWN)
		if (vehicle_deck)
			return start_vehicle_deck_down()
		if (climbed_tree)
			return start_climb_down()
		var/obj/structure/multiz/ladder/L = updown_ladder(DOWN)
		if (L)
			L.attack_hand(src)
			return TRUE
		var/d = updown_edge(DOWN)
		if (d)
			return climb_down_edge(d)
		to_chat(src, SPAN_WARNING("There is no way down here. Stand by a ladder down, or beside an open edge with ground one storey below."))
	return FALSE
