// ============================================================
// Walking between lands over a shared map edge (docs/americas-regions.md)
// ------------------------------------------------------------
// Where one land mass is split over two regions (the Americas at the isthmus),
// the edge of the map is not the end of the land. A map names the neighbour
// beyond an edge in edge_crossings. A player who walks onto dry or wadeable
// ground at that edge is asked once whether to walk on; on "Travel" they leave
// as an ordinary region traveller (region_travel.dm) and come out on the
// matching edge of the neighbour, as far along it as they were here.
//
// Nothing stands on the map for this: the hidden gate below exists only while
// one traveller is asked and sent. Riders and anyone dragging something are
// told to go on foot; vehicles do not cross yet.
// ============================================================

// How far in from the border an arriving walker is put down, so the first
// step is theirs and the edge does not ask them straight back.
#define REGION_EDGE_ARRIVAL_INSET 3
// How long a player who said no is left alone.
#define REGION_EDGE_ASK_COOLDOWN 300
// Wading out past the last dry tile of the edge still counts as the crossing.
#define REGION_EDGE_SHORE 4

// "north", "south", "east" or "west" = region id of the land beyond that edge.
/obj/map_metadata/var/list/edge_crossings = null

/mob/living/human/var/tmp/region_edge_asking = FALSE
/mob/living/human/var/tmp/region_edge_asked_at = 0

/mob/living/human/persistence_runtime_var(key)
	return key == "region_edge_asking" || key == "region_edge_asked_at" || ..()

var/global/list/region_edge_spans = list()

/proc/region_edge_dir(side)
	switch (side)
		if ("north") return NORTH
		if ("south") return SOUTH
		if ("east") return EAST
		if ("west") return WEST
	return 0

/proc/region_edge_opposite(side)
	switch (side)
		if ("north") return "south"
		if ("south") return "north"
		if ("east") return "west"
		if ("west") return "east"
	return null

// Ground a walker can stand on at the edge: no rock, lava or deep water.
/proc/region_edge_ground(turf/T, dry = FALSE)
	if (!istype(T, /turf/floor) || T.density)
		return FALSE
	if (istype(T, /turf/floor/dirt/underground) || istype(T, /turf/floor/lava) || istype(T, /turf/floor/beach/water/deep))
		return FALSE
	if (dry && istype(T, /turf/floor/beach/water))
		return FALSE
	return TRUE

// The turf at position a along a side, depth tiles in from the border.
/proc/region_edge_turf(side, a, depth = 0)
	switch (side)
		if ("north") return locate(a, world.maxy - depth, 1)
		if ("south") return locate(a, 1 + depth, 1)
		if ("east") return locate(world.maxx - depth, a, 1)
		if ("west") return locate(1 + depth, a, 1)
	return null

// list(first, last) positions of dry ground along a side's border row, or null.
/proc/region_edge_span(side)
	if (side in region_edge_spans)
		return region_edge_spans[side]
	var/first = 0
	var/last = 0
	var/length = (side == "north" || side == "south") ? world.maxx : world.maxy
	for (var/a = 1 to length)
		if (region_edge_ground(region_edge_turf(side, a), TRUE))
			if (!first)
				first = a
			last = a
	region_edge_spans[side] = first ? list(first, last) : null
	return region_edge_spans[side]

// The side whose crossing T lies on, or null.
/proc/region_edge_side(turf/T)
	if (!map || !length(map.edge_crossings) || !istype(T) || T.z != 1)
		return null
	var/side = null
	if (T.y == 1) side = "south"
	else if (T.y == world.maxy) side = "north"
	else if (T.x == 1) side = "west"
	else if (T.x == world.maxx) side = "east"
	if (!side || !map.edge_crossings[side] || !region_edge_ground(T))
		return null
	var/list/span = region_edge_span(side)
	if (!span)
		return null
	var/a = (side == "north" || side == "south") ? T.x : T.y
	if (a < span[1] - REGION_EDGE_SHORE || a > span[2] + REGION_EDGE_SHORE)
		return null
	return side

// How far along the side's dry ground T is, 0 to 1.
/proc/region_edge_fraction(side, turf/T)
	var/list/span = region_edge_span(side)
	if (!span || span[2] <= span[1])
		return 0.5
	var/a = (side == "north" || side == "south") ? T.x : T.y
	return round(clamp((a - span[1]) / (span[2] - span[1]), 0, 1), 0.001)

// ---------------------------------------------------------------- leaving

// The way a walker leaves: a hidden gate that exists only for their crossing.
/obj/structure/region_gate/land_edge
	name = "the way on"
	desc = "The land carries on beyond here."
	invisibility = 101
	icon = null
	// Never part of a save: it lasts only while one walker is asked and sent.
	should_save = FALSE
	var/list/crossing = null

/obj/structure/region_gate/land_edge/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/land_edge/travel_extra(mob/living/human/H)
	return crossing ? list("edge" = crossing) : null

/obj/structure/region_gate/land_edge/attack_hand(mob/living/human/user)
	return

/obj/structure/region_gate/land_edge/attack_ghost(mob/user)
	return

/obj/structure/region_gate/land_edge/closed_reason()
	. = ..()
	// The shared wording speaks of a trail; there is none here.
	if (. && findtext(., "trail"))
		if (busy || persistence_save_active())
			return "You cannot walk on just now. Try again in a moment."
		return "The land goes on, but nobody can walk on into [destination_name() || "it"] right now."

// A walk across the border takes wounds along (they travel as damage), so
// unlike a trail it does not ask for full health.
/obj/structure/region_gate/land_edge/travel_refusal(mob/living/human/H)
	var/reason = closed_reason()
	if (reason) return reason
	if (H.client ? IsGuestKey(H.client.key) : !agent_travel_account(H)) return "Only players with a BYOND account can travel."
	if (H.buckled || H.riding || H.riding_mob || H.driver || H.driver_vehicle) return "You cannot ride or drive across yet. Get down and walk on."
	if (H.pulling) return "You cannot drag anything across. Let go and walk on."
	if (H.stat != CONSCIOUS || H.restrained()) return "You can't set off right now."
	if (get_turf(H) != loc && H.loc != src) return "You turned back from the edge of the land."
	return null

// Called after a human's own step. Asks, and sends them on a yes.
/mob/living/human/proc/region_edge_check()
	if (region_edge_asking || !map || !map.edge_crossings)
		return
	var/turf/T = loc
	if (!isturf(T) || (T.y != 1 && T.x != 1 && T.y != world.maxy && T.x != world.maxx))
		return
	var/side = region_edge_side(T)
	if (!side)
		return
	if (!client && !agent_travel_account(src))
		return
	if (world.time < region_edge_asked_at + REGION_EDGE_ASK_COOLDOWN)
		return
	region_edge_asking = TRUE
	region_edge_asked_at = world.time
	region_edge_cross(side, T)

// Asks and waits on its own; the step that led here is not held up.
/mob/living/human/proc/region_edge_cross(side, turf/T)
	set waitfor = FALSE
	var/obj/structure/region_gate/land_edge/gate = new(T)
	gate.destination = map.edge_crossings[side]
	gate.crossing = list(side, region_edge_fraction(side, T))
	gate.travel(src)
	// travel() returns once they left, said no or were refused.
	if (!QDELETED(gate))
		qdel(gate)
	if (!QDELETED(src))
		region_edge_asking = FALSE
		region_edge_asked_at = world.time

// ---------------------------------------------------------------- arriving

/proc/region_edge_payload_ok(list/P)
	var/list/E = P["edge"]
	if (isnull(E))
		return TRUE
	return islist(E) && E.len == 2 && !!region_edge_dir(E[1]) && isnum(E[2]) && E[2] >= 0 && E[2] <= 1

// Where a walker who crossed an edge comes out: the matching place on the
// facing edge here, a few steps in. Null when this land has no such edge.
/proc/region_edge_arrival_turf(list/P, incoming)
	if (!islist(P) || !islist(P["edge"]) || !map || !length(map.edge_crossings))
		return null
	var/list/E = P["edge"]
	// Turned back at the far side: they stand where they left.
	var/side = incoming ? region_edge_opposite(E[1]) : E[1]
	if (!side || (incoming && map.edge_crossings[side] != P["from"]))
		return null
	var/list/span = region_edge_span(side)
	if (!span)
		return null
	var/at = round(span[1] + E[2] * (span[2] - span[1]))
	// The nearest free dry ground to that spot, working inland and outward.
	for (var/depth = REGION_EDGE_ARRIVAL_INSET, depth <= REGION_EDGE_ARRIVAL_INSET + 12, depth++)
		for (var/off = 0, off <= 12, off++)
			for (var/sign in list(1, -1))
				if (!off && sign < 0)
					continue
				var/turf/T = region_edge_turf(side, at + off * sign, depth)
				if (!region_edge_ground(T, TRUE))
					continue
				var/blocked = FALSE
				for (var/atom/movable/M in T)
					if (M.density && !istype(M, /atom/movable/lighting_overlay))
						blocked = TRUE
						break
				if (!blocked)
					return T
	return null

/proc/region_edge_arrived(mob/living/human/H, list/P, incoming)
	if (!istype(H) || !islist(P) || !islist(P["edge"]))
		return
	// Faces inland, so the next step leads on and not straight back.
	var/side = incoming ? region_edge_opposite(P["edge"][1]) : P["edge"][1]
	H.dir = turn(region_edge_dir(side), 180)

#undef REGION_EDGE_ARRIVAL_INSET
#undef REGION_EDGE_ASK_COOLDOWN
#undef REGION_EDGE_SHORE
