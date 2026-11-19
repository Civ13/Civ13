// A component that works a Result out of two inputs, A and B, and for some of
// them a chosen Operation. A subtype names its port types and choices and
// writes operate(); the ports and the wiring are the same for all of them.
/obj/item/circuit_component/operator
	display_name = "Operator"

	var/operand_type = PORT_TYPE_ANY
	var/result_type = PORT_TYPE_ANY
	// The choices of the Operation input; the first is the one it starts on.
	// Null for a component that does one thing and has no such input.
	var/list/operations
	// TRUE when the component waits for both inputs and keeps its last result
	// until it has them.
	var/needs_both_inputs = FALSE

	var/datum/port/input/input_a
	var/datum/port/input/input_b
	var/datum/port/input/operation
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/operator/populate_ports()
	input_a = add_input_port("A", operand_type, trigger = PROC_REF(run_operation))
	input_b = add_input_port("B", operand_type, trigger = PROC_REF(run_operation))
	if(operations)
		operation = add_input_port("Operation", PORT_TYPE_OPTION, trigger = PROC_REF(run_operation), default = operations[1], options = operations)
	result = add_output_port("Result", result_type)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/operator/proc/run_operation(datum/port/input/input)
	if(needs_both_inputs && (isnull(input_a.value) || isnull(input_b.value)))
		return
	result.set_output(operate(input_a.value, input_b.value, operation?.value))
	triggered.set_output(COMPONENT_SIGNAL)

// The result for these two input values. No value (null) is a valid answer.
/obj/item/circuit_component/operator/proc/operate(left, right, chosen)
	return null
