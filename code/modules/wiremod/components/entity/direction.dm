// Where a nearby entity is, seen from the circuit. Like tgstation's Direction
// component it only finds a target close by, so it cannot follow something
// across the map.
/obj/item/circuit_component/direction
	name = "direction component"
	display_name = "Direction"
	category = "Entity"
	desc = "Finds Target from where the circuit is: the compass direction to it and the distance in tiles. It looks when Target changes and at every signal on Trigger. A target more than 7 tiles away, on another level or gone leaves both outputs empty. On the same tile Distance is 0 and Direction is empty."

	var/datum/port/input/target_input
	var/datum/port/input/trigger
	var/datum/port/output/direction_output
	var/datum/port/output/distance_output

/obj/item/circuit_component/direction/populate_ports()
	target_input = add_input_port("Target", PORT_TYPE_ENTITY, trigger = PROC_REF(find_target))
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(find_target))
	direction_output = add_output_port("Direction", PORT_TYPE_STRING)
	distance_output = add_output_port("Distance", PORT_TYPE_NUMBER)

/obj/item/circuit_component/direction/proc/find_target(datum/port/input/input)
	var/turf/here = get_turf(parent)
	var/turf/there = get_turf(wiremod_entity(target_input.value))
	if(!here || !there || here.z != there.z || get_dist(here, there) > CIRCUIT_DIRECTION_RANGE)
		direction_output.set_output(null)
		distance_output.set_output(null)
		return
	var/static/list/compass = list("[NORTH]" = "north", "[SOUTH]" = "south", "[EAST]" = "east", "[WEST]" = "west", "[NORTHEAST]" = "northeast", "[NORTHWEST]" = "northwest", "[SOUTHEAST]" = "southeast", "[SOUTHWEST]" = "southwest")
	direction_output.set_output(compass["[get_dir(here, there)]"])
	// get_dist() gives -1 for the same tile.
	distance_output.set_output(max(0, get_dist(here, there)))
