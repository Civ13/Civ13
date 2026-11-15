// ============================================================
// Sites of the open sea (docs/craft-core.md): islands and wrecks
// ------------------------------------------------------------
// A site is a place on the open sea chart (open_sea_chart.dm) that is built in
// a sea cell (open_sea.dm) when a ship reaches it and taken away again
// SEA_SITE_LINGER after the last ship and the last person have left. A site
// keeps its seed, so the same island rises in the same shape each time,
// with its trees and rocks grown back. A mooring post makes a harbour of a
// site: up to SEA_KEPT_CAP sites with one stay for good.
//
// Building is plain DM over the cell's water, so it needs no map files and
// the same code raises a home island on a map that has none drawn in.
// ============================================================

var/global/list/open_sea_sites = list()   // every /datum/chart_site/sea of this world

// A small repeatable dice: the same seed rolls the same island.
/datum/sea_dice
	var/s = 1

/datum/sea_dice/New(seed)
	..()
	s = (round(abs(seed)) % 65536) + 1

// A whole number from 1 to n.
/datum/sea_dice/proc/cast(n)
	s = (s * 75 + 74) % 65537
	return (s % max(1, n)) + 1

// TRUE that many times in a hundred.
/datum/sea_dice/proc/chance(percent)
	return cast(1000) <= percent * 10

/proc/open_sea_site(id)
	for (var/datum/chart_site/sea/S in open_sea_sites)
		if (S.id == id)
			return S
	return null

// The loaded site lying in cell n, or null.
/proc/open_sea_site_in(n)
	for (var/datum/chart_site/sea/S in open_sea_sites)
		if (S.loaded && S.cell == n)
			return S
	return null

/datum/chart_site/sea
	var/id = ""
	var/kind = "site"
	var/seed = 1
	var/cell = 0                  // The sea cell it is loaded in, or 0.
	var/charted = 0               // 1 once a survey put it on every ship's chart.
	var/tmp/linger_timer = 0

/datum/chart_site/sea/New()
	..()
	open_sea_sites += src

/datum/chart_site/sea/Destroy()
	open_sea_sites -= src
	if (linger_timer)
		deltimer(linger_timer)
		linger_timer = 0
	return ..()

// Builds the site in the water of a cell: list(x1, y1, x2, y2).
/datum/chart_site/sea/proc/build(list/box)
	return

// Loads the site into a free cell. Returns null when it is there, else why
// it is not.
/datum/chart_site/sea/proc/load()
	if (loaded)
		return null
	var/datum/plane_pool/sea/pool = sea_pool()
	if (!pool)
		return "this is not the open sea"
	var/owner = "site:[id]"
	var/refusal = pool.claim_refusal(owner)
	if (refusal)
		return refusal
	var/n = pool.claim(owner)
	if (!n)
		return "every stretch of water is taken"
	cell = n
	loaded = TRUE
	build(sea_cell_box(n))
	return null

// A mooring post in her waters makes a harbour of a site.
/datum/chart_site/sea/proc/has_harbour()
	if (!loaded)
		return FALSE
	for (var/obj/structure/berth/quay/Q in sea_harbours)
		if (Q.takes_ships && sea_cell_of(get_turf(Q)) == cell)
			return TRUE
	return FALSE

// TRUE while a harbour holds the site loaded. Only the first SEA_KEPT_CAP
// harbour sites are held, in the order of open_sea_sites.
/datum/chart_site/sea/proc/held()
	if (!has_harbour())
		return FALSE
	var/before = 0
	for (var/datum/chart_site/sea/S in open_sea_sites)
		if (S == src)
			break
		if (S.has_harbour())
			before++
	return before < SEA_KEPT_CAP

/datum/chart_site/sea/can_unload()
	if (!loaded || kept || held())
		return FALSE
	var/datum/plane_pool/sea/pool = sea_pool()
	return pool && !pool.clear_refusal(cell)

// Takes the site away: the sea closes over its cell. FALSE when it cannot be.
/datum/chart_site/sea/proc/unload()
	if (!can_unload())
		return FALSE
	var/datum/plane_pool/sea/pool = sea_pool()
	if (!pool.clear(cell))
		return FALSE
	cell = 0
	loaded = FALSE
	return TRUE

// Someone has left: when nobody is here any more, the site goes
// SEA_SITE_LINGER later unless somebody has come back by then.
/datum/chart_site/sea/proc/watch()
	if (!loaded || linger_timer || !can_unload())
		return FALSE
	linger_timer = addtimer(CALLBACK(src, PROC_REF(linger_done)), SEA_SITE_LINGER, TIMER_STOPPABLE)
	return TRUE

/datum/chart_site/sea/proc/linger_done()
	linger_timer = 0
	return unload()

// The site as plain values for the registry, and back.
/datum/chart_site/sea/proc/site_state()
	return list("type" = "[type]", "id" = id, "name" = name, "x" = x, "y" = y, "seed" = seed, "cell" = loaded ? cell : 0, "charted" = charted ? 1 : 0)

/proc/open_sea_site_restore(list/state)
	if (!islist(state))
		return null
	var/path = text2path("[state["type"]]")
	if (!ispath(path, /datum/chart_site/sea))
		return null
	var/datum/chart_site/sea/S = new path
	S.id = "[state["id"]]"
	S.name = "[state["name"]]"
	S.x = isnum(state["x"]) ? state["x"] : 1
	S.y = isnum(state["y"]) ? state["y"] : 1
	S.seed = isnum(state["seed"]) ? state["seed"] : 1
	S.charted = state["charted"] ? 1 : 0
	var/n = state["cell"]
	if (isnum(n) && n >= 1 && n <= sea_cell_count() && !sea_cell_is_home(n))
		S.cell = n
		S.loaded = TRUE
	return S

// ---------------------------------------------------------------- islands

/datum/chart_site/sea/island
	name = "island"
	kind = "island"
	// The half-widths an island is rolled between, in tiles.
	var/radius_low = 12
	var/radius_high = 22

// TRUE when a spot lies in one of the round patches: each list(dx, dy, radius).
/proc/sea_in_blob(dx, dy, list/blobs)
	for (var/list/B in blobs)
		if ((dx - B[1]) * (dx - B[1]) + (dy - B[2]) * (dy - B[2]) <= B[3] * B[3])
			return TRUE
	return FALSE

// TRUE when this spot of the island must stay clear of trees and rocks.
/datum/chart_site/sea/island/proc/keep_clear(dx, dy)
	return FALSE

/datum/chart_site/sea/island/build(list/box)
	var/datum/sea_dice/dice = new(seed)
	var/z = open_sea_level()
	var/cx = round((box[1] + box[3]) / 2)
	var/cy = round((box[2] + box[4]) / 2)
	// Never so wide that a ship cannot lie off it inside the cell.
	var/room = round(min(box[3] - box[1], box[4] - box[2]) / 2) - 14
	var/rx = min(room, radius_low + dice.cast(radius_high - radius_low + 1) - 1)
	var/ry = min(room, radius_low + dice.cast(radius_high - radius_low + 1) - 1)
	var/p1 = dice.cast(360)
	var/p2 = dice.cast(360)
	var/p3 = dice.cast(360)
	// Fresh ponds off the middle, and on a wide island outcrops of rock to
	// mine: each list(dx, dy, radius). A small island has one pond.
	var/list/ponds = list()
	var/list/outcrops = list()
	var/wide = min(rx, ry)
	for (var/i = 1, i <= 1 + round(rx * ry / 1200), i++)
		var/pond_x = dice.cast(7) - 4
		var/pond_y = dice.cast(7) - 4
		var/pond_r = 1 + dice.cast(2)
		if (i > 1)
			pond_x = dice.cast(wide) - round(wide / 2)
			pond_y = dice.cast(wide) - round(wide / 2)
			pond_r = 1 + dice.cast(2 + round(wide / 25))
		if (abs(pond_x) < 3 + pond_r && abs(pond_y) < 3 + pond_r)
			pond_x += 5 + pond_r
		ponds += list(list(pond_x, pond_y, pond_r))
	for (var/i = 1, i <= round(rx * ry / 2500), i++)
		var/rock_x = dice.cast(wide) - round(wide / 2)
		var/rock_y = dice.cast(wide) - round(wide / 2)
		if (abs(rock_x) < 12 && abs(rock_y) < 12)
			rock_x += 20
		outcrops += list(list(rock_x, rock_y, 3 + dice.cast(4)))
	// The shore wanders out to about 1.6 times the half-width at its capes.
	var/reach = round(max(rx, ry) * 1.65) + 2
	var/list/grass = list()
	var/list/sand = list()
	for (var/x = max(box[1], cx - reach), x <= min(box[3], cx + reach), x++)
		for (var/y = max(box[2], cy - reach), y <= min(box[4], cy + reach), y++)
			var/dx = x - cx
			var/dy = y - cy
			var/angle = arctan(dx, dy)
			var/shape = 1 + 0.16 * sin(3 * angle + p1) + 0.1 * sin(5 * angle + p2) + 0.06 * sin(9 * angle + p3)
			var/d = sqrt((dx / rx) * (dx / rx) + (dy / ry) * (dy / ry)) / shape
			var/turf/T = locate(x, y, z)
			if (!T || d > 1.22)
				continue
			if (d > 1)
				T.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
			else if (d < 0.6 && sea_in_blob(dx, dy, ponds))
				T.ChangeTurf(/turf/floor/beach/water)
			else if (d < 0.7 && sea_in_blob(dx, dy, outcrops))
				T.ChangeTurf(/turf/floor/dirt/underground)
			else if (d > 0.8)
				sand += T.ChangeTurf(/turf/floor/beach/sand) || T
			else
				grass += T.ChangeTurf(/turf/floor/grass) || T
	for (var/turf/T in grass)
		if (keep_clear(T.x - cx, T.y - cy))
			continue
		if (dice.chance(9))
			new /obj/structure/wild/tree/live_tree(T)
		else if (dice.chance(2))
			new /obj/structure/wild/rock(T)
		else if (dice.chance(2))
			new /obj/structure/wild/berrybush/tinto(T)
		else if (dice.chance(4))
			new /obj/structure/wild/tallgrass(T)
	for (var/turf/T in sand)
		if (keep_clear(T.x - cx, T.y - cy))
			continue
		if (dice.chance(4))
			new /obj/structure/wild/palm(T)
		else if (dice.chance(1))
			new /obj/structure/wild/rock(T)
	// Game: a flock on any island with room, and one more for every wide
	// stretch of grass after that.
	if (grass.len >= 200)
		for (var/i = 1, i <= 1 + round(grass.len / 5000), i++)
			var/turf/den = grass[dice.cast(grass.len)]
			if (!keep_clear(den.x - cx, den.y - cy))
				new /obj/effect/spawner/mobspawner/turkeys(den)
	return grass.len + sand.len

// The island of the home waters, clear where arrivals land. The region map
// (tools/open_sea/make_map.py) has its own, far wider, drawn into it; this
// one is raised only on a map whose home waters are empty, such as a fixture.
/datum/chart_site/sea/island/home
	name = "home island"
	radius_low = 24
	radius_high = 28

/datum/chart_site/sea/island/home/keep_clear(dx, dy)
	return abs(dx) <= 3 && abs(dy) <= 3

// ---------------------------------------------------------------- wrecks

// A ship that did not make it: broken planks adrift, with what was in her
// hold. Her floors are ordinary floors over water, so a crew that brings a
// tiller can patch her and sail her home.
/datum/chart_site/sea/wreck
	name = "wreck"
	kind = "wreck"

/datum/chart_site/sea/wreck/build(list/box)
	var/datum/sea_dice/dice = new(seed)
	var/z = open_sea_level()
	var/cx = round((box[1] + box[3]) / 2)
	var/cy = round((box[2] + box[4]) / 2)
	var/half_long = 3 + dice.cast(3)
	var/half_wide = dice.cast(2)
	var/list/deck = list()
	for (var/dx = -half_long, dx <= half_long, dx++)
		for (var/dy = -half_wide, dy <= half_wide, dy++)
			// Pointed at both ends, and holed.
			if (abs(dx) == half_long && abs(dy) == half_wide && half_wide > 0)
				continue
			if (dice.chance(18))
				continue
			var/turf/T = locate(cx + dx, cy + dy, z)
			if (!istype(T, /turf/floor/beach/water))
				continue
			var/obj/covers/repairedfloor/ship/plank = new(T)
			plank.updateturf()
			deck += T
	if (!deck.len)
		return 0
	var/list/hold = list(/obj/item/stack/material/wood = 20, /obj/item/stack/material/rope = 6, /obj/item/stack/material/cloth = 8, /obj/item/stack/material/iron = 6)
	var/crates = 1 + dice.cast(3)
	for (var/i = 1, i <= crates, i++)
		var/turf/T = deck[dice.cast(deck.len)]
		if (locate(/obj/structure/closet/crate) in T)
			continue
		var/obj/structure/closet/crate/C = new(T)
		C.salvage_of = id
		for (var/n = 1, n <= 2, n++)
			var/path = hold[dice.cast(hold.len)]
			var/obj/item/stack/S = new path(C)
			S.amount = max(1, round(hold[path] * (dice.cast(100) + 50) / 100))
	return deck.len
