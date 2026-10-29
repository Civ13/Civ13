// Unrun preparation: include only in a separately reviewed isolated full-game
// fixture with normal observation registries and already-owned staged actors.
// This proc neither starts a world nor opens a listener nor certifies pixels.
/proc/carriage_glide_fixture_check(ok, label)
	if (!ok)
		throw EXCEPTION("Carriage glide fixture: [label]")

/proc/carriage_glide_contract_probe(obj/structure/vehicle/carriage/C, mob/living/human/H, obj/structure/cargo)
	carriage_glide_fixture_check(C && H && cargo && H.loc == C.loc && cargo.loc == C.loc && !C.movement_processes, "idle owned fixture actors")
	var/turf/origin = get_turf(C)
	var/turf/destination = get_step(C, SOUTH)
	var/prior_human = H.glide_size
	var/prior_cargo = cargo.glide_size
	var/datum/carriage_glide_lease/first = new
	first.carriage = C
	C.carriage_glide = first
	// Exercise actual production human handoff, not a Python imitation.
	H.glide_size = 7
	H.human_subtile_update_visuals(4, SOUTH, null)
	carriage_glide_fixture_check(H.human_subtile_glide_owned, "walking visuals owned")
	first.claim(H, 21, SOUTH, destination)
	carriage_glide_fixture_check(!H.human_subtile_glide_owned && H.carriage_glide_previous == 7 && H.carriage_glide_owner == first, "native prior survives human handoff")
	carriage_glide_fixture_check(abs(H.glide_size - 16/21) < 0.00001, "server tick formula")
	first.release()
	carriage_glide_fixture_check(H.glide_size == 7 && !H.carriage_glide_owner && !C.carriage_glide, "owned prior restored")
	var/datum/carriage_glide_lease/second = new
	second.carriage = C
	C.carriage_glide = second
	second.claim(H, 21, SOUTH, destination)
	second.moved(null, origin, destination)
	second.destroyed(null)
	carriage_glide_fixture_check(H.carriage_glide_owner == second, "null callbacks leave live ownership intact")
	first.moved(H, origin, destination)
	first.release()
	carriage_glide_fixture_check(H.carriage_glide_owner == second && C.carriage_glide == second, "old callback cannot clear reboarded leg")
	H.glide_size = 19
	H.release_carriage_glide()
	carriage_glide_fixture_check(H.glide_size == 19, "foreign appearance writer survives cleanup")
	second.claim(cargo, 21, SOUTH, destination)
	cargo.forceMove(destination)
	carriage_glide_fixture_check(cargo.carriage_glide_owner == second && !cargo.carriage_glide_step, "real expected arrival consumes marker")
	cargo.forceMove(origin)
	carriage_glide_fixture_check(!cargo.carriage_glide_owner && cargo.glide_size == prior_cargo, "real forced removal restores cargo")
	carriage_glide_fixture_check(!GLOB.moved_event.is_listening(cargo, second) && !GLOB.destroyed_event.is_listening(cargo, second), "cargo listeners removed")
	second.claim(H, 16, EAST, get_step(C, EAST))
	carriage_glide_fixture_check(abs(H.glide_size - 1) < 0.00001 && H.dir == SOUTH, "next-leg timing does not turn actor")
	for (var/key in list("carriage_glide_owner", "carriage_glide_previous", "carriage_glide_applied", "carriage_glide_step", "glide_size"))
		carriage_glide_fixture_check(H.persistence_runtime_var(key), "runtime human field excluded")
	carriage_glide_fixture_check(C.persistence_runtime_var("carriage_glide") && !second.should_save, "lease excluded")
	second.release()
	for (var/atom/movable/A in list(C, H, cargo))
		for (var/datum/carriage_glide_lease/L in list(first, second))
			carriage_glide_fixture_check(!GLOB.moved_event.is_listening(A, L) && !GLOB.destroyed_event.is_listening(A, L), "released leases absent from registries")
	for (var/datum/carriage_glide_lease/L in list(first, second))
		carriage_glide_fixture_check(!(L in GLOB.event_listen_count) && !(L in GLOB.global_listen_count), "released leases absent from registry counters")
	H.glide_size = prior_human
	cargo.glide_size = prior_cargo
	carriage_glide_fixture_check(!first.carriage && !first.members.len && !second.carriage && !second.members.len, "retired leases empty")
