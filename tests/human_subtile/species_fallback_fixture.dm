// Fixture only: merged crab Life and mosquito species helper; no mob scheduler.
// The staged DME must bind this file and every production input exactly.
var/global/list/species_fallback_rows = list()
var/global/list/species_fallback_events = list()
var/global/mob/living/simple_animal/species_fallback_subject
var/global/species_fallback_checks = 0
var/global/species_fallback_id = 0
var/global/species_fallback_case = null
var/global/species_fallback_completions = 0

/proc/species_fallback_assert(condition, label)
	species_fallback_checks++
	if (!condition)
		throw EXCEPTION("species_fallback_[label]")

/mob/living/simple_animal/proc/species_fallback_record(event, list/detail = null)
	if (src != species_fallback_subject)
		return
	if (species_fallback_events.len >= 512)
		throw EXCEPTION("species_fallback_event_overflow")
	species_fallback_events += list(list("event" = event, "time" = world.time, "case" = species_fallback_case, \
		"id" = species_fallback_id, "x" = x, "y" = y, "z" = z, "sx" = step_x, "sy" = step_y, \
		"enabled" = !!npc_subtile_enabled, "species_enabled" = !!npc_subtile_species_enabled, \
		"owned" = !!npc_subtile_offset_owned, "transaction" = !!npc_subtile_transaction, \
		"pulse" = !!npc_subtile_pulse, "wild" = !!npc_subtile_wild_walk, \
		"generation" = move_gen, "until" = npc_subtile_until, "tick_lag" = world.tick_lag, "ticks" = world.tick_usage, \
		"health" = health, "turns" = turns_since_move, "bx" = bound_x, "by" = bound_y, \
		"bw" = bound_width, "bh" = bound_height, "step_size" = step_size, "locs" = locs.len, \
		"map_x" = world.maxx, "map_y" = world.maxy, "icon_size" = world.icon_size, "detail" = detail))

/mob/living/simple_animal/crab/species_fallback_probe/Move()
	species_fallback_record("move_before")
	. = ..()
	species_fallback_record("move_after")

/mob/living/simple_animal/crab/species_fallback_probe/living_movement_completed()
	. = ..()
	species_fallback_completions++
	species_fallback_record("completion")

// Fixture-only wrappers record admission calls even if no physical Move follows.
/mob/living/simple_animal/mosquito/species_fallback_probe/npc_subtile_start_wild_walk(mode, atom/target, interval, direction, distance_limit)
	species_fallback_record("wild_before")
	. = ..()
	species_fallback_record("wild_after")

/mob/living/simple_animal/mosquito/species_fallback_probe/ai_step(turf/destination, interval, pulse_only = FALSE, list/receipt = null, datum/intent_owner = null)
	species_fallback_record("step_before")
	. = ..()
	species_fallback_record("step_after")

/mob/living/simple_animal/mosquito/species_fallback_probe/Move()
	species_fallback_record("move_before")
	. = ..()
	species_fallback_record("move_after")

/mob/living/simple_animal/mosquito/species_fallback_probe/living_movement_completed()
	. = ..()
	species_fallback_completions++
	species_fallback_record("completion")

/proc/species_fallback_begin(mob/living/simple_animal/A, label)
	species_fallback_id++
	species_fallback_subject = A
	species_fallback_case = label
	species_fallback_events = list()
	species_fallback_completions = 0
	species_fallback_assert(A && !A.client && !A.stat && !A.npc_subtile_enabled && A.npc_subtile_shape() && !A.npc_subtile_transaction && \
		!A.npc_subtile_pulse && !A.step_x && !A.step_y && !A.npc_subtile_wild_walk, "clean_start_[label]")
	for (var/xpos = A.x - 1, xpos <= A.x + 5, xpos++)
		for (var/ypos = A.y - 1, ypos <= A.y + 1, ypos++)
			var/turf/T = locate(xpos, ypos, A.z)
			species_fallback_assert(T && !T.density, "clear_turf_[label]")
			for (var/atom/movable/M in T)
				species_fallback_assert(M == A || !M.density, "clear_contents_[label]")
	A.species_fallback_record("start")

// Sample each engine tick and reject quiet-period owner reacquisition.
// Fixture wrappers also trace admissions that start and finish within a tick.
/proc/species_fallback_quiet(mob/living/simple_animal/A, label)
	var/start = world.time
	var/px = A.x * 32 + A.step_x
	var/py = A.y * 32 + A.step_y
	while (world.time < start + 4)
		sleep(world.tick_lag)
		A.species_fallback_record("quiet_sample")
		species_fallback_assert(!A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_wild_walk && A.x * 32 + A.step_x == px && A.y * 32 + A.step_y == py, "quiet_[label]")

/proc/species_fallback_end(mob/living/simple_animal/A, label)
	A.species_fallback_record("end")
	species_fallback_rows += list(list("case" = label, "id" = species_fallback_id, \
		"events" = species_fallback_events.Copy(), "completions" = species_fallback_completions))
	species_fallback_subject = null
	species_fallback_case = null
	qdel(A)
	species_fallback_assert(QDELETED(A), "actor_deleted_[label]")

/proc/species_fallback_crab(enabled)
	var/label = enabled ? "crab_mixed" : "crab_legacy"
	var/mob/living/simple_animal/crab/species_fallback_probe/A = new(locate(6, 5, 1))
	species_fallback_begin(A, label)
	A.npc_subtile_species_enabled = enabled
	A.turns_since_move = A.move_to_delay - 1
	var/before = A.x * 32 + A.step_x
	A.species_fallback_record("life_before")
	A.Life()
	A.species_fallback_record("life_after")
	var/dx = A.x * 32 + A.step_x - before
	species_fallback_assert(abs(dx) == 32 && !A.step_y && !A.npc_subtile_transaction && \
		!A.npc_subtile_pulse && !A.turns_since_move, "crab_real_move_[label]")
	species_fallback_end(A, label)

/proc/species_fallback_native(enabled)
	var/label = enabled ? "mosquito_mixed" : "mosquito_legacy"
	var/mob/living/simple_animal/mosquito/species_fallback_probe/A = new(locate(6, 8, 1))
	species_fallback_begin(A, label)
	A.npc_subtile_species_enabled = enabled
	var/before = A.x * 32 + A.step_x
	A.species_fallback_record("command_before")
	A.npc_subtile_species_walk("direction", null, 3, EAST)
	A.species_fallback_record("command_after")
	sleep(7)
	A.species_fallback_record("before_stop")
	walk(A, 0)
	var/stopped = A.x * 32 + A.step_x
	A.species_fallback_record("after_stop")
	species_fallback_quiet(A, "after_stop")
	species_fallback_assert(stopped > before && stopped == A.x * 32 + A.step_x && \
		!A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_wild_walk, "native_walk_[label]")
	species_fallback_end(A, label)

/proc/species_fallback_setter()
	var/mob/living/simple_animal/mosquito/species_fallback_probe/A = new(locate(6, 11, 1))
	species_fallback_begin(A, "setter")
	A.npc_subtile_enabled = TRUE
	A.npc_subtile_species_enabled = TRUE
	species_fallback_assert(A.npc_subtile_species_walk("direction", null, 4, EAST), "owner_admitted")
	var/datum/npc_subtile_wild_walk/old = A.npc_subtile_wild_walk
	species_fallback_assert(old && !A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.step_x && !A.step_y, "owner_aligned_window")
	A.species_fallback_record("before_disable", list("owner_generation" = old.generation, "owner_revision" = old.revision))
	species_fallback_assert(A.set_npc_subtile(FALSE) && old.cancelled && !A.npc_subtile_wild_walk, "owner_retired")
	A.species_fallback_record("after_disable", list("old_cancelled" = !!old.cancelled, "owner_generation" = old.generation, "owner_revision" = old.revision))
	var/before = A.x * 32 + A.step_x
	A.npc_subtile_species_walk("direction", null, 3, EAST)
	sleep(7)
	walk(A, 0)
	var/stopped = A.x * 32 + A.step_x
	A.species_fallback_record("replacement_stop")
	species_fallback_quiet(A, "replacement_stop")
	species_fallback_assert(stopped > before && stopped == A.x * 32 + A.step_x && \
		!A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_wild_walk, "replacement_survives")
	species_fallback_end(A, "setter")

/proc/species_fallback_partial()
	var/mob/living/simple_animal/mosquito/species_fallback_probe/A = new(locate(6, 11, 1))
	species_fallback_begin(A, "partial")
	A.npc_subtile_enabled = TRUE
	A.npc_subtile_species_enabled = TRUE
	species_fallback_assert(A.npc_subtile_species_walk("direction", null, 4, EAST), "partial_owner")
	var/deadline = world.time + 8
	while (world.time < deadline && (!A.npc_subtile_transaction || !A.npc_subtile_offset_owned || !A.step_x))
		sleep(world.tick_lag)
	var/datum/npc_subtile_wild_walk/W = A.npc_subtile_wild_walk
	species_fallback_assert(W && A.npc_subtile_transaction && A.npc_subtile_offset_owned && A.step_x, "partial_observed")
	A.species_fallback_record("partial_before", list("owner_generation" = W.generation, "owner_revision" = W.revision))
	species_fallback_assert(!A.set_npc_subtile(FALSE) && A.npc_subtile_wild_walk == W && \
		A.npc_subtile_enabled, "partial_disable_refused")
	A.species_fallback_record("partial_after", list("owner_generation" = W.generation, "owner_revision" = W.revision))
	// Fault injection models an external flag mutation the safe setter refuses.
	// It changes no geometry and must not authorize a competing native walker.
	var/datum/npc_subtile_transaction/old_tx = A.npc_subtile_transaction
	var/old_x = A.x * 32 + A.step_x
	A.npc_subtile_enabled = FALSE
	A.species_fallback_record("fault_base_off")
	var/legacy_result = A.npc_subtile_species_walk("direction", null, 3, WEST)
	A.species_fallback_record("fallback_refused", list("result" = !!legacy_result, "same_owner" = (A.npc_subtile_wild_walk == W), "same_tx" = (A.npc_subtile_transaction == old_tx)))
	species_fallback_assert(!legacy_result && A.npc_subtile_wild_walk == W && A.npc_subtile_transaction == old_tx && A.x * 32 + A.step_x == old_x, "partial_legacy_refused")
	A.npc_subtile_stop_wild_walk()
	deadline = world.time + 12
	while (world.time < deadline && (A.npc_subtile_transaction || A.npc_subtile_pulse))
		sleep(world.tick_lag)
	var/stopped = A.x * 32 + A.step_x
	A.species_fallback_record("partial_stopped")
	species_fallback_quiet(A, "partial_stopped")
	species_fallback_assert(!A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_wild_walk && \
		A.x * 32 + A.step_x == stopped && species_fallback_completions == 1, "partial_terminal")
	species_fallback_end(A, "partial")

/proc/species_fallback_main()
	species_fallback_assert(world.params["fallback_tick"] == "0.5", "requested_tick")
	world.tick_lag = 0.5
	species_fallback_assert(world.tick_lag == 0.5 && !processScheduler && !living_mob_list.len, "startup")
	var/start = world.time
	sleep(world.tick_lag)
	species_fallback_assert(world.time > start && world.tick_lag == 0.5, "ready")
	species_fallback_rows = list()
	species_fallback_crab(FALSE)
	species_fallback_crab(TRUE)
	species_fallback_native(FALSE)
	species_fallback_native(TRUE)
	species_fallback_setter()
	species_fallback_partial()
	species_fallback_assert(species_fallback_rows.len == 6, "all_cases")
