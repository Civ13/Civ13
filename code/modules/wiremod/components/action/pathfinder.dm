// Pathfinder walks a bounded AStar path one step per trigger. It never moves
// the shell itself: it names the next direction, and the circuit decides what
// to do with it.
/obj/item/circuit_component/pathfinder
	name = "pathfinder component"
	display_name = "Pathfinder"
	category = "Action"
	desc = "Finds a route from the shell to the target X and Y on its own level and gives the next direction to walk. Trigger again after the shell reaches that step to get the next one, and Arrived fires at the target. It fails when there is no route or the target is out of reach. A loose circuit has nowhere to walk from."

	var/datum/port/input/x_input
	var/datum/port/input/y_input
	var/datum/port/input/trigger
	var/datum/port/output/step_output
	var/datum/port/output/step_signal
	var/datum/port/output/arrived
	var/datum/port/output/failed

	var/list/turf/path = list()
	var/turf/next_turf
	var/turf/cached_destination

/obj/item/circuit_component/pathfinder/populate_ports()
	x_input = add_input_port("Target X", PORT_TYPE_NUMBER)
	y_input = add_input_port("Target Y", PORT_TYPE_NUMBER)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(find_step))
	step_output = add_output_port("Step", PORT_TYPE_STRING)
	step_signal = add_output_port("Step Signal", PORT_TYPE_SIGNAL)
	arrived = add_output_port("Arrived", PORT_TYPE_SIGNAL)
	failed = add_output_port("Failed", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/pathfinder/proc/find_step(datum/port/input/input)
	var/turf/here = wiremod_shell_turf(parent)
	if(!here)
		return fail()
	var/turf/destination = wiremod_turf_at(x_input.value, y_input.value, here.z)
	if(!isturf(destination))
		return fail()
	if(here == destination)
		path = list()
		next_turf = null
		cached_destination = null
		return finish()
	if(destination != cached_destination || !length(path))
		if(!build_path(here, destination))
			return fail()
	// The shell has reached the step it was given, so the route moves on.
	if(next_turf && here == next_turf)
		path.Cut(1, 2)
		next_turf = length(path) ? path[1] : null
	// The shell wandered off the route, so the route is worked out again.
	else if(next_turf && here != next_turf)
		if(!build_path(here, destination))
			return fail()
	if(!next_turf)
		return finish()
	var/direction = get_dir(here, next_turf)
	step_output.set_output(wiremod_compass_name(direction))
	step_signal.set_output(COMPONENT_SIGNAL)
	arrived.set_output(null)
	failed.set_output(null)

/obj/item/circuit_component/pathfinder/proc/build_path(turf/here, turf/destination)
	path = cirrAstar(here, destination, 0, CIRCUIT_MAX_PATH_NODES)
	cached_destination = destination
	if(!length(path) || length(path) > CIRCUIT_MAX_PATH_STEPS + 1)
		path = list()
		next_turf = null
		return FALSE
	if(path[1] == here)
		path.Cut(1, 2)
	next_turf = length(path) ? path[1] : null
	return TRUE

/obj/item/circuit_component/pathfinder/proc/finish()
	step_output.set_output("arrived")
	step_signal.set_output(COMPONENT_SIGNAL)
	arrived.set_output(COMPONENT_SIGNAL)
	failed.set_output(null)

/obj/item/circuit_component/pathfinder/proc/fail()
	path = list()
	next_turf = null
	cached_destination = null
	step_output.set_output(null)
	arrived.set_output(null)
	failed.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/pathfinder/anchor_changed()
	// A route belongs to the shell it was found from.
	path = list()
	next_turf = null
	cached_destination = null

/obj/item/circuit_component/pathfinder/removed_from_circuit(obj/item/integrated_circuit/circuit)
	path = list()
	next_turf = null
	cached_destination = null
