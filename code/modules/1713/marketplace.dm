/obj/structure/marketplace
	name = "global exchange"
	desc = "Use this to sell and buy products on the global market."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook2"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = FALSE

/obj/structure/marketplace/attack_hand(var/mob/living/carbon/human/user as mob)
	var/choice =  WWinput(user, "Do you want to buy something, or change a order you placed in the market?", "Global Exchange", "Cancel", list("Buy", "Change Orders", "Withdraw Money","Cancel"))
	if (choice == "Cancel")
		return
	else if (choice == "Withdraw Money")
		var/done = FALSE
		for (var/mob/living/carbon/human/H in map.marketplaceaccounts)
			if (H == user)
				done = TRUE
				var/accmoney = map.marketplaceaccounts[H]
				if (accmoney <= 0)
					user << "Your account is empty!"
					map.marketplaceaccounts[H] = 0
					return
				var/choicew =  WWinput(user, "You have [accmoney*10] silver coins in your account.", "Global Exchange", "Cancel", list("Withdraw","Cancel"))
				if (choicew == "Cancel")
					return
				else if (choicew == "Withdraw" && accmoney > 0)
					var/obj/item/stack/money/silvercoin/SC = new /obj/item/stack/money/silvercoin(get_turf(src))
					SC.amount = accmoney*10
					accmoney = 0
					map.marketplaceaccounts[H] = 0
					return
				else
					return

		if (!done)
			user << "You haven't sold anything yet! Your account is empty."
			return
	else if (choice == "Buy")
		var/list/currlist = list()
		for (var/i = 1, i <= map.globalmarketplacecount, i++)
			if (map.globalmarketplace[i][6] == 0)
				currlist += list(list(i,"[map.globalmarketplace[i][3]] [map.globalmarketplace[i][2]], for [(map.globalmarketplace[i][4]*10)*1.1] silver."))
		if (isemptylist(currlist))
			user << "There are no orders on the market!"
			return
		var/list/choicelist = list()
		for (var/k = 1, k <= currlist.len, k++)
			choicelist += "[currlist[k][2]]"
		choicelist += "Cancel"
		var/choice2 =  WWinput(user, "Choose a order:", "Global Exchange", "Cancel", choicelist)
		if (choice2 == "Cancel")
			return
		else
			for (var/k = 1, k <= currlist.len, k++)
				if (choice2 == "[currlist[k][2]]")
					var/cost = (map.globalmarketplace[currlist[k][1]][4]*1.1)
					if (!istype(user.l_hand, /obj/item/stack/money) && !istype(user.r_hand, /obj/item/stack/money))
						user << "You need to have money in one of your hands!"
						return
					else
						var/obj/item/stack/money/mstack = null
						if (istype(user.l_hand, /obj/item/stack/money))
							mstack = user.l_hand
						else
							mstack = user.r_hand
						if (mstack.value*mstack.amount >= cost)
							mstack.amount -= (cost/mstack.value)
							if (mstack.amount<= 0)
								qdel(mstack)
							var/obj/BO = map.globalmarketplace[currlist[k][1]][2]
							if (BO)
								BO.forceMove(get_turf(src))
							map.globalmarketplace[currlist[k][1]][6] = 1
							user << "You fulfill the order."
							var/mob/living/carbon/human/seller = map.globalmarketplace[currlist[k][1]][1]
							map.marketplaceaccounts[seller] += (cost/1.1)
							return
						else
							user << "Not enough money!"
							return
	else if (choice == "Buy Order")
		var/buychoice = WWinput(user, "Do you want to check current buy orders, or add a new one?", "Check", list("Check","Add New"))
		if (buychoice == "Add New")
			return
		else if (buychoice == "Check")
			return
		return
	else if (choice == "Change Orders")
		var/list/currlist = list()
		for (var/i = 1, i <= map.globalmarketplace.len, i++)
			if (map.globalmarketplace[i][1] == user)
				currlist += list(list(i,"[map.globalmarketplace[i][3]] of [map.globalmarketplace[i][2]], for [map.globalmarketplace[i][4]*10] silver."))
		if (isemptylist(currlist))
			user << "You have no orders on the market!"
			return
		var/list/choicelist = list()
		for (var/k = 1, k <= currlist.len, k++)
			choicelist += "[currlist[k][2]]"
		choicelist += "Cancel"
		var/choice2 =  WWinput(user, "Choose a order:", "Global Exchange", "Cancel", choicelist)
		if (choice2 == "Cancel")
			return
		else
			for (var/k = 1, k <= currlist.len, k++)
				if (choice2 == "[currlist[k][2]]")
					var/choice3 =  WWinput(user, "What do you want to change?", "Global Exchange", "Cancel", list("Change Price", "Cancel Order", "Cancel"))
					if (choice3 == "Cancel")
						return
					else if (choice3 == "Cancel Order")
						var/obj/BO = map.globalmarketplace[k][2]
						BO.forceMove(get_turf(src))
						map.globalmarketplace[k][6] = 1
						user << "You cancel your sell order and get your items back."
						return
					else if (choice3 == "Change Price")
						var/newprice = input(user, "What shall the new price be?") as num|null
						if (!isnum(newprice))
							return
						if (newprice <= 0)
							return
						map.globalmarketplace[k][4] = newprice/10
						user << "You update the listing's price."
						return
	else
		return
/obj/structure/marketplace/attackby(var/obj/item/W, var/mob/user)
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/ST = W
		if (ST.amount <= 0)
			return
		else
			var/price = input(user, "What price do you want to place the [ST.amount] [ST] for sale? (Silver coins). A 10% fee will be added.") as num|null
			if (!isnum(price))
				return
			if (price <= 0)
				return
			else
				//owner, object, amount, price, sale/buy, fulfilled
				map.globalmarketplacecount++
				map.globalmarketplace += list(list(user,ST,ST.amount,price/10,"sale",0))
				user.drop_from_inventory(ST)
				ST.forceMove(locate(0,0,0))
				user << "You place \the [ST] for sale."
				return

/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////
/obj/structure/stockmarket
	name = "stock market"
	desc = "Use this to buy, sell and check company shares. You can also manage your companies here."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = FALSE

/obj/structure/stockmarket/attack_hand(var/mob/living/carbon/human/user as mob)
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
			body += "<b>[relf]</b>: [tmplistc[relf]*10] silver coins. [vm_owned] vending points.</br>"
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
					GC.amount = map.custom_civs[user.civilization][5]*2.5
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
					GC.amount = price_without_tax*2.5
					j[3] = 0
					user << "<span class='notice'>You withdraw [GC.amount*4] silver coins in profit, paying [businesstax*10] silver coins ([map.custom_civs[user.civilization][10]]%) in Business Tax to your faction.</span>"
		return

	else if (choice1 == "Buy Stock")
		if (isemptylist(map.sales_registry))
			user << "<span class='notice'>There are no stocks for sale!</span>"
			return
		else
			var/list/tempbuylist = list("Cancel")
			for(var/list/i in map.sales_registry)
				tempbuylist += "[i[2]]% of [i[1]], at [i[3]*10] sc"
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
						if (L[1] == ord && text2num(L[2]) == ord_perc && text2num(L[3]) == ord_price)
							if (M.amount*M.value >= ord_price)
								var/tma = M.amount*M.value
								var/tmb = ord_price
								var/tmc = (tma - tmb)/0.4
								qdel(M)
								var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
								GC.amount = tmc
								if (GC.amount <= 0)
									qdel(GC)
								if (L[4])
									var/mob/living/carbon/human/SELLER = L[4]
									SELLER.transfer_stock_proc(ord,ord_perc,user)
									map.sales_registry -= L
									for(var/list/LL in map.sales_registry)
										if (LL[1] == ord && LL[4]==SELLER)
											map.sales_registry -= LL
								else
									transfer_stock_nomob(ord,ord_perc,user)
									map.sales_registry -= L
									for(var/list/LL in map.sales_registry)
										if (LL[1]==ord && LL[2]==ord_perc && LL[3]==ord_price && LL[4]==null)
											map.sales_registry -= LL
							else
								user << "<span class='notice'>You do not have enough money. You need [map.sales_registry[ord][3]*10] sc and you only have [M.amount*M.value*10] sc.</span>"
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
						map.sales_registry += list(list(choice2,compchoice_amt,saleprice/10,user))
						user << "<span class='notice'>You sucessfully put up [compchoice_amt]% of [choice2] at [saleprice].</span>"
						return
