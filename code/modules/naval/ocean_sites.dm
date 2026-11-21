// ============================================================
// Sites at sea in the ocean regions (docs/ocean-regions.md)
// ------------------------------------------------------------
// An ocean is open water (ocean_regions.dm), but it is not empty. Each one
// has a fixed list of sites, rolled from the ocean's id so every restart
// finds them in the same places: islets (a small island with trees, rock and
// a fresh pond), reefs (shallow water, the best fishing at sea), wrecks
// (planks adrift with salvage) and sea marks (a named rock to steer by).
//
// A site is raised when a ship or a person comes within OCEAN_SITE_NEAR tiles
// of it, and the sea closes over it again SEA_SITE_LINGER after the last of
// them has gone OCEAN_SITE_FAR tiles away. Nothing about a site is kept in a
// registry: a raised site is part of the saved world like anything else, and
// it is known to be raised by what lies at its middle. A mooring post that
// takes ships on an islet makes a harbour of it, and up to SEA_KEPT_CAP
// harboured sites of an ocean stay for good.
//
// The islands and wrecks are built by the open sea's own builders
// (open_sea_sites.dm), on the ocean's one level.
// ============================================================

#define OCEAN_SITE_SCAN 100           // how often the sites look for ships, in ticks
#define OCEAN_SITE_NEAR 40            // a site rises when a ship or person is this near its edge
#define OCEAN_SITE_FAR 60             // it may go once everyone is this far from its edge
#define OCEAN_SITE_EDGE 60            // no site this near the map's edge
#define OCEAN_SITE_LANDING 80         // nor this near the landing rock in the middle
#define OCEAN_SITE_TILES 30000        // one site for every so many tiles of ocean
#define OCEAN_SITE_BASE /turf/floor/beach/water/deep/saltwater

var/global/list/ocean_sites = list()      // every /datum/ocean_site of this world
var/global/ocean_sites_timer = 0

/datum/ocean_site
	var/id = ""
	var/kind = "islet"
	var/name = "islet"
	var/x = 0
	var/y = 0
	var/seed = 1
	var/half = 48                     // half the side of the square it is built in
	var/tmp/linger_timer = 0

/datum/ocean_site/Destroy()
	ocean_sites -= src
	if (linger_timer)
		deltimer(linger_timer)
		linger_timer = 0
	return ..()

// list(x1, y1, x2, y2) of the square it is built in.
/datum/ocean_site/proc/box()
	return list(x - half, y - half, x + half, y + half)

// How far a turf lies outside its square, in tiles (0 inside it).
/datum/ocean_site/proc/distance_to(turf/T)
	if (!T || T.z != ocean_site_level())
		return 1e9
	return max(0, abs(T.x - x) - half, abs(T.y - y) - half)

// TRUE when the site stands in the sea now.
/datum/ocean_site/proc/raised()
	var/turf/T = locate(x, y, ocean_site_level())
	return T && T.type != OCEAN_SITE_BASE

// Raises it. TRUE when it is there.
/datum/ocean_site/proc/raise()
	if (raised())
		return TRUE
	build()
	log_game("Ocean site [id] ([kind]) raised at [x],[y].")
	return raised()

/datum/ocean_site/proc/build()
	return

// The open sea builder of an islet or a wreck, at this site.
/datum/ocean_site/proc/sea_builder(path)
	var/datum/chart_site/sea/S = new path
	S.id = id
	S.seed = seed
	S.level = ocean_site_level()
	S.build(box())
	qdel(S)

// A mooring post that takes ships stands in its square.
/datum/ocean_site/proc/has_harbour()
	var/list/B = box()
	for (var/obj/structure/berth/quay/Q in sea_harbours)
		if (!Q.takes_ships)
			continue
		var/turf/T = get_turf(Q)
		if (T && T.z == ocean_site_level() && T.x >= B[1] && T.x <= B[3] && T.y >= B[2] && T.y <= B[4])
			return TRUE
	return FALSE

// TRUE while a harbour keeps it: only the first SEA_KEPT_CAP harboured sites
// of the ocean, in the order of ocean_sites.
/datum/ocean_site/proc/held()
	if (!raised() || !has_harbour())
		return FALSE
	var/before = 0
	for (var/datum/ocean_site/S in ocean_sites)
		if (S == src)
			break
		if (S.raised() && S.has_harbour())
			before++
	return before < SEA_KEPT_CAP

// Why the sea cannot close over it now, or null.
/datum/ocean_site/proc/lower_refusal()
	if (!raised())
		return "it is not raised"
	if (held())
		return "a harbour keeps it"
	if (persistence_save_in_progress)
		return "the world is being saved"
	var/list/B = box()
	var/z = ocean_site_level()
	for (var/mob/living/human/H in human_mob_list)
		var/turf/T = get_turf(H)
		if ((H.stat != DEAD || H.client) && T && T.z == z && T.x >= B[1] && T.x <= B[3] && T.y >= B[2] && T.y <= B[4])
			return "[H.real_name || H.name] is there"
	crafts_prune()
	for (var/datum/craft/C in crafts)
		var/turf/O = (C.body && C.body.placed()) ? C.body.origin() : null
		if (O && distance_to(O) <= OCEAN_SITE_NEAR)
			return "the [C.name] lies there"
	for (var/turf/T in block(locate(B[1], B[2], z), locate(B[3], B[4], z)))
		for (var/obj/structure/bed/bunk in T)
			if (bunk.persistence_bed_owner_ckey)
				return "someone keeps a bunk there as home"
	return null

// The sea closes over it: what stood there is gone, and the water is open
// again. FALSE with nothing changed when it cannot be (lower_refusal()).
/datum/ocean_site/proc/lower()
	if (lower_refusal())
		return FALSE
	var/list/B = box()
	var/z = ocean_site_level()
	for (var/turf/T in block(locate(B[1], B[2], z), locate(B[3], B[4], z)))
		for (var/atom/movable/A in T)
			if (A.loc != T || isobserver(A) || istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))
				continue
			qdel(A)
		if (istype(T, /turf/floor/beach/water/ice) || istype(T, /turf/floor/beach/water/deep/saltwater/breakers))
			continue
		if (T.type != OCEAN_SITE_BASE)
			T.ChangeTurf(OCEAN_SITE_BASE)
		else
			// A plank that lay here kept the water out.
			var/turf/floor/beach/water/W = T
			W.water_level = initial(W.water_level)
			W.move_delay = initial(W.move_delay)
	log_game("Ocean site [id] ([kind]) went under at [x],[y].")
	return TRUE

// Everyone has gone: the site goes SEA_SITE_LINGER later unless somebody has
// come back by then.
/datum/ocean_site/proc/watch()
	if (linger_timer || lower_refusal())
		return FALSE
	linger_timer = addtimer(CALLBACK(src, PROC_REF(linger_done)), SEA_SITE_LINGER, TIMER_STOPPABLE)
	return TRUE

/datum/ocean_site/proc/linger_done()
	linger_timer = 0
	if (ocean_site_nearest(src) > OCEAN_SITE_FAR)
		lower()

/datum/ocean_site/proc/stop_watching()
	if (linger_timer)
		deltimer(linger_timer)
		linger_timer = 0

// ---------------------------------------------------------------- kinds

/datum/ocean_site/islet
	kind = "islet"
	name = "islet"
	half = 48

/datum/ocean_site/islet/build()
	sea_builder(/datum/chart_site/sea/island/ocean)

// The open sea's island, a little smaller: room for a ship to lie off it.
/datum/chart_site/sea/island/ocean
	name = "islet"
	radius_low = 10
	radius_high = 20

/datum/ocean_site/wreck
	kind = "wreck"
	name = "wreck"
	half = 10

/datum/ocean_site/wreck/build()
	sea_builder(/datum/chart_site/sea/wreck)

// Her planks lie on the water, so the water under her middle is still open:
// she is there when any of her planks or her salvage is.
/datum/ocean_site/wreck/raised()
	var/list/B = box()
	for (var/turf/T in block(locate(B[1], B[2], ocean_site_level()), locate(B[3], B[4], ocean_site_level())))
		if (locate(/obj/covers/repairedfloor/ship) in T)
			return TRUE
		for (var/obj/structure/closet/crate/C in T)
			if (C.salvage_of == id)
				return TRUE
	return FALSE

// Shallows over coral heads: the richest fishing at sea (fishing_grounds.dm
// counts shallow salt water as shelf), and rocks just awash.
/datum/ocean_site/reef
	kind = "reef"
	name = "reef"
	half = 16

/datum/ocean_site/reef/build()
	var/datum/sea_dice/dice = new(seed)
	var/z = ocean_site_level()
	var/list/blobs = list(list(0, 0, 4 + dice.cast(4)))
	for (var/i = 1, i <= 3 + dice.cast(4), i++)
		blobs += list(list(dice.cast(19) - 10, dice.cast(19) - 10, 2 + dice.cast(4)))
	for (var/dx = -half, dx <= half, dx++)
		for (var/dy = -half, dy <= half, dy++)
			if (!sea_in_blob(dx, dy, blobs))
				continue
			var/turf/T = locate(x + dx, y + dy, z)
			if (!T || T.type != OCEAN_SITE_BASE)
				continue
			T = T.ChangeTurf(/turf/floor/beach/water/shallowsaltwater) || T
			if (dice.chance(4))
				var/obj/structure/wild/rock/R = new(T)
				R.name = "coral head"
				R.desc = "A knob of coral just awash. Mind the hull."

// A rock standing out of the sea, with a name sailors steer by.
/datum/ocean_site/mark
	kind = "mark"
	name = "sea mark"
	half = 5

/datum/ocean_site/mark/build()
	var/datum/sea_dice/dice = new(seed)
	var/z = ocean_site_level()
	var/size = 1 + dice.cast(2)
	for (var/dx = -size - 1, dx <= size + 1, dx++)
		for (var/dy = -size - 1, dy <= size + 1, dy++)
			var/turf/T = locate(x + dx, y + dy, z)
			if (!T || T.type != OCEAN_SITE_BASE)
				continue
			if (max(abs(dx), abs(dy)) > size)
				T.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
			else
				T.ChangeTurf(/turf/floor/beach/sand)
	var/obj/structure/wild/rock/R = new(locate(x, y, z))
	R.name = name
	R.desc = "A tall rock out of the sea, known to sailors as [name]. They steer by it."

// ---------------------------------------------------------------- the list

/proc/ocean_site_level()
	return 1

// A whole number from a text, the same on every server.
/proc/ocean_site_seed(text)
	. = 7
	for (var/i = 1, i <= length(text), i++)
		. = (. * 31 + text2ascii(text, i)) % 65521

// TRUE when a site of half-side half may stand at x, y.
/proc/ocean_site_fits(x, y, half, list/placed)
	var/margin = half + OCEAN_SITE_EDGE
	if (x < margin || y < margin || x > world.maxx - margin || y > world.maxy - margin)
		return FALSE
	if (abs(x - round(world.maxx / 2)) < half + OCEAN_SITE_LANDING && abs(y - round(world.maxy / 2)) < half + OCEAN_SITE_LANDING)
		return FALSE
	for (var/datum/ocean_site/S in placed)
		if (abs(S.x - x) < S.half + half + 20 && abs(S.y - y) < S.half + half + 20)
			return FALSE
	// Never over pack ice or an island's breakers.
	var/list/boxes = world_insets[ocean_id()]
	if (islist(boxes))
		for (var/land in boxes)
			var/list/X = boxes[land]
			if (x + half >= X[1] - 20 && x - half <= X[3] + 20 && y + half >= X[2] - 20 && y - half <= X[4] + 20)
				return FALSE
	var/z = ocean_site_level()
	for (var/list/P in list(list(0, 0), list(-half, -half), list(half, -half), list(-half, half), list(half, half), list(0, -half), list(0, half), list(-half, 0), list(half, 0)))
		var/turf/T = locate(x + P[1], y + P[2], z)
		if (!T || istype(T, /turf/floor/beach/water/ice) || istype(T, /turf/floor/beach/water/deep/saltwater/breakers))
			return FALSE
	return TRUE

// The ocean's sites, rolled from its id: the same list on every start.
/proc/ocean_sites_roll()
	for (var/datum/ocean_site/S in ocean_sites.Copy())
		qdel(S)
	ocean_sites = list()
	var/ocean = ocean_id()
	if (!ocean)
		return ocean_sites
	var/datum/sea_dice/dice = new(ocean_site_seed(ocean))
	var/count = max(4, round(world.maxx * world.maxy / OCEAN_SITE_TILES))
	var/list/names = list("the Old Man", "Gull Rock", "the Sentinel", "Black Stack", "the Needle", "Seal Rock", "the Anvil", "Widow's Stack", "the Chimney", "Lone Tooth", "the Bishop", "Cormorant Rock")
	var/marks = 0
	for (var/n = 1, n <= count, n++)
		var/roll = dice.cast(100)
		var/path = roll <= 40 ? /datum/ocean_site/islet : roll <= 65 ? /datum/ocean_site/reef : roll <= 85 ? /datum/ocean_site/wreck : /datum/ocean_site/mark
		var/datum/ocean_site/S = new path
		S.id = "[ocean]-[n]"
		S.seed = ocean_site_seed(S.id)
		for (var/tries = 1, tries <= 40, tries++)
			var/x = dice.cast(world.maxx)
			var/y = dice.cast(world.maxy)
			if (ocean_site_fits(x, y, S.half, ocean_sites))
				S.x = x
				S.y = y
				break
		if (!S.x)
			qdel(S)
			continue
		if (S.kind == "mark")
			marks++
			S.name = names[((ocean_site_seed(ocean) + marks) % names.len) + 1]
		ocean_sites += S
	return ocean_sites

// How far the nearest ship or person is from a site's square.
/proc/ocean_site_nearest(datum/ocean_site/S)
	. = 1e9
	crafts_prune()
	for (var/datum/craft/C in crafts)
		if (C.body && C.body.placed())
			. = min(., S.distance_to(C.body.origin()))
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat != DEAD && H.client)
			. = min(., S.distance_to(get_turf(H)))

// Raises the sites someone is coming to, and lets the sea close over the
// ones everyone has left.
/proc/ocean_sites_tick()
	if (!ocean_world() || persistence_save_in_progress || !persistence_player_restore_ready)
		return
	for (var/datum/ocean_site/S in ocean_sites)
		var/near = ocean_site_nearest(S)
		if (near <= OCEAN_SITE_NEAR)
			S.stop_watching()
			S.raise()
		else if (near > OCEAN_SITE_FAR && S.raised())
			S.watch()

// Called at round start (the roundstart hook below).
/proc/ocean_sites_start()
	if (!ocean_world())
		return FALSE
	ocean_sites_roll()
	if (!ocean_sites_timer)
		ocean_sites_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(ocean_sites_tick)), OCEAN_SITE_SCAN, TIMER_LOOP | TIMER_STOPPABLE)
	return TRUE

/hook/roundstart/proc/ocean_sites_begin()
	ocean_sites_start()
	return TRUE

#undef OCEAN_SITE_SCAN
#undef OCEAN_SITE_NEAR
#undef OCEAN_SITE_FAR
#undef OCEAN_SITE_EDGE
#undef OCEAN_SITE_LANDING
#undef OCEAN_SITE_TILES
#undef OCEAN_SITE_BASE
