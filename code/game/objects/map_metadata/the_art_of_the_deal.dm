/obj/map_metadata/art_of_the_deal
	ID = MAP_THE_ART_OF_THE_DEAL
	title = "The Art of the Deal"
	lobby_icon = "icons/lobby/taotd.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one)
	respawn_delay = 3000
	is_singlefaction = TRUE
	has_hunger = TRUE
	no_winner ="The fighting is still going."
	songs = list(
		"Woke Up This Morning:1" = "sound/music/woke_up_this_morning.ogg",)
	faction_organization = list(
		CIVILIAN)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british/ship, //it isnt in the map so nobody wins by capture
		)
	age = "1994"
	ordinal_age = 8
	var/fac_nr = 3
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the deal"
	mission_start_message = "<font size=4><b>4</b> corporations are fighting for control of the disks.<br>Please read the manual: https://civ13.github.io/civ13-wiki/The_Art_of_the_Deal</font>"
	var/winner_name = "Unknown"
	var/list/winner_ckeys = list()
	faction1 = CIVILIAN
	faction2 = PIRATES
	gamemode = "Negotiations"
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
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				score()
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
	var/newnamee = list("Sheriff Office" = list(0,0,0,null,0,"star","#E5E500","#00007F",0,0))
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
		if (clients.len <= 15)
			if (J.title == "Paramedic" || J.title == "Legitimate Business" || J.title == "Nurse")
				. = FALSE
		if (clients.len <= 20)
			if (J.title == "Physician" || J.title == "County Judge" || J.title == "Detective")
				. = FALSE
		if (clients.len <= 25)
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

/*/obj/map_metadata/art_of_the_deal/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.original_job_title == "Nurse")
				H << "<span class = 'warning'>You cannot leave the Hospital area as a Nurse.</span>"
				return TRUE
	return FALSE*/ //Commented out, to be re-implemented if players go unga.

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
	world << "<font size=2 color ='yellow'>New disks have arrived at the vaults!</font>"

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
	world << "<b><font color='yellow' size=3>Scores:</font></b>"
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
			world << "<big><font color='yellow' size=2>[tlist[1]]: [tlist[2]] points</font></big>"
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
	world << "<big><font color='yellow' size=2>[tlist2[1]]: [tlist2[2]] points</font></big>"
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
		/obj/item/clothing/head/ghillie = 1,
		/obj/item/clothing/suit/storage/ghillie = 1,
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
		 user << "You do not have access to this."
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
	)
	prices = list(
		/obj/item/clothing/accessory/armor/nomads/civiliankevlar = 1000,

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
		if (user.gun_permit)
			..()
		else
		 user << "You do not have a valid gun permit. Get one first from your local police station."
		 return
	attackby(obj/item/I, mob/living/human/user)
		if (user.gun_permit)
			..()
		else
		 user << "You do not have a valid gun permit. Get one first from your local police station."
		 return
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
		 user << "You do not have access to this."
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
		 user << "You do not have access to this."
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
	/obj/item/weapon/gun/projectile/pistol/tt30 = 50,
	)
	attack_hand(mob/living/human/user as mob)
		if (user.civilization == "Sheriff Office")
			..()
		else
		 user << "You do not have access to this."
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
	force = 9.0
	throwforce = 10.0
	flags = FALSE

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	w_class = ITEM_SIZE_NORMAL
/obj/item/weapon/paper_bin/police
	name = "incomming documents"
	desc = "incomming documents and warrants will arrive here."
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
	if (map.ID == MAP_CAMPAIGN)
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

/mob/living/human/proc/undercover()
	set category = "IC"
	set name = "Toggle Undercover"
	set desc = "Hide your identity for undercover police operations."

	var/jobtype = "none"
	if (findtext(name, "Deputy") || findtext(name, "Detective"))
		if (findtext(name, "Deputy"))
			real_name = replacetext(real_name, "Deputy ", "")
			jobtype = "Deputy"
		else if (findtext(name, "Detective"))
			real_name = replacetext(real_name, "Detective ", "")
			jobtype = "Detective"
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
		src << "<b><big>You go undercover.</big></b>"
		return
	else
		if (jobtype == "Deputy")
			real_name = "Deputy [hidden_name]"
			name = "Deputy [hidden_name]"
			voice = "Deputy [hidden_name]"
		else
			real_name = "Detective [hidden_name]"
			name = "Detective [hidden_name]"
			voice = "Detective [hidden_name]"
		src << "<b><big>You are now revealing your identity again.</big></b>"
		return

/obj/item/clothing/accessory/armband/policebadge
	name = "police badge"
	desc = "a police badge in star shape, with an officer's name engraved."
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
					H << "<big><font color='green'>You fulfill the order. The payment has been sent to your company's safe.</font></big>"

	else
		..()