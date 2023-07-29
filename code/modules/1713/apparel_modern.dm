/*Index*/
/* * - 1 Armor Plates
   * - 1a Armored Plate Suits
   * - 1b Carrier & Plate Carrier Vests
   /////////////////////////////////////
   * - 2 Us Army
   * - 2a Us Army Armor
   * - 2a1 PASGT Armor
   * - 2a2 US Lightwieght Helmets
   * - 2b US Army Clothing
   /////////////////////////////////////
   * - 3 USSR helmets
   * - 4 Hezbollah
   /////////////////////////////////////
   * - 5 Insurgents
   * - 5a Insurgent Clothing
   * - 5b Insurgent Objects
   * - 6 IDF Armor & Clothing
   /////////////////////////////////////
   * - 7 Kevlar Suits & Helmets
   * - 8 Motorist
   * - 9 Punk
   /////////////////////////////////////
   * - 10 Emergency Services
   * - 10a Emergency Services Armor
   * - 10b Emergency Services Clothing
   * - 10c Emergency Services Objects
   /////////////////////////////////////
   * - 11 Miscallenous
   * - 11a Tactical
   * - 11b IOG armor
   * - 11c Scrap Armor*/
   /////////////////////////////////////

// Foreword - Objects of this Category are typically late Cold War to present, in a range of 1960 - 2013
// as such, more thing need to be properly distributed to apparel_coldwar.dm when time allows.

/obj/item/clothing/accessory/armor/coldwar/plates
	var/slots = 2
	var/obj/item/weapon/storage/internal/hold

/obj/item/clothing/accessory/armor/coldwar/plates/New()
	..()
	hold = new/obj/item/weapon/storage/internal(src)
	hold.storage_slots = slots
	hold.can_hold = list(/obj/item/weapon/armorplates,)

/obj/item/clothing/accessory/armor/coldwar/plates/attack_hand(mob/user as mob)
	if (has_suit)	//if we are part of a suit
		hold.open(user)
		return

	if (hold.handle_attack_hand(user))	//otherwise interact as a regular storage item
		..(user)

/obj/item/clothing/accessory/armor/coldwar/plates/MouseDrop(obj/over_object as obj)
	if (has_suit)
		return

	if (hold.handle_mousedrop(usr, over_object))
		..(over_object)

/obj/item/clothing/accessory/armor/coldwar/plates/attackby(obj/item/W as obj, mob/user as mob)
	return hold.attackby(W, user)

/obj/item/clothing/accessory/armor/coldwar/plates/emp_act(severity)
	hold.emp_act(severity)
	..()

/obj/item/clothing/accessory/armor/coldwar/plates/attack_self(mob/user as mob)
	user << "<span class='notice'>You empty [src].</span>"
	var/turf/T = get_turf(src)
	hold.hide_from(usr)
	for (var/obj/item/I in hold.contents)
		hold.remove_from_storage(I, T)
	add_fingerprint(user)

/* Armor Plates*/

/obj/item/weapon/armorplates
	name = "ballistic plates"
	desc = "Used to increase the protection of some body armors."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "plates"
	item_state = "plates"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 8.0
	throwforce = 6.0

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = TRUE
	w_class = 2.0

/obj/item/weapon/armorplatesswimmer
	name = "swimmer plate"
	desc = "Used to increase the protection of some body armors."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "swimmerplate"
	item_state = "swimmerplate"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 8.0
	throwforce = 6.0

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = TRUE
	w_class = 2.0

/obj/item/weapon/armorplatessharpshooter
	name = "sharpshooter plate"
	desc = "Used to increase the protection of some body armors."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "sharpshooter"
	item_state = "sharpshooter"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 8.0
	throwforce = 6.0

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = TRUE
	w_class = 2.0

/obj/item/weapon/armorplate
	name = "armor plate"
	desc = "Used to increase the protection of some body armors."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "plate1"
	item_state = "plate1"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 8.0
	throwforce = 6.0

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = TRUE
	w_class = 2.0

/obj/item/clothing/accessory/armor/knee_protections
	name = "knee protections"
	desc = "Used to increase the protection of the legs."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "knee_protections"
	item_state = "knee_protections"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 6.0
	throwforce = 3.0
	slot = "leg_armor"

	attack_verb = list("bashed", "bludgeoned", "whacked")
	body_parts_covered = LEGS
	armor = list(melee = 75, arrow = 50, gun = 15, energy = 25, bomb = 55, bio = 20, rad = FALSE)
	slowdown = 0.1
	sharp = FALSE
	edge = TRUE
	w_class = 2.0

/obj/item/clothing/accessory/armor/legguards
	name = "leg guards"
	desc = "Used to increase the protection of the legs."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "legguards"
	item_state = "legguards"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 6.0
	throwforce = 3.0
	slot = "leg_armor"

	attack_verb = list("bashed", "bludgeoned", "whacked")
	body_parts_covered = LEGS
	armor = list(melee = 75, arrow = 50, gun = 30, energy = 32, bomb = 55, bio = 20, rad = FALSE)
	slowdown = 0.3
	sharp = FALSE
	edge = TRUE
	w_class = 2.0

/obj/item/clothing/accessory/armor/elbow_protections
	name = "elbow protections"
	desc = "Used to increase the protection of the arms."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "elbow_protections"
	item_state = "elbow_protections"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 6.0
	throwforce = 3.0
	slot = "arm_armor"

	attack_verb = list("bashed", "bludgeoned", "whacked")
	body_parts_covered = ARMS
	armor = list(melee = 65, arrow = 45, gun = 15, energy = 25, bomb = 55, bio = 20, rad = FALSE)
	slowdown = 0.1
	sharp = FALSE
	edge = TRUE
	w_class = 2.0

/obj/item/clothing/accessory/armor/armguards
	name = "arm guards"
	desc = "Used to increase the protection of the arms."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "armguards"
	item_state = "armguards"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 6.0
	throwforce = 3.0
	slot = "arm_armor"

	attack_verb = list("bashed", "bludgeoned", "whacked")
	body_parts_covered = ARMS
	armor = list(melee = 75, arrow = 50, gun = 30, energy = 32, bomb = 55, bio = 20, rad = FALSE)
	slowdown = 0.1
	sharp = FALSE
	edge = TRUE
	w_class = 2.0

	/* Armored Plate Suits*/

/obj/item/clothing/accessory/armor/coldwar/plates/interceptor
	name = "black Interceptor Body Armor"
	desc = "Wearable armor that can stop even some rifle rounds. Can be fitted with plates to increase protection."
	icon_state = "iba_black"
	item_state = "iba_black"
	worn_state = "iba_black"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 75, arrow = 100, gun = 65, energy = 25, bomb = 65, bio = 20, rad = FALSE)
	value = 120
	slowdown = 0.4
	w_class = 4
	weight = 6

/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ucp
	name = "UCP Interceptor Body Armor"
	desc = "Wearable armor that can stop even some rifle rounds. Can be fitted with plates to increase protection. This one has the Universal Camouflage Pattern."
	icon_state = "iba_ucp"
	item_state = "iba_ucp"
	worn_state = "iba_ucp"

/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp
	name = "OCP Interceptor Body Armor"
	desc = "Wearable armor that can stop even some rifle rounds. Can be fitted with plates to increase protection. This one has the Operational Camouflage Pattern."
	icon_state = "iba_ocp"
	item_state = "iba_ocp"
	worn_state = "iba_ocp"

	/* Carrier & Plate Carrier Vests */

/obj/item/clothing/accessory/armor/coldwar/platecarrier
	name = "tan plate carrier"
	desc = "A plate carrier that can store magazines and pouches. This one is tan."
	icon_state = "platecarrier_tan"
	item_state = "platecarrier_tan"
	worn_state = "platecarrier_tan"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 30, arrow = 20, gun = 0, energy = 20, bomb = 30, bio = 20, rad = FALSE)
	value = 130
	slowdown = 0.1
	w_class = 4
	weight = 1.0

/obj/item/clothing/accessory/armor/coldwar/platecarriergreen
	name = "olive plate carrier"
	desc = "A plate carrier that can store magazines and pouches. This one is olive."
	icon_state = "platecarrier_green"
	item_state = "platecarrier_green"
	worn_state = "platecarrier_green"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 30, arrow = 20, gun = 0, energy = 20, bomb = 30, bio = 20, rad = FALSE)
	value = 130
	slowdown = 0.1
	w_class = 4
	weight = 1.0

/obj/item/clothing/accessory/armor/coldwar/platecarrierblack
	name = "black plate carrier"
	desc = "A plate carrier that can store magazines and pouches. This one is black."
	icon_state = "platecarrier_black"
	item_state = "platecarrier_black"
	worn_state = "platecarrier_black"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 30, arrow = 20, gun = 0, energy = 20, bomb = 30, bio = 20, rad = FALSE)
	value = 130
	slowdown = 0.1
	w_class = 4
	weight = 1.0

/obj/item/clothing/accessory/armor/nomads/pcarriertan
	name = "tan carrier vest"
	desc = "A kevlar vest with pouches, it is tan."
	icon_state = "pcarrier_tan"
	item_state = "pcarrier_tan"
	worn_state = "pcarrier_tan"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 65, arrow = 95, gun = 76, energy = 22, bomb = 60, bio = 20, rad = FALSE)
	value = 90
	slowdown = 0.35
	w_class = 4
	weight = 3.8

/obj/item/clothing/accessory/armor/nomads/pcarrierblack
	name = "black carrier vest"
	desc = "A kevlar vest with pouches, it is black."
	icon_state = "pcarrier_black"
	item_state = "pcarrier_black"
	worn_state = "pcarrier_black"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 65, arrow = 95, gun = 76, energy = 22, bomb = 60, bio = 20, rad = FALSE)
	value = 90
	slowdown = 0.35
	w_class = 4
	weight = 3.8

/obj/item/clothing/accessory/armor/nomads/thickcarrier
	name = "heavy carrier vest"
	desc = "A tan carrier vest for holding various items."
	icon_state = "thickcarrier"
	item_state = "thickcarrier"
	worn_state = "thickcarrier"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 30, arrow = 30, gun = 78, energy = 16, bomb = 30, bio = 15, rad = FALSE)
	value = 90
	slowdown = 0.10
	w_class = 3
	weight = 3.0


/* Us Army*/

	/* Us Army Armor*/

		/* PASGT Armor*/

/obj/item/clothing/head/helmet/modern/pasgt
	name = "PASGT helmet"
	desc = "A typical US Army PASGT helmet. This one is in U.S. Woodland pattern."
	icon_state = "pasgt_woodland"
	item_state = "pasgt_woodland"
	worn_state = "pasgt_woodland"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 62, arrow = 55, gun = 21, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/pasgt/desert
	name = "PASGT helmet"
	desc = "A typical US Army PASGT helmet. This one is in U.S. Desert pattern."
	icon_state = "pasgt_desert"
	item_state = "pasgt_desert"
	worn_state = "pasgt_desert"

/obj/item/clothing/head/helmet/modern/pasgt/desert/New()
	..()
	if (prob(50))
		icon_state = "pasgt_desert_attachments"
		item_state = "pasgt_desert_attachments"
		worn_state = "pasgt_desert_attachments"
		update_icon()

/obj/item/clothing/accessory/armor/coldwar/pasgt
	name = "woodland PASGT body armor"
	desc = "Wearable armor that can stop most pistol rounds. This one is in U.S. Woodland pattern."
	icon_state = "pasgt_woodland"
	item_state = "pasgt_woodland"
	worn_state = "pasgt_woodland"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 67, arrow = 95, gun = 52, energy = 22, bomb = 60, bio = 20, rad = FALSE)
	value = 90
	slowdown = 0.3
	w_class = 4
	weight = 3.8

/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki
	name = "khaki PASGT body armor"
	desc = "Wearable armor that can stop most pistol rounds. This one is khaki colored."
	icon_state = "pasgt_khaki"
	item_state = "pasgt_khaki"
	worn_state = "pasgt_khaki"

		/* US Lightwieght Helmets*/

/obj/item/clothing/head/helmet/modern/lwh
	name = "LWH helmet"
	desc = "A typical US Army LightWeight Helmet. This one is in beige color."
	icon_state = "lwh_desert"
	item_state = "lwh_desert"
	worn_state = "lwh_desert"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 68, arrow = 67, gun = 27, energy = 18, bomb = 65, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/lwh/black
	name = "black LWH helmet"
	desc = "A typical US Army LightWeight Helmet. This one is in black color."
	icon_state = "lwh_black"
	item_state = "lwh_black"
	worn_state = "lwh_black"

/obj/item/clothing/head/helmet/modern/ach
	name = "OCP ACH helmet"
	desc = "A typical US Army Advanced Combat Helmet. This one is in OCP cammo."
	icon_state = "ach_ocp"
	item_state = "ach_ocp"
	worn_state = "ach_ocp"

	/* US Army Clothing*/

/obj/item/clothing/under/us_uni/us_camo_dcu
	name = "desert camouflage uniform"
	desc = "The standard US Army desert camo uniform the late 20th century."
	icon_state = "us_camo_dcu"
	item_state = "us_camo_dcu"
	worn_state = "us_camo_dcu"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_camo_woodland
	name = "woodland camouflage uniform"
	desc = "The standard US Army camo uniform the late 20th century."
	icon_state = "us_camo_woodland"
	item_state = "us_camo_woodland"
	worn_state = "us_camo_woodland"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_camo_ucp
	name = "UCP camo uniform"
	desc = "The standard US Army camo uniform the early 21st century."
	icon_state = "us_camo_ucp"
	item_state = "us_camo_ucp"
	worn_state = "us_camo_ucp"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_camo_ocp
	name = "OCP camo uniform"
	desc = "The standard US Army camo uniform from 2018 onwards."
	icon_state = "us_camo_ocp"
	item_state = "us_camo_ocp"
	worn_state = "us_camo_ocp"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_lightuni_modern
	name = "U.S. Army training uniform"
	desc = "An informal outfit made of OCP pattern trousers and a olive drab shirt."
	icon_state = "us_lightuni_modern"
	item_state = "us_lightuni_modern"
	worn_state = "us_lightuni_modern"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS

/obj/item/clothing/gloves/fingerless
	name = "fingerless black gloves"
	icon_state = "fingerless"
	item_state = "fingerless"
	body_parts_covered = HANDS
	slot_flags = SLOT_GLOVES

/* USSR Helmets*/

/obj/item/clothing/head/helmet/modern/sovietfacehelmet
	name = "MASKA 1 helmet"
	desc = "A USSR heavy armoured helmet with a slitted facemask."
	icon_state = "sovietfacehelmet"
	item_state = "sovietfacehelmet"
	worn_state = "sovietfacehelmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 90, arrow = 110, gun = 96, energy = 27, bomb = 76, bio = 30, rad = FALSE)

/obj/item/clothing/head/helmet/modern/sovietfacehelmet/welding
	name = "K6-3 helmet"
	desc = "A USSR heavy armoured helmet with a welding visor facemask."
	icon_state = "sovietfacehelmet" //wip
	item_state = "sovietfacehelmet"
	worn_state = "sovietfacehelmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 90, arrow = 110, gun = 96, energy = 27, bomb = 76, bio = 30, rad = FALSE)

/obj/item/clothing/head/helmet/modern/sovietfacehelmet/nomads
	name = "MASKA 1 helmet"
	desc = "A USSR heavy armoured helmet with a slitted facemask."
	icon_state = "sovietfacehelmet_o"
	item_state = "sovietfacehelmet_o"
	worn_state = "sovietfacehelmet_o"
	armor = list(melee = 85, arrow = 110, gun = 95, energy = 25, bomb = 75, bio = 30, rad = FALSE)
	health = 80
	slowdown = 0.45
	var/toggled = FALSE

/obj/item/clothing/head/helmet/modern/sovietfacehelmet/nomads/verb/toggle_visor()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/modern/sovietfacehelmet/nomads)
		return
	else
		if (toggled)
			item_state = "sovietfacehelmet_o"
			icon_state = "sovietfacehelmet_o"
			worn_state = "sovietfacehelmet_o"
			item_state_slots["slot_head"] = "sovietfacehelmet_o"
			usr << "<span class = 'danger'>You put up your helmet's visor.</span>"
			toggled = FALSE
			update_clothing_icon()
			body_parts_covered = HEAD
			flags_inv = BLOCKHEADHAIR
		else if (!toggled)
			item_state = "sovietfacehelmet"
			icon_state = "sovietfacehelmet"
			worn_state = "sovietfacehelmet"
			item_state_slots["slot_head"] = "sovietfacehelmet"
			usr << "<span class = 'danger'>You put down your helmet's visor.</span>"
			toggled = TRUE
			update_clothing_icon()
			body_parts_covered = HEAD|FACE
			flags_inv = BLOCKHAIR

/obj/item/clothing/head/helmet/modern/sovietfacehelmet/welding/nomads //also known as the
	name = "K6-3 helmet"
	desc = "A russian heavy armoured helmet with a welding visor facemask."
	icon_state = "sovietface_weldhelmet"
	item_state = "sovietface_weldhelmet"
	worn_state = "sovietface_weldhelmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 85, arrow = 110, gun = 95, energy = 25, bomb = 75, bio = 30, rad = FALSE)
	health = 80
	slowdown = 0.45
	var/toggled = FALSE

/obj/item/clothing/head/helmet/modern/sovietfacehelmet/welding/nomads/verb/toggle_visor()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/modern/sovietfacehelmet/welding/nomads)
		return
	else
		if (toggled)
			item_state = "sovietface_weldhelmet_o"
			icon_state = "sovietface_weldhelmet_o"
			worn_state = "sovietface_weldhelmet_o"
			item_state_slots["slot_head"] = "sovietface_weldhelmet_o"
			usr << "<span class = 'danger'>You put up your helmet's visor.</span>"
			toggled = FALSE
			update_clothing_icon()
			body_parts_covered = HEAD
			flags_inv = BLOCKHEADHAIR
		else if (!toggled)
			item_state = "sovietface_weldhelmet"
			icon_state = "sovietface_weldhelmet"
			worn_state = "sovietface_weldhelmet"
			item_state_slots["slot_head"] = "sovietface_weldhelmet"
			usr << "<span class = 'danger'>You put down your helmet's visor.</span>"
			toggled = TRUE
			update_clothing_icon()
			body_parts_covered = HEAD|FACE|EYES
			flags_inv = BLOCKHAIR

/obj/item/clothing/head/helmet/modern/a6b47 //Post 2000 helmet more modern.
	name = "6B47 helmet"
	desc = "A russian heavy armoured helmet often used by russian infantry forces in the 21st century."
	icon_state = "a6b47"
	item_state = "a6b47"
	worn_state = "a6b47"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 60, arrow = 100, gun = 86, energy = 27, bomb = 76, bio = 30, rad = FALSE)

/obj/item/clothing/head/helmet/modern/zsh1 //1990's helmet for reference, specific date unknown.
	name = "ZSh-1 helmet"
	desc = "A russian heavy armoured helmet, often used by USSR infantry forces in the late 20th century."
	icon_state = "zsh1"
	item_state = "zsh1"
	worn_state = "zsh1"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 80, arrow = 100, gun = 95, energy = 36, bomb = 76, bio = 30, rad = FALSE)

/obj/item/clothing/head/helmet/modern/zsh2 //Post 2000 helmet like description suggests
	name = "ZSh-2 helmet"
	desc = "A russian heavy armoured helmet with a visor; often used by russian infantry forces in the 21st century."
	icon_state = "zsh2"
	item_state = "zsh2"
	worn_state = "zsh2"
	body_parts_covered = HEAD|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 84, arrow = 104, gun = 98, energy = 38, bomb = 79, bio = 34, rad = FALSE)

/* Hezbollah*/

/obj/item/clothing/under/us_uni/us_camo_woodland/hezbollah
	name = "woodland camouflage uniform"
	desc = "The standard US Army camo uniform the late 20th century, with Hezbollah insiginia."
	icon_state = "us_camo_woodland_hez"
	item_state = "us_camo_woodland_hez"
	worn_state = "us_camo_woodland_hez"

/obj/item/clothing/under/us_uni/us_camo_woodland/hezbollah/officer
	name = "woodland camouflage uniform"
	desc = "The standard US Army camo uniform the late 20th century, with Hezbollah insiginia of an officer."
	icon_state = "us_camo_woodland_hez_officer"
	item_state = "us_camo_woodland_hez_officer"
	worn_state = "us_camo_woodland_hez_officer"

/* Insurgents*/
	/* Insurgent Clothing*/

/obj/item/clothing/under/insurgent_black
	name = "black tunic"
	desc = "An all black tunic and trousers outfit."
	icon_state = "insurgent_black"
	item_state = "insurgent_black"
	worn_state = "insurgent_black"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/insurgent_sand
	name = "sand-colored tunic"
	desc = "A dark yellow, sand-colored tunic and trousers outfit."
	icon_state = "insurgent_sand"
	item_state = "insurgent_sand"
	worn_state = "insurgent_sand"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/insurgent_sand_woodland
	name = "sand-colored tunic with woodland camo trousers"
	desc = "A dark yellow, sand-colored tunic with woodland camo trousers."
	icon_state = "insurgent_sand_woodland"
	item_state = "insurgent_sand_woodland"
	worn_state = "insurgent_sand_woodland"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/insurgent_sand_dcu
	name = "sand-colored uniform with desert camo trousers"
	desc = "A dark yellow, sand-colored uniform with desert camo trousers."
	icon_state = "insurgent_sand_dcu"
	item_state = "insurgent_sand_dcu"
	worn_state = "insurgent_sand_dcu"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/insurgent_sand_green
	name = "light brown uniform with green trousers"
	desc = "A light brown uniform with green trousers."
	icon_state = "insurgent_sand_green"
	item_state = "insurgent_sand_green"
	worn_state = "insurgent_sand_green"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/insurgent_leader
	name = "black tunic with desert camo trousers"
	desc = "A black tunic with desert camo trousers, worn by insurgent leaders."
	icon_state = "insurgent_leader"
	item_state = "insurgent_leader"
	worn_state = "insurgent_leader"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/head/black_bandana
	name = "black bandana"
	desc = "A light black piece of cloth worn wrapped around the head."
	icon_state = "black_bandana"
	item_state = "black_bandana"
	body_parts_covered = HEAD

/obj/item/clothing/head/black_shemagh
	name = "black shemagh"
	desc = "A light black piece of cloth worn loosely wrapped around the head, typical of middle-east countries."
	icon_state = "black_shemagh"
	item_state = "black_shemagh"
	body_parts_covered = HEAD
	heat_protection = HEAD|FACE|EYES

	/* Insurgent Objects*/

/obj/item/weapon/material/sword/arabsword
	name = "ceremonial saif sword"
	desc = "A ceremonial reproduction of a saif with a thin, stright blade. Commonly used by officers and nobility."
	icon_state = "arabsword1"
	item_state = "longsword"
	throw_speed = 4
	throw_range = 5
	force_divisor = 0.75 // 45 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 14 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 26
	cooldownw = 9
	value = 60

/obj/item/weapon/material/sword/arabsword2
	name = "ceremonial scimitar sword"
	desc = "A ceremonial reproduction of a scimitar with thin, curved blade. Commonly used by officers and nobility."
	icon_state = "arabsword2"
	item_state = "longsword"
	throw_speed = 4
	throw_range = 5
	force_divisor = 0.79 // 45 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 14 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 26
	cooldownw = 10
	value = 60

	/* IDF Armor & Clothing*/

/obj/item/clothing/under/idf
	name = "IDF olive uniform"
	desc = "The plain olive coloured uniform of the Israeli Defense Forces."
	icon_state = "idf_olive"
	item_state = "idf_olive"
	worn_state = "idf_olive"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS

/obj/item/clothing/head/helmet/modern/idf
	name = "IDF helmet"
	desc = "A typical IDF helmet. This one is in IDF olive green."
	icon_state = "idf"
	item_state = "idf1"
	worn_state = "idf1"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 62, arrow = 55, gun = 21, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/idf/New()
	..()
	item_state = pick("idf1","idf2","idf3")
	worn_state = item_state

/obj/item/clothing/accessory/armor/coldwar/idf
	name = "Masada body armor"
	desc = "Israeli wearable armor that can stop most pistol rounds. This one is green."
	icon_state = "greenkevlarvest"
	item_state = "greenkevlarvest"
	worn_state = "greenkevlarvest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 67, arrow = 95, gun = 52, energy = 22, bomb = 60, bio = 20, rad = FALSE)
	value = 90
	slowdown = 0.3
	w_class = 4
	weight = 3.8

/* Kevlar Suits & Helmets*/

/obj/item/clothing/accessory/armor/nomads/kevlarblack
	name = "black kevlar vest"
	desc = "Standard kevlar, can stop low caliber bullets. This one is black."
	icon_state = "kevlarvest"
	item_state = "kevlarvest"
	worn_state = "kevlarvest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS|LEGS
	armor = list(melee = 80, arrow = 95, gun = 95, energy = 35, bomb = 64, bio = 20, rad = FALSE)
	value = 90
	slowdown = 0.4
	w_class = 4
	weight = 3.8

/obj/item/clothing/accessory/armor/nomads/civiliankevlar
	name = "civilian kevlar vest"
	desc = "A black kevlar vest for commercial use."
	icon_state = "civilianvest"
	item_state = "civilianvest"
	worn_state = "civilianvest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 90, gun = 72, energy = 22, bomb = 60, bio = 20, rad = FALSE)
	value = 90
	slowdown = 0.30
	w_class = 4
	weight = 3.6

/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under //for TDM maps, showing under the clothing

/obj/item/clothing/head/helmet/kevlarhelmet
	name = "black kevlar helmet"
	desc = "A standard bulletproof helmet, made of kevlar."
	icon_state = "kevlarhelmet"
	item_state = "kevlarhelmet"
	worn_state = "kevlarhelmet"
	body_parts_covered = HEAD
	armor = list(melee = 65, arrow = 95, gun = 73, energy = 22, bomb = 60, bio = 20, rad = FALSE)
	flags_inv = BLOCKHAIR
	restricts_view = 2
	health = 90

/* Motorist*/

/obj/item/clothing/head/helmet/motorcycle
	name = "motorcycle helmet"
	desc = "Protects your head from injuries if you crash your bike."
	icon_state = "motorcycle"
	item_state = "motorcycle"
	worn_state = "motorcycle"
	body_parts_covered = FACE|EYES|HEAD
	restricts_view = 2
	flags_inv = HIDEMASK|BLOCKHAIR|BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 65, gun = 5, energy = 35, bomb = 35, bio = 30, rad = FALSE)

/obj/item/clothing/under/motorist
	name = "motorist outfit"
	desc = "A casual jeans and white shirt combo, often worn by tofu deliveryboy's"
	icon_state = "motorist"
	item_state = "motorist"
	worn_state = "motorist"

/obj/item/clothing/gloves/motorist
	name = "black motorist gloves"
	icon_state = "motorist"
	item_state = "motorist"
	worn_state = "motorist"
	body_parts_covered = HANDS
	slot_flags = SLOT_GLOVES

/obj/item/clothing/shoes/sneakers/courier
	name = "courier sneakers"
	desc = "A pair of simple, thin grey sneakers."
	icon_state = "courier_sneakers"
	item_state = "courier_sneakers"
	worn_state = "courier_sneakers"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 10, arrow = 10, gun = FALSE, energy = 8, bomb = 10, bio = 10, rad = 25)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/suit/storage/jacket/motorist
	name = "motorist jacket"
	desc = "A jacket often worn by enthusiasts of vehicles, speed and the smell of burning rubber."
	icon_state = "motorist_jacket"
	item_state = "motorist_jacket"
	worn_state = "motorist_jacket"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)

/* Punk */

/obj/item/clothing/under/punk
	name = "punk outfit"
	desc = "A rowdy alternative culture purple sleeveless shirt and purple trousers for bringing down the establishment."
	icon_state = "punk"
	item_state = "punk"
	worn_state = "punk"

/obj/item/clothing/accessory/armband/punk
	name = "spiked bracers"
	desc = "A pair of punkish spiked bracers."
	icon_state = "spiked_bracers"
	item_state = "spiked_bracers"
	worn_state = "spiked_bracers"

/obj/item/clothing/shoes/punk
	name = "punk boots"
	desc = "A pair of stylized high leather boots for kicking the snot out of 'The Man'."
	icon_state = "punk"
	item_state = "punk"
	worn_state = "punk"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 20, arrow = 10, gun = FALSE, energy = 8, bomb = 10, bio = 10, rad = 25)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/suit/storage/jacket/punk
	name = "punk jacket"
	desc = "A loose jacket often worn by counter-cultural types, commonly additional inscriptions can be found on the back."
	icon_state = "punk_vest"
	item_state = "punk_vest"
	worn_state = "punk_vest"
	body_parts_covered = UPPER_TORSO
	cold_protection = UPPER_TORSO
	armor = list(melee = 15, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)

/* Emergency Services*/

	/* Emergency Services Armor*/

/obj/item/clothing/head/helmet/swat
	name = "swat helmet"
	desc = "A standard kevlar helmet used by swat officers."
	icon_state = "swat"
	item_state = "swat"
	worn_state = "swat"
	body_parts_covered = HEAD
	armor = list(melee = 65, arrow = 95, gun = 85, energy = 27, bomb = 64, bio = 20, rad = FALSE)
	flags_inv = BLOCKHAIR
	restricts_view = 2
	health = 90

	/* Emergency Services Clothing*/

/obj/item/clothing/suit/storage/jacket/highvis
	name = "high visibility jacket"
	desc = "A yellow high visibility jacket."
	icon_state = "high_vis_jacket_yellow"
	item_state = "high_vis_jacket_yellow"
	worn_state = "high_vis_jacket_yellow"

/obj/item/clothing/suit/storage/jacket/highvis/paramedic
	name = "paramedic jacket"
	icon_state = "paramedic_jacket"
	item_state = "paramedic_jacket"
	worn_state = "paramedic_jacket"

	/* Emergency Services Objects*/

/obj/item/weapon/storage/belt/police
	name = "police belt"
	desc = "A belt that can hold the standard issue gear of police officers."
	icon_state = "gerbelt"
	item_state = "gerbelt"
	storage_slots = 10
	max_w_class = 3
	max_storage_space = 24
	can_hold = list(
		/obj/item/ammo_magazine,
		/obj/item/weapon/material,
		/obj/item/weapon/grenade,
		/obj/item/weapon/attachment,
		/obj/item/weapon/gun/projectile/pistol,
		/obj/item/weapon/gun/projectile/revolver,
		/obj/item/weapon/handcuffs,
		/obj/item/ammo_casing,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
		/obj/item/weapon/melee/classic_baton,
		/obj/item/weapon/melee/nightbaton,
		/obj/item/stack/medical/bruise_pack,
		/obj/item/weapon/whistle,
		/obj/item/weapon/pen,
		/obj/item/stack/money,
		/obj/item/weapon/key,
		)
/obj/item/weapon/storage/belt/police/New()
	..()
	new /obj/item/weapon/melee/nightbaton(src)
	new /obj/item/stack/medical/bruise_pack/bint(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/whistle(src)
	new /obj/item/ammo_magazine/glock17(src)
	new /obj/item/ammo_magazine/glock17(src)

/* Miscallenous*/

/obj/item/clothing/accessory/armor/nomads/baily //too broad, can't make out what detail this is actually meant to be associated with.
	name = "baily vest"
	desc = "A vest used by baily security units."
	icon_state = "bailyvest"
	item_state = "bailyvest"
	worn_state = "bailyvest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS|LEGS
	armor = list(melee = 40, arrow = 95, gun = 82, energy = 30, bomb = 35, bio = 20, rad = FALSE)
	value = 90
	slowdown = 0.2
	w_class = 3
	weight = 2

	/* Tactical*/

/obj/item/clothing/head/helmet/tactical //unsure, but a white helmet is good for peacekeeper corps until a legit code entry is made.
	name = "tactical helmet"
	desc = "A standard bulletproof helmet, made of polyethylene."
	icon_state = "tacticalhelmet"
	item_state = "tacticalhelmet"
	worn_state = "tacticalhelmet"
	body_parts_covered = HEAD
	armor = list(melee = 75, arrow = 95, gun = 93, energy = 22, bomb = 60, bio = 20, rad = FALSE)
	flags_inv = BLOCKHAIR
	restricts_view = 2
	health = 90

/obj/item/clothing/under/tacti
	name = "tactical outfit"
	desc = "A outfit used by tactical units."
	icon_state = "tacti"
	item_state = "tacti"
	worn_state = "tacti"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT

/obj/item/clothing/under/tacticool_hawaiian
	name = "tacticool hawaiian outfit"
	desc = "Assorted surplus cammo trousers with a nice hawaiian shirt for all your operating needs."
	icon_state = "tacticool_hawaiian_blue"
	item_state = "tacticool_hawaiian_blue"
	worn_state = "tacticool_hawaiian_blue"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/tacticool_hawaiian/green
	icon_state = "tacticool_hawaiian_green"
	item_state = "tacticool_hawaiian_green"
	worn_state = "tacticool_hawaiian_green"
/obj/item/clothing/under/tacticool_hawaiian/orange
	icon_state = "tacticool_hawaiian_orange"
	item_state = "tacticool_hawaiian_orange"
	worn_state = "tacticool_hawaiian_orange"
/obj/item/clothing/under/tacticool_hawaiian/purple
	icon_state = "tacticool_hawaiian_purple"
	item_state = "tacticool_hawaiian_purple"
	worn_state = "tacticool_hawaiian_purple"

/obj/item/clothing/under/boomerwaffen1
	name = "patriot outfit"
	desc = "A uniform used by patriotic American militias."
	icon_state = "boomerwaffen1"
	item_state = "boomerwaffen1"
	worn_state = "boomerwaffen1"

/obj/item/clothing/under/boomerwaffen2
	name = "patriot outfit"
	desc = "A uniform used by patriotic American militias."
	icon_state = "boomerwaffen2"
	item_state = "boomerwaffen2"
	worn_state = "boomerwaffen2"

/obj/item/clothing/under/boomerwaffen3
	name = "patriot outfit"
	desc = "A uniform used by patriotic American militias."
	icon_state = "boomerwaffen3"
	item_state = "boomerwaffen3"
	worn_state = "boomerwaffen3"

/obj/item/clothing/under/modern_shaman
	name = "modern shaman outfit"
	desc = "A modern shaman outfit."
	icon_state = "modern_shaman"
	item_state = "modern_shaman"
	worn_state = "modern_shaman"

/obj/item/clothing/head/cap
	name = "cap"
	desc = "A generic visored cap."
	icon_state = "blackcap"
	item_state = "blackcap"
	worn_state = "blackcap"
	var/base_state = "blackcap"
	var/flipped = FALSE

/obj/item/clothing/head/cap/verb/flip()
	set category = null
	set src in usr

	flipped = !flipped
	update_icon()
	/* IOG armor*/

/obj/item/clothing/head/cap/update_icon()
	..()
	if (flipped)
		icon_state = "[base_state]_flipped"
		item_state = icon_state
		worn_state = icon_state
	else
		icon_state = base_state
		item_state = icon_state
		worn_state = icon_state

/obj/item/clothing/head/cap/maga
	name = "MAGA hat"
	desc = "A red hat with \"Make America Great Again\" on the front."
	icon_state = "maga"
	item_state = "maga"
	worn_state = "maga"
	base_state = "maga"

/obj/item/clothing/head/cap/fbi
	name = "FBI hat"
	desc = "A black hat with FBI in white letters in the front."
	icon_state = "fbi"
	item_state = "fbi"
	worn_state = "fbi"
	base_state = "fbi"


/obj/item/clothing/accessory/armor/nomads/iogsuit //too broad, this is meant to be some sort of extreme sports armorwear or something.
	name = "IOG heavy vest B-7"
	desc = "A heavy suit made of strong materials."
	icon_state = "iogsuit"
	item_state = "iogsuit"
	worn_state = "iogsuit"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS|LEGS
	armor = list(melee = 110, arrow = 100, gun = 130, energy = 50, bomb = 90, bio = 100, rad = FALSE)
	value = 160
	slowdown = 0.2
	w_class = 4
	weight = 3.4

/obj/item/clothing/head/helmet/ioghelmet //too broad, this is meant to be some sort of extreme sports armorwear or something.
	name = "IOG helmet"
	desc = "A strong helmet."
	icon_state = "ioghelmet"
	item_state = "ioghelmet"
	worn_state = "ioghelmet"
	body_parts_covered = HEAD
	armor = list(melee = 95, arrow = 100, gun = 110, energy = 50, bomb = 90, bio = 45, rad = FALSE)
	flags_inv = BLOCKHAIR
	restricts_view = 1
	health = 200

/obj/item/clothing/head/helmet/iogmask1 //too broad, this is meant to be some sort of extreme sports armorwear or something.
	name = "IOG helmet"
	desc = "A strong helmet."
	icon_state = "iogmask1"
	item_state = "iogmask1"
	worn_state = "iogmask1"
	body_parts_covered = HEAD
	armor = list(melee = 95, arrow = 100, gun = 100, energy = 50, bomb = 90, bio = 45, rad = 100)
	flags_inv = BLOCKHAIR
	restricts_view = 2
	health = 200

	/* Scrap Armor*/

/obj/item/clothing/suit/armor/scrap
	name = "scrap plate armor"
	desc = "A ramshackle suit of armor, reminiscence of medieval times."
	icon_state = "scraparmor"
	item_state = "scraparmor"
	worn_state = "scraparmor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 70, arrow = 85, gun = 20, energy = 20, bomb = 50, bio = 10, rad = 40)
	value = 50
	slowdown = 1.5
	health = 65

/obj/item/clothing/head/helmet/scrap
	name = "scrap metal helmet"
	desc = "A makeshift helmet made of random metal."
	icon_state = "scraphelmet"
	item_state = "scraphelmet"
	worn_state = "scraphelmet"
	body_parts_covered = HEAD|FACE
	armor = list(melee = 70, arrow = 85, gun = 20, energy = 20, bomb = 50, bio = 10, rad = 40)
	flags_inv = BLOCKHAIR
	restricts_view = 2
	health = 60

