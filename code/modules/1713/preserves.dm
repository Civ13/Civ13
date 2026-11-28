// Preserves: vinegar, pickles and jam.
//
// Crock: shaped from 3 clay and fired in a kiln. Put the lid on and it works
// every couple of minutes while it stays closed:
// - wine, cider, beer or mead sours into vinegar, 6 units at a time
// - up to 4 fruits or vegetables packed inside, with 5 vinegar and 2 salt for
//   each, become pickles after 3 working spells. Pickles never spoil.
// - cooked meat or fish packed inside, sealed with 5 butter or lard for each,
//   is potted after 3 working spells (butter.dm).
// Alt-click an open crock (or use its verb) to take food back out.
//
// Jam: 10 fruit juice with 5 sugar, 5 honey or 5 maple syrup sets into 10 jam. A preserve
// jar holds 20; spread 5 on a slice of bread to make jellied toast.

#define CROCK_WORK_TIME 1200
#define CROCK_SOUR_STEP 6
#define CROCK_MAX_FOOD 4
#define CROCK_PICKLE_STEPS 3
#define PICKLE_VINEGAR 5
#define PICKLE_SALT 2
#define JAM_PER_TOAST 5

/obj/item/weapon/clay/crock
	name = "unfired clay crock"
	desc = "A squat clay crock waiting for the kiln."
	icon = 'icons/obj/food/preserves.dmi'
	icon_state = "unfired_crock"
	result = /obj/item/weapon/reagent_containers/glass/crock

/obj/item/weapon/reagent_containers/glass/crock
	name = "clay crock"
	desc = "A glazed clay crock with a wooden lid. Closed up, it sours wine, cider, beer or mead into vinegar, and pickles food packed in vinegar and salt."
	icon = 'icons/obj/food/preserves.dmi'
	icon_state = "crock"
	item_state = null
	volume = 60
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(5,10,20,30,60)
	w_class = ITEM_SIZE_NORMAL
	dropsound = 'sound/effects/drop_default.ogg'
	flammable = FALSE
	value = 4
	var/pickle_progress = 0
	var/tmp/crock_timer

/obj/item/weapon/reagent_containers/glass/crock/persistence_runtime_var(key)
	return key == "crock_timer" || ..()

/obj/item/weapon/reagent_containers/glass/crock/after_load()
	..()
	update_icon()
	crock_schedule()

/obj/item/weapon/reagent_containers/glass/crock/on_reagent_change()
	..()
	update_icon()

/obj/item/weapon/reagent_containers/glass/crock/update_icon()
	overlays.Cut()
	if (!is_open_container())
		icon_state = "crock_closed"
		return
	icon_state = "crock"
	if (reagents && reagents.total_volume > 0)
		var/image/filling = image(icon, src, "crock_fill")
		filling.color = reagents.get_color()
		overlays += filling

/obj/item/weapon/reagent_containers/glass/crock/examine(mob/user, distance = -1)
	..()
	var/list/food = crock_food()
	if (food.len)
		to_chat(user, SPAN_NOTICE("Packed inside: [english_list(food)]."))
	if (is_open_container())
		to_chat(user, SPAN_NOTICE("Put the lid on to let it work."))
	else if (crock_has_work())
		to_chat(user, SPAN_NOTICE("It is quietly working away."))

/obj/item/weapon/reagent_containers/glass/crock/attack_self(mob/user)
	. = ..()
	if (is_open_container())
		crock_cancel()
	else
		crock_schedule()

/obj/item/weapon/reagent_containers/glass/crock/Destroy()
	crock_cancel()
	return ..()

/obj/item/weapon/reagent_containers/glass/crock/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/butter))
		press_butter(W, user)
		return TRUE
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks))
		pack_food(W, user)
		return TRUE
	return ..()

/obj/item/weapon/reagent_containers/glass/crock/proc/crock_food()
	. = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/S in contents)
		. += S

/proc/crock_can_pickle(obj/item/weapon/reagent_containers/food/snacks/S)
	if (!istype(S, /obj/item/weapon/reagent_containers/food/snacks/grown))
		return FALSE
	if (S.rotten || S.decay <= 0 || !S.reagents || S.reagents.get_reagent_amount("nutriment") <= 0)
		return FALSE
	return TRUE

/obj/item/weapon/reagent_containers/glass/crock/proc/pack_food(obj/item/weapon/reagent_containers/food/snacks/S, mob/user)
	if (!is_open_container())
		to_chat(user, SPAN_WARNING("Take the lid off \the [src] first."))
		return FALSE
	if (!crock_can_pickle(S) && !crock_can_pot(S) && !S.potted)
		to_chat(user, SPAN_WARNING(istype(S, /obj/item/weapon/reagent_containers/food/snacks/grown) ? "\The [S] will not keep in brine." : "\The [S] will not keep under fat. Only cooked, unspoiled meat or fish can be potted."))
		return FALSE
	if (crock_food().len >= CROCK_MAX_FOOD)
		to_chat(user, SPAN_WARNING("\The [src] is packed full."))
		return FALSE
	if (user)
		user.remove_from_mob(S)
	S.forceMove(src)
	if (istype(S, /obj/item/weapon/reagent_containers/food/snacks/grown))
		pickle_progress = 0
	else if (!S.potted)
		pot_progress = 0
	to_chat(user, SPAN_NOTICE("You pack \the [S] into \the [src]."))
	return TRUE

/obj/item/weapon/reagent_containers/glass/crock/AltClick(mob/user)
	if (!user || !Adjacent(user) || user.incapacitated())
		return ..()
	if (!crock_food().len)
		return ..()
	take_food(user)

/obj/item/weapon/reagent_containers/glass/crock/verb/take_out_food()
	set name = "Take Food Out"
	set category = null
	set src in view(1)
	take_food(usr)

/obj/item/weapon/reagent_containers/glass/crock/proc/take_food(mob/user)
	if (!user || user.incapacitated() || !Adjacent(user))
		return FALSE
	if (!is_open_container())
		to_chat(user, SPAN_WARNING("Take the lid off \the [src] first."))
		return FALSE
	var/list/food = crock_food()
	if (!food.len)
		to_chat(user, SPAN_WARNING("There is nothing packed in \the [src]."))
		return FALSE
	var/obj/item/I = food[food.len]
	I.forceMove(get_turf(src))
	user.put_in_hands(I)
	if (!crock_food().len)
		pickle_progress = 0
		pot_progress = 0
	to_chat(user, SPAN_NOTICE("You take \the [I] out of \the [src]."))
	return TRUE

/obj/item/weapon/reagent_containers/glass/crock/proc/unpickled_food()
	. = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/S in contents)
		if (crock_can_pickle(S))
			. += S

/obj/item/weapon/reagent_containers/glass/crock/proc/has_brine_for(count)
	return count > 0 && reagents.get_reagent_amount("vinegar") >= PICKLE_VINEGAR * count && reagents.get_reagent_amount("sodiumchloride") >= PICKLE_SALT * count

// Return the first alcohol the closed crock can turn into vinegar.
/obj/item/weapon/reagent_containers/glass/crock/proc/crock_souring_source()
	for (var/id in list("wine", "cider", "beer", "mead"))
		if (reagents.get_reagent_amount(id) > 0)
			return id
	return null

/obj/item/weapon/reagent_containers/glass/crock/proc/crock_has_work()
	if (is_open_container() || !reagents)
		return FALSE
	if (crock_souring_source())
		return TRUE
	var/list/food = unpickled_food()
	var/list/to_pot = unpotted_food()
	return has_brine_for(food.len) || has_seal_for(to_pot.len)

/obj/item/weapon/reagent_containers/glass/crock/proc/crock_schedule()
	if (crock_timer || QDELETED(src) || !crock_has_work())
		return
	crock_timer = addtimer(CALLBACK(src, PROC_REF(crock_work)), CROCK_WORK_TIME, TIMER_STOPPABLE)

/obj/item/weapon/reagent_containers/glass/crock/proc/crock_cancel()
	if (crock_timer)
		deltimer(crock_timer)
		crock_timer = null

// One working spell of a closed crock. Returns TRUE if anything changed.
/obj/item/weapon/reagent_containers/glass/crock/proc/crock_work()
	if (QDELETED(src))
		return FALSE
	crock_cancel()
	if (is_open_container() || !reagents)
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		crock_schedule()
		return FALSE
	. = FALSE
	var/id = crock_souring_source()
	if (id)
		var/amount = min(reagents.get_reagent_amount(id), CROCK_SOUR_STEP)
		reagents.remove_reagent(id, amount)
		reagents.add_reagent("vinegar", amount)
		. = TRUE
	var/list/food = unpickled_food()
	if (has_brine_for(food.len))
		pickle_progress++
		. = TRUE
		if (pickle_progress >= CROCK_PICKLE_STEPS)
			pickle_progress = 0
			reagents.remove_reagent("vinegar", PICKLE_VINEGAR * food.len)
			reagents.remove_reagent("sodiumchloride", PICKLE_SALT * food.len)
			for (var/obj/item/weapon/reagent_containers/food/snacks/S in food)
				pickle_food(S)
	if (crock_pot_work())
		. = TRUE
	crock_schedule()

/proc/pickle_food(obj/item/weapon/reagent_containers/food/snacks/S)
	S.name = "pickled [S.name]"
	S.desc = "[S.desc] It has been pickled in vinegar and salt, and will keep."
	S.decay = 0
	S.decaytimer = 0
	S.rots = FALSE
	S.satisfaction = max(S.satisfaction, 4)
	if (S.reagents)
		S.reagents.add_reagent("vinegar", 1)

/////////////////////////////// Preserve jar ///////////////////////////////

/obj/item/weapon/reagent_containers/glass/preserve_jar
	name = "preserve jar"
	desc = "A small glass jar with a cloth cover. Fill it with jam and it keeps; spread the jam on a slice of bread."
	icon = 'icons/obj/food/preserves.dmi'
	icon_state = "preserve_jar"
	item_state = null
	volume = 20
	amount_per_transfer_from_this = 5
	possible_transfer_amounts = list(5,10,20)
	value = 2

/obj/item/weapon/reagent_containers/glass/preserve_jar/on_reagent_change()
	..()
	update_icon()

/obj/item/weapon/reagent_containers/glass/preserve_jar/after_load()
	..()
	update_icon()

/obj/item/weapon/reagent_containers/glass/preserve_jar/update_icon()
	overlays.Cut()
	icon_state = "preserve_jar"
	if (!reagents || reagents.total_volume <= 0)
		return
	if (reagents.get_master_reagent_id() == "jam")
		icon_state = "jam_jar"
	var/image/filling = image(icon, src, "jam_jar_fill")
	filling.color = reagents.get_color()
	overlays += filling

/obj/item/weapon/reagent_containers/glass/preserve_jar/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/item/weapon/reagent_containers/food/snacks/breadslice) && user && user.Adjacent(A))
		spread_jam(A, user)
		return TRUE
	return ..()

/obj/item/weapon/reagent_containers/glass/preserve_jar/proc/spread_jam(obj/item/weapon/reagent_containers/food/snacks/breadslice/B, mob/user)
	if (!is_open_container())
		to_chat(user, SPAN_WARNING("Take the cover off \the [src] first."))
		return FALSE
	if (reagents.get_reagent_amount("jam") < JAM_PER_TOAST)
		to_chat(user, SPAN_WARNING("There is not enough jam in \the [src]."))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		to_chat(user, SPAN_WARNING("You cannot do that during persistence operations."))
		return FALSE
	var/turf/T = get_turf(B)
	var/held = (B.loc == user)
	reagents.remove_reagent("jam", JAM_PER_TOAST)
	var/obj/item/weapon/reagent_containers/food/snacks/jelliedtoast/J = new(T)
	// The toast keeps whatever was in the slice (bread left after bites, anything
	// added with a dropper) on top of its own jam layer (#6283).
	B.transfer_reagents_to_spread(J.reagents, J.reagents.total_volume)
	qdel(B)
	if (held)
		user.put_in_hands(J)
	to_chat(user, SPAN_NOTICE("You spread jam on the bread."))
	return J

/////////////////////////////// Reagents ///////////////////////////////

/datum/reagent/drink/vinegar
	name = "Vinegar"
	id = "vinegar"
	description = "Soured wine or ale. Sharp, and good for pickling."
	taste_description = "sharp sourness"
	taste_mult = 2
	color = "#C9B37E"

/datum/reagent/nutriment/jam
	name = "Jam"
	id = "jam"
	description = "Fruit boiled down with sugar. It keeps for a long time."
	taste_description = "sweet fruit"
	nutriment_factor = 12
	reagent_state = LIQUID
	color = "#8E1F3F"

/datum/chemical_reaction/jam
	name = "Jam"
	id = "jam"
	result = "jam"
	required_reagents = list("berryjuice" = 10, "sugar" = 5)
	result_amount = 10

/datum/chemical_reaction/jam/honey
	id = "jam_honey"
	required_reagents = list("berryjuice" = 10, "honey" = 5)

/datum/chemical_reaction/jam/grape
	id = "jam_grape"
	required_reagents = list("grapejuice" = 10, "sugar" = 5)

/datum/chemical_reaction/jam/grape_honey
	id = "jam_grape_honey"
	required_reagents = list("grapejuice" = 10, "honey" = 5)

/datum/chemical_reaction/jam/apple
	id = "jam_apple"
	required_reagents = list("applejuice" = 10, "sugar" = 5)

/datum/chemical_reaction/jam/apple_honey
	id = "jam_apple_honey"
	required_reagents = list("applejuice" = 10, "honey" = 5)

/datum/chemical_reaction/jam/apricot
	id = "jam_apricot"
	required_reagents = list("apricotjuice" = 10, "sugar" = 5)

/datum/chemical_reaction/jam/apricot_honey
	id = "jam_apricot_honey"
	required_reagents = list("apricotjuice" = 10, "honey" = 5)

/datum/chemical_reaction/jam/orange
	id = "jam_orange"
	required_reagents = list("orangejuice" = 10, "sugar" = 5)

/datum/chemical_reaction/jam/orange_honey
	id = "jam_orange_honey"
	required_reagents = list("orangejuice" = 10, "honey" = 5)

// Maple syrup sets jam as sugar and honey do (syrups.dm).
/datum/chemical_reaction/jam/berry_maple
	id = "jam_berry_maple"
	required_reagents = list("berryjuice" = 10, "maple_syrup" = 5)

/datum/chemical_reaction/jam/grape_maple
	id = "jam_grape_maple"
	required_reagents = list("grapejuice" = 10, "maple_syrup" = 5)

/datum/chemical_reaction/jam/apple_maple
	id = "jam_apple_maple"
	required_reagents = list("applejuice" = 10, "maple_syrup" = 5)

/datum/chemical_reaction/jam/apricot_maple
	id = "jam_apricot_maple"
	required_reagents = list("apricotjuice" = 10, "maple_syrup" = 5)

/datum/chemical_reaction/jam/orange_maple
	id = "jam_orange_maple"
	required_reagents = list("orangejuice" = 10, "maple_syrup" = 5)

#undef CROCK_WORK_TIME
#undef CROCK_SOUR_STEP
#undef CROCK_MAX_FOOD
#undef CROCK_PICKLE_STEPS
#undef PICKLE_VINEGAR
#undef PICKLE_SALT
#undef JAM_PER_TOAST
