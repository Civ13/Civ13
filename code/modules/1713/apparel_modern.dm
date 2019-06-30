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

//late coldwar stuff

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
	matter = list(DEFAULT_WALL_MATERIAL = 50)
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
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("bashed", "bludgeoned", "whacked")
	body_parts_covered = LEGS
	armor = list(melee = 75, arrow = 50, gun = 15, energy = 25, bomb = 55, bio = 20, rad = FALSE)
	slowdown = 0.1
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
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("bashed", "bludgeoned", "whacked")
	body_parts_covered = ARMS
	armor = list(melee = 65, arrow = 45, gun = 15, energy = 25, bomb = 55, bio = 20, rad = FALSE)
	slowdown = 0.1
	sharp = FALSE
	edge = TRUE
	w_class = 2.0


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

/obj/item/clothing/under/us_uni/us_camo_woodland
	name = "woodland camouflage uniform"
	desc = "The standard US Army camo uniform the late 20th century."
	icon_state = "us_camo_woodland"
	item_state = "us_camo_woodland"
	worn_state = "us_camo_woodland"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

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
/obj/item/clothing/under/us_uni/us_camo_dcu
	name = "desert camouflage uniform"
	desc = "The standard US Army desert camo uniform the late 20th century."
	icon_state = "us_camo_dcu"
	item_state = "us_camo_dcu"
	worn_state = "us_camo_dcu"
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

/obj/item/weapon/material/sword/arabsword
	name = "arabic sword"
	desc = "A light sword with a thin, stright blade. Commonly used by officers and nobility."
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


/obj/item/clothing/under/idf
	name = "IDF olive uniform"
	desc = "The plain olive coloured uniform of the Israeli Defense Forces."
	icon_state = "idf_olive"
	item_state = "idf_olive"
	worn_state = "idf_olive"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

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
