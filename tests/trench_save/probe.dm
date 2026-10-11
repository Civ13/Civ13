/obj/map_metadata/trench_fixture/New()
	return
/proc/trench_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "trench_result.txt")
		del(world)
		sleep(1)
/proc/trench_appearance(turf/floor/T)
	var/list/result = list("[T.icon]", T.icon_state, T.plane, T.flooring.type)
	for(var/image/I in T.overlays)
		result += "[I.icon]|[I.icon_state]|[I.dir]|[I.plane]"
	return jointext(result, ";")
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 8
	maxz = 2
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Trench fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e]"
	text2file("FAIL: runtime [e]", "trench_result.txt")
	del(world)
	sleep(1)
/world/New()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	map = new /obj/map_metadata/trench_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	season = "SUMMER"
	var/obj/map_metadata/original_map = map
	for(var/turf/T in world)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	// Connected dry bend, isolated fresh and salty channels, plus z-level edge.
	new /turf/floor/trench(locate(2,2,1))
	new /turf/floor/trench(locate(3,2,1))
	new /turf/floor/trench(locate(3,3,1))
	new /turf/floor/trench/flooded(locate(7,2,1))
	new /turf/floor/trench/flooded(locate(8,2,1))
	new /turf/floor/trench/flooded/salty(locate(7,6,1))
	new /turf/floor/trench(locate(12,8,2))
	var/turf/floor/dirt/D = locate(2,6,1)
	D.trench_stage = 1
	var/turf/floor/beach/sand/S = new(locate(3,6,1))
	S.trench_stage = 1
	var/turf/floor/trench/dry = locate(2,2,1)
	dry.trench_filling = 1
	var/turf/floor/trench/flooded/wet = locate(7,2,1)
	var/obj/covers/repairedfloor/bridge = new(wet)
	bridge.name = "saved trench bridge"
	wet.check_bridge()
	var/obj/structure/closet/crate/C = new(dry)
	C.name = "saved trench crate"
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(C)
	K.name = "saved trench knife"
	sleep(10)
	var/list/geometry = list()
	var/list/coords = list(list(2,2,1),list(3,2,1),list(3,3,1),list(7,2,1),list(8,2,1),list(7,6,1),list(12,8,2))
	for(var/list/xyz in coords)
		var/turf/floor/T = locate(xyz[1],xyz[2],xyz[3])
		geometry[jointext(xyz, ",")] = trench_appearance(T)
	trench_check(map_storage.Save_World(), "production whole-world export succeeds")
	for(var/list/xyz in coords)
		var/turf/T = locate(xyz[1],xyz[2],xyz[3])
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	D.trench_stage = 0
	S.trench_stage = 0
	trench_check(map_storage.validate_world_save(), "production preflight accepts trench save")
	map_storage.ClearMap()
	trench_check(map_storage.Load_World(), "production whole-world import succeeds")
	sleep(10)
	for(var/list/xyz in coords)
		var/turf/floor/T = locate(xyz[1],xyz[2],xyz[3])
		trench_check(istype(T, /turf/floor/trench), "trench type and coordinate survives [jointext(xyz,",")]")
		trench_check(trench_appearance(T) == geometry[jointext(xyz,",")], "trench flooring, plane and neighbor overlays survive [jointext(xyz,",")]")
	trench_check(locate(7,2,1):flooded && !locate(7,2,1):salty && locate(7,6,1):salty, "fresh and salty flooded state survives")
	C = locate(/obj/structure/closet/crate) in locate(2,2,1)
	trench_check(C && C.name == "saved trench crate", "trench crate survives at correct turf")
	K = locate(/obj/item/weapon/material/kitchen/utensil/knife) in C
	trench_check(K && K.name == "saved trench knife" && K.loc == C, "nested trench item survives")
	bridge = locate(/obj/covers/repairedfloor) in locate(7,2,1)
	trench_check(bridge && bridge.name == "saved trench bridge", "trench bridge survives")
	trench_check(map == original_map, "map metadata identity survives")
	world.log << "PASS: trench geometry/types/overlays/flooding/contents/metadata"
	dry = locate(2,2,1)
	world.log << "Restored progress: fill=[dry.trench_filling], dirt=[locate(2,6,1):trench_stage], sand=[locate(3,6,1):trench_stage]"
	trench_check(dry.trench_filling == 1, "trench fill progress survives")
	D = locate(2,6,1)
	S = locate(3,6,1)
	trench_check(D.trench_stage == 1 && S.trench_stage == 1, "dirt and sand partial digging survives")
	// The preserved first dirt deposit must let the next deposit complete filling.
	dry.trench_filling++
	dry.check_filling()
	trench_check(!istype(locate(2,2,1), /turf/floor/trench), "second deposit completes restored fill")
	text2file("PASS: whole-world trench geometry, overlays, flooding, contents, partial digging and filling", "trench_result.txt")
	del(world)
