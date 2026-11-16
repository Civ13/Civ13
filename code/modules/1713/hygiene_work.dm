// Dirt from work and dirty hands (docs/hygiene.md).
//
// Cleanliness falls slowly on its own (HYGIENE_FACTOR) and in steps when work
// finishes: a mined rock or a farming task 1, butchering 3, relieving
// yourself 5. Heat adds sweat.
//
// Dirty hands are a separate, saved mark set only by what really carries
// germs: waste (relieving yourself, picking up dung) and butchering. Gloves
// keep the hands clean. Any hand wash clears it: a sink, tap, bath, or a bare
// hand on fresh water with help intent. With dirty hands the first bite of
// each piece of food rolls once for food poisoning, and hands that touched
// waste roll for cholera or worms as well.

// Chance (%) the first bite with grimy hands gives food poisoning.
#define DIRTY_HANDS_POISON_CHANCE 5
// Chance (%) the first bite with waste on the hands gives cholera (worms at
// a share of it, as with dirty water).
#define DIRTY_HANDS_CHOLERA_CHANCE 4
// Hygiene lost per second of sweat in heat, on top of HYGIENE_FACTOR.
#define HYGIENE_SWEAT 0.01
#define HYGIENE_SWEAT_HEAT 27

/mob/living/human/var/dirty_hands = 0
/obj/item/weapon/reagent_containers/food/snacks/var/tmp/hands_rolled = FALSE

// Dirt from a finished task, and optionally dirty hands.
/mob/living/human/proc/soil(amount, hands = 0)
	if (amount > 0)
		adjust_hygiene(-amount)
	if (hands > dirty_hands && !gloves)
		dirty_hands = hands

/mob/living/human/proc/wash_hands()
	dirty_hands = 0

// Every hand wash in the game cleans the blood off: sinks, taps, baths.
/mob/living/human/clean_blood()
	. = ..()
	wash_hands()

/mob/living/human/proc/hygiene_sweat()
	if (stat == DEAD || inducedSSD)
		return
	var/turf/T = get_turf(src)
	if (T && get_temp(T) >= HYGIENE_SWEAT_HEAT)
		adjust_hygiene(-HYGIENE_SWEAT)

// ---- where dirt comes from --------------------------------------------------

/mob/living/human/adaptStat(statname, multiplier = 1, variety_key = null)
	. = ..()
	if (statname == "farming")
		soil(1)

/turf/mining_gem_pocket(mob/living/human/H)
	if (istype(H))
		H.soil(1)
	return ..()

/mob/living/human/handle_shit()
	var/before = bowels
	. = ..()
	if (bowels < before)
		soil(5, DIRTY_HANDS_WASTE)

/obj/item/weapon/reagent_containers/food/snacks/poo/pickup(mob/user)
	. = ..()
	var/mob/living/human/H = user
	if (istype(H) && !istype(src, /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer))
		H.soil(0, DIRTY_HANDS_WASTE)

// ---- washing hands at open water --------------------------------------------

/turf/floor/beach/water/attack_hand(mob/living/human/H)
	if (!ishuman(H) || H.a_intent != I_HELP || salty || !Adjacent(H) || istype(src, /turf/floor/beach/water/ice))
		return ..()
	to_chat(H, SPAN_NOTICE("You start washing your hands in \the [src]."))
	if (!do_after(H, 20, src))
		return
	H.clean_blood()
	H.update_inv_gloves()
	playsound(H.loc, 'sound/effects/watersplash.ogg', 30, TRUE)
	H.visible_message(SPAN_NOTICE("[H] washes their hands in \the [src]."), SPAN_NOTICE("You wash your hands."))

// ---- eating with dirty hands ------------------------------------------------

/obj/item/weapon/reagent_containers/food/snacks/On_Consume(mob/M)
	var/mob/living/human/H = M
	if (ishuman(H) && H.dirty_hands && !hands_rolled)
		hands_rolled = TRUE
		H.dirty_hands_bite(src)
	return ..()

/mob/living/human/proc/dirty_hands_bite(atom/food)
	if (dirty_hands >= DIRTY_HANDS_WASTE && catch_dirty_water_illness(DIRTY_HANDS_CHOLERA_CHANCE))
		return
	if (prob(DIRTY_HANDS_POISON_CHANCE * infection_chance_scale("food_poisoning")))
		reagents.add_reagent("food_poisoning", 1)
		log_food_toxin(src, food, list("food_poisoning" = 1), "first bite with dirty hands ([DIRTY_HANDS_POISON_CHANCE]% roll)", "dirty-hands roll")

// ---- what others see --------------------------------------------------------

/mob/living/human/examine(mob/user)
	. = ..()
	if (!dirty_hands || gloves || !user || get_dist(user, src) > 2)
		return
	if (user == src)
		to_chat(user, SPAN_WARNING("Your hands are filthy. Wash them before you eat."))
	else
		to_chat(user, SPAN_WARNING("[src]'s hands are filthy."))

#undef DIRTY_HANDS_POISON_CHANCE
#undef DIRTY_HANDS_CHOLERA_CHANCE
#undef HYGIENE_SWEAT
#undef HYGIENE_SWEAT_HEAT
