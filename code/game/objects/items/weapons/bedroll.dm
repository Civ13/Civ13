/obj/item/weapon/bedroll
	name = "bedroll"
	desc = "A portable bed, made of leather and fur."
	icon = 'icons/obj/items.dmi'
	icon_state = "bedroll_r"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	w_class = 3.0
	matter = list(DEFAULT_WALL_MATERIAL = 150)
	attack_verb = list("battered","whacked")

/obj/structure/bed/bedroll
	name = "bedroll"
	desc = "A portable bed, made of leather and fur."
	icon = 'icons/obj/items.dmi'
	icon_state = "bedroll_o"
	anchored = TRUE
	var/used = FALSE
	var/running = FALSE //to prevent exploits of unbuckling/bucking etc

/obj/item/weapon/bedroll/attack_self(mob/user as mob)
	user << "You open the bedroll, extending it."
	new/obj/structure/bed/bedroll(src.loc)
	qdel(src)
	return

/obj/structure/bed/bedroll/verb/fold()
	set category = null
	set src in usr
	set name = "Fold Bedroll"
	if (used == FALSE)
		usr << "You fold the bedroll."
		running = FALSE
		new/obj/item/weapon/bedroll(src.loc)
		qdel(src)
		return

/obj/structure/bed/bedroll/proc/check_use(var/mob/living/carbon/human/H)
	if ((H in src.loc) && buckled_mob == H && used == TRUE && running == FALSE)
		running = TRUE
		spawn(300)
		if ((H in src.loc) && buckled_mob == H && used == TRUE && running == TRUE)
			if (H.getBruteLoss() >= 40)
				H.adjustBruteLoss(-1)
			icon_state = "bedroll_w"
			running = FALSE
			check_use(H)
	else
		used = FALSE
		icon_state = "bedroll_o"
		return