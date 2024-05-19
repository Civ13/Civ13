
/obj/map_metadata/little_creek_tdm
	ID = MAP_LITTLE_CREEK_TDM
	title = "Big Trouble in Little Creek (TDM)"
	lobby_icon = 'icons/lobby/wildwest.png'
	no_winner ="The fighting for the town is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one, /area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 600


	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "1873"
	ordinal_age = 4
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "Little Creek"
	mission_start_message = "<font size=3>At the small frontier town of <b>Little Creek</b>, the Sheriff recieves a warning: A group of outlaws is about to rob the town's bank! He must organize the bank's defense and prevent them...</font><br><br><big><i>The grace wall will go down in <b>6 minutes</b>. The Outlaws have <b>30 minutes</b> to collect <b>1500 dollars</b> before the Army arrives!</big></i>"
	faction1 = CIVILIAN
	grace_wall_timer = 3600
	ambience = list('sound/ambience/desert.ogg')
	gamemode = "Bank Robbery (TDM)"
	songs = list(
		"The Good, the Bad, and the Ugly Theme:1" = 'sound/music/good_bad_ugly.ogg',)
	is_singlefaction = TRUE
obj/map_metadata/little_creek_tdm/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_cowboy == TRUE)
		if (J.title == "Outlaw" || J.title == "Sheriffs Deputy" || J.title == "Sheriff")
			. = TRUE
		else if (J.is_deathmatch == TRUE)
			. = FALSE
		else if (J.is_heist == TRUE)
			. = FALSE
		else if (J.is_civil_war == TRUE)
			. = FALSE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/little_creek_tdm/cross_message(faction)
	return "<font size = 4>The grace wall is lifted!</font>"

/obj/map_metadata/little_creek_tdm/reverse_cross_message(faction)
	return ""

/obj/map_metadata/little_creek_tdm/update_win_condition()
	if (win_condition_spam_check)
		return FALSE
	for(var/obj/structure/carriage_tdm/C in world)
		if (C.storedvalue >= 1500) // total value stored = 2191. So roughly 2/3rds
			var/message = "The Outlaws have sucessfully stolen over 1500 dollars! The robbery was successful!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			ticker.finished = TRUE
			return TRUE
	if (processes.ticker.playtime_elapsed >= 18000)
		ticker.finished = TRUE
		var/message = "The Sheriff's troops have sucessfully defended the Bank! With the Army arriving, the Outlaws retreat!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return TRUE

/obj/map_metadata/little_creek_tdm/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))

			if (H.original_job.is_outlaw == TRUE && !H.original_job.is_law == TRUE)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.original_job.is_law == TRUE && !H.original_job.is_outlaw == TRUE)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE


/obj/structure/carriage_tdm
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
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/carriage_tdm/New()
	..()
	desc = "Stored Value: [storedvalue]."
	timer()

/obj/structure/carriage_tdm/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W,/obj/item/stack/money) || istype(W,/obj/item/stack/material/gold) || istype(W,/obj/item/stack/material/silver) || istype(W,/obj/item/stack/material/diamond))
		storedvalue += (W.value*W.amount)
		desc = "Stored Value: [storedvalue]."
		user << "You place \the [W] inside \the [src]."
		qdel(W)
		if (storedvalue >= 1500)
			map.update_win_condition()
	else
		return

/obj/structure/carriage_tdm/proc/timer()
	spawn(4000)
		world << "<big>Current status: Outlaws: <b>[storedvalue]/1500 Dollars</b></big>."
		timer()