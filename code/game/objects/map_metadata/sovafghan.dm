/obj/map_metadata/sovafghan
	ID = MAP_SOVAFGHAN
	title = "Soviet-Afghan War"
	no_winner ="The region of Kandahar is still contested."
	lobby_icon_state = "sovafghan"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one, /area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 600
	has_hunger = TRUE

	faction_organization = list(
		RUSSIAN,
		CIVILIAN,
		ARAB)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/british,
		list(ARAB) = /area/caribbean/russian/land/inside/command,
		)
	age = "1984"
	ordinal_age = 7
	faction_distribution_coeffs = list(RUSSIAN = 0.4, CIVILIAN = 0.5, ARAB = 0.5)
	battle_name = "Soviet Afghan War"
	mission_start_message = "<font size=4>The <b><font color ='red'>Soviets</font></b>, along with the <b><font color ='green'>DRA</font></b>, have to remain in control of the Kandahar province and arrest or eliminate the Mujahideen leaders that are turning the local populace against the government. <br>The <b><font color ='black'>Mujahideen</font></b> must get rid of the communist oppressors in the region by capturing and holding their outposts and/or by killing/capturing their officers. <b>The faction with the most points (<b>75</b>) wins!</b><br></font>"
	faction1 = ARAB
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Swallowing Dust:1" = "sound/music/swallowingdust.ogg")
	gamemode = "Afghan"
	artillery_count = 3
	var/sov_points = 0
	var/muj_points = 0
	var/a1_control = "DRA"
	var/a2_control = "DRA"
	var/a3_control = "DRA"
	var/a4_control = "DRA"
	is_RP = TRUE
	var/gracedown1 = TRUE

/obj/map_metadata/sovafghan/New()
	..()
	var/newnamea = list("Soviet Army" = list(175,175,175,null,0,"star","#FF0000","#f5c400",0,0))
	var/newnameb = list("DRA" = list(175,175,175,null,0,"star","#FF0000","#005400",0,0))
	var/newnamec = list("Civilian" = list(175,175,175,null,0,"moon","#005400","#000000",0,0))
	var/newnamed = list("Mujahideen" = list(175,175,175,null,0,"skull","#000000","#FFFFFF",0,0))
	custom_civs += newnamea
	custom_civs += newnameb
	custom_civs += newnamec
	custom_civs += newnamed
	load_new_recipes("config/crafting/material_recipes_sovafghan.txt")
	spawn(3000)
		points_check()

/obj/map_metadata/sovafghan/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_afghan)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/sovafghan/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/sovafghan/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/sovafghan/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviet Army"
		if (ARAB)
			return "Mujahideen"
		if (CIVILIAN)
			return "DRA"

/obj/map_metadata/sovafghan/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviet Army"
		if (ARAB)
			return "Mujahideen"
		if (CIVILIAN)
			return "DRA"

/obj/map_metadata/sovafghan/army2name(army)
	..()
	switch (army)
		if ("Soviet Army")
			return "Soviet Army"
		if ("ARAB")
			return "Mujahideen"
		if ("CIVILIAN")
			return "DRA"

/obj/map_metadata/sovafghan/cross_message(faction)
	if (faction == ARAB)
		return "<font size = 4>The grace wall is down!</font>"
	else if (faction == CIVILIAN)
		return ""
	else if (faction == RUSSIAN)
		return "<font size = 4>The grace wall is down!</font>"
	else
		return ""

/obj/map_metadata/sovafghan/reverse_cross_message(faction)
	if (faction == ARAB)
		return "<font size = 4>The grace wall is up!</font>"
	else if (faction == CIVILIAN)
		return ""
	else if (faction == RUSSIAN)
		return "<font size = 4>The grace wall is up!</font>"
	else
		return ""

/obj/map_metadata/sovafghan/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (caribbean_blocking_area_types.Find(A.type))
		if (H.faction_text == faction2 || H.faction_text == faction1 && !H.original_job.is_muj)
			return !faction1_can_cross_blocks()
		else if (H.original_job.is_muj)
			return !faction2_can_cross_blocks()
		else
			return FALSE
	return FALSE

/obj/map_metadata/sovafghan/proc/points_check()
	if (processes.ticker.playtime_elapsed >4800)
		var/c1 = 0
		var/c2 = 0
		var/c3 = 0
		var/cust_color = "white"
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == "ARAB" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
				else if ((H.faction_text == "CIVILIAN" && H.original_job.is_dra == TRUE) && H.stat == CONSCIOUS)
					c3++
		if ((c1 == c2 || c1 == c3) && c1 != 0)
			a1_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a1_control = "Mujahideen"
			cust_color="black"
			muj_points++
		else if (c2 > c1 || c2 > c3)
			a1_control = "Soviets"
			cust_color="red"
			sov_points++
		else if (c3 > c1 || c3 > c2)
			a1_control = "DRA"
			cust_color="green"
			sov_points++
		if (a1_control != "none")
			if (a1_control == "Soviets")
				cust_color = "red"
			else if (a1_control == "Mujahideen")
				cust_color = "black"
			else if (a1_control == "DRA")
				cust_color = "green"
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>Bridge Outpost</b>: [a1_control]</font></big>"
		else
			world << "<big><b>Bridge Outpost</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		c3 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == "ARAB" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
				else if ((H.faction_text == "CIVILIAN" && H.original_job.is_dra == TRUE) && H.stat == CONSCIOUS)
					c3++
		if ((c1 == c2 || c1 == c3) && c1 != 0)
			a2_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a2_control = "Mujahideen"
			cust_color="black"
			muj_points++
		else if (c2 > c1 || c2 > c3)
			a2_control = "Soviets"
			cust_color="red"
			sov_points++
		else if (c3 > c1 || c3 > c2)
			a2_control = "DRA"
			cust_color="green"
			sov_points++
		if (a2_control != "none")
			if (a2_control == "Soviets")
				cust_color = "red"
			else if (a2_control == "Mujahideen")
				cust_color = "black"
			else if (a2_control == "DRA")
				cust_color = "green"
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>South Border Checkpoint</b>: [a2_control]</font></big>"
		else
			world << "<big><b>South Border Checkpoint</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		c3 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/three))
				if (H.faction_text == "ARAB" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
				else if ((H.faction_text == "CIVILIAN" && H.original_job.is_dra == TRUE) && H.stat == CONSCIOUS)
					c3++
		if ((c1 == c2 || c1 == c3) && c1 != 0)
			a3_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a3_control = "Mujahideen"
			cust_color="black"
			muj_points++
		else if (c2 > c1 || c2 > c3)
			a3_control = "Soviets"
			cust_color="red"
			sov_points++
		else if (c3 > c1 || c3 > c2)
			a3_control = "DRA"
			cust_color="green"
			sov_points++
		if (a3_control != "none")
			if (a3_control == "Soviets")
				cust_color = "red"
			else if (a3_control == "Mujahideen")
				cust_color = "black"
			else if (a3_control == "DRA")
				cust_color = "green"
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>Palace</b>: [a3_control]</font></big>"
		else
			world << "<big><b>Palace</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		c3 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/four))
				if (H.faction_text == "ARAB" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
				else if ((H.faction_text == "CIVILIAN" && H.original_job.is_dra == TRUE) && H.stat == CONSCIOUS)
					c3++
		if ((c1 == c2 || c1 == c3) && c1 != 0)
			a4_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a4_control = "Mujahideen"
			cust_color="black"
			muj_points++
		else if (c2 > c1 || c2 > c3)
			a4_control = "Soviets"
			cust_color="red"
			sov_points++
		else if (c3 > c1 || c3 > c2)
			a4_control = "DRA"
			cust_color="green"
			sov_points++
		if (a4_control != "none")
			if (a4_control == "Soviets")
				cust_color = "red"
			else if (a4_control == "Mujahideen")
				cust_color = "black"
			else if (a4_control == "DRA")
				cust_color = "green"
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>North West Village Outpost</b>: [a4_control]</font></big>"
		else
			world << "<big><b>North West Village Outpost</b>: Nobody</big>"
	for (var/mob/living/human/H in player_list)
		if (H.stat!=DEAD && (H.original_job.is_soviet == TRUE || H.original_job.is_dra == TRUE))
			var/area/A = get_area(H)
			if (istype(A, /area/caribbean/arab/caves/prison))
				if (H.stat!=DEAD && H.original_job.title == "Soviet Army Lieutenant")
					muj_points += 2
					world << "<font color='orange' size=2>A <b><font color='red'>Soviet Army Lieutenant</font></b> is in captivity!</font>"
				else if (H.stat!=DEAD && H.original_job.title == "Soviet Army Sergeant")
					muj_points += 1
					world << "<font color='orange' size=2>A <b><font color='red'>Soviet Army Sergeant</font></b> is in captivity!</font>"
				else if (H.stat!=DEAD && H.original_job.title == "DRA Governor")
					muj_points += 3
					world << "<font color='orange' size=2>The <b><font color='green'>DRA Governor</font></b> is in captivity!</font>"
				else if (H.stat!=DEAD && H.original_job.title == "DRA Sergeant")
					muj_points += 1
					world << "<font color='orange' size=2>A <b><font color='green'>DRA Sergeant</font></b> is in captivity!</font>"
		if (H.stat!=DEAD && (H.original_job.is_muj == TRUE))
			var/area/B = get_area(H)
			if (istype(B, /area/caribbean/prison/jail))
				if (H.stat!=DEAD && H.original_job.title == "Mujahideen Leader")
					sov_points += 2
					world << "<font color='orange' size=2>A <b><font color='black'>Mujahideen Leader</font></b> is currently being detained!</font>"
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Mujahideen: [muj_points]</big>"
	world << "<big>Soviets and DRA: [sov_points]</big>"
	spawn(600)
		points_check()

/obj/map_metadata/sovafghan/update_win_condition()
	if (processes.ticker.playtime_elapsed > 3000)
		if (sov_points < 75 && muj_points < 75)
			return TRUE
		if (sov_points >= 75 && sov_points > muj_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b><font color ='red'>Soviets</font></b> and <b><font color ='green'>DRA</font></b> have reached [sov_points] points and won! The Kandahar region remains under the <b><font color ='green'>DRA</font></b> control"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (muj_points >= 75 && muj_points > sov_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b><font color ='black'>Mujahideen</font></b> have reached [muj_points] points and won! The Kandahar province is under their control!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE

/obj/map_metadata/sovafghan/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
			if (H.faction_text == "CIVILIAN")
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
			if (H.civilization == "Civilian")
				return TRUE
		else
			return !faction1_can_cross_blocks()
			return !faction2_can_cross_blocks()
	return FALSE


//////Vendors////////

/obj/structure/vending/sales/cia_agent
	name = "CIA agent"
	desc = "The USA supports your cause in exchange of ressources."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "afghcia"
	products = list(
		/obj/item/weapon/gun/projectile/submachinegun/m16 = 30,
		/obj/item/weapon/gun/projectile/submachinegun/m16/m16a2 = 10,
		/obj/item/weapon/gun/launcher/grenadelauncher/M79 = 10,
		/obj/item/weapon/gun/launcher/rocket/bazooka = 10,
		/obj/item/weapon/gun/projectile/submachinegun/m14/sniper/ = 10,


		/obj/item/ammo_magazine/m16 = 80,
		/obj/item/ammo_magazine/m14 = 30,
		/obj/item/ammo_casing/rocket/bazooka = 20,
		/obj/item/ammo_casing/grenade_l = 30,
		/obj/item/weapon/plastique/c4 = 10,
	)
	prices = list(
		/obj/item/weapon/gun/projectile/submachinegun/m16 = 100,
		/obj/item/weapon/gun/projectile/submachinegun/m16/m16a2 = 175,
		/obj/item/weapon/gun/launcher/grenadelauncher/M79 = 200,
		/obj/item/weapon/gun/launcher/rocket/bazooka = 220,
		/obj/item/weapon/gun/projectile/submachinegun/m14/sniper/ = 150,


		/obj/item/ammo_magazine/m16 = 20,
		/obj/item/ammo_magazine/m14 = 30,
		/obj/item/ammo_casing/rocket/bazooka = 60,
		/obj/item/ammo_casing/grenade_l = 40,
		/obj/item/weapon/plastique/c4 = 80,
	)
	attack_hand(mob/living/human/user as mob)
		if (user.faction_text == "ARAB")
			..()
		else
		 user << "You are not part of the Mujahideen, you should really leave the area."
		 return
	attackby(obj/item/I, mob/living/human/user)
		if (user.faction_text == "ARAB")
			..()
		else
		 user << "You are not part of the Mujahideen, you should really leave the area."
		 return

/obj/structure/props/afghan/druglord
	name = "Tarik the Trafficker"
	desc = "You've got opium? I've got money."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "afghdrug"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE

/obj/structure/props/afghan/druglord/attackby(obj/item/W, mob/living/human/user)
	if(user.civilization == "Mujahideen")
		if (istype(W, /obj/item/weapon/reagent_containers/pill/opium))
			if (!W)
				return
			user << "Here's your payment, pleasure doing business with you, brother."
			new/obj/item/stack/money/dollar/five(loc)
			if (prob(5))
				user << "Here's also a little extra to get you going."
				new/obj/item/stack/money/dollar/five(loc)
			if (prob(5))
				var/obj/map_metadata/sovafghan/MP = map
				var/randevent = rand(1,2)
				switch (randevent)
					if (1)
						world << "A shipment of heroin has successfully left the Afghan border! The authorities are furious!"
						MP.muj_points += 1
						MP.sov_points -= 1
					if (2)
						world << "A shipment of heroin was intercepted by the authorities at the Afghan border!"
						MP.muj_points -= 1
						MP.sov_points += 1
			qdel(W)
			return
	else if(user.civilization == "Civilian")
		if (istype(W, /obj/item/weapon/reagent_containers/pill/opium))
			if (!W)
				return
			user << "Here's your payment, there's more where it came from, if you bring me the stuff, of course."
			new/obj/item/stack/money/dollar(loc)
			new/obj/item/stack/money/dollar(loc)
			if (prob(5))
				user << "Here's also a little extra to get you going."
				new/obj/item/stack/money/dollar/five(loc)
			qdel(W)
			return
	else
		user << "I've got no business with you! Get lost, you dog!"
		return