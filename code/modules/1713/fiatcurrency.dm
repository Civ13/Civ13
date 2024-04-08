/datum/currency_list //A list of all the custom fiat currencies in the world, structured as a list of lists.
	var/list/currency_list = list()

/* an example of what the list looks like
/datum/currency_list
	var/list/currency_list = list(
		"civ13d" = list("Civ13 Dollar", "Civ13 Dollar", "The official currency of Civilization 13", "5dollar", 1),
		"dciv13" = list("Dollar Civ13", "Dollar Civ13", "The unofficial currency of 13 Civilizations", "ruble_alt", 0)
	)
*/

var/global/datum/currency_list/fiat = new()

/obj/item/stack/money/fiat
	name = "fiat money"
	desc = "Fiat money."
	singular_name = "money"
	amount = 1
	value = 0.03
	var/fiat_id
	flags = CONDUCT

/obj/item/stack/money/fiat/New(loc, _amount, _fiat_id)
	if(_fiat_id)
		fiat_id = _fiat_id
	if (_amount)
		amount = _amount
	if(fiat_id)
		name = fiat.currency_list[fiat_id][1]
		singular_name = fiat.currency_list[fiat_id][2]
		desc = "[fiat.currency_list[fiat_id][3]]. The ID number of this currency is [fiat_id]."
		icon_state = fiat.currency_list[fiat_id][4]
	else
		name = "This is broken, contact an admin."
		singular_name = "This is broken, contact an admin."
		desc = "This is broken, contact an admin."
		message_admins("Fiat currency was created without a fiat_id var!")

/obj/item/stack/money/fiat/attackby(obj/item/stack/money/fiat/W as obj, mob/user as mob)
	if (istype(W, type) && W.fiat_id == src.fiat_id)
		var/obj/item/stack/S = W
		merge(S)
		S.update_icon()
		S.update_strings()
		src.update_icon()
		src.update_strings()
		spawn(0) //give the stacks a chance to delete themselves if necessary
		if (S && usr.using_object == S)
			S.interact(usr)
		if (src && usr.using_object == src)
			interact(usr)
	else
		return

/obj/item/stack/money/fiat/split(var/_amount)
	if (!amount)
		return null
	if (_amount)
		var/obj/item/stack/money/fiat/S = new(src.loc, _amount, src.fiat_id)
		S.color = color
		if (prob(_amount/amount * 100))
			transfer_fingerprints_to(S)
			if (blood_DNA)
				S.blood_DNA |= blood_DNA
		amount -= _amount
		if (amount <= 0)
			qdel(src)
		return S
	else
		return FALSE

/obj/structure/money_printer
	name = "money printer"
	desc = "This prints money. It currently contains 0 cloth."
	icon = 'icons/obj/structures.dmi'
	icon_state = "printingpress0"
	anchored = TRUE
	density = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/fiat_id
	var/cloth

/obj/structure/money_printer/proc/print_money(user)
	var/nm
	var/num = input(user, "How much money do you want to print?","Printing", nm) as num
	if (num == 0)
		return
	else
		for(var/i in fiat.currency_list)
			var/cloth_remaining = (cloth - num*0.01)
			if (fiat_id && cloth_remaining >= 0)
				cloth = cloth_remaining
				desc = "This prints money. It currently contains [cloth] cloth."
				new/obj/item/stack/money/fiat(loc, num, fiat_id)
				playsound(loc, 'sound/machines/vending_drop.ogg', 100, TRUE)
				return
			else if (cloth_remaining < 0)
				to_chat(user, "You do not have enough cloth in the machine to produce that much currency! The maximum you can currently produce is [cloth*100]")
				return
			else if (!fiat_id)
				to_chat(user, "That currency does not exist.")
				return

/obj/structure/money_printer/proc/display_ui(user)
	var/choice = WWinput(user, "Pick an option", "Money Printer", "Cancel", list("Cancel", "Print money"))
	if (choice == "Cancel")
		return
	else if (choice == "Print money")
		print_money(user)
		return

/obj/structure/money_printer/attack_hand(var/mob/living/human/user as mob)
	if(fiat_id)
		display_ui(user)
	else
		var/cd
		var/currency_code = input(user, "Input the ID for your currency. You can use any text.","Currency Creation", cd) as text
		var/currency_exists = 0
		var/currency_revival = 0
		for(var/codes in fiat.currency_list)
			if(codes == currency_code)
				if (fiat.currency_list[codes][5] == 1)
					to_chat(user, "That currency already exists.")
					currency_exists = 1
					break
				else
					currency_revival = 1
					break

		if(currency_exists == 0)
			fiat_id = currency_code
			if (currency_revival == 1)
				fiat.currency_list[fiat_id][5] = 1
				name = "[fiat.currency_list[fiat_id][1]] printer"
				to_chat(user, "You rebuild the printer for the [fiat.currency_list[fiat_id][1]].")
				return
			else
				var/list/currency_icons = list(
					list("Spanish Real", "dollar"),
					list("Spanish Dollar", "5dollar"),
					list("Escudo", "20dollar"),
					list("Doubloon", "50dollar"),
					list("Soviet Ruble", "ruble"),
					list("Ruble (alt)", "ruble_alt"),
				)

				var/currencyname
				var/currency_name = input(user, "Please provide the name of your currency.","Currency Creation", currencyname) as text

				var/currencysingular
				var/currency_singular = input(user, "Please provide the singular form of your currency's name (e.g. 'dollar', 'pound', 'peso', or 'ruble').","Currency Creation", currencysingular) as text

				var/currencydesc
				var/currency_desc = input(user, "Please provide your currency's description (without a period at the end).","Currency Creation", currencydesc) as text

				var/list/display = list()
				for (var/list/i in currency_icons)
					display += "[i[1]]"
				var/currency_icon = WWinput(user, "What should our currency look like?", "Currency Creation", "U.S. Dollar", display)
				for(var/list/i2 in currency_icons)
					if (i2[1]== currency_icon)
						currency_icon = i2

				var/list/currency_to_add = list(currency_name, currency_singular, currency_desc, currency_icon[2], 1)
				fiat.currency_list[fiat_id] += currency_to_add
				name = "[fiat.currency_list[fiat_id][1]] printer"
				return
		return

/obj/structure/money_printer/attackby(var/obj/item/stack/I as obj, var/mob/living/human/user as mob)
	if (I.amount && istype(I, /obj/item/stack/material/cloth))
		cloth += I.amount
		playsound(user, 'sound/machines/button.ogg', 100, TRUE)
		to_chat(user, "You insert [I.amount] cloth into the machine. It now contains [cloth] cloth.")
		qdel(I)
		desc = "This prints money. It currently contains [cloth] cloth."
		return
	else
		to_chat(user, "Banknotes are made of cloth, not [I.name].")
		return

/obj/structure/money_printer/Destroy()
	if(fiat_id)
		fiat.currency_list[fiat_id][5] = 0
	qdel(src)
	return ..()