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

	// ---- Striking a hull ----
	var/count = hull_ledgers.len
	skiff.decommission()
	naval_check(hull_ledgers.len == count - 1 && !(S in hull_ledgers), "a struck hull gives up her ledger")
	qdel(steamer)
	qdel(tiller)
	naval_check(!hull_ledgers.len, "no ledger outlives its tiller")

/proc/naval_run()
	try
		naval_checks()
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
