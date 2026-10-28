// Standalone 5x4x1 world; no full game, real scheduler, recipes or food behavior.
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 4
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
	fps = 10

var/global/list/fish_probe_verdicts = list()
var/global/fish_probe_initial_port = 0
var/global/fish_probe_port_closed = 0
var/global/fish_probe_reopen_refused = 0
var/global/fish_probe_clients = 0
var/global/fish_probe_topics = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return 0

/client/New()
	fish_probe_clients++
	del(src)
	return

/world/Topic(T, addr, master, key)
	fish_probe_topics++
	return null

/world/Error(exception/e)
	fish_probe_errors += "runtime: [e] [e.file]:[e.line]"
	world.log << "FISHING_RUNTIME_ERROR: [e] [e.file]:[e.line]"

/proc/fish_probe_check(condition, label)
	if (label in fish_probe_verdicts)
		fish_probe_errors += "duplicate verdict [label]"
	fish_probe_verdicts[label] = condition ? 1 : 0
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/proc/fish_probe_cleanup()
	for (var/atom/A in fish_probe_owned.Copy())
		if (A)
			del(A)
	fish_probe_owned.Cut()
	fish_probe_school = null
	fish_probe_outer = null
	fish_probe_inner = null
	fish_probe_inner_tool = null
	return

/proc/fish_probe_reset(selected_species = "fish")
	fish_probe_cleanup()
	fish_probe_outputs = list()
	fish_probe_wait_delays = list()
	fish_probe_wait_stocks = list()
	fish_probe_chances = list()
	fish_probe_mode = "pass"
	fish_probe_nested = 0
	fish_probe_bite = 1
	fish_probe_refills = 0
	fish_probe_success_messages = 0
	fish_probe_failure_messages = 0
	fish_probe_starts = 0
	fish_probe_school = new /obj/structure/fish(locate(3,2,1))
	fish_probe_school.counter = 1
	fish_probe_school.species = selected_species
	fish_probe_outer = new /mob/living/human(locate(2,2,1))
	fish_probe_inner = new /mob/living/human(locate(4,2,1))
	fish_probe_owned += fish_probe_school
	fish_probe_owned += fish_probe_outer
	fish_probe_owned += fish_probe_inner

/proc/fish_probe_tool(route, mob/actor)
	var/obj/item/tool
	if (route == "modern")
		tool = new /obj/item/weapon/fishing/modern(actor)
	else if (route == "ordinary")
		tool = new /obj/item/weapon/fishing(actor)
	else if (route == "branch")
		tool = new /obj/item/weapon/branch(actor)
	else
		fish_probe_errors += "unknown route [route]"
		return null
	fish_probe_owned += tool
	return tool

/proc/fish_probe_delay(route)
	return route == "ordinary" ? 150 : 120

/proc/fish_probe_chance(route)
	if (route == "modern")
		return 40
	return route == "ordinary" ? 30 : 20

/proc/fish_probe_output_matches(selected_species, output_x)
	if (fish_probe_outputs.len != 1)
		return 0
	var/list/row = fish_probe_outputs[1]
	var/expected_type = "/obj/item/weapon/reagent_containers/food/snacks/rawfish"
	if (selected_species != "fish")
		expected_type += "/[selected_species]"
	return row["type"] == expected_type && row["stock"] == 0 && row["x"] == output_x && row["y"] == 2 && row["z"] == 1

/proc/fish_probe_cases()
	var/list/routes = list("modern", "ordinary", "branch")
	for (var/outer_route in routes)
		for (var/inner_route in routes)
			fish_probe_reset()
			fish_probe_mode = "compete"
			fish_probe_inner_tool = fish_probe_tool(inner_route, fish_probe_inner)
			fish_probe_school.attackby(fish_probe_tool(outer_route, fish_probe_outer), fish_probe_outer)
			var/pair_ok = fish_probe_wait_delays.len == 2 && fish_probe_wait_stocks.len == 2 && fish_probe_chances.len == 1
			if (pair_ok)
				pair_ok = fish_probe_wait_delays[1] == fish_probe_delay(outer_route) && fish_probe_wait_delays[2] == fish_probe_delay(inner_route)
				pair_ok = pair_ok && fish_probe_wait_stocks[1] == 1 && fish_probe_wait_stocks[2] == 1
				pair_ok = pair_ok && fish_probe_chances[1] == fish_probe_chance(inner_route)
			pair_ok = pair_ok && fish_probe_school.counter == 0 && fish_probe_school.invisibility == 101
			pair_ok = pair_ok && fish_probe_refills == 1 && fish_probe_success_messages == 1 && fish_probe_failure_messages == 0 && fish_probe_starts == 2
			pair_ok = pair_ok && fish_probe_output_matches("fish", 4)
			fish_probe_check(pair_ok, "pair/[outer_route]/[inner_route]")
	for (var/cancel_route in routes)
		fish_probe_reset()
		fish_probe_mode = "cancel"
		fish_probe_school.attackby(fish_probe_tool(cancel_route, fish_probe_outer), fish_probe_outer)
		var/cancel_ok = fish_probe_wait_delays.len == 1 && fish_probe_chances.len == 0 && fish_probe_outputs.len == 0
		cancel_ok = cancel_ok && fish_probe_wait_delays[1] == fish_probe_delay(cancel_route)
		cancel_ok = cancel_ok && fish_probe_school.counter == 1 && fish_probe_school.invisibility == 0 && fish_probe_refills == 0
		cancel_ok = cancel_ok && fish_probe_success_messages == 0 && fish_probe_failure_messages == 0 && fish_probe_starts == 1
		fish_probe_check(cancel_ok, "cancel/[cancel_route]")
	for (var/chance_route in routes)
		fish_probe_reset()
		fish_probe_bite = 0
		fish_probe_school.attackby(fish_probe_tool(chance_route, fish_probe_outer), fish_probe_outer)
		var/chance_ok = fish_probe_wait_delays.len == 1 && fish_probe_chances.len == 1 && fish_probe_outputs.len == 0
		if (chance_ok)
			chance_ok = fish_probe_wait_delays[1] == fish_probe_delay(chance_route) && fish_probe_chances[1] == fish_probe_chance(chance_route)
		chance_ok = chance_ok && fish_probe_school.counter == 1 && fish_probe_school.invisibility == 0 && fish_probe_refills == 0
		chance_ok = chance_ok && fish_probe_success_messages == 0 && fish_probe_failure_messages == 1
		fish_probe_check(chance_ok, "miss/[chance_route]")
	for (var/species_route in routes)
		for (var/selected_species in list("fish", "salmon", "cod"))
			fish_probe_reset(selected_species)
			fish_probe_school.attackby(fish_probe_tool(species_route, fish_probe_outer), fish_probe_outer)
			var/species_ok = fish_probe_wait_delays.len == 1 && fish_probe_chances.len == 1
			if (species_ok)
				species_ok = fish_probe_wait_delays[1] == fish_probe_delay(species_route) && fish_probe_chances[1] == fish_probe_chance(species_route)
			species_ok = species_ok && fish_probe_school.counter == 0 && fish_probe_school.invisibility == 101 && fish_probe_refills == 1
			species_ok = species_ok && fish_probe_success_messages == 1 && fish_probe_failure_messages == 0
			species_ok = species_ok && fish_probe_output_matches(selected_species, 2)
			fish_probe_check(species_ok, "species/[species_route]/[selected_species]")

/proc/fish_probe_finish()
	fish_probe_cleanup()
	var/list/failed = list()
	for (var/label in fish_probe_verdicts)
		if (!fish_probe_verdicts[label])
			failed += label
	var/list/receipt = list("schema_version" = 1, "fixture" = "fishing-completion-v1", "source_head" = FISHING_SOURCE_HEAD, "source_sha256" = FISHING_SOURCE_SHA, "hook_sha256" = FISHING_HOOK_SHA, "variant" = FISHING_VARIANT, "byond_version" = world.byond_version, "byond_build" = world.byond_build, "initial_port" = fish_probe_initial_port, "port_closed" = fish_probe_port_closed, "reopen_refused" = fish_probe_reopen_refused, "clients" = fish_probe_clients, "topics" = fish_probe_topics, "cases" = fish_probe_verdicts, "failed_cases" = failed, "errors" = fish_probe_errors, "cleanup_owned_remaining" = fish_probe_owned.len)
	text2file(json_encode(receipt), "result.json")
	world.log << "FISHING_DONE"
	del(world)
	return

/world/New()
	fish_probe_initial_port = port
	OpenPort("none")
	fish_probe_port_closed = port == 0
	fish_probe_reopen_refused = OpenPort(0) == 0 && port == 0
	if (fish_probe_initial_port <= 0 || !fish_probe_port_closed || !fish_probe_reopen_refused)
		fish_probe_errors += "port contract failed"
		fish_probe_finish()
		return
	if (world.byond_version != 516 || world.byond_build != 1688)
		fish_probe_errors += "requires explicitly approved BYOND 516.1688"
		fish_probe_finish()
		return
	try
		fish_probe_cases()
	catch (var/exception/fixture_exception)
		fish_probe_errors += "exception: [fixture_exception]"
	fish_probe_finish()
	return
