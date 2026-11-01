// Full-source, disposable test world only. The staging adapter injects one
// deterministic movement at the existing child-consistency checkpoint.
var/global/mob/living/simple_animal/debug_save_fixture/fixture_subject
var/global/fixture_armed = FALSE
var/global/fixture_moves = 0
var/global/mob/living/human/combined_actor
var/global/combined_authorized = FALSE
var/global/combined_active = FALSE
var/global/combined_handoffs = 0
var/global/combined_pulses_after = 0
var/global/list/combined_capsule

/obj/map_metadata/nomads/gaia/New()
	map = src

/obj/structure/debug_save_fixture
	name = "synthetic retained box"
	var/mob/living/simple_animal/fixture_reference

/obj/item/debug_save_fixture
	name = "synthetic retained item"

/obj/item/debug_lossy_control
	name = "synthetic retained control"

/mob/living/simple_animal/debug_save_fixture
	name = "synthetic omitted animal"

/proc/debug_fixture_assert(ok, label)
	if(!ok) throw EXCEPTION(label)

/proc/debug_fixture_after_child_capture(atom/parent, atom/movable/child, child_ref)
	if(!fixture_armed || child != fixture_subject || !child_ref) return
	debug_fixture_assert(child.loc == parent, "fixture_child_not_owned_before_move")
	fixture_armed = FALSE
	fixture_moves++
	// Test-only mutation, deliberately before the production unchanged guard.
	child.loc = locate(2, 2, 1)
	debug_fixture_assert(child.loc != parent, "fixture_move_failed")

/proc/debug_fixture_initialize()
	human_subtile_fixture_initialize()
	config = new
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	ticker = new
	ticker.current_state = GAME_STATE_PLAYING
	processes.time_of_day = new
	processes.weather = new
	map = new /obj/map_metadata/nomads/gaia(locate(1, 1, 1))
	job_master = new /datum/controller/occupations()
	game_id = "synthetic-debug-lossy-round"
	debug_fixture_assert(map && map.uses_durable_metadata(), "fixture_no_durable_profile")
	debug_fixture_assert(job_master, "fixture_no_job_controller")

/proc/debug_fixture_refusal_controls(obj/structure/debug_save_fixture/box, mob/living/simple_animal/debug_save_fixture/animal)
	var/datum/persistence_world_operation/op = begin_persistence_operation(map_storage, "save")
	debug_fixture_assert(op && op.current(map_storage, "save"), "fixture_control_owner")
	op.diagnostic_save_id = "synthetic-control-attempt"
	op.diagnostic_generation = "round-v2:synthetic-control"
	var/datum/save_debug_recovery/policy = new
	policy.attempt = 1
	debug_fixture_assert(policy.bind(op), "fixture_control_bind")
	op.debug_recovery = policy
	var/obj/item/debug_lossy_control/contained = new(animal)
	animal.loc = locate(2, 2, 1)
	debug_fixture_assert(!policy.observe(box, null, op), "fixture_missing_child_admitted")
	debug_fixture_assert(!policy.observe(box, animal, op), "fixture_nonempty_animal_admitted")
	contained.loc = locate(3, 3, 1)
	debug_fixture_assert(contained.loc == locate(3, 3, 1) && !animal.contents.len, "fixture_control_detach_failed")
	debug_fixture_assert(policy.observe(box, animal, op), "fixture_supported_fault_not_observed")
	policy.quarantine["\ref[animal]"] = animal
	policy.encoding_depth = 2
	var/nested_refused = FALSE
	try
		policy.omits(animal, null)
	catch(var/exception/nested_error)
		nested_refused = nested_error.name == "Debug omission in nested list is unsupported"
	debug_fixture_assert(nested_refused, "fixture_nested_list_admitted")
	policy.encoding_depth = 0
	policy.quarantine = list()
	var/fault = policy.pending_fault_id
	var/attempt_id = policy.pending_operation_id
	var/generation = policy.pending_generation
	policy.retryable = TRUE
	debug_fixture_assert(!policy.admit_retry(fault, attempt_id, generation), "fixture_owned_retry_admitted")
	debug_fixture_assert(op.withdraw(), "fixture_control_withdraw")
	debug_fixture_assert(!policy.observe(box, animal, op), "fixture_lost_owner_observed")
	var/exception/lost_error = EXCEPTION("Child moved or disappeared during capture")
	debug_fixture_assert(!policy.finish_failure(op, lost_error, TRUE, FALSE) && policy.stop_reason == "owner_lost", "fixture_lost_owner_not_recorded")
	debug_fixture_assert(!policy.admit_retry(fault, attempt_id, generation), "fixture_lost_owner_retry_admitted")
	policy.close()
	animal.loc = box
	return TRUE

/proc/debug_fixture_seed_copy()
	for(var/name in list("map.txt", "round.json", "1.sav", "save_complete.txt"))
		debug_fixture_assert(fcopy("map_saves/[name]", "fixture_seed/[name]"), "fixture_seed_copy_failed")
	return TRUE

/proc/combined_start_walker()
	combined_actor = new(locate(8, 8, 1))
	combined_actor.persistence_owner_ckey = "syntheticcombined"
	combined_actor.canmove = TRUE
	combined_actor.stat = CONSCIOUS
	combined_actor.pixel_x = 7
	combined_actor.pixel_y = -3
	debug_fixture_assert(combined_actor.set_human_subtile(TRUE), "combined_enable")
	var/obj/item/weapon/storage/backpack/bag = new(combined_actor)
	combined_actor.back = bag
	var/obj/item/weapon/pen/nested = new(bag)
	nested.name = "combined nested pen"
	combined_authorized = TRUE
	combined_active = TRUE
	spawn(0)
		while(combined_active && combined_actor)
			var/direction = combined_actor.x < 9 ? EAST : WEST
			combined_actor.human_subtile_travel(get_step(combined_actor, direction), direction, world.time + 80)
			sleep(world.tick_lag)
	var/deadline = world.time + 60
	while((!combined_actor.human_subtile_transaction || !combined_actor.step_x) && world.time < deadline) sleep(world.tick_lag)
	debug_fixture_assert(combined_actor.human_subtile_transaction && combined_actor.step_x, "combined_walker_not_started")

/proc/debug_fixture_writer(list/result)
	var/obj/structure/debug_save_fixture/box = new(locate(4, 4, 1))
	var/obj/item/debug_save_fixture/item = new(box)
	fixture_subject = new(box)
	box.fixture_reference = fixture_subject
	debug_fixture_assert(fixture_subject.loc == box && item.loc == box, "fixture_initial_containment")
	debug_fixture_assert(debug_fixture_refusal_controls(box, fixture_subject), "fixture_refusal_controls")
	debug_fixture_assert(ticker.savemap(null, null), "fixture_seed_save_failed")
	var/seed_generation = trim(file2text("map_saves/save_complete.txt"))
	debug_fixture_assert(length(seed_generation) > 9 && debug_fixture_seed_copy(), "fixture_seed_missing")
	fixture_armed = TRUE
	debug_fixture_assert(!ticker.savemap(null, null), "fixture_original_save_did_not_fail")
	debug_fixture_assert(fixture_moves == 1 && !fexists("map_saves/save_complete.txt"), "fixture_failed_capture_marker")
	debug_fixture_assert(findtext(map_storage.last_error, "Child moved or disappeared during capture"), "fixture_wrong_original_failure")
	debug_fixture_assert(trim(file2text("map_backups/save_complete.txt")) == seed_generation, "fixture_backup_generation_changed")
	fixture_subject.loc = box
	fixture_armed = TRUE
	combined_start_walker()
	debug_fixture_assert(ticker.debug_lossy_save(), "fixture_debug_save_failed")
	combined_active = FALSE
	debug_fixture_assert(combined_handoffs == 1 && combined_pulses_after > 0 && islist(combined_capsule), "combined_handoff_or_continuation_missing")
	debug_fixture_assert(!combined_capsule["sx"] && !combined_capsule["sy"], "combined_capsule_not_centered")
	debug_fixture_assert(fixture_moves == 2 && !fixture_armed, "fixture_debug_fault_not_reached")
	debug_fixture_assert(fixture_subject && fixture_subject.loc == locate(2, 2, 1), "fixture_live_animal_changed")
	debug_fixture_assert(item && item.loc == box, "fixture_live_item_changed")
	var/list/round = map_storage.read_round_state()
	var/list/audit = round["debug_recovery"]
	var/generation = trim(file2text("map_saves/save_complete.txt"))
	debug_fixture_assert(valid_debug_recovery_audit(audit, generation), "fixture_invalid_audit")
	debug_fixture_assert(audit["attempt"] == 2 && audit["incidents"].len == 1 && audit["omissions"].len > 0, "fixture_audit_counts")
	debug_fixture_assert(audit["generation"] == generation && generation != seed_generation, "fixture_audit_generation")
	result["generation"] = generation
	result["seed_generation"] = seed_generation
	result["audit"] = audit
	result["fixture_moves"] = fixture_moves
	result["human_tile"] = list(combined_capsule["x"], combined_capsule["y"], combined_capsule["z"])
	result["human_handoffs"] = combined_handoffs
	result["human_pulses_after"] = combined_pulses_after
	result["controls"] = list("unsupported_contents" = TRUE, "missing_child" = TRUE, "nested_list" = TRUE, "owner_bound" = TRUE, "owner_lost" = TRUE)
	return TRUE

/proc/debug_fixture_reader(list/result)
	var/list/round = map_storage.read_round_state()
	var/generation = trim(file2text("map_saves/save_complete.txt"))
	debug_fixture_assert(valid_debug_recovery_audit(round["debug_recovery"], generation), "fixture_reader_audit")
	debug_fixture_assert(ticker.loadmap(null, null), "fixture_reader_load_failed")
	var/obj/structure/debug_save_fixture/box
	var/obj/item/debug_save_fixture/item
	var/box_count = 0
	var/item_count = 0
	var/control_count = 0
	var/obj/item/debug_lossy_control/control_item
	var/animal_count = 0
	var/mob/living/human/saved_human
	var/human_count = 0
	for(var/mob/living/human/H in world)
		if(H.persistence_owner_ckey == "syntheticcombined")
			saved_human = H
			human_count++
	for(var/obj/structure/debug_save_fixture/B in world)
		box = B
		box_count++
	for(var/obj/item/debug_save_fixture/I in world)
		item = I
		item_count++
	for(var/obj/item/debug_lossy_control/C in world)
		control_item = C
		control_count++
	for(var/mob/living/simple_animal/debug_save_fixture/A in world)
		if(A) animal_count++
	debug_fixture_assert(box_count == 1 && item_count == 1 && control_count == 1 && !animal_count && box && item && control_item && item.loc == box && control_item.loc == locate(3, 3, 1) && !box.fixture_reference && box.x == 4 && box.y == 4 && box.z == 1 && item.name == "synthetic retained item", "fixture_reader_retained_graph")
	debug_fixture_assert(human_count == 1 && saved_human && isturf(saved_human.loc) && !saved_human.step_x && !saved_human.step_y && saved_human.pixel_x == 7 && saved_human.pixel_y == -3, "combined_reader_human")
	debug_fixture_assert(istype(saved_human.back, /obj/item/weapon/storage/backpack) && saved_human.back.loc == saved_human, "combined_reader_bag")
	var/pen_count = 0
	for(var/obj/item/weapon/pen/P in saved_human.back.contents)
		if(P.name == "combined nested pen") pen_count++
	debug_fixture_assert(pen_count == 1, "combined_reader_nested")
	result["generation"] = generation
	result["audit"] = round["debug_recovery"]
	result["retained_box"] = TRUE
	result["retained_item"] = TRUE
	result["retained_control_item"] = TRUE
	result["omitted_animal"] = TRUE
	result["reference_null"] = TRUE
	result["human_tile"] = list(saved_human.x, saved_human.y, saved_human.z)
	result["human_centered"] = TRUE
	result["human_art_and_inventory"] = TRUE
	return TRUE

/world/New()
	OpenPort("none")
	var/list/result = list("phase" = world.params["phase"], "head" = world.params["tested_commit"], "scope" = world.params["scope"], "byond_version" = byond_version, "byond_build" = byond_build, "port" = port, "error" = null)
	try
		debug_fixture_assert(!port && byond_version == 516 && byond_build == 1688, "fixture_engine_or_port")
		debug_fixture_initialize()
		if(result["phase"] == "writer") debug_fixture_writer(result)
		else if(result["phase"] == "reader") debug_fixture_reader(result)
		else throw EXCEPTION("fixture_unknown_phase")
	catch(var/exception/fixture_error)
		result["error"] = "[fixture_error] at [fixture_error.file]:[fixture_error.line]"
	text2file(json_encode(result), "debug-fixture-[result["phase"]].json")
	del(world)
