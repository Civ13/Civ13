/obj/map_metadata/nationsrp
	ID = MAP_NATIONSRP
	title = "Nations RP"
	lobby_icon_state = "civ13"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/sea/temperate)
	respawn_delay = 6000 // 10 minutes!
	has_hunger = TRUE


	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "Industrial Age"
	no_winner = "The round is proceeding normally."
	is_RP = TRUE
	civilizations = TRUE
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the nations"
	faction1 = CIVILIAN
	availablefactions = list("Civilization A Citizen", "Civilization B Citizen")
	mission_start_message = "<big>Two industrial towns govern this land. The grace wall will end in <b>90 minutes</b>. This is an RP focused map; people of both nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	nomads = FALSE
	availablefactions_run = FALSE
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	default_research = 105
	gamemode = "Nations RP"
	ordinal_age = 4
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	research_active = FALSE
	is_singlefaction = TRUE

/obj/map_metadata/nationsrp/New()
	..()
	civname_a = "Latin Nation"
	civname_b = "Gaelic Nation"
	var/newnamea = list("Latin Nation" = list(default_research,default_research,default_research,null,0,"cross","#D4AF37","#660000"))
	var/newnameb = list("Gaelic Nation" = list(default_research,default_research,default_research,null,0,"saltire","#C0C0C0","#006600"))
	custom_civs += newnamea
	custom_civs += newnameb
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)
	spawn(18000)
		seasons()

/obj/map_metadata/nationsrp/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 54000 || admin_ended_all_grace_periods)

/obj/map_metadata/nationsrp/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 54000 || admin_ended_all_grace_periods)

/obj/map_metadata/nationsrp/cross_message(faction)
	return "<big><b>THE GRACE PERIOD HAS ENDED!</b></big>"

/obj/map_metadata/nationsrp/med
	ID = MAP_NATIONSRPMED
	title = "Nations RP Mediterranean"
	mission_start_message = "<big>Two imperial nations rule this land. The grace wall will end in <b>30 minutes</b>. This is an RP focused map, people of both nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	default_research = 88
	ordinal_age = 3
	age4_done = FALSE

/obj/map_metadata/nationsrp/med/New()
	..()
	civname_a = "Greek Nation"
	civname_b = "Turkish Nation"
	var/newnamea = list("Greek Nation" = list(default_research,default_research,default_research,null,0,"saltire","#D4AF37","#660000"))
	var/newnameb = list("Turkish Nation" = list(default_research,default_research,default_research,null,0,"saltire","#C0C0C0","#006600"))
	custom_civs += newnamea
	custom_civs += newnameb
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)
	spawn(18000)
		seasons()
