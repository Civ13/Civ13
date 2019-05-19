/obj/item/clothing/suit/storage/coat/germcoat
	name = "German coat"
	desc = "A German army coat."
	icon_state = "germtrench"
	item_state = "germtrench"
	worn_state = "germtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/coat/frenchcoat
	name = "French trench coat"
	desc = "A French trench coat."
	icon_state = "frenchtrench"
	item_state = "frenchtrench"
	worn_state = "frenchtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/coat/britishcoat
	name = "British coat"
	desc = "A British coat."
	icon_state = "britishtrench"
	item_state = "britishtrench"
	worn_state = "britishtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 65
	var/colorn = 1


/obj/item/clothing/head/germcap
	name = "German Cap"
	desc = "A cap worn by german soldiers."
	icon_state = "germcap2"
	item_state = "germcap2"

/obj/item/clothing/head/frenchcap
	name = "French képi"
	desc = "A flat circular cap worn by french soldiers."
	icon_state = "frenchcap"
	item_state = "frenchcap"

/obj/item/clothing/head/britishcap
	name = "British Cap"
	desc = "A cap worn by british soldiers."
	icon_state = "brittcap"
	item_state = "brittcap"

/obj/item/clothing/head/helmet/ww/stahlhelm
	name = "M1915 stahlhelm"
	desc = "A typical grman stahlhelm helmet."
	icon_state = "stahlhelm_old"
	item_state = "stahlhelm_old"
	worn_state = "stahlhelm_old"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 35, gun = 10, energy = 15, bomb = 45, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww/adrian
	name = "Adrian helmet"
	desc = "A typical french adrian helmet."
	icon_state = "adrian"
	item_state = "adrian"
	worn_state = "adrian"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww/brodie
	name = "Brodie helmet"
	desc = "A typical british helmet."
	icon_state = "brodie"
	item_state = "brodie"
	worn_state = "brodie"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)
/obj/item/clothing/head/helmet/ww/pickelhaube2
	name = "leather pickelhaube"
	desc = "A typical pointed helmet."
	icon_state = "pickelhaube2"
	item_state = "pickelhaube2"
	worn_state = "pickelhaube2"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 30, gun = 3, energy = 10, bomb = 35, bio = 20, rad = FALSE)
/obj/item/clothing/head/helmet/ww/brodie/khaki
	name = "Khaki Brodie helmet"
	desc = "A typical british helmet, with a khaki cover."
	icon_state = "brodie_old"
	item_state = "brodie_old"
	worn_state = "brodie_old"

/obj/item/clothing/mask/glasses/pilot
	name = "pilot goggles"
	desc = "Early 20th century pilot goggles."
	icon_state = "biker"
	item_state = "biker"
	worn_state = "biker"
	restricts_view = 1

/obj/item/clothing/head/helmet/ww/japhelm
	name = "japanese helmet"
	desc = "A typical rounded steel helmet."
	icon_state = "japhelm"
	item_state = "japhelm"
	worn_state = "japhelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 43, arrow = 33, gun = 10, energy = 15, bomb = 44, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww/japhelm/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/clothing/head/jap_headband))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the heabdand on the helmet.</span>"
		new/obj/item/clothing/head/helmet/ww/japhelm_bandana(user.loc)
		qdel(src)
		qdel(W)

/obj/item/clothing/head/helmet/ww/japhelm_bandana
	name = "japanese helmet"
	desc = "A typical rounded steel helmet. This one has a headband attached to it."
	icon_state = "japhelm_bandana"
	item_state = "japhelm_bandana"
	worn_state = "japhelm_bandana"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 43, arrow = 33, gun = 10, energy = 15, bomb = 44, bio = 20, rad = FALSE)

/obj/item/clothing/head/japcap_ww2
	name = "Japanese Cap"
	desc = "A cap worn by japanese soldiers."
	icon_state = "ww2_japcap"
	item_state = "ww2_japcap"
	worn_state = "ww2_japcap"
	var/toggled = FALSE

/obj/item/clothing/head/japcap_ww2/verb/toggle_flaps()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/japcap_ww2)
		return
	else
		if (toggled)
			item_state = "ww2_japcap"
			worn_state = "ww2_japcap"
			item_state_slots["slot_w_uniform"] = "ww2_japcap"
			usr << "<span class = 'danger'>You put down your cap's flaps.</span>"
			toggled = FALSE
		else if (!toggled)
			item_state = "ww2_japcap_extended"
			worn_state = "ww2_japcap_extended"
			item_state_slots["slot_w_uniform"] = "ww2_japcap_extended"
			usr << "<span class = 'danger'>You put up your cap's flaps.</span>"
			toggled = TRUE
	update_clothing_icon()


/obj/item/clothing/head/japoffcap_ww2
	name = "Japanese Officer Cap"
	desc = "A cap worn by japanese officers."
	icon_state = "ww2_japoffcap"
	item_state = "ww2_japoffcap"
	worn_state = "ww2_japoffcap"
	var/toggled = FALSE

/obj/item/clothing/head/japoffcap_ww2/verb/toggle_flaps()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/japoffcap_ww2)
		return
	else
		if (toggled)
			item_state = "ww2_japoffcap"
			worn_state = "ww2_japoffcap"
			item_state_slots["slot_w_uniform"] = "ww2_japoffcap"
			usr << "<span class = 'danger'>You put down your cap's flaps.</span>"
			toggled = FALSE
		else if (!toggled)
			item_state = "ww2_japoffcap_extended"
			worn_state = "ww2_japoffcap_extended"
			item_state_slots["slot_w_uniform"] = "ww2_japoffcap_extended"
			usr << "<span class = 'danger'>You put up your cap's flaps.</span>"
			toggled = TRUE
	update_clothing_icon()

/obj/item/clothing/under/japoffuni_ww2
	name = "Japanese Officer Uniform"
	desc = "A imperial japanese army officer uniform."
	icon_state = "ww2_japoffuni"
	item_state = "ww2_japoffuni"
	worn_state = "ww2_japoffuni"
	var/rolled = FALSE

/obj/item/clothing/under/japoffuni_ww2/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/japoffuni_ww2)
		return
	else
		if (rolled)
			item_state = "ww2_japoffuni"
			worn_state = "ww2_japoffuni"
			item_state_slots["slot_w_uniform"] = "ww2_japoffuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
		else if (!rolled)
			item_state = "ww2_japoffuni_rolled"
			worn_state = "ww2_japoffuni_rolled"
			item_state_slots["slot_w_uniform"] = "ww2_japoffuni_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
	update_clothing_icon()

/obj/item/clothing/under/japuni_ww2
	name = "Japanese Uniform"
	desc = "A imperial japanese army uniform."
	icon_state = "ww2_japuni"
	item_state = "ww2_japuni"
	worn_state = "ww2_japuni"
	var/rolled = FALSE

/obj/item/clothing/under/japuni_ww2/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/japuni_ww2)
		return
	else
		if (rolled)
			item_state = "ww2_japuni"
			worn_state = "ww2_japuni"
			item_state_slots["slot_w_uniform"] = "ww2_japuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
		else if (!rolled)
			item_state = "ww2_japuni_rolled"
			worn_state = "ww2_japuni_rolled"
			item_state_slots["slot_w_uniform"] = "ww2_japuni_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
	update_clothing_icon()

/obj/item/clothing/head/jap_headband
	name = "Japanese Headband"
	desc = "A headband worn by japanese soldiers."
	icon_state = "japbandana"
	item_state = "japbandana"
	worn_state = "japbandana"

///////////WW1 UNIFORMS///////////
/obj/item/clothing/under/ww1/german
	name = "german uniform"
	desc = "A german feldgrau uniform, used by the Imperial German Army."
	icon_state = "ww1_german"
	item_state = "ww1_german"
	worn_state = "ww1_german"

/obj/item/clothing/under/ww1/british
	name = "british uniform"
	desc = "A british khaki uniform, used by the Royal Army."
	icon_state = "ww1_british"
	item_state = "ww1_british"
	worn_state = "ww1_british"

/obj/item/clothing/under/ww1/french
	name = "french uniform"
	desc = "A french light blue uniform, used by the French Army."
	icon_state = "ww1_french"
	item_state = "ww1_french"
	worn_state = "ww1_french"


/obj/item/clothing/accessory/storage/webbing/ww1
	name = "webbing"
	desc = "two leather belts with small pouches for ammunition and grenades."
	icon_state = "german_vest"
	item_state = "german_vest"
	slots = 4
	New()
		..()
		hold.can_hold = list(/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade, /obj/item/weapon/attachment/bayonet,/obj/item/weapon/shovel/trench,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/weapon/reagent_containers/food/snacks/MRE,)

/obj/item/clothing/accessory/storage/webbing/ww1/german
	name = "german webbing"
	icon_state = "german_vest"
	item_state = "german_vest"

/obj/item/clothing/accessory/storage/webbing/ww1/french
	name = "french webbing"
	icon_state = "french_vest"
	item_state = "french_vest"

/obj/item/clothing/accessory/storage/webbing/ww1/british
	name = "british webbing"
	icon_state = "british_vest"
	item_state = "british_vest"

/obj/item/clothing/accessory/storage/webbing/ww1/leather
	name = "leather webbing"
	icon_state = "british_vest"
	item_state = "british_vest"


/obj/item/clothing/accessory/armor/modern/plate
	name = "breastplate body armor"
	desc = "Wearable armor made of steel sheets."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "modern_platearmor"
	item_state = "modern_platearmor"
	worn_state = "modern_platearmor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 70, arrow = 95, gun = 45, energy = 15, bomb = 45, bio = 20, rad = FALSE)
	value = 50
	slowdown = 0.8

/obj/item/clothing/accessory/armor/modern/british
	name = "Dayfield body armor"
	desc = "British-made wearable armor made of steel sheets."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "modern_dayfield"
	item_state = "modern_dayfield"
	worn_state = "modern_dayfield"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 70, arrow = 90, gun = 40, energy = 12, bomb = 40, bio = 20, rad = FALSE)
	value = 50
	slowdown = 0.8

////////////////////////////////////
///////////////WW2//////////////////
////////////////////////////////////
/obj/item/clothing/under/ww2/german
	name = "german uniform"
	desc = "A german feldgrau uniform, used by the Wehrmacht."
	icon_state = "ww2_german"
	item_state = "ww2_german"
	worn_state = "ww2_german"