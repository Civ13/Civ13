// Preserve the existing fixed item yields and preparation times.
/proc/cutting_board_recipe(path)
	if (ispath(path, /obj/item/weapon/reagent_containers/food/snacks/fishfillet) || ispath(path, /obj/item/weapon/reagent_containers/food/snacks/rawcutlet))
		return list("output" = /obj/item/weapon/reagent_containers/food/snacks/mince, "count" = 1, "delay" = 180, "state" = "cutting_board_cutlet")
	if (ispath(path, /obj/item/weapon/reagent_containers/food/snacks/meat) || ispath(path, /obj/item/weapon/reagent_containers/food/snacks/rawfish))
		return list("output" = /obj/item/weapon/reagent_containers/food/snacks/mince, "count" = 2, "delay" = 180, "state" = "cutting_board_steak")
	if (ispath(path, /obj/item/weapon/reagent_containers/food/snacks/mince))
		return list("output" = /obj/item/weapon/reagent_containers/food/snacks/meatball, "count" = 1, "delay" = 10, "state" = "cutting_board_mince")
	if (ispath(path, /obj/item/weapon/reagent_containers/food/snacks/meatball))
		return list("output" = /obj/item/weapon/reagent_containers/food/snacks/patty, "count" = 1, "delay" = 0, "state" = "cutting_board_meatball")
	if (ispath(path, /obj/item/weapon/reagent_containers/food/snacks/driedmeat))
		return list("output" = /obj/item/weapon/reagent_containers/food/snacks/driedmeat/minced_driedmeat, "count" = 1, "delay" = 180, "state" = "cutting_board_driedmeat")
	return null

/obj/structure/cutting_board
	name = "cutting board"
	desc = "A wood board used to prepare food."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "cutting_board"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	// A distinct list per consumed item: durable type data, not a deleted object.
	var/input = null

/obj/structure/cutting_board/proc/normalize_input()
	var/obj/item/weapon/reagent_containers/food/snacks/legacy = input
	if (istype(legacy) && QDELETED(legacy) && cutting_board_recipe(legacy.type))
		input = list("type" = "[legacy.type]")

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
	var/old_icon = icon_state
	if (!paid_input && old_icon != "cutting_board_dirty")
		return
	to_chat(user, "You begin scraping the cutting board.")
	if (!wait_for_preparation(user, paid_input ? 20 : 15))
		return
	if (!actor_ready(user, site, save_epoch) || input != paid_input || icon_state != old_icon)
		return
	input = null
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
		if (!islist(input) || !istext(input["type"]))
			to_chat(user, "You need to put food on the cutting board first.")
			return
		var/list/paid_input = input
		var/paid_type = paid_input["type"]
		var/list/recipe = cutting_board_recipe(text2path(paid_type))
		if (!recipe)
			return
		to_chat(user, "You begin preparing the food.")
		playsound(loc, 'sound/effects/chop.ogg', 60, TRUE)
		if (recipe["delay"] && !wait_for_preparation(user, recipe["delay"]))
			return
		if (!actor_ready(user, site, save_epoch) || input != paid_input || paid_input["type"] != paid_type || QDELETED(W) || W.loc != user || !user.item_is_in_hands(W))
			return
		// Claim the paid slot before constructors can reenter the board.
		input = null
		icon_state = "cutting_board_dirty"
		var/output_type = recipe["output"]
		for (var/i = 1, i <= recipe["count"], i++)
			new output_type(site)
		return
	if (input || !user.canUnEquip(W))
		return
	var/list/recipe = cutting_board_recipe(W.type)
	if (!recipe)
		to_chat(user, "You cannot put that on the cutting board.")
		return
	// The offered object is consumed once, as before; keep only its paid type.
	input = list("type" = "[W.type]")
	icon_state = istype(W, /obj/item/weapon/reagent_containers/food/snacks/rawfish) ? "cutting_board_fish" : recipe["state"]
	qdel(W)
