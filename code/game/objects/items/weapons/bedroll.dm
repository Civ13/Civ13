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
	var/deployed = FALSE
	var/used = FALSE
/obj/item/weapon/bedroll/attack_self(mob/user as mob)
	if (deployed == FALSE)
		user << "You open the bedroll, extending it."
		deployed = TRUE
		w_class = 5.0
		icon_state = "bedroll_o"
		return

	else if (deployed == TRUE && used == FALSE)
		user << "You get inside the bedroll."
		if (user.dir == NORTH)
			icon_state = "bedroll_w"
		else if (user.dir == WEST)
			icon_state = "bedroll_w"
		else if (user.dir == EAST )
			icon_state = "bedroll_w"
		else if (user.dir == SOUTH)
			icon_state = "bedroll_w"
		user.drop_item()
		if (layer == initial(layer))
			layer = MOB_LAYER + 0.1
		else
			layer = initial(layer)
		user.resting = TRUE
		used = TRUE
		check_use(user)
		return

/obj/item/weapon/bedroll/attack_hand(mob/user as mob)
	..()
	icon_state = "bedroll_r"
	deployed = FALSE
	used = FALSE
	w_class = 3.0

/obj/item/weapon/bedroll/proc/check_use(var/mob/living/carbon/human/H)
	if ((H in src.loc) && H.resting)
		spawn(600)
		if ((H in src.loc) && H.resting)
			if (H.getBruteLoss() >= 40)
				H.adjustBruteLoss(-2)
			check_use(H)
	else
		used = FALSE
		icon_state = "bedroll_o"
		return