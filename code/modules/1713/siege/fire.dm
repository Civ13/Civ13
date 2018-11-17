/obj/structure/brazier
	name = "brazier"
	desc = "Where you keep warm or light arrows on fire."
	icon_state = "brazier0"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	var/fuel = 0
	var/on = FALSE

/obj/structure/brazier/New()
	..()
	do_light()

/obj/structure/brazier/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/ore/coal))
		fuel = (180)*W.amount
		user << "You refuel the [src]."
		qdel(W)
		return
	else if (istype(W, /obj/item/stack/material/wood))
		fuel = (60)*W.amount
		user << "You refuel the [src]."
		qdel(W)
		return
	else if (istype(W, /obj/item/ammo_casing/arrow) && on)
		var/obj/item/ammo_casing/arrow/WW = W
		user << "You start lighting the arrow in the brazier..."
		if (do_after(user, 30, src))
			user << "You light the arrow in the brazier."
			WW.name = "fire arrow"
			WW.icon_state = "arrowf"
			WW.projectile_type = /obj/item/projectile/arrow/arrow/fire
			WW.damtype = BURN
			WW.BB = new/obj/item/projectile/arrow/arrow/fire(WW)
			WW.contents = list(WW.BB)
			return
/obj/structure/brazier/proc/do_light()
	if (on)
		fuel = (fuel-1)
		if (fuel <= 0)
			on = FALSE
			icon_state = "brazier0"
	spawn(10)
		do_light()

/obj/structure/brazier/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user << "You light the brazier."
		on = TRUE
		icon_state = "brazier1"
		return
	else
		user << "You put out the brazier."
		on = FALSE
		icon_state = "brazier0"
		return