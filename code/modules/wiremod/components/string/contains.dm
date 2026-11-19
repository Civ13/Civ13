/obj/item/circuit_component/string_contains
	name = "string contains component"
	display_name = "String Contains"
	category = "String"
	desc = "Gives true if String contains Search, and false if it does not or if either is not set. Capital and small letters count as the same."

	var/datum/port/input/haystack
	var/datum/port/input/needle
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/string_contains/populate_ports()
	haystack = add_input_port("String", PORT_TYPE_STRING, trigger = PROC_REF(check))
	needle = add_input_port("Search", PORT_TYPE_STRING, trigger = PROC_REF(check))
	result = add_output_port("Contains", PORT_TYPE_BOOLEAN)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/string_contains/proc/check(datum/port/input/input)
	result.set_output(!isnull(haystack.value) && !isnull(needle.value) && findtext(haystack.value, needle.value))
	triggered.set_output(COMPONENT_SIGNAL)
