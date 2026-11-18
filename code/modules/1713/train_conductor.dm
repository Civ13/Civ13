// The conductor (docs/trains.md#the-conductor). Somebody is in charge of the
// train behind the engine: the guard or conductor, with four tools.
//
// - The guard's journal lists the train car by car: weight against what the
//   engines pull, handbrakes left on, hot and seized axle boxes, wrecked cars
//   and locked doors.
// - A carriage key locks and unlocks any car door. A locked door still opens
//   from its own tile, so nobody is shut in; a crowbar forces one.
// - A ticket book writes tickets and a ticket punch cancels them. Fares pass
//   from hand to hand: nothing here sells or buys.
// - Signal flags are seen in every cab of the train, however long it is.

#define TRAIN_DOOR_FORCE_TIME 80
#define TRAIN_TICKETS 40

/obj/structure/trains/platform
	var/locked_doors = 0 // bit per edge index, like open_doors

/////////////////////////////////////////////////////////////////////////////
// Door locks

/obj/structure/train_part/edge/proc/is_locked()
	return segment && is_door() && (segment.locked_doors & (1 << (edge_index - 1)))

// Locks or unlocks a closed door. TRUE when the lock changed.
/obj/structure/train_part/edge/proc/set_locked(state)
	if (!segment || !is_door() || !edge_index || (state && open) || !!is_locked() == !!state)
		return FALSE
	var/bit = 1 << (edge_index - 1)
	if (state)
		segment.locked_doors |= bit
	else
		segment.locked_doors &= ~bit
	return TRUE

// TRUE when a locked door keeps user out: it opens by hand from its own tile.
/obj/structure/train_part/edge/proc/locked_against(mob/user)
	return is_locked() && !(user && user.loc == loc)

/obj/structure/train_part/edge/proc/open_by_force()
	set_locked(FALSE)
	set_open(TRUE)
	if (segment && edge_index)
		segment.open_doors |= 1 << (edge_index - 1)

/obj/structure/train_part/edge/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/train_key) && is_door())
		if (open)
			to_chat(user, "Close \the [src] first.")
			return
		var/state = !is_locked()
		if (!set_locked(state))
			return
		playsound(loc, 'sound/effects/lever.ogg', 40, TRUE)
		user.visible_message("[user] [state ? "locks" : "unlocks"] \the [src].", "You [state ? "lock" : "unlock"] \the [src].")
		return
	if (is_tool(W, TOOL_CROWBAR) && is_locked())
		user.visible_message(SPAN_WARNING("[user] starts forcing \the [src]..."), "You start forcing \the [src]...")
		if (!do_after(user, TRAIN_DOOR_FORCE_TIME, src) || !is_locked())
			return
		open_by_force()
		playsound(loc, 'sound/effects/clang.ogg', 80, TRUE)
		user.visible_message(SPAN_WARNING("[user] forces \the [src] open."), "You force \the [src] open.")
		return
	return ..()

/obj/structure/train_part/edge/examine(mob/user)
	. = ..()
	if (is_locked())
		to_chat(user, "This door is locked. A carriage key unlocks it; from inside it opens by hand.")

/obj/item/train_key
	name = "carriage key"
	desc = "A square-socket key that fits the door locks of every railway car. Use it on a closed car door to lock or unlock it."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "carriage_key"
	w_class = 1
	force = 2
	throwforce = 2

/////////////////////////////////////////////////////////////////////////////
// The train list

// The car O is aboard or stands next to, if any.
/proc/train_beside(atom/movable/O)
	if (!O || !isturf(O.loc))
		return null
	for (var/atom/A in O.loc)
		var/obj/structure/trains/platform/S = train_deck_segment(A)
		if (S)
			return S
		if (istype(A, /obj/structure/trains))
			return A
		if (istype(A, /obj/structure/train_part/deck/body))
			var/obj/structure/train_part/deck/body/B = A
			if (B.engine)
				return B.engine
	for (var/obj/structure/S in range(1, O))
		if (istype(S, /obj/structure/trains))
			return S
		var/obj/structure/trains/platform/P = train_deck_segment(S)
		if (P)
			return P
	return null

// The train `any` is part of, as lines of text: a heading, then one line a
// vehicle from the front.
/proc/train_list_lines(obj/structure/trains/any)
	var/list/lines = list()
	if (!any)
		return lines
	var/list/cars = train_consist_list(any.train_head())
	var/weight = 0
	var/pull = 0
	var/vehicles = 0
	var/braked = 0
	var/last = null
	var/list/entry = null
	var/list/entries = list()
	for (var/obj/structure/trains/car in cars)
		var/id = car.car_id ? car.car_id : "\ref[car]"
		if (id != last)
			last = id
			vehicles++
			entry = list("name" = car.name, "weight" = 0, "brake" = FALSE, "axle" = "oiled", "wrecked" = FALSE, "locked" = 0, "engine" = null)
			entries += list(entry)
		var/car_weight = car.car_load_weight()
		weight += car_weight
		entry["weight"] += car_weight
		if (car.handbrake)
			entry["brake"] = TRUE
		var/axle = car.axle_state()
		if (axle == "seized" || (axle == "hot" && entry["axle"] != "seized") || (axle == "dry" && entry["axle"] == "oiled"))
			entry["axle"] = axle
		if (istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			entry["name"] = L.name
			entry["engine"] = L
			if (!L.engine_disabled())
				pull += L.haul * L.wear_factor()
		else if (istype(car, /obj/structure/trains/platform))
			var/obj/structure/trains/platform/P = car
			if (P.wrecked)
				entry["wrecked"] = TRUE
			for (var/obj/structure/train_part/edge/G in P.deck_parts)
				if (G.is_locked())
					entry["locked"]++
	var/n = 0
	for (var/list/E in entries)
		n++
		var/list/notes = list()
		var/obj/structure/trains/locomotive/L = E["engine"]
		if (L)
			notes += L.engine_disabled() ? "wrecked" : (L.on ? "running" : "stopped")
		if (E["wrecked"])
			notes += "wrecked"
		if (E["brake"])
			notes += "handbrake on"
			braked++
		switch (E["axle"])
			if ("seized")
				notes += "axle seized"
			if ("hot")
				notes += "hot axle box"
			if ("dry")
				notes += "axle boxes dry"
		if (E["locked"])
			notes += "[E["locked"]] door\s locked"
		lines += "[n]. [E["name"]], weight [round(E["weight"], 0.1)][notes.len ? ": [jointext(notes, ", ")]" : ""]"
	var/heading = "[vehicles] vehicle\s, [cars.len] tile\s long, weight [round(weight, 0.1)]."
	if (pull > 0)
		heading += " Its engines pull [round(pull, 0.1)] at full speed[weight > pull ? ", so it is overloaded" : ""]."
	else
		heading += " It has no working engine."
	if (braked)
		heading += " [braked] handbrake\s on."
	// The tail lamp (train_stations.dm).
	heading += train_tail_lamp_text(cars)
	lines.Insert(1, heading)
	return lines

/obj/item/train_list
	name = "guard's journal"
	desc = "The guard's book of the train. Use it aboard or beside a train to list it car by car: weights, handbrakes, hot axle boxes and locked doors."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "guard_journal"
	w_class = 2
	force = 2
	throwforce = 2

/obj/item/train_list/attack_self(mob/user)
	var/obj/structure/trains/TR = train_beside(user)
	if (!TR)
		to_chat(user, "Stand aboard or beside a train to list it.")
		return
	user.visible_message("[user] walks an eye along the train and writes in \the [src].", "You list the train:")
	for (var/line in train_list_lines(TR))
		to_chat(user, line)

/////////////////////////////////////////////////////////////////////////////
// Tickets

/obj/item/train_ticket_book
	name = "ticket book"
	desc = "A book of blank railway tickets. Use it to write one out: where to, and the fare you were paid."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "ticket_book"
	w_class = 2
	force = 2
	throwforce = 2
	var/tickets = TRAIN_TICKETS

/obj/item/train_ticket_book/examine(mob/user)
	..()
	to_chat(user, tickets > 0 ? "[tickets] blank ticket\s left." : "It is used up.")

// Writes one ticket out. Returns it, or null when the book is used up.
/obj/item/train_ticket_book/proc/issue(mob/user, destination, fare)
	if (tickets <= 0 || !destination)
		return null
	tickets--
	var/obj/item/train_ticket/T = new(user ? get_turf(user) : get_turf(src))
	T.destination = destination
	T.fare = fare
	T.issuer = user ? user.name : null
	T.update_ticket()
	return T

/obj/item/train_ticket_book/attack_self(mob/living/user)
	if (!istype(user))
		return
	if (tickets <= 0)
		to_chat(user, "\The [src] is used up.")
		return
	var/destination = sanitize(player_input(user, "Where is the ticket to?", "[name]", null, "text", null, TRUE), 40)
	if (!destination || QDELETED(src) || user.incapacitated() || !(src in user))
		return
	var/fare = sanitize(player_input(user, "What fare was paid? Leave it blank for a free pass.", "[name]", null, "text", null, TRUE), 40)
	if (QDELETED(src) || user.incapacitated() || !(src in user))
		return
	var/obj/item/train_ticket/T = issue(user, destination, fare)
	if (!T)
		return
	user.put_in_hands(T)
	user.visible_message("[user] writes out a ticket.", "You write out a ticket to [destination].")

/obj/item/train_ticket
	name = "railway ticket"
	desc = "A railway ticket."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "ticket"
	w_class = 1
	force = 0
	throwforce = 0
	var/destination = null
	var/fare = null
	var/issuer = null
	var/punched_by = null

/obj/item/train_ticket/proc/update_ticket()
	name = destination ? "ticket to [destination]" : "railway ticket"
	icon_state = punched_by ? "ticket_punched" : "ticket"

/obj/item/train_ticket/examine(mob/user)
	..()
	if (destination)
		to_chat(user, "To [destination]. [fare ? "Fare paid: [fare]." : "A free pass."][issuer ? " Written out by [issuer]." : ""]")
	to_chat(user, punched_by ? "It has been punched by [punched_by] and is used." : "It has not been punched.")

// Cancels the ticket. TRUE when it was still good.
/obj/item/train_ticket/proc/punch(mob/user)
	if (punched_by)
		return FALSE
	punched_by = user ? user.name : "a conductor"
	update_ticket()
	return TRUE

/obj/item/train_ticket/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/train_ticket_punch))
		if (!punch(user))
			to_chat(user, SPAN_WARNING("This ticket has already been punched by [punched_by]."))
			return
		playsound(get_turf(src), 'sound/effects/lever.ogg', 30, TRUE)
		user.visible_message("[user] punches \a [src].", "You punch \the [src].")
		return
	return ..()

/obj/item/train_ticket_punch
	name = "ticket punch"
	desc = "A conductor's punch. Use it on a railway ticket to cancel it, so it cannot be used twice."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "ticket_punch"
	w_class = 1
	force = 3
	throwforce = 3

/////////////////////////////////////////////////////////////////////////////
// Hand signals

/obj/item/train_flags
	name = "pair of signal flags"
	desc = "A red and a green flag on short staffs. Use them aboard or beside a train to signal its engine crew, who see them from the cab however long the train is."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "signal_flags"
	w_class = 2
	force = 3
	throwforce = 3

/proc/train_hand_signals()
	return list(
		"Right away" = "holds a green flag high: right away",
		"Stop" = "waves a red flag: stop",
		"Set back" = "waves a green flag slowly from side to side: set back",
		"Come on slowly" = "holds a green flag steady: come on slowly",
		"Danger" = "waves a red flag hard above the head: danger, stop at once")

// Shows a hand signal. Those in sight see it as usual; the crews in the cabs
// of the train are told as well. Returns how many in the cabs were told.
/obj/item/train_flags/proc/show_signal(mob/user, signal)
	. = 0
	var/what = train_hand_signals()[signal]
	if (!what || !user)
		return
	user.visible_message("<b>[user]</b> [what].", "You signal: [lowertext(signal)].")
	var/obj/structure/trains/TR = train_beside(user)
	if (!TR)
		return
	var/list/seen = viewers(world.view, user)
	for (var/obj/structure/trains/locomotive/L in train_consist_list(TR.train_head()))
		var/list/spots = list(L.control_spot(), L.rear_cab())
		for (var/obj/structure/trains/S in spots)
			if (!isturf(S.loc))
				continue
			for (var/turf/T in train_platform_tiles(S.loc, S.dir))
				for (var/mob/living/human/H in T)
					if (H == user || (H in seen))
						continue
					to_chat(H, "Back along the train, <b>[user]</b> [what].")
					.++

/obj/item/train_flags/attack_self(mob/living/user)
	if (!istype(user) || user.incapacitated())
		return
	var/signal = player_input(user, "Which signal?", "[name]", null, "anything", train_hand_signals(), TRUE)
	if (!signal || QDELETED(src) || user.incapacitated() || !(src in user))
		return
	show_signal(user, signal)

/obj/item/train_flags/examine(mob/user)
	..()
	to_chat(user, "Green held high: right away. Red waved: stop. Green waved slowly: set back. Green held steady: come on slowly. Red waved hard: danger.")

#undef TRAIN_DOOR_FORCE_TIME
#undef TRAIN_TICKETS
