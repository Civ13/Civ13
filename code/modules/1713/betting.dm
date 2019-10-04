/obj/structure/betting_box
	name = "betting box"
	desc = "A box storing bets on something."
	icon = 'icons/obj/storage.dmi'
	icon_state = "bet_box"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/odd = 2.0 //not used yet
	var/list/storedvalues = list()
	var/list/payvalues = list()
	var/bettingon = "none"
	var/lastodd = 2.0
	var/moneyname = "rubles"
	var/match_running = FALSE
/obj/structure/betting_box/red
	name = "red betting box"
	icon_state = "bet_box_red"
	desc = "A box storing bets on the red."
	bettingon = "red"

/obj/structure/betting_box/blue
	name = "blue betting box"
	icon_state = "bet_box_blue"
	desc = "A box storing bets on the blue."
	bettingon = "blue"

/obj/structure/betting_box/examine(mob/user)
	..()
	user << "<b>There is a total of [process_totals()] [moneyname] inside.</b>"

/obj/structure/betting_box/proc/clear_bets()
	odd = 2.0
	storedvalues = list()
	return

/obj/structure/betting_box/proc/process_results(var/result = "none")
	if (result != "none" && result == bettingon)
		var/tmptotal = process_totals()
		var/totalreceived = transfer(result)
		for (var/i in storedvalues)
			var/pctg = i[2]/tmptotal
			i[2] += totalreceived*pctg
		payvalues = storedvalues
		lastodd = (totalreceived/tmptotal)+1
		clear_bets()
		for(var/obj/structure/betting_box/BB in range(5,src))
			if (result != "none" && result == bettingon)
				BB.clear_bets()
		return

/obj/structure/betting_box/proc/process_totals()
	if (!storedvalues.len)
		return 0
	var/tmptotal = 0
	for (var/i in storedvalues)
		tmptotal += i[2]
	return tmptotal

/obj/structure/betting_box/proc/transfer(var/result = "none")
	var/tmptotal_transfer = 0
	for(var/obj/structure/betting_box/BB in range(5,src))
		if (result != "none" && result == bettingon)
			tmptotal_transfer = BB.process_totals()
	return tmptotal_transfer

/obj/structure/betting_box/attack_hand(var/mob/living/carbon/human/H)
	if (!ishuman(H))
		return

/obj/structure/betting_box/attackby(var/obj/item/I,var/mob/living/carbon/human/H)
	if (!istype(I, /obj/item/stack/money))
		return
	else if (match_running)
		return
	else
		var/obj/item/stack/money/M = I
		var/done = FALSE
		for(var/i in storedvalues)
			if (i[1] == H)
				i[2] += M.amount*M.value
				qdel(I)
				done = TRUE
				return
		if (!done)
			var/list/tlist = list(H, M.amount*M.value)
			storedvalues += list(tlist)
			qdel(I)
			return
	..()