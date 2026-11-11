/obj/item/weapon/storage/toolbox
	name = "toolbox"
	desc = "Danger. Very robust."
	icon = 'icons/obj/storage.dmi'
	icon_state = "toolbox_red"
	item_state = "toolbox_red"
	flags = CONDUCT
	force = WEAPON_FORCE_PAINFUL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = TRUE
	throw_range = 7
	w_class = ITEM_SIZE_LARGE
	max_w_class = 3
	max_storage_space = 14 //enough to hold all starting contents
	attack_verb = list("robusted")

/obj/item/weapon/storage/toolbox/blue
	icon_state = "toolbox_blue"
	item_state = "toolbox_blue"
/obj/item/weapon/storage/toolbox/yellow
	icon_state = "toolbox_yellow"
	item_state = "toolbox_yellow"
/obj/item/weapon/storage/toolbox/emergency
	name = "emergency toolbox"
	icon_state = "toolbox_red"
	item_state = "toolbox_red"

	New()
		..()
		new /obj/item/weapon/wrench(src)
		new /obj/item/weapon/reagent_containers/glass/fire_extinguisher(src)
		new /obj/item/flashlight/flashlight(src)
		new /obj/item/weapon/weldingtool(src)
		new /obj/item/weapon/wirecutters/boltcutters(src)
		new /obj/item/weapon/material/shovel/trench(src)

/obj/item/weapon/storage/toolbox/mechanical
	name = "mechanical toolbox"
	icon_state = "toolbox_blue"
	item_state = "toolbox_blue"

	New()
		..()
		new /obj/item/weapon/wrench(src)
		new /obj/item/weapon/crowbar/prybar(src)
		new /obj/item/weapon/weldingtool(src)
		new /obj/item/weapon/wirecutters/boltcutters(src)
		new /obj/item/weapon/hammer(src)

/obj/item/weapon/storage/toolbox/electrical
	name = "electrical toolbox"
	icon_state = "toolbox_yellow"
	item_state = "toolbox_yellow"

	New()
		..()
		// Both coils share one colour. The third stack argument is the merge flag, so pass FALSE.
		var/coil_type = pick(/obj/item/stack/cable_coil/red, /obj/item/stack/cable_coil/yellow, /obj/item/stack/cable_coil/green, /obj/item/stack/cable_coil/blue, /obj/item/stack/cable_coil/pink, /obj/item/stack/cable_coil/orange, /obj/item/stack/cable_coil/cyan, /obj/item/stack/cable_coil/white)
		new /obj/item/weapon/wrench(src)
		new /obj/item/weapon/wirecutters/boltcutters(src)
		new /obj/item/weapon/crowbar/prybar(src)
		new coil_type(src, 30, FALSE)
		new coil_type(src, 30, FALSE)