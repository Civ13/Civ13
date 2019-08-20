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
			item_state_slots["slot_w_uniform"] = "japuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
		else if (!rolled)
			item_state = "japunirolled"
			worn_state = "japunirolled"
			item_state_slots["slot_w_uniform"] = "japunirolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
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
			item_state_slots["slot_w_uniform"] = "japoffuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
		else if (!rolled)
			item_state = "japoffunirolled"
			worn_state = "japoffunirolled"
			item_state_slots["slot_w_uniform"] = "japoffunirolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
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
			item_state_slots["slot_w_uniform"] = "rusuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
		else if (!rolled)
			item_state = "rusunirolled"
			worn_state = "rusunirolled"
			item_state_slots["slot_w_uniform"] = "rusunirolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
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
		/obj/item/weapon/material,
		/obj/item/weapon/grenade,
		/obj/item/weapon/attachment,
		/obj/item/weapon/gun/projectile/pistol,
		/obj/item/weapon/gun/projectile/revolver,
		/obj/item/weapon/handcuffs,
		/obj/item/ammo_casing,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
		/obj/item/weapon/shovel
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
	new /obj/item/weapon/attachment/bayonet/military(src)

/obj/item/weapon/storage/belt/jap/ww2soldier
/obj/item/weapon/storage/belt/jap/ww2soldier/New()
	..()
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/ammo_magazine/arisaka99(src)
	new /obj/item/weapon/attachment/bayonet/military(src)

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
	name = "black suit"
	desc = "A formal charcoal grey suit."
	icon_state = "charcoal_suit"
	item_state = "charcoal_suit"
	worn_state = "charcoal_suit"

/obj/item/clothing/suit/storage/jacket/navy_suit
	name = "black suit"
	desc = "A formal navy blue suit."
	icon_state = "navy_suit"
	item_state = "navy_suit"
	worn_state = "navy_suit"

/obj/item/clothing/suit/storage/jacket/checkered_suit
	name = "black suit"
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

/obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt
/obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/thompson(src)
	new/obj/item/ammo_magazine/thompson(src)
	new/obj/item/ammo_magazine/thompson(src)

/obj/item/weapon/storage/belt/smallpouches/us_ww2_sniper
/obj/item/weapon/storage/belt/smallpouches/us_ww2_sniper/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/ammo_magazine/springfield(src)
	new/obj/item/ammo_magazine/springfield(src)
	new/obj/item/ammo_magazine/springfield(src)

/obj/item/weapon/storage/belt/smallpouches/us_ww2_gunner
/obj/item/weapon/storage/belt/smallpouches/us_ww2_gunner/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)
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

/obj/item/weapon/storage/belt/smallpouches/green
	icon_state = "smallpouches_green"
	item_state = "smallpouches_green"


/obj/item/weapon/storage/belt/smallpouches/green/bint
/obj/item/weapon/storage/belt/smallpouches/green/bint/New()
	..()
	new/obj/item/stack/medical/bruise_pack/bint(src)