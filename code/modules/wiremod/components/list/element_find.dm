/obj/item/circuit_component/element_find
	name = "element find component"
	display_name = "Element Find"
	category = "List"
	desc = "Gives true when List holds an entry equal to Value, and false when it does not. Lists and things in the world are never equal to anything."

	var/datum/port/input/value_input
	var/datum/port/input/list_input
	var/datum/port/output/found_output
	var/datum/port/output/triggered

/obj/item/circuit_component/element_find/populate_ports()
	value_input = add_input_port("Value", PORT_TYPE_ANY, trigger = PROC_REF(find_element))
	list_input = add_input_port("List", PORT_TYPE_LIST, trigger = PROC_REF(find_element))
	found_output = add_output_port("Found", PORT_TYPE_BOOLEAN)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/element_find/proc/find_element(datum/port/input/input)
	var/found = FALSE
	var/list/source = list_input.value
	var/value = value_input.value
	if(islist(source) && (isnum(value) || istext(value)))
		for(var/entry in source)
			if((isnum(entry) || istext(entry)) && entry == value)
				found = TRUE
				break
	found_output.set_output(found)
	triggered.set_output(COMPONENT_SIGNAL)
