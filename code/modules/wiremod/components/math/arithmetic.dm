/obj/item/circuit_component/arithmetic
	name = "arithmetic component"
	display_name = "Arithmetic"
	category = "Math"

	var/datum/port/input/input_a
	var/datum/port/input/input_b
	var/datum/port/input/operation
	var/datum/port/output/result

/obj/item/circuit_component/arithmetic/populate_ports()
	input_a = add_input_port("A", PORT_TYPE_NUMBER, trigger = PROC_REF(calculate))
	input_b = add_input_port("B", PORT_TYPE_NUMBER, trigger = PROC_REF(calculate))
	operation = add_input_port("Operation", PORT_TYPE_STRING, trigger = PROC_REF(calculate), default = "Add", options = list("Add", "Subtract", "Multiply", "Divide", "Modulo", "Power", "Minimum", "Maximum"))
	result = add_output_port("Result", PORT_TYPE_NUMBER)

/obj/item/circuit_component/arithmetic/proc/calculate(datum/port/input/input)
	if(isnull(input_a.value) || isnull(input_b.value))
		return
	var/output
	switch(operation.value)
		if("Add")
			output = input_a.value + input_b.value
		if("Subtract")
			output = input_a.value - input_b.value
		if("Multiply")
			output = input_a.value * input_b.value
		if("Divide")
			if(input_b.value == 0)
				output = null
			else
				output = input_a.value / input_b.value
		if("Modulo")
			if(input_b.value != 0)
				output = input_a.value %% input_b.value
		if("Power")
			// A negative base has no real fractional power, and zero has no negative one.
			if(!(input_a.value < 0 && input_b.value != round(input_b.value)) && !(input_a.value == 0 && input_b.value < 0))
				output = input_a.value ** input_b.value
		if("Minimum")
			output = min(input_a.value, input_b.value)
		if("Maximum")
			output = max(input_a.value, input_b.value)
	result.set_output(output)
