/obj/map_metadata/teutoburg
	ID = MAP_TEUTOBURG
	title = "Teutoburg"
	lobby_icon = 'icons/lobby/ancient.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300


	faction_organization = list(
		ROMAN,
		GERMAN)

	roundend_condition_sides = list(
		list(ROMAN) = /area/caribbean/roman,
		list(GERMAN) = /area/caribbean/german/inside/objective
		)
	age = "9 A.D."
	ordinal_age = 1
	faction_distribution_coeffs = list(ROMAN = 0.4, GERMAN = 0.6)
	battle_name = "battle of Teutoburg Forest"
	mission_start_message = "<font size=4>The <b>Germanic</b> and <b>Roman</b> armies are facing each other across the Teutoburg forest! Each side wants to capture the other's base. Get ready for the battle, it will start in <b>5 minutes</b>!</font>"
	faction1 = ROMAN
	faction2 = GERMAN
	ambience = list('sound/ambience/jungle1.ogg')
	grace_wall_timer = 3000
	songs = list(
		"Divinitus:1" = 'sound/music/divinitus.ogg',)



