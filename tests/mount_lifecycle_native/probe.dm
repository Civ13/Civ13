// Prepared native observations. No client, normal startup, save or AI loop.
// Injected callbacks below are synthetic instrumentation, not real mount gestures.
/world
	maxx = 8
	maxy = 8
	maxz = 1
	fps = 20
	hub = ""
	visibility = 0

var/datum/mount_native_case/mount_native_active
var/list/mount_native_rows = list()
var/list/mount_native_observations = list()

/proc/mount_native_check(ok, label)
	if (mount_native_rows.len >= 80)
		throw EXCEPTION("assertion_bound")
	mount_native_rows += list(list("label" = label, "passed" = !!ok))
	if (!ok)
		throw EXCEPTION(label)

/mob/living/human/mount_native/forceMove(atom/destination, var/special_event, list/throw_hop_token = null)
	var/datum/mount_native_case/C = mount_native_active
	if (C && C.active && src == C.H)
		if (isturf(destination))
			C.force_calls++
			C.before_force_riding = riding
			C.before_force_mount = riding_mob
		else
			C.teardown_force_calls++
	. = ..(destination, special_event, throw_hop_token)
	if (C && C.active && src == C.H)
		C.note(isturf(destination) ? "native_forceMove_return" : "native_teardown_forceMove_return", list("return" = ., "x" = x, "y" = y))
		if (isturf(destination) && (C.operation == "death" || C.operation == "separation") && C.kind == "reassignment" && !C.injected)
			C.injected = TRUE
			C.bind_b()
			C.note("synthetic_forceMove_reassignment", list("target" = "B"))

/mob/living/human/mount_native/Destroy()
	var/datum/mount_native_case/C = mount_native_active
	if (C && C.active && src == C.H)
		C.human_destroy_calls++
		C.human_retiring_entry = QDELETED(src)
		C.note("native_human_Destroy_entry", list("modern" = gc_destroyed, "legacy" = gcDestroyed))
		if (C.kind == "retiring" && !C.injected)
			C.injected = TRUE
			if (C.operation == "mount_qdel")
				qdel(C.A)
				C.retirement_window = riding && isnull(riding_mob) && isnull(locate(C.a_ref))
			else if (C.operation == "death")
				C.A.death()
				C.retirement_window = !riding && isnull(riding_mob) && QDELETED(src)
	return ..()

/mob/living/simple_animal/horse/mount_native/update_icons()
	. = ..()
	var/datum/mount_native_case/C = mount_native_active
	if (C && C.active && src == C.A)
		C.icon_calls++
		C.note("native_mount_icons_return", list("ride" = ride, "rider_present" = !!rider, "stop" = stop_automated_movement))
		if (C.operation == "separation" && C.kind == "icon_reassignment" && !C.injected)
			C.injected = TRUE
			C.bind_j()
			C.note("synthetic_icon_reassignment", list("target" = "J"))

/mob/living/simple_animal/horse/mount_native/Destroy()
	var/datum/mount_native_case/C = mount_native_active
	if (C && C.active && src == C.A)
		C.mount_destroy_calls++
		C.mount_retiring_entry = QDELETED(src)
		C.note("native_mount_Destroy_entry", list("modern" = gc_destroyed, "legacy" = gcDestroyed))
		if (C.kind == "retiring" && !C.injected)
			C.injected = TRUE
			if (C.operation == "rider_qdel")
				qdel(C.H)
				C.retirement_window = ride && isnull(rider) && stop_automated_movement && isnull(locate(C.h_ref))
			else if (C.operation == "separation")
				C.H.mount_native_separation()
				C.retirement_window = ride && rider == C.H && stop_automated_movement && QDELETED(src)
	return ..()

/datum/mount_native_case
	var/operation
	var/kind
	var/id
	var/active = FALSE
	var/injected = FALSE
	var/mob/living/human/mount_native/H
	var/mob/living/human/mount_native/J
	var/mob/living/simple_animal/horse/mount_native/A
	var/mob/living/simple_animal/horse/mount_native/B
	var/h_ref
	var/a_ref
	var/list/owned_refs
	var/force_calls = 0
	var/teardown_force_calls = 0
	var/icon_calls = 0
	var/human_destroy_calls = 0
	var/mount_destroy_calls = 0
	var/events = 0
	var/human_retiring_entry = FALSE
	var/mount_retiring_entry = FALSE
	var/retirement_window = FALSE
	var/before_force_riding
	var/mob/living/simple_animal/before_force_mount
	var/observed_clear = FALSE

/datum/mount_native_case/proc/note(phase, list/values)
	if (mount_native_observations.len >= 256)
		throw EXCEPTION("observation_bound")
	mount_native_observations += list(list("case" = id, "phase" = phase, "values" = values))

/datum/mount_native_case/proc/setup(op, state)
	operation = op
	kind = state
	id = "[op].[state]"
	H = new(locate(2, 2, 1))
	J = new(locate(2, 3, 1))
	A = new(locate(2, 2, 1))
	B = new(locate(2, 2, 1))
	h_ref = "\ref[H]"
	a_ref = "\ref[A]"
	owned_refs = list(h_ref, "\ref[J]", a_ref, "\ref[B]")
	H.riding = TRUE
	H.riding_mob = A
	A.rider = H
	A.ride = TRUE
	A.stop_automated_movement = TRUE
	J.riding = FALSE
	J.riding_mob = null
	B.rider = null
	B.ride = FALSE
	B.stop_automated_movement = FALSE
	if (kind == "foreign")
		if (operation == "death" || operation == "mount_qdel")
			bind_b()
		else
			bind_j()
	if (kind == "absent")
		H.riding = FALSE
		H.riding_mob = null
		A.rider = null
		A.ride = FALSE
		A.stop_automated_movement = FALSE
	if (operation == "separation")
		H.forceMove(locate(6, 6, 1))
	if (operation == "mount_qdel")
		GLOB.destroyed_event.register(A, src, /datum/mount_native_case/proc/destroyed)
	if (operation == "rider_qdel")
		GLOB.destroyed_event.register(H, src, /datum/mount_native_case/proc/destroyed)
	active = TRUE

/datum/mount_native_case/proc/bind_b()
	B.forceMove(H.loc)
	H.riding = TRUE
	H.riding_mob = B
	B.rider = H
	B.ride = TRUE
	B.stop_automated_movement = TRUE

/datum/mount_native_case/proc/bind_j()
	J.riding = TRUE
	J.riding_mob = A
	A.rider = J
	A.ride = TRUE
	A.stop_automated_movement = TRUE

/datum/mount_native_case/proc/destroyed(datum/target)
	if (!active)
		return
	events++
	if (operation == "mount_qdel")
		observed_clear = !H.riding && isnull(H.riding_mob)
	else
		observed_clear = !A.ride && isnull(A.rider) && !A.stop_automated_movement
	note("native_destroyed_event", list("modern" = target.gc_destroyed, "released" = observed_clear))
	if (operation == "mount_qdel")
		if (kind == "reassignment")
			qdel(target)
			bind_b()
			note("synthetic_destroyed_reassignment", list("target" = "B", "released_before_callback" = observed_clear))
	else
		if (kind == "reassignment")
			qdel(target)
			bind_j()
			note("synthetic_destroyed_reassignment", list("target" = "J", "released_before_callback" = observed_clear))

/datum/mount_native_case/proc/perform()
	if (operation == "death")
		if (kind == "retiring")
			qdel(H)
		else
			A.death()
	else if (operation == "separation")
		if (kind == "retiring")
			qdel(A)
		else
			H.mount_native_separation()
	else if (operation == "mount_qdel")
		if (kind == "retiring")
			qdel(H)
		else
			qdel(A)
	else if (operation == "rider_qdel")
		if (kind == "retiring")
			qdel(A)
		else
			qdel(H)
	else
		throw EXCEPTION("unsupported_operation")

/datum/mount_native_case/proc/check_state()
	var/state_ok = FALSE
	var/callback_ok = FALSE
	var/ownership_ok = FALSE
	if (operation == "death")
		state_ok = A && A.stat == DEAD && !A.ride && isnull(A.rider)
		if (kind == "retiring")
			state_ok = state_ok && isnull(locate(h_ref)) && retirement_window
			ownership_ok = human_retiring_entry && human_destroy_calls == 1
		else if (kind == "foreign")
			// Legacy death still clears riding; only its foreign pointer is preserved.
			state_ok = state_ok && !H.riding && H.riding_mob == B
			ownership_ok = B.rider == H && B.ride
		else if (kind == "reassignment")
			state_ok = state_ok && H.riding && H.riding_mob == B
			ownership_ok = injected && B.rider == H && B.ride
		else
			state_ok = state_ok && !H.riding && isnull(H.riding_mob)
			ownership_ok = H && !J.riding && isnull(J.riding_mob)
		callback_ok = force_calls == 1 && !before_force_riding && (kind == "foreign" ? before_force_mount == B : isnull(before_force_mount))
		if (kind == "retiring")
			callback_ok = callback_ok && teardown_force_calls == 1
	else if (operation == "separation")
		if (kind == "retiring")
			state_ok = isnull(locate(a_ref)) && H && !H.riding && isnull(H.riding_mob)
			ownership_ok = retirement_window && mount_retiring_entry && mount_destroy_calls == 1
		else if (kind == "foreign" || kind == "icon_reassignment")
			state_ok = !H.riding && isnull(H.riding_mob) && A.ride && A.rider == J && A.stop_automated_movement
			ownership_ok = J.riding && J.riding_mob == A
		else if (kind == "reassignment")
			state_ok = H.riding && H.riding_mob == B && !A.ride && isnull(A.rider) && !A.stop_automated_movement
			ownership_ok = injected && B.ride && B.rider == H
		else
			state_ok = !H.riding && isnull(H.riding_mob) && !A.ride && isnull(A.rider) && !A.stop_automated_movement
			ownership_ok = !J.riding && isnull(J.riding_mob)
		callback_ok = force_calls == 1 && !before_force_riding && isnull(before_force_mount) && H.loc == locate(6, 6, 1)
		callback_ok = callback_ok && ((kind == "foreign" || kind == "retiring") ? icon_calls == 0 : icon_calls == 1)
	else if (operation == "mount_qdel")
		state_ok = isnull(locate(a_ref)) && mount_retiring_entry && mount_destroy_calls == 1
		callback_ok = events == 1
		if (kind == "retiring")
			state_ok = state_ok && isnull(locate(h_ref))
			ownership_ok = retirement_window && human_retiring_entry
		else if (kind == "foreign" || kind == "reassignment")
			state_ok = state_ok && H.riding && H.riding_mob == B
			ownership_ok = B.ride && B.rider == H
			if (kind == "reassignment")
				callback_ok = callback_ok && observed_clear && injected
		else
			state_ok = state_ok && H && !H.riding && isnull(H.riding_mob)
			ownership_ok = H.loc == locate(2, 2, 1) && !J.riding
	else
		state_ok = isnull(locate(h_ref)) && human_retiring_entry && human_destroy_calls == 1
		callback_ok = events == 1
		if (kind == "retiring")
			state_ok = state_ok && isnull(locate(a_ref))
			ownership_ok = retirement_window && mount_retiring_entry
		else if (kind == "foreign" || kind == "reassignment")
			state_ok = state_ok && A.ride && A.rider == J && A.stop_automated_movement
			ownership_ok = J.riding && J.riding_mob == A
			if (kind == "reassignment")
				callback_ok = callback_ok && observed_clear && injected
		else
			state_ok = state_ok && A && !A.ride && isnull(A.rider) && !A.stop_automated_movement
			ownership_ok = !J.riding && isnull(J.riding_mob)
	mount_native_check(state_ok, "[id].state")
	mount_native_check(callback_ok, "[id].callbacks")
	mount_native_check(ownership_ok, "[id].ownership")

/datum/mount_native_case/proc/cleanup(record = TRUE)
	active = FALSE
	if (A)
		GLOB.destroyed_event.unregister(A, src)
	if (H)
		GLOB.destroyed_event.unregister(H, src)
	for (var/mob/M in list(H, J, A, B))
		if (M)
			qdel(M)
	var/gone = TRUE
	for (var/ref_id in owned_refs)
		if (locate(ref_id))
			gone = FALSE
	if (record)
		mount_native_check(gone, "[id].cleanup")
	return gone

/proc/mount_native_run_case(operation, kind)
	var/datum/mount_native_case/C = new
	mount_native_active = C
	C.setup(operation, kind)
	C.perform()
	C.check_state()
	C.cleanup()
	mount_native_active = null
	qdel(C)

/world/New()
	var/initial_native_port = port
	OpenPort("none")
	if (!port)
		text2file("closed", "port-closed.txt")
	var/error = null
	var/cleanup_error = null
	try
		mount_native_check(!port && !OpenPort(0) && !port, "startup.closed_port")
		mount_native_check(byond_version == 516 && byond_build == 1688, "startup.engine")
		mount_native_check(world.params["tested_commit"] == MOUNT_NATIVE_HEAD && world.params["fixture_variant"] == MOUNT_NATIVE_VARIANT, "startup.identity")
		human_subtile_fixture_initialize()
		for (var/operation in list("death", "separation", "mount_qdel", "rider_qdel"))
			for (var/kind in list("matching", "foreign", "retiring", "reassignment"))
				mount_native_run_case(operation, kind)
			if (operation == "separation")
				mount_native_run_case(operation, "icon_reassignment")
			if (operation == "mount_qdel" || operation == "rider_qdel")
				mount_native_run_case(operation, "absent")
	catch (var/exception/mount_failure)
		error = mount_failure.name
		if (mount_native_active)
			try
				var/datum/mount_native_case/failed_case = mount_native_active
				if (!failed_case.cleanup(FALSE))
					cleanup_error = "fixture_owned_mobs_survived"
				mount_native_active = null
				qdel(failed_case)
			catch (var/exception/mount_cleanup_failure)
				cleanup_error = mount_cleanup_failure.name
	// Preserve the first assertion and prefix; cleanup never adds passing rows.
	text2file(json_encode(list("head" = MOUNT_NATIVE_HEAD, "variant" = MOUNT_NATIVE_VARIANT, "byond_version" = byond_version, "byond_build" = byond_build, "initial_native_port" = initial_native_port, "port" = port, "checks" = mount_native_rows, "observations" = mount_native_observations, "error" = error, "cleanup_error" = cleanup_error, "scope" = "native fields/qdel/Destroy;selected separation branch;synthetic callback injections")), "receipt.json")
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	del(world)
	return
