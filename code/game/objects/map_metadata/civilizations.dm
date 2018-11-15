#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/civilizations
	ID = MAP_CIVILIZATIONS
	title = "Civilizations (225x225x2)"
	lobby_icon_state = "civilizations"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		CIVILIAN,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "5000 B.C."
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>After ages as hunter-gatherers, one tribe has settled in this area and started farming. Will it advance through the ages, or be forgotten forever?</big>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	single_faction = TRUE
	availablefactions_run = TRUE
	songs = list(
		"Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg',)


/obj/map_metadata/civilizations/New()

	if (clients.len <= 8)
		tribes_nr = 1
	if (clients.len > 8 && clients.len <= 16)
		tribes_nr = 2
	if (clients.len > 16 && clients.len <= 24)
		tribes_nr = 3
	if (clients.len > 24 && clients.len <= 30)
		tribes_nr = 4
	if (clients.len > 30 && clients.len <= 36)
		tribes_nr = 5
	if (clients.len > 36)
		tribes_nr = 6
	if (tribes_nr >= 2)
		mission_start_message = "<big>After ages as hunter-gatherers, [tribes_nr] tribes have settled in this area and started farming. Will they advance through the ages, or be forgotten forever?</big>"
/obj/map_metadata/civilizations/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/civilizations/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/civilizations/cross_message(faction)
	return ""

#undef NO_WINNER