// A save written before a var was removed must still load (Gaia handover,
// 2026-11-17: research benches saved tier_progress after it was removed).
/obj/map_metadata/removed_field_fixture/New()
	return
/obj/item/removed_field_fixture
	name = "removed field fixture"
	var/kept_field = 0
	var/retired_field = 0
/proc/removed_field_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "removed_field_result.txt")
		del(world)
		sleep(1)
/world
	hub = ""
	hub_password = ""
	maxx = 4
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Removed field fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "removed_field_result.txt")
	del(world)
	sleep(1)
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	map = new /obj/map_metadata/removed_field_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/item/removed_field_fixture/F = new(locate(2,2,1))
	F.kept_field = 5
	F.retired_field = 7
	sleep(10)
	removed_field_check(map_storage.Save_World(), "whole-world export succeeds")
	removed_field_check(map_storage.validate_world_save(), "preflight accepts the save: [map_storage.last_error]")
	map_storage.ClearMap()
	// The next build no longer has retired_field: drop it from the type's var names.
	var/list/names = persistence_type_vars(new /obj/item/removed_field_fixture).Copy()
	names -= "retired_field"
	persistence_type_var_names[/obj/item/removed_field_fixture] = names
	removed_field_check(map_storage.Load_World(), "import succeeds past a removed field: [map_storage.last_error]")
	sleep(10)
	F = locate(/obj/item/removed_field_fixture) in locate(2,2,1)
	removed_field_check(F, "fixture is restored")
	removed_field_check(F.kept_field == 5, "a field the code still has is restored ([F.kept_field])")
	removed_field_check(F.retired_field == 0, "the removed field is left behind ([F.retired_field])")
	text2file("PASS: a save with a removed field still loads", "removed_field_result.txt")
	del(world)
