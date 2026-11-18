/obj/item/circuit_component/logic
	name = "logic component"
	display_name = "Logic"
	category = "Math"

	var/datum/port/input/input_a
	var/datum/port/input/input_b
	var/datum/port/input/operation
	var/datum/port/output/result

/obj/item/circuit_component/logic/populate_ports()
	input_a = add_input_port("A", PORT_TYPE_BOOLEAN, trigger = PROC_REF(evaluate))
	input_b = add_input_port("B", PORT_TYPE_BOOLEAN, trigger = PROC_REF(evaluate))
	operation = add_input_port("Operation", PORT_TYPE_STRING, trigger = PROC_REF(evaluate), default = "AND", options = list("AND", "OR", "XOR"))
	result = add_output_port("Result", PORT_TYPE_BOOLEAN)

/obj/item/circuit_component/logic/proc/evaluate(datum/port/input/input)
	var/result_value
	switch(operation.value)
		if("AND")
			result_value = input_a.value && input_b.value
		if("OR")
			result_value = input_a.value || input_b.value
		if("XOR")
			result_value = !!input_a.value != !!input_b.value
	result.set_output(result_value)
