/obj/item/circuit_component/trigonometry
	name = "trigonometry component"
	display_name = "Trigonometry"
	category = "Math"
	desc = "Works out the chosen Operation on Input, in degrees: Sine, Cosine, Tangent, Arcsine, Arccosine or Arctangent. An Arcsine or Arccosine outside -1 to 1 has no answer and gives nothing."

	var/datum/port/input/input_value
	var/datum/port/input/operation
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/trigonometry/populate_ports()
	input_value = add_input_port("Input", PORT_TYPE_NUMBER, trigger = PROC_REF(calculate))
	operation = add_input_port("Operation", PORT_TYPE_OPTION, trigger = PROC_REF(calculate), default = "Sine", options = list("Sine", "Cosine", "Tangent", "Arcsine", "Arccosine", "Arctangent"))
	result = add_output_port("Result", PORT_TYPE_NUMBER)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/trigonometry/proc/calculate(datum/port/input/input)
	if(!isnum(input_value.value))
		result.set_output(null)
		triggered.set_output(COMPONENT_SIGNAL)
		return
	switch(operation.value)
		if("Cosine")
			result.set_output(cos(input_value.value))
		if("Tangent")
			result.set_output(tan(input_value.value))
		if("Arcsine")
			if(input_value.value < -1 || input_value.value > 1)
				result.set_output(null)
			else
				result.set_output(arcsin(input_value.value))
		if("Arccosine")
			if(input_value.value < -1 || input_value.value > 1)
				result.set_output(null)
			else
				result.set_output(arccos(input_value.value))
		if("Arctangent")
			result.set_output(arctan(input_value.value))
		else
			result.set_output(sin(input_value.value))
	triggered.set_output(COMPONENT_SIGNAL)
