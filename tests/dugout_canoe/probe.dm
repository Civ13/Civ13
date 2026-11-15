// Native dugout canoe probe, included by tests/ecology_spawning/run_linux.py, never by
// the game DME. It drives code/modules/1713/dugout_canoe.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/canoe_probe/New()
	map = src
/mob/living/human/canoe_probe/New()
	icon_update = FALSE
	return
var/canoe_failures = 0
var/canoe_runtime_error = FALSE
/proc/canoe_check(condition, label)
	if (!condition)
		canoe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	canoe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"


/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/canoe_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		for (var/turf/T in block(locate(10, 1, 1), locate(12, 30, 1)))
			T.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
		locate(13, 5, 1):ChangeTurf(/turf/floor/beach/water/deep/saltwater, FALSE, FALSE)
		locate(13, 8, 1):ChangeTurf(/turf/floor/beach/water/shallowsaltwater, FALSE, FALSE)
		canoe_log_checks()
		canoe_water_checks()
	catch(var/exception/e)
		canoe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = canoe_failures, "runtime_error" = canoe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/canoe_log_checks()
	var/obj/structure/dugout_log/L = new(locate(3, 3, 1))
	canoe_check(L.icon_state == "dugout_log0", "a fresh log")
	L.stage = 3
	L.update_icon()
	canoe_check(L.icon_state == "dugout_log1_charred", "stage three shows the charred second hollow")
	canoe_check(dugout_hollowing_tool(new /obj/item/weapon/material/hatchet/tribal/adze) == DUGOUT_HOLLOW_TIME, "an adze hollows at full speed")
	canoe_check(!dugout_hollowing_tool(new /obj/item/weapon/paddle), "a paddle does not hollow")
	var/mob/living/human/canoe_probe/H = new(locate(3, 4, 1))
	L.finish(H)
	var/obj/structure/vehicle/raft/dugout/C = locate() in locate(3, 3, 1)
	canoe_check(C && QDELETED(L), "finishing turns the log into a canoe")
	canoe_check(C && C.mobcapacity == 2 && C.storagecapacity == 1, "two seats and one crate")

/proc/canoe_water_checks()
	var/obj/structure/vehicle/raft/dugout/C = new(locate(12, 5, 1))
	var/mob/living/human/canoe_probe/H = new(locate(12, 5, 1))
	C.driver = H
	C.ontop += H
	H.dir = NORTH
	canoe_check(C.do_vehicle_check(), "fresh water ahead is fine")
	H.dir = EAST
	canoe_check(!C.do_vehicle_check(), "the open sea is refused")
	C.forceMove(locate(12, 8, 1))
	H.forceMove(locate(12, 8, 1))
	map.windspeedvar = 1
	canoe_check(C.do_vehicle_check(), "calm shallow salt water is fine")
	map.windspeedvar = 3
	canoe_check(!C.do_vehicle_check(), "rough salt water is refused")
	map.windspeedvar = 1
	C.forceMove(locate(10, 8, 1))
	H.forceMove(locate(10, 8, 1))
	H.dir = WEST
	canoe_check(!C.do_vehicle_check(), "dry land is refused")
	canoe_check(!C.paddling(), "no paddle, no paddling")
	H.r_hand = new /obj/item/weapon/paddle(H)
	canoe_check(C.paddling(), "a paddle in hand paddles")
	H.dir = NORTH
	var/mob/living/human/canoe_probe/P = new(locate(10, 8, 1))
	C.ontop += P
	C.update_icon()
	canoe_check(H.pixel_y == -P.pixel_y && H.pixel_y != 0, "the two sit one behind the other")
