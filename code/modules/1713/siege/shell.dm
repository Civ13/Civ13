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
		name = "[caliber]mm artillery shell"
		icon_state = "shell[atype]"

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