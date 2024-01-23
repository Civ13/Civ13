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

/obj/item/cannon_ball/rocket
	icon = 'icons/obj/cannon_ball.dmi'
	name = "rocket"
	icon_state = "rocket"
	w_class = ITEM_SIZE_LARGE
	value = 30
	atype = "HE"

/obj/item/cannon_ball/rocket/ex_act()
	var/turf/t = get_turf(src)
	explosion(t,0,1,1,3)
	qdel(src)

/obj/item/cannon_ball/rocket/bullet_act(var/obj/item/projectile/proj, def_zone)
	var/turf/t = get_turf(src)
	if (prob(10))
		playsound(t, 'sound/effects/smoke.ogg', 10, TRUE, -3)
		explosion(t,0,1,1,2)
		visible_message(SPAN_DANGER("<big>\The [src] is hit by a projectile causing it to explode!</big>"))
		qdel(src)

/obj/item/cannon_ball/rocket/fire_act(temperature)
	var/turf/t = get_turf(src)
	if (temperature > T0C+500)
		if (prob(20))
			explosion(t,1,1,1,2)
			visible_message(SPAN_DANGER("<big>\The [src] cooks-off and explodes!</big>"))
			qdel(src)

/obj/item/cannon_ball/rocket/incendiary
	name = "incendiary rocket"
	icon_state = "rocket_incendiary"
	atype = "INCENDIARY"

/obj/item/cannon_ball/shell
	icon = 'icons/obj/cannon_ball.dmi'
	name = "artillery shell"
	icon_state = "shell"
	w_class = ITEM_SIZE_LARGE
	value = 55
	atype = "HE"

/obj/item/cannon_ball/shell/ex_act()
	var/turf/t = get_turf(src)
	explosion(t,2,1,2,5)
	qdel(src)

/obj/item/cannon_ball/shell/naval/HE380/ex_act()
	var/turf/t = get_turf(src)
	explosion(t,1,1,2,5)
	qdel(src)

/obj/item/cannon_ball/shell/naval/HE150/ex_act()
	var/turf/t = get_turf(src)
	explosion(t,0,1,1,3)
	qdel(src)

/obj/item/cannon_ball/shell/bullet_act(var/obj/item/projectile/proj, def_zone)
	var/turf/t = get_turf(src)
	if (prob(20))
		playsound(t, 'sound/effects/smoke.ogg', 20, TRUE, -3)
		explosion(t,1,1,2,5)
		visible_message(SPAN_DANGER("<big>\The [src] is hit by a projectile causing it to explode!</big>"))
		qdel(src)

/obj/item/cannon_ball/shell/fire_act(temperature)
	var/turf/t = get_turf(src)
	if (temperature > T0C+500)
		if (prob(20))
			explosion(t,1,1,2,5) //cook off makes it explode less
			visible_message(SPAN_DANGER("<big>\The [src] cooks-off and explodes!</big>"))
			qdel(src)

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

/obj/item/cannon_ball/shell/tank/HE45
	atype = "HE"
	caliber = 45
	heavy_armor_penetration = 8
	damage = 290
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

/obj/item/cannon_ball/shell/tank/HE120
	atype = "HE"
	caliber = 120
	heavy_armor_penetration = 20
	damage = 333
/obj/item/cannon_ball/shell/tank/AP120
	atype = "AP"
	caliber = 120
	heavy_armor_penetration = 110
	damage = 140
/obj/item/cannon_ball/shell/tank/APCR120
	atype = "APCR"
	caliber = 120
	heavy_armor_penetration = 130
	damage = 100

/obj/item/cannon_ball/shell/tank/HE125
	atype = "HE"
	caliber = 125
	heavy_armor_penetration = 20
	damage = 333
/obj/item/cannon_ball/shell/tank/AP125
	atype = "AP"
	caliber = 125
	heavy_armor_penetration = 115
	damage = 140
/obj/item/cannon_ball/shell/tank/APCR125
	atype = "APCR"
	caliber = 125
	heavy_armor_penetration = 135
	damage = 100

/obj/item/cannon_ball/shell/tank/HE88
	atype = "HE"
	caliber = 88
	heavy_armor_penetration = 20
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

/obj/item/cannon_ball/shell/naval
	icon = 'icons/obj/cannon_ball.dmi'
	name = "naval shell"
	icon_state = "navalshell"
	w_class = ITEM_SIZE_GARGANTUAN
	value = 20
	caliber = 100
	heavy_armor_penetration = 15
	atype = "HE"
	New()
		..()
		name = "[caliber]mm [atype] shell"
		icon_state = "navalshell"

/obj/item/cannon_ball/shell/naval/HE150
	atype = "HE"
	caliber = 150
	heavy_armor_penetration = 80
	damage = 350

/obj/item/cannon_ball/shell/naval/HE380
	atype = "HE"
	caliber = 380
	heavy_armor_penetration = 120
	damage = 650

// Mortar

/obj/item/cannon_ball/mortar_shell
	icon = 'icons/obj/cannon_ball.dmi'
	name = "mortar shell"
	icon_state = "shell_mortar"
	desc = "A small mortar shell, keep it safe and sound otherwise it might explode."
	w_class = ITEM_SIZE_NORMAL //simplified logistics, 60mm shell is smaller than a 160mm artillery shell
	value = 20

/obj/item/cannon_ball/mortar_shell/ex_act()
	var/turf/t = get_turf(src)
	explosion(t,1,1,1,1)
	qdel(src)

/obj/item/cannon_ball/mortar_shell/bullet_act(var/obj/item/projectile/proj, def_zone)
	var/turf/t = get_turf(src)
	if (prob(5))
		playsound(t, 'sound/effects/smoke.ogg', 10, TRUE, -3)
		explosion(t,0,1,1,1)
		visible_message(SPAN_DANGER("<big>\The [src] is hit by a projectile causing it to explode!</big>"))
		qdel(src)

/obj/item/cannon_ball/mortar_shell/fire_act(temperature)
	var/turf/t = get_turf(src)
	if (temperature > T0C+500)
		if (prob(20))
			explosion(t,0,1,1,1)
			visible_message(SPAN_DANGER("<big>\The [src] cooks-off and explodes!</big>"))
			qdel(src)


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
	reagent_payload = "chlorine"
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
	name = "Nuclear Rocket"
	desc = "You might want to step back a bit..."
	icon_state = "rocket_nuclear"
	value = 80
	atype = "NUCLEAR"

/obj/item/cannon_ball/shell/nuclear
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Nuclear Shell"
	desc = "A nuclear shell"
	icon_state = "shell_nuclear"
	value = 80
	atype = "NUCLEAR"

/obj/item/cannon_ball/shell/nuclear/nomads
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Nuclear Shell"
	desc = "A nuclear shell, once the genie is out of the bottle you can't put it back in..."
	icon_state = "shell_nuclear"
	value = 60

/obj/item/cannon_ball/shell/nuclear/W9
	icon = 'icons/obj/cannon_ball.dmi'
	name = "W9 Atomic Demolition Munition"
	desc = "A W9 nuclear shell"
	icon_state = "shell_nuclear"
	value = 80

/obj/item/cannon_ball/shell/nuclear/W19
	icon = 'icons/obj/cannon_ball.dmi'
	name = "W19 Katie Nuclear Shell"
	desc = "A W19 Katie nuclear shell"
	icon_state = "shell_nuclear"
	atype = "NUCLEAR"
	value = 80

/obj/item/cannon_ball/shell/nuclear/W33
	icon = 'icons/obj/cannon_ball.dmi'
	name = "W33 Nuclear Shell"
	desc = "A W33 nuclear shell"
	icon_state = "shell_nuclear"
	value = 80

/obj/item/cannon_ball/shell/nuclear/W33Boosted
	icon = 'icons/obj/cannon_ball.dmi'
	name = "Boosted W33 Nuclear Shell"
	desc = "A boosted nuclear shell for extra destruction"
	icon_state = "shell_nuclear_boosted"
	value = 80


////////////////////////////////////////////////////////
/obj/structure/shellrack
	icon = 'icons/obj/structures.dmi'
	name = "shell rack"
	desc = "A rack for storage your explosive goods."
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
	storage.can_hold = list(/obj/item/cannon_ball/shell,/obj/item/cannon_ball/rocket)
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

/obj/structure/shellrack/autoloader
	name = "shell rack"
	desc = "A rack for storage your explosive goods. This one designed to feed into an autoloader, neat!"
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/shellrack/autoloader/full100/New()
	..()
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/HE100(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/AP100(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/APCR100(storage)
	update_icon()

/obj/structure/shellrack/autoloader/full125/New()
	..()
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/HE125(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/AP125(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/APCR125(storage)
	update_icon()

/obj/structure/shellrack/full57/New()
	..()
	for (var/i=1, i<=6, i++)
		new /obj/item/cannon_ball/shell/tank/HE57(storage)
	for (var/i=1, i<=5, i++)
		new /obj/item/cannon_ball/shell/tank/AP57(storage)
	for (var/i=1, i<=5, i++)
		new /obj/item/cannon_ball/shell/tank/APCR57(storage)
	update_icon()

/obj/structure/shellrack/full45/New()
	..()
	for (var/i=1, i<=6, i++)
		new /obj/item/cannon_ball/shell/tank/HE45(storage)
	for (var/i=1, i<=5, i++)
		new /obj/item/cannon_ball/shell/tank/AP45(storage)
	for (var/i=1, i<=5, i++)
		new /obj/item/cannon_ball/shell/tank/APCR45(storage)
	update_icon()

/obj/structure/shellrack/full75/New()
	..()
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/HE75(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/AP75(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/APCR75(storage)
	update_icon()

/obj/structure/shellrack/full75/american/New()
	..()
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/HE75(storage)
	update_icon()

/obj/structure/shellrack/full100/New()
	..()
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/HE100(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/AP100(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/APCR100(storage)
	update_icon()


/obj/structure/shellrack/full120/New()
	..()
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/HE120(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/AP120(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/APCR120(storage)
	update_icon()

/obj/structure/shellrack/full125/New()
	..()
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/HE125(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/AP125(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/APCR125(storage)
	update_icon()

/obj/structure/shellrack/full85/New()
	..()
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/HE85(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/AP85(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/APCR85(storage)

/obj/structure/shellrack/full88/New()
	..()
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/HE88(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/AP88(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/APCR88(storage)
	update_icon()

/obj/structure/shellrack/full76/New()
	..()
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/HE76(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/AP76(storage)
	for (var/i=1, i<=4, i++)
		new /obj/item/cannon_ball/shell/tank/APCR76(storage)
	update_icon()

/obj/structure/shellrack/full204/New()
	..()
	for (var/i=1, i<=6, i++)
		new /obj/item/cannon_ball/shell/tank/HE204(storage)
	for (var/i=1, i<=5, i++)
		new /obj/item/cannon_ball/shell/tank/AP204(storage)
	for (var/i=1, i<=5, i++)
		new /obj/item/cannon_ball/shell/tank/APCR204(storage)
	update_icon()

/obj/structure/shellrack/fullrocket/New()
	..()
	for (var/i=1, i<=16, i++)
		new /obj/item/cannon_ball/rocket(storage)
	update_icon()