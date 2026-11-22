// A punch card holds 10 rows of 80 bits, read as 25 32-bit words, most
// significant bit first. The word count is carried explicitly so the last card
// of a program can be short: the reader emits exactly that many words and never
// a padding word the CPU would execute.
//
// Cards chain by pointing at the next card. Click a held card on another to put
// it after it; the assembler links the cards it makes. The chain is bounded so a
// reader can never be made to walk an unbounded list.

/obj/item/weapon/punch_card
	name = "punch card"
	gender = NEUTER
	desc = "A card of ten rows of eighty punched positions. It holds twenty five computer words."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper"
	w_class = ITEM_SIZE_TINY
	var/list/words = list()
	var/obj/item/weapon/punch_card/next_card

// Cards are made by the assembler or by a player; nothing outside this file
// writes the word list directly.
/obj/item/weapon/punch_card/proc/set_words(list/new_words)
	words = list()
	if(!islist(new_words))
		return FALSE
	for(var/index in 1 to min(length(new_words), PUNCH_CARD_WORDS))
		words += list(wiremod_u32(new_words[index]))
	return TRUE

/obj/item/weapon/punch_card/proc/word_count()
	return length(words)

/obj/item/weapon/punch_card/proc/get_word(index)
	if(index < 1 || index > length(words))
		return null
	return words[index]

// The cards from this one onward, or as many as the bound allows.
/obj/item/weapon/punch_card/proc/chain()
	var/list/result = list()
	var/obj/item/weapon/punch_card/current = src
	while(current && length(result) < PUNCH_CARD_MAX_CHAIN)
		result += current
		if(current.next_card == current)
			break
		current = current.next_card
	return result

/obj/item/weapon/punch_card/proc/chain_length()
	return length(chain())

// Puts another card at the end of this chain. Returns FALSE when the chain is
// full or the other card belongs to it already.
/obj/item/weapon/punch_card/proc/link_card(obj/item/weapon/punch_card/other)
	if(!istype(other) || other == src)
		return FALSE
	var/list/current_chain = chain()
	if(length(current_chain) >= PUNCH_CARD_MAX_CHAIN || (other in current_chain))
		return FALSE
	var/obj/item/weapon/punch_card/last = current_chain[length(current_chain)]
	last.next_card = other
	return TRUE

/obj/item/weapon/punch_card/attackby(obj/item/item, mob/user)
	if(istype(item, /obj/item/weapon/punch_card))
		if(link_card(item))
			to_chat(user, "<span class='notice'>You link [item] to the end of [src].</span>")
			user.drop_from_inventory(item)
		else
			to_chat(user, "<span class='warning'>[src] cannot take another card.</span>")
		return TRUE
	return ..()

/obj/item/weapon/punch_card/examine(mob/user)
	. = ..()
	to_chat(user, "It holds [word_count()] word[word_count() == 1 ? "" : "s"] and [chain_length() - 1] more card[chain_length() == 2 ? "" : "s"] behind it.")
