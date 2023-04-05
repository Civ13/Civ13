/obj/item/clothing/shoes/japboots
	name = "Winter wrapped boots"
	desc = "A pair of simple, thin leather boots. Covers up to the lower leg."
	icon_state = "japboots"
	item_state = "japboots"
	worn_state = "japboots"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 15, arrow = 10, gun = FALSE, energy = 8, bomb = 15, bio = 10, rad = 25)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	var/colorn = 1
////////////////////////////////////ABASHIRI//////////////////////////////////////////////////////////////////////////////////////
/obj/item/clothing/under/abashiri
	name = "Abashiri Guard Uniform"
	desc = "A standard uniform for the guards of Abashiri Prison."
	icon_state = "abashiri_guard"
	item_state = "abashiri_guard"
	worn_state = "abashiri_guard"
	var/rolled = FALSE

/obj/item/clothing/under/abashiri/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/abashiri)
		return
	else
		if (rolled)
			item_state = "abashiri_guard"
			worn_state = "abashiri_guard"
			item_state_slots["w_uniform"] = "abashiri_guard"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "abashiri_guard_rolled"
			worn_state = "abashiri_guard_rolled"
			item_state_slots["w_uniform"] = "abashiri_guard_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/under/abashiri_prisoner
	name = "Abashiri Prison Uniform"
	desc = "A standard yukata for the guards of Abashiri Prison."
	icon_state = "abashiri_prisoner"
	item_state = "abashiri_prisoner"
	worn_state = "abashiri_prisoner"
	var/rolled = FALSE

/obj/item/clothing/under/abashiri_prisoner/verb/roll_suit()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/abashiri_prisoner)
		return
	else
		if (rolled)
			item_state = "abashiri_prisoner"
			worn_state = "abashiri_prisoner"
			item_state_slots["w_uniform"] = "abashiri_prisoner"
			usr << "<span class = 'danger'>You roll down your suit.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "abashiri_prisoner_down"
			worn_state = "abashiri_prisoner_down"
			item_state_slots["w_uniform"] = "abashiri_prisoner_down"
			usr << "<span class = 'danger'>You roll up your suit.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()
/obj/item/clothing/head/abashiri_guard
	name = "Abashiri Guard Cap"
	desc = "A cap worn by Abashiri Guards."
	icon_state = "abashiri_guard"
	item_state = "abashiri_guard"
/obj/item/clothing/head/abashiri_guard/head_guard
	name = "Abashiri Head Guard Cap"
	desc = "A cap worn by the Abashiri Head Guard."
	icon_state = "abashiri_guard_head"
	item_state = "abashiri_guard_head"
/obj/item/clothing/head/abashiri_guard/head_guard/warden
	name = "Abashiri Warden Cap"
	desc = "A cap worn by the Abashiri Warden."
/obj/item/clothing/head/abashiri_prisoner
	name = "Kasa"
	desc = "A straw hat that obscures inmate's view, as well as their faces."
	icon_state = "abashiri_kasa"
	item_state = "abashiri_kasa"
	flags_inv = BLOCKHAIR|HIDEFACE
	restricts_view = 2
/obj/item/clothing/suit/storage/jacket/haori_jacket/abashiri
	name = "Abashiri Haori"
	desc = "A simple haori jacket usually worn over a haori outfit."
	icon_state = "haori_jacket"
	item_state = "haori_jacket"
	worn_state = "haori_jacket"
	body_parts_covered = UPPER_TORSO|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 12, arrow = 5, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 75
/obj/item/clothing/suit/storage/jacket/haori_jacket/abashiri/wing1
	name = "Abashiri Haori"
	desc = "A simple haori jacket usually worn over a haori outfit. This one is designated with Wing1 on its back."
	icon_state = "haori_jacket1"
	item_state = "haori_jacket1"
	worn_state = "haori_jacket1"
/obj/item/clothing/suit/storage/jacket/haori_jacket/abashiri/wing2
	name = "Abashiri Haori"
	desc = "A simple haori jacket usually worn over a haori outfit. This one is designated with Wing 2 on its back."
	icon_state = "haori_jacket2"
	item_state = "haori_jacket2"
	worn_state = "haori_jacket2"
/obj/item/clothing/suit/storage/jacket/haori_jacket/abashiri/wing3
	name = "Abashiri Haori"
	desc = "A simple haori jacket usually worn over a haori outfit. This one is designated with Wing 3 on its back."
	icon_state = "haori_jacket3"
	item_state = "haori_jacket3"
	worn_state = "haori_jacket3"

////////////////////////////////////////////RUSSO-JAP///////////////////////////////////////////////
/obj/item/clothing/under/japuni
	name = "Japanese Army Uniform"
	desc = "A standard imperial japanese army uniform."
	icon_state = "japuni"
	item_state = "japuni"
	worn_state = "japuni"
	var/rolled = FALSE

/obj/item/clothing/under/japuni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/japuni)
		return
	else
		if (rolled)
			item_state = "japuni"
			worn_state = "japuni"
			item_state_slots["w_uniform"] = "japuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "japunirolled"
			worn_state = "japunirolled"
			item_state_slots["w_uniform"] = "japunirolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/under/japoffuni
	name = "Japanese Officer Uniform"
	desc = "A imperial japanese army officer uniform."
	icon_state = "japoffuni"
	item_state = "japoffuni"
	worn_state = "japoffuni"
	var/rolled = FALSE

/obj/item/clothing/under/japoffuni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/japoffuni)
		return
	else
		if (rolled)
			item_state = "japoffuni"
			worn_state = "japoffuni"
			item_state_slots["w_uniform"] = "japoffuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		else if (!rolled)
			item_state = "japoffunirolled"
			worn_state = "japoffunirolled"
			item_state_slots["w_uniform"] = "japoffunirolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()


/obj/item/clothing/accessory/white_sash
	name = "White Sash"
	desc = "A white sash, used by the Japanese White Sash Brigade."
	icon_state = "sash"
	item_state = "sash"

/obj/item/clothing/under/rusuni
	name = "Russian Army uniform"
	desc = "A standard imperial russian army uniform."
	icon_state = "rusuni"
	item_state = "rusuni"
	worn_state = "rusuni"
	var/rolled = FALSE

/obj/item/clothing/under/rusuni_ww1
	name = "Russian Army uniform"
	desc = "A standard imperial russian army uniform."
	icon_state = "ww1_russian2"
	item_state = "ww1_russian2"
	worn_state = "ww1_russian2"

/obj/item/clothing/under/rusuni_ww1_officer
	name = "Russian Army officer uniform"
	desc = "A standard imperial russian army uniform, with officer epaulettes."
	icon_state = "ww1_russian_o"
	item_state = "ww1_russian_o"
	worn_state = "ww1_russian_o"


/obj/item/clothing/under/rusuni_rcw
	name = "Red Army uniform"
	desc = "A standard early 20th century russian uniform, with no epaulettes or insignias."
	icon_state = "ww1_russian"
	item_state = "ww1_russian"
	worn_state = "ww1_russian"

/obj/item/clothing/under/rusuni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/rusuni)
		return
	else
		if (rolled)
			item_state = "rusuni"
			worn_state = "rusuni"
			item_state_slots["w_uniform"] = "rusuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "rusunirolled"
			worn_state = "rusunirolled"
			item_state_slots["w_uniform"] = "rusunirolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/suit/storage/coat/cheka
	name = "Cheka leather coat"
	desc = "A shiny black leather coat used by Cheka agents."
	icon_state = "leathercoat_c"
	item_state = "leathercoat_c"
	worn_state = "leathercoat_c"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
/obj/item/clothing/under/kuban_cossak
	name = "Kuban Cossak beshmet"
	desc = "A red beshmet with grey trousers, traditional of the Kuban Cossaks."
	icon_state = "kuban_cossak"
	item_state = "kuban_cossak"
	worn_state = "kuban_cossak"
/obj/item/clothing/suit/storage/coat/kuban_cossak
	name = "black cherkesska coat"
	desc = "A traditional Kuban Cossak coat."
	icon_state = "kuban_cossak"
	item_state = "kuban_cossak"
	worn_state = "kuban_cossak"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65


/obj/item/clothing/suit/storage/coat/russian_rcw
	name = "Soviet coat"
	desc = "An early Red Army coat."
	icon_state = "japcoat2"
	item_state = "japcoat2"
	worn_state = "japcoat2"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65

/obj/item/clothing/suit/storage/coat/japcoat
	name = "Japanese Coat"
	desc = "A japanese army coat."
	icon_state = "japcoat"
	item_state = "japcoat"
	worn_state = "japcoat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	var/colorn = 1
/obj/item/clothing/suit/storage/coat/japcoat/abashiri
	name = "Abashiri Guard Coat"
	desc = "An Abashiri Prison Guard coat."
/obj/item/clothing/suit/storage/coat/priest
	name = "priest sleev"
	desc = "A holy coat worn by a priest."
	icon_state = "priestwhite"
	item_state = "priestwhite"
	worn_state = "priestwhite"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/coat/japcoat2
	name = "Japanese Coat"
	desc = "A japanese army coat."
	icon_state = "japcoat2"
	item_state = "japcoat2"
	worn_state = "japcoat2"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/coat/ruscoat
	name = "Russian Coat"
	desc = "A russian army coat."
	icon_state = "ruscoat"
	item_state = "ruscoat"
	worn_state = "ruscoat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/coat/ruscoat/grey
	name = "Grey Winter Coat"
	desc = "A thick winter coat."

/obj/item/clothing/suit/storage/coat/japcoat2/brown
	name = "Brown Winter Coat"
	desc = "A thick winter coat."

/obj/item/clothing/suit/storage/coat/japcoat2/trench
	name = "brown trench coat"
	desc = "A long coat to keep you clean and dry."

/obj/item/clothing/suit/storage/coat/rusoffcoat
	name = "Russian Officer Coat."
	desc = "A russian army  officer coat. Worn by officers, acknowledge their rank."
	icon_state = "rusoffcoat"
	item_state = "rusoffcoat"
	worn_state = "rusoffcoat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/armor/japmisc
	min_cold_protection_temperature = COAT_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/suit/armor/japmisc/japvest
	name = "Matagi Vest"
	desc = "A warm, fur lined vest made of leather."
	icon_state = "japvest"
	item_state = "japvest"
	worn_state = "japvest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	cold_protection = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 10, arrow = 10, gun = FALSE, energy = 10, bomb = 10, bio = 10, rad = 15)
	value = 10
	health = 12

/obj/item/clothing/head/japcap
	name = "Japanese Cap"
	desc = "A cap worn by japanese soldiers."
	icon_state = "japcap"
	item_state = "japcap"
	var/adjusted = FALSE

/obj/item/clothing/head/japcap/verb/adjust_band()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/japcap)
		return
	else
		if (adjusted)
			item_state = "japcap"
			worn_state = "japcap"
			item_state_slots["slot_head"] = "japcap"
			usr << "<span class = 'danger'>You adjust your cap's band.</span>"
			adjusted = FALSE
		else if (!adjusted)
			item_state = "japcapad"
			worn_state = "japcapad"
			item_state_slots["slot_head"] = "japcapad"
			usr << "<span class = 'danger'>You adjust your cap's band.</span>"
			adjusted = TRUE
	update_clothing_icon()

/obj/item/clothing/head/japcap2
	name = "Japanese Cap"
	desc = "A cap worn by japanese soldiers."
	icon_state = "japcap2"
	item_state = "japcap2"
	var/adjusted = FALSE

/obj/item/clothing/head/japcap2/verb/adjust_band()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/japcap2)
		return
	else
		if (adjusted)
			item_state = "japcap2"
			worn_state = "japcap2"
			item_state_slots["slot_head"] = "japcap2"
			usr << "<span class = 'danger'>You adjust your cap's band.</span>"
			adjusted = FALSE
		else if (!adjusted)
			item_state = "japcap2ad"
			worn_state = "japcap2ad"
			item_state_slots["slot_head"] = "japcap2ad"
			usr << "<span class = 'danger'>You adjust your cap's band.</span>"
			adjusted = TRUE
	update_clothing_icon()

/obj/item/clothing/head/japoffcap
	name = "Japanese Officer Cap"
	desc = "A cap worn by japanese officers."
	icon_state = "japoffcap"
	item_state = "japoffcap"
	var/adjusted = FALSE

/obj/item/clothing/head/japoffcap/verb/adjust_band()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/japoffcap)
		return
	else
		if (adjusted)
			item_state = "japoffcap"
			worn_state = "japoffcap"
			item_state_slots["slot_head"] = "japoffcap"
			usr << "<span class = 'danger'>You adjust your cap's band.</span>"
			adjusted = FALSE
		else if (!adjusted)
			item_state = "japoffcapad"
			worn_state = "japoffcapad"
			item_state_slots["slot_head"] = "japoffcapad"
			usr << "<span class = 'danger'>You adjust your cap's band.</span>"
			adjusted = TRUE
	update_clothing_icon()

/obj/item/clothing/head/ruscap
	name = "Russian Cap"
	desc = "A cap worn by russian soldiers."
	icon_state = "ruscap"
	item_state = "ruscap"

/obj/item/clothing/head/rusoffcap
	name = "Russian Officer Cap"
	desc = "A cap worn by russian army officers."
	icon_state = "rusoffcap"
	item_state = "rusoffcap"

////////////storage//////////////////////////
//russo-jap
/obj/item/weapon/storage/belt/russian
	name = "Russian Soldier belt"
	desc = "A belt that can hold gear like pistols, ammo and other things."
	icon_state = "rubelt"
	item_state = "rubelt"
	storage_slots = 7
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
		/obj/item/weapon/material/shovel,
		/obj/item/weapon/key,
		/obj/item/weapon/melee/classic_baton
		)
/obj/item/weapon/storage/belt/russian/soldier
/obj/item/weapon/storage/belt/russian/soldier/New()
	..()
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/weapon/attachment/bayonet(src)

/obj/item/clothing/accessory/storage/webbing/russband
	name = "Imperial Russian Army bandolier"
	desc = "A large leather bandolier 6 small pouches for strip clips."
	icon_state = "ru_band"
	item_state = "ru_band"
	slots = 6
	New()
		..()
		hold.storage_slots = slots
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/handcuffs,/obj/item/stack/medical/bruise_pack)

//world war 1
/obj/item/weapon/storage/belt/russian/ww1
	name = "Russian Soldier belt"
	desc = "A belt with 2 pouches to hold 12 strip clips."
	icon_state = "rubelt_ww1"
	item_state = "rubelt_ww1"
	storage_slots = 7
	max_w_class = 3
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
		/obj/item/weapon/material/shovel,
		/obj/item/weapon/key,
		/obj/item/weapon/melee/classic_baton
		)
/obj/item/weapon/storage/belt/russian/ww1/soldier
/obj/item/weapon/storage/belt/russian/ww1/soldier/New()
	..()
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/ammo_magazine/mosin(src)
	new /obj/item/weapon/attachment/bayonet(src)
/obj/item/weapon/storage/belt/jap
	name = "Japanese Soldier belt"
	desc = "A belt that can hold gear like pistols, ammo and other things."
	icon_state = "japbelt"
	item_state = "japbelt"
	storage_slots = 12
	max_w_class = 3
	max_storage_space = 24
	can_hold = list(
		/obj/item/ammo_magazine,
		/obj/item/weapon/material/kitchen/utensil/knife,
		/obj/item/weapon/grenade,
		/obj/item/weapon/attachment,
		/obj/item/weapon/gun/projectile/pistol,
		/obj/item/weapon/gun/projectile/revolver,
		/obj/item/weapon/handcuffs,
		/obj/item/ammo_casing,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
		/obj/item/weapon/material/shovel,
		/obj/item/weapon/key,
		/obj/item/weapon/melee/classic_baton,
		/obj/item/weapon/material,
		/obj/item/flashlight,
		/obj/item/weapon/whistle
		)
/obj/item/weapon/storage/belt/jap/soldier
/obj/item/weapon/storage/belt/jap/soldier/New()
	..()
	new /obj/item/ammo_magazine/arisaka(src)
	new /obj/item/ammo_magazine/arisaka(src)
	new /obj/item/ammo_magazine/arisaka(src)
	new /obj/item/ammo_magazine/arisaka(src)
	new /obj/item/ammo_magazine/arisaka(src)
	new /obj/item/ammo_magazine/arisaka(src)
	new /obj/item/weapon/attachment/bayonet(src)

/obj/item/weapon/storage/belt/jap/ww2soldier
/obj/item/weapon/storage/belt/jap/ww2soldier/New()
	..()
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/weapon/attachment/bayonet(src)

/obj/item/weapon/storage/belt/jap/ww2soldier100
/obj/item/weapon/storage/belt/jap/ww2soldier100/New()
	..()
	new /obj/item/ammo_magazine/type100(src)
	new /obj/item/ammo_magazine/type100(src)
	new /obj/item/ammo_magazine/type100(src)
	new /obj/item/ammo_magazine/type100(src)
	new /obj/item/ammo_magazine/type100(src)

/obj/item/weapon/storage/belt/jap/ww2soldier99
/obj/item/weapon/storage/belt/jap/ww2soldier99/New()
	..()
	new /obj/item/ammo_magazine/type99(src)
	new /obj/item/ammo_magazine/type99(src)
	new /obj/item/ammo_magazine/type99(src)
	new /obj/item/ammo_magazine/type99(src)
	new /obj/item/ammo_magazine/type99(src)
	new /obj/item/ammo_magazine/type99(src)
	new /obj/item/ammo_magazine/type99(src)
	new /obj/item/weapon/attachment/bayonet(src)

/obj/item/weapon/storage/belt/jap/camp_guard
/obj/item/weapon/storage/belt/jap/camp_guard/New()
	..()
	new /obj/item/weapon/melee/classic_baton(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/attachment/bayonet(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
/obj/item/weapon/storage/belt/jap/abashiri_guard
/obj/item/weapon/storage/belt/jap/abashiri_guard/New()
	..()
	new /obj/item/weapon/material/classic_baton/guard(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/flashlight/flashlight(src)

/obj/item/weapon/storage/belt/jap/camp_guard_SS
	name = "SS guard belt"
/obj/item/weapon/storage/belt/jap/camp_guard_SS/New()
	..()
	new /obj/item/weapon/whistle(src)
	new /obj/item/weapon/material/classic_baton/guard(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)

/obj/item/weapon/storage/belt/jap/camp_officer
/obj/item/weapon/storage/belt/jap/camp_officer/New()
	..()
	new /obj/item/weapon/material/classic_baton/guard(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/attachment/bayonet(src)
	new /obj/item/ammo_magazine/c8mmnambu(src)
	new /obj/item/ammo_magazine/c8mmnambu(src)
/////////////////////////////////////////////////////////////////////////////////
//////////////CIVILIAN STUFF/////////////////////////////////////////////////////

/obj/item/clothing/head/top_hat
	name = "top hat"
	desc = "A high top hat."
	icon_state = "tophat"
	item_state = "tophat"

/obj/item/clothing/head/flatcap1
	name = "brown flat cap"
	desc = "A common flat cap, in brown."
	icon_state = "flatcap1"
	item_state = "flatcap1"

/obj/item/clothing/head/flatcap2
	name = "blue flat cap"
	desc = "A common flat cap, in blue."
	icon_state = "flatcap2"
	item_state = "flatcap2"

/obj/item/clothing/head/flatcap3
	name = "grey flat cap"
	desc = "A common flat cap, in grey."
	icon_state = "flatcap3"
	item_state = "flatcap3"

/obj/item/clothing/head/fedora
	name = "fedora hat"
	desc = "A wide brim hat."
	icon_state = "fedora"
	item_state = "fedora"

/obj/item/clothing/head/helmet/constable
	name = "constable helmet"
	desc = "A typical plastic helmet worn by constable's of law enforcement. Protects the head from petty battery and assault."
	icon_state = "constable"
	item_state = "constable"
	worn_state = "constable"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 60, gun = 5, energy = 15, bomb = 45, bio = 20, rad = FALSE)

/obj/item/clothing/under/modern1
	name = "light brown outfit"
	desc = "An outfit composed of a white shirt and light brown trousers."
	icon_state = "modern1"
	item_state = "modern1"
	worn_state = "modern1"

/obj/item/clothing/under/modern2
	name = "black outfit"
	desc = "An outfit composed of a white shirt and black trousers."
	icon_state = "modern2"
	item_state = "modern2"
	worn_state = "modern2"

/obj/item/clothing/under/expensive
	name = "shirt outfit"
	desc = "An outfit composed of a expensive white shirt and black trousers."
	icon_state = "bman"
	item_state = "bman"
	worn_state = "bman"

/obj/item/clothing/under/expensive/green
	name = "green tie shirt outfit"
	desc = "An outfit composed of a expensive white shirt and black trousers, with a green tie."
	icon_state = "bman_green"
	item_state = "bman_green"
	worn_state = "bman_green"

/obj/item/clothing/under/expensive/blue
	name = "blue tie shirt outfit"
	desc = "An outfit composed of a expensive white shirt and black trousers, with a blue tie."
	icon_state = "bman_blue"
	item_state = "bman_blue"
	worn_state = "bman_blue"

/obj/item/clothing/under/expensive/red
	name = "red tie shirt outfit"
	desc = "An outfit composed of a expensive white shirt and black trousers, with a red tie."
	icon_state = "bman_red"
	item_state = "bman_red"
	worn_state = "bman_red"

/obj/item/clothing/under/expensive/yellow
	name = "yellow tie shirt outfit"
	desc = "An outfit composed of a expensive white shirt and black trousers, with a yellow tie."
	icon_state = "bman_yellow"
	item_state = "bman_yellow"
	worn_state = "bman_yellow"

/obj/item/clothing/under/modern3
	name = "grey outfit"
	desc = "An outfit composed of a white shirt and grey trousers."
	icon_state = "modern3"
	item_state = "modern3"
	worn_state = "modern3"

/obj/item/clothing/under/modern4
	name = "brown outfit"
	desc = "An outfit composed of a white shirt and brown trousers."
	icon_state = "modern4"
	item_state = "modern4"
	worn_state = "modern4"

/obj/item/clothing/under/modern7
	name = "modern outfit"
	desc = "An outfit composed of a white shirt and black cargo pants."
	icon_state = "modern7"
	item_state = "modern7"
	worn_state = "modern7"

/obj/item/clothing/under/swat
	name = "swat outfit"
	desc = "A uniform used by police special forces."
	icon_state = "swat"
	item_state = "swat"
	worn_state = "swat"

/obj/item/clothing/under/cleansuit
	name = "cleansuit"
	desc = "A white personal protective uniform against ambient radiation."
	armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = 15, bomb = 10, bio = 20, rad = 20)
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	icon_state = "cleansuit"
	item_state = "cleansuit"
	worn_state = "cleansuit"

/obj/item/clothing/under/swat_new
	name = "swat outfit"
	desc = "A uniform used by police special forces."
	icon_state = "swat_new"
	item_state = "swat_new"
	worn_state = "swat_new"

/obj/item/clothing/under/combat
	name = "combat outfit"
	desc = "A combat uniform plated with kevlar."
	icon_state = "combat"
	item_state = "combat"
	worn_state = "combat"

/obj/item/clothing/under/police
	name = "police outfit"
	desc = "A uniform used by police forces."
	icon_state = "police"
	item_state = "police"
	worn_state = "police"

/obj/item/clothing/under/prisoner
	name = "prison outfit"
	desc = "Normally worn by criminals and scum."
	icon_state = "prisoner"
	item_state = "prisoner"
	worn_state = "prisoner"

/obj/item/clothing/under/milrus2
	name = "russian military outfit"
	desc = "An outfit composed of camo pants and shirt."
	icon_state = "milrus2"
	item_state = "milrus2"
	worn_state = "milrus2"

/obj/item/clothing/under/baily
	name = "security outfit"
	desc = "An outfit composed of a green jacket and black pants."
	icon_state = "baily"
	item_state = "baily"
	worn_state = "baily"

/obj/item/clothing/under/tactical1
	name = "tactical outfit"
	desc = "An outfit composed of a camo cargo pants and tan ubac."
	icon_state = "tactical1"
	item_state = "tactical1"
	worn_state = "tactical1"

/obj/item/clothing/under/pmc
	name = "pmc outfit"
	desc = "A outfit used by PMC units."
	icon_state = "pmc"
	item_state = "pmc"
	worn_state = "pmc"

/obj/item/clothing/under/mafia
	name = "fancy outfit"
	desc = "A outfit that is expensive and has style."
	icon_state = "mafia"
	item_state = "mafia"
	worn_state = "mafia"

/obj/item/clothing/under/engi
	name = "worker outfit"
	desc = "A outfit used by construction workers."
	icon_state = "engi"
	item_state = "engi"
	worn_state = "engi"

/obj/item/clothing/under/gorka
	name = "gorka outfit"
	desc = "A gorka outfit used by Spetsnaz."
	icon_state = "gorka"
	item_state = "gorka"
	worn_state = "gorka"

/obj/item/clothing/under/gorka/frag //provides actual armor
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 30, arrow = 30, gun = FALSE, energy = 15, bomb = 25, bio = 30, rad = 30)
	value = 65

/obj/item/clothing/under/modern8
	name = "modern skirt"
	desc = "An outfit composed of a black skirt and white shirt."
	icon_state = "modern8"
	item_state = "modern8"
	worn_state = "modern8"

/obj/item/clothing/under/oldmansuit
	name = "old man suit"
	desc = "An outfit worn by fancy men in the 1800s."
	icon_state = "oldmansuit"
	item_state = "oldmansuit"
	worn_state = "oldmansuit"

/obj/item/clothing/under/cozyoldy
	name = "fancy outfit"
	desc = "An outfit worn by fancy men in the 1800s."
	icon_state = "cozyoldy"
	item_state = "cozyoldy"
	worn_state = "cozyoldy"

/obj/item/clothing/under/peakyblinder
	name = "fancy suit"
	desc = "An outfit used by scum."
	icon_state = "peakyblinder"
	item_state = "peakyblinder"
	worn_state = "peakyblinder"

/obj/item/clothing/under/constable
	name = "constable outfit"
	desc = "An black outfit used by enforcers of the law."
	icon_state = "constable"
	item_state = "constable"
	worn_state = "constable"

/obj/item/clothing/under/oldfirefighter
	name = "fire fighter uniform"
	desc = "An outfit used by fire fighters. Damn hot."
	icon_state = "oldfirefighter"
	item_state = "oldfirefighter"
	worn_state = "oldfirefighter"

/obj/item/clothing/under/blacktango
	name = "black dress"
	desc = "An dress used by fancy woman."
	icon_state = "black_tango_alt_s"
	item_state = "black_tango_alt_s"
	worn_state = "black_tango_alt_s"

/obj/item/clothing/under/clown
	name = "clown outfit"
	desc = "An outfit used by clowns."
	icon_state = "clown"
	item_state = "clown"
	worn_state = "clown"

/obj/item/clothing/under/jester
	name = "jester outfit"
	desc = "A jester outfit. WHERE IS ME FUN HAHA."
	icon_state = "jester"
	item_state = "jester"
	worn_state = "jester"

/obj/item/clothing/under/farmer_outfit
	name = "farmer outfit"
	desc = "An outfit composed of a checkered shirt and a denim bib."
	icon_state = "farmer_outfit"
	item_state = "farmer_outfit"
	worn_state = "farmer_outfit"

/obj/item/clothing/under/mechanic_outfit
	name = "mechanic outfit"
	desc = "An outfit composed of a white shirt and a leather bib."
	icon_state = "mechanic_outfit"
	item_state = "mechanic_outfit"
	worn_state = "mechanic_outfit"

/*Feminine Clothing*/

/obj/item/clothing/under/tradwife
	name = "blue traditional dress"
	desc = "A early 20th century style dress made to be well fitting, often worn by housewives"
	icon_state = "tradwife_blue"
	item_state = "tradwife_blue"
	worn_state = "tradwife_blue"

/obj/item/clothing/under/tradwife/yellow
	name = "yellow traditional dress"
	desc = "A early 20th century style dress made to be well fitting, often worn by housewives"
	icon_state = "tradwife_yellow"
	item_state = "tradwife_yellow"
	worn_state = "tradwife_yellow"

/obj/item/clothing/under/tradwife/orange
	name = "orange traditional dress"
	desc = "A early 20th century style dress made to be well fitting, often worn by housewives"
	icon_state = "tradwife_orange"
	item_state = "tradwife_orange"
	worn_state = "tradwife_orange"

/obj/item/clothing/under/tradwife/purple
	name = "purple traditional dress"
	desc = "A early 20th century style dress made to be well fitting, often worn by housewives"
	icon_state = "tradwife_purple"
	item_state = "tradwife_purple"
	worn_state = "tradwife_purple"

/obj/item/clothing/under/tradwife/red
	name = "red traditional dress"
	desc = "A early 20th century style dress made to be well fitting, often worn by housewives"
	icon_state = "tradwife_red"
	item_state = "tradwife_red"
	worn_state = "tradwife_red"

/obj/item/clothing/suit/storage/jacket/black_suit
	name = "black suit"
	desc = "A formal black suit."
	icon_state = "black_suit"
	item_state = "black_suit"
	worn_state = "black_suit"

/obj/item/clothing/suit/storage/jacket/really_black_suit
	name = "dark black suit"
	desc = "A very black formal suit."
	icon_state = "really_black_suit"
	item_state = "really_black_suit"
	worn_state = "really_black_suit"

/obj/item/clothing/suit/storage/jacket/charcoal_suit
	name = "charcoal suit"
	desc = "A formal charcoal grey suit."
	icon_state = "charcoal_suit"
	item_state = "charcoal_suit"
	worn_state = "charcoal_suit"

/obj/item/clothing/suit/storage/jacket/navy_suit
	name = "navy suit"
	desc = "A formal navy blue suit."
	icon_state = "navy_suit"
	item_state = "navy_suit"
	worn_state = "navy_suit"

/obj/item/clothing/suit/storage/jacket/checkered_suit
	name = "checkered suit"
	desc = "A formal grey checkered suit."
	icon_state = "checkered_suit"
	item_state = "checkered_suit"
	worn_state = "checkered_suit"

/obj/item/clothing/suit/storage/jacket/burgundy_suit
	name = "burgundy suit"
	desc = "A formal burgundy colored suit."
	icon_state = "burgundy_suit"
	item_state = "burgundy_suit"
	worn_state = "burgundy_suit"

/obj/item/clothing/accessory/tie
	name = "black tie"
	desc = "A black tie."
	icon_state = "black_tie"
	item_state = "black_tie"
	slot = "tie"

/obj/item/clothing/accessory/tie/red
	name = "red tie"
	desc = "A red tie."
	icon_state = "red_tie"
	item_state = "red_tie"

/obj/item/clothing/accessory/tie/blue
	name = "blue tie"
	desc = "A blue tie."
	icon_state = "blue_tie"
	item_state = "blue_tie"

/obj/item/clothing/accessory/tie/bowtie
	name = "black bowtie"
	desc = "A black bowtie."
	icon_state = "black_bowtie"
	item_state = "black_bowtie"

/obj/item/weapon/material/sword/shashka
	name = "shashka sword"
	desc = "A caucasian sabre, very sharp and meant to be used single-handedly."
	icon_state = "shashka"
	item_state = "longsword"
	throw_speed = 4
	throw_range = 5
	force_divisor = 0.7 // 45 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 14 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 22
	cooldownw = 7
	value = 60
/obj/item/clothing/head/ww/cheka
	name = "Cheka cap"
	desc = "A black leather cap worn by Cheka agents."
	icon_state = "cheka"
	item_state = "cheka"
/obj/item/clothing/head/ww/papakha
	name = "papakha"
	desc = "A traditional caucasus hat."
	icon_state = "papakha"
	item_state = "papakha"
/obj/item/clothing/head/ww/papakha/white
	name = "white papakha"
	desc = "A traditional caucasus hat."
	icon_state = "papakha_white"
	item_state = "papakha_white"
/obj/item/clothing/head/ww/papakha/kuban
	name = "Kuban papakha"
	desc = "A traditional Kuban Cossak papakha, black with a red crown."
	icon_state = "papakha_kuban"
	item_state = "papakha_kuban"
/obj/item/clothing/head/helmet/modern/pickelhaube
	name = "iron pickelhaube"
	desc = "A typical pointed helmet."
	icon_state = "pickelhaube"
	item_state = "pickelhaube"
	worn_state = "pickelhaube"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
/obj/item/clothing/head/ww/budenovka
	name = "budenovka"
	desc = "A Soviet budenovka hat."
	icon_state = "budenovka"
	item_state = "budenovka"
/obj/item/clothing/head/helmet/modern/stahlhelm
	name = "M1935 stahlhelm"
	desc = "A typical german helmet."
	icon_state = "stahlhelm"
	item_state = "stahlhelm"
	worn_state = "stahlhelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 15, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/brodie
	name = "iron brodie"
	desc = "A typical rounded helmet."
	icon_state = "brodie"
	item_state = "brodie"
	worn_state = "brodie"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 35, gun = 10, energy = 15, bomb = 45, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/pith
	name = "pith helmet"
	desc = "A typical tropical helmet."
	icon_state = "pith"
	item_state = "pith"
	worn_state = "pith"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)

/obj/item/clothing/suit/storage/jacket/doctor
	name = "white labcoat"
	desc = "A white labcoat."
	icon_state = "labcoat"
	item_state = "labcoat"
	worn_state = "labcoat"
	var/closed = TRUE

/obj/item/clothing/suit/storage/jacket/doctor/verb/toggle()
	set category = null
	set src in usr
	set name = "Adjust lab coat"
	if (type != /obj/item/clothing/suit/storage/jacket/doctor)
		return
	else
		if(closed)
			worn_state = "labcoat_open"
			item_state = "labcoat_open"
			icon_state = "labcoat_open"
			item_state_slots["w_uniform"] = "labcoat_open"
			usr << "You <b>open up</b> your jacket."
			closed = FALSE
			update_clothing_icon()
		else if (!closed)
			worn_state = "labcoat"
			item_state = "labcoat"
			icon_state = "labcoat"
			item_state_slots["w_uniform"] = "labcoat"
			usr << "You <b>close up</b> your jacket."
			closed = TRUE
			update_clothing_icon()

/obj/item/clothing/suit/storage/jacket/surgeon
	name = "surgery apron"
	desc = "A blue plastic surgery apron."
	icon_state = "surgical"
	item_state = "surgical"
	worn_state = "surgical"

/obj/item/clothing/suit/storage/jacket/coveralls
	name = "coveralls"
	desc = "A blue pair of coveralls, protects against heat."
	icon_state = "coveralls"
	item_state = "coveralls"
	worn_state = "coveralls"
	var/rolled = FALSE

/obj/item/clothing/suit/storage/jacket/coveralls/verb/roll_down_suit()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/suit/storage/jacket/coveralls)
		return
	else
		if (rolled)
			item_state = "coveralls"
			worn_state = "coveralls"
			item_state_slots["w_suit"] = "coveralls"
			usr << "<span class = 'danger'>You roll down your coveralls.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			heat_protection = ARMS|UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()
		else if (!rolled)
			item_state = "coveralls_down"
			worn_state = "coveralls_down"
			item_state_slots["w_suit"] = "coveralls_down"
			usr << "<span class = 'danger'>You roll up your coveralls.</span>"
			rolled = TRUE
			heat_protection = UPPER_TORSO|ARMS
			cold_protection = LOWER_TORSO|LEGS
			update_clothing_icon()
/obj/item/weapon/storage/belt/largepouches
	name = "large pouches"
	desc = "A belt with two large pouches, that can fit large items like machinegun belts."
	icon = 'icons/obj/clothing/belts.dmi'
	icon_state = "largepouches"
	item_state = "largepouches"
	storage_slots = 2
	max_w_class = 3
	max_storage_space = 9
	show_above_suit = TRUE
/obj/item/weapon/storage/belt/largepouches/green
	icon_state = "largepouches_green"
	item_state = "largepouches_green"
/obj/item/weapon/storage/belt/largepouches/olive
	icon_state = "largepouches_olive"
	item_state = "largepouches_olive"
/obj/item/weapon/storage/belt/largepouches/white
	icon_state = "largepouches_white"
	item_state = "largepouches_white"
/obj/item/weapon/storage/belt/largepouches/white/pkm
/obj/item/weapon/storage/belt/largepouches/white/pkm/New()
	..()
	new/obj/item/ammo_magazine/pkm/c100(src)
	new/obj/item/ammo_magazine/pkm/c100(src)
/obj/item/weapon/storage/belt/largepouches/white/rpk
/obj/item/weapon/storage/belt/largepouches/white/rpk/New()
	..()
	new/obj/item/ammo_magazine/rpk74(src)
	new/obj/item/ammo_magazine/rpk74(src)
/obj/item/weapon/storage/belt/largepouches/white/rpd
/obj/item/weapon/storage/belt/largepouches/white/rpd/New()
	..()
	new/obj/item/ammo_magazine/rpd(src)
	new/obj/item/ammo_magazine/rpd(src)
/obj/item/weapon/storage/belt/smallpouches
	name = "small pouches"
	desc = "A belt with 4 small pouches, that can fit items like magazines, knives, and other small things."
	icon = 'icons/obj/clothing/belts.dmi'
	icon_state = "smallpouches"
	item_state = "smallpouches"
	storage_slots = 4
	max_w_class = 2
	max_storage_space = 8
	show_above_suit = TRUE

/obj/item/weapon/storage/belt/smallpouches/white
	icon_state = "smallpouches_white"
	item_state = "smallpouches_white"

/obj/item/weapon/storage/belt/smallpouches/white/stormtroomper
	storage_slots = 6
	max_storage_space = 12
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(src)
		new/obj/item/weapon/handcuffs/strips(src)
		new/obj/item/weapon/handcuffs/strips(src)
		new/obj/item/weapon/grenade/flashbang/galaxywars(src)

/obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/basic
	New()
		..()
		new/obj/item/weapon/grenade/flashbang/galaxywars(src)
		new/obj/item/weapon/grenade/modern/thermaldetonator(src)

/obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/sgt
	New()
		..()
		new/obj/item/weapon/grenade/incendiary/incendiarydetonator(src)
		new/obj/item/weapon/plastique(src)

/obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/flash
	New()
		..()
		new/obj/item/weapon/grenade/flashbang/galaxywars(src)
		new/obj/item/weapon/grenade/flashbang/galaxywars(src)

/obj/item/weapon/storage/belt/smallpouches/rebel
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(src)
		new/obj/item/weapon/wrench(src)
		new/obj/item/weapon/grenade/modern/thermaldetonator(src)
		new/obj/item/weapon/grenade/modern/thermaldetonator(src)

/obj/item/weapon/storage/belt/smallpouches/red
	icon_state = "smallpouches_olive"
	item_state = "smallpouches_olive"
	New()
		..()
		new/obj/item/flashlight/militarylight(src)
		new/obj/item/stack/medical/bruise_pack/gauze(src)
		new/obj/item/ammo_magazine/m16(src)
		new/obj/item/weapon/attachment/bayonet(src)

/obj/item/weapon/storage/belt/smallpouches/red/white
	icon_state = "smallpouches_white"
	item_state = "smallpouches_white"

/obj/item/weapon/storage/belt/largepouches/redmg
/obj/item/weapon/storage/belt/largepouches/redmg/New()
	..()
	new/obj/item/ammo_magazine/dp(src)
	new/obj/item/ammo_magazine/dp(src)

/obj/item/weapon/storage/belt/largepouches/redmg/white
	icon_state = "largepouches_white"
	item_state = "largepouches_white"

/obj/item/weapon/storage/belt/smallpouches/blue
	icon_state = "smallpouches_olive"
	item_state = "smallpouches_olive"
	New()
		..()
		new/obj/item/flashlight/militarylight(src)
		new/obj/item/stack/medical/bruise_pack/gauze(src)
		new/obj/item/ammo_magazine/ak47(src)
		new/obj/item/weapon/attachment/bayonet(src)

/obj/item/weapon/storage/belt/smallpouches/blue/white
	icon_state = "smallpouches_white"
	item_state = "smallpouches_white"

/obj/item/weapon/storage/belt/largepouches/bluemg
/obj/item/weapon/storage/belt/largepouches/bluemg/New()
	..()
	new/obj/item/ammo_magazine/rpk47/drum(src)
	new/obj/item/ammo_magazine/rpk47/drum(src)

/obj/item/weapon/storage/belt/largepouches/bluemg/white
	icon_state = "largepouches_white"
	item_state = "largepouches_white"

/obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt
	storage_slots = 6
/obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/thompson(src)
	new/obj/item/ammo_magazine/thompson(src)
	new/obj/item/ammo_magazine/thompson(src)
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/weapon/whistle(src)

/obj/item/weapon/storage/belt/smallpouches/us_ww2_sgtc
	storage_slots = 6
/obj/item/weapon/storage/belt/smallpouches/us_ww2_sgtc/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/m1carbine(src)
	new/obj/item/ammo_magazine/m1carbine(src)
	new/obj/item/ammo_magazine/m1carbine/box(src)
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/weapon/whistle(src)

/obj/item/weapon/storage/belt/smallpouches/us_ww2_sniper
	max_w_class = 3
/obj/item/weapon/storage/belt/smallpouches/us_ww2_sniper/New()
	..()
	new/obj/item/ammo_magazine/springfield(src)
	new/obj/item/ammo_magazine/springfield(src)
	new/obj/item/ammo_magazine/m3006box(src)

/obj/item/weapon/storage/belt/smallpouches/us_ww2_gunner
	storage_slots = 6
	max_storage_space = 12
/obj/item/weapon/storage/belt/smallpouches/us_ww2_gunner/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/bar(src)
	new/obj/item/ammo_magazine/bar(src)
	new/obj/item/ammo_magazine/bar(src)
	new/obj/item/ammo_magazine/bar(src)
	new/obj/item/ammo_magazine/bar(src)

/obj/item/weapon/storage/belt/smallpouches/us_ww2
/obj/item/weapon/storage/belt/smallpouches/us_ww2/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/garand(src)
	new/obj/item/ammo_magazine/garand(src)
	new/obj/item/ammo_magazine/garand(src)

/obj/item/weapon/storage/belt/smallpouches/us_ww2_grease
/obj/item/weapon/storage/belt/smallpouches/us_ww2_grease/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/greasegun(src)
	new/obj/item/ammo_magazine/greasegun(src)
	new/obj/item/ammo_magazine/greasegun(src)

/obj/item/weapon/storage/belt/smallpouches/green
	icon_state = "smallpouches_green"
	item_state = "smallpouches_green"


/obj/item/weapon/storage/belt/smallpouches/green/bint
/obj/item/weapon/storage/belt/smallpouches/green/bint/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)

/obj/item/weapon/storage/belt/smallpouches/green/chechoff
/obj/item/weapon/storage/belt/smallpouches/green/chechoff/New()
	..()
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/weapon/horn(src)
	new/obj/item/weapon/reagent_containers/food/drinks/flask/officer/vodka(src)

/obj/item/weapon/storage/belt/smallpouches/green/rusoff
	storage_slots = 5
/obj/item/weapon/storage/belt/smallpouches/green/rusoff/New()
	..()
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/weapon/reagent_containers/food/drinks/flask/officer/vodka(src)
	new/obj/item/ammo_magazine/ak74(src)
	new/obj/item/ammo_magazine/ak74(src)

/obj/item/weapon/storage/belt/smallpouches/green/officeruni
	storage_slots = 4
/obj/item/weapon/storage/belt/smallpouches/green/officeruni/New()
	..()
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/weapon/reagent_containers/food/drinks/flask/officer/vodka(src)
	new/obj/item/weapon/compass(src)

/obj/item/weapon/storage/belt/smallpouches/green/insuroff
/obj/item/weapon/storage/belt/smallpouches/green/insuroff/New()
	..()
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/weapon/horn(src)
	new/obj/item/weapon/reagent_containers/food/drinks/flask/officer/tea(src)

/obj/item/weapon/storage/belt/smallpouches/green/mosin
/obj/item/weapon/storage/belt/smallpouches/green/mosin/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/mosin (src)
	new/obj/item/ammo_magazine/mosin (src)
	new/obj/item/ammo_magazine/mosin (src)

/obj/item/weapon/storage/belt/smallpouches/green/mosinsniper
	max_w_class = 3

/obj/item/weapon/storage/belt/smallpouches/green/mosinsniper/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/mosin (src)
	new/obj/item/ammo_magazine/mosinbox (src)

/obj/item/weapon/storage/belt/smallpouches/rusoff
/obj/item/weapon/storage/belt/smallpouches/rusoff/New()
	..()
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/weapon/whistle(src)
	new/obj/item/weapon/reagent_containers/food/drinks/flask/officer/vodka(src)

/obj/item/weapon/storage/belt/smallpouches/olive
	icon_state = "smallpouches_olive"
	item_state = "smallpouches_olive"

/obj/item/weapon/storage/belt/smallpouches/olive/m16
/obj/item/weapon/storage/belt/smallpouches/olive/m16/New()
	..()
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/olive/m16/sf
	storage_slots = 5
/obj/item/weapon/storage/belt/smallpouches/olive/m16/sf/New()
	..()
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/weapon/grenade/coldwar/m67(src)
	new/obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/olive/m16_smoke
	storage_slots = 5
/obj/item/weapon/storage/belt/smallpouches/olive/m16_smoke/New()
	..()
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/weapon/grenade/smokebomb/m18smoke(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/olive/m16_grenade
	storage_slots = 5
/obj/item/weapon/storage/belt/smallpouches/olive/m16_grenade/New()
	..()
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/weapon/grenade/coldwar/m67(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/olive/us_sgt
	storage_slots = 5
/obj/item/weapon/storage/belt/smallpouches/olive/us_sgt/New()
	..()
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/weapon/grenade/smokebomb/m18smoke(src)
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/olive/us_lt
	storage_slots = 5
/obj/item/weapon/storage/belt/smallpouches/olive/us_lt/New()
	..()
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/weapon/grenade/smokebomb/m18smoke(src)
	new/obj/item/ammo_magazine/greasegun(src)
	new/obj/item/ammo_magazine/greasegun(src)
	new/obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/olive/us_gren
	can_hold = list(
		/obj/item/weapon/gun/projectile/pistol
	)
/obj/item/weapon/storage/belt/smallpouches/olive/us_gren/New()
	..()
	new/obj/item/ammo_magazine/m1911(src)
	new/obj/item/ammo_magazine/m1911(src)
	new/obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/olive/m14
/obj/item/weapon/storage/belt/smallpouches/olive/m14/New()
	..()
	new/obj/item/ammo_magazine/m14(src)
	new/obj/item/ammo_magazine/m14(src)
	new/obj/item/weapon/grenade/smokebomb/m18smoke(src)
	new/obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/olive/greasegun
/obj/item/weapon/storage/belt/smallpouches/olive/greasegun/New()
	..()
	new/obj/item/ammo_magazine/greasegun(src)
	new/obj/item/ammo_magazine/greasegun(src)
	new/obj/item/ammo_magazine/greasegun(src)
	new/obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/ak74m_smoke
	storage_slots = 5
/obj/item/weapon/storage/belt/smallpouches/green/ak74m_smoke/New()
	..()
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/weapon/grenade/smokebomb/rdg2(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/ak74m_trench
	storage_slots = 5
/obj/item/weapon/storage/belt/smallpouches/green/ak74m_trench/New()
	..()
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/weapon/foldable_shovel/trench/etool(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/clothing/under/blue_shorts
	name = "blue shorts"
	desc = "Basic blue shorts."
	icon_state = "shorts_blue"
	item_state = "shorts_blue"
	worn_state = "shorts_blue"

/obj/item/clothing/under/red_shorts
	name = "red shorts"
	desc = "Basic red shorts"
	icon_state = "shorts_red"
	item_state = "shorts_red"
	worn_state = "shorts_red"

/obj/item/clothing/under/yellow_shorts
	name = "yellow shorts"
	desc = "Basic yellow shorts"
	icon_state = "shorts_yellow"
	item_state = "shorts_yellow"
	worn_state = "shorts_yellow"
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////PHILIPPINE-AMERICAN WAR///////////////////////////////////////////////////////////////////////
/obj/item/clothing/head/ph_us_war/filipino
/obj/item/clothing/head/ph_us_war/filipino/fil_off_cap
	name = "Filipino Officer Cap"
	desc = "A cap worn by Filipino Officers of the Philippine Republic Army."
	icon_state = "fil_off_cap"
	item_state = "fil_off_cap"

/obj/item/clothing/head/ph_us_war/filipino/baliwag
	name = "Baliwag"
	desc = "A common hat worn by the spanish and filipinos, this one bearing the mark of the Philippine Republic Army."
	icon_state = "baliwag"
	item_state = "baliwag"
	var/adjusted = FALSE
/obj/item/clothing/head/ph_us_war/filipino/baliwag/verb/adjust()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/ph_us_war/filipino/baliwag)
		return
	else
		if (adjusted)
			item_state = "baliwag"
			worn_state = "baliwag"
			item_state_slots["slot_head"] = "baliwag"
			usr << "<span class = 'danger'>You pull your hat down.</span>"
			adjusted = FALSE
		else if (!adjusted)
			item_state = "baliwag_down"
			worn_state = "baliwag_down"
			item_state_slots["slot_head"] = "baliwag_down"
			usr << "<span class = 'danger'>You push up your hat.</span>"
			adjusted = TRUE
	update_clothing_icon()
/obj/item/clothing/under/ph_us_war/filipino
/obj/item/clothing/under/ph_us_war/filipino/filuni
	name = "Philippine Republic Army Uniform"
	desc = "A standard philippine republic army uniform."
	icon_state = "filuni"
	item_state = "filuni"
	worn_state = "filuni"
	var/rolled = FALSE

/obj/item/clothing/under/ph_us_war/filipino/filuni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ph_us_war/filipino/filuni)
		return
	else
		if (rolled)
			item_state = "filuni"
			worn_state = "filuni"
			item_state_slots["w_uniform"] = "filuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "filuni_rolled"
			worn_state = "filuni_rolled"
			item_state_slots["w_uniform"] = "filuni_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/under/ph_us_war/filipino/tiradores
	name = "Tiradores de Muerta Uniform"
	desc = "A standard philippine republic army uniform."
	icon_state = "filuni_sniper"
	item_state = "filuni_sniper"
	worn_state = "filuni_sniper"
	var/rolled = FALSE

/obj/item/clothing/under/ph_us_war/filipino/tiradores/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ph_us_war/filipino/tiradores)
		return
	else
		if (rolled)
			item_state = "filuni_sniper"
			worn_state = "filuni_sniper"
			item_state_slots["w_uniform"] = "filuni_sniper"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "filuni_sniper_rolled"
			worn_state = "filuni_sniper_rolled"
			item_state_slots["w_uniform"] = "filuni_sniper_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/under/ph_us_war/american
/obj/item/clothing/under/ph_us_war/american/us_uni
	name = "US Army Uniform"
	desc = "A standard tropical US army uniform."
	icon_state = "us_fp"
	item_state = "us_fp"
	worn_state = "us_fp"
	var/rolled = FALSE

/obj/item/clothing/under/ph_us_war/american/us_uni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ph_us_war/american/us_uni)
		return
	else
		if (rolled)
			item_state = "us_fp"
			worn_state = "us_fp"
			item_state_slots["w_uniform"] = "us_fp"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "us_fp_rolled"
			worn_state = "us_fp_rolled"
			item_state_slots["w_uniform"] = "us_fp_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/under/ph_us_war/american/us_off_uni
	name = "US Army Officer Uniform"
	desc = "A standard tropical US army officer uniform."
	icon_state = "us_fp_off"
	item_state = "us_fp_off"
	worn_state = "us_fp_off"
	var/rolled = FALSE

/obj/item/clothing/under/ph_us_war/american/us_off_uni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ph_us_war/american/us_off_uni)
		return
	else
		if (rolled)
			item_state = "us_fp_off"
			worn_state = "us_fp_off"
			item_state_slots["w_uniform"] = "us_fp_off"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "us_fp_off_rolled"
			worn_state = "us_fp_off_rolled"
			item_state_slots["w_uniform"] = "us_fp_off_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/head/ph_us_war/american
/obj/item/clothing/head/ph_us_war/american/infantry_hat
	name = "US Army Hat"
	desc = "A hat worn by enlisted men of the US Army in tropical climates."
	icon_state = "us_fp_hat"
	item_state = "us_fp_hat"

/obj/item/clothing/head/ph_us_war/american/infantry_hat/civie
	name = "cowboy hat"
	desc = "A hat worn by stylish rural people."

/obj/item/clothing/accessory/storage/webbing/filipino
	name = "filipino webbing"
	desc = "8 black leather pouches."
	icon_state = "fp_webbing"
	item_state = "fp_webbing"
	slots = 8
	New()
		..()
		hold.can_hold = list(/obj/item/ammo_magazine, /obj/item/weapon/material/kitchen/utensil/knife, /obj/item/weapon/attachment/bayonet, /obj/item/weapon/grenade, /obj/item/weapon/attachment, /obj/item/weapon/handcuffs, /obj/item/ammo_casing, /obj/item/weapon/reagent_containers/food/drinks/bottle/canteen, /obj/item/weapon/material/shovel, /obj/item/weapon/key)

/obj/item/clothing/suit/storage/coat/winter_coat
	name = "brown winter coat"
	desc = "A thick winter coat."
	icon_state = "winter_coat"
	item_state = "winter_coat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT

//////spanish civil war

/obj/item/clothing/under/spain/republican //recolored russian ww1 uniform cause they look very similiar
	name = "Spanish Republican Uniform"
	desc = "A Uniform used by the spanish republican forces."
	icon_state = "spanishrepublican"
	item_state = "spanishrepublican"
	worn_state = "spanishrepublican"

/obj/item/clothing/under/spain/nationalist
	name = "Spanish Nationalist Uniform"
	desc = "A Uniform used by the spanish Nationalist forces."
	icon_state = "spanishnationalist"
	item_state = "spanishnationalist"
	worn_state = "spanishnationalist"

/obj/item/clothing/under/spain/brigadist
	name = "Brigadists Uniform"
	desc = "A Cheap Blue Uniform."
	icon_state = "intbrigadist"
	item_state = "intbrigadist"
	worn_state = "intbrigadist"

// Blugoslavia
/obj/item/clothing/under/blugoslavia/standard
	name = "Blugoslavian Uniform"
	desc = "An easy to see uniform used by Blugoslavia."
	icon_state = "baf_standard"
	item_state = "baf_standard"
	worn_state = "baf_standard"

/obj/item/clothing/under/blugoslavia/standard/combat
	name = "Blugoslavian Camo Uniform"
	desc = "A Blugoslavian combat uniform, slightly camoed."
	icon_state = "baf_standardc"
	item_state = "baf_standardc"
	worn_state = "baf_standardc"

/obj/item/clothing/under/blugoslavia/standard/squadlead
	name = "Blugoslavian Camo Uniform"
	desc = "A Blugoslavian combat uniform, used by squad leaders."
	icon_state = "baf_standardc"
	item_state = "baf_standardc"
	worn_state = "baf_standardc"

/obj/item/clothing/under/blugoslavia/standard/command
	name = "Blugoslavian Ceremonial Uniform"
	desc = "A ceremonial uniform of Blugoslavia, used by officers and commanders"
	icon_state = "baf_command"
	item_state = "baf_command"
	worn_state = "baf_command"

// Redmenia
/obj/item/clothing/under/redmenia/standard
	name = "Redmenian army uniform"
	desc = "An easy to see uniform used by Blugoslavia."
	icon_state = "rdf_standard"
	item_state = "rdf_standard"
	worn_state = "rdf_standard"

/obj/item/clothing/under/redmenia/standard/combat
	name = "Redmenian Camo Uniform"
	desc = "A Redmenian combat uniform, slightly camoed."
	icon_state = "rdf_standardc"
	item_state = "rdf_standardc"
	worn_state = "rdf_standardc"

/obj/item/clothing/under/redmenia/standard/squadlead
	name = "Redmenian Camo Uniform"
	desc = "A Redmenian combat uniform used by squad leaders."
	icon_state = "rdf_standardc"
	item_state = "rdf_standardc"
	worn_state = "rdf_standardc"

/obj/item/clothing/under/redmenia/standard/command
	name = "Redmenian Ceremonial Uniform"
	desc = "A ceremonial uniform of Redmenia, used by officers and commanders"
	icon_state = "rdf_command"
	item_state = "rdf_command"
	worn_state = "rdf_command"

/obj/item/clothing/under/redmenia/standard/modern
	name = "Redmenian Camo Uniform"
	desc = "A Redmenian combat uniform, slightly camoed."
	icon_state = "rdf_modern"
	item_state = "rdf_modern"
	worn_state = "rdf_modern"