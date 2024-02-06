/obj/structure/supply_radio
	name = "long range supply radio"
	desc = "Use this to request supplies to be delivered to the city."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supply_radio"
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
	var/list/civ_catalogue = list( //type (governor/merchant/all), name, path, price
		list("wood crate", /obj/structure/closet/crate/wood,50),
		list("iron crate", /obj/structure/closet/crate/iron,50),
		list("glass crate", /obj/structure/closet/crate/glass,50),
		list("stone crate", /obj/structure/closet/crate/stone,50),
		list("vegetables crate", /obj/structure/closet/crate/rations/vegetables,30),
		list("fruits crate", /obj/structure/closet/crate/rations/fruits,30),
		list("biscuits crate", /obj/structure/closet/crate/rations/biscuits,30),
		list("beer crate", /obj/structure/closet/crate/rations/beer,30),
		list("ale crate", /obj/structure/closet/crate/rations/ale,30),
		list("cow", /mob/living/simple_animal/cattle/cow,150),
		list("bull", /mob/living/simple_animal/cattle/bull,150),
		list("sheep ram", /mob/living/simple_animal/sheep,80),
		list("sheep ewe", /mob/living/simple_animal/sheep/female,80),
		list("pig boar", /mob/living/simple_animal/pig_boar,100),
		list("pig gilt", /mob/living/simple_animal/pig_gilt,100),
		list("hen", /mob/living/simple_animal/chicken,50),
		list("rooster", /mob/living/simple_animal/rooster,50),
		list("horse", /mob/living/simple_animal/horse,200),
		list("brick crate", /obj/structure/closet/crate/brick,100),
		list("medical supplies", /obj/item/weapon/storage/firstaid/adv,50)
	)
	var/list/mil_catalogue = list(
		list("gunpowder barrel", /obj/item/weapon/reagent_containers/glass/barrel/gunpowder,25),
		list("sks crate (5)", /obj/structure/closet/crate/pepelsibirsk/sks,500),
		list("akm crate (5)", /obj/structure/closet/crate/pepelsibirsk/akm,1000),
		list("ak-74 crate (5)", /obj/structure/closet/crate/pepelsibirsk/ak74,1200),
		list("svd crate (2)", /obj/structure/closet/crate/pepelsibirsk/svd,1000),
		list("mosin-nagant crate (10)", /obj/structure/closet/crate/pepelsibirsk/mosin,500),
		list("PPSh-41 crate (2)", /obj/structure/closet/crate/pepelsibirsk/ppsh,400),
		list("makarov crate (5)", /obj/structure/closet/crate/pepelsibirsk/makarov,150),
		list("surplus red army uniform crate (5)", /obj/structure/closet/crate/pepelsibirsk/surplus_ww2,200),
		list("afghanka uniform crate (5)", /obj/structure/closet/crate/pepelsibirsk/sov_uniforms,250),
		list("frag grenade crate (12)", /obj/structure/closet/crate/pepelsibirsk/rgd5,800),
		list("7.62x39mm ammunition crate (300)", /obj/structure/closet/crate/pepelsibirsk/seven62x39mm,100),
		list("7.62x54mmR ammunition crate (200)", /obj/structure/closet/crate/pepelsibirsk/seven62x54mmr,100),
		list("9x18mm ammunition crate (240)", /obj/structure/closet/crate/pepelsibirsk/ninex18mm,50),
		list("6B1 vest crate (5)", /obj/structure/closet/crate/pepelsibirsk/sixb1,300),
		list("6B2 vest crate (5)", /obj/structure/closet/crate/pepelsibirsk/sixb2,1000)
	)

/obj/structure/supply_radio/New()
	src.import_tax_rate = global.global_import_tax
	return ..()


/obj/structure/supply_radio/attack_hand(var/mob/living/human/user as mob)
	var/list/final_list = list()
	var/money_string = "rubles"
	var/list/display = list ()//The products to be displayed, includes name of crate and price
	
	var/choice = WWinput(user, "Pick a supplier:", "Pepelsibirsk 1 (MIL)", "Narodnyygorod (CIV)", "Cancel", display)

	if (choice == "Cancel")
		return
	else
		if (choice == "Pepelsibirsk 1 (MIL)")
			if (mil_relations <= 25 )
				src.say("Get the fuck off our radio frequency before we wipe you off the face of the Earth, you dishonourable, thieving bastards.")
				user << "Your relations with this faction are too low!"
			else
				var/list/choicename = splittext(choice, " - ")
				for(var/list/i in mil_catalogue)
					if (i[2]== choicename[1])
						final_list = i
						world.log << "[final_list], [final_list[1]], [final_list[2]]"
						break
			return
		else if (choice == "Narodnyygorod (CIV)")
			if (civ_relations <= 25 )
				src.say("Chert voz'mi! Go fuck yourselves.")
				user << "Your relations with this faction are too low!"
			else
				var/list/choicename = splittext(choice, " - ")
				for(var/list/i in civ_catalogue)
					if (i[2]== choicename[1])
						final_list = i
						world.log << "[final_list], [final_list[1]], [final_list[2]]"
						break
			return
		else
			user << "Uh oh - something went wrong! Ping an admin!"
			return

	if (isemptylist(final_list))
		user << "Uh oh - something went wrong! Ping an admin!"
		return
	if(final_list[4] > money)
		user << "You don't have enough money to buy that crate!"
// giving change back
		if (money > 0)
			if((round(money) >= 1))
				new/obj/item/stack/money/rubles(loc, round(money))		//Rubles
			if (((money) - round(money)) > 0)
				new/obj/item/stack/money/coppercoin(loc, round(((money) - round(money)), 0.01) * 100)  //This should never happen, but just in case
			money = 0
			return
	else if (final_cost <= money)
		if (choice == "Pepelsibirsk 1 (MIL)")
			mil_relations += final_cost*0.02
			return
		else if (choice == "Narodnyygorod (CIV)")
			civ_relations += final_cost*0.02
			return
		else
			user << "Uh oh - something went wrong! Ping an admin!"
			return
		money -= final_cost
		src.say("Order received. Have a good day, comrades.")
		user << "Your crate will arrive soon at the far northern parking lot."
		spawn(600)
			var/list/turfs = list()
			if (faction_treasury != "craftable")
				turfs = latejoin_turfs[factionarea]
			else
				turfs = list(get_turf(locate(x,y+1,z)))
			var/spawnpoint
			spawnpoint = pick(turfs)
			var/tpath = final_list[3]
			new tpath(get_turf(spawnpoint))
			user << "A shipment has arrived."

/obj/structure/supply_radio/attackby(var/obj/item/stack/W as obj, var/mob/living/human/H as mob)
	if (W.amount && istype(W, /obj/item/stack/money))
		money += W.value*W.amount
		qdel(W)
		return
	else
		H << "You need to use rubles."
		return


/obj/structure/export_radio
	name = "long range export radio"
	desc = "Use this to export resources."
	icon = 'icons/obj/structures.dmi'
	icon_state = "export_radio"
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

/obj/structure/export_radio/New()
	src.export_tax_rate = global.global_export_tax
	return ..()

/obj/structure/export_radio/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	New() //Updating the export tax
	if (W.value == 0)
		H << "There is no demand for this item."
		return
	else
		if (civ_relations >= 25)
			if (istype(W) && done == FALSE)
				done = TRUE
				marketval = W.value + rand(-round(W.value/10),round(W.value/10))
				moneyin = marketval*W.amount-((marketval*W.amount)*(export_tax_rate/100))
				var/exportChoice
				exportChoice = WWinput(H, "Sell the whole stack for [moneyin] rubles?", "Exporting", "Yes", list("Yes", "No"))
				if (exportChoice == "Yes" && W)
					if (W && marketval > 0)
						if(round(moneyin) >= 1)
							new/obj/item/stack/money/rubles(loc, round(moneyin))		// Rubles
						if (((moneyin) - round(moneyin)) > 0)
							new/obj/item/stack/money/cents(loc, round(((moneyin) - round(moneyin)), 0.01) * 100)  //copper coins, should never happen
						else
							return
						qdel(W)
						marketval = 0
						done = FALSE
						return
				else
					marketval = 0
					done = FALSE
					return
		else
			src.say("Oh god, not you again... Kindly, fuck off. We don't want your business anymore.")
			user << "Your relations with this faction are too low!"
			return