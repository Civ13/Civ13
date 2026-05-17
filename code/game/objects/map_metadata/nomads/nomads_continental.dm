
/obj/map_metadata/nomads/continental
	ID = MAP_NOMADS_CONTINENTAL
	title = "Nomads (Continents)"
	description = "Battle on the Nomads (Continents) map."
	research_active = TRUE

/obj/map_metadata/nomads/continental/New()
	..()
	spawn(2500)
		for (var/i = 1, i <= 65, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/sea/sea))
			new/obj/structure/fish(areaspawn)
	spawn(2500)
		for (var/i = 1, i <= 30, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/nomads/forest/Jungle/river))
			new/obj/structure/piranha(areaspawn)
	spawn(18000)
		seasons()

/obj/map_metadata/nomads/continental/faction2_can_cross_blocks()
	return (ordinal_age >= 2)

/obj/map_metadata/nomads/continental/faction1_can_cross_blocks()
	return (ordinal_age >= 2)

/obj/map_metadata/nomads/continental/cross_message(faction)
	if (faction == CIVILIAN)
		return "<big><b>As the world technological level advances, new shipbuilding techniques make us at last be able to navigate the oceans...</b></big>"