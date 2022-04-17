
/obj/map_metadata/african_warlords
	ID = MAP_AFRICAN_WARLORDS
	title = "African Warlords"
	lobby_icon_state = "africanwarlords"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle,/area/caribbean/no_mans_land/invisible_wall/jungle/one,/area/caribbean/no_mans_land/invisible_wall/jungle/two,/area/caribbean/no_mans_land/invisible_wall/jungle/three)
	respawn_delay = 300
	no_winner ="No warband has won yet."
	faction_organization = list(INDIANS, CIVILIAN)

	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/british,
		)
	no_hardcore = TRUE
	age = "1984"
	is_singlefaction = TRUE
	ordinal_age = 7
	faction_distribution_coeffs = list(INDIANS = 0.9, CIVILIAN = 0.1)
	battle_name = "Skull competition"
	mission_start_message = "<font size=4>Three African warlords are fighting for the control of this area. They will need to collect <b>enemy skulls</b> and bring them to their shaman hut. First team to reach <b>35 points</b> wins.<br><b>DO NOT KILL THE UN (ESPECIALLY DOCTORS) AS IT WILL GIVE NEGATIVE POINTS TO YOUR TEAM!</b></font>"
	faction1 = INDIANS
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Barrington Levy - Murderer:1" = "sound/music/murderer.ogg",)
	scores = list(
		"Blugisi" = 0,
		"Yellowagwana" = 0,
		"Redkantu" = 0
	)
	New()
		..()
		spawn(600)
			points_check()
obj/map_metadata/african_warlords/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_warlords && J.title != "warlord (do not use)")
		. = TRUE
	if (clients.len <= 12)
		if (J.title == "United Nations Doctor" || J.title == "United Nations Soldier")
			. = FALSE
	if (clients.len <= 15)
		if (J.title == "Local Policeman")
			. = FALSE
	if (clients.len <= 18)
		if (J.title == "United Nations Engineer")
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/african_warlords/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"

/obj/map_metadata/african_warlords/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/african_warlords/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/african_warlords/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/one))
			if (H.nationality != "Redkantu")
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/two))
			if (H.nationality != "Blugisi")
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/three))
			if (H.nationality != "Yellowagwana")
				return TRUE
		return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/african_warlords/proc/points_check()
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Yellowagwana: [scores["Yellowagwana"]]</big>"
	world << "<big>Redkantu: [scores["Redkantu"]]</big>"
	world << "<big>Blugisi: [scores["Blugisi"]]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/african_warlords/update_win_condition()
	if (processes.ticker.playtime_elapsed > 4800)
		if (win_condition_spam_check)
			return FALSE
		if (!(scores["Yellowagwana"] >= 35 || scores["Blugisi"] >= 35 || scores["Redkantu"] >= 35))
			return TRUE
		ticker.finished = TRUE
		var/message = ""
		message = "The round has ended!"
		if (scores["Yellowagwana"] > scores["Blugisi"] && scores["Yellowagwana"] > scores["Redkantu"])
			message = "The battle is over! The <font color='yellow'><b>Yellowagwana</b></font> were victorious over the other militias!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
			return FALSE
		else if (scores["Blugisi"] > scores["Yellowagwana"] && scores["Blugisi"] > scores["Redkantu"])
			message = "The battle is over! The <font color='blue'><b>Blugisi</b></font> were victorious over the other militias!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
			return FALSE
		else if (scores["Redkantu"] > scores["Blugisi"] && scores["Redkantu"] > scores["Yellowagwana"])
			message = "The battle is over! The <font color='red'><b>Redkantu</b></font> were victorious over the other militias!"
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
				if (head_nationality == "Exiled")
					AW.scores["Blugisi"] += 4
					new/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
			if("Yellowagwana")
				AW.scores["Yellowagwana"] += 2
				if (head_nationality == "Exiled")
					AW.scores["Yellowagwana"] += 4
					new/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
			if("Redkantu")
				AW.scores["Redkantu"] += 2
				if (head_nationality == "Exiled")
					AW.scores["Redkantu"] += 4
					new/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
		switch(head_nationality)
			if("Blugisi")
				AW.scores["Blugisi"] -= 1
			if("Yellowagwana")
				AW.scores["Yellowagwana"] -= 1
			if("Redkantu")
				AW.scores["Redkantu"] -= 1
		user << "You place the head on the shaman's altar."
		if	(prob(20))
			var/randmed = rand(1,3)
			switch (randmed)
				if (1)
					new/obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/minor(user.loc)
				if (2)
					new/obj/item/weapon/reagent_containers/food/drinks/bottle/small/stamina/minor(user.loc)
				if (3)
					new/obj/item/stack/medical/advanced/herbs(user.loc)
		else if (prob (20))
			var/randcloth = rand(1,6)
			switch(randcloth)
				if (1)
					new/obj/item/clothing/head/pimphat(user.loc)
					new/obj/item/clothing/suit/pimpsuit(user.loc)
				if (2)
					new/obj/item/clothing/head/lionpelt(user.loc)
				if (3)
					new/obj/item/clothing/head/gatorpelt(user.loc)
				if (4)
					new/obj/item/clothing/mask/wooden/african(user.loc)
				if (5)
					new/obj/item/clothing/suit/zulu_mbata(user.loc)
				if (6)
					new/obj/item/clothing/head/top_hat(user.loc)
		else if (prob (25))
			var/randgun = rand(1,3)
			switch(randgun)
				if (1)
					new/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
				if (2)
					new/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
					new/obj/item/ammo_magazine/ak74(user.loc)
				if (3)
					new/obj/item/weapon/gun/projectile/shotgun/pump(user.loc)
					new/obj/item/ammo_magazine/shellbox(user.loc)
					new/obj/item/ammo_magazine/shellbox(user.loc)
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
			new/obj/item/ammo_casing/rocket/pg7v(user.loc)
		return