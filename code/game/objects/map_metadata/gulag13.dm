
/obj/map_metadata/gulag13
	ID = MAP_GULAG13
	title = "GULAG 13"
	no_winner ="The round is proceeding normally."
	lobby_icon = "icons/lobby/gulag.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/tundra, /area/caribbean/no_mans_land/invisible_wall/one)
	respawn_delay = 3600
	has_hunger = TRUE

	faction_organization = list(
		RUSSIAN,
		CIVILIAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/russian/land/inside/command,
		)
	age = "1946"
	ordinal_age = 6
	faction_distribution_coeffs = list(RUSSIAN = 0.25, CIVILIAN = 0.75)
	battle_name = "Gulag nr. 13"
	mission_start_message = "<font size=4>NKVD have <b>4 minutes</b> to prepare before the grace wall is removed for the NKVD, the Prisoners won't be able to cross until 30 minutes have elapsed.<br>The <b>NKVD</b> must keep the prisoners contained, and make them serve the Soviet Union with forced labor. The <b>Prisoners</b> must try to survive, increase their faction power, and if possible, escape.</font>"
	faction1 = RUSSIAN
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Red Army Choir - Slavery and Suffering:1" = "sound/music/slavery_and_suffering.ogg")
	gamemode = "Prison Simulation"
	var/list/points = list(
		list("Guards",0,0),
		list("German",0,0),
		list("Polish",0,0),
		list("Ukrainian",0,0),
	)
	is_RP = TRUE
	var/gracedown1 = TRUE
	var/siren = FALSE
	grace_wall_timer = 2400
obj/map_metadata/gulag13/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian/fantasy))
		. = FALSE
	if (J.is_civil_war == TRUE)
		. = FALSE
	if (J.is_abashiri)
		. = FALSE
	if (istype(J, /datum/job/russian))
		if (J.is_prison)
			. = TRUE
		else
			. = FALSE
	else
		if (J.is_prison && J.title != "DO NOT USE" && J.is_abashiri != TRUE)
			. = TRUE
		else
			. = FALSE

/obj/map_metadata/gulag13/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "NKVD"
		if (CIVILIAN)
			return "Prisoner"
/obj/map_metadata/gulag13/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "NKVD Guards"
		if (CIVILIAN)
			return "Prisoners"

/obj/map_metadata/gulag13/army2name(army)
	..()
	switch (army)
		if ("NKVD Guards")
			return "NKVD"
		if ("Prisoners")
			return "Prisoner"


/obj/map_metadata/gulag13/cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == RUSSIAN)
		return "<font size = 4>The grace wall is down!</font>"
	else
		return ""

/obj/map_metadata/gulag13/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == RUSSIAN)
		return "<font size = 4>The grace wall is up!</font>"
	else
		return ""
/obj/map_metadata/gulag13/New()
	..()
	spawn(100)
		load_new_recipes("config/crafting/material_recipes_camp.txt")
		override_global_recipes = "camp"
	spawn(3000)
		check_points_msg()
		config.no_respawn_delays = FALSE

/obj/map_metadata/gulag13/proc/check_points()
	for(var/i in points)
		if (i[1] != "Guards")
			i[2]=0
	for (var/mob/living/human/H in player_list)
		if (H.stat!=DEAD && H.original_job && istype(H.original_job, /datum/job/civilian/prisoner))
			var/curval = 0
			var/area/A = get_area(H)
			if (istype(A, /area/caribbean/nomads/ice/target))
				for(var/i in points)
					if (i[1]==H.nationality)
						i[3]+=4
					else if (i[1]!="Guards")
						i[3]+=2
			for(var/obj/item/stack/money/rubles/R in H)
				curval += R.amount
			if (H.wear_suit && istype(H.wear_suit, /obj/item/clothing/suit/storage))
				var/obj/item/clothing/suit/storage/ST = H.wear_suit
				for(var/obj/item/stack/money/rubles/R in ST.pockets)
					curval += R.amount
			for(var/i in points)
				if (i[1]==H.nationality)
					i[2]+=curval
	return

/obj/map_metadata/gulag13/proc/check_points_msg()
	check_points()
	spawn(1)
		world << "<font size = 4><span class = 'notice'><b>Current Score:</b></font></span>"
		for (var/i=1,i<=points.len,i++)
			world << "<br><font size = 3><span class = 'notice'>[points[i][1]]: <b>[points[i][2]+points[i][3]]</b></span></font>"
		var/donecheck = FALSE
		for(var/mob/living/human/H in player_list)
			if(H.stat!=DEAD && H.original_job && istype(H.original_job, /datum/job/civilian/prisoner) && !donecheck)
				var/area/A = get_area(H)
				if (istype(A, /area/caribbean/nomads/ice/target))
					world << "<br><font size = 3><span class = 'warning'>There are prisoners currently escaping!</span></font>"
					donecheck = TRUE

	spawn(2400)
		check_points_msg()
	return

/obj/map_metadata/gulag13/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (caribbean_blocking_area_types.Find(A.type))
		if (A.name == "I grace wall")
			if (!gracedown1)
				return TRUE
			else
				return FALSE
		else
			return (!faction1_can_cross_blocks() || !faction2_can_cross_blocks())
	return FALSE


/obj/item/weapon/prisoner_passport
	name = "Prisoner's Documents"
	desc = "The identification papers of a prisoner."
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
				name = "[document_name] prisoner documents"
				desc = "The identification papers of <b>[document_name]</b>."
				var/crimereason = "Criminal Behaviour"
				if (istype(H.original_job, /datum/job/civilian/prisoner))
					var/datum/job/civilian/prisoner/P = H.original_job
					switch(H.nationality)
						if ("Vory")
							crimereason = pick("Attempted murder.","Damage to people's property.","Theft of communal goods.")
						if ("German")
							crimereason = "Fought for the Fascist invaders during the Great Patriotic War."
						if ("Ukrainian")
							crimereason = "Supporting the Banderovitsi in [pick("Lvov","Tarnopol", "Lutsk", "Chelm")]."
						if ("Polish")
							crimereason = "Fighting for the Armia Krajowa in [pick("Grodno","Wroclaw", "Lodz", "Lvov")]."
						if ("Japanese")
							crimereason = "Fighting for the Imperial Japanese Army in [pick("Khalkhyn Gol", "Mongolia", "the Krillin Islands", "Sakhalinsk")]."

					document_details = list(H.h_style, P.original_hair, H.f_style, P.original_facial, crimereason, H.gender, rand(6,32),P.original_eyes, P.randrole)
				else if (istype(H.original_job, /datum/job/civilian/abashiri/prisoner/wing1) || istype(H.original_job, /datum/job/civilian/abashiri/prisoner/wing2) || istype(H.original_job, /datum/job/civilian/abashiri/prisoner/wing2) || istype(H.original_job, /datum/job/civilian/abashiri/prisoner/wing3) || istype(H.original_job, /datum/job/civilian/abashiri/prisoner/wing3_danger))
					var/datum/job/civilian/abashiri/prisoner/P = H.original_job
					switch(H.nationality)
						if ("Japanese")
							crimereason = pick("Attempted murder.","Damage to people's property.","Theft of private property.","Crimes against the Imperial Japanese Empire")
						if ("Russian")
							crimereason = pick("Fought for the Imperial Russian Army in the Russo-Japanese War.", "Tresspassing into Japan", "Spreading Anti-Imperialist Propaganda")
						if ("Ainu")
							crimereason = pick("Insubordination in the Imperial Japanese Army during the [pick("Russo-Japanese War", "Sino-Japanese War")].", "Murder", "Resisting Assimilation to Japanese Society")
					document_details = list(H.h_style, P.original_hair, H.f_style, P.original_facial, crimereason, H.gender, rand(6,32),P.original_eyes, P.randrole)
/obj/item/weapon/prisoner_passport/examine(mob/user)
	user << "<span class='info'>*---------*</span>"
	..(user)
	if (document_details.len >= 9)
		user << "<b><span class='info'>Hair:</b> [document_details[1]], [document_details[2]] color</span>"
		if (document_details[6] == "male")
			user << "<b><span class='info'>Face:</b> [document_details[3]], [document_details[4]] color</span>"
		user << "<b><span class='info'>Eyes:</b> [document_details[8]]</span>"
		user << "<b><span class='info'>Detained for:</b> [document_details[5]]</span>"
		user << "<b><span class='info'>Sentence:</b> [document_details[7]] years</span>"
		user << "<b><span class='info'>Assigned:</b> [document_details[9]]</span>"
	user << "<span class='info'>*---------*</span>"
	if (guardnotes.len)
		for(var/i in guardnotes)
			user << "NOTE: [i]"
	user << "<span class='info'>*---------*</span>"

/obj/item/weapon/prisoner_passport/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!ishuman(H))
		return
	if ((istype(I, /obj/item/weapon/pen) && istype(H.original_job, /datum/job/russian)) || (istype(I, /obj/item/weapon/pen) && istype(H.original_job, /datum/job/japanese/abashiri/guard)))
		var/confirm = WWinput(H, "Do you want to add a note to these documents?", "Prisoner Documents", "No", list("No","Yes"))
		if (confirm == "No")
			return
		else
			var/texttoadd = input(H, "What do you want to write? Up to 150 characters", "Notes", "") as text
			texttoadd = sanitize(texttoadd, 150, FALSE)
			texttoadd = "<i>[texttoadd] - <b>[H.real_name]</b></i>"
			guardnotes += texttoadd
			return

/obj/item/weapon/prisoner_passport/secondary_attack_self(mob/living/human/user)
	showoff(user)
	return

/mob/living/human/proc/Sound_Alarm()
	set name = "Sound the Siren"
	set category = "Officer"
	if (!map || (map.ID != MAP_GULAG13 && map.ID != MAP_ABASHIRI))
		usr << "You cannot use this in this map."
		return
	if (!original_job || (!(istype(original_job, /datum/job/russian)) && !(istype(original_job, /datum/job/japanese/abashiri/guard))))
		usr << "You cannot use this."
		return
	if (istype(map, /obj/map_metadata/gulag13))
		var/obj/map_metadata/gulag13/G13 = map
		if (!G13.siren)
			world << "<font size=3 color='red'><center><b>ALARM</b><br>The siren has been activated, all prisoners must stop what they are doing and lay on the floor until the alarm is lifted!</center></font>"
			var/warning_sound = sound('sound/misc/siren.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			for (var/mob/M in player_list)
				M.client << warning_sound
			G13.siren = TRUE
			spawn(285)
				if (G13.siren)
					G13.alarm_proc()
				return
	if (istype(map, /obj/map_metadata/abashiri))
		var/obj/map_metadata/abashiri/ABA = map
		if (!ABA.siren)
			world << "<font size=3 color='red'><center><b>ALARM</b><br>The siren has been activated, all prisoners must stop what they are doing and lay on the floor until the alarm is lifted!</center></font>"
			var/warning_sound = sound('sound/misc/siren.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			for (var/mob/M in player_list)
				M.client << warning_sound
			ABA.siren = TRUE
			spawn(285)
				if (ABA.siren)
					ABA.alarm_proc()
				return
/mob/living/human/proc/Stop_Alarm()
	set name = "Stop the Siren"
	set category = "Officer"
	if (!map || (map.ID != MAP_GULAG13 && map.ID != MAP_ABASHIRI))
		usr << "You cannot use this in this map."
		return
	if (!original_job || (!(istype(original_job, /datum/job/russian)) && !(istype(original_job, /datum/job/japanese/abashiri/guard))))
		usr << "You cannot use this."
		return
	if (istype(map, /obj/map_metadata/gulag13))
		var/obj/map_metadata/gulag13/G13 = map
		if (G13.siren)
			world << "<font size=3 color='green'><center><b>ALARM LIFTED</b><br>The siren has been stopped, prisoners can get back up.</center></font>"
			var/warning_sound = sound(null, channel = 777)
			for (var/mob/M in player_list)
				M.client << warning_sound
			G13.siren = FALSE
	if (istype(map, /obj/map_metadata/abashiri))
		var/obj/map_metadata/abashiri/ABA = map
		if (ABA.siren)
			world << "<font size=3 color='green'><center><b>ALARM LIFTED</b><br>The siren has been stopped, prisoners can get back up.</center></font>"
			var/warning_sound = sound(null, channel = 777)
			for (var/mob/M in player_list)
				M.client << warning_sound
			ABA.siren = FALSE

/obj/map_metadata/gulag13/proc/alarm_proc()
	if (siren)
		var/warning_sound = sound('sound/misc/siren.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		for (var/mob/M in player_list)
			M.client << warning_sound
		world << "<font size=3 color='red'><center><b>ALARM</b><br>The alarm is still on!</center></font>"

		spawn(285)
			if (siren)
				alarm_proc()
			return


/obj/structure/camp_exportbook
	name = "camp exports"
	desc = "Use this to export products from the camp and gain points for the guards."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook2"
	density = TRUE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/camp_exportbook/attackby(var/obj/item/stack/S, var/mob/living/human/H)
	var/obj/map_metadata/gulag13/G = null
	var/obj/map_metadata/abashiri/AB = null
	if (istype(map, /obj/map_metadata/gulag13))
		G = map
		if (istype(S, /obj/item/stack/ore) || istype(S, /obj/item/stack/material/wood))
			for(var/i in G.points)
				if (i[1]=="Guards")
					i[2]+=S.amount*S.value
					H << "You export \the [S]."
					qdel(S)
					new/obj/item/stack/money/rubles(src.loc, round(S.amount*S.value))
					return
	else if (istype(map, /obj/map_metadata/abashiri))
		AB = map
		if (istype(S, /obj/item/stack/ore) || istype(S, /obj/item/stack/material/wood))
			for(var/i in AB.points)
				if (i[1]=="Guards")
					i[2]+=S.amount*S.value
					H << "You export \the [S]."
					qdel(S)
					new/obj/item/stack/money/yen(src.loc, round(S.amount*S.value))
					return
	else
		return