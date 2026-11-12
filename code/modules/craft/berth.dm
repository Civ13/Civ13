// Berths and the docking handshake (docs/craft-core.md).
//
// A berth is a place a craft can lie: a quay, a slipway, a deck berth, a
// station port. It has a size and a facing, an owning party and a rule for
// who else is welcome. A craft never just arrives: it asks, and the berth
// answers with a ticket that either reserves the berth for it or says why
// not. Whoever moves the craft then finishes or drops the ticket.
//
// This is the shared base. It has no recipe and is never placed as it is;
// the quay, port and deck berth subtypes come with the phases that use them.

/obj/structure/berth
	name = "berth"
	desc = "A place for a craft to lie."
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	var/berth_length = 1          // Along the facing, in tiles.
	var/berth_beam = 1            // Across it.
	var/owner_party = null
	var/welcome = BERTH_WELCOME_OWNERS
	var/list/guests = list()      // parties
	var/tmp/datum/craft/occupant
	var/tmp/datum/berth_ticket/reserved

/obj/structure/berth/Destroy()
	if (reserved)
		reserved.release()
	if (occupant && occupant.berth == src)
		occupant.berth = null
	occupant = null
	return ..()

// TRUE when a craft of that party may lie here.
/obj/structure/berth/proc/welcomes(party)
	if (!owner_party || welcome == BERTH_WELCOME_EVERYONE)
		return TRUE
	if (!party)
		return FALSE
	if (party == owner_party)
		return TRUE
	return welcome == BERTH_WELCOME_GUESTS && (party in guests)

// TRUE when a craft of that length and beam fits.
/obj/structure/berth/proc/fits_size(length, beam)
	return length <= berth_length && beam <= berth_beam

// Why this craft cannot have the berth, or null when it can. forced skips the
// welcome (a boarding under the raid rule); nothing skips size or a taken berth.
/obj/structure/berth/proc/refusal(datum/craft/C, forced = FALSE)
	if (!C || !C.body)
		return "there is nothing to berth"
	if (occupant && occupant != C)
		return "the berth is taken by [occupant.name]"
	if (reserved && reserved.craft != C)
		return "the berth is promised to [reserved.craft ? reserved.craft.name : "another craft"]"
	if (!fits_size(C.body.length_tiles(), C.body.beam_tiles()))
		return "she is too big: the berth takes [berth_length] by [berth_beam]"
	if (!forced && !welcomes(C.party()))
		return "the berth does not welcome her party"
	return null

// Answers a craft that asks to dock: always a ticket, with refusal set when
// the answer is no. A granted ticket holds the berth until it is completed
// or released.
/obj/structure/berth/proc/request(datum/craft/C, forced = FALSE)
	var/datum/berth_ticket/T = new
	T.berth = src
	T.craft = C
	T.forced = forced
	T.refusal = refusal(C, forced)
	if (!T.refusal && C && C.ticket && C.ticket.berth != src)
		T.refusal = "she is already making for another berth"
	if (T.refusal)
		T.berth = null
		T.craft = null
		return T
	if (reserved)
		reserved.release()
	reserved = T
	C.ticket = T
	return T

/datum/berth_ticket
	var/obj/structure/berth/berth
	var/datum/craft/craft
	var/refusal = null
	var/forced = FALSE

/datum/berth_ticket/proc/granted()
	return !refusal && berth && craft && berth.reserved == src

// Gives the berth back without docking.
/datum/berth_ticket/proc/release()
	if (berth && berth.reserved == src)
		berth.reserved = null
	if (craft && craft.ticket == src)
		craft.ticket = null
	berth = null
	craft = null

// The craft has arrived: it now lies at the berth. Moving the craft there is
// the caller's work; this only records it.
/datum/berth_ticket/proc/complete()
	if (!granted())
		return FALSE
	var/obj/structure/berth/B = berth
	var/datum/craft/C = craft
	if (C.berth && C.berth != B && C.berth.occupant == C)
		C.berth.occupant = null
	B.occupant = C
	C.berth = B
	release()
	return TRUE

// The craft leaves its berth.
/datum/craft/proc/cast_off()
	if (!berth)
		return FALSE
	if (berth.occupant == src)
		berth.occupant = null
	berth = null
	return TRUE

// The smallest free berth in the list that will take this craft, or null:
// a harbour gives a small boat a small berth and keeps the big ones.
/proc/berth_best_fit(list/berths, datum/craft/C, forced = FALSE)
	var/obj/structure/berth/best = null
	for (var/obj/structure/berth/B in berths)
		if (B.refusal(C, forced))
			continue
		if (!best || B.berth_length * B.berth_beam < best.berth_length * best.berth_beam)
			best = B
	return best
