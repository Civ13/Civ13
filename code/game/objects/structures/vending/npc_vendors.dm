/obj/structure/npc_vendor
	name = "NPC (Do not use!)"
	icon = 'icons/mob/npcs.dmi'
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE

/obj/item/weapon/plastique/afterattack(atom/movable/target, mob/user, flag)
	if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
		if (istype(target, /obj/structure/npc_vendor) || istype(target, /obj/structure/closet/safe))
			return
	..()

/obj/structure/npc_vendor/smuggler // To be converted to a proper NPC
	name = "Omar the Smuggler"
	desc = "You've got money? I've got goods."
	icon_state = "afghdrug"

/obj/structure/npc_vendor/smuggler/attackby(obj/item/W as obj, mob/living/human/user as mob)
	var/smuggler_cooldown = 0
	if (user.civilization == "Sheriff Office" || user.civilization == "Government")
		to_chat(user, "Good day, everything is okay and running smoothly.")
		return
	if (user.civilization == "Paramedics")
		to_chat(user, "Keep up the good work, no one here is injured, see you.")
		return 
	if (world.time <= smuggler_cooldown)
		to_chat(user, "No shipments available, come back later.")
		return
	if (istype(W, /obj/item/stack/money))
		var/obj/item/stack/money/M = W
		if (M && M.value*M.amount < 500*4)
			to_chat(user, SPAN_WARNING("Not enough money! You need to give me at least 500 dollars."))
			return
		M.amount-=500/5
		if (M.amount <= 0)
			qdel(M)
		to_chat(user, "A shipment will arrive soon at the Docks. Better be ready.")
		if (prob(50))
			for (var/mob/living/human/H in player_list)
				if (H.civilization == "Goldstein Solutions" || H.civilization == "Kogama Kraftsmen" || H.civilization ==  "Rednikov Industries" || H.civilization ==  "Giovanni Blu Stocks")
					if (H.civilization != user.civilization)
						to_chat(H, "<b>Word of mouth goes that a shipment will arrive soon at the docks. Might be worth intercepting it.</b>")
			if (prob(50))
				spawn(rand(300,1800))
					global_broadcast(FREQP,"<big>A confidential informant gave away that a suspicious shipment will arrive soon at the docks!</big>")
		smuggler_cooldown = world.time + 1800
		spawn(rand(900,1800))
			if (prob(90))
				var/crate_group = rand(1,3)
				var/crate_type = rand(1,3)
				switch(crate_group)
					if (1)
						switch(crate_type)
							if (1)
								new /obj/structure/largecrate/smuggler/crystals(get_turf(locate(84,6,1)))
							if (2)
								new /obj/structure/largecrate/smuggler/disks(get_turf(locate(84,6,1)))
							if (3)
								new /obj/structure/largecrate/smuggler/fake_disks(get_turf(locate(84,6,1)))
					if (2)
						switch(crate_type)
							if (1)
								new /obj/structure/largecrate/smuggler/makarov(get_turf(locate(84,6,1)))
							if (2)
								new /obj/structure/largecrate/smuggler/magnum44(get_turf(locate(84,6,1)))
							if (3)
								new /obj/structure/largecrate/smuggler/m1911(get_turf(locate(84,6,1)))
					if (3)
						switch(crate_type)
							if (1)
								new /obj/structure/largecrate/smuggler/skorpion(get_turf(locate(84,6,1)))
							if (2)
								new /obj/structure/largecrate/smuggler/uzi(get_turf(locate(84,6,1)))
							if (3)
								new /obj/structure/largecrate/smuggler/mac10(get_turf(locate(84,6,1)))
			else
				if (prob(70))
					new /obj/structure/largecrate/smuggler/cocaine(get_turf(locate(84,6,1)))
				else
					new /obj/structure/largecrate/smuggler/ak47(get_turf(locate(84,6,1)))

// Biker NPC (Drugs and weapons)

/obj/structure/npc_vendor/biker // To be converted to a proper NPC
	name = "Bruce the Biker"
	desc = "You've got drugs? I've got money."
	icon_state = "bruce"
	var/biker_cooldown = 0
	var/buying_price1 = 50
	var/buying_price2 = 65
	var/list/reputation = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,)

/obj/structure/npc_vendor/biker/attack_hand(mob/living/human/user as mob)
	var/optlist = list("Cancel","Sell drugs","Buy weapons")
	if (reputation[user.civilization] < 0)
		to_chat(user, "\icon[src] I'm not dealing with you punks anymore, get the fuck out of here.")
		return
	if (user.civilization == "Sheriff Office" || user.civilization == "Paramedics" || user.civilization == "Government")
		if (user.civilization == "Sheriff Office")
			to_chat(user, "\icon[src] Get off my property, pig.")
		else
			to_chat(user, "\icon[src] Sorry, who the fuck are you? Get outta here!")
		return
	if (world.time <= biker_cooldown)
		to_chat(user, "\icon[src] My boys are busy for now. Come back later.")
		return
	var/choice1 = WWinput(user, "What do you need?", "Bruce the Biker", "Cancel", optlist)
	switch(choice1)
		if ("Cancel")
			to_chat(user, "\icon[src] Don't waste my time again.")
			return
		if ("Sell drugs")
			if (istype(user.get_active_hand(),/obj/item/weapon/reagent_containers/pill/) || istype(user.get_inactive_hand(),/obj/item/weapon/reagent_containers/pill/))
				var/obj/item/weapon/reagent_containers/pill/P
				if (istype(user.get_active_hand(),/obj/item/weapon/reagent_containers/pill/))
					P = user.get_active_hand()
				else if (istype(user.get_inactive_hand(),/obj/item/weapon/reagent_containers/pill/))
					P = user.get_inactive_hand()
				if (P && P.reagents.has_reagent("methamphetamine") && !P.reagents.has_reagent("cocaine"))
					if (P.reagents.get_reagent_amount("methamphetamine")>= 10)
						qdel(P)
						var/obj/item/stack/money/dollar/D = new /obj/item/stack/money/dollar(null)
						D.amount = (buying_price1+src.reputation[user.civilization])/(D.value/5)
						if (D.amount == 0)
							qdel(D)
						user.put_in_hands(D)
						to_chat(user, "\icon[src] Here, there's more where it came from.")
						src.reputation[user.civilization] += 2
						if (prob(50))
							if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
								var/obj/map_metadata/art_of_the_deal/AD = map
								AD.heat[user.civilization] += 1
						return
					else
						to_chat(user, pick("\icon[src] You've got some nerve trying to pass off this cut crap as meth! Fuck off!","What the hell is this weak shit? Even my grandmother's painkillers pack more punch!"))
						return
				else if (P && P.reagents.has_reagent("cocaine") && !P.reagents.has_reagent("methamphetamine"))
					if (P.reagents.get_reagent_amount("cocaine")>= 25)
						qdel(P)
						var/obj/item/stack/money/dollar/D = new /obj/item/stack/money/dollar(null)
						D.amount = (buying_price2+min(src.reputation[user.civilization],15))/(D.value/5)
						if (D.amount == 0)
							qdel(D)
						user.put_in_hands(D)
						to_chat(user, "\icon[src] Here, there's more where it came from.")
						src.reputation[user.civilization] += 1
						if (prob(50))
							if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
								var/obj/map_metadata/art_of_the_deal/AD = map
								AD.heat[user.civilization] += 1
						return
					else
						to_chat(user, "\icon[src] What's that? Babypowder? Your shit's cut! Fuck off!")
						return
				else if (P && P.reagents.has_reagent("cocaine") && P.reagents.has_reagent("methamphetamine"))
					to_chat(user, "\icon[src] Are you trying to get my clients killed? Tell your cook to separate his shit.")
					return
				else if (P && P.reagents.has_reagent("crack"))
					to_chat(user, "\icon[src] Fuck off, my boys don't mess with that shit.")
					return
			else if (istype(user.get_active_hand(),/obj/item/weapon/reagent_containers/cocaineblock/) || istype(user.get_inactive_hand(),/obj/item/weapon/reagent_containers/cocaineblock/))
				var/obj/item/weapon/reagent_containers/cocaineblock/CB
				if (istype(user.get_active_hand(),/obj/item/weapon/reagent_containers/cocaineblock))
					CB = user.get_active_hand()
				else if (istype(user.get_inactive_hand(),/obj/item/weapon/reagent_containers/cocaineblock))
					CB = user.get_inactive_hand()
				qdel(CB)
				var/obj/item/stack/money/dollar/D = new /obj/item/stack/money/dollar(null)
				D.amount = ((buying_price2+src.reputation[user.civilization])*20)/(D.value/5)
				if (D.amount == 0)
					qdel(D)
				user.put_in_hands(D)
				to_chat(user, "\icon[src] Holy shit, now that's some product. I'll need some time to distribute it.")
				biker_cooldown = world.time + 6000
				if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
					var/obj/map_metadata/art_of_the_deal/AD = map
					AD.heat[user.civilization] += 15
				return
			else
				to_chat(user, "\icon[src] You need have the drugs in one of your hands.")
				return
		if ("Buy weapons")
			//path, price
			var/weapons = list("Cancel","M1911","Smith & Wesson Model 30")
			var/choice2 = WWinput(user, "What do you need?", "Bruce the Biker", "Cancel", weapons)
			var/obj/item/stack/money/M
			switch(choice2)
				if ("Cancel")
					to_chat(user, "\icon[src] Don't bother wasting my time again.")
					return
				if ("Smith & Wesson Model 30")
					if (istype(user.get_active_hand(),/obj/item/stack/money) || istype(user.get_inactive_hand(),/obj/item/stack/money))
						if (istype(user.get_active_hand(),/obj/item/stack/money))
							M = user.get_active_hand()
						else if (istype(user.get_inactive_hand(),/obj/item/stack/money))
							M = user.get_inactive_hand()
						if(M.value*M.amount < 350*4)
							to_chat(user, "\icon[src] Not enough money. You need 350 dollars.")
							return
						M.amount -= 350/5
						if (M.amount <= 0)
							qdel(M)
						var/obj/item/weapon/gun/projectile/revolver/smithwesson/SW = new /obj/item/weapon/gun/projectile/revolver/smithwesson(null)
						SW.serial = ""
						new /obj/item/ammo_magazine/c32(user.loc)
						user.put_in_hands(SW)
						if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
							var/obj/map_metadata/art_of_the_deal/AD = map
							AD.heat[user.civilization] += 2
							if (AD.heat[user.civilization] >= 40)
								to_chat(user, "\icon[src] You better run fast before the feds get you.")
								spawn(rand(300,600))
									global_broadcast(FREQP,"<big>The ATF reports that [user.real_name] may have acquired an illegal firearm. Detain and search the suspect as soon as possible.</big>")
						return
				if ("M1911")
					if (istype(user.get_active_hand(),/obj/item/stack/money) || istype(user.get_inactive_hand(),/obj/item/stack/money))
						if (istype(user.get_active_hand(),/obj/item/stack/money))
							M = user.get_active_hand()
						else if (istype(user.get_inactive_hand(),/obj/item/stack/money))
							M = user.get_inactive_hand()
						if(M.value*M.amount < 700*4)
							to_chat(user, "\icon[src] Not enough money. You need 700 dollars.")
							return
						M.amount -= 700/5
						if (M.amount <= 0)
							qdel(M)
						var/obj/item/weapon/gun/projectile/pistol/m1911/P = new /obj/item/weapon/gun/projectile/pistol/m1911(null)
						P.serial = ""
						new /obj/item/ammo_magazine/m1911(user.loc)
						new /obj/item/ammo_magazine/m1911(user.loc)
						user.put_in_hands(P)
						if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
							var/obj/map_metadata/art_of_the_deal/AD = map
							AD.heat[user.civilization] += 2
							if (AD.heat[user.civilization] >= 40)
								to_chat(user, "\icon[src] You better run fast before the feds get you.")
								spawn(rand(300,600))
									global_broadcast(FREQP,"<big>The ATF reports that [user.real_name] may have acquired an illegal firearm. Detain and search the suspect as soon as possible.</big>")
						return

/obj/structure/npc_vendor/biker/attackby(obj/item/W as obj, mob/living/human/user as mob)
	return

// Cartel NPC (Cocaine)

/obj/structure/npc_vendor/cartel
	name = "Diego 'El Diablo' Morales"
	desc = "Plata or plomo? I've got the product."
	icon_state = "cartel"
	var/cartel_cooldown = 0
	var/heat_message_cooldown = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,)
	var/list/reputation = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,)
	var/list/buy_list = list("Cancel","1 gram","10 grams","a block")

/obj/structure/npc_vendor/cartel/attackby(obj/item/W as obj, mob/living/human/user as mob)
	if (reputation[user.civilization] < 0)
		to_chat(user, "\icon[src] Don't waste my time, find another hole to climb into, sapo.")
		return
	if (user.civilization == "Sheriff Office" || user.civilization == "Paramedics" || user.civilization == "Government")
		to_chat(user, "\icon[src] I have nothing to tell you.")
		return
	if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
		var/obj/map_metadata/art_of_the_deal/AD = map
		if (AD.heat[user.civilization] >= 35 && AD.heat[user.civilization] < 40)
			to_chat(user, SPAN_NOTICE("\icon[src] You should start being more careful with the produce. Maybe someone can help you get under the radar."))
		if (AD.heat[user.civilization] >= 40)
			to_chat(user, SPAN_WARNING("\icon[src] Chico, you'll get us busted by the feds. They are watching you close!"))
			if (prob(80) && world.time >= heat_message_cooldown[user.civilization])
				spawn(300)
					if (prob(50))
						global_broadcast(FREQP,"<big> The DEA informs the local authorities that the company [user.civilization] <b>may be</b> involved in drug trafficking. Pay close attention to their activities.</big>")
					else
						global_broadcast(FREQP,"<big> The DEA informs the local authorities that [user.real_name], working for [user.civilization], <b>may be</b> involved in drug trafficking. Surveillance of the individual is required, detain and search if necessary.</big>")
					heat_message_cooldown[user.civilization] = world.time + 1200
	if (istype(W, /obj/item/stack/money))
		var/obj/item/stack/money/M = W
		switch (reputation[user.civilization])
			if (0 to 14)
				buy_list = list("Cancel","1 gram")
			if (15 to 29)
				buy_list = list("Cancel","1 gram","10 grams")
			if (30 to INFINITY)
				buy_list = list("Cancel","1 gram","10 grams","a block")
		var/choice = WWinput(user, "What do you want to buy?", "Cartel Member", "Cancel", buy_list)
		if (!choice)
			return
		switch (choice)
			if ("Cancel")
				return
			if ("1 gram")
				var/gram_price = 70
				if (reputation[user.civilization] >= 10)
					gram_price = max(50, 70-Floor(reputation[user.civilization]/2))
				if (M && M.value*M.amount >= gram_price*4)
					M.amount -= gram_price/5
					if (M.amount <= 0)
						qdel(M)
					var/obj/item/weapon/reagent_containers/pill/cocaine/one_g = new /obj/item/weapon/reagent_containers/pill/cocaine(null)
					user.put_in_hands(one_g)
					if (prob(50))
						reputation[user.civilization] += 1
					if (prob(40))
						if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
							var/obj/map_metadata/art_of_the_deal/AD = map
							AD.heat[user.civilization] += 1
				else
					to_chat(user, "\icon[src] Not enough money, maricon.")
			if ("10 grams")
				var/tenner_price = 600
				if (reputation[user.civilization] >= 20)
					tenner_price = max(500, tenner_price-(2*reputation[user.civilization]))
				if (M && M.value*M.amount >= tenner_price*4)
					M.amount-=tenner_price/5
					if (M.amount <= 0)
						qdel(M)
					var/obj/item/weapon/storage/briefcase/cocaine_10/briefcase = new /obj/item/weapon/storage/briefcase/cocaine_10(null)
					user.put_in_hands(briefcase)
					reputation[user.civilization] += 1
					if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
						var/obj/map_metadata/art_of_the_deal/AD = map
						AD.heat[user.civilization] += 5
				else
					to_chat(user, "\icon[src] Not enough money, maricon.")
			if ("a block")
				if (M && M.value*M.amount >= 1200*4)
					M.amount-=1200/5
					if (M.amount <= 0)
						qdel(M)
					var/obj/item/weapon/reagent_containers/cocaineblock/block = new /obj/item/weapon/reagent_containers/cocaineblock/(null)
					user.put_in_hands(block)
					if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
						var/obj/map_metadata/art_of_the_deal/AD = map
						AD.heat[user.civilization] += 10
				else
					to_chat(user, "\icon[src] Not enough money, maricon.")
		return
	else
		return

/obj/item/weapon/storage/briefcase/cocaine_10/New()
	..()
	for (var/i = 1; i<=10;i++)
		new /obj/item/weapon/reagent_containers/pill/cocaine(src)

// Mr. White (Chemicals and explosives)

/obj/structure/npc_vendor/walter
	name = "Mr. White"
	desc = "A respectable chemistry teacher."
	icon_state = "waltuh"
	var/walter_cooldown = 0
	var/list/reputation = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,)
	var/list/option_list = list("Cancel","Buy chemicals","Buy explosives")
	var/list/chemical_list = list("Cancel","Diethylamine","Acetone","Potassium Chloride","Carbon")

/obj/structure/npc_vendor/walter/attack_hand(mob/living/human/user as mob)
	if (reputation[user.civilization] < 0)
		to_chat(user, "\icon[src] Don't waste my time.")
		return
	if (user.civilization == "Sheriff Office" || user.civilization == "Government")
		to_chat(user, "\icon[src] I have nothing to tell you.")
		return
	if (world.time <= walter_cooldown)
		to_chat(user, "\icon[src] I need more time to cook. Come back later.")
		return
	var/obj/item/stack/money/M
	if (istype(user.get_active_hand(),/obj/item/stack/money) || istype(user.get_inactive_hand(),/obj/item/stack/money))
		if (istype(user.get_active_hand(),/obj/item/stack/money))
			M = user.get_active_hand()
		else if (istype(user.get_inactive_hand(),/obj/item/stack/money))
			M = user.get_inactive_hand()
	var/choice1 = WWinput(user, "What do you need?", "Mr. White", "Cancel", option_list)
	switch(choice1)
		if ("Cancel")
			return
		if ("Buy chemicals")
			var/chemical_price = 100
			if (!M || M.value*M.amount < chemical_price*4)
				to_chat(user, "\icon[src] You need [chemical_price] dollars in one of your hands.")
				return
			var/choice2 = WWinput(user, "What kind of chemicals?", "Mr. White", "Cancel", chemical_list)
			switch(choice2)
				if ("Cancel")
					return
				if ("Diethylamine")
					new /obj/item/weapon/reagent_containers/glass/bottle/diethylamine(user.loc)
				if ("Acetone")
					new /obj/item/weapon/reagent_containers/glass/bottle/acetone(user.loc)
				if ("Potassium Chloride")
					new /obj/item/weapon/reagent_containers/glass/bottle/potassium_chloride(user.loc)
				if ("Carbon")
					new /obj/item/weapon/reagent_containers/glass/bottle/carbon(user.loc)
			M.amount -= chemical_price/5
			if (M.amount <= 0)
				qdel(M)
			walter_cooldown = world.time + 600
			return
		if ("Buy explosives")
			var/c4_price = 900
			if (!M || (M && M.value*M.amount < c4_price*4))
				to_chat(user, "\icon[src] You need [c4_price] dollars in one of your hands.")
				return
			M.amount -= c4_price/5
			if (M.amount <= 0)
				qdel(M)
			new /obj/item/weapon/plastique/c4(user.loc)
			if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
				var/obj/map_metadata/art_of_the_deal/AD = map
				AD.heat[user.civilization] += 25
				if (AD.heat[user.civilization] >= 40)
					to_chat(user, "\icon[src] You better run fast before the feds get you.")
				spawn(300)
					global_broadcast(FREQP,"<big>The ATF reports that [user.real_name] may have acquired an explosive device.</big>")
			return

/obj/structure/npc_vendor/fed
	name = "Agent Harrison Yates"
	desc = "A federal agent with questionable morality."
	icon_state = "narc"
	var/list/option_list_comp = list("Cancel","Bribe","Reduce heat")
	var/list/option_list_police = list("Cancel","Get Intel")
	var/list/reputation = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,)
	var/intel_cooldown = 0
	var/heat_cooldown = 0
	light_range = 2

/obj/structure/npc_vendor/fed/attack_hand(mob/living/human/user as mob)
	if (user.civilization == "Paramedics" || user.civilization == "none")
		return
	var/obj/item/stack/money/M
	if (istype(user.get_active_hand(),/obj/item/stack/money) || istype(user.get_inactive_hand(),/obj/item/stack/money))
		if (istype(user.get_active_hand(),/obj/item/stack/money))
			M = user.get_active_hand()
		else if (istype(user.get_inactive_hand(),/obj/item/stack/money))
			M = user.get_inactive_hand()
	if (user.civilization != "Sheriff Office" && user.civilization != "Government")
		var/choice1 = WWinput(user, "What do you need?", "Agent Harrison Yates", "Cancel", option_list_comp)
		switch(choice1)
			if ("Cancel")
				return
			if ("Bribe")
				if (reputation[user.civilization] < 0)
					to_chat(user, "\icon[src] Don't waste my time. I can't do anything for you anymore.")
					return
				var/bribe_price = 500
				if (!M || M.value*M.amount < bribe_price*4)
					to_chat(user, "\icon[src] You need at least [bribe_price] dollars in one of your hands.")
					return
				M.amount -= bribe_price/5
				if (M.amount <= 0)
					qdel(M)
				reputation[user.civilization] += 1
				to_chat(user, "\icon[src] Pleasure doing business with you.")
			if ("Reduce heat")
				if (reputation[user.civilization] == 0)
					to_chat(user, "\icon[src] I will need a little sign of appreciation for this, if you know what I mean.")
					return
				if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
					var/obj/map_metadata/art_of_the_deal/AD = map
					var/heat_price = ceil(200/reputation[user.civilization])
					if (AD.heat[user.civilization] == 0)
						to_chat(user, "\icon[src] You gentlemen are off the radar, for now.")
						return
					if (world.time <= heat_cooldown)
						to_chat(user, "\icon[src] Not so fast, pal. I can't just temper with evidence that fast. That's not your sister.")
						return
					var/evidence_amount = list("Cancel","1","5","10")
					var/heat_choice = WWinput(user, "Your company has currently [AD.heat[user.civilization]] evidence files gathered against it. How many do you want me to get rid off?","Agent Harrison Yates", "Cancel", evidence_amount)
					switch(heat_choice)
						if ("Cancel")
							return
						if ("1")
							if (!M || M.value*M.amount < heat_price*4)
								to_chat(user, "\icon[src] You need at least [heat_price] dollars in one of your hands.")
								return
							M.amount -= heat_price/5
							if (M.amount <= 0)
								qdel(M)
							AD.heat[user.civilization] -= 1
							if (AD.heat[user.civilization] < 0)
								AD.heat[user.civilization] = 0
						if ("5")
							if (!M || M.value*M.amount < (5*heat_price)*4)
								to_chat(user, "\icon[src] You need at least [5*heat_price] dollars in one of your hands.")
								return
							M.amount -= (5*heat_price)/5
							if (M.amount <= 0)
								qdel(M)
							AD.heat[user.civilization] -= 5
							if (AD.heat[user.civilization] < 0)
								AD.heat[user.civilization] = 0
							heat_cooldown = world.time + 600
						if ("10")
							if (!M || M.value*M.amount < (10*heat_price)*4)
								to_chat(user, "\icon[src] You need at least [10*heat_price] dollars in one of your hands.")
								return
							M.amount -= (10*heat_price)/5
							if (M.amount <= 0)
								qdel(M)
							AD.heat[user.civilization] -= 10
							if (AD.heat[user.civilization] < 0)
								AD.heat[user.civilization] = 0
							heat_cooldown = world.time + 1200
	else
		var/choice2 = WWinput(user, "What do you need?", "Agent Harrison Yates", "Cancel", option_list_police)
		switch (choice2)
			if ("Cancel")
				return
			if ("Get Intel")
				if (world.time <= intel_cooldown)
					to_chat(user, "\icon[src] I need more time to investigate. Come back later.")
					return
				var/intel_type = list("Cancel","Narcotics","Illegal Firearms","Disks")
				var/intel_choice = WWinput(user, "What do you need?", "Agent Harrison Yates", "Cancel", intel_type)
				switch(intel_choice)
					if ("Cancel")
						return
					if ("Narcotics")
						var/count_c = 0
						var/count_m = 0
						for (var/obj/item/weapon/reagent_containers/pill/P in world)
							if (P)
								if (P.reagents.has_reagent("cocaine") && P.reagents.get_reagent_amount("cocaine")>= 25)
									count_c++
								if (P.reagents.has_reagent("methamphetamine") && P.reagents.get_reagent_amount("methamphetamine")>= 10)
									count_m++
						to_chat(user, "\icon[src] There's currently [count_c] grams of cocaine and [count_m] grams of methamphtamine in circulation right now.")
						var/count_b = 0
						for (var/obj/item/weapon/reagent_containers/cocaineblock/block in world)
							if (block)
								count_b++
						to_chat(user, "\icon[src] There's currently [count_b] blocks of cocaine in circulation.")
					if ("Illegal Firearms")
						var/count_f = 0
						var/count_bomb = 0
						for (var/obj/item/weapon/gun/projectile/firearm in world)
							if (firearm.serial == "")
								count_f++
						for (var/obj/item/weapon/plastique/c4/bomb in world)
							if (bomb)
								count_bomb++
						to_chat(user, "\icon[src] There's [count_f] illegal firearms and [count_bomb] explosives in circulation right now.")
					if ("Disks")
						var/count_d = 0
						for (var/obj/item/weapon/disk/D in world)
							if (D.faction)
								count_d++
						to_chat(user, "\icon[src] There's [count_d] illegal disks in circulation right now.")
				intel_cooldown = world.time + 4800
				return

/obj/structure/npc_vendor/bouncer
	name = "Marcellus"
	desc = "Your \"friendly\" neighborhood bouncer. Your wife loves him."
	icon_state = "bouncer"

/obj/structure/npc_vendor/bouncer/attack_hand(mob/living/human/user as mob)
	to_chat(user, "\icon[src] No weapons, no drugs inside the club, else I'll make you drop the soap.")
	return

/obj/structure/npc_vendor/big_lenny
	name = "Big Lenny"
	desc = "A barber that likes to relax."
	icon_state = "big_lenny"

/obj/structure/npc_vendor/big_lenny/attack_hand(mob/living/human/user as mob)
	to_chat(user, "\icon[src] Shiieeet, come back another time, I'm taking a nap.")
	return