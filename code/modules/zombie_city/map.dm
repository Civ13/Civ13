// The zombie city world: a blank 200 x 200 plain that generator.dm fills at
// round start. The map is never in a vote list; the city host selects it by
// name and calls zombie_city_generate() from its own round-start hook when
// map.zombie_city is set.
/obj/map_metadata/nomads/zombie_city
	ID = MAP_ZOMBIE_CITY
	title = "Zombie City"
	description = "A procedurally generated city overrun by the dead. Loot what the living left behind and reach an evacuation point."
	lobby_icon = ""
	age = "2019"
	ordinal_age = 8
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = TRUE
	age8_done = TRUE
	default_research = 230
	research_active = FALSE
	gamemode = "Zombie City"
	gamemode_vote = FALSE
	mission_start_message = "<big>The city fell weeks ago. Its streets belong to the dead now.</big>"
	ambience = list("sound/ambience/desert.ogg")
	songs = list()
	var/zombie_city = TRUE

/area/caribbean/zombie_city
	name = "Zombie City"
