// The punch card reader plays the words of the cards loaded into it, one word
// per Trigger, most significant bit first. It never emits a padding word: a
// short last card simply contributes its own word count.
//
// Finished is a level, not a pulse. It rises on the first Trigger after the last
// real word and stays high until Restart or Eject, so a player can switch the
// CPU's Data in source over to memory without building a latch of their own.

/obj/item/circuit_component/punch_card_reader
	name = "punch card reader component"
	display_name = "Punch Card Reader"
	category = "Computer"
	desc = "Reads the punch cards loaded into it, one word per Trigger, in order. Finished rises after the last word and stays high until Restart or Eject."
	var/datum/port/input/trigger_input
	var/datum/port/input/eject_input
	var/datum/port/input/restart_input
	var/datum/port/output/data_output
	var/datum/port/output/word_read_output
	var/datum/port/output/finished_output
	var/list/obj/item/weapon/punch_card/cards = list()
	var/list/words = list()
	var/position = 0
	var/finished = FALSE
	var/signal_serial = 0

/obj/item/circuit_component/punch_card_reader/populate_ports()
	trigger_input = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(read_word))
	eject_input = add_input_port("Eject", PORT_TYPE_SIGNAL, trigger = PROC_REF(eject_cards))
	restart_input = add_input_port("Restart", PORT_TYPE_SIGNAL, trigger = PROC_REF(restart_cards))
	data_output = add_output_port("Data out", PORT_TYPE_STRING)
	word_read_output = add_output_port("Word read", PORT_TYPE_SIGNAL)
	finished_output = add_output_port("Finished", PORT_TYPE_BOOLEAN)

// A clicked card, or the whole chain behind it, goes in at the end.
/obj/item/circuit_component/punch_card_reader/proc/insert_card(obj/item/weapon/punch_card/card, mob/user)
	if(!istype(card))
		return FALSE
	var/list/incoming = card.chain()
	if(length(cards) + length(incoming) > PUNCH_CARD_MAX_CHAIN)
		return FALSE
	for(var/obj/item/weapon/punch_card/entry as anything in incoming)
		cards += entry
		for(var/word in entry.words)
			words += list(word)
	if(user)
		to_chat(user, "<span class='notice'>You feed [card] into [src].</span>")
	return TRUE

/obj/item/circuit_component/punch_card_reader/proc/read_word(datum/port/input/input)
	if(finished)
		return
	if(position >= length(words))
		set_finished()
		return
	data_output.set_output(wiremod_word_to_binary(words[position + 1], 32))
	position++
	signal_serial = signal_serial % 100000 + 1
	word_read_output.set_output(signal_serial)

/obj/item/circuit_component/punch_card_reader/proc/set_finished()
	finished = TRUE
	finished_output.set_output(TRUE)

/obj/item/circuit_component/punch_card_reader/proc/restart_cards(datum/port/input/input)
	position = 0
	finished = FALSE
	data_output.set_output("")
	finished_output.set_output(FALSE)

/obj/item/circuit_component/punch_card_reader/proc/eject_cards(datum/port/input/input)
	var/obj/item/circuit_shell/shell = wiremod_circuit_shell(parent)
	var/turf/destination = shell ? get_turf(shell) : get_turf(src)
	for(var/obj/item/weapon/punch_card/card as anything in cards)
		card.next_card = null
		card.forceMove(destination)
	cards.Cut()
	words.Cut()
	position = 0
	finished = FALSE
	finished_output.set_output(FALSE)

/obj/item/circuit_component/punch_card_reader/examine(mob/user)
	. = ..()
	to_chat(user, "It holds [length(cards)] card[length(cards) == 1 ? "" : "s"] and [length(words)] unread word[length(words) == 1 ? "" : "s"].")
