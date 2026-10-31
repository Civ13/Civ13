// Explicit full-source fixture, NOT included by the existing DME or smoke job.
// Direct Enter probes a Civ13 exit-check seam; it is not a real movement test.
var/large_border_checks = 0
var/list/large_border_rows = list()

/obj/large_border_observe
	flags = ON_BORDER
	density = FALSE
	var/fixture_exit_calls = 0

/obj/large_border_observe/CheckExit(atom/movable/mover as mob|obj, target as turf)
	fixture_exit_calls++
	return FALSE

// Bump is suppressed solely to keep the direct Enter experiment observational.
// It therefore does not validate actual Bump, pushes or native movement order.
/mob/living/simple_animal/hostile/mammoth/large_border_observe
	npc_subtile_enabled = FALSE
	stop_automated_movement = TRUE

/mob/living/simple_animal/hostile/mammoth/large_border_observe/Bump(atom/obstacle)
	return

/mob/living/simple_animal/hostile/dinosaur/trex/large_border_observe
	npc_subtile_enabled = FALSE
	stop_automated_movement = TRUE

/mob/living/simple_animal/hostile/dinosaur/trex/large_border_observe/Bump(atom/obstacle)
	return

/proc/large_border_assert(ok, label)
	large_border_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/large_border_fixture()
	for (var/animal_type in list(/mob/living/simple_animal/hostile/mammoth/large_border_observe, /mob/living/simple_animal/hostile/dinosaur/trex/large_border_observe))
		for (var/bound_variant in list(0, 64))
			var/mob/living/simple_animal/hostile/A = new animal_type(locate(9, 7, 1))
			A.bound_x = bound_variant
			var/turf/anchor = A.loc
			var/turf/destination = locate(2, 2, 1)
			var/turf/remote = null
			var/list/occupied = list()
			for (var/turf/T in A.locs)
				occupied += list(list("x" = T.x, "y" = T.y, "z" = T.z, "in_contents" = (A in T.contents)))
				if (T != anchor && T != destination && !remote)
					remote = T
			large_border_assert(!A.npc_subtile_enabled && !A.npc_subtile_shape(), "large_body_stays_ineligible")
			large_border_assert(remote && occupied.len > 1, "large_body_has_remote_occupied_turf")
			var/list/before = A.npc_subtile_snapshot()
			var/baseline = destination.Enter(A, null)
			var/obj/large_border_observe/R = new(remote)
			var/remote_result = destination.Enter(A, null)
			var/remote_calls = R.fixture_exit_calls
			var/obj/large_border_observe/C = new(anchor)
			var/anchor_result = destination.Enter(A, null)
			large_border_rows += list(list("classification" = "expected_gap_characterization", "animal" = "[animal_type]", "variant" = bound_variant,
				"anchor" = list("x" = anchor.x, "y" = anchor.y), "remote" = list("x" = remote.x, "y" = remote.y),
				"occupied" = occupied, "bound_x_readback" = A.bound_x, "pixel_w" = A.vars["pixel_w"],
				"baseline" = baseline, "remote_result" = remote_result, "remote_calls" = remote_calls,
				"anchor_result" = anchor_result, "anchor_calls" = C.fixture_exit_calls))
			large_border_assert(baseline && remote_result && !remote_calls, "remote_edge_exit_not_checked_by_direct_enter")
			large_border_assert(!anchor_result && C.fixture_exit_calls == 1, "anchor_border_exit_positive_control")
			large_border_assert(human_subtile_same(before, A.npc_subtile_snapshot()), "direct_enter_does_not_move_subject")
			qdel(C)
			qdel(R)
			qdel(A)
