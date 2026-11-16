// Poison bait and flea-ridden nests (docs/mouse-nests.md).
//
// Poison bait is grain mixed with a poison players can actually get: a green
// potato (solanine), poisonous frog meat (cyanide), or 5u of arsenic, cyanide
// or solanine poured from a container. Put on the floor within 5 tiles of a
// nest, each dose kills up to MOUSE_BAIT_KILLS mice in a settle step; after
// MOUSE_BAIT_DOSES steps it is used up. It is real poison: a person who eats
// it is poisoned too.
//
// In the plague eras (2-3) a house nest kept overrun for MOUSE_FLEA_STEPS steps
// becomes flea-ridden. Sleeping or lying within 3 tiles of it, or digging it
// out without gloves, risks plague; immune traits apply. Thinning the nest
// below MOUSE_FLEA_CLEAR mice gets rid of the fleas. Maps can switch fleas off
// with mouse_fleas.

#define MOUSE_BAIT_KILLS 3
#define MOUSE_BAIT_DOSES 3
#define MOUSE_FLEA_STEPS 6
#define MOUSE_FLEA_CLEAR 5
#define MOUSE_FLEA_RANGE 3
#define MOUSE_FLEA_SLEEP_CHANCE 10
#define MOUSE_FLEA_DIG_CHANCE 25

var/global/list/mouse_bait_poisons = list("arsenic", "cyanide", "solanine")

/obj/map_metadata
	var/mouse_fleas = TRUE // flea-ridden nests can spread plague in eras 2-3

/obj/item/weapon/reagent_containers/food/snacks/mouse_poison_bait
	name = "poison bait"
	desc = "Grain mixed with poison on a potsherd. Put it on the floor where mice run. Do not eat it."
	icon = 'icons/obj/mouse_nests.dmi'
	icon_state = "poison_bait"
	food_toxin_origin = "mouse poison bait"
	bitesize = 2
	satisfaction = -10
	decay = 0
	var/doses = MOUSE_BAIT_DOSES

/obj/item/weapon/reagent_containers/food/snacks/mouse_poison_bait/examine(mob/user, distance = -1)
	..()
	to_chat(user, SPAN_NOTICE("It has [doses] dose\s left."))

/proc/mouse_bait_grain(obj/item/I)
	return istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/oat) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/barley) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/rice)

// Grain plus a poison makes bait.
/proc/mouse_bait_poison_source(obj/item/W)
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/greenpotato) || istype(W, /obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog))
		return TRUE
	if (istype(W, /obj/item/weapon/reagent_containers/glass) && W.reagents)
		for (var/id in mouse_bait_poisons)
			if (W.reagents.get_reagent_amount(id) >= 5)
				return TRUE
	return FALSE

/proc/mouse_make_bait(obj/item/weapon/reagent_containers/food/snacks/grain, obj/item/W, mob/user)
	var/obj/item/weapon/reagent_containers/food/snacks/mouse_poison_bait/B = new(get_turf(user))
	if (istype(W, /obj/item/weapon/reagent_containers/glass))
		for (var/id in mouse_bait_poisons)
			if (W.reagents.get_reagent_amount(id) >= 5)
				W.reagents.trans_id_to(B, id, 5)
				break
	else
		if (W.reagents)
			W.reagents.trans_to_obj(B, min(10, W.reagents.total_volume))
		user.drop_from_inventory(W)
		qdel(W)
	user.drop_from_inventory(grain)
	qdel(grain)
	user.put_in_hands(B)
	B.note_food_toxin("mouse poison bait")
	user.visible_message(SPAN_NOTICE("[user] mixes poison into some grain."), SPAN_NOTICE("You mix the poison into the grain and make poison bait. Put it on the floor near the mice, and keep it away from people and pets."))
	return B

/obj/item/weapon/reagent_containers/food/snacks/grown/attackby(obj/item/W, mob/user)
	if (mouse_bait_grain(src) && mouse_bait_poison_source(W))
		mouse_make_bait(src, W, user)
		return TRUE
	return ..()

// Each bait near the nest kills up to MOUSE_BAIT_KILLS mice and uses a dose.
/obj/structure/mouse_nest/proc/take_bait(list/baits)
	. = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/mouse_poison_bait/B in baits)
		if (population <= 0)
			break
		if (QDELETED(B) || !isturf(B.loc))
			continue
		var/killed = min(population, MOUSE_BAIT_KILLS)
		population -= killed
		. += killed
		B.doses--
		if (B.doses <= 0)
			qdel(B)

// ---------------------------------------------------------------- fleas
/proc/mouse_fleas_possible()
	return (!map || map.mouse_fleas) && era_between(2, 3)

/obj/structure/mouse_nest/proc/flea_step()
	if (!commensal || !mouse_fleas_possible())
		overrun_steps = 0
		fleas = FALSE
		return
	if (population >= MOUSE_HOUSE_MAX)
		overrun_steps++
		if (overrun_steps >= MOUSE_FLEA_STEPS)
			fleas = TRUE
	else
		overrun_steps = 0
		if (population < MOUSE_FLEA_CLEAR)
			fleas = FALSE

/proc/mouse_flea_infect(mob/living/human/H, chance)
	if (!istype(H) || H.stat == DEAD)
		return FALSE
	var/dmod = 1
	if (H.find_trait("Weak Immune System"))
		dmod = 2
	if (H.find_trait("Strong Immune System"))
		dmod = 0.2
	if (prob(chance * dmod))
		H.disease = TRUE
		H.disease_type = "plague"
		return TRUE
	return FALSE

// Fleas jump to anyone sleeping or lying close to a flea-ridden nest.
/obj/structure/mouse_nest/proc/flea_bites()
	if (!fleas || !mouse_fleas_possible())
		return 0
	. = 0
	for (var/mob/living/human/H in range(MOUSE_FLEA_RANGE, src))
		if (H.sleeping || H.lying)
			if (mouse_flea_infect(H, MOUSE_FLEA_SLEEP_CHANCE))
				.++

// Digging out a flea-ridden nest bare-handed.
/proc/mouse_flea_dig(mob/living/human/H)
	return mouse_flea_infect(H, MOUSE_FLEA_DIG_CHANCE)
