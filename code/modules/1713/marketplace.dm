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