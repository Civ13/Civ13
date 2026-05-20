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
		var/body = "<html><head><title>Stock Market Companies</title></head>[common_browser_style]<b>STOCK MARKET</b><br><br>"
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
				to_chat(user, "<b>Sales Tax</b> set to [choiceinput1]%. <b>Business Tax</b> set to [choiceinput2]%.")
				return
			else
				to_chat(user, "<span class='warning'>You do not have the permissions to do that!</span>")
				return
		else if (choicefac == "Withdraw Taxes")
			if (map.custom_civs[user.civilization][4] == user)
				var/withdrew_something = FALSE
				if (map.custom_civs[user.civilization][5]>0)
					var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
					GC.amount = map.custom_civs[user.civilization][5]/4
					map.custom_civs[user.civilization][5] = 0
					to_chat(user, "You withdraw [GC.amount] gold coins in faction funds.")
					withdrew_something = TRUE
				if (map.custom_civs[user.civilization].len >= 11 && istype(map.custom_civs[user.civilization][11], /list))
					var/list/fiat_treasury = map.custom_civs[user.civilization][11]
					for (var/fid in fiat_treasury)
						var/amt = fiat_treasury[fid]
						if (amt > 0)
							new/obj/item/stack/money/fiat(loc, round(amt), fid)
							to_chat(user, "You withdraw [round(amt)] [fiat.currency_list[fid][1]] in faction funds.")
							fiat_treasury[fid] = 0
							withdrew_something = TRUE
				if (!withdrew_something)
					to_chat(user, "<span class='notice'>There is no money to withdraw.</span>")
			else
				to_chat(user, "<span class='warning'>You do not have the permissions to do that!</span>")
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
			to_chat(user, "<span class='notice'>You do not own any stocks!</span>")
			return
		poss_list += "Cancel"
		var/custom_company = WWinput(user, "Which company do you want to manage?", "Stock Market", "Cancel", poss_list)
		if (custom_company == "Cancel")
			return
		if (choice4 == "View Members")
			var/body = "<html><head><title>[custom_company]</title></head>[common_browser_style]<b>STOCK MARKET</b><br><br>"
			for(var/list/i in map.custom_company[custom_company])
				body += "<b>[i[1]]</b> owns [i[2]]%.</br>"
			body += {"<br>
				</body></html>
			"}

			usr << browse(body,"window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=250x450")
		else if (choice4 == "Distribute Profits")
			var/distributed_something = FALSE
			if (map.custom_company_value[custom_company]>0)
				var/tprof = map.custom_company_value[custom_company]
				map.custom_company_value[custom_company] = 0
				for (var/i in map.custom_company[custom_company])
					i[3]+=(i[2]/100)*tprof
				distributed_something = TRUE
			if (map.custom_company_fiat_value[custom_company])
				for(var/fid in map.custom_company_fiat_value[custom_company])
					var/tprof_fiat = map.custom_company_fiat_value[custom_company][fid]
					if (tprof_fiat > 0)
						map.custom_company_fiat_value[custom_company][fid] = 0
						for (var/list/j in map.custom_company[custom_company])
							if (j.len < 4 || !istype(j[4], /list))
								j.len = max(j.len, 4)
								j[4] = list()
							if (!j[4][fid])
								j[4][fid] = 0
							j[4][fid] += (j[2]/100)*tprof_fiat
						distributed_something = TRUE
			if (distributed_something)
				to_chat(user, "<span class='notice'>You distribute the profits of [custom_company].</span>")
				return
			else
				to_chat(user, "<span class='notice'>There are no profits to distribute from [custom_company].</span>")
				return
		else if (choice4 == "Withdraw Profits")
			for (var/list/j in map.custom_company[custom_company])
				if (j[1]==user)
					var/withdrew_something = FALSE
					if (j[3]>0)
						var/businesstax = 0
						var/price_without_tax = j[3]
						if (user.civilization != "none" && map.custom_civs[user.civilization])
							businesstax = (map.custom_civs[user.civilization][10]/100)*j[3]
							price_without_tax = j[3]-businesstax
							map.custom_civs[user.civilization][5] += businesstax
						var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
						GC.amount = round(price_without_tax/4)
						j[3] = 0
						to_chat(user, "<span class='notice'>You withdraw [GC.amount*4] silver coins in profit, paying [businesstax] silver coins ([map.custom_civs[user.civilization][10]]%) in Business Tax to your faction.</span>")
						withdrew_something = TRUE
					if (j.len >= 4 && istype(j[4], /list))
						var/list/fiat_profits = j[4]
						for(var/fid in fiat_profits)
							if (fiat_profits[fid] > 0)
								var/amt = fiat_profits[fid]
								var/businesstax = 0
								var/price_without_tax = amt
								if (user.civilization != "none" && map.custom_civs[user.civilization])
									businesstax = (map.custom_civs[user.civilization][10]/100)*amt
									price_without_tax = amt - businesstax
									// Credit fiat tax to the faction treasury (index 11).
									if (businesstax > 0)
										if (map.custom_civs[user.civilization].len < 11)
											map.custom_civs[user.civilization].len = 11
										if (!istype(map.custom_civs[user.civilization][11], /list))
											map.custom_civs[user.civilization][11] = list()
										if (!map.custom_civs[user.civilization][11][fid])
											map.custom_civs[user.civilization][11][fid] = 0
										map.custom_civs[user.civilization][11][fid] += businesstax
								new/obj/item/stack/money/fiat(loc, round(price_without_tax), fid)
								fiat_profits[fid] = 0
								to_chat(user, "<span class='notice'>You withdraw [round(price_without_tax)] [fiat.currency_list[fid][1]] in profit, paying [businesstax] [fiat.currency_list[fid][1]] in Business Tax to your faction.</span>")
								withdrew_something = TRUE
					if (!withdrew_something)
						to_chat(user, "<span class='notice'>You have no profits to withdraw.</span>")
		return

	else if (choice1 == "Buy Stock")
		if (isemptylist(map.sales_registry))
			to_chat(user, "<span class='notice'>There are no stocks for sale!</span>")
			return
		else
			var/list/tempbuylist = list("Cancel")
			var/list/choice_to_reg = list()
			var/found = FALSE
			var/sale_id = 1
			for(var/list/i in map.sales_registry)
				if (i[5])
					var/curr_name = "sc"
					if (i.len >= 6 && i[6] != "standard")
						curr_name = fiat.currency_list[i[6]][1]
					var/choice_str = "[i[2]]% of [i[1]], at [i[3]*10] [curr_name] #[sale_id++]"
					tempbuylist += choice_str
					choice_to_reg[choice_str] = i
					found = TRUE
			if (!found)
				to_chat(user, "<span class='notice'>There are no stocks for sale!</span>")
				return
			var/choice3 = WWinput(user, "Which stock do you want to buy?", "Stock Market", "Cancel", tempbuylist)
			if (choice3 == "Cancel")
				return
			else
				var/list/L = choice_to_reg[choice3]
				var/ord = L[1]
				var/ord_perc = L[2]
				var/ord_price = L[3]*10
				var/req_currency = L.len >= 6 ? L[6] : "standard"

				if (istype(user.get_inactive_hand(), /obj/item/stack/money))
					var/obj/item/stack/money/M = user.get_inactive_hand()
					var/valid_money = FALSE
					var/money_val = 0
					var/money_return = 0

					if (req_currency == "standard")
						if (!istype(M, /obj/item/stack/money/fiat))
							valid_money = TRUE
							money_val = M.amount * M.value
							money_return = money_val - ord_price
					else
						if (istype(M, /obj/item/stack/money/fiat))
							var/obj/item/stack/money/fiat/M_fiat = M
							if (M_fiat.fiat_id == req_currency)
								valid_money = TRUE
								money_val = M_fiat.amount
								money_return = money_val - ord_price

					for(var/list/reg_check in map.sales_registry)
						if (reg_check == L && L[5])
							if (valid_money)
								if (money_val >= ord_price)
									qdel(M)
									if (money_return > 0)
										if (req_currency == "standard")
											var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
											GC.amount = round(money_return/GC.value)
											if (GC.amount <= 0)
												qdel(GC)
										else
											new/obj/item/stack/money/fiat(loc, money_return, req_currency)

									if (ishuman(L[4]))
										var/mob/living/human/SELLER = L[4]
										SELLER.transfer_stock_proc(ord,ord_perc,user)
										for(var/list/j in map.custom_company[ord])
											if (j[1] == SELLER)
												if (j.len < 4)
													j.len = 4
													j[4] = list()
												if (req_currency == "standard")
													j[3] += ord_price
												else
													if (!j[4][req_currency])
														j[4][req_currency] = 0
													j[4][req_currency] += ord_price
												break

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
									var/req_name = req_currency == "standard" ? "sc" : fiat.currency_list[req_currency][1]
									to_chat(user, "<span class='notice'>You do not have enough money. You need [ord_price] [req_name] and you only have [money_val] [req_name].</span>")
									return
							else
								to_chat(user, "<span class='notice'>You are not holding the requested currency!</span>")
								return
				else
					to_chat(user, "<span class='notice'>You need to have money in your hands in order to buy stocks!</span>")
					return
	else if (choice1 == "Sell Stock")
		var/list/poss_list = list()
		for(var/cmp in map.custom_company_nr)
			if (find_company_member(user,cmp))
				poss_list += cmp
		if (isemptylist(poss_list))
			to_chat(user, "<span class='notice'>You do not own any stocks!</span>")
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
					var/saleprice = input(user, "At what price do you want to sell the [compchoice_amt]% of [choice2]?") as num|null
					if (saleprice <=0)
						return
					else
						var/list/currency_options = list("Standard Coins")
						for(var/fid in fiat.currency_list)
							currency_options += fiat.currency_list[fid][1]
						var/currency_choice = WWinput(user,"What currency do you want to be paid in?", "Stock Market", "Cancel", currency_options)
						if (currency_choice == "Cancel")
							return
						var/requested_currency = "standard"
						if (currency_choice != "Standard Coins")
							for(var/fid in fiat.currency_list)
								if (fiat.currency_list[fid][1] == currency_choice)
									requested_currency = fid
									break

						map.sales_registry += list(list(choice2,compchoice_amt,saleprice/10,user,1,requested_currency))
						to_chat(user, "<span class='notice'>You sucessfully put up [compchoice_amt]% of [choice2] at [saleprice] [currency_choice].</span>")
						return
