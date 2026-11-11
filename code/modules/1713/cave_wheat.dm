// Cave wheat: a grain that grows without sunlight (docs/balanced-diet.md).
// It gives cave and indoor farms a year-round carbohydrate. Unlike mushrooms it
// still needs water, so a cave farm needs a well, channel or watering.
// Art adapted from Pocket Stronghold 13; see icons/farming/ATTRIBUTION.md.

/obj/item/stack/farming/seeds/cave_wheat
	name = "cave wheat seeds"
	desc = "Seeds of a pale grain that grows without sunlight. Sow them in a ploughed plot indoors or underground, and keep it watered."
	plant = "cave_wheat"
	icon = 'icons/farming/pocket_stronghold_cave_wheat.dmi'
	icon_state = "cave_wheat-seeds"

/obj/item/stack/farming/seeds/cave_wheat/planting_error(turf/T)
	return cave_wheat_plot_error(T)

/proc/cave_wheat_plot_error(turf/T)
	if (!istype(T, /turf/floor/dirt/ploughed) || !T.is_plowed || T.density)
		return "Cave wheat needs a ploughed plot."
	var/area/A = get_area(T)
	if (!A || A.location == AREA_OUTSIDE)
		return "Cave wheat withers in sunlight. Plant it indoors or underground."
	return null

/obj/structure/farming/plant/cave_wheat
	name = "cave wheat"
	desc = "A pale grain that grows without sunlight. It still needs water."
	plant = "cave_wheat"
	icon = 'icons/farming/pocket_stronghold_cave_wheat.dmi'
	icon_state = "cave_wheat-grow1"
	// Every climate and season: darkness, not the weather, is what it needs.
	biomes = list("tundra", "taiga", "temperate", "sea", "semiarid", "desert", "jungle", "savanna")
	seasons = list("WINTER", "SUMMER", "SPRING", "FALL", "Wet Season", "Dry Season")
	max_water = 50

/obj/structure/farming/plant/cave_wheat/growth()
	..()
	name = replacetext(name, "_", " ")
	desc = replacetext(desc, "_", " ")

/obj/structure/farming/plant/cave_wheat/stageGrowth()
	// Half the speed of surface wheat pays for growing all year. A plot that
	// has lost its roof stops developing, but a ripe crop still ages.
	if (stage < readyStageMin && cave_wheat_plot_error(get_turf(src)))
		return
	if (prob(50))
		return ..()

/obj/structure/farming/plant/cave_wheat/examine(mob/user)
	..(user)
	to_chat(user, SPAN_NOTICE("Cave wheat grows slowly in any season, indoors or underground, but it needs water like any grain. Harvest it with a knife or scythe and mill it into flour."))

// A wheat subtype, so mills, animal feed and wheat recipes accept it.
/obj/item/weapon/reagent_containers/food/snacks/grown/cave_wheat
	parent_type = /obj/item/weapon/reagent_containers/food/snacks/grown/wheat
	name = "cave wheat"
	desc = "Pale grain grown without sunlight. Can be milled."
	icon = 'icons/farming/pocket_stronghold_cave_wheat.dmi'
	icon_state = "cave_wheat"
