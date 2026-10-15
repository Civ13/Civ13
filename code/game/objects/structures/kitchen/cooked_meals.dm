// Original Civ13 recipes; PS13's shared meal mood event inspired the bounded tiers.
/obj/structure/pot
	var/meal_portions = 0
	var/meal_quality = 0
	var/meal_has_meat = FALSE
	var/tmp/meal_cooking = FALSE

/obj/structure/pot/persistence_runtime_var(key)
	return key == "meal_cooking" || ..()

/obj/structure/pot/proc/meal_heat()
	if (!get_turf(src))
		return FALSE
	for (var/obj/structure/oven/O in range(1, src))
		if (O.on)
			return TRUE
	return FALSE

// Only substantial, intact ingredients count. Duplicate vegetables add food,
// but never a second variety. No arbitrary chemical mixture earns meal quality.
/obj/structure/pot/proc/meal_recipe()
	var/starch = FALSE
	var/protein = FALSE
	var/list/vegetables = list()
	var/volume = reagents.total_volume
	var/nutrition = 0
	if (!contents.len || contents.len > 15)
		return 0
	for (var/obj/item/I in contents)
		if (!istype(I, /obj/item/weapon/reagent_containers/food/snacks))
			return 0
		var/obj/item/weapon/reagent_containers/food/snacks/F = I
		if (F.rotten || !F.reagents)
			return 0
		var/food = F.reagents.get_reagent_amount("nutriment") + F.reagents.get_reagent_amount("protein")
		if (food < 1)
			return 0
		volume += F.reagents.total_volume
		nutrition += food
		if (istype(F, /obj/item/weapon/reagent_containers/food/snacks/grown/potato) || istype(F, /obj/item/weapon/reagent_containers/food/snacks/grown/corn))
			starch = TRUE
		else if (istype(F, /obj/item/weapon/reagent_containers/food/snacks/meat) || istype(F, /obj/item/weapon/reagent_containers/food/snacks/grown/beans))
			protein = TRUE
		else if (istype(F, /obj/item/weapon/reagent_containers/food/snacks/grown/carrot))
			vegetables |= "carrot"
		else if (istype(F, /obj/item/weapon/reagent_containers/food/snacks/grown/cabbage))
			vegetables |= "cabbage"
		else if (istype(F, /obj/item/weapon/reagent_containers/food/snacks/grown/tomato))
			vegetables |= "tomato"
		else
			return 0
	if (!starch || !vegetables.len || nutrition < 4 || volume > reagents.maximum_volume)
		return 0
	if (protein && vegetables.len >= 2 && reagents.get_reagent_amount("sodiumchloride") >= 0.5)
		return 3
	return protein ? 2 : 1

/obj/structure/pot/proc/meal_ready(mob/living/human/H)
	return H && H.stat == CONSCIOUS && H.loc && get_turf(src) && H.z == z && get_dist(H, src) <= 1 && fullness == 100 && (state == STATE_WATER || state == STATE_BOILING) && !meal_portions && meal_heat() && meal_recipe()

/mob/living/human/proc/meal_cooking_wait(obj/structure/pot/P)
	return do_after(src, 10, P)

/obj/structure/pot/verb/prepare_meal()
	set src in oview(1)
	set name = "Prepare meal"
	set category = null
	cook_meal(usr)

/obj/structure/pot/proc/cook_meal(mob/living/human/H)
	if (meal_cooking || !meal_ready(H))
		to_chat(H, "Fill the pot with water, add potato or corn and carrot, cabbage or tomato, and light a fire beside it. Ingredients must fit, be substantial and not rotten.")
		return FALSE
	meal_cooking = TRUE
	var/list/ingredients = contents.Copy()
	for (var/i in 1 to 6)
		if (!H.meal_cooking_wait(src) || !meal_ready(H) || contents.len != ingredients.len)
			meal_cooking = FALSE
			return FALSE
		for (var/obj/item/I in ingredients)
			if (I.loc != src)
				meal_cooking = FALSE
				return FALSE
	meal_quality = meal_recipe()
	meal_has_meat = FALSE
	for (var/obj/item/weapon/reagent_containers/food/snacks/F in ingredients)
		meal_has_meat = meal_has_meat || F.non_vegetarian
		F.reagents.trans_to_holder(reagents, F.reagents.total_volume)
		qdel(F)
	// Boiling removes these two biological hazards, not arbitrary poisons.
	reagents.del_reagent("food_poisoning")
	reagents.del_reagent("cholera")
	meal_portions = 3
	state = STATE_STEWING
	fullness = 0 // Cooking water is spent; no nutrition or hydration is created.
	meal_cooking = FALSE
	update_icon()
	visible_message("[H] finishes preparing three portions of [meal_quality == 3 ? "seasoned hearty stew" : (meal_quality == 2 ? "hearty stew" : "vegetable potage")].")
	return TRUE

/obj/structure/pot/proc/serve_meal(obj/item/I, mob/living/human/H)
	if (!meal_portions || meal_cooking || !H || H.stat != CONSCIOUS || H.z != z || get_dist(H, src) > 1 || !get_turf(src))
		return FALSE
	if (!(istype(I, /obj/item/kitchen/wood_bowl) || istype(I, /obj/item/kitchen/snack_bowl)) || (H.l_hand != I && H.r_hand != I))
		to_chat(H, "Hold an empty bowl to serve the meal.")
		return FALSE
	var/slot = H.l_hand == I ? slot_l_hand : slot_r_hand
	var/obj/item/weapon/reagent_containers/food/snacks/prepared_meal/M = new(get_turf(src))
	M.meal_quality = meal_quality
	M.non_vegetarian = meal_has_meat
	M.name = meal_quality == 3 ? "seasoned hearty stew" : (meal_quality == 2 ? "hearty stew" : "vegetable potage")
	M.trash = I.type
	if (istype(I, /obj/item/kitchen/snack_bowl))
		M.icon_state = "stew"
	// Divide the remaining pool, then debit it. The final bowl gets the remainder.
	reagents.trans_to_holder(M.reagents, reagents.total_volume / meal_portions)
	H.remove_from_mob(I)
	qdel(I)
	H.equip_to_slot(M, slot)
	meal_portions--
	if (!meal_portions)
		state = STATE_EMPTY
		meal_quality = 0
		meal_has_meat = FALSE
		stew_ticks = 0
	update_icon()
	return TRUE

/obj/item/weapon/reagent_containers/food/snacks/prepared_meal
	name = "prepared meal"
	desc = "A properly cooked meal. Eat four units of food to enjoy its bounded mood benefit."
	icon_state = "stew_wood"
	trash = /obj/item/kitchen/wood_bowl
	nutriment_amt = 0
	volume = 100
	satisfaction = 0
	bitesize = 3
	var/meal_quality = 0

/obj/item/weapon/reagent_containers/food/snacks/prepared_meal/examine(mob/user)
	..()
	to_chat(user, "Meal quality: [meal_quality]/3. A substantial helping can lift mood to [50 + 5 * clamp(meal_quality, 0, 3)]; repeated bites do not stack above that level.")

/mob/living/human
	var/meal_food_credit = 0
	var/meal_credit_quality = 0

// Durable bounded progress, no action references, timers or hunger multipliers.
/mob/living/human/proc/credit_prepared_meal(quality, food)
	quality = clamp(round(quality), 0, 3)
	if (!quality || food <= 0)
		return
	if (meal_credit_quality != quality)
		meal_food_credit = 0
	meal_credit_quality = quality
	meal_food_credit = clamp(meal_food_credit, 0, 4) + min(food, 100)
	if (meal_food_credit >= 4)
		meal_food_credit = 0
		var/floor_mood = 50 + 5 * quality
		if (mood < floor_mood)
			mood = floor_mood
			to_chat(src, "The properly prepared meal lifts your spirits.")

/obj/item/weapon/reagent_containers/food/snacks/proc/take_food_bite(mob/living/human/H, amount)
	var/before = reagents.get_reagent_amount("nutriment") + reagents.get_reagent_amount("protein")
	reagents.trans_to_mob(H, amount, CHEM_INGEST)
	if (istype(src, /obj/item/weapon/reagent_containers/food/snacks/prepared_meal))
		var/obj/item/weapon/reagent_containers/food/snacks/prepared_meal/M = src
		if (!rotten)
			H.credit_prepared_meal(M.meal_quality, max(0, before - reagents.get_reagent_amount("nutriment") - reagents.get_reagent_amount("protein")))
