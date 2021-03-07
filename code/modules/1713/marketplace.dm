/obj/structure/stockmarket
	name = "stock market"
	desc = "Use this to buy, sell and check company shares. You can also manage your companies here."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = FALSE

/obj/structure/stockmarket/attack_hand(var/mob/living/human/user as mob)
	var/list/optlist = list("Check Companies","Buy Stock","Sell Stock","Manage Company")
	if (user.leader && user.civilization != "none")
		optlist += "Faction Treasury"
	optlist += "Cancel"
	var/choice1 = WWinput(user, "What do you want to do?", "Stock Market", "Check Companies", optlist)
	if (choice1 == "Cancel")
		return
	else if (choice1 == "Check Companies")
		var/list/tmplistc = sortTim(map.custom_company_value, /proc/cmp_numeric_dsc,TRUE)
		var/body = "<html><head><title>Stock Market Companies</title></head><b>STOCK MARKET</b><br><br>"
		for (var/relf in map.custom_company_nr)
			var/vm_owned = 0
			for(var/obj/structure/vending/sales/S in vending_machine_list)
				if (S.owner == relf)
					vm_owned++
			body += "<b>[relf]</b>: [tmplistc[relf]] silver coins. [vm_owned] vending points.</br>"
		body += {"<br>
			</body></html>
		"}

		usr << browse(body,"window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=250x450")
	else if (choice1 == "Faction Treasury")
		var/choicefac = WWinput(user, "What do you want to do?", "Faction Treasury", "Cancel", list("Set Taxes", "Withdraw Taxes","Cancel"))
		if (choicefac == "Cancel")
			return
		else if (choicefac == "Set Taxes")
			if (user.leader)
				var/choiceinput1 = input(user, "What do you want the Sales Tax to be? (0-30%)","Sales Tax",map.custom_civs[user.civilization][9]) as num
				if (choiceinput1 < 0)
					choiceinput1 = 0
				if (choiceinput1 > 30)
					choiceinput1 = 10
				var/choiceinput2 = input(user, "What do you want the Business Tax to be? (0-30%)","Business Tax",map.custom_civs[user.civilization][10]) as num
				if (choiceinput2 < 0)
					choiceinput2 = 0
				if (choiceinput2 > 30)
					choiceinput2 = 10
				map.custom_civs[user.civilization][9] = choiceinput1
				map.custom_civs[user.civilization][10] = choiceinput2
				user << "<b>Sales Tax</b> set to [choiceinput1]%. <b>Business Tax</b> set to [choiceinput2]%."
				return
			else
				user << "<span class='warning'>You do not have the permissions to do that!</span>"
				return
		else if (choicefac == "Withdraw Taxes")
			if (map.custom_civs[user.civilization][4] == user)
				if (map.custom_civs[user.civilization][5]>0)
					var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
					GC.amount = map.custom_civs[user.civilization][5]/4
					map.custom_civs[user.civilization][5]=0
					user << "You withdraw [GC.amount] gold coins in faction funds."
					return
				else
					user << "<span class='notice'>There is no money to withdraw.</span>"
					return
			else
				user << "<span class='warning'>You do not have the permissions to do that!</span>"
				return
	else if (choice1 == "Manage Company")
		var/choice4 = WWinput(user, "What do you want to do?", "Stock Market", "View Members", list("View Members", "Distribute Profits", "Withdraw Profits","Cancel"))
		if (choice4 == "Cancel")
			return
		var/list/poss_list = list()
		for(var/cmp in map.custom_company_nr)
			if (find_company_member(user,cmp))
				poss_list += cmp
		if (isemptylist(poss_list))
			user << "<span class='notice'>You do not own any stocks!</span>"
			return
		poss_list += "Cancel"
		var/custom_company = WWinput(user, "Which company do you want to manage?", "Stock Market", "Cancel", poss_list)
		if (custom_company == "Cancel")
			return
		if (choice4 == "View Members")
			var/body = "<html><head><title>[custom_company]</title></head><b>STOCK MARKET</b><br><br>"
			for(var/list/i in map.custom_company[custom_company])
				body += "<b>[i[1]]</b> owns [i[2]]%.</br>"
			body += {"<br>
				</body></html>
			"}

			usr << browse(body,"window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=250x450")
		else if (choice4 == "Distribute Profits")
			if (map.custom_company_value[custom_company]>0)
				var/tprof = map.custom_company_value[custom_company]
				map.custom_company_value[custom_company] = 0
				for (var/i in map.custom_company[custom_company])
					i[3]+=(i[2]/100)*tprof
				user << "<span class='notice'>You distribute the profits of [custom_company].</span>"
				return
			else
				user << "<span class='notice'>There are no profits to distribute from [custom_company].</span>"
				return
		else if (choice4 == "Withdraw Profits")
			for (var/j in map.custom_company[custom_company])
				if (j[1]==user && j[3]>0)
					var/businesstax = 0
					var/price_without_tax = j[3]
					if (user.civilization != "none" && map.custom_civs[user.civilization])
						businesstax = (map.custom_civs[user.civilization][10]/100)*j[3]
						price_without_tax = j[3]-businesstax
						map.custom_civs[user.civilization][5] += businesstax
					var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
					GC.amount = price_without_tax/4
					j[3] = 0
					user << "<span class='notice'>You withdraw [GC.amount*4] silver coins in profit, paying [businesstax] silver coins ([map.custom_civs[user.civilization][10]]%) in Business Tax to your faction.</span>"
		return

	else if (choice1 == "Buy Stock")
		if (isemptylist(map.sales_registry))
			user << "<span class='notice'>There are no stocks for sale!</span>"
			return
		else
			var/list/tempbuylist = list("Cancel")
			var/found = FALSE
			for(var/list/i in map.sales_registry)
				if (i[5])
					tempbuylist += "[i[2]]% of [i[1]], at [i[3]] sc"
					found = TRUE
			if (!found)
				user << "<span class='notice'>There are no stocks for sale!</span>"
				return
			var/choice3 = WWinput(user, "Which stock do you want to buy?", "Stock Market", "Cancel", tempbuylist)
			if (choice3 == "Cancel")
				return
			else
				var/ord_perc = splittext(choice3,"% of ")[1]
				var/ord = splittext(choice3,"% of ")[2]
				var/ord_price = splittext(ord,", at ")[2]
				ord = splittext(ord,", at ")[1]
				ord_price = replacetext(ord_price, " sc", "")
				ord_price = text2num(ord_price)/10
				ord_perc = text2num(ord_perc)
				if (istype(user.get_inactive_hand(), /obj/item/stack/money))
					var/obj/item/stack/money/M = user.get_inactive_hand()
					for(var/list/L in map.sales_registry)
						if (L[5] && L[1] == ord && text2num(L[2]) == ord_perc && text2num(L[3]) == ord_price)
							if (M.amount*M.value >= ord_price)
								var/tma = M.amount*M.value
								var/tmb = ord_price
								var/tmc = (tma - tmb)/4
								qdel(M)
								var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
								GC.amount = tmc
								if (GC.amount <= 0)
									qdel(GC)
								if (ishuman(L[4]))
									var/mob/living/human/SELLER = L[4]
									SELLER.transfer_stock_proc(ord,ord_perc,user)
									L[5] = 0
									map.sales_registry -= L
									for(var/list/LL in map.sales_registry)
										if (LL[1] == ord && LL[4]==SELLER)
											LL[5] = 0
											map.sales_registry -= LL
								else
									transfer_stock_nomob(ord,ord_perc,user)
									L[5] = 0
									map.sales_registry -= L
									for(var/list/LL in map.sales_registry)
										if (LL[1]==ord && LL[2]==ord_perc && LL[3]==ord_price && LL[4]==null)
											LL[5] = 0
											map.sales_registry -= LL
							else
								user << "<span class='notice'>You do not have enough money. You need [map.sales_registry[ord][3]] sc and you only have [M.amount*M.value] sc.</span>"
								return
				else
					user << "<span class='notice'>You need to have money in your hands in order to buy stocks!</span>"
					return
	else if (choice1 == "Sell Stock")
		var/list/poss_list = list()
		for(var/cmp in map.custom_company_nr)
			if (find_company_member(user,cmp))
				poss_list += cmp
		if (isemptylist(poss_list))
			user << "<span class='notice'>You do not own any stocks!</span>"
			return
		poss_list += "Cancel"
		var/choice2 = WWinput(user, "Which stock do you want to sell?", "Stock Market", "Cancel", poss_list)
		if (choice2 == "Cancel")
			return
		else
			for(var/list/i in map.custom_company[choice2])
				if (i[1] == user)
					var/compchoice_amt = input(user, "You own [i[2]]% of [choice2]. How much do you want to put up for sale? (1 to [i[2]])") as num|null
					compchoice_amt = round(compchoice_amt)
					if (compchoice_amt > i[2])
						compchoice_amt = i[2]
					else if (compchoice_amt <= 0)
						return
					var/saleprice = input(user, "At what price do you want to sell the [compchoice_amt]% of [choice2]? In silver coins.") as num|null
					if (saleprice <=0)
						return
					else
						map.sales_registry += list(list(choice2,compchoice_amt,saleprice/10,user,1))
						user << "<span class='notice'>You sucessfully put up [compchoice_amt]% of [choice2] at [saleprice].</span>"
						return
