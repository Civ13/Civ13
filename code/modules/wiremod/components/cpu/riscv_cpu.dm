// A 32-bit RV32I core as a circuit component. Words arrive on Data in, one per
// fetch; the CPU drives Address and Command for the fetch and for each load or
// store, and pulses Triggered so a memory or a punch reader has something to
// answer. It knows nothing about either device: the player wires them.
//
// A fetch always drives Address with pc and Command 0. pc is architectural only:
// words come from whatever is wired to Data in, never from pc, so during the
// card phase the reader supplies instructions while jumps still update pc. The
// last word of a loader is `jalr x0, 0(x0)`, which sets pc to 0; the player then
// switches Data in to memory and the program runs from RAM.
//
// Clock is an instruction budget, not a timer per hertz. Above the per-tick cap
// the core runs slower than asked. A bad word or instruction halts it with empty
// outputs until Reset; ecall and ebreak halt the same way, on purpose.

/obj/item/circuit_component/riscv_cpu
	name = "RV32I CPU component"
	display_name = "RV32I CPU"
	category = "Computer"
	desc = "Runs 32-bit RV32I words from Data in, one per fetch. Address and Command drive memory, Triggered pulses each bus cycle, and Reset clears the core. A bad word or instruction halts it."
	var/datum/port/input/data_input
	var/datum/port/input/clock_input
	var/datum/port/input/reset_input
	var/datum/port/output/address_output
	var/datum/port/output/command_output
	var/datum/port/output/data_output
	var/datum/port/output/chip_select_output
	var/datum/port/output/triggered_output

	var/list/registers = list()
	var/pc = 0
	var/chip_select_latch = 0
	var/state = CIRCUIT_CPU_STATE_IDLE
	var/budget = 0
	var/per_tick = 1
	var/pumping = FALSE
	var/timer_id
	var/signal_serial = 0
	var/halted = FALSE
	var/fault_text = null
	var/pending_rd = 0
	var/pending_funct3 = 0
	var/pending_address = 0
	var/pending_value = 0

/obj/item/circuit_component/riscv_cpu/populate_ports()
	data_input = add_input_port("Data in", PORT_TYPE_STRING, trigger = PROC_REF(word_received))
	clock_input = add_input_port("Clock", PORT_TYPE_NUMBER, trigger = PROC_REF(clock_changed), default = 1)
	reset_input = add_input_port("Reset", PORT_TYPE_SIGNAL, trigger = PROC_REF(do_reset))
	address_output = add_output_port("Address", PORT_TYPE_STRING)
	command_output = add_output_port("Command", PORT_TYPE_NUMBER)
	data_output = add_output_port("Data", PORT_TYPE_STRING)
	chip_select_output = add_output_port("Chip select", PORT_TYPE_NUMBER)
	triggered_output = add_output_port("Triggered", PORT_TYPE_SIGNAL)
	clear_registers()

/obj/item/circuit_component/riscv_cpu/proc/clear_registers()
	registers = list()
	for(var/index in 1 to 32)
		registers += 0

/obj/item/circuit_component/riscv_cpu/proc/get_reg(index)
	if(index <= 0 || index > 31)
		return wiremod_u32(0)
	var/value = registers[index + 1]
	if(islist(value))
		return value
	if(isnum(value))
		return wiremod_u32(value)
	return wiremod_u32(0)

/obj/item/circuit_component/riscv_cpu/proc/get_reg_num(index)
	var/list/h = get_reg(index)
	return h[1] * 65536 + h[2]

/obj/item/circuit_component/riscv_cpu/proc/set_reg(index, value)
	if(index <= 0 || index > 31)
		return
	registers[index + 1] = wiremod_u32(value)

/obj/item/circuit_component/riscv_cpu/added_to_circuit(obj/item/integrated_circuit/circuit)
	. = ..()
	start_clock()

/obj/item/circuit_component/riscv_cpu/removed_from_circuit(obj/item/integrated_circuit/circuit)
	stop_clock()
	return ..()

/obj/item/circuit_component/riscv_cpu/Destroy()
	stop_clock()
	return ..()

/obj/item/circuit_component/riscv_cpu/ui_alerts()
	if(fault_text)
		return list("warning" = fault_text)
	return null

/obj/item/circuit_component/riscv_cpu/proc/clock_changed(datum/port/input/input)
	var/hz = clock_input.value
	if(!isnum(hz))
		hz = CIRCUIT_CPU_MIN_CLOCK
	hz = max(CIRCUIT_CPU_MIN_CLOCK, min(CIRCUIT_CPU_MAX_CLOCK, hz))
	per_tick = max(1, min(CIRCUIT_CPU_MAX_PER_TICK, floor(hz / 10)))
	start_clock()

/obj/item/circuit_component/riscv_cpu/proc/start_clock()
	if(timer_id || halted || !parent || QDELETED(src))
		return
	timer_id = addtimer(CALLBACK(src, PROC_REF(tick)), 1, TIMER_STOPPABLE)

/obj/item/circuit_component/riscv_cpu/proc/stop_clock()
	if(timer_id)
		deltimer(timer_id)
		timer_id = null

/obj/item/circuit_component/riscv_cpu/proc/tick()
	timer_id = null
	if(QDELETED(src) || !parent)
		return
	if(halted)
		return
	budget = per_tick
	pump()
	start_clock()

/obj/item/circuit_component/riscv_cpu/proc/pulse()
	signal_serial = signal_serial % 100000 + 1
	triggered_output.set_output(signal_serial)

// Starts the next fetch if the core is idle and the tick still has budget.
/obj/item/circuit_component/riscv_cpu/proc/pump()
	if(pumping || halted || state != CIRCUIT_CPU_STATE_IDLE || budget <= 0 || !parent)
		return
	pumping = TRUE
	while(!halted && state == CIRCUIT_CPU_STATE_IDLE && budget > 0 && parent)
		budget--
		state = CIRCUIT_CPU_STATE_FETCH
		address_output.set_output(wiremod_word_to_binary(pc % CIRCUIT_MEMORY_LOCAL_BYTES, 19))
		command_output.set_output(0)
		pulse()
		if(state == CIRCUIT_CPU_STATE_FETCH)
			break
	pumping = FALSE

/obj/item/circuit_component/riscv_cpu/proc/advance()
	pc = wiremod_u32_num(pc + 4)
	state = CIRCUIT_CPU_STATE_IDLE
	if(!pumping)
		pump()

/obj/item/circuit_component/riscv_cpu/proc/do_reset(datum/port/input/input)
	clear_registers()
	pc = 0
	chip_select_latch = 0
	state = CIRCUIT_CPU_STATE_IDLE
	halted = FALSE
	fault_text = null
	budget = per_tick
	address_output.set_output(wiremod_word_to_binary(0, 19))
	command_output.set_output(0)
	data_output.set_output("")
	chip_select_output.set_output(0)
	parent?.refresh_editor()
	start_clock()
	pump()

/obj/item/circuit_component/riscv_cpu/proc/halt(reason)
	halted = TRUE
	state = CIRCUIT_CPU_STATE_IDLE
	budget = 0
	fault_text = reason
	stop_clock()
	command_output.set_output(0)
	address_output.set_output("")
	data_output.set_output("")
	parent?.refresh_editor()

/obj/item/circuit_component/riscv_cpu/proc/fault(reason)
	halt(reason)

/obj/item/circuit_component/riscv_cpu/proc/word_received(datum/port/input/input)
	if(halted || state == CIRCUIT_CPU_STATE_IDLE)
		return
	if(!istext(data_input.value) || !length(data_input.value))
		return
	if(length(data_input.value) != 32)
		fault("Data in was not a 32-bit binary word.")
		return
	var/word = wiremod_binary_to_word(data_input.value)
	if(isnull(word))
		fault("Data in was not a 32-bit binary word.")
		return
	switch(state)
		if(CIRCUIT_CPU_STATE_FETCH)
			state = CIRCUIT_CPU_STATE_IDLE
			execute(word)
		if(CIRCUIT_CPU_STATE_LOAD)
			state = CIRCUIT_CPU_STATE_IDLE
			finish_load(word)
			pc = wiremod_u32_num(pc + 4)
			if(!pumping)
				pump()
		if(CIRCUIT_CPU_STATE_RMW_READ)
			state = CIRCUIT_CPU_STATE_IDLE
			finish_rmw(word)
			pc = wiremod_u32_num(pc + 4)
			if(!pumping)
				pump()

/obj/item/circuit_component/riscv_cpu/proc/execute(word)
	var/opcode = wiremod_bits(word, 0, 7)
	var/rd = wiremod_bits(word, 7, 5)
	var/funct3 = wiremod_bits(word, 12, 3)
	var/rs1 = wiremod_bits(word, 15, 5)
	var/rs2 = wiremod_bits(word, 20, 5)
	var/funct7 = wiremod_bits(word, 25, 7)
	switch(opcode)
		if(0x37) // LUI
			var/imm20 = wiremod_bits(word, 12, 20); set_reg(rd, list(floor(imm20 / 16) % 65536, (imm20 % 16) * 4096))
			advance()
		if(0x17) // AUIPC
			var/a_imm20 = wiremod_bits(word, 12, 20); set_reg(rd, wiremod_u32_add(wiremod_u32(pc), list(floor(a_imm20 / 16) % 65536, (a_imm20 % 16) * 4096)))
			advance()
		if(0x6F) // JAL
			var/offset = riscv_jump_offset(word)
			set_reg(rd, pc + 4)
			pc = wiremod_u32_num(pc + offset)
			state = CIRCUIT_CPU_STATE_IDLE
			pump()
		if(0x67) // JALR
			var/offset = wiremod_sign_extend(wiremod_bits(word, 20, 12), 12)
			var/target = wiremod_u32_num(get_reg_num(rs1) + offset)
			if(target % 2)
				target -= 1
			set_reg(rd, pc + 4)
			pc = wiremod_u32_num(target)
			state = CIRCUIT_CPU_STATE_IDLE
			pump()
		if(0x63) // branches
			var/offset = riscv_branch_offset(word)
			var/list/first_r = get_reg(rs1)
			var/list/second_r = get_reg(rs2)
			var/taken = FALSE
			switch(funct3)
				if(0)
					taken = wiremod_u32_eq(first_r, second_r)
				if(1)
					taken = !wiremod_u32_eq(first_r, second_r)
				if(4)
					taken = wiremod_u32_slt(first_r, second_r)
				if(5)
					taken = !wiremod_u32_slt(first_r, second_r)
				if(6)
					taken = wiremod_u32_sltu(first_r, second_r)
				if(7)
					taken = !wiremod_u32_sltu(first_r, second_r)
				else
					fault("Unknown branch instruction.")
					return
			pc = wiremod_u32_num(pc + (taken ? offset : 4))
			state = CIRCUIT_CPU_STATE_IDLE
			pump()
		if(0x03) // loads
			var/offset = wiremod_sign_extend(wiremod_bits(word, 20, 12), 12)
			var/address = wiremod_u32_num(get_reg_num(rs1) + offset)
			if(funct3 == 1 || funct3 == 5)
				if(address % 2)
					fault("A halfword load was not aligned.")
					return
			else if(funct3 == 2)
				if(address % 4)
					fault("A word load was not aligned.")
					return
			else if(funct3 != 0 && funct3 != 4)
				fault("Unknown load instruction.")
				return
			pending_rd = rd
			pending_funct3 = funct3
			pending_address = address
			state = CIRCUIT_CPU_STATE_LOAD
			budget--
			address_output.set_output(wiremod_word_to_binary((address - (address % 4)) % CIRCUIT_MEMORY_LOCAL_BYTES, 19))
			command_output.set_output(0)
			pulse()
		if(0x23) // stores
			var/offset = wiremod_sign_extend((wiremod_bits(word, 25, 7) * 32) + wiremod_bits(word, 7, 5), 12)
			var/address = wiremod_u32_num(get_reg_num(rs1) + offset)
			var/value = get_reg(rs2)
			if(address == CIRCUIT_CHIP_SELECT_ADDRESS)
				chip_select_latch = wiremod_u32_halves(value)[2] % 256
				chip_select_output.set_output(chip_select_latch)
				advance()
				return
			if(funct3 == 0)
				start_rmw(address, value, 0)
			else if(funct3 == 1)
				if(address % 2)
					fault("A halfword store was not aligned.")
					return
				start_rmw(address, value, 1)
			else if(funct3 == 2)
				if(address % 4)
					fault("A word store was not aligned.")
					return
				budget--
				address_output.set_output(wiremod_word_to_binary(address % CIRCUIT_MEMORY_LOCAL_BYTES, 19))
				command_output.set_output(1)
				data_output.set_output(wiremod_word_to_binary(value, 32))
				pulse()
				advance()
			else
				fault("Unknown store instruction.")
		if(0x13) // immediate arithmetic
			var/immediate = wiremod_sign_extend(wiremod_bits(word, 20, 12), 12)
			var/shamt = immediate % 32
			var/list/source = get_reg(rs1)
			var/list/imm_word = immediate < 0 ? list(65535, (65536 + immediate) % 65536) : list(0, immediate % 65536)
			var/result
			switch(funct3)
				if(0)
					result = wiremod_u32_add(source, imm_word)
					if(rd == 15) world.log << "ADDI15 src=[wiremod_word_to_binary(source,32)] imm=[immediate] res=[wiremod_word_to_binary(result,32)]"
				if(2)
					result = wiremod_s32(source) < immediate ? 1 : 0
				if(3)
					result = wiremod_u32_sltu(source, imm_word) ? 1 : 0
				if(4)
					result = wiremod_u32_xor(source, imm_word)
				if(6)
					result = wiremod_u32_or(source, imm_word)
				if(7)
					result = wiremod_u32_and(source, imm_word)
				if(1)
					result = wiremod_u32_shl(source, shamt)
				if(5)
					if(funct7 == 0)
						result = wiremod_u32_shrl(source, shamt)
					else if(funct7 == 0x20)
						result = wiremod_u32_sra(source, shamt)
					else
						fault("Unknown shift instruction.")
						return
			set_reg(rd, result)
			advance()
		if(0x33) // register arithmetic
			var/list/source = get_reg(rs1)
			var/list/other = get_reg(rs2)
			var/shamt = other[2] % 32
			var/result
			switch(funct3)
				if(0)
					if(funct7 == 0x20)
						result = wiremod_u32_sub(source, other)
					else if(funct7 == 0)
						result = wiremod_u32_add(source, other)
					else
						fault("Unknown arithmetic instruction.")
						return
				if(1)
					result = wiremod_u32_shl(source, shamt)
				if(2)
					result = wiremod_u32_slt(source, other) ? 1 : 0
				if(3)
					result = wiremod_u32_sltu(source, other) ? 1 : 0
				if(4)
					result = wiremod_u32_xor(source, other)
				if(5)
					if(funct7 == 0x20)
						result = wiremod_u32_sra(source, shamt)
					else if(funct7 == 0)
						result = wiremod_u32_shrl(source, shamt)
					else
						fault("Unknown shift instruction.")
						return
				if(6)
					result = wiremod_u32_or(source, other)
				if(7)
					result = wiremod_u32_and(source, other)
			set_reg(rd, result)
			advance()
		if(0x0F) // fence
			advance()
		if(0x73) // ecall and ebreak stop the program on purpose
			halt("The program halted.")
		else
			fault("Unknown instruction [wiremod_word_to_binary(word, 32)].")

/obj/item/circuit_component/riscv_cpu/proc/start_rmw(address, value, funct3)
	pending_address = address
	pending_value = value
	pending_funct3 = funct3
	state = CIRCUIT_CPU_STATE_RMW_READ
	budget--
	address_output.set_output(wiremod_word_to_binary((address - (address % 4)) % CIRCUIT_MEMORY_LOCAL_BYTES, 19))
	command_output.set_output(0)
	pulse()

/obj/item/circuit_component/riscv_cpu/proc/finish_rmw(word)
	var/address = pending_address
	var/aligned = address - (address % 4)
	var/list/wh = wiremod_u32_halves(word)
	var/patched_hi = wh[1]
	var/patched_lo = wh[2]
	if(pending_funct3 == 0)
		var/shift = (address % 4) * 8
		var/list/pvh = wiremod_u32_halves(pending_value); var/byteval = pvh[2] % 256
		if(shift < 16)
			var/mask = 255 * (2 ** shift)
			patched_lo = (patched_lo - (patched_lo & mask)) + byteval * (2 ** shift)
		else
			var/s2 = shift - 16
			var/mask2 = 255 * (2 ** s2)
			patched_hi = (patched_hi - (patched_hi & mask2)) + byteval * (2 ** s2)
	else
		var/list/pvh2 = wiremod_u32_halves(pending_value); var/hv = pvh2[2] % 65536
		if(address % 4 >= 2)
			patched_hi = hv
		else
			patched_lo = hv
	var/patched = list(patched_hi, patched_lo)
	state = CIRCUIT_CPU_STATE_IDLE
	budget--
	address_output.set_output(wiremod_word_to_binary(aligned % CIRCUIT_MEMORY_LOCAL_BYTES, 19))
	command_output.set_output(1)
	data_output.set_output(wiremod_word_to_binary(patched, 32))
	pulse()

/obj/item/circuit_component/riscv_cpu/proc/finish_load(word)
	var/address = pending_address
	var/list/wh = wiremod_u32_halves(word)
	var/value
	switch(pending_funct3)
		if(0) // lb
			var/shift = (address % 4) * 8
			var/bv = floor((shift < 16 ? wh[2] : wh[1]) / (2 ** (shift % 16))) % 256
			value = bv >= 128 ? bv - 256 : bv
		if(4) // lbu
			var/shift4 = (address % 4) * 8
			value = floor((shift4 < 16 ? wh[2] : wh[1]) / (2 ** (shift4 % 16))) % 256
		if(1) // lh
			var/hv = (address % 4) >= 2 ? wh[1] : wh[2]
			value = hv >= 32768 ? hv - 65536 : hv
		if(5) // lhu
			value = (address % 4) >= 2 ? wh[1] : wh[2]
		else // lw
			value = word
	set_reg(pending_rd, value)

/proc/riscv_branch_offset(word)
	var/bit12 = wiremod_bits(word, 31, 1)
	var/bits10_5 = wiremod_bits(word, 25, 6)
	var/bits4_1 = wiremod_bits(word, 8, 4)
	var/bit11 = wiremod_bits(word, 7, 1)
	return wiremod_sign_extend(bit12 * 4096 + bits10_5 * 32 + bits4_1 * 2 + bit11 * 2048, 13)

/proc/riscv_jump_offset(word)
	var/bit20 = wiremod_bits(word, 31, 1)
	var/bits10_1 = wiremod_bits(word, 21, 10)
	var/bit11 = wiremod_bits(word, 20, 1)
	var/bits19_12 = wiremod_bits(word, 12, 8)
	return wiremod_sign_extend(bit20 * 1048576 + bits10_1 * 2 + bit11 * 2048 + bits19_12 * 4096, 21)

