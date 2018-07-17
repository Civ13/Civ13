/obj/item/weapon/gun/launcher/rocket/panzerfaust
	name = "Panzerfaust"
	icon_state = "panzerfaust"
	item_state = "panzerfaust"
	slot_flags = SLOT_BACK
	recoil = TRUE

// panzerfaust takes 1.2 seconds to fire now
/obj/item/weapon/gun/launcher/rocket/panzerfaust/special_check(var/mob/user)
	. = ..()
	if (!.)
		return .
	if (!do_after(user, 9, get_turf(user)))
		return FALSE
	return TRUE

/obj/item/weapon/gun/launcher/rocket/panzerfaust/New()
	..()
	rockets += new/obj/item/ammo_casing/rocket/yuge/lessyuge()

/obj/item/weapon/gun/launcher/rocket/handle_post_fire()
	..()
	qdel(src)

/obj/item/weapon/gun/launcher/rocket/panzerfaust/tank

/obj/item/weapon/gun/launcher/rocket/panzerfaust/tank/New()
	..()
	rockets += new/obj/item/ammo_casing/rocket/tank()