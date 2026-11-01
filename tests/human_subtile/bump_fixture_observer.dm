// Fixture-only observations. Not included in a production DME or any runner.
// The scenario driver and host receipt bridge are not yet implemented.
var/global/fixture_bump_running = FALSE
var/global/fixture_bump_overflow = FALSE
var/global/list/fixture_bump_events = list()
var/global/list/fixture_bump_human_admissions = list()
var/global/list/fixture_bump_animal_admissions = list()
var/global/fixture_bump_collision_id = 0
var/global/mob/living/human/subtile_fixture/bump_probe/fixture_bump_human
var/global/mob/living/simple_animal/goat/bump_probe/fixture_bump_animal

/proc/fixture_bump_observe(label, mob/living/subject, atom/movable/other, tracked_id = null, latched_guard = null, datum/npc_subtile_transaction/explicit_animal_tx = null, detail = null)
	if (!fixture_bump_running || !fixture_bump_human || !fixture_bump_animal)
		return
	if (!((subject == fixture_bump_human && other == fixture_bump_animal) || (subject == fixture_bump_animal && other == fixture_bump_human)))
		return
	if (fixture_bump_events.len >= 512)
		fixture_bump_overflow = TRUE
		return
	if (label == "collision")
		fixture_bump_collision_id++
		tracked_id = fixture_bump_collision_id
	var/mob/living/human/subtile_fixture/bump_probe/H = fixture_bump_human
	var/mob/living/simple_animal/goat/bump_probe/A = fixture_bump_animal
	var/datum/human_subtile_transaction/T = H.human_subtile_transaction
	var/datum/npc_subtile_transaction/N = explicit_animal_tx ? explicit_animal_tx : A.npc_subtile_transaction
	var/datum/npc_subtile_wild_walk/W = A.npc_subtile_wild_walk
	var/admission = T ? fixture_bump_human_admissions[T] : null
	if (T && !admission)
		admission = fixture_bump_human_admissions.len + 1
		fixture_bump_human_admissions[T] = admission
	var/animal_admission = N ? fixture_bump_animal_admissions[N] : null
	if (N && !animal_admission)
		animal_admission = fixture_bump_animal_admissions.len + 1
		fixture_bump_animal_admissions[N] = animal_admission
	fixture_bump_events += list(list("kind" = label, "time" = world.time,
		"ordinal" = fixture_bump_events.len + 1, "collision_id" = tracked_id,
		"latched_guard" = latched_guard, "detail" = detail,
		"actor_lifetime" = subject == H ? 1 : 2,
		"human_admission" = admission, "human_admission_epoch" = admission,
		"human_active" = !!T, "human_offset_owned" = !!H.human_subtile_offset_owned,
		"human_x" = H.x, "human_y" = H.y, "human_z" = H.z, "human_sx" = H.step_x, "human_sy" = H.step_y,
		"animal_x" = A.x, "animal_y" = A.y, "animal_z" = A.z, "animal_sx" = A.step_x, "animal_sy" = A.step_y,
		"animal_generation" = A.move_gen, "animal_active" = !!A.npc_subtile_transaction, "animal_admission" = animal_admission,
		"animal_tx_generation" = N ? N.generation : null, "animal_tx_finished" = N ? !!N.finished : null,
		"animal_tx_attempted" = N ? !!N.attempted : null, "animal_offset_owned" = !!A.npc_subtile_offset_owned,
		"animal_wild_owner" = !!W, "animal_owner_generation" = W ? W.generation : null, "animal_pending" = !!A.npc_subtile_pending_intent,
		"human_ref" = "\ref[H]", "animal_ref" = "\ref[A]", "human_tx_ref" = T ? "\ref[T]" : null,
		"animal_tx_ref" = N ? "\ref[N]" : null))
	return tracked_id

/proc/fixture_bump_observe_actor(label, atom/movable/subject)
	if (subject == fixture_bump_human)
		fixture_bump_observe(label, fixture_bump_human, fixture_bump_animal)
	else if (subject == fixture_bump_animal)
		fixture_bump_observe(label, fixture_bump_animal, fixture_bump_human)

/mob/living/human/subtile_fixture/bump_probe/Move()
	fixture_bump_observe("human_move_before", src, fixture_bump_animal)
	. = ..()
	fixture_bump_observe("human_move_after", src, fixture_bump_animal)

/mob/living/human/subtile_fixture/bump_probe/human_movement_completed()
	fixture_bump_observe("human_completed", src, fixture_bump_animal)
	return ..()

/mob/living/human/subtile_fixture/bump_probe/living_movement_completed()
	fixture_bump_observe("human_living_completed", src, fixture_bump_animal)
	return ..()

/mob/living/simple_animal/goat/bump_probe/Move()
	fixture_bump_observe("animal_move_before", src, fixture_bump_human)
	. = ..()
	fixture_bump_observe("animal_move_after", src, fixture_bump_human)

/mob/living/human/subtile_fixture/bump_probe/Bumped(atom/movable/AM)
	fixture_bump_observe("bumped_before", src, AM)
	. = ..()
	fixture_bump_observe("bumped_after", src, AM)

/mob/living/simple_animal/goat/bump_probe/Bumped(atom/movable/AM)
	fixture_bump_observe("bumped_before", src, AM)
	. = ..()
	fixture_bump_observe("bumped_after", src, AM)

/turf/floor/plating/subtile_fixture/Exited(atom/movable/AM, atom/newloc)
	fixture_bump_observe_actor("turf_exit_before", AM)
	. = ..()
	fixture_bump_observe_actor("turf_exit_after", AM)
