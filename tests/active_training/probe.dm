// Full-source probe for the training gear: lifting sets, weights that are too
// heavy or too light, hauling, the tread wheel and treadmill, the skipping
// rope, fatigue, caps, eras and the old fixtures and course pieces turning
// into the new gear. Real humans, items and structures; the two-second waits
// and the dice are replaced so every outcome is decided by the test.
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

/obj/item/weapon/lifting_weight/lift_wait(mob/living/human/H, duration)
	return training_probe_wait

/obj/item/weapon/lifting_weight/fumble_chance(mob/living/human/H)
	return ..() ? training_probe_fumble : 0

/obj/item/weapon/skipping_rope/skip_wait(mob/living/human/H, duration)
	return training_probe_wait

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
	training_probe_assert(H.persistence_runtime_var("exercise_equipment") && H.persistence_runtime_var("exercise_token") && !H.persistence_runtime_var("exercise_fatigue"), "human_runtime_fields_unsaved")

	// --- the tread wheel -------------------------------------------------
	var/obj/structure/treadwheel/wheel = new(locate(10, 10, 1))
	wheel.set_dir(EAST)
	var/mob/living/human/training_probe/R = training_probe_actor(9, 10)
	R.m_intent = "run"
	var/mob/living/human/training_probe/far = training_probe_actor(5, 5)
	training_probe_assert(!wheel.step_in(far) && !far.buckled, "too_far_to_step_in")
	training_probe_assert(wheel.step_in(R) && R.loc == wheel.loc && R.buckled == wheel && wheel.buckled_mob == R && wheel.icon_state == "treadwheel_turning", "step_into_wheel")
	var/mob/living/human/training_probe/rival = training_probe_actor(10, 11)
	wheel.attack_hand(rival)
	training_probe_assert(wheel.buckled_mob == R && rival.loc == locate(10, 11, 1), "one_at_a_time")

	// Forty strides at a run, in place, pay dexterity and stamina.
	var/dexterity = R.stats["dexterity"][1]
	stamina = R.stats["stamina"][1]
	for (var/i = 1, i <= 39, i++)
		wheel.relaymove(R, EAST)
	training_probe_assert(wheel.strides == 39 && wheel.run_strides == 39 && R.exercise_equipment == wheel && R.loc == wheel.loc && R.stats["dexterity"][1] == dexterity, "strides_stay_in_place")
	wheel.relaymove(R, EAST)
	var/run_stamina = R.stats["stamina"][1] - stamina
	training_probe_assert(wheel.strides == 0 && !R.exercise_equipment && R.stats["dexterity"][1] > dexterity && run_stamina > 0 && R.exercise_fatigue == 2, "running_set_pays_dexterity_and_stamina")
	training_probe_assert(R.buckled == wheel, "still_on_the_wheel_after_a_set")
	// At a walk: a little stamina and no dexterity.
	R.exercise_fatigue = 0
	R.m_intent = "walk"
	dexterity = R.stats["dexterity"][1]
	stamina = R.stats["stamina"][1]
	for (var/i = 1, i <= 40, i++)
		wheel.relaymove(R, EAST)
	training_probe_assert(R.stats["dexterity"][1] == dexterity && R.stats["stamina"][1] > stamina && R.stats["stamina"][1] - stamina < run_stamina && R.exercise_fatigue == 2, "walking_set_pays_less_stamina")
	R.exercise_fatigue = 0
	R.m_intent = "run"
	// Stopping too long starts the set over.
	for (var/i = 1, i <= 5, i++)
		wheel.relaymove(R, EAST)
	wheel.last_stride = exercise_time() - 60
	wheel.relaymove(R, EAST)
	training_probe_assert(wheel.strides == 1 && R.exercise_equipment == wheel, "pause_restarts_set")
	// Stop Exercise ends the set but leaves the runner on the wheel.
	R.cancel_exercise()
	training_probe_assert(wheel.strides == 0 && !R.exercise_equipment && R.buckled == wheel, "stop_ends_set")
	// Any other direction steps off that way and ends the set.
	for (var/i = 1, i <= 5, i++)
		wheel.relaymove(R, EAST)
	wheel.relaymove(R, NORTH)
	training_probe_assert(!R.buckled && !wheel.buckled_mob && R.loc == locate(10, 11, 1) && !R.exercise_equipment && wheel.strides == 0 && wheel.icon_state == "treadwheel", "other_direction_steps_off")
	R.forceMove(locate(9, 10, 1))
	// Touching the wheel while on it steps off the back.
	wheel.attack_hand(R)
	training_probe_assert(R.buckled == wheel, "touch_steps_in")
	wheel.attack_hand(R)
	training_probe_assert(!R.buckled && R.loc == locate(9, 10, 1), "touch_again_steps_off_the_back")
	// Being taken off mid-set ends it.
	wheel.step_in(R)
	for (var/i = 1, i <= 5, i++)
		wheel.relaymove(R, EAST)
	wheel.unbuckle_mob()
	training_probe_assert(!R.exercise_equipment && wheel.strides == 0 && wheel.icon_state == "treadwheel", "unbuckled_mid_set_ends_it")
	// A lifting set and the wheel cannot overlap.
	R.forceMove(locate(9, 10, 1))
	R.put_in_active_hand(small)
	small.attack_self(R)
	training_probe_assert(!wheel.step_in(R) && !R.buckled, "no_wheel_during_a_set")
	R.cancel_exercise()
	R.drop_from_inventory(small)
	// Fatigued: strides allowed, nothing taught.
	R.exercise_fatigue = 6
	R.exercise_rest_epoch = world.time
	dexterity = R.stats["dexterity"][1]
	wheel.step_in(R)
	for (var/i = 1, i <= 40, i++)
		wheel.relaymove(R, EAST)
	training_probe_assert(R.stats["dexterity"][1] == dexterity && R.exercise_fatigue == 6 && wheel.strides == 0, "fatigued_set_teaches_nothing")
	R.exercise_fatigue = 0
	// The wooden wheel stops at 1.25.
	R.stats["dexterity"] = list(125, 125)
	R.stats["stamina"] = list(125, 125)
	for (var/i = 1, i <= 40, i++)
		wheel.relaymove(R, EAST)
	training_probe_assert(R.stats["dexterity"][1] == 125 && R.exercise_fatigue == 0, "wheel_cap")
	wheel.relaymove(R, WEST)
	training_probe_assert(!R.buckled, "step_off_backwards")
	training_probe_assert(wheel.persistence_runtime_var("strides") && wheel.persistence_runtime_var("last_stride") && !wheel.persistence_runtime_var("dir"), "wheel_runtime_fields_unsaved")
	// Turning the wheel; not while someone is on it.
	var/facing = wheel.dir
	usr = R
	wheel.turn_wheel()
	training_probe_assert(wheel.dir == turn(facing, 90), "wheel_turns")

	// --- the treadmill: Modern, and trains past the wheel ----------------
	var/obj/structure/treadwheel/treadmill/mill = new(locate(14, 14, 1))
	mill.set_dir(SOUTH)
	R.forceMove(locate(14, 13, 1))
	training_probe_assert(!mill.step_in(R), "treadmill_needs_modern_era")
	map.ordinal_age = 8
	training_probe_assert(mill.step_in(R) && mill.icon_state == "treadmill_running", "treadmill_in_modern_era")
	// Facing the viewer, its rail draws over the runner; only while in use.
	training_probe_assert(mill.overlays.len == 1 && mill.front_state() == "treadmill_front" && !wheel.front_state(), "south_treadmill_rail_in_front")
	for (var/i = 1, i <= 40, i++)
		mill.relaymove(R, SOUTH)
	training_probe_assert(R.stats["dexterity"][1] > 125 && R.stats["stamina"][1] > 125, "treadmill_trains_further")
	mill.relaymove(R, NORTH)
	training_probe_assert(!mill.overlays.len && !R.buckled, "rail_overlay_cleared_when_empty")
	map.ordinal_age = 0

	// --- the skipping rope ------------------------------------------------
	R.forceMove(locate(3, 12, 1))
	R.exercise_fatigue = 0
	R.stats["dexterity"] = list(60, 60)
	R.stats["stamina"] = list(60, 60)
	var/obj/item/weapon/skipping_rope/rope = new(R.loc)
	R.put_in_active_hand(rope)
	for (var/i = 1, i <= 5, i++)
		rope.attack_self(R)
	training_probe_assert(rope.skips == 5 && R.exercise_equipment == rope && R.stats["dexterity"][1] == 60 && rope.item_state == "skipping_rope", "five_skips_pay_nothing_yet")
	rope.attack_self(R)
	training_probe_assert(rope.skips == 0 && !R.exercise_equipment && R.stats["dexterity"][1] > 60 && R.stats["stamina"][1] > 60 && R.exercise_fatigue == 2, "sixth_skip_pays_the_set")
	// A tangled skip is lost; the set is kept. Dropping the rope ends it.
	rope.attack_self(R)
	training_probe_wait = FALSE
	rope.attack_self(R)
	training_probe_wait = TRUE
	training_probe_assert(rope.skips == 1 && R.exercise_equipment == rope && !rope.skipping, "tangled_skip_keeps_set")
	R.drop_from_inventory(rope)
	training_probe_assert(rope.skips == 0 && !R.exercise_equipment, "dropping_rope_ends_set")
	// Both hands.
	R.put_in_active_hand(rope)
	R.put_in_inactive_hand(small)
	training_probe_assert(findtext(rope.skip_refusal(R), "both hands"), "rope_needs_both_hands")
	R.drop_from_inventory(small)
	R.drop_from_inventory(rope)
	training_probe_assert(rope.persistence_runtime_var("skips") && !rope.persistence_runtime_var("name"), "rope_runtime_fields_unsaved")

	// --- the old obstacle course turns into the wheel or its material ----
	var/obj/structure/training_course/post/old_start = new(locate(14, 20, 1))
	old_start.set_dir(WEST)
	var/list/old_pieces = list(old_start, new /obj/structure/training_course/post/finish(locate(15, 20, 1)), new /obj/structure/training_course/hurdle(locate(16, 20, 1)), new /obj/structure/training_course/hurdle/steel(locate(17, 20, 1)))
	var/obj/structure/training_course/balance_log/old_log = new(locate(18, 20, 1))
	for (var/obj/structure/training_course/piece in old_pieces)
		piece.replace_legacy()
	old_log.attack_hand(R)
	var/obj/structure/treadwheel/converted = locate(/obj/structure/treadwheel) in locate(14, 20, 1)
	training_probe_assert(converted && converted.type == /obj/structure/treadwheel && converted.dir == WEST, "old_start_post_becomes_wheel")
	var/obj/item/stack/material/wood/wood = locate() in locate(15, 20, 1)
	training_probe_assert(wood && wood.amount == 3, "old_finish_post_gives_wood")
	wood = locate() in locate(16, 20, 1)
	training_probe_assert(wood && wood.amount == 3, "old_hurdle_gives_wood")
	var/obj/item/stack/material/steel/steel_bars = locate() in locate(17, 20, 1)
	training_probe_assert(steel_bars && steel_bars.amount == 3, "old_steel_hurdle_gives_steel")
	wood = locate() in locate(18, 20, 1)
	training_probe_assert(wood && wood.amount == 4, "old_log_gives_wood")
	for (var/tx = 14, tx <= 18, tx++)
		training_probe_assert(!(locate(/obj/structure/training_course) in locate(tx, 20, 1)), "old_course_piece_removed_[tx]")

	// --- old fixtures become the new gear --------------------------------
	var/obj/structure/exercise/old_weights = new(locate(3, 20, 1))
	var/obj/structure/exercise/course/old_marker = new(locate(4, 20, 1))
	var/obj/structure/exercise/modern/old_gym = new(locate(3, 21, 1))
	training_probe_assert(old_weights.persistence_runtime_var("actor"), "old_fixture_runtime_fields_skipped")
	old_weights.replace_legacy()
	old_marker.attack_hand(R)
	old_gym.replace_legacy()
	training_probe_assert(locate(/obj/item/weapon/lifting_weight/heavy) in locate(3, 20, 1), "old_weights_become_heavy_stone")
	training_probe_assert(locate(/obj/structure/treadwheel) in locate(4, 20, 1), "old_marker_becomes_tread_wheel")
	training_probe_assert(locate(/obj/item/weapon/lifting_weight/barbell) in locate(3, 21, 1), "old_gym_becomes_barbell")
	training_probe_assert(!(locate(/obj/structure/exercise) in locate(3, 20, 1)) && !(locate(/obj/structure/exercise) in locate(4, 20, 1)), "old_fixtures_removed")

	// --- crafting gates --------------------------------------------------
	training_probe_assert(exercise_gear(/obj/item/weapon/lifting_weight/great) && exercise_gear(/obj/structure/treadwheel) && exercise_gear(/obj/item/weapon/skipping_rope) && !exercise_gear(/obj/structure/training_course) && !exercise_gear(/obj/structure/exercise), "gear_paths")
	training_probe_assert(exercise_modern_gear(/obj/item/weapon/lifting_weight/barbell) && exercise_modern_gear(/obj/structure/treadwheel/treadmill) && !exercise_modern_gear(/obj/structure/treadwheel), "modern_gear_paths")
	training_probe_assert(exercise_build_skill(/obj/item/weapon/lifting_weight) == 0 && exercise_build_skill(/obj/item/weapon/skipping_rope) == 0 && exercise_build_skill(/obj/structure/treadwheel) == 30 && exercise_build_skill(/obj/structure/treadwheel/treadmill) == 105 && exercise_build_skill(/obj/item/weapon/lifting_weight/heavy) == 30 && exercise_build_skill(/obj/item/weapon/lifting_weight/barbell) == 105, "build_skills")
	training_probe_assert(!exercise_recipe_era(/obj/item/weapon/lifting_weight/barbell) && exercise_recipe_era(/obj/item/weapon/lifting_weight/hand_weights), "modern_recipes_wait_for_their_era")
	for (var/state in list("lifting_stone_small", "lifting_stone_heavy", "lifting_stone_great", "hand_weights", "barbell", "course_start", "course_finish", "log_hurdle", "balance_log", "steel_hurdle", "treadwheel", "treadwheel_turning", "treadmill", "treadmill_running", "treadmill_front", "skipping_rope"))
		training_probe_assert(state in icon_states('icons/obj/training.dmi'), "icon_state_[state]")
	for (var/held in list("lifting_stone_small", "lifting_stone_heavy", "lifting_stone_great", "hand_weights", "barbell", "skipping_rope"))
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
