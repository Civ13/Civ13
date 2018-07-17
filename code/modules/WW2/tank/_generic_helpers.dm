/proc/istankvalidtool(var/obj/item/weapon/W)
	if (istype(W, /obj/item/weapon/wrench))
		return TRUE
	if (istype(W, /obj/item/weapon/weldingtool))
		return TRUE
	if (istype(W, /obj/item/weapon/screwdriver))
		return TRUE
	if (istype(W, /obj/item/weapon/crowbar))
		return TRUE
	return FALSE
