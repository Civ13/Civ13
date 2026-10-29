// Preserve the existing fixed item yields and preparation times.
/proc/cutting_board_recipe(path)
	if (path == /obj/item/weapon/reagent_containers/food/snacks/fishfillet || path == /obj/item/weapon/reagent_containers/food/snacks/rawcutlet)
		return list("output" = /obj/item/weapon/reagent_containers/food/snacks/mince, "count" = 1, "delay" = 180, "state" = "cutting_board_cutlet")
	if (path == /obj/item/weapon/reagent_containers/food/snacks/meat || path == /obj/item/weapon/reagent_containers/food/snacks/rawfish)
		return list("output" = /obj/item/weapon/reagent_containers/food/snacks/mince, "count" = 2, "delay" = 180, "state" = "cutting_board_steak")
	if (path == /obj/item/weapon/reagent_containers/food/snacks/mince)
		return list("output" = /obj/item/weapon/reagent_containers/food/snacks/meatball, "count" = 1, "delay" = 10, "state" = "cutting_board_mince")
	if (path == /obj/item/weapon/reagent_containers/food/snacks/meatball)
		return list("output" = /obj/item/weapon/reagent_containers/food/snacks/patty, "count" = 1, "delay" = 0, "state" = "cutting_board_meatball")
	if (path == /obj/item/weapon/reagent_containers/food/snacks/driedmeat)
		return list("output" = /obj/item/weapon/reagent_containers/food/snacks/driedmeat/minced_driedmeat, "count" = 1, "delay" = 180, "state" = "cutting_board_driedmeat")
	return null

// Exact types only: subtype-specific state cannot be inferred from a type name.
/proc/cutting_board_food_is_safe(obj/item/weapon/reagent_containers/food/snacks/food)
	return istype(food) && !QDELETED(food) && cutting_board_recipe(food.type) && !food.rotten && food.decay > 0 && food.decaytimer < food.decay && (!food.rots || food.decaytimer < food.decay / 2) && food.reagents && food.reagents.total_volume <= 50 && !food.contents.len

/proc/cutting_board_transfer_food(obj/item/weapon/reagent_containers/food/snacks/food, obj/item/weapon/reagent_containers/food/snacks/output, remaining)
	output.reagents.clear_reagents()
	food.reagents.trans_to_holder(output.reagents, food.reagents.total_volume / remaining)
	if (food.salted_meat)
		output.mark_salted_meat()
	output.decaytimer = food.decaytimer * output.decay / food.decay
	output.raw = food.raw
	output.roasted = food.roasted
	output.boiled = food.boiled
	output.disgusting = food.disgusting
	output.satisfaction = min(output.satisfaction, food.satisfaction)
	if (output.rots && output.decaytimer >= output.decay / 2)
		output.rot()

/obj/structure/cutting_board
	name = "cutting board"
	desc = "A wood board used to prepare food."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "cutting_board"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	// Retain the paid food itself: normal decay, reagents and save contents apply.
	var/input = null

/obj/structure/cutting_board/proc/normalize_input()
	var/obj/item/weapon/reagent_containers/food/snacks/food = input
	if (istype(food) && QDELETED(food))
		input = null
	if (!input && icon_state != "cutting_board")
		icon_state = "cutting_board_dirty"

/obj/structure/cutting_board/before_save()
	normalize_input()
	return ..()

/obj/structure/cutting_board/proc/actor_ready(mob/living/user, turf/site, datum/save_epoch)
	return !QDELETED(src) && !QDELETED(user) && istype(user, /mob/living) && site && isturf(user.loc) && loc == site && user.z == site.z && get_dist(user, site) <= 1 && !user.incapacitated() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && save_epoch == persistence_admission_identity

/obj/structure/cutting_board/proc/wait_for_preparation(mob/living/user, delay)
	return do_after(user, delay, src)

/obj/structure/cutting_board/attack_hand(mob/living/human/user)
	var/turf/site = get_turf(src)
	var/datum/save_epoch = persistence_admission_identity
	if (!actor_ready(user, site, save_epoch))
		return
	normalize_input()
	var/paid_input = input
	var/obj/item/weapon/reagent_containers/food/snacks/paid_food = paid_input
	if (istype(paid_food) && paid_food.loc != src)
		return
	var/old_icon = icon_state
	if (!paid_input && old_icon != "cutting_board_dirty")
		return
	to_chat(user, "You begin scraping the cutting board.")
	if (!wait_for_preparation(user, paid_input ? 20 : 15))
		return
	if (!actor_ready(user, site, save_epoch) || input != paid_input || icon_state != old_icon)
		return
	if (istype(paid_food) && paid_food.loc != src)
		return
	input = null
	if (istype(paid_food))
		qdel(paid_food)
	icon_state = paid_input ? "cutting_board_dirty" : "cutting_board"
	to_chat(user, "You scrape the cutting board clean.")

/obj/structure/cutting_board/attackby(obj/item/weapon/W as obj, mob/living/user as mob)
	if (!istype(W, /obj/item/weapon/material/kitchen/utensil/knife) && !istype(W, /obj/item/weapon/reagent_containers/food/snacks))
		return ..()
	var/turf/site = get_turf(src)
	var/datum/save_epoch = persistence_admission_identity
	if (!actor_ready(user, site, save_epoch) || QDELETED(W) || W.loc != user || !user.item_is_in_hands(W))
		return
	normalize_input()
	if (istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
		var/obj/item/weapon/reagent_containers/food/snacks/paid_input = input
		if (!cutting_board_food_is_safe(paid_input) || paid_input.loc != src)
			to_chat(user, "You need fresh supported food on the cutting board first.")
			return
		var/paid_type = paid_input.type
		var/list/recipe = cutting_board_recipe(paid_type)
		if (!recipe)
			return
		to_chat(user, "You begin preparing the food.")
		playsound(loc, 'sound/effects/chop.ogg', 60, TRUE)
		if (recipe["delay"] && !wait_for_preparation(user, recipe["delay"]))
			return
		if (!actor_ready(user, site, save_epoch) || input != paid_input || !cutting_board_food_is_safe(paid_input) || paid_input.type != paid_type || paid_input.loc != src || QDELETED(W) || W.loc != user || !user.item_is_in_hands(W))
			return
		// Claim the paid slot before constructors can reenter the board.
		input = null
		paid_input.forceMove(null)
		icon_state = "cutting_board_dirty"
		var/output_type = recipe["output"]
		for (var/i = 1, i <= recipe["count"], i++)
			var/obj/item/weapon/reagent_containers/food/snacks/output = new output_type(site)
			cutting_board_transfer_food(paid_input, output, recipe["count"] - i + 1)
		qdel(paid_input)
		return
	if (input || !user.canUnEquip(W))
		return
	var/list/recipe = cutting_board_recipe(W.type)
	if (!recipe || !cutting_board_food_is_safe(W))
		to_chat(user, "You cannot put that on the cutting board.")
		return
	user.remove_from_mob(W)
	if (!actor_ready(user, site, save_epoch) || input || QDELETED(W) || W.loc != user.loc || !cutting_board_food_is_safe(W))
		return
	W.forceMove(src)
	input = W
	icon_state = istype(W, /obj/item/weapon/reagent_containers/food/snacks/rawfish) ? "cutting_board_fish" : recipe["state"]
