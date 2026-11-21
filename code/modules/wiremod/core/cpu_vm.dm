// A closed instruction set: no DM evaluation, files, objects, calls or timers.
// A VM is owned by an attached component. One board fits in each shell; all
// CPU components on that board draw from the same RAM and work limits.
var/global/wiremod_cpu_budget_time = -1
var/global/wiremod_cpu_ops = 0
var/global/wiremod_cpu_ram = 0

/obj/item/integrated_circuit
	var/tmp/cpu_budget_time = -1
	var/tmp/cpu_ops = 0
	var/tmp/cpu_ram = 0

/obj/item/integrated_circuit/proc/consume_cpu_ops(cost)
	if(cpu_budget_time != world.time)
		cpu_budget_time = world.time
		cpu_ops = 0
	if(wiremod_cpu_budget_time != world.time)
		wiremod_cpu_budget_time = world.time
		wiremod_cpu_ops = 0
	if(cpu_ops + cost > CIRCUIT_CPU_BOARD_OPS || wiremod_cpu_ops + cost > CIRCUIT_CPU_WORLD_OPS)
		return FALSE
	cpu_ops += cost
	wiremod_cpu_ops += cost
	return TRUE

/datum/wiremod_cpu
	var/obj/item/integrated_circuit/board
	var/list/program = list()
	// Lazily allocated pages of 256 bytes, packed 3 per 24-bit number. The
	// last word's two padding bytes cannot be addressed.
	var/list/pages = list()
	var/pc = 1
	var/accumulator = 0
	var/address = 0
	var/halted = FALSE

/datum/wiremod_cpu/New(obj/item/integrated_circuit/owner)
	. = ..()
	board = owner

/datum/wiremod_cpu/proc/reset()
	if(board)
		var/bytes = length(pages) * CIRCUIT_CPU_PAGE_BYTES
		board.cpu_ram -= bytes
		wiremod_cpu_ram -= bytes
	pages.Cut()
	pc = 1
	accumulator = 0
	address = 0
	halted = FALSE

/datum/wiremod_cpu/Destroy()
	reset()
	board = null
	program.Cut()
	return ..()

/datum/wiremod_cpu/proc/load_program(source)
	if(!istext(source) || !length(source) || length(source) > PORT_MAX_STRING_LENGTH)
		return FALSE
	var/static/regex/instruction = regex(@"^([a-z]+)( +([0-9]{1,8}))?$")
	var/static/list/ranges = list("set" = CIRCUIT_CPU_WORD_MAX, "add" = CIRCUIT_CPU_WORD_MAX, "addr" = CIRCUIT_CPU_RAM_BYTES - 1, "next" = CIRCUIT_CPU_RAM_BYTES - 1, "jmp" = CIRCUIT_CPU_PROGRAM_MAX, "jz" = CIRCUIT_CPU_PROGRAM_MAX)
	var/static/list/no_arg = list("in", "out", "get", "put", "halt", "nop")
	var/list/parsed = list()
	var/list/lines = splittext(replacetext(replacetext(replacetext(lowertext(source), ";", "\n"), ascii2text(13), ""), "\t", " "), "\n")
	for(var/raw in lines)
		var/line = trim(raw)
		if(!length(line))
			continue
		if(length(parsed) >= CIRCUIT_CPU_PROGRAM_MAX || !instruction.Find(line))
			return FALSE
		var/op = instruction.group[1]
		var/arg = length(instruction.group) >= 3 ? instruction.group[3] : null
		var/limit = ranges[op]
		if(isnull(limit))
			if(length(arg) || !(op in no_arg))
				return FALSE
		else
			if(!length(arg))
				return FALSE
			arg = text2num(arg)
			if(!isnum(arg) || arg > limit)
				return FALSE
		parsed += list(list(op, arg))
	if(!length(parsed))
		return FALSE
	for(var/list/command as anything in parsed)
		if((command[1] == "jmp" || command[1] == "jz") && (command[2] < 1 || command[2] > length(parsed)))
			return FALSE
	// Invalid source never clears RAM, drops a program or rewinds a running VM.
	reset()
	program = parsed
	return TRUE

/datum/wiremod_cpu/proc/read_byte(at)
	if(!isnum(at) || isnan(at) || isinf(at) || at < 0 || at >= CIRCUIT_CPU_RAM_BYTES || round(at) != at)
		return null
	var/page_key = "[round(at / CIRCUIT_CPU_PAGE_BYTES)]"
	var/list/page = pages[page_key]
	if(!page)
		return 0
	var/offset = at % CIRCUIT_CPU_PAGE_BYTES
	var/word = page[round(offset / 3) + 1]
	return isnum(word) ? ((word >> ((offset % 3) * 8)) & 255) : 0

/datum/wiremod_cpu/proc/write_byte(at, byte)
	if(!board || !isnum(at) || isnan(at) || isinf(at) || at < 0 || at >= CIRCUIT_CPU_RAM_BYTES || round(at) != at)
		return FALSE
	if(!isnum(byte) || isnan(byte) || isinf(byte) || byte < 0 || byte > 255 || round(byte) != byte)
		return FALSE
	var/page_key = "[round(at / CIRCUIT_CPU_PAGE_BYTES)]"
	var/list/page = pages[page_key]
	if(!page)
		if(!byte)
			return TRUE
		if(board.cpu_ram + CIRCUIT_CPU_PAGE_BYTES > CIRCUIT_CPU_RAM_BYTES || wiremod_cpu_ram + CIRCUIT_CPU_PAGE_BYTES > CIRCUIT_CPU_WORLD_RAM_BYTES)
			return FALSE
		page = new /list(CIRCUIT_CPU_PAGE_WORDS)
		pages[page_key] = page
		board.cpu_ram += CIRCUIT_CPU_PAGE_BYTES
		wiremod_cpu_ram += CIRCUIT_CPU_PAGE_BYTES
	var/offset = at % CIRCUIT_CPU_PAGE_BYTES
	var/index = round(offset / 3) + 1
	var/shift = (offset % 3) * 8
	var/word = page[index]
	if(!isnum(word))
		word = 0
	var/previous_byte = (word >> shift) & 255
	page[index] = word ^ ((previous_byte ^ byte) << shift)
	return TRUE

// The caller supplies a bounded request, not a clock or a loop continuation.
// Stop at the first OUT so no port event disappears inside a batch.
/datum/wiremod_cpu/proc/execute(requested, input_value)
	if(!length(program))
		return "no program"
	if(halted)
		return "halted"
	for(var/i = 1 to min(requested, CIRCUIT_CPU_SLICE))
		if(pc > length(program))
			halted = TRUE
			return "halted"
		if(!board?.consume_cpu_ops(1))
			return "budget"
		var/list/command = program[pc]
		var/argument = command[2]
		pc++
		switch(command[1])
			if("set")
				accumulator = argument
			if("add")
				// Wrap before adding so the intermediate stays exactly representable.
				if(accumulator > CIRCUIT_CPU_WORD_MAX - argument)
					accumulator -= CIRCUIT_CPU_WORD_MAX - argument + 1
				else
					accumulator += argument
			if("addr")
				address = argument
			if("next")
				address = (address + argument) % CIRCUIT_CPU_RAM_BYTES
			if("get")
				accumulator = read_byte(address)
			if("put")
				if(!write_byte(address, accumulator & 255))
					halted = TRUE
					return "RAM limit"
			if("in")
				var/number = wiremod_safe_number(input_value)
				accumulator = isnum(number) ? round(max(0, min(number, CIRCUIT_CPU_WORD_MAX))) : 0
			if("out")
				return "output"
			if("jmp")
				pc = argument
			if("jz")
				if(!accumulator)
					pc = argument
			if("halt")
				halted = TRUE
				return "halted"
	return "ready"
