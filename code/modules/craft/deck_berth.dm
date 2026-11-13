// ============================================================
// Deck berths (docs/craft-core.md): boats carried on ships
// ------------------------------------------------------------
// A boat davit is a berth that stands on a ship's deck. Its cradle is a
// rectangle of her deck ahead of it. A boat of ship frames lying in the
// water near the ship is hoisted into the cradle whole, with whoever and
// whatever is in it, and lowered again over any side that has open water.
//
// Whatever modular vehicle stands wholly in a cradle - a hoisted boat, an
// aircraft or a car parked there - is berthed aboard: its craft's carrier is
// the ship and the ship's carried list holds it. It rides the deck as cargo
// like any vehicle aboard (vehicle_aboard.dm); the link is what the ship's
// chart, her papers and later systems read. A carried craft may carry
// others, and a ship tells everything she carries, in nesting order, after
// each hop.
//
// Nothing here is saved but the davit's own size and facing: the occupant is
// found again from what stands in the cradle.
// ============================================================

var/global/list/deck_berths = list()

// ---- Carrying, on the craft ----

// Takes another craft aboard. FALSE when that would make a ring.
/datum/craft/proc/take_aboard(datum/craft/C)
	if (!C || C == src || QDELETED(C) || (src in C.all_carried()))
		return FALSE
	if (C.carrier == src)
		return TRUE
	if (C.carrier)
		C.carrier.set_down(C)
	C.carrier = src
	carried += C
	return TRUE

/datum/craft/proc/set_down(datum/craft/C)
	if (!C || C.carrier != src)
		return FALSE
	carried -= C
	C.carrier = null
	return TRUE

// The craft that carries the craft that carries this one, and so on up.
/datum/craft/proc/top_carrier()
	. = src
	var/datum/craft/C = src
	var/guard = 0
	while (C.carrier && guard++ < 16)
		C = C.carrier
		. = C
	return .

// Called on a ship after she hopped: everything she carries came with her.
/datum/craft/proc/tell_carried()
	for (var/datum/craft/C in carried.Copy())
		var/obj/structure/berth/deck/D = C.berth
		if (istype(D))
			D.refresh()
		if (C.carrier == src)
			C.on_carried()

// Called on a carried craft after its carrier moved it.
/datum/craft/proc/on_carried()
	if (token)
		token.follow_craft()
	tell_carried()

// Every davit on her decks.
/datum/craft/proc/davits()
	. = list()
	for (var/obj/structure/berth/deck/D in deck_berths)
		if (D.ship() == src)
			. += D

// What she carries in her davits' cradles, by name, looked at afresh.
/datum/craft/proc/carried_names()
	. = list()
	for (var/obj/structure/berth/deck/D in davits())
		var/datum/craft/C = D.refresh()
		if (C)
			. += C.name

// ---- The davit ----

/obj/structure/berth/deck
	name = "boat davit"
	desc = "A capstan and a pair of davits for a ship's boat. Built on a ship's deck, it hoists a boat lying in the water nearby into the cradle of deck ahead of it and lowers it again. Click it to hoist, lower, turn the cradle or set its size."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "capstan"
	density = TRUE
	berth_length = 3
	berth_beam = 3
	var/tmp/hoisting = FALSE

/obj/structure/berth/deck/New()
	..()
	deck_berths += src

/obj/structure/berth/deck/Destroy()
	deck_berths -= src
	if (occupant)
		let_go()
	return ..()

/obj/structure/berth/deck/berth_name()
	var/datum/craft/S = ship()
	return S ? "a davit of the [S.name]" : "a boat davit"

// The ship whose deck it stands on, or null.
/obj/structure/berth/deck/proc/ship()
	return craft_at(get_turf(src))

// The way the cradle lies from the davit.
/obj/structure/berth/deck/proc/ahead()
	return (dir in cardinal) ? dir : SOUTH

// The tiles of the cradle: berth_length rows ahead of the davit, each
// berth_beam tiles to the right of that way. Fewer at the edge of the map.
/obj/structure/berth/deck/proc/cradle()
	. = list()
	var/way = ahead()
	var/side = turn(way, -90)
	var/turf/row = get_turf(src)
	for (var/i = 1, i <= berth_length, i++)
		row = row ? get_step(row, way) : null
		var/turf/T = row
		for (var/j = 1, j <= berth_beam, j++)
			if (!T)
				break
			. += T
			T = get_step(T, side)

// The frames of a vehicle that stand on the map.
/proc/deck_berth_frames(obj/structure/vehicleparts/axis/A)
	. = list()
	if (!A || QDELETED(A))
		return
	for (var/obj/structure/vehicleparts/frame/F in A.components)
		if (!QDELETED(F) && isturf(F.loc) && F.axis == A)
			. += F

// The box around some atoms: list(min x, min y, max x, max y), or null.
/proc/deck_berth_box(list/atoms)
	var/list/box = null
	for (var/atom/A in atoms)
		var/turf/T = get_turf(A)
		if (!T)
			continue
		if (!box)
			box = list(T.x, T.y, T.x, T.y)
			continue
		box[1] = min(box[1], T.x)
		box[2] = min(box[2], T.y)
		box[3] = max(box[3], T.x)
		box[4] = max(box[4], T.y)
	return box

// The vehicle standing wholly in the cradle, or null.
/obj/structure/berth/deck/proc/vehicle_in()
	var/list/cells = cradle()
	var/list/seen = list()
	for (var/turf/T in cells)
		for (var/obj/structure/vehicleparts/frame/F in T)
			var/obj/structure/vehicleparts/axis/A = F.axis
			if (F.loc != T || !A || QDELETED(A) || seen[A])
				continue
			seen[A] = TRUE
			var/whole = TRUE
			for (var/obj/structure/vehicleparts/frame/O in deck_berth_frames(A))
				if (!(O.loc in cells))
					whole = FALSE
					break
			if (whole)
				return A
	return null

// The vehicle the davit holds: one wholly in the cradle of a davit on a ship.
/obj/structure/berth/deck/proc/held()
	return ship() ? vehicle_in() : null

/obj/structure/berth/deck/proc/let_go()
	var/datum/craft/C = occupant
	occupant = null
	if (!C || QDELETED(C))
		return
	if (C.berth == src)
		C.berth = null
	if (C.carrier)
		C.carrier.set_down(C)

// Looks at the cradle and sets who lies in it. Returns the craft berthed
// here now, or null.
/obj/structure/berth/deck/proc/refresh()
	var/datum/craft/parent = ship()
	var/obj/structure/vehicleparts/axis/A = parent ? vehicle_in() : null
	var/datum/craft/now = A ? craft_of_axis(A) : null
	if (occupant && occupant != now)
		let_go()
	if (!now)
		return null
	if (now.berth && now.berth != src)
		now.cast_off()
	A.cradle = src
	occupant = now
	now.berth = src
	if (!parent.take_aboard(now))
		let_go()
		return null
	return now

// The level her waterline is on: where a boat is hoisted from and lowered
// to. A davit may stand on a deck above it.
/obj/structure/berth/deck/proc/sea_z()
	var/datum/craft/parent = ship()
	var/turf/O = (parent && parent.body) ? parent.body.origin() : null
	return O ? O.z : z

/proc/deck_berth_water(turf/T)
	return istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/trench/flooded)

// Why a boat cannot be set down on this tile of water, or null.
/proc/deck_berth_water_refusal(turf/T, obj/structure/vehicleparts/axis/A)
	if (!deck_berth_water(T))
		return "there is no water"
	if (locate(/obj/covers) in T)
		return "the water is built over"
	for (var/atom/movable/M in T)
		if (M.loc != T || ismob(M))
			continue
		var/obj/structure/vehicleparts/frame/F = M
		if (istype(F))
			if (F.axis != A)
				return "another vessel lies there"
			continue
		if (M.density && !istype(M, /obj/structure/vehicleparts) && !istype(M, /obj/effect/pseudovehicle))
			return "\the [M] is in the way"
	return null

// Why the davit cannot work at all, or null.
/obj/structure/berth/deck/proc/cradle_refusal()
	var/datum/craft/parent = ship()
	if (!parent || !parent.body)
		return "the davit must stand on a ship's deck"
	var/list/cells = cradle()
	if (cells.len < berth_length * berth_beam)
		return "the cradle runs off the edge of the sea"
	for (var/turf/T in cells)
		if (craft_at(T) != parent)
			return "the cradle reaches past her deck at [T.x], [T.y]: turn it or make it smaller"
	if (z < sea_z())
		return "the davit is below her waterline"
	if (parent.making_way())
		return "she must be stopped"
	return null

// Why this character may not work the davit, or null. A ship nobody
// registered is worked by anyone.
/obj/structure/berth/deck/proc/hand_refusal(mob/living/human/H)
	var/datum/craft/parent = ship()
	var/datum/craft_register/R = parent ? parent.register : null
	if (R && R.party && !R.is_crew(H))
		return "you are not of her crew"
	return null

// Plans hoisting a boat into the cradle. Returns list(dx, dy) or, in plain
// words, why not. Writes nothing.
/obj/structure/berth/deck/proc/hoist_plan(obj/structure/vehicleparts/axis/A)
	var/why = cradle_refusal()
	if (why)
		return why
	if (occupant && refresh())
		return "the cradle holds [occupant.name]"
	var/list/frames = deck_berth_frames(A)
	if (!frames.len)
		return "there is no hull to hoist"
	if (A.moving)
		return "the boat is under way"
	var/turf/at = get_turf(A)
	if (!at || at.z != sea_z() || get_dist(at, src) > DECK_BERTH_REACH)
		return "the boat lies out of reach: bring it within [DECK_BERTH_REACH] tiles"
	var/list/cells = cradle()
	var/list/box = deck_berth_box(frames)
	var/list/room = deck_berth_box(cells)
	var/wide = box[3] - box[1] + 1
	var/tall = box[4] - box[2] + 1
	var/room_wide = room[3] - room[1] + 1
	var/room_tall = room[4] - room[2] + 1
	if (wide > room_wide || tall > room_tall)
		return "the boat is too big as it lies: [wide] by [tall] against a cradle of [room_wide] by [room_tall] (east-west by north-south)"
	for (var/turf/T in cells)
		if (T.density)
			return "the cradle is not clear at [T.x], [T.y]"
		for (var/atom/movable/M in T)
			if (M.loc != T || M == src || ismob(M))
				continue
			if (istype(M, /obj/structure/vehicleparts))
				return "another vehicle stands in the cradle"
			if (M.density)
				return "\the [M] stands in the cradle"
	return list(room[1] - box[1], room[2] - box[2])

// Plans lowering the held vehicle over the side that way. Returns
// list(dx, dy, z) or why not. Writes nothing.
/obj/structure/berth/deck/proc/launch_plan(obj/structure/vehicleparts/axis/A, way)
	var/datum/craft/parent = ship()
	if (!parent || !parent.body)
		return "the davit must stand on a ship's deck"
	if (parent.making_way())
		return "she must be stopped"
	var/list/frames = deck_berth_frames(A)
	if (!frames.len)
		return "there is nothing to lower"
	var/vx = (way == EAST) ? 1 : ((way == WEST) ? -1 : 0)
	var/vy = (way == NORTH) ? 1 : ((way == SOUTH) ? -1 : 0)
	if (!vx && !vy)
		return "there is no such side"
	var/level = sea_z()
	var/outside = 0
	for (var/k = 1, k <= world.maxx, k++)
		var/overlap = FALSE
		var/clear = TRUE
		for (var/obj/structure/vehicleparts/frame/F in frames)
			var/turf/D = locate(F.x + k * vx, F.y + k * vy, level)
			if (!D)
				return "the edge of the sea is too near to the [dir2text(way)]"
			if (craft_at(D))
				overlap = TRUE
			else if (deck_berth_water_refusal(D, A))
				clear = FALSE
		if (overlap)
			// Still over a deck; water beyond a second ship is out of reach.
			if (outside)
				break
			continue
		outside++
		if (clear)
			return list(k * vx, k * vy, level)
		if (outside >= DECK_BERTH_SWING)
			break
	return "there is no open water within reach to the [dir2text(way)]"

// The boats that lie where the davit could hoist them: name = axis.
/obj/structure/berth/deck/proc/boats_in_reach()
	. = list()
	var/on = sea_z()
	for (var/obj/structure/vehicleparts/axis/ship/S in ship_axes)
		if (QDELETED(S) || istype(S, /obj/structure/vehicleparts/axis/ship/submarine))
			continue
		var/turf/T = get_turf(S)
		if (!T || T.z != on || get_dist(T, src) > DECK_BERTH_REACH || craft_at(T))
			continue
		if (!deck_berth_frames(S).len)
			continue
		var/label = "[sea_contact_name(S)] ([get_dist(T, src)] tiles [dir2text(get_dir(src, T))])"
		while (.[label])
			label += " "
		.[label] = S
	return .

// Moves the boat by the plan and makes it fast in the cradle.
/obj/structure/berth/deck/proc/hoist(obj/structure/vehicleparts/axis/A)
	var/list/plan = hoist_plan(A)
	if (!islist(plan))
		return plan
	A.moving = FALSE
	A.stopmovementloop()
	if (!A.shift_vehicle_level(z, plan[1], plan[2]))
		return "the falls foul and the boat stays where it is"
	A.anchor = TRUE
	if (!refresh())
		return "the boat does not sit in the cradle"
	return null

// Lowers the held vehicle over that side and lets it go.
/obj/structure/berth/deck/proc/launch(way)
	var/obj/structure/vehicleparts/axis/A = held()
	if (!A)
		return "the cradle is empty"
	var/list/plan = launch_plan(A, way)
	if (!islist(plan))
		return plan
	if (!A.shift_vehicle_level(plan[3], plan[1], plan[2]))
		return "the falls foul and the boat stays where it is"
	A.cradle = null
	refresh()
	return null

/obj/structure/berth/deck/proc/status_text()
	var/list/lines = list()
	var/why = cradle_refusal()
	var/datum/craft/C = refresh()
	lines += "The cradle is the [berth_length] by [berth_beam] tiles of deck to the [dir2text(ahead())] of the davit."
	if (C)
		lines += "It holds [C.name]."
	else
		lines += "It is empty."
	if (why)
		lines += "It cannot be worked: [why]."
	return jointext(lines, " ")

/obj/structure/berth/deck/examine(mob/user)
	..()
	to_chat(user, status_text())

// Shows the cradle's tiles for a few seconds.
/obj/structure/berth/deck/proc/mark_cradle()
	var/list/marks = list()
	for (var/turf/T in cradle())
		marks += new /obj/effect/vessel_path/cradle(T)
	spawn (40)
		for (var/obj/effect/E in marks)
			if (!QDELETED(E))
				qdel(E)

/obj/effect/vessel_path/cradle
	name = "davit's cradle"
	desc = "The deck a boat davit hoists a boat onto."

/obj/structure/berth/deck/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	if (hoisting)
		to_chat(H, SPAN_WARNING("The davit is being worked."))
		return
	var/not_crew = hand_refusal(H)
	if (not_crew)
		to_chat(H, SPAN_WARNING("[status_text()] You cannot work it: [not_crew]."))
		return
	var/obj/structure/vehicleparts/axis/in_cradle = held()
	var/list/options = list()
	var/list/sides = list()
	if (in_cradle)
		for (var/way in cardinal)
			if (islist(launch_plan(in_cradle, way)))
				sides["Lower it to the [dir2text(way)]"] = way
		options += sides
	else
		if (!cradle_refusal() && boats_in_reach().len)
			options += "Hoist a boat aboard"
		options += list("Turn the cradle", "Set the cradle's size")
	options += "Show the cradle"
	var/choice = WWinput(H, status_text(), name, "Cancel", options + list("Cancel"))
	if (!choice || choice == "Cancel" || QDELETED(src) || get_dist(H, src) > 1 || hoisting || hand_refusal(H))
		return
	switch (choice)
		if ("Show the cradle")
			mark_cradle()
		if ("Turn the cradle")
			if (held())
				return
			set_dir(turn(ahead(), -90))
			mark_cradle()
			to_chat(H, SPAN_NOTICE(status_text()))
		if ("Set the cradle's size")
			var/long = player_input(H, "How many tiles should the cradle reach ahead of the davit? ([DECK_BERTH_MIN] to [DECK_BERTH_MAX])", name, berth_length, "num", null, TRUE)
			if (isnull(long) || QDELETED(src) || get_dist(H, src) > 1)
				return
			var/broad = player_input(H, "How many tiles wide should it be? ([DECK_BERTH_MIN] to [DECK_BERTH_MAX])", name, berth_beam, "num", null, TRUE)
			if (isnull(broad) || QDELETED(src) || get_dist(H, src) > 1 || held() || hand_refusal(H))
				return
			berth_length = clamp(round(long), DECK_BERTH_MIN, DECK_BERTH_MAX)
			berth_beam = clamp(round(broad), DECK_BERTH_MIN, DECK_BERTH_MAX)
			mark_cradle()
			to_chat(H, SPAN_NOTICE(status_text()))
		if ("Hoist a boat aboard")
			var/list/boats = boats_in_reach()
			if (!boats.len)
				return
			var/pick = boats.len == 1 ? boats[1] : WWinput(H, "Which boat?", name, "Cancel", boats + list("Cancel"))
			var/obj/structure/vehicleparts/axis/A = boats[pick]
			if (!A || QDELETED(src) || get_dist(H, src) > 1)
				return
			var/plan = hoist_plan(A)
			if (!islist(plan))
				to_chat(H, SPAN_WARNING("The boat cannot be hoisted: [plan]."))
				return
			work(H, A, null)
		else
			if (sides[choice])
				work(H, held(), sides[choice])

// The lift itself: the wait, the check again and the move.
/obj/structure/berth/deck/proc/work(mob/living/human/H, obj/structure/vehicleparts/axis/A, way)
	if (!A || hoisting)
		return FALSE
	hoisting = TRUE
	mark_cradle()
	visible_message(SPAN_NOTICE("[H] heaves at the davit's capstan[way ? " to lower \the [A]" : " to hoist \the [A] aboard"]."))
	playsound(loc, 'sound/effects/lever.ogg', 60, TRUE)
	var/done = do_after(H, DECK_HOIST_TIME, src)
	hoisting = FALSE
	if (!done || QDELETED(src) || QDELETED(A) || hand_refusal(H))
		return FALSE
	var/why = way ? launch(way) : hoist(A)
	if (why)
		to_chat(H, SPAN_WARNING("The davit cannot [way ? "lower" : "hoist"] it: [why]."))
		return FALSE
	var/datum/craft/parent = ship()
	visible_message(SPAN_NOTICE(way ? "\The [A] is lowered to the water." : "\The [A] is hoisted aboard[parent ? " the [parent.name]" : ""] and made fast."))
	log_game("[key_name(H)] [way ? "lowered" : "hoisted"] [A] at the davit at [x],[y],[z].")
	return TRUE

// ---- The vehicle ----

/obj/structure/vehicleparts/axis
	var/tmp/obj/structure/berth/deck/cradle

// The davit whose cradle holds this vehicle, or null.
/obj/structure/vehicleparts/axis/proc/in_cradle()
	if (cradle && (QDELETED(cradle) || cradle.held() != src))
		cradle = null
	if (!cradle && deck_berths.len)
		for (var/obj/structure/berth/deck/D in deck_berths)
			if (D.z == z && get_dist(D, src) <= DECK_BERTH_MAX + 1 && D.held() == src)
				cradle = D
				break
	return cradle

// A boat in a cradle is out of the water and does not sail off the deck.
/obj/structure/vehicleparts/axis/ship/do_vehicle_check()
	if (in_cradle())
		visible_message(SPAN_WARNING("\The [name] is made fast in a davit's cradle. Lower it to the water first."))
		moving = FALSE
		stopmovementloop()
		return FALSE
	return ..()
