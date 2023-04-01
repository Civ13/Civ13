/obj/map_metadata/nomads_persistence_beta
	ID = MAP_NOMADS_PERSISTENCE_BETA
	title = "Nations RP (Persistence BETA)"
	lobby_icon = "icons/lobby/campaign.gif"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	has_hunger = TRUE
	faction_organization = list(
		PIRATES,
		CIVILIAN)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/japanese,
		list(CIVILIAN) = /area/caribbean/british,
		)
	age = "2023"
	no_winner = "The round is proceeding normally."
	is_RP = TRUE
	civilizations = TRUE
	faction_distribution_coeffs = list(PIRATES = 0.5, CIVILIAN = 0.5)
	battle_name = "the nations"
	faction1 = PIRATES
	faction2 = CIVILIAN
	availablefactions = list("Redmenian Civilian", "Blugoslavian Civilian")
	mission_start_message = "<big>Two modern countries govern this land. The grace wall will end in <b>90 minutes</b>. This is an RP focused map; people of both nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	nomads = FALSE
	availablefactions_run = FALSE
	songs = list(
		"Emma:1" = "sound/music/emma.ogg",)
	default_research = 210
	gamemode = "Nations RP (Persistence)"
	ordinal_age = 8
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = TRUE
	age8_done = TRUE
	research_active = FALSE
	grace_wall_timer = 90 MINUTES
	force_mapgen = TRUE

/obj/map_metadata/nomads_persistence_beta/New()
	..()
	civname_a = "Redmenian Nation"
	civname_b = "Blugoslavian Nation"
	var/newnamea = list("Redmenian Nation" = list(default_research,default_research,default_research,null,0,"star","#D7A326","#DA1515"))
	var/newnameb = list("Blugoslavian Nation" = list(default_research,default_research,default_research,null,0,"sun","#B5AA6C","#2A44CF"))
	custom_civs += newnamea
	custom_civs += newnameb
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)
	spawn(18000)
		seasons()
		config.no_respawn_delays = FALSE

/obj/map_metadata/nomads_persistence_beta/cross_message(faction)
	return "<big><b>THE GRACE PERIOD HAS ENDED!</b></big>"