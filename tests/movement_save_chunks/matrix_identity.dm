// Native matrix-key primitive only. No automatic entry or timing claims.
// Explicit caller required; fewer than 100 explicit object/list allocations.
// Matrix == may compare values: reference strings below are identity oracles,
// never an assertion that equal-content matrices must compare unequal with ==.
/proc/check_native_matrix_identity()
	var/list/baseline_cache = list()
	var/list/baseline_pins = list()
	var/list/direct_cache = list()
	var/list/direct_pins = list()
	var/matrix/equal_a = matrix(1, 0, 0, 0, 1, 0)
	var/matrix/equal_b = matrix(1, 0, 0, 0, 1, 0)
	var/matrix/alias_a = equal_a
	var/id_a = check_native_matrix_registration("equal_a", equal_a, baseline_cache, baseline_pins, direct_cache, direct_pins)
	var/id_b = check_native_matrix_registration("equal_b", equal_b, baseline_cache, baseline_pins, direct_cache, direct_pins)
	if("\ref[equal_a]" == "\ref[equal_b]")
		throw EXCEPTION("MATRIX_IDENTITY: constructor did not yield distinct reference identities")
	world.log << "MATRIX_IDENTITY_OBSERVATION equal_values_compare_equal=[equal_a == equal_b]"
	if(id_a == id_b)
		throw EXCEPTION("MATRIX_IDENTITY: baseline distinct references merged")
	if(check_native_matrix_registration("alias_a", alias_a, baseline_cache, baseline_pins, direct_cache, direct_pins) != id_a)
		throw EXCEPTION("MATRIX_IDENTITY: held alias failed baseline reuse")
	equal_a.c = 13
	equal_a.f = -7
	if(check_native_matrix_registration("mutated_a", equal_a, baseline_cache, baseline_pins, direct_cache, direct_pins) != id_a)
		throw EXCEPTION("MATRIX_IDENTITY: mutation changed held registration")
	check_native_matrix_registration("unchanged_b", equal_b, baseline_cache, baseline_pins, direct_cache, direct_pins)

	var/matrix/missing = matrix(2, 0, 0, 0, 2, 0)
	var/before_baseline = baseline_cache.len
	var/before_direct = direct_cache.len
	var/missing_baseline = baseline_cache["\ref[missing]"]
	var/missing_direct = direct_cache[missing]
	if(!isnull(missing_baseline) || !isnull(missing_direct) || baseline_cache.len != before_baseline || direct_cache.len != before_direct)
		throw EXCEPTION("MATRIX_IDENTITY: missing lookup returned value or grew a cache")

	var/obj/holder = new /obj
	holder.transform = matrix(1, 0, 2, 0, 1, 3)
	var/matrix/held_transform = holder.transform
	check_native_matrix_registration("held_transform", held_transform, baseline_cache, baseline_pins, direct_cache, direct_pins)
	check_native_matrix_registration("getter_transform_1", holder.transform, baseline_cache, baseline_pins, direct_cache, direct_pins)
	check_native_matrix_registration("getter_transform_2", holder.transform, baseline_cache, baseline_pins, direct_cache, direct_pins)
	check_native_matrix_registration("held_transform_alias", held_transform, baseline_cache, baseline_pins, direct_cache, direct_pins)
	held_transform.c = 23
	check_native_matrix_registration("mutated_held_transform", held_transform, baseline_cache, baseline_pins, direct_cache, direct_pins)
	holder.transform = matrix(2, 0, 5, 0, 2, 6)
	check_native_matrix_registration("replaced_getter_transform", holder.transform, baseline_cache, baseline_pins, direct_cache, direct_pins)
	check_native_matrix_registration("retained_old_transform", held_transform, baseline_cache, baseline_pins, direct_cache, direct_pins)

	// Deliberately stale non-null pins test exactly the production pin guard.
	// Cache keys still resolve id_a, but that slot now contains another matrix.
	var/matrix/stale = matrix(9, 0, 9, 0, 9, 9)
	baseline_pins[id_a] = stale
	direct_pins[id_a] = stale
	var/before_stale = baseline_pins.len
	var/new_id = check_native_matrix_registration("stale_pin", equal_a, baseline_cache, baseline_pins, direct_cache, direct_pins)
	if(new_id != before_stale + 1)
		throw EXCEPTION("MATRIX_IDENTITY: stale unequal pin failed to allocate")
	if(check_native_matrix_registration("after_stale_alias", alias_a, baseline_cache, baseline_pins, direct_cache, direct_pins) != new_id)
		throw EXCEPTION("MATRIX_IDENTITY: replacement pin failed alias reuse")

	// Remove normal aliases and cache keys; pins must retain the old matrices.
	equal_a = null
	equal_b = null
	alias_a = null
	held_transform = null
	stale = null
	baseline_cache.Cut()
	direct_cache.Cut()
	del(holder)
	for(var/i = 1, i <= 32, i++)
		var/matrix/churn = matrix(i, 0, 0, 0, i, 0)
		for(var/j = 1, j <= baseline_pins.len, j++)
			var/matrix/old = baseline_pins[j]
			var/matrix/candidate = direct_pins[j]
			if("\ref[old]" != "\ref[candidate]" || "\ref[churn]" == "\ref[old]")
				throw EXCEPTION("MATRIX_IDENTITY: retained pin identity lost or reused")
	var/matrix/retained = baseline_pins[new_id]
	if(!retained || retained.c != 13 || retained.f != -7)
		throw EXCEPTION("MATRIX_IDENTITY: retained mutation values changed")
	baseline_pins.Cut()
	direct_pins.Cut()
	if(baseline_cache.len || direct_cache.len || baseline_pins.len || direct_pins.len)
		throw EXCEPTION("MATRIX_IDENTITY: reset retained bookkeeping")
	if(check_native_matrix_registration("new_pass", retained, baseline_cache, baseline_pins, direct_cache, direct_pins) != 1)
		throw EXCEPTION("MATRIX_IDENTITY: new pass did not restart IDs")
	baseline_cache.Cut()
	direct_cache.Cut()
	baseline_pins.Cut()
	direct_pins.Cut()
	return TRUE

// This is the existing datum registration guard/order, not list registration.
// Both algorithms see the exact same input handle once per labeled step.
/proc/check_native_matrix_registration(label, matrix/M, list/baseline_cache, list/baseline_pins, list/direct_cache, list/direct_pins)
	var/baseline_id = baseline_cache["\ref[M]"]
	if(!(baseline_id && baseline_pins[baseline_id] == M))
		baseline_id = baseline_pins.len + 1
		baseline_pins += M
		baseline_cache["\ref[M]"] = baseline_id
	var/direct_id = direct_cache[M]
	if(!(direct_id && direct_pins[direct_id] == M))
		direct_id = direct_pins.len + 1
		direct_pins += M
		direct_cache[M] = direct_id
	if(baseline_id != direct_id || baseline_pins.len != direct_pins.len)
		throw EXCEPTION("MATRIX_IDENTITY: registration IDs/counts differ: [label]")
	var/matrix/baseline_pin = baseline_pins[baseline_id]
	var/matrix/direct_pin = direct_pins[direct_id]
	if("\ref[baseline_pin]" != "\ref[M]" || "\ref[direct_pin]" != "\ref[M]")
		throw EXCEPTION("MATRIX_IDENTITY: registered pins differ from input reference: [label]")
	for(var/i = 1, i <= baseline_pins.len, i++)
		var/matrix/old = baseline_pins[i]
		var/matrix/candidate = direct_pins[i]
		if("\ref[old]" != "\ref[candidate]")
			throw EXCEPTION("MATRIX_IDENTITY: registration identity partition differs: [label]")
	return baseline_id
