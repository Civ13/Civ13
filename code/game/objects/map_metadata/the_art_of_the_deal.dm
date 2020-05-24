/obj/map_metadata/art_of_the_deal
	ID = MAP_THE_ART_OF_THE_DEAL
	title = "The Art of the Deal"
	lobby_icon_state = "civ13"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 0
	is_singlefaction = TRUE
	battleroyale = TRUE

	no_winner ="The fighting is still going."

	faction_organization = list(
		CIVILIAN)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british/ship, //it isnt in the map so nobody wins by capture
		)
	age = "2013"
	ordinal_age = 8
	var/fac_nr = 3
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the deal"
	mission_start_message = "<font size=4><b>3</b> corporations <b>Last standing player wins!</b></font>"
	var/winner_name = "Unknown"
	var/list/winner_ckeys = list()
	faction1 = CIVILIAN
	faction2 = CIVILIAN
	gamemode = "Battleroyale"
	required_players = 6

/obj/map_metadata/art_of_the_deal/New()
	..()
	var/newnamea = list("Red Corporation" = list(230,230,230,null,0,"sun","#7F0000","#7F7F7F",0,0))
	var/newnameb = list("Blue Syndicate" = list(230,230,230,null,0,"sun","#00007F","#7F7F7F",0,0))
	var/newnamec = list("Green Enterprises" = list(230,230,230,null,0,"sun","#007F00","#7F7F7F",0,0))
	var/newnamed = list("Yellow Conglomerate" = list(230,230,230,null,0,"sun","#E5E500","#7F7F7F",0,0))
	custom_civs += newnamea
	custom_civs += newnameb
	custom_civs += newnamec
	custom_civs += newnamed
/obj/map_metadata/art_of_the_deal/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_deal)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/art_of_the_deal/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1800 || admin_ended_all_grace_periods)

/obj/map_metadata/art_of_the_deal/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1800 || admin_ended_all_grace_periods)

/obj/map_metadata/art_of_the_deal/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4><b>The round has started!</b> Players may now cross the invisible wall!</font>"
