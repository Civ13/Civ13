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

	var/list/sale_registry = list()

/obj/structure/stockmarket/attack_hand(var/mob/living/carbon/human/user as mob)
	var/choice1 = WWinput(user, "What do you want to do?", "Stock Market", "Check Companies", list("Check Companies","Buy Stock","Sell Stock","Cancel"))
	if (choice1 == "Cancel")
		return
	else if (choice1 == "Check Companies")
		var/list/tmplistc = sortTim(map.custom_company_value, /proc/cmp_numeric_dsc,TRUE)
		var/body = "<html><head><title>Stock Market Companies</title></head><b>STOCK MARKET</b><br><br>"
		for (var/relf in map.custom_company_nr)
			body += "<b>[relf]</b>: [tmplistc[relf]*10] silver coins</br>"
		body += {"<br>
			</body></html>
		"}

		usr << browse(body,"window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=250x450")
	else if (choice1 == "Buy Stock")
		if (isemptylist(sale_registry))
			user << "<span class='notice'>There are no stocks for sale!</span>"
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
					var/saleprice = input(user, "At what price do you want to sell the [i[2]]% of [choice2]?") as num|null
					if (saleprice <=0)
						return
					else
						sale_registry += list(list(choice2,saleprice,user))
						user << "<span class='notice'>You sucessfully put up [i[2]]% of [choice2] at [saleprice].</span>"
						return
