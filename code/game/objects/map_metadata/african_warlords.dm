
/obj/map_metadata/african_warlords
	ID = MAP_AFRICAN_WARLORDS
	title = "African Warlords"
	lobby_icon = "icons/lobby/africanwarlords.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle,/area/caribbean/no_mans_land/invisible_wall/jungle/one,/area/caribbean/no_mans_land/invisible_wall/jungle/two,/area/caribbean/no_mans_land/invisible_wall/jungle/three)
	respawn_delay = 300
	no_winner ="No warband has won yet."
	faction_organization = list(INDIANS, CIVILIAN)
	grace_wall_timer = 1200
	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/british
		)
	no_hardcore = TRUE
	age = "1984"

	ordinal_age = 7
	faction_distribution_coeffs = list(INDIANS = 0.5, CIVILIAN = 0.5)
	battle_name = "Skull competition"
	mission_start_message = "<font size=4>Two African warlords are fighting to humiliate the other's tribe. They will need to collect <b>Enemy Skulls</b> and bring them to their camp shaman's altar to score. Each skull is worth two points and first team to reach <b>30 points</b> wins.<br></font>"
	faction1 = INDIANS
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Barrington Levy - Murderer:1" = "sound/music/murderer.ogg",)
	scores = list(
		"Blugisi" = 0,
		"Yellowagwana" = 0,
	)
	New()
		..()
		spawn(600)
			points_check()

/obj/map_metadata/african_warlords/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_blugi)
		if (J.title != "warlord (do not use)")
			. = TRUE
	else if (J.is_yellowag)
		if (J.title != "warlord (do not use)")
			. = TRUE
	else
		. = FALSE

/obj/map_metadata/african_warlords/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"

/obj/map_metadata/african_warlords/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/two))
			if (H.nationality != "Blugisi")
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/three))
			if (H.nationality != "Yellowagwana")
				return TRUE
		return !faction2_can_cross_blocks() && !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/african_warlords/proc/points_check()
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Yellowagwana: [scores["Yellowagwana"]]</big>"
	world << "<big>Blugisi: [scores["Blugisi"]]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/african_warlords/update_win_condition()
	if (processes.ticker.playtime_elapsed > 4800)
		if (win_condition_spam_check)
			return FALSE
		if (!(scores["Yellowagwana"] >= 30 || scores["Blugisi"] >= 30))
			return TRUE
		ticker.finished = TRUE
		var/message = ""
		message = "The round has ended!"
		if (scores["Yellowagwana"] > scores["Blugisi"])
			message = "The battle is over! The <font color='yellow'><b>Yellowagwana</b></font> were victorious over the <b>Blugisi</b> tribe!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
			return FALSE
		else if (scores["Blugisi"] > scores["Yellowagwana"])
			message = "The battle is over! The <font color='blue'><b>Blugisi</b></font> were victorious over the <b>Yellowagwana</b> tribe!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
			return FALSE
		else
			message = "The battle has ended in a <b>stalemate</b>!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
			return FALSE
		last_win_condition = win_condition.hash
		return TRUE
	return TRUE
///////////map specific objs/////////
/obj/structure/altar/darkstone/sacrifice
	name = "shaman's altar"
	icon_state = "blood_altar"
	flammable = FALSE
	health = 1000000
	not_movable = TRUE
	var/faction = "none"

/obj/structure/altar/darkstone/sacrifice/attackby(obj/item/W, mob/living/human/user)
	if(faction != user.nationality)
		return
	if (istype(W, /obj/item/organ/external/head) && map.ID == MAP_AFRICAN_WARLORDS)
		var/obj/map_metadata/african_warlords/AW = map
		if (!W)
			return
		var/obj/item/organ/external/head/HD = W
		var/head_nationality = HD.nationality
		qdel(W)
		if (faction == head_nationality || faction != user.nationality)
			return
		if (!head_nationality || head_nationality == "none")
			return
		switch(faction)
			if("Blugisi")
				AW.scores["Blugisi"] += 2
				/*if (head_nationality == "Exiled")
					AW.scores["Blugisi"] += 4
					new/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)*/
			if("Yellowagwana")
				AW.scores["Yellowagwana"] += 2
				/*if (head_nationality == "Exiled")
					AW.scores["Yellowagwana"] += 4
					new/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)*/
			/*if("Redkantu")
				AW.scores["Redkantu"] += 2
				if (head_nationality == "Exiled")
					AW.scores["Redkantu"] += 4
					new/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)*/
/*		switch(head_nationality)
			if("Blugisi")
				AW.scores["Blugisi"] -= 1
			if("Yellowagwana")
				AW.scores["Yellowagwana"] -= 1*/
	//		if("Redkantu")
	//			AW.scores["Redkantu"] -= 1
		user << "You place the head on the shaman's altar."
		if	(prob(20))
			var/randmed = rand(1,6)
			switch (randmed)
				if (1)
					new/obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/minor(user.loc)
				if (2)
					new/obj/item/weapon/reagent_containers/food/drinks/bottle/small/stamina/minor(user.loc)
				if (3)
					new/obj/item/weapon/storage/firstaid/adv(user.loc)
				if (4)
					new/obj/item/weapon/storage/firstaid/advsmall(user.loc)
				if (5)
					new/obj/item/stack/medical/advanced/herbs(user.loc)
				if (6)
					new/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/mush(user.loc)


		else if (prob (20))
			var/randcloth = rand(1,8)
			switch(randcloth)
				if (1)
					new/obj/item/clothing/head/pimphat(user.loc)
					new/obj/item/clothing/suit/pimpsuit(user.loc)
				if (2)
					new/obj/item/clothing/suit/storage/ghillie(user.loc)
					new/obj/item/clothing/head/ghillie(user.loc)
				if (3)
					new/obj/item/clothing/head/gatorpelt(user.loc)
					new/obj/item/clothing/suit/storage/coat/ww2/biker/gator_jacket(user.loc)
				if (4)
					new/obj/item/clothing/head/laurelcrown/gold(user.loc)
					new/obj/item/clothing/suit/storage/jacket/regal(user.loc)
				if (5)
					new/obj/item/clothing/head/lionpelt(user.loc)
					new/obj/item/clothing/suit/zulu_mbata(user.loc)
					new/obj/item/clothing/mask/wooden/african(user.loc)
				if (6)
					new/obj/item/clothing/head/top_hat(user.loc)
					new/obj/item/clothing/suit/storage/jacket/vict_tailcoat(user.loc)
				if (7)
					new/obj/item/clothing/under/victorian_dress/red(user.loc)
					new/obj/item/clothing/head/kerchief(user.loc)
				if (8)
					new/obj/item/clothing/head/ten_gallon(user.loc)
					new/obj/item/clothing/suit/storage/jacket/texan(user.loc)

		else if (prob (25))
			var/randgun = rand(1,5)
			switch(randgun)
				if (1)
					new/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
				if (2)
					new/obj/item/weapon/gun/projectile/submachinegun/ak47/gold(user.loc)
					new/obj/item/ammo_magazine/ak47/drum(user.loc)
					new/obj/item/ammo_magazine/ak47/drum(user.loc)
				if (3)
					new/obj/item/weapon/gun/projectile/submachinegun/saiga12(user.loc)
					new/obj/item/ammo_magazine/saiga12/slug(user.loc)
					new/obj/item/ammo_magazine/saiga12/slug(user.loc)
					new/obj/item/ammo_magazine/saiga12(user.loc)
				if (4)
					new/obj/item/weapon/gun/projectile/pistol/deagle(user.loc)
					new/obj/item/ammo_magazine/deagle(user.loc)
					new/obj/item/ammo_magazine/deagle(user.loc)
					new/obj/item/ammo_magazine/deagle(user.loc)
				if (5)
					new/obj/item/weapon/macuahuitl(user.loc)
					new/obj/item/weapon/material/thrown/throwing_axe(user.loc)
					new/obj/item/weapon/material/thrown/throwing_axe(user.loc)
		else if (prob (20))
			new/obj/item/weapon/grenade/modern/f1(user.loc)
		else if (prob (15))
			new/obj/item/weapon/grenade/incendiary/anm14(user.loc)
		else if (prob (15))
			new/obj/item/weapon/gun/projectile/semiautomatic/svd(user.loc)
			new /obj/item/ammo_magazine/svd(user.loc)
			new /obj/item/ammo_magazine/svd(user.loc)
		else if (prob (15))
			new/obj/item/weapon/gun/launcher/rocket/rpg7(user.loc)
			new/obj/item/ammo_casing/rocket/og7v(user.loc)
			new/obj/item/ammo_casing/rocket/og7v(user.loc)
		return

