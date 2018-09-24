#define NO_WINNER "The crew is alive."
/obj/map_metadata/cursed_island
	ID = MAP_CURSED_ISLAND
	title = "Cursed Island (100x100x1)"
	lobby_icon_state = "cursed"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,
		/area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 0
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british
		)
	front = "Pacific"
	faction_distribution_coeffs = list(BRITISH = 1)
	battle_name = "battle of the cursed island"
	mission_start_message = "<big>After a storm, your battered ship had to dock at this island for repairs. Only then did the crew notice something was wrong about this place...<br><b>Retrieve the cursed treasure and bring it back to the ship to break the curse!</b></big>"
	ambience = list('sound/ambience/spooky1.ogg')
	faction1 = BRITISH
	single_faction = TRUE
	availablefactions_run = TRUE
	songs = list(
		"Spooky Tunes" = 'sound/ambience/spooky1.ogg',)
	//times_of_day = list("Night")
/obj/map_metadata/cursed_island/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/cursed_island/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/cursed_island/cross_message(faction)
	return ""

#undef NO_WINNER