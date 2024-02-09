/obj/map_metadata/pepelsibirsk
	ID = MAP_PEPELSIBIRSK
	title = "Pepelsibirsk"
	lobby_icon = "icons/lobby/civ13.gif"
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 12000 // 2 minutes
	has_hunger = TRUE

	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "1976 A.D."
	ordinal_age = 7
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>Following a limited thermonuclear exchange which saw most central authorities in the northern hemisphere collapse, it appears Pepelsibirsk was left mostly untouched. You must bring the city to prosperity!</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = "sound/music/toska.ogg",)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Cold War"

	//Trader spawnpoint
	var/trader_spawnpoint = "TraderArrivals"
	
	// Variables defining starting faction relations
	var/civ_relations = 50
	var/mil_relations = 50
	var/china_relations = 50
	var/soviet_relations = 50
	var/pacific_relations = 50
	
/obj/map_metadata/pepelsibirsk/New()
	..()
	for (var/obj/structure/wild/tree/live_tree/TREES)
		TREES.change_season()
	spawn(9000)
		seasons()

/obj/map_metadata/pepelsibirsk/seasons()
	if (real_season == "SUMMER")
		season = "WINTER"
		world << "<big>It's getting very cold. <b>Winter</b> has started.</big>"
		change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/obj/structure/wild/smallbush/SB)
			new/obj/structure/wild/smallbush/winter(SB.loc)
			qdel(SB)
		for (var/turf/floor/dirt/D)
			if (!istype(D,/turf/floor/dirt/winter) && !istype(D,/turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust))
				var/area/A = get_area(D)
				if  (A.location != AREA_INSIDE)
					D.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/G)
			var/area/A = get_area(G)
			if  (A.location != AREA_INSIDE)
				G.ChangeTurf(/turf/floor/winter/grass)
		spawn(100)
			change_weather(WEATHER_WET)
		spawn(800)
		for (var/turf/floor/beach/water/shallowsaltwater/W)
			W.ChangeTurf(/turf/floor/beach/water/ice/salty)
		real_season = "WINTER"
	else
		season = "SUMMER"
		world << "<big>The weather gets warmer. <b>Summer</b> has started.</big>"
		change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/obj/structure/wild/smallbush/winter/SBW)
			new/obj/structure/wild/smallbush(SBW.loc)
			qdel(SBW)
		for (var/turf/floor/dirt/winter/D)
			if (prob(50))
				D.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/G)
			if (prob(50))
				G.ChangeTurf(/turf/floor/grass)
		for (var/turf/floor/dirt/burned/B)
			if (prob(60))
				B.ChangeTurf(/turf/floor/grass)
		spawn(150)
			change_weather(WEATHER_NONE)
		spawn(1500)
		for (var/turf/floor/beach/water/ice/salty/W)
			if (prob(65) && W.water_level >= 50)
				W.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
		real_season = "SUMMER"

	if (real_season == "SUMMER")
		spawn(9000)
			seasons()
	else if (real_season == "WINTER")
		spawn(27000)
			seasons()

/obj/map_metadata/pepelsibirsk/cross_message(faction)
	return ""

/obj/map_metadata/pepelsibirsk/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/pepelsibirsk/proc/send_traders() //Picks a turf from trader_spawnpoint and sends traders there if relations are high enough.
	var/spawnpoint
	var/list/turfs = list()
	spawn (1)
		turfs = latejoin_turfs[trader_spawnpoint]
		spawnpoint = pick(turfs)
		if (china_relations >= 26)
			var/traderpath = /obj/structure/vending/sales/chinese_trader
			var/gt = get_turf(spawnpoint)
			new traderpath(gt)
		if (soviet_relations >= 26)
			var/traderpath = /obj/structure/vending/sales/soviet_trader
			var/gt = get_turf(spawnpoint)
			new traderpath(gt)
		if (pacific_relations >= 26)
			var/traderpath = /obj/structure/vending/sales/pacific_trader
			var/gt = get_turf(spawnpoint)
			new traderpath(gt)
		
	spawn (6000) //Deletes all the traders after 10 minutes
		qdel(/obj/structure/vending/sales/chinese_trader)
		qdel(/obj/structure/vending/sales/soviet_trader)
		qdel(/obj/structure/vending/sales/pacific_trader)
		return

	spawn (18000)
		send_traders()
		return

/obj/map_metadata/pepelsibirsk/proc/check_relations_msg()
	spawn(1)
		world << "<font size = 4><span class = 'notice'><b>Diplomatic Relations:</b></font></span>"
		world << "<br><font size = 3><span class = 'notice'>Narodnyygorod: <b>[civ_relations]</b></span></font>"
		world << "<br><font size = 3><span class = 'notice'>Pepelsibirsk 1: <b>[mil_relations]</b></span></font>"
		world << "<br><font size = 3><span class = 'notice'>People's Republic of China: <b>[china_relations]</b></span></font>"
		world << "<br><font size = 3><span class = 'notice'>Union of Soviet Socialist Republics: <b>[soviet_relations]</b></span></font>"
		world << "<br><font size = 3><span class = 'notice'>United States of the Pacific: <b>[pacific_relations]</b></span></font>"

	spawn(3000)
		check_relations_msg()
		return

/obj/structure/vending/sales/pacific_trader
	name = "U.S.P Trader"
	desc = "The United States of the Pacific has come to trade."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "afghcia"
	products = list(
		//Weapons
		/obj/item/weapon/gun/projectile/submachinegun/m16/commando = 5,
		/obj/item/weapon/gun/projectile/submachinegun/m16/m16a2 = 15,
		/obj/item/weapon/gun/launcher/grenade/standalone/m79 = 5,
		/obj/item/weapon/gun/launcher/rocket/bazooka = 10,
		/obj/item/weapon/gun/projectile/submachinegun/m14/sniper = 10,
		/obj/item/weapon/attachment/scope/adjustable/advanced/holographic = 10
		/obj/item/weapon/attachment/scope/adjustable/advanced/acog = 10
		/obj/item/weapon/attachment/scope/adjustable/advanced/reddot = 10
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope = 10
		/obj/item/weapon/attachment/under/foregrip = 10
		/obj/item/weapon/attachment/silencer/pistol = 10
		/obj/item/weapon/attachment/silencer/rifle = 10
		/obj/item/weapon/attachment/silencer/shotgun = 10
		/obj/item/weapon/attachment/silencer/smg = 10

		//Ammunition
		/obj/item/ammo_magazine/m16 = 80,
		/obj/item/ammo_magazine/m14 = 30,
		/obj/item/ammo_casing/rocket/bazooka = 20,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 30,
		/obj/item/weapon/plastique/c4 = 10,

		//Clothing
		/obj/item/clothing/under/us_uni/us_camo_woodland = 30
		/obj/item/clothing/accessory/storage/webbing/us_vest = 30
		/obj/item/clothing/suit/storage/coat/ww2/us_coat = 30
		/obj/item/clothing/shoes/jackboots/modern = 30
		/obj/item/clothing/accessory/armor/coldwar/pasgt = 10
		/obj/item/clothing/head/helmet/modern/pasgt = 10

		//Food and Drink
		/obj/item/weapon/reagent_containers/food/snacks/burger = 30
		/obj/item/weapon/reagent_containers/food/snacks/cheeseburger = 30
		/obj/item/weapon/reagent_containers/food/snacks/hotdog = 30
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/american = 30
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/pumpkinpie = 1
		/obj/item/weapon/reagent_containers/food/snacks/applepie = 1
	)
	prices = list(
		//Weapons
		/obj/item/weapon/gun/projectile/submachinegun/m16/commando = 200,
		/obj/item/weapon/gun/projectile/submachinegun/m16/m16a2 = 160,
		/obj/item/weapon/gun/launcher/grenade/standalone/m79 = 150,
		/obj/item/weapon/gun/launcher/rocket/bazooka = 150,
		/obj/item/weapon/gun/projectile/submachinegun/m14/sniper = 200,
		/obj/item/weapon/attachment/scope/adjustable/advanced/holographic = 100
		/obj/item/weapon/attachment/scope/adjustable/advanced/acog = 100
		/obj/item/weapon/attachment/scope/adjustable/advanced/reddot = 100
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope = 100
		/obj/item/weapon/attachment/under/foregrip = 100
		/obj/item/weapon/attachment/silencer/pistol = 100
		/obj/item/weapon/attachment/silencer/rifle = 100
		/obj/item/weapon/attachment/silencer/shotgun = 100
		/obj/item/weapon/attachment/silencer/smg = 100

		//Ammunition
		/obj/item/ammo_magazine/m16 = 20,
		/obj/item/ammo_magazine/m14 = 30,
		/obj/item/ammo_casing/rocket/bazooka = 200,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 80,
		/obj/item/weapon/plastique/c4 = 100,

		//Clothing
		/obj/item/clothing/under/us_uni/us_camo_woodland = 20
		/obj/item/clothing/accessory/storage/webbing/us_vest = 20
		/obj/item/clothing/suit/storage/coat/ww2/us_coat = 30
		/obj/item/clothing/shoes/jackboots/modern = 20
		/obj/item/clothing/accessory/armor/coldwar/pasgt = 100
		/obj/item/clothing/head/helmet/modern/pasgt = 100

		//Food and Drink
		/obj/item/weapon/reagent_containers/food/snacks/burger = 5
		/obj/item/weapon/reagent_containers/food/snacks/cheeseburger = 5
		/obj/item/weapon/reagent_containers/food/snacks/hotdog = 5
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/american = 10
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/pumpkinpie = 20
		/obj/item/weapon/reagent_containers/food/snacks/applepie = 20
	)

/obj/structure/vending/sales/chinese_trader //not done/placeholder
	name = "PRC Trader"
	desc = "现在我有冰淇淋我很喜欢冰淇淋."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "chinese_trader"
	products = list(
		//Weapons
		/obj/item/weapon/gun/projectile/submachinegun/ak47/chinese = 5,
		/obj/item/weapon/gun/projectile/semiautomatic/sks/chinese = 5,
		/obj/item/weapon/gun/projectile/submachinegun/ppsh/chinese = 5,

		//Clothing
		/obj/item/clothing/suit/storage/coat/chinese/officer = 5,
		/obj/item/clothing/suit/storage/coat/chinese = 80,
		/obj/item/clothing/under/chinaguard = 80,
		/obj/item/clothing/head/chinaguardcap = 80,
		/obj/item/clothing/head/chinese_ushanka = 80,
		/obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized = 80,
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
	)

/obj/structure/vending/sales/soviet_trader //not done/placeholder
	name = "Soviet Trader"
	desc = "Вы неправильно используете это программное обеспечение для перевода. Пожалуйста, проконсультируйтесь с руководством по программному обеспечению.."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "soviet_trader"
	products = list(
		//Weapons
		/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso = 5,
		/obj/item/weapon/gun/projectile/shotgun/pump/ks23 = 10,
		/obj/item/weapon/gun/launcher/rocket/single_shot/rpg22 = 10,
		/obj/item/weapon/gun/launcher/grenade/underslung/gp25 = 10,
		/obj/item/weapon/gun/launcher/rocket/rpg7 = 10,

		//Ammunition
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 30,
		/obj/item/ammo_casing/rocket/pg7v = 20,
		/obj/item/ammo_casing/rocket/og7v = 20,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 30,
		/obj/item/weapon/plastique/russian = 10,

		//Food and Drink
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/russian = 50
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel = 50
		/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka = 50
		/obj/item/weapon/reagent_containers/food/drinks/flask/barflask = 8
		/obj/item/weapon/reagent_containers/food/drinks/flask/officer = 8
		/obj/item/weapon/reagent_containers/food/drinks/teapot/filled = 8
		/obj/item/weapon/reagent_containers/food/drinks/golden_cup = 1

		//Medicines
		/obj/item/weapon/storage/pill_bottle/tramadol = 8
		/obj/item/weapon/storage/pill_bottle/penicillin = 8
		/obj/item/weapon/storage/pill_bottle/paracetamol = 8
		/obj/item/weapon/storage/pill_bottle/citalopram = 8
		/obj/item/weapon/storage/pill_bottle/potassium_iodide = 8
	)
	prices = list(
		/obj/item/weapon/gun/projectile/submachinegun/m16 = 100,
		/obj/item/weapon/gun/projectile/submachinegun/m16/m16a2 = 175,
		/obj/item/weapon/gun/launcher/grenade/standalone/m79 = 200,
		/obj/item/weapon/gun/launcher/rocket/bazooka = 220,
		/obj/item/weapon/gun/projectile/submachinegun/m14/sniper = 150,


		/obj/item/ammo_magazine/m16 = 20,
		/obj/item/ammo_magazine/m14 = 30,
		/obj/item/ammo_casing/rocket/bazooka = 60,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 40,
		/obj/item/weapon/plastique/c4 = 80,
	)

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
		spawn(20)
			if (ishuman(loc))
				var/mob/living/human/H = loc
				document_name = H.real_name
				owner = H
				name = "[document_name]'s personal documents"
				desc = "The identification papers of <b>[document_name]</b>."
				var/job = "Working"
				if (istype(H.original_job, /datum/job/civnomad))
					var/datum/job/civilian/prisoner/P = H.original_job
					switch(H.nationality)
						if ("German")
							job = "Citizen of the German Democratic Republic, expatriated and working [pick("in the Pepelsibirsk research facility","in the Pepelsibirsk hospital", "for the local KGB office", "in the Pepelsibirsk car factory")]."
						if ("Ukrainian")
							job = "Internal migrant from the Ukrainian SSR, working [pick("for the KGB","for the city Soviet", "in the Pepelsibirsk mine", "in the Pepelsibirsk car factory", "at the collective farm in Pepelsibirsk", "in the Pepelsibirsk power plant", "at the collective farm in Pepelsibirsk", "in the Pepelsibirsk mine", "in the Pepelsibirsk research facility", "in the Pepelsibirsk hospital", "for the Soviet Armed Forces", "for the local Militsiya")]."
						if ("Polish")
							job = "Citizen of the Polish Socialist Republic, expatriated and working in [pick("the Pepelsibirsk mine","the Pepelsibirsk car factory", "the collective farm in Pepelsibirsk", "the Pepelsibirsk power plant")]."
						if ("Russian")
							job = "Pepelsibirsk local, working [pick("for the KGB", "for the city Soviet", "in the Pepelsibirsk mine", "in the Pepelsibirsk car factory", "at the collective farm in Pepelsibirsk", "in the Pepelsibirsk power plant", "at the collective farm in Pepelsibirsk", "in the Pepelsibirsk mine", "in the Pepelsibirsk research facility", "in the Pepelsibirsk hospital", "for the Soviet Armed Forces", "for the local Militsiya", "for the Soviet Armed Forces", "for the local Militsiya").]"
					document_details = list(H.h_style, P.original_hair, H.f_style, P.original_facial, job, H.gender, client.prefs.age, ,P.original_eyes)

/obj/item/weapon/personal_documents/examine(mob/user)
	user << "<span class='info'>*---------*</span>"
	..(user)
	if (document_details.len >= 9)
		user << "<b><span class='info'>Hair:</b> [document_details[1]], [document_details[2]] color</span>"
		if (document_details[6] == "male")
			user << "<b><span class='info'>Face:</b> [document_details[3]], [document_details[4]] color</span>"
		user << "<b><span class='info'>Eyes:</b> [document_details[8]]</span>"
		user << "<b><span class='info'>Employment and Citizenship Status:</b> [document_details[5]]</span>"
		user << "<b><span class='info'>Age:</b> [document_details[7]] years</span>"
	user << "<span class='info'>*---------*</span>"
	if (guardnotes.len)
		for(var/i in guardnotes)
			user << "NOTE: [i]"
	user << "<span class='info'>*---------*</span>"

/obj/item/weapon/personal_documents/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!ishuman(H))
		return
	if ((istype (istype(I, /obj/item/weapon/pen))))
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