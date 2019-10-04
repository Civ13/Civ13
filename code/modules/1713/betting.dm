/obj/structure/betting_box
	name = "betting box"
	desc = "A box storing bets on something."
	icon = 'icons/obj/storage.dmi'
	icon_state = "bet_box"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/odd = 2.0
	var/list/storedvalues = list()
	var/list/payvalues = list()
	var/bettingon = "none"

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
		clear_bets()
		for(var/obj/structure/betting_box/BB in range(5,src))
			if (result != "none" && result == bettingon)
				BB.clear_bets()
		return

/obj/structure/betting_box/proc/process_totals()
	if (!storedvalues.len)
		return
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