// Native BYOND primitive probe, not a Python model or production optimization.
// No World/New hook: caller must include this file and invoke explicitly.
// Fixed bounded churn: fewer than 150 explicit list/appearance/object allocations.
/proc/check_native_list_identity()
	var/list/identity_map = list()
	var/list/pins = list()
	var/list/empty_a = list()
	var/list/empty_b = list()
	var/list/equal_a = list("same", 7)
	var/list/equal_b = list("same", 7)
	identity_map[empty_a] = 1
	identity_map[empty_b] = 2
	identity_map[equal_a] = 3
	identity_map[equal_b] = 4
	pins += list(empty_a)
	pins += list(empty_b)
	pins += list(equal_a)
	pins += list(equal_b)
	if(identity_map.len != 4 || identity_map[empty_a] != 1 || identity_map[empty_b] != 2 || identity_map[equal_a] != 3 || identity_map[equal_b] != 4)
		throw EXCEPTION("LIST_IDENTITY: distinct equal or empty list keys collided")
	var/list/alias_a = equal_a
	if(identity_map[alias_a] != 3 || pins[3] != alias_a)
		throw EXCEPTION("LIST_IDENTITY: alias lookup/pin mismatch")
	equal_a += "changed"
	empty_a["new"] = "value"
	if(identity_map[equal_a] != 3 || identity_map[alias_a] != 3 || identity_map[empty_a] != 1 || identity_map[equal_b] != 4)
		throw EXCEPTION("LIST_IDENTITY: mutation changed key identity")

	var/list/missing = list()
	var/before_missing = identity_map.len
	var/missing_id = identity_map[missing]
	var/find_missing = identity_map.Find(missing)
	var/find_null = identity_map.Find(null)
	world.log << "LIST_IDENTITY_OBSERVATION missing_isnull=[isnull(missing_id)] missing_isnum=[isnum(missing_id)] missing_islist=[islist(missing_id)] missing_value=[missing_id] before_len=[before_missing] after_len=[identity_map.len] find_missing=[find_missing] find_null=[find_null]"
	if(!isnull(missing_id) || identity_map.len != before_missing)
		throw EXCEPTION("LIST_IDENTITY: absent associative lookup changed map or returned value")

	var/list/self_cycle = list()
	self_cycle += list(self_cycle)
	var/list/cycle_a = list()
	var/list/cycle_b = list()
	cycle_a += list(cycle_b)
	cycle_b += list(cycle_a)
	identity_map[self_cycle] = 5
	identity_map[cycle_a] = 6
	identity_map[cycle_b] = 7
	pins += list(self_cycle)
	pins += list(cycle_a)
	pins += list(cycle_b)
	if(identity_map[self_cycle] != 5 || identity_map[cycle_a] != 6 || identity_map[cycle_b] != 7 || self_cycle[1] != self_cycle || cycle_a[1] != cycle_b || cycle_b[1] != cycle_a)
		throw EXCEPTION("LIST_IDENTITY: cyclic list key/pin mismatch")

	// Drop ordinary aliases; retained keys and pins must still designate exactly
	// the old lists even after unrelated allocations. This is not a GC proof.
	empty_a = null
	empty_b = null
	equal_a = null
	equal_b = null
	alias_a = null
	for(var/i = 1, i <= 32, i++)
		var/list/churn = list(i)
		if(identity_map[churn])
			throw EXCEPTION("LIST_IDENTITY: fresh list inherited retained key")
	for(var/i = 1, i <= 7, i++)
		var/list/retained = pins[i]
		if(!islist(retained) || identity_map[retained] != i)
			throw EXCEPTION("LIST_IDENTITY: retained pin identity lost")

	var/obj/native_holder = new /obj
	var/list/native_overlays = native_holder.overlays
	var/list/native_underlays = native_holder.underlays
	var/list/native_filters = native_holder.filters
	identity_map[native_overlays] = 8
	identity_map[native_underlays] = 9
	identity_map[native_filters] = 10
	pins += list(native_overlays)
	pins += list(native_underlays)
	pins += list(native_filters)
	if(identity_map[native_holder.overlays] != 8 || identity_map[native_holder.underlays] != 9 || identity_map[native_holder.filters] != 10 || pins[8] != native_holder.overlays || pins[9] != native_holder.underlays || pins[10] != native_holder.filters)
		throw EXCEPTION("LIST_IDENTITY: native-list repeated getter/key/pin mismatch")
	native_holder.overlays += image(null)
	native_holder.underlays += image(null)
	native_holder.filters += filter(type = "blur", size = 1)
	if(identity_map[native_holder.overlays] != 8 || identity_map[native_holder.underlays] != 9 || identity_map[native_holder.filters] != 10 || native_overlays != native_holder.overlays || native_underlays != native_holder.underlays || native_filters != native_holder.filters)
		throw EXCEPTION("LIST_IDENTITY: native-list mutation changed handle identity")

	// Break cycles, then discard map and pins; a new pass must start empty.
	self_cycle.Cut()
	cycle_a.Cut()
	cycle_b.Cut()
	identity_map.Cut()
	// With map keys and ordinary aliases gone, pins alone retain equal_a.
	for(var/j = 1, j <= 16, j++)
		var/list/later_allocation = list(j)
		if(later_allocation == pins[3])
			throw EXCEPTION("LIST_IDENTITY: allocation reused a pinned list")
	var/list/pin_only = pins[3]
	if(!islist(pin_only) || pin_only.len != 3 || pin_only[1] != "same" || pin_only[2] != 7 || pin_only[3] != "changed")
		throw EXCEPTION("LIST_IDENTITY: pins-only retained list lost its contents")
	pin_only = null
	pins.Cut()
	if(identity_map.len || pins.len)
		throw EXCEPTION("LIST_IDENTITY: map/pin cleanup retained entries")
	identity_map = list()
	pins = list()
	if(!isnull(identity_map[missing]) || identity_map.len || pins.len)
		throw EXCEPTION("LIST_IDENTITY: new pass inherited an identity")
	identity_map[missing] = 1
	pins += list(missing)
	if(identity_map[missing] != 1 || pins[1] != missing || identity_map.len != 1)
		throw EXCEPTION("LIST_IDENTITY: next-pass ID restart failed")
	identity_map.Cut()
	pins.Cut()
	del(native_holder)
	return TRUE
