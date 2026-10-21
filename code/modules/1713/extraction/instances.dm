// Standalone instance ABI v1. No world allocation, account I/O or activation.
/proc/extraction_instance_keys(list/value, list/keys)
	if (!islist(value) || value.len != keys.len) return FALSE
	for (var/key in keys)
		if (!(key in value)) return FALSE
	return TRUE

/proc/extraction_instance_id(value)
	if (!istext(value) || !length(value) || length(value) > 64) return FALSE
	for (var/i = 1, i <= length(value), i++)
		var/c = text2ascii(value, i)
		if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 45 || c == 95)) return FALSE
	return TRUE

/proc/extraction_instance_integer(value, low, high)
	return isnum(value) && value >= low && value <= high && round(value) == value

/proc/extraction_instance_copy(list/value)
	return json_decode(json_encode(value))

/proc/extraction_instance_record_signature(list/R)
	return json_encode(list(R["schema"], R["instance_id"], R["party_id"], R["kind"], R["template_id"], R["template_revision"]))

/proc/extraction_instance_template_signature(list/T)
	var/list/layers = list()
	for (var/list/D in T["decks"]) layers += list(list(D["layer"], D["id"]))
	return json_encode(list(T["schema"], T["template_id"], T["revision"], T["width"], T["height"], layers, T["berths"]))

/datum/extraction_instance_limits
	// Implementation budgets, not game design promises. Callers may supply limits.
	var/max_instances = 32
	var/max_width = 512
	var/max_height = 512
	var/max_decks = 4
	proc/valid()
		return extraction_instance_integer(max_instances, 1, 1024) && extraction_instance_integer(max_width, 1, 32767) && extraction_instance_integer(max_height, 1, 32767) && extraction_instance_integer(max_decks, 1, 64)
	proc/record_valid(list/R)
		if (!extraction_instance_keys(R, list("schema", "instance_id", "party_id", "kind", "template_id", "template_revision"))) return FALSE
		return R["schema"] == 1 && extraction_instance_id(R["instance_id"]) && extraction_instance_id(R["party_id"]) && (R["kind"] in list("dagger", "safehouse")) && extraction_instance_id(R["template_id"]) && extraction_instance_integer(R["template_revision"], 1, 16777215)
	proc/template_valid(list/T, list/R)
		if (!valid() || !record_valid(R) || !extraction_instance_keys(T, list("schema", "template_id", "revision", "width", "height", "decks", "berths"))) return FALSE
		if (T["schema"] != 1 || T["template_id"] != R["template_id"] || T["revision"] != R["template_revision"]) return FALSE
		if (!extraction_instance_integer(T["width"], 1, max_width) || !extraction_instance_integer(T["height"], 1, max_height)) return FALSE
		var/list/decks = T["decks"]
		var/list/berths = T["berths"]
		if (!islist(decks) || !islist(berths) || !decks.len || decks.len > max_decks || berths.len > 2) return FALSE
		if (R["kind"] == "dagger" && (decks.len != 4 || berths.len != 2)) return FALSE
		var/list/seen = list()
		for (var/i = 1, i <= decks.len, i++)
			var/list/D = decks[i]
			if (!extraction_instance_keys(D, list("layer", "id"))) return FALSE
			if (D["layer"] != i || !extraction_instance_id(D["id"]) || (D["id"] in seen)) return FALSE
			seen += D["id"]
		seen = list()
		for (var/id in berths)
			if (!extraction_instance_id(id) || (id in seen)) return FALSE
			seen += id
		return TRUE

/datum/extraction_instance_ledger
	var/datum/extraction_instance_limits/limits
	var/list/records = list()
	New(datum/extraction_instance_limits/budget)
		..()
		limits = budget ? budget : new /datum/extraction_instance_limits
	proc/register(list/R)
		if (!limits.valid() || !limits.record_valid(R)) return FALSE
		var/id = R["instance_id"]
		if (records[id]) return extraction_instance_record_signature(records[id]) == extraction_instance_record_signature(R)
		if (records.len >= limits.max_instances) return FALSE
		records[id] = extraction_instance_copy(R)
		return TRUE
	proc/snapshot()
		var/list/items = list()
		for (var/id in records) items += list(extraction_instance_copy(records[id]))
		return list("schema" = 1, "instances" = items)
	proc/restore(list/envelope)
		if (!limits.valid() || !extraction_instance_keys(envelope, list("schema", "instances")) || envelope["schema"] != 1) return FALSE
		var/list/items = envelope["instances"]
		if (!islist(items) || items.len > limits.max_instances) return FALSE
		var/list/staged = list()
		for (var/list/R in items)
			if (!limits.record_valid(R) || staged[R["instance_id"]]) return FALSE
			staged[R["instance_id"]] = extraction_instance_copy(R)
		// Typed loops skip malformed scalars; require every element was validated.
		if (staged.len != items.len) return FALSE
		records = staged
		return TRUE

// Opaque identity handles. A released handle can never authorize a later lease.
/datum/extraction_instance_token

/datum/extraction_instance_registry
	var/datum/extraction_instance_limits/limits
	var/map_id
	var/generation
	var/list/homes = list()
	var/list/logical_bindings = list()
	var/list/berth_tokens = list()
	New(scope_map, scope_generation, datum/extraction_instance_limits/budget)
		..()
		map_id = scope_map
		generation = scope_generation
		limits = budget ? budget : new /datum/extraction_instance_limits
	proc/current(scope_map, scope_generation)
		return extraction_instance_id(map_id) && extraction_instance_id(generation) && map_id == scope_map && generation == scope_generation && limits.valid()
	proc/reserve_home(list/R, list/T, list/origin, list/bounds, scope_map, scope_generation)
		if (!current(scope_map, scope_generation) || !limits.template_valid(T, R)) return null
		if (!islist(origin) || origin.len != 3 || !islist(bounds) || bounds.len != 3) return null
		for (var/i = 1, i <= 3, i++)
			if (!extraction_instance_integer(bounds[i], 1, 32767) || !extraction_instance_integer(origin[i], 1, bounds[i])) return null
		var/list/decks = T["decks"]
		var/top = origin[3] + decks.len - 1
		if (origin[1] + T["width"] - 1 > bounds[1] || origin[2] + T["height"] - 1 > bounds[2] || top > bounds[3]) return null
		var/id = R["instance_id"]
		var/binding = json_encode(list(extraction_instance_record_signature(R), extraction_instance_template_signature(T)))
		if (logical_bindings[id] && logical_bindings[id] != binding) return null
		var/signature = json_encode(list(binding, origin, bounds))
		var/list/existing = homes[id]
		if (existing) return existing["signature"] == signature ? existing["token"] : null
		if (!logical_bindings[id] && logical_bindings.len >= limits.max_instances) return null
		for (var/other_id in homes)
			var/list/other = homes[other_id]
			// Private homes own whole z intervals, irrespective of XY separation.
			if (origin[3] <= other["top"] && top >= other["bottom"]) return null
		var/datum/extraction_instance_token/token = new
		logical_bindings[id] = binding
		homes[id] = list("signature" = signature, "bottom" = origin[3], "top" = top, "token" = token)
		return token
	proc/release_home(id, datum/extraction_instance_token/token, scope_map, scope_generation)
		if (!current(scope_map, scope_generation)) return FALSE
		var/list/entry = homes[id]
		if (!entry || !token || entry["token"] != token) return FALSE
		homes -= id
		return TRUE
	// Destination slots are occupancy only; this does not project map geometry.
	// A separate destination registry can share destination z levels. Never use
	// these tokens to allocate or release a private-home interval.
	proc/acquire_berth(destination_id, berth_id, scope_map, scope_generation)
		if (!current(scope_map, scope_generation) || !extraction_instance_id(destination_id) || !(berth_id in list("raid_west", "raid_east"))) return null
		var/key = "[destination_id]:[berth_id]"
		if (berth_tokens[key] || berth_tokens.len >= 2 * limits.max_instances) return null
		var/datum/extraction_instance_token/token = new
		berth_tokens[key] = token
		return token
	proc/release_berth(destination_id, berth_id, datum/extraction_instance_token/token, scope_map, scope_generation)
		if (!current(scope_map, scope_generation) || !extraction_instance_id(destination_id) || !(berth_id in list("raid_west", "raid_east"))) return FALSE
		var/key = "[destination_id]:[berth_id]"
		if (!token || berth_tokens[key] != token) return FALSE
		berth_tokens -= key
		return TRUE
