// Hay: grass cuttings spread on open ground dry into hay in dry weather.
// Hay feeds grazing animals, ties into bales for fodder storage and bundles
// into thatch roofing.

#define HAY_DRY_STEPS 6 // six dry 30-second checks: three minutes of dry weather
#define HAY_DRY_STEP_TIME 300
#define HAY_SPREAD_MAX 20
#define HAY_BALE_SIZE 10
#define HAY_FEED_HUNGER 550
#define HAY_THATCH_COST 2

/obj/item/stack/hay
	name = "hay"
	desc = "Dried grass. Feed it to grazing animals, or use it in hand to tie a hay bale or bundle thatch roofing."
	icon = 'icons/obj/hay.dmi'
	icon_state = "hay"
	singular_name = "hay bundle"
	max_amount = 20
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/hay/proc/hay_worker_valid(mob/user)
	return !QDELETED(src) && !QDELETED(user) && loc == user && user.stat == CONSCIOUS && !user.incapacitated()

/obj/item/stack/hay/attack_self(mob/user)
	if (!hay_worker_valid(user))
		return
	var/bale_choice = "Tie a hay bale ([HAY_BALE_SIZE] hay)"
	var/thatch_choice = "Bundle thatch roofing ([HAY_THATCH_COST] hay)"
	var/choice = WWinput(user, "What do you want to make from the hay?", "Hay", "Cancel", list(bale_choice, thatch_choice, "Cancel"))
	if (!hay_worker_valid(user))
		return
	if (choice == bale_choice)
		tie_hay_bale(user)
	else if (choice == thatch_choice)
		bundle_thatch(user)

/obj/item/stack/hay/proc/tie_hay_bale(mob/user)
	if (amount < HAY_BALE_SIZE)
		to_chat(user, SPAN_WARNING("You need [HAY_BALE_SIZE] hay to tie a bale."))
		return FALSE
	var/turf/T = get_step(user, user.dir)
	if (!hay_bale_site_clear(T))
		T = get_turf(user)
		if (!hay_bale_site_clear(T, user))
			to_chat(user, SPAN_WARNING("There is no room for a hay bale here."))
			return FALSE
	if (!use(HAY_BALE_SIZE))
		return FALSE
	new /obj/structure/hay_bale(T)
	user.visible_message(SPAN_NOTICE("[user] ties a bale of hay."), SPAN_NOTICE("You tie a bale of hay."))
	return TRUE

/proc/hay_bale_site_clear(turf/T, mob/ignored = null)
	if (!istype(T, /turf/floor) || T.density)
		return FALSE
	for (var/atom/movable/AM in T)
		if (AM != ignored && AM.density)
			return FALSE
	return TRUE

/obj/item/stack/hay/proc/bundle_thatch(mob/user)
	if (!crafting_recipe_allowed(user, "/obj/item/weapon/roofbuilder/leaves"))
		to_chat(user, SPAN_WARNING("You don't know how to make thatch roofing yet."))
		return FALSE
	if (amount < HAY_THATCH_COST)
		to_chat(user, SPAN_WARNING("You need [HAY_THATCH_COST] hay to bundle thatch roofing."))
		return FALSE
	if (!use(HAY_THATCH_COST))
		return FALSE
	var/obj/item/weapon/roofbuilder/leaves/roofing = new(get_turf(user))
	user.put_in_any_hand_if_possible(roofing)
	to_chat(user, SPAN_NOTICE("You bundle the hay into thatch roofing."))
	return TRUE

// Spreading cuttings: click open ground next to you with grass cuttings in hand.
/proc/hay_drying_site_problem(turf/T)
	if (!istype(T, /turf/floor) || T.density)
		return "There is no open ground there."
	if (istype(T, /turf/floor/beach/water))
		return "The grass would only soak there."
	for (var/atom/movable/AM in T)
		if (AM.density && !ismob(AM))
			return "Something is in the way."
	return null

/obj/item/stack/grass_cuttings/proc/spread_to_dry(mob/user, turf/T)
	if (QDELETED(src) || QDELETED(user) || loc != user || user.stat != CONSCIOUS || user.incapacitated() || !isturf(T) || get_dist(user, T) > 1 || amount < 1)
		return FALSE
	var/obj/structure/hay_drying/D = locate() in T
	if (D)
		return D.add_cuttings(src, user)
	var/problem = hay_drying_site_problem(T)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/count = min(amount, HAY_SPREAD_MAX)
	if (!use(count))
		return FALSE
	D = new(T)
	D.portions = count
	D.start_drying()
	to_chat(user, SPAN_NOTICE("You spread [count] grass cuttings on the ground to dry into hay."))
	return TRUE

/turf/floor/attackby(obj/item/C, mob/user)
	if (istype(C, /obj/item/stack/grass_cuttings) && user && C.loc == user)
		var/obj/item/stack/grass_cuttings/G = C
		G.spread_to_dry(user, src)
		return TRUE
	return ..()

/obj/structure/hay_drying
	name = "drying grass"
	desc = "Grass cuttings spread out to dry into hay. It dries in dry weather and stops while rain or snow falls on it. Pick it up by hand to take the cuttings back."
	icon = 'icons/obj/hay.dmi'
	icon_state = "drying_grass"
	density = FALSE
	anchored = TRUE
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/portions = 0
	var/dry_steps = 0
	var/tmp/drying_epoch = 0

/obj/structure/hay_drying/persistence_runtime_var(key)
	return key == "drying_epoch" || ..()

/obj/structure/hay_drying/update_icon()
	icon_state = dry_steps * 2 >= HAY_DRY_STEPS ? "drying_grass_half" : "drying_grass"

/obj/structure/hay_drying/proc/start_drying()
	drying_epoch++
	var/epoch = drying_epoch
	update_icon()
	addtimer(CALLBACK(src, PROC_REF(dry_step), epoch), HAY_DRY_STEP_TIME)
	return TRUE

// Open sky with rain or snow keeps the grass wet; a roof or the indoors does not.
/obj/structure/hay_drying/proc/rained_on()
	var/turf/T = loc
	if (!isturf(T))
		return FALSE
	var/area/A = get_area(T)
	if (!A || A.location != AREA_OUTSIDE || (locate(/obj/roof) in T))
		return FALSE
	return weather_intensity_at(T) > 0

/obj/structure/hay_drying/proc/dry_step(epoch)
	if (QDELETED(src) || epoch != drying_epoch || !isturf(loc) || portions < 1)
		return FALSE
	if (!rained_on())
		dry_steps++
	if (dry_steps >= HAY_DRY_STEPS)
		return finish_drying()
	update_icon()
	addtimer(CALLBACK(src, PROC_REF(dry_step), epoch), HAY_DRY_STEP_TIME)
	return TRUE

/obj/structure/hay_drying/proc/finish_drying()
	var/turf/T = loc
	var/count = portions
	drying_epoch++
	portions = 0
	if (!isturf(T) || count < 1)
		qdel(src)
		return FALSE
	new /obj/item/stack/hay(T, count)
	visible_message(SPAN_NOTICE("The grass has dried into hay."))
	qdel(src)
	return TRUE

/obj/structure/hay_drying/proc/add_cuttings(obj/item/stack/grass_cuttings/G, mob/user)
	if (QDELETED(src) || QDELETED(G) || G.loc != user || !user.Adjacent(src))
		return FALSE
	var/room = HAY_SPREAD_MAX - portions
	if (room < 1)
		to_chat(user, SPAN_WARNING("There is no room for more grass here."))
		return FALSE
	var/count = min(room, G.amount)
	if (!G.use(count))
		return FALSE
	portions += count
	// The fresh grass has to dry too.
	dry_steps = 0
	start_drying()
	to_chat(user, SPAN_NOTICE("You spread [count] more grass cuttings to dry."))
	return TRUE

/obj/structure/hay_drying/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/grass_cuttings))
		add_cuttings(W, user)
		return TRUE
	return ..()

/obj/structure/hay_drying/attack_hand(mob/living/user)
	if (QDELETED(src) || QDELETED(user) || user.stat != CONSCIOUS || user.incapacitated() || !user.Adjacent(src) || !isturf(loc))
		return
	var/count = portions
	drying_epoch++
	portions = 0
	if (count > 0)
		var/obj/item/stack/grass_cuttings/G = new(loc, count, FALSE)
		user.put_in_any_hand_if_possible(G)
		to_chat(user, SPAN_NOTICE("You gather up the grass cuttings."))
	qdel(src)

/obj/structure/hay_drying/after_load()
	..()
	if (portions > 0 && isturf(loc))
		start_drying()
	else
		qdel(src)

/obj/structure/hay_bale
	name = "hay bale"
	desc = "A tied bale of hay. Grazing animals next to it eat from it. Take hay off it by hand, or add hay to fill it."
	icon = 'icons/obj/hay.dmi'
	icon_state = "hay_bale"
	density = TRUE
	anchored = FALSE
	flammable = TRUE
	var/hay_left = HAY_BALE_SIZE

/obj/structure/hay_bale/update_icon()
	icon_state = hay_left * 2 > HAY_BALE_SIZE ? "hay_bale" : "hay_bale_half"

/obj/structure/hay_bale/examine(mob/user, distance = -1)
	..()
	to_chat(user, "It holds [hay_left] of [HAY_BALE_SIZE] hay.")

/obj/structure/hay_bale/proc/take_hay(count = 1)
	if (QDELETED(src) || count < 1 || hay_left < count)
		return FALSE
	hay_left -= count
	if (hay_left < 1)
		qdel(src)
	else
		update_icon()
	return TRUE

/obj/structure/hay_bale/attack_hand(mob/living/user)
	if (QDELETED(src) || QDELETED(user) || user.stat != CONSCIOUS || user.incapacitated() || !user.Adjacent(src) || !isturf(loc))
		return
	var/turf/T = loc
	if (!take_hay(1))
		return
	var/obj/item/stack/hay/H = new(T, 1, FALSE)
	user.put_in_any_hand_if_possible(H)
	to_chat(user, SPAN_NOTICE("You pull some hay off \the [src]."))

/obj/structure/hay_bale/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/hay))
		var/obj/item/stack/hay/H = W
		var/room = HAY_BALE_SIZE - hay_left
		if (room < 1)
			to_chat(user, SPAN_WARNING("\The [src] is full."))
			return TRUE
		var/count = min(room, H.amount)
		if (H.loc == user && H.use(count))
			hay_left += count
			update_icon()
			to_chat(user, SPAN_NOTICE("You stuff [count] hay into \the [src]."))
		return TRUE
	return ..()

/obj/structure/hay_bale/after_load()
	..()
	hay_left = clamp(round(hay_left), 0, HAY_BALE_SIZE)
	if (hay_left < 1)
		qdel(src)
		return
	update_icon()

// Grazing animals eat hay by hand, from the ground and from bales.
/mob/living/simple_animal/attackby(obj/item/O, mob/user)
	if (istype(O, /obj/item/stack/hay))
		feed_hay(O, user)
		return TRUE
	return ..()

/mob/living/simple_animal/proc/feed_hay(obj/item/stack/hay/H, mob/user)
	if (stat != CONSCIOUS || QDELETED(H) || H.loc != user)
		return FALSE
	if (!herbivore)
		to_chat(user, SPAN_WARNING("\The [src] sniffs \the [H] but won't eat it."))
		return FALSE
	if (simplehunger >= 800)
		to_chat(user, SPAN_RED("\The [src] is not hungry."))
		return FALSE
	if (!H.use(1))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] feeds [src] some hay."))
	finish_eating(HAY_FEED_HUNGER)
	return TRUE

/mob/living/simple_animal/proc/eat_nearby_hay()
	for (var/obj/structure/hay_bale/B in range(1, src))
		if (B.hay_left < 1)
			continue
		npc_subtile_stop_continuous_walk()
		visible_message("\The [src] eats some hay from \the [B].")
		B.take_hay(1)
		finish_eating(HAY_FEED_HUNGER)
		return TRUE
	for (var/obj/item/stack/hay/H in range(1, src))
		if (!isturf(H.loc) || H.amount < 1)
			continue
		npc_subtile_stop_continuous_walk()
		visible_message("\The [src] eats some of the hay.")
		H.use(1)
		finish_eating(HAY_FEED_HUNGER)
		return TRUE
	return FALSE

/mob/living/simple_animal/check_food()
	if (herbivore && prob(40) && eat_nearby_hay())
		return
	// With no grass to graze nearby, walk to a hay bale.
	if (herbivore && !(locate(/turf/floor/grass) in range(6, src)))
		for (var/obj/structure/hay_bale/B in range(6, src))
			if (get_dist(src, B) > 1)
				smart_step_towards(B)
				return
	return ..()

#undef HAY_DRY_STEPS
#undef HAY_DRY_STEP_TIME
#undef HAY_SPREAD_MAX
#undef HAY_BALE_SIZE
#undef HAY_FEED_HUNGER
#undef HAY_THATCH_COST
