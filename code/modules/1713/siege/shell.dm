/obj/item/cannon_ball
	icon = 'icons/obj/cannon_ball.dmi'
	name = "cannon ball"
	icon_state = "cannon_ball"
	w_class = 4.0
	value = 15
	var/reagent_payload = null
	var/damage = 100
	var/caliber = 75
	var/atype = "HE"

/obj/item/cannon_ball/shell
	icon = 'icons/obj/cannon_ball.dmi'
	name = "artillery shell"
	icon_state = "shell"
	w_class = 4.0
	value = 20

/obj/item/cannon_ball/shell/tank
	icon = 'icons/obj/cannon_ball.dmi'
	name = "cannon shell"
	icon_state = "shellHE"
	w_class = 5.0
	value = 20
	caliber = 75
	heavy_armor_penetration = 15
	New()
		..()
		name = "[caliber]mm [atype] shell"
		icon_state = "shell[atype]"

/obj/item/cannon_ball/shell/tank/HE57
	atype = "HE"
	caliber = 57
	heavy_armor_penetration = 15
	damage = 225

/obj/item/cannon_ball/shell/tank/AP57
	atype = "AP"
	caliber = 57
	heavy_armor_penetration = 52
	damage = 95

/obj/item/cannon_ball/shell/tank/APCR57
	atype = "APCR"
	caliber = 57
	heavy_armor_penetration = 75
	damage = 115

/obj/item/cannon_ball/shell/tank/HE75
	atype = "HE"
	caliber = 75
	heavy_armor_penetration = 15
	damage = 250

/obj/item/cannon_ball/shell/tank/AP75
	atype = "AP"
	caliber = 75
	heavy_armor_penetration = 52
	damage = 100

/obj/item/cannon_ball/shell/tank/APCR75
	atype = "APCR"
	caliber = 75
	heavy_armor_penetration = 75
	damage = 125

/obj/item/cannon_ball/shell/tank/HE88
	atype = "HE"
	caliber = 88
	heavy_armor_penetration = 22
	damage = 350

/obj/item/cannon_ball/shell/tank/AP88
	atype = "AP"
	caliber = 88
	heavy_armor_penetration = 110
	damage = 145

/obj/item/cannon_ball/shell/tank/APCR88
	atype = "APCR"
	caliber = 88
	heavy_armor_penetration = 130
	damage = 175

/obj/item/cannon_ball/shell/tank/HE85
	atype = "HE"
	caliber = 85
	heavy_armor_penetration = 20
	damage = 330

/obj/item/cannon_ball/shell/tank/AP85
	atype = "AP"
	caliber = 85
	heavy_armor_penetration = 110
	damage = 140

/obj/item/cannon_ball/shell/tank/APCR85
	atype = "APCR"
	caliber = 85
	heavy_armor_penetration = 130
	damage = 170

/obj/item/cannon_ball/shell/tank/HE76
	atype = "HE"
	caliber = 76.2
	heavy_armor_penetration = 16
	damage = 250

/obj/item/cannon_ball/shell/tank/AP76
	atype = "AP"
	caliber = 76.2
	heavy_armor_penetration = 55
	damage = 100

/obj/item/cannon_ball/shell/tank/APCR76
	atype = "APCR"
	caliber = 76.2
	heavy_armor_penetration = 80
	damage = 125

/obj/item/cannon_ball/shell/tank/HE204
	atype = "HE"
	caliber = 204
	heavy_armor_penetration = 100
	damage = 500

/obj/item/cannon_ball/shell/tank/AP204
	atype = "AP"
	caliber = 204
	heavy_armor_penetration = 150
	damage = 400

/obj/item/cannon_ball/shell/tank/APCR204
	atype = "APCR"
	caliber = 204
	heavy_armor_penetration = 125
	damage = 450
/obj/item/cannon_ball/shell/tank/nuclear/
	atype = "NUCLEAR"
	New()
		..()
		icon = 'icons/obj/cannon_ball.dmi'
		icon_state = "shell_nuclear"
/obj/item/cannon_ball/mortar_shell
	icon = 'icons/obj/cannon_ball.dmi'
	name = "mortar shell"
	icon_state = "shell_mortar"
	w_class = 4.0
	value = 20

/obj/item/cannon_ball/shell/gas/chlorine
	reagent_payload = "chlorine_gas"
	name = "Chlorine Shell"
	icon_state = "shell_chlorine"

/obj/item/cannon_ball/shell/gas/mustard
	reagent_payload = "mustard_gas"
	name = "Mustard Gas Shell"
	icon_state = "shell_mustard"

/obj/item/cannon_ball/shell/gas/phosgene
	reagent_payload = "phosgene_gas"
	name = "Phosgene Gas Shell"
	icon_state = "shell_phosgene"

/obj/item/cannon_ball/shell/gas/white_phosphorus
	reagent_payload = "white_phosphorus_gas"
	name = "White Phosphorus Shell"
	icon_state = "shell_wp"

/obj/item/cannon_ball/shell/gas/xylyl_bromide
	reagent_payload = "xylyl_bromide"
	name = "Xylyl Bromide Shell"
	icon_state = "shell_xb"

/obj/item/cannon_ball/shell/gas/zyklon_b
	reagent_payload = "zyclon_b"
	name = "Zyklon B Shell"
	icon_state = "shell_xb"

/obj/item/cannon_ball/rocket/nuclear
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Nuclear Rocket"
	icon_state = "shell_nuclear_rocket"
	w_class = 4.0
	value = 80

/obj/item/cannon_ball/shell/nuclear
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Nuclear Shell"
	icon_state = "shell_nuclear"
	w_class = 4.0
	value = 25

/obj/item/cannon_ball/shell/nuclear/makeshift
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Makeshift Nuclear Shell"
	icon_state = "shell_nuclear"
	w_class = 4.0
	value = 20

/obj/item/cannon_ball/shell/nuclear/W9
	icon = 'icons/obj/cannon_ball.dmi'
	name = "W9 Atomic Demolition Munition"
	icon_state = "shell_nuclear"
	w_class = 4.0
	value = 40

/obj/item/cannon_ball/shell/nuclear/W19
	icon = 'icons/obj/cannon_ball.dmi'
	name = "W19 Katie Nuclear Shell"
	icon_state = "shell_nuclear"
	w_class = 4.0
	value = 30

/obj/item/cannon_ball/shell/nuclear/W33
	icon = 'icons/obj/cannon_ball.dmi'
	name = "W33 Nuclear Shell"
	icon_state = "shell_nuclear"
	w_class = 4.0
	value = 20

/obj/item/cannon_ball/shell/nuclear/W33Boosted
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Boosted W33 Nuclear Shell"
	icon_state = "shell_nuclear"
	w_class = 4.0
	value = 50


////////////////////////////////////////////////////////
/obj/structure/shellrack
	icon = 'icons/obj/structures.dmi'
	name = "shell rack"
	icon_state = "shellrack0"
	w_class = 10.0
	var/obj/item/weapon/storage/internal/storage
	density = FALSE
	opacity = FALSE

/obj/structure/shellrack/New()
	..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = 16
	storage.max_w_class = 10
	storage.max_storage_space = 600
	storage.can_hold = list(/obj/item/cannon_ball/shell)
	update_icon()

/obj/structure/shellrack/Destroy()
	qdel(storage)
	storage = null
	..()

/obj/structure/shellrack/attack_hand(mob/user as mob)
	if (istype(user, /mob/living/human) && user in range(1,src))
		if (storage)
			storage.open(user)
		update_icon()
	else
		return
/obj/structure/shellrack/MouseDrop(obj/over_object as obj)
	if (storage && storage.handle_mousedrop(usr, over_object))
		..(over_object)
		update_icon()

/obj/structure/shellrack/attackby(obj/item/W as obj, mob/user as mob)
	..()
	storage.attackby(W, user)
	update_icon()

/obj/structure/shellrack/update_icon()
	..()
	if (storage)
		icon_state = "shellrack[storage.contents.len]"

/obj/structure/shellrack/full57/New()
	..()
	new /obj/item/cannon_ball/shell/tank/HE57(storage)
	new /obj/item/cannon_ball/shell/tank/HE57(storage)
	new /obj/item/cannon_ball/shell/tank/HE57(storage)
	new /obj/item/cannon_ball/shell/tank/HE57(storage)
	new /obj/item/cannon_ball/shell/tank/HE57(storage)
	new /obj/item/cannon_ball/shell/tank/HE57(storage)


	new /obj/item/cannon_ball/shell/tank/AP57(storage)
	new /obj/item/cannon_ball/shell/tank/AP57(storage)
	new /obj/item/cannon_ball/shell/tank/AP57(storage)
	new /obj/item/cannon_ball/shell/tank/AP57(storage)
	new /obj/item/cannon_ball/shell/tank/AP57(storage)

	new /obj/item/cannon_ball/shell/tank/APCR57(storage)
	new /obj/item/cannon_ball/shell/tank/APCR57(storage)
	new /obj/item/cannon_ball/shell/tank/APCR57(storage)
	new /obj/item/cannon_ball/shell/tank/APCR57(storage)
	new /obj/item/cannon_ball/shell/tank/APCR57(storage)
	update_icon()


/obj/structure/shellrack/full75/New()
	..()
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	new /obj/item/cannon_ball/shell/tank/HE75(storage)

	new /obj/item/cannon_ball/shell/tank/AP75(storage)
	new /obj/item/cannon_ball/shell/tank/AP75(storage)
	new /obj/item/cannon_ball/shell/tank/AP75(storage)
	new /obj/item/cannon_ball/shell/tank/AP75(storage)

	new /obj/item/cannon_ball/shell/tank/APCR75(storage)
	new /obj/item/cannon_ball/shell/tank/APCR75(storage)
	new /obj/item/cannon_ball/shell/tank/APCR75(storage)
	new /obj/item/cannon_ball/shell/tank/APCR75(storage)
	update_icon()

/obj/structure/shellrack/full75/american/New()
	..()
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	update_icon()

/obj/structure/shellrack/full88/New()
	..()
	new /obj/item/cannon_ball/shell/tank/HE88(storage)
	new /obj/item/cannon_ball/shell/tank/HE88(storage)
	new /obj/item/cannon_ball/shell/tank/HE88(storage)
	new /obj/item/cannon_ball/shell/tank/HE88(storage)

	new /obj/item/cannon_ball/shell/tank/AP88(storage)
	new /obj/item/cannon_ball/shell/tank/AP88(storage)
	new /obj/item/cannon_ball/shell/tank/AP88(storage)
	new /obj/item/cannon_ball/shell/tank/AP88(storage)

	new /obj/item/cannon_ball/shell/tank/APCR88(storage)
	new /obj/item/cannon_ball/shell/tank/APCR88(storage)
	new /obj/item/cannon_ball/shell/tank/APCR88(storage)
	new /obj/item/cannon_ball/shell/tank/APCR88(storage)
	update_icon()

/obj/structure/shellrack/full76/New()
	..()
	new /obj/item/cannon_ball/shell/tank/HE76(storage)
	new /obj/item/cannon_ball/shell/tank/HE76(storage)
	new /obj/item/cannon_ball/shell/tank/HE76(storage)
	new /obj/item/cannon_ball/shell/tank/HE76(storage)

	new /obj/item/cannon_ball/shell/tank/AP76(storage)
	new /obj/item/cannon_ball/shell/tank/AP76(storage)
	new /obj/item/cannon_ball/shell/tank/AP76(storage)
	new /obj/item/cannon_ball/shell/tank/AP76(storage)

	new /obj/item/cannon_ball/shell/tank/APCR76(storage)
	new /obj/item/cannon_ball/shell/tank/APCR76(storage)
	new /obj/item/cannon_ball/shell/tank/APCR76(storage)
	new /obj/item/cannon_ball/shell/tank/APCR76(storage)
	update_icon()

/obj/structure/shellrack/full204/New()
	..()
	new /obj/item/cannon_ball/shell/tank/HE204(storage)
	new /obj/item/cannon_ball/shell/tank/HE204(storage)
	new /obj/item/cannon_ball/shell/tank/HE204(storage)
	new /obj/item/cannon_ball/shell/tank/HE204(storage)
	new /obj/item/cannon_ball/shell/tank/HE204(storage)
	new /obj/item/cannon_ball/shell/tank/HE204(storage)


	new /obj/item/cannon_ball/shell/tank/AP204(storage)
	new /obj/item/cannon_ball/shell/tank/AP204(storage)
	new /obj/item/cannon_ball/shell/tank/AP204(storage)
	new /obj/item/cannon_ball/shell/tank/AP204(storage)
	new /obj/item/cannon_ball/shell/tank/AP204(storage)

	new /obj/item/cannon_ball/shell/tank/APCR204(storage)
	new /obj/item/cannon_ball/shell/tank/APCR204(storage)
	new /obj/item/cannon_ball/shell/tank/APCR204(storage)
	new /obj/item/cannon_ball/shell/tank/APCR204(storage)
	new /obj/item/cannon_ball/shell/tank/APCR204(storage)
	update_icon()