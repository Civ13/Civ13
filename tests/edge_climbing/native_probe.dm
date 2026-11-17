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

/datum/edge_probe_lift
	var/pressed = 0

/datum/edge_probe_lift/updown_offer(mob/living/human/user, direction)
	return direction == DOWN ? "Lower the lift" : null

/datum/edge_probe_lift/updown_press(mob/living/human/user, direction)
	pressed = direction
	return TRUE

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
	// The down button stays lit with full hands; pressing it says what to change.
	edge_probe_check(findtext(H.updown_offer(H, DOWN), "over the edge"), "button_down_edge_full_hands")
	edge_probe_check(!H.updown_offer(H, UP), "button_up_nothing_above")
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
	// The up button climbs the ladder H stands on; from the floor above, the
	// down button prefers the ladder beside you to the open edge.
	edge_probe_check(H.loc == bottom.loc && findtext(H.updown_offer(H, UP), "Climb up") && findtext(H.updown_offer(H, UP), "ladder"), "button_up_ladder")
	var/mob/living/human/L = edge_probe_human(locate(5, 6, 2))
	edge_probe_check(findtext(L.updown_offer(L, DOWN), "Climb down") && findtext(L.updown_offer(L, DOWN), "ladder"), "button_down_ladder_beside")
	qdel(L)
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
	edge_probe_check(C.updown_offer(C, UP) == "Climb the stairs", "button_up_stairs")
	// The HUD tiles light or grey out from the same offer.
	var/obj/screen/updown/up_tile = new("go up", "1,1", C)
	var/obj/screen/updown/down/down_tile = new("go down", "1,2", C)
	edge_probe_check(up_tile.name == "go up" && down_tile.name == "go down", "button_name_kept_until_first_check")
	up_tile.refresh(TRUE)
	down_tile.refresh(TRUE)
	edge_probe_check(up_tile.icon_state == "arrow_up" && up_tile.name == "Climb the stairs", "button_up_lit")
	edge_probe_check(down_tile.icon_state == "arrow_down_off", "button_down_greyed")
	edge_probe_check(!C.updown_press(C, DOWN), "button_down_press_refuses")
	// A machine can take the buttons over and hand them back.
	var/datum/edge_probe_lift/lift = new
	C.updown_control = lift
	down_tile.refresh(TRUE)
	edge_probe_check(down_tile.icon_state == "arrow_down" && down_tile.name == "Lower the lift", "button_taken_over")
	edge_probe_check(C.updown_handler().updown_press(C, DOWN) && lift.pressed == DOWN, "button_press_reaches_control")
	C.updown_control = null
	down_tile.refresh(TRUE)
	edge_probe_check(down_tile.icon_state == "arrow_down_off", "button_handed_back")
	qdel(up_tile)
	qdel(down_tile)
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

	// Stairs built from an upper floor facing an opening go on the ground
	// below it and climb back up to the builder.
	new /obj/covers/wood(locate(10, 11, 2))
	var/mob/living/human/B = edge_probe_human(locate(10, 11, 2))
	B.dir = WEST
	var/list/down = stairs_down_spot(B, /obj/covers/wood/stairs, why)
	edge_probe_check(down && down[1] == locate(9, 11, 1) && down[2] == EAST, "stairs_down_spot")
	var/obj/covers/wood/stairs/SD = new(down[1])
	SD.dir = down[2]
	// The builder stands on the landing; anyone else climbing lands there.
	B.forceMove(locate(5, 6, 2))
	edge_probe_check(stairs_destination(edge_probe_human(locate(2, 1, 1)), SD) == locate(10, 11, 2), "stairs_down_lead_back_up")
	B.forceMove(locate(10, 11, 2))
	edge_probe_check(!stairs_down_spot(B, /obj/covers/wood/stairs, why) && findtext(why[1], "already"), "stairs_down_twice_reason")
	// The open air over the stairs shows the top of the stairs, turned the way
	// they climb, and still walks down safely.
	stairs_refresh_top(SD)
	var/obj/effect/stairwell_top/well_top = locate() in locate(9, 11, 2)
	edge_probe_check(well_top && well_top == SD.stairwell_top && well_top.dir == EAST && !well_top.should_save && !well_top.mouse_opacity, "stairwell_top_marker")
	edge_probe_check(edge_open_air(locate(9, 11, 2)), "stairwell_top_is_still_open_air")
	var/mob/living/human/TD = edge_probe_human(locate(10, 12, 1))
	TD.forceMove(locate(10, 11, 2))
	TD.forceMove(locate(9, 11, 2))
	edge_probe_check(TD.loc == locate(9, 11, 1), "stairwell_top_walks_down")
	TD.forceMove(locate(10, 12, 1))
	// Facing a floor, the builder is told to face an opening.
	new /obj/covers/wood(locate(11, 11, 2))
	B.dir = EAST
	edge_probe_check(!stairs_down_spot(B, /obj/covers/wood/stairs, why) && findtext(why[1], "face it"), "stairs_down_face_opening_reason")
	// A floor below the opening must come up first.
	new /obj/covers/wood(locate(10, 10, 1))
	B.dir = SOUTH
	edge_probe_check(!stairs_down_spot(B, /obj/covers/wood/stairs, why) && findtext(why[1], "hammer"), "stairs_down_floor_below_reason")
	// More than one storey down is refused.
	new /obj/covers/wood(locate(11, 10, 2))
	var/mob/living/human/B2 = edge_probe_human(locate(11, 10, 2))
	B2.dir = SOUTH
	new /turf/sky/building(locate(11, 9, 1))
	edge_probe_check(!stairs_down_spot(B2, /obj/covers/wood/stairs, why) && findtext(why[1], "more than one storey"), "stairs_down_long_drop_reason")
	// On bare ground, stairs are built underfoot as before.
	var/mob/living/human/G = edge_probe_human(locate(1, 1, 1))
	edge_probe_check(!stairs_down_spot(G, /obj/covers/wood/stairs, why) && !why.len, "stairs_underfoot_unchanged")
	// On a ground floor facing more floor, the usual underfoot refusal stands.
	new /obj/covers/wood(locate(1, 2, 1))
	new /obj/covers/wood(locate(1, 3, 1))
	var/mob/living/human/GF = edge_probe_human(locate(1, 2, 1))
	GF.dir = NORTH
	edge_probe_check(!stairs_down_spot(GF, /obj/covers/wood/stairs, why) && !why.len, "ground_floor_no_down_spot")
	// Taking the stairs away takes the marker with them.
	qdel(SD)
	edge_probe_check(QDELETED(well_top) && !(locate(/obj/effect/stairwell_top) in locate(9, 11, 2)), "stairwell_top_goes_with_stairs")

	// Climbing down lands in shallow water you can wade in, not deep water,
	// unless a floor is built over it.
	new /obj/covers/wood(locate(2, 6, 2))
	var/mob/living/human/K = edge_probe_human(locate(2, 6, 2))
	new /turf/floor/beach/water(locate(3, 6, 1))
	edge_probe_check(edge_descent_destination(K, EAST) == locate(3, 6, 1), "climb_down_into_shallow_water")
	new /turf/floor/beach/water/deep(locate(3, 6, 1))
	edge_probe_check(!edge_descent_destination(K, EAST, why) && findtext(why[1], "not clear"), "deep_water_refused")
	new /obj/covers/wood(locate(3, 6, 1))
	edge_probe_check(edge_descent_destination(K, EAST) == locate(3, 6, 1), "floor_over_deep_water_lands")
	// Stairs built on shallow water: walking onto the stairwell from above
	// steps down onto them instead of falling.
	new /turf/floor/beach/water(locate(8, 4, 1))
	var/obj/covers/wood/stairs/SW = new(locate(8, 4, 1))
	SW.dir = NORTH
	new /obj/covers/wood(locate(8, 5, 2))
	var/mob/living/human/WD = edge_probe_human(locate(8, 5, 2))
	var/water_before = WD.getBruteLoss()
	WD.forceMove(locate(8, 4, 2))
	edge_probe_check(WD.loc == locate(8, 4, 1) && WD.getBruteLoss() == water_before, "stairs_on_shallow_water_walk_down")

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
