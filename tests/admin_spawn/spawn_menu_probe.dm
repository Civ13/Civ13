// Native probe for the admin Spawn picker's catalog and search
// (code/modules/admin/spawn_menu.dm): build cost, search cost, ranking.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/admin_spawn/spawn_menu_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/spawn_probe_failures = 0
var/spawn_probe_runtime_error = FALSE
/proc/spawn_probe_check(condition, label)
	if (!condition)
		spawn_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	spawn_probe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	var/list/timings = list()
	try
		timings = spawn_probe_checks()
	catch(var/exception/e)
		spawn_probe_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = spawn_probe_failures, "runtime_error" = spawn_probe_runtime_error, "timings_ms" = timings, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/spawn_probe_ms(start)
	return round((world.timeofday - start) * 100) // timeofday is in tenths of a second

/proc/spawn_probe_checks()
	. = list()
	var/start = world.timeofday
	build_spawn_catalog()
	.["build"] = spawn_probe_ms(start)
	spawn_probe_check(spawn_catalog_paths.len == length(typesof(/atom)), "the catalog holds every atom type ([spawn_catalog_paths.len])")
	spawn_probe_check(spawn_catalog_index[/obj/item/stack/material/steel] && spawn_catalog_paths[spawn_catalog_index[/obj/item/stack/material/steel]] == /obj/item/stack/material/steel, "the index maps a path back to its entry")
	var/list/first = spawn_catalog_paths
	build_spawn_catalog()
	spawn_probe_check(first == spawn_catalog_paths, "the catalog is built once and reused")

	// Broad and narrow searches, 20 rounds each, timed together.
	var/list/queries = list("o", "item", "rifle", "steel sheet", "/turf/floor", "zzzz-nothing")
	for (var/q in queries)
		start = world.timeofday
		for (var/n = 1 to 20)
			search_spawn_catalog(q)
		.[q] = spawn_probe_ms(start) / 20

	var/list/total = list()
	var/list/hits = search_spawn_catalog("steel", "all", 150, FALSE, total)
	spawn_probe_check(hits.len <= 150 && total.len == 1 && total[1] >= hits.len, "results are capped and the full count is reported ([total[1]])")
	var/list/broad = list()
	spawn_probe_check(search_spawn_catalog("o", "all", 150, FALSE, broad).len == 150, "a one-letter search still returns at most the cap")
	spawn_probe_check(!search_spawn_catalog("zzzz-nothing").len, "a search with no match returns nothing")
	spawn_probe_check(!search_spawn_catalog("   ").len, "a blank search returns nothing")

	// Exact leaf first, then leaves and names that start with the word.
	hits = search_spawn_catalog("steel")
	var/list/leading = list()
	for (var/i = 1 to min(3, hits.len))
		leading += spawn_catalog_leaves[hits[i]]
	spawn_probe_check(hits.len && spawn_catalog_leaves[hits[1]] == "steel", "an exact leaf ranks first ([jointext(leading, ", ")])")

	// Every word must match, in path or name.
	var/ok = TRUE
	for (var/i in search_spawn_catalog("material steel"))
		if (!findtext(spawn_catalog_keys[i], "material") || !findtext(spawn_catalog_keys[i], "steel"))
			ok = FALSE
	spawn_probe_check(ok, "every word of a search must match")

	// Kinds filter.
	ok = TRUE
	for (var/i in search_spawn_catalog("floor", "turf"))
		if (!ispath(spawn_catalog_paths[i], /turf))
			ok = FALSE
	spawn_probe_check(ok && search_spawn_catalog("floor", "turf").len, "the turf filter keeps only turfs")

	// The typed verb form searches paths only.
	var/list/path_hits = search_spawn_catalog("/obj/item/stack/material/steel", "all", 2, TRUE)
	spawn_probe_check(path_hits.len >= 1 && spawn_catalog_paths[path_hits[1]] == /obj/item/stack/material/steel, "a full path ranks its own type first in the path-only search")
