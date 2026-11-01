// Full-source synthetic probe only. The staging adapter supplies the headless
// authority seam; this is not a connected-client or production-world test.
var/global/human_spatial_fixture_authorized = FALSE
var/global/human_spatial_fixture_handoffs = 0
var/global/human_spatial_fixture_pulses_after = 0
var/global/human_spatial_fixture_case = null
var/global/list/human_spatial_fixture_capsule = null
var/global/mob/living/human/human_spatial_fixture_drag_actor = null
var/global/human_spatial_fixture_living_completions = 0
var/global/human_spatial_fixture_human_completions = 0
var/global/mob/living/human/human_spatial_fixture_direct_actor = null
var/global/human_spatial_fixture_direct_active = FALSE
var/global/human_spatial_fixture_direct_callbacks = 0
var/global/human_spatial_fixture_restore_living = 0
var/global/human_spatial_fixture_restore_human = 0
var/global/mob/living/human/human_spatial_fixture_late_actor = null
var/global/list/human_spatial_fixture_late_capsule = null
var/global/human_spatial_fixture_late_pulses = 0
var/global/list/human_spatial_fixture_geometry_metrics = null
var/global/human_spatial_fixture_seated_moved = 0

// Test-only collision callbacks on the exact floor and item in the fixture.
/turf/floor/winter/grass/human_spatial_probe/Entered(atom/movable/A)
	if(human_spatial_fixture_direct_active && A == human_spatial_fixture_direct_actor) human_spatial_fixture_direct_callbacks++
	return ..()

/turf/floor/winter/grass/human_spatial_probe/Exited(atom/movable/A)
	if(human_spatial_fixture_direct_active && A == human_spatial_fixture_direct_actor) human_spatial_fixture_direct_callbacks++
	return ..()

/obj/item/weapon/flint/human_spatial_probe/Crossed(atom/movable/A)
	if(human_spatial_fixture_direct_active && A == human_spatial_fixture_direct_actor) human_spatial_fixture_direct_callbacks++
	return ..()

/proc/human_spatial_fixture_assert(ok, label)
	if(!ok) throw EXCEPTION(label)

// Staged writer only: created after the initial spatial group was captured.
/proc/human_spatial_fixture_start_late_walker()
	var/mob/living/human/H = new(locate(7, 9, 1))
	H.persistence_owner_ckey = "syntheticlate"
	H.canmove = TRUE
	H.stat = CONSCIOUS
	human_spatial_fixture_assert(H.set_human_subtile(TRUE), "fixture_late_enable")
	human_spatial_fixture_late_actor = H
	spawn(0)
		H.human_subtile_travel(get_step(H, EAST), EAST, world.time + 400)
	var/deadline = world.time + 60
	while((!H.human_subtile_transaction || !H.step_x) && world.time < deadline) sleep(world.tick_lag)
	human_spatial_fixture_assert(H.human_subtile_transaction && H.step_x, "fixture_late_walk_not_started")

/proc/human_spatial_fixture_wait_late_pulse()
	var/deadline = world.time + 60
	while(!human_spatial_fixture_late_pulses && world.time < deadline) sleep(world.tick_lag)
	human_spatial_fixture_assert(human_spatial_fixture_late_pulses > 0 && persistence_save_in_progress, "fixture_late_walk_did_not_continue")

// This actor is first reached by its chair's serialized buckle reference.
// Move it only after its legacy entry is complete and before the turf drain.
/proc/human_spatial_fixture_move_saved_seated(mob/living/human/H)
	human_spatial_fixture_assert(!human_spatial_fixture_seated_moved && H && H.buckled, "fixture_seated_reference_first")
	var/obj/seat = H.buckled
	human_spatial_fixture_assert(seat.unbuckle_mob() == H, "fixture_seated_unbuckle")
	H.forceMove(locate(12, 6, 1))
	human_spatial_fixture_assert(H.x == 12 && H.y == 6, "fixture_seated_move")
	human_spatial_fixture_seated_moved++

// Called only from the staged test build before candidate inspection. These
// controls corrupt a synthetic candidate, never a completed seed generation.
/proc/human_spatial_fixture_mutate_candidate(datum/persistence_world_operation/operation)
	if(!(human_spatial_fixture_case in list("duplicate", "missing_roster", "unsafe_default"))) return
	human_spatial_fixture_assert(operation && operation.human_spatial_requests.len == 1, "fixture_mutation_request")
	if(human_spatial_fixture_case == "missing_roster")
		operation.human_roster_records = list()
		return
	var/datum/human_subtile_save_request/request = operation.human_spatial_requests[1]
	var/savefile/F = new("map_saves/[request.saved_z].sav")
	if(human_spatial_fixture_case == "duplicate")
		var/other_ref = F["/map/[request.saved_z]/3/3"]
		var/path = "[map_storage.entry_path(F, other_ref)]/content"
		var/list/chunks = F[path]
		human_spatial_fixture_assert(islist(chunks), "fixture_duplicate_parent")
		chunks += list2params(list("[request.saved_ref]"))
		F[path] << chunks
	else
		F["[map_storage.entry_path(F, request.saved_ref)]/bound_width"] << list("kind" = "value", "value" = null)
	F.Flush()

/world/New()
	var/initial_native_port = port
	OpenPort("none")
	var/error = null
	var/list/observed = list("phase" = world.params["phase"], "head" = world.params["tested_commit"], "byond_version" = byond_version, "byond_build" = byond_build, "initial_native_port" = initial_native_port, "port" = port)
	try
		human_spatial_fixture_assert(!port && byond_version == 516 && byond_build == 1688, "fixture_engine_or_port")
		human_subtile_fixture_initialize()
		if(world.params["phase"] == "writer")
			var/mob/living/human/H = new(locate(1, 1, 1))
			H.persistence_owner_ckey = "syntheticfixture"
			var/mob/living/human/H2 = new(locate(3, 1, 1))
			H2.persistence_owner_ckey = "syntheticsecond"
			var/obj/structure/bed/chair/seat = new(locate(6, 6, 1))
			var/mob/living/human/seated = new(locate(6, 6, 1))
			seated.persistence_owner_ckey = "syntheticseated"
			human_spatial_fixture_assert(seat.buckle_mob(seated), "fixture_seated_setup")
			var/obj/structure/closet/crate/box = new(locate(8, 6, 1))
			var/mob/living/human/contained = new(box)
			contained.persistence_owner_ckey = "syntheticcontained"
			H.canmove = TRUE
			H.stat = CONSCIOUS
			human_spatial_fixture_assert(H.set_human_subtile(TRUE), "fixture_enable_movement")
			var/obj/item/weapon/storage/backpack/B = new(H)
			H.back = B
			var/obj/item/weapon/pen/nested = new(B)
			nested.name = "synthetic nested pen"
			var/turf/candidate_floor = locate(2, 2, 1)
			candidate_floor.ChangeTurf(/turf/floor/winter/grass/human_spatial_probe)
			new /obj/item/weapon/flint/human_spatial_probe(locate(2, 2, 1))
			human_spatial_fixture_authorized = TRUE
			spawn(0)
				H.human_subtile_travel(get_step(H, NORTHEAST), NORTHEAST, world.time + 80)
			var/deadline = world.time + 20
			while((!H.human_subtile_transaction || !H.step_x || !H.step_y) && world.time < deadline) sleep(world.tick_lag)
			human_spatial_fixture_assert(H.human_subtile_transaction && H.step_x && H.step_y, "fixture_transaction_not_started")
			if(world.params["mode"] == "restart")
				persistence_restart.busy = TRUE
				var/datum/persistence_world_operation/op = begin_persistence_operation(map_storage, "save", persistence_restart)
				human_spatial_fixture_assert(op && op.restart_transaction == persistence_restart && human_subtile_save_motion_allowed(), "fixture_restart_owner")
				try
					human_spatial_fixture_assert(map_storage.run_world_operation("save", op), "fixture_restart_save_failed")
					op.finish(TRUE)
				catch(var/exception/restart_error)
					map_storage.cleanup_world_operation()
					op.finish(FALSE)
					throw restart_error
				persistence_restart.busy = FALSE
			else
				human_spatial_fixture_assert(map_storage.Save_World(), "fixture_save_failed")
			human_spatial_fixture_assert(human_spatial_fixture_handoffs == 1 && human_spatial_fixture_pulses_after > 0, "fixture_handoff_or_continuation_missing")
			human_spatial_fixture_assert(islist(human_spatial_fixture_capsule) && human_spatial_fixture_capsule.len == 5, "fixture_capsule_missing")
			human_spatial_fixture_assert(islist(human_spatial_fixture_late_capsule) && human_spatial_fixture_late_pulses > 0, "fixture_late_walker_not_captured")
			human_spatial_fixture_assert(human_spatial_fixture_seated_moved == 1, "fixture_seated_did_not_move")
			var/marker = trim(file2text("map_saves/save_complete.txt"))
			human_spatial_fixture_assert(length(marker) > 0, "fixture_marker_missing")
			observed["generation"] = marker
			observed["transaction_observed"] = TRUE
			observed["handoffs"] = human_spatial_fixture_handoffs
			observed["pulses_after_handoff"] = human_spatial_fixture_pulses_after
			observed["capsule"] = human_spatial_fixture_capsule
			observed["late_capsule"] = human_spatial_fixture_late_capsule
			observed["late_pulses"] = human_spatial_fixture_late_pulses
			observed["geometry_metrics"] = human_spatial_fixture_geometry_metrics
			observed["seated_moved"] = human_spatial_fixture_seated_moved
			observed["mode"] = world.params["mode"]
		else if(world.params["phase"] == "reader")
			var/list/expected = json_decode(file2text("human-spatial-expected.json"))
			human_spatial_fixture_assert(islist(expected) && islist(expected["capsule"]) && expected["generation"] == trim(file2text("map_saves/save_complete.txt")), "fixture_expected_generation")
			human_spatial_fixture_assert(map_storage.Load_World(), "fixture_load_failed")
			var/list/bodies = persistence_restored_bodies["syntheticfixture"]
			human_spatial_fixture_assert(islist(bodies) && bodies.len == 1, "fixture_body_missing")
			var/mob/living/human/H = bodies[1]
			human_spatial_fixture_assert(H && H.type == /mob/living/human && istype(H.back, /obj/item/weapon/storage/backpack), "fixture_owner_or_slot")
			var/list/other_bodies = persistence_restored_bodies["syntheticsecond"]
			human_spatial_fixture_assert(islist(other_bodies) && other_bodies.len == 1, "fixture_second_body_missing")
			var/mob/living/human/H2 = other_bodies[1]
			human_spatial_fixture_assert(H2 && H2.x == 3 && H2.y == 1 && H2.z == 1 && !H2.step_x && !H2.step_y, "fixture_second_body_position")
			var/list/seated_bodies = persistence_restored_bodies["syntheticseated"]
			var/list/contained_bodies = persistence_restored_bodies["syntheticcontained"]
			var/list/late_bodies = persistence_restored_bodies["syntheticlate"]
			human_spatial_fixture_assert(islist(seated_bodies) && seated_bodies.len == 1 && islist(contained_bodies) && contained_bodies.len == 1 && islist(late_bodies) && late_bodies.len == 1, "fixture_legacy_or_late_missing")
			var/mob/living/human/restored_seated = seated_bodies[1]
			var/mob/living/human/restored_contained = contained_bodies[1]
			var/mob/living/human/restored_late = late_bodies[1]
			human_spatial_fixture_assert(istype(restored_seated.buckled, /obj/structure/bed/chair) && restored_seated.buckled:buckled_mob == restored_seated && restored_seated.loc == restored_seated.buckled:loc && restored_seated.x == 6 && restored_seated.y == 6 && istype(restored_contained.loc, /obj/structure/closet/crate), "fixture_legacy_parent_and_link")
			human_spatial_fixture_assert(human_subtile_same(restored_late.human_subtile_snapshot(), expected["late_capsule"]), "fixture_late_exact_capsule")
			var/obj/item/weapon/pen/P = locate(/obj/item/weapon/pen) in H.back
			human_spatial_fixture_assert(P && P.loc == H.back && H.back.loc == H && P.name == "synthetic nested pen", "fixture_nested_item_or_slot")
			var/turf/restored_floor = locate(2, 2, 1)
			var/obj/item/weapon/flint/restored_flint = locate(/obj/item/weapon/flint) in restored_floor
			human_spatial_fixture_assert(restored_floor.type == /turf/floor/winter/grass/human_spatial_probe && restored_flint && restored_flint.loc == restored_floor, "fixture_audited_floor_and_tool")
			human_spatial_fixture_assert(human_subtile_same(H.human_subtile_snapshot(), expected["capsule"]), "fixture_exact_frozen_capsule")
			human_spatial_fixture_assert(human_spatial_fixture_direct_actor && !human_spatial_fixture_direct_active && !human_spatial_fixture_direct_callbacks && human_spatial_fixture_restore_living == 2 && human_spatial_fixture_restore_human == 2, "fixture_restore_callbacks")
			observed["position"] = H.human_subtile_snapshot()
			observed["late_position"] = restored_late.human_subtile_snapshot()
			observed["generation"] = trim(file2text("map_saves/save_complete.txt"))
		else if(world.params["phase"] == "drag")
			var/mob/living/human/H = new(locate(2, 2, 1))
			var/obj/item/weapon/pen/P = new(locate(1, 2, 1))
			var/mob/living/human/no_seam = new(locate(8, 8, 1))
			var/obj/item/weapon/pen/no_seam_pen = new(locate(7, 8, 1))
			H.canmove = TRUE
			H.stat = CONSCIOUS
			human_spatial_fixture_assert(H.set_human_subtile(TRUE), "fixture_drag_enable")
			H.pulling = P
			P.pulledby = H
			human_spatial_fixture_drag_actor = H
			human_spatial_fixture_authorized = TRUE
			var/datum/persistence_world_operation/op = begin_persistence_operation(map_storage, "save")
			human_spatial_fixture_assert(op && human_subtile_save_motion_allowed(), "fixture_drag_admission")
			human_spatial_fixture_assert(H.human_subtile_travel(get_step(H, EAST), EAST, world.time + 20), "fixture_drag_travel")
			human_spatial_fixture_assert(H.x == 3 && P.x == 2 && H.pulling == P && P.pulledby == H, "fixture_drag_follower")
			human_spatial_fixture_assert(human_spatial_fixture_living_completions == 1 && human_spatial_fixture_human_completions == 1, "fixture_drag_completion_count")
			// A different headless body has no seam and must take production's
			// no-client stop-pulling path. This is not a connected-client test.
			no_seam.pulling = no_seam_pen
			no_seam_pen.pulledby = no_seam
			no_seam.Move(get_step(no_seam, EAST), EAST)
			human_spatial_fixture_assert(!no_seam.pulling && no_seam_pen.x == 7, "fixture_unadapted_headless_control")
			var/datum/subtile_pull_pair/fake = new
			subtile_pull_ownership.owners[H] = fake
			human_spatial_fixture_assert(!H.human_subtile_input_supported(EAST), "fixture_owned_leader_fallback")
			subtile_pull_ownership.owners -= H
			subtile_pull_ownership.owners[P] = fake
			human_spatial_fixture_assert(!H.human_subtile_input_supported(EAST) && !H.human_subtile_ready(EAST), "fixture_owned_follower_fallback")
			subtile_pull_ownership.owners -= P
			human_spatial_fixture_assert(op.withdraw(), "fixture_drag_release")
			observed["living_completions"] = human_spatial_fixture_living_completions
			observed["human_completions"] = human_spatial_fixture_human_completions
		else if(world.params["phase"] == "negative")
			human_spatial_fixture_case = world.params["case"]
			var/previous = trim(file2text("map_saves/save_complete.txt"))
			human_spatial_fixture_assert(length(previous) > 0, "fixture_negative_seed_missing")
			var/mob/living/human/H = new(locate(1, 1, 1))
			H.persistence_owner_ckey = "syntheticfixture"
			H.canmove = TRUE
			H.stat = CONSCIOUS
			human_spatial_fixture_assert(H.set_human_subtile(TRUE), "fixture_negative_enable")
			H.step_x = 4
			H.step_y = 4
			var/expected = null
			switch(human_spatial_fixture_case)
				if("wall")
					var/turf/T = locate(2, 2, 1)
					T.ChangeTurf(/turf/wall, FALSE, FALSE)
					expected = "Human saved turf type is not audited"
				if("dense")
					var/obj/structure/closet/crate/overhang = new(locate(3, 2, 1))
					overhang.bound_x = -32
					expected = "Human saved footprint has a hard or unaudited occupant"
				if("contained")
					var/obj/structure/closet/crate/C = new(locate(3, 3, 1))
					H.forceMove(C)
					expected = "Human legacy save needs an aligned idle position"
				if("buckle")
					H.buckled = new /obj/structure/bed/chair(locate(1, 1, 1))
					expected = "Human legacy save needs an aligned idle position"
				if("roster")
					expected = "Human roster proof has no stable owner"
				if("pulling")
					var/obj/item/weapon/pen/P = new(locate(2, 2, 1))
					H.pulling = P
					P.pulledby = H
					expected = "Human legacy save needs an aligned idle position"
				if("duplicate")
					expected = "Human slot candidate has duplicate saved parents"
				if("missing_roster")
					expected = "Human roster proof changed before completion"
				if("unsafe_default")
					expected = "Human saved size is unsupported"
				else
					throw EXCEPTION("fixture_negative_case_unknown")
			var/rejection = null
			try
				if(map_storage.Save_World()) throw EXCEPTION("fixture_negative_unexpected_success")
			catch(var/exception/rejected)
				rejection = rejected.name
			human_spatial_fixture_assert(rejection == expected, "fixture_negative_wrong_rejection")
			var/current_exists = fexists("map_saves/save_complete.txt")
			var/current = current_exists ? trim(file2text("map_saves/save_complete.txt")) : null
			var/backup = trim(file2text("map_backups/save_complete.txt"))
			human_spatial_fixture_assert(!current_exists || current == previous, "fixture_negative_published_new_marker")
			human_spatial_fixture_assert(current == previous || backup == previous, "fixture_negative_previous_generation_lost")
			observed["case"] = human_spatial_fixture_case
			observed["rejection"] = rejection
			observed["previous_generation"] = previous
		else
			throw EXCEPTION("fixture_phase_unknown")
	catch(var/exception/E)
		error = E.name
	observed["error"] = error
	text2file(json_encode(observed), "human-spatial-[world.params["phase"]].json")
	if(error) world.log << "FAIL: [error]"
	del(world)
	return
