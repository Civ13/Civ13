/obj/map_metadata/art_of_the_deal
	ID = MAP_THE_ART_OF_THE_DEAL
	title = "The Art of the Deal"
	lobby_icon = 'icons/lobby/taotd.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one, /area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 3000
	is_singlefaction = TRUE
	has_hunger = TRUE
	no_winner = "The fighting is still going."
	songs = list(
		"Woke Up This Morning:1" = 'sound/music/woke_up_this_morning.ogg',)
	faction_organization = list(
		CIVILIAN)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british/ship, //it isnt in the map so nobody wins by capture
		)
	age = "1994"
	ordinal_age = 8
	var/fac_nr = 3
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "The Deal"
	mission_start_message = "<font size=4><b>4</b> corporations are fighting for control of the disks.<br>Please read the manual: https://civ13.github.io/civ13-wiki/The_Art_of_the_Deal</font>"
	var/winner_name = "Unknown"
	var/list/winner_ckeys = list()
	faction1 = CIVILIAN
	faction2 = PIRATES
	gamemode = "Negotiations"
	respawn_delay = 3000

	scores = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,
		"Sheriff Office" = 0,)

	required_players = 6
	var/list/delivery_locations = list()
	var/list/delivery_orders = list()
	var/maxpoints = 4000
	grace_wall_timer = 3000
	availablefactions = list("Goldstein Solutions", "Kogama Kraftsmen", "Rednikov Industries", "Giovanni Blu Stocks")
	var/list/heat = list("Rednikov Industries" = 0, "Giovanni Blu Stocks" = 0, "Kogama Kraftsmen" = 0, "Goldstein Solutions" = 0)

/obj/map_metadata/art_of_the_deal/update_win_condition()
	if (win_condition_spam_check)
		return FALSE
	for(var/obj/structure/closet/safe/SF in world)
		if (SF.faction)
			var/list/tlist = list(SF.faction,0)
			for(var/obj/item/I in SF)
				if (istype(I, /obj/item/stack/money))
					var/obj/item/stack/money/M = I
					tlist[2]+=M.amount*M.value/4
			tlist[2] += scores[SF.faction]
			if (tlist[2] >= maxpoints)
				var/message = "[tlist[1]] has reached a valuation over [maxpoints] and won!"
				to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))
				win_condition_spam_check = TRUE
				ticker.finished = TRUE
				return TRUE

/obj/map_metadata/art_of_the_deal/New()
	..()
	spawn(3000)
		score()
	var/newnamea = list("Rednikov Industries" = list(0,0,0,null,0,"sun","#7F0000","#7F7F7F",0,0))
	var/newnameb = list("Giovanni Blu Stocks" = list(0,0,0,null,0,"sun","#00007F","#7F7F7F",0,0))
	var/newnamec = list("Kogama Kraftsmen" = list(0,0,0,null,0,"sun","#007F00","#7F7F7F",0,0))
	var/newnamed = list("Goldstein Solutions" = list(0,0,0,null,0,"sun","#E5E500","#7F7F7F",0,0))
	var/newnamee = list("Sheriff Office" = list(0,0,0,null,0,"star","#51513f","#00007F",0,0))
	var/newnamef = list("Paramedics" = list(0,0,0,null,0,"cross","#7F0000","#FFFFFF",0,0))
	var/newnameg = list("Government" = list(0,0,0,null,0,"star","#E3E3E3", "#3e57a8",0,0))
	custom_civs += newnamea
	custom_civs += newnameb
	custom_civs += newnamec
	custom_civs += newnamed
	custom_civs += newnamee
	custom_civs += newnamef
	custom_civs += newnameg
	spawn(100)
		load_new_recipes("config/crafting/material_recipes_camp.txt")
		override_global_recipes = "camp"
	spawn(15000)
		spawn_disks(TRUE)
	spawn(100)
		refill_marketplace(TRUE)
	spawn(150)
		assign_delivery_zones()
		send_buy_orders()
								//id = seller, obj, amt, price, type, id, active
		map.globalmarketplace += list("red1" = list("Rednikov Industries",null,1,1000+scores["Rednikov Industries"],"bank","red1",1))
		map.globalmarketplace += list("gio1" = list("Giovanni Blu Stocks",null,1,1000+scores["Giovanni Blu Stocks"],"bank","gio1",1))
		map.globalmarketplace += list("green1" = list("Kogama Kraftsmen",null,1,1000+scores["Kogama Krafsmen"],"bank","green1",1))
		map.globalmarketplace += list("yellow1" = list("Goldstein Solutions",null,1,1000+scores["Goldstein Solutions"],"bank","yellow1",1))

/obj/map_metadata/art_of_the_deal/proc/assign_delivery_zones()
	for(var/turf/floor/delivery/D in turfs)
		var/list/tlist = list(list(D.name,D.x,D.y,D.get_coded_loc()))
		delivery_locations += tlist
/obj/map_metadata/art_of_the_deal/proc/send_buy_orders()
	for(var/i in list("mail@kogama.ug","mail@rednikov.ug","mail@goldstein.ug","mail@blu.ug"))
		var/list/tloc = pick(delivery_locations)
		var/nr = pick(3,7)
		var/comps = ""
		switch(i)
			if ("mail@kogama.ug")
				comps = pick("GBSA-1994 chip","RDKV S-445 chip","GS-IC-M3 chip")
			if ("mail@rednikov.ug")
				comps = pick("GBSA-1994 chip","KOGM S5R1 chip","GS-IC-M3 chip")
			if ("mail@goldstein.ug")
				comps = pick("GBSA-1994 chip","KOGM S5R1 chip","RDKV S-445 chip")
			if ("mail@blu.ug")
				comps = pick("KOGM S5R1 chip","RDKV S-445 chip","GS-IC-M3 chip")
		var/pay = nr*rand(500,1100)
		var/list/tlist = list(list(tloc[2],tloc[3],comps,nr,pay,i)) //x,y,product,amount,payment,faction
		delivery_orders += tlist
		var/needed = "[nr] [comps]s at the [tloc[4]] [tloc[1]] postbox ([tloc[2]],[tloc[3]])"
		var/datum/email/E = new/datum/email
		pay/=4 //convert to dollars
		E.subject = pick("New Order","Delivery Requested","Need Some More","Ordering","URGENT: Order")
		E.sender = "[lowertext(pick(first_names_male))][rand(1,99)]@monkeysoft.ug"
		E.receiver = i
		E.message = pick(
			"Hey man, send [needed], really need it. Is [pay] ok? Will be expecting.<br>kudos from [uppertext(E.sender[1])].",
			"Hope you guys are ok. Need [needed]. ASAP. Will pay [pay]$ for all of it. Yours trully",
			"Hey, need a delivery of [needed] for [pay], thanks.",
			"I heard you can get your hands on something i need. I'll pay you [pay]. Send me [needed].<br>Thanks",
			"Send [needed]. Pay is [pay]$. Discretion as always.<br>-[uppertext(E.sender[1])]",
			)
		E.date = roundduration2text()
		E.read = FALSE
		map.emails[i] += list(E)
	spawn(rand(5000,7000))
		send_buy_orders()
		return

/obj/map_metadata/art_of_the_deal/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_deal)
		. = TRUE
		if (istype(J, /datum/job/civilian/businessman) && !istype(J, /datum/job/civilian/businessman/legitimate) && !istype(J, /datum/job/civilian/businessman/mckellen))
			if(!findtext(J.title, "CEO"))
				. = FALSE
		if (world.time >= 3000)
			if (istype(J, /datum/job/civilian/businessman))
				if(findtext(J.title, "CEO"))
					J.whitelisted = FALSE
		if (clients.len < 14)
			if (J.title == "County Deputy" || J.title == "County Sheriff")
				. = FALSE
		if (clients.len <= 20)
			if (J.title == "Physician" || J.title == "County Judge" || J.title == "Detective")
				. = FALSE
			else if (J.title == "Paramedic")
				J.max_positions = 2
				J.total_positions = 2
			else if (J.title == "Nurse")
				J.max_positions = 1
				J.total_positions = 1
		if (clients.len > 20)
			if (J.title == "Paramedic")
				J.max_positions = 3
				J.total_positions = 3
			else if (J.title == "Nurse")
				J.max_positions = 2
				J.total_positions = 2
		if (clients.len <= 22)
			if (J.title == "Legitimate Business")
				. = FALSE
		if (clients.len <= 30)
			if (J.title == "Mechanic" || J.title == "Homeless Man")
				. = FALSE
		if (clients.len <= 35)
			if (J.title == "McKellen Staff" || J.title == "McKellen Manager")
				. = FALSE
	else
		. = FALSE

/obj/map_metadata/art_of_the_deal/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4><b>The round has started!</b> Players may now cross the invisible wall!</font>"

/obj/map_metadata/art_of_the_deal/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.original_job_title == "Nurse")
				if (world.time >= H.next_gracewall_message)
					to_chat(H, SPAN_WARNING("You cannot leave the hospital area as a nurse."))
					H.next_gracewall_message = world.time + 10
				return TRUE
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.civilization == "Sheriff Office")
				if (!H.is_undercover)
					if (world.time >= H.next_gracewall_message)
						to_chat(H, SPAN_WARNING("You can't go any farther, it's out of your jurisdiction; at least, on duty..."))
						H.next_gracewall_message = world.time + 10
					return TRUE
		return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/art_of_the_deal/proc/spawn_disks(repeat = FALSE)
	for(var/obj/structure/closet/safe/SF in world)
		if (SF.faction)
			switch(SF.faction)
				if ("Rednikov Industries")
					if (SF.opened)
						new/obj/item/weapon/disk/red(SF.loc)
						new/obj/item/weapon/disk/red/fake(SF.loc)
					else
						new/obj/item/weapon/disk/red(SF)
						new/obj/item/weapon/disk/red/fake(SF)
				if ("Giovanni Blu Stocks")
					if (SF.opened)
						new/obj/item/weapon/disk/blue(SF.loc)
						new/obj/item/weapon/disk/blue/fake(SF.loc)
					else
						new/obj/item/weapon/disk/blue(SF)
						new/obj/item/weapon/disk/blue/fake(SF)
				if ("Kogama Kraftsmen")
					if (SF.opened)
						new/obj/item/weapon/disk/green(SF.loc)
						new/obj/item/weapon/disk/green/fake(SF.loc)
					else
						new/obj/item/weapon/disk/green(SF)
						new/obj/item/weapon/disk/green/fake(SF)
				if ("Goldstein Solutions")
					if (SF.opened)
						new/obj/item/weapon/disk/yellow(SF.loc)
						new/obj/item/weapon/disk/yellow/fake(SF.loc)
					else
						new/obj/item/weapon/disk/yellow(SF)
						new/obj/item/weapon/disk/yellow/fake(SF)
	if (repeat)
		spawn(12000)
			spawn_disks(repeat)
	to_chat(world, "<font size=2 color ='yellow'>New disks have arrived at the vaults!</font>")

/obj/map_metadata/art_of_the_deal/proc/refill_marketplace(repeat = FALSE)
	if (precursor_stocks.len >= 4)
		precursor_stocks["galdonium crystals"][1] += 2
		precursor_stocks["galdonium crystals"][2] = min(60,round(precursor_stocks["galdonium crystals"][2]*0.9))
		precursor_stocks["indigon crystals"][1] += 2
		precursor_stocks["indigon crystals"][2] = min(60,round(precursor_stocks["indigon crystals"][2]*0.9))
		precursor_stocks["verdine crystals"][1] += 2
		precursor_stocks["verdine crystals"][2] = min(60,round(precursor_stocks["verdine crystals"][2]*0.9))
		precursor_stocks["crimsonite crystals"][1] += 2
		precursor_stocks["crimsonite crystals"][2] = min(60,round(precursor_stocks["crimsonite crystals"][2]*0.9))
	if (prob(100))
		var/idx = rand(1,999999)
		var/list/chosen = list()
		chosen = list(list(/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k,rand(2200,3500)),list(/obj/item/weapon/gun/projectile/boltaction/mosin/m30,rand(1600,1900)),list(/obj/item/weapon/gun/projectile/shotgun/pump,rand(1400,1700)),list(/obj/item/weapon/gun/projectile/pistol/waltherp38,rand(800,1200)), list(/obj/item/weapon/material/sword/katana,rand(1000,2500)))
		var/chosen1 = pick(chosen)
		if (ispath(chosen1[1]))
			var/pt = chosen1[1]
			var/obj/item/ST = new pt(locate(1,1,1))
			if (istype(ST, /obj/item/weapon/gun/projectile))
				var/obj/item/weapon/gun/projectile/PJ = ST
				PJ.serial = ""
			map.globalmarketplace += list("[idx]" = list("Anonymous",ST,1,chosen1[2],"deepnet","[idx]",1))
			ST.forceMove(locate(0,0,0))
	var/num = rand(1,2) //equipment
	for(var/i, i<=num, i++)
		var/idx = rand(1,999999)
		var/list/chosen = list()
		chosen = list(list(/obj/item/weapon/reagent_containers/pill/cocaine,rand(150,250)),list(/obj/item/weapon/disk/program/squadtracker,rand(250,350)),list(/obj/item/weapon/attachment/scope/adjustable/sniper_scope,rand(150,200)),list(/obj/item/weapon/attachment/silencer/pistol,rand(180,250)),list(/obj/item/weapon/plastique/c4,rand(750,950)),list(/obj/item/clothing/glasses/nvg,rand(140,180)),list(/obj/item/clothing/accessory/armor/nomads/civiliankevlar,rand(400,500)))
		var/chosen1 = pick(chosen)
		if (ispath(chosen1[1]))
			var/pt = chosen1[1]
			var/obj/item/ST = new pt(locate(1,1,1))
			map.globalmarketplace += list("[idx]" = list("Anonymous",ST,1,chosen1[2],"deepnet","[idx]",1))
			ST.forceMove(locate(0,0,0))

	num = rand(2,3) //ammo
	for(var/i, i<=num, i++)
		var/idx = rand(1,999999)
		var/list/chosen = list()
		chosen = list(list(/obj/item/ammo_magazine/gewehr98,rand(100,120)),list(/obj/item/ammo_magazine/mosin,rand(80,120)),list(/obj/item/ammo_magazine/shellbox,rand(120,180)),list(/obj/item/ammo_magazine/walther,rand(60,90)))
		var/chosen1 = pick(chosen)
		if (ispath(chosen1[1]))
			var/pt = chosen1[1]
			var/obj/item/ST = new pt(locate(1,1,1))
			map.globalmarketplace += list("[idx]" = list("Anonymous",ST,1,chosen1[2],"deepnet","[idx]",1))
			ST.forceMove(locate(0,0,0))

	if (repeat)
		spawn(rand(12000,14000))
			refill_marketplace(repeat)
/obj/map_metadata/art_of_the_deal/proc/score()
	to_chat(world, "<b><font color='yellow' size=3>Scores:</font></b>")
	for(var/obj/structure/closet/safe/SF in world)
		if (SF.faction)
			var/list/tlist = list(SF.faction,0)
			for(var/obj/item/I in SF)
//				if (istype(I, /obj/item/weapon/disk))
//					var/obj/item/weapon/disk/D = I
//					if (D.faction && D.faction != SF.faction)
//						tlist[2]+=500
				if (istype(I, /obj/item/stack/money))
					var/obj/item/stack/money/M = I
					tlist[2]+=M.amount*M.value/4
			tlist[2] += scores[SF.faction]
			to_chat(world, "<big><font color='yellow' size=2>[tlist[1]]: [tlist[2]] points</font></big>")
//five-o scores
	var/list/tlist2 = list("Sheriff Office",0)
	for(var/obj/item/I in get_area(/area/caribbean/prison/jail))
		if (istype(I, /obj/item/weapon/disk))
			var/obj/item/weapon/disk/D = I
			if (D.faction && !D.used)
				tlist2[2]+= 400
		if (istype(I, /obj/item/stack/money))
			var/obj/item/stack/money/M = I
			tlist2[2]+= M.amount*(M.value/4)
	tlist2[2] += scores["Sheriff Office"]
	to_chat(world, "<big><font color='yellow' size=2>[tlist2[1]]: [tlist2[2]] points</font></big>")
	spawn(3000)
		score()
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/obj/structure/vending/business_apparel
	name = "equipment rack"
	desc = "All the equipment you need for that special business meeting."
	icon_state = "apparel_german2"
	products = list(
		/obj/item/stack/medical/bruise_pack/gauze = 10,
		/obj/item/clothing/accessory/storage/webbing/pouches = 10,
		/obj/item/weapon/storage/backpack/duffel = 5,
		/obj/item/weapon/storage/briefcase = 5,
		/obj/item/clothing/accessory/holster/armpit = 10,
		/obj/item/clothing/accessory/holster/chest = 10,
		/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = 10,
		/obj/item/clothing/glasses/sunglasses = 10,
		/obj/item/clothing/gloves/fingerless = 10,
		/obj/item/clothing/mask/balaclava = 10,
		/obj/item/flashlight/flashlight = 10,
		/obj/item/ammo_magazine/emptyspeedloader = 20,
		/obj/item/weapon/handcuffs/rope = 50,
		/obj/item/weapon/material/kitchen/utensil/knife/shank/iron = 10,
	)

/obj/structure/vending/undercover_apparel
	name = "undercover apparel"
	desc = "All the equipment needed for undercover missions."
	icon_state = "apparel_german2"
	products = list(
		/obj/item/clothing/suit/storage/jacket/charcoal_suit = 10,
		/obj/item/clothing/suit/storage/jacket/black_suit = 10,
		/obj/item/clothing/suit/storage/jacket/navy_suit = 10,
		/obj/item/clothing/shoes/laceup = 10,
		/obj/item/clothing/glasses/sunglasses = 10,
		/obj/item/clothing/under/expensive/red = 10,
		/obj/item/clothing/accessory/armband/british = 10,
		/obj/item/clothing/under/expensive/yellow = 10,
		/obj/item/clothing/accessory/armband/spanish = 10,
		/obj/item/clothing/under/expensive/green = 10,
		/obj/item/clothing/accessory/armband/portuguese = 10,
		/obj/item/clothing/under/expensive/blue = 10,
		/obj/item/clothing/accessory/armband/french = 10,
		/obj/item/weapon/storage/backpack/duffel = 10,
		/obj/item/weapon/storage/briefcase = 10,
		/obj/item/clothing/accessory/holster/armpit = 10,
		/obj/item/clothing/accessory/holster/chest = 10,
		/obj/item/weapon/material/kitchen/utensil/knife/shank/iron = 10,
	)

	attack_hand(mob/living/human/user as mob)
		if (user.civilization == "Sheriff Office")
			..()
		else
			to_chat(user, "You do not have access to this.")
			return

/obj/structure/vending/sales/business_weapons
	name = "weapon and ammo rack"
	desc = "When you need to pack that extra punch."
	icon_state = "weapons_sof"
	products = list(
		/obj/item/weapon/gun/projectile/pistol/colthammerless = 5,
		/obj/item/weapon/gun/projectile/pistol/colthammerless/m1908 = 5,
		/obj/item/weapon/gun/projectile/pistol/m1911 = 5,
		/obj/item/weapon/gun/projectile/revolver/smithwesson = 10,
		/obj/item/weapon/attachment/silencer/pistol = 5,

		/obj/item/ammo_magazine/colthammerless = 20,
		/obj/item/ammo_magazine/colthammerless/a380acp = 20,
		/obj/item/ammo_magazine/m1911 = 20,
		/obj/item/ammo_magazine/c32 = 10,

		/obj/item/clothing/accessory/armor/nomads/civiliankevlar = 5,
		/obj/item/clothing/head/ghillie = 2,
		/obj/item/clothing/suit/storage/ghillie = 2,
	)

	prices = list(
		/obj/item/clothing/accessory/armor/nomads/civiliankevlar = 1000,
		/obj/item/clothing/head/ghillie = 500,
		/obj/item/clothing/suit/storage/ghillie = 1000,

		/obj/item/weapon/gun/projectile/pistol/colthammerless = 300,
		/obj/item/weapon/gun/projectile/pistol/colthammerless/m1908 = 300,
		/obj/item/weapon/gun/projectile/pistol/m1911 = 400,
		/obj/item/weapon/gun/projectile/revolver/smithwesson = 240,
		/obj/item/weapon/gun/projectile/shotgun/pump/remington870 = 500,
		/obj/item/weapon/gun/projectile/boltaction/m24 = 600,
		/obj/item/weapon/attachment/silencer/pistol = 120,

		/obj/item/ammo_magazine/colthammerless = 40,
		/obj/item/ammo_magazine/colthammerless/a380acp = 40,
		/obj/item/ammo_magazine/m1911 = 40,
		/obj/item/ammo_magazine/c32 = 80,
		/obj/item/ammo_magazine/shellbox = 80,
		/obj/item/ammo_magazine/shellbox/slug = 80,
		/obj/item/ammo_magazine/m24 = 80,
	)
	attack_hand(mob/living/human/user as mob)
		if (!user.gun_permit)
			to_chat(user, SPAN_WARNING("You do not have a valid gun permit. Get one first from your local police station."))
			return
		var/count = 0
		for (var/list/L in map.gun_registrations)
			if(L[3] == user.real_name)
				count++
		if (count > 4)
			to_chat(user, SPAN_WARNING("You can't buy more weapons. You can only have [count] weapons registered to your name."))
		..()
	attackby(obj/item/I, mob/living/human/user)
		if (!user.gun_permit)
			to_chat(user, SPAN_WARNING("You do not have a valid gun permit. Get one first from your local police station."))
			return
		var/count = 0
		for (var/list/L in map.gun_registrations)
			if(L[3] == user.real_name)
				count++
		if (count > 4)
			to_chat(user, SPAN_WARNING("You can't buy more weapons. You can only have [count] weapons registered to your name."))
		..()

/obj/structure/vending/police_equipment
	name = "police equipment"
	desc = "All the equipment to keep your officers in top shape."
	icon_state = "apparel_german2"
	products = list(
		/obj/item/stack/medical/bruise_pack/gauze = 15,
		/obj/item/clothing/accessory/holster/hip = 15,
		/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = 15,
		/obj/item/clothing/glasses/sunglasses = 15,
		/obj/item/clothing/gloves/thick/swat = 15,
		/obj/item/clothing/head/helmet/swat = 15,
		/obj/item/clothing/mask/gas/swat = 15,
		/obj/item/clothing/suit/police = 15,
		/obj/item/clothing/suit/storage/jacket/highvis = 15,
		/obj/item/clothing/shoes/swat = 15,
		/obj/item/clothing/under/countysheriff/deputy = 15,
		/obj/item/clothing/under/countysheriff/deputy/short = 15,
		/obj/item/clothing/shoes/laceup = 15,
		/obj/item/clothing/head/countysheriff_cap = 15,
		/obj/item/clothing/head/countysheriff_cap/black = 15,
		/obj/item/weapon/storage/backpack/satchel/police = 10,
		/obj/item/weapon/storage/backpack/satchel/black = 5,
		/obj/item/weapon/storage/backpack/satchel = 5,
		/obj/item/weapon/storage/backpack/duffel = 5,
		/obj/item/weapon/melee/nightbaton = 15,
		/obj/item/weapon/storage/box/handcuffs = 10,
		/obj/item/weapon/storage/box/bodybags = 3,
		/obj/item/weapon/storage/box/evidence = 10,
		/obj/item/taperoll/police = 10,
//		/obj/item/clothing/head/helmet/constable = 5,
//		/obj/item/clothing/under/constable = 5,
//		/obj/item/clothing/under/traffic_police = 5,
	)
	attack_hand(mob/living/human/user as mob)
		if (user.civilization == "Sheriff Office")
			..()
		else
			to_chat(user, "You do not have access to this.")
			return

/obj/structure/vending/police_weapons
	name = "lethal police weapons"
	desc = "When the baton is not enough."
	icon_state = "weapons_sof"
	products = list(
	/obj/item/weapon/gun/projectile/shotgun/pump/remington870 = 10,
	/obj/item/ammo_magazine/shellbox/slug = 10,
	/obj/item/ammo_magazine/shellbox = 10,
	/obj/item/ammo_magazine/glock17 = 50,
	/obj/item/ammo_magazine/m9beretta = 50,
	/obj/item/ammo_magazine/c32 = 50,
	/obj/item/ammo_magazine/c44 = 50,
	/obj/item/weapon/grenade/coldwar/stinger = 20,
	/obj/item/weapon/gun/projectile/boltaction/m24 = 10,
	/obj/item/ammo_magazine/m24 = 20,
	/obj/item/weapon/attachment/scope/adjustable/sniper_scope = 10,
	)
	attack_hand(mob/living/human/user as mob)
		if (user.civilization == "Sheriff Office")
			..()
		else
			to_chat(user, "You do not have access to this.")
			return

/obj/structure/vending/police_weapons/ltl
	name = "less than lethal police weapons"
	desc = "Baton +."
	icon_state = "equipment_usa"
	products = list(
	/obj/item/weapon/gun/projectile/shotgun/pump/remington870 = 10,
	/obj/item/ammo_magazine/shellbox/rubber = 10,
	/obj/item/ammo_magazine/shellbox/beanbag = 10,
	/obj/item/weapon/gun/launcher/grenade/standalone/m79 = 5,
	/obj/item/weapon/grenade/chemical/ugl/teargas = 10,
	/obj/item/weapon/grenade/flashbang = 20,
	/obj/item/weapon/grenade/chemical/xylyl_bromide = 10,
	/obj/item/weapon/grenade/smokebomb/m18smoke = 10,
	/obj/item/weapon/reagent_containers/spray/pepper = 10,
	/obj/item/weapon/gun/projectile/dartgun/mag = 10,

	/obj/item/ammo_magazine/chemdart/mag = 20,
	/obj/item/weapon/reagent_containers/glass/bottle/chloralhydrate = 10,
	/obj/item/ammo_magazine/tt30ll/rubber = 50,

	/obj/item/weapon/gun/projectile/pistol/taser = 5,
	/obj/item/ammo_magazine/taser = 10,
	)
	attack_hand(mob/living/human/user as mob)
		if (user.civilization == "Sheriff Office")
			..()
		else
			to_chat(user, "You do not have access to this.")
			return
/obj/item/weapon/package
	name = "package"
	desc = "Some kind of package."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "deliverypackage"
	item_state = "deliverypackage"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 1
	throwforce = 1
	flags = FALSE

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	w_class = ITEM_SIZE_NORMAL

/obj/item/weapon/paper_bin/police
	name = "incoming documents"
	desc = "incoming documents and warrants will arrive here."
	amount = 0

/obj/item/weapon/paper/police
	icon_state = "police_record"
	base_icon = "police_record"
	name = "Police Record"
	var/spawntimer = 0

/obj/item/weapon/paper/police/warrant
	icon_state = "police_record"
	base_icon = "police_record"
	name = "Arrest Warrant"
	var/reason = "Mischief"
	var/mob/living/human/tgt_mob = null
	var/tgt = "Unknown"
	var/tgtcmp = "Unknown"
	var/arn = 0
	New()
		..()
		arn = rand(1000,9999)
		icon_state = "police_record"
		spawn(10)
			info = "<center>DEPARTMENT OF JUSTICE<hr><large><b>Arrest Warrant No. [arn]</b></large><hr><br>Law Enforcement Agencies are hereby authorized and directed to detain <b>[tgt]</b>, working for <b><i>[tgtcmp]</i></b>, for the following reasons:<br><br><i>- [reason]</i><br><br>They will disregard any claims of immunity or privilege by the Suspect or agents acting on the Suspect's behalf. Law Enforcement Agencies shall bring <b>[tgt]</b> forthwith to the local station.<br><br><small><center><i>Form Model 13-B</i><center></small><hr>"
		spawn(100)
			if (spawntimer)
				spawn(spawntimer)
					qdel(src)

/obj/item/weapon/paper/police/searchwarrant
	icon_state = "police_warrant"
	base_icon = "police_warrant"
	name = "Search Warrant"
	var/cmp = "Unknown"
	var/arn = 0
	New()
		..()
		arn = rand(100,999)
		icon_state = "police_warrant"
		spawn(10)
			info = "<center>DEPARTMENT OF JUSTICE<hr><large><b>Search Warrant No. [arn]</b></large><hr><br>Law Enforcement Agencies are hereby authorized and directed to search all and every property owned by <b>[cmp]</b>. They will disregard any claims of immunity or privilege by the Suspect or agents acting on the Suspect's behalf.<br><br><small><center><i>Form Model 13-C1</i></center></small><hr>"

/obj/item/weapon/paper/k9_manual
	name = "K-9 manual"
	desc = "The official SCSD K-9 training manual."
	info = "<h1>SCSD K-9 Training Manual</h1><br>Here's the list of commands that your K-9 is trained to respond to:<br><br><ul><li>\"Follow!\" - Follows you </li><li>\"Stop following!\" - Stops following who issued the command to follow</li><li>\"Attack!\" - Attacks armed enemies</li><li>\"Kill!\" - Attacks anyone that isn't a LEO, armed or unarmed</li><li>\"Guard!\" - Attacks people who approach the area</li><li>\"Patrol!\" - Wanders around the base, overlaps with other commands</li><li>\"Stop patrolling!\" - Stop the previous command</li><li>\"Be passive!\" - Only attacks in self-defense</li><li>\"Stop everything!\" - Stops everything</li><li>\"Prioritize following!\" - Will prioritize following over attacking</li><li>\"Prioritize attacking!\" - Will pririoritize attacking over following</ul><br>Your dog automatically detects most contraband (disks and narcotics) in a 7 tile range. It'll also bark if there's a person not apart of the Sheriff's Department in that same range."

/obj/structure/vending/sales/menu
	name = "menu"
	desc = "Place your order here!"
	sound_type = 'sound/effects/deskbell.ogg'
	icon_state = "menu"

/obj/structure/vending/sales/menu/pizza
	products = list(
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzasauced = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzacheesed = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzamushroom = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzapepperoni = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/meatpizza = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzahawaiian = 1,
	)
	prices = list(
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzasauced = 40,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzacheesed = 60,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzamushroom = 80,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzapepperoni = 80,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza = 80,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/meatpizza = 120,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzahawaiian = 12000,
	)

/obj/structure/vending/sales/menu/ramen
	products = list(
	/obj/item/weapon/reagent_containers/food/snacks/ramen = 30,
	/obj/item/weapon/reagent_containers/food/drinks/bottle/small/sake = 10,
	)
	prices = list(
	/obj/item/weapon/reagent_containers/food/snacks/ramen = 100,
	/obj/item/weapon/reagent_containers/food/drinks/bottle/small/sake = 120,
	)

/obj/structure/vending/sales/menu/mcd
	icon = 'icons/obj/decals.dmi'
	icon_state = "mcd2"
	products = list(
	/obj/item/weapon/reagent_containers/food/snacks/burger = 50,
	/obj/item/weapon/reagent_containers/food/snacks/cheeseburger = 50,
	/obj/item/weapon/reagent_containers/food/snacks/fries = 80,
	/obj/item/weapon/reagent_containers/food/drinks/can/cola = 50,
	)
	prices = list(
	/obj/item/weapon/reagent_containers/food/snacks/burger = 40,
	/obj/item/weapon/reagent_containers/food/snacks/cheeseburger = 60,
	/obj/item/weapon/reagent_containers/food/snacks/fries = 20,
	/obj/item/weapon/reagent_containers/food/drinks/can/cola = 20,
	)

/obj/structure/vending/sales/menu/donuts
	products = list(
	/obj/item/weapon/storage/fancy/donut_box = 30,
	/obj/item/weapon/reagent_containers/food/snacks/cheesecakeslice = 10,
	/obj/item/weapon/reagent_containers/food/snacks/chocolatecakeslice = 10,
	/obj/item/weapon/reagent_containers/food/snacks/muffin = 15,
	/obj/item/weapon/reagent_containers/food/drinks/coffee = 20,
	/obj/item/weapon/reagent_containers/food/condiment/bsugar = 30,
	)
	prices = list(
	/obj/item/weapon/storage/fancy/donut_box = 60,
	/obj/item/weapon/reagent_containers/food/snacks/cheesecakeslice = 40,
	/obj/item/weapon/reagent_containers/food/snacks/chocolatecakeslice = 40,
	/obj/item/weapon/reagent_containers/food/snacks/muffin = 40,
	/obj/item/weapon/reagent_containers/food/drinks/coffee = 20,
	/obj/item/weapon/reagent_containers/food/condiment/bsugar = 20,
	)

//////////////////SCREEN HELPERS////////////////////////////
/obj/screen/areashow_aod
	maptext = "<center><font color='yellow'>Unknown Area</font></center>"
	maptext_width = 32*8
	maptext_x = (32*8 * -0.5)+32
	maptext_y = 32*0.75
	icon_state = "blank"

/obj/screen/areashow_aod/New()
	..()
	spawn(50)
		update()

/obj/screen/areashow_aod/proc/update()
	if (!parentmob || !src)
		return
	var/cloc = "Unknown"
	cloc = parentmob.get_coded_loc()
	maptext = "<center><font color='yellow'><b>[cloc]</b>  ([parentmob.x],[parentmob.y])</font></center>"

	spawn(10)
		update()
/atom/proc/get_coded_loc()
	var/a = ceil(x/22)
	var/b = 10-Floor(y/22)
	if (map.ID == MAP_CAMPAIGN || CAMPAIGN_MAP_LIST_MAPID_OR)
		a = ceil(x/15)
		b = 10-Floor(y/10)
	if (map.ID == MAP_OPERATION_FALCON)
		a = ceil(x/40)
		b = 10-Floor(y/40)

	switch(a)
		if (0 to 1)
			a = "A"
		if (1 to 2)
			a = "B"
		if (2 to 3)
			a = "C"
		if (3 to 4)
			a = "D"
		if (4 to 5)
			a = "E"
		if (5 to 6)
			a = "F"
		if (6 to 7)
			a = "G"
		if (7 to 8)
			a = "H"
		if (8 to 9)
			a = "I"
		if (9 to 10)
			a = "J"
	return "[a][b]"

/mob/living/human/var/hidden_name = ""
/mob/living/human/var/is_undercover = FALSE

/mob/living/human/proc/undercover()
	set category = "IC"
	set name = "Toggle Undercover"
	set desc = "Hide your identity for undercover police operations."

	if (findtext(name, "Deputy") || findtext(name, "Detective"))
		if (findtext(name, "Deputy"))
			real_name = replacetext(real_name, "Deputy ", "")
		else if (findtext(name, "Detective"))
			real_name = replacetext(real_name, "Detective ", "")
		hidden_name = real_name
		var/chosen_name = WWinput(src, "Which ethnicity do you want your name to be?","Choose Name","Cancel",list("Cancel","Russian","Jewish","Italian","Japanese"))
		switch(chosen_name)
			if ("Cancel")
				return
			if ("Russian")
				chosen_name =  species.get_random_russian_name(gender)
			if ("Japanese")
				chosen_name =  species.get_random_japanese_name(gender)
			if ("Italian")
				chosen_name =  species.get_random_italian_name(gender)
			if ("Jewish")
				chosen_name =  species.get_random_hebrew_name(gender)
		name = chosen_name
		real_name = chosen_name
		voice = chosen_name
		is_undercover = TRUE
		to_chat(src, "<b><big>You go undercover.</big></b>")
		return
	else
		switch(original_job_title)
			if ("County Deputy")
				real_name = "Deputy [hidden_name]"
				name = "Deputy [hidden_name]"
				voice = "Deputy [hidden_name]"
			if ("Detective")
				real_name = "Detective [hidden_name]"
				name = "Detective [hidden_name]"
				voice = "Detective [hidden_name]"
		is_undercover = FALSE
		to_chat(src, "<b><big>You are now revealing your identity again.</big></b>")
		return

/obj/item/clothing/accessory/armband/policebadge
	name = "police badge"
	desc = "A police badge in a star shape, with an officer's name engraved."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "sheriff"
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = TRUE
	throw_range = 2
	w_class = ITEM_SIZE_TINY
	flammable = FALSE
	slot_flags = SLOT_POCKET|SLOT_BELT

/obj/item/clothing/accessory/armband/policebadge/secondary_attack_self(mob/living/human/user)
	showoff(user)

/mob/living/human/var/gun_permit = FALSE
/mob/living/human/var/bail_price = 0
/////////////////////////delivery points//////////////////////
/turf/floor/delivery
	name = "delivery area"
	desc = "A collection point for deliveries."
	icon = 'icons/turf/floors.dmi'
	icon_state = "sidewalk"

	New()
		..()
		spawn(50)
			new/obj/structure/redmailbox(src)

/obj/structure/redmailbox
	name = "pillar postbox"
	desc = "A red pillar postbox."
	icon = 'icons/obj/mail.dmi'
	icon_state = "redmailbox"
	density = TRUE
	opacity = FALSE
	anchored = TRUE
	not_disassemblable = TRUE
	not_movable = TRUE
	crushable = FALSE

/obj/structure/redmailbox/attackby(obj/item/I,mob/living/human/H)
	if (istype(I,/obj/item/stack/component) && istype(map, /obj/map_metadata/art_of_the_deal))
		var/obj/item/stack/component/P = I
		var/obj/map_metadata/art_of_the_deal/map2 = map
		var/turf/T = get_turf(src)
		if (istype(T, /turf/floor/delivery))
			for(var/list/i in map2.delivery_orders)
				//x,y,product,amount,payment,factionmail
				var/faction
				switch(i[6])
					if ("mail@kogama.ug")
						faction = "Kogama Kraftsmen"
					if ("mail@rednikov.ug")
						faction = "Rednikov Industries"
					if ("mail@goldstein.ug")
						faction = "Goldstein Solutions"
					if ("mail@blu.ug")
						faction = "Giovanni Blu Stocks"
				if (faction && H.civilization == faction && i[1]==src.x && i[2]==src.y && P.name == i[3] && P.amount >= i[4])
					P.amount-=i[4]
					if (P.amount<=0)
						qdel(P)
					map2.delivery_orders -= i
					for(var/obj/structure/closet/safe/SF in world)
						if (SF.faction == faction)
							if (SF.opened)
								var/obj/item/stack/money/dollar/D = new/obj/item/stack/money/dollar(SF.loc)
								D.amount = i[5]/D.value
							else
								var/obj/item/stack/money/dollar/D = new/obj/item/stack/money/dollar(SF)
								D.amount = i[5]/D.value
					to_chat(H, "<big><font color='green'>You fulfill the order. The payment has been sent to your company's safe.</font></big>")

	else
		..()


/////DOOR SPAWNERS/////

/obj/effect/spawner/objspawner/door
	name = "door spawner"
	max_range = 0
	max_number = 1
	timer = 10
	activated = FALSE

/obj/effect/spawner/objspawner/door/getEmptyTurf()
	var/list/turf/emptyTurfs = new
	for(var/turf/T in range(max_range,src))
		var/invalid = FALSE
		for (var/obj/structure/simple_door/SD in T)
			invalid = TRUE
		if (!invalid)
			emptyTurfs += T
	if (emptyTurfs.len)
		return pick(emptyTurfs)

/obj/effect/spawner/objspawner/door/blue
	create_path = /obj/structure/simple_door/key_door/civ/businessblue
/obj/effect/spawner/objspawner/door/yellow
	create_path = /obj/structure/simple_door/key_door/civ/businessyellow
/obj/effect/spawner/objspawner/door/red
	create_path = /obj/structure/simple_door/key_door/civ/businessred
/obj/effect/spawner/objspawner/door/green
	create_path = /obj/structure/simple_door/key_door/civ/businessgreen
/obj/effect/spawner/objspawner/door/police
	create_path = /obj/structure/simple_door/key_door/civ/police
	activated = TRUE
	timer = 1800



//// SMUGGLING SYSTEM//////

/obj/structure/largecrate/smuggler
	name = "suspicious large crate"

/obj/structure/largecrate/smuggler/crystals/New()
	..()
	for (var/i = 1; i<=8;i++)
		new /obj/item/stack/precursor/yellow(src)
		new /obj/item/stack/precursor/green(src)
		new	/obj/item/stack/precursor/red(src)
		new /obj/item/stack/precursor/blue(src)

/obj/structure/largecrate/smuggler/cocaine/New()
	..()
	var/blocks_amount = rand(1,3)
	switch(blocks_amount)
		if (1)
			new /obj/item/weapon/reagent_containers/cocaineblock(src)
		if (2)
			new /obj/item/weapon/reagent_containers/cocaineblocks(src)
		if (3)
			new /obj/item/weapon/reagent_containers/cocaineblocks/three(src)

/obj/structure/largecrate/smuggler/disks/New()
	..()
	var/disks_amount = rand(2,5)
	for (var/i = 1; i<=disks_amount;i++)
		new /obj/random/disk(src)

/obj/structure/largecrate/smuggler/fake_disks/New()
	..()
	var/disks_amount = rand(2,5)
	for (var/i = 1; i<=disks_amount;i++)
		new /obj/random/disk/fake(src)

/obj/structure/largecrate/smuggler/makarov/New()
	..()
	var/guns_amount = rand(1,3)
	var/ammo_amount = rand (3,9)
	var/ammobox_amount = rand (0,1)
	for (var/i = 1; i<=guns_amount;i++)
		new /obj/item/weapon/gun/projectile/pistol/makarov(src)
	for (var/i = 1; i<=ammo_amount;i++)
		new /obj/item/ammo_magazine/makarov(src)
	for (var/i = 1; i<=ammobox_amount;i++)
		new /obj/item/ammo_magazine/makarov/box(src)
/obj/structure/largecrate/smuggler/magnum44/New()
	..()
	new /obj/item/weapon/gun/projectile/revolver/magnum44(src)
	new /obj/item/ammo_magazine/c44magnum(src)
	new /obj/item/ammo_magazine/emptyspeedloader(src)
	new /obj/item/ammo_magazine/emptyspeedloader(src)
/obj/structure/largecrate/smuggler/m1911/New()
	..()
	var/guns_amount = rand(1,3)
	var/ammo_amount = rand (3,9)
	var/ammobox_amount = rand (0,1)
	for (var/i = 1; i<=guns_amount;i++)
		new /obj/item/weapon/gun/projectile/pistol/m1911(src)
	for (var/i = 1; i<=ammo_amount;i++)
		new /obj/item/ammo_magazine/m1911(src)
	for (var/i = 1; i<=ammobox_amount;i++)
		new /obj/item/ammo_magazine/a45acpbox(src)

/obj/structure/largecrate/smuggler/uzi/New()
	..()
	new /obj/item/weapon/gun/projectile/submachinegun/uzi(src)
	new /obj/item/ammo_magazine/uzi(src)
	new /obj/item/ammo_magazine/uzi(src)
/obj/structure/largecrate/smuggler/skorpion/New()
	..()
	new /obj/item/weapon/gun/projectile/submachinegun/skorpion(src)
	new /obj/item/ammo_magazine/skorpion(src)
	new /obj/item/ammo_magazine/skorpion(src)
/obj/structure/largecrate/smuggler/mac10/New()
	..()
	new /obj/item/weapon/gun/projectile/submachinegun/mac10(src)
	new /obj/item/ammo_magazine/mac10(src)
	new /obj/item/ammo_magazine/mac10(src)
/obj/structure/largecrate/smuggler/tec9/New()
	..()
	new /obj/item/weapon/gun/projectile/submachinegun/tec9(src)
	new /obj/item/ammo_magazine/tec9(src)
	new /obj/item/ammo_magazine/tec9(src)
/obj/structure/largecrate/smuggler/ak47/New()
	..()
	new /obj/item/weapon/gun/projectile/submachinegun/ak47(src)
	new /obj/item/ammo_magazine/ak47(src)
	new /obj/item/ammo_magazine/ak47(src)

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

/obj/random/disk
	name = "random disk"
/obj/random/disk/spawn_choices()
	return list(/obj/item/weapon/disk/blue,
				/obj/item/weapon/disk/red,
				/obj/item/weapon/disk/blue,
				/obj/item/weapon/disk/green)

/obj/random/disk/fake
	name = "fake random disk"
/obj/random/disk/fake/spawn_choices()
	return list(/obj/item/weapon/disk/blue/fake,
				/obj/item/weapon/disk/red/fake,
				/obj/item/weapon/disk/blue/fake,
				/obj/item/weapon/disk/green/fake)

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