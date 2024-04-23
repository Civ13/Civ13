/obj/map_metadata/nationsrp
	ID = MAP_NATIONSRP
	title = "Nations RP"
	lobby_icon = 'icons/lobby/civilizations.gif'
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
	grace_wall_timer = 90 MINUTES

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
	lobby_icon = 'icons/lobby/coldwar.png'
	mission_start_message = "<big>Two nations rule this land. The grace wall will end in <b>24 hours</b>. This is an RP focused map, people of both nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	age = "the Cold War"
	songs = list(
		"Emma:1" = "sound/music/emma.ogg",)
	default_research = 175
	ordinal_age = 7
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = TRUE
	grace_wall_timer = 24 HOURS

/obj/map_metadata/nationsrp/coldwar/New()
	..()
	civname_a = "United States of America"
	civname_b = "Soviet Union"
	var/newnamea = list("United States of America" = list(default_research,default_research,default_research,null,0,"saltire","#C0C0C0","#000a66"))
	var/newnameb = list("Soviet Union" = list(default_research,default_research,default_research,null,0,"saltire","#D4AF37","#660000"))
	custom_civs += newnamea
	custom_civs += newnameb
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)

/obj/map_metadata/nationsrp/coldwar_campaign
	ID = MAP_NATIONSRP_COLDWAR_CAMPAIGN
	title = "Nations RP Cold War"
	lobby_icon = 'icons/lobby/campaign.png'
	mission_start_message = "<big>Two nations rule this land. The grace wall will end in <b>2 days</b>. This is an RP focused map, people of both nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	age = "the Cold War"
	songs = list(
		"Emma:1" = "sound/music/emma.ogg",)
	is_singlefaction = FALSE
	availablefactions = list("Redmenian Civilian", "Blugoslavian Civilian")
	faction_organization = list(
		REDFACTION,
		BLUEFACTION)

	roundend_condition_sides = list(
		list(REDFACTION) = /area/caribbean/japanese,
		list(BLUEFACTION) = /area/caribbean/british,
		)
	faction_distribution_coeffs = list(REDFACTION = 0.5, BLUEFACTION = 0.5)
	faction1 = REDFACTION
	faction2 = BLUEFACTION
	default_research = 175
	ordinal_age = 7
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = TRUE
	grace_wall_timer = 2 DAYS

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

/obj/map_metadata/nationsrp/coldwar_campaign/cross_message(faction)
	var/warning_sound = sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = TRUE, channel = 777)
	for (var/mob/M in player_list)
		M.client << warning_sound

	if (faction == REDFACTION)
		return SPAN_DANGER("<font size = 5>THE GRACE PERIOD HAS ENDED<br>REDMENIA AND BLUGOSLAVIA ARE AT WAR!</font>")
	else
		return ""

/obj/map_metadata/nationsrp/coldwar_campaign/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/nationsrp/triple
	ID = MAP_NATIONSRP_TRIPLE
	title = "Triple Nations RP"
	availablefactions = list("Civilization A Citizen", "Civilization B Citizen", "Civilization C Citizen")
	mission_start_message = "<big>Three nations rule this land. The grace wall will end in <b>30 minutes</b>. This is a RP focused map, people of all three nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
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
	civname_a = "British Nation"
	civname_b = "French Nation"
	civname_c = "German Nation"
	var/newnamea = list("British Nation" = list(default_research,default_research,default_research,null,0,"bigcross","#800101","#C0C0C0"))
	var/newnameb = list("French Nation" = list(default_research,default_research,default_research,null,0,"saltire","#193798","#C0C0C0"))
	var/newnamec = list("German Nation" = list(default_research,default_research,default_research,null,0,"cross","#FFCC1E","#111111"))
	custom_civs += newnamea
	custom_civs += newnameb
	custom_civs += newnamec
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)
	civc_research = list(default_research,default_research,default_research,null)
