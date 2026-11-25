// Pollination by bees.
//
// Fruit, beans, cotton and flax set more crop when bees work their flowers.
// Nothing ticks: when a ripe crop that needs insects is harvested, the game
// looks for a bee colony within reach and rolls for one extra crop, more
// likely the stronger the colony. Growth speed does not change. Grains,
// grapes and olives pollinate by wind or by themselves and get nothing.

#define POLLINATION_RANGE 5 // tiles a colony's foragers cover
#define POLLINATION_BASE_CHANCE 20 // percent for a weak colony
#define POLLINATION_STRENGTH_CHANCE 0.6 // extra percent per point of colony strength
#define WILD_NEST_POLLINATION_STRENGTH 50 // a wild nest's colony counts as middling

/obj/structure/farming/plant
	var/insect_pollinated = FALSE

/obj/structure/farming/plant/apple
	insect_pollinated = TRUE
/obj/structure/farming/plant/cherry
	insect_pollinated = TRUE
/obj/structure/farming/plant/apricot
	insect_pollinated = TRUE
/obj/structure/farming/plant/orange
	insect_pollinated = TRUE
/obj/structure/farming/plant/lime
	insect_pollinated = TRUE
/obj/structure/farming/plant/lemon
	insect_pollinated = TRUE
/obj/structure/farming/plant/watermelon
	insect_pollinated = TRUE
/obj/structure/farming/plant/pumpkin
	insect_pollinated = TRUE
/obj/structure/farming/plant/zucchini
	insect_pollinated = TRUE
/obj/structure/farming/plant/beans
	insect_pollinated = TRUE
/obj/structure/farming/plant/cotton
	insect_pollinated = TRUE
/obj/structure/farming/plant/tomato
	insect_pollinated = TRUE
/obj/structure/farming/plant/redpepper
	insect_pollinated = TRUE
/obj/structure/farming/plant/coffee
	insect_pollinated = TRUE
/obj/structure/farming/plant/cocoa
	insect_pollinated = TRUE
/obj/structure/farming/plant/flax
	insect_pollinated = TRUE

// Strength (0 to 100) of the strongest bee colony that forages over T.
/proc/bee_colony_strength_near(turf/T)
	. = 0
	if (!T)
		return
	for (var/obj/structure/S in range(POLLINATION_RANGE, T))
		if (istype(S, /obj/structure/kept_hive))
			var/obj/structure/kept_hive/K = S
			if (K.occupied)
				. = max(., K.strength)
		else if (istype(S, /obj/structure/wild_bee_nest))
			var/obj/structure/wild_bee_nest/N = S
			if (N.occupied)
				. = max(., WILD_NEST_POLLINATION_STRENGTH)
		else if (istype(S, /obj/structure/beehive))
			var/obj/structure/beehive/B = S
			if (B.bee_count)
				. = max(., B.bee_count)
		if (. >= 100)
			return 100

/proc/pollination_chance(strength)
	if (strength <= 0)
		return 0
	return min(POLLINATION_BASE_CHANCE + strength * POLLINATION_STRENGTH_CHANCE, 80)

// A ripe crop that a harvest tool removes was harvested (the base attackby
// in farming.dm, sickle reaping included). Roll for bees afterwards.
/obj/structure/farming/plant/attackby(obj/item/weapon/W as obj, mob/user as mob)
	var/was_ripe = insect_pollinated && !vstatic && readyHarvest()
	var/turf/T = get_turf(src)
	. = ..()
	if (was_ripe && QDELETED(src))
		pollination_harvest(user, T)

// Called once per harvested plant, after its normal produce.
/obj/structure/farming/plant/proc/pollination_harvest(mob/user, turf/T = null)
	if (!T)
		T = get_turf(src)
	if (!insect_pollinated || vstatic || !T)
		return FALSE
	if (!prob(pollination_chance(bee_colony_strength_near(T))))
		return FALSE
	spawn_pollinated_extra(T)
	if (user)
		to_chat(user, SPAN_NOTICE("Bees have worked these flowers well. There is extra crop."))
	return TRUE

/obj/structure/farming/plant/proc/spawn_pollinated_extra(turf/T = null)
	if (!T)
		T = get_turf(src)
	var/obj/item/I
	if (stack <> "product_name")
		var/stackpath = text2path("/obj/item/stack/[stack]")
		if (stackpath)
			return spawn_crop_stack(stackpath, T, max(stack_amount, 1))
		return null
	else
		var/fruitpath
		if (condiment <> "product_name")
			fruitpath = text2path("/obj/item/weapon/reagent_containers/food/condiment/[condiment]")
		else
			fruitpath = text2path("/obj/item/weapon/reagent_containers/food/snacks/grown/[plant]")
		if (fruitpath)
			I = new fruitpath(T)
	if (I && !QDELETED(I))
		I.radiation = radiation/2
	return I

// Shown to a farmer looking at a flowering crop.
/obj/structure/farming/plant/proc/pollination_diagnostic()
	if (!insect_pollinated || vstatic || stage > readyStageMax)
		return null
	if (bee_colony_strength_near(get_turf(src)) > 0)
		return "Bees are working its flowers, so it may give extra crop."
	return "It needs bees or other insects to set its best crop. A hive nearby would help."

/obj/structure/farming/plant/examine(mob/user)
	..(user)
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.getStatCoeff("farming") >= 1.3)
			var/bee_note = pollination_diagnostic()
			if (bee_note)
				to_chat(user, bee_note)

#undef POLLINATION_RANGE
#undef POLLINATION_BASE_CHANCE
#undef POLLINATION_STRENGTH_CHANCE
#undef WILD_NEST_POLLINATION_STRENGTH
