obj/structure/bell_stand
	name = "bell stand"
	desc = "Fire! Fire!"
	icon = 'icons/obj/structures.dmi'
	icon_state = "bell_stand"
	anchored = TRUE
	density = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/cooldown_bell_stand = FALSE

/obj/structure/bell_stand/attack_hand(var/mob/living/human/H)
	if (cooldown_bell_stand == FALSE)
		icon_state = "bell_stand_ringing"
		playsound(loc, 'sound/effects/bell_stand.ogg', 200, FALSE, 5)
		visible_message("<span class='warning'>[H] rings the bell!</span>")
		cooldown_bell_stand = TRUE
		spawn(15)
			cooldown_bell_stand = FALSE
			icon_state = "bell_stand"
		return

obj/structure/bell_stand/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!istype(H))
		return
	if (H.a_intent == I_HELP)
		if (istype(I, /obj/item/weapon/wrench))
			visible_message("<span class='warning'>[H] starts to [anchored ? "unsecure" : "secure"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
			playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
			if (do_after(H,50,src))
				visible_message("<span class='warning'>[H] [anchored ? "unsecures" : "secures"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
				anchored = !anchored
				return
		if (istype(I, /obj/item/weapon/hammer))
			visible_message("<span class='warning'>[H] starts to deconstruct \the [src].</span>")
			playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
			if (do_after(H,50,src))
				visible_message("<span class='warning'>[H] deconstructs \the [src].</span>")
				qdel(src)
				return

/obj/item/weapon/handbell
	name = "handbell"
	desc = "Good for signalling something melodiously."
	icon = 'icons/obj/items.dmi'
	icon_state = "handbell"
	item_state = "handbell"
	flags = CONDUCT
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	w_class = ITEM_SIZE_SMALL

	attack_verb = list("attacked", "whacked")
	var/cooldown_handbell = FALSE

/obj/item/weapon/handbell/attack_self(mob/user as mob)
	if (cooldown_handbell == FALSE)
		playsound(loc, 'sound/effects/handbell.ogg', 100, FALSE, 5)
		user.visible_message("<span class='warning'>[user] rings the [name]!</span>")
		cooldown_handbell = TRUE
		spawn(5 SECONDS)
			cooldown_handbell = FALSE
		return