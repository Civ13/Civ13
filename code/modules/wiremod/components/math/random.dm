/obj/item/circuit_component/random
	name = "random component"
	display_name = "Random"
	category = "Math"

	var/datum/port/input/minimum
	var/datum/port/input/maximum
	var/datum/port/input/trigger
	var/datum/port/output/result

/obj/item/circuit_component/random/populate_ports()
	minimum = add_input_port("Minimum", PORT_TYPE_NUMBER, default = 1)
	maximum = add_input_port("Maximum", PORT_TYPE_NUMBER, default = 100)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(generate))
	result = add_output_port("Result", PORT_TYPE_NUMBER)

/obj/item/circuit_component/random/proc/generate(datum/port/input/input)
	if(!isnum(minimum.value) || !isnum(maximum.value))
		return
	var/low = round(max(-CIRCUIT_RANDOM_LIMIT, min(CIRCUIT_RANDOM_LIMIT, minimum.value)))
	var/high = round(max(-CIRCUIT_RANDOM_LIMIT, min(CIRCUIT_RANDOM_LIMIT, maximum.value)))
	if(low > high)
		return
	result.set_output(rand(low, high))
