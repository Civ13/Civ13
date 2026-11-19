/obj/item/circuit_component/binary_conversion
	name = "binary conversion component"
	display_name = "Binary Conversion"
	category = "Math"
	desc = "Turns a whole number from 0 to 255 into its 8 bits, lowest bit first. A number outside that range, or one that is not whole, gives an empty list."

	var/datum/port/input/number_input
	var/datum/port/output/bits_output
	var/datum/port/output/triggered

/obj/item/circuit_component/binary_conversion/populate_ports()
	number_input = add_input_port("Number", PORT_TYPE_NUMBER, trigger = PROC_REF(convert_number))
	bits_output = add_output_port("Bits", PORT_TYPE_LIST)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/binary_conversion/proc/convert_number(datum/port/input/input)
	var/list/bits = list()
	var/number = number_input.value
	if(isnum(number) && number == round(number) && number >= 0 && number <= 255)
		for(var/bit = 1, bit <= CIRCUIT_BINARY_BITS, bit++)
			bits += ((number >> (bit - 1)) & 1)
	bits_output.set_output(bits)
	triggered.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/decimal_conversion
	name = "decimal conversion component"
	display_name = "Decimal Conversion"
	category = "Math"
	desc = "Reads up to 8 bits, lowest bit first, as a whole number. The list must hold at least one entry and every entry must be a number 0 or 1; anything else gives no number."

	var/datum/port/input/bits_input
	var/datum/port/output/number_output
	var/datum/port/output/triggered

/obj/item/circuit_component/decimal_conversion/populate_ports()
	bits_input = add_input_port("Bits", PORT_TYPE_LIST, trigger = PROC_REF(convert_bits))
	number_output = add_output_port("Number", PORT_TYPE_NUMBER)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/decimal_conversion/proc/convert_bits(datum/port/input/input)
	var/list/bits = bits_input.value
	var/number = null
	if(islist(bits) && length(bits) > 0)
		number = 0
		for(var/bit = 1, bit <= length(bits) && bit <= CIRCUIT_BINARY_BITS, bit++)
			var/entry = bits[bit]
			if(!isnum(entry) || (entry != 0 && entry != 1))
				number = null
				break
			if(entry == 1)
				number += (1 << (bit - 1))
	number_output.set_output(number)
	triggered.set_output(COMPONENT_SIGNAL)
