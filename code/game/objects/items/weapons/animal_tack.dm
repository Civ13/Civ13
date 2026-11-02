// Containment is the only equipment ownership: no cached animal/item links.
/obj/item/animal_tack
	name = "animal tack"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE

/obj/item/animal_tack/proc/fits_animal(mob/living/simple_animal/animal)
	return FALSE

/obj/item/animal_tack/saddle
	name = "leather saddle"
	desc = "A leather horse saddle. Halves the time to mount and voluntarily dismount. Fit it by using it on an unoccupied horse."
	icon = 'icons/obj/clothing/belts.dmi'
	icon_state = "belt_satchel"
	item_state = "belt_holster"

/obj/item/animal_tack/saddle/fits_animal(mob/living/simple_animal/animal)
	return istype(animal, /mob/living/simple_animal/horse)

/obj/item/animal_tack/harness
	name = "leather animal harness"
	desc = "Leather draft tack for a horse or cow. Halves the extra hunger from pulling a carriage. Fit it before hitching the animal normally."
	icon = 'icons/obj/items.dmi'
	icon_state = "leash"

/obj/item/animal_tack/harness/fits_animal(mob/living/simple_animal/animal)
	return istype(animal, /mob/living/simple_animal/horse) || istype(animal, /mob/living/simple_animal/cattle)

/mob/living/simple_animal/proc/get_animal_tack(tack_type, obj/item/animal_tack/ignore = null)
	for (var/obj/item/animal_tack/T in src.contents)
		if (T != ignore && !QDELETED(T) && T.loc == src && istype(T, tack_type) && T.fits_animal(src))
			return T
	return null

/mob/living/simple_animal/proc/animal_mount_delay()
	if (src.stat != DEAD && src.get_animal_tack(/obj/item/animal_tack/saddle))
		return 20
	return 40

/mob/living/simple_animal/proc/animal_draft_hunger_cost()
	if (src.get_animal_tack(/obj/item/animal_tack/harness))
		return 0.5
	return 1

/mob/living/simple_animal/proc/can_handle_animal_tack(mob/living/human/user)
	return !QDELETED(src) && !QDELETED(user) && ishuman(user) && !user.incapacitated() && user.Adjacent(src) && !src.ride && !src.rider && !src.buckled && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

/mob/living/simple_animal/proc/fit_animal_tack(obj/item/animal_tack/T, mob/living/human/user)
	if (!src.can_handle_animal_tack(user) || src.stat == DEAD || QDELETED(T) || !T.fits_animal(src) || T.loc != user || user.get_active_hand() != T)
		to_chat(user, "You must hold suitable tack beside an unoccupied, unhitched living animal.")
		return FALSE
	var/tack_type = /obj/item/animal_tack/harness
	if (istype(T, /obj/item/animal_tack/saddle))
		tack_type = /obj/item/animal_tack/saddle
	if (src.get_animal_tack(tack_type))
		to_chat(user, "That animal already has this kind of tack. Use Remove animal tack first.")
		return FALSE
	var/turf/site = get_turf(src)
	var/tack_epoch = persistence_admission_identity
	if (!site || !user.drop_from_inventory(T, site))
		return FALSE
	// Inventory callbacks may move/delete the actor, target or exact item.
	if (!src.can_handle_animal_tack(user) || src.stat == DEAD || QDELETED(T) || T.loc != site || get_turf(src) != site || !T.fits_animal(src) || src.get_animal_tack(tack_type) || tack_epoch != persistence_admission_identity)
		return FALSE
	T.forceMove(src)
	if (QDELETED(T) || T.loc != src)
		return FALSE
	if (!src.can_handle_animal_tack(user) || src.stat == DEAD || !T.fits_animal(src) || src.get_animal_tack(tack_type, T) || tack_epoch != persistence_admission_identity)
		// Roll back only the exact item still owned by this animal.
		T.forceMove(site)
		return FALSE
	src.visible_message("[user] fits [T] to [src].")
	return TRUE

/mob/living/simple_animal/proc/remove_animal_tack(obj/item/animal_tack/T, mob/living/human/user)
	if (!src.can_handle_animal_tack(user) || QDELETED(T) || T.loc != src)
		return FALSE
	var/turf/site = get_turf(src)
	if (!site)
		return FALSE
	T.forceMove(site)
	if (QDELETED(T) || T.loc != site)
		return FALSE
	src.visible_message("[user] removes [T] from [src].")
	return TRUE

/mob/living/simple_animal/verb/unfit_animal_tack()
	set name = "Remove animal tack"
	set category = "IC"
	set src in oview(1)
	var/mob/living/human/user = usr
	if (!src.can_handle_animal_tack(user))
		return
	var/list/choices = list()
	for (var/obj/item/animal_tack/T in src.contents)
		if (!QDELETED(T) && T.loc == src)
			choices += T
	if (!choices.len)
		to_chat(user, "There is no tack to remove.")
		return
	var/client/controller = user.client
	if (!controller || controller.mob != user)
		return
	var/tack_epoch = persistence_admission_identity
	var/obj/item/animal_tack/chosen = WWinput(user, "Which tack do you want to remove?", "Animal tack", "Cancel", choices)
	if (!controller || QDELETED(user) || user.client != controller || controller.mob != user || tack_epoch != persistence_admission_identity || !(chosen in choices))
		return
	src.remove_animal_tack(chosen, user)
