// Full-source probe: a tree blocks only around the trunk drawn at its pixel
// offset, never the whole tile, and the box stays inside the tree's own tile.
// Real humans and native pixel moves; headless authority is an explicit adapter.
/world
	hub = ""
	visibility = 0
	maxx = 16
	maxy = 16
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/tree_trunk_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/tree_trunk_probe/New()
	map = src

/turf/floor/plating/tree_trunk_probe

/mob/living/human/tree_trunk_probe/human_subtile_authority(client/owner)
	return TRUE

var/tree_trunk_probe_checks = 0

// A dense thing that moves a whole tile at a time, like an NPC or a pushed crate.
/obj/tree_trunk_probe_crate
	density = TRUE
	var/list/bumped = list()

/obj/tree_trunk_probe_crate/Bump(atom/A, yes)
	bumped += A
	return ..()

/mob/living/human/tree_trunk_probe/var/list/bumped = list()

/mob/living/human/tree_trunk_probe/Bump(atom/A, yes)
	bumped += A
	return ..()

/proc/tree_trunk_probe_assert(ok, label)
	tree_trunk_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/tree_trunk_probe_actor(tx, ty)
	var/mob/living/human/tree_trunk_probe/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.real_name = "Walker"
	H.name = H.real_name
	H.m_intent = "walk"
	H.set_human_subtile(TRUE)
	return H

// One 2px nudge; TRUE when the body moved the full 2px.
/proc/tree_trunk_probe_nudge(mob/living/human/H, direction)
	var/px = H.x * 32 + H.step_x
	var/py = H.y * 32 + H.step_y
	H.dir = direction
	H.SelfMove(get_step(H, direction), direction, world.time + 1, FINE_STEP_NUDGE)
	var/dx = H.x * 32 + H.step_x - px
	var/dy = H.y * 32 + H.step_y - py
	return (direction & EAST ? 2 : direction & WEST ? -2 : 0) == dx && (direction & NORTH ? 2 : direction & SOUTH ? -2 : 0) == dy

// Pixels walked in 2px nudges before the first blocked nudge, up to limit.
/proc/tree_trunk_probe_walk(mob/living/human/H, direction, limit)
	. = 0
	while (. < limit && tree_trunk_probe_nudge(H, direction))
		. += 2

/proc/tree_trunk_probe_tree(tx, ty, type, px, py)
	var/obj/structure/wild/T = new type(locate(tx, ty, 1))
	T.pixel_x = px
	T.pixel_y = py
	T.fit_trunk_bounds()
	return T

/proc/tree_trunk_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/tree_trunk_probe
	tree_trunk_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	// Random offsets keep every trunk inside its tile, 8..24px across.
	for (var/i in 1 to 40)
		for (var/type in list(/obj/structure/wild/tree, /obj/structure/wild/tree/live_tree, /obj/structure/wild/tree/live_tree/pine, /obj/structure/wild/tree/dead_tree, /obj/structure/wild/jungle))
			var/obj/structure/wild/R = new type(locate(14, 14, 1))
			var/centre = R.pixel_x + R.trunk_center_x
			tree_trunk_probe_assert(centre >= 8 && centre <= 24, "random_trunk_inside_tile_[type]")
			tree_trunk_probe_assert(R.bound_width == R.trunk_width && R.bound_height == R.trunk_height && R.bound_x >= 0 && R.bound_x + R.bound_width <= 32 && R.bound_y >= 0 && R.bound_y + R.bound_height <= 32, "random_box_inside_tile_[type]")
			tree_trunk_probe_assert(R.locs.len == 1 && R.loc == locate(14, 14, 1), "random_tree_keeps_its_tile_[type]")
			qdel(R)

	// Trunk drawn on the west side of its tile: x 1..15, y 2..14.
	var/obj/structure/wild/tree/live_tree/T = tree_trunk_probe_tree(8, 8, /obj/structure/wild/tree/live_tree, -24, 0)
	tree_trunk_probe_assert(T.bound_x == 1 && T.bound_y == 2 && T.bound_width == 14 && T.bound_height == 12, "west_trunk_box")
	tree_trunk_probe_assert(T.locs.len == 1 && T.loc == locate(8, 8, 1) && T.density && T.opacity, "tree_stays_on_its_tile")

	// From the east tile, a body walks about half a tile into the tree's tile
	// before it meets the trunk. Before, the whole tile blocked at once.
	var/mob/living/human/tree_trunk_probe/H = tree_trunk_probe_actor(9, 8)
	tree_trunk_probe_assert(tree_trunk_probe_walk(H, WEST, 32) == 16, "west_walk_stops_at_trunk")
	// The last nudge closes the final pixel: the body's west edge meets the trunk.
	tree_trunk_probe_assert(H.x * 32 + H.step_x == 8 * 32 + 15 && H.loc == T.loc && H.step_y == 0, "body_beside_trunk")
	// Beside the trunk it walks north and south straight through the tree's tile.
	tree_trunk_probe_assert(tree_trunk_probe_walk(H, NORTH, 32) == 32, "north_past_trunk")
	tree_trunk_probe_assert(tree_trunk_probe_walk(H, SOUTH, 64) == 64, "south_past_trunk")
	qdel(H)

	// Walking north straight at the trunk, a body stops at the trunk's base,
	// not at the tile edge.
	var/mob/living/human/tree_trunk_probe/N = tree_trunk_probe_actor(8, 7)
	tree_trunk_probe_assert(tree_trunk_probe_walk(N, NORTH, 32) == 2, "north_stops_at_trunk_base")
	// Meeting the trunk still bumps the tree (bump chopping uses this).
	tree_trunk_probe_assert(T in N.bumped, "trunk_bumps_tree")
	qdel(N)
	// Walking south onto the trunk from above, the canopy does not block: the
	// body stops on top of the trunk, 18px into the tree's tile.
	var/mob/living/human/tree_trunk_probe/S = tree_trunk_probe_actor(8, 9)
	tree_trunk_probe_assert(tree_trunk_probe_walk(S, SOUTH, 32) == 18, "south_stops_at_trunk_top")
	qdel(S)

	// Whole-tile movers (NPCs, pushed crates) still cannot step onto the tree's tile.
	var/obj/structure/wild/tree/live_tree/C = tree_trunk_probe_tree(8, 12, /obj/structure/wild/tree/live_tree, -16, 8)
	var/obj/tree_trunk_probe_crate/crate = new(locate(9, 12, 1))
	tree_trunk_probe_assert(!step(crate, WEST) && crate.loc == locate(9, 12, 1) && !crate.step_x && !crate.step_y && (C in crate.bumped), "tile_mover_blocked_by_tree")
	// A tile mover beside the trunk's tile row passes as before.
	tree_trunk_probe_assert(step(crate, SOUTH) && crate.loc == locate(9, 11, 1) && !crate.step_x && !crate.step_y, "tile_mover_free_elsewhere")
	qdel(crate)
	qdel(C)

	// Offsets beyond the usual range clamp the box inside the tile.
	var/obj/structure/wild/tree/live_tree/E = tree_trunk_probe_tree(4, 4, /obj/structure/wild/tree/live_tree, 20, 40)
	tree_trunk_probe_assert(E.bound_x == 18 && E.bound_y == 20 && E.locs.len == 1 && E.loc == locate(4, 4, 1), "clamped_box_inside_tile")
	qdel(E)

	// A loaded tree refits to the offset the save restored.
	T.pixel_x = -8
	T.pixel_y = 10
	T.after_load()
	tree_trunk_probe_assert(T.bound_x == 17 && T.bound_y == 12, "after_load_refits")

	// Anything that is not a tree keeps whole-tile collision.
	var/obj/structure/wild/palm/P = new(locate(12, 12, 1))
	tree_trunk_probe_assert(!P.fit_trunk_bounds() && P.bound_x == 0 && P.bound_y == 0 && P.bound_width == 32 && P.bound_height == 32, "palm_whole_tile")

/world/New()
	OpenPort("none")
	var/error = null
	try
		tree_trunk_probe_run()
	catch (var/exception/probe_error)
		error = probe_error.name
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = tree_trunk_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
