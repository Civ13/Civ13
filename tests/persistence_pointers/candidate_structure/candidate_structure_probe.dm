// Native fixture for the in-memory candidate check of a stream save
// (record_candidate_level_structure in saving.dm). The collector force-deletes
// a queued object the save still pins once its grace period passes; del()
// then nulls the pin. Such an entry was already written, so the check must
// pass it, and must still reject an entry that is not a placeable datum.
var/structure_case
var/structure_checks = 0
var/structure_runtime_failed = FALSE

/world
	name = "Civ13 isolated candidate structure fixture"
	maxx = 3
	maxy = 2
	maxz = 2
	fps = 10
	visibility = 0
	sleep_offline = FALSE
	turf = /turf/candidate_structure
	hub = ""
	hub_password = ""
/world/OpenPort(port)
	return ..("none")
/client/New()
	del(src)
/world/Error(exception/E)
	structure_runtime_failed = TRUE
	world.log << "Unexpected runtime error: [E] at [E.file]:[E.line]"

/turf/candidate_structure
/obj/candidate_item

/proc/structure_check(condition, message)
	structure_checks++
	if(!condition) throw EXCEPTION(message)

// Pins a turf, an item in it and a second item in the item, as the exporter
// does, then deletes the inner item the way the collector does.
/proc/structure_run(deleted_child, area_entry)
	var/turf/T = locate(1, 1, 1)
	var/obj/candidate_item/outer = new(T)
	var/obj/candidate_item/inner = new(outer)
	map_storage.saving_reference_pins = list(T, outer, inner)
	map_storage.saving_content_owners = list("2" = 1, "3" = 2)
	if(area_entry) map_storage.saving_reference_pins += T.loc
	if(deleted_child)
		del(inner)
		structure_check(isnull(map_storage.saving_reference_pins[3]), "del() did not clear the pin")
	try
		map_storage.record_candidate_level_structure(1)
	catch(var/exception/check_error)
		return check_error.name
	return null

/world/New()
	OpenPort("none")
	..()
	sleep(1)
	structure_case = world.params["case"]
	var/result = "PASS"
	try
		structure_check(!world.port, "fixture opened a network port")
		map = new /obj/map_metadata(locate(3,2,1))
		map_storage = new /map_storage("candidate-structure-fixture")
		switch(structure_case)
			if("live")
				var/error = structure_run(FALSE, FALSE)
				structure_check(!error, "live entries were rejected: [error]")
				structure_check(map_storage.saving_candidate_structure["1"]["entries"] == 3, "wrong entry count")
			if("deleted")
				var/error = structure_run(TRUE, FALSE)
				structure_check(!error, "an entry deleted after capture was rejected: [error]")
				structure_check(map_storage.saving_candidate_structure["1"]["entries"] == 3, "wrong entry count")
			if("area")
				var/error = structure_run(FALSE, TRUE)
				structure_check(findtext(error, "Unsupported saved entry 4 on z=1") == 1, "an area entry was admitted: [error]")
				structure_check(!map_storage.saving_candidate_structure || !("1" in map_storage.saving_candidate_structure), "a refused level recorded a structure")
			else throw EXCEPTION("Unknown candidate structure fixture scenario")
	catch(var/exception/probe_error)
		result = "FAIL: [probe_error.name]"
	text2file(json_encode(list("case" = structure_case, "done" = TRUE, "result" = result, "checks" = structure_checks, "runtime_failed" = structure_runtime_failed, "port" = world.port)), "result.json")
	del(world)
	sleep(1)
