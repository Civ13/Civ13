// Where a nearby entity is, seen from the shell. Like tgstation's Direction
// component it only finds a target close by, so it cannot follow something
// across the map. A loose circuit has no shell to look from.
/obj/item/circuit_component/direction
	name = "direction component"
	display_name = "Direction"
	category = "Entity"
	desc = "Finds Target from the shell the circuit is in: the compass direction to it and the distance in tiles. It looks when Target changes and at every signal on Trigger. A target more than 7 tiles away, on another level or gone leaves both outputs empty. On the same tile Distance is 0 and Direction is empty. A loose circuit finds nothing."

	var/datum/port/input/target_input
	var/datum/port/input/trigger
	var/datum/port/output/direction_output
	var/datum/port/output/distance_output
	var/datum/port/output/north_signal
	var/datum/port/output/east_signal
	var/datum/port/output/south_signal
	var/datum/port/output/west_signal

/obj/item/circuit_component/direction/populate_ports()
	target_input = add_input_port("Target", PORT_TYPE_ENTITY, trigger = PROC_REF(find_target))
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(find_target))
	direction_output = add_output_port("Direction", PORT_TYPE_STRING)
	distance_output = add_output_port("Distance", PORT_TYPE_NUMBER)
	north_signal = add_output_port("North", PORT_TYPE_SIGNAL)
	east_signal = add_output_port("East", PORT_TYPE_SIGNAL)
	south_signal = add_output_port("South", PORT_TYPE_SIGNAL)
	west_signal = add_output_port("West", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/direction/proc/find_target(datum/port/input/input)
	var/turf/here = get_turf(wiremod_anchor(parent))
	var/turf/there = get_turf(wiremod_entity(target_input.value))
	if(!here || !there || here.z != there.z || get_dist(here, there) > CIRCUIT_DIRECTION_RANGE)
		direction_output.set_output(null)
		distance_output.set_output(null)
		return
	var/direction = get_dir(here, there)
	direction_output.set_output(wiremod_compass_name(direction))
	// get_dist() gives -1 for the same tile.
	distance_output.set_output(max(0, get_dist(here, there)))
	// A diagonal fires both of its sides, so a circuit can move along one axis.
	if(direction & NORTH)
		north_signal.set_output(COMPONENT_SIGNAL)
	if(direction & SOUTH)
		south_signal.set_output(COMPONENT_SIGNAL)
	if(direction & EAST)
		east_signal.set_output(COMPONENT_SIGNAL)
	if(direction & WEST)
		west_signal.set_output(COMPONENT_SIGNAL)
