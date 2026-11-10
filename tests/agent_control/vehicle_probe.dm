// Native probe for agent vehicle controls (code/modules/agent_control/agent_vehicles.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/agent_control/vehicle_probe.dm
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
/mob/living/human/vehicle_probe/New()
	return
/mob/living/human/vehicle_probe/update_icons()
	return
/mob/living/human/vehicle_probe/movement_delay()
	return 1
var/vehicle_failures = 0
var/vehicle_runtime_error = FALSE
/proc/vehicle_check(condition, label)
	if (!condition)
		vehicle_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	vehicle_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		vehicle_checks()
	catch(var/exception/e)
		vehicle_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = vehicle_failures, "runtime_error" = vehicle_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/obj/structure/turret/vehicle_probe/New()
	return
/obj/structure/turret/vehicle_probe/increase_target_azimuth(value)
	azimuth_to_target += value

/proc/drive_try(datum/agent_character/C, control)
	try
		return agent_control.agent_drive(C, list("control" = control))
	catch(var/exception/e)
		return e.desc

/proc/step_try(datum/agent_identity/A, datum/agent_character/C, d, hold = 5)
	try
		return agent_control.agent_walk_step(A, C, d, TRUE, hold)
	catch(var/exception/e)
		return e.desc

/proc/vehicle_checks()
	var/datum/agent_identity/A = new
	A.name = "probe"
	var/mob/living/human/vehicle_probe/H = new(locate(5, 5, 1))
	H.species = new /datum/species/human
	H.stats = list("stamina" = list(100, 100))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.m_intent = "walk"
	var/datum/agent_character/C = new
	C.body = H
	agent_characters[H] = C
	vehicle_check(findtext(drive_try(C, "gear_up"), "not_driving") == 1, "drive needs a driver's seat")
	vehicle_check(isnull(agent_driving_row(H)), "no driving row outside a seat")

	// A car: driver's seat on an axis.
	var/obj/structure/vehicleparts/axis/V = new(locate(5, 5, 1))
	var/obj/structure/bed/chair/drivers/D = new(locate(5, 5, 1))
	D.axis = V
	H.buckled = D
	vehicle_check(drive_try(C, "reverse") == "reverse ([V.name])" && V.reverse, "the reverse button sets reverse")
	vehicle_check(drive_try(C, "forward") == "forward ([V.name])" && !V.reverse, "the forward button sets forward")
	vehicle_check(findtext(drive_try(C, "turn_left"), "cannot_turn") == 1, "turning fails while the car cannot turn")
	vehicle_check(findtext(drive_try(C, "climb"), "bad_type") == 1, "a car cannot climb")
	vehicle_check(findtext(drive_try(C, "honk"), "bad_args") == 1, "unknown controls are refused")
	var/list/row = agent_driving_row(H)
	vehicle_check(row && row["gear"] == 0 && row["reverse"] == FALSE && row["engine"] == "none", "the driving row shows gear, direction and engine")

	// The arrow keys with the wheel in hand: south picks reverse while stopped, north forward.
	var/obj/structure/vehicleparts/frame/F = new(locate(5, 5, 1))
	F.axis = V
	D.wheel.control = F
	D.wheel.loc = H
	var/list/res = step_try(A, C, SOUTH)
	vehicle_check(islist(res) && res["moved"] == FALSE && ("reverse" in res["controls"]) && V.reverse, "a seated south key picks reverse")
	res = step_try(A, C, NORTH)
	vehicle_check(islist(res) && ("forward" in res["controls"]) && !V.reverse, "a seated north key picks forward")
	vehicle_check(get_turf(H) == locate(5, 5, 1), "seated arrow keys do not walk")
	V.currentspeed = 2
	V.moving = TRUE
	res = step_try(A, C, SOUTH)
	vehicle_check(islist(res) && !V.reverse, "the gearbox does not reverse while moving")
	V.currentspeed = 0
	V.moving = FALSE
	D.wheel.loc = D
	H.buckled = null

	// An aircraft seat: climb on the ground explains the takeoff.
	var/obj/structure/vehicleparts/axis/aircraft/P = new(locate(5, 5, 1))
	D.axis = P
	H.buckled = D
	vehicle_check(findtext(drive_try(C, "climb"), "cannot_climb:Start the engine") == 1, "climbing on the ground gives the takeoff hint")
	vehicle_check(findtext(drive_try(C, "descend"), "cannot_descend") == 1, "descending on the ground is refused")
	row = agent_driving_row(H)
	vehicle_check(row && row["flight"] == "ground" && !isnull(row["altitude"]), "the driving row shows the flight state")
	H.buckled = null

	// Turret controls: north and south change range, east and west turn while held.
	var/obj/structure/turret/vehicle_probe/T = new(locate(5, 5, 1))
	var/obj/item/turret_controls/TC = new(H)
	TC.turret = T
	H.buckled = D
	var/range = T.distance
	step_try(A, C, NORTH)
	vehicle_check(T.distance == range + 1, "north raises turret range")
	res = step_try(A, C, EAST, 3)
	vehicle_check(TC.is_rotating && TC.rotating_dir == 1 && ("turret turning right" in res["controls"]), "east starts turning the turret")
	res = step_try(A, C, WEST)
	vehicle_check(!TC.is_rotating && ("turret stopped" in res["controls"]), "the opposite key stops the turret")
	var/list/remotes = agent_remote_rows(H)
	vehicle_check(remotes.len == 1 && remotes[1]["control"] == "turret" && remotes[1]["distance"] == range + 1, "turret controls are reported")
	qdel(TC)
	H.buckled = null

	// A drone controller in use: the arrow key flies the drone and the body stays put.
	var/obj/item/drone_controller/RC = new(H)
	H.using_drone = RC
	H.forceMove(locate(2, 8, 1))
	res = step_try(A, C, EAST)
	vehicle_check(islist(res) && !res["moved"] && ("drone east" in res["controls"]) && RC.moving_dir == EAST && H.x == 2, "an active drone takes the arrow key and the body stays put")
	H.using_drone = null
	res = step_try(A, C, EAST)
	vehicle_check(islist(res) && res["moved"] && isnull(res["controls"]) && H.x == 3, "an inactive drone controller leaves walking alone")
	vehicle_check(agent_remote_rows(H).len == 1, "the drone controller is reported")
