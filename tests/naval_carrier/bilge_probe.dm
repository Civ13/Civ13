// The hull ledger (code/modules/naval/hull_ledger.dm): bilge water on a hull
// the players built. Small craft keep dry, wooden boats and ships seep while
// they are awake, the water weighs on her drives and stops at awash, an empty
// bucket bails it, and the tiller saves it.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// A plank laid the way a player lays one, with its first update already run.
/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/hull_planks(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		.++

/proc/steel_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/steelplating/C = new(T)
	C.updateturf()
	return C

/proc/bilge_hull(x1, y1, x2, y2, hull_name, steel = FALSE)
	for (var/x = x1, x <= x2, x++)
		for (var/y = y1, y <= y2, y++)
			if (steel)
				steel_lay(x, y)
			else
				hull_lay(x, y)
	var/obj/structure/hull_tiller/tiller = new(locate(x1, y1, 2))
	naval_check(isnull(tiller.commission(hull_name, NORTH)) && tiller.craft, "the [hull_name] is commissioned")
	return tiller

/proc/near(a, b, slack = 0.01)
	return abs(a - b) <= slack

/proc/naval_checks()
	hull_ledger_timer_off = TRUE
	naval_fixture()
	// ---- A small craft: 3 x 4 = 12 tiles ----
	var/obj/structure/hull_tiller/skiff = bilge_hull(25, 5, 27, 8, "Skiff")
	var/datum/hull_ledger/S = skiff.craft.ledger
	naval_check(S && S.tiles == 12 && S.hull_class() == HULL_CLASS_SMALL && S.class_name() == "small craft", "twelve tiles of hull are a small craft with a ledger")
	naval_check(S.seep_rate() == 0, "a small craft does not seep")
	skiff.craft.set_anchor(FALSE)
	skiff.craft.set_speed(VESSEL_SPEED_SLOW)
	naval_check(S.awake(), "under way she is awake")
	S.step_ledger(1800)
	naval_check(S.water == 0 && S.depth() == HULL_DEPTH_DRY, "half an hour under way leaves her bilge dry")
	naval_check(findtext(skiff.status_text(), "small craft") && findtext(skiff.status_text(), "bilge is dry"), "her tiller says so ([S.status_text()])")
	skiff.craft.set_speed(VESSEL_SPEED_STOP)
	skiff.craft.set_anchor(TRUE)

	// ---- A boat: 3 x 10 = 30 tiles of wood ----
	var/obj/structure/hull_tiller/tiller = bilge_hull(35, 5, 37, 14, "Knarr")
	var/datum/craft/C = tiller.craft
	var/datum/hull_ledger/L = C.ledger
	naval_check(L && L.tiles == 30 && L.seep_tiles == 30 && L.hull_class() == HULL_CLASS_BOAT, "thirty tiles of wooden hull are a boat, every tile seeping")
	naval_check(L.capacity() == 120 && L.limit() == 60, "she holds 120 bucketfuls and is awash at 60")
	naval_check(near(L.seep_rate(), 1.35), "her seams let in 1.35 bucketfuls a minute under way ([L.seep_rate()])")
	naval_check(C.mass() == 30, "dry, her drives push 30 tiles")
	// Asleep: at anchor with nobody aboard nothing changes.
	naval_check(!L.awake(), "at anchor with no player aboard she is asleep")
	naval_check(hull_ledgers_tick() == 0 && L.water == 0, "the step passes a sleeping hull by")
	// A player aboard, lying still: half the rate.
	L.crewed = TRUE
	naval_check(L.awake(), "with a player aboard she is awake")
	L.step_ledger(600)
	naval_check(L.water_weight() == 0 && C.mass() == 30, "a damp bilge weighs nothing she notices")
	naval_check(near(L.water, 6.75), "ten minutes at anchor with her crew aboard let in 6.75 bucketfuls ([L.water])")
	naval_check(L.depth() == HULL_DEPTH_DAMP, "her bilge is damp")
	L.crewed = FALSE
	// Under way: the full rate, and the step finds her by herself.
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(hull_ledgers_tick() == 1, "under way the step finds her and no other")
	naval_check(near(L.water, 6.75 + 0.675), "thirty seconds under way let in 0.675 bucketfuls ([L.water])")
	L.water = 0
	L.depth_told = HULL_DEPTH_DRY
	L.seams = HULL_SEAMS_FAIR
	L.step_ledger(1800)
	naval_check(near(L.water, 40.5), "half an hour under way lets in 40.5 bucketfuls ([L.water])")
	naval_check(L.depth() == HULL_DEPTH_KNEE && L.depth_told == HULL_DEPTH_KNEE, "her bilge is knee deep and her crew was told")
	naval_check(L.water_weight() == 7 && C.mass() == 37, "the water weighs like seven more tiles of hull ([C.mass()])")
	naval_check(near(C.push_strength_needed(), 1.8), "and pushing her off takes more strength now ([C.push_strength_needed()])")
	naval_check(findtext(tiller.status_text(), "knee deep") && findtext(tiller.status_text(), "40 bucketfuls of 60"), "the tiller reads the bilge ([L.status_text()])")
	L.step_ledger(3600)
	naval_check(L.water == 60 && L.depth() == HULL_DEPTH_AWASH, "left alone she is awash and takes no more")
	naval_check(C.mass() == 42, "awash she pushes 42 tiles")
	// A sail that made half ahead dry cannot when she is awash.
	L.water = 0
	var/obj/structure/vehicleparts/movement/sail/mast = new(locate(36, 9, 2))
	mast.sails = TRUE
	C.fit_drives()
	naval_check(C.max_speed() == VESSEL_SPEED_HALF, "dry, one mast makes half ahead on 30 tiles (push [C.thrust()])")
	L.water = 60
	var/push = C.thrust()
	naval_check((push / C.mass() >= 1) == (C.max_speed() == VESSEL_SPEED_HALF), "awash, the same sail has 42 tiles to push (push [push], best step [C.max_speed()])")
	C.set_speed(VESSEL_SPEED_STOP)
	C.set_anchor(TRUE)

	// ---- Bailing ----
	var/mob/living/human/naval_probe/hand = new(locate(36, 6, 2))
	var/obj/item/weapon/reagent_containers/glass/bucket/bucket = new(locate(36, 6, 2))
	var/obj/covers/plank = locate(/obj/covers) in locate(36, 7, 2)
	naval_check(isnull(hull_bail_refusal(hand, bucket, plank)), "a hand on her deck with an empty bucket may bail ([hull_bail_refusal(hand, bucket, plank)])")
	bucket.reagents.add_reagent("water", 20)
	naval_check(findtext(hull_bail_refusal(hand, bucket, plank), "empty the bucket"), "a bucket with something in it must be emptied first")
	bucket.reagents.clear_reagents()
	hand.forceMove(locate(34, 6, 2))
	naval_check(findtext(hull_bail_refusal(hand, bucket, plank), "on her deck"), "nobody bails her from the water beside her")
	hand.forceMove(locate(36, 6, 2))
	var/obj/covers/skiff_plank = locate(/obj/covers) in locate(26, 6, 2)
	var/mob/living/human/naval_probe/skipper = new(locate(26, 5, 2))
	naval_check(findtext(hull_bail_refusal(skipper, bucket, skiff_plank), "dry"), "a dry bilge has nothing to bail")
	naval_check(L.remove_water(1) == 1 && L.water == 59 && L.depth() == HULL_DEPTH_KNEE && L.depth_told == HULL_DEPTH_KNEE, "a bucketful over the side takes one out and she is no longer awash")
	naval_check(L.remove_water(100) == 59 && L.water == 0 && L.depth_told == HULL_DEPTH_DRY, "bailing never takes more than is there")
	naval_check(findtext(hull_bail_refusal(hand, bucket, plank), "dry"), "and a bailed bilge is dry")

	// ---- A refit keeps the water and counts her again ----
	L.water = 30
	for (var/y = 5, y <= 14, y++)
		hull_lay(38, y)
	naval_check(isnull(tiller.commission()) && C.ledger == L && L.tiles == 40 && L.water == 30, "a wider hull is surveyed again and keeps her water")
	for (var/y = 5, y <= 14, y++)
		hull_lay(39, y)
	tiller.commission()
	naval_check(L.tiles == 50 && L.hull_class() == HULL_CLASS_SHIP && L.class_name() == "ship", "fifty tiles of hull are a ship")

	// ---- Saving ----
	tiller.before_save()
	var/list/saved = json_decode(tiller.hull_state)
	naval_check(islist(saved["ledger"]) && saved["ledger"]["water"] == 30, "the tiller saves her bilge")
	var/datum/craft/old = tiller.craft
	tiller.craft = null
	qdel(old.body)
	qdel(old)
	naval_check(!(L in hull_ledgers), "a hull that is gone leaves no ledger behind")
	tiller.after_load()
	naval_check(tiller.craft && tiller.craft.ledger && tiller.craft.ledger.water == 30 && tiller.craft.ledger.tiles == 50, "and a loaded world finds her with the same water")
	naval_check(tiller.craft.ledger.depth_told == tiller.craft.ledger.depth(), "her crew is not told again of water they knew")

	// ---- A steel hull ----
	var/obj/structure/hull_tiller/steamer = bilge_hull(45, 20, 47, 29, "Steamer", TRUE)
	var/datum/hull_ledger/T = steamer.craft.ledger
	naval_check(T && T.tiles == 30 && T.seep_tiles == 0 && T.seep_rate() == 0, "a steel hull has no seams to seep")
	steamer.craft.set_anchor(FALSE)
	steamer.craft.set_speed(VESSEL_SPEED_SLOW)
	T.step_ledger(1800)
	naval_check(T.water == 0 && findtext(T.status_text(), "plating"), "and stays dry under way")
	steamer.craft.set_speed(VESSEL_SPEED_STOP)

	// ---- Holes ----
	var/obj/structure/hull_tiller/cog_tiller = bilge_hull(25, 30, 27, 39, "Cog")
	var/datum/craft/G = cog_tiller.craft
	var/datum/hull_ledger/H = G.ledger
	var/turf/hole = locate(26, 34, 2)
	var/obj/covers/shot = locate(/obj/covers) in hole
	qdel(shot)
	naval_check(H.holes == 1 && H.hole_at(hole) && G.body.tile_count() == 30, "a floor shot away leaves a hole in her hull and she keeps her shape")
	naval_check(findtext(H.status_text(), "1 hole in her hull lets the sea in"), "the tiller reports the hole ([H.status_text()])")
	naval_check(findtext(cog_tiller.commission(), "Patch the hole"), "she cannot be surveyed again while she is holed")
	// A wall built aboard is no part of her bottom.
	var/obj/covers/wood_wall/wall = new(locate(25, 31, 2))
	wall.afloat = TRUE
	qdel(wall)
	naval_check(H.holes == 1, "a wall knocked down aboard is no hole")
	// Asleep she takes nothing; awake the hole outruns one bailer.
	naval_check(hull_ledgers_tick() == 0 && H.water == 0, "holed but asleep, she takes no water")
	H.crewed = TRUE
	H.step_ledger(60)
	naval_check(near(H.water, 25 + 0.675), "awake, the hole lets in 25 bucketfuls a minute on top of her seams ([H.water])")
	H.step_ledger(120)
	naval_check(H.water > H.limit() && H.depth() == HULL_DEPTH_AWASH, "a hole takes her past awash ([H.water])")
	H.water = 95
	H.depth_told = HULL_DEPTH_AWASH
	H.step_ledger(1)
	naval_check(H.depth() == HULL_DEPTH_LISTING && H.depth_told == HULL_DEPTH_LISTING, "three quarters full she lists and her crew is told")
	var/obj/structure/vehicleparts/movement/sail/cog_mast = new(locate(26, 31, 2))
	cog_mast.sails = TRUE
	var/obj/structure/vehicleparts/movement/sail/cog_mast2 = new(locate(26, 38, 2))
	cog_mast2.sails = TRUE
	G.fit_drives()
	naval_check(G.thrust() / G.mass() >= 1 && G.max_speed() == VESSEL_SPEED_SLOW, "listing, two masts that could make half ahead make slow ahead at best (push [G.thrust()] on [G.mass()])")

	// ---- Patching ----
	var/mob/living/human/naval_probe/carpenter = new(locate(26, 33, 2))
	var/obj/item/stack/material/wood/timber = new(locate(26, 33, 2))
	timber.amount = 5
	naval_check(findtext(hull_patch_refusal(carpenter, timber, hole), "hammer"), "a patch needs a hammer in the other hand ([hull_patch_refusal(carpenter, timber, hole)])")
	naval_check(findtext(hull_patch_refusal(carpenter, timber, locate(26, 35, 2)), "no hole"), "sound planks need no patch")
	naval_check(findtext(hull_patch_refusal(carpenter, timber, locate(40, 40, 2)), "no hole"), "nor does the open sea")
	var/obj/covers/patch = hull_patch_lay(G, timber, hole)
	naval_check(istype(patch, /obj/covers/repairedfloor/ship/patch) && patch.afloat && timber.amount == 3, "the patch is a floor of her hull and takes two pieces of wood")
	naval_check(H.holes == 0 && H.patches == 1 && !H.hole_at(hole), "the hole is closed and counted as a patch")
	H.water = 0
	H.depth_told = HULL_DEPTH_DRY
	H.step_ledger(60)
	naval_check(near(H.water, 30 * 0.045 * 0.5 + 1), "a patch weeps a bucketful a minute on top of her seams ([H.water])")
	naval_check(isnull(cog_tiller.commission()) && H.patches == 1 && H.holes == 0 && H.seep_tiles == 29, "patched, she is surveyed again and the patch is found")
	// Water a hole let in past awash stays until it is bailed.
	H.water = 100
	H.step_ledger(600)
	naval_check(H.water == 100, "with the hole patched the water neither rises nor drains by itself")
	qdel(patch)
	naval_check(H.holes == 1 && H.patches == 0, "a patch torn out is a hole again")

	// ---- Foundering on deep water ----
	H.water = 119
	H.step_ledger(60)
	naval_check(H.water == 120 && H.depth() == HULL_DEPTH_FULL && H.sink_left == HULL_SINK_WARNINGS && !H.grounded, "full on deep water she founders and the count begins")
	naval_check(!H.sink_tick() && H.sink_left == HULL_SINK_WARNINGS - 1, "half a minute on she is still afloat")
	H.remove_water(10)
	naval_check(!H.sink_tick() && H.sink_left == 0, "a crew that gets ahead of the water stops the count")
	H.step_ledger(60)
	naval_check(H.sink_left == HULL_SINK_WARNINGS, "the open hole fills her again and the count starts over")
	var/mob/living/human/naval_probe/mate = new(locate(25, 36, 2))
	var/obj/item/weapon/reagent_containers/glass/bucket/pail = new(locate(27, 36, 2))
	var/obj/structure/closet/crate/chest = new(locate(27, 37, 2))
	var/obj/structure/probe_gun/gun = new(locate(25, 37, 2))
	var/went = FALSE
	for (var/i = 1, i <= HULL_SINK_WARNINGS, i++)
		went = H.sink_tick()
	naval_check(went && H.depth_disabled, "four half minutes later the flooded hull cannot sail")
	var/left = 0
	for (var/x = 25, x <= 27, x++)
		for (var/y = 30, y <= 39, y++)
			left += hull_planks(locate(x, y, 2))
	naval_check(left > 0 && !QDELETED(cog_tiller) && !QDELETED(cog_mast) && !QDELETED(gun), "without a valid lower level the complete hull stays in place")
	naval_check(!QDELETED(mate) && mate.z == 2 && mate.x == 25 && !QDELETED(carpenter) && !QDELETED(pail) && !QDELETED(chest) && !QDELETED(timber), "the same crew and cargo are preserved")
	var/turf/was_deck = locate(26, 36, 2)
	naval_check(craft_at(was_deck) == cog_tiller.craft && (H in hull_ledgers), "the existing hull retains its ledger and occupancy")
	var/datum/craft_body/built/cog_body = cog_tiller.body()
	for (var/turf/cog_surface in cog_body.cells())
		var/turf/cog_seabed = locate(cog_surface.x, cog_surface.y, 1)
		cog_seabed.ChangeTurf(/turf/floor/beach/water/deep/saltwater/underwater/sea_layer)
	var/obj/structure/probe_rock/blocker = new(locate(27, 38, 1))
	naval_check(!H.step_hull_depth() && cog_tiller.z == 2 && chest.z == 2, "one blocked destination prevents the whole descent")
	qdel(blocker)
	naval_check(H.step_hull_depth() && cog_tiller.z == 1 && chest.z == 1 && mate.z == 1 && cog_tiller.craft == G, "the complete ship, crew and cargo descend as the same objects")
	cog_tiller.before_save()
	var/list/saved_hull = json_decode(cog_tiller.hull_state)
	var/list/saved_depth = saved_hull["ledger"]
	naval_check(saved_depth["depth_disabled"] && saved_depth["water"] >= 119, "the existing tiller saves depth disablement and bilge")
	H.holes = 0 // Assume an outside repair for this traversal-only fixture.
	H.remove_water(H.capacity())
	naval_check(H.step_hull_depth() && cog_tiller.z == 2 && mate.z == 2 && chest.z == 2 && !H.depth_disabled, "a patched and pumped hull refloats with contents intact")


	// ---- Grounding in the shallows ----
	for (var/x = 50, x <= 56, x++)
		for (var/y = 30, y <= 45, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)
	var/obj/structure/hull_tiller/punt_tiller = bilge_hull(52, 32, 54, 41, "Punt")
	var/datum/craft/P = punt_tiller.craft
	var/datum/hull_ledger/N = P.ledger
	var/turf/gap = locate(53, 36, 2)
	qdel(locate(/obj/covers) in gap)
	N.crewed = TRUE
	N.water = 119
	N.step_ledger(60)
	naval_check(N.grounded && N.sink_left == 0 && N.water == 120, "full in the shallows she settles on the bottom and does not sink")
	P.set_anchor(FALSE)
	P.set_speed(VESSEL_SPEED_SLOW)
	naval_check(P.speed == VESSEL_SPEED_STOP && !P.order_turn(EAST) && findtext(P.last_refusal, "bottom"), "on the bottom she neither sails nor comes about")
	N.remove_water(100)
	N.step_ledger(1)
	naval_check(N.grounded, "bailed but still holed she stays down")
	var/obj/item/stack/material/wood/more = new(locate(53, 35, 2))
	more.amount = 2
	hull_patch_lay(P, more, gap)
	N.water = 70
	N.step_ledger(1)
	naval_check(N.grounded, "patched but still over awash she stays down")
	N.remove_water(30)
	N.step_ledger(1)
	naval_check(!N.grounded, "patched and bailed below awash she floats again")
	P.set_speed(VESSEL_SPEED_SLOW)
	naval_check(P.speed == VESSEL_SPEED_SLOW, "and answers her tiller")
	P.set_speed(VESSEL_SPEED_STOP)
	P.set_anchor(TRUE)
	// The grounding is saved.
	N.grounded = TRUE
	punt_tiller.before_save()
	var/list/punt_saved = json_decode(punt_tiller.hull_state)
	naval_check(punt_saved["ledger"]["grounded"] == 1 && punt_saved["ledger"]["patches"] == 1 && punt_saved["ledger"]["holes"] == 0, "the tiller saves her holes, patches and grounding")
	qdel(punt_tiller)

	// ---- Striking a hull ----
	var/count = hull_ledgers.len
	skiff.decommission()
	naval_check(hull_ledgers.len == count - 1 && !(S in hull_ledgers), "a struck hull gives up her ledger")
	qdel(steamer)
	qdel(tiller)
	naval_check(!hull_ledgers.len, "no ledger outlives its tiller")

// Small craft (naval/small_craft_leaks.dm): a raft or canoe stove in below
// half her strength ships water as she moves, and lies swamped at ten.
/proc/small_craft_checks()
	// A vehicle's own move registers glide listeners.
	if (!GLOB.global_listen_count)
		GLOB.global_listen_count = list()
	if (!GLOB.event_sources_count)
		GLOB.event_sources_count = list()
	if (!GLOB.event_listen_count)
		GLOB.event_listen_count = list()
	var/obj/structure/vehicle/raft/R = new(locate(25, 40, 2))
	var/mob/living/human/naval_probe/H = new(locate(25, 40, 2))
	R.driver = H
	R.ontop += H
	H.dir = NORTH
	naval_check(R.takes_water() && !R.leaky() && !R.leak_chance(), "a sound raft does not leak")
	naval_check(R.do_vehicle_check(), "a sound raft answers her paddle")
	var/obj/structure/vehicle/motorcycle/M = new(locate(5, 40, 2))
	naval_check(!M.takes_water() && !M.small_craft_damage(50) && !M.ship_water(), "a land vehicle is none of this")
	qdel(M)
	R.small_craft_damage(20)
	naval_check(R.health == 30 && !R.leaky(), "a knock above half her strength leaves her tight")
	naval_check(findtext(R.small_craft_text(), "still tight"), "a look says she is damaged but tight")
	R.small_craft_damage(10)
	naval_check(R.health == 20 && R.leaky() && R.leak_chance() == 44, "below half she leaks, the more the worse ([R.leak_chance()])")
	R.small_craft_damage(500)
	naval_check(R.health == 1 && !QDELETED(R) && R.leak_chance() == 97, "blows leave a hulk and never break her up ([R.leak_chance()])")
	// A hulk ships water on nearly every move; a sound raft on none.
	var/obj/structure/vehicle/raft/sound = new(locate(27, 40, 2))
	for (var/i = 1, i <= 60, i++)
		R.do_move(NORTH)
		sound.do_move(NORTH)
		if (R.swamped())
			break
	naval_check(R.swamped() && R.bilge == 10 && R.y > 40, "moving swamps a hulk (after [R.y - 40] tiles)")
	naval_check(sound.bilge == 0 && sound.y > 40, "the sound raft beside her stays dry")
	qdel(sound)
	H.forceMove(R.loc)
	naval_check(!R.do_vehicle_check(), "a swamped raft will not move")
	naval_check(!R.ship_water() && R.bilge == 10, "a swamped raft holds no more")
	naval_check((H in R.ontop) && R.driver == H && !QDELETED(R), "nobody is thrown out and nothing is lost")
	naval_check(findtext(R.small_craft_text(), "swamped") && findtext(R.small_craft_text(), "hulk"), "a look says she is a swamped hulk")
	R.bilge = 4
	naval_check(R.do_vehicle_check(), "bailed below the brim she moves again")
	naval_check(findtext(R.small_craft_text(), "4 bucketfuls"), "a look counts the water in her")
	// What mends and what harms.
	var/obj/item/stack/material/wood/logs = new(locate(25, 40, 2))
	var/obj/item/stack/material/cloth/cloth = new(locate(25, 40, 2))
	naval_check(R.mends_with(logs) && !R.mends_with(cloth), "wood mends a raft, cloth does not")
	var/obj/structure/vehicle/boat/rhib/rib = new(locate(30, 40, 2))
	naval_check(rib.takes_water() && rib.mends_with(cloth) && !rib.mends_with(logs), "cloth mends an inflatable")
	rib.small_craft_damage(160)
	naval_check(rib.health == 140 && rib.leaky(), "an inflatable holed below half leaks too")
	qdel(rib)
	var/obj/structure/vehicle/raft/dugout/C = new(locate(32, 40, 2))
	naval_check(C.takes_water() && !C.leaky(), "a canoe is a small craft")
	C.small_craft_damage(41)
	naval_check(C.leaky(), "a canoe below half her strength leaks")
	C.bilge = 10
	C.driver = H
	naval_check(!C.do_vehicle_check(), "a swamped canoe will not move")
	C.driver = null
	qdel(C)
	naval_check(!R.small_craft_work_refusal(H), "her paddler can work on her")
	H.forceMove(locate(40, 60, 2))
	naval_check(R.small_craft_work_refusal(H), "nobody bails or mends from afar")
	R.driver = null
	R.ontop -= H
	qdel(R)
	qdel(H)

// Caulking (naval/hull_caulking.dm): seams wear under way and are driven
// tight again with tarred oakum.
/proc/caulking_checks()
	var/obj/structure/hull_tiller/tiller = bilge_hull(60, 5, 62, 14, "Cog")
	var/datum/craft/C = tiller.craft
	var/datum/hull_ledger/L = C.ledger
	naval_check(near(L.seams, 1 / 3) && near(L.seam_factor(), 1) && L.seam_name() == "sound", "a new hull has sound seams and seeps at the plain rate ([L.seam_name()])")
	// Wear: only under way.
	L.crewed = TRUE
	L.step_ledger(3600)
	naval_check(near(L.seams, 1 / 3), "an hour at anchor wears nothing")
	L.crewed = FALSE
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	L.water = 0
	L.step_ledger(3600)
	naval_check(near(L.seams, 1 / 3 + 0.25), "an hour under way wears her seams a quarter of the way ([L.seams])")
	naval_check(L.seam_name() == "fair" && L.seams_told == 0, "they are fair still")
	L.step_ledger(600)
	naval_check(L.seams >= HULL_SEAMS_WORKING && L.seams_told == 1 && L.seam_name() == "working loose", "past six tenths they work loose and her crew is told")
	L.step_ledger(7200)
	naval_check(L.seams == 1 && L.seams_told == 2 && L.seam_name() == "open", "worn out, her seams are open and her crew is told")
	naval_check(near(L.seep_rate(), 2.7), "open seams let in twice the water (2.7 a minute, [L.seep_rate()])")
	naval_check(findtext(tiller.status_text(), "seams are open") && findtext(tiller.status_text(), "arred oakum"), "the tiller says so and what to do")
	// Tarred oakum from rope and pitch.
	var/mob/living/human/naval_probe/H = new(locate(61, 8, 2))
	var/obj/item/weapon/reagent_containers/glass/bucket/pot = new(locate(61, 8, 2))
	var/obj/item/stack/material/rope/rope = new(locate(61, 8, 2))
	rope.amount = 4
	naval_check(!oakum_dip(rope, pot, H), "an empty bucket makes no oakum")
	pot.reagents.add_reagent("pitch", 5)
	naval_check(oakum_dip(rope, pot, H) && rope.amount == 4, "five units of pitch are too little for a coil")
	pot.reagents.add_reagent("pitch", 25)
	naval_check(oakum_dip(rope, pot, H) && rope.amount == 3 && near(pot.reagents.get_reagent_amount("pitch"), 20), "a coil of rope soaks up ten units of pitch")
	var/obj/item/stack/tarred_oakum/oakum = locate() in H
	if (!oakum)
		oakum = locate() in locate(61, 8, 2)
	naval_check(oakum && oakum.amount == 3, "and makes three twists of tarred oakum")
	if (!oakum)
		oakum = new(locate(61, 8, 2))
	oakum.amount = 30
	// Refusals.
	var/obj/covers/plank = locate(/obj/covers) in locate(61, 9, 2)
	naval_check(findtext(hull_caulk_refusal(H, oakum, plank), "chisel"), "caulking needs a chisel or hammer in the other hand ([hull_caulk_refusal(H, oakum, plank)])")
	var/obj/item/weapon/chisel/iron = new(H)
	H.l_hand = oakum
	oakum.forceMove(H)
	H.r_hand = iron
	H.hand = 1
	naval_check(H.get_active_hand() == oakum && H.get_inactive_hand() == iron, "oakum in one hand, chisel in the other")
	naval_check(findtext(hull_caulk_refusal(H, oakum, plank), "lie still"), "she cannot be caulked under way")
	C.set_speed(VESSEL_SPEED_STOP)
	C.set_anchor(TRUE)
	L.water = 70
	naval_check(findtext(hull_caulk_refusal(H, oakum, plank), "bail"), "nor awash")
	L.water = 0
	naval_check(isnull(hull_caulk_refusal(H, oakum, plank)), "at anchor and dry she can be caulked")
	H.forceMove(locate(40, 50, 2))
	naval_check(findtext(hull_caulk_refusal(H, oakum, plank), "deck"), "but only from her own deck")
	H.forceMove(locate(61, 8, 2))
	// One twist does three of her thirty tiles; deep water stops at fair.
	naval_check(near(L.caulk_twist(), 0.1) && near(L.seams, 0.9), "one twist tightens three tiles of thirty ([L.seams])")
	for (var/i = 1, i <= 20, i++)
		L.caulk_twist()
	naval_check(near(L.seams, 1 / 3) && L.seams_told == 0, "afloat on deep water she comes back to sound and no better ([L.seams])")
	naval_check(findtext(hull_caulk_refusal(H, oakum, plank), "shallows"), "and her caulker is told to lay her in the shallows")
	// Saved with the tiller.
	L.seams = 0.8
	tiller.before_save()
	var/list/saved = json_decode(tiller.hull_state)
	naval_check(near(saved["ledger"]["seams"], 0.8), "the tiller saves her seams")
	L.seams = 0
	L.from_list(saved["ledger"])
	naval_check(near(L.seams, 0.8) && L.seams_told == 1, "and restores them")
	qdel(tiller)
	// In the shallows she is caulked right down.
	for (var/x = 58, x <= 66, x++)
		for (var/y = 44, y <= 58, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)
	var/obj/structure/hull_tiller/beached = bilge_hull(60, 46, 62, 55, "Hoy")
	var/datum/hull_ledger/B = beached.craft.ledger
	naval_check(!B.over_deep() && B.caulk_floor() == 0, "a hull lying in the shallows can be caulked right down")
	for (var/i = 1, i <= 10, i++)
		B.caulk_twist()
	naval_check(B.seams == 0 && B.seam_name() == "tight" && near(B.seep_rate(), 0.675), "tight, she seeps half as fast as fair ([B.seep_rate()])")
	H.forceMove(locate(61, 50, 2))
	naval_check(findtext(hull_caulk_refusal(H, oakum, locate(/obj/covers) in locate(61, 51, 2)), "seams are tight"), "and needs no more")
	qdel(beached)
	// Plated hulls and small craft have nothing to caulk.
	var/obj/structure/hull_tiller/plated = bilge_hull(60, 20, 62, 29, "Plate", TRUE)
	H.forceMove(locate(61, 22, 2))
	naval_check(findtext(hull_caulk_refusal(H, oakum, locate(/obj/covers) in locate(61, 23, 2)), "plating"), "a plated hull has no seams to caulk")
	plated.craft.set_anchor(FALSE)
	plated.craft.set_speed(VESSEL_SPEED_SLOW)
	plated.craft.ledger.step_ledger(7200)
	naval_check(near(plated.craft.ledger.seams, 1 / 3), "nor seams to wear")
	qdel(plated)

// Bilge pumps (naval/hull_pumps.dm): cellar pumps on her deck pump her bilge.
/proc/pump_checks()
	var/obj/structure/hull_tiller/tiller = bilge_hull(65, 5, 67, 14, "Pink")
	var/datum/hull_ledger/L = tiller.craft.ledger
	// Her seams are left out of the sums below.
	L.seep_tiles = 0
	naval_check(!length(L.pumps()) && L.pumps_text() == "", "a hull with no pump says nothing of pumps")
	var/obj/structure/cellar_pump/steam/ashore = new(locate(10, 10, 2))
	ashore.on = TRUE
	ashore.fuel = 10
	naval_check(!hull_ledger_at(get_turf(ashore)) && !length(L.pumps()), "a pump ashore is no bilge pump")
	// The steam pump.
	var/obj/structure/cellar_pump/steam/engine = new(locate(66, 7, 2))
	naval_check(hull_ledger_at(get_turf(engine)) == L && length(L.pumps()) == 1, "a pump on her deck is hers")
	L.water = 100
	L.step_ledger(60)
	naval_check(L.water == 100 && !engine.running, "cold, it lifts nothing")
	engine.fuel = 10
	engine.on = TRUE
	L.step_ledger(60)
	naval_check(near(L.water, 20) && engine.running && engine.fuel == 9, "fired, a steam pump lifts 80 bucketfuls a minute and burns a minute of fuel ([L.water])")
	naval_check(ashore.fuel == 10, "the pump ashore burned nothing")
	naval_check(findtext(L.pumps_text(), "1 pump stands on her deck, 1 of them working"), "the tiller counts her pumps ([L.pumps_text()])")
	engine.fuel = 0.5
	L.water = 100
	L.step_ledger(60)
	naval_check(!engine.on && !engine.running && engine.fuel == 0 && near(L.water, 20), "its fire burns out at the end of the step")
	L.step_ledger(60)
	naval_check(near(L.water, 20), "and then it lifts nothing")
	// A hole against a pump: 25 in, 80 out.
	engine.fuel = 60
	engine.on = TRUE
	L.holes = 2
	L.water = 60
	L.step_ledger(60)
	naval_check(near(L.water, 60 + 50 - 80), "one steam pump gets ahead of two holes ([L.water])")
	L.holes = 0
	engine.on = FALSE
	qdel(ashore)
	// The sump pump: a float switch and a battery.
	var/obj/structure/cellar_pump/sump/sump = new(locate(66, 9, 2))
	L.water = 0
	L.step_ledger(60)
	naval_check(!sump.running && sump.battery == 60, "on a dry bilge the float switch keeps the sump pump idle")
	L.water = 50
	L.step_ledger(60)
	naval_check(sump.running && sump.battery == 59 && near(L.water, 10), "with water in her it lifts 40 bucketfuls a minute on its battery ([L.water])")
	sump.on = FALSE
	L.water = 50
	L.step_ledger(60)
	naval_check(!sump.running && L.water == 50, "switched off it lifts nothing")
	sump.on = TRUE
	sump.battery = 0
	L.step_ledger(60)
	naval_check(!sump.running && L.water == 50, "nor with a flat battery and no power")
	// The lever pump is worked by hand.
	var/obj/structure/cellar_pump/lever/lever = new(locate(66, 11, 2))
	var/mob/living/human/naval_probe/H = new(locate(66, 12, 2))
	naval_check(length(L.pumps()) == 3 && isnull(lever.bilge_refusal(H, L)), "a hand beside the lever pump can pump her out")
	L.step_ledger(60)
	naval_check(L.water == 50, "left alone a lever pump lifts nothing")
	L.water = 0
	naval_check(findtext(lever.bilge_refusal(H, L), "dry"), "a dry bilge needs no pumping")
	L.water = 50
	H.forceMove(locate(66, 14, 2))
	naval_check(findtext(lever.bilge_refusal(H, L), "too far"), "nor can it be worked from afar")
	var/obj/structure/cellar_pump/lever/cellar = new(locate(12, 12, 2))
	naval_check(findtext(cellar.bilge_refusal(H, L), "too far") && !hull_ledger_at(get_turf(cellar)), "a lever pump ashore is a cellar pump still")
	qdel(cellar)
	qdel(lever)
	qdel(sump)
	qdel(engine)
	naval_check(!length(L.pumps()), "pumps taken off her are hers no longer")
	qdel(tiller)

// Load and ballast (naval/hull_load.dm).
/proc/load_checks()
	var/obj/structure/hull_tiller/tiller = bilge_hull(65, 20, 67, 29, "Hulk")
	var/datum/craft/C = tiller.craft
	var/datum/hull_ledger/L = C.ledger
	L.seep_tiles = 0
	naval_check(L.carries_load() && L.burden() == 15, "a boat of thirty tiles has a burden of fifteen")
	L.survey_load()
	naval_check(near(L.load, 0.5) && L.laden() == HULL_LADEN_LIGHT && L.load_weight() == 0 && C.mass() == 30, "with only her tiller aboard she is light ([L.load])")
	// Weights.
	var/obj/item/stack/material/stone/stone = new(locate(66, 22, 2))
	stone.amount = 50
	var/obj/structure/closet/crate/crate = new(locate(66, 23, 2))
	var/mob/living/human/naval_probe/H = new(locate(66, 24, 2))
	naval_check(near(stone.hull_load(), 1) && near(crate.hull_load(), 0.5) && near(H.hull_load(), 0.2), "fifty stone weigh a tile, a crate half and a hand a fifth")
	var/obj/covers/floor = locate(/obj/covers) in locate(66, 25, 2)
	naval_check(floor.hull_load() == 0, "her own floors weigh nothing more")
	L.survey_load()
	naval_check(near(L.load, 2.2), "the deck walk adds them up ([L.load])")
	// Deep laden: past her burden the weight is hull to push.
	stone.amount = 50 * 18
	L.survey_load()
	naval_check(near(L.load, 19.2) && L.laden() == HULL_LADEN_DEEP && L.laden_told == HULL_LADEN_DEEP, "past her burden she is deep laden and her crew is told ([L.load])")
	naval_check(L.load_weight() == 4 && C.mass() == 34, "four tiles over her burden are four more tiles to push ([C.mass()])")
	naval_check(findtext(tiller.status_text(), "deep laden"), "the tiller says so")
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(near(L.load, 19.2), "getting under way counts her load in the same walk as her drives ([L.load])")
	L.water = 0
	L.step_ledger(600)
	naval_check(L.water == 0, "deep laden she ships no water")
	// Overladen: past twice her burden the sea slops in, up to awash.
	stone.amount = 50 * 34
	C.fit_drives()
	naval_check(near(L.load, 35.2) && L.laden() == HULL_LADEN_OVER && L.laden_told == HULL_LADEN_OVER, "past twice her burden she is overladen ([L.load])")
	L.step_ledger(60)
	naval_check(near(L.water, 5.2), "under way an overladen hull ships a bucketful a minute for each tile over the mark ([L.water])")
	L.step_ledger(3600)
	naval_check(near(L.water, L.limit()), "and stops at awash ([L.water])")
	C.set_speed(VESSEL_SPEED_STOP)
	C.set_anchor(TRUE)
	L.water = 0
	L.step_ledger(600)
	naval_check(L.water == 0, "lying still she ships none")
	stone.amount = 50
	L.step_ledger(30)
	naval_check(L.laden() == HULL_LADEN_LIGHT && L.laden_told == HULL_LADEN_LIGHT, "lightened at anchor, the next step finds her light again")
	naval_check(!L.crank() && L.ballast_wanted() == 0, "a boat is never crank")
	qdel(stone)
	qdel(crate)
	qdel(tiller)
	// A ship with masts and too little weight low in her is crank.
	var/obj/structure/hull_tiller/ship_tiller = bilge_hull(30, 45, 34, 54, "Carrack")
	var/datum/craft/K = ship_tiller.craft
	var/datum/hull_ledger/R = K.ledger
	R.seep_tiles = 0
	var/obj/structure/vehicleparts/movement/sail/fore = new(locate(32, 47, 2))
	fore.sails = TRUE
	var/obj/structure/vehicleparts/movement/sail/main = new(locate(32, 51, 2))
	main.sails = TRUE
	K.set_anchor(FALSE)
	K.set_speed(VESSEL_SPEED_SLOW)
	naval_check(R.hull_class() == HULL_CLASS_SHIP && R.masts == 2 && near(R.ballast_wanted(), 5), "a ship of fifty tiles with two rigged masts wants five tiles of weight ([R.ballast_wanted()])")
	naval_check(near(R.load, 1.5) && R.crank() && R.under_sail(), "with only her masts and tiller aboard she is crank ([R.load])")
	naval_check(findtext(ship_tiller.status_text(), "crank"), "the tiller says so")
	var/wind_was = map.windspeedvar
	map.windspeedvar = 1
	R.step_ledger(60)
	naval_check(R.water == 0 && !R.crank_told, "in a light wind a crank ship sails dry")
	map.windspeedvar = 3
	R.step_ledger(60)
	naval_check(near(R.water, 10) && R.crank_told, "in a strong wind she heels and ships ten bucketfuls a minute, and her crew is told ([R.water])")
	var/obj/item/stack/material/stone/ballast = new(locate(32, 49, 2))
	ballast.amount = 200
	K.fit_drives()
	naval_check(near(R.load, 5.5) && !R.crank(), "two hundred stone ballast her ([R.load])")
	R.water = 0
	R.step_ledger(60)
	naval_check(R.water == 0 && !R.crank_told, "ballasted she stands up to the same wind")
	map.windspeedvar = wind_was
	qdel(ballast)
	qdel(ship_tiller)
	// A small craft carries what she likes.
	var/obj/structure/hull_tiller/skiff = bilge_hull(65, 32, 67, 35, "Wherry")
	var/datum/hull_ledger/S = skiff.craft.ledger
	var/obj/item/stack/material/stone/heap = new(locate(66, 33, 2))
	heap.amount = 5000
	S.survey_load()
	skiff.craft.fit_drives()
	naval_check(!S.carries_load() && S.load_weight() == 0 && skiff.craft.mass() == 12 && S.load_text() == "", "load is not counted on a small craft")
	qdel(heap)
	qdel(skiff)

// Anchors, mooring and drift (naval/hull_anchors.dm).
/proc/anchor_checks()
	var/wind_was = map.windspeedvar
	var/from_was = map.winddirection
	map.windspeedvar = 2
	map.winddirection = "West"
	var/obj/structure/hull_tiller/tiller = bilge_hull(40, 45, 42, 54, "Dhow")
	var/datum/craft/C = tiller.craft
	var/datum/hull_ledger/L = C.ledger
	var/turf/start = C.body.origin()
	naval_check(L.needs_anchor() && !L.old_anchor && L.holding() == 0 && C.anchored, "a new boat has no anchor, though her helm says anchor down")
	naval_check(!L.held() && findtext(L.hold_text(), "nothing to hold her"), "so nothing holds her ([L.hold_text()])")
	naval_check(L.drift_dir() == EAST, "a wind of 2 from the west would set her east")
	naval_check(!L.step_drift() && C.body.origin() == start, "with nobody aboard she stays where she was left")
	L.crewed = TRUE
	naval_check(L.step_drift() && C.body.origin():x == start.x + 1 && L.drift_told, "with someone aboard she drifts a tile downwind and her crew is told")
	map.windspeedvar = 1
	naval_check(!L.drift_dir() && !L.step_drift(), "in a light wind with no current she lies quiet")
	map.windspeedvar = 2
	// A killick holds forty tiles.
	var/turf/O = C.body.origin()
	var/obj/structure/hull_anchor/stone/killick = new(locate(O.x + 1, O.y + 2, 2))
	naval_check(L.holding() == 40 && L.held() && findtext(L.hold_text(), "lies to her anchor"), "a killick on her deck holds her ([L.holding()], [L.hold_text()])")
	naval_check(!L.step_drift() && !L.drift_told, "held, she does not drift")
	C.set_anchor(FALSE)
	naval_check(!L.held() && L.step_drift(), "with her anchor up and no way on she drifts again")
	C.set_anchor(TRUE)
	naval_check(L.held(), "called down again it holds")
	qdel(killick)
	naval_check(!L.held(), "her anchor gone, nothing holds her")
	// A bollard within two tiles is a mooring.
	O = C.body.origin()
	var/obj/structure/bollard/post = new(locate(O.x + 4, O.y + 3, 2))
	naval_check(L.mooring() == post && L.held() && findtext(L.hold_text(), "made fast"), "a bollard two tiles off her side is a mooring ([L.hold_text()])")
	post.forceMove(locate(O.x + 5, O.y + 3, 2))
	naval_check(!L.mooring() && !L.held(), "three tiles off it is out of reach")
	qdel(post)
	// Saved: a new hull has no old anchor, a record from before has one.
	var/list/fresh = L.to_list()
	naval_check(fresh["old_anchor"] == 0, "a new hull is saved without an old anchor")
	L.from_list(list("water" = 0))
	naval_check(L.old_anchor && L.holding() == 30 && L.held(), "a record from before anchors keeps the anchor she always had")
	L.from_list(fresh)
	naval_check(!L.old_anchor && !L.held(), "and a new record does not")
	qdel(tiller)
	// A ship wants more than a killick.
	var/obj/structure/hull_tiller/big = bilge_hull(22, 12, 26, 21, "Nao")
	var/datum/hull_ledger/B = big.craft.ledger
	var/obj/structure/hull_anchor/stone/small = new(locate(24, 14, 2))
	naval_check(B.holding() == 40 && !B.held(), "one killick will not hold fifty tiles ([B.holding()], [B.tiles], [B.held()])")
	var/obj/structure/hull_anchor/bower = new(locate(24, 16, 2))
	naval_check(B.holding() == 140 && B.held() && near(bower.hull_load(), 1) && near(small.hull_load(), 0.4), "an iron anchor will, and anchors weigh on her")
	qdel(small)
	qdel(bower)
	qdel(big)
	// A small craft needs none.
	var/obj/structure/hull_tiller/skiff = bilge_hull(22, 25, 24, 28, "Cock")
	var/datum/hull_ledger/S = skiff.craft.ledger
	S.crewed = TRUE
	naval_check(!S.needs_anchor() && S.held() && !S.step_drift(), "a small craft needs no anchor and does not drift")
	qdel(skiff)
	map.windspeedvar = wind_was
	map.winddirection = from_was

// Rigging and sail handling (naval/hull_rigging.dm).
/proc/rigging_checks()
	var/wind_was = map.windspeedvar
	var/from_was = map.winddirection
	map.windspeedvar = 1
	map.winddirection = "West"
	var/obj/structure/hull_tiller/tiller = bilge_hull(46, 46, 48, 55, "Brig")
	var/datum/craft/C = tiller.craft
	var/datum/hull_ledger/L = C.ledger
	L.seep_tiles = 0
	var/obj/structure/vehicleparts/movement/sail/fore = new(locate(47, 48, 2))
	fore.sails = TRUE
	var/obj/structure/vehicleparts/movement/sail/main = new(locate(47, 52, 2))
	main.sails = TRUE
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	var/full_push = C.thrust()
	naval_check(fore.canvas == SAIL_FULL && !fore.torn && full_push > 0 && L.rigging_text() == "", "a mast starts with full sail and the tiller says nothing new (push [full_push])")
	naval_check(fore.handled_here() && fore.canvas_name() == "set full", "a rigged mast on her deck can be handled")
	// Reefed and furled.
	fore.set_canvas(SAIL_REEFED)
	naval_check(C.thrust() == round(full_push / 2) + round(full_push / 2 * 0.6), "a reefed sail pushes six tenths ([C.thrust()] of [full_push])")
	fore.set_canvas(SAIL_FURLED)
	naval_check(C.thrust() == round(full_push / 2) && L.masts == 1, "a furled sail pushes nothing and is no rigged mast to ballast ([C.thrust()])")
	naval_check(findtext(L.rigging_text(), "1 set full") && findtext(L.rigging_text(), "1 furled"), "the tiller says how her sails are carried ([L.rigging_text()])")
	main.set_canvas(SAIL_FURLED)
	naval_check(C.thrust() == 0 && !L.under_sail(), "all furled, no sail drives her")
	// The tearing table.
	naval_check(!sail_tear_chance(SAIL_FULL, 2) && sail_tear_chance(SAIL_FULL, 3) == 15 && !sail_tear_chance(SAIL_REEFED, 3) && sail_tear_chance(SAIL_REEFED, 4) == 5 && !sail_tear_chance(SAIL_FURLED, 4), "full sail tears from wind 3, reefed only in a gale, furled never")
	// Furled in a gale: safe.
	map.windspeedvar = 4
	var/torn_count = 0
	for (var/i = 1, i <= 100, i++)
		torn_count += L.step_rigging(30)
	naval_check(!torn_count && !fore.torn && !main.torn && !L.gale_told, "a hundred half minutes of gale tear no furled sail")
	// Reefed in a strong wind: safe.
	map.windspeedvar = 3
	fore.set_canvas(SAIL_REEFED)
	main.set_canvas(SAIL_REEFED)
	for (var/i = 1, i <= 100, i++)
		torn_count += L.step_rigging(30)
	naval_check(!torn_count && !L.gale_told, "nor does a strong wind tear a reefed one")
	// Full in a strong wind: sooner or later.
	main.set_canvas(SAIL_FULL)
	var/before = C.thrust()
	for (var/i = 1, i <= 200 && !main.torn, i++)
		torn_count += L.step_rigging(30)
	naval_check(main.torn && torn_count == 1 && !fore.torn && L.gale_told, "a full sail in a strong wind tears, and her crew was warned")
	naval_check(C.thrust() < before && findtext(L.rigging_text(), "1 torn"), "torn, it pushes little ([C.thrust()] of [before])")
	naval_check(!L.step_rigging(30) || fore.torn, "a torn sail does not tear twice")
	main.mend_sail()
	naval_check(!main.torn && C.thrust() == before, "mended, it pushes as before")
	// At anchor nothing tears.
	C.set_speed(VESSEL_SPEED_STOP)
	C.set_anchor(TRUE)
	fore.set_canvas(SAIL_FULL)
	torn_count = 0
	for (var/i = 1, i <= 100, i++)
		torn_count += L.step_rigging(30)
	naval_check(!torn_count, "at anchor the wind tears nothing")
	map.windspeedvar = wind_was
	map.winddirection = from_was
	qdel(tiller)

// Stations and the watch (hull_watch.dm).
/proc/watch_checks()
	var/obj/structure/hull_tiller/tiller = bilge_hull(52, 5, 54, 14, "Snow")
	var/datum/craft/C = tiller.craft
	var/datum/hull_ledger/L = C.ledger
	L.seep_tiles = 0
	naval_check(L.keeps_lookout() && L.helm() == tiller && L.bow_line() == 14, "a boat keeps a lookout, and her bow is her foremost row ([L.bow_line()])")
	naval_check(L.in_bow(locate(53, 14, 2)) && L.in_bow(locate(52, 13, 2)) && !L.in_bow(locate(53, 12, 2)) && !L.in_bow(locate(53, 15, 2)), "her bow is her two foremost rows and nothing off her deck")
	var/mob/living/human/naval_probe/helmsman = new(locate(53, 5, 2))
	helmsman.name = "Helm Hand"
	var/mob/living/human/naval_probe/hand = new(locate(53, 9, 2))
	hand.name = "Deck Hand"
	var/obj/structure/vehicleparts/movement/sail/mast = new(locate(53, 11, 2))
	naval_check(!L.lookout(), "nobody in the bow is no lookout")
	var/muster = L.muster_text()
	naval_check(findtext(muster, "2 aboard") && findtext(muster, "Helm Hand: at the helm") && findtext(muster, "Deck Hand: on deck") && findtext(muster, "Nobody keeps a lookout"), "the muster names the helm and the idle hand and misses a lookout ([muster])")
	hand.forceMove(locate(53, 10, 2))
	naval_check(findtext(L.muster_text(), "Deck Hand: at a mast"), "beside a mast is at a mast")
	hand.forceMove(locate(53, 14, 2))
	muster = L.muster_text()
	naval_check(L.lookout() == hand && findtext(muster, "Deck Hand: in the bow, keeping the lookout") && !findtext(muster, "Nobody keeps"), "on their feet in the bow they keep the lookout")
	// Clear water: nothing to call.
	naval_check(isnull(L.sight_ahead()) && !L.step_watch(), "clear water ahead and at anchor: nothing is called")
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(!L.step_watch() && !L.sighted, "under way over clear water nothing is called")
	// Something on her course.
	hull_lay(53, 22)
	var/list/seen = L.sight_ahead()
	naval_check(seen && seen[1] == 8 && seen[2] == "a built floor in the way", "a floor eight tiles off her bow is seen, without coordinates ([seen ? "[seen[1]] [seen[2]]" : "nothing"])")
	naval_check(L.step_watch() && L.sighted == 8, "the lookout calls it once")
	naval_check(!L.step_watch(), "and does not call it again while it is far")
	hull_lay(53, 18)
	naval_check(L.step_watch() && L.sighted == 4, "close aboard it is called again")
	naval_check(!L.step_watch(), "and then no more")
	// No lookout, no call.
	hand.forceMove(locate(53, 9, 2))
	naval_check(!L.step_watch() && !L.sighted, "with nobody in the bow nothing is called")
	hand.forceMove(locate(53, 14, 2))
	hand.lying = TRUE
	naval_check(!L.lookout() && findtext(L.muster_text(), "Deck Hand: laid out"), "a hand lying down keeps no lookout")
	hand.lying = FALSE
	// The helm keeps none either, and a small craft has none.
	helmsman.forceMove(locate(52, 14, 2))
	hand.forceMove(locate(53, 9, 2))
	naval_check(L.lookout() == helmsman, "anyone on their feet in the bow will do")
	C.set_speed(VESSEL_SPEED_STOP)
	C.set_anchor(TRUE)
	naval_check(!L.step_watch(), "at anchor nothing is called")
	var/obj/structure/hull_tiller/skiff = bilge_hull(56, 5, 58, 8, "Gig")
	var/datum/hull_ledger/S = skiff.craft.ledger
	var/mob/living/human/naval_probe/rower = new(locate(57, 8, 2))
	rower.name = "Gig Hand"
	naval_check(!S.keeps_lookout() && !S.lookout() && findtext(S.muster_text(), "Gig Hand: on deck") && !findtext(S.muster_text(), "Nobody keeps"), "a small craft musters her hands and keeps no lookout")
	mast.sails = FALSE

// Fouling, scraping and copper (hull_fouling.dm).
/proc/fouling_checks()
	var/obj/structure/hull_tiller/tiller = bilge_hull(52, 45, 54, 54, "Bark")
	var/datum/craft/C = tiller.craft
	var/datum/hull_ledger/L = C.ledger
	naval_check(L.fouls() && L.fouling == 0 && L.fouling_name() == "clean" && L.foul_weight() == 0, "a boat starts with a clean bottom that drags nothing")
	var/mass_was = C.mass()
	naval_check(findtext(L.status_text(), "Her bottom is clean."), "the tiller says so ([L.fouling_text()])")
	// A day of use fouls her.
	L.step_fouling(4320)
	naval_check(L.fouling_name() == "clean" && L.foul_weight() == 0 && C.mass() == mass_was, "an hour or so leaves her clean and no slower")
	L.step_fouling(4320)
	naval_check(near(L.fouling, 0.1) && L.fouling_name() == "slimed", "a tenth of the way she is slimed ([L.fouling])")
	L.step_fouling(34560)
	naval_check(near(L.fouling, 0.5) && L.fouling_name() == "weedy" && L.foul_weight() == 6 && L.fouling_told == 1, "half way she is weedy and drags like six tiles of her thirty ([L.foul_weight()])")
	naval_check(C.mass() == mass_was + 6, "her drives push that much more ([C.mass()] from [mass_was])")
	L.step_fouling(86400)
	naval_check(L.fouling == 1 && L.fouling_name() == "foul" && L.foul_weight() == 12 && L.fouling_told == 2, "after a day she is foul and drags four tenths of her tiles")
	naval_check(findtext(L.status_text(), "Her bottom is foul, dragging like 12 more tiles of hull"), "the tiller says so ([L.fouling_text()])")
	// Saved and loaded.
	var/list/saved = L.to_list()
	naval_check(saved["fouling"] == 1 && saved["coppered"] == 0, "her bottom is saved")
	// Out of reach on deep water.
	var/mob/living/human/naval_probe/H = new(locate(53, 50, 2))
	var/obj/covers/plank = locate(/obj/covers) in locate(53, 51, 2)
	naval_check(findtext(hull_bottom_refusal(H, plank), "shallows"), "on deep water her bottom is out of reach ([hull_bottom_refusal(H, plank)])")
	// Laid in the shallows.
	for (var/x = 51, x <= 55, x++)
		for (var/y = 44, y <= 55, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)
	naval_check(!L.over_deep() && isnull(hull_bottom_refusal(H, plank)), "in the shallows she can be scraped ([hull_bottom_refusal(H, plank)])")
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(findtext(hull_bottom_refusal(H, plank), "lie still"), "but not under way")
	C.set_speed(VESSEL_SPEED_STOP)
	C.set_anchor(TRUE)
	naval_check(near(L.scrape_go(), 0.1) && near(L.fouling, 0.9), "one go scrapes three tiles of thirty")
	naval_check(findtext(hull_sheathe_refusal(H, plank), "scrape her bottom clean"), "copper wants a clean bottom")
	for (var/i = 1, i <= 9, i++)
		L.scrape_go()
	naval_check(L.fouling == 0 && L.fouling_told == 0 && C.mass() == mass_was, "ten goes clean her and her drag is gone")
	// Copper.
	naval_check(findtext(hull_sheathe_refusal(H, plank), "hammer"), "sheathing wants a hammer in the other hand ([hull_sheathe_refusal(H, plank)])")
	L.seep_tiles = 0
	naval_check(!L.takes_copper(), "a plated hull takes no copper")
	L.seep_tiles = 30
	naval_check(L.takes_copper() && L.copper_wanted() == 15, "a wooden boat of thirty tiles wants fifteen sheets ([L.copper_wanted()])")
	L.copper_sheet()
	naval_check(near(L.coppered, 2 / 30) && L.copper_wanted() == 14, "one sheet covers two tiles")
	for (var/i = 1, i <= 14, i++)
		L.copper_sheet()
	naval_check(L.coppered == 1 && L.copper_wanted() == 0 && findtext(L.fouling_text(), "sheathed in copper"), "fifteen sheathe her from stem to stern ([L.fouling_text()])")
	L.step_fouling(86400)
	naval_check(near(L.fouling, 0.1), "coppered, a day fouls her a tenth as much ([L.fouling])")
	// Loaded back.
	var/datum/hull_ledger/N = new
	N.craft = C
	N.tiles = 30
	N.from_list(list("water" = 0, "fouling" = 0.8, "coppered" = 0.5))
	naval_check(near(N.fouling, 0.8) && near(N.coppered, 0.5) && N.fouling_told == 2, "a saved bottom loads as it was, and is not told again")
	N.craft = null
	qdel(N)
	// Grounded she grows nothing, and a small craft never fouls.
	L.fouling = 0
	L.grounded = TRUE
	L.step_fouling(86400)
	naval_check(L.fouling == 0, "sat on the bottom she grows nothing")
	L.grounded = FALSE
	var/obj/structure/hull_tiller/skiff = bilge_hull(56, 12, 58, 15, "Yawl")
	var/datum/hull_ledger/S = skiff.craft.ledger
	S.step_fouling(86400)
	naval_check(!S.fouls() && S.fouling == 0 && S.fouling_text() == "" && !S.foul_weight(), "a small craft never fouls")

// The film of water over an awash deck (hull_awash.dm).
/proc/awash_checks()
	var/obj/structure/hull_tiller/tiller = bilge_hull(56, 18, 58, 27, "Ketch")
	var/datum/hull_ledger/L = tiller.craft.ledger
	L.seep_tiles = 0
	var/obj/covers/plank = locate(/obj/covers) in locate(57, 20, 2)
	var/bare = plank.overlays.len
	naval_check(!L.deck_awash() && !L.awash_planks.len && !L.show_awash(), "a dry deck shows no water")
	L.add_water(L.limit() * 0.4)
	naval_check(L.depth() < HULL_DEPTH_AWASH && !L.awash_planks.len && plank.overlays.len == bare, "nor one knee deep ([L.depth()])")
	L.add_water(L.limit())
	naval_check(L.depth() >= HULL_DEPTH_AWASH && L.awash_planks.len == 30 && plank.overlays.len == bare + 1, "awash, water is drawn over every one of her thirty planks ([L.awash_planks.len])")
	L.step_ledger(30)
	naval_check(L.awash_planks.len == 30 && plank.overlays.len == bare + 1, "a step lays it again and never twice ([plank.overlays.len - bare])")
	L.remove_water(L.limit() * 0.7)
	naval_check(L.depth() < HULL_DEPTH_AWASH && !L.awash_planks.len && plank.overlays.len == bare, "bailed below awash, it is gone")
	L.add_water(L.limit())
	qdel(L)
	naval_check(plank.overlays.len == bare, "and it goes with her ledger")

// Watertight compartments (hull_compartments.dm): a steel ship of 4 x 16
// tiles parted by two lines of bulkheads, each with a watertight door.
/proc/compartment_checks()
	for (var/x = 40, x <= 43, x++)
		for (var/y = 18, y <= 33, y++)
			steel_lay(x, y)
	for (var/y in list(23, 28))
		for (var/x = 40, x <= 43, x++)
			if (x == 42)
				new /obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight(locate(x, y, 2))
			else
				new /obj/structure/hull_bulkhead(locate(x, y, 2))
	var/obj/structure/hull_tiller/tiller = new(locate(40, 18, 2))
	naval_check(isnull(tiller.commission("Liner", NORTH)) && tiller.craft, "a ship with bulkheads is commissioned")
	var/datum/hull_ledger/L = tiller.craft.ledger
	naval_check(L.tiles == 64 && L.seep_tiles == 0, "she is 64 tiles of steel")
	naval_check(L.bays_split() && L.bay_water.len == 3, "two lines of bulkheads part her into three compartments ([L.bay_water.len])")
	var/sizes = 0
	for (var/n in L.bay_size)
		sizes += n
	naval_check(sizes == 64, "every tile of her is in one of them")
	var/turf/aft = locate(41, 20, 2)
	var/turf/mid = locate(41, 25, 2)
	var/turf/fore = locate(41, 31, 2)
	var/aft_bay = L.bay_at(aft)
	var/mid_bay = L.bay_at(mid)
	var/fore_bay = L.bay_at(fore)
	naval_check(aft_bay && mid_bay && fore_bay && aft_bay != mid_bay && mid_bay != fore_bay && aft_bay != fore_bay, "aft, amidships and forward lie in different compartments")
	naval_check(L.bay_at(locate(42, 23, 2)) == mid_bay && L.bay_size[aft_bay] == 20 && L.bay_size[mid_bay] == 20 && L.bay_size[fore_bay] == 24, "a bulkhead's own tile holds water with the compartment beside it")
	naval_check(L.bay_name(fore_bay) == "forward compartment" && L.bay_name(aft_bay) == "after compartment", "they are named from her bow")
	// A hole aft floods the after compartment only, to its brim.
	qdel(locate(/obj/covers/steelplating) in aft)
	naval_check(L.holes == 1 && L.hole_at(aft), "a plate shot away aft is a hole")
	L.crewed = TRUE
	L.step_ledger(600)
	naval_check(near(L.bay_water[aft_bay], 80) && L.bay_water[mid_bay] == 0 && L.bay_water[fore_bay] == 0 && near(L.water, 80), "ten minutes on, the after compartment is full and the others are dry ([json_encode(L.bay_water)])")
	naval_check(L.flooded_tiles() == 20 && !L.founders() && !L.sink_left && !L.grounded, "with a quarter of her flooded she floats on")
	naval_check(L.bays_told["[L.bay_first[aft_bay]]"], "her crew was told the after compartment flooded")
	var/status = L.status_text()
	naval_check(findtext(status, "into 3 compartments") && findtext(status, "after compartment <b>flooded</b>") && findtext(status, "forward compartment dry"), "the tiller reads each compartment ([status])")
	// Pumping and bailing take from the compartment they are in.
	naval_check(L.remove_water(2, mid) == 0, "a pump amidships lifts nothing: its compartment is dry")
	naval_check(L.remove_water(2, locate(40, 21, 2)) == 2 && near(L.bay_water[aft_bay], 78) && near(L.water, 78), "a bailer aft lifts the after compartment's water")
	naval_check(L.water_at(aft) == L.bay_water[aft_bay] && L.water_at(fore) == 0, "the water where each stands is its compartment's")
	// Opening the door between them lets the water even out.
	var/obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight/D = locate() in locate(42, 23, 2)
	L.bays_split()
	D.door_closed()
	naval_check(L.bays_dirty, "a watertight door that moves has her compartments walked again")
	D.state = TRUE
	D.density = FALSE
	naval_check(L.bays_split() && L.bay_water.len == 2 && near(L.water, 78) && L.bay_at(aft) == L.bay_at(mid) && near(L.water_at(mid), 78), "open, the door joins two compartments and keeps their water ([json_encode(L.bay_water)])")
	D.state = FALSE
	D.density = TRUE
	hull_compartments_changed(get_turf(D))
	naval_check(L.bays_split() && L.bay_water.len == 3, "shut, it parts them again")
	aft_bay = L.bay_at(aft)
	mid_bay = L.bay_at(mid)
	naval_check(near(L.bay_water[aft_bay], 39) && near(L.bay_water[mid_bay], 39) && near(L.water, 78), "the water that ran through stays on both sides ([json_encode(L.bay_water)])")
	// Saved and read back.
	var/list/saved = L.to_list()
	naval_check(islist(saved["bays"]) && length(saved["bays"]) == 3, "her record keeps each compartment's water")
	L.water = 0
	L.bays_sync()
	L.from_list(saved)
	naval_check(L.bays_split() && near(L.bay_water[L.bay_at(aft)], 39) && near(L.bay_water[L.bay_at(mid)], 39) && L.bay_water[L.bay_at(fore)] == 0 && near(L.water, 78), "read back, each compartment has its own water again ([json_encode(L.bay_water)])")
	// A shut door holds: the open hole fills the after compartment and only it.
	L.step_ledger(600)
	naval_check(near(L.bay_water[L.bay_at(aft)], 80) && near(L.bay_water[L.bay_at(mid)], 39), "the shut door holds the sea aft")
	// A second hole amidships floods more than half of her: she founders.
	qdel(locate(/obj/covers/steelplating) in mid)
	L.step_ledger(600)
	naval_check(L.flooded_tiles() == 40 && L.founders() && L.sink_left == HULL_SINK_WARNINGS, "two compartments flooded, 40 of her 64 tiles, and she founders ([L.flooded_tiles()])")
	naval_check(L.water < L.capacity() * 0.98, "though she is far from full ([L.water] of [L.capacity()])")
	L.remove_water(10, mid)
	naval_check(!L.sink_tick() && L.sink_left == 0, "pumping the second compartment below its brim stops the count")
	// Hauled out dry: the compartments follow the bilge.
	L.water = 0
	L.bays_sync()
	var/dry = 0
	for (var/w in L.bay_water)
		dry += w
	naval_check(dry == 0, "a bilge emptied outright empties every compartment")
	L.crewed = FALSE
	tiller.craft.set_speed(VESSEL_SPEED_STOP)

// The source tile order survives a turn but is no longer fresh survey order.
/proc/compartment_crossing_checks()
	var/obj/structure/hull_tiller/tiller = bilge_hull(25, 53, 27, 57, "Bay crossing", TRUE)
	var/datum/craft_body/built/body = tiller.body()
	var/datum/hull_ledger/L = tiller.craft.ledger
	new /obj/structure/hull_bulkhead(locate(25, 55, 2))
	new /obj/structure/hull_bulkhead(locate(27, 55, 2))
	new /obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight(locate(26, 55, 2))
	var/one_index = L.bay_cell_index(locate(25, 54, 2))
	var/two_index = L.bay_cell_index(locate(27, 57, 2))
	var/door_index = L.bay_cell_index(locate(26, 55, 2))
	naval_check(L.bays_split() && L.bay_water.len == 2, "crossing fixture has two compartments")
	naval_check(body.turn_to(WEST), "crossing fixture turns before packing")
	var/list/one = body.offsets[one_index]
	var/list/two = body.offsets[two_index]
	var/list/door = body.offsets[door_index]
	var/list/dry_packed = sea_crossing_pack(tiller)
	var/list/dry_record = islist(dry_packed) ? dry_packed["record"] : null
	naval_check(dry_record && sea_crossing_record_ok(json_decode(json_encode(dry_record))), "dry split hull packs, crosses the wire and passes validation")
	L.add_water(2.5, L.capacity(), locate(body.px + one[1], body.py + one[2], body.z))
	var/turf/two_at = locate(body.px + two[1], body.py + two[2], body.z)
	var/full_side = L.bay_capacity(L.bay_at(two_at))
	var/second_volume = full_side - 0.75
	L.add_water(second_volume, L.capacity(), two_at)
	var/list/packed = sea_crossing_pack(tiller)
	var/list/R = islist(packed) ? json_decode(json_encode(packed["record"])) : null
	naval_check(R && sea_crossing_record_ok(R), "wet split hull passes crossing validation after JSON")
	if (!R)
		return
	var/list/wire_ledger = R["ledger"]
	var/list/bays = wire_ledger["bays"]
	if (!islist(bays) || bays.len != 2)
		naval_check(FALSE, "wire ledger has both bays")
		return
	var/list/legacy = R.Copy()
	var/list/scalars = wire_ledger.Copy()
	scalars -= "bays"
	scalars -= "bay_order_heading"
	legacy["ledger"] = scalars
	naval_check(sea_crossing_record_ok(legacy), "legacy scalar crossing ledger is still accepted")
	var/list/bad = R.Copy()
	var/list/bad_ledger = scalars.Copy()
	bad["ledger"] = bad_ledger
	bad_ledger["bays"] = list(0, 0)
	naval_check(!sea_crossing_record_ok(bad), "positional bay array is refused")
	bad_ledger["bays"] = list("1" = 0, "01" = 0)
	naval_check(!sea_crossing_record_ok(bad), "noncanonical bay index is refused")
	bad_ledger["bays"] = list("1" = 0, "16" = 0)
	naval_check(!sea_crossing_record_ok(bad), "bay index beyond the fifteen tiles is refused")
	bad_ledger["bays"] = list("1" = 0, "2" = -1)
	naval_check(!sea_crossing_record_ok(bad), "negative bay water is refused")
	bad_ledger["bays"] = list("1" = 0, "2" = L.capacity() + 1)
	naval_check(!sea_crossing_record_ok(bad), "bay water beyond the hull capacity is refused")
	bad_ledger["bays"] = list("1" = 0, "2" = list("water" = 1))
	naval_check(!sea_crossing_record_ok(bad), "nested bay water is refused")
	bad_ledger["bays"] = bays
	bad_ledger["bay_order_heading"] = NORTHEAST
	naval_check(!sea_crossing_record_ok(bad), "invalid bay order heading is refused")
	bad_ledger -= "bays"
	bad_ledger -= "bay_order_heading"
	bad_ledger["water"] = list("1" = 0, "2" = 0)
	naval_check(!sea_crossing_record_ok(bad), "other ledger fields must still be scalar")
	var/turf/arrival = locate(39, 57, 2)
	var/obj/structure/hull_tiller/rebuilt = sea_crossing_build(R, arrival)
	naval_check(rebuilt && rebuilt.craft && rebuilt.craft.ledger, "the divided hull is rebuilt at an anchorage")
	if (!rebuilt || !rebuilt.craft || !rebuilt.craft.ledger)
		return
	var/list/survey = built_hull_survey(arrival, rebuilt.craft)
	var/differs = FALSE
	var/list/tiles = R["tiles"]
	for (var/i = 1, i <= tiles.len, i++)
		var/list/tile = tiles[i]
		if (survey[i] != locate(arrival.x + tile[1], arrival.y + tile[2], arrival.z))
			differs = TRUE
			break
	naval_check(differs, "the new survey really does give different indices")
	var/datum/hull_ledger/arrived = rebuilt.craft.ledger
	var/obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight/rebuilt_door = locate() in locate(arrival.x + door[1], arrival.y + door[2], arrival.z)
	naval_check(rebuilt_door && !rebuilt_door.state && rebuilt_door.density && arrived.bays_split(), "the shut door still divides the hull after crossing")
	var/first_water = arrived.water_at(locate(arrival.x + one[1], arrival.y + one[2], arrival.z))
	var/second_water = arrived.water_at(locate(arrival.x + two[1], arrival.y + two[2], arrival.z))
	naval_check(near(first_water, 2.5) && near(second_water, second_volume) && near(arrived.water, 2.5 + second_volume), "unequal water crosses in the same physical compartments ([first_water], [second_water], total [arrived.water])")
	naval_check(near(arrived.bay_capacity(arrived.bay_at(locate(arrival.x + two[1], arrival.y + two[2], arrival.z))), full_side), "turning does not shift a divider tile to the other bay or shrink its brim")
	sea_crossing_strip(rebuilt)
	qdel(rebuilt)
	sea_crossing_strip(tiller)
	qdel(tiller)

// A floor lifted from her edge to clear an obstacle (player report: a plank
// hull that would not pass a trench after a corner plank was taken up). The
// hole stays part of her shape until a refit cuts it away, and the refusal says
// so; a hole inside her outline must still be patched first.
/proc/edge_hole_checks()
	var/obj/structure/hull_tiller/tiller = bilge_hull(30, 20, 33, 24, "Scow")
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C.body
	var/datum/hull_ledger/L = C.ledger
	var/turf/trench = locate(34, 24, 2)
	trench.ChangeTurf(/turf/floor/trench)
	var/turf/O = B.origin()
	naval_check(!B.can_move_to(O.x + 1, O.y, NORTH) && findtext(B.last_refusal, "trench") && !findtext(B.last_refusal, "lifted"), "a trench off her corner stops a step east ([B.last_refusal])")
	var/turf/corner = locate(33, 24, 2)
	qdel(locate(/obj/covers) in corner)
	naval_check(L.holes == 1 && L.edge_hole_at(corner) && L.inner_holes() == 0, "the corner plank taken up is a hole on her edge")
	naval_check(!B.can_move_to(O.x + 1, O.y, NORTH) && findtext(B.last_refusal, "trench") && findtext(B.last_refusal, "floor lifted at 33,24") && findtext(B.last_refusal, "refit"), "until she is refitted the hole is still hers, and the refusal says so ([B.last_refusal])")
	var/turf/inner = locate(31, 22, 2)
	qdel(locate(/obj/covers) in inner)
	naval_check(L.holes == 2 && !L.edge_hole_at(inner) && L.inner_holes() == 1, "a plank taken up inside her is a hole in her bottom")
	naval_check(findtext(tiller.commission(), "Patch the hole"), "a hole inside her outline must be patched before a refit")
	hull_lay(31, 22)
	L.survey()
	var/why = tiller.commission()
	naval_check(isnull(why) && B.tile_count() == 19 && L.holes == 0 && !B.contains(corner), "a refit cuts the lifted corner away ([why])")
	O = B.origin()
	naval_check(B.can_move_to(O.x + 1, O.y, NORTH), "and she can now step east past the trench ([B.last_refusal])")
	tiller.decommission()
	qdel(tiller)

// A canal of flooded trench dug in from the sea (canals.dm), with ground one
// step higher from x 18 inland.
/datum/terrain_heights/bilge_canal/at(x, y, z)
	return x <= 18 ? 1 : 0

// Built hulls sail flooded-trench canals and keep to their levels: every tile
// of her keeps the rule a boat keeps, and a pound lock lets a tile through only
// at the level of the water it opens to.
/proc/canal_hull_checks()
	map.terrain_height_file = "probe"
	map.terrain_heights_cache = new /datum/terrain_heights/bilge_canal
	for (var/x = 17, x <= 20, x++)
		var/turf/T = locate(x, 40, 2)
		T.ChangeTurf(/turf/floor/trench/flooded)
	var/obj/structure/hull_tiller/tiller = bilge_hull(22, 40, 23, 40, "Barge")
	var/datum/craft_body/built/B = tiller.craft.body
	var/turf/O = B.origin()
	naval_check(B.can_move_to(O.x - 2, O.y, B.dir) && B.move_to(O.x - 2, O.y, B.dir), "she sails off the sea into a flooded trench ([B.last_refusal])")
	O = B.origin()
	naval_check(O.x == 20 && B.can_move_to(O.x - 1, O.y, B.dir) && B.move_to(O.x - 1, O.y, B.dir), "and along the level canal ([B.last_refusal])")
	O = B.origin()
	naval_check(!B.can_move_to(O.x - 1, O.y, B.dir) && findtext(B.last_refusal, "step in the canal at 18,40"), "no tile of hers climbs a step in the canal ([B.last_refusal])")
	var/obj/structure/canal_lock/K = new(locate(18, 40, 2))
	naval_check(!K.high && K.chamber_level == 0 && B.can_move_to(O.x - 1, O.y, B.dir), "a lock standing low lets her bow into it ([B.last_refusal])")
	K.set_high(TRUE)
	naval_check(!B.can_move_to(O.x - 1, O.y, B.dir) && findtext(B.last_refusal, "step in the canal"), "a lock standing high does not")
	var/turf/hole = locate(19, 40, 2)
	qdel(locate(/obj/covers) in hole)
	var/obj/item/stack/material/wood/timber = new(locate(20, 40, 2))
	timber.amount = 5
	naval_check(tiller.craft.ledger.hole_at(hole) && istype(hull_patch_lay(tiller.craft, timber, hole), /obj/covers/repairedfloor/ship/patch) && !tiller.craft.ledger.hole_at(hole), "a hole over the canal is patched like one over the sea")
	tiller.decommission()
	qdel(tiller)
	qdel(K)
	map.terrain_height_file = null
	map.terrain_heights_cache = null

/proc/naval_run()
	try
		naval_checks()
		small_craft_checks()
		caulking_checks()
		pump_checks()
		load_checks()
		anchor_checks()
		rigging_checks()
		watch_checks()
		fouling_checks()
		awash_checks()
		compartment_checks()
		compartment_crossing_checks()
		edge_hole_checks()
		canal_hull_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
