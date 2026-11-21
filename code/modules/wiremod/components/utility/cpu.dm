/obj/item/circuit_component/cpu
	name = "clocked processor component"
	display_name = "Clocked Processor"
	category = "Utility"
	desc = "Runs a small integer-only program in a shell. Write Program and pulse Load. Pulse Step for one instruction or Run for up to 16. OUT sends Value and then pulses Emit. Reset clears registers and RAM but keeps the program."
	var/datum/wiremod_cpu/machine
	var/datum/port/input/program_input
	var/datum/port/input/value_input
	var/datum/port/output/value_output
	var/datum/port/output/status_output
	var/datum/port/output/emit

/obj/item/circuit_component/cpu/populate_ports()
	program_input = add_input_port("Program", PORT_TYPE_STRING, trigger = null)
	value_input = add_input_port("Input", PORT_TYPE_NUMBER, trigger = null)
	add_input_port("Load", PORT_TYPE_SIGNAL, trigger = PROC_REF(load_input))
	add_input_port("Step", PORT_TYPE_SIGNAL, trigger = PROC_REF(step_input))
	add_input_port("Run", PORT_TYPE_SIGNAL, trigger = PROC_REF(run_slice_input))
	add_input_port("Reset", PORT_TYPE_SIGNAL, trigger = PROC_REF(reset_input))
	value_output = add_output_port("Value", PORT_TYPE_NUMBER)
	status_output = add_output_port("Status", PORT_TYPE_STRING)
	emit = add_output_port("Emit", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/cpu/added_to_circuit(obj/item/integrated_circuit/circuit)
	machine = new(circuit)

/obj/item/circuit_component/cpu/removed_from_circuit(obj/item/integrated_circuit/circuit)
	QDEL_NULL(machine)

// Unmounting powers down the CPU. Keep its loaded program but release RAM.
/obj/item/circuit_component/cpu/anchor_changed()
	if(machine && !available())
		machine.reset()
		value_output.hold(null)
		status_output.hold("unmounted")
		emit.hold(null)

/obj/item/circuit_component/cpu/proc/available()
	var/obj/item/circuit_shell/shell = wiremod_shell(parent)
	return machine && shell && shell.circuit == parent

/obj/item/circuit_component/cpu/proc/load_input(datum/port/input/input)
	if(!available() || !parent.consume_cpu_ops(CIRCUIT_CPU_BOARD_OPS))
		return
	if(machine.load_program(program_input.value))
		value_output.set_output(null)
		status_output.set_output("ready")
	else
		status_output.set_output("invalid program")

/obj/item/circuit_component/cpu/proc/reset_input(datum/port/input/input)
	if(!available() || !parent.consume_cpu_ops(CIRCUIT_CPU_BOARD_OPS))
		return
	machine.reset()
	value_output.set_output(null)
	status_output.set_output(length(machine.program) ? "ready" : "no program")

/obj/item/circuit_component/cpu/proc/step_input(datum/port/input/input)
	execute_slice(1)

/obj/item/circuit_component/cpu/proc/run_slice_input(datum/port/input/input)
	execute_slice(CIRCUIT_CPU_SLICE)

/obj/item/circuit_component/cpu/proc/execute_slice(count)
	if(!available())
		return
	var/result = machine.execute(count, value_input.value)
	if(result == "output")
		value_output.set_output(machine.accumulator)
	// In the circuit queue, subscribers run after this call returns.
	status_output.set_output(result)
	if(result == "output")
		emit.set_output(COMPONENT_SIGNAL)
