/obj/structure/grinder
	name = "grinder"
	desc = "A professional grinder used to grind certain objects into a pulp."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "grinder"
	density = TRUE
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/active = FALSE
	powerneeded = 30
	var/obj/item/stack/inserted = null

/obj/structure/grinder/proc/check_power()
	if (!powersource || !powerneeded)
		powered = FALSE
		return FALSE
	else
		powered = TRUE
		if (draw_cable_power())
			return TRUE
		else
			if (active)
				powersource.update_power(-powerneeded,1,src)
				active = FALSE
			return FALSE

/obj/structure/grinder/update_icon()
	..()
	if (powered)
		icon_state = "grinder_powered"
	else
		icon_state = "grinder"
	if (active)
		icon_state = "grinder_active"

/obj/structure/grinder/attack_hand(var/mob/living/human/H)
	if (!anchored)
		to_chat(H, SPAN_NOTICE("Fix \the [src] in place with a wrench first."))
		return
	else if (!check_power())
		to_chat(H, SPAN_WARNING("\The [src] doesn't have any power!"))
		return
	else if (!inserted && !active)
		to_chat(H, SPAN_NOTICE("\The [src] is empty."))
		return
	else if (inserted && !active)
		to_chat(H, SPAN_NOTICE("You turn \the [src] active."))
		active = TRUE
		update_icon()
		process_machine()
		return
	..()

/obj/structure/grinder/attackby(var/obj/item/W as obj, var/mob/living/human/user as mob)
	..()

	if (!anchored)
		to_chat(user, SPAN_NOTICE("Fix \the [src] in place with a wrench first."))
		return

	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user,W)
		return

	else if (istype(W, /obj/item/stack) && !inserted)
		to_chat(user, "You place \the [W] in \the [src] for grinding.")
		inserted =  W
		user.drop_item()
		W.loc = src
		update_icon()
		return

/obj/structure/grinder/verb/empty()
	set category = null
	set name = "Remove Inserted"
	set src in range(1)

	if (!inserted)
		to_chat(usr, "There is no object to remove from \the [src].")
		return

	if (active)
		to_chat(usr, SPAN_WARNING(">You cannot remove \the [inserted] while \the [src] is running!</span>"))
		return

	if (inserted && !active)
		visible_message("You remove \the [inserted].","[usr] removes \the [inserted] from \the [src].")
		inserted.loc = get_turf(src)
		inserted = null
		return
	return

/obj/structure/grinder/proc/process_machine()
	if (!check_power())
		visible_message(SPAN_WARNING("\The [src] abruptly stops grinding and powers down."))
		return
	else
		spawn(10 SECONDS)
			playsound(loc, 'sound/machines/grinder.ogg', 100, TRUE)
			spawn (5 SECONDS)
				if (!check_power())
					visible_message(SPAN_WARNING("\The [src] abruptly stops grinding and powers down."))

				var/obj/item/stack/tospawn

				if (istype(inserted, /obj/item/stack/material/wood))
					tospawn = new /obj/item/stack/material/wood(get_turf(src))
					tospawn.amount = inserted.amount/5
				else
					active = FALSE
					update_icon()
					visible_message(SPAN_WARNING("\The [src] cannot grind this item."))
					playsound(loc, 'sound/machines/buzz-sigh.ogg', 50, TRUE)
					inserted.loc = get_turf(src)
					inserted = null
					return

				active = FALSE
				qdel (inserted)
				inserted = null
				update_icon()
				visible_message("\The [src] stops grinding.")

////////////////////////////////////////////////////////////////////////////////////////////////////////
