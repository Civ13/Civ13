/obj/structure/supplybook
	name = "supply orders book"
	desc = "Use this to request supplies to be delivered to the colony. Only merchants have access to it and only the governor can order ammunition."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook"
	var/money = 0
	var/marketval = 0
	density = TRUE
	anchored = TRUE
	var/factionarea = "SupplyRN"
	var/import_tax_rate = 0
	var/faction = "civilian"
	var/faction_treasury = "TreasuryRN"
	not_movable = TRUE
	not_disassemblable = TRUE
	var/list/items_for_sale = list( //type (governor/merchant/all), name, path, price
		list("merchant","wood crate", /obj/structure/closet/crate/wood,120),
		list("merchant","iron crate", /obj/structure/closet/crate/iron,330),
		list("merchant","glass crate", /obj/structure/closet/crate/glass,330),
		list("merchant","stone crate", /obj/structure/closet/crate/stone,130),
		list("merchant","vegetables crate", /obj/structure/closet/crate/rations/vegetables,60),
		list("merchant","fruits crate", /obj/structure/closet/crate/rations/fruits,66),
		list("merchant","biscuits crate", /obj/structure/closet/crate/rations/biscuits,50),
		list("merchant","beer crate", /obj/structure/closet/crate/rations/beer,60),
		list("merchant","ale crate", /obj/structure/closet/crate/rations/ale,70),

		list("merchant","cow", /mob/living/simple_animal/cattle/cow,160),
		list("merchant","bull", /mob/living/simple_animal/cattle/bull,150),
		list("merchant","sheep ram", /mob/living/simple_animal/sheep,80),
		list("merchant","sheep ewe", /mob/living/simple_animal/sheep/female,90),
		list("merchant","pig boar", /mob/living/simple_animal/pig_boar,100),
		list("merchant","pig gilt", /mob/living/simple_animal/pig_gilt,110),
		list("merchant","hen", /mob/living/simple_animal/chicken,50),
		list("merchant","rooster", /mob/living/simple_animal/rooster,40),
		list("merchant","horse", /mob/living/simple_animal/horse,200),
		list("merchant","brick crate", /obj/structure/closet/crate/brick,140),
		list("merchant","medical supplies", /obj/item/weapon/storage/firstaid/adv,150),

		list("governor","gunpowder barrel", /obj/item/weapon/reagent_containers/glass/barrel/gunpowder,230),
		list("governor","musket ammo crate (25)", /obj/structure/closet/crate/musketball,100),
		list("governor","pistol ammo crate (25)", /obj/structure/closet/crate/musketball_pistol,60),
		list("governor","blunderbuss ammo crate (15)", /obj/structure/closet/crate/blunderbuss_ammo,60),
		list("governor","grenade crate (10)", /obj/structure/closet/crate/grenades,110),
		list("governor","cannonball crate (10)", /obj/structure/closet/crate/cannonball,175),
		list("governor","pistol crate (5)", /obj/structure/closet/crate/pistols,385),
		list("governor","musket crate (5)", /obj/structure/closet/crate/muskets,550),
		list("governor","musketoon crate (5)", /obj/structure/closet/crate/musketoons,440),
		list("governor","blunderbuss crate (5)", /obj/structure/closet/crate/blunderbusses,495),
	)

/obj/structure/supplybook/New()
	src.import_tax_rate = global.global_import_tax
	return ..()

/obj/structure/exportbook
	name = "exporting book"
	desc = "Use this to export colony products and exchange money. Only merchants and governors have access to it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook2"
	var/money = 0
	var/marketval = 0
	var/moneyin = 0
	density = TRUE
	anchored = TRUE
	var/export_tax_rate = 0
	var/faction = "civilian"
	var/faction_treasury = "TreasuryRN"
	var/done = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
/obj/structure/exportbook/New()
	src.export_tax_rate = global.global_export_tax
	return ..()

/obj/structure/supplybook/craftable
	faction_treasury = "craftable"
	factionarea = "craftable"
	icon = 'icons/misc/support.dmi'
	icon_state = "supplybook"
	not_movable = FALSE
	not_disassemblable = TRUE
/obj/structure/supplybook/attack_hand(var/mob/living/human/user as mob)
	if (user.original_job_title != "Gobernador" && user.original_job_title != "Governador" && user.original_job_title != "Governeur" && user.original_job_title != "Governor" && user.original_job_title != "British Governor" && user.original_job_title != "British Merchant"  && user.original_job_title != "Merchant" && user.original_job_title != "Trader" && user.original_job_title != "Mercador" && user.original_job_title != "Comerciante" && user.original_job_title != "Marchand" && user.original_job_title != "Mayor" && user.original_job_title != "Kaufmann" && user.original_job_title != "Freiherr" && user.original_job_title != "Pirate Quartermaster")
		user << "Only the merchants have access to the international shipping companies. Negotiate with one."
		return

	var/list/final_list = list()
	var/money_string = "reales"
	var/age_modifier = 1 //since dollars are worth 1/4 reales
	if (map.ordinal_age >= 4)
		money_string = "dollars"
		age_modifier = 4
	var/list/display = list ()//The products to be displayed, includes name of crate and price
	if (user.original_job_title != "Gobernador" && user.original_job_title != "Governador" && user.original_job_title != "Governeur" && user.original_job_title != "Governor" && user.original_job_title != "British Governor" && user.original_job_title != "Mayor" && user.original_job_title != "Freiherr")
		New()	//Updates the taxes
		for (var/list/i in items_for_sale)
			if (i[1] == "merchant" || i[1] == "both")
				display += "[i[2]] - [(i[4]/age_modifier)+((i[4]/age_modifier)*(import_tax_rate/100))] [money_string]"
				display += "Cancel"

	else
		import_tax_rate = input(user, "Set the import tax rate: (0%-100%)") as num
		import_tax_rate = Clamp(import_tax_rate, 0, 100)
		user << "Setting import tax to [import_tax_rate]%"
		change_import_tax(import_tax_rate)
		New()
		for (var/list/i in items_for_sale)
			if (i[1] == "governor" || i[1] == "both")
				display += "[i[2]] - [(i[4]/age_modifier)+((i[4]/age_modifier)*(import_tax_rate/100))] [money_string]"
				display += "Cancel"

	var/choice = WWinput(user, "Order a crate: (Current Money: [money/age_modifier] [money_string]; included IT: [import_tax_rate]%)", "Imports", "Cancel", display)

	if (choice == "Cancel")
		return
	else
		var/list/choicename = splittext(choice, " - ")
		for(var/list/i2 in items_for_sale)
			if (i2[2]== choicename[1])
				final_list = i2
				world.log << "[final_list], [final_list[1]], [final_list[2]]"
				break

	var/final_cost = (final_list[4]/age_modifier)+((final_list[4]/age_modifier)*(import_tax_rate/100))

	if (isemptylist(final_list))
		user << "Uh oh - something went wrong! Ping an admin!"
		return
	if(final_list[4] > money)
		user << "You don't have enough money to buy that crate!"
// giving change back
		if (money <= 50 && money > 0)
			if (map.ordinal_age >= 4)
				if((round(money/4) >= 1))
					new/obj/item/stack/money/real(loc, round(money/4))		//1 Dollar Bills
				if (((money/4) - round(money/4)) > 0)
					new/obj/item/stack/money/cents(loc, round(((money/4) - round(money/4)), 0.01) * 100)  //Cents
			else
				new/obj/item/stack/money/real(loc, money)
			money = 0
			return
		else if (money > 50 && money <= 400)
			if (map.ordinal_age >= 4)
				if (round(money/20) >= 1)
					new/obj/item/stack/money/dollar(loc, round(money/20)) //5 Dollar Bill
				if (round((money%20)/4) >= 1)
					new/obj/item/stack/money/real(loc, round((money%20)/4))	// 1 Dollar Bill
				if (((money/4) - round(money/4)) > 0)
					new/obj/item/stack/money/cents(loc, round(((money/4) - round(money/4)), 0.01) * 100)  //Cents
			else if (map.ordinal_age == 3)
				new/obj/item/stack/money/dollar(loc, money/8)
			else
				new/obj/item/stack/money/dollar(loc, money/4)
			money = 0
			return
		else if (money > 400 && money <= 800)
			if (map.ordinal_age >= 4)
				if (round(money/80) >= 1)
					new/obj/item/stack/money/escudo(loc, round(money/80)) //Change 20 Dollar Bill
				if (round((money%80)/20) >= 1)
					new/obj/item/stack/money/dollar(loc, round((money%80)/20)) //Change 5 Dollar Bill
				if (round((money%80)%20)/4 > 1)
					new/obj/item/stack/money/real(loc, round(((money%80)%20)/4)) //Change 1 Dollar Bill
				if (((money/4) - round(money/4)) > 0)
					new/obj/item/stack/money/cents(loc, round(((money/4) - round(money/4)), 0.01) * 100)  //Cents
			else if (map.ordinal_age == 3)
				new/obj/item/stack/money/escudo(loc, money/16)
			else
				new/obj/item/stack/money/escudo(loc, money/60)
			money = 0
			return
		else if (money > 800 && money <= 1600)
			if (map.ordinal_age >= 4)
				if(round(money/200) >= 1)
					new/obj/item/stack/money/doubloon(loc, round(money/200)) //Change 50 Dollar Bill
				if (round((money%200)/80) >= 1)
					new/obj/item/stack/money/escudo(loc, round((money%200)/80)) //Change 20 Dollar Bill
				if (round(((money%200)%80)/20) >= 1)
					new/obj/item/stack/money/dollar(loc, round(((money%200)%80)/20)) //Change 5 Dollar Bill
				if (round((((money%200)%80)%20)/4) >= 1)
					new/obj/item/stack/money/real(loc, round((((money%200)%80)%20)/4)) //Change 1 Dollar Bill
				if (((money/4) - round(money/4)) > 0)
					new/obj/item/stack/money/cents(loc, round(((money/4) - round(money/4)), 0.01) * 100)  //Cents
			else if (map.ordinal_age == 3)
				new/obj/item/stack/money/doubloon(loc, money/32)
			else
				new/obj/item/stack/money/doubloon(loc, money/120)
			money = 0
			return
		else if (money == 0)
			return
		else if (money > 1600)
			user << "Too much money to pay you back! Buy something else to reduce the money deposited."
			return
	else if (final_cost <= money)
		money -= final_cost
		user << "You have successfully purchased the crate. It will arrive soon."
		spawn(600)
			var/list/turfs = list()
			if (faction_treasury != "craftable")
				turfs = latejoin_turfs[factionarea]
			else
				turfs = list(get_turf(locate(x,y+1,z)))
			var/spawnpoint
			if (map.ordinal_age >= 4)
				if (user.original_job_title != "Gobernador" && user.original_job_title != "Governador" && user.original_job_title != "Governeur" && user.original_job_title != "Governor" && user.original_job_title != "British Governor" && user.original_job_title != "Mayor" && user.original_job_title !="Kaufmann" && user.original_job_title != "Freiherr")
					spawnpoint = pick(turfs)
				else
					var/list/fturfs = latejoin_turfs[faction_treasury]			//Mayor crates will arrive at treasure room
					spawnpoint = pick(fturfs)									//not into the Merchant Wagon
			else
				spawnpoint = pick(turfs)
			var/tpath = final_list[3]
			new tpath(get_turf(spawnpoint))
			user << "A shipment has arrived."

// giving change back, and taxes
		if (money <= 50 && money > 0)
			if (map.ordinal_age >= 4)
				if(round(money/4) >= 1)
					new/obj/item/stack/money/real(loc, round(money/4))		//1 Dollar Bills
				if (((money/4) - round(money/4)) > 0)
					new/obj/item/stack/money/cents(loc, round(((money/4) - round(money/4)), 0.01) * 100)  //Cents
			else if (map.ordinal_age < 4)
				new/obj/item/stack/money/real(loc, money)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			var/taxSet = (final_list[4]*(import_tax_rate/100))
			if ((final_list[4]*(import_tax_rate/100) > 0) && import_tax_rate > 0)
				if (map.ordinal_age >= 4)
					if((round(taxSet/4) >= 1))
						new/obj/item/stack/money/real(get_turf(spawnpointa), round(taxSet/4))
					if (((taxSet/4) - round(taxSet/4)) > 0)
						new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((taxSet/4) - round(taxSet/4)), 0.01) * 100)  //Cents
				else
					new/obj/item/stack/money/real(get_turf(spawnpointa), (final_list[4]*(import_tax_rate/100)))
			return
		else if (money > 50 && money <= 400) //63
			if (map.ordinal_age >= 4)
				if (round(money/20) >= 1)
					new/obj/item/stack/money/dollar(loc, round(money/20)) //5 Dollar Bill
				if (round((money%20)/4) >= 1)
					new/obj/item/stack/money/real(loc, round((money%20)/4))	// 1 Dollar Bill
				if (((money/4) - round(money/4)) > 0)
					new/obj/item/stack/money/cents(loc, round(((money/4) - round(money/4)), 0.01) * 100)  //Cents
			else if (map.ordinal_age == 4)
				new/obj/item/stack/money/dollar(loc, money/8)
			else
				new/obj/item/stack/money/dollar(loc, money/4)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			var/taxSet = (final_list[4]*(import_tax_rate/100))
			if ((final_list[4]*(import_tax_rate/100) >= 1) && import_tax_rate > 0)
				if (map.ordinal_age >= 4)
					if((round(taxSet/4) >= 1))
						new/obj/item/stack/money/real(get_turf(spawnpointa), round(taxSet/4))
					if (((taxSet/4) - round(taxSet/4)) > 0)
						new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((taxSet/4) - round(taxSet/4)), 0.01) * 100)  //Cents
				else
					new/obj/item/stack/money/real(get_turf(spawnpointa), (final_list[4]*(import_tax_rate/100)))
			return
		else if (money > 400 && money <= 800)
			if (map.ordinal_age >= 4)
				if (round(money/80) >= 1)
					new/obj/item/stack/money/escudo(loc, round(money/80)) //Change 20 Dollar Bill
				if (round((money%80)/20) >= 1)
					new/obj/item/stack/money/dollar(loc, round((money%80)/20)) //Change 5 Dollar Bill
				if (round((money%80)%20)/4 > 1)
					new/obj/item/stack/money/real(loc, round(((money%80)%20)/4)) //Change 1 Dollar Bill
				if (((money/4) - round(money/4)) > 0)
					new/obj/item/stack/money/cents(loc, round(((money/4) - round(money/4)), 0.01) * 100)  //Cents
			else if (map.ordinal_age == 4)
				new/obj/item/stack/money/escudo(loc, money/16)
			else
				new/obj/item/stack/money/escudo(loc, money/60)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			var/taxSet = (final_list[4]*(import_tax_rate/100))
			if ((final_list[4]*(import_tax_rate/100) >= 1) && import_tax_rate > 0)
				if (map.ordinal_age >= 4)
					if((round(taxSet/4) >= 1))
						new/obj/item/stack/money/real(get_turf(spawnpointa), round(taxSet/4))
					if (((taxSet/4) - round(taxSet/4)) > 0)
						new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((taxSet/4) - round(taxSet/4)), 0.01) * 100)  //Cents
				else
					new/obj/item/stack/money/real(get_turf(spawnpointa), (final_list[4]*(import_tax_rate/100)))
			return
		else if (money > 800 && money <= 1600)
			if (map.ordinal_age >= 4)
				if(round(money/200) >= 1)
					new/obj/item/stack/money/doubloon(loc, round(money/200)) //Change 50 Dollar Bill
				if (round((money%200)/80) >= 1)
					new/obj/item/stack/money/escudo(loc, round((money%200)/80)) //Change 20 Dollar Bill
				if (round(((money%200)%80)/20) >= 1)
					new/obj/item/stack/money/dollar(loc, round(((money%200)%80)/20)) //Change 5 Dollar Bill
				if (round((((money%200)%80)%20)/4) >= 1)
					new/obj/item/stack/money/real(loc, round((((money%200)%80)%20)/4)) //Change 1 Dollar Bill
				if (((money/4) - round(money/4)) > 0)
					new/obj/item/stack/money/cents(loc, round(((money/4) - round(money/4)), 0.01) * 100)  //Cents
			else if (map.ordinal_age == 4)
				new/obj/item/stack/money/doubloon(loc, money/32)
			else
				new/obj/item/stack/money/doubloon(loc, money/120)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			var/taxSet = (final_list[4]*(import_tax_rate/100))
			if ((final_list[4]*(import_tax_rate/100) >= 1) && import_tax_rate > 0)
				if (map.ordinal_age >= 4)
					if((round(taxSet/4) >= 1))
						new/obj/item/stack/money/real(get_turf(spawnpointa), round(taxSet/4))
					if (((taxSet/4) - round(taxSet/4)) > 0)
						new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((taxSet/4) - round(taxSet/4)), 0.01) * 100)  //Cents
				else
					new/obj/item/stack/money/real(get_turf(spawnpointa), (final_list[4]*(import_tax_rate/100)))
			return
		else if (money == 0)
			return
		else if (money > 10000)
			user << "Too much money to pay you back! Buy something else to reduce the money deposited."
			return

/obj/structure/supplybook/attackby(var/obj/item/stack/W as obj, var/mob/living/human/H as mob)
	if (W.amount && istype(W, /obj/item/stack/money))
		money += W.value*W.amount
		qdel(W)
		return
	else
		H << "You need to use either money or another form of currency (gold, pearls, valuable items)."
		return

/obj/structure/exportbook/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Trader" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand" && H.original_job_title != "Kaufmann")
		if (H.original_job_title != "Gobernador" && H.original_job_title != "Governador" && H.original_job_title != "Governeur" && H.original_job_title != "Governor" && H.original_job_title != "British Governor" && H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Trader" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand" && H.original_job_title != "Mayor" && H.original_job_title != "Kaufmann" && H.original_job_title != "Freiherr" && H.original_job_title != "Pirate Quartermaster")
			H << "Only the merchants have access to the international shipping companies. Negotiate with one."
			return
	else
		New() //Updating the export tax
		if (W.value == 0)
			H << "There is no demand for this item."
			return
		else
			if (istype(W, /obj/item/stack/money) && done == FALSE)
				done = TRUE
				marketval = W.value
				moneyin = marketval*W.amount
				if ((WWinput(H, "Exchange this amount into other coins?", "Exporting", "Yes", list("Yes", "No")) == "Yes") && W)
					if (moneyin <= 50 && W && marketval > 0)
						if (map.ordinal_age >= 4)
							if(round(moneyin/4) >= 1)
								new/obj/item/stack/money/real(loc, round(moneyin/4))		//1 Dollar Bills
							if (((moneyin/4) - round(moneyin/4)) > 0)
								new/obj/item/stack/money/cents(loc, round(((moneyin/4) - round(moneyin/4)), 0.01) * 100)  //Cents
						else if (map.ordinal_age < 4)
							new/obj/item/stack/money/real(loc, moneyin)
						qdel(W)
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 50 && moneyin <= 400 && W && marketval > 0)
						if (map.ordinal_age >= 4)
							if (round(moneyin/20) >= 1)
								new/obj/item/stack/money/dollar(loc, round(moneyin/20)) //5 Dollar Bill
							if (round((moneyin%20)/4) >= 1)
								new/obj/item/stack/money/real(loc, round((moneyin%20)/4))	// 1 Dollar Bill
							if (((moneyin/4) - round(moneyin/4)) > 0)
								new/obj/item/stack/money/cents(loc, round(((moneyin/4) - round(moneyin/4)), 0.01) * 100)  //Cents
						else
							new/obj/item/stack/money/dollar(loc, moneyin/8)
						qdel(W)
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 400 && moneyin <= 800 && W && marketval > 0)
						if (map.ordinal_age >= 4)
							if (round(moneyin/80) >= 1)
								new/obj/item/stack/money/escudo(loc, round(moneyin/80)) //Change 20 Dollar Bill
							if (round((moneyin%80)/20) >= 1)
								new/obj/item/stack/money/dollar(loc, round((moneyin%80)/20)) //Change 5 Dollar Bill
							if (round((moneyin%80)%20)/4 > 1)
								new/obj/item/stack/money/real(loc, round(((moneyin%80)%20)/4)) //Change 1 Dollar Bill
							if (((moneyin/4) - round(moneyin/4)) > 0)
								new/obj/item/stack/money/cents(loc, round(((moneyin/4) - round(moneyin/4)), 0.01) * 100)  //Cents
						else
							new/obj/item/stack/money/escudo(loc, moneyin/16)
						qdel(W)
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 800 && moneyin <= 1600 && W && marketval > 0)
						if (map.ordinal_age >= 4)
							if(round(moneyin/200) >= 1)
								new/obj/item/stack/money/doubloon(loc, round(moneyin/200)) //Change 50 Dollar Bill
							if (round((moneyin%200)/80) >= 1)
								new/obj/item/stack/money/escudo(loc, round((moneyin%200)/80)) //Change 20 Dollar Bill
							if (round(((moneyin%200)%80)/20) >= 1)
								new/obj/item/stack/money/dollar(loc, round(((moneyin%200)%80)/20)) //Change 5 Dollar Bill
							if (round((((moneyin%200)%80)%20)/4) >= 1)
								new/obj/item/stack/money/real(loc, round((((moneyin%200)%80)%20)/4)) //Change 1 Dollar Bill
							if (((moneyin/4) - round(moneyin/4)) > 0)
								new/obj/item/stack/money/cents(loc, round(((moneyin/4) - round(moneyin/4)), 0.01) * 100)  //Cents
						else
							new/obj/item/stack/money/doubloon(loc, moneyin/32)
						qdel(W)
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 1600 && W && marketval > 0)
						H << "Too much money! Split it into smaller stacks first."
						marketval = 0
						done = FALSE
						return
				else
					marketval = 0
					done = FALSE
					return
			if (istype(W) && done == FALSE)
				done = TRUE
				marketval = W.value + rand(-round(W.value/10),round(W.value/10))
				moneyin = marketval*W.amount-((marketval*W.amount)*(export_tax_rate/100))
				var/exportChoice
				if (map.ordinal_age >= 4)
					exportChoice = WWinput(H, "Sell the whole stack for [moneyin/4] dollars? Included ET: [export_tax_rate]%", "Exporting", "Yes", list("Yes", "No"))
				else
					exportChoice = WWinput(H, "Sell the whole stack for [moneyin] realles? Included ET: [export_tax_rate]%", "Exporting", "Yes", list("Yes", "No"))
				if (exportChoice == "Yes" && W)
					if (moneyin <= 50 && W && marketval > 0)
						if (map.ordinal_age >= 4)
							if(round(moneyin/4) >= 1)
								new/obj/item/stack/money/real(loc, round(moneyin/4))		//1 Dollar Bills
							if (((moneyin/4) - round(moneyin/4)) > 0)
								new/obj/item/stack/money/cents(loc, round(((moneyin/4) - round(moneyin/4)), 0.01) * 100)  //Cents
						else if (map.ordinal_age < 4)
							new/obj/item/stack/money/real(loc, moneyin)
						qdel(W)
						var/list/fturfs = latejoin_turfs[faction_treasury]
						var/spawnpointa = pick(fturfs)
						var/exportset = (marketval*W.amount)*(export_tax_rate/100)
						if (((marketval*W.amount)*(export_tax_rate/100) > 0) && export_tax_rate > 0)
							if (map.ordinal_age >= 4)
								if(round(exportset/4) >= 1)
									new/obj/item/stack/money/real(get_turf(spawnpointa), round(exportset/4))
								if (((exportset/4) - round(exportset/4)) > 0)
									new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((exportset/4) - round(exportset/4)), 0.01) * 100)  //Cents
							else
								new/obj/item/stack/money/real(get_turf(spawnpointa), (marketval*W.amount)*(export_tax_rate/100))

						marketval = 0
						done = FALSE
						return
					else if (moneyin > 50 && moneyin <= 400 && W && marketval > 0)
						if (map.ordinal_age >= 4)
							if (round(moneyin/20) >= 1)
								new/obj/item/stack/money/dollar(loc, round(moneyin/20)) //5 Dollar Bill
							if (round((moneyin%20)/4) >= 1)
								new/obj/item/stack/money/real(loc, round((moneyin%20)/4))	// 1 Dollar Bill
							if (((moneyin/4) - round(moneyin/4)) > 0)
								new/obj/item/stack/money/cents(loc, round(((moneyin/4) - round(moneyin/4)), 0.01) * 100)  //Cents
						else
							new/obj/item/stack/money/dollar(loc, moneyin/8)
						qdel(W)
						var/list/fturfs = latejoin_turfs[faction_treasury]
						var/spawnpointa = pick(fturfs)
						var/exportset = (marketval*W.amount)*(export_tax_rate/100)
						if (((marketval*W.amount)*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
							if (map.ordinal_age >= 4)
								if(round(exportset/4) >= 1)
									new/obj/item/stack/money/real(get_turf(spawnpointa), round(exportset/4))
								if (((exportset/4) - round(exportset/4)) > 0)
									new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((exportset/4) - round(exportset/4)), 0.01) * 100)  //Cents
							else
								new/obj/item/stack/money/real(get_turf(spawnpointa), (marketval*W.amount)*(export_tax_rate/100))
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 400 && moneyin <= 800 && W && marketval > 0)
						if (map.ordinal_age >= 4)
							if (round(moneyin/80) >= 1)
								new/obj/item/stack/money/escudo(loc, round(moneyin/80)) //Change 20 Dollar Bill
							if (round((moneyin%80)/20) >= 1)
								new/obj/item/stack/money/dollar(loc, round((moneyin%80)/20)) //Change 5 Dollar Bill
							if (round((moneyin%80)%20)/4 > 1)
								new/obj/item/stack/money/real(loc, round(((moneyin%80)%20)/4)) //Change 1 Dollar Bill
							if (((moneyin/4) - round(moneyin/4)) > 0)
								new/obj/item/stack/money/cents(loc, round(((moneyin/4) - round(moneyin/4)), 0.01) * 100)  //Cents
						else
							new/obj/item/stack/money/escudo(loc, moneyin/16)
						qdel(W)
						var/list/fturfs = latejoin_turfs[faction_treasury]
						var/spawnpointa = pick(fturfs)
						var/exportset = (marketval*W.amount)*(export_tax_rate/100)
						if (((marketval*W.amount)*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
							if (map.ordinal_age >= 4)
								if(round(exportset/4) >= 1)
									new/obj/item/stack/money/real(get_turf(spawnpointa), round(exportset/4))
								if (((exportset/4) - round(exportset/4)) > 0)
									new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((exportset/4) - round(exportset/4)), 0.01) * 100)  //Cents
							else
								new/obj/item/stack/money/real(get_turf(spawnpointa), (marketval*W.amount)*(export_tax_rate/100))
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 800 && moneyin <= 1600 && W && marketval > 0)
						if (map.ordinal_age >= 4)
							if(round(moneyin/200) >= 1)
								new/obj/item/stack/money/doubloon(loc, round(moneyin/200)) //Change 50 Dollar Bill
							if (round((moneyin%200)/80) >= 1)
								new/obj/item/stack/money/escudo(loc, round((moneyin%200)/80)) //Change 20 Dollar Bill
							if (round(((moneyin%200)%80)/20) >= 1)
								new/obj/item/stack/money/dollar(loc, round(((moneyin%200)%80)/20)) //Change 5 Dollar Bill
							if (round((((moneyin%200)%80)%20)/4) >= 1)
								new/obj/item/stack/money/real(loc, round((((moneyin%200)%80)%20)/4)) //Change 1 Dollar Bill
							if (((moneyin/4) - round(moneyin/4)) > 0)
								new/obj/item/stack/money/cents(loc, round(((moneyin/4) - round(moneyin/4)), 0.01) * 100)  //Cents
						else
							new/obj/item/stack/money/doubloon(loc, moneyin/32)
						qdel(W)
						var/list/fturfs = latejoin_turfs[faction_treasury]
						var/spawnpointa = pick(fturfs)
						var/exportset = (marketval*W.amount)*(export_tax_rate/100)
						if (((marketval*W.amount)*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
							if (map.ordinal_age >= 4)
								if(round(exportset/4) >= 1)
									new/obj/item/stack/money/real(get_turf(spawnpointa), round(exportset/4))
								if (((exportset/4) - round(exportset/4)) > 0)
									new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((exportset/4) - round(exportset/4)), 0.01) * 100)  //Cents
							else
								new/obj/item/stack/money/real(get_turf(spawnpointa), (marketval*W.amount)*(export_tax_rate/100))
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 1600 && W && marketval > 0)
						H << "This item is too expensive! You can't find a buyer for it."
						marketval = 0
						done = FALSE
						return
				else
					marketval = 0
					done = FALSE
					return

/obj/structure/exportbook/attack_hand(var/mob/living/human/H as mob)
	if (H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Trader" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand" && H.original_job_title != "Banker" && H.original_job_title != "Kaufmann" && H.original_job_title != "Pirate Quartermaster")
		if (H.original_job_title != "Gobernador" && H.original_job_title != "Governador" && H.original_job_title != "Governeur" && H.original_job_title != "Governor" && H.original_job_title != "British Governor" && H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Trader" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand" && H.original_job_title != "Mayor"&& H.original_job_title != "Freiherr" && H.original_job_title != "Kaufmann")
			H << "Only the merchants have access to the international shipping companies. Negotiate with one."
			return
		else
			var/set_export_tax = input(H, "Set the export tax rate: (0%-100%)") as num
			set_export_tax = Clamp(set_export_tax, 0, 100)
			H << "Setting export tax to [set_export_tax]%"
			change_export_tax(set_export_tax)
			New()
			return

/obj/structure/exportbook/proc/change_export_tax(N as num)
	global.global_export_tax = N
	return

/obj/structure/supplybook/proc/change_import_tax(N as num)
	global.global_import_tax = N
	return
/* For reference
/obj/item/stack/money/real
	value = 1

/obj/item/stack/money/dollar
	value = 8

/obj/item/stack/money/escudo
	value = 16

/obj/item/stack/money/doubloon
	value = 32

/obj/item/stack/money/goldnugget
	value = 96

/obj/item/stack/money/goldvaluables
	value = 48

/obj/item/stack/money/gems
	value = 35

/obj/item/stack/money/pearls
	value = 45
*/
