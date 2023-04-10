
/obj/map_metadata/little_creek
	ID = MAP_LITTLE_CREEK
	title = "Big Trouble in Little Creek (RP)"
	lobby_icon = "icons/lobby/wildwest.png"
	no_winner ="The fighting for the town is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 3600
	has_hunger = TRUE

	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "1873"
	ordinal_age = 4
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "Little Creek"
	mission_start_message = "<font size=3>At the small frontier town of <b>Little Creek</b>, the Sheriff recieves a warning: Two groups of outlaws are about to rob the town's bank! He must organize the bank's defense and prevent them...</font><br><br><big><i>The grace wall will go down in <b>4 minutes</b>. The Outlaws have <b>30 minutes</b> to collect <b>750 dollars</b>!</big></i>"
	faction1 = CIVILIAN
	ambience = list('sound/ambience/desert.ogg')
	gamemode = "Bank Robbery (RP)"
	is_RP = TRUE
	songs = list(
		"The Good, the Bad, and the Ugly Theme:1" = "sound/music/good_bad_ugly.ogg",)
	is_singlefaction = TRUE
obj/map_metadata/little_creek/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_cowboy == TRUE)
		if (J.title == "Outlaw" || J.title == "Sheriffs Deputy")
			. = FALSE
		else if (J.is_heist == TRUE)
			. = FALSE
		else if (J.is_civil_war == TRUE)
			. = FALSE
		else
			. = TRUE
	else
		. = FALSE

/obj/map_metadata/little_creek/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)
	
/obj/map_metadata/little_creek/cross_message(faction)
	return ""

/obj/map_metadata/little_creek/reverse_cross_message(faction)
	return ""

/obj/map_metadata/little_creek/update_win_condition()
	if (ticker.delay_end)
		return FALSE
	if (win_condition_spam_check)
		return FALSE
	for(var/obj/structure/carriage/C in world)
		if (C.faction1val >= 700) // total value stored = 2191. So roughly 1/3rd
			var/message = "The <b>West Side Gang</b> has sucessfully stolen over 700 dollars! The robbery was successful!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			ticker.finished = TRUE
			return TRUE
		else if (C.faction2val >= 700) // total value stored = 2191. So roughly 1/3rd
			var/message = "The <b>East Side Gang</b> has sucessfully stolen over 700 dollars! The robbery was successful!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			ticker.finished = TRUE
			return TRUE
	if (processes.ticker.playtime_elapsed >= 72000)
		ticker.finished = TRUE
		var/message = "The Sheriff's troops have sucessfully defended the Bank! With the Army arriving, the Outlaws retreat!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return TRUE


/obj/structure/carriage
	name = "Stagecoach Load"
	desc = ""
	icon = 'icons/obj/storage.dmi'
	icon_state = "miningcaropen"
	anchored = TRUE
	opacity = FALSE
	density = TRUE
	flammable = FALSE
	var/storedvalue = 0
	var/prevent = FALSE
	var/faction1val = 0
	var/faction2val = 0
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/carriage/New()
	..()
	desc = "West Side: [faction1val]. East Side: [faction2val]."
	timer()

/obj/structure/carriage/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W,/obj/item/stack/money) || istype(W,/obj/item/stack/material/gold) || istype(W,/obj/item/stack/material/silver) || istype(W,/obj/item/stack/material/diamond))
		if (ishuman(user))
			var/mob/living/human/H = user
			if (H.original_job_title == "West Side Gang")
				faction1val += (W.value*W.amount)
			else if (H.original_job_title == "East Side Gang")
				faction2val += (W.value*W.amount)
			desc = "West Side: [faction1val]. East Side: [faction2val]."
			user << "You place \the [W] inside \the [src]."
		qdel(W)
		if (faction1val >= 750)
			map.update_win_condition()
		else if (faction2val >= 750)
			map.update_win_condition()
	else
		return

/obj/structure/carriage/proc/timer()
	spawn(4000)
		world << "<big>Current status: West Side Gang: <b>[faction1val]/700</b>. East Side Gang: <b>[faction2val]/700</b>."
		timer()