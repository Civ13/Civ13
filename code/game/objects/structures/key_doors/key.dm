/obj/item/weapon/key
	var/code = -1
	icon = 'icons/obj/key.dmi'
	icon_state = "key"
	name = "random fucking key that should NOT exist"
	w_class = 1
	dropsound = 'sound/effects/drop_knife.ogg'

/obj/item/weapon/key/New()
	if (istype(src, /obj/item/weapon/key/german))
		name = "German [name]"
	else if (istype(src, /obj/item/weapon/key/soviet))
		name = "Soviet [name]"
	else if (istype(src, /obj/item/weapon/key/japan))
		name = "Japanese [name]"
	else if (istype(src, /obj/item/weapon/key/allied))
		name = "Allied [name]"
	..()