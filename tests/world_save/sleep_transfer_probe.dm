// Narrow gameplay adapters. Production transfer helpers, normal buckling and
// base forceMove are extracted verbatim by run-sleep-transfer.py. The fixture
// does not emulate real clients, physiology, vision cones or the timed verbs.
var/mob/living/human/sleep_fixture/sleep_actor
var/mob/living/human/sleep_fixture/sleep_decoy
var/obj/structure/bed/sleep_fixture/sleep_bed

/mob/living
	var/obj/buckled
	var/list/pinned = list()
	var/facing_dir
/mob/living/proc/restrained()
	return FALSE
/mob/living/proc/set_dir(value)
	dir = value
/mob/living/proc/update_canmove()
	return
/obj
	var/can_buckle = FALSE
	var/buckle_require_restraints = FALSE
	var/buckle_dir = 0
	var/mob/living/buckled_mob
/obj/structure/bed/bedroll
	var/used = FALSE
/obj/structure/bed/bedroll/proc/check_use(mob/living/M)
	return
/obj/structure/bed/chair/drivers
	var/datum/sleep_fixture_axis/axis
/datum/sleep_fixture_axis
	var/driver
/mob/living/human
	var/lastx = 0
	var/lasty = 0
	var/lastz = 0
	var/sleeping = 0
	var/inducedSSD = FALSE
	var/fixture_drop_calls = 0
	var/fixture_sleep_calls = 0
/mob/living/human/proc/drop_item()
	fixture_drop_calls++
/mob/living/human/proc/sleep_update()
	fixture_sleep_calls++
/mob/living/human/sleep_fixture/get_saved_vars()
	return list("name", "stat", "lastx", "lasty", "lastz", "sleeping", "inducedSSD", "buckled")
/mob/living/human/sleep_fixture/refused_move/forceMove(atom/destination, var/special_event)
	return FALSE
/mob/living/human/sleep_fixture/inventory_busy/drop_item()
	..()
	persistence_save_in_progress = TRUE
/mob/living/human/sleep_fixture/inventory_moves/drop_item()
	..()
	forceMove(locate(2,1,2))
/mob/living/human/sleep_fixture/inventory_rebuckles/drop_item()
	..()
	sleep_bed.buckle_mob(src)
/obj/structure/bed/sleep_fixture
	can_buckle = TRUE
	var/fixture_unbuckle_calls = 0
/obj/structure/bed/sleep_fixture/get_saved_vars()
	return list("name", "buckled_mob")
/obj/structure/bed/sleep_fixture/unbuckle_mob()
	fixture_unbuckle_calls++
	return ..()
/obj/structure/bed/sleep_fixture/refuses/unbuckle_mob()
	fixture_unbuckle_calls++
	return null
/obj/structure/bed/sleep_fixture/becomes_busy/unbuckle_mob()
	. = ..()
	persistence_save_in_progress = TRUE
/obj/structure/bed/sleep_fixture/moves_owner/unbuckle_mob()
	. = ..()
	var/mob/living/M = .
	if(M) M.forceMove(locate(2,1,2))

/map_storage/cross_level/sleep_transfer/capture_durable_world()
	durable_export = new
	return list("root" = durable_export.encode(list(sleep_actor, sleep_actor, sleep_bed)))

/proc/sleep_setup(actor_path = /mob/living/human/sleep_fixture, bed_path = /obj/structure/bed/sleep_fixture)
	sleep_actor = new actor_path(locate(3,2,2))
	sleep_actor.name = "protected source actor"
	sleep_decoy = new(locate(2,2,2))
	sleep_decoy.name = "unrelated actor"
	sleep_bed = new bed_path(locate(3,2,2))
	cross_check(sleep_bed.buckle_mob(sleep_actor), "production buckle setup refused")
	cross_check(sleep_actor.buckled == sleep_bed && sleep_bed.buckled_mob == sleep_actor, "production buckle did not establish reciprocal ownership")

/proc/sleep_assert_protected(mob/living/human/H, turf/where)
	cross_check(H.loc == where && H.inducedSSD && H.sleeping == 66, "refused wake changed protected actor state")

/proc/sleep_check_normal()
	sleep_setup()
	cross_check(sleep_actor.enter_protected_sleep(), "protected sleep entry failed")
	cross_check(!sleep_actor.buckled && !sleep_bed.buckled_mob, "protected sleep retained a cross-level buckle")
	cross_check(sleep_bed.fixture_unbuckle_calls == 1, "protected sleep bypassed normal unbuckle")
	sleep_assert_protected(sleep_actor, locate(1,1,1))
	cross_check(sleep_actor.lastx == 3 && sleep_actor.lasty == 2 && sleep_actor.lastz == 2, "protected sleep lost its return coordinates")
	cross_check(sleep_actor.fixture_drop_calls == 1 && sleep_actor.fixture_sleep_calls == 1, "successful entry omitted its existing gameplay hooks")
	cross_check(sleep_decoy.loc == locate(2,2,2) && !sleep_decoy.inducedSSD && !sleep_decoy.sleeping, "sleep entry changed an unrelated actor")
	var/woke = sleep_actor.complete_protected_wakeup()
	cross_check(sleep_actor.loc == locate(3,2,2) && sleep_decoy.loc == locate(2,2,2), "wake helper moved the wrong actor")
	cross_check(woke && !sleep_actor.inducedSSD && !sleep_actor.sleeping, "protected wake did not complete")
	cross_check(!sleep_actor.complete_protected_wakeup(), "repeated wake completion was accepted")

/proc/sleep_make_legacy_state()
	// Reproduce the old distant reciprocal link without repairing it in setup.
	sleep_actor.loc = locate(1,1,1)
	sleep_actor.lastx = 3
	sleep_actor.lasty = 2
	sleep_actor.lastz = 2
	sleep_actor.inducedSSD = TRUE
	sleep_actor.sleeping = 66

/proc/sleep_check_legacy()
	sleep_setup()
	sleep_make_legacy_state()
	cross_check(sleep_actor.complete_protected_wakeup(), "legacy reciprocal wake was refused")
	cross_check(sleep_actor.loc == locate(3,2,2) && !sleep_actor.buckled && !sleep_bed.buckled_mob, "legacy wake retained the distant reciprocal bed link")
	cross_check(sleep_bed.fixture_unbuckle_calls == 1 && !sleep_actor.inducedSSD && !sleep_actor.sleeping, "legacy wake bypassed normal unbuckle or kept protection")

/proc/sleep_check_unrelated()
	sleep_setup()
	// A stale pointer must never release the bed's different actual occupant.
	sleep_bed.buckled_mob = sleep_decoy
	sleep_decoy.buckled = sleep_bed
	cross_check(!sleep_actor.enter_protected_sleep(), "inconsistent entry was accepted")
	cross_check(sleep_actor.loc == locate(3,2,2) && !sleep_actor.inducedSSD, "inconsistent entry moved the source actor")
	cross_check(!sleep_bed.fixture_unbuckle_calls && sleep_bed.buckled_mob == sleep_decoy && sleep_decoy.buckled == sleep_bed, "stale sleep pointer unbuckled a different occupant")
	sleep_make_legacy_state()
	cross_check(!sleep_actor.complete_protected_wakeup(), "inconsistent wake was accepted")
	sleep_assert_protected(sleep_actor, locate(1,1,1))
	cross_check(!sleep_bed.fixture_unbuckle_calls && sleep_bed.buckled_mob == sleep_decoy && sleep_decoy.buckled == sleep_bed, "stale wake pointer unbuckled a different occupant")

/proc/sleep_check_refusal()
	sleep_setup(bed_path = /obj/structure/bed/sleep_fixture/refuses)
	cross_check(!sleep_actor.enter_protected_sleep(), "refused unbuckle allowed sleep transfer")
	cross_check(sleep_actor.loc == locate(3,2,2) && !sleep_actor.inducedSSD && !sleep_actor.sleeping, "refused entry changed actor state")
	cross_check(sleep_actor.buckled == sleep_bed && sleep_bed.buckled_mob == sleep_actor, "refused entry severed ownership by assignment")
	sleep_make_legacy_state()
	cross_check(!sleep_actor.complete_protected_wakeup(), "refused unbuckle allowed wake transfer")
	sleep_assert_protected(sleep_actor, locate(1,1,1))
	cross_check(sleep_bed.fixture_unbuckle_calls == 2 && sleep_actor.buckled == sleep_bed && sleep_bed.buckled_mob == sleep_actor, "refused wake lost reciprocal ownership")

/proc/sleep_check_busy()
	sleep_setup()
	persistence_save_in_progress = TRUE
	cross_check(!sleep_actor.enter_protected_sleep(), "entry moved during persistence")
	cross_check(sleep_actor.loc == locate(3,2,2) && !sleep_bed.fixture_unbuckle_calls && !sleep_actor.inducedSSD, "busy entry changed actor or bed")
	sleep_make_legacy_state()
	cross_check(!sleep_actor.complete_protected_wakeup(), "wake moved during persistence")
	sleep_assert_protected(sleep_actor, locate(1,1,1))
	cross_check(!sleep_bed.fixture_unbuckle_calls, "busy wake dispatched unbuckle")
	persistence_save_in_progress = FALSE
	cross_check(sleep_actor.complete_protected_wakeup(), "wake did not resume after persistence completed")

/proc/sleep_check_busy_recheck()
	sleep_setup(bed_path = /obj/structure/bed/sleep_fixture/becomes_busy)
	cross_check(!sleep_actor.enter_protected_sleep(), "entry moved after unbuckle started persistence")
	cross_check(sleep_actor.loc == locate(3,2,2) && !sleep_actor.inducedSSD, "entry changed state after persistence began")
	persistence_save_in_progress = FALSE
	cross_check(sleep_bed.buckle_mob(sleep_actor), "recheck wake setup could not rebuckle")
	sleep_make_legacy_state()
	cross_check(!sleep_actor.complete_protected_wakeup(), "wake moved after unbuckle started persistence")
	sleep_assert_protected(sleep_actor, locate(1,1,1))
	persistence_save_in_progress = FALSE

/proc/sleep_check_moved_origin()
	sleep_setup(bed_path = /obj/structure/bed/sleep_fixture/moves_owner)
	cross_check(!sleep_actor.enter_protected_sleep(), "entry ignored movement during unbuckle")
	cross_check(sleep_actor.loc == locate(2,1,2) && !sleep_actor.inducedSSD && !sleep_actor.sleeping, "entry overwrote the unbuckle hook's new position")
	cross_check(!sleep_actor.lastx && !sleep_actor.lasty && !sleep_actor.lastz, "refused entry overwrote return coordinates")

/proc/sleep_check_move_refusal()
	sleep_setup(actor_path = /mob/living/human/sleep_fixture/refused_move)
	sleep_actor.lastx = 2
	sleep_actor.lasty = 1
	sleep_actor.lastz = 1
	sleep_actor.sleeping = 4
	cross_check(!sleep_actor.enter_protected_sleep(), "failed relocation committed sleep protection")
	cross_check(sleep_actor.loc == locate(3,2,2) && !sleep_actor.inducedSSD && sleep_actor.sleeping == 4, "failed entry did not restore previous sleep state")
	cross_check(sleep_actor.lastx == 2 && sleep_actor.lasty == 1 && sleep_actor.lastz == 1 && !sleep_actor.fixture_sleep_calls, "failed entry committed return coordinates or sleep loop")
	sleep_make_legacy_state()
	cross_check(!sleep_actor.complete_protected_wakeup(), "failed relocation cleared wake protection")
	sleep_assert_protected(sleep_actor, locate(1,1,1))

/proc/sleep_check_invalid_return()
	sleep_setup()
	sleep_make_legacy_state()
	sleep_actor.lastz = 99
	cross_check(!sleep_actor.complete_protected_wakeup(), "invalid return turf admitted wake")
	sleep_assert_protected(sleep_actor, locate(1,1,1))
	cross_check(!sleep_bed.fixture_unbuckle_calls && sleep_actor.buckled == sleep_bed, "invalid return turf mutated buckle state")

/proc/sleep_check_inventory(kind)
	var/path = /mob/living/human/sleep_fixture/inventory_busy
	if(kind == "move") path = /mob/living/human/sleep_fixture/inventory_moves
	if(kind == "rebuckle") path = /mob/living/human/sleep_fixture/inventory_rebuckles
	sleep_setup(actor_path = path)
	cross_check(!sleep_actor.enter_protected_sleep(), "inventory callback bypassed transfer revalidation")
	cross_check(sleep_actor.loc == (kind == "move" ? locate(2,1,2) : locate(3,2,2)), "entry overwrote inventory callback location")
	cross_check(!sleep_actor.inducedSSD && !sleep_actor.sleeping && !sleep_actor.lastz && !sleep_actor.fixture_sleep_calls, "inventory callback refusal committed protected state")
	if(kind == "rebuckle")
		cross_check(sleep_actor.buckled == sleep_bed && sleep_bed.buckled_mob == sleep_actor, "entry severed inventory callback buckle")
	persistence_save_in_progress = FALSE

/proc/sleep_check_legacy_save()
	sleep_setup()
	sleep_make_legacy_state()
	map_storage = new /map_storage/cross_level/sleep_transfer("sleep-transfer-fixture")
	var/reason = cross_try_save()
	cross_assert_failed_save(reason, "Cross-level object reference cannot be represented", "old distant bed link unexpectedly exported")
	cross_check(findtext(reason, "/obj/structure/bed/sleep_fixture saved_z=1 native_z=2 turf_z=2 source_type=/mob/living/human/sleep_fixture source_field=buckled"), "cross-level bed diagnostic omitted its bounded field context")
	sleep_assert_protected(sleep_actor, locate(1,1,1))
	cross_check(sleep_actor.buckled == sleep_bed && sleep_bed.buckled_mob == sleep_actor, "save rejection changed the legacy buckle")

/proc/sleep_check_disk()
	sleep_setup()
	cross_check(sleep_actor.enter_protected_sleep(), "disk sleeper could not enter protection")
	map_storage = new /map_storage/cross_level/sleep_transfer("sleep-transfer-fixture")
	var/reason = cross_try_save()
	cross_check(!reason, "protected sleeper/bed export rejected: [reason]")
	var/list/state = map_storage.read_round_state()
	cross_check(state["version"] == 2, "sleep export changed the durable envelope")
	cross_check(map_storage.validate_world_save(), "protected sleeper failed production preflight: [map_storage.last_error]")
	map_storage.ClearMap()
	cross_check(map_storage.Load_World(), "protected sleeper failed production import")
	map_storage.restore_durable_world()
	var/map_storage/cross_level/storage = map_storage
	var/list/roots = storage.fixture_restored
	cross_check(roots.len == 3 && roots[1] == roots[2], "protected sleeper metadata aliases split")
	var/mob/living/human/sleep_fixture/H = roots[1]
	var/obj/structure/bed/sleep_fixture/B = roots[3]
	cross_check(istype(H) && istype(B) && H.loc == locate(1,1,1) && B.loc == locate(3,2,2), "disk roundtrip lost sleeper or bed location")
	cross_check(!H.buckled && !B.buckled_mob, "disk roundtrip restored a cross-level bed edge")
	cross_check(H.inducedSSD && H.sleeping == 66 && H.lastx == 3 && H.lasty == 2 && H.lastz == 2, "disk roundtrip lost protected return state")
	cross_check(H.complete_protected_wakeup() && H.loc == B.loc && !H.inducedSSD && !H.sleeping, "restored sleeper could not return safely")
	var/actors = 0
	var/beds = 0
	for(var/mob/living/human/sleep_fixture/actor in world)
		if(actor.name == "protected source actor") actors++
	for(var/obj/structure/bed/sleep_fixture/bed in world) beds++
	cross_check(actors == 1 && beds == 1, "disk roundtrip duplicated protected actor or bed")

/world/New()
	OpenPort("none")
	..()
	sleep(1)
	cross_case = world.params["case"]
	var/result = "PASS"
	try
		cross_check(!world.port, "fixture opened a network port")
		OpenPort(0)
		cross_check(!world.port, "fixture allowed reopening a network port")
		map = new /obj/map_metadata(locate(3,2,1))
		switch(cross_case)
			if("normal") sleep_check_normal()
			if("legacy-wake") sleep_check_legacy()
			if("unrelated-occupant") sleep_check_unrelated()
			if("refused-unbuckle") sleep_check_refusal()
			if("busy") sleep_check_busy()
			if("busy-recheck") sleep_check_busy_recheck()
			if("moved-origin") sleep_check_moved_origin()
			if("refused-move") sleep_check_move_refusal()
			if("invalid-return") sleep_check_invalid_return()
			if("inventory-busy") sleep_check_inventory("busy")
			if("inventory-move") sleep_check_inventory("move")
			if("inventory-rebuckle") sleep_check_inventory("rebuckle")
			if("legacy-save") sleep_check_legacy_save()
			if("disk") sleep_check_disk()
			else throw EXCEPTION("Unknown protected sleep fixture scenario")
	catch(var/exception/probe_error)
		result = "FAIL: [probe_error.name]"
	text2file(json_encode(list("case" = cross_case, "done" = TRUE, "result" = result, "checks" = cross_checks, "runtime_failed" = cross_runtime_failed, "port" = world.port)), "result.json")
	del(world)
	sleep(1)
