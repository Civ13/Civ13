#define TRUE 1
#define FALSE 0
var/list/failures = list()
var/list/controls = list()
var/checks = 0
var/scenarios = 0

/world
	maxx = 4
	maxy = 4
	maxz = 2
	fps = 20
	turf = /turf
	New()
		..()
		OpenPort("none")
		spawn(1)
			run_probe()
	OpenPort(port)
		if(port == "none") return ..()
		return FALSE

// Native /client instances cannot be constructed. Only verb ownership is
// adapted; the released-key bodies and controller callbacks remain production.
/datum/movement_client
	var/mob/mob
/mob
	var/movement_eastwest
	var/movement_northsouth
	var/using_drone = FALSE
	var/next_move = 123
	var/next_click = 456
/obj/item
/obj/item/drone_controller
	var/stop_calls = 0
	proc/stop_move_drone()
		stop_calls++
/obj/item/turret_controls
	var/is_rotating = FALSE
	var/rotating_dir = 0
	var/obj/structure/turret/turret
/obj/structure/turret
	var/azimuth_calls = 0
	var/last_direction = 0
	proc/increase_target_azimuth(direction)
		azimuth_calls++
		last_direction = direction

/proc/check(condition, label)
	checks++
	if(!condition)
		failures += label

/proc/controller(atom/holder)
	var/obj/item/turret_controls/C = new(holder)
	C.turret = new(locate(4, 4, 1))
	controls += C
	return C

/proc/stop_all()
	for(var/obj/item/turret_controls/C in controls)
		C.stop_rotation()
	sleep(1)

/proc/run_probe()
	var/datum/movement_client/input_owner = new
	input_owner.stopmovingright()
	input_owner.stopmovingleft()
	check(TRUE, "null mob releases complete")
	scenarios++

	var/mob/M = new(locate(1, 1, 1))
	var/mob/other = new(locate(2, 2, 2))
	input_owner.mob = M
	var/obj/item/drone_controller/drone = new(M)
	var/obj/item/turret_controls/C = controller(M)
	M.movement_eastwest = EAST
	M.movement_northsouth = NORTH
	M.using_drone = TRUE
	C.start_rotation(1)
	sleep(2)
	check(C.turret.azimuth_calls > 0, "production scheduled rotation starts")
	check(C.turret.last_direction == 1, "east rotation sign preserved")
	var/atom/original_location = M.loc
	input_owner.stopmovingright()
	check(isnull(M.movement_eastwest), "east axis released")
	check(M.movement_northsouth == NORTH, "diagonal north axis preserved")
	check(!C.is_rotating && C.rotating_dir == 0, "east release clears controller flags")
	check(drone.stop_calls == 1, "active drone release preserved")
	check(M.loc == original_location, "release preserves mob location")
	check(M.next_move == 123 && M.next_click == 456, "release preserves action clocks")
	var/stopped_calls = C.turret.azimuth_calls
	sleep(3)
	check(C.turret.azimuth_calls == stopped_calls, "east release stops scheduled rotation")
	stop_all()
	scenarios++

	M.movement_eastwest = WEST
	M.using_drone = FALSE
	C.start_rotation(-1)
	sleep(2)
	check(C.turret.last_direction == -1, "west rotation sign preserved")
	input_owner.stopmovingleft()
	check(isnull(M.movement_eastwest), "west axis released")
	check(!C.is_rotating && C.rotating_dir == 0, "west release clears controller flags")
	check(drone.stop_calls == 1, "inactive drone is not stopped")
	stopped_calls = C.turret.azimuth_calls
	sleep(3)
	check(C.turret.azimuth_calls == stopped_calls, "west release stops scheduled rotation")
	stop_all()
	scenarios++

	M.movement_eastwest = WEST
	C.start_rotation(-1)
	input_owner.stopmovingright()
	check(M.movement_eastwest == WEST, "stale east release preserves newer west key")
	check(C.is_rotating && C.rotating_dir == -1, "opposite release keeps current rotation")
	stopped_calls = C.turret.azimuth_calls
	sleep(3)
	check(C.turret.azimuth_calls > stopped_calls, "opposite-key loop continues")
	input_owner.stopmovingleft()
	check(!C.is_rotating, "matching newer key stops rotation")
	stop_all()
	scenarios++

	var/obj/item/turret_controls/foreign = controller(other)
	M.movement_eastwest = EAST
	other.movement_eastwest = EAST
	C.start_rotation(1)
	foreign.start_rotation(1)
	input_owner.stopmovingright()
	check(!C.is_rotating, "owned controller stops")
	check(foreign.is_rotating, "other mob controller remains active")
	check(other.movement_eastwest == EAST, "other mob input remains unchanged")
	check(other.z == 2, "other z-level location remains unchanged")
	stop_all()
	scenarios++

	var/obj/container = new(M)
	var/obj/item/turret_controls/nested = controller(container)
	M.movement_eastwest = WEST
	C.start_rotation(-1)
	nested.start_rotation(-1)
	input_owner.stopmovingleft()
	check(!C.is_rotating, "directly carried controller stops")
	check(nested.is_rotating, "nested controller is not selected")
	check(C.loc == M && nested.loc == container, "inventory references preserved")
	stop_all()
	scenarios++

	M.movement_eastwest = null
	M.using_drone = TRUE
	C.start_rotation(1)
	input_owner.stopmovingright()
	input_owner.stopmovingleft()
	check(C.is_rotating, "duplicate unmatched releases do not stop unrelated rotation")
	check(drone.stop_calls == 1, "duplicate releases preserve drone call count")
	input_owner.mob = null
	input_owner.stopmovingright()
	check(C.is_rotating, "detached input owner does not control old mob")
	stop_all()
	scenarios++

	text2file(json_encode(list("scenarios" = scenarios, "checks" = checks, "failures" = failures)), "result.json")
	del(world)
