/obj/map_metadata/four_colonies
	ID = MAP_FOUR_COLONIES
	title = "Four Colonies"
	lobby_icon = "icons/lobby/imperial.png"
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 7200 // 12 minutes!
	has_hunger = TRUE

	faction_organization = list(
		BRITISH,
		PORTUGUESE,
		FRENCH,
		SPANISH)

	roundend_condition_sides = list(
	//nonexistent in this map, to prevent win by capture
		list(SPANISH) = /area/caribbean/british,
		list(PORTUGUESE) = /area/caribbean/british,
		list(FRENCH) = /area/caribbean/british,
		list(SPANISH) = /area/caribbean/british,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(BRITISH = 0.25, SPANISH = 0.25, FRENCH = 0.25, PORTUGUESE = 0.25)
	battle_name = "Colonization"
	mission_start_message = "<big>Four countries have reached this Island! The <b>Colonists</b> must build their villages. After <b>30</b> minutes, the grace wall will end.</big><br><span class = 'notice'><i>THIS IS A RP MAP - ALL FACTIONS ARE FRIENDLY BY DEFAULT.</b> No griefing will be tolerated. If you break the rules, you will be banned from this gamemode!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	faction2 = CIVILIAN
	songs = list(
		"Nassau Shores:1" = "sound/music/nassau_shores.ogg",)
	gamemode = "Faction-Based RP"
	is_RP = TRUE
	grace_wall_timer = 18000

	New()
		..()
		spawn(3000)
			score()
/obj/map_metadata/four_colonies/proc/score()
	world << "<b><font color='yellow' size=3>Faction Treasuries:</font></b>"
	for(var/obj/structure/closet/crate/chest/treasury/SF in world)
		if (SF.faction)
			var/list/tlist = list(capitalize(SF.faction),0)
			for(var/obj/item/I in SF)
				if (istype(I, /obj/item/stack/money))
					var/obj/item/stack/money/M = I
					tlist[2]+=M.amount*M.value
			world << "<big><font color='yellow' size=2>[tlist[1]]: [tlist[2]] dollars</font></big>"

	spawn(3000)
		score()
/obj/map_metadata/four_colonies/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_1713 == TRUE)
		. = TRUE
	else
		. = FALSE


/obj/map_metadata/four_colonies/cross_message(faction)
	return ""