// Requires the exact-source generated /datum/moving_save_preflight_reference.
// Semantic differential only. Real CPU/tick bounds remain enabled; timing-cap
// interference is an explicit inconclusive failure, never performance evidence.
/datum/preflight_identity_node
	var/payload
	get_saved_vars()
		return list("payload")

/proc/check_native_preflight_identity()
	var/list/equal_a = list("same", 7)
	var/list/equal_b = list("same", 7)
	var/list/empty_a = list()
	var/list/empty_b = list()
	var/list/self_cycle = list()
	self_cycle += list(self_cycle)
	var/list/cycle_a = list()
	var/list/cycle_b = list()
	cycle_a += list(cycle_b)
	cycle_b += list(cycle_a)
	var/matrix/matrix_a = matrix(1, 0, 2, 0, 1, 3)
	var/matrix/matrix_b = matrix(1, 0, 2, 0, 1, 3)
	var/datum/preflight_identity_node/datum_a = new
	var/datum/preflight_identity_node/datum_b = new
	datum_a.payload = equal_a
	datum_b.payload = equal_b
	var/list/graph = list(equal_a, equal_a, equal_b, empty_a, empty_b, self_cycle, cycle_a, cycle_b, matrix_a, matrix_a, matrix_b, datum_a, datum_a, datum_b)
	var/list/observed = list(graph, equal_a, equal_b, empty_a, empty_b, self_cycle, cycle_a, cycle_b, matrix_a, matrix_b, datum_a, datum_b)
	check_preflight_identity_case("mixed_alias_cycles", graph, TRUE, observed)
	matrix_a.c = 9
	equal_a += "mutation"
	check_preflight_identity_case("mutated_same_graph", graph, TRUE, observed)
	var/obj/external = new /obj
	check_preflight_identity_case("external_movable", list(external), FALSE)
	del(external)
	check_preflight_identity_case("depth_limit", list(), FALSE, null, 33)
	check_preflight_identity_case("byte_limit", "x", FALSE, null, 0, 0, 262144)
	check_preflight_identity_case("work_limit", list("x"), FALSE, null, 0, 511)
	check_preflight_identity_case("node_limit", list(), FALSE, null, 0, 0, 0, 64)
	var/list/too_wide = list()
	too_wide.len = 257
	check_preflight_identity_case("length_limit", too_wide, FALSE)
	self_cycle.Cut()
	cycle_a.Cut()
	cycle_b.Cut()
	datum_a.payload = null
	datum_b.payload = null
	return TRUE

/proc/check_preflight_identity_case(label, value, expected, list/observed, depth = 0, initial_work = 0, initial_bytes = 0, initial_nodes = 0)
	var/map_storage/exporter = new
	var/datum/moving_save_preflight/candidate = new
	var/datum/moving_save_preflight_reference/reference = new
	candidate.exporter = exporter
	reference.exporter = exporter
	candidate.work = initial_work
	reference.work = initial_work
	candidate.bytes = initial_bytes
	reference.bytes = initial_bytes
	// Retain every seeded node independently, even in the string-key reference.
	var/list/seed_pins = list()
	for(var/i = 1, i <= initial_nodes, i++)
		var/list/node = list()
		seed_pins += list(node)
		candidate.seen[node] = TRUE
		reference.seen["\ref[node]"] = TRUE
	candidate.start_tick = world.time
	candidate.start_usage = world.tick_usage
	var/candidate_result = candidate.accept(value, depth)
	if(world.time != candidate.start_tick || world.tick_usage - candidate.start_usage > 5)
		throw EXCEPTION("PREFLIGHT_IDENTITY: candidate timing cap interfered: [label]")
	reference.start_tick = world.time
	reference.start_usage = world.tick_usage
	var/reference_result = reference.accept(value, depth)
	if(world.time != reference.start_tick || world.tick_usage - reference.start_usage > 5)
		throw EXCEPTION("PREFLIGHT_IDENTITY: reference timing cap interfered: [label]")
	if(!!candidate_result != !!reference_result || !!candidate_result != !!expected || candidate.work != reference.work || candidate.bytes != reference.bytes || candidate.seen.len != reference.seen.len)
		throw EXCEPTION("PREFLIGHT_IDENTITY: semantic decision/counters differ: [label]")
	if(observed)
		for(var/i = 1, i <= observed.len, i++)
			var/node = observed[i]
			var/candidate_key = islist(node) ? node : exporter.save_entry_identity(node)
			var/reference_key = "\ref[node]"
			if(!candidate.seen[candidate_key] || candidate.seen[candidate_key] != reference.seen[reference_key])
				throw EXCEPTION("PREFLIGHT_IDENTITY: seen identity partition differs: [label]")
	candidate.seen.Cut()
	reference.seen.Cut()
	seed_pins.Cut()
	exporter.clear_bookkeeping()
	return TRUE
