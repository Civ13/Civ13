// Breaches and breakable glass on modular vehicles (docs/vessel-entries.md).
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
/obj/map_metadata/vehicle_breaches_probe/New()
	return
/mob/living/vehicle_breaches_probe/New()
	return
var/breach_failures = 0
var/breach_runtime_error = FALSE
/proc/breach_check(condition, label)
	if (!condition)
		breach_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	breach_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/breach_frame(x, y)
	var/obj/structure/vehicleparts/frame/F = new(locate(x, y, 1))
	F.dir = NORTH
	F.w_front = list("c_wall", TRUE, TRUE, 20, 50, FALSE, FALSE)
	F.w_back = list("c_door", TRUE, TRUE, 20, 45, TRUE, FALSE)
	F.w_left = list("c_window", FALSE, TRUE, 10, 40, FALSE, FALSE)
	F.w_right = list("c_armoredwall", TRUE, TRUE, 55, 90, FALSE, FALSE)
	return F

/proc/breach_checks()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			locate(x, y, 1).ChangeTurf(/turf/floor/dirt)
	var/obj/structure/vehicleparts/frame/F = breach_frame(5, 5)
	var/mob/living/vehicle_breaches_probe/walker = new(locate(5, 5, 1))

	// Sides: the same table as CheckExit.
	breach_check(F.side_toward(NORTH) == "front" && F.side_toward(SOUTH) == "back" && F.side_toward(WEST) == "left" && F.side_toward(EAST) == "right", "facing north, each world direction names its side")
	F.dir = EAST
	breach_check(F.side_toward(EAST) == "front" && F.side_toward(NORTH) == "left" && F.side_toward(SOUTH) == "right" && F.side_toward(WEST) == "back", "facing east, the sides turn with the frame")
	F.dir = NORTH

	// A wall shot to nothing is a hole.
	breach_check(!F.CheckExit(walker, locate(5, 6, 1), NORTH), "a whole wall blocks the way out")
	F.w_front[5] = -1
	F.try_destroy()
	breach_check(F.w_front[5] == 0 && F.w_front[7] && !F.w_front[3], "a wall with no health left is a breach")
	breach_check(F.CheckExit(walker, locate(5, 6, 1), NORTH), "people climb out through the breach")
	breach_check(F.breached_walls && F.breached_walls["front"] && F.breached_walls["front"][4] == 20, "the frame remembers what the wall was")
	F.w_front[5] = -5
	F.try_destroy()
	breach_check(F.breached_walls["front"][4] == 20, "a second blast does not overwrite what the wall was")
	breach_check(F.breach_sides() ~= list("front"), "the breach is listed for welding")

	// Wrecked doors hang open as before, and are not breaches to weld.
	F.w_back[5] = -1
	F.try_destroy()
	breach_check(F.w_back[7] && !F.breached_walls["back"], "a wrecked door hangs open and is not a breach")

	// Welding the breach shut.
	breach_check(F.mend_breach("front") && F.w_front[1] == "c_wall" && F.w_front[3] && !F.w_front[7] && F.w_front[5] == 20 && !F.breached_walls, "welding the breach gives the wall back at mended health")
	breach_check(!F.CheckExit(walker, locate(5, 6, 1), NORTH), "the mended wall blocks again")
	breach_check(!F.mend_breach("front"), "there is nothing left to weld")

	// Glass.
	breach_check(F.glass_sides() ~= list("left"), "only the window counts as glass, not walls, doors or armour")
	breach_check(F.smash_glass("left") && F.w_left[7] && F.CheckExit(walker, locate(4, 5, 1), WEST), "smashed glass leaves a hole to climb through")
	breach_check(F.breached_walls["left"] && !F.glass_sides().len, "smashed glass is a breach and is no longer glass")
	breach_check(!F.smash_glass("right"), "armour cannot be smashed like glass")
	breach_check(vehicle_wall_glass(list("c_windshield", FALSE, TRUE, 6, 35, FALSE, FALSE)) && vehicle_wall_glass(list("c_windoweddoor", TRUE, TRUE, 10, 25, TRUE, FALSE)), "windshields and glazed doors are glass")
	breach_check(!vehicle_wall_glass(list("sub_glass", FALSE, TRUE, 30, 80, FALSE, FALSE)), "a submarine's glass bow is pressure glass, not a window")

	// Submarine pressure hulls never open this way.
	var/obj/structure/vehicleparts/frame/ship/steel/submarine/S = new(locate(2, 2, 1))
	S.w_left = list("sub_hull", TRUE, TRUE, 40, 100, FALSE, FALSE)
	S.w_left[5] = -1
	S.try_destroy()
	breach_check(!S.w_left[7] && !S.breached_walls, "a wrecked submarine hull stays shut")

/proc/breach_run()
	try
		breach_checks()
	catch(var/exception/e)
		breach_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = breach_failures, "runtime_error" = breach_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/vehicle_breaches_probe
	catch(var/exception/e)
		breach_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		breach_run()
