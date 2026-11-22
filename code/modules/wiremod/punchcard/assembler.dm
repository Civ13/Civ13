// The punch card assembler turns RV32I assembly written on paper into linked
// punch cards. It reads the paper in the order it was loaded and produces one
// card per 25 words, the last card short if the program does not divide evenly.
// A program with any error produces no cards and reports every bad line.
//
// The parser is a plain proc over text so it can be tested without paper, a
// machine or a player. It follows the same MSB-first bit order as the reader
// and the CPU.

/obj/structure/punch_assembler
	name = "punch card assembler"
	desc = "Reads RV32I assembly from paper and punches it into linked cards. Load paper, then press Assemble."
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer"
	var/list/obj/item/weapon/paper/papers = list()
	var/list/obj/item/weapon/punch_card/output_cards = list()
	var/list/errors = list()

/obj/structure/punch_assembler/attackby(obj/item/item, mob/user)
	if(istype(item, /obj/item/weapon/paper))
		if(item.loc == user)
			user.drop_from_inventory(item)
		item.forceMove(src)
		papers += item
		errors = list()
		to_chat(user, "<span class='notice'>You load [item] into [src].</span>")
		return TRUE
	return ..()

/obj/structure/punch_assembler/attack_hand(mob/user)
	ui_interact(user)

/obj/structure/punch_assembler/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = TRUE)
	var/list/paper_items = list()
	for(var/obj/item/weapon/paper/paper as anything in papers)
		paper_items += list(list("name" = paper.name))
	var/list/card_items = list()
	for(var/obj/item/weapon/punch_card/card as anything in output_cards)
		card_items += list(list("name" = card.name, "detail" = "[card.word_count()] words"))
	var/list/sections = list(
		list("title" = "Paper", "items" = paper_items, "empty" = "No paper loaded. Use a sheet of paper on the assembler."),
		list("title" = "Cards", "items" = card_items, "empty" = "No cards punched yet."),
		list("buttons" = list(
			list("label" = "Assemble", "action" = "assemble", "id" = 1),
			list("label" = "Eject Cards", "action" = "eject", "id" = 1),
			list("label" = "Clear Paper", "action" = "clear", "id" = 1))))
	if(length(errors))
		sections.Insert(1, list("title" = "Errors", "notes" = errors))
	open_tgui(user, ui_key, "panel.tmpl", name, 520, 560, list("sections" = sections), ui, force_open)

/obj/structure/punch_assembler/ui_actions(ui_key)
	return list("assemble", "eject", "clear")

/obj/structure/punch_assembler/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if(!istype(user) || !user.Adjacent(src))
		return TRUE
	switch(action)
		if("assemble")
			assemble(user)
			ui_interact(user)
			return TRUE
		if("eject")
			eject_cards()
			ui_interact(user)
			return TRUE
		if("clear")
			clear_paper()
			ui_interact(user)
			return TRUE
	return FALSE

/obj/structure/punch_assembler/proc/assemble(mob/user)
	errors = list()
	var/list/words = list()
	for(var/obj/item/weapon/paper/paper as anything in papers)
		var/list/result = punch_assembler_parse(paper.info)
		words += result["words"]
		errors += result["errors"]
	if(length(errors))
		to_chat(user, "<span class='warning'>[src] finds [length(errors)] error[length(errors) == 1 ? "" : "s"] and punches no cards.</span>")
		return FALSE
	if(!length(words))
		errors += "No instructions on the loaded paper."
		return FALSE
	for(var/card in output_cards)
		qdel(card)
	output_cards = list()
	var/obj/item/weapon/punch_card/previous
	for(var/start = 1, start <= length(words), start += PUNCH_CARD_WORDS)
		var/list/chunk = list()
		for(var/index = start, index < start + PUNCH_CARD_WORDS && index <= length(words), index++)
			chunk += words[index]
		var/obj/item/weapon/punch_card/card = new(get_turf(src))
		card.set_words(chunk)
		if(previous)
			previous.link_card(card)
		else
			output_cards += card
		previous = card
	to_chat(user, "<span class='notice'>[src] punches [length(words)] words into [length(output_cards)] card[length(output_cards) == 1 ? "" : "s"].</span>")
	return TRUE

/obj/structure/punch_assembler/proc/eject_cards()
	var/turf/destination = get_turf(src)
	for(var/obj/item/weapon/punch_card/card as anything in output_cards)
		card.forceMove(destination)
	output_cards = list()
	errors = list()

/obj/structure/punch_assembler/proc/clear_paper()
	for(var/obj/item/weapon/paper/paper as anything in papers)
		paper.forceMove(get_turf(src))
	papers = list()
	errors = list()

/obj/structure/punch_assembler/examine(mob/user)
	. = ..()
	to_chat(user, "It holds [length(papers)] sheet[length(papers) == 1 ? "" : "s"] and [length(output_cards)] finished card[length(output_cards) == 1 ? "" : "s"].")

// Turns assembly text into words. Returns list("words" = ..., "errors" = ...).
// It fails closed: a single bad line means the caller gets no words from it.
/proc/punch_assembler_parse(text)
	var/list/errors = list()
	var/list/items = list()
	var/list/labels = list()
	if(!istext(text))
		return list("words" = list(), "errors" = list("The paper is empty."))
	var/address = 0
	var/line_number = 0
	for(var/raw_line in splittext(text, "\n"))
		line_number++
		var/line = trim(punch_strip_comment(raw_line))
		if(!length(line))
			continue
		if(copytext(line, length(line)) == ":")
			var/label = lowertext(trim(copytext(line, 1, length(line))))
			if(!length(label))
				errors += "Line [line_number]: a label has no name."
			else
				labels[label] = address
			continue
		var/split = 0
		for(var/separator in list(" ", "\t"))
			var/found = findtext(line, separator)
			if(found && (!split || found < split))
				split = found
		var/mnemonic
		var/rest = ""
		if(split)
			mnemonic = lowertext(copytext(line, 1, split))
			rest = trim(copytext(line, split + 1))
		else
			mnemonic = lowertext(line)
		var/list/operands = list()
		if(length(rest))
			for(var/part in splittext(rest, ","))
				operands += trim(part)
		items += list(list("mnemonic" = mnemonic, "operands" = operands, "address" = address, "line" = line_number))
		address += 4 * punch_item_words(mnemonic, operands)
	var/list/words = list()
	for(var/list/item as anything in items)
		var/list/emitted = punch_encode_item(item, labels, errors)
		for(var/word in emitted)
			words += list(word)
	if(length(errors))
		return list("words" = list(), "errors" = errors)
	return list("words" = words, "errors" = errors)

/proc/punch_strip_comment(line)
	var/cut = 0
	for(var/marker in list("#", ";"))
		var/found = findtext(line, marker)
		if(found && (!cut || found < cut))
			cut = found
	return cut ? copytext(line, 1, cut) : line

/proc/punch_item_words(mnemonic, list/operands)
	switch(mnemonic)
		if(".word")
			return max(1, length(operands))
		if("la", "call")
			return 2
		if("li", "liu")
			if(length(operands) < 2)
				return 1
			var/list/vw = punch_number(operands[2])
			if(isnull(vw))
				return 2
			var/signed = wiremod_s32(vw)
			return (signed >= -2048 && signed <= 2047) ? 1 : 2
		if("lb","lbu","lh","lhu","lw","sb","sh")
			if(length(operands) < 2)
				return 1
			var/list/memory = punch_memory_operand(operands[2])
			if(!memory)
				return 1
			var/imm = wiremod_u32_num(memory[1])
			if(imm >= -2048 && imm <= 2047)
				return 1
			return (memory[2] != 0) ? 4 : 3
	return 1

// One instruction as up to two words. Errors are appended to the caller's list
// and nothing is emitted for that line.
/proc/punch_emit_mem_large(rd_or_rs2, rs1, funct3, opcode, immediate, is_store, list/result)
	// expand: lui tmp,hi; addi tmp,tmp,lo; add tmp,tmp,rs1; op rd_or_rs2,0(tmp)
	var/tmp = is_store ? 31 : rd_or_rs2
	if(is_store && rd_or_rs2 == 31)
		tmp = 30
	var/list/h = wiremod_u32_halves(immediate)
	var/u_hi = h[1]
	var/u_lo = h[2]
	var/lo12 = u_lo % 4096
	var/hi = floor(u_hi * 16 + floor(u_lo / 4096) + (lo12 >= 2048 ? 1 : 0)) % 1048576
	if(lo12 >= 2048)
		lo12 -= 4096
	result += list(punch_u_type(hi, tmp, 0x37))
	result += list(punch_i_type(lo12, tmp, 0, tmp, 0x13))
	if(rs1 != 0)
		result += list(punch_r_type(0, rs1, tmp, 0, tmp, 0x33))
	if(is_store)
		result += list(punch_s_type(0, rd_or_rs2, tmp, funct3, opcode))
	else
		result += list(punch_i_type(0, tmp, funct3, rd_or_rs2, opcode))

/proc/punch_encode_item(list/item, list/labels, list/errors)
	var/mnemonic = item["mnemonic"]
	var/list/ops = item["operands"]
	var/address = item["address"]
	var/line = item["line"]
	var/list/result = list()
	if(mnemonic == ".word")
		if(length(ops) < 1)
			errors += "Line [line]: .word needs a value."
			return result
		for(var/operand in ops)
			var/value = punch_number(operand)
			if(isnull(value))
				errors += "Line [line]: [operand] is not a number."
				return list()
			result += list(wiremod_u32(value))
		return result
	if(mnemonic == "nop")
		return list(punch_i_type(0, 0, 0, 0, 0x13))
	if(mnemonic == "ecall")
		return list(wiremod_u32(0x00000073))
	if(mnemonic == "ebreak")
		return list(wiremod_u32(0x00100073))
	if(mnemonic == "fence")
		return list(wiremod_u32(0x0000000F))
	if(mnemonic == "ret")
		return list(punch_i_type(0, 1, 0, 0, 0x67))
	if(mnemonic == "mv")
		if(length(ops) != 2)
			errors += "Line [line]: mv needs a destination and a source."
			return result
		var/destination = punch_register(ops[1])
		var/source = punch_register(ops[2])
		if(destination < 0 || source < 0)
			errors += "Line [line]: mv needs two registers."
			return result
		return list(punch_i_type(0, source, 0, destination, 0x13))
	if(mnemonic == "li" || mnemonic == "liu" || mnemonic == "la")
		if(length(ops) != 2)
			errors += "Line [line]: [mnemonic] needs a register and a value."
			return result
		var/destination = punch_register(ops[1])
		if(destination < 0)
			errors += "Line [line]: [ops[1]] is not a register."
			return result
		var/value
		if(mnemonic == "la")
			value = punch_target(ops[2], labels, 0)
		else
			value = punch_number(ops[2])
		if(isnull(value))
			errors += "Line [line]: [ops[2]] is not a value."
			return result
		if(mnemonic == "la")
			punch_emit_absolute(destination, value, result)
		else
			punch_emit_li(destination, value, result)
		return result
	if(mnemonic == "j" || mnemonic == "call")
		if(length(ops) != 1)
			errors += "Line [line]: [mnemonic] needs a target."
			return result
		var/offset = punch_target(ops[1], labels, address)
		if(isnull(offset))
			errors += "Line [line]: [ops[1]] is not a target."
			return result
		if(mnemonic == "j")
			return list(punch_j_type(offset, 0, 0x6F))
		var/hi = floor(wiremod_u32(offset + 0x800) / 4096) % 1048576
		var/lo = wiremod_sign_extend(wiremod_u32_num(offset - hi * 4096) % 4096, 12)
		return list(punch_u_type(hi, 1, 0x17), punch_i_type(lo, 1, 0, 1, 0x67))
	if(mnemonic == "jr")
		if(length(ops) != 1)
			errors += "Line [line]: jr needs a register."
			return result
		var/source = punch_register(ops[1])
		if(source < 0)
			errors += "Line [line]: [ops[1]] is not a register."
			return result
		return list(punch_i_type(0, source, 0, 0, 0x67))

	var/funct3 = -1
	var/funct7 = 0
	var/opcode = -1
	switch(mnemonic)
		if("add")
			opcode = 0x33; funct3 = 0; funct7 = 0
		if("sub")
			opcode = 0x33; funct3 = 0; funct7 = 0x20
		if("sll")
			opcode = 0x33; funct3 = 1
		if("slt")
			opcode = 0x33; funct3 = 2
		if("sltu")
			opcode = 0x33; funct3 = 3
		if("xor")
			opcode = 0x33; funct3 = 4
		if("srl")
			opcode = 0x33; funct3 = 5
		if("sra")
			opcode = 0x33; funct3 = 5; funct7 = 0x20
		if("or")
			opcode = 0x33; funct3 = 6
		if("and")
			opcode = 0x33; funct3 = 7
		if("addi")
			opcode = 0x13; funct3 = 0
		if("slti")
			opcode = 0x13; funct3 = 2
		if("sltiu")
			opcode = 0x13; funct3 = 3
		if("xori")
			opcode = 0x13; funct3 = 4
		if("ori")
			opcode = 0x13; funct3 = 6
		if("andi")
			opcode = 0x13; funct3 = 7
		if("slli")
			opcode = 0x13; funct3 = 1
		if("srli")
			opcode = 0x13; funct3 = 5
		if("srai")
			opcode = 0x13; funct3 = 5; funct7 = 0x20
		if("lb")
			opcode = 0x03; funct3 = 0
		if("lh")
			opcode = 0x03; funct3 = 1
		if("lw")
			opcode = 0x03; funct3 = 2
		if("lbu")
			opcode = 0x03; funct3 = 4
		if("lhu")
			opcode = 0x03; funct3 = 5
		if("sb")
			opcode = 0x23; funct3 = 0
		if("sh")
			opcode = 0x23; funct3 = 1
		if("sw")
			opcode = 0x23; funct3 = 2
		if("beq")
			opcode = 0x63; funct3 = 0
		if("bne")
			opcode = 0x63; funct3 = 1
		if("blt")
			opcode = 0x63; funct3 = 4
		if("bge")
			opcode = 0x63; funct3 = 5
		if("bltu")
			opcode = 0x63; funct3 = 6
		if("bgeu")
			opcode = 0x63; funct3 = 7
		if("beqz")
			opcode = 0x63; funct3 = 0
		if("bnez")
			opcode = 0x63; funct3 = 1
		if("jal")
			opcode = 0x6F
		if("jalr")
			opcode = 0x67; funct3 = 0
		if("lui")
			opcode = 0x37
		if("auipc")
			opcode = 0x17
	if(opcode < 0)
		errors += "Line [line]: [mnemonic] is not an RV32I instruction."
		return result

	if(opcode == 0x33)
		if(length(ops) != 3)
			errors += "Line [line]: [mnemonic] needs a destination and two sources."
			return result
		var/rd = punch_register(ops[1])
		var/rs1 = punch_register(ops[2])
		var/rs2 = punch_register(ops[3])
		if(rd < 0 || rs1 < 0 || rs2 < 0)
			errors += "Line [line]: [mnemonic] needs three registers."
			return result
		return list(punch_r_type(funct7, rs2, rs1, funct3, rd, opcode))
	if(opcode == 0x13)
		if(length(ops) != 3)
			errors += "Line [line]: [mnemonic] needs a destination, a source and a value."
			return result
		var/rd = punch_register(ops[1])
		var/rs1 = punch_register(ops[2])
		var/list/immw2 = punch_number(ops[3])
		if(rd < 0 || rs1 < 0 || isnull(immw2))
			errors += "Line [line]: [mnemonic] needs two registers and an immediate."
			return result
		var/immediate = wiremod_u32_num(immw2)
		if(rd < 0 || rs1 < 0)
			errors += "Line [line]: [mnemonic] needs two registers and a value."
			return result
		if(funct3 == 1 || funct3 == 5)
			immediate = immediate % 32
			if(funct7)
				immediate += funct7 * 32
		return list(punch_i_type(immediate, rs1, funct3, rd, opcode))
	if(opcode == 0x03)
		if(length(ops) != 2)
			errors += "Line [line]: [mnemonic] needs a destination and an address."
			return result
		var/rd = punch_register(ops[1])
		var/list/memory = punch_memory_operand(ops[2])
		if(rd < 0 || !memory)
			errors += "Line [line]: [mnemonic] needs a register and offset(base)."
			return result
		var/imm = wiremod_u32_num(memory[1])
		if(imm >= -2048 && imm <= 2047)
			return list(punch_i_type(imm, memory[2], funct3, rd, opcode))
		punch_emit_mem_large(rd, memory[2], funct3, opcode, imm, FALSE, result)
		return result
	if(opcode == 0x23)
		if(length(ops) != 2)
			errors += "Line [line]: [mnemonic] needs a source and an address."
			return result
		var/rs2 = punch_register(ops[1])
		var/list/memory = punch_memory_operand(ops[2])
		if(rs2 < 0 || !memory)
			errors += "Line [line]: [mnemonic] needs a register and offset(base)."
			return result
		var/imm = wiremod_u32_num(memory[1])
		if(imm >= -2048 && imm <= 2047)
			return list(punch_s_type(imm, rs2, memory[2], funct3, opcode))
		punch_emit_mem_large(rs2, memory[2], funct3, opcode, imm, TRUE, result)
		return result
	if(opcode == 0x63)
		if(length(ops) == 2 && (mnemonic == "beqz" || mnemonic == "bnez"))
			var/rs1 = punch_register(ops[1])
			var/offset = punch_target(ops[2], labels, address)
			if(rs1 < 0 || isnull(offset))
				errors += "Line [line]: [mnemonic] needs a register and a target."
				return result
			return list(punch_b_type(offset, 0, rs1, funct3, opcode))
		if(length(ops) != 3)
			errors += "Line [line]: [mnemonic] needs two registers and a target."
			return result
		var/rs1 = punch_register(ops[1])
		var/rs2 = punch_register(ops[2])
		var/offset = punch_target(ops[3], labels, address)
		if(rs1 < 0 || rs2 < 0 || isnull(offset))
			errors += "Line [line]: [mnemonic] needs two registers and a target."
			return result
		return list(punch_b_type(offset, rs2, rs1, funct3, opcode))
	if(opcode == 0x6F)
		var/rd = 1
		var/target
		if(length(ops) == 1)
			target = ops[1]
		else if(length(ops) == 2)
			rd = punch_register(ops[1])
			target = ops[2]
		else
			errors += "Line [line]: jal needs a target, and optionally a destination."
			return result
		var/offset = punch_target(target, labels, address)
		if(rd < 0 || isnull(offset))
			errors += "Line [line]: jal needs a register and a target."
			return result
		return list(punch_j_type(offset, rd, opcode))
	if(opcode == 0x67)
		var/rd = 1
		var/rs1 = 1
		var/immediate = 0
		if(length(ops) == 1)
			rs1 = punch_register(ops[1])
		else if(length(ops) == 2)
			rd = punch_register(ops[1])
			var/list/memory = punch_memory_operand(ops[2])
			if(memory)
				immediate = memory[1]
				rs1 = memory[2]
			else
				rs1 = punch_register(ops[2])
		else if(length(ops) == 3)
			rd = punch_register(ops[1])
			rs1 = punch_register(ops[2])
			immediate = punch_number(ops[3])
		else
			errors += "Line [line]: jalr needs a destination, a base and a value."
			return result
		if(rd < 0 || rs1 < 0 || isnull(immediate))
			errors += "Line [line]: jalr needs registers and a value."
			return result
		return list(punch_i_type(immediate, rs1, 0, rd, opcode))
	if(opcode == 0x37 || opcode == 0x17)
		if(length(ops) != 2)
			errors += "Line [line]: [mnemonic] needs a destination and an upper value."
			return result
		var/rd = punch_register(ops[1])
		var/value = punch_number(ops[2])
		if(rd < 0 || isnull(value))
			errors += "Line [line]: [mnemonic] needs a register and a value."
			return result
		return list(punch_u_type(wiremod_u32_num(value), rd, opcode))
	return result

/proc/punch_emit_li(rd, value, list/result)
	var/signed = wiremod_s32(value)
	if(signed >= -2048 && signed <= 2047)
		result += list(punch_i_type(signed, 0, 0, rd, 0x13))
		return
	var/list/h = wiremod_u32_halves(value)
	var/u_hi = h[1]
	var/u_lo = h[2]
	var/lo12 = u_lo % 4096
	var/hi = floor(u_hi * 16 + floor(u_lo / 4096) + (lo12 >= 2048 ? 1 : 0)) % 1048576
	if(lo12 >= 2048)
		lo12 -= 4096
	result += list(punch_u_type(hi, rd, 0x37)); result += list(punch_i_type(lo12, rd, 0, rd, 0x13))

/proc/punch_emit_absolute(rd, value, list/result)
	var/list/h = wiremod_u32_halves(value)
	var/u_hi = h[1]
	var/u_lo = h[2]
	var/lo12 = u_lo % 4096
	var/hi = floor(u_hi * 16 + floor(u_lo / 4096) + (lo12 >= 2048 ? 1 : 0)) % 1048576
	if(lo12 >= 2048)
		lo12 -= 4096
	result += list(punch_u_type(hi, rd, 0x37))
	result += list(punch_i_type(lo12, rd, 0, rd, 0x13))

/proc/punch_target(text, list/labels, address)
	var/key = lowertext(trim(text))
	if(key in labels)
		return labels[key] - address
	var/list/nw = punch_number(text)
	return islist(nw) ? wiremod_u32_num(nw) : null

/proc/punch_register(text)
	var/name = lowertext(trim(text))
	var/static/list/names = list("zero" = 0, "ra" = 1, "sp" = 2, "gp" = 3, "tp" = 4,
		"t0" = 5, "t1" = 6, "t2" = 7, "s0" = 8, "fp" = 8, "s1" = 9,
		"a0" = 10, "a1" = 11, "a2" = 12, "a3" = 13, "a4" = 14, "a5" = 15, "a6" = 16, "a7" = 17,
		"s2" = 18, "s3" = 19, "s4" = 20, "s5" = 21, "s6" = 22, "s7" = 23, "s8" = 24, "s9" = 25, "s10" = 26, "s11" = 27,
		"t3" = 28, "t4" = 29, "t5" = 30, "t6" = 31)
	if(name in names)
		return names[name]
	if(copytext(name, 1, 2) == "x")
		var/list/numw = punch_number(copytext(name, 2))
		if(islist(numw))
			var/number = wiremod_u32_num(numw)
			if(number >= 0 && number <= 31 && number == round(number))
				return number
	return -1

/proc/punch_number(text)
	var/value = trim(text)
	if(!length(value))
		return null
	var/sign = 1
	var/first = copytext(value, 1, 2)
	if(first == "-")
		sign = -1
		value = copytext(value, 2)
	else if(first == "+")
		value = copytext(value, 2)
	if(!length(value))
		return null
	var/prefix = lowertext(copytext(value, 1, 3))
	var/list/number
	if(prefix == "0x")
		number = punch_digits(copytext(value, 3), 16)
	else if(prefix == "0b")
		number = punch_digits(copytext(value, 3), 2)
	else
		number = punch_digits(value, 10)
	if(isnull(number))
		return null
	if(sign < 0)
		var/lo = number[2]
		var/hi = number[1]
		var/neg_lo = (65536 - lo) % 65536
		var/neg_hi = (65535 - hi + (lo == 0 ? 1 : 0)) % 65536
		number = list(neg_hi, neg_lo)
	return number

/proc/punch_digits(text, base)
	if(!length(text))
		return null
	var/hi = 0
	var/lo = 0
	for(var/index in 1 to length(text))
		var/character = lowertext(copytext(text, index, index + 1))
		var/found = findtext("0123456789abcdef", character)
		if(!found || found - 1 >= base)
			return null
		var/digit = found - 1
		// value = value*base + digit, in 16-bit halves
		var/new_lo = lo * base + digit
		var/carry = floor(new_lo / 65536)
		new_lo = new_lo - carry * 65536
		var/new_hi = hi * base + carry
		new_hi = new_hi - floor(new_hi / 65536) * 65536
		hi = new_hi
		lo = new_lo
	return list(hi, lo)

/proc/punch_memory_operand(text)
	var/open = findtext(text, "(")
	var/close = findtext(text, ")")
	if(!open || !close || close <= open)
		return null
	var/list/immw = punch_number(copytext(text, 1, open))
	var/register = punch_register(copytext(text, open + 1, close))
	if(isnull(immw) || register < 0)
		return null
	return list(wiremod_u32_num(immw), register)

/proc/punch_field(value, width)
	var/modulus = 2 ** width
	return ((value % modulus) + modulus) % modulus

/proc/punch_pack(hi, lo)
	return list(((hi % 65536) + 65536) % 65536, ((lo % 65536) + 65536) % 65536)

/proc/punch_r_type(funct7, rs2, rs1, funct3, rd, opcode)
	var/lo = (rs1 % 2) * 32768 + funct3 * 4096 + rd * 128 + opcode
	var/hi = funct7 * 512 + rs2 * 16 + floor(rs1 / 2)
	return punch_pack(hi, lo)

/proc/punch_i_type(immediate, rs1, funct3, rd, opcode)
	var/imm = punch_field(immediate, 12)
	var/lo = (rs1 % 2) * 32768 + funct3 * 4096 + rd * 128 + opcode
	var/hi = imm * 16 + floor(rs1 / 2)
	return punch_pack(hi, lo)

/proc/punch_s_type(immediate, rs2, rs1, funct3, opcode)
	var/field = punch_field(immediate, 12)
	var/imm_hi = floor(field / 32)
	var/imm_lo = field % 32
	var/lo = (rs1 % 2) * 32768 + funct3 * 4096 + imm_lo * 128 + opcode
	var/hi = imm_hi * 512 + rs2 * 16 + floor(rs1 / 2)
	return punch_pack(hi, lo)

/proc/punch_b_type(immediate, rs2, rs1, funct3, opcode)
	var/field = punch_field(immediate, 13)
	var/bit12 = floor(field / 4096) % 2
	var/bit11 = floor(field / 2048) % 2
	var/bits10_5 = floor(field / 32) % 64
	var/bits4_1 = floor(field / 2) % 16
	var/lo = (rs1 % 2) * 32768 + funct3 * 4096 + bits4_1 * 256 + bit11 * 128 + opcode
	var/hi = bit12 * 32768 + bits10_5 * 512 + rs2 * 16 + floor(rs1 / 2)
	return punch_pack(hi, lo)

/proc/punch_u_type(upper, rd, opcode)
	var/u = punch_field(upper, 20)
	var/lo = (u % 16) * 4096 + rd * 128 + opcode
	var/hi = floor(u / 16)
	return punch_pack(hi, lo)

/proc/punch_j_type(immediate, rd, opcode)
	var/field = punch_field(immediate, 21)
	var/bit20 = floor(field / 1048576) % 2
	var/bits10_1 = floor(field / 2) % 1024
	var/bit11 = floor(field / 2048) % 2
	var/bits19_12 = floor(field / 4096) % 256
	var/lo = bits19_12 * 256 + rd * 128 + opcode
	var/hi = bit20 * 32768 + bits10_1 * 32 + bit11 * 16 + floor(bits19_12 / 16)
	return punch_pack(hi, lo)
