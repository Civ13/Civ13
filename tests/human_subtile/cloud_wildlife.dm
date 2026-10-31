// Separate minimal wildlife-owner fixture. No fake client and no Life RNG adapter.
// This is not evidence for mosquito bite probability, disease, species enabling,
// 96x96 collision, visual smoothness, or sustained gameplay.
var/cloud_wildlife_checks = 0

/mob/living/simple_animal/mosquito/cloud_fixture
	npc_subtile_enabled = TRUE
	npc_subtile_species_enabled = TRUE
	npc_subtile_recovery_enabled = TRUE

/proc/cloud_wildlife_assert(ok, label)
	cloud_wildlife_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/cloud_wildlife_fixture()
	var/mob/living/simple_animal/mosquito/cloud_fixture/M = new(locate(5, 5, 1))
	cloud_wildlife_assert(!M.client && M.npc_subtile_ready(), "wildlife_fixture_admitted_shape")
	cloud_wildlife_assert(M.npc_subtile_species_walk("direction", null, 2, EAST), "wildlife_owner_accepted")
	var/limit = world.time + 4
	while (!M.npc_subtile_transaction && world.time < limit)
		sleep(world.tick_lag)
	cloud_wildlife_assert(M.npc_subtile_transaction && !M.npc_subtile_contact_settled(), "wildlife_partial_contact_denied")
	sleep(4)
	cloud_wildlife_assert(M.npc_subtile_wild_walk, "wildlife_owner_remains_active")
	var/list/at_window = M.npc_subtile_snapshot()
	sleep(3)
	cloud_wildlife_assert(!human_subtile_same(at_window, M.npc_subtile_snapshot()), "wildlife_moves_without_life_tick")
	at_window = M.npc_subtile_snapshot()
	sleep(3)
	cloud_wildlife_assert(!human_subtile_same(at_window, M.npc_subtile_snapshot()), "wildlife_continues_without_life_tick")
	M.npc_subtile_stop_wild_walk()
	qdel(M)

	var/mob/living/simple_animal/mosquito/cloud_fixture/C = new(locate(5, 8, 1))
	cloud_wildlife_assert(C.npc_subtile_species_walk("direction", null, 2, EAST), "wildlife_cancel_owner_accepted")
	limit = world.time + 4
	while (!C.npc_subtile_transaction && world.time < limit)
		sleep(world.tick_lag)
	cloud_wildlife_assert(C.npc_subtile_transaction && C.npc_subtile_offset_owned && (C.step_x || C.step_y), "wildlife_cancel_partial")
	C.behaviour = "hunt"
	C.stunned = 1
	sleep(4)
	cloud_wildlife_assert(!C.npc_subtile_pending_intent && !C.npc_subtile_wild_walk, "wildlife_changed_semantics_not_requeued")
	qdel(C)
