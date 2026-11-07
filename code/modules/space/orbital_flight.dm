// ============================================================
// Orbital flight (orbital stations, stage B, 1969)
// ------------------------------------------------------------
// A two-stage rocket is a crewed lander (lander.dm) that only flies to an
// orbit region (shard kind ORBIT, orbit_world.dm): three seats, a ten-item
// hold and twice the propellant. It launches from an ordinary admin-approved
// launch pad. Orbit needs no survey map, and opens from 1969 (Cold War, age 7).
//
// The crew arrive in an orbital capsule: the first arrival of a flight claims
// a free plane for it and builds it in the middle; when every plane is taken
// it is built at a clear spot on the arrival plane. Like a landed lander, the
// capsule is a 3x3 sealed deck around a life-support core with a few hours of
// air and power and one claimable bunk, so orbit can be made home at once.
//
// To come home, the crew strap in on the capsule's tile and deorbit. They
// travel to the mainland like any returning flight (a "return" payload) and
// the capsule is spent: its deck goes back to vacuum, its bunk goes, and its
// plane is released when nothing else stands on it. A capsule will not
// deorbit while someone else is left in its cabin or keeps its bunk as home.
//
// Nothing here is a world.time stamp, and the capsule ticks only while the
// world has players (as every habitat ledger does).
// ============================================================

#define ORBIT_ROCKET_PROPELLANT 600
#define ORBIT_ROCKET_SEATS 3
#define ORBIT_ROCKET_CARGO_MAX 10
// The epoch (map.ordinal_age) orbit opens in: 1969, as the Moon.
#define ORBIT_MIN_AGE 7

// TRUE when a pad here may fly to region id: an orbit region, from a world
// that is not itself in orbit, once the epoch has reached 1969.
/proc/space_flight_orbit_ok(id)
	if (!istext(id) || !shard_group || !shard_group.enabled || orbit_world())
		return FALSE
	var/list/peer = shard_group.peers[id]
	return islist(peer) && peer["kind"] == "ORBIT" && map && map.ordinal_age >= ORBIT_MIN_AGE

// TRUE when the orbit region last said it has no free plane.
/proc/space_flight_orbit_full(id)
	var/list/peer = shard_group && shard_group.peers[id]
	return islist(peer) && isnum(peer["free_planes"]) && peer["free_planes"] <= 0

// ---------------------------------------------------------------- rocket

/obj/structure/crewed_lander/orbital_rocket
	name = "two-stage rocket"
	desc = "A tall two-stage rocket with a three-seat capsule on top. Fill it with rocket propellant beside an approved launch pad to orbit, strap in on its tile and launch."
	propellant_needed = ORBIT_ROCKET_PROPELLANT
	seats = ORBIT_ROCKET_SEATS
	cargo_max = ORBIT_ROCKET_CARGO_MAX

/obj/structure/crewed_lander/orbital_rocket/vehicle_refusal(destination)
	if (!space_flight_orbit_ok(destination))
		return "\The [src] only flies to orbit. Point the pad at an orbit to launch it."
	if (space_flight_orbit_full(destination))
		return "Every plane in [region_trail_name(destination)] is taken. Wait until one is freed."
	return null

// ---------------------------------------------------------------- capsule

/obj/structure/landed_lander/capsule
	name = "orbital capsule"
	desc = "A three-seat capsule in orbit. Its core keeps the small cabin around it sealed, warm and breathable for a few hours. Strap in on its tile and deorbit to fly home; the capsule is spent."
	// The registry owner of the plane this capsule claimed, or null on the
	// arrival plane. Plain text, as every registry field.
	var/plane_owner = null
	// ckeys of the crew strapped in for the flight home. Runtime only.
	var/tmp/list/strapped = list()

/obj/structure/landed_lander/capsule/ambient_c()
	return ORBIT_VACUUM_C

// There are no dust storms in orbit.
/obj/structure/landed_lander/capsule/hazards_pulse()
	return

/obj/structure/landed_lander/capsule/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Crew strapped in for home: [length(crew())]/[ORBIT_ROCKET_SEATS]."))

/obj/structure/landed_lander/capsule/proc/crew()
	var/list/found = list()
	for (var/mob/living/human/H in get_turf(src))
		if (H.client && H.stat == CONSCIOUS && (H.client.ckey in strapped))
			found += H
	return found

/obj/structure/landed_lander/capsule/attack_hand(mob/user as mob)
	var/mob/living/human/H = user
	if (!istype(H) || !H.client)
		return
	var/strapped_in = (H.client.ckey in strapped) && get_turf(H) == get_turf(src)
	var/choice = WWinput(H, "Crew strapped in for home: [length(crew())]/[ORBIT_ROCKET_SEATS]. Deorbiting spends the capsule.", capitalize(name), "Cancel", list(strapped_in ? "Unstrap" : "Strap in", "Deorbit", "Cancel"))
	if (QDELETED(src) || !H.client || !in_range(src, H) || H.incapacitated())
		return
	switch (choice)
		if ("Strap in")
			if (get_turf(H) != get_turf(src))
				to_chat(H, SPAN_WARNING("Stand on \the [src] to strap in."))
			else if (length(crew()) >= ORBIT_ROCKET_SEATS)
				to_chat(H, SPAN_WARNING("Every seat is taken."))
			else
				strapped |= H.client.ckey
				to_chat(H, SPAN_NOTICE("You strap into \the [src]. Stay on its tile: you fly home when a crewmate deorbits."))
		if ("Unstrap")
			strapped -= H.client.ckey
			to_chat(H, SPAN_NOTICE("You unstrap from \the [src]."))
		if ("Deorbit")
			deorbit_prompt(H)

// Null when the capsule may deorbit now, otherwise why not.
/obj/structure/landed_lander/capsule/proc/deorbit_refusal(mob/living/human/H)
	if (!istext(shard_group.mainland) || !space_flight_return_ok(shard_group.mainland))
		return "There is no way home from here."
	if (persistence_save_active())
		return "The world is saving. Try again in a moment."
	if (H && !(H in crew()))
		return "Strap in before you deorbit."
	var/list/aboard = crew()
	var/list/crew_keys = list()
	for (var/mob/living/human/C in aboard)
		crew_keys += C.client.ckey
	for (var/mob/living/human/other in range(LANDER_DECK_RADIUS, src))
		if (other.stat != DEAD && !(other in aboard) && istype(get_turf(other), /turf/floor/lander_deck))
			return "Everyone in the cabin must strap in or leave it first."
	for (var/obj/structure/bed/lander_bunk/B in range(LANDER_DECK_RADIUS, src))
		if (B.persistence_bed_owner_ckey && !(B.persistence_bed_owner_ckey in crew_keys))
			return "Someone who is not strapped in keeps the bunk here as their home."
	return null

/obj/structure/landed_lander/capsule/proc/deorbit_prompt(mob/living/human/H)
	var/reason = deorbit_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/home = shard_group.mainland
	if (WWinput(H, "Deorbit and fly everyone strapped in home to [region_trail_name(home)], with what they wear and carry? The capsule is spent.", "Deorbit", "Cancel", list("Deorbit", "Cancel")) != "Deorbit")
		return
	if (QDELETED(src) || !H.client || !in_range(src, H))
		return
	// The prompt slept: check everything again.
	reason = deorbit_refusal(H) || deorbit(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))

// Sends every strapped-in crew member home. Returns null once anyone left (the
// capsule is then spent), or the reason nobody did.
/obj/structure/landed_lander/capsule/proc/deorbit(mob/living/human/notify = null)
	var/home = shard_group.mainland
	if (shard_group.enabled && shard_group.peers[home] && shard_group.peers[home]["state"] != "UP")
		var/woke = shard_group.wake_peer(home, notify)
		if (woke)
			return woke
		if (QDELETED(src))
			return "The flight home was called off."
	var/obj/structure/region_gate/capsule_hatch/hatch = new(get_turf(src))
	hatch.destination = home
	hatch.pending_flight = list("lander" = lander_id, "return" = 1)
	var/departed = 0
	var/list/refusals = list()
	for (var/mob/living/human/H in crew())
		var/reason = QDELETED(hatch) ? "The hatch jammed." : hatch.travel_refusal(H)
		if (!reason)
			var/list/items = H.region_travel_items()
			if (istext(items))
				reason = items
		if (!reason)
			H.record_persistence_owner()
			reason = hatch.depart(H)
		if (reason == "departed")
			departed++
		else
			refusals += "[H.real_name]: [reason]"
			to_chat(H, SPAN_WARNING("You stay behind: [reason]"))
	if (!QDELETED(hatch))
		qdel(hatch)
	if (!departed)
		return refusals.len ? "Nobody could deorbit. [jointext(refusals, " ")]" : "Nobody is strapped in."
	log_game("Orbital flight: [departed] crew deorbited capsule [lander_id] at [x],[y],[z] for home at [home].")
	visible_message(SPAN_DANGER("\The [src] fires its retro-rockets and falls away toward the world below!"))
	spend()
	return null

// The capsule is gone: its deck goes back to vacuum, its bunk goes, and its
// plane is released when nothing else stands on it.
/obj/structure/landed_lander/capsule/proc/spend()
	var/turf/center = get_turf(src)
	var/plane = center ? center.z : 0
	if (center)
		for (var/obj/structure/bed/lander_bunk/B in range(LANDER_DECK_RADIUS, center))
			qdel(B)
		for (var/turf/floor/lander_deck/T in range(LANDER_DECK_RADIUS, center))
			T.ChangeTurf(/turf/floor/space/orbit, FALSE, FALSE)
	var/owner = plane_owner
	qdel(src)
	if (owner && plane && orbit_plane_owner(plane) == owner && orbit_plane_empty(plane))
		orbit_release_plane(plane)
		log_game("Orbital flight: plane [plane] released after its capsule was spent.")

// ---------------------------------------------------------------- hatch

// The capsule's way home while it deorbits. It exists only during a deorbit
// and is never used by hand; one left by a save is removed on load.
/obj/structure/region_gate/capsule_hatch
	name = "capsule hatch"
	invisibility = 101
	icon_state = null
	var/tmp/list/pending_flight = null

/obj/structure/region_gate/capsule_hatch/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/capsule_hatch/attack_hand(mob/living/human/user)
	return

/obj/structure/region_gate/capsule_hatch/travel_extra(mob/living/human/H)
	return pending_flight

/obj/structure/region_gate/capsule_hatch/after_load()
	..()
	qdel(src)

// ---------------------------------------------------------------- arrival

// TRUE when nothing but vacuum and passing effects is left on plane z.
/proc/orbit_plane_empty(z)
	if (!orbit_valid_plane(z))
		return FALSE
	for (var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		if (!istype(T, /turf/floor/space/orbit))
			return FALSE
		for (var/atom/movable/A in T)
			if (isobserver(A) || istype(A, /obj/effect) || istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))
				continue
			return FALSE
	return TRUE

// TRUE when a capsule deck centred on x,y,z lies on open vacuum, clear of the
// edge seams.
/proc/orbit_capsule_site_clear(x, y, z)
	if (x - LANDER_DECK_RADIUS < 2 || y - LANDER_DECK_RADIUS < 2 || x + LANDER_DECK_RADIUS > world.maxx - 1 || y + LANDER_DECK_RADIUS > world.maxy - 1)
		return FALSE
	if (!space_deck_clear(x, y, z))
		return FALSE
	for (var/turf/T in block(locate(x - LANDER_DECK_RADIUS, y - LANDER_DECK_RADIUS, z), locate(x + LANDER_DECK_RADIUS, y + LANDER_DECK_RADIUS, z)))
		if (!istype(T, /turf/floor/space/orbit))
			return FALSE
	return TRUE

// The clear capsule site on plane z nearest its middle, or null.
/proc/orbit_capsule_site(z)
	var/cx = round(world.maxx / 2)
	var/cy = round(world.maxy / 2)
	for (var/r = 0, r <= max(world.maxx, world.maxy), r++)
		for (var/y = cy - r, y <= cy + r, y++)
			for (var/x = cx - r, x <= cx + r, x++)
				if (max(abs(x - cx), abs(y - cy)) != r)
					continue
				if (orbit_capsule_site_clear(x, y, z))
					return locate(x, y, z)
	return null

// Where an arriving crew member of a flight to orbit appears: their capsule,
// built by the first arrival. Null off an orbit world, or when no site is
// left; they then arrive like any traveller.
/proc/orbit_capsule_arrival_turf(list/P)
	if (!orbit_world() || !islist(P) || !istext(P["lander"]))
		return null
	var/obj/structure/landed_lander/L = space_landed_lander(P["lander"])
	if (L)
		return get_turf(L)
	var/owner = "capsule:[P["lander"]]"
	var/plane = orbit_claim_plane(owner)
	var/turf/T = plane ? orbit_capsule_site(plane) : null
	if (!T)
		if (plane)
			orbit_release_plane(plane)
		owner = null
		T = orbit_capsule_site(ORBIT_ARRIVAL_PLANE)
	if (!T)
		return null
	var/obj/structure/landed_lander/capsule/C = new(T)
	C.lander_id = P["lander"]
	C.plane_owner = owner
	C.deploy()
	log_game("Orbital flight: capsule [C.lander_id] arrived at [T.x],[T.y],[T.z][owner ? " on its own plane" : " on the arrival plane"].")
	return T
