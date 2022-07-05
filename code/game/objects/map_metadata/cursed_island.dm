
/obj/map_metadata/cursed_island
	ID = MAP_CURSED_ISLAND
	title = "Cursed Island"
	lobby_icon = "icons/lobby/cursed.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,
		/area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 0

	no_winner ="The crew is alive."
	no_hardcore = TRUE
	faction_organization = list(
		BRITISH,)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(BRITISH = 1)
	battle_name = "battle of the cursed island"
	mission_start_message = "<big>After a storm your battered ship had to beach at this island for repairs. Only then did the crew notice something was wrong about this place...<br><b>Retrieve the cursed treasure and bring it back to the ship to break the curse!</b></big>"
	ambience = list('sound/ambience/rain.ogg')
	faction1 = BRITISH
	is_singlefaction = TRUE
	availablefactions_run = TRUE
	songs = list(
		"Words Trough the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	gamemode = "Player vs NPCs"
	grace_wall_timer = 1200

/obj/map_metadata/cursed_island/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/british))
		if (J.is_navy)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/cursed_island/cross_message(faction)
	return ""

/obj/map_metadata/cursed_island/update_win_condition()
	var/treasure_location = get_area(locate(/obj/item/cursedtreasure))
	if (win_condition_spam_check)
		return FALSE
	if (istype(treasure_location, /area/caribbean/british/ship))
		ticker.finished = TRUE
		var/message = "The treasure was retrieved! The curse is broken!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
