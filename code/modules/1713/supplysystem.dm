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
	var/list/itemsnr = list(
		1 = "wood crate",
		2 = "iron crate",
		3 = "glass crate",
		4 = "vegetables crate",
		5 = "fruits crate",
		6 = "biscuits crate",
		7 = "beer crate",
		8 = "ale crate",
		9 = "meat crate",
		10 = "tree seeds crate",
		11 = "vegetable seeds crate",
		12 = "cereal seeds crate",
		13 = "cash crops crate",
		14 = "medicinal seeds crate",
		15 = "cow",
		16 = "bull",
		17 = "sheep ram",
		18 = "sheep ewe",
		19 = "hen",
		20 = "rooster",
		21 = "horse",
		22 = "brick crate",
		23 = "medical supplies",
		24 = "gunpowder barrel",
		25 = "musket ammo crate (25)",
		26 = "pistol ammo crate (25)",
		27 = "blunderbuss ammo crate (15)",
		28 = "grenade crate (10)",
		29 = "cannonball crate (10)",
		30 = "pistol crate (5)",
		31 = "musket crate (5)",
		32 = "musketoon crate (5)",
		33 = "blunderbuss crate (5)",)
	var/list/itemstobuy = list(
		"wood crate" = /obj/structure/closet/crate/wood,
		"iron crate" = /obj/structure/closet/crate/iron,
		"glass crate" = /obj/structure/closet/crate/glass,
		"vegetables crate" = /obj/structure/closet/crate/rations/vegetables,
		"fruits crate" = /obj/structure/closet/crate/rations/fruits,
		"biscuits crate" = /obj/structure/closet/crate/rations/biscuits,
		"beer crate" = /obj/structure/closet/crate/rations/beer,
		"ale crate" = /obj/structure/closet/crate/rations/ale,
		"meat crate" = /obj/structure/closet/crate/rations/meat,
		"tree seeds crate" = /obj/structure/closet/crate/rations/seeds/trees,
		"vegetable seeds crate" = /obj/structure/closet/crate/rations/seeds/vegetables,
		"cereal seeds crate" = /obj/structure/closet/crate/rations/seeds/cereals,
		"cash crops crate" = /obj/structure/closet/crate/rations/seeds/cashcrops,
		"medicinal seeds crate" = /obj/structure/closet/crate/rations/seeds/medicinal,
		"cow" = /mob/living/simple_animal/cow,
		"bull" = /mob/living/simple_animal/bull,
		"sheep ram" = /mob/living/simple_animal/sheep,
		"sheep ewe" = /mob/living/simple_animal/sheep/female,
		"hen" = /mob/living/simple_animal/chicken,
		"rooster" = /mob/living/simple_animal/rooster,
		"horse" = /mob/living/simple_animal/horse,
		"brick crate" = /obj/structure/closet/crate/brick,
		"medical supplies" = /obj/item/weapon/storage/firstaid/adv,
		"gunpowder barrel" = /obj/item/weapon/reagent_containers/glass/barrel/gunpowder,
		"musket ammo crate (25)" = /obj/structure/closet/crate/musketball,
		"pistol ammo crate (25)" = /obj/structure/closet/crate/musketball_pistol,
		"blunderbuss ammo crate (15)" = /obj/structure/closet/crate/blunderbuss_ammo,
		"grenade crate (10)" = /obj/structure/closet/crate/grenades,
		"cannonball crate (10)"= /obj/structure/closet/crate/cannonball,
		"pistol crate (5)" = /obj/structure/closet/crate/pistols,
		"musket crate (5)" = /obj/structure/closet/crate/muskets,
		"musketoon crate (5)" = /obj/structure/closet/crate/musketoons,
		"blunderbuss crate (5)"= /obj/structure/closet/crate/blunderbusses,)

	var/list/itemprices = list(
		"wood crate" = 120,
		"iron crate" = 330,
		"glass crate" = 330,
		"vegetables crate" = 60,
		"fruits crate" = 66,
		"biscuits crate" = 50,
		"beer crate" = 60,
		"ale crate" = 70,
		"meat crate" = 70,
		"tree seeds crate" = 20,
		"vegetable seeds crate" = 30,
		"cereal seeds crate" = 20,
		"cash crops crate" = 50,
		"medicinal seeds crate" = 50,
		"cow" = 160,
		"bull" = 150,
		"sheep ram" = 90,
		"sheep ewe" = 90,
		"chicken" = 50,
		"rooster" = 40,
		"horse" = 200,
		"brick crate" = 140,
		"medical supplies" = 150,
		"gunpowder barrel" = 230,
		"musket ammo crate (25)" = 100,
		"pistol ammo crate (25)" = 60,
		"blunderbuss crate (15)" = 60,
		"grenade crate (10)" = 110,
		"cannonball crate (10)" = 175,
		"pistol crate (5)" = 385,
		"musket crate (5)" = 550,
		"musketoon crate (5)" = 440,
		"blunderbuss crate (5)" = 495,)
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
/obj/structure/supplybook/attack_hand(var/mob/living/carbon/human/user as mob)
	if (user.original_job_title != "Gobernador" && user.original_job_title != "Governador" && user.original_job_title != "Governeur" && user.original_job_title != "Governor" && user.original_job_title != "British Governor" && user.original_job_title != "British Merchant"  && user.original_job_title != "Merchant" && user.original_job_title != "Trader" && user.original_job_title != "Mercador" && user.original_job_title != "Comerciante" && user.original_job_title != "Marchand" && user.original_job_title != "Mayor")
		user << "Only the merchants have access to the international shipping companies. Negotiate with one."
		return

	var/finalnr = 1
	var/finalcost = 1
	var/finalpath
	var/list/display = list ()//The products to be displayed, includes name of crate and price
	if (user.original_job_title != "Gobernador" && user.original_job_title != "Governador" && user.original_job_title != "Governeur" && user.original_job_title != "Governor" && user.original_job_title != "British Governor" && user.original_job_title != "Mayor")
		New()	//Updates the taxes
		if (map.ordinal_age >= 4)
			for (var/i=1;i<=23,i++)
				display += "[itemsnr[i]] - ([itemprices[itemsnr[i]]/4+((itemprices[itemsnr[i]]/4)*(import_tax_rate/100))]) dollars" //Simplicity so the crate's name can be shown in the list
		else
			for (var/i=1;i<=23,i++)
				display += "[itemsnr[i]] - [itemprices[itemsnr[i]]+(itemprices[itemsnr[i]]*(import_tax_rate/100))] reales" //Simplicity so the crate's name can be shown in the list
	else
		import_tax_rate = input(user, "Set the import tax rate: (0%-100%)") as num
		import_tax_rate = Clamp(import_tax_rate, 0, 100)
		user << "Setting import tax to [import_tax_rate]%"
		change_import_tax(import_tax_rate)
		New()
		if (map.ordinal_age >= 4)
			for (var/i=24;i<=33,i++)	//Mayor now can only buy military related products
				display += "[itemsnr[i]] - [itemprices[itemsnr[i]]/4+((itemprices[itemsnr[i]]/4)*(import_tax_rate/100))] dollars"
		else
			for (var/i=24;i<=33,i++)	//Mayor now can only buy military related products
				display += "[itemsnr[i]] - [itemprices[itemsnr[i]]+(itemprices[itemsnr[i]]*(import_tax_rate/100))] reales"
	var/choice
	if (map.ordinal_age >= 4)
		choice = WWinput(user, "Order a crate: (Current Money: [money/4] dollars; included IT: [import_tax_rate]%)", "Imports", "Cancel", display)
	else if (map.ordinal_age < 4)
		choice = WWinput(user, "Order a crate: (Current Money: [money] reales; included IT: [import_tax_rate]%)", "Imports", "Cancel", display)
	if (choice == "Cancel")
		return
	else
		var/list/choicename = splittext(choice, " - ")
		finalnr = choicename[1]
		finalcost = itemprices[finalnr]+(itemprices[finalnr]*(import_tax_rate/100))
		finalpath = itemstobuy[finalnr]
	if(finalcost > money)
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
			else
				new/obj/item/stack/money/dollar(loc, money/8)
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
			else
				new/obj/item/stack/money/escudo(loc, money/16)
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
			else
				new/obj/item/stack/money/doubloon(loc, money/32)
			money = 0
			return
		else if (money == 0)
			return
		else if (money > 1600)
			user << "Too much money to pay you back! Buy something else to reduce the money deposited."
			return
	else if (finalcost <= money)
		money -= finalcost
		user << "You have successfully purchased the crate. It will arrive soon."
		spawn(600)
			var/list/turfs = list()
			if (faction_treasury != "craftable")
				turfs = latejoin_turfs[factionarea]
			else
				turfs = list(get_turf(locate(x,y+1,z)))
			var/spawnpoint
			if (map.ordinal_age >= 4)
				if (user.original_job_title != "Gobernador" && user.original_job_title != "Governador" && user.original_job_title != "Governeur" && user.original_job_title != "Governor" && user.original_job_title != "British Governor" && user.original_job_title != "Mayor")
					spawnpoint = pick(turfs)
				else
					var/list/fturfs = latejoin_turfs[faction_treasury]			//Mayor crates will arrive at treasure room
					spawnpoint = pick(fturfs)									//not into the Merchant Wagon
			else
				spawnpoint = pick(turfs)
			new finalpath(get_turf(spawnpoint))
			user << "A shipment has arrived."
/*			if (done == FALSE)
				money += finalcost
				user << "The arrival area is too crowded, clear it first and reorder!"
				return*/
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
			var/taxSet = (itemprices[finalnr]*(import_tax_rate/100))
			if ((itemprices[finalnr]*(import_tax_rate/100) > 0) && import_tax_rate > 0)
				if (map.ordinal_age >= 4)
					if((round(taxSet/4) >= 1))
						new/obj/item/stack/money/real(get_turf(spawnpointa), round(taxSet/4))
					if (((taxSet/4) - round(taxSet/4)) > 0)
						new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((taxSet/4) - round(taxSet/4)), 0.01) * 100)  //Cents
				else
					new/obj/item/stack/money/real(get_turf(spawnpointa), (itemprices[finalnr]*(import_tax_rate/100)))
			return
		else if (money > 50 && money <= 400) //63
			if (map.ordinal_age >= 4)
				if (round(money/20) >= 1)
					new/obj/item/stack/money/dollar(loc, round(money/20)) //5 Dollar Bill
				if (round((money%20)/4) >= 1)
					new/obj/item/stack/money/real(loc, round((money%20)/4))	// 1 Dollar Bill
				if (((money/4) - round(money/4)) > 0)
					new/obj/item/stack/money/cents(loc, round(((money/4) - round(money/4)), 0.01) * 100)  //Cents
			else
				new/obj/item/stack/money/dollar(loc, money/8)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			var/taxSet = (itemprices[finalnr]*(import_tax_rate/100))
			if ((itemprices[finalnr]*(import_tax_rate/100) >= 1) && import_tax_rate > 0)
				if (map.ordinal_age >= 4)
					if((round(taxSet/4) >= 1))
						new/obj/item/stack/money/real(get_turf(spawnpointa), round(taxSet/4))
					if (((taxSet/4) - round(taxSet/4)) > 0)
						new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((taxSet/4) - round(taxSet/4)), 0.01) * 100)  //Cents
				else
					new/obj/item/stack/money/real(get_turf(spawnpointa), (itemprices[finalnr]*(import_tax_rate/100)))
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
			else
				new/obj/item/stack/money/escudo(loc, money/16)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			var/taxSet = (itemprices[finalnr]*(import_tax_rate/100))
			if ((itemprices[finalnr]*(import_tax_rate/100) >= 1) && import_tax_rate > 0)
				if (map.ordinal_age >= 4)
					if((round(taxSet/4) >= 1))
						new/obj/item/stack/money/real(get_turf(spawnpointa), round(taxSet/4))
					if (((taxSet/4) - round(taxSet/4)) > 0)
						new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((taxSet/4) - round(taxSet/4)), 0.01) * 100)  //Cents
				else
					new/obj/item/stack/money/real(get_turf(spawnpointa), (itemprices[finalnr]*(import_tax_rate/100)))
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
			else
				new/obj/item/stack/money/doubloon(loc, money/32)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			var/taxSet = (itemprices[finalnr]*(import_tax_rate/100))
			if ((itemprices[finalnr]*(import_tax_rate/100) >= 1) && import_tax_rate > 0)
				if (map.ordinal_age >= 4)
					if((round(taxSet/4) >= 1))
						new/obj/item/stack/money/real(get_turf(spawnpointa), round(taxSet/4))
					if (((taxSet/4) - round(taxSet/4)) > 0)
						new/obj/item/stack/money/cents(get_turf(spawnpointa), round(((taxSet/4) - round(taxSet/4)), 0.01) * 100)  //Cents
				else
					new/obj/item/stack/money/real(get_turf(spawnpointa), (itemprices[finalnr]*(import_tax_rate/100)))
			return
		else if (money == 0)
			return
		else if (money > 10000)
			user << "Too much money to pay you back! Buy something else to reduce the money deposited."
			return

/obj/structure/supplybook/attackby(var/obj/item/stack/W as obj, var/mob/living/carbon/human/H as mob)
	if (W.amount && istype(W, /obj/item/stack/money))
		money += W.value*W.amount
		qdel(W)
		return
	else
		H << "You need to use either money or another form of currency (gold, pearls, valuable items)."
		return

/obj/structure/exportbook/attackby(var/obj/item/W as obj, var/mob/living/carbon/human/H as mob)
	if (H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Trader" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand")
		if (H.original_job_title != "Gobernador" && H.original_job_title != "Governador" && H.original_job_title != "Governeur" && H.original_job_title != "Governor" && H.original_job_title != "British Governor" && H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Trader" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand" && H.original_job_title != "Mayor")
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
			if (istype(W)) //&& "done == FALSE" removed and accepting anything holdable and vuluable
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
			/*else what in the holly fuck
				if (done == FALSE)
					done = TRUE
					marketval = W.value + rand(-round(W.value/10),round(W.value/10))
					moneyin = marketval+(marketval*(export_tax_rate/100))
					if ((WWinput(H, "Sell this for [marketval] reales? Included ET:[export_tax_rate]%", "Exporting", "Yes", list("Yes", "No")) == "Yes") && W)
						if (moneyin <= 50 && W && marketval > 0)
							new/obj/item/stack/money/real(loc, moneyin)
							qdel(W)
							var/list/fturfs = latejoin_turfs[faction_treasury]
							var/spawnpointa = pick(fturfs)
							if ((marketval*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
								new/obj/item/stack/money/real(get_turf(spawnpointa), marketval*(export_tax_rate/100))
							marketval = 0
							done = FALSE
							return
						else if (moneyin > 50 && moneyin <= 400 && W && marketval > 0)
							new/obj/item/stack/money/dollar(loc, moneyin/8)
							qdel(W)
							var/list/fturfs = latejoin_turfs[faction_treasury]
							var/spawnpointa = pick(fturfs)
							if ((marketval*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
								new/obj/item/stack/money/real(get_turf(spawnpointa), marketval*(export_tax_rate/100))
							marketval = 0
							done = FALSE
							return
						else if (moneyin > 400 && moneyin <= 800 && W && marketval > 0)
							new/obj/item/stack/money/escudo(loc, moneyin/16)
							qdel(W)
							var/list/fturfs = latejoin_turfs[faction_treasury]
							var/spawnpointa = pick(fturfs)
							if ((marketval*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
								new/obj/item/stack/money/real(get_turf(spawnpointa), marketval*(export_tax_rate/100))
							marketval = 0
							done = FALSE
							return
						else if (moneyin > 800 && moneyin <= 1600 && W && marketval > 0)
							new/obj/item/stack/money/doubloon(loc, moneyin/32)
							qdel(W)
							var/list/fturfs = latejoin_turfs[faction_treasury]
							var/spawnpointa = pick(fturfs)
							if ((marketval*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
								new/obj/item/stack/money/real(get_turf(spawnpointa), marketval*(export_tax_rate/100))
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
						return */

/obj/structure/exportbook/attack_hand(var/mob/living/carbon/human/H as mob)
	if (H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Trader" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand" && H.original_job_title != "Banker")
		if (H.original_job_title != "Gobernador" && H.original_job_title != "Governador" && H.original_job_title != "Governeur" && H.original_job_title != "Governor" && H.original_job_title != "British Governor" && H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Trader" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand" && H.original_job_title != "Mayor")
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
