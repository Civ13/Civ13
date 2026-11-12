// ============================================================
// The open sea (docs/craft-core.md): an ocean world of sea cells
// ------------------------------------------------------------
// An open-sea region (shard kind OCEANIC, maps/sea/open_sea.dmm) is one wide
// level of deep salt water cut into square cells by tide races nothing can
// cross. One cell is the home waters, with the island new arrivals land on.
// The others are a pool (craft/plane_pool.dm): a ship making passage on the
// open sea chart lies alone in one, and an island or a wreck she reaches is
// built in another when she arrives and taken away again some time after the
// last ship and the last person have left it.
//
// Nothing grows the world and no level is added: a cell is a square of the
// one sea level, so saving, digging, weather and lighting are those of any
// surface map. A free cell is simply one with no loaded site, no ship and
// nobody in it, so no ownership has to survive a restart except which site
// lies in which cell (the registry).
// ============================================================

var/global/sea_cell_pitch = SEA_CELL_PITCH
var/global/sea_cell_margin = SEA_CELL_MARGIN

// TRUE on an open-sea world (the map, not the shard kind, so fixtures work).
/proc/open_sea_world()
	return istype(map, /obj/map_metadata/nomads/open_sea)

// The level the sea is on.
/proc/open_sea_level()
	return 2

/obj/map_metadata/nomads/open_sea
	title = "The Open Sea"
	description = "Blue water in every direction. Crews build their ships in the home waters and make passage by the chart to islands and wrecks beyond the horizon."
	battle_name = "open sea"
	mission_start_message = "<big>Blue water in every direction. Build a ship in the home waters, then make passage by the chart to the islands and wrecks beyond the horizon.</big>"

/obj/map_metadata/nomads/open_sea/New()
	..()
	spawn (50)
		open_sea_prepare()

// ---------------------------------------------------------------- tide race

// The water between cells. Nothing swims, sails, drifts or is built across.
/turf/floor/beach/water/deep/saltwater/tide_race
	name = "tide race"
	desc = "Broken white water where the currents meet. Nothing gets across; a ship makes passage by the chart."
	density = TRUE

/turf/floor/beach/water/deep/saltwater/tide_race/CanPass(atom/movable/mover)
	return istype(mover, /obj/effect/effect/smoke) || istype(mover, /obj/item/projectile)

/turf/floor/beach/water/deep/saltwater/tide_race/attackby(obj/item/C as obj, mob/user as mob)
	to_chat(user, SPAN_WARNING("The tide race would tear it away."))

/turf/floor/beach/water/deep/saltwater/tide_race/cast_ocean_line(obj/item/weapon/fishing/F, mob/user)
	to_chat(user, SPAN_WARNING("No line holds in the tide race."))

// ---------------------------------------------------------------- cells

/proc/sea_cells_across()
	return round(world.maxx / sea_cell_pitch)

/proc/sea_cell_count()
	return sea_cells_across() * round(world.maxy / sea_cell_pitch)

// The whole square of cell n, tide race and all: list(x1, y1, x2, y2).
/proc/sea_cell_outer(n)
	if (!isnum(n) || n < 1 || n > sea_cell_count())
		return null
	var/column = (n - 1) % sea_cells_across()
	var/row = round((n - 1) / sea_cells_across())
	return list(column * sea_cell_pitch + 1, row * sea_cell_pitch + 1, (column + 1) * sea_cell_pitch, (row + 1) * sea_cell_pitch)

// The water of cell n inside its tide race: list(x1, y1, x2, y2).
/proc/sea_cell_box(n)
	var/list/B = sea_cell_outer(n)
	if (!B)
		return null
	return list(B[1] + sea_cell_margin, B[2] + sea_cell_margin, B[3] - sea_cell_margin, B[4] - sea_cell_margin)

// The cell a tile lies in, on the sea level or under it, or 0.
/proc/sea_cell_of(turf/T)
	if (!T || T.z > open_sea_level())
		return 0
	var/column = round((T.x - 1) / sea_cell_pitch)
	var/row = round((T.y - 1) / sea_cell_pitch)
	if (column >= sea_cells_across() || row >= round(world.maxy / sea_cell_pitch))
		return 0
	return row * sea_cells_across() + column + 1

/proc/sea_cell_centre(n)
	var/list/B = sea_cell_outer(n)
	return B ? locate(round((B[1] + B[3]) / 2), round((B[2] + B[4]) / 2), open_sea_level()) : null

// The cell of the home waters: the middle of the grid.
/proc/sea_home_cell()
	var/across = sea_cells_across()
	var/down = round(world.maxy / sea_cell_pitch)
	return round(down / 2) * across + round(across / 2) + 1

// TRUE when the tile is part of a tide race (or off the grid).
/proc/sea_tide_race_at(x, y)
	var/px = (x - 1) % sea_cell_pitch
	var/py = (y - 1) % sea_cell_pitch
	if (x > sea_cells_across() * sea_cell_pitch || y > round(world.maxy / sea_cell_pitch) * sea_cell_pitch)
		return TRUE
	return px < sea_cell_margin || py < sea_cell_margin || px >= sea_cell_pitch - sea_cell_margin || py >= sea_cell_pitch - sea_cell_margin

// Lays the tide races of the sea level. The compiled map already has them;
// this is for a map that does not and for fixtures. Returns the tiles changed.
/proc/open_sea_lay_races()
	. = 0
	var/z = open_sea_level()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			if (!sea_tide_race_at(x, y))
				continue
			var/turf/T = locate(x, y, z)
			if (T && !istype(T, /turf/floor/beach/water/deep/saltwater/tide_race))
				T.ChangeTurf(/turf/floor/beach/water/deep/saltwater/tide_race)
				.++

// TRUE when a trail to other lands can leave from this tile: dry ground of
// the home island, at the shore (persistence/region_trails.dm).
/proc/open_sea_landing_at(turf/T)
	if (!T || T.z != open_sea_level() || sea_cell_of(T) != sea_home_cell() || istype(T, /turf/floor/beach/water))
		return FALSE
	for (var/turf/floor/beach/water/W in range(OPEN_SEA_LANDING_TILES, T))
		if (!istype(W, /turf/floor/beach/water/deep/saltwater/tide_race) && W.salty)
			return TRUE
	return FALSE

// Every craft with a body in cell n.
/proc/sea_crafts_in(n)
	. = list()
	crafts_prune()
	for (var/datum/craft/C in crafts)
		var/turf/O = (C.body && C.body.placed()) ? C.body.origin() : null
		if (O && sea_cell_of(O) == n)
			. += C

// The first living or logged-in character in cell n, on the sea or under it.
/proc/sea_person_in(n)
	for (var/mob/living/human/H in human_mob_list)
		if ((H.stat != DEAD || H.client) && sea_cell_of(get_turf(H)) == n)
			return H
	return null

// ---------------------------------------------------------------- registry

var/global/obj/structure/sea_registry/sea_registry = null

// One per open-sea world, in the corner of the sea level. It saves the open
// sea as one text (open_sea_chart.dm writes and reads it).
/obj/structure/sea_registry
	name = "sea registry"
	invisibility = 101
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/state = ""
	var/pool_paused = 0

/obj/structure/sea_registry/New()
	..()
	sea_registry = src

/obj/structure/sea_registry/Destroy()
	if (sea_registry == src)
		sea_registry = null
	return ..()

/obj/structure/sea_registry/ex_act(severity)
	return

/proc/sea_get_registry()
	if (!open_sea_world())
		return null
	if (!sea_registry || QDELETED(sea_registry))
		var/turf/T = locate(1, 1, open_sea_level())
		if (!T)
			return null
		sea_registry = locate(/obj/structure/sea_registry) in T
		if (!sea_registry)
			sea_registry = new /obj/structure/sea_registry(T)
	return sea_registry

// ---------------------------------------------------------------- pool

// The pool of an open-sea world. Its "planes" are cell numbers.
/datum/plane_pool/sea
	name = "sea cell pool"
	site_cap = SEA_SITE_CAP

/datum/plane_pool/sea/all_planes()
	. = list()
	var/home = sea_home_cell()
	for (var/n = 1, n <= sea_cell_count(), n++)
		if (n != home)
			. += n

// Who holds cell n: "site:<id>" for a loaded site, "ship" or "people" for a
// cell something lies in, or null.
/datum/plane_pool/sea/owner_of(n)
	var/datum/chart_site/sea/S = open_sea_site_in(n)
	if (S)
		return "site:[S.id]"
	if (length(sea_crafts_in(n)))
		return "ship"
	if (sea_person_in(n))
		return "people"
	return null

/datum/plane_pool/sea/free_planes()
	. = list()
	for (var/n in all_planes())
		if (!owner_of(n))
			. += n

/datum/plane_pool/sea/planes_of(owner)
	. = list()
	for (var/n in all_planes())
		if (owner_of(n) == owner)
			. += n

/datum/plane_pool/sea/quota(owner)
	return (istext(owner) && findtext(owner, "site:") == 1) ? 1 : 0

/datum/plane_pool/sea/is_paused()
	var/obj/structure/sea_registry/R = sea_get_registry()
	return R ? (R.pool_paused ? TRUE : FALSE) : paused

/datum/plane_pool/sea/set_paused(state)
	var/obj/structure/sea_registry/R = sea_get_registry()
	if (R)
		R.pool_paused = state ? 1 : 0
	paused = state ? TRUE : FALSE

/datum/plane_pool/sea/claim_refusal(owner)
	. = ..()
	if (. == "every encounter plane is in use")
		return "too many islands and wrecks are raised already"
	if (. == "every plane is taken")
		return "every stretch of water is taken"

// A free cell for owner, or 0. Whoever asked puts something in it at once: a
// site records itself (open_sea_sites.dm), a ship is moved in.
/datum/plane_pool/sea/claim(owner)
	if (claim_refusal(owner))
		return 0
	var/list/free = free_planes()
	return free.len ? free[1] : 0

/datum/plane_pool/sea/release(n, clear = FALSE)
	if (clear && !src.clear(n))
		return FALSE
	return TRUE

/datum/plane_pool/sea/base_turf(n)
	return /turf/floor/beach/water/deep/saltwater

/datum/plane_pool/sea/clear_refusal(n)
	if (!(n in all_planes()))
		return "that is not one of this pool's cells"
	var/mob/living/human/H = sea_person_in(n)
	if (H)
		return "[H.real_name || H.name] is there"
	var/list/ships = sea_crafts_in(n)
	if (ships.len)
		var/datum/craft/C = ships[1]
		return "the [C.name] lies there"
	var/list/B = sea_cell_box(n)
	for (var/z = 1, z <= open_sea_level(), z++)
		for (var/turf/T in block(locate(B[1], B[2], z), locate(B[3], B[4], z)))
			for (var/obj/structure/bed/bunk in T)
				if (bunk.persistence_bed_owner_ckey)
					return "someone keeps a bunk there as home"
	return null

// Empties cell n: the sea closes over it and the rock under it is whole
// again. FALSE with nothing changed when it cannot be (clear_refusal()).
/datum/plane_pool/sea/clear(n)
	if (clear_refusal(n))
		return FALSE
	var/list/B = sea_cell_box(n)
	var/sea = open_sea_level()
	for (var/z = 1, z <= sea, z++)
		var/base = (z == sea) ? base_turf(n) : /turf/floor/dirt/underground
		for (var/turf/T in block(locate(B[1], B[2], z), locate(B[3], B[4], z)))
			for (var/atom/movable/A in T)
				if (A.loc != T || isobserver(A) || istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))
					continue
				qdel(A)
			if (T.type != base)
				T.ChangeTurf(base)
			else if (z == sea)
				// A plank that stood here kept the water out.
				var/turf/floor/beach/water/W = T
				W.water_level = initial(W.water_level)
				W.move_delay = initial(W.move_delay)
	return TRUE

var/global/datum/plane_pool/sea/sea_pool_made = null

// The pool of this open-sea world, or null off one.
/proc/sea_pool()
	if (!open_sea_world())
		return null
	if (!sea_pool_made)
		sea_pool_made = new /datum/plane_pool/sea
	return sea_pool_made

// Called once the map is up: lays the tide races a map lacks and builds the
// home island the first time (while the middle of the home waters is still
// open sea).
/proc/open_sea_prepare()
	if (!open_sea_world())
		return FALSE
	sea_get_registry()
	if (!istype(locate(1, 1, open_sea_level()), /turf/floor/beach/water/deep/saltwater/tide_race))
		open_sea_lay_races()
	var/turf/middle = sea_cell_centre(sea_home_cell())
	if (istype(middle, /turf/floor/beach/water/deep))
		var/datum/chart_site/sea/island/home/H = new
		H.seed = 1
		H.build(sea_cell_box(sea_home_cell()))
		qdel(H)
	sea_office_place()
	return TRUE
