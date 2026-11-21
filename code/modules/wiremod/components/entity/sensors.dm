// Sensors read the world from the shell the circuit is installed in and put
// what they find on their outputs. A loose circuit has no shell and reads
// nothing. Triggered sensors only look when a signal reaches Trigger, so a
// circuit decides when it pays for a scan.

/obj/item/circuit_component/gps
	name = "gps component"
	display_name = "GPS"
	category = "Entity"
	desc = "Shows the X, Y and Z coordinates of the shell the circuit is in when a signal reaches Trigger. A circuit that is not in a shell has nothing to show."

	var/datum/port/input/trigger
	var/datum/port/output/x_output
	var/datum/port/output/y_output
	var/datum/port/output/z_output

/obj/item/circuit_component/gps/populate_ports()
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(read_position))
	x_output = add_output_port("X", PORT_TYPE_NUMBER)
	y_output = add_output_port("Y", PORT_TYPE_NUMBER)
	z_output = add_output_port("Z", PORT_TYPE_NUMBER)

/obj/item/circuit_component/gps/proc/read_position(datum/port/input/input)
	var/turf/here = wiremod_anchor_turf(parent)
	x_output.set_output(here ? here.x : null)
	y_output.set_output(here ? here.y : null)
	z_output.set_output(here ? here.z : null)

/obj/item/circuit_component/health
	name = "health component"
	display_name = "Health"
	category = "Entity"
	desc = "Reads a living thing's Health and its Damage, which is how much health it has lost from its maximum, when a signal reaches Trigger. Anything that is not living gives nothing."

	var/datum/port/input/entity_input
	var/datum/port/input/trigger
	var/datum/port/output/health_output
	var/datum/port/output/damage_output

/obj/item/circuit_component/health/populate_ports()
	entity_input = add_input_port("Entity", PORT_TYPE_ENTITY)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(read_health))
	health_output = add_output_port("Health", PORT_TYPE_NUMBER)
	damage_output = add_output_port("Damage", PORT_TYPE_NUMBER)

/obj/item/circuit_component/health/proc/read_health(datum/port/input/input)
	var/mob/living/target = wiremod_entity(entity_input.value)
	if(!istype(target) || !wiremod_anchor_turf(parent))
		health_output.set_output(null)
		damage_output.set_output(null)
		return
	health_output.set_output(wiremod_safe_number(target.health))
	damage_output.set_output(wiremod_safe_number(target.maxHealth - target.health))

/obj/item/circuit_component/species
	name = "species component"
	display_name = "Get Species"
	category = "Entity"
	desc = "Names the species of a person when a signal reaches Trigger, such as Human. An entity that is not a person gives nothing."

	var/datum/port/input/entity_input
	var/datum/port/input/trigger
	var/datum/port/output/species_output

/obj/item/circuit_component/species/populate_ports()
	entity_input = add_input_port("Entity", PORT_TYPE_ENTITY)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(read_species))
	species_output = add_output_port("Species", PORT_TYPE_STRING)

/obj/item/circuit_component/species/proc/read_species(datum/port/input/input)
	species_output.set_output(wiremod_entity_species(entity_input.value))

/obj/item/circuit_component/pinpointer
	name = "proximity pinpointer component"
	display_name = "Proximity Pinpointer"
	category = "Entity"
	desc = "Shows the X, Y and Z coordinates of an entity while it is in view of the shell, within 7 tiles on the same level. An entity out of view, or a circuit with no shell, gives nothing. Moving the target is not followed until its value changes."

	var/datum/port/input/entity_input
	var/datum/port/output/x_output
	var/datum/port/output/y_output
	var/datum/port/output/z_output

/obj/item/circuit_component/pinpointer/populate_ports()
	entity_input = add_input_port("Entity", PORT_TYPE_ENTITY, trigger = PROC_REF(read_position))
	x_output = add_output_port("X", PORT_TYPE_NUMBER)
	y_output = add_output_port("Y", PORT_TYPE_NUMBER)
	z_output = add_output_port("Z", PORT_TYPE_NUMBER)

/obj/item/circuit_component/pinpointer/proc/read_position(datum/port/input/input)
	var/atom/target = wiremod_entity(entity_input.value)
	var/turf/here = wiremod_anchor_turf(parent)
	var/turf/there = target ? get_turf(target) : null
	if(!here || !there || here.z != there.z || get_dist(here, there) > CIRCUIT_DIRECTION_RANGE || !(there in view(CIRCUIT_DIRECTION_RANGE, here)))
		x_output.set_output(null)
		y_output.set_output(null)
		z_output.set_output(null)
		return
	x_output.set_output(there.x)
	y_output.set_output(there.y)
	z_output.set_output(there.z)

/obj/item/circuit_component/self
	name = "self component"
	display_name = "Self"
	category = "Entity"
	desc = "Gives the circuit's shell as an entity, so the circuit can refer to the thing it is installed in. A circuit that is not in a shell gives nothing."

	var/datum/port/output/shell_output

/obj/item/circuit_component/self/populate_ports()
	shell_output = add_output_port("Shell", PORT_TYPE_ENTITY)

/obj/item/circuit_component/self/added_to_circuit(obj/item/integrated_circuit/circuit)
	anchor_changed()

/obj/item/circuit_component/self/anchor_changed()
	var/obj/item/circuit_shell/shell = wiremod_circuit_shell(parent)
	shell_output.set_output(shell ? WEAKREF(shell) : null)

/obj/item/circuit_component/view_sensor
	name = "view sensor component"
	display_name = "View Sensor"
	category = "Sensor"
	desc = "Lists every thing the shell can see, as entities, when a signal reaches Trigger. It looks at most once a second and leaves the last list in place while it waits. A circuit that is not in a shell sees nothing."

	var/datum/port/input/trigger
	var/datum/port/output/entities_output
	var/next_scan = 0

/obj/item/circuit_component/view_sensor/populate_ports()
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(scan))
	entities_output = add_output_port("Entities", PORT_TYPE_LIST)

/obj/item/circuit_component/view_sensor/proc/scan(datum/port/input/input)
	if(!wiremod_circuit_shell(parent))
		entities_output.set_output(null)
		return
	if(world.time < next_scan)
		return
	next_scan = world.time + 10
	entities_output.set_output(wiremod_anchor_view(parent))

/obj/item/circuit_component/pressure_sensor
	name = "pressure sensor component"
	display_name = "Pressure Sensor"
	category = "Sensor"
	desc = "Reads the atmospheric pressure of the tile the shell is in when a signal reaches Trigger, in kilopascals. A tile with no air gives 0, and a circuit with no shell, or a tile with no air mixture at all, leaves Pressure empty."

	var/datum/port/input/trigger
	var/datum/port/output/pressure_output

/obj/item/circuit_component/pressure_sensor/populate_ports()
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(read_pressure))
	pressure_output = add_output_port("Pressure", PORT_TYPE_NUMBER)

/obj/item/circuit_component/pressure_sensor/proc/read_pressure(datum/port/input/input)
	var/turf/here = wiremod_anchor_turf(parent)
	var/datum/gas_mixture/air = here ? here.return_air() : null
	if(!air)
		pressure_output.set_output(null)
		return
	if(!air.total_moles)
		pressure_output.set_output(0)
		return
	pressure_output.set_output(wiremod_safe_number(round(air.return_pressure(), 1)))

/obj/item/circuit_component/temperature_sensor
	name = "temperature sensor component"
	display_name = "Temperature Sensor"
	category = "Sensor"
	desc = "Reads the temperature of the tile the shell is in when a signal reaches Trigger, in kelvin. A tile with no air gives 0, and a circuit with no shell, or a tile with no air mixture at all, leaves Temperature empty."

	var/datum/port/input/trigger
	var/datum/port/output/temperature_output

/obj/item/circuit_component/temperature_sensor/populate_ports()
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(read_temperature))
	temperature_output = add_output_port("Temperature", PORT_TYPE_NUMBER)

/obj/item/circuit_component/temperature_sensor/proc/read_temperature(datum/port/input/input)
	var/turf/here = wiremod_anchor_turf(parent)
	var/datum/gas_mixture/air = here ? here.return_air() : null
	if(!air)
		temperature_output.set_output(null)
		return
	if(!air.total_moles)
		temperature_output.set_output(0)
		return
	temperature_output.set_output(wiremod_safe_number(round(air.temperature, 1)))
