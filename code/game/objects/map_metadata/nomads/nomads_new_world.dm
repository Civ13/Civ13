
/obj/map_metadata/nomads/new_world
	ID = MAP_NOMADS_NEW_WORLD
	title = "Nomads (New World)"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/sea)
	mission_start_message = "<big>Human population is expanding fast, and this continent feels small to you - Maybe there is more land to the West? What dangers will it hold? It's up to you to find out, if you dare...</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/gamemodes/Civilizations_and_Nomads</b>"
	research_active = TRUE

/obj/map_metadata/nomads/new_world/faction2_can_cross_blocks()
	return (ordinal_age >= 2)

/obj/map_metadata/nomads/new_world/faction1_can_cross_blocks()
	return (ordinal_age >= 2)

/obj/map_metadata/nomads/new_world/cross_message(faction)
	if (faction == CIVILIAN)
		return "<big><b>As the world technological level advances, new shipbuilding techniques make us at last be able to navigate the oceans...</b></big>"


