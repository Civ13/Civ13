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
	// The isolated runner bypasses global_init/New(), including round identity.
	generate_gameid()
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
	// Ordinary dirt channels are not the flooded trench subtypes below. Keep
	// these disconnected from sources so constructor defaults cannot fake a pass.
	var/list/ordinary_irrigation = list(list(2,4,0,0), list(5,4,1,0), list(8,4,1,1))
	for(var/list/channel_case in ordinary_irrigation)
		var/turf/floor/plot = locate(channel_case[1],channel_case[2],1)
		plot.irrigate(channel_case[4] ? "salty" : channel_case[3] ? "fresh" : "empty")
		plot.name = "custom saved channel [channel_case[1]]"
	var/turf/floor/filled_plot = locate(11,4,1)
	filled_plot.flooded = TRUE
	filled_plot.salty = TRUE // Residue on a non-channel must not revive irrigation.
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
	var/savefile/irrigation_file = new("map_saves/1.sav")
	var/dry_ref = irrigation_file["/map/1/4/2"]
	var/dry_path = map_storage.entry_path(irrigation_file, dry_ref)
	var/fresh_ref = irrigation_file["/map/1/4/5"]
	var/fresh_path = map_storage.entry_path(irrigation_file, fresh_ref)
	var/list/saved_dry = irrigation_file["[dry_path]/flooded"]
	var/list/saved_fresh_salt = irrigation_file["[fresh_path]/salty"]
	trench_check(islist(saved_dry) && saved_dry["kind"] == "value" && saved_dry["value"] == FALSE, "dry channel writes an explicit zero flooded flag")
	trench_check(islist(saved_fresh_salt) && saved_fresh_salt["kind"] == "value" && saved_fresh_salt["value"] == FALSE, "fresh channel writes an explicit zero salt flag")
	for(var/list/channel_case in ordinary_irrigation)
		var/turf/floor/plot = locate(channel_case[1],channel_case[2],1)
		plot.ChangeTurf(/turf/floor/beach/sand, FALSE, FALSE)
		plot = locate(channel_case[1],channel_case[2],1)
		plot.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		plot = locate(channel_case[1],channel_case[2],1)
		plot.irrigate("salty") // Poison same-type destination state after true replacement.
	filled_plot.irrigate("salty")
	for(var/list/xyz in coords)
		var/turf/T = locate(xyz[1],xyz[2],xyz[3])
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	D.trench_stage = 0
	S.trench_stage = 0
	trench_check(map_storage.validate_world_save(), "production preflight accepts trench save")
	map_storage.ClearMap()
	trench_check(map_storage.Load_World(), "production whole-world import succeeds")
	for(var/list/channel_case in ordinary_irrigation)
		var/turf/floor/plot = locate(channel_case[1],channel_case[2],1)
		trench_check(istype(plot, /turf/floor/dirt) && plot.irrigation && plot.flooded == channel_case[3] && plot.salty == channel_case[4], "ordinary irrigation flags survive without natural sources")
		var/expected_icon = channel_case[3] ? "irrigation0_flooded" : "irrigation0"
		trench_check(plot.irrigation_overlay && plot.irrigation_overlay.icon_state == expected_icon, "ordinary irrigation overlay rebuilds from restored flags")
	filled_plot = locate(11,4,1)
	trench_check(!filled_plot.irrigation && !filled_plot.irrigation_overlay, "non-channel save clears poisoned live irrigation")
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
