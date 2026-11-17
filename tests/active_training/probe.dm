// Full-source probe for the training gear: lifting sets, weights that are too
// heavy or too light, hauling, the obstacle course with its hurdles, balance
// logs, pace and best times, fatigue, caps, eras and the old fixtures turning
// into the new gear. Real humans, items and structures; the two-second lift
// waits and the dice are replaced so every outcome is decided by the test.
/world
	hub = ""
	visibility = 0
	maxx = 24
	maxy = 24
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/training_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/training_probe/New()
	map = src

/turf/floor/plating/training_probe

/mob/living/human/training_probe/human_subtile_authority(client/owner)
	return TRUE

// No timer subsystem in the probe: a held set never lapses by itself.
/mob/living/human/training_probe/hold_exercise(datum/E, window)
	exercise_equipment = E
	exercise_token++

var/training_probe_checks = 0
var/training_probe_wait = TRUE
var/training_probe_fumble = 0
var/training_probe_vault = 0
var/training_probe_fall = 0

/obj/item/weapon/lifting_weight/lift_wait(mob/living/human/H, duration)
	return training_probe_wait

/obj/item/weapon/lifting_weight/fumble_chance(mob/living/human/H)
	return ..() ? training_probe_fumble : 0

/obj/structure/training_course/hurdle/vault_chance(mob/living/human/H)
	return training_probe_vault

/obj/structure/training_course/hurdle/clamber_wait(mob/living/human/H)
	return training_probe_wait

/obj/structure/training_course/balance_log/fall_chance(mob/living/human/H)
	return H.m_intent == "run" ? 100 : training_probe_fall

/proc/training_probe_assert(ok, label)
	training_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/training_probe_actor(tx, ty)
	var/mob/living/human/training_probe/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.real_name = "Runner [tx]"
	H.name = H.real_name
	H.nutrition = 300
	H.water = 300
	for (var/skill in list("strength", "dexterity", "stamina"))
		H.stats[skill] = list(60, 60)
	return H

/proc/training_probe_set(mob/living/human/H, obj/item/weapon/lifting_weight/W)
	for (var/i = 1, i <= 6, i++)
		W.attack_self(H)

/proc/training_probe_run()
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
	map = new /obj/map_metadata/training_probe
	map.ordinal_age = 0
	training_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	// --- lifting: six lifts make a set, and the set pays strength ---------
	var/mob/living/human/training_probe/H = training_probe_actor(3, 3)
	var/obj/item/weapon/lifting_weight/small = new(H.loc)
	H.put_in_active_hand(small)
	training_probe_assert(small.in_hand_of(H) && small.heft_for(H) == 0, "small_stone_right_weight")
	var/before = H.stats["strength"][1]
	for (var/i = 1, i <= 5, i++)
		small.attack_self(H)
	training_probe_assert(small.reps == 5 && H.exercise_equipment == small && H.stats["strength"][1] == before && H.exercise_fatigue == 0, "five_lifts_pay_nothing_yet")
	training_probe_assert(small.item_state == "lifting_stone_small", "lift_pose_put_down")
	small.attack_self(H)
	training_probe_assert(small.reps == 0 && !H.exercise_equipment && H.stats["strength"][1] > before && H.exercise_fatigue == 2, "sixth_lift_pays_the_set")
	training_probe_assert(H.nutrition < 300 && H.water < 300, "set_costs_food_and_water")
	var/full_gain = H.stats["strength"][1] - before

	// A lift that is interrupted is lost; the set is kept.
	H.exercise_fatigue = 0
	small.attack_self(H)
	training_probe_wait = FALSE
	small.attack_self(H)
	training_probe_wait = TRUE
	training_probe_assert(small.reps == 1 && H.exercise_equipment == small && !small.lifting, "interrupted_lift_keeps_set")
	// Dropping it, or resting too long, starts the set over.
	H.drop_from_inventory(small)
	training_probe_assert(small.reps == 0 && !H.exercise_equipment, "dropping_ends_set")
	H.put_in_active_hand(small)
	small.attack_self(H)
	H.lapse_exercise(H.exercise_token)
	training_probe_assert(small.reps == 0 && !H.exercise_equipment, "long_rest_restarts_set")
	H.lapse_exercise(H.exercise_token - 1)

	// Too light: a quarter of the gain. Past the cap: nothing, and no fatigue.
	H.stats["strength"] = list(85, 85)
	training_probe_assert(small.heft_for(H) == 1, "small_stone_outgrown")
	before = H.stats["strength"][1]
	training_probe_set(H, small)
	var/light_gain = H.stats["strength"][1] - before
	training_probe_assert(light_gain > 0 && light_gain < full_gain && H.exercise_fatigue == 2, "light_weight_teaches_little")
	H.exercise_fatigue = 0
	H.stats["strength"] = list(100, 100)
	training_probe_set(H, small)
	training_probe_assert(H.stats["strength"][1] == 100 && H.exercise_fatigue == 0, "cap_stops_training")
	H.drop_from_inventory(small)

	// Too heavy: it slips from the hands. Both hands are needed.
	var/obj/item/weapon/lifting_weight/great/great = new(H.loc)
	H.stats["strength"] = list(60, 60)
	H.put_in_active_hand(great)
	training_probe_assert(great.heft_for(H) == -1, "great_stone_too_heavy")
	training_probe_fumble = 100
	great.attack_self(H)
	training_probe_assert(great.loc == H.loc && !H.exercise_equipment && great.reps == 0, "too_heavy_slips")
	training_probe_fumble = 0
	H.stats["strength"] = list(110, 110)
	H.put_in_active_hand(great)
	H.put_in_inactive_hand(small)
	training_probe_assert(great.lift_refusal(H) && findtext(great.lift_refusal(H), "both hands"), "both_hands_needed")
	great.attack_self(H)
	training_probe_assert(great.reps == 0, "no_lift_with_a_full_hand")
	H.drop_from_inventory(small)
	training_probe_set(H, great)
	training_probe_assert(H.stats["strength"][1] > 110 && H.exercise_fatigue == 2, "great_stone_trains_the_strong")

	// Fatigue: at six a set teaches nothing.
	H.exercise_fatigue = 6
	H.exercise_rest_epoch = world.time
	before = H.stats["strength"][1]
	training_probe_set(H, great)
	training_probe_assert(H.stats["strength"][1] == before && H.exercise_fatigue == 6, "fatigue_blocks_gain")
	H.exercise_fatigue = 0
	H.nutrition = 10
	training_probe_set(H, great)
	training_probe_assert(H.stats["strength"][1] == before && H.exercise_fatigue == 0, "hunger_blocks_gain")
	H.nutrition = 300

	// Hauling: forty tiles with a heavy stone in hand pay strength and stamina.
	before = H.stats["strength"][1]
	var/stamina = H.stats["stamina"][1]
	for (var/i = 1, i <= 39, i++)
		H.exercise_carry_step()
	training_probe_assert(H.stats["strength"][1] == before && great.carry_tiles == 39, "hauling_counts_tiles")
	H.exercise_carry_step()
	training_probe_assert(H.stats["strength"][1] > before && H.stats["stamina"][1] > stamina && H.exercise_fatigue == 1 && great.carry_tiles == 0, "hauling_pays")
	H.drop_from_inventory(great)
	H.put_in_active_hand(small)
	for (var/i = 1, i <= 45, i++)
		H.exercise_carry_step()
	training_probe_assert(small.carry_tiles == 0, "small_stone_is_no_haul")
	H.drop_from_inventory(small)
	// The turf hook: walking onto a tile with the stone in hand counts it.
	H.put_in_active_hand(great)
	var/turf/next = locate(4, 3, 1)
	next.Entered(H, H.loc)
	training_probe_assert(great.carry_tiles == 1, "turf_entry_counts_hauling")
	H.drop_from_inventory(great)

	// The barbell waits for the Modern era, then trains past the stones.
	var/obj/item/weapon/lifting_weight/barbell/bar = new(H.loc)
	H.stats["strength"] = list(125, 125)
	H.exercise_fatigue = 0
	H.put_in_active_hand(bar)
	training_probe_assert(bar.lift_refusal(H), "barbell_needs_modern_era")
	map.ordinal_age = 8
	training_probe_assert(isnull(bar.lift_refusal(H)), "barbell_usable_in_modern_era")
	training_probe_set(H, bar)
	training_probe_assert(H.stats["strength"][1] > 125, "barbell_trains_past_stone_cap")
	H.stats["strength"] = list(150, 150)
	H.exercise_fatigue = 0
	training_probe_set(H, bar)
	training_probe_assert(H.stats["strength"][1] == 150, "barbell_cap")
	map.ordinal_age = 0
	H.drop_from_inventory(bar)
	training_probe_assert(great.persistence_runtime_var("reps") && great.persistence_runtime_var("lifting") && great.persistence_runtime_var("carry_tiles") && !great.persistence_runtime_var("name"), "weight_runtime_fields_unsaved")
	training_probe_assert(H.persistence_runtime_var("exercise_equipment") && H.persistence_runtime_var("exercise_token") && H.persistence_runtime_var("course_vault_at") && !H.persistence_runtime_var("exercise_fatigue"), "human_runtime_fields_unsaved")

	// --- the course ------------------------------------------------------
	// Start post at (10,10); hurdles at x 12, 15 and 18 on the same row; a
	// balance log at (20,12); a finish post at (22,12).
	var/obj/structure/training_course/post/start = new(locate(10, 10, 1))
	var/obj/structure/training_course/post/finish/finish = new(locate(22, 12, 1))
	var/list/hurdles = list()
	for (var/hx in list(12, 15, 18))
		hurdles += new /obj/structure/training_course/hurdle(locate(hx, 10, 1))
	var/obj/structure/training_course/balance_log/log = new(locate(20, 12, 1))
	var/mob/living/human/training_probe/R = training_probe_actor(11, 10)
	R.stats["dexterity"] = list(60, 60)
	R.stats["stamina"] = list(60, 60)
	R.m_intent = "run"

	finish.attack_hand(R)
	training_probe_assert(!R.course_run(), "finish_post_starts_nothing")
	start.attack_hand(R)
	var/datum/course_run/run = R.course_run()
	training_probe_assert(run && run.start == start && run.runner == R, "start_post_starts_run")

	// Vault at a run: over to the far side, and counted once.
	var/obj/structure/training_course/hurdle/first = hurdles[1]
	training_probe_assert(first.vault(R) && R.loc == locate(13, 10, 1) && run.cleared.len == 1, "vault_clears_hurdle")
	R.course_vault_at = 0
	R.forceMove(locate(11, 10, 1))
	training_probe_assert(first.vault(R) && run.cleared.len == 1, "hurdle_counts_once")
	// A stumble: knocked down on the near side, nothing counted.
	var/obj/structure/training_course/hurdle/second = hurdles[2]
	R.course_vault_at = 0
	R.forceMove(locate(14, 10, 1))
	training_probe_vault = 100
	training_probe_assert(!second.vault(R) && R.loc == locate(14, 10, 1) && run.stumbles == 1 && run.cleared.len == 1 && R.weakened, "stumble_clears_nothing")
	training_probe_vault = 0
	R.weakened = 0
	R.lying = FALSE
	R.course_vault_at = 0
	training_probe_assert(second.vault(R) && run.cleared.len == 2, "second_hurdle")
	// No landing room: refused. Diagonal approach: refused.
	var/obj/structure/training_course/hurdle/third = hurdles[3]
	var/obj/structure/training_course/post/blocker = new(locate(19, 10, 1))
	R.course_vault_at = 0
	R.forceMove(locate(17, 10, 1))
	training_probe_assert(!third.vault(R) && R.loc == locate(17, 10, 1), "blocked_landing_refused")
	qdel(blocker)
	R.course_vault_at = 0
	R.forceMove(locate(17, 11, 1))
	training_probe_assert(!third.vault(R), "diagonal_vault_refused")

	// Too few obstacles: the post will not end the run.
	training_probe_assert(!finish.finish_run(R) && R.course_run() == run, "three_obstacles_needed")
	// At a walk you clamber over, which still counts.
	R.course_vault_at = 0
	R.forceMove(locate(17, 10, 1))
	R.m_intent = "walk"
	training_probe_assert(third.vault(R) && R.loc == locate(19, 10, 1) && run.cleared.len == 3, "clamber_counts")
	// An obstacle right beside the last one does not count.
	var/obj/structure/training_course/hurdle/crowded = new(locate(19, 9, 1))
	R.course_vault_at = 0
	R.m_intent = "run"
	training_probe_assert(crowded.vault(R) && R.loc == locate(19, 8, 1) && run.cleared.len == 3, "crowded_obstacle_not_counted")
	qdel(crowded)
	// The balance log: run onto it and fall; walk it and it counts.
	R.forceMove(locate(20, 11, 1))
	log.Crossed(R)
	training_probe_assert(run.cleared.len == 3 && run.stumbles == 2 && R.weakened, "running_the_log_falls")
	R.weakened = 0
	R.lying = FALSE
	R.m_intent = "walk"
	log.Crossed(R)
	training_probe_assert(run.cleared.len == 4, "walking_the_log_counts")

	// Finish: dexterity and stamina paid, fatigue and the record kept.
	var/dexterity = R.stats["dexterity"][1]
	stamina = R.stats["stamina"][1]
	run.started = exercise_time() - 160
	R.forceMove(locate(21, 12, 1))
	training_probe_assert(finish.finish_run(R) && !R.course_run(), "finish_ends_run")
	var/fast_gain = R.stats["dexterity"][1] - dexterity
	training_probe_assert(fast_gain > 0 && R.stats["stamina"][1] > stamina && R.exercise_fatigue == 2, "run_pays_dexterity_and_stamina")
	training_probe_assert(start.best_time == 160 && start.best_count == 4 && start.best_name == R.real_name, "best_time_recorded")

	// A slower run over as many obstacles pays less and leaves the record.
	R.exercise_fatigue = 0
	R.stats["dexterity"] = list(60, 60)
	start.start_run(R)
	run = R.course_run()
	run.cleared = list(first, second, third, log)
	run.started = exercise_time() - 600
	finish.finish_run(R)
	training_probe_assert(R.stats["dexterity"][1] - 60 < fast_gain && R.stats["dexterity"][1] > 60, "slow_run_pays_less")
	training_probe_assert(start.best_time == 160, "slower_run_keeps_record")
	// Another runner, faster: takes the record. More obstacles beats a faster time.
	var/mob/living/human/training_probe/rival = training_probe_actor(9, 10)
	start.start_run(rival)
	run = rival.course_run()
	run.cleared = list(first, second, third, log)
	run.started = exercise_time() - 120
	start.finish_run(rival)
	training_probe_assert(start.best_time == 120 && start.best_name == rival.real_name, "faster_rival_takes_record")
	training_probe_assert(!start.record(R, 100, 3) && start.record(R, 400, 5) && start.best_count == 5, "more_obstacles_beats_time")

	// Racing while fatigued is allowed; it just teaches nothing.
	R.exercise_fatigue = 6
	R.exercise_rest_epoch = world.time
	R.stats["dexterity"] = list(60, 60)
	start.start_run(R)
	run = R.course_run()
	run.cleared = list(first, second, third)
	training_probe_assert(finish.finish_run(R) && R.stats["dexterity"][1] == 60 && R.exercise_fatigue == 6, "fatigued_run_teaches_nothing")
	// Stop Exercise and the lapse both end a run.
	R.exercise_fatigue = 0
	start.start_run(R)
	R.cancel_exercise()
	training_probe_assert(!R.course_run(), "stop_ends_run")
	// A lifting set and a run cannot overlap.
	R.put_in_active_hand(small)
	small.attack_self(R)
	training_probe_assert(!start.start_run(R), "no_run_during_a_set")
	R.cancel_exercise()
	R.drop_from_inventory(small)

	// Wooden courses stop at 1.25; three steel hurdles in the Modern era reach 1.5.
	R.stats["dexterity"] = list(125, 125)
	R.stats["stamina"] = list(125, 125)
	start.start_run(R)
	run = R.course_run()
	run.cleared = list(first, second, third)
	finish.finish_run(R)
	training_probe_assert(R.stats["dexterity"][1] == 125 && R.exercise_fatigue == 0, "wooden_course_cap")
	map.ordinal_age = 8
	start.start_run(R)
	run = R.course_run()
	run.cleared = list(first, second, third)
	run.steel = 3
	finish.finish_run(R)
	training_probe_assert(R.stats["dexterity"][1] > 125 && R.stats["stamina"][1] > 125, "steel_course_trains_further")
	map.ordinal_age = 0
	var/obj/structure/training_course/hurdle/steel/steel = new(locate(5, 20, 1))
	training_probe_assert(steel.steel && !first.steel, "steel_hurdle_marked")

	// Turning an obstacle; posts keep their facing.
	var/facing = first.dir
	usr = R
	R.forceMove(locate(11, 10, 1))
	first.turn_obstacle()
	training_probe_assert(first.dir == turn(facing, 90), "obstacle_turns")

	// --- old fixtures become the new gear --------------------------------
	var/obj/structure/exercise/old_weights = new(locate(3, 20, 1))
	var/obj/structure/exercise/course/old_marker = new(locate(4, 20, 1))
	var/obj/structure/exercise/modern/old_gym = new(locate(3, 21, 1))
	training_probe_assert(old_weights.persistence_runtime_var("actor"), "old_fixture_runtime_fields_skipped")
	old_weights.replace_legacy()
	old_marker.attack_hand(R)
	old_gym.replace_legacy()
	training_probe_assert(locate(/obj/item/weapon/lifting_weight/heavy) in locate(3, 20, 1), "old_weights_become_heavy_stone")
	training_probe_assert(locate(/obj/structure/training_course/post) in locate(4, 20, 1), "old_marker_becomes_start_post")
	training_probe_assert(locate(/obj/item/weapon/lifting_weight/barbell) in locate(3, 21, 1), "old_gym_becomes_barbell")
	training_probe_assert(!(locate(/obj/structure/exercise) in locate(3, 20, 1)) && !(locate(/obj/structure/exercise) in locate(4, 20, 1)), "old_fixtures_removed")

	// --- crafting gates --------------------------------------------------
	training_probe_assert(exercise_gear(/obj/item/weapon/lifting_weight/great) && exercise_gear(/obj/structure/training_course/balance_log) && !exercise_gear(/obj/structure/exercise), "gear_paths")
	training_probe_assert(exercise_modern_gear(/obj/item/weapon/lifting_weight/barbell) && exercise_modern_gear(/obj/structure/training_course/hurdle/steel) && !exercise_modern_gear(/obj/structure/training_course/hurdle), "modern_gear_paths")
	training_probe_assert(exercise_build_skill(/obj/item/weapon/lifting_weight) == 0 && exercise_build_skill(/obj/item/weapon/lifting_weight/heavy) == 30 && exercise_build_skill(/obj/item/weapon/lifting_weight/barbell) == 105, "build_skills")
	training_probe_assert(!exercise_recipe_era(/obj/item/weapon/lifting_weight/barbell) && exercise_recipe_era(/obj/item/weapon/lifting_weight/hand_weights), "modern_recipes_wait_for_their_era")
	for (var/state in list("lifting_stone_small", "lifting_stone_heavy", "lifting_stone_great", "hand_weights", "barbell", "course_start", "course_finish", "log_hurdle", "balance_log", "steel_hurdle"))
		training_probe_assert(state in icon_states('icons/obj/training.dmi'), "icon_state_[state]")
	for (var/held in list("lifting_stone_small", "lifting_stone_heavy", "lifting_stone_great", "hand_weights", "barbell"))
		training_probe_assert((held in icon_states('icons/mob/items/lefthand_training.dmi')) && ("[held]_lift" in icon_states('icons/mob/items/righthand_training.dmi')), "held_state_[held]")

/world/New()
	OpenPort("none")
	var/error = null
	try
		training_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = training_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
