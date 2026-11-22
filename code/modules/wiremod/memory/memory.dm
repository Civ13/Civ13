// A memory component is a plain storage device. It knows nothing about the CPU
// or about its neighbours: Address is a byte offset inside the component's own
// slice, Mode says read or write, and Trigger performs it. Choosing which
// memory answers is the player's wiring, using logic on the CPU's Chip select
// to gate each Trigger.
//
// A store is always a whole 32-bit word at a word-aligned address. Sub-word
// access is done by the CPU as a read-modify-write, so every read and write
// that reaches a component is one aligned word.

/obj/item/circuit_component/memory
	name = "memory component"
	display_name = "Memory"
	category = "Memory"
	desc = "Stores whole 32-bit words for a computer. Address is a byte offset, Mode is 0 to read and 1 to write, and Trigger performs the access. The contents vanish when the circuit leaves its shell."
	var/small = FALSE
	var/slice_base = 0
	var/slice_bytes = 0
	var/datum/port/input/address_input
	var/datum/port/input/data_input
	var/datum/port/input/mode_input
	var/datum/port/input/trigger_input
	var/datum/port/output/output

/obj/item/circuit_component/memory/populate_ports()
	address_input = add_input_port("Address", PORT_TYPE_STRING, trigger = PROC_REF(access_memory))
	data_input = add_input_port("Data", PORT_TYPE_STRING, trigger = PROC_REF(access_memory))
	mode_input = add_input_port("Mode", PORT_TYPE_NUMBER, trigger = PROC_REF(access_memory), default = 0)
	trigger_input = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(access_memory))
	output = add_output_port("Output", PORT_TYPE_ANY)

/obj/item/circuit_component/memory/proc/get_pool()
	var/obj/item/circuit_shell/shell = wiremod_circuit_shell(parent)
	return shell ? shell.get_memory_pool() : null

/obj/item/circuit_component/memory/added_to_circuit(obj/item/integrated_circuit/circuit)
	. = ..()
	get_pool()?.invalidate()

/obj/item/circuit_component/memory/anchor_changed()
	. = ..()
	get_pool()?.invalidate()

/obj/item/circuit_component/memory/removed_from_circuit(obj/item/integrated_circuit/circuit)
	get_pool()?.invalidate()
	return ..()

/obj/item/circuit_component/memory/proc/access_memory(datum/port/input/input)
	var/datum/wiremod_memory_pool/pool = get_pool()
	if(!pool)
		return
	if(!istext(address_input.value) || length(address_input.value) != 19)
		return
	var/address_word = wiremod_binary_to_word(address_input.value)
	if(isnull(address_word))
		return
	var/address = wiremod_u32_num(address_word)
	var/mode = mode_input.value
	if(!isnum(mode) || (mode != 0 && mode != 1))
		return
	if(mode == 1)
		if(!istext(data_input.value) || length(data_input.value) != 32)
			return
		var/word = wiremod_binary_to_word(data_input.value)
		if(isnull(word))
			return
		pool.write_word(src, address, word)
		return
	var/word = pool.read_word(src, address)
	if(isnull(word))
		return
	output.set_output(wiremod_word_to_binary(word, 32))
