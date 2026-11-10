// Full-source probe: a free-moving human stands on the tile under its centre.
// Real humans and native pixel moves; headless authority is an explicit adapter.
/world
	hub = ""
	visibility = 0
	maxx = 16
	maxy = 16
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/centre_tile_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/centre_tile_probe/New()
	map = src

/turf/floor/plating/centre_tile_probe
	var/entered_count = 0

/turf/floor/plating/centre_tile_probe/Entered(atom/movable/M, atom/old)
	if (ishuman(M))
		entered_count++
	return ..()

/mob/living/human/centre_tile_probe/human_subtile_authority(client/owner)
	return TRUE

var/centre_tile_probe_checks = 0

// A shot that records the bodies it reaches. Stops on its first hit unless
// set to pass through.
/obj/item/projectile/bullet/centre_tile_probe
	var/list/hits = list()
	var/pass_bodies = FALSE

/obj/item/projectile/bullet/centre_tile_probe/attack_mob(mob/living/target_mob, distance, miss_modifier = 0)
	hits += target_mob
	return !pass_bodies

/obj/item/centre_tile_probe_rock
	var/list/hits = list()

/obj/item/centre_tile_probe_rock/throw_impact(atom/hit_atom, speed)
	if (isliving(hit_atom))
		hits += hit_atom

// Fire a probe shot from the shooter's body at an atom and fly it out.
/proc/centre_tile_probe_shoot(mob/living/human/shooter, atom/target, pass_bodies = FALSE)
	var/obj/item/projectile/bullet/centre_tile_probe/P = new(shooter.loc)
	P.firer = shooter
	P.starting = shooter.loc
	P.original = target
	P.def_zone = "chest"
	P.pass_bodies = pass_bodies
	var/list/hits = P.hits
	for (var/i in 1 to 24)
		if (QDELETED(P) || !P.loc)
			break
		P.process()
	return hits

/proc/centre_tile_probe_assert(ok, label)
	centre_tile_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/centre_tile_probe_actor(tx, ty)
	var/mob/living/human/centre_tile_probe/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.real_name = "Walker"
	H.name = H.real_name
	H.m_intent = "walk"
	H.set_human_subtile(TRUE)
	return H

/proc/centre_tile_probe_nudge(mob/living/human/H, direction)
	var/px = H.x * 32 + H.step_x
	var/py = H.y * 32 + H.step_y
	H.SelfMove(get_step(H, direction), direction, world.time + 1, FINE_STEP_NUDGE)
	var/dx = H.x * 32 + H.step_x - px
	var/dy = H.y * 32 + H.step_y - py
	return (direction & EAST ? 2 : direction & WEST ? -2 : 0) == dx && (direction & NORTH ? 2 : direction & SOUTH ? -2 : 0) == dy

// Walk 30px from an aligned start in one direction, 2px at a time, and check
// that the body is filed under the start tile until its centre crosses the
// tile edge (halfway) and under the next tile from then on.
/proc/centre_tile_probe_walk(tx, ty, direction, label)
	var/mob/living/human/centre_tile_probe/H = centre_tile_probe_actor(tx, ty)
	var/turf/start = H.loc
	var/turf/next = get_step(start, direction)
	for (var/moved = 2, moved <= 30, moved += 2)
		H.dir = direction
		centre_tile_probe_assert(centre_tile_probe_nudge(H, direction), "[label]_moves_2px_at_[moved]")
		// Exactly halfway, a body counts on the east or north tile of the two.
		var/turf/expected = ((direction & (EAST | NORTH)) ? moved >= 16 : moved > 16) ? next : start
		centre_tile_probe_assert(H.loc == expected && get_turf(H) == expected, "[label]_tile_at_[moved]px")
		centre_tile_probe_assert(H.step_x >= -16 && H.step_x < 16 && H.step_y >= -16 && H.step_y < 16, "[label]_offset_range_at_[moved]")
		// The body still overlaps both tiles natively.
		centre_tile_probe_assert(H.locs.len == 2 && (start in H.locs) && (next in H.locs), "[label]_covers_both_at_[moved]")
	// The last 2px lands squarely on the next tile.
	centre_tile_probe_assert(centre_tile_probe_nudge(H, direction) && H.loc == next && !H.step_x && !H.step_y && H.locs.len == 1, "[label]_lands_aligned")
	qdel(H)

/proc/centre_tile_probe_run()
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
	map = new /obj/map_metadata/centre_tile_probe
	centre_tile_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	// The tile switches at the halfway point in every direction. Before, east
	// and north kept the old tile for the full 32px; west and south switched
	// after 2px.
	centre_tile_probe_walk(4, 4, EAST, "east")
	centre_tile_probe_walk(10, 4, WEST, "west")
	centre_tile_probe_walk(4, 8, NORTH, "north")
	centre_tile_probe_walk(10, 12, SOUTH, "south")

	// Diagonals switch each axis at its own halfway point.
	var/mob/living/human/centre_tile_probe/D = centre_tile_probe_actor(6, 6)
	for (var/i in 1 to 8)
		centre_tile_probe_nudge(D, NORTHEAST)
	centre_tile_probe_assert(D.x == 7 && D.y == 7 && D.step_x == -16 && D.step_y == -16, "diagonal_switches_at_halfway")
	qdel(D)

	// Turf events still follow the body's overlap: the next tile is entered
	// at the first 2px, once, however the body is filed.
	var/mob/living/human/centre_tile_probe/E = centre_tile_probe_actor(3, 13)
	var/turf/floor/plating/centre_tile_probe/ahead = locate(4, 13, 1)
	ahead.entered_count = 0
	centre_tile_probe_nudge(E, EAST)
	centre_tile_probe_assert(ahead.entered_count == 1 && E.loc == locate(3, 13, 1), "next_tile_entered_on_first_overlap")
	for (var/i in 1 to 10)
		centre_tile_probe_nudge(E, EAST)
	centre_tile_probe_assert(ahead.entered_count == 1 && E.loc == ahead, "refiling_fires_no_extra_enter")

	// What you drop lands on the tile you are mostly standing on.
	var/obj/item/stack/rods/R = new(E)
	E.put_in_active_hand(R)
	E.drop_item()
	centre_tile_probe_assert(R.loc == ahead, "dropped_item_lands_on_centre_tile")

	// Walking back west from past halfway returns to the first tile at halfway.
	for (var/i in 1 to 4)
		centre_tile_probe_nudge(E, WEST)
	centre_tile_probe_assert(E.loc == locate(3, 13, 1) && E.step_x == 14, "reverse_switches_back_at_halfway")

	// Walls still stop the body at the same pixel: one tile from a wall.
	new /turf/wall(locate(14, 2, 1))
	var/mob/living/human/centre_tile_probe/W = centre_tile_probe_actor(12, 2)
	for (var/i in 1 to 24)
		centre_tile_probe_nudge(W, EAST)
	centre_tile_probe_assert(W.loc == locate(13, 2, 1) && !W.step_x && !W.step_y, "wall_stops_at_same_pixel")

	// A free held slide crosses tiles and stops squarely on release.
	var/mob/living/human/centre_tile_probe/S = centre_tile_probe_actor(2, 10)
	S.movement_eastwest = EAST
	S.SelfMove(get_step(S, EAST), EAST, world.time + 4, FINE_STEP_HELD)
	S.movement_eastwest = null
	centre_tile_probe_assert(S.x == 3 && S.y == 10 && !S.step_x && !S.step_y, "held_slide_reaches_next_tile")
	qdel(S)

	// Shots fly from the shooter's body and hit a body wherever it is drawn,
	// even one filed under the neighbouring row.
	var/mob/living/human/centre_tile_probe/gunner = centre_tile_probe_actor(2, 14)
	gunner.step_y = 10
	var/mob/living/human/centre_tile_probe/straddler = centre_tile_probe_actor(6, 15)
	straddler.step_y = -14
	var/list/hits = centre_tile_probe_shoot(gunner, locate(12, 14, 1))
	centre_tile_probe_assert(hits.len == 1 && hits[1] == straddler, "shot_hits_body_reaching_into_its_row")
	// The same body only 4px into the row is clear of the line.
	straddler.step_y = -4
	hits = centre_tile_probe_shoot(gunner, locate(12, 14, 1))
	centre_tile_probe_assert(!hits.len, "shot_misses_body_clear_of_line")
	// A body half across two tiles of the line is tried once, not per tile.
	var/mob/living/human/centre_tile_probe/between = centre_tile_probe_actor(9, 14)
	between.step_x = -16
	hits = centre_tile_probe_shoot(gunner, locate(12, 14, 1), TRUE)
	centre_tile_probe_assert(hits.len == 1 && hits[1] == between, "straddling_body_tried_once")
	qdel(between)
	// Aimed straight at a body between tiles, the shot reaches it.
	gunner.step_y = 0
	straddler.step_y = 12
	hits = centre_tile_probe_shoot(gunner, straddler)
	centre_tile_probe_assert(hits.len == 1 && hits[1] == straddler, "shot_reaches_aimed_straddler")
	// The shooter's own body never stops its shot, even half across a tile.
	gunner.step_x = 14
	straddler.step_y = 0
	hits = centre_tile_probe_shoot(gunner, straddler, TRUE)
	centre_tile_probe_assert(!(gunner in hits) && (straddler in hits), "own_shot_never_hits_shooter")
	qdel(gunner)
	qdel(straddler)

	// A thrown thing hits a body reaching a quarter tile into its path.
	var/mob/living/human/centre_tile_probe/pitcher = centre_tile_probe_actor(2, 10)
	var/mob/living/human/centre_tile_probe/catcher = centre_tile_probe_actor(6, 11)
	var/obj/item/centre_tile_probe_rock/rock = new(locate(6, 10, 1))
	rock.throwing = TRUE
	rock.thrower = pitcher
	catcher.step_y = -12
	rock.hit_check(1)
	centre_tile_probe_assert(rock.hits.len == 1 && rock.hits[1] == catcher, "throw_hits_body_reaching_into_path")
	rock.hits.Cut()
	catcher.step_y = -4
	rock.hit_check(1)
	centre_tile_probe_assert(!rock.hits.len, "throw_misses_body_at_path_edge")

/world/New()
	OpenPort("none")
	var/error = null
	try
		centre_tile_probe_run()
	catch (var/exception/probe_error)
		error = probe_error.name
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = centre_tile_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
