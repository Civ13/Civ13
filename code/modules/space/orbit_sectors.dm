// ============================================================
// Station sectors (orbital stations, stage D)
// ------------------------------------------------------------
// From 2026 a station also grows outward. A sector is another plane linked
// at a cardinal edge of a station plane (orbit_world.dm seams): walking,
// drifting or carrying a kit off that edge arrives one tile inside the
// matching edge of the sector, on the same deck. The station quota of 6
// planes covers decks and sectors together.
//
// - A sector beacon, used within ORBIT_SECTOR_REACH tiles of an unlinked
//   edge of the party's own plane, claims a free plane and links it there.
// - Power crosses the seam through edge couplers: secure one on a cable one
//   tile inside a linked edge and another at the matching spot across the
//   seam, and every cable on both tiles joins one grid (like cable risers).
// - Modules and pods keep two tiles clear of every edge, so nothing stands on
//   a seam or on the tile where travellers arrive.
//
// Links live in the plane registry; couplers pair from positions each time,
// so nothing cross-level is saved.
// ============================================================

#define ORBIT_SECTOR_AGE 9
#define ORBIT_SECTOR_REACH 4
#define ORBIT_SECTOR_DELAY 50
// Tiles at each edge that modules and pods leave clear: the seam itself and
// the arrival tile inside it.
#define ORBIT_SEAM_MARGIN 2

var/global/list/orbit_sector_sides = list("north", "east", "south", "west")

// TRUE when the square of radius r around centre keeps clear of the seams.
/proc/orbit_clear_of_seams(turf/centre, r)
	if (!centre)
		return FALSE
	var/m = ORBIT_SEAM_MARGIN
	return centre.x - r > m && centre.y - r > m && centre.x + r <= world.maxx - m && centre.y + r <= world.maxy - m

// The nearest plane edge within reach of T ("north", ...), or null.
/proc/orbit_sector_side(turf/T)
	if (!T)
		return null
	var/list/distances = list("north" = world.maxy - T.y, "south" = T.y - 1, "east" = world.maxx - T.x, "west" = T.x - 1)
	var/best = null
	for (var/side in orbit_sector_sides)
		if (distances[side] <= ORBIT_SECTOR_REACH && (!best || distances[side] < distances[best]))
			best = side
	return best

// ---------------------------------------------------------------- beacon

/obj/item/sector_beacon
	name = "sector beacon"
	desc = "A survey transmitter and a bundle of marker lines. In orbit, carry it to the edge of your station's plane and switch it on to claim the space beyond for a new sector."
	icon = 'icons/obj/device.dmi'
	icon_state = "radio_transmitter"
	w_class = ITEM_SIZE_NORMAL
	flammable = FALSE

// Null when a sector may be claimed from T on side, otherwise why not.
/proc/orbit_sector_refusal(turf/T, side, mob/user)
	if (!orbit_world() || !T)
		return "Sectors are only claimed in orbit."
	if (!map || map.ordinal_age < ORBIT_SECTOR_AGE)
		return "Stations only grow outward from 2026."
	var/party = orbit_station_party(T.z)
	if (!party)
		return "Only a station's plane can grow new sectors."
	if (user && !party_train_may_board(user, party))
		return "This station belongs to [party_train_party_name(party)]."
	if (!side)
		return "Carry it to within [ORBIT_SECTOR_REACH] tiles of the plane's edge."
	if (orbit_plane_link(T.z, side))
		return "A sector already lies [side] of here."
	if (length(orbit_station_planes(party)) >= ORBIT_STATION_PLANE_QUOTA)
		return "The station already has [ORBIT_STATION_PLANE_QUOTA] decks and sectors, the most one party may hold."
	if (!length(orbit_free_planes()))
		return "Every plane in orbit is taken."
	if (persistence_save_active())
		return "The world is saving. Try again in a moment."
	return null

// Claims a plane for the station on z and links it on side. Returns the new
// plane, or 0.
/proc/orbit_add_sector(z, side)
	var/party = orbit_station_party(z)
	if (!party || !(side in orbit_sector_sides) || orbit_plane_link(z, side))
		return 0
	var/level = orbit_claim_plane(orbit_station_owner(party))
	if (!level)
		return 0
	if (!orbit_link_planes(z, side, level))
		orbit_release_plane(level)
		return 0
	orbit_couple_seam(z, side)
	log_game("Orbit station: [party] added a sector [side] (plane [level]) from plane [z].")
	return level

/obj/item/sector_beacon/attack_self(mob/living/human/user)
	if (!istype(user) || !isturf(user.loc))
		return
	var/turf/T = user.loc
	var/side = orbit_sector_side(T)
	var/reason = orbit_sector_refusal(T, side, user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	if (WWinput(user, "Claim the space [side] of this plane for a new sector?", "Sector beacon", "Cancel", list("Claim", "Cancel")) != "Claim")
		return
	to_chat(user, SPAN_NOTICE("You switch on \the [src] and pay out the marker lines..."))
	if (!do_after(user, ORBIT_SECTOR_DELAY, T) || QDELETED(src) || loc != user || user.loc != T)
		return
	reason = orbit_sector_refusal(T, side, user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	if (!orbit_add_sector(T.z, side))
		to_chat(user, SPAN_WARNING("The beacon finds no free space to claim."))
		return
	user.visible_message(SPAN_NOTICE("[user] marks out a new sector [side] of the station."))
	qdel(src)

// ---------------------------------------------------------------- couplers

/obj/item/connector/riser/coupler
	name = "edge coupler"
	desc = "A heavy cable joint for the seam between two station sectors. Secure it on a cable one tile inside a linked edge, and secure another at the matching spot across the seam: every cable on both tiles joins one grid."
	color = "#60a0c0"

// The tiles across a linked seam that match T (one per linked side T sits
// on, so a corner tile can match two).
/proc/orbit_coupler_spots(turf/T)
	var/list/spots = list()
	if (!T || !orbit_world())
		return spots
	for (var/side in orbit_sector_sides)
		var/turf/S = null
		var/other = orbit_plane_link(T.z, side)
		if (!other)
			continue
		switch (side)
			if ("north")
				if (T.y == world.maxy - 1)
					S = locate(T.x, 2, other)
			if ("south")
				if (T.y == 2)
					S = locate(T.x, world.maxy - 1, other)
			if ("east")
				if (T.x == world.maxx - 1)
					S = locate(2, T.y, other)
			if ("west")
				if (T.x == 2)
					S = locate(world.maxx - 1, T.y, other)
		if (S)
			spots += S
	return spots

/obj/item/connector/riser/coupler/riser_partners()
	var/list/partners = list()
	if (!anchored || !isturf(loc))
		return partners
	for (var/turf/S in orbit_coupler_spots(loc))
		for (var/obj/item/connector/riser/coupler/C in S)
			if (C != src && C.anchored && !QDELETED(C))
				partners |= C
	return partners

// Joins the couplers already secured along one edge, after a new link.
/proc/orbit_couple_seam(z, side)
	var/turf/A
	var/turf/B
	switch (side)
		if ("north")
			A = locate(1, world.maxy - 1, z)
			B = locate(world.maxx, world.maxy - 1, z)
		if ("south")
			A = locate(1, 2, z)
			B = locate(world.maxx, 2, z)
		if ("east")
			A = locate(world.maxx - 1, 1, z)
			B = locate(world.maxx - 1, world.maxy, z)
		if ("west")
			A = locate(2, 1, z)
			B = locate(2, world.maxy, z)
	if (!A || !B)
		return 0
	var/joined = 0
	for (var/turf/T in block(A, B))
		for (var/obj/item/connector/riser/coupler/C in T)
			if (C.anchored && length(C.riser_partners()))
				C.connect_cables()
				joined++
	return joined

/obj/item/connector/riser/coupler/examine(mob/user)
	. = ..()
	if (anchored && !length(orbit_coupler_spots(loc)))
		to_chat(user, SPAN_WARNING("It must sit one tile inside an edge that leads to another sector."))
