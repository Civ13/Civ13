// The boathouse: boat storage on the shore, the way a garage keeps cars, a
// hangar keeps planes and a rail warehouse keeps rolling stock.
//
// The slip is the 7x7 square of water diagonally next to the office, on the
// side the office faces (a wrench turns it while the boathouse is empty).
// Sail a stopped, empty boat wholly into the slip and put it away: the boat,
// every part of it and whatever lies on its deck are moved into holders inside
// the office. Nothing of it is on the map, rendered or simulated while it is
// stored, and world saves carry it as ordinary nested contents of the office,
// cargo, fuel, names and paint included. Taking it out puts every piece back
// on the same tiles of the slip.
//
// Two kinds of boat are kept:
// - modular boats: a rudder axis with ship frames (hand-built boats, the
//   Scout and Explorer submarines);
// - small boats: one object, such as a raft, an outrigger or a RHIB.
// Built hulls and slipway ships are far bigger than a slip and stay at a berth.

#define BOATHOUSE_SLIP 7
#define BOATHOUSE_TIME 50

/obj/structure/boathouse
	name = "boathouse"
	desc = "A shipwright's boathouse on the shore. The 7x7 square of water diagonally next to it, on the side it faces, is its slip: sail a stopped, empty boat wholly into the slip to put it away, and it waits here, out of the water, until you take it out again. A wrench turns it to face another corner while it is empty."
	icon = 'icons/obj/structures.dmi'
	icon_state = "gate_control"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/capacity = 3
	// Which diagonal the slip lies on from the office.
	var/slip_dir = NORTHEAST
	var/tmp/busy = FALSE

/obj/structure/boathouse/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/obj/structure/boathouse/after_load()
	..()
	busy = FALSE
	if (!(slip_dir in cornerdirs))
		slip_dir = NORTHEAST
	// A stored boat's axis registers itself as it is made; it is not afloat.
	for (var/obj/structure/boathouse_stored/B in contents)
		B.forget_axis()

// A boat packed away with its deck cargo.
/obj/structure/boathouse_stored
	name = "stored boat"
	icon = null
	anchored = TRUE
	density = FALSE
	var/boat_name = "boat"

// One tile of a stored boat: what stood on the slip tile at dx, dy from the office.
/obj/structure/boathouse_stored_tile
	name = "stored boat tile"
	icon = null
	anchored = TRUE
	density = FALSE
	var/off_x = 0
	var/off_y = 0

// The boat's axis or small boat, found in the holders (no saved references).
/obj/structure/boathouse_stored/proc/boat()
	// An axis stands on its tile or rides inside one of its frames.
	for (var/obj/structure/boathouse_stored_tile/H in contents)
		for (var/obj/structure/vehicleparts/axis/A in H)
			return A
		for (var/obj/structure/vehicleparts/frame/F in H)
			for (var/obj/structure/vehicleparts/axis/A in F)
				return A
	for (var/obj/structure/boathouse_stored_tile/H in contents)
		for (var/obj/structure/vehicle/V in H)
			if (boathouse_is_small_boat(V))
				return V
	return null

/obj/structure/boathouse_stored/proc/forget_axis()
	var/obj/structure/vehicleparts/axis/A = boat()
	if (!istype(A))
		return
	ship_axes -= A
	if (istype(A, /obj/structure/vehicleparts/axis/ship/submarine))
		player_submarines -= A

/obj/structure/boathouse_stored/proc/tiles()
	. = list()
	for (var/obj/structure/boathouse_stored_tile/H in contents)
		. += H

// ---- The slip ----

/obj/structure/boathouse/proc/slip_x()
	return (slip_dir & EAST) ? 1 : -1

/obj/structure/boathouse/proc/slip_y()
	return (slip_dir & NORTH) ? 1 : -1

/obj/structure/boathouse/proc/slip()
	. = list()
	if (!isturf(loc))
		return
	for (var/i in 1 to BOATHOUSE_SLIP)
		for (var/j in 1 to BOATHOUSE_SLIP)
			var/turf/T = locate(x + i * slip_x(), y + j * slip_y(), z)
			if (T)
				. += T

/obj/structure/boathouse/proc/stored_boats()
	. = list()
	for (var/obj/structure/boathouse_stored/B in contents)
		. += B

/obj/structure/boathouse/proc/stored_names()
	. = list()
	for (var/obj/structure/boathouse_stored/B in stored_boats())
		. += B.boat_name

/proc/boathouse_is_boat_axis(obj/structure/vehicleparts/axis/A)
	if (!A || QDELETED(A))
		return FALSE
	if (istype(A, /obj/structure/vehicleparts/axis/ship))
		return TRUE
	for (var/obj/structure/vehicleparts/frame/ship/F in A.components)
		return TRUE
	return FALSE

/proc/boathouse_is_small_boat(atom/movable/M)
	return istype(M, /obj/structure/vehicle/boat) || istype(M, /obj/structure/vehicle/raft)

/proc/boathouse_boat_name(atom/movable/M)
	if (istype(M, /obj/structure/vehicleparts/axis))
		var/obj/structure/vehicleparts/axis/A = M
		var/label = sea_contact_name(A)
		if (findtext(label, "axis") || findtext(label, "rudder"))
			label = A.vehicle_type ? A.vehicle_type : "boat"
		if (A.reg_number)
			label = "[label] ([A.reg_number])"
		return label
	return M.name

// The boats lying wholly in the slip: modular axes and small boats.
/obj/structure/boathouse/proc/boats_in_slip()
	. = list()
	var/list/cells = slip()
	var/list/seen = list()
	for (var/turf/T in cells)
		for (var/obj/structure/vehicleparts/frame/F in T)
			var/obj/structure/vehicleparts/axis/A = F.axis
			if (F.loc != T || !boathouse_is_boat_axis(A) || seen[A])
				continue
			seen[A] = TRUE
			var/list/frames = deck_berth_frames(A)
			var/whole = frames.len > 0
			for (var/obj/structure/vehicleparts/frame/O in frames)
				if (!(O.loc in cells))
					whole = FALSE
					break
			if (whole)
				. += A
		for (var/obj/structure/vehicle/V in T)
			if (V.loc != T || seen[V] || !boathouse_is_small_boat(V))
				continue
			seen[V] = TRUE
			var/whole = TRUE
			for (var/turf/L in V.locs)
				if (!(L in cells))
					whole = FALSE
					break
			if (whole)
				. += V

// Why this boat cannot be put away now, in plain words, or null.
/obj/structure/boathouse/proc/store_problem(atom/movable/boat, mob/living/human/H)
	if (stored_boats().len >= capacity)
		return "\The [src] is full: it holds [capacity] boats."
	if (istype(boat, /obj/structure/vehicleparts/axis))
		var/obj/structure/vehicleparts/axis/A = boat
		if (A.moving)
			return "Stop the boat first."
		if (A.engine && A.engine.on)
			return "Stop the engine first."
		if (A.tow_in || A.tow_out)
			return "Cast off the tow line first."
		if (H && !A.key_access(H))
			return "You need this boat's key to put it away."
		if (istype(A, /obj/structure/vehicleparts/axis/ship/submarine))
			var/obj/structure/vehicleparts/axis/ship/submarine/S = A
			if (S.submerged)
				return "Surface the submarine first."
			if (S.floodlights)
				return "Switch the floodlights off first."
		A.add_transporting(FALSE)
		for (var/mob/living/L in A.transporting)
			return "Get everyone off the boat first."
		return null
	var/obj/structure/vehicle/V = boat
	if (V.moving || V.driver || V.buckled_mob)
		return "Get everyone off the boat first."
	for (var/mob/living/L in V.ontop)
		return "Get everyone off the boat first."
	if (V.engine && V.engine.on)
		return "Stop the engine first."
	return null

// The holder tile for dx, dy in a stored boat, made when first needed.
/obj/structure/boathouse_stored/proc/tile_at(dx, dy)
	for (var/obj/structure/boathouse_stored_tile/old in contents)
		if (old.off_x == dx && old.off_y == dy)
			return old
	var/obj/structure/boathouse_stored_tile/H = new(src)
	H.off_x = dx
	H.off_y = dy
	return H

// Packs the boat into a holder inside the office. Returns the holder or null.
/obj/structure/boathouse/proc/store_boat(atom/movable/boat)
	var/obj/structure/boathouse_stored/B = new(src)
	B.boat_name = boathouse_boat_name(boat)
	var/list/movers = list()
	if (istype(boat, /obj/structure/vehicleparts/axis))
		var/obj/structure/vehicleparts/axis/A = boat
		A.moving = FALSE
		A.stopmovementloop()
		A.add_transporting(FALSE)
		for (var/atom/movable/M in A.components)
			if (!QDELETED(M) && isturf(M.loc))
				movers |= M
		// Deck cargo: loose items and fittings, never the water's own effects.
		for (var/atom/movable/M in A.transporting)
			if (QDELETED(M) || !isturf(M.loc) || M.craft_left_behind() || istype(M, /obj/structure/wild))
				continue
			if (istype(M, /obj/item) || istype(M, /obj/structure))
				movers |= M
		movers |= A
	else
		movers += boat
	for (var/atom/movable/M in movers)
		var/turf/T = M.loc
		if (!isturf(T))
			continue
		M.forceMove(B.tile_at(T.x - x, T.y - y))
	B.forget_axis()
	return B

// Why the stored boat cannot come out now, or null.
/obj/structure/boathouse/proc/retrieve_problem(obj/structure/boathouse_stored/B)
	for (var/obj/structure/boathouse_stored_tile/H in B.tiles())
		var/turf/T = locate(x + H.off_x, y + H.off_y, z)
		if (!T)
			return "[B.boat_name] no longer fits in the slip."
		if (T.density)
			return "Something solid stands in the slip at [T.x], [T.y]."
		for (var/atom/movable/M in T)
			if (M.loc != T || istype(M, /atom/movable/lighting_overlay))
				continue
			if (isliving(M))
				return "Clear the slip of people first."
			if (istype(M, /obj/structure/vehicleparts) || istype(M, /obj/structure/vehicle))
				return "Another boat is in the slip."
			if (M.density)
				return "\The [M] is in the way in the slip."
	return null

// Puts every piece back on the slip. Returns the axis or small boat.
/obj/structure/boathouse/proc/retrieve_boat(obj/structure/boathouse_stored/B)
	if (retrieve_problem(B))
		return null
	var/list/holders = B.tiles()
	var/atom/movable/boat = B.boat()
	// Frames first, so whatever stands on them arrives on a deck.
	for (var/obj/structure/boathouse_stored_tile/H in holders)
		var/turf/T = locate(x + H.off_x, y + H.off_y, z)
		for (var/obj/structure/vehicleparts/frame/F in H.contents.Copy())
			F.forceMove(T)
	for (var/obj/structure/boathouse_stored_tile/H in holders)
		var/turf/T = locate(x + H.off_x, y + H.off_y, z)
		for (var/atom/movable/M in H.contents.Copy())
			M.forceMove(T)
	if (istype(boat, /obj/structure/vehicleparts/axis))
		var/obj/structure/vehicleparts/axis/A = boat
		if (istype(A, /obj/structure/vehicleparts/axis/ship))
			ship_axes |= A
		if (istype(A, /obj/structure/vehicleparts/axis/ship/submarine))
			player_submarines |= A
		for (var/obj/O in A.components)
			O.update_icon()
		A.update_icon()
	else if (istype(boat, /obj))
		var/obj/O = boat
		O.update_icon()
	qdel(B)
	return boat

// ---- Players ----

/obj/structure/boathouse/examine(mob/user, distance)
	..()
	var/list/names = stored_names()
	to_chat(user, names.len ? "Stored ([names.len]/[capacity]): [english_list(names)]." : "It is empty ([capacity] spaces).")
	to_chat(user, "Its slip is the 7x7 square of water to the [dir2text(slip_dir)].")

/obj/structure/boathouse/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench))
		if (busy)
			return
		if (stored_boats().len)
			to_chat(user, SPAN_WARNING("Take the stored boats out before you turn \the [src]."))
			return
		slip_dir = turn(slip_dir, -90)
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		to_chat(user, SPAN_NOTICE("\The [src] now faces [dir2text(slip_dir)]: its slip is the 7x7 square of water that way."))
		return
	..()

/obj/structure/boathouse/attack_hand(mob/living/human/H)
	if (busy || !istype(H) || !Adjacent(H))
		return
	var/list/options = list("Put away a boat from the slip" = "store")
	var/list/stored = stored_boats()
	if (stored.len)
		options["Take a boat out"] = "retrieve"
	var/list/names = stored_names()
	var/text = names.len ? "Stored ([names.len]/[capacity]): [english_list(names)]." : "Nothing is stored ([capacity] spaces)."
	var/choice = WWinput(H, "[text] The slip is the 7x7 square of water to the [dir2text(slip_dir)] of the boathouse.", name, "Cancel", options + list("Cancel"))
	if (!(choice in options) || busy || !Adjacent(H))
		return
	if (options[choice] == "store")
		var/list/boats = boats_in_slip()
		if (!boats.len)
			to_chat(H, SPAN_WARNING("Sail the boat wholly into the 7x7 slip to the [dir2text(slip_dir)] of \the [src] first."))
			return
		var/atom/movable/boat = boats[1]
		if (boats.len > 1)
			var/list/picks = list()
			for (var/atom/movable/M in boats)
				var/label = boathouse_boat_name(M)
				while (picks[label])
					label += " "
				picks[label] = M
			var/pick = WWinput(H, "Choose the boat to put away.", name, "Cancel", picks + list("Cancel"))
			boat = picks[pick]
			if (!boat)
				return
		var/why = store_problem(boat, H)
		if (why)
			to_chat(H, SPAN_WARNING(why))
			return
		busy = TRUE
		if (!do_after(H, BOATHOUSE_TIME, src) || QDELETED(src) || QDELETED(boat) || !Adjacent(H) || !(boat in boats_in_slip()))
			busy = FALSE
			return
		why = store_problem(boat, H)
		if (why)
			to_chat(H, SPAN_WARNING(why))
			busy = FALSE
			return
		var/label = boathouse_boat_name(boat)
		store_boat(boat)
		log_game("[key_name(H)] stored [label] in [src] at [x],[y],[z].")
		to_chat(H, SPAN_NOTICE("You haul [label] out of the water into \the [src]."))
		busy = FALSE
		return
	var/obj/structure/boathouse_stored/B = stored[1]
	if (stored.len > 1)
		var/list/picks = list()
		for (var/i in 1 to stored.len)
			var/obj/structure/boathouse_stored/S = stored[i]
			picks["[i]. [S.boat_name]"] = S
		var/pick = WWinput(H, "Choose the boat to put back in the water.", name, "Cancel", picks + list("Cancel"))
		B = picks[pick]
		if (!B)
			return
	var/obj/structure/vehicleparts/axis/key_axis = B.boat()
	if (istype(key_axis) && !key_axis.key_access(H))
		to_chat(H, SPAN_WARNING("You need the key for [B.boat_name] to take it out."))
		return
	var/why = retrieve_problem(B)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return
	busy = TRUE
	if (!do_after(H, BOATHOUSE_TIME, src) || QDELETED(src) || QDELETED(B) || B.loc != src || !Adjacent(H))
		busy = FALSE
		return
	why = retrieve_problem(B)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		busy = FALSE
		return
	var/label = B.boat_name
	retrieve_boat(B)
	log_game("[key_name(H)] took [label] out of [src] at [x],[y],[z].")
	to_chat(H, SPAN_NOTICE("You run [label] back down into the water."))
	busy = FALSE

#undef BOATHOUSE_SLIP
#undef BOATHOUSE_TIME
