/obj/item/circuit_component/printer
	name = "printer component"
	display_name = "Printer"
	category = "Action"
	desc = "Keeps the text it is given and prints it onto one sheet of paper when a signal reaches Eject. The sheet appears at the shell or in the hand of whoever holds it. Printing again needs new text. A loose circuit prints nothing."

	var/datum/port/input/string_input
	var/datum/port/input/eject
	var/pending_text
	var/last_print = 0

/obj/item/circuit_component/printer/populate_ports()
	string_input = add_input_port("String", PORT_TYPE_STRING, trigger = PROC_REF(store_text))
	eject = add_input_port("Eject", PORT_TYPE_SIGNAL, trigger = PROC_REF(print_paper))

/obj/item/circuit_component/printer/proc/store_text(datum/port/input/input)
	pending_text = wiremod_safe_text(string_input.value)

/obj/item/circuit_component/printer/proc/print_paper(datum/port/input/input)
	if(isnull(pending_text) || !length(pending_text))
		return
	var/atom/anchor = wiremod_shell(parent)
	if(!anchor)
		return
	if(world.time < last_print)
		return
	last_print = world.time + CIRCUIT_SOUND_COOLDOWN
	var/obj/item/weapon/paper/sheet = new(get_turf(anchor))
	// The sheet shows its info as markup, so the text is escaped and its line
	// breaks become the sheet's own breaks.
	sheet.info = replacetext(html_encode(pending_text), "\n", "<BR>")
	sheet.update_icon()
	pending_text = null
	if(ismob(anchor.loc))
		var/mob/holder = anchor.loc
		holder.put_in_hands(sheet)
	playsound(get_turf(anchor), 'sound/machines/printer.ogg', 40, TRUE)
