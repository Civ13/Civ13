// Native probe: on a ground level with an open-air level above, a body on an
// upper floor climbs down over open air, a wooden ladder stands between the
// levels, and stairs under open air lead up and back down.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 2
	fps = 20
	turf = /turf/floor/grass
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/edge_climbing_native/New()
	map = src

/mob/living/human/edge_climbing_native/human_subtile_authority(client/owner)
	return TRUE

/obj/structure/edge_probe_block
	density = TRUE

var/list/edge_probe_log = list()

/proc/edge_probe_human(turf/T)
	var/mob/living/human/edge_climbing_native/H = new(T)
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.set_human_subtile(TRUE)
	return H

/proc/edge_probe_run()
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
	map = new /obj/map_metadata/edge_climbing_native
	for (var/tx in 1 to 12)
		for (var/ty in 1 to 12)
			new /turf/sky/building(locate(tx, ty, 2))
	var/list/why = list()
	edge_probe_check(multiz_level_below(2) == 1 && multiz_level_above(1) == 2, "levels_linked")

	// An upper floor of two tiles at (5,5) and (5,6) with open air around.
	new /obj/covers/wood(locate(5, 5, 2))
	new /obj/covers/wood(locate(5, 6, 2))
	var/mob/living/human/H = edge_probe_human(locate(5, 5, 2))
	edge_probe_check(edge_descent_destination(H, EAST) == locate(6, 5, 1), "climbs_down_east")
	edge_probe_check(edge_descent_destination(H, WEST) == locate(4, 5, 1), "climbs_down_west")
	edge_probe_check(!edge_descent_destination(H, NORTH, why) && findtext(why[1], "no open edge"), "floor_is_not_an_edge")
	new /obj/structure/edge_probe_block(locate(5, 4, 1))
	edge_probe_check(!edge_descent_destination(H, SOUTH, why) && findtext(why[1], "not clear"), "blocked_ground_reason")
	new /turf/sky/building(locate(4, 5, 1))
	edge_probe_check(!edge_descent_destination(H, WEST, why) && findtext(why[1], "more than one storey"), "long_drop_reason")
	new /turf/floor/grass(locate(4, 5, 1))
	edge_probe_check(!edge_descent_destination(H, NORTHEAST, why) && findtext(why[1], "Face straight"), "diagonal_reason")
	edge_probe_check(EAST in edge_descent_directions(NORTH), "climb_down_tries_every_side")
	H.r_hand = new /obj/item/stack/rods(H)
	H.l_hand = new /obj/item/stack/rods(H)
	edge_probe_check(!edge_descent_destination(H, EAST, why) && findtext(why[1], "free hand"), "no_free_hand_reason")
	qdel(H.r_hand)
	H.r_hand = null
	edge_probe_check(edge_descent_destination(H, EAST), "one_free_hand")
	edge_probe_check(trench_climb_place(H, edge_descent_destination(H, EAST)) && H.loc == locate(6, 5, 1), "placed_on_ground")

	// A wooden ladder from above (open air) and from below (ground) is the same pair.
	var/list/spot = placed_ladder_spot(locate(6, 5, 2), H, why)
	edge_probe_check(spot && spot[1] == locate(6, 5, 1) && spot[2] == locate(6, 5, 2), "ladder_from_above")
	spot = placed_ladder_spot(locate(6, 5, 1), H, why)
	edge_probe_check(spot && spot[1] == locate(6, 5, 1) && spot[2] == locate(6, 5, 2), "ladder_from_below")
	edge_probe_check(!placed_ladder_spot(locate(5, 5, 1), H, why) && findtext(why[1], "ceiling"), "ladder_under_floor_reason")
	var/obj/structure/multiz/ladder/up/placed/bottom = new(locate(6, 5, 1))
	var/obj/structure/multiz/ladder/placed/top = new(locate(6, 5, 2))
	edge_probe_check(bottom.find_target() == top && top.find_target() == bottom, "ladder_ends_pair")
	edge_probe_check(!(top in ladder_list) && !(bottom in ladder_list), "ladder_not_in_mapped_numbering")
	edge_probe_check(!placed_ladder_spot(locate(6, 5, 2), H, why) && findtext(why[1], "already"), "ladder_twice_reason")
	// Walking onto the ladder top does not drop you.
	var/mob/living/human/W = edge_probe_human(locate(5, 6, 2))
	W.forceMove(locate(6, 5, 2))
	edge_probe_check(W.z == 2, "ladder_top_holds")
	qdel(W)
	qdel(bottom)
	edge_probe_check(QDELETED(top) || top.gc_destroyed, "ladder_ends_go_together")

	// Stairs at (3,3) built facing north, open air above, a floor at (3,4,2).
	var/obj/covers/wood/stairs/S = new(locate(3, 3, 1))
	S.dir = NORTH
	new /obj/covers/wood(locate(3, 4, 2))
	var/mob/living/human/C = edge_probe_human(locate(3, 3, 1))
	edge_probe_check(stairs_in(locate(3, 3, 1)) == S, "stairs_found")
	edge_probe_check(stairs_destination(C, S) == locate(3, 4, 2), "stairs_lead_up")
	// A floor over the stairs is a ceiling.
	var/obj/covers/wood/stairs/S2 = new(locate(9, 9, 1))
	new /obj/covers/wood(locate(9, 9, 2))
	edge_probe_check(!stairs_destination(C, S2, why) && findtext(why[1], "ceiling"), "stairs_ceiling_reason")
	// No floor at the top.
	var/obj/covers/wood/stairs/S3 = new(locate(9, 2, 1))
	edge_probe_check(!stairs_destination(C, S3, why) && findtext(why[1], "no floor"), "stairs_no_top_reason")
	// Walking off the top floor onto the stairwell steps down onto the stairs.
	var/mob/living/human/D = edge_probe_human(locate(3, 4, 2))
	var/before = D.getBruteLoss()
	D.forceMove(locate(3, 3, 2))
	edge_probe_check(D.loc == locate(3, 3, 1) && D.getBruteLoss() == before, "stairwell_walks_down")
	// Open air with no stairs below still drops you.
	var/mob/living/human/F = edge_probe_human(locate(5, 6, 2))
	F.forceMove(locate(7, 7, 2))
	edge_probe_check(F.z == 1, "plain_open_air_still_falls")

/proc/edge_probe_check(ok, label)
	edge_probe_log += label
	if (!ok)
		throw EXCEPTION(label)

/world/New()
	OpenPort("none")
	var/error = null
	try
		edge_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] [probe_error.file]:[probe_error.line]"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("log" = edge_probe_log, "error" = error)), "receipt.json")
	del(world)
