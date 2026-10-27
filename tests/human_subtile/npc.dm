// Prepared native acceptance, not automatically executed by the walking lane.
// No fake clients or authority override: actual unowned Omar subtype and Move.
var/npc_subtile_checks = 0
var/list/npc_subtile_rows = list()

/mob/living/simple_animal/npc_vendor/smuggler/subtile_fixture
	var/fixture_pulses = 0
	var/fixture_hooks = 0
	var/fixture_cancel_after = 0
	var/list/fixture_rows = list()

/mob/living/simple_animal/npc_vendor/smuggler/subtile_fixture/persistence_runtime_var(key)
	return copytext(key, 1, 9) == "fixture_" || ..()

/mob/living/simple_animal/npc_vendor/smuggler/subtile_fixture/Move()
	var/owns = npc_subtile_pulse && npc_subtile_pulse.armed
	. = ..()
	if (owns && npc_subtile_pulse)
		fixture_pulses++
		if (fixture_rows.len >= 16)
			throw EXCEPTION("NPC observation bound")
		fixture_rows += list(list("at" = world.time, "x" = x, "y" = y, "sx" = step_x, "sy" = step_y, "native" = npc_subtile_pulse.engine_return))
		if (fixture_cancel_after && fixture_pulses >= fixture_cancel_after)
			stunned = 1

/mob/living/simple_animal/npc_vendor/smuggler/subtile_fixture/living_movement_completed()
	fixture_hooks++
	return ..()

/proc/npc_subtile_assert(ok, label)
	npc_subtile_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/npc_subtile_fixture()
	for (var/direction in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
		var/mob/living/simple_animal/npc_vendor/smuggler/subtile_fixture/N = new(locate(5, 5, 1))
		var/turf/goal = get_step(N, direction)
		var/old_glide = N.glide_size
		var/started = world.time
		npc_subtile_assert(!N.client && N.npc_subtile_enabled && N.ai_step(goal, 4), "npc_admitted_[direction]")
		npc_subtile_assert(N.npc_subtile_transaction && N.fixture_pulses == 1 && !N.ai_step(goal, 4), "npc_first_pulse_and_no_second_worker_[direction]")
		sleep(5)
		npc_subtile_assert(N.loc == goal && !N.step_x && !N.step_y && N.fixture_pulses == 16 && N.fixture_hooks == 1, "npc_distance_hooks_[direction]")
		npc_subtile_assert(!N.npc_subtile_transaction && !N.npc_subtile_pulse && N.glide_size == old_glide && N.npc_subtile_until == started + 4, "npc_deadline_cleanup_[direction]")
		npc_subtile_rows += list(list("direction" = direction, "started" = started, "deadline" = N.npc_subtile_until, "pulses" = N.fixture_rows))
		qdel(N)
	var/mob/living/simple_animal/npc_vendor/smuggler/subtile_fixture/C = new(locate(5, 8, 1))
	C.fixture_cancel_after = 3
	npc_subtile_assert(C.ai_step(get_step(C, EAST), 4), "npc_cancel_admitted")
	sleep(5)
	npc_subtile_assert(C.x == 5 && C.step_x == 6 && C.npc_subtile_offset_owned && C.fixture_pulses == 3 && C.fixture_hooks == 1 && !C.npc_subtile_transaction, "npc_cancel_retains_physical_offset")
	C.stunned = 0
	C.fixture_cancel_after = 0
	C.fixture_pulses = 0
	C.fixture_rows = list()
	C.fixture_hooks = 0
	npc_subtile_assert(!C.set_npc_subtile(FALSE), "npc_offset_optout_refused")
	npc_subtile_assert(C.ai_step(get_step(C, WEST), 4), "npc_reverse_admitted")
	sleep(5)
	npc_subtile_assert(C.x == 5 && !C.step_x && C.fixture_pulses == 3 && C.fixture_hooks == 1 && !C.npc_subtile_transaction, "npc_reverse_recovers_without_snap")
	npc_subtile_assert(C.set_npc_subtile(FALSE), "npc_aligned_optout")
	C.fixture_hooks = 0
	npc_subtile_assert(C.ai_step(get_step(C, EAST), 4) && C.x == 6 && !C.step_x && C.fixture_hooks == 1 && !C.npc_subtile_transaction, "npc_optout_legacy")
	qdel(C)
	var/mob/living/simple_animal/npc_vendor/smuggler/subtile_fixture/B = new(locate(5, 8, 1))
	var/turf/blocked = locate(6, 8, 1)
	blocked.density = TRUE
	npc_subtile_assert(!B.ai_step(blocked, 4), "npc_blocked_returns_false")
	npc_subtile_assert(B.x == 5 && !B.step_x && B.fixture_hooks == 1 && !B.npc_subtile_transaction, "npc_blocked_once_only_hook")
	blocked.density = FALSE
	qdel(B)
	var/mob/living/simple_animal/npc_vendor/smuggler/subtile_fixture/S = new(locate(5, 8, 1))
	S.fixture_cancel_after = 3
	npc_subtile_assert(S.ai_step(get_step(S, EAST), 4), "npc_save_partial_admitted")
	sleep(5)
	S.stunned = 0
	S.fixture_cancel_after = 0
	var/savefile/F = new("npc-subtile-owned.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, S, 1)
	var/entry = map_storage.entry_path(F, ref)
	F.cd = entry
	npc_subtile_assert(("npc_subtile_position" in F.dir) && !("step_x" in F.dir) && !("npc_subtile_transaction" in F.dir), "npc_codec_runtime_exclusion")
	F["[entry]/step_x"] << list("kind" = "value", "value" = 31)
	F.Flush()
	S.forceMove(locate(16, 12, 1))
	map_storage.clear_bookkeeping()
	var/mob/living/simple_animal/npc_vendor/smuggler/subtile_fixture/L = map_storage.Load_Entry(F, ref, starting_loc = locate(5, 8, 1))
	L.after_load()
	npc_subtile_assert(L.x == 5 && L.step_x == 6 && L.npc_subtile_offset_owned && !L.npc_subtile_transaction && !L.npc_subtile_pulse, "npc_actual_codec_owned_offset")
	L.fixture_pulses = 0
	L.fixture_rows = list()
	npc_subtile_assert(L.ai_step(get_step(L, WEST), 4), "npc_restored_recovery_admitted")
	sleep(5)
	npc_subtile_assert(!L.step_x && L.x == 5 && !L.npc_subtile_transaction, "npc_restored_recovery_aligned")
	qdel(L)
	qdel(S)
	text2file(json_encode(list("head" = world.params["tested_commit"], "checks" = npc_subtile_checks, "rows" = npc_subtile_rows)), "npc-receipt.json")
