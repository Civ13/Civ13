
/obj/map_metadata/operation_falcon
	ID = MAP_OPERATION_FALCON
	title = "Operation Falcon"
	lobby_icon = 'icons/lobby/operation_falcon.png'
	no_winner = "The battle for the city is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 90 SECONDS

	faction_organization = list(
		DUTCH,
		RUSSIAN)

	roundend_condition_sides = list(
		list(DUTCH) = /area/caribbean/german/reichstag/roof/objective,
		list(RUSSIAN) = /area/caribbean/german/reichstag/roof/objective,
		)
	age = "2017"
	ordinal_age = 8
	faction_distribution_coeffs = list(DUTCH = 0.5, RUSSIAN = 0.5)
	battle_name = "Operation Falcon"
	mission_start_message = "<font size=4>Both factions have <b>3 minutes</b> to prepare before the ceasefire ends!</font> <br><big>Points are added to each team for each minute they control the different objectives.</big> <br><font size=6>First team to reach <b>100</b> points wins!</big></font>"
	faction1 = DUTCH
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Doe Maar - The Bomb (De Bom):1" = 'sound/music/de_bom.ogg',)
	gamemode = "Area Control"
	ambience = list('sound/ambience/battle1.ogg')
	var/rus_points = 0
	var/dutch_points = 0
	var/win_points = 100 // Amount of points needed to win

	var/faction1_flag = "netherlands"
	var/faction2_flag = "russian"

	var/a1_control = "nobody"
	var/a1_name = "Radio Post"

	var/a2_control = "nobody"
	var/a2_name = "Central Town"

	var/a3_control = "nobody"
	var/a3_name = "Factory"

	var/a4_control = "nobody"
	var/a4_name = "Lumber Company"
	grace_wall_timer = 3 MINUTES
	no_hardcore = TRUE
	fob_spawns = TRUE

/obj/map_metadata/operation_falcon/New()
	..()
	spawn(3000)
		points_check()
		spawn(rand(500,800))
			jet_flyby()

/obj/map_metadata/operation_falcon/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_operation_falcon == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/operation_falcon/roundend_condition_def2name(define)
	..()
	switch (define)
		if (DUTCH)
			return "Dutch"
		if (RUSSIAN)
			return "Russian"

/obj/map_metadata/operation_falcon/roundend_condition_def2army(define)
	..()
	switch (define)
		if (DUTCH)
			return "Dutch Royal Army"
		if (RUSSIAN)
			return "Russian Armed Forces"

/obj/map_metadata/operation_falcon/army2name(army)
	..()
	switch (army)
		if ("Dutch Royal Army")
			return "Dutch"
		if ("Russian Armed Forces")
			return "Russian"

/obj/map_metadata/operation_falcon/cross_message(faction)
	switch (faction)
		if (DUTCH)
			var/warning_sound = sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = TRUE, channel = 780)
			for (var/mob/M in player_list)
				if (M.client)
					M.client << warning_sound
			return "<font size = 4>Operation Falcon has begun!</font>"
		else
			return ""

/obj/map_metadata/operation_falcon/proc/points_check()
	if (processes.ticker.playtime_elapsed > 3000)
		var/c1 = 0
		var/c2 = 0
		var/cust_color = "white"
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == DUTCH && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == RUSSIAN && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a1_control = "none"
			cust_color = "white"
		else if (c1 > c2)
			a1_control = "Dutch Royal Army"
			cust_color = "#FFA500"
		else if (c2 > c1)
			a1_control = "Russian Armed Forces"
			cust_color = "red"
		if (a1_control != "none")
			if (a1_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a1_control == "Dutch Royal Army")
				cust_color = "#FFA500"
				dutch_points++
			else
				cust_color = "white"
			world << "<big><b>[a1_name]</b>: <font color='[cust_color]'>[a1_control]</font></big>"
		else
			world << "<big><b>[a1_name]</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == DUTCH && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == RUSSIAN && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a2_control = "none"
			cust_color = "white"
		else if (c1 > c2)
			a2_control = "Dutch Royal Army"
			cust_color = "#FFA500"
		else if (c2 > c1)
			a2_control = "Russian Armed Forces"
			cust_color = "red"
		if (a2_control != "none")
			if (a2_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a2_control == "Dutch Royal Army")
				cust_color = "#FFA500"
				dutch_points++
			else
				cust_color = "white"
			world << "<big><b>[a2_name]</b>: <font color='[cust_color]'>[a2_control]</font></big>"
		else
			world << "<big><b>[a2_name]</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/three))
				if (H.faction_text == DUTCH && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == RUSSIAN && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a3_control = "none"
			cust_color = "white"
		else if (c1 > c2)
			a3_control = "Dutch Royal Army"
			cust_color = "#FFA500"
		else if (c2 > c1)
			a3_control = "Russian Armed Forces"
			cust_color = "red"
		if (a3_control != "none")
			if (a3_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a3_control == "Dutch Royal Army")
				cust_color = "#FFA500"
				dutch_points++
			else
				cust_color = "white"
			world << "<big><b>[a3_name]</b>: <font color='[cust_color]'>[a3_control]</font></big>"
		else
			world << "<big><b>[a3_name]</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/four))
				if (H.faction_text == DUTCH && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == RUSSIAN && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a4_control = "none"
			cust_color = "white"
		else if (c1 > c2)
			a4_control = "Dutch Royal Army"
			cust_color = "#FFA500"
		else if (c2 > c1)
			a4_control = "Russian Armed Forces"
			cust_color = "red"
		if (a4_control != "none")
			if (a4_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a4_control == "Dutch Royal Army")
				cust_color = "#FFA500"
				dutch_points++
			else
				cust_color = "white"
			world << "<big><b>[a4_name]</b>: <font color='[cust_color]'>[a4_control]</font></big>"
		else
			world << "<big><b>[a4_name]</b>: Nobody</big>"

	switch (a1_control)
		if ("Dutch Royal Army")
			faction1_supply_points += 20
			for (var/obj/structure/flag/objective/one/F in world)
				F.icon_state = "[faction1_flag]"
		if ("Russian Armed Forces")
			faction2_supply_points += 20
			for (var/obj/structure/flag/objective/one/F in world)
				F.icon_state = "[faction2_flag]"
		else
			for (var/obj/structure/flag/objective/one/F in world)
				F.icon_state = "white"
	switch (a2_control)
		if ("Dutch Royal Army")
			faction1_supply_points += 20
			for (var/obj/structure/flag/objective/two/F in world)
				F.icon_state = "[faction1_flag]"
		if ("Russian Armed Forces")
			faction2_supply_points += 20
			for (var/obj/structure/flag/objective/two/F in world)
				F.icon_state = "[faction2_flag]"
		else
			for (var/obj/structure/flag/objective/two/F in world)
				F.icon_state = "white"
	switch (a3_control)
		if ("Dutch Royal Army")
			faction1_supply_points += 20
			for (var/obj/structure/flag/objective/three/F in world)
				F.icon_state = "[faction1_flag]"
		if ("Russian Armed Forces")
			faction2_supply_points += 20
			for (var/obj/structure/flag/objective/three/F in world)
				F.icon_state = "[faction2_flag]"
		else
			for (var/obj/structure/flag/objective/three/F in world)
				F.icon_state = "white"
	switch (a4_control)
		if ("Dutch Royal Army")
			faction1_supply_points += 20
			for (var/obj/structure/flag/objective/four/F in world)
				F.icon_state = "[faction1_flag]"
		if ("Russian Armed Forces")
			faction2_supply_points += 20
			for (var/obj/structure/flag/objective/four/F in world)
				F.icon_state = "[faction2_flag]"
		else
			for (var/obj/structure/flag/objective/four/F in world)
				F.icon_state = "white"

	spawn(600) // 1 minute
		points_check()
		spawn(5)
			world << "<big><b>Current Points:</b></big>"
			world << "<big>Dutch: [dutch_points]</big>"
			world << "<big>Russian: [rus_points]</big>"

/obj/map_metadata/operation_falcon/update_win_condition()
	if (processes.ticker.playtime_elapsed > 3000)
		if (rus_points < win_points && dutch_points < win_points)
			return TRUE
		if (rus_points >= win_points && rus_points > dutch_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Russians</b> have reached [rus_points] points and claimed victory in Operation Falcon!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"

			var/anthem = sound('sound/music/russian_anthem.ogg', repeat = FALSE, wait = FALSE, volume = 100, channel = 775)
			for (var/mob/M in player_list)
				if (M.client)
					M.client << anthem

			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (dutch_points >= win_points && dutch_points > rus_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Dutch</b> have reached [dutch_points] points and claimed victory in Operation Falcon!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			
			var/anthem = sound('sound/music/dutch_anthem.ogg', repeat = FALSE, wait = FALSE, volume = 100, channel = 775)
			for (var/mob/M in player_list)
				if (M.client)
					M.client << anthem

			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE

/obj/map_metadata/operation_falcon/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/operation_falcon/proc/jet_flyby()
	var/flyby_type = rand(1,4)
	switch (flyby_type)
		if (1)
			var/direction = rand(1,3)
			var/sound/uploaded_sound
			switch (direction)
				if (1)
					uploaded_sound = sound('sound/effects/aircraft/f16_left-right.ogg', repeat = FALSE, wait = TRUE, channel = 777)
				if (2)
					uploaded_sound = sound('sound/effects/aircraft/f16_center.ogg', repeat = FALSE, wait = TRUE, channel = 777)
				if (3)
					uploaded_sound = sound('sound/effects/aircraft/f16_right-left.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			uploaded_sound.priority = 250
			for (var/mob/M in player_list)
				if (!new_player_mob_list.Find(M))
					M << SPAN_NOTICE("<font size=3>The air rumbles as a F-16 flies overhead.</font>")
					if (M.client)
						M.client << uploaded_sound
		if(2)
			var/direction = rand(1,3)
			var/sound/uploaded_sound
			switch (direction)
				if (1)
					uploaded_sound = sound('sound/effects/aircraft/su25_left-right.ogg', repeat = FALSE, wait = TRUE, channel = 777)
				if (2)
					uploaded_sound = sound('sound/effects/aircraft/su25_center.ogg', repeat = FALSE, wait = TRUE, channel = 777)
				if (3)
					uploaded_sound = sound('sound/effects/aircraft/su25_right-left.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			uploaded_sound.priority = 250
			for (var/mob/M in player_list)
				if (!new_player_mob_list.Find(M))
					M << SPAN_NOTICE("<font size=3>The air rumbles as a Su-25 flies overhead.</font>")
					if (M.client)
						M.client << uploaded_sound
		if(3)
			var/direction = rand(1,2)
			var/sound/uploaded_sound1
			var/sound/uploaded_sound2
			switch (direction)
				if (1)
					uploaded_sound1 = sound('sound/effects/aircraft/su25_left-right.ogg', repeat = FALSE, wait = TRUE, channel = 777)
					if (prob(80))
						uploaded_sound2 = sound('sound/effects/aircraft/f16_left-right_firing.ogg', repeat = FALSE, wait = TRUE, channel = 776)
					else
						uploaded_sound2 = sound('sound/effects/aircraft/f16_left-right.ogg', repeat = FALSE, wait = TRUE, channel = 776)
				if (2)
					uploaded_sound1 = sound('sound/effects/aircraft/su25_right-left.ogg', repeat = FALSE, wait = TRUE, channel = 777)
					if (prob(80))
						uploaded_sound2 = sound('sound/effects/aircraft/f16_right-left_firing.ogg', repeat = FALSE, wait = TRUE, channel = 776)
					else
						uploaded_sound2 = sound('sound/effects/aircraft/f16_right-left.ogg', repeat = FALSE, wait = TRUE, channel = 776)
			uploaded_sound1.priority = 250
			uploaded_sound2.priority = 250
			for (var/mob/M in player_list)
				if (!new_player_mob_list.Find(M))
					M << SPAN_DANGER("<font size=4>The air lights up as a Su-25 and a pursuing F-16 fly overhead.</font>")
					if (M.client)
						M.client << uploaded_sound1
					spawn(5 SECONDS)
						if (M.client)
							M.client << uploaded_sound2

	spawn(rand(1600,4000))
		jet_flyby()

////////MAP SPECIFIC OBJECTS////////
// Everything here codewise is made by Bierkraan or SaveTheTreez :D

var/global/list/fob_names_nato = list("Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India")
var/global/list/fob_names_russian = list("Anna", "Boris", "Dmitri", "Yelena", "Ivan", "Konstantin", "Leonid", "Mikhail", "Nikolai")

/obj/structure/fob_spawnpoint
	name = "FOB"
	desc = "A heavy garrison. Used to spawn in reinforcements close to the frontline."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "fob"
	anchored = TRUE
	flammable = FALSE
	w_class = ITEM_SIZE_LARGE
	opacity = FALSE
	density = TRUE
	var/health = 1000
	layer = 4.0
	var/faction_text = null // To what faction does it belong?
	var/pickedfrom = null // All FOB names for that faction
	var/pickedname = null // The chosen name from the FOB name list

/obj/structure/fob_spawnpoint/proc/try_destroy()
	if (health <= 0)
		visible_message(SPAN_DANGER("<big>\The [src] is blown apart!</big>"))
		message_admins("FOB at ([src.x], [src.y], [src.z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[src.x];Y=[src.y];Z=[src.z]'>JMP</a>) has been destroyed.")
		if (pickedname)
			pickedfrom += pickedname
		for (var/obj/structure/flag/F in range(1, src))
			qdel(F)
		qdel(src)
		return

/obj/structure/fob_spawnpoint/attack_hand(mob/living/human/H as mob)
	if (!faction_text)
		faction_text = H.faction_text
		playsound(loc, "radio_chatter", 250, FALSE)
		message_admins("[H.ckey] ([H.faction_text]) has built a FOB at ([src.x], [src.y], [src.z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[src.x];Y=[src.y];Z=[src.z]'>JMP</a>).", H.ckey)
		switch (H.faction_text)
			if (DUTCH)
				pickedfrom = fob_names_nato
				pickedname = pick(pickedfrom)
				fob_names_nato -= pickedname
				
				new /obj/structure/flag/dutch(get_turf(src))
				new /obj/item/weapon/storage/ammo_can/m16(locate(src.x, src.y-1, src.z))
			if (BRITISH)
				pickedfrom = fob_names_nato
				pickedname = pick(pickedfrom)
				fob_names_nato -= pickedname
				
				new /obj/structure/flag/british(get_turf(src))
				new /obj/item/weapon/storage/ammo_can/m16(locate(src.x, src.y-1, src.z))
			if (RUSSIAN)
				pickedfrom = fob_names_russian
				pickedname = pick(pickedfrom)
				fob_names_russian -= pickedname

				new /obj/structure/flag/russian(get_turf(src))
				new /obj/item/weapon/storage/ammo_can/ak74(locate(src.x, src.y-1, src.z))
			else
				pickedfrom = fob_names_nato
				pickedname = pick(pickedfrom)
				fob_names_nato -= pickedname

		for (var/obj/structure/flag/F in range(1, src))
			F.pixel_x += 20
		new /obj/structure/closet/crate/sandbags(locate(src.x-(pick(-1,1)), src.y, src.z))

		name = "[name] \'[pickedname]\'"
	return

/obj/structure/fob_spawnpoint/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 600
		if (2.0)
			health -= 200
		if (3.0)
			health -= 20
	try_destroy()

/obj/structure/fob_spawnpoint/bullet_act(var/obj/item/projectile/proj)
	return // Can only be blown up by explosives

/obj/structure/supply_crate
	name = "supply crate"
	desc = "A supply crate used to make FOBs and other various structures. This crate belongs to nobody."
	icon = 'icons/obj/junk.dmi'
	icon_state = "supply_crate"
	anchored = FALSE
	flammable = FALSE
	w_class = ITEM_SIZE_LARGE
	opacity = FALSE
	density = TRUE
	var/health = 250
	var/faction_text = null // To what faction does it belong?
	var/list/buildable = list(
							"FOB",
							"Anti-Air",
							)

/obj/structure/supply_crate/New()
	..()
	if (faction_text)
		name = "[map.roundend_condition_def2name(faction_text)] [name]"
		desc = "A supply crate used to make FOBs and other various structures. This crate belongs to the <b>[map.roundend_condition_def2army(faction_text)]!</b>"
	spawn(2)
		update_icon()

/obj/structure/supply_crate/faction1/New()
	..()
	faction_text = map.faction1

/obj/structure/supply_crate/faction2/New()
	..()
	faction_text = map.faction2

/obj/structure/supply_crate/proc/try_destroy()
	if (health <= 0)
		visible_message(SPAN_DANGER("<big>\The [src] took too much damage and explodes!</big>"))
		explosion(get_turf(src),0,1,1,1)
		message_admins("Supply crate at ([src.x], [src.y], [src.z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[src.x];Y=[src.y];Z=[src.z]'>JMP</a>) has been destroyed.")
		qdel(src)
		return

/obj/structure/supply_crate/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 600
		if (2.0)
			health -= 200
		if (3.0)
			health -= 100
	try_destroy()

/obj/structure/supply_crate/bullet_act(var/obj/item/projectile/proj)
	health -= proj.damage * 0.01
	visible_message(SPAN_DANGER("\The [src] is hit by \the [proj.name]!"))
	try_destroy()


/obj/structure/supply_crate/attack_hand(mob/living/human/H as mob)
	if (!faction_text) // Claim a crate if it isn't assigned to a faction.
		faction_text = H.faction_text
		name = "[map.roundend_condition_def2name(faction_text)] [name]"
		desc = "A supply crate used to make FOBs and other various structures. This crate belongs to the <b>[map.roundend_condition_def2army(faction_text)]!</b>"
		spawn(2)
			update_icon()
	if (faction_text != H.faction_text) // Check if the user's faction is the same as the crate's faction.
		to_chat(H, SPAN_WARNING("This supply crate does not belong to your faction!"))
		return

	buildable += "Cancel"
	var/input = WWinput(H, "What do you want to build?", "Structure Selection", "FOB", buildable)
	switch (input)
		if ("Cancel")
			return
		if ("FOB")
			for (var/obj/structure/fob_spawnpoint/fob in range(14, src))
				if (fob.faction_text != src.faction_text)
					to_chat(H, SPAN_WARNING("<big>This area is too dangerous to build a FOB. Move away or destroy the enemy FOB!</big>"))
					return
				if (fob.faction_text == src.faction_text)
					to_chat(H, SPAN_WARNING("You're building too close to a friendly FOB. Consider moving further away."))
					return
			to_chat(H, SPAN_NOTICE("You starting building a FOB with \the [src]."))
			var/found = 0
			for(var/obj/structure/fob_spawnpoint/fob in world)
				if (fob.faction_text == H.faction_text)
					found++
			if (found < 8)
				if (do_after(H, 30 SECONDS, src))
					to_chat(H, SPAN("good", "<big>You build a FOB with \the [src].</big>"))
					var/obj/structure/fob_spawnpoint/fob = new/obj/structure/fob_spawnpoint(get_turf(src))
					fob.attack_hand(H)
					qdel(src)
					return
			else
				to_chat(H, SPAN_WARNING("<big>There are too many friendly FOBs! Consider destroying one to build one somewhere else.</big>"))
				return
		if ("Anti-Air")
			var/AA_in_range = 0
			for (var/obj/structure/milsim/anti_air/AA in range(10, src)) // Check if there are friendly Anti-Air within 10 tiles, if so block the build
				if (AA.faction_text == src.faction_text)
					AA_in_range++
			if (AA_in_range)
				to_chat(H, SPAN_WARNING("<big>You cannot build Anti-Air so close to another, consider moving away.</big>"))
				return

			var/fobs_in_range = 0
			for (var/obj/structure/fob_spawnpoint/fob in range(8, src)) // Check if there is a friendly FOB within 8 tiles
				if (fob.faction_text == src.faction_text)
					fobs_in_range++
			
			if (fobs_in_range) // If there are friendly FOBs nearby let them build it
				to_chat(H, SPAN_NOTICE("You starting building an Anti-Air with \the [src]."))
				if (do_after(H, 30 SECONDS, src))
					to_chat(H, SPAN("good", "<big>You build an Anti-Air with \the [src].</big>"))
					var/obj/structure/milsim/anti_air/AA = new/obj/structure/milsim/anti_air(get_turf(src))
					AA.attack_hand(H)
					qdel(src)
					return
			else // If there are no friendly FOBs nearby block the build
				to_chat(H, SPAN_WARNING("<big>You need to build this closer to an existing FOB.</big>"))
				return
			return

/obj/structure/supply_crate/update_icon()
	overlays.Cut()
	if (faction_text)
		switch(faction_text)
			if (RUSSIAN)
				overlays += image(icon = 'icons/obj/junk.dmi', icon_state = "o-ru")
			if (DUTCH)
				overlays += image(icon = 'icons/obj/junk.dmi', icon_state = "o-nl")
			if (BRITISH)
				overlays += image(icon = 'icons/obj/junk.dmi', icon_state = "o-uk")



/obj/structure/milsim
	name = "PARENT OBJECT"
	desc = "DO NOT USE."
	icon = 'icons/obj/obj64x96.dmi'
	anchored = TRUE
	flammable = FALSE
	w_class = ITEM_SIZE_GARGANTUAN
	opacity = FALSE
	density = TRUE
	layer = 5
	var/health = 500

/obj/structure/milsim/proc/try_destroy()
	if (health <= 0)
		visible_message(SPAN_DANGER("<big>\The [src] is blown apart!</big>"))
		message_admins("Anti-Air at ([src.x], [src.y], [src.z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[src.x];Y=[src.y];Z=[src.z]'>JMP</a>) has been destroyed.")
		qdel(src)
		return

/obj/structure/milsim/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 600
		if (2.0)
			health -= 400
		if (3.0)
			health -= 200
	try_destroy()

/obj/structure/milsim/bullet_act(var/obj/item/projectile/proj)
	return // Can only be blown up by explosives

/obj/structure/milsim/anti_air
	name = "Anti-Air SAM site"
	desc = "This is an Anti-Air Surface to Air Missile site for defence against aircraft."
	icon_state = "namas_open"
	health = 1000
	bound_width = 64
	bound_height = 64
	var/faction_text = null // To what faction does it belong?

/obj/structure/milsim/anti_air/attack_hand(mob/living/human/H as mob)
	if (!faction_text && map.ID != MAP_PEPELSIBIRSK)
		faction_text = H.faction_text
		name = "[map.roundend_condition_def2name(faction_text)] [name]"
		message_admins("[H.ckey] ([H.faction_text]) has built an Anti-Air at ([src.x], [src.y], [src.z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[src.x];Y=[src.y];Z=[src.z]'>JMP</a>).", H.ckey)
	return
