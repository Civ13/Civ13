// Holding travellers still while they leave for another region (Val,
// 2026-11-22). Once a trip is confirmed (a trail or the edge of the land, a
// ship's crossing, a flight, a lander, or an admin's send in
// region_admin_send.dm), everyone going is held: they can look around and chat,
// but cannot move, click, use, drop or equip anything, and any action in
// progress stops, so what the checks saw is what travels. Their belongings,
// what they ride or pull, and the ship or craft they leave in are guarded:
// nobody else may touch, take from, board or move any of it.
//
// A hold ends when the transfer agent has recorded the trip (the travellers
// are then safe in its journal and leave this land), or as soon as the trip
// fails or is called off, and it lapses by itself after TRAVEL_HOLD_TIME if
// nothing renews it, so nobody is ever left frozen.

// Deciseconds a hold lasts unless renewed: longer than a cold land takes to
// start (travel_start_estimate_seconds), so it never lapses while its trip is
// still on its way.
#define TRAVEL_HOLD_TIME 9000
// Deciseconds between reminders to a held traveller who keeps trying to act.
#define TRAVEL_HOLD_REMIND 50

/datum/travel_hold
	// The humans held still.
	var/list/travellers = list()
	// Things nobody else may touch (a cart, a mount, a tiller, a plane's parts).
	var/list/guarded = list()
	// Tiles nobody else may step onto or reach into (a deck), as turf = TRUE.
	var/list/ground = null
	var/where
	var/until = 0
	// An admin's send, which words its notices as one.
	var/admin = FALSE

/datum/travel_hold/proc/active()
	return world.time < until

// Live holds; null while there are none, so every check stays one test.
var/global/list/travel_holds = null

// The hold a traveller is in.
/mob/living/human/var/tmp/datum/travel_hold/travel_hold = null
/mob/living/human/var/tmp/travel_hold_told = 0
// When someone reaching for a guarded traveller or thing was last told why not.
/mob/var/tmp/travel_guard_told = 0

// Never saved: region_admin_send.dm's persistence_runtime_var lists them.

/mob/proc/travel_held()
	return FALSE

/mob/living/human/travel_held()
	return travel_hold && travel_hold.active()

// Holds travellers still for a trip to where, guarding guarded and the tiles
// in ground. Returns the hold, to renew and end.
/proc/travel_hold_begin(list/travellers, where, list/guarded = null, list/ground = null, admin = FALSE)
	travel_hold_sweep()
	var/datum/travel_hold/hold = new
	hold.where = where
	hold.admin = admin
	hold.until = world.time + TRAVEL_HOLD_TIME
	if (guarded)
		hold.guarded = guarded.Copy()
	if (length(ground))
		hold.ground = list()
		for (var/turf/T in ground)
			hold.ground[T] = TRUE
	LAZYINITLIST(travel_holds)
	travel_holds += hold
	for (var/mob/living/human/H in travellers)
		travel_hold_add(hold, H)
	return hold

// Adds H to hold, letting go of anyone else's grip on them.
/proc/travel_hold_add(datum/travel_hold/hold, mob/living/human/H)
	if (!hold || !istype(H) || QDELETED(H) || (H in hold.travellers))
		return
	var/was = H.travel_held()
	hold.travellers += H
	H.travel_hold = hold
	var/mob/M = H.pulledby
	if (M && !(M in hold.travellers))
		M.stop_pulling()
	if (was)
		return
	H.travel_hold_told = world.time
	if (H.client)
		var/opening = hold.admin ? "An admin is sending you to [hold.where]." : "You are setting off for [hold.where]."
		to_chat(H, SPAN_WARNING("<b>[opening]</b> Stay put: you can look around and chat, but you cannot move or act until you leave."))

/proc/travel_hold_renew(datum/travel_hold/hold)
	if (hold && (hold in travel_holds))
		hold.until = world.time + TRAVEL_HOLD_TIME

// Lets one traveller go (they did not leave). They stay in any other live hold.
/proc/travel_hold_release(datum/travel_hold/hold, mob/living/human/H)
	if (!hold || !istype(H))
		return
	hold.travellers -= H
	if (QDELETED(H) || H.travel_hold != hold)
		return
	var/was = hold.active()
	H.travel_hold = null
	for (var/datum/travel_hold/other in travel_holds)
		if (other != hold && other.active() && (H in other.travellers))
			H.travel_hold = other
			return
	if (was && H.client)
		var/stayed = hold.admin ? "The send was called off, so you stay here." : "You did not leave, so you stay here."
		to_chat(H, SPAN_NOTICE("[stayed] You can move and act again."))

// Ends hold: whoever is still here can act again, and everything is unguarded.
/proc/travel_hold_end(datum/travel_hold/hold)
	if (!hold)
		return
	for (var/mob/living/human/H in hold.travellers.Copy())
		travel_hold_release(hold, H)
	hold.travellers.Cut()
	hold.guarded.Cut()
	hold.ground = null
	hold.until = 0
	if (travel_holds)
		travel_holds -= hold
		if (!travel_holds.len)
			travel_holds = null

// Drops holds that lapsed (a trip that died part way), freeing their travellers.
/proc/travel_hold_sweep()
	for (var/datum/travel_hold/hold in travel_holds)
		if (!hold.active())
			travel_hold_end(hold)

// A held traveller's click, step or action is refused, with a reminder now and then.
/proc/travel_hold_input(mob/M)
	if (!M || !M.travel_held())
		return FALSE
	var/mob/living/human/H = M
	if (world.time >= H.travel_hold_told + TRAVEL_HOLD_REMIND)
		H.travel_hold_told = world.time
		to_chat(H, SPAN_WARNING("You are leaving for [H.travel_hold.where]. Stay put until you leave."))
	return TRUE

// The live hold that guards A from user, or null. A traveller, what they wear
// and carry at any depth, what a hold guards and what lies on its ground are
// guarded from everyone not in that hold.
/proc/travel_hold_guarding(mob/user, atom/A)
	if (!travel_holds || !A)
		return null
	var/turf/T = get_turf(A)
	for (var/datum/travel_hold/hold in travel_holds)
		if (!hold.active())
			continue
		if (user && (user in hold.travellers))
			continue
		if (hold.ground && T && hold.ground[T])
			return hold
		var/atom/top = A
		while (top && !isturf(top))
			if ((top in hold.travellers) || (top in hold.guarded))
				return hold
			top = top.loc
	return null

// Refuses user's reach for A when a hold guards it, telling them why now and then.
/proc/travel_hold_refuses(mob/user, atom/A)
	var/datum/travel_hold/hold = travel_hold_guarding(user, A)
	if (!hold)
		return FALSE
	if (user && user.client && world.time >= user.travel_guard_told + TRAVEL_HOLD_REMIND)
		user.travel_guard_told = world.time
		var/going = hold.admin ? "They are being sent to [hold.where]." : "They are setting off for [hold.where]."
		to_chat(user, SPAN_WARNING("[going] Leave them and their things be."))
	return TRUE

// TRUE when M may not step onto T: the deck of a ship or craft whose crew are
// leaving, for anyone not going with them.
/proc/travel_hold_bars_step(mob/M, turf/T)
	if (!travel_holds || !T)
		return FALSE
	for (var/datum/travel_hold/hold in travel_holds)
		if (hold.ground && hold.ground[T] && hold.active() && !(M in hold.travellers))
			return TRUE
	return FALSE

// What H rides, drives or pulls, guarded with them on a walk or a trail.
/proc/travel_hold_belongings(mob/living/human/H)
	. = list()
	for (var/atom/movable/A in list(H.pulling, H.riding_mob, H.buckled, H.driver_vehicle))
		if (!QDELETED(A) && !(A in .))
			. += A

#undef TRAVEL_HOLD_TIME
#undef TRAVEL_HOLD_REMIND
