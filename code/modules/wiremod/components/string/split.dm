/obj/item/circuit_component/string_split
	name = "string split component"
	display_name = "String Split"
	category = "String"

	var/datum/port/input/value_input
	var/datum/port/input/separator
	var/datum/port/output/result

/obj/item/circuit_component/string_split/populate_ports()
	value_input = add_input_port("String", PORT_TYPE_STRING, trigger = PROC_REF(split))
	separator = add_input_port("Separator", PORT_TYPE_STRING, trigger = PROC_REF(split), default = ",")
	result = add_output_port("Parts", PORT_TYPE_LIST)

/obj/item/circuit_component/string_split/proc/split(datum/port/input/input)
	if(isnull(value_input.value))
		result.set_output(null)
	else if(!length(separator.value))
		result.set_output(list(value_input.value))
	else
		result.set_output(splittext(value_input.value, separator.value))
