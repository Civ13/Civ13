/obj/item/circuit_component/material_scanner
	name = "material scanner component"
	display_name = "Material Scanner"
	category = "Sensor"
	desc = "Reads an item's materials as an associative list from material name to amount. Names are lower case, and Metal is listed as Iron. An entity that is not an item gives nothing."

	var/datum/port/input/entity_input
	var/datum/port/output/materials_output

/obj/item/circuit_component/material_scanner/populate_ports()
	entity_input = add_input_port("Entity", PORT_TYPE_ENTITY, trigger = PROC_REF(scan))
	materials_output = add_output_port("Materials", PORT_TYPE_ASSOC_LIST)

/obj/item/circuit_component/material_scanner/proc/scan(datum/port/input/input)
	materials_output.set_output(wiremod_entity_materials(entity_input.value))

/obj/item/circuit_component/reagents_scanner
	name = "reagents scanner component"
	display_name = "Reagents Scanner"
	category = "Sensor"
	desc = "Reads what a container holds as an associative list from reagent id to volume. An entity that holds no reagents gives nothing."

	var/datum/port/input/entity_input
	var/datum/port/output/reagents_output

/obj/item/circuit_component/reagents_scanner/populate_ports()
	entity_input = add_input_port("Entity", PORT_TYPE_ENTITY, trigger = PROC_REF(scan))
	reagents_output = add_output_port("Reagents", PORT_TYPE_ASSOC_LIST)

/obj/item/circuit_component/reagents_scanner/proc/scan(datum/port/input/input)
	reagents_output.set_output(wiremod_entity_reagents(entity_input.value))
