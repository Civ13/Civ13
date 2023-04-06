/obj/item/cannon_ball
	icon = 'icons/obj/cannon_ball.dmi'
	name = "cannon ball"
	icon_state = "cannon_ball"
	w_class = ITEM_SIZE_LARGE
	value = 15
	flags = CONDUCT
	var/reagent_payload = null
	var/damage = 100
	var/caliber = 75
	var/atype = "cannonball"
	var/subtype = /obj/item/projectile/shell

/obj/item/cannon_ball/chainshot
	name = "chain shot"
	icon_state = "chainshot"
	damage = 60
	subtype = /obj/item/projectile/shell/cannonball/chainshot
	atype = "chainshot"

/obj/item/cannon_ball/grapeshot
	name = "grape shot"
	icon_state = "grapeshot"
	damage = 30
	subtype = /obj/item/projectile/shell/cannonball/grapeshot
	atype = "grapeshot"

/obj/item/cannon_ball/shell
	icon = 'icons/obj/cannon_ball.dmi'
	name = "artillery shell"
	icon_state = "shell"
	w_class = ITEM_SIZE_LARGE
	value = 20
	atype = "HE"

/obj/item/cannon_ball/shell/incendiary
	name = "incendiary artillery shell"
	icon_state = "shell_incendiary"
	atype = "INCENDIARY"

/obj/item/cannon_ball/shell/tank
	icon = 'icons/obj/cannon_ball.dmi'
	name = "cannon shell"
	icon_state = "shellHE"
	w_class = ITEM_SIZE_HUGE
	value = 20
	caliber = 75
	heavy_armor_penetration = 15
	atype = "HE"
	New()
		..()
		name = "[caliber]mm [atype] shell"
		icon_state = "shell[atype]"

/obj/item/cannon_ball/shell/tank/HE57
	atype = "HE"
	caliber = 57
	heavy_armor_penetration = 15
	damage = 225

/obj/item/cannon_ball/shell/tank/AP45
	atype = "AP"
	caliber = 45
	heavy_armor_penetration = 40
	damage = 75

/obj/item/cannon_ball/shell/tank/APCR45
	atype = "APCR"
	caliber = 45
	heavy_armor_penetration = 60
	damage = 90

/obj/item/cannon_ball/shell/tank/HE45
	atype = "HE"
	caliber = 45
	heavy_armor_penetration = 8
	damage = 290

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

/obj/item/cannon_ball/shell/tank/HE100
	atype = "HE"
	caliber = 100
	heavy_armor_penetration = 20
	damage = 333

/obj/item/cannon_ball/shell/tank/AP100
	atype = "AP"
	caliber = 100
	heavy_armor_penetration = 70
	damage = 133

/obj/item/cannon_ball/shell/tank/APCR100
	atype = "APCR"
	caliber = 100
	heavy_armor_penetration = 100
	damage = 100

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

/obj/item/cannon_ball/shell/tank/HE150
	atype = "HE"
	caliber = 150
	heavy_armor_penetration = 80
	damage = 350
	icon_state = "navalshell"
	New()
		..()
		icon_state = "navalshell"

/obj/item/cannon_ball/shell/tank/HE380
	atype = "HE"
	caliber = 380
	heavy_armor_penetration = 120
	damage = 650
	icon_state = "navalshell"
	New()
		..()
		icon_state = "navalshell"

// Mortar

/obj/item/cannon_ball/mortar_shell
	icon = 'icons/obj/cannon_ball.dmi'
	name = "mortar shell"
	icon_state = "shell_mortar"
	w_class = ITEM_SIZE_LARGE
	value = 20

/obj/item/cannon_ball/mortar_shell/type89
	name = "type 89 mortar shell"
	icon_state = "shell_mortar_89"

/obj/item/cannon_ball/mortar_shell/smoke
	name = "smoke mortar shell"
	icon_state = "shell_mortar_smoke"
	reagent_payload = "smokescreen"

/obj/item/cannon_ball/mortar_shell/incendiary
	name = "incendiary mortar shell"
	icon_state = "shell_mortar_incendiary"
	atype = "INCENDIARY"

// Chemical

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

// Nuclear

/obj/item/cannon_ball/shell/tank/nuclear
	atype = "NUCLEAR"
	New()
		..()
		icon = 'icons/obj/cannon_ball.dmi'
		icon_state = "shell_nuclear"

/obj/item/cannon_ball/rocket/nuclear
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Nuclear Rocket"
	desc = "You might want to step back a bit..."
	icon_state = "shell_nuclear_rocket"
	w_class = ITEM_SIZE_LARGE
	value = 80

/obj/item/cannon_ball/shell/nuclear
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Nuclear Shell"
	desc = "A nuclear shell"
	icon_state = "shell_nuclear"
	w_class = ITEM_SIZE_LARGE
	value = 25

/obj/item/cannon_ball/shell/nuclear/makeshift
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Makeshift Nuclear Shell"
	desc = "A makeshift nuclear shell, once the genie is out of the bottle you can't put it back in..."
	icon_state = "shell_nuclear"
	w_class = ITEM_SIZE_LARGE
	value = 20

/obj/item/cannon_ball/shell/nuclear/W9
	icon = 'icons/obj/cannon_ball.dmi'
	name = "W9 Atomic Demolition Munition"
	desc = "A W9 nuclear shell"
	icon_state = "shell_nuclear"
	w_class = ITEM_SIZE_LARGE
	value = 40

/obj/item/cannon_ball/shell/nuclear/W19
	icon = 'icons/obj/cannon_ball.dmi'
	name = "W19 Katie Nuclear Shell"
	desc = "A W19 Katie nuclear shell"
	icon_state = "shell_nuclear"
	w_class = ITEM_SIZE_LARGE
	value = 30

/obj/item/cannon_ball/shell/nuclear/W33
	icon = 'icons/obj/cannon_ball.dmi'
	name = "W33 Nuclear Shell"
	desc = "A W33 nuclear shell"
	icon_state = "shell_nuclear"
	w_class = ITEM_SIZE_LARGE
	value = 20

/obj/item/cannon_ball/shell/nuclear/W33Boosted
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Boosted W33 Nuclear Shell"
	desc = "A boosted nuclear shell for extra destruction"
	icon_state = "shell_nuclear_boosted"
	w_class = ITEM_SIZE_LARGE
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

/obj/structure/shellrack/full45/New()
	..()
	new /obj/item/cannon_ball/shell/tank/HE45(storage)
	new /obj/item/cannon_ball/shell/tank/HE45(storage)
	new /obj/item/cannon_ball/shell/tank/HE45(storage)
	new /obj/item/cannon_ball/shell/tank/HE45(storage)
	new /obj/item/cannon_ball/shell/tank/HE45(storage)
	new /obj/item/cannon_ball/shell/tank/HE45(storage)

	new /obj/item/cannon_ball/shell/tank/AP45(storage)
	new /obj/item/cannon_ball/shell/tank/AP45(storage)
	new /obj/item/cannon_ball/shell/tank/AP45(storage)
	new /obj/item/cannon_ball/shell/tank/AP45(storage)
	new /obj/item/cannon_ball/shell/tank/AP45(storage)

	new /obj/item/cannon_ball/shell/tank/APCR45(storage)
	new /obj/item/cannon_ball/shell/tank/APCR45(storage)
	new /obj/item/cannon_ball/shell/tank/APCR45(storage)
	new /obj/item/cannon_ball/shell/tank/APCR45(storage)
	new /obj/item/cannon_ball/shell/tank/APCR45(storage)
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

/obj/structure/shellrack/full100/New()
	..()
	new /obj/item/cannon_ball/shell/tank/HE100(storage)
	new /obj/item/cannon_ball/shell/tank/HE100(storage)
	new /obj/item/cannon_ball/shell/tank/HE100(storage)
	new /obj/item/cannon_ball/shell/tank/HE100(storage)

	new /obj/item/cannon_ball/shell/tank/AP100(storage)
	new /obj/item/cannon_ball/shell/tank/AP100(storage)
	new /obj/item/cannon_ball/shell/tank/AP100(storage)
	new /obj/item/cannon_ball/shell/tank/AP100(storage)

	new /obj/item/cannon_ball/shell/tank/APCR100(storage)
	new /obj/item/cannon_ball/shell/tank/APCR100(storage)
	new /obj/item/cannon_ball/shell/tank/APCR100(storage)
	new /obj/item/cannon_ball/shell/tank/APCR100(storage)
	update_icon()

/obj/structure/shellrack/full75/american/New()
	..()
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	new /obj/item/cannon_ball/shell/tank/HE75(storage)
	update_icon()

/obj/structure/shellrack/full85/New()
	..()
	new /obj/item/cannon_ball/shell/tank/HE85(storage)
	new /obj/item/cannon_ball/shell/tank/HE85(storage)
	new /obj/item/cannon_ball/shell/tank/HE85(storage)
	new /obj/item/cannon_ball/shell/tank/HE85(storage)

	new /obj/item/cannon_ball/shell/tank/AP85(storage)
	new /obj/item/cannon_ball/shell/tank/AP85(storage)
	new /obj/item/cannon_ball/shell/tank/AP85(storage)
	new /obj/item/cannon_ball/shell/tank/AP85(storage)

	new /obj/item/cannon_ball/shell/tank/APCR85(storage)
	new /obj/item/cannon_ball/shell/tank/APCR85(storage)
	new /obj/item/cannon_ball/shell/tank/APCR85(storage)
	new /obj/item/cannon_ball/shell/tank/APCR85(storage)

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