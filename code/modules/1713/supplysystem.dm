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
		16 = "chicken",
		17 = "horse",
		18 = "medical supplies",
		19 = "gunpowder barrel",
		20 = "musket ammo crate (25)",
		21 = "pistol ammo crate (25)",
		22 = "blunderbuss ammo crate (15)",
		23 = "grenade crate (10)",
		24 = "cannonball crate (10)",
		25 = "pistol crate (5)",
		26 = "musket crate (5)",
		27 = "musketoon crate (5)",
		28 = "blunderbuss crate (5)",)
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
		"chicken" = /mob/living/simple_animal/chicken,
		"horse" = /mob/living/simple_animal/horse,
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
		"cow" = 90,
		"chicken" = 30,
		"horse" = 150,
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

/obj/structure/supplybook/craftable
	faction_treasury = "craftable"
	factionarea = "craftable"
	icon = 'icons/misc/support.dmi'
	icon_state = "supplybook"
	not_movable = FALSE
	not_disassemblable = TRUE
/obj/structure/supplybook/attack_hand(var/mob/living/carbon/human/user as mob)
	if (user.original_job_title != "Gobernador" && user.original_job_title != "Governador" && user.original_job_title != "Governeur" && user.original_job_title != "Governor" && user.original_job_title != "British Governor" && user.original_job_title != "British Merchant"  && user.original_job_title != "Merchant" && user.original_job_title != "Mercador" && user.original_job_title != "Comerciante" && user.original_job_title != "Marchand")
		user << "Only the merchants have access to the international shipping companies. Negotiate with one."
		return

	var/finalnr = 1
	var/finalcost = 1
	var/finalpath
	var/list/display = list ()//The products to be displayed, includes name of crate and price
	if (user.original_job_title != "Gobernador" && user.original_job_title != "Governador" && user.original_job_title != "Governeur" && user.original_job_title != "Governor" && user.original_job_title != "British Governor" )
		for (var/i=1;i<=18,i++)
			display += "[itemsnr[i]] - [itemprices[itemsnr[i]]+(itemprices[itemsnr[i]]*(import_tax_rate/100))] reales" //Simplicity so the crate's name can be shown in the list
	else
		import_tax_rate = input(user, "Set the import tax rate: (0%-100%)") as num
		import_tax_rate = Clamp(import_tax_rate, 0, 100)
		for (var/i=1;i<=28,i++)
			display += "[itemsnr[i]] - [itemprices[itemsnr[i]]+(itemprices[itemsnr[i]]*(import_tax_rate/100))] reales"
	var/choice = WWinput(user, "Order a crate: (Current Money: [money] reales; included IT: [import_tax_rate]%)", "Imports", "Cancel", display)
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
			new/obj/item/stack/money/real(loc, money)
			money = 0
			return
		else if (money > 50 && money <= 400)
			new/obj/item/stack/money/dollar(loc, money/8)
			money = 0
			return
		else if (money > 400 && money <= 800)
			new/obj/item/stack/money/escudo(loc, money/16)
			money = 0
			return
		else if (money > 800 && money <= 1600)
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
			var/spawnpoint = pick(turfs)
			new finalpath(get_turf(spawnpoint))
			user << "A shipment has arrived."
/*			if (done == FALSE)
				money += finalcost
				user << "The arrival area is too crowded, clear it first and reorder!"
				return*/
// giving change back, and taxes
		if (money <= 50 && money > 0)
			new/obj/item/stack/money/real(loc, money)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			if ((itemprices[finalnr]*(import_tax_rate/100) >= 1) && import_tax_rate > 0)
				new/obj/item/stack/money/real(get_turf(spawnpointa), itemprices[finalnr]*(import_tax_rate/100))
			return
		else if (money > 50 && money <= 400)
			new/obj/item/stack/money/dollar(loc, money/8)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			if ((itemprices[finalnr]*(import_tax_rate/100) >= 1) && import_tax_rate > 0)
				new/obj/item/stack/money/real(get_turf(spawnpointa), itemprices[finalnr]*(import_tax_rate/100))
			return
		else if (money > 400 && money <= 800)
			new/obj/item/stack/money/escudo(loc, money/16)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			if ((itemprices[finalnr]*(import_tax_rate/100) >= 1) && import_tax_rate > 0)
				new/obj/item/stack/money/real(get_turf(spawnpointa), itemprices[finalnr]*(import_tax_rate/100))
			return
		else if (money > 800 && money <= 1600)
			new/obj/item/stack/money/doubloon(loc, money/32)
			money = 0
			var/list/fturfs = latejoin_turfs[faction_treasury]
			var/spawnpointa = pick(fturfs)
			if ((itemprices[finalnr]*(import_tax_rate/100) >= 1) && import_tax_rate > 0)
				new/obj/item/stack/money/real(get_turf(spawnpointa), itemprices[finalnr]*(import_tax_rate/100))
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
	if (H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand")
		if (H.original_job_title != "Gobernador" && H.original_job_title != "Governador" && H.original_job_title != "Governeur" && H.original_job_title != "Governor" && H.original_job_title != "British Governor" && H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand")
			H << "Only the merchants have access to the international shipping companies. Negotiate with one."
			return
		else
			export_tax_rate = input(H, "Set the export tax rate: (0%-100%)") as num
			export_tax_rate = Clamp(export_tax_rate, 0, 100)
			return
	else
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
						new/obj/item/stack/money/real(loc, moneyin)
						qdel(W)
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 50 && moneyin <= 400 && W && marketval > 0)
						new/obj/item/stack/money/dollar(loc, moneyin/8)
						qdel(W)
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 400 && moneyin <= 800 && W && marketval > 0)
						new/obj/item/stack/money/escudo(loc, moneyin/16)
						qdel(W)
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 800 && moneyin <= 1600 && W && marketval > 0)
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
			if (istype(W, /obj/item/stack) && done == FALSE)
				done = TRUE
				marketval = W.value + rand(-round(W.value/10),round(W.value/10))
				moneyin = marketval*W.amount-((marketval*W.amount)*(export_tax_rate/100))
				if ((WWinput(H, "Sell the whole stack for [moneyin] reales? Included ET: [export_tax_rate]%", "Exporting", "Yes", list("Yes", "No")) == "Yes") && W)
					if (moneyin <= 50 && W && marketval > 0)
						new/obj/item/stack/money/real(loc, moneyin)
						qdel(W)
						var/list/fturfs = latejoin_turfs[faction_treasury]
						var/spawnpointa = pick(fturfs)
						if (((marketval*W.amount)*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
							new/obj/item/stack/money/real(get_turf(spawnpointa), (marketval*W.amount)*(export_tax_rate/100))
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 50 && moneyin <= 400 && W && marketval > 0)
						new/obj/item/stack/money/dollar(loc, moneyin/8)
						qdel(W)
						var/list/fturfs = latejoin_turfs[faction_treasury]
						var/spawnpointa = pick(fturfs)
						if (((marketval*W.amount)*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
							new/obj/item/stack/money/real(get_turf(spawnpointa), (marketval*W.amount)*(export_tax_rate/100))
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 400 && moneyin <= 800 && W && marketval > 0)
						new/obj/item/stack/money/escudo(loc, moneyin/16)
						qdel(W)
						var/list/fturfs = latejoin_turfs[faction_treasury]
						var/spawnpointa = pick(fturfs)
						if (((marketval*W.amount)*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
							new/obj/item/stack/money/real(get_turf(spawnpointa), (marketval*W.amount)*(export_tax_rate/100))
						marketval = 0
						done = FALSE
						return
					else if (moneyin > 800 && moneyin <= 1600 && W && marketval > 0)
						new/obj/item/stack/money/doubloon(loc, moneyin/32)
						qdel(W)
						var/list/fturfs = latejoin_turfs[faction_treasury]
						var/spawnpointa = pick(fturfs)
						if (((marketval*W.amount)*(export_tax_rate/100) >= 1) && export_tax_rate > 0)
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
			else
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
						return

/obj/structure/exportbook/attack_hand(var/mob/living/carbon/human/H as mob)
	if (H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand")
		if (H.original_job_title != "Gobernador" && H.original_job_title != "Governador" && H.original_job_title != "Governeur" && H.original_job_title != "Governor" && H.original_job_title != "British Governor" && H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand")
			H << "Only the merchants have access to the international shipping companies. Negotiate with one."
			return
		else
			export_tax_rate = input(H, "Set the export tax rate: (0%-100%)") as num
			export_tax_rate = Clamp(export_tax_rate, 0, 100)
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
