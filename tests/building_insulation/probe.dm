// Native probe for room insulation (code/game/objects/building_insulation.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/building_insulation/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 60
	maxy = 30
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/building_insulation_probe/New()
	return
var/vr_failures = 0
var/vr_runtime_error = FALSE
/proc/vr_check(condition, label)
	if (!condition)
		vr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	vr_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/building_insulation_probe
		Master.start_timer_loop()
		vr_checks()
	catch(var/exception/e)
		vr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = vr_failures, "runtime_error" = vr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/area/insulation_probe_inside
	location = AREA_INSIDE
	climate = "tundra"

/proc/insul_room(x1, y1, x2, y2, wall_type)
	var/area/I = locate(/area/insulation_probe_inside)
	for (var/x in x1 to x2)
		for (var/y in y1 to y2)
			var/turf/T = locate(x, y, 1)
			I.contents += T
			if (!wall_type || (x != x1 && x != x2 && y != y1 && y != y2))
				continue
			if (ispath(wall_type, /turf))
				T.ChangeTurf(wall_type)
			else
				new wall_type(T)

/proc/insul_fresh(turf/T)
	var/datum/building_room/R = building_room_of[T]
	if (R)
		R.expires = 0
	return get_temp(T)

/proc/vr_checks()
	new /area/insulation_probe_inside
	var/area/outside = get_area(locate(1, 1, 1))
	outside.location = AREA_OUTSIDE
	outside.climate = "tundra"
	season = "WINTER"
	time_of_day = "Evening"
	var/open_air = get_temp(locate(1, 1, 1))
	vr_check(open_air <= -25, "open air is the tundra winter cold ([open_air])")

	// A bare roof only breaks the wind.
	insul_room(3, 3, 5, 5, null)
	var/roof_only = get_temp(locate(4, 4, 1))
	vr_check(roof_only == open_air + 5, "a roof alone shelters 5 C ([roof_only])")

	// A room in mapped walls stays as warm as before.
	insul_room(10, 3, 14, 7, /turf/wall)
	var/mapped = get_temp(locate(12, 5, 1))
	vr_check(mapped == 10, "a mapped stone room keeps 10 C ([mapped])")

	// A closed wooden room holds less than mapped stone.
	insul_room(20, 3, 24, 7, /obj/covers/wood_wall)
	var/wood = get_temp(locate(22, 5, 1))
	vr_check(wood < mapped && wood > roof_only, "a wooden room is between a roof and stone ([wood])")
	var/datum/building_room/R = building_room_at(locate(22, 5, 1))
	vr_check(R && !R.draughty && R.turfs.len == 9, "the wooden room is 9 closed tiles")

	// A gap makes it draughty.
	var/obj/covers/gap = locate(/obj/covers) in locate(24, 5, 1)
	qdel(gap)
	var/draughty = insul_fresh(locate(22, 5, 1))
	R = building_room_at(locate(22, 5, 1))
	vr_check(R && R.draughty && draughty < wood && draughty >= roof_only, "a hole in the wall makes it draughty ([draughty])")

	// A closed curtain over the hole closes the room again, but less well than the wall.
	var/obj/structure/curtain/CU = new /obj/structure/curtain(locate(24, 5, 1))
	var/curtained = insul_fresh(locate(22, 5, 1))
	R = building_room_at(locate(22, 5, 1))
	vr_check(R && !R.draughty && curtained > draughty && curtained <= wood, "a closed curtain stops the draught ([curtained])")
	CU.opacity = FALSE
	vr_check(insul_fresh(locate(22, 5, 1)) == draughty, "an open curtain lets it through again")
	CU.opacity = TRUE

	// Lining the walls with wool keeps more warmth in.
	for (var/obj/covers/C in range(3, locate(22, 5, 1)))
		C.insulation_lining = "wool"
	var/lined = insul_fresh(locate(22, 5, 1))
	vr_check(lined > curtained, "wool-lined walls hold more warmth ([lined])")
	vr_check(building_lining_kind(new /obj/item/stack/material/straw) == "straw" && !building_lining_kind(new /obj/item/stack/material/wood), "straw lines a wall, planks do not")

	// A brazier heats its room; a bigger room needs more fire.
	insul_room(30, 3, 42, 7, /obj/covers/wood_wall)
	var/hall_cold = get_temp(locate(41, 5, 1))
	var/obj/structure/brazier/B = new /obj/structure/brazier(locate(31, 5, 1))
	B.on = TRUE
	var/hall_warm = insul_fresh(locate(41, 5, 1))
	vr_check(hall_warm > hall_cold && hall_warm < 22, "a brazier warms a long hall, not fully ([hall_cold] -> [hall_warm])")
	var/obj/structure/brazier/B2 = new /obj/structure/brazier(locate(36, 5, 1))
	B2.on = TRUE
	var/hall_warmer = insul_fresh(locate(41, 6, 1))
	vr_check(hall_warmer > hall_warm, "two braziers warm it more ([hall_warmer])")

	// In the open a fire warms only those beside it.
	var/obj/structure/brazier/OB = new /obj/structure/brazier(locate(50, 20, 1))
	OB.on = TRUE
	vr_check(get_temp(locate(52, 20, 1)) == 22, "two tiles from an outdoor fire is warm")
	vr_check(get_temp(locate(53, 20, 1)) == open_air, "three tiles from an outdoor fire is not")

	// The room is remembered between asks.
	var/datum/building_room/again = building_room_at(locate(41, 5, 1))
	vr_check(again && again == building_room_at(locate(31, 4, 1)), "the room is surveyed once for all its tiles")
	vr_check(findtext(building_room_warmth_text(again), "insulated"), "Judge This Room describes the warmth")
