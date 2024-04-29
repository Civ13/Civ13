// Diplomatic variables, very important
/datum/external_relations
	var/list/npc_faction_relations = list(
		"faction_1_relations" = 50,
		"faction_2_relations" = 50,
		"faction_3_relations" = 50,
		"faction_4_relations" = 50,
		"faction_5_relations" = 50,
	)

var/global/datum/external_relations/external_relations = new()

/obj/map_metadata/pepelsibirsk
	ID = MAP_PEPELSIBIRSK
	title = "Pepelsibirsk"
	lobby_icon = "icons/lobby/pepelsibirsk.png"
	no_winner = "The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/taiga)
	respawn_delay = 1200 // 2 minutes
	has_hunger = TRUE

	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "1975 A.D. Q4 (ROUND SETUP)"
	ordinal_age = 7
	civilizations = TRUE
	nomads = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big><b>Following a limited thermonuclear exchange which saw most central authorities in the northern hemisphere collapse, it appears Pepelsibirsk was left mostly untouched. You must bring the city to prosperity!</b></big>"
	ambience = list('sound/ambience/desert.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Molchat Doma - Toska:1" = 'sound/music/toska.ogg',)
	gamemode = "Cold War"
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = TRUE
	default_research = 180
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	var/real_season = "FALL"
	var/quarter = 1
	var/year = 1976
	//Trader spawnpoint
	var/trader_spawnpoint = "trader_spawnpoint"
	
	#define CHINA_RELATIONS external_relations.npc_faction_relations["faction_1_relations"]
	#define SOVIET_RELATIONS external_relations.npc_faction_relations["faction_2_relations"]
	#define PACIFIC_RELATIONS external_relations.npc_faction_relations["faction_3_relations"]
	#define CIV_RELATIONS external_relations.npc_faction_relations["faction_4_relations"]
	#define MIL_RELATIONS external_relations.npc_faction_relations["faction_5_relations"]

/obj/map_metadata/pepelsibirsk/New()
	..()
	relations_subsystem()
	send_traders()
	enemy_attacks()
	recover_relations()
	check_relations_msg()
	time_update(age, quarter, year)
	spawn(1)
		seasons()

/obj/map_metadata/pepelsibirsk/seasons()
	if (real_season == "FALL")
		season = "WINTER"
		to_chat(world, "<big>The <b>Winter</b> has started.</big>")
		change_weather_somehow()
		spawn(1200)
			for (var/obj/structure/wild/tree/live_tree/TREES in world)
				TREES.change_season()
		for (var/turf/floor/dirt/flooded/D)
			D.ChangeTurf(/turf/floor/beach/water/flooded)
		for (var/turf/floor/dirt/ploughed/flooded/D)
			D.ChangeTurf(/turf/floor/beach/water/flooded)
		for(var/obj/structure/sink/S)
			if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
				S.dry = FALSE
				S.update_icon()
		for (var/turf/floor/beach/drywater/B in get_area_turfs(/area/caribbean/nomads/desert))
			B.ChangeTurf(/turf/floor/beach/water/swamp)
		for (var/turf/floor/beach/drywater2/C in get_area_turfs(/area/caribbean/nomads/desert))
			C.ChangeTurf(/turf/floor/beach/water/deep/swamp)
		for (var/turf/floor/dirt/jungledirt/JD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
			if (prob(50))
				JD.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/dry_lava/JD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
			if (prob(50))
				JD.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/jungledirt/JD2 in get_area_turfs(/area/caribbean/nomads/forest/savanna))
			if (prob(50))
				JD2.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/burned/BD in get_area_turfs(/area/caribbean/nomads/desert))
			if (prob(75))
				BD.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/dirt/burned/BDD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
			if (prob(75))
				BDD.ChangeTurf(/turf/floor/dirt/jungledirt)
		for (var/turf/floor/dirt/burned/BDD2 in get_area_turfs(/area/caribbean/nomads/forest/savanna))
			if (prob(75))
				BDD2.ChangeTurf(/turf/floor/dirt/jungledirt)
		for (var/turf/floor/dirt/DT in get_area_turfs(/area/caribbean/nomads/forest))
			if (!istype(DT, /turf/floor/dirt/underground))
				var/area/A = get_area(DT)
				if (A.climate == "temperate")
					if (prob(75))
						DT.ChangeTurf(/turf/floor/dirt/winter)
				else if (A.climate == "tundra" || A.climate == "taiga")
					DT.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/GT in get_area_turfs(/area/caribbean/nomads/forest))
			var/area/A = get_area(GT)
			if (A.climate == "temperate")
				if (prob(80))
					GT.ChangeTurf(/turf/floor/winter/grass)
			else if (A.climate == "tundra" || A.climate == "taiga")
				GT.ChangeTurf(/turf/floor/winter/grass)
		for (var/turf/floor/dirt/DTT in get_area_turfs(/area/caribbean/nomads/snow))
			if (!istype(DTT, /turf/floor/dirt/underground))
				DTT.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/GTT in get_area_turfs(/area/caribbean/nomads/snow))
			GTT.ChangeTurf(/turf/floor/winter/grass)
		real_season = "WINTER"
	else if (real_season == "SPRING")
		season = "SUMMER"
		to_chat(world, "<big>The <b>Summer</b> has started.</big>")
		change_weather_somehow()
		spawn(300)
			for (var/obj/structure/wild/tree/live_tree/TREES in world)
				TREES.change_season()
		for(var/obj/structure/sink/S in get_area_turfs(/area/caribbean/nomads/desert))
			if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
				S.dry = TRUE
				S.update_icon()
		for (var/turf/floor/beach/water/swamp/D in get_area_turfs(/area/caribbean/nomads/desert))
			if (D.z > 1)
				D.ChangeTurf(/turf/floor/beach/drywater)
		for (var/turf/floor/beach/water/deep/swamp/DS in get_area_turfs(/area/caribbean/nomads/desert))
			if (DS.z > 1)
				DS.ChangeTurf(/turf/floor/beach/drywater2)
		for (var/turf/floor/beach/water/flooded/DF)
			if (DF.z > 1)
				DF.ChangeTurf(/turf/floor/dirt/flooded)
		for (var/turf/floor/dirt/winter/DT in get_area_turfs(/area/caribbean/nomads/forest))
			var/area/A = get_area(DT)
			if (A.climate == "temperate")
				DT.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/GT in get_area_turfs(/area/caribbean/nomads/forest))
			var/area/A = get_area(GT)
			if (A.climate == "temperate")
				GT.ChangeTurf(/turf/floor/grass)
		for (var/turf/floor/winter/WT in get_area_turfs(/area/caribbean/roofed))
			WT.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/dirt/winter/WT in get_area_turfs(/area/caribbean/roofed))
			WT.ChangeTurf(/turf/floor/dirt)
		real_season = "SUMMER"
	else if (real_season == "WINTER")
		season = "SPRING"
		to_chat(world, "<big>The weather is getting warmer in other places of the world, but not here. It is now <b>Spring</b>.</big>")
		real_season = "SPRING"
	else if (real_season == "SUMMER")
		season = "FALL"
		to_chat(world, "<big>The warmth of summer abruptly ends, being replaced with strong winds and rain, swiftly turning to snowstorms and ice. It is now <b>Fall</b>.</big>")
		spawn(1200)
			for (var/obj/structure/wild/tree/live_tree/TREES in world)
				TREES.change_season()
		for (var/turf/floor/dirt/flooded/D)
			D.ChangeTurf(/turf/floor/beach/water/flooded)
		for (var/turf/floor/dirt/ploughed/flooded/D)
			D.ChangeTurf(/turf/floor/beach/water/flooded)
		for(var/obj/structure/sink/S)
			if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
				S.dry = FALSE
				S.update_icon()
		for (var/turf/floor/beach/drywater/B in get_area_turfs(/area/caribbean/nomads/desert))
			B.ChangeTurf(/turf/floor/beach/water/swamp)
		for (var/turf/floor/beach/drywater2/C in get_area_turfs(/area/caribbean/nomads/desert))
			C.ChangeTurf(/turf/floor/beach/water/deep/swamp)
		for (var/turf/floor/dirt/jungledirt/JD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
			if (prob(50))
				JD.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/dry_lava/JD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
			if (prob(50))
				JD.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/jungledirt/JD2 in get_area_turfs(/area/caribbean/nomads/forest/savanna))
			if (prob(50))
				JD2.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/burned/BD in get_area_turfs(/area/caribbean/nomads/desert))
			if (prob(75))
				BD.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/dirt/burned/BDD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
			if (prob(75))
				BDD.ChangeTurf(/turf/floor/dirt/jungledirt)
		for (var/turf/floor/dirt/burned/BDD2 in get_area_turfs(/area/caribbean/nomads/forest/savanna))
			if (prob(75))
				BDD2.ChangeTurf(/turf/floor/dirt/jungledirt)
		for (var/turf/floor/dirt/DT in get_area_turfs(/area/caribbean/nomads/forest))
			if (!istype(DT, /turf/floor/dirt/underground))
				var/area/A = get_area(DT)
				if (A.climate == "temperate")
					if (prob(75))
						DT.ChangeTurf(/turf/floor/dirt/winter)
				else if (A.climate == "tundra" || A.climate == "taiga")
					DT.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/GT in get_area_turfs(/area/caribbean/nomads/forest))
			var/area/A = get_area(GT)
			if (A.climate == "temperate")
				if (prob(80))
					GT.ChangeTurf(/turf/floor/winter/grass)
			else if (A.climate == "tundra" || A.climate == "taiga")
				GT.ChangeTurf(/turf/floor/winter/grass)
		for (var/turf/floor/dirt/DTT in get_area_turfs(/area/caribbean/nomads/snow))
			if (!istype(DTT, /turf/floor/dirt/underground))
				DTT.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/GTT in get_area_turfs(/area/caribbean/nomads/snow))
			GTT.ChangeTurf(/turf/floor/winter/grass)
		real_season = "FALL"
	spawn(30 MINUTES)
		seasons()

/obj/map_metadata/pepelsibirsk/cross_message(faction)
	return "<font size = 3><span class = 'notice'><b>The all-clear has been given. You may now leave the Soviet.</b></font></span>"

/obj/map_metadata/pepelsibirsk/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/pepelsibirsk/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE

////// DIPLOMATIC RELATIONS MANAGEMENT //////

/obj/map_metadata/pepelsibirsk/proc/relations_subsystem()
	spawn(3 SECONDS)
		for(var/relation in external_relations.npc_faction_relations)
			if (external_relations.npc_faction_relations > 100)
				external_relations.npc_faction_relations[relation] = 100
			else if (external_relations.npc_faction_relations[relation] < 0)
				external_relations.npc_faction_relations[relation] = 0
		relations_subsystem()
	return

/obj/map_metadata/pepelsibirsk/proc/check_relations_msg()
	to_chat(world, "<font size = 4><span class = 'notice'><b>Diplomatic Relations:</b></font></span>")
	to_chat(world, "<br><font size = 3><span class = 'notice'>People's Republic of China: <b>[CHINA_RELATIONS]</b></span></font>")
	to_chat(world, "<br><font size = 3><span class = 'notice'>Union of Soviet Socialist Republics: <b>[SOVIET_RELATIONS]</b></span></font>")
	to_chat(world, "<br><font size = 3><span class = 'notice'>United States of the Pacific: <b>[PACIFIC_RELATIONS]</b></span></font>")
	to_chat(world, "<br><font size = 3><span class = 'notice'>Naroddnygorod: <b>[CIV_RELATIONS]</b></span></font>")
	to_chat(world, "<br><font size = 3><span class = 'notice'>Pepelsibirsk-1: <b>[MIL_RELATIONS]</b></span></font>")
	spawn(5 MINUTES)
		check_relations_msg()
	return

/obj/map_metadata/pepelsibirsk/proc/recover_relations()
	if (CIV_RELATIONS <= 26)
		CIV_RELATIONS += 0.02
	if (MIL_RELATIONS <= 26)
		MIL_RELATIONS += 0.02
	spawn(20 MINUTES)
		recover_relations()
	return

////// TIME CODE ////// (thanks malt)

/obj/map_metadata/pepelsibirsk/proc/time_quarters()
	quarter++
	if(quarter >=5)
		quarter = 1
		year++
		to_chat(world, "<font size = 3><span class = 'notice'><b>The year has advanced to [year].</b></font></span>")
	else
		to_chat(world, "<font size = 3><span class = 'notice'><b>The quarter has advanced to Q[quarter].</b></font></span>")
	return

/obj/map_metadata/pepelsibirsk/proc/time_update()
	age = "[year] A.D. Q[quarter]"
	world.log << "Time_update has been triggered, the date is now [year] A.D. Q[quarter]."
	spawn (30 MINUTES)
		time_quarters()
		time_update()
	return

////// PEPELSIBIRSK TRAVELING MERCHANTS //////
/obj/structure/vending/sales/pepelsibirsk
	var/faction_relations

/obj/structure/vending/sales/pepelsibirsk/proc/dropwares()
	return

/obj/structure/vending/sales/pepelsibirsk/ex_act(severity)
	dropwares()
	qdel(src)
	return

/obj/structure/vending/sales/pepelsibirsk/bullet_act()
	dropwares()
	qdel(src)
	return

/obj/structure/vending/sales/pepelsibirsk/pacific_trader
	name = "U.S.P Trader"
	desc = "The United States of the Pacific has come to trade."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "afghcia"
	faction_relations = "faction_3_relations"
	products = list(
		//Weapons
		/obj/item/weapon/gun/projectile/submachinegun/m16/commando = 2,
		/obj/item/weapon/gun/projectile/submachinegun/m16/m16a2 = 5,
		/obj/item/weapon/gun/launcher/grenade/standalone/m79 = 2,
		/obj/item/weapon/gun/launcher/rocket/bazooka = 2,
		/obj/item/weapon/gun/projectile/submachinegun/m14/sniper = 1,
		/obj/item/weapon/attachment/scope/adjustable/advanced/holographic = 2,
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog = 2,
		/obj/item/weapon/attachment/scope/adjustable/advanced/reddot = 2,
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope = 2,
		/obj/item/weapon/attachment/under/foregrip = 2,
		/obj/item/weapon/attachment/silencer/pistol = 2,
		/obj/item/weapon/attachment/silencer/rifle = 2,
		/obj/item/weapon/attachment/silencer/shotgun = 2,
		/obj/item/weapon/attachment/silencer/smg = 2,
		/obj/item/weapon/foldable/atgm/bgm_tow = 1,

		//Ammunition
		/obj/item/ammo_magazine/m16 = 8,
		/obj/item/ammo_magazine/m14 = 3,
		/obj/item/ammo_casing/rocket/bazooka = 4,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 3,
		/obj/item/weapon/plastique/c4 = 2,
		/obj/item/ammo_casing/rocket/atgm = 4,
		/obj/item/ammo_casing/rocket/atgm/he = 4,

		//Clothing
		/obj/item/clothing/under/us_uni/us_camo_woodland = 8,
		/obj/item/clothing/accessory/storage/webbing/us_vest = 8,
		/obj/item/clothing/suit/storage/coat/ww2/us_coat = 8,
		/obj/item/clothing/shoes/jackboots/modern = 8,
		/obj/item/clothing/accessory/armor/coldwar/pasgt = 2,
		/obj/item/clothing/head/helmet/modern/pasgt = 2,

		//Food and Drink
		/obj/item/weapon/reagent_containers/food/snacks/burger = 4,
		/obj/item/weapon/reagent_containers/food/snacks/cheeseburger = 4,
		/obj/item/weapon/reagent_containers/food/snacks/hotdog = 4,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/american = 3,
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/pumpkinpie = 1,
		/obj/item/weapon/reagent_containers/food/snacks/applepie = 1,

		//Miscellaneous
		/obj/item/weapon/telephone/mobile = 2,
		/obj/structure/anti_air_crate = 1,
	)
	prices = list(
		//Weapons
		/obj/item/weapon/gun/projectile/submachinegun/m16/commando = 200,
		/obj/item/weapon/gun/projectile/submachinegun/m16/m16a2 = 160,
		/obj/item/weapon/gun/launcher/grenade/standalone/m79 = 150,
		/obj/item/weapon/gun/launcher/rocket/bazooka = 150,
		/obj/item/weapon/gun/projectile/submachinegun/m14/sniper = 200,
		/obj/item/weapon/attachment/scope/adjustable/advanced/holographic = 100,
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog = 100,
		/obj/item/weapon/attachment/scope/adjustable/advanced/reddot = 100,
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope = 100,
		/obj/item/weapon/attachment/under/foregrip = 100,
		/obj/item/weapon/attachment/silencer/pistol = 100,
		/obj/item/weapon/attachment/silencer/rifle = 100,
		/obj/item/weapon/attachment/silencer/shotgun = 100,
		/obj/item/weapon/attachment/silencer/smg = 100,
		/obj/item/weapon/foldable/atgm/bgm_tow = 1000,

		//Ammunition
		/obj/item/ammo_magazine/m16 = 20,
		/obj/item/ammo_magazine/m14 = 30,
		/obj/item/ammo_casing/rocket/bazooka = 200,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 80,
		/obj/item/weapon/plastique/c4 = 100,
		/obj/item/ammo_casing/rocket/atgm = 150,
		/obj/item/ammo_casing/rocket/atgm/he = 150,

		//Clothing
		/obj/item/clothing/under/us_uni/us_camo_woodland = 20,
		/obj/item/clothing/accessory/storage/webbing/us_vest = 20,
		/obj/item/clothing/suit/storage/coat/ww2/us_coat = 30,
		/obj/item/clothing/shoes/jackboots/modern = 20,
		/obj/item/clothing/accessory/armor/coldwar/pasgt = 100,
		/obj/item/clothing/head/helmet/modern/pasgt = 100,

		//Food and Drink
		/obj/item/weapon/reagent_containers/food/snacks/burger = 5,
		/obj/item/weapon/reagent_containers/food/snacks/cheeseburger = 5,
		/obj/item/weapon/reagent_containers/food/snacks/hotdog = 5,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/american = 10,
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/pumpkinpie = 20,
		/obj/item/weapon/reagent_containers/food/snacks/applepie = 20,

		//Miscellaneous
		/obj/item/weapon/telephone/mobile = 500,
		/obj/structure/anti_air_crate = 1000,
	)

/obj/structure/vending/sales/pepelsibirsk/pacific_trader/dropwares()
	for(var/product_key in products)
		for(var/i in 1 to products[product_key])
			if (prob(25))
				new product_key(get_turf(src))
	new /mob/living/human/corpse(get_turf(src))
	PACIFIC_RELATIONS -= rand(10, 25)
	to_chat(world, "<font size = 3><span class = 'notice'><b>A Pacifician trader has died. Relations with the United States of the Pacific have dropped to [PACIFIC_RELATIONS]!</b></font></span>")

/obj/structure/vending/sales/pepelsibirsk/chinese_trader
	name = "PRC Trader"
	desc = "现在我有冰淇淋我很喜欢冰淇淋."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "chinese_trader"
	faction_relations = "faction_1_relations"
	products = list(
		//Weapons
		/obj/item/weapon/gun/projectile/submachinegun/ak47/chinese = 3,
		/obj/item/weapon/gun/projectile/semiautomatic/sks/chinese = 3,
		/obj/item/weapon/gun/projectile/submachinegun/ppsh/chinese = 3,

		//Clothing
		/obj/item/clothing/suit/storage/coat/chinese/officer = 2,
		/obj/item/clothing/suit/storage/coat/chinese = 8,
		/obj/item/clothing/under/chinaguard = 8,
		/obj/item/clothing/head/chinaguardcap = 8,
		/obj/item/clothing/head/chinese_ushanka = 8,
		/obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized = 8,

		//Food and Drink
		/obj/item/weapon/reagent_containers/food/snacks/ssicle/osicle = 8,
	)
	prices = list(
		//Weapons
		/obj/item/weapon/gun/projectile/submachinegun/ak47/chinese = 50,
		/obj/item/weapon/gun/projectile/semiautomatic/sks/chinese = 30,
		/obj/item/weapon/gun/projectile/submachinegun/ppsh/chinese = 30,

		//Clothing
		/obj/item/clothing/suit/storage/coat/chinese/officer = 30,
		/obj/item/clothing/suit/storage/coat/chinese = 25,
		/obj/item/clothing/under/chinaguard = 25,
		/obj/item/clothing/head/chinaguardcap = 15,
		/obj/item/clothing/head/chinese_ushanka = 15,
		/obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized = 35,

		//Food and Drink
		/obj/item/weapon/reagent_containers/food/snacks/ssicle/osicle = 5,
	)

/obj/structure/vending/sales/pepelsibirsk/chinese_trader/dropwares()
	for(var/product_key in products)
		for(var/i in 1 to products[product_key])
			new product_key(get_turf(src))
	new /mob/living/human/corpse(get_turf(src))
	CHINA_RELATIONS -= rand(10, 25)
	to_chat(world, "<font size = 3><span class = 'notice'><b>A Chinese trader has died. Relations with the People's Republic of China have dropped to [CHINA_RELATIONS]!</b></font></span>")

/obj/structure/vending/sales/pepelsibirsk/soviet_trader
	name = "Soviet Trader"
	desc = "Вы неправильно используете это программное обеспечение для перевода. Пожалуйста, проконсультируйтесь с руководством по программному обеспечению."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "soviet_trader"
	faction_relations = "faction_2_relations"
	products = list(
		//Weapons
		/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso = 1,
		/obj/item/weapon/gun/projectile/shotgun/pump/ks23 = 1,
		/obj/item/weapon/gun/launcher/rocket/single_shot/rpg22 = 2,
		/obj/item/weapon/gun/launcher/grenade/underslung/gp25 = 2,
		/obj/item/weapon/gun/launcher/rocket/rpg7 = 1,

		//Ammunition
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 3,
		/obj/item/ammo_casing/rocket/pg7v = 2,
		/obj/item/ammo_casing/rocket/og7v = 2,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 3,
		/obj/item/weapon/plastique/russian = 1,

		//Food and Drink
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/russian = 5,
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel = 5,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka = 5,
		/obj/item/weapon/reagent_containers/food/drinks/flask/barflask = 3,
		/obj/item/weapon/reagent_containers/food/drinks/flask/officer = 3,
		/obj/item/weapon/reagent_containers/food/drinks/teapot/filled = 3,
		/obj/item/weapon/reagent_containers/food/drinks/golden_cup = 1,

		//Medicines
		/obj/item/weapon/storage/pill_bottle/tramadol = 4,
		/obj/item/weapon/storage/pill_bottle/penicillin = 4,
		/obj/item/weapon/storage/pill_bottle/paracetamol = 4,
		/obj/item/weapon/storage/pill_bottle/citalopram = 4,
		/obj/item/weapon/storage/pill_bottle/potassium_iodide = 4,
	)
	prices = list(
		//Weapons
		/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso = 200,
		/obj/item/weapon/gun/projectile/shotgun/pump/ks23 = 150,
		/obj/item/weapon/gun/launcher/rocket/single_shot/rpg22 = 250,
		/obj/item/weapon/gun/launcher/grenade/underslung/gp25 = 100,
		/obj/item/weapon/gun/launcher/rocket/rpg7 = 100,

		//Ammunition
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 40,
		/obj/item/ammo_casing/rocket/pg7v = 100,
		/obj/item/ammo_casing/rocket/og7v = 100,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 40,
		/obj/item/weapon/plastique/russian = 30,

		//Food and Drink
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/russian = 10,
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel = 10,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka = 10,
		/obj/item/weapon/reagent_containers/food/drinks/flask/barflask = 25,
		/obj/item/weapon/reagent_containers/food/drinks/flask/officer = 50,
		/obj/item/weapon/reagent_containers/food/drinks/teapot/filled = 25,
		/obj/item/weapon/reagent_containers/food/drinks/golden_cup = 500,

		//Medicines
		/obj/item/weapon/storage/pill_bottle/tramadol = 150,
		/obj/item/weapon/storage/pill_bottle/penicillin = 150,
		/obj/item/weapon/storage/pill_bottle/paracetamol = 150,
		/obj/item/weapon/storage/pill_bottle/citalopram = 150,
		/obj/item/weapon/storage/pill_bottle/potassium_iodide = 150,
	)

/obj/structure/vending/sales/pepelsibirsk/soviet_trader/dropwares()
	for(var/product_key in products)
		for(var/i in 1 to products[product_key])
			new product_key(get_turf(src))
	new /mob/living/human/corpse(get_turf(src))
	SOVIET_RELATIONS -= rand(10, 25)
	to_chat(world, "<font size = 3><span class = 'notice'><b>A Soviet trader has died. Relations with the Union of Soviet Socialist Republics have dropped to [MIL_RELATIONS]!</b></font></span>")

////// TRAVELING MERCHANTS MANAGEMENT //////
/obj/map_metadata/pepelsibirsk/proc/send_traders() //Picks a turf from trader_spawnpoint and sends traders there if relations are high enough.
	world.log << "send_traders has been triggered"
	var/list/turfs = list()
	var/spawnpoint
	spawn(1)
		turfs = latejoin_turfs[trader_spawnpoint]
		if (CHINA_RELATIONS >= 26)
			var/traderpath = /obj/structure/vending/sales/pepelsibirsk/chinese_trader
			spawnpoint = pick(turfs)
			var/trader = new traderpath(get_turf(spawnpoint))
			world.log << "[trader] has been spawned at with get_turf, example: [get_turf(spawnpoint)]."
			spawn(10 MINUTES)
				world.log << "[trader] has been deleted."
				qdel(trader)
		if (SOVIET_RELATIONS >= 26)
			var/traderpath = /obj/structure/vending/sales/pepelsibirsk/soviet_trader
			spawnpoint = pick(turfs)
			var/trader = new traderpath(get_turf(spawnpoint))
			world.log << "[trader] has been spawned with get_turf, example: [get_turf(spawnpoint)]."
			spawn(10 MINUTES)
				world.log << "[trader] has been deleted."
				qdel(trader)
		if (PACIFIC_RELATIONS >= 26)
			var/traderpath = /obj/structure/vending/sales/pepelsibirsk/pacific_trader
			spawnpoint = pick(turfs)
			var/trader = new traderpath(get_turf(spawnpoint))
			world.log << "[trader] has been spawned with get_turf, example: [get_turf(spawnpoint)]."
			spawn(10 MINUTES)
				world.log << "[trader] has been deleted."
				qdel(trader)
		return

	var/traders = list()
	if (CHINA_RELATIONS >= 26)
		traders += "the Chinese"
	if (SOVIET_RELATIONS >= 26)
		traders += "the Soviets"
	if (PACIFIC_RELATIONS >= 26)
		traders += "the Pacificans"

	if (length(traders) > 1)
		traders[length(traders)] = "and [traders[length(traders)]]"
		to_chat(world, "<font size = 4><span class = 'notice'>[jointext(traders, ", ")] have arrived to trade.</b></font></span>")
		world.log << "[jointext(traders, ", ")] have arrived to trade."
	else
		to_chat(world, "<font size = 4><span class = 'notice'>Due to poor relations, no one has arrived to trade.</b></font></span>")
		world.log << "Due to poor relations, no one has arrived to trade."

	spawn(30 MINUTES)
		send_traders(trader_spawnpoint)
		return

////// PEPELSIBIRSK PERSONAL DOCUMENTS //////
/obj/item/weapon/personal_documents
	name = "Personal Documents"
	desc = "The identification papers of a citizen."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "passport"
	item_state = "paper"
	throwforce = FALSE
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_ID | SLOT_POCKET
	throw_range = TRUE
	throw_speed = TRUE
	attack_verb = list("bapped")
	flammable = TRUE
	var/mob/living/human/owner = null
	var/document_name = ""
	var/list/document_details = list()
	var/list/guardnotes = list()
	secondary_action = TRUE
	flags = FALSE
	New()
		..()
		spawn(2 SECONDS)
			if (ishuman(loc))
				var/mob/living/human/H = loc
				document_name = H.real_name
				owner = H
				name = "[document_name]'s personal documents"
				desc = "The identification papers of <b>[document_name]</b>."
				var/job = "Working"
				if (istype(H.original_job, /datum/job/civilian/civnomad))
					switch(H.nationality)
						if ("German")
							job = "Citizen of the German Democratic Republic, expatriated and working [pick("in the Pepelsibirsk research facility","in the Pepelsibirsk hospital", "for the local KGB office", "in the Pepelsibirsk car factory")]."
						if ("Ukrainian")
							job = "Internal migrant from the Ukrainian SSR, working [pick("for the KGB", "for the city Soviet", "in the Pepelsibirsk mine", "in the Pepelsibirsk car factory", "at the collective farm in Pepelsibirsk", "in the Pepelsibirsk power plant", "at the collective farm in Pepelsibirsk", "in the Pepelsibirsk mine", "in the Pepelsibirsk research facility", "in the Pepelsibirsk hospital", "for the Soviet Armed Forces", "for the local Militsiya")]."
						if ("Polish")
							job = "Citizen of the Polish Socialist Republic, expatriated and working in [pick("the Pepelsibirsk mine","the Pepelsibirsk car factory", "the collective farm in Pepelsibirsk", "the Pepelsibirsk power plant")]."
						if ("Russian")
							job = "Pepelsibirsk local, working [pick("for the KGB", "for the city Soviet", "in the Pepelsibirsk mine", "in the Pepelsibirsk car factory", "at the collective farm in Pepelsibirsk", "in the Pepelsibirsk power plant", "at the collective farm in Pepelsibirsk", "in the Pepelsibirsk mine", "in the Pepelsibirsk research facility", "in the Pepelsibirsk hospital", "for the Soviet Armed Forces", "for the local Militsiya")]."
					document_details = list(H.h_style, H.gender, H.age, job)

/obj/item/weapon/personal_documents/examine(mob/user)
	..(user)
	to_chat(user, "<span class='info'>*---------*</span>")
	to_chat(user, "<b><span class='info'>Hair:</b> [document_details[1]]</span>")
	to_chat(user, "<b><span class='info'>Gender:</b> [document_details[2]]</span>")
	to_chat(user, "<b><span class='info'>Age:</b> [document_details[3]] years</span>")
	to_chat(user, "<b><span class='info'>Employment and Citizenship Status:</b> [document_details[4]]</span>")
	to_chat(user, "<span class='info'>*---------*</span>")
	if (guardnotes.len)
		for(var/i in guardnotes)
			to_chat(user, "NOTE: [i]")
		to_chat(user, "<span class='info'>*---------*</span>")

/obj/item/weapon/personal_documents/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!ishuman(H))
		return
	if (istype(I, /obj/item/weapon/pen))
		var/confirm = WWinput(H, "Do you want to add a note to these documents?", "Personal Documents", "No", list("No","Yes"))
		if (confirm == "No")
			return
		else
			var/texttoadd = input(H, "What do you want to write? Up to 150 characters", "Notes", "") as text
			texttoadd = sanitize(texttoadd, 150, FALSE)
			texttoadd = "<i>[texttoadd] - <b>[H.real_name]</b></i>"
			guardnotes += texttoadd
			return

/obj/item/weapon/personal_documents/secondary_attack_self(mob/living/human/user)
	showoff(user)
	return

////// TRADING CODE ////// (it's my magnum opus -Terrariola)
/obj/structure/pepelsibirsk_radio //does nothing too important, ignore
	name = "If you see this, talk to an admin."
	desc = "THIS SHOULD NOT EXIST. -Terrariola"
	icon = 'icons/obj/structures.dmi'
	icon_state = "supply_radio"

/obj/structure/pepelsibirsk_radio/supply_radio
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
	var/list/civ_catalogue = list( //type name, path, price
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
		list("medical supplies", /obj/item/weapon/storage/firstaid/adv,50),
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
		list("6B2 vest crate (5)", /obj/structure/closet/crate/pepelsibirsk/sixb2,1000),
	)

/obj/structure/pepelsibirsk_radio/supply_radio/no_scam
	name = "long range high-sensitivity supply radio"
	desc = "Use this to request supplies to be delivered to the city. It appears like the microphone on it is set to much too high sensitivity for you to safely arrange a scam."

/obj/structure/pepelsibirsk_radio/supply_radio/proc/update_cost(final_list, final_cost, choice, user, scam)
	if (choice == "Pepelsibirsk 1 (MIL)" && scam != "Yes, scam them!")
		MIL_RELATIONS += final_cost*0.02
	else if (choice == "Narodnyygorod (CIV)" && scam != "Yes, scam them!")
		CIV_RELATIONS += final_cost*0.02
	else if (choice == "Narodnyygorod (CIV)" && scam == "Yes, scam them!")
		CIV_RELATIONS -= final_cost*0.08
	else if (choice == "Pepelsibirsk 1 (MIL)" && scam == "Yes, scam them!")
		MIL_RELATIONS -= final_cost*0.08
	if (scam != "Yes, scam them!")
		to_chat(user, "Your item will arrive in 60 seconds. Relations with [choice] have increased by [final_cost*0.02].")
	else if (scam == "Yes, scam them!")
		to_chat(user, "Your item will arrive in 60 seconds. Relations with [choice] have decreased by [final_cost*0.08].")
	spawn(1 MINUTE)
		var/list/turfs = list()
		if (faction_treasury != "craftable")
			turfs = latejoin_turfs[factionarea]
		else
			turfs = list(get_turf(locate(x,y+1,z)))
		var/spawnpoint
		spawnpoint = pick(turfs)
		var/tpath = final_list[2]
		new tpath(get_turf(spawnpoint))
		to_chat(user, "Your [final_list[1]] has arrived.")
	return

/obj/structure/pepelsibirsk_radio/supply_radio/proc/purchase(user, choice, catalogue)
	///VARS///
	var/final_cost //The final cost of the purchased product
	var/list/final_list = list() //The details for the product to be purchased
	var/list/display = list() //The products to be displayed, includes name of crate and price
	var/list/scamornot = list (
		"No, we're honest.",
		"Yes, scam them!",
	)
	var/scam

	///Display the menu asking for what you want to purchase
	for (var/list/i in catalogue)
		display += "[i[1]], [i[3]] rubles"
		display += "Cancel Purchase"
	var/choice2 = WWinput(user, "Current Rubles: [money]", "Order a crate", "Cancel Purchase", display)
	if(istype(src, /obj/structure/pepelsibirsk_radio/supply_radio/no_scam))
		scam = "No, we're honest."
	else
		scam = WWinput(user, "Current Rubles: [money]", "Shall we scam them?", "No, we're honest.", scamornot)
	var/list/choicename = splittext(choice2, ", ")

	///ACTUAL PURCHASING LOGIC///
	if (choice2 != "Cancel Purchase")
		for(var/list/i2 in catalogue) //Goes through everything in the chosen catalogue
			if (i2[1]== choicename[1]) //Checks if each item it goes through is the correct item
				final_list = i2 //If it is, set that to final_list
				world.log << "A purchase has been made: [final_list[1]], [final_list[2]], [final_list[3]]"
				final_cost = (final_list[3]) //Set the cost of the item based on the cost value in the list
				if (final_list[3] <= money || scam == "Yes, scam them!" )
					if (scam != "Yes, scam them!")
						money -= final_cost
					update_cost(final_list, final_cost, choice, user, scam)
					if((round(money) >= 1))
						new/obj/item/stack/money/rubles(loc, round(money))
					if (((money) - round(money)) > 0)
						new/obj/item/stack/money/coppercoin(loc, round(((money) - round(money)), 0.01) * 100)	//This should never happen, but just in case
					money = 0
				else // you're broke
					if((round(money) >= 1))
						new/obj/item/stack/money/rubles(loc, round(money))
					if (((money) - round(money)) > 0)
						new/obj/item/stack/money/coppercoin(loc, round(((money) - round(money)), 0.01) * 100)	//This should never happen, but just in case
					money = 0
					to_chat(user, "You don't have enough money for this item.")
				break
	else
		if((round(money) >= 1)) //giving money back
			new/obj/item/stack/money/rubles(loc, round(money))
		if (((money) - round(money)) > 0)
			new/obj/item/stack/money/coppercoin(loc, round(((money) - round(money)), 0.01) * 100)	//This should never happen, but just in case
		money = 0
		return

/obj/structure/pepelsibirsk_radio/supply_radio/proc/company(user)
	///VARS///
	var/catalogue = list()
	var/list/companies = list(
		"Cancel Purchase",
		"Pepelsibirsk 1 (MIL)",
		"Narodnyygorod (CIV)",
	)

	///PURCHASING LOGIC///
	var/choice = WWinput(user, "Pick a supplier:", "Supplier", "Cancel Purchase", companies) //Dialog box
	if (choice == "Cancel Purchase")
		///Giving your money back///
		if((round(money) >= 1))
			new/obj/item/stack/money/rubles(loc, round(money))		//Rubles
		if (((money) - round(money)) > 0)
			new/obj/item/stack/money/coppercoin(loc, round(((money) - round(money)), 0.01) * 100)  //This should never happen, but just in case
		money = 0
		return
	if (choice == "Narodnyygorod (CIV)")
		catalogue = civ_catalogue
		if (CIV_RELATIONS <= 25 )
			to_chat(user, "Your relations with this faction are too low!")
			return
	else if (choice == "Pepelsibirsk 1 (MIL)")
		catalogue = mil_catalogue
		if (MIL_RELATIONS <= 25 )
			to_chat(user, "Your relations with this faction are too low!")
			return
	purchase(user, choice, catalogue)
	return

/obj/structure/pepelsibirsk_radio/supply_radio/attack_hand(var/mob/living/human/user as mob)
	company(user)
	return

/obj/structure/pepelsibirsk_radio/supply_radio/attackby(var/obj/item/stack/W as obj, var/mob/living/human/user as mob)
	if (W.amount && istype(W, /obj/item/stack/money/rubles))
		money += W.value*W.amount
		qdel(W)
		return
	else
		to_chat(user, "You need to use rubles.")
		return


/obj/structure/pepelsibirsk_radio/export_radio
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
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/pepelsibirsk_radio/export_radio/attackby(var/obj/item/W as obj, var/mob/living/human/user as mob)
	if (W.value == 0)
		to_chat(user, "There is no demand for this item.")
		return
	else
		if (CIV_RELATIONS >= 25)
			if (istype(W))
				marketval = W.value + rand(-round(W.value/10),round(W.value/10))
				moneyin = marketval*W.amount-((marketval*W.amount)*(export_tax_rate/100))
				var/exportChoice = WWinput(user, "Sell the whole stack for [moneyin] rubles?", "Exporting", "Yes", list("Yes", "No"))
				if (exportChoice == "Yes")
					if (W && marketval > 0)
						new/obj/item/stack/money/rubles(loc, round(moneyin))	// Rubles
						qdel(W)
						marketval = 0
						return
			else
				marketval = 0
				return
		else
			to_chat(user, "Your relations with Narodnyygorod are too low!")
			return


////// ENEMY AIR BOMBING //////

/obj/map_metadata/pepelsibirsk/proc/bombing(var/turf/T, direction, aircraft_name)
	var/strikenum = rand(1, 10)
	var/xoffset = 0
	var/yoffset = 0
	var/direction_xoffset = 0
	var/direction_yoffset = 0

	to_chat(world, SPAN_DANGER("<font size=4>And drops a barrage of bombs!</fnt>"))
	
	spawn(15)
		for (var/i = 1, i <= strikenum, i++)
			switch (direction)
				if (1)
					direction_yoffset += 3
					xoffset = rand(-2,2)
					yoffset = rand(0,1)
				if (2)
					direction_xoffset += 3
					xoffset = rand(0,1)
					yoffset = rand(-2,2)
				if (3)
					direction_yoffset -= 3
					xoffset = rand(-2,2)
					yoffset = rand(0,1)
				if (4)
					direction_xoffset -= 3
					xoffset = rand(0,1)
					yoffset = rand(-2,2)
			spawn(i*8)
				explosion(locate((T.x + xoffset + direction_xoffset),(T.y + yoffset + direction_yoffset),T.z),0,1,5,3,sound='sound/weapons/Explosives/FragGrenade.ogg')

/obj/map_metadata/pepelsibirsk/proc/try_shoot_down_aircraft(var/turf/T, direction, aircraft_name)
	spawn(8 SECONDS)
		var/sound/sam_sound = sound('sound/effects/aircraft/sa6_sam_site.ogg', repeat = FALSE, wait = FALSE, channel = 777)
		sam_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				to_chat(M, SPAN_DANGER("<big>A SAM site fires at the [aircraft_name]!</big>"))
				M.client << sam_sound
		spawn(5 SECONDS)
			if (prob(95)) // Shoot down the jet
				var/sound/uploaded_sound = sound((pick('sound/effects/aircraft/effects/metal1.ogg','sound/effects/aircraft/effects/metal2.ogg')), repeat = FALSE, wait = FALSE, channel = 777)
				uploaded_sound.priority = 250
				for (var/mob/M in player_list)
					if (!new_player_mob_list.Find(M))
						to_chat(M, SPAN_DANGER("<big>The SAM directly hits the [aircraft_name], shooting it down!</big>"))
						if (M.client)
							M.client << uploaded_sound
				log_game("Aircraft [aircraft_name] has been shot down.")
				return
			else // Evade the Anti-Air
				var/sound/uploaded_sound = sound((pick('sound/effects/aircraft/effects/missile1.ogg','sound/effects/aircraft/effects/missile2.ogg')), repeat = FALSE, wait = FALSE, channel = 777)
				uploaded_sound.priority = 250
				for (var/mob/M in player_list)
					if (!new_player_mob_list.Find(M))
						to_chat(M, SPAN_NOTICE("<big><b>The SAM misses the [aircraft_name]!</b></big>"))
						if (M.client)
							M.client << uploaded_sound
				bombing(T, direction, aircraft_name)

/obj/map_metadata/pepelsibirsk/proc/try_bombing(var/turf/T, direction, faction)
	var/aircraft_name
	switch(faction)
		if ("CHINA")
			new /obj/effect/plane_flyby/f16_no_message(T)
			aircraft_name = "Xi'an H-6"
		if ("SOVIET")
			new /obj/effect/plane_flyby/su25_no_message(T)
			aircraft_name = "MiG-27"
	to_chat(world, SPAN_DANGER("<font size=4>The clouds open up as a [aircraft_name] cuts through.</font>"))
	
	var/anti_air_in_range = FALSE
	for (var/obj/structure/milsim/anti_air/AA in range(60, T))
		anti_air_in_range++
	if (anti_air_in_range)
		try_shoot_down_aircraft(T, direction, aircraft_name)
	else
		bombing(T, direction, aircraft_name)
	return

/obj/map_metadata/pepelsibirsk/proc/bombing_location(faction)
	var/direction = rand(1, 4)
	var/turf/T = locate(rand(1, 255),rand(1, 255),2)
	try_bombing(T, direction, faction)

/obj/map_metadata/pepelsibirsk/proc/enemy_attacks()
	var/faction
	var/next_bombing_1 = rand(30 SECONDS, 30 MINUTES)
	var/next_bombing_2 = rand(30 SECONDS, 5 MINUTES)
	message_admins("The initial stage of the enemy_attacks() proc will be triggered in [next_bombing_1] deciseconds. The second stage will be triggered [next_bombing_2] deciseconds after that.")
	world.log << "The initial stage of the enemy_attacks() proc will be triggered in [next_bombing_1] deciseconds. The second stage will be triggered [next_bombing_2] deciseconds after that."
	spawn(next_bombing_1)
		if (CHINA_RELATIONS <= 25)
			faction = "CHINA"
			bombing_location(faction)
			CHINA_RELATIONS += 0.5
		spawn(next_bombing_2)
			if (SOVIET_RELATIONS <= 25)
				faction = "SOVIET"
				bombing_location(faction)
				SOVIET_RELATIONS += 0.5
			enemy_attacks()

/obj/structure/anti_air_crate
	name = "anti-air crate"
	desc = "A supply crate used to make SAM sites."
	icon = 'icons/obj/junk.dmi'
	icon_state = "supply_crate"
	anchored = FALSE
	flammable = FALSE
	w_class = ITEM_SIZE_LARGE
	opacity = FALSE
	density = TRUE
	var/health = 250

/obj/structure/anti_air_crate/New()
	..()
	overlays += image(icon = 'icons/obj/junk.dmi', icon_state = "o-ru")

/obj/structure/anti_air_crate/proc/try_destroy()
	if (health <= 0)
		visible_message(SPAN_DANGER("<big>\The [src] took too much damage and explodes!</big>"))
		explosion(get_turf(src),0,1,1,1)
		qdel(src)
		return

/obj/structure/anti_air_crate/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 600
		if (2.0)
			health -= 200
		if (3.0)
			health -= 100
	try_destroy()

/obj/structure/anti_air_crate/bullet_act(var/obj/item/projectile/proj)
	health -= proj.damage * 0.01
	visible_message(SPAN_DANGER("\The [src] is hit by \the [proj.name]!"))
	try_destroy()

/obj/structure/anti_air_crate/attack_hand(mob/living/human/H as mob)
	var/AA_in_range = 0
	for (var/obj/structure/milsim/anti_air/AA in range(10, src)) // Check if there are friendly Anti-Air within 10 tiles, if so block the build
		AA_in_range++
	if (AA_in_range)
		to_chat(H, SPAN_WARNING("<big>You cannot build Anti-Air so close to another, consider moving away.</big>"))
		return
	else
		to_chat(H, SPAN_NOTICE("You starting building an Anti-Air with \the [src]."))
		if (do_after(H, 30 SECONDS, src))
			to_chat(H, SPAN("good", "<big>You build an Anti-Air with \the [src].</big>"))
			var/obj/structure/milsim/anti_air/AA = new/obj/structure/milsim/anti_air(get_turf(src))
			AA.attack_hand(H)
			qdel(src)
			return
	return

/obj/structure/warehouse_book
	name = "warehouse inventory"
	desc = "A document containing a list of all goods in the warehouse."
	icon = 'icons/obj/library.dmi'
	icon_state = "book_qm"
	layer = 3.2
	anchored = TRUE

	attack_hand(mob/living/human/H)
		var/list/supplies = get_supplies()
		var/dat = "<center><h2>Warehouse Contents</h2></center>"
		var/i2 = 1
		for(var/i in supplies)
			dat += "<b>[supplies[i2]]:</b> [supplies[i]]<br>" //example: Cloth: 50
			i2++
		H << browse(dat, "window=Warehouse Contents")

/obj/structure/warehouse_book/proc/get_supplies()
	var/list/supplies = list()
	var/list/t_turfs = get_area_turfs(/area/caribbean/pirates/ship/voyage/lower/storage)
	for(var/turf/sel_turf in t_turfs)
		for(var/obj/structure/closet/crate/S in sel_turf)
			for(var/obj/item/I in S)
				if (supplies[I.name])
					supplies[I.name] += I.amount
				else
					supplies[I.name] = I.amount
	return supplies
