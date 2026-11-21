// Native probe: ramps laid as a run of sections under open air lead up a
// storey from their top section, carry what their kind allows, and walk back
// down from the opening above. Stairs and ladders keep their own load rules.
/world
	hub = ""
	visibility = 0
	maxx = 16
	maxy = 16
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

/obj/map_metadata/ramps_native/New()
	map = src

/mob/living/human/ramps_native/human_subtile_authority(client/owner)
	return TRUE

var/list/ramp_probe_log = list()

/proc/ramp_probe_human(turf/T)
	var/mob/living/human/ramps_native/H = new(T)
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.set_human_subtile(TRUE)
	return H

/proc/ramp_probe_pull(mob/living/H, atom/movable/A)
	H.pulling = A
	A.pulledby = H

// A run of sections climbing EAST along row y from x0, with a floor beyond.
/proc/ramp_probe_run(path, x0, y, sections)
	var/list/run = list()
	for (var/i in 0 to sections - 1)
		var/obj/covers/C = new path(locate(x0 + i, y, 1))
		C.set_dir(EAST)
		run += C
	new /obj/covers/wood(locate(x0 + sections, y, 2))
	return run

/proc/ramp_probe_run_all()
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
	map = new /obj/map_metadata/ramps_native
	for (var/tx in 1 to 16)
		for (var/ty in 1 to 16)
			new /turf/sky/building(locate(tx, ty, 2))

	// Timber ramp: x 2-5 on row 2, floor at (6,2,2).
	var/list/timber = ramp_probe_run(/obj/covers/wood/ramp, 2, 2, 4)
	var/obj/covers/top = timber[4]
	ramp_probe_check(ramp_top_in(locate(5, 2, 1)) == top && stairs_in(locate(5, 2, 1)) == top, "timber_top_found")
	ramp_probe_check(!stairs_in(locate(4, 2, 1)), "only_the_top_climbs")
	ramp_probe_check(findtext(ramp_problem(timber[2]), "Walk on up"), "lower_section_points_up")
	var/mob/living/human/H = ramp_probe_human(locate(5, 2, 1))
	ramp_probe_check(stairs_destination(H, top) == locate(6, 2, 2), "timber_leads_up")
	// Too short: three sections.
	qdel(timber[1])
	ramp_probe_check(findtext(ramp_problem(top), "3 sections long") && !stairs_in(locate(5, 2, 1)), "short_ramp_reason")
	timber[1] = new /obj/covers/wood/ramp(locate(2, 2, 1))
	var/obj/covers/first = timber[1]
	first.set_dir(EAST)
	ramp_probe_check(!ramp_problem(top), "relaid_ramp_complete")
	// A floor over any section is a ceiling.
	var/obj/covers/lid = new /obj/covers/wood(locate(3, 2, 2))
	ramp_probe_check(findtext(ramp_problem(top), "open air above"), "ramp_ceiling_reason")
	qdel(lid)
	ramp_probe_check(!ramp_problem(top), "ceiling_removed")
	// A section facing another way breaks the run.
	var/obj/covers/turned = timber[3]
	turned.set_dir(NORTH)
	ramp_probe_check(ramp_problem(top), "turned_section_breaks_run")
	turned.set_dir(EAST)

	// A hand cart rolls up a timber ramp with its puller and stays in hand.
	var/obj/structure/closet/crate/cart/cart = new(locate(4, 2, 1))
	ramp_probe_pull(H, cart)
	ramp_probe_check(H.climb_stairs(top, FALSE) && H.loc == locate(6, 2, 2) && cart.loc == H.loc && H.pulling == cart, "cart_rolls_up_timber")
	H.stop_pulling()
	qdel(cart) // clear the landing for the next climber
	// Walking off the floor into the opening walks back down the ramp.
	var/before = H.getBruteLoss()
	H.forceMove(locate(5, 2, 2))
	ramp_probe_check(H.loc == locate(5, 2, 1) && H.getBruteLoss() == before, "walks_down_the_ramp")
	// Someone in a wheelchair rolls up with the chair.
	var/mob/living/human/R = ramp_probe_human(locate(5, 2, 1))
	var/obj/structure/bed/chair/wheelchair/chair = new(locate(5, 2, 1))
	R.buckled = chair
	chair.buckled_mob = R
	ramp_probe_check(R.climb_stairs(top, FALSE) && R.loc == locate(6, 2, 2) && chair.loc == R.loc && R.buckled == chair, "wheelchair_rolls_up_timber")

	// Earth ramp: x 2-5 on row 6. Too rough for wheels, fine for a crate.
	var/list/earth = ramp_probe_run(/obj/covers/cobblestone/ramp_earth, 2, 6, 4)
	var/obj/covers/earth_top = earth[4]
	var/mob/living/human/E = ramp_probe_human(locate(5, 6, 1))
	var/obj/structure/closet/crate/cart/cart2 = new(locate(4, 6, 1))
	ramp_probe_pull(E, cart2)
	ramp_probe_check(E.climb_stairs(earth_top, FALSE) && E.loc == locate(6, 6, 2) && cart2.loc == locate(4, 6, 1) && !E.pulling, "earth_ramp_drops_cart")
	E.forceMove(locate(14, 14, 1)) // clear the landing
	var/mob/living/human/E2 = ramp_probe_human(locate(5, 6, 1))
	var/obj/structure/closet/crate/crate = new(locate(4, 6, 1))
	ramp_probe_pull(E2, crate)
	ramp_probe_check(E2.climb_stairs(earth_top, FALSE) && crate.loc == locate(6, 6, 2), "earth_ramp_takes_crate")
	E2.stop_pulling()
	E2.forceMove(locate(14, 15, 1))
	qdel(crate)
	var/mob/living/human/E3 = ramp_probe_human(locate(5, 6, 1))
	var/obj/structure/bed/chair/wheelchair/chair2 = new(locate(5, 6, 1))
	E3.buckled = chair2
	chair2.buckled_mob = E3
	ramp_probe_check(!stairs_destination(E3, earth_top), "earth_ramp_refuses_wheelchair")
	E3.buckled = null
	chair2.buckled_mob = null
	ramp_probe_check(stairs_destination(E3, earth_top) == locate(6, 6, 2), "earth_ramp_takes_walker")

	// Stairs take a crate but not a cart (the rule from #6142 is kept).
	var/obj/covers/wood/stairs/S = new(locate(12, 2, 1))
	S.set_dir(NORTH)
	new /obj/covers/wood(locate(12, 3, 2))
	var/mob/living/human/T = ramp_probe_human(locate(12, 2, 1))
	var/obj/structure/closet/crate/cart/cart3 = new(locate(12, 1, 1))
	ramp_probe_pull(T, cart3)
	ramp_probe_check(T.climb_stairs(S, FALSE) && cart3.loc == locate(12, 1, 1) && !T.pulling, "stairs_still_drop_carts")

	// Stone ramp: eight sections, x 2-9 on row 12. A heavy load needs a helper.
	var/list/stone = ramp_probe_run(/obj/covers/cobblestone/ramp_gentle, 2, 12, 8)
	var/obj/covers/stone_top = stone[8]
	ramp_probe_check(!ramp_problem(stone_top) && stairs_in(locate(9, 12, 1)) == stone_top, "stone_ramp_needs_eight")
	var/obj/covers/concretefloor/ramp/joined = new(locate(5, 12, 1))
	ramp_probe_check(joined.icon_state == "concrete_ramp", "concrete_ramp_keeps_its_sprite")
	qdel(joined)
	var/mob/living/human/P = ramp_probe_human(locate(9, 12, 1))
	var/obj/structure/anvil/anvil = new(locate(8, 12, 1))
	ramp_probe_check(findtext(level_change_load_problem(anvil, FALSE, RAMP_HEAVY, P), "alone"), "heavy_needs_helper")
	ramp_probe_check(findtext(level_change_load_problem(anvil, FALSE, RAMP_WHEELS, P), "far too heavy"), "heavy_refused_on_timber")
	var/mob/living/human/helper = ramp_probe_human(locate(8, 11, 1))
	ramp_probe_check(ramp_haul_helper(P, anvil) == helper && !level_change_load_problem(anvil, FALSE, RAMP_HEAVY, P), "helper_lets_heavy_up")
	ramp_probe_check(findtext(level_change_load_problem(anvil, TRUE), "far too heavy"), "ladder_still_refuses_heavy")

/proc/ramp_probe_check(ok, label)
	ramp_probe_log += label
	if (!ok)
		throw EXCEPTION(label)

/world/New()
	OpenPort("none")
	var/error = null
	try
		ramp_probe_run_all()
	catch (var/exception/probe_error)
		error = "[probe_error.name] [probe_error.file]:[probe_error.line]"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("log" = ramp_probe_log, "error" = error)), "receipt.json")
	del(world)
