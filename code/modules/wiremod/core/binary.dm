// 32-bit word arithmetic and the one bit order the computer parts share.
// Words travel as text, most significant bit first: "1000...000" is the
// hardware's bit 31 and the leftmost character. Every producer and consumer of
// a word uses these procs, so the assembler, the punch reader, memory and the
// CPU cannot disagree about which end is which.
//
// BYOND 516 bitwise ops are 24-bit; DM numbers are doubles and round near 2^32.
// A word is therefore kept as two 16-bit halves and only combined into a float
// for display or arithmetic that stays well below 2^53.

/proc/wiremod_u16(value)
	if(!isnum(value) || isnan(value) || isinf(value))
		return 0
	value = round(value)
	value -= floor(value / 65536) * 65536
	if(value < 0)
		value += 65536
	return value

// Canonical word form: list(hi16, lo16). BYOND 516 has 24-bit bitwise ops and
// rounds 2^32-boundary doubles, so 32-bit decomposition stays in halves.
/proc/wiremod_u32_halves(value)
	if(islist(value) && length(value) >= 2)
		return list(wiremod_u16(value[1]), wiremod_u16(value[2]))
	if(!isnum(value) || isnan(value) || isinf(value))
		return list(0, 0)
	value = round(value)
	var/two32 = 65536 * 65536
	// BYOND represents 0xFFFFFFFF (4294967295) as 4294967296.0.
	if(value == two32)
		return list(65535, 65535)
	value -= floor(value / two32) * two32
	if(value < 0)
		value += two32
	if(value == two32)
		return list(65535, 65535)
	var/hi = floor(value / 65536)
	var/lo = round(value - hi * 65536)
	if(lo >= 65536)
		lo -= 65536
		hi += 1
	if(hi >= 65536)
		hi = 65536 - 1
		lo = 65536 - 1
	return list(hi, lo)

/proc/wiremod_u32(value)
	return wiremod_u32_halves(value)

/proc/wiremod_u32_num(value)
	var/list/h = wiremod_u32_halves(value)
	return h[1] * 65536 + h[2]

/proc/wiremod_s32(value)
	var/list/h = wiremod_u32_halves(value)
	if(h[1] >= 32768)
		return (h[1] - 65536) * 65536 + h[2]
	return h[1] * 65536 + h[2]

// Count bits wide starting at bit `start`.
/proc/wiremod_bits(value, start, count)
	if(count <= 0 || start < 0)
		return 0
	var/list/h = wiremod_u32_halves(value)
	var/hi = h[1]
	var/lo = h[2]
	var/result = 0
	for(var/bit = 0, bit < count, bit++)
		var/source = start + bit
		var/bit_value = 0
		if(source < 16)
			bit_value = floor(lo / (2 ** source)) % 2
		else if(source < 32)
			bit_value = floor(hi / (2 ** (source - 16))) % 2
		if(bit_value)
			result += 2 ** bit
	return result

/proc/wiremod_sign_extend(value, width)
	if(width <= 0)
		return 0
	value = round(value)
	var/modulus = 2 ** width
	value -= floor(value / modulus) * modulus
	if(value < 0)
		value += modulus
	if(value >= 2 ** (width - 1))
		value -= modulus
	return value

/proc/wiremod_binary_to_word(text)
	if(!istext(text))
		return null
	var/len = length(text)
	if(len <= 0 || len > 32)
		return null
	var/hi = 0
	var/lo = 0
	for(var/index in 1 to len)
		var/character = copytext(text, index, index + 1)
		var/bit
		if(character == "1")
			bit = 1
		else if(character == "0")
			bit = 0
		else
			return null
		var/bitpos = len - index
		if(bitpos < 16)
			lo += bit * (2 ** bitpos)
		else
			hi += bit * (2 ** (bitpos - 16))
	return list(hi, lo)

/proc/wiremod_word_to_binary(word, width = 32)
	var/list/h = wiremod_u32_halves(word)
	var/hi = h[1]
	var/lo = h[2]
	var/text = ""
	for(var/bit = width - 1, bit >= 0, bit--)
		var/bit_value
		if(bit < 16)
			bit_value = floor(lo / (2 ** bit)) % 2
		else
			bit_value = floor(hi / (2 ** (bit - 16))) % 2
		text += bit_value ? "1" : "0"
	return text

/proc/wiremod_u32_eq(a, b)
	var/list/ha = wiremod_u32_halves(a)
	var/list/hb = wiremod_u32_halves(b)
	return ha[1] == hb[1] && ha[2] == hb[2]

/proc/wiremod_u32_add(a, b)
	var/list/ha = wiremod_u32_halves(a)
	var/list/hb = wiremod_u32_halves(b)
	var/lo = ha[2] + hb[2]
	var/hi = ha[1] + hb[1] + floor(lo / 65536)
	return list(hi % 65536, lo % 65536)

/proc/wiremod_u32_sub(a, b)
	var/list/ha = wiremod_u32_halves(a)
	var/list/hb = wiremod_u32_halves(b)
	var/lo = ha[2] - hb[2]
	var/hi = ha[1] - hb[1]
	if(lo < 0)
		lo += 65536
		hi -= 1
	if(hi < 0)
		hi += 65536
	return list(hi % 65536, lo % 65536)

/proc/wiremod_u32_xor(a, b)
	var/list/ha = wiremod_u32_halves(a)
	var/list/hb = wiremod_u32_halves(b)
	return list(ha[1] ^ hb[1], ha[2] ^ hb[2])

/proc/wiremod_u32_or(a, b)
	var/list/ha = wiremod_u32_halves(a)
	var/list/hb = wiremod_u32_halves(b)
	return list(ha[1] | hb[1], ha[2] | hb[2])

/proc/wiremod_u32_and(a, b)
	var/list/ha = wiremod_u32_halves(a)
	var/list/hb = wiremod_u32_halves(b)
	return list(ha[1] & hb[1], ha[2] & hb[2])

/proc/wiremod_u32_slt(a, b)
	return wiremod_s32(a) < wiremod_s32(b)

/proc/wiremod_u32_sltu(a, b)
	var/list/ha = wiremod_u32_halves(a)
	var/list/hb = wiremod_u32_halves(b)
	if(ha[1] != hb[1])
		return ha[1] < hb[1]
	return ha[2] < hb[2]

/proc/wiremod_u32_shl(a, shamt)
	var/list/h = wiremod_u32_halves(a)
	var/hi = h[1]
	var/lo = h[2]
	if(shamt <= 0)
		return list(hi, lo)
	if(shamt >= 32)
		return list(0, 0)
	if(shamt >= 16)
		return list(lo * (2 ** (shamt - 16)) % 65536, 0)
	var/new_hi = (hi * (2 ** shamt) + floor(lo / (2 ** (16 - shamt)))) % 65536
	var/new_lo = (lo * (2 ** shamt)) % 65536
	return list(new_hi, new_lo)

/proc/wiremod_u32_shrl(a, shamt)
	var/list/h = wiremod_u32_halves(a)
	var/hi = h[1]
	var/lo = h[2]
	if(shamt <= 0)
		return list(hi, lo)
	if(shamt >= 32)
		return list(0, 0)
	if(shamt >= 16)
		return list(0, floor(hi / (2 ** (shamt - 16))) % 65536)
	var/new_hi = floor(hi / (2 ** shamt))
	var/new_lo = (floor(lo / (2 ** shamt)) + (hi % (2 ** shamt)) * (2 ** (16 - shamt))) % 65536
	return list(new_hi, new_lo)

/proc/wiremod_u32_sra(a, shamt)
	var/list/h = wiremod_u32_halves(a)
	if(h[1] < 32768)
		return wiremod_u32_shrl(a, shamt)
	if(shamt <= 0)
		return list(h[1], h[2])
	if(shamt >= 32)
		return list(65535, 65535)
	var/list/r = wiremod_u32_shrl(a, shamt)
	var/fill = (65536 - (2 ** (16 - min(shamt, 16)))) % 65536
	if(shamt >= 16)
		r[1] = 65535
		r[2] = (r[2] | (65536 - (2 ** (32 - shamt)))) % 65536
	else
		r[1] = (r[1] | fill) % 65536
	return r

