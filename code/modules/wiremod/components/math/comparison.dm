/obj/item/circuit_component/comparison
	name = "comparison component"
	display_name = "Comparison"
	category = "Math"

	var/datum/port/input/input_a
	var/datum/port/input/input_b
	var/datum/port/input/operation
	var/datum/port/output/result

/obj/item/circuit_component/comparison/populate_ports()
	input_a = add_input_port("A", PORT_TYPE_ANY, trigger = PROC_REF(calculate))
	input_b = add_input_port("B", PORT_TYPE_ANY, trigger = PROC_REF(calculate))
	operation = add_input_port("Operation", PORT_TYPE_STRING, trigger = PROC_REF(calculate), default = "Equal", options = list("Equal", "Not Equal", "Greater Than", "Less Than", "Greater Than or Equal", "Less Than or Equal"))
	result = add_output_port("Result", PORT_TYPE_BOOLEAN)

/obj/item/circuit_component/comparison/proc/calculate(datum/port/input/input)
	var/result_value
	var/left_value = input_a.value
	var/right_value = input_b.value
	switch(operation.value)
		if("Equal")
			result_value = left_value == right_value
		if("Not Equal")
			result_value = left_value != right_value
		if("Greater Than")
			if(isnum(left_value) && isnum(right_value))
				result_value = left_value > right_value
			else if(istext(left_value) && istext(right_value))
				result_value = sorttext(left_value, right_value) > 0
		if("Less Than")
			if(isnum(left_value) && isnum(right_value))
				result_value = left_value < right_value
			else if(istext(left_value) && istext(right_value))
				result_value = sorttext(left_value, right_value) < 0
		if("Greater Than or Equal")
			if(isnum(left_value) && isnum(right_value))
				result_value = left_value >= right_value
			else if(istext(left_value) && istext(right_value))
				result_value = sorttext(left_value, right_value) >= 0
		if("Less Than or Equal")
			if(isnum(left_value) && isnum(right_value))
				result_value = left_value <= right_value
			else if(istext(left_value) && istext(right_value))
				result_value = sorttext(left_value, right_value) <= 0
	result.set_output(result_value)
