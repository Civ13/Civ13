/obj/map_metadata/nationsrp
	ID = MAP_NATIONSRP
	title = "Nations RP"
	lobby_icon = "icons/lobby/civ13.gif"
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
	age5_done = FALSE
	age6_done = FALSE
	age7_done = FALSE
	age8_done = FALSE
	research_active = FALSE
	is_singlefaction = TRUE
	grace_wall_timer = 54000

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
		config.no_respawn_delays = FALSE

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

/obj/map_metadata/nationsrp/ww2
	ID = MAP_NATIONSRP_WW2
	title = "Nations RP World War 2"
	mission_start_message = "<big>Two nations rule this land. The grace wall will end in <b>30 minutes</b>. This is an RP focused map, people of both nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	default_research = 145
	ordinal_age = 6
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE

/obj/map_metadata/nationsrp/ww2/New()
	..()
	civname_a = "Russian Nation"
	civname_b = "German Nation"
	var/newnamea = list("Russian Nation" = list(default_research,default_research,default_research,null,0,"saltire","#D4AF37","#660000"))
	var/newnameb = list("German Nation" = list(default_research,default_research,default_research,null,0,"saltire","#C0C0C0","#006600"))
	custom_civs += newnamea
	custom_civs += newnameb
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)

/obj/map_metadata/nationsrp/coldwar
	ID = MAP_NATIONSRP_COLDWAR
	title = "Nations RP Cold War"
	lobby_icon = "icons/lobby/coldwar.png"
	mission_start_message = "<big>Two nations rule this land. The grace wall will end in <b>30 minutes</b>. This is an RP focused map, people of both nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	age = "the Cold War"
	songs = list(
		"War Never Changes:1" = "sound/music/war_never_changes.ogg",)
	default_research = 175
	ordinal_age = 7
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = TRUE

/obj/map_metadata/nationsrp/coldwar/New()
	..()
	civname_a = "English Nation"
	civname_b = "Russian Nation"
	var/newnamea = list("English Nation" = list(default_research,default_research,default_research,null,0,"saltire","#C0C0C0","#006600"))
	var/newnameb = list("Russian Nation" = list(default_research,default_research,default_research,null,0,"saltire","#D4AF37","#660000"))
	custom_civs += newnamea
	custom_civs += newnameb
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)

/obj/map_metadata/nationsrp/coldwar_campaign
	ID = MAP_NATIONSRP_COLDWAR_CAMPAIGN
	title = "Nations RP Cold War"
	lobby_icon = "icons/lobby/coldwar.png"
	mission_start_message = "<big>Two nations rule this land. The grace wall will end in <b>30 minutes</b>. This is an RP focused map, people of both nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	age = "the Cold War"
	songs = list(
		"War Never Changes:1" = "sound/music/war_never_changes.ogg",)
	default_research = 175
	ordinal_age = 7
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = TRUE

/obj/map_metadata/nationsrp/coldwar_campaign/New()
	..()
	civname_a = "Redmenian Nation"
	civname_b = "Blugoslavian Nation"
	var/newnamea = list("Redmenian Nation" = list(default_research,default_research,default_research,null,0,"star","#D7A326","#DA1515"))
	var/newnameb = list("Blugoslavian Nation" = list(default_research,default_research,default_research,null,0,"sun","#B5AA6C","#2A44CF"))
	custom_civs += newnamea
	custom_civs += newnameb
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)

/obj/map_metadata/nationsrp/triple
	ID = MAP_NATIONSRP_TRIPLE
	title = "Triple Nations RP"
	availablefactions = list("Civilization A Citizen", "Civilization B Citizen", "Civilization C Citizen")
	mission_start_message = "<big>Three nations rule this land. The grace wall will end in <b>30 minutes</b>. This is an RP focused map, people of all three nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	default_research = 145
	ordinal_age = 4
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = FALSE
	age6_done = FALSE
	age7_done = FALSE
	age8_done = FALSE

/obj/map_metadata/nationsrp/triple/New()
	..()
	civname_a = "Latin Nation"
	civname_b = "Gaelic Nation"
	civname_c = "German Nation"
	var/newnamea = list("Latin Nation" = list(default_research,default_research,default_research,null,0,"cross","#D4AF37","#660000"))
	var/newnameb = list("Gaelic Nation" = list(default_research,default_research,default_research,null,0,"saltire","#C0C0C0","#006600"))
	var/newnamec = list("German Nation" = list(default_research,default_research,default_research,null,0,"saltire","#0B5394","#B45F06"))
	custom_civs += newnamea
	custom_civs += newnameb
	custom_civs += newnamec
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)
	civc_research = list(default_research,default_research,default_research,null)
