// Disabled standalone expedition foundation. No singleton, timers or movement.
/proc/backrooms_integer(value, low, high)
	return isnum(value) && value >= low && value <= high && round(value) == value

/proc/backrooms_keys(list/value, list/keys)
	if (!islist(value) || value.len != keys.len)
		return FALSE
	for (var/key in keys)
		if (!(key in value))
			return FALSE
	return TRUE

/proc/backrooms_id(value)
	if (!istext(value) || !length(value) || length(value) > 64)
		return FALSE
	for (var/i = 1, i <= length(value), i++)
		var/c = text2ascii(value, i)
		if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 45 || c == 95))
			return FALSE
	return TRUE

/proc/backrooms_digest(value)
	if (!istext(value) || length(value) != 64)
		return FALSE
	for (var/i = 1, i <= 64, i++)
		var/c = text2ascii(value, i)
		if (!((c >= 48 && c <= 57) || (c >= 97 && c <= 102)))
			return FALSE
	return TRUE

/proc/backrooms_binding_valid(list/value)
	if (!backrooms_keys(value, list("scenario_id", "colony_id", "gateway_id", "instance_id", "template_id", "scenario_spec_sha256", "manifest_sha256", "scenario_year")))
		return FALSE
	return backrooms_id(value["scenario_id"]) && backrooms_id(value["colony_id"]) && backrooms_id(value["gateway_id"]) && backrooms_id(value["instance_id"]) && backrooms_digest(value["template_id"]) && backrooms_digest(value["scenario_spec_sha256"]) && backrooms_digest(value["manifest_sha256"]) && backrooms_integer(value["scenario_year"], 1990, 1993)

/datum/backrooms_supply
	var/charge = 0
	var/capacity = 0
	var/connected = FALSE
	var/epoch = 0
	New(initial_charge = 0, maximum_charge = 600)
		..()
		if (backrooms_integer(maximum_charge, 1, 100000) && backrooms_integer(initial_charge, 0, maximum_charge))
			capacity = maximum_charge
			charge = initial_charge
	proc/valid()
		return backrooms_integer(capacity, 1, 100000) && backrooms_integer(charge, 0, capacity)
	proc/connect()
		if (!valid())
			return FALSE
		if (!connected)
			epoch++
			connected = TRUE
		return TRUE
	proc/disconnect()
		if (connected)
			epoch++
		connected = FALSE
	proc/draw(units)
		if (!valid() || !connected || !backrooms_integer(units, 1, capacity) || units > charge)
			return FALSE
		charge -= units
		return TRUE
	// Internal accounting only. Future item handler must pay before crediting.
	proc/credit(units)
		if (!valid() || !backrooms_integer(units, 1, capacity) || units > capacity - charge)
			return FALSE
		charge += units
		return TRUE

/datum/backrooms_gateway_core
	var/enabled = FALSE
	var/list/binding
	var/datum/backrooms_supply/supply
	var/state = "OFF"
	var/last_error
	var/last_now = 0
	var/ready_at = 0
	var/next_due = 0
	var/source_epoch = 0
	New(list/identity, datum/backrooms_supply/source)
		..()
		if (backrooms_binding_valid(identity))
			binding = identity.Copy()
		supply = source
	proc/valid()
		return backrooms_binding_valid(binding) && supply && supply.valid()
	proc/fault(reason)
		state = "FAULT"
		last_error = reason
		ready_at = 0
		next_due = 0
		return FALSE
	proc/stop()
		state = "OFF"
		last_error = null
		ready_at = 0
		next_due = 0
		source_epoch = 0
	proc/start(now, destination_ready)
		if (!backrooms_integer(now, 0, 16776000) || now < last_now)
			return fault("clock")
		last_now = now
		if (state != "OFF")
			return FALSE
		if (!enabled || !valid() || !destination_ready)
			return fault("admission")
		// Startup 10 + first one-second maintenance interval 1, paid together.
		if (!supply.draw(11))
			return fault("power")
		source_epoch = supply.epoch
		state = "STARTING"
		last_error = null
		ready_at = now + 300
		next_due = now + 10
		return TRUE
	proc/service(now, destination_ready)
		if (!backrooms_integer(now, 0, 16776000) || now < last_now)
			return fault("clock")
		last_now = now
		if (!(state in list("STARTING", "READY")))
			return FALSE
		if (!enabled || !valid() || !destination_ready)
			return fault("admission")
		if (!supply.connected || source_epoch != supply.epoch)
			return fault("power")
		// Late service expires the lease; never backfill unpaid running time.
		if (now > next_due)
			return fault("maintenance_late")
		if (now == next_due)
			if (!supply.draw(1))
				return fault("power")
			next_due = now + 10
		if (now >= ready_at)
			state = "READY"
		return TRUE
	// Predicate only: no authorization, crossing debit, reservation or movement.
	proc/can_cross(now, destination_ready)
		if (!backrooms_integer(now, 0, 16776000) || now < last_now)
			return FALSE
		return enabled && valid() && destination_ready && state == "READY" && supply.connected && source_epoch == supply.epoch && now < next_due && supply.charge >= 2
	proc/snapshot()
		if (!valid())
			return null
		return list("schema" = 1, "binding" = binding.Copy(), "supply_capacity" = supply.capacity, "supply_charge" = supply.charge)
	proc/restore(list/record)
		if (!valid() || !backrooms_keys(record, list("schema", "binding", "supply_capacity", "supply_charge")) || record["schema"] != 1)
			return FALSE
		var/list/candidate = record["binding"]
		if (!backrooms_binding_valid(candidate) || record["supply_capacity"] != supply.capacity || !backrooms_integer(record["supply_charge"], 0, supply.capacity))
			return FALSE
		for (var/key in binding)
			if (candidate[key] != binding[key])
				return FALSE
		// Publish only after complete validation. No live pointers/clocks restored.
		var/datum/backrooms_supply/staged = new(record["supply_charge"], supply.capacity)
		supply = staged
		stop()
		last_now = 0
		return TRUE
