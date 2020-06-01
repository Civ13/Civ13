/obj/map_metadata/art_of_the_deal
	ID = MAP_THE_ART_OF_THE_DEAL
	title = "The Art of the Deal"
	lobby_icon_state = "taotd"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 3000
	is_singlefaction = TRUE
	no_winner ="The fighting is still going."
	songs = list(
		"Fortunate Son:1" = 'sound/music/fortunate_son.ogg',)
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
	mission_start_message = "<font size=4><b>4</b> corporations are fighting for control of the disks.<br>Please read the manual: http://civ13.com/wiki/index.php/The_Art_of_the_Deal</font>"
	var/winner_name = "Unknown"
	var/list/winner_ckeys = list()
	faction1 = CIVILIAN
	faction2 = PIRATES
	gamemode = "Negotiations"
	scores = list(
		"Reddington Arms" = 0,
		"Bluford Stock and Bonds" = 0,
		"Greene Traders Co-ops" = 0,
		"Goldstein Solutions" = 0,
		"Police" = 0,)
	required_players = 6

/obj/map_metadata/art_of_the_deal/New()
	..()
	spawn(3000)
		score()
	var/newnamea = list("Reddington Arms" = list(230,230,230,null,0,"sun","#7F0000","#7F7F7F",0,0))
	var/newnameb = list("Bluford Stock and Bonds" = list(230,230,230,null,0,"sun","#00007F","#7F7F7F",0,0))
	var/newnamec = list("Greene Traders Co-ops" = list(230,230,230,null,0,"sun","#007F00","#7F7F7F",0,0))
	var/newnamed = list("Goldstein Solutions" = list(230,230,230,null,0,"sun","#E5E500","#7F7F7F",0,0))
	var/newnamee = list("Police" = list(230,230,230,null,0,"star","#E5E500","#00007F",0,0))
	var/newnamef = list("Paramedics" = list(230,230,230,null,0,"cross","#7F0000","#FFFFFF",0,0))
	custom_civs += newnamea
	custom_civs += newnameb
	custom_civs += newnamec
	custom_civs += newnamed
	custom_civs += newnamee
	custom_civs += newnamef
	spawn(15000)
		spawn_disks(TRUE)
/obj/map_metadata/art_of_the_deal/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_deal)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/art_of_the_deal/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/art_of_the_deal/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/art_of_the_deal/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4><b>The round has started!</b> Players may now cross the invisible wall!</font>"

/obj/map_metadata/art_of_the_deal/proc/spawn_disks(repeat = FALSE)
	for(var/obj/structure/closet/safe/SF in world)
		if (SF.faction)
			switch(SF.faction)
				if ("Reddington Arms")
					if (SF.opened)
						new/obj/item/weapon/disk/red(SF.loc)
						new/obj/item/weapon/disk/red/fake(SF.loc)
					else
						new/obj/item/weapon/disk/red(SF)
						new/obj/item/weapon/disk/red/fake(SF)
				if ("Bluford Stock and Bonds")
					if (SF.opened)
						new/obj/item/weapon/disk/blue(SF.loc)
						new/obj/item/weapon/disk/blue/fake(SF.loc)
					else
						new/obj/item/weapon/disk/red(SF)
						new/obj/item/weapon/disk/red/fake(SF)
				if ("Greene Traders Co-ops")
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
	var/list/tlist2 = list("Police",0)
	for(var/obj/item/I in get_area(/area/caribbean/prison))
		if (istype(I, /obj/item/weapon/disk))
			var/obj/item/weapon/disk/D = I
			if (D.faction && !D.used)
				tlist2[2]+=300
		if (istype(I, /obj/item/stack/money))
			var/obj/item/stack/money/M = I
			tlist2[2]+=M.amount*M.value/4
	tlist2[2] += scores["Police"]
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
//		/obj/item/clothing/suit/storage/jacket/charcoal_suit = 10,
//		/obj/item/clothing/suit/storage/jacket/black_suit = 10,
//		/obj/item/clothing/suit/storage/jacket/navy_suit = 10,
//		/obj/item/clothing/suit/storage/jacket/burgundy_suit = 10,
//		/obj/item/clothing/suit/storage/jacket/checkered_suit = 10,
	)

/obj/structure/vending/sales/business_weapons
	name = "weapon and ammo rack"
	desc = "When you need to pack that extra punch."
	icon_state = "weapons_sof"
	products = list(
		/obj/item/weapon/gun/projectile/pistol/colthammerless = 5,
		/obj/item/weapon/gun/projectile/pistol/colthammerless/m1908 = 5,
		/obj/item/weapon/gun/projectile/pistol/m1911 = 5,
		/obj/item/weapon/gun/projectile/revolver/smithwesson = 10,
//		/obj/item/weapon/gun/projectile/shotgun/pump = 2,
//		/obj/item/weapon/gun/projectile/boltaction/m24 = 2,
		/obj/item/weapon/attachment/silencer/pistol = 5,

		/obj/item/weapon/plastique/c4 = 2,
		/obj/item/ammo_magazine/colthammerless = 20,
		/obj/item/ammo_magazine/colthammerless/a380acp = 20,
		/obj/item/ammo_magazine/m1911 = 20,
		/obj/item/ammo_magazine/c32 = 10,
//		/obj/item/ammo_magazine/shellbox = 10,
//		/obj/item/ammo_magazine/shellbox/slug = 10,
//		/obj/item/ammo_magazine/m24 = 10,

		/obj/item/clothing/glasses/nvg = 2,
		/obj/item/clothing/accessory/armor/nomads/civiliankevlar = 4,
	)
	prices = list(
		/obj/item/weapon/gun/projectile/pistol/colthammerless = 300,
		/obj/item/weapon/gun/projectile/pistol/colthammerless/m1908 = 300,
		/obj/item/weapon/gun/projectile/pistol/m1911 = 400,
		/obj/item/weapon/gun/projectile/revolver/smithwesson = 240,
		/obj/item/weapon/gun/projectile/shotgun/remington870 = 500,
		/obj/item/weapon/gun/projectile/boltaction/m24 = 600,
		/obj/item/weapon/attachment/silencer/pistol = 120,

		/obj/item/weapon/plastique/c4 = 800,
		/obj/item/ammo_magazine/colthammerless = 40,
		/obj/item/ammo_magazine/colthammerless/a380acp = 40,
		/obj/item/ammo_magazine/m1911 = 40,
		/obj/item/ammo_magazine/c32 = 80,
		/obj/item/ammo_magazine/shellbox = 80,
		/obj/item/ammo_magazine/shellbox/slug = 80,
		/obj/item/ammo_magazine/m24 = 80,

		/obj/item/clothing/glasses/nvg = 100,
		/obj/item/clothing/accessory/armor/nomads/civiliankevlar = 400,
	)
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
		/obj/item/clothing/head/helmet/constable = 15,
		/obj/item/clothing/under/constable = 15,
		/obj/item/clothing/shoes/swat = 15,
		/obj/item/weapon/storage/backpack/civbag = 15,
		/obj/item/weapon/melee/nightbaton = 15,
		/obj/item/weapon/storage/box/handcuffs = 10,
	)
	attack_hand(mob/user as mob)
		if (user.original_job_title == "Police Officer")
			..()
		else
		 user << "You do not have access to this."
		 return
/obj/structure/vending/police_weapons
	name = "police weapons"
	desc = "When the baton is not enough."
	icon_state = "weapons_sof"
	products = list(
	/obj/item/weapon/gun/projectile/shotgun/remington870 = 10,
	/obj/item/ammo_magazine/shellbox/rubber = 10,
	/obj/item/ammo_magazine/shellbox = 10,
	/obj/item/weapon/gun/projectile/pistol/glock17 = 20,
	/obj/item/ammo_magazine/glock17 = 50,
	/obj/item/weapon/gun/launcher/grenadelauncher/M79 = 5,
	/obj/item/ammo_casing/grenade_l/teargas = 20,
	/obj/item/weapon/grenade/flashbang = 20,

	)
	attack_hand(mob/user as mob)
		if (user.original_job_title == "Police Officer")
			..()
		else
		 user << "You do not have access to this."
		 return
/obj/item/weapon/disk
	name = "diskette"
	desc = "Some kind of diskette."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "disk_red"
	item_state = "disk_red"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 4.0
	throwforce = 3.0
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	w_class = 1.0

	var/fake = FALSE
	var/used = FALSE
	var/faction = null
	var/exchange_state = -1 //0-both fake, 1-one is real, 2-both real

/obj/item/weapon/disk/examine(mob/user)
	..()
	if (used)
		user << "<font color='yellow'><i><b>The disk was already decrypted and wiped</b></i></font>."
	if (exchange_state == -1)
		user << "The disk is <b><font color='red'>inactive</font></b>."
	else
		user << "The disk is <b><font color='green'>active</font></b>."
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.civilization == faction)
			H << "This is a <b>[fake ? "<font color ='red'>fake</font>" : "<font color ='green'>real</font>"]</b> disk."
	else if (isghost(user))
		user << "This is a <b>[fake ? "<font color ='red'>fake</font>" : "<font color ='green'>real</font>"]</b> disk."

/obj/item/weapon/disk/attackby(var/obj/item/weapon/disk/D, var/mob/living/human/H)
	if (istype(D, /obj/item/weapon/disk))
		H.setClickCooldown(20)
		if (src.faction == D.faction)
			H << "These disks are of the same faction, you need another faction's disk to activate them."
			return
		else if (src.used)
			H << "\The [src] has already been used and wiped."
			return
		else if (D.used)
			H << "\The [src] has already been used and wiped."
			return
		else if (src.exchange_state != -1 && D.exchange_state != -1)
			visible_message("<big><font color='red'>Both disks are already active.</font></big>")
			return
		else if (src.exchange_state != -1)
			visible_message("<big><font color='yellow'>\The [src] has already been activated.</font></big>")
			return
		else if (D.exchange_state != -1)
			visible_message("<big><font color='yellow'>\The [D] has already been activated.</font></big>")
			return

		if (D.fake && src.fake) //both fake
			D.exchange_state = 0
			src.exchange_state = 0
			visible_message("<big><font color='green'>Both disks get activated, completing the transaction.</font></big>")
			return
		else if ((D.fake && !src.fake) || (!D.fake && src.fake)) //one is fake
			D.exchange_state = 1
			src.exchange_state = 1
			visible_message("<big><font color='green'>Both disks get activated, completing the transaction.</font></big>")
			return
		else if (!D.fake && !src.fake) //both real
			D.exchange_state = 2
			src.exchange_state = 2
			visible_message("<big><font color='green'>Both disks get activated, completing the transaction.</font></big>")
			return
	else
		..()
/obj/item/weapon/disk/red
	name = "red diskette"
	icon_state = "disk_red"
	item_state = "disk_red"
	faction = "Reddington Arms"

/obj/item/weapon/disk/red/fake
	name = "red diskette"
	faction = "Reddington Arms"
	fake = TRUE

/obj/item/weapon/disk/blue
	name = "blue diskette"
	icon_state = "disk_blue"
	item_state = "disk_blue"
	faction = "Bluford Stock and Bonds"

/obj/item/weapon/disk/blue/fake
	name = "blue diskette"
	faction = "Bluford Stock and Bonds"
	fake = TRUE

/obj/item/weapon/disk/yellow
	name = "yellow diskette"
	icon_state = "disk_yellow"
	item_state = "disk_yellow"
	faction = "Goldstein Solutions"

/obj/item/weapon/disk/yellow/fake
	name = "yellow diskette"
	faction = "Goldstein Solutions"
	fake = TRUE

/obj/item/weapon/disk/green
	name = "green diskette"
	icon_state = "disk_green"
	item_state = "disk_green"
	faction = "Greene Traders Co-ops"

/obj/item/weapon/disk/green/fake
	name = "green diskette"
	faction = "Greene Traders Co-ops"
	fake = TRUE

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

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	w_class = 3.0
/obj/item/weapon/paper_bin/police
	name = "incomming documents"
	desc = "incomming documents and warrants will arrive here."
	amount = 0
/obj/item/weapon/paper/police
	icon_state = "police_record"
	base_icon = "police_record"
	name = "Police Record"
/obj/item/weapon/paper/police/warrant
	icon_state = "police_record"
	base_icon = "police_record"
	name = "Arrest Warrant"
	var/tgt = "Unknown"
	var/tgtcmp = "Unknown"
	New()
		..()
		icon_state = "police_record"
		spawn(10)
			info = "<center>POLICE DEPARTMENT<hr><large><b>Arrest Warrant No. [rand(1000,9999)]</b></large><hr><br>Police forces are hereby authorized and directed to detain <b>[tgt]</b>, working for <b><i>[tgtcmp]</i></b>. They will disregard any claims of immunity or privilege by the Suspect or agents acting on the Suspect's behalf. Police forces shall bring <b>[tgt]</b> forthwith to the Police Station.<br><br><small><center><i>Form Model 13-B</i><center></small><hr>"

/obj/item/weapon/paper/police/searchwarrant
	icon_state = "police_warrant"
	base_icon = "police_warrant"
	name = "Search Warrant"
	var/cmp = "Unknown"
	New()
		..()
		icon_state = "police_warrant"
		spawn(10)
			info = "<center>POLICE DEPARTMENT<hr><large><b>Search Warrant No. [rand(100,999)]</b></large><hr><br>Police forces are hereby authorized and directed to search all and every property owned by <b>[cmp]</b>. They will disregard any claims of immunity or privilege by the Suspect or agents acting on the Suspect's behalf.<br><br><small><center><i>Form Model 13-C1</i></center></small><hr>"
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
/mob/proc/get_coded_loc()
	var/a = ceil(x/22)
	var/b = 10-ceil(y/22)
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