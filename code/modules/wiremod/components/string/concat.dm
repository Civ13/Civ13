/obj/item/circuit_component/string_concat
	name = "string concat component"
	display_name = "String Concat"
	category = "String"

	var/datum/port/input/input_a
	var/datum/port/input/input_b
	var/datum/port/output/result

/obj/item/circuit_component/string_concat/populate_ports()
	input_a = add_input_port("A", PORT_TYPE_STRING, trigger = PROC_REF(concatenate))
	input_b = add_input_port("B", PORT_TYPE_STRING, trigger = PROC_REF(concatenate))
	result = add_output_port("Result", PORT_TYPE_STRING)

/obj/item/circuit_component/string_concat/proc/concatenate(datum/port/input/input)
	var/left_text = isnull(input_a.value) ? "" : input_a.value
	var/right_text = isnull(input_b.value) ? "" : input_b.value
	result.set_output("[left_text][right_text]")
