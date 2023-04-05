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
   * - 2c Russian Army Clothing
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
	hold.can_hold = list(/obj/item/weapon/armorplates, /obj/item/ammo_magazine,)

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
	w_class = ITEM_SIZE_SMALL

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
	w_class = ITEM_SIZE_SMALL

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
	w_class = ITEM_SIZE_SMALL

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
	w_class = ITEM_SIZE_SMALL

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
	w_class = ITEM_SIZE_SMALL

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
	w_class = ITEM_SIZE_SMALL

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
	w_class = ITEM_SIZE_SMALL

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
	w_class = ITEM_SIZE_SMALL

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
	w_class = ITEM_SIZE_LARGE
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

/obj/item/clothing/accessory/armor/coldwar/plates/platecarrier
	name = "tan plate carrier"
	desc = "A plate carrier that can store magazines and pouches. This one is tan."
	icon_state = "platecarrier_tan"
	item_state = "platecarrier_tan"
	worn_state = "platecarrier_tan"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 30, arrow = 20, gun = 40, energy = 20, bomb = 30, bio = 20, rad = FALSE)
	value = 130
	slowdown = 0.1
	w_class = ITEM_SIZE_LARGE
	weight = 1.0

/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen
	name = "olive plate carrier"
	desc = "A plate carrier that can store magazines and pouches. This one is olive."
	icon_state = "platecarrier_green"
	item_state = "platecarrier_green"
	worn_state = "platecarrier_green"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 30, arrow = 20, gun = 40, energy = 20, bomb = 30, bio = 20, rad = FALSE)
	value = 130
	slowdown = 0.1
	w_class = ITEM_SIZE_LARGE
	weight = 1.0

/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack
	name = "black plate carrier"
	desc = "A plate carrier that can store magazines and pouches. This one is black."
	icon_state = "platecarrier_black"
	item_state = "platecarrier_black"
	worn_state = "platecarrier_black"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 30, arrow = 20, gun = 40, energy = 20, bomb = 30, bio = 20, rad = FALSE)
	value = 130
	slowdown = 0.1
	w_class = ITEM_SIZE_LARGE
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
	w_class = ITEM_SIZE_LARGE
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
	w_class = ITEM_SIZE_LARGE
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
	w_class = ITEM_SIZE_NORMAL
	weight = 3.0

/obj/item/clothing/accessory/armor/coldwar/plates/platecarrier_ukraine
	name = "UARM plate carrier"
	desc = "A plate carrier that can store magazines and pouches. This one is made by UARM."
	icon_state = "ukraine_armor"
	item_state = "ukraine_armor"
	worn_state = "ukraine_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 40, arrow = 20, gun = 40, energy = 20, bomb = 30, bio = 20, rad = FALSE)
	value = 130
	slowdown = 0.1
	w_class = ITEM_SIZE_LARGE
	weight = 1.0
	slots = 3

/obj/item/clothing/accessory/armor/coldwar/plates/b45
	name = "6B45 body armor"
	desc = "A modern body armor of Russian origin."
	icon_state = "6b45"
	item_state = "6b45"
	worn_state = "6b45"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 67, arrow = 95, gun = 52, energy = 22, bomb = 60, bio = 20, rad = FALSE)
	value = 130
	slowdown = 0.2
	w_class = ITEM_SIZE_LARGE
	weight = 3.8

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
	armor = list(melee = 62, arrow = 75, gun = 55, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/pasgt/com
	icon_state = "pasgt_woodland_com"
	item_state = "pasgt_woodland_com"
	worn_state = "pasgt_woodland_com"
/obj/item/clothing/head/helmet/modern/pasgt/sl
	icon_state = "pasgt_woodland_sl"
	item_state = "pasgt_woodland_sl"
	worn_state = "pasgt_woodland_sl"
/obj/item/clothing/head/helmet/modern/pasgt/desert
	name = "PASGT helmet"
	desc = "A typical US Army PASGT helmet. This one is in U.S. Desert pattern."
	icon_state = "pasgt_desert"
	item_state = "pasgt_desert"
	worn_state = "pasgt_desert"

/obj/item/clothing/head/helmet/modern/pasgt/reddish
	name = "Red PASGT helmet"
	desc = "A typical US Army PASGT helmet. This one has a red dye."
	icon_state = "pasgt_reddish"
	item_state = "pasgt_reddish"
	worn_state = "pasgt_reddish"

/obj/item/clothing/head/helmet/modern/pasgt/white
	name = "White PASGT helmet"
	desc = "A typical US Army PASGT helmet. This one has a white dye."
	icon_state = "pasgt_white"
	item_state = "pasgt_white"
	worn_state = "pasgt_white"

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
	w_class = ITEM_SIZE_LARGE
	weight = 3.8

/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki
	name = "khaki PASGT body armor"
	desc = "Wearable armor that can stop most pistol rounds. This one is khaki colored."
	icon_state = "pasgt_khaki"
	item_state = "pasgt_khaki"
	worn_state = "pasgt_khaki"

/obj/item/clothing/accessory/armor/coldwar/pasgt/green
	name = "green PASGT body armor"
	desc = "Wearable armor that can stop most pistol rounds. This one is green colored."
	icon_state = "pasgt_green"
	item_state = "pasgt_green"
	worn_state = "pasgt_green"

/obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard
	name = "blizzard PASGT body armor"
	desc = "Wearable armor that can stop most pistol rounds. This one has a blizzard pattern."
	icon_state = "pasgt_blizzard"
	item_state = "pasgt_blizzard"
	worn_state = "pasgt_blizzard"

		/* US Lightwieght Helmets*/

/obj/item/clothing/head/helmet/modern/lwh
	name = "LWH helmet"
	desc = "A typical US Army LightWeight Helmet. This one is in beige color."
	icon_state = "lwh_desert"
	item_state = "lwh_desert"
	worn_state = "lwh_desert"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 68, arrow = 67, gun = 65, energy = 18, bomb = 65, bio = 20, rad = FALSE)

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
	body_parts_covered = HEAD
	armor = list(melee = 75, arrow = 95, gun = 93, energy = 22, bomb = 60, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/ach/green
	name = "ACH helmet"
	desc = "A typical US Army Advanced Combat Helmet. This one is in green."
	icon_state = "ach_green"
	item_state = "ach_green"
	worn_state = "ach_green"
/obj/item/clothing/head/helmet/modern/ach/white
	name = "ACH helmet"
	desc = "A typical US Army Advanced Combat Helmet. This one is in white."
	icon_state = "ach_white"
	item_state = "ach_white"
	worn_state = "ach_white"
/obj/item/clothing/head/helmet/modern/ach/green/com
	icon_state = "ach_green_com"
	item_state = "ach_green_com"
	worn_state = "ach_green_com"

/obj/item/clothing/head/helmet/modern/ach/green/sl
	icon_state = "ach_green_sl"
	item_state = "ach_green_sl"
	worn_state = "ach_green_sl"
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
	fingerprint_chance = 100

/* US belts*/

/obj/item/weapon/storage/belt/smallpouches/us/modern/m14
/obj/item/weapon/storage/belt/smallpouches/us/modern/m14/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/m14(src)
	new/obj/item/ammo_magazine/m14(src)
	new/obj/item/ammo_magazine/m14(src)


/* Russian Army Clothing*/

/obj/item/clothing/under/milrus_vsr93
	name = "russian military outfit VSR 93" //Uniform used mostly in the 90's
	desc = "An outfit composed of the VSR93 camo pants and shirt, along with a high waistbelt."
	icon_state = "milrus_vsr93"
	item_state = "milrus_vsr93"
	worn_state = "milrus_vsr93"

/obj/item/clothing/under/milrus_omon
	name = "russian OMON uniform" //Uniform used mostly in the 90's
	desc = "An outfit designed and issued for the OMON forces of the Russian Federation."
	icon_state = "milrus_omon"
	item_state = "milrus_omon"
	worn_state = "milrus_omon"

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

/obj/item/clothing/head/helmet/modern/a6b47/camo
	name = "camo 6B47 helmet"
	icon_state = "a6b47cam"
	item_state = "a6b47cam"
	worn_state = "a6b47cam"

/obj/item/clothing/head/helmet/modern/a6b47/camo/blugo
	name = "blugo 6B47 helmet"
	icon_state = "a6b47b"
	item_state = "a6b47b"
	worn_state = "a6b47b"

/obj/item/clothing/head/helmet/modern/a6b47/camo/blugo/command
	name = "blugo command 6B47 helmet"
	icon_state = "a6b47bc"
	item_state = "a6b47bc"
	worn_state = "a6b47bc"

/obj/item/clothing/head/helmet/modern/sfera //1990's helmet for reference, specific date unknown.
	name = "Sfera helmet"
	desc = "A russian combat armoured helmet, often used by internal troops in the USSR and Russia."
	icon_state = "sfera_helmet"
	item_state = "sfera_helmet"
	worn_state = "sfera_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 80, arrow = 100, gun = 95, energy = 36, bomb = 76, bio = 30, rad = FALSE)

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

/obj/item/clothing/head/ruscap_fed
	name = "Russian Federal Forces service cap"
	desc = "A cap worn by the Russian Federal Army."
	icon_state = "fieldcap_rus_fed"
	item_state = "fieldcap_rus_fed"

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
	armor = list(melee = 62, arrow = 55, gun = 51, energy = 15, bomb = 55, bio = 20, rad = FALSE)

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
	w_class = ITEM_SIZE_LARGE
	weight = 3.8

/obj/item/weapon/storage/belt/smallpouches/m24
/obj/item/weapon/storage/belt/smallpouches/m24/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/m24(src)
	new/obj/item/ammo_magazine/m24(src)
	new/obj/item/ammo_magazine/m24(src)

/* Kevlar Suits & Helmets*/

/obj/item/clothing/accessory/armor/nomads/kevlarblack
	name = "black kevlar vest"
	desc = "Standard kevlar, can stop low caliber bullets. This one is black."
	icon_state = "kevlarvest"
	item_state = "kevlarvest"
	worn_state = "kevlarvest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS|LEGS
	armor = list(melee = 80, arrow = 95, gun = 65, energy = 35, bomb = 64, bio = 20, rad = FALSE)
	value = 90
	slowdown = 0.4
	w_class = ITEM_SIZE_LARGE
	weight = 3.8

/obj/item/clothing/accessory/armor/nomads/civiliankevlar
	name = "civilian kevlar vest"
	desc = "A black kevlar vest for commercial use."
	icon_state = "civilianvest"
	item_state = "civilianvest"
	worn_state = "civilianvest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 90, gun = 52, energy = 22, bomb = 60, bio = 20, rad = FALSE)
	value = 90
	slowdown = 0.30
	w_class = ITEM_SIZE_LARGE
	weight = 3.6

/obj/item/clothing/accessory/armor/nomads/civiliankevlar/press
	name = "Press kevlar vest"
	desc = "A blue kevlar vest, with 'PRESS' written across the chest."
	icon_state = "press_kevlarvest"
	item_state = "press_kevlarvest"
	worn_state = "press_kevlarvest"

/obj/item/clothing/head/helmet/kevlarhelmet/press
	name = "Press kevlar helmet"
	desc = "A standard bulletproof helmet, made of kevlar, with 'PRESS' written across it."
	icon_state = "kevlarhelmet_press"
	item_state = "kevlarhelmet_press"
	worn_state = "kevlarhelmet_press"

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
	restricts_view = 1
	health = 90

/* Motorist*/

/obj/item/clothing/head/helmet/motorcycle
	name = "motorcycle helmet"
	desc = "Protects your head from injuries if you crash your bike."
	icon_state = "motorcycle"
	item_state = "motorcycle"
	worn_state = "motorcycle"
	body_parts_covered = FACE|EYES|HEAD
	restricts_view = 1
	flags_inv = HIDEMASK|BLOCKHAIR|BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 65, gun = 5, energy = 35, bomb = 35, bio = 30, rad = FALSE)

/obj/item/clothing/under/motorist
	name = "motorist outfit"
	desc = "A casual jeans and white shirt combo."
	icon_state = "motorist"
	item_state = "motorist"
	worn_state = "motorist"

/obj/item/clothing/under/reporter
	name = "war correspondent outfit"
	desc = "Casual brown trousers and a black shirt, perfect for running away from gunfire."
	icon_state = "reporter"
	item_state = "reporter"
	worn_state = "reporter"

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

/obj/item/clothing/suit/storage/jacket/rus_winter_vsr93
	name = "Russian Federal Forces winter jacket"
	desc = "A winter jacket used by the Russian Federal Forces in VSR93 camo."
	icon_state = "rus_winter_vsr93"
	item_state = "rus_winter_vsr93"
	worn_state = "rus_winter_vsr93"
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
	restricts_view = 1
	health = 90

/obj/item/clothing/head/helmet/swat_new
	name = "swat helmet"
	desc = "A standard kevlar helmet used by swat officers."
	icon_state = "swat_new"
	item_state = "swat_new"
	worn_state = "swat_new"
	body_parts_covered = HEAD
	armor = list(melee = 85, arrow = 95, gun = 85, energy = 27, bomb = 70, bio = 20, rad = FALSE)
	flags_inv = BLOCKHAIR
	restricts_view = 1
	health = 100

	/* Emergency Services Clothing*/

/obj/item/clothing/suit/lifejacket
	name = "lifejacket"
	desc = "A red lifejacket, to improve survival on sea."
	icon_state = "sealvest"
	item_state = "sealvest"
	worn_state = "sealvest"
	body_parts_covered = UPPER_TORSO
	armor = list(melee = 10, arrow = 5, gun = FALSE, energy = FALSE, bomb = FALSE, bio = 5, rad = 5)
	w_class = ITEM_SIZE_SMALL
	ripable = FALSE

/obj/item/clothing/suit/lifejacket/yellow
	name = "lifejacket"
	desc = "A yellow lifejacket, to improve survival on sea."
	icon_state = "sealvest_yellow"
	item_state = "sealvest_yellow"
	worn_state = "sealvest_yellow"

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

/obj/item/clothing/under/paramedic
	name = "paramedic uniform"
	desc = "A uniform used by EMS workers."
	icon_state = "paramedic"
	item_state = "paramedic"
	worn_state = "paramedic"

/obj/item/clothing/under/firefighter
	name = "firefighter uniform"
	desc = "A uniform used by firefighters. Offers heat protection on the legs."
	icon_state = "firefighter"
	item_state = "firefighter"
	worn_state = "firefighter"
	flammable = FALSE
	heat_protection = LOWER_TORSO|LEGS
	max_heat_protection_temperature = FIRESUIT_MAX_HEAT_PROTECTION_TEMPERATURE

/obj/item/clothing/suit/storage/coat/firefighter
	name = "firefighter coat"
	desc = "A coat used by firefighters. Offers heat protection on the torso and arms."
	icon_state = "firefighter"
	item_state = "firefighter"
	worn_state = "firefighter"
	flammable = FALSE
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	max_heat_protection_temperature = FIRESUIT_MAX_HEAT_PROTECTION_TEMPERATURE

/obj/item/clothing/head/helmet/modern/firefighter
	name = "firefighter helmet"
	desc = "A protective and fire-resistant helmet used by firefigthers."
	icon_state = "hardhat_yellow"
	item_state = "hardhat_yellow"
	worn_state = "hardhat_yellow"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD
	max_heat_protection_temperature = FIRE_HELMET_MAX_HEAT_PROTECTION_TEMPERATURE

/obj/item/clothing/head/helmet/modern/firefighter/white
	icon_state = "hardhat_white"
	item_state = "hardhat_white"
	worn_state = "hardhat_white"

/obj/item/clothing/under/detective1
	name = "shirt outfit"
	desc = "A brown shirt with black pants."
	icon_state = "detective1"
	item_state = "detective1"
	worn_state = "detective1"

/obj/item/clothing/under/detective2
	name = "shirt outfit"
	desc = "A blue shirt with black pants."
	icon_state = "detective2"
	item_state = "detective2"
	worn_state = "detective2"

/obj/item/clothing/under/detective3
	name = "shirt outfit"
	desc = "A black shirt with grey pants."
	icon_state = "detective3"
	item_state = "detective3"
	worn_state = "detective3"

	/* Emergency Services Objects*/

/obj/item/weapon/storage/belt/police
	name = "police belt"
	desc = "A belt that can hold the standard issue gear of law enforcement officers."
	icon_state = "gerbelt"
	item_state = "security"
	worn_state = "security"
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
		/obj/item/flashlight,
		/obj/item/weapon/reagent_containers/spray/pepper,
		/obj/item/clothing/accessory/armband/policebadge,
		/obj/item/weapon/clipboard,
		)
/obj/item/weapon/storage/belt/police/modern
/obj/item/weapon/storage/belt/police/modern/New()
	..()
	new /obj/item/weapon/material/classic_baton/nightstick(src)
	new /obj/item/flashlight/modern(src)
	new /obj/item/stack/medical/bruise_pack/bint(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/clipboard/full(src)
	new /obj/item/weapon/pen(src)
	new /obj/item/weapon/whistle(src)

/obj/item/weapon/storage/belt/police/old
/obj/item/weapon/storage/belt/police/old/New()
	..()
	new /obj/item/weapon/material/classic_baton(src)
	new /obj/item/stack/medical/bruise_pack/bint(src)
	new /obj/item/weapon/handcuffs/old(src)
	new /obj/item/weapon/handcuffs/old(src)
	new /obj/item/weapon/handcuffs/old(src)
	new /obj/item/weapon/handcuffs/old(src)
	new /obj/item/weapon/whistle(src)

/obj/item/weapon/storage/belt/police/bank
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
		/obj/item/weapon/key,
		/obj/item/flashlight,
		/obj/item/weapon/reagent_containers/spray/pepper,
		/obj/item/clothing/accessory/armband/policebadge,
		/obj/item/weapon/clipboard,
		)
/obj/item/weapon/storage/belt/police/bank/New()
	..()
	new /obj/item/weapon/melee/nightbaton(src)
	new /obj/item/weapon/reagent_containers/spray/pepper(src)
	new /obj/item/flashlight/modern(src)
	new /obj/item/stack/medical/bruise_pack/bint(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)

/obj/item/weapon/storage/belt/police/bank/glock/New()
	..()
	new /obj/item/ammo_magazine/glock17(src)
	new /obj/item/ammo_magazine/glock17(src)
	new /obj/item/ammo_magazine/glock17(src)
	new /obj/item/ammo_magazine/glock17(src)

/obj/item/weapon/storage/belt/police/bank/c38/New()
	..()
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/ammo_magazine/c38(src)
	new /obj/item/ammo_magazine/c38(src)

/obj/item/weapon/storage/belt/police/bank/p220/New()
	..()
	new /obj/item/ammo_magazine/p220(src)
	new /obj/item/ammo_magazine/p220(src)
	new /obj/item/ammo_magazine/p220(src)
	new /obj/item/ammo_magazine/p220(src)

/obj/item/weapon/storage/belt/police/bank/m9/New()
	..()
	new /obj/item/ammo_magazine/m9beretta(src)
	new /obj/item/ammo_magazine/m9beretta(src)
	new /obj/item/ammo_magazine/m9beretta(src)
	new /obj/item/ammo_magazine/m9beretta(src)

/obj/item/weapon/storage/belt/police/m16
	icon_state = "swatbelt"
	item_state = "swatbelt"
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
		/obj/item/weapon/key,
		/obj/item/flashlight,
		/obj/item/weapon/reagent_containers/spray/pepper,
		/obj/item/clothing/accessory/armband/policebadge,
		/obj/item/weapon/clipboard,
		)
/obj/item/weapon/storage/belt/police/m16/New()
	..()
	new /obj/item/flashlight/modern(src)
	new /obj/item/stack/medical/bruise_pack/bint(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/ammo_magazine/glock17(src)
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/weapon/grenade/flashbang(src)
	new /obj/item/weapon/grenade/flashbang(src)
	new /obj/item/weapon/grenade/coldwar/stinger(src)

/obj/item/weapon/storage/belt/police/mp5
	icon_state = "swatbelt"
	item_state = "swatbelt"
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
		/obj/item/weapon/key,
		/obj/item/flashlight,
		/obj/item/weapon/reagent_containers/spray/pepper,
		/obj/item/clothing/accessory/armband/policebadge,
		/obj/item/weapon/clipboard,
		)
/obj/item/weapon/storage/belt/police/mp5/New()
	..()
	new /obj/item/flashlight/modern(src)
	new /obj/item/stack/medical/bruise_pack/bint(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/ammo_magazine/glock17(src)
	new /obj/item/ammo_magazine/mp40/mp5(src)
	new /obj/item/ammo_magazine/mp40/mp5(src)
	new /obj/item/weapon/grenade/flashbang(src)
	new /obj/item/weapon/grenade/flashbang(src)
	new /obj/item/weapon/grenade/coldwar/stinger(src)

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
	w_class = ITEM_SIZE_NORMAL
	weight = 2

//my nerd shit (skyfire)//

//armor//
/obj/item/clothing/suit/armor/zgz1
	name = "zgz1 advanced armor"
	desc = "An advanced piece of armor that provides medium protection against kinetic and other projectiles. This armor is mostly used by the Chinese."
	icon_state = "zgz1_armor"
	item_state = "zgz1_armor"
	worn_state = "zgz1_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 45, arrow = 90, gun = 78, energy = 50, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 0.5
	health = 60

/obj/item/clothing/suit/armor/zgz1/med
	name = "Medical zgz1 advanced armor"
	desc = "An advanced piece of armor that provides medium protection against kinetic and other projectiles. This armor is mostly used by the Chinese medics."
	icon_state = "zgz1med_armor"
	item_state = "zgz1med_armor"
	worn_state = "zgz1med_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 45, arrow = 90, gun = 78, energy = 50, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 0.5
	health = 60
//helmets//
/obj/item/clothing/head/helmet/ft1
	name = "FT1 advanced helmet"
	desc = "An extremely advanced helmet used by the Chinese."
	icon_state = "ft1_helmet"
	item_state = "ft1_helmet"
	worn_state = "ft1_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 35, arrow = 60, gun = 80, energy = 40, bomb = 30, bio = 30, rad = FALSE)


/obj/item/clothing/head/helmet/ft1/med
	name = "Medical FT1 advanced helmet"
	desc = "An extremely advanced helmet used by the Chinese medics."
	icon_state = "ft1med_helmet"
	item_state = "ft1med_helmet"
	worn_state = "ft1med_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 35, arrow = 60, gun = 80, energy = 40, bomb = 30, bio = 30, rad = FALSE)

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
	restricts_view = 1
	health = 90

/obj/item/clothing/under/trackpants
	name = "track pants"
	desc = "A shirt with tracksuit pants."
	item_state = "trackpants"
	icon_state = "trackpants"
	worn_state = "trackpants"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS

/obj/item/clothing/suit/storage/jacket/tracksuit
	name = "track suit"
	desc = "A sporty track suit."
	item_state = "tracksuit"
	icon_state = "tracksuit"
	worn_state = "tracksuit"
	body_parts_covered = UPPER_TORSO|ARMS

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
	name = "camouflage shirt with blue pants"
	desc = "A camouflage shirt with blue pants."
	icon_state = "boomerwaffen1"
	item_state = "boomerwaffen1"
	worn_state = "boomerwaffen1"

/obj/item/clothing/under/boomerwaffen2
	name = "tanktop with camouflage pants"
	desc = "A tanktop with camouflage pants."
	icon_state = "boomerwaffen2"
	item_state = "boomerwaffen2"
	worn_state = "boomerwaffen2"

/obj/item/clothing/under/boomerwaffen3
	name = "black shirt with camouflage pants"
	desc = "A black shirt with camouflage pants."
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
	set name = "Flip cap"

	flipped = !flipped
	update_icon()
	update_clothing_icon()
	usr << "You flip your cap around."

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

/obj/item/clothing/head/cap/tfc
	name = "TFC Cap"
	desc = "A red Texas Fried Chicken cap."
	icon_state = "tfc"
	item_state = "tfc"
	worn_state = "tfc"
	base_state = "tfc"

/obj/item/clothing/head/cap/red
	name = "red cap"
	desc = "A red cap."
	icon_state = "redcap"
	item_state = "redcap"
	worn_state = "redcap"
	base_state = "redcap"

/obj/item/clothing/head/cap/yellow
	name = "yellow cap"
	desc = "A yellow cap."
	icon_state = "yellowcap"
	item_state = "yellowcap"
	worn_state = "yellowcap"
	base_state = "yellowcap"

/obj/item/clothing/head/cap/blue
	name = "blue cap"
	desc = "A blue cap."
	icon_state = "bluecap"
	item_state = "bluecap"
	worn_state = "bluecap"
	base_state = "bluecap"

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

/obj/item/clothing/head/cap/atf
	name = "ATF hat"
	desc = "A dark navy hat with ATF in yellow letters in the front."
	icon_state = "atf"
	item_state = "atf"
	worn_state = "atf"
	base_state = "atf"

/obj/item/clothing/head/cap/dea
	name = "DEA hat"
	desc = "A dark navy hat with DEA in yellow letters in the front."
	icon_state = "dea"
	item_state = "dea"
	worn_state = "dea"
	base_state = "dea"

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
	w_class = ITEM_SIZE_LARGE
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
	restricts_view = 1
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
	restricts_view = 1
	health = 60


//////////////////////////////////////Russo-Ukraine war/////////////////////////////////////////////////////////////////////
/obj/item/clothing/head/helmet/modern/mk6
	name = "Mk6 helmet"
	desc = "A british developed kevlar ballistics helmet."
	icon_state = "mk6"
	item_state = "mk6"
	worn_state = "mk6"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 70, arrow = 67, gun = 73, energy = 18, bomb = 65, bio = 20, rad = FALSE)
	var/adjusted = FALSE

/obj/item/clothing/head/helmet/modern/mk6/verb/adjust_band()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/modern/mk6)
		return
	else
		if (adjusted)
			item_state = "mk6"
			worn_state = "mk6"
			item_state_slots["slot_head"] = "mk6"
			usr << "<span class = 'danger'>you adjust your helmet's straps.</span>"
			adjusted = FALSE
		else if (!adjusted)
			item_state = "mk6_straps"
			worn_state = "mk6_straps"
			item_state_slots["slot_head"] = "mk6_straps"
			usr << "<span class = 'danger'>you adjust your helmet's straps.</span>"
			adjusted = TRUE
	update_clothing_icon()


/obj/item/clothing/head/helmet/modern/russian_b7
	name = "64b7 helmet"
	desc = "A russian developed kevlar ballistics helmet."
	icon_state = "64b7"
	item_state = "64b7"
	worn_state = "64b7"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 62, arrow = 75, gun = 55, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/under/ukraine
	name = "ACU pattern uniform"
	desc = "The standard Ukrainian Ground Forces camo uniform."
	icon_state = "ukraine_acu"
	item_state = "ukraine_acu"
	worn_state = "ukraine_acu"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	var/rolled = FALSE

/obj/item/clothing/under/ukraine/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ukraine)
		return
	else
		if (rolled)
			item_state = "ukraine_acu"
			worn_state = "ukraine_acu"
			item_state_slots["w_uniform"] = "ukraine_acu"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "ukraine_acu_rolled"
			worn_state = "ukraine_acu_rolled"
			item_state_slots["w_uniform"] = "ukraine_acu_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/head/cap/ukraine
	name = "ACU field cap"
	desc = "An ACU pattern field cap, standard issue for the Ukrainian Ground Forces"
	icon_state = "ukraine_cap"
	item_state = "ukraine_cap"
	worn_state = "ukraine_cap"


/obj/item/clothing/under/russian
	name = "EMR pattern uniform"
	desc = "The standard Russian Federation Army camo uniform."
	icon_state = "russian_emr"
	item_state = "russian_emr"
	worn_state = "russian_emr"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	var/rolled = FALSE

/obj/item/clothing/under/russian/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/russian)
		return
	else
		if (rolled)
			item_state = "russian_emr"
			worn_state = "russian_emr"
			item_state_slots["w_uniform"] = "russian_emr"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "russian_emr_rolled"
			worn_state = "russian_emr_rolled"
			item_state_slots["w_uniform"] = "russian_emr_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/head/cap/usec
	name = "USEC field cap"
	desc = "An USEC pattern field cap, standard issue for USEC PMCs"
	icon_state = "usec_cap"
	item_state = "usec_cap"
	worn_state = "usec_cap"

/obj/item/clothing/head/cap/bear
	name = "BEAR field cap"
	desc = "A BEAR pattern field cap, standard issue for BEAR PMCs"
	icon_state = "bear_cap"
	item_state = "bear_cap"
	worn_state = "bear_cap"

//african militias
/obj/item/clothing/under/warband1
	name = "jeans with suspenders"
	desc = "A pair of jeans secured by suspenders."
	icon_state = "warband1"
	item_state = "warband1"
	worn_state = "warband1"
	body_parts_covered =LOWER_TORSO|LEGS

/obj/item/clothing/under/warband2
	name = "camo trousers and white sleeveless shirt"
	desc = "A mix of woodland camoflage trousers and a white sleeveless shirt."
	icon_state = "warband2"
	item_state = "warband2"
	worn_state = "warband2"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

//modern winter jackets
/obj/item/clothing/suit/storage/coat/fur/m05
	name = "M05 snow pattern coat"
	desc = "A coat in Finnish M05 snow pattern."
	icon_state = "fur_jacket7"
	item_state = "fur_jacket7"
	worn_state = "fur_jacket7"
	specific = TRUE
	colorn = 7

/obj/item/clothing/suit/storage/coat/fur/ukrainian
	name = "Ukrainian winter camo coat"
	desc = "A coat in Ukrainian winter pattern."
	icon_state = "fur_jacket8"
	item_state = "fur_jacket8"
	worn_state = "fur_jacket8"
	specific = TRUE
	colorn = 8

/obj/item/clothing/suit/storage/coat/fur/klyaksa
	name = "Klyaksa camo coat"
	desc = "A coat in Russian 'Klyaksa' snow pattern."
	icon_state = "fur_jacket10"
	item_state = "fur_jacket10"
	worn_state = "fur_jacket10"
	specific = TRUE
	colorn = 10


/obj/item/clothing/suit/storage/coat/fur/schneetarn
	name = "Schneetarn camo coat"
	desc = "A coat in German Schneetarn pattern."
	icon_state = "fur_jacket9"
	item_state = "fur_jacket9"
	worn_state = "fur_jacket9"
	specific = TRUE
	colorn = 9
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////CAF/////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/obj/item/clothing/under/caf
	name = "cadpat uniform"
	desc = "A canadian pattern uniform"
	icon_state = "cad_pat"
	item_state = "cad_pat"
	worn_state = "cad_pat"
	var/base_icon = "cad_pat"
	var/rolled = FALSE
	var/stripped = FALSE

/obj/item/clothing/under/caf/arid
	name = "cadpat uniform"
	desc = "A canadian pattern uniform"
	icon_state = "cad_pat_arid"
	item_state = "cad_pat_arid"
	worn_state = "cad_pat_arid"
	rolled = FALSE
	stripped = FALSE
	base_icon = "cad_pat_arid"

/obj/item/clothing/under/caf/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/caf)
		return
	else
		if (!stripped)
			if (rolled)
				worn_state = "[base_icon]"
				item_state = "[base_icon]"
				icon_state = "[base_icon]"
				item_state_slots["w_uniform"] = "[base_icon]"
				usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
				rolled = FALSE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
			if (!rolled)
				worn_state = "[base_icon]_rolled"
				item_state = "[base_icon]_rolled"
				icon_state = "[base_icon]_rolled"
				item_state_slots["w_uniform"] = "[base_icon]_rolled"
				usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
				rolled = TRUE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
		else
			if (rolled)
				worn_state = "[base_icon]_stripped"
				item_state = "[base_icon]_stripped"
				icon_state = "[base_icon]_stripped"
				item_state_slots["w_uniform"] = "[base_icon]_stripped"
				usr << "<span class = 'danger'>You have no sleeves.</span>"
				rolled = FALSE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
			else
				worn_state = "[base_icon]_stripped"
				item_state = "[base_icon]_stripped"
				icon_state = "[base_icon]_stripped"
				item_state_slots["w_uniform"] = "[base_icon]_stripped"
				usr << "<span class = 'danger'>You have no sleeves.</span>"
				rolled = FALSE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
/obj/item/clothing/under/caf/verb/strip()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/japuni)
		return
	else
		if (stripped)
			if (!rolled)
				worn_state = "[base_icon]"
				item_state = "[base_icon]"
				icon_state = "[base_icon]"
				item_state_slots["w_uniform"] = "[base_icon]"
				usr << "<span class = 'danger'>You put on your overshirt.</span>"
				stripped = FALSE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
			else
				worn_state = "[base_icon]_rolled"
				item_state = "[base_icon]_rolled"
				icon_state = "[base_icon]_rolled"
				item_state_slots["cad_pat_rolled"] = "[base_icon]_rolled"
				usr << "<span class = 'danger'>You put on your overshirt.</span>"
				stripped = FALSE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
		else
			if (!rolled)
				worn_state = "[base_icon]_stripped"
				item_state = "[base_icon]_stripped"
				icon_state = "[base_icon]_stripped"
				item_state_slots["w_uniform"] = "[base_icon]_stripped"
				usr << "<span class = 'danger'>You strip to your under shirt.</span>"
				stripped = TRUE
				rolled = FALSE
				heat_protection = ARMS
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
				update_clothing_icon()
				return
			else
				worn_state = "[base_icon]_stripped"
				item_state = "[base_icon]_stripped"
				icon_state = "[base_icon]_stripped"
				item_state_slots["w_uniform"] = "[base_icon]_stripped"
				usr << "<span class = 'danger'>You strip to your under shirt.</span>"
				stripped = TRUE
				rolled = FALSE
				heat_protection = ARMS
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
				update_clothing_icon()
				return

/obj/item/clothing/under/caf/New()
	..()
	update_clothing_icon()
//////////////////////////////////////////////////////////////////////////////////////////////////
/obj/item/clothing/head/helmet/modern/cg634
	name = "CG634 helmet"
	desc = "A typical CAF CADPAT Combat Helmet."
	icon_state = "cg634"
	item_state = "cg634"
	worn_state = "cg634"
	body_parts_covered = HEAD
	armor = list(melee = 75, arrow = 95, gun = 93, energy = 22, bomb = 60, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/cg634/arid
	icon_state = "cg634_arid"
	item_state = "cg634_arid"
	worn_state = "cg634_arid"

/obj/item/clothing/accessory/storage/webbing/caf_tacvest
	name = "CAF Tacvest"
	desc = "A large webbing with several pouches."
	icon_state = "caf_tacvest"
	item_state = "caf_tacvest"
	slots = 8
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/handcuffs,/obj/item/stack/medical/bruise_pack,/obj/item/weapon/gun/projectile/pistol)

/obj/item/clothing/accessory/storage/webbing/caf_tacvest/arid
	icon_state = "caf_tacvest_arid"

/obj/item/clothing/head/helmet/modern/mechanical
	name = "Mechanical Helmet"
	desc = "A mechanical steel helmet."
	icon_state = "mechanicalhelmet"
	item_state = "mechanicalhelmet"
	worn_state = "mechanicalhelmet"
	body_parts_covered = HEAD
	armor = list(melee = 175, arrow = 99, gun = 120, energy = 42, bomb = 185, bio = 35, rad = FALSE)

/obj/item/clothing/suit/armor/mechanical
	name = "mechanized armor"
	desc = "A thick, thrown together iron armor, covering most of the body."
	icon_state = "mechanicalarmor"
	item_state = "mechanicalarmor"
	worn_state = "mechanicalarmor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 85, arrow = 150, gun = 150, energy = 55, bomb = 70, bio = 30, rad = FALSE)
	value = 150
	slowdown = 1.8
	health = 175

/obj/item/clothing/under/chinese_type07
	name = "type 07 chinese uniform"
	desc = "The standard modern Chinese military uniform."
	icon_state = "type07"
	item_state = "type07"
	worn_state = "type07"

/obj/item/clothing/head/helmet/modern/qgf03
	name = "QGF03 helmet"
	desc = "A modern chinese combat helmet."
	icon_state = "qgf03"
	item_state = "qgf03"
	worn_state = "qgf03"
	body_parts_covered = HEAD
	armor = list(melee = 65, arrow = 80, gun = 65, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/under/cartel
	name = "floral shirt with light pants"
	desc = "A pair of light pants with a red floral shirt."
	icon_state = "cartel1"
	item_state = "cartel1"
	worn_state = "cartel1"

/obj/item/clothing/head/black_beanie
	name = "black beanie"
	desc = "A woolcloth black skull cap."
	icon_state = "black_beanie"
	item_state = "black_beanie"
	cold_protection = HEAD