/*Index*/
/* * - 1 Medieval Shoes & Boots
   * - 2 Medieval Gloves & Gauntlets
   * - 3 Medieval Headpieces
   * - 4 Medieval Suits
   * - 5 Medieval Armor
   * - 6 Medieval Armor Accessories
   * - 7 Medieval Crowns
   * - 8 Medieval Helmets
   * - 8a Crusader Helmets
   * - 8b Baltic Helmets
   * - 8c Crusader Priests
   * - 9 Medieval Equipment Crates
   /////////////////////////////////////
   * - 10 Extra-Cultural Medieval Clothes
   * - 10a Medieval Mayan
   * - 10b Medieval Norse Armor
   * - 10c Medieval Chinese Armor
   * - 10d Medieval Mamluk Armor
   * - 10e Medieval Steppe Clothes & Armor
   /////////////////////////////////////
   * - 11 Medieval Japanese
   * - 11a Medieval Japanese Armor
   * - 11b Medieval Japanese Uniforms
   * - 11c Medieval Japanese Shoes & Boots
   * - 11d Medieval Japanese Headpieces & Helmets
   * - 11e Medieval Japanese Masks
   /////////////////////////////////////
   * - 12 Miscallenous Medieval Extra-Cultural Clothes
   * - 13 Fantasy Medieval Clothes
   * - 13a Fantasy Crusader Helmets
   * - 13b Dark Souls Armor
   * - 14 skryim*/

/* Medieval Shoes & Boots*/

/obj/item/clothing/shoes/medieval
	name = "leather shoes"
	desc = "A pair of simple, thin leather shoes. Covers up to the ankle."
	icon_state = "medieval"
	item_state = "medieval"
	worn_state = "medieval"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 15, arrow = 10, gun = FALSE, energy = 8, bomb = 15, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6

/obj/item/clothing/shoes/medieval/arab
	name = "arabic leather shoes"
	desc = "A pair of simple, thin leather shoes. Loose at the tip."
	icon_state = "arab"
	item_state = "arab"
	worn_state = "arab"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 10, arrow = 8, gun = FALSE, energy = 6, bomb = 12, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6

/obj/item/clothing/shoes/medieval/emirate
	name = "emirate leather shoes"
	desc = "A pair of simple, arabic style leather shoes. Extra padded & loose at the tip."
	icon_state = "emir"
	item_state = "emir"
	worn_state = "emir"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 15, arrow = 10, gun = FALSE, energy = 8, bomb = 15, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6

/obj/item/clothing/shoes/medieval/knight
	name = "Sabatons"
	desc = "A pair of plated armored boots."
	icon_state = "knight"
	item_state = "knight"
	worn_state = "knight"
	body_parts_covered = FEET
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 75, arrow = 60, gun = 10, energy = 8, bomb = 25, bio = 15, rad = FALSE)
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	slowdown = 0.1
	health = 35

/* Medieval Gloves & Gauntlets*/

/obj/item/clothing/gloves/gauntlets
	name = "armored gauntlets"
	desc = "A pair of armored iron gauntlets."
	icon_state = "gauntlet"
	item_state = "gauntlet"
	worn_state = "gauntlet"
	body_parts_covered = HANDS
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 75, arrow = 60, gun = 10, energy = 8, bomb = 25, bio = 15, rad = FALSE)
	cold_protection = HANDS
	min_cold_protection_temperature = GLOVES_MIN_COLD_PROTECTION_TEMPERATURE
	slowdown = 0.1
	health = 30

/* Medieval Headpieces*/

/obj/item/clothing/head/artisan
	name = "artisan hat"
	desc = "a large artisan hat."
	icon_state = "artisan"
	item_state = "artisan"
	worn_state = "artisan"

/obj/item/clothing/head/feathered_hat
	name = "feathered hat"
	desc = "a feathered hat."
	icon_state = "feathered_hat"
	item_state = "feathered_hat"
	worn_state = "feathered_hat"

/obj/item/clothing/head/count_hat
	name = "count hat"
	desc = "a fancy, feathered hat."
	icon_state = "medieval_count_hat"
	item_state = "medieval_count_hat"
	worn_state = "medieval_count_hat"

/obj/item/clothing/head/cavalier
	name = "cavalier hat"
	desc = "a free willled and fanciful leather feathered hat."
	icon_state = "cavalier"
	item_state = "cavalier"
	worn_state = "cavalier"

/obj/item/clothing/head/noblehat1
	name = "brown noble hat"
	icon_state = "noblehat1"
	item_state = "noblehat1"

/obj/item/clothing/head/noblehat2
	name = "black noble hat"
	icon_state = "noblehat2"
	item_state = "noblehat2"

/obj/item/clothing/head/phrigian_hat
	name = "phrigian hat"
	desc = "a knob ended hat of the ancient phrigian design. Often worn by merchants or peasants of jewish descent."
	icon_state = "phrigian_hat"
	item_state = "phrigian_hat"
	worn_state = "phrigian_hat"

/obj/item/clothing/head/phrigian_hat/red
	name = "red phrigian hat"
	icon_state = "phrigian_hat_red"
	item_state = "phrigian_hat_red"
	worn_state = "phrigian_hat_red"

/obj/item/clothing/head/phrigian_hat/blue
	name = "blue phrigian hat"
	icon_state = "phrigian_hat_blue"
	item_state = "phrigian_hat_blue"
	worn_state = "phrigian_hat_blue"

/obj/item/clothing/head/phrigian_hat/doge
	name = "doge hat"
	desc = "a ornate knob ended hat banded in gold of the ancient phrigian design. Often worn by republic rulers over many petty merchantile aristocrats."
	icon_state = "doge"
	item_state = "doge"
	worn_state = "doge"

/obj/item/clothing/head/hooded_cape
	name = "long black hooded cape"
	desc = "A long black hooded cape. Often worn those wishing to conceal themselves in the shadows."
	icon_state = "black_cape"
	item_state = "black_cape"
	worn_state = "black_cape"
	body_parts_covered = HEAD
	flags_inv = BLOCKHAIR|HIDEFACE

/obj/item/clothing/head/plaguedoctor
	name = "plague doctor hat"
	desc = "A a short brimmed black hat. Often worn by plague doctors to cut a discreet figure in the streets between visitations."
	icon_state = "plaguedoctor"
	item_state = "plaguedoctor"
	worn_state = "plaguedoctor"
	flags_inv = BLOCKHAIR
	body_parts_covered = HEAD

/obj/item/clothing/head/nun_hood //path can't be changed, has dependencies in civilian.dm & civ_factions.dm
	name = "nun hood"
	desc = "A typical nun hood. Made in such a way to indicate commitment, like that found in marriage to the faith."
	icon_state = "nun_hood"
	item_state = "nun_hood"
	worn_state = "nun_hood"
	flags_inv = BLOCKHAIR
	body_parts_covered = HEAD

/obj/item/clothing/head/turban
	name = "turban"
	desc = "a colored, light fabric turban."
	icon_state = "turban1"
	item_state = "turban1"
	worn_state = "turban1"
	heat_protection = HEAD
/obj/item/clothing/head/turban/New()
	..()
	var/pickcolor = pick("turban1", "turban2", "turban3", "turban4")
	icon_state = pickcolor
	item_state = pickcolor
	worn_state = pickcolor

/obj/item/clothing/head/turban/imam
	name = "white turban"
	desc = "a simple white turban."
	icon_state = "turban_w"
	item_state = "turban_w"
	worn_state = "turban_w"
/obj/item/clothing/head/turban/imam/New()
	..()
	icon_state = "turban_w"
	item_state = "turban_w"
	worn_state = "turban_w"

/obj/item/clothing/head/turban/sultan
	name = "grand turban"
	desc = "a large turban often worn by figures of importance.."
	icon_state = "sultan"
	item_state = "sultan"
	worn_state = "sultan"
	heat_protection = HEAD
/obj/item/clothing/head/turban/sultan/New()
	..()
	icon_state = "sultan"
	item_state = "sultan"
	worn_state = "sultan"

/obj/item/clothing/head/keffiyeh
	name = "keffiyeh"
	desc = "A headdress fashioned from a scarf with a checkered pattern."
	icon_state = "keffiyeh_black"
	item_state = "keffiyeh_black"
	worn_state = "keffiyeh_black"
	heat_protection = HEAD

/obj/item/clothing/head/keffiyeh/red
	icon_state = "keffiyeh_red"
	item_state = "keffiyeh_red"
	worn_state = "keffiyeh_red"

/obj/item/clothing/head/pakol
	name = "pakol"
	desc = "A soft round-topped men's cap made of wool."
	icon_state = "pakol_rose"
	item_state = "pakol_rose"
	worn_state = "pakol_rose"
	heat_protection = HEAD
/obj/item/clothing/head/pakol/New()
	..()
	var/pickcolor = pick("pakol_rose", "pakol_beige", "pakol_bgrey")
	icon_state = pickcolor
	item_state = pickcolor
	worn_state = pickcolor

/*Medieval Suits*/

/obj/item/clothing/suit/storage/jacket/arabic_robe
	name = "arabic robe"
	desc = "A light, loose fitting arabic robe."
	icon = 'icons/obj/clothing/uniforms.dmi'
	icon_state = "arabw_robe"
	item_state = "arabw_robe"
	worn_state = "arabw_robe"
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/suit/arabic_robe
	name = "light white arabic robe"
	desc = "A light, white, loose fitting garment for keeping the sun off."
	icon = 'icons/obj/clothing/uniforms.dmi'
	icon_state = "arab2"
	item_state = "arab2"
	worn_state = "arab2"
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/suit/storage/arabic_robe
	name = "light white arabic robe"
	desc = "A light, white, loose fitting garment for keeping the sun off."
	icon = 'icons/obj/clothing/uniforms.dmi'
	icon_state = "arab2"
	item_state = "arab2"
	worn_state = "arab2"
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/suit/storage/jacket/plaguedoctor //moved from jobs.dm
	name = "plague doctor suit"
	desc = "Used by plague doctors. Only adds to the mystery behind their methods."
	icon_state = "plaguedoctor"
	icon_state = "plaguedoctor"
	icon_state = "plaguedoctor"

/obj/item/clothing/suit/storage/coat/fancy_fur_coat
	name = "fancy fur coat"
	desc = "A fancy and expensive fur coat."
	icon_state = "fancy_fur_coat"
	item_state = "fancy_fur_coat"
	worn_state = "fancy_fur_coat"
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/suit/storage/coat/overlord_coat
	name = "overlord robe"
	desc = "An extremely elegant robe worn by powerful undead."
	icon_state = "overlord_coat"
	item_state = "overlord_coat"
	worn_state = "overlord_coat"
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/suit/storage/jacket/regal
	name = "regal ermine cape"
	desc = "A large cape finely decked in stylized fur pattern often used to denote the most prominent members amongst noble circles."
	icon_state = "regal_cape"
	item_state = "regal_cape"
	worn_state = "regal_cape"
	cold_protection = UPPER_TORSO|ARMS

/obj/item/clothing/suit/storage/coat/monk_robes
	name = "monk robes"
	desc = "Robes commonly worn by monks, warm in the winters."
	icon_state = "monk_robes"
	item_state = "monk_robes"
	worn_state = "monk_robes"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/suit/storage/coat/monk_robes/verb/toggle_hood()
	set category = null
	set src in usr
	set name = "Toggle Hood"
	if (hood)
		icon_state = "monk_robes"
		item_state = "monk_robes"
		worn_state = "monk_robes"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
		item_state_slots["slot_wear_suit"] = "monk_robes"
		usr << "<span class = 'danger'>you take off your robes' hood.</span>"
		update_icon()
		hood = FALSE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return
	else if (!hood)
		icon_state = "monk_robes_hood"
		item_state = "monk_robes_hood"
		worn_state = "monk_robes_hood"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|HEAD
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT|HEAD
		item_state_slots["slot_wear_suit"] = "monk_robes_hood"
		usr << "<span class = 'danger'>you cover your head with your robes' hood.</span>"
		update_icon()
		hood = TRUE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return

/* Medieval Uniforms*/

/obj/item/clothing/under/medieval
	name = "white tunic"
	desc = "A long white tunic, with golden trimmings."
	icon_state = "white_tunic_long"
	item_state = "white_tunic_long"
	worn_state = "white_tunic_long"

/obj/item/clothing/under/count_outfit
	name = "count outfit"
	desc = "A fancy count outfit."
	icon_state = "count_outfit"
	item_state = "count_outfit"
	worn_state = "count_outfit"

/obj/item/clothing/under/renaissance
	name = "purple renaissance clothing"
	desc = "A baggy renaissance-style outfit."
	icon_state = "renaissance"
	item_state = "renaissance"
	worn_state = "renaissance"

/obj/item/clothing/under/renaissance/doge
	name = "doge outfit"
	desc = "A gold embroidered baggy renaissance-style outfit. Often worn by republic rulers over many petty merchantile aristocrats."
	icon_state = "doge"
	item_state = "doge"
	worn_state = "doge"

/obj/item/clothing/under/renaissance_pontifical
	name = "pontifical renaissance clothing"
	desc = "A baggy renaissance-style outfit, with colored stripes."
	icon_state = "pontifical"
	item_state = "pontifical"
	worn_state = "pontifical"

/obj/item/clothing/under/medieval/crusader
	name = "crusader tunic"
	desc = "A white tunic with a red cross in the middle."
	icon_state = "crusader1"
	item_state = "crusader1"
	worn_state = "crusader1"

/obj/item/clothing/under/medieval/crusader/New()
	..()
	var/randcloth = pick("crusader1","crusader2")
	icon_state = randcloth
	item_state = randcloth
	worn_state = randcloth

/obj/item/clothing/under/medieval/yellow
	name = "yellow tunic"
	desc = "A light yellow tunic."
	icon_state = "yellow_tunic"
	item_state = "yellow_tunic"
	worn_state = "yellow_tunic"

/obj/item/clothing/under/medieval/leather
	name = "leather tunic"
	desc = "A light leather tunic."
	icon_state = "leather_tunic"
	item_state = "leather_tunic"
	worn_state = "leather_tunic"

/obj/item/clothing/under/medieval/kilt
	name = "kilt"
	desc = "A green and tartan woolen kilt."
	icon_state = "kilt"
	item_state = "kilt"
	worn_state = "kilt"

/obj/item/clothing/under/medieval/beggar_clothing
	name = "beggar clothing"
	desc = "Loosely stitched from patch cloth, contains deep pockets for spare change."
	icon_state = "beggar_clothing"
	item_state = "beggar_clothing"
	worn_state = "beggar_clothing"

/obj/item/clothing/under/medieval/blue
	name = "blue tunic"
	desc = "A light blue tunic."
	icon_state = "blue_tunic"
	item_state = "blue_tunic"
	worn_state = "blue_tunic"

/obj/item/clothing/under/medieval/blue2
	name = "blue-white tunic"
	desc = "A light blue and white tunic."
	icon_state = "blue_tunic2"
	item_state = "blue_tunic2"
	worn_state = "blue_tunic2"

/obj/item/clothing/under/medieval/green
	name = "green tunic"
	desc = "A light green tunic."
	icon_state = "green_tunic"
	item_state = "green_tunic"
	worn_state = "green_tunic"

/obj/item/clothing/under/medieval/red
	name = "red tunic"
	desc = "A light red tunic."
	icon_state = "red_tunic"
	item_state = "red_tunic"
	worn_state = "red_tunic"

/obj/item/clothing/under/medieval/red2
	name = "yellow-red tunic"
	desc = "A light red and yellow tunic."
	icon_state = "red_tunic2"
	item_state = "red_tunic2"
	worn_state = "red_tunic2"

/obj/item/clothing/under/medieval/arabic_tunic
	name = "fancy arabic tunic"
	desc = "A light fitting tunic with arabic motifs."
	icon_state = "arabw_tunic"
	item_state = "arabw_tunic"
	worn_state = "arabw_tunic"
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/medieval/lighttunic
	name = "light brown tunic"
	desc = "A light, loose fitting tunic."
	icon_state = "arab1"
	item_state = "arab1"
	worn_state = "arab1"
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/medieval/emirate
	name = "emirate tunic"
	desc = "A loose fitting green tunic with arabic motifs and long sleeves. Often worn by emirate rulers"
	icon_state = "emir_tunic"
	item_state = "emir_tunic"
	worn_state = "emir_tunic"
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/medieval/arab1
	name = "light brown arabic tunic"
	desc = "A light, loose fitting arabic tunic."
	icon_state = "arab1"
	item_state = "arab1"
	worn_state = "arab1"
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/medieval/arab2
	name = "light white arabic tunic"
	desc = "A light, loose fitting arabic tunic."
	icon_state = "arab2"
	item_state = "arab2"
	worn_state = "arab2"
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/medieval/arab3
	name = "white arabic tunic"
	desc = "A loose fitting arabic tunic."
	icon_state = "arab3"
	item_state = "arab3"
	worn_state = "arab3"
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/nun
	name = "nun dress"
	desc = "A very modest nun dress. With a small cross around the neck, to aide protection against temptation."
	icon_state = "nun"
	item_state = "nun"
	worn_state = "nun"

/obj/item/clothing/under/medieval/wise_knight
	name = "Wise Knight robes"
	desc = "A lightly darkened robe used by wise knights."
	icon_state = "wise_knight"
	item_state = "wise_knight"
	worn_state = "wise_knight"

/obj/item/clothing/under/medieval/arrogant_warrior
	name = "Arrogant Warrior robes"
	desc = "A darkened robe used by upset warriors."
	icon_state = "arrogant_warrior"
	item_state = "arrogant_warrior"
	worn_state = "arrogant_warrior"

/obj/item/clothing/under/christian_priest
	name = "black priest outfit"
	desc = "A plain black outfit with a clerical white collar around the neck, often worn by priests of organized religions."
	icon_state = "christian_priest"
	item_state = "christian_priest"
	worn_state = "christian_priest"

/obj/item/clothing/under/landschneckt
	name = "green landschneckt uniform"
	desc = "A ornate and bright uniform often worn by elite mercenaries & central european troops during the 15th century."
	icon_state = "landschneckt"
	item_state = "landschneckt"
	worn_state = "landschneckt"

/obj/item/clothing/under/landschneckt/blue
	name = "blue landschneckt uniform"
	desc = "A ornate and bright uniform often worn by elite mercenaries & central european troops during the 15th century."
	icon_state = "b_landschneckt"
	item_state = "b_landschneckt"
	worn_state = "b_landschneckt"

/obj/item/clothing/under/landschneckt/red
	name = "red landschneckt uniform"
	desc = "A ornate and bright uniform often worn by elite mercenaries & central european troops during the 15th century."
	icon_state = "r_landschneckt"
	item_state = "r_landschneckt"
	worn_state = "r_landschneckt"

/obj/item/clothing/under/blackdress
	name = "plain black dress"
	desc = "A plain black dress for women to properly uphold their modesty"
	icon_state = "dress_black"
	item_state = "dress_black"
	worn_state = "dress_black"

/obj/item/clothing/under/sari/blue
	name = "blue sari"
	desc = "A satin layered piece of clothing for women, made in indian style"
	icon_state = "blue_sari"
	item_state = "blue_sari"
	worn_state = "blue_sari"

/obj/item/clothing/under/sari/red
	name = "red sari"
	desc = "A satin layered piece of clothing for women, made in indian style"
	icon_state = "red_sari"
	item_state = "red_sari"
	worn_state = "red_sari"

/* Medieval Armor*/

/obj/item/clothing/suit/armor/medieval
	name = "plated armor"
	desc = "A thick, expensive iron armor, covering most of the body."
	icon_state = "knight_simple"
	item_state = "knight_simple"
	worn_state = "knight_simple"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 85, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/suit/armor/royal
	name = "royal plated armor"
	desc = "A thick, expensive iron armor, covering most of the body."
	icon_state = "royalplate"
	item_state = "royalplate"
	worn_state = "royalplate"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 85, arrow = 100, gun = 20, energy = 15, bomb = 65, bio = 20, rad = FALSE)
	value = 65
	slowdown = 1.2
	health = 90

/obj/item/clothing/suit/armor/medieval/blue
	name = "blue plated armor"
	desc = "A thick, expensive iron armor, covering most of the body."
	icon_state = "knight_blue"
	item_state = "knight_blue"
	worn_state = "knight_blue"

/obj/item/clothing/suit/armor/medieval/red
	name = "red plated armor"
	desc = "A thick, expensive iron armor, covering most of the body."
	icon_state = "knight_red"
	item_state = "knight_red"
	worn_state = "knight_red"

/obj/item/clothing/suit/armor/medieval/yellow
	name = "yellow plated armor"
	desc = "A thick, expensive iron armor, covering most of the body."
	icon_state = "knight_yellow"
	item_state = "knight_yellow"
	worn_state = "knight_yellow"

/obj/item/clothing/suit/armor/medieval/green
	name = "green plated armor"
	desc = "A thick, expensive iron armor, covering most of the body."
	icon_state = "knight_green"
	item_state = "knight_green"
	worn_state = "knight_green"

/obj/item/clothing/suit/armor/medieval/templar
	name = "templar plated armor"
	desc = "A thick, expensive iron armor, covering most of the body. This one is covered by white linen with the cross."
	icon_state = "knight_templar"
	item_state = "knight_templar"
	worn_state = "knight_templar"

/obj/item/clothing/suit/armor/medieval/bronze_chestplate
	name = "bronze chestplate"
	desc = "A bronze chestplate."
	icon_state = "bronze_chestplate"
	item_state = "bronze_chestplate"
	worn_state = "bronze_chestplate"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	value = 25
	slowdown = 0.7
	health = 48

/obj/item/clothing/suit/armor/medieval/iron_chestplate
	name = "iron chestplate"
	desc = "An iron chestplate."
	icon_state = "iron_chestplate"
	item_state = "iron_chestplate"
	worn_state = "iron_chestplate"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 40, gun = 8, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	value = 32
	slowdown = 0.8
	health = 52

/obj/item/clothing/suit/armor/medieval/iron_chestplate/red
	icon_state = "iron_chestplater"
	item_state = "iron_chestplater"
	worn_state = "iron_chestplater"

/obj/item/clothing/suit/armor/medieval/iron_chestplate/crusader
	icon_state = "iron_chestplatec"
	item_state = "iron_chestplatec"
	worn_state = "iron_chestplatec"

/obj/item/clothing/suit/armor/medieval/iron_chestplate/blue
	icon_state = "iron_chestplateb"
	item_state = "iron_chestplateb"
	worn_state = "iron_chestplateb"

/obj/item/clothing/suit/armor/medieval/leather
	name = "leather armor"
	desc = "Several pressed sheets of leather, making a reasonable armor plate."
	icon_state = "leather_armor"
	item_state = "leather_armor"
	worn_state = "leather_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 30, arrow = 15, gun = FALSE, energy = 15, bomb = 20, bio = 20, rad = FALSE)
	value = 20
	flammable = TRUE
	slowdown = 0.2
	health = 33

/obj/item/clothing/suit/armor/medieval/hauberk
	name = "hauberk"
	desc = "A longer version of the chainmail, worn as a coat. Offers greater protection."
	icon_state = "hauberk"
	item_state = "hauberk"
	worn_state = "hauberk"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 60, arrow = 55, gun = 10, energy = 20, bomb = 40, bio = 30, rad = FALSE)
	value = 40
	slowdown = 0.75
	health = 60

/obj/item/clothing/suit/armor/medieval/emirate
	name = "emirate armor"
	desc = "A loosely fitting but protective suit of armor to wrap around the body & tunic for a emirate lord"
	icon_state = "emir_armor"
	item_state = "emir_armor"
	worn_state = "emir_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 55, arrow = 50, gun = 10, energy = 20, bomb = 40, bio = 30, rad = FALSE)
	value = 35
	slowdown = 0.60
	health = 50

/obj/item/clothing/suit/armor/medieval/chainmail
	name = "chainmail"
	desc = "Wearable armor made of several small interlinked chains."
	icon_state = "chainmail"
	item_state = "chainmail"
	worn_state = "chainmail"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 30, bio = 20, rad = FALSE)
	value = 30
	slowdown = 0.6
	health = 50

/*Medieval Armor Accessories*/

/obj/item/clothing/accessory/armor
	icon = 'icons/obj/clothing/suits.dmi'
	slot = "armor"
	flags = CONDUCT
/obj/item/clothing/accessory/armor/get_mob_overlay()
	if (!mob_overlay)
		var/tmp_icon_state = "[overlay_state? "[overlay_state]" : "[icon_state]"]"
		if (icon_override)
			if ("[tmp_icon_state]_mob" in icon_states(icon_override))
				tmp_icon_state = "[tmp_icon_state]_mob"
			mob_overlay = image("icon" = icon_override, "icon_state" = "[tmp_icon_state]")
		else
			mob_overlay = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "[tmp_icon_state]")
	return mob_overlay

/obj/item/clothing/accessory/armor/chainmail
	name = "chainmail"
	desc = "Wearable armor made of several small interlinked chains."
	icon_state = "chainmail"
	item_state = "chainmail"
	worn_state = "chainmail"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 30, bio = 20, rad = FALSE)
	value = 30
	slowdown = 0.6
	health = 50

/* Medieval Crowns*/

/obj/item/clothing/head/helmet/gold_crown
	name = "gold crown"
	desc = "A crown of gold. Fancy."
	icon_state = "gold_crown"
	item_state = "gold_crown"
	worn_state = "gold_crown"
	armor = list(melee = 20, arrow = 15, gun = 10, energy = 15, bomb = 15, bio = 10, rad = FALSE)

/obj/item/clothing/head/helmet/silver_crown
	name = "silver crown"
	desc = "A crown of silver. Fancy."
	icon_state = "silver_crown"
	item_state = "silver_crown"
	worn_state = "silver_crown"
	armor = list(melee = 20, arrow = 15, gun = 10, energy = 15, bomb = 15, bio = 10, rad = FALSE)

//Insert more inlaid crowns here.

/obj/item/clothing/head/helmet/gold_crown_diamond
	name = "inlaid gold crown"
	desc = "A crown of gold, with a diamond in it. Extra Fancy."
	icon_state = "gold_crown_diamond"
	item_state = "gold_crown_diamond"
	worn_state = "gold_crown_diamond"
	armor = list(melee = 25, arrow = 20, gun = 10, energy = 25, bomb = 20, bio = 15, rad = FALSE)

/obj/item/clothing/head/helmet/silver_crown_diamond
	name = "inlaid silver crown"
	desc = "A crown of silver, with a diamond in it. Extra Fancy."
	icon_state = "silver_crown_diamond"
	item_state = "silver_crown_diamond"
	worn_state = "silver_crown_diamond"
	armor = list(melee = 25, arrow = 20, gun = 10, energy = 25, bomb = 20, bio = 15, rad = FALSE)

/obj/item/clothing/head/helmet/silver_crown/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/diamond))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the diamond in the crown.</span>"
		if(W.amount <= 1)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/silver_crown_diamond(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 1
			new/obj/item/clothing/head/helmet/silver_crown_diamond(user.loc)

/obj/item/clothing/head/helmet/gold_crown/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/diamond))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the diamond in the crown.</span>"
		if(W.amount <= 1)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/gold_crown_diamond(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 1
			new/obj/item/clothing/head/helmet/gold_crown_diamond(user.loc)
//continue

/* Medieval Helmets*/

/obj/item/clothing/head/helmet/brown_eisenbruck
	name = "brown padded head-cap"
	desc = "a padded brown coif, applies practical if modest protection."
	icon_state = "brown_eisenbruck"
	item_state = "brown_eisenbruck"
	worn_state = "brown_eisenbruck"
	body_parts_covered = HEAD
	armor = list(melee = 24, arrow = 15, gun = FALSE, energy = 15, bomb = 25, bio = 20, rad = FALSE)
	health = 20

/obj/item/clothing/head/helmet/grey_eisenbruck
	name = "grey padded head-cap"
	desc = "a padded grey coif, applies practical if modest protection."
	icon_state = "grey_eisenbruck"
	item_state = "grey_eisenbruck"
	worn_state = "grey_eisenbruck"
	body_parts_covered = HEAD
	armor = list(melee = 24, arrow = 15, gun = FALSE, energy = 15, bomb = 25, bio = 20, rad = FALSE)
	health = 20

/obj/item/clothing/head/helmet/aged_eisenbruck
	name = "ratty old padded head-cap"
	desc = "a ratty, old padded coif, its color faded but remains protective."
	icon_state = "aged_eisenbruck"
	item_state = "aged_eisenbruck"
	worn_state = "aged_eisenbruck"
	body_parts_covered = HEAD
	armor = list(melee = 24, arrow = 15, gun = FALSE, energy = 15, bomb = 25, bio = 20, rad = FALSE)
	health = 20

/*Sallets*/

/obj/item/clothing/head/helmet/sallet/italian
	name = "italian sallet"
	desc = "A very protective helmet used by archers and crossbowmen in the 15th century throughout europe."
	icon_state = "italian_sallet_o"
	item_state = "italian_sallet_o"
	worn_state = "italian_sallet_o"
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 45
	slowdown = 0.15
	var/toggled = FALSE

/obj/item/clothing/head/helmet/sallet/italian/verb/toggle_visor()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/sallet/italian)
		return
	else
		if (toggled)
			item_state = "italian_sallet_o"
			icon_state = "italian_sallet_o"
			worn_state = "italian_sallet_o"
			item_state_slots["slot_head"] = "italian_sallet_o"
			usr << "<span class = 'danger'>You put up your helmet's visor.</span>"
			toggled = FALSE
			update_clothing_icon()
			body_parts_covered = HEAD
			flags_inv = BLOCKHEADHAIR
		else if (!toggled)
			item_state = "italian_sallet"
			icon_state = "italian_sallet"
			worn_state = "italian_sallet"
			item_state_slots["slot_head"] = "italian_sallet"
			usr << "<span class = 'danger'>You put down your helmet's visor.</span>"
			toggled = TRUE
			update_clothing_icon()
			body_parts_covered = HEAD|FACE
			flags_inv = BLOCKHAIR

/obj/item/clothing/head/helmet/sallet/german
	name = "german sallet"
	desc = "A very protective helmet used by archers and crossbowmen in the 15th century throughout europe."
	icon_state = "german_sallet_o"
	item_state = "german_sallet_o"
	worn_state = "german_sallet_o"
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 45
	slowdown = 0.15
	var/toggled = FALSE

/obj/item/clothing/head/helmet/sallet/german/verb/toggle_visor()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/sallet/german)
		return
	else
		if (toggled)
			item_state = "german_sallet_o"
			icon_state = "german_sallet_o"
			worn_state = "german_sallet_o"
			item_state_slots["slot_head"] = "german_sallet_o"
			usr << "<span class = 'danger'>You put up your helmet's visor.</span>"
			toggled = FALSE
			update_clothing_icon()
			body_parts_covered = HEAD
			flags_inv = BLOCKHEADHAIR
		else if (!toggled)
			item_state = "german_sallet"
			icon_state = "german_sallet"
			worn_state = "german_sallet"
			item_state_slots["slot_head"] = "german_sallet"
			usr << "<span class = 'danger'>You put down your helmet's visor.</span>"
			toggled = TRUE
			update_clothing_icon()
			body_parts_covered = HEAD|FACE
			flags_inv = BLOCKHAIR

/obj/item/clothing/head/helmet/sallet/burg
	name = "burgundian sallet"
	desc = "A very protective helmet used by archers and crossbowmen in the 15th century throughout europe, providing moderate protection."
	icon_state = "burg_sallet_o"
	item_state = "burg_sallet_o"
	worn_state = "burg_sallet_o"
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 45
	slowdown = 0.15
	var/toggled = FALSE

/obj/item/clothing/head/helmet/sallet/burg/verb/toggle_visor()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/sallet/burg)
		return
	else
		if (toggled)
			item_state = "burg_sallet_o"
			icon_state = "burg_sallet_o"
			worn_state = "burg_sallet_o"
			item_state_slots["slot_head"] = "burg_sallet_o"
			usr << "<span class = 'danger'>You put up your helmet's visor.</span>"
			toggled = FALSE
			update_clothing_icon()
			body_parts_covered = HEAD
			flags_inv = BLOCKHEADHAIR
		else if (!toggled)
			item_state = "burg_sallet"
			icon_state = "burg_sallet"
			worn_state = "burg_sallet"
			item_state_slots["slot_head"] = "burg_sallet"
			usr << "<span class = 'danger'>You put down your helmet's visor.</span>"
			toggled = TRUE
			update_clothing_icon()
			body_parts_covered = HEAD|FACE
			flags_inv = BLOCKHAIR

/* Sallets End*/

/obj/item/clothing/head/helmet/bascinet
	name = "hounskull bascinet"
	desc = "A bascinet helmet with a large outward faceguard; used by knights & heavy infantry in the 14th century."
	icon_state = "bascinet_o"
	item_state = "bascinet_o"
	worn_state = "bascinet_o"
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 45
	slowdown = 0.15
	var/toggled = FALSE

/obj/item/clothing/head/helmet/bascinet/verb/toggle_visor()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/bascinet)
		return
	else
		if (toggled)
			item_state = "bascinet_o"
			icon_state = "bascinet_o"
			worn_state = "bascinet_o"
			item_state_slots["slot_head"] = "bascinet_o"
			usr << "<span class = 'danger'>You put up your helmet's visor.</span>"
			toggled = FALSE
			update_clothing_icon()
			body_parts_covered = HEAD
			flags_inv = BLOCKHEADHAIR
		else if (!toggled)
			item_state = "bascinet_hounskull"
			icon_state = "bascinet_hounskull"
			worn_state = "bascinet_hounskull"
			item_state_slots["slot_head"] = "bascinet_hounskull"
			usr << "<span class = 'danger'>You put down your helmet's visor.</span>"
			toggled = TRUE
			update_clothing_icon()
			body_parts_covered = HEAD|FACE
			flags_inv = BLOCKHAIR

/obj/item/clothing/head/helmet/medieval
	name = "knight helmet"
	desc = "A thick knight helmet."
	icon_state = "knight_simple"
	item_state = "knight_simple"
	worn_state = "knight_simple"
	body_parts_covered = HEAD|FACE|EYES
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	flags_inv = BLOCKHAIR
	restricts_view = 2
	health = 55
	slowdown = 0.25

/obj/item/clothing/head/helmet/medieval/helmet1
	name = "protective conical helmet"
	desc = "A conical helmet, with nose and ear protection."
	icon_state = "medieval_helmet1"
	item_state = "medieval_helmet1"
	worn_state = "medieval_helmet1"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 35

/obj/item/clothing/head/helmet/medieval/helmet2
	name = "kettle helmet"
	desc = "A wide brim iron helmet."
	icon_state = "medieval_helmet2"
	item_state = "medieval_helmet2"
	worn_state = "medieval_helmet2"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 35, gun = 5, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 28

/obj/item/clothing/head/helmet/medieval/helmet3
	name = "conical helmet"
	desc = "A conical helmet, with nose protection."
	icon_state = "medieval_helmet3"
	item_state = "medieval_helmet3"
	worn_state = "medieval_helmet3"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 5, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 32

/obj/item/clothing/head/helmet/medieval/coif
	name = "iron coif"
	desc = "A chainmail headcover."
	icon_state = "coif"
	item_state = "coif"
	worn_state = "coif"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 40, gun = 7, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 37

/obj/item/clothing/head/helmet/medieval/coif_helmet
	name = "iron coif and helmet"
	desc = "A chainmail headcover, with a conical helmet on top."
	icon_state = "coif_helmet"
	item_state = "coif_helmet"
	worn_state = "coif_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 10, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 45

/obj/item/clothing/head/helmet/leather_skullcap
	name = "leather skullcap helmet"
	desc = "A iron studded leather helmet. Often used by raiders or bands of mercenaries."
	icon_state = "leather_skullcap_helmet"
	item_state = "leather_skullcap_helmet"
	worn_state = "leather_skullcap_helmet"
	body_parts_covered = HEAD
	armor = list(melee = 30, arrow = 20, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE) //lightly stronger than leather
	health = 30

/obj/item/clothing/head/helmet/medieval/arab
	name = "conical arabic helmet and turban"
	desc = "An iron helmet, covered with a turban."
	icon_state = "turhelm1"
	item_state = "turhelm1"
	worn_state = "turhelm1"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 32

/obj/item/clothing/head/helmet/medieval/arab2
	name = "long arabic helmet and turban"
	desc = "An iron helmet, covered with a turban, with side protections for the face."
	icon_state = "arabw_helmet1"
	item_state = "arabw_helmet1"
	worn_state = "arabw_helmet1"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 32

/obj/item/clothing/head/helmet/medieval/arab3
	name = "long arabic helmet"
	desc = "An iron helmet, covered with a turban, with side protections for the face."
	icon_state = "arabw_helmet"
	item_state = "arabw_helmet"
	worn_state = "arabw_helmet"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 32

/obj/item/clothing/head/helmet/medieval/arab/New()
	..()
	var/pickcolor = pick("turhelm1", "turhelm2", "turhelm3", "turhelm4")
	icon_state = pickcolor
	item_state = pickcolor
	worn_state = pickcolor

/* Nomads Arabic Helmets*/

/obj/item/clothing/head/helmet/medieval/nomads/arab
	name = "purple arabic turban helmet"
	desc = "An iron helmet, covered with a purple turban."
	icon_state = "turhelm1"
	item_state = "turhelm1"
	worn_state = "turhelm1"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 40, gun = 5, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 25

/obj/item/clothing/head/helmet/medieval/nomads/arab2
	name = "red arabic turban helmet"
	desc = "An iron helmet, covered with a red turban."
	icon_state = "turhelm2"
	item_state = "turhelm2"
	worn_state = "turhelm2"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 40, gun = 5, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 25

/obj/item/clothing/head/helmet/medieval/nomads/arab3
	name = "green arabic turban helmet"
	desc = "An iron helmet, covered with a green turban."
	icon_state = "turhelm3"
	item_state = "turhelm3"
	worn_state = "turhelm3"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 40, gun = 5, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 25

/obj/item/clothing/head/helmet/medieval/nomads/arab4
	name = "blue arabic turban helmet"
	desc = "An iron helmet, covered with a blue turban."
	icon_state = "turhelm3"
	item_state = "turhelm3"
	worn_state = "turhelm3"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 40, gun = 5, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 25

/obj/item/clothing/head/helmet/medieval/nomads/longarab
	name = "long arabic helmet"
	desc = "An long conical iron helmet, in arabic style, with side protections for the face. Often worn by arabic soldiers"
	icon_state = "arabw_helmet"
	item_state = "arabw_helmet"
	worn_state = "arabw_helmet"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 32

/obj/item/clothing/head/helmet/medieval/nomads/longarab/female
	name = "feminine long arabic helmet"
	desc = "An long conical iron helmet, in arabic style, with side protections for the face. Often worn by arabic princesses"
	icon_state = "arabw_helmet1"
	item_state = "arabw_helmet1"
	worn_state = "arabw_helmet1"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 32

/* Nomads Arabic Helmet -End*/

/obj/item/clothing/head/helmet/medieval/emirate
	name = "emirate helmet"
	desc = "An iron helmet, covered with a green turban & cloth wrapped around. Often worn by rulers of emirate kingdoms"
	icon_state = "emir_turban"
	item_state = "emir_turban"
	worn_state = "emir_turban"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 45

	/* Crusader Helmets*/
//the classic goofy helmet, leaving path in place to not disturb mapping, very chicken & egg issue.

/obj/item/clothing/head/helmet/medieval/templar
	name = "templar knight helmet"
	desc = "A thick knight helmet, with a yellow cross painted on the front."
	icon_state = "knight_templar"
	item_state = "knight_templar"
	worn_state = "knight_templar"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)

//where the nomads helmets begins

/obj/item/clothing/head/helmet/medieval/crusader
	name = "crusader helmet"
	desc = "A thick knight helmet, with narrow slit eye holes."
	icon_state = "crusader"
	item_state = "crusader"
	worn_state = "crusader"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 55
	slowdown = 0.25

/obj/item/clothing/head/helmet/medieval/crusader/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/gold ))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You embellish the gold ingots upon the crusader helm</span>"
		if(W.amount <= 5)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/medieval/nomads/templar(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 5
			new/obj/item/clothing/head/helmet/medieval/nomads/templar(user.loc)

//the craftable iteration.

/obj/item/clothing/head/helmet/medieval/nomads/templar
	desc = "A thick knight helmet, embellished with a gold cross on the front. It has narrow slit eye holes."
	icon_state = "new_knight_templar"
	item_state = "new_knight_templar"
	worn_state = "new_knight_templar"
	restricts_view = 2
	health = 55
	slowdown = 0.25

/obj/item/clothing/head/helmet/medieval/nomads/templar/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/gold ))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You embellish a gold crown upon the templar crusader helm</span>"
		if(W.amount <= 10)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/medieval/crusaderking(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 10
			new/obj/item/clothing/head/helmet/medieval/crusaderking(user.loc)
			return

/obj/item/clothing/head/helmet/medieval/crusaderking
	name = "crusader king helmet"
	desc = "A thick knight helmet, embellished with a gold cross on the front and crown on top. It has narrow slit eye holes."
	icon_state = "crusader_king"
	item_state = "crusader_king"
	worn_state = "crusader_king"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 55
	slowdown = 0.25

	/* Baltic Crusaders*/

/obj/item/clothing/head/helmet/medieval/crusader/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/bone ))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You affix the bone horns upon the crusader helm.</span>"
		if(W.amount <= 3)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/medieval/baltic(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 3
			new/obj/item/clothing/head/helmet/medieval/baltic(user.loc)

/obj/item/clothing/head/helmet/medieval/baltic
	name = "baltic crusader helmet"
	desc = "A thick knight helmet with menacing horns affixed to the side. It has narrow slit eye holes."
	icon_state = "baltic_crusader"
	item_state = "baltic_crusader"
	worn_state = "baltic_crusader"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 55
	slowdown = 0.25

/obj/item/clothing/head/helmet/medieval/baltic/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/silver ))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You begin to decorate the baltic crusader helm in grandmaster patterns.</span>"
		if(W.amount <= 5)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/medieval/grandmaster(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 5
			new/obj/item/clothing/head/helmet/medieval/grandmaster(user.loc)

/obj/item/clothing/head/helmet/medieval/grandmaster
	name = "baltic grandmaster helmet"
	desc = "A thick knight helmet with menacing horns affixed to the side and a grandmaster's pattern decoration. It has narrow slit eye holes."
	icon_state = "baltic_crusader_grandmaster"
	item_state = "baltic_crusader_grandmaster"
	worn_state = "baltic_crusader_grandmaster"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 55
	slowdown = 0.25

/obj/item/clothing/head/helmet/medieval/grandmaster/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/silver))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You embellish a silver crown upon the grandmaster helm!</span>"
		if(W.amount <= 10)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/medieval/baltic_crusaderking(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 10
			new/obj/item/clothing/head/helmet/medieval/baltic_crusaderking(user.loc)

/obj/item/clothing/head/helmet/medieval/baltic_crusaderking
	name = "baltic crusader king helmet"
	desc = "A thick knight helmet with menacing horns affixed to the side, a grandmaster's pattern decoration & a silver crown. It has narrow slit eye holes."
	icon_state = "baltic_crusader_king"
	item_state = "baltic_crusader_king"
	worn_state = "baltic_crusader_king"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 55
	slowdown = 0.25

	/* Crusader Priests*/

/obj/item/clothing/head/helmet/medieval/nomads/templar/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/cloth)) //unsure if this will take wool at the moment, just ret some cloth.
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You begin to anoint & sow the cloth dome to your helmet.</span>"
		if(W.amount <= 3)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/medieval/priest(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 3
			new/obj/item/clothing/head/helmet/medieval/priest(user.loc)

/obj/item/clothing/head/helmet/medieval/priest
	name = "templar priest helmet"
	desc = "A thick knight helmet with a covered cloth dome in templar colors, it has narrow slit eye holes."
	icon_state = "templar_priest"
	item_state = "templar_priest"
	worn_state = "templar_priest"
	flags_inv = BLOCKHAIR
	armor = list(melee = 60, arrow = 70, gun = 5, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 35
	slowdown = 0.20

/obj/item/clothing/head/helmet/medieval/baltic/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/cloth)) //unsure if this will take wool at the moment, just ret some cloth.
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You begin to anoint & sow the cloth dome to your helmet.</span>"
		if(W.amount <= 3)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/medieval/baltic_priest(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 3
			new/obj/item/clothing/head/helmet/medieval/baltic_priest(user.loc)

/obj/item/clothing/head/helmet/medieval/baltic_priest
	name = "baltic priest helmet"
	desc = "A thick knight helmet with a covered cloth dome in baltic colors, it has narrow slit eye holes."
	icon_state = "baltic_priest"
	item_state = "baltic_priest"
	worn_state = "baltic_priest"
	flags_inv = BLOCKHAIR
	armor = list(melee = 60, arrow = 70, gun = 5, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 35
	slowdown = 0.20

/* Medieval Equipment Crates*/

/obj/structure/closet/crate/equipment
	name = "wood crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"

/obj/structure/closet/crate/equipment/knight_armor
	name = "knight's equipment crate"
	paths = list(/obj/item/clothing/head/helmet/medieval = 1,
				/obj/item/clothing/suit/armor/medieval = 1,
				/obj/item/clothing/under/medieval/red2 = 1,
				/obj/item/clothing/shoes/medieval/knight = 1,
				/obj/item/weapon/material/sword/longsword/iron = 1,
				/obj/item/weapon/shield/iron/semioval = 1,)

/obj/structure/closet/crate/equipment/mamluk_armor
	name = "mamluk's equipment crate"
	paths = list(/obj/item/clothing/head/helmet/medieval = 1,
				/obj/item/clothing/suit/armor/medieval/hauberk = 1,
				/obj/item/clothing/under/medieval/arabic_tunic = 1,
				/obj/item/clothing/shoes/medieval/knight = 1,
				/obj/item/weapon/material/sword/saif = 1,
				/obj/item/weapon/material/spear/sarissa/pike = 1,
				/obj/item/weapon/shield/arab_buckler = 1,)

/obj/structure/closet/crate/equipment/sayaf
	name = "sayaf's equipment crate"
	paths = list(/obj/item/clothing/head/helmet/medieval/arab = 1,
				/obj/item/clothing/suit/armor/medieval/chainmail = 1,
				/obj/item/clothing/under/medieval/arab2 = 1,
				/obj/item/clothing/shoes/medieval/arab = 1,
				/obj/item/weapon/material/sword/scimitar = 1,
				/obj/item/weapon/shield/arab_buckler = 1,)

/* Extra-Cultural Medieval Clothes*/

	/* Medieval Mayan*/

/obj/item/clothing/head/mayan_headdress
	name = "mayan headdress"
	desc = "a mayan style headdress."
	icon_state = "mayan_headdress"
	item_state = "mayan_headdress"
	worn_state = "mayan_headdress"

/obj/item/clothing/under/huipil
	name = "huipil"
	desc = "a light cloth, with blue trimmings."
	icon_state = "huipil"
	item_state = "huipil"
	worn_state = "huipil"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS

/obj/item/clothing/under/halfhuipil
	name = "half huipil"
	desc = "a light cloth, covering the lower part of the body. With red trimmings."
	icon_state = "halfhuipil"
	item_state = "halfhuipil"
	worn_state = "halfhuipil"

/* Medieval Norse Armor*/

/obj/item/clothing/head/helmet/medieval/viking
	name = "viking helmet"
	desc = "A rounded viking helmet, with nose and ear protection"
	icon_state = "new_viking" //to keep seperate from the wagner-esque viking helmet
	item_state = "new_viking"
	worn_state = "new_viking"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/medieval/viking/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/gold))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You decorate the soon to be royal helmet carefully with gold.</span>"
		if(W.amount <= 5)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/medieval/viking/king(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 5
			new/obj/item/clothing/head/helmet/medieval/viking/king(user.loc)

/obj/item/clothing/head/helmet/medieval/viking/king
	name = "royal viking helmet"
	desc = "A royally decorated gold rounded viking helmet, with nose and ear protection"
	icon_state = "viking_king"
	item_state = "viking_king"
	worn_state = "viking_king"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/medieval/viking/valkyrie
	name = "royal viking helmet"
	desc = "A rounded valkyrie helmet, it is protective and adorned with wings"
	icon_state = "valkyrie"
	item_state = "valkyrie"
	worn_state = "valkyrie"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/medieval/viking/valkyrie/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/gold))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You decorate the soon to be royal helmet carefully with gold.</span>"
		if(W.amount <= 5)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/medieval/viking/valkyrie_queen(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 5
			new/obj/item/clothing/head/helmet/medieval/viking/valkyrie_queen(user.loc)

/obj/item/clothing/head/helmet/medieval/viking/valkyrie_queen
	name = "royal viking helmet"
	desc = "A royally decorated gold rounded valkyrie helmet, it is protective and adorned with wings"
	icon_state = "valkyrie_queen"
	item_state = "valkyrie_queen"
	worn_state = "valkyrie_queen"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/medieval/viking/varangian
	name = "varangian helmet"
	desc = "A robust varangian guard style helmet, with tightly wrapped chainmail over everything but the eye holes."
	icon_state = "varangian_guard"
	item_state = "varangian_guard"
	worn_state = "varangian_guard"
	flags_inv = BLOCKHAIR
	body_parts_covered = HEAD|FACE|EYES
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 55
	slowdown = 0.25

/obj/item/clothing/suit/armor/medieval/varangian
	name = "varangian lamellar armor"
	desc = "A close fitting armor of small iron rectangular shapes to make a scale vest. Manageably heavy but flexible."
	icon_state = "varangian_lamellar"
	item_state = "varangian_lamellar"
	worn_state = "varangian_lamellar"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 60, arrow = 55, gun = 10, energy = 20, bomb = 40, bio = 30, rad = FALSE)
	slowdown = 0.75
	health = 60

/* Medieval Chinese Armor*/

/obj/item/clothing/head/helmet/medieval/imperial_chinese
	name = "imperial chinese helmet"
	desc = "A iron helmet with a quilted neck covering and a decorative red plume, made in a imperial chinese style. "
	icon_state = "imperial_chinese"
	item_state = "imperial_chinese"
	worn_state = "imperial_chinese"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 45
	slowdown = 0.25

/obj/item/clothing/suit/armor/medieval/imperial_chinese
	name = "imperial chinese armor"
	desc = "A well built & laquered armor with iron plates concealed inwardly and outwardly protecting the body, made in imperial chinese style"
	icon_state = "imperial_chinese"
	item_state = "imperial_chinese"
	worn_state = "imperial_chinese"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 55, arrow = 50, gun = 10, energy = 20, bomb = 40, bio = 30, rad = FALSE)
	value = 35
	slowdown = 0.50
	health = 50


/* Medieval Mamluk Armor*/

/obj/item/clothing/head/helmet/medieval/mamluk/helmet
	name = "mamluk conical helmet"
	desc = "A conical helmet, with nose and ear protection in mamluk style."
	icon_state = "mamluk_helmet"
	item_state = "mamluk_helmet"
	worn_state = "mamluk_helmet"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 35

/obj/item/clothing/head/helmet/medieval/mamluk/helmet/lord //not as brute strength protective, but its users are unrestricted fast & nasty.
	name = "lordly mamluk conical helmet"
	desc = "A conical helmet, with nose and ear protection in mamluk style. It is wrapped in chainmail."
	icon_state = "mamluk_lord"
	item_state = "mamluk_lord"
	worn_state = "mamluk_lord"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 60, arrow = 50, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 50
	slowdown = 0.15

/obj/item/clothing/head/helmet/medieval/mamluk/helmet/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/gold))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You decorate the lordly helmet carefully with gold.</span>"
		if(W.amount <= 5)
			qdel(src)
			qdel(W)
			new/obj/item/clothing/head/helmet/medieval/mamluk/helmet/king(user.loc)
		else
			qdel(src)
			W.amount = W.amount - 1
			new/obj/item/clothing/head/helmet/medieval/mamluk/helmet/king(user.loc)

/obj/item/clothing/head/helmet/medieval/mamluk/helmet/king
	name = "royal mamluk conical helmet"
	desc = "A royally decorated gold plated conical helmet, with nose and ear protection in mamluk style. It is wrapped in chainmail."
	icon_state = "mamluk_king"
	item_state = "mamluk_king"
	worn_state = "mamluk_king"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 60, arrow = 50, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 50
	slowdown = 0.15

/obj/item/clothing/head/helmet/medieval/mamluk/coif
	name = "coif wrapped mamluk helmet"
	desc = "A chainmail headcover and pointed helmet, in mamluk style"
	icon_state = "mamluk_coif_helmet"
	item_state = "mamluk_coif_helmet"
	worn_state = "mamluk_coif_helmet"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 10, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 45

/* Medieval Steppe Clothes & Armor*/

/obj/item/clothing/head/steppe_shaman
	name = "steppe shaman wool hat"
	desc = "a dyed red wool hat of steppe nomad design. Often worn by shamans to protect themselves from the elements on the steppe whilst performing rituals"
	icon_state = "steppe_shaman_wool_hat"
	item_state = "steppe_shaman_wool_hat"
	worn_state = "steppe_shaman_wool_hat"

/obj/item/clothing/suit/storage/jacket/steppe_shaman
	name = "steppe shaman wool coat"
	desc = "A colorful woolen coat, used by shamans to wrap warm whilst performing rituals on the open steppe."
	icon_state = "steppe_shaman_wool_coat"
	item_state = "steppe_shaman_wool_coat"
	worn_state = "steppe_shaman_wool_coat"
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/suit/armor/medieval/steppe_leather
	name = "steppe leather armor"
	desc = "Leather armor made from sheets of leather bound in a steppe nomad style, making adequate protection for prospective warriors."
	icon_state = "steppe_leather_armor"
	item_state = "steppe_leather_armor"
	worn_state = "steppe_leather_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 45, arrow = 25, gun = 5, energy = 15, bomb = 40, bio = 20, rad = FALSE) //stronger than leather, weaker than bronze
	value = 20
	flammable = TRUE
	slowdown = 0.2
	health = 33

/obj/item/clothing/under/medieval/steppe_tunic
	name = "steppe wool tunic"
	desc = "A brown tunic made out of wool. Often worn by nomads upon the great steppes."
	icon_state = "steppe_wool_tunic"
	item_state = "steppe_wool_tunic"
	worn_state = "steppe_wool_tunic"
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/shoes/steppe_shoes
	name = "steppe wool shoe"
	desc = "A pair of insulated rough woolen shoes for keeping feet warm on the open steppe."
	icon_state = "steppe_wool_shoes"
	item_state = "steppe_wool_shoes"
	worn_state = "steppe_wool_shoes"
	body_parts_covered = FEET
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 10, arrow = 8, gun = FALSE, energy = 6, bomb = 12, bio = 10, rad = FALSE)
	cold_protection = FEET
	health = 35
	item_flags = NOSLIP
	siemens_coefficient = 0.6

/* Medieval Japanese*/
	/* Medieval Japanese*/

/obj/item/clothing/suit/armor/samurai
	name = "leather samurai armor"
	desc = "A protective & lightweight armor, bound to and covering most of the body yet slightly flexible. Often worn by a lord's bodyguards."
	icon_state = "samurai3"
	item_state = "samurai3"
	worn_state = "samurai3"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	value = 15
	slowdown = 0.45
	health = 35

/obj/item/clothing/suit/armor/samurai/red
	name = "red leather samurai armor"
	icon_state = "samurai1"
	item_state = "samurai1"
	worn_state = "samurai1"

/obj/item/clothing/suit/armor/samurai/blue
	name = "blue leather samurai armor"
	icon_state = "samurai2"
	item_state = "samurai2"
	worn_state = "samurai2"

/obj/item/clothing/suit/armor/samurai/black
	name = "black leather samurai armor"
	icon_state = "samurai4"
	item_state = "samurai4"
	worn_state = "samurai4"

/obj/item/clothing/suit/armor/samurai/warrior
	name = "samurai armor"
	desc = "A dense, metal armor of japanese origin, covering most of the body. Often worn by a loyal warriors to a feudal lord."
	icon_state = "samurai_warrior3"
	item_state = "samurai_warrior3"
	worn_state = "samurai_warrior3"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 65, arrow = 75, gun = 5, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	value = 45
	slowdown = 0.9

/obj/item/clothing/suit/armor/samurai/warrior/red
	name = "red samurai armor"
	icon_state = "samurai_warrior1"
	item_state = "samurai_warrior1"
	worn_state = "samurai_warrior1"

/obj/item/clothing/suit/armor/samurai/warrior/blue
	name = "blue kozane armor"
	icon_state = "samurai_warrior2"
	item_state = "samurai_warrior2"
	worn_state = "samurai_warrior2"

/obj/item/clothing/suit/armor/samurai/warrior/black
	name = "black kozane armor"
	icon_state = "samurai_warrior4"
	item_state = "samurai_warrior4"
	worn_state = "samurai_warrior4"

/obj/item/clothing/suit/armor/samurai/lord
	name = "samurai lord armor"
	desc = "A thick, expensive armor of japanese origin. Often worn by feudal lords."
	icon_state = "samurai_lord3"
	item_state = "samurai_lord3"
	worn_state = "samurai_lord3"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 85, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/suit/armor/samurai/lord/red
	name = "red samurai lord armor"
	icon_state = "samurai_lord1"
	item_state = "samurai_lord1"
	worn_state = "samurai_lord1"

/obj/item/clothing/suit/armor/samurai/lord/blue
	name = "blue samurai lord armor"
	icon_state = "samurai_lord2"
	item_state = "samurai_lord2"
	worn_state = "samurai_lord2"

/obj/item/clothing/suit/armor/samurai/lord/black
	name = "black samurai lord armor"
	icon_state = "samurai_lord4"
	item_state = "samurai_lord4"
	worn_state = "samurai_lord4"

	/* Medieval Japanese Uniforms*/

/obj/item/clothing/under/hanfu
	name = "dark hanfu"
	desc = "A light, loose fitting hanfu."
	icon_state = "dark_hanfu"
	item_state = "dark_hanfu"
	worn_state = "dark_hanfu"

/obj/item/clothing/under/hanfu/light
	name = "light hanfu"
	desc = "A light, loose fitting hanfu."
	icon_state = "light_hanfu"
	item_state = "light_hanfu"
	worn_state = "light_hanfu"

/obj/item/clothing/under/hanfu/green
	name = "green hanfu"
	desc = "A green, loose fitting hanfu."
	icon_state = "green_hanfu"
	item_state = "green_hanfu"
	worn_state = "green_hanfu"

/obj/item/clothing/under/artisan
	name = "artisan clothing"
	desc = "A light, loose fitting bit of clothes."
	icon_state = "artisan1"
	item_state = "artisan1"
	worn_state = "artisan1"

/obj/item/clothing/under/artisan/dark
	name = "dark artisan clothing"
	desc = "A light, loose fitting bit of clothes."
	icon_state = "artisan2"
	item_state = "artisan2"
	worn_state = "artisan2"

/obj/item/clothing/under/artisan/light
	name = "light artisan clothing"
	desc = "A light, loose fitting bit of clothes."
	icon_state = "artisan3"
	item_state = "artisan3"
	worn_state = "artisan3"

/obj/item/clothing/under/haori
	name = "haori"
	desc = "A light, loose fitting bit of clothes, worn in japan."
	icon_state = "haori"
	item_state = "haori"
	worn_state = "haori"

/obj/item/clothing/under/haori/blue
	name = "haori"
	desc = "A light, loose fitting bit of clothes, worn in japan."
	icon_state = "haori3"
	item_state = "haori3"
	worn_state = "haori3"

/obj/item/clothing/under/haori/red
	name = "haori"
	desc = "A light, loose fitting bit of clothes, worn in japan."
	icon_state = "haori2"
	item_state = "haori2"
	worn_state = "haori2"

/obj/item/clothing/under/haori/samurai
	name = "haori"
	desc = "A light, loose fitting bit of clothes, worn in japan."
	icon_state = "haori_samurai"
	item_state = "haori_samurai"
	worn_state = "haori_samurai"

/obj/item/clothing/under/haori/samurai/blue
	name = "haori"
	desc = "A light, loose fitting bit of clothes, worn in japan."
	icon_state = "haori_samurai2"
	item_state = "haori_samurai2"
	worn_state = "haori_samurai2"

/obj/item/clothing/under/haori/samurai/red
	name = "haori"
	desc = "A light, loose fitting bit of clothes, worn in japan."
	icon_state = "haori_samurai3"
	item_state = "haori_samurai3"
	worn_state = "haori_samurai3"

	/* Medieval Japanese Shoes & Boots*/

/obj/item/clothing/shoes/geta
	name = "geta sandals"
	desc = "A pair of simple, wood sandals. Keeps you elevated off he ground slightly."
	icon_state = "geta"
	item_state = "geta"
	worn_state = "geta"
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 5, arrow = 3, gun = FALSE, energy = 5, bomb = 5, bio = 5, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	var/obj/item/weapon/handcuffs/chained = null

/obj/item/clothing/shoes/geta/proc/attach_cuffs(var/obj/item/weapon/handcuffs/cuffs, mob/user as mob)
	if (chained) return

	user.drop_item()
	cuffs.loc = src
	chained = cuffs
	slowdown = 15
	icon_state = "geta1"
	worn_state = "geta1"
	update_icon()

/obj/item/clothing/shoes/geta/proc/remove_cuffs(mob/user as mob)
	if (!chained) return

	user.put_in_hands(chained)
	chained.add_fingerprint(user)

	slowdown = initial(slowdown)
	icon_state = "geta"
	worn_state = "geta"
	chained = null
	update_icon()

/obj/item/clothing/shoes/geta/attack_self(mob/user as mob)
	..()
	remove_cuffs(user)

/obj/item/clothing/shoes/geta/attackby(H as obj, mob/user as mob)
	..()
	if (istype(H, /obj/item/weapon/handcuffs))
		attach_cuffs(H, user)

/obj/item/clothing/shoes/tsuranuki
	name = "tsuranuki"
	desc = "A pair of plated shin guards & shoes of japanese origin."
	icon_state = "tsuranuki"
	item_state = "tsuranuki"
	worn_state = "tsuranuki"
	body_parts_covered = FEET|LEG_RIGHT|LEG_LEFT
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 45, arrow = 30, gun = 7, energy = 8, bomb = 25, bio = 15, rad = FALSE)
	cold_protection = FEET|LEG_RIGHT|LEG_LEFT
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	health = 35
	item_flags = NOSLIP

/obj/item/clothing/gloves/gauntlets/kote
	name = "kote gauntlets"
	desc = "A pair of armored iron bracer guards of japanese origin."
	icon_state = "kote"
	item_state = "kote"
	worn_state = "kote"
	body_parts_covered = HANDS|ARM_RIGHT|ARM_LEFT
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 45, arrow = 30, gun = 7, energy = 8, bomb = 25, bio = 15, rad = FALSE)
	cold_protection = HANDS|ARM_RIGHT|ARM_LEFT
	min_cold_protection_temperature = GLOVES_MIN_COLD_PROTECTION_TEMPERATURE
	slowdown = 0.1
	health = 23

	/* Medieval Japanese Headpieces & Helmets*/

/obj/item/clothing/head/helmet/samurai
	name = "samurai helmet"
	desc = "A thick metal helmet of japanese origin. Typically worn by feudal warriors."
	icon_state = "samurai_warrior3"
	item_state = "samurai_warrior3"
	worn_state = "samurai_warrior3"
	body_parts_covered = HEAD
	armor = list(melee = 60, arrow = 50, gun = 10, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	health = 45

/obj/item/clothing/head/helmet/samurai/lord/brown
	name = "samurai lord helmet"
	desc = "A impressionable & thick metal helmet with a jaw protective plate built in of japanese origin. Typically worn by feudal warriors."
	icon_state = "samurai_lord3"
	item_state = "samurai_lord3"
	worn_state = "samurai_lord3"
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 45
	slowdown = 0.15
	var/toggled = FALSE

/obj/item/clothing/head/helmet/samurai/lord/brown/verb/toggle_visor()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/samurai/lord/brown)
		return
	else
		if (toggled)
			item_state = "samurai_lord3_o"
			icon_state = "samurai_lord3_o"
			worn_state = "samurai_lord3_o"
			item_state_slots["slot_head"] = "samurai_lord3_o"
			usr << "<span class = 'danger'>You put up your helmet's faceguard.</span>"
			toggled = FALSE
			update_clothing_icon()
			body_parts_covered = HEAD
			flags_inv = BLOCKHEADHAIR
		else if (!toggled)
			item_state = "samurai_lord3"
			icon_state = "samurai_lord3"
			worn_state = "samurai_lord3"
			item_state_slots["slot_head"] = "samurai_lord3"
			usr << "<span class = 'danger'>You put down your helmet's faceguard.</span>"
			toggled = TRUE
			update_clothing_icon()
			body_parts_covered = HEAD|FACE
			flags_inv = BLOCKHAIR

/obj/item/clothing/head/helmet/jingasa
	name = "jingasa"
	desc = "A thick leather and straw hat of japanese origin. Typically worn by ranged combatant samurai."
	icon_state = "jingasa"
	item_state = "jingasa"
	worn_state = "jingasa"
	body_parts_covered = HEAD
	armor = list(melee = 30, arrow = 15, gun = 5, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	health = 30
	var/adjusted = FALSE

/obj/item/clothing/head/helmet/jingasa/verb/adjust_flaps()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/jingasa)
		return
	else
		if (adjusted)
			item_state = "jingasa"
			worn_state = "jingasa"
			item_state_slots["slot_head"] = "jingasa"
			usr << "<span class = 'danger'>You adjust your jingasa's flaps.</span>"
			adjusted = FALSE
		else if (!adjusted)
			item_state = "jingasa_flaps"
			worn_state = "jingasa_flaps"
			item_state_slots["slot_head"] = "jingasa_flaps"
			usr << "<span class = 'danger'>You adjust your jingasa's flaps.</span>"
			adjusted = TRUE
	update_clothing_icon()

/obj/item/clothing/head/helmet/kasa
	name = "kasa"
	desc = "A thick straw hat of japanese origin. Typically worn by travelers."
	icon_state = "kasa"
	item_state = "kasa"
	worn_state = "kasa"
	body_parts_covered = HEAD
	armor = list(melee = 20, arrow = 15, gun = 5, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/samurai/guard
	name = "leather samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by petty guards and light infantry."
	icon_state = "samurai_guard3"
	item_state = "samurai_guard3"
	worn_state = "samurai_guard3"
	body_parts_covered = HEAD
	armor = list(melee = 45, arrow = 40, gun = 7, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 32

/obj/item/clothing/head/helmet/samurai/guard/red
	name = "red leather samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by petty guards and light infantry."
	icon_state = "samurai_guard1"
	item_state = "samurai_guard1"
	worn_state = "samurai_guard1"

/obj/item/clothing/head/helmet/samurai/guard/blue
	name = "blue leather samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by petty guards and light infantry."
	icon_state = "samurai_guard2"
	item_state = "samurai_guard2"
	worn_state = "samurai_guard2"

/obj/item/clothing/head/helmet/samurai/guard/black
	name = "black leather samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by petty guards and light infantry."
	icon_state = "samurai_guard4"
	item_state = "samurai_guard4"
	worn_state = "samurai_guard4"

/obj/item/clothing/head/helmet/samurai/red
	name = "red samurai helmet"
	desc = "A thick metal helmet of japanese origin. Typically worn by feudal warriors."
	icon_state = "samurai_warrior1"
	item_state = "samurai_warrior1"
	worn_state = "samurai_warrior1"

/obj/item/clothing/head/helmet/samurai/blue
	name = "blue samurai helmet"
	desc = "A thick metal helmet of japanese origin. Typically worn by feudal warriors."
	icon_state = "samurai_warrior2"
	item_state = "samurai_warrior2"
	worn_state = "samurai_warrior2"

obj/item/clothing/head/helmet/samurai/black
	name = "black samurai helmet"
	desc = "A thick metal helmet of japanese origin. Typically worn by feudal warriors."
	icon_state = "samurai_warrior4"
	item_state = "samurai_warrior4"
	worn_state = "samurai_warrior4"

/obj/item/clothing/head/helmet/samurai/lord/red
	name = "red samurai lord helmet"
	desc = "A impressionable & thick metal helmet with a jaw protective plate built in of japanese origin. Typically worn by feudal warriors."
	icon_state = "samurai_lord1"
	item_state = "samurai_lord1"
	worn_state = "samurai_lord1"
	var/toggled = FALSE

/obj/item/clothing/head/helmet/samurai/lord/red/verb/toggle_visor()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/samurai/lord/red)
		return
	else
		if (toggled)
			item_state = "samurai_lord1_o"
			icon_state = "samurai_lord1_o"
			worn_state = "samurai_lord1_o"
			item_state_slots["slot_head"] = "samurai_lord1_o"
			usr << "<span class = 'danger'>You put up your helmet's faceguard.</span>"
			toggled = FALSE
			update_clothing_icon()
			body_parts_covered = HEAD
			flags_inv = BLOCKHEADHAIR
		else if (!toggled)
			item_state = "samurai_lord1"
			icon_state = "samurai_lord1"
			worn_state = "samurai_lord1"
			item_state_slots["slot_head"] = "samurai_lord1"
			usr << "<span class = 'danger'>You put down your helmet's faceguard.</span>"
			toggled = TRUE
			update_clothing_icon()
			body_parts_covered = HEAD|FACE
			flags_inv = BLOCKHAIR

/obj/item/clothing/head/helmet/samurai/lord/blue
	name = "blue samurai lord helmet"
	desc = "A impressionable & thick metal helmet with a jaw protective plate built in of japanese origin. Typically worn by feudal warriors."
	icon_state = "samurai_lord2"
	item_state = "samurai_lord2"
	worn_state = "samurai_lord2"
	var/toggled = FALSE

/obj/item/clothing/head/helmet/samurai/lord/blue/verb/toggle_visor()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/samurai/lord/blue)
		return
	else
		if (toggled)
			item_state = "samurai_lord2_o"
			icon_state = "samurai_lord2_o"
			worn_state = "samurai_lord2_o"
			item_state_slots["slot_head"] = "samurai_lord2_o"
			usr << "<span class = 'danger'>You put up your helmet's faceguard.</span>"
			toggled = FALSE
			update_clothing_icon()
			body_parts_covered = HEAD
			flags_inv = BLOCKHEADHAIR
		else if (!toggled)
			item_state = "samurai_lord2"
			icon_state = "samurai_lord2"
			worn_state = "samurai_lord2"
			item_state_slots["slot_head"] = "samurai_lord2"
			usr << "<span class = 'danger'>You put down your helmet's faceguard.</span>"
			toggled = TRUE
			update_clothing_icon()
			body_parts_covered = HEAD|FACE
			flags_inv = BLOCKHAIR

/obj/item/clothing/head/helmet/samurai/lord/black
	name = "black samurai lord helmet"
	desc = "A impressionable & thick metal helmet with a jaw protective plate built in of japanese origin. Typically worn by feudal warriors."
	icon_state = "samurai_lord4"
	item_state = "samurai_lord4"
	worn_state = "samurai_lord4"
	var/toggled = FALSE

/obj/item/clothing/head/helmet/samurai/lord/black/verb/toggle_visor()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/samurai/lord/black)
		return
	else
		if (toggled)
			item_state = "samurai_lord4_o"
			icon_state = "samurai_lord4_o"
			worn_state = "samurai_lord4_o"
			item_state_slots["slot_head"] = "samurai_lord4_o"
			usr << "<span class = 'danger'>You put up your helmet's faceguard.</span>"
			toggled = FALSE
			update_clothing_icon()
			body_parts_covered = HEAD
			flags_inv = BLOCKHEADHAIR
		else if (!toggled)
			item_state = "samurai_lord4"
			icon_state = "samurai_lord4"
			worn_state = "samurai_lord4"
			item_state_slots["slot_head"] = "samurai_lord4"
			usr << "<span class = 'danger'>You put down your helmet's faceguard.</span>"
			toggled = TRUE
			update_clothing_icon()
			body_parts_covered = HEAD|FACE
			flags_inv = BLOCKHAIR

	/* Medieval Japanese Masks*/

/obj/item/clothing/mask/samurai
	name = "samurai mask"
	desc = "A mask of metal, often worn by lords to protect their face."
	icon_state = "samurai1"
	item_state = "samurai1"
	worn_state = "samurai1"
	body_parts_covered = FACE|EYES
	flags = CONDUCT
	flags_inv = 0
	w_class = ITEM_SIZE_SMALL
	armor = list(melee = 20, arrow = 15, gun = 5, energy = 15, bomb = 55, bio = 20, rad = FALSE) //nerfed, armor stacking bad.
	restricts_view = 1

/obj/item/clothing/mask/samurai/red
	name = "red samurai mask"
	icon_state = "samurai2"
	item_state = "samurai2"
	worn_state = "samurai2"

/obj/item/clothing/mask/samurai/blue
	name = "blue samurai mask"
	icon_state = "samurai3"
	item_state = "samurai3"
	worn_state = "samurai3"

/* Miscallenous Medieval Extra-Cultural Clothes*/

/obj/item/clothing/head/gat
	name = "gat hat"
	desc = "A traditional korean hat."
	icon_state = "gat"
	item_state = "gat"
	worn_state = "gat"

/* Fantasy Medieval Clothes*/ //tell admins to iconswap preferencially to spawning in the piece itself if engaging in a event duel, since these are more op than they appear.

/obj/item/clothing/head/turban/toadstool
	name = "toadstool hat"
	desc = "The princess is in another castle."
	icon_state = "toadstool"
	item_state = "toadstool"
	worn_state = "toadstool"
	heat_protection = HEAD
/obj/item/clothing/head/turban/toadstool/New()
	..()
	icon_state = "toadstool"
	item_state = "toadstool"
	worn_state = "toadstool"

	/* Fantasy Crusader Helmets */

/obj/item/clothing/head/helmet/medieval/whitestrake
	name = "penlianal_whitestrake helmet"
	desc = "The thick legendary paladin helmet of a martially gifted genocidal maniac. Or great hero from particular point of view."
	icon_state = "penlianal_whitestrake"
	item_state = "penlianal_whitestrake"
	worn_state = "penlianal_whitestrake"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 60
	slowdown = 0.10

/obj/item/clothing/head/helmet/medieval/hellknight
	name = "hell knight helmet"
	desc = "The thick horned helmet of elite demonic champions. A green furor of anger and hatred spills out of its narrow slit eye holes."
	icon_state = "hell_champion"
	item_state = "hell_champion"
	worn_state = "hell_champion"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 60
	slowdown = 0.10

/obj/item/clothing/head/helmet/medieval/saint
	name = "saint helmet"
	desc = "The thick helmet of those chosen of divinity, a angelic halo hangs overhead."
	icon_state = "crusader_saint"
	item_state = "crusader_saint"
	worn_state = "crusader_saint"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 60
	slowdown = 0.10

	/* Dark Souls Armor*/

/obj/item/clothing/head/helmet/medieval/giantdad
	name = "lordran helmet"
	desc = "The legendary helmet of the father, it is said its former owner's booming voice could answer any challenge"
	icon_state = "giantdad"
	item_state = "giantdad"
	worn_state = "giantdad"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 65
	slowdown = 0.10

/* wip
/obj/item/clothing/suit/armor/giantdad
	name = "lordran armor"
	desc = "The legendary armor of the father, its pierce mark from a equally legendary sword is indistinguishable. It is written he got back up again and smited the attacker."
	icon_state = "giantdad"
	item_state = "giantdad"
	worn_state = "giantdad"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 85, arrow = 100, gun = 20, energy = 15, bomb = 65, bio = 20, rad = FALSE)
	health = 90
	slowdown = 1.2

/obj/item/clothing/gloves/gauntlets/giantdad
	name = "lordran gauntlets"
	desc = "The legendary gauntlets of the father, protective and flexible for gripping his weapon and pointing downwards at his opponents."
	icon_state = "giantdad"
	item_state = "giantdad"
	worn_state = "giantdad"
	body_parts_covered = HANDS
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 75, arrow = 60, gun = 10, energy = 8, bomb = 25, bio = 15, rad = FALSE)
	cold_protection = HANDS
	min_cold_protection_temperature = GLOVES_MIN_COLD_PROTECTION_TEMPERATURE
	slowdown = 0.1
	health = 40

/obj/item/clothing/shoes/medieval/giantdad
	name = "lordran shoes"
	desc = "A legendary pair of plated armored shoes, they are suprisingly light. Ideal for outmaneuvering duelists."
	icon_state = "giantdad"
	item_state = "giantdad"
	worn_state = "giantdad"
	body_parts_covered = FEET
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 75, arrow = 60, gun = 10, energy = 8, bomb = 25, bio = 15, rad = FALSE)
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	health = 40
*/
///////////////////////////////////////////////SKYRIM////////////////////////////////////////////////////////
/obj/item/clothing/head/helmet/medieval/tes13/dwemmer
	name = "dwemmer helmet"
	desc = "The thick helmet of elite dwemmer warriors."
	icon_state = "dwelmet"
	item_state = "dwelmet"
	worn_state = "dwelmet"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 80
	slowdown = 0.10

/obj/item/clothing/gloves/gauntlets/tes13/dwemmer
	name = "dwemmer gauntlets"
	desc = "A pair of armored dwemmer bracer guards of dwemmer origin."
	icon_state = "dwoves"
	item_state = "dwoves"
	worn_state = "dwoves"
	body_parts_covered = HANDS|ARM_RIGHT|ARM_LEFT
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 70, arrow = 40, gun = 7, energy = 8, bomb = 25, bio = 15, rad = FALSE)
	cold_protection = HANDS|ARM_RIGHT|ARM_LEFT
	min_cold_protection_temperature = GLOVES_MIN_COLD_PROTECTION_TEMPERATURE
	slowdown = 0.1
	health = 50

/obj/item/clothing/shoes/dwemmer
	name = "dwemmer boots"
	desc = "A pair of plated boots made of dwemmer metal."
	icon_state = "dwoots"
	item_state = "dwoots"
	worn_state = "dwoots"
	body_parts_covered = FEET|LEG_RIGHT|LEG_LEFT
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 70, arrow = 50, gun = 7, energy = 8, bomb = 25, bio = 15, rad = FALSE)
	cold_protection = FEET|LEG_RIGHT|LEG_LEFT
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	health = 50
	item_flags = NOSLIP

/obj/item/clothing/suit/armor/tes13/dwemmer
	name = "dwemmer armor"
	desc = "A thick, expensive armor of dwemmer metal."
	icon_state = "dwarmor"
	item_state = "dwarmor"
	worn_state = "dwarmor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 85, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 80
////////whiterun/stormcloaks/////////
/obj/item/clothing/under/tes13/stormcloak
	name = "stormcloak curass"
	desc = "A blue tabard over some leather armor with chainmail underneath."
	icon_state = "stormcloak"
	item_state = "stormcloak"
	worn_state = "stormcloak"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
	armor = list(melee = 45, arrow = 30, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/under/tes13/stormcloak/female
	desc = "A blue tabard over some leather armor with chainmail underneath. This one is fitted for women."
	icon_state = "stormcloak_f"
	item_state = "stormcloak_f"
	worn_state = "stormcloak_f"

/obj/item/clothing/under/tes13/whiterun
	name = "whiterun guard curass"
	desc = "An orange tabard over some leather armor with chainmail underneath."
	icon_state = "whiterun"
	item_state = "whiterun"
	worn_state = "whiterun"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
	armor = list(melee = 45, arrow = 30, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/under/tes13/whiterun/female
	desc = "An orange tabard over some leather armor with chainmail underneath. This one is fitted for women."
	icon_state = "whiterun_f"
	item_state = "whiterun_f"
	worn_state = "whiterun_f"

/obj/item/clothing/head/helmet/medieval/tes13/guard
	name = "guard helmet"
	desc = "A thick helmet of steel worn often by soldiers or guards."
	icon_state = "tes13"
	item_state = "tes13"
	worn_state = "tes13"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHAIR
	armor = list(melee = 50, arrow = 30, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 60
	slowdown = 0.05

/obj/item/clothing/head/helmet/medieval/tes13/hide
	name = "hide helmet"
	desc = "A thick helmet of hide worn often by soldiers or guards."
	icon_state = "tes13_hide"
	item_state = "tes13_hide"
	worn_state = "tes13_hide"
	body_parts_covered = HEAD
	flags_inv = BLOCKHAIR
	armor = list(melee = 35, arrow = 20, gun = 10, energy = 15, bomb = 20, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 60
	slowdown = 0.01

/obj/item/clothing/head/helmet/medieval/tes13/iron
	name = "iron helmet"
	desc = "A thick horned helmet of iron worn often by bandits mercenaries and travelers."
	icon_state = "tes13_iron"
	item_state = "tes13_iron"
	worn_state = "tes13_iron"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHAIR
	armor = list(melee = 45, arrow = 30, gun = 15, energy = 25, bomb = 30, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 100
	slowdown = 0.02

/obj/item/clothing/suit/armor/tes13/stormcloak
	name = "stormcloak officer armor"
	desc = "A thick, leather armor of hide with a bearpelt draped over it."
	icon_state = "stormcloak"
	item_state = "stormcloak"
	worn_state = "stormcloak"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 65, arrow = 45, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 0.4
	health = 80

/obj/item/clothing/suit/armor/tes13/imperial
	name = "imperial officer armor"
	desc = "A thick, steel armor worn by imperial officers"
	icon_state = "imperial_officer"
	item_state = "imperial_officer"
	worn_state = "imperial_officer"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 65, arrow = 45, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 0.5
	health = 80

/obj/item/clothing/head/helmet/medieval/tes13/stormcloak
	name = "stormcloak officer helmet"
	desc = "A bear pelt helmet with an armored lining."
	icon_state = "stormcloak"
	item_state = "stormcloak"
	worn_state = "stormcloak"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHAIR
	armor = list(melee = 60, arrow = 45, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 80
	slowdown = 0.05


/obj/item/clothing/under/tes13/imperial
	name = "imperial armor"
	desc = "A red tunic with leather armor overtop."
	icon_state = "tes13_imperial"
	item_state = "tes13_imperial"
	worn_state = "tes13_imperial"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
	armor = list(melee = 45, arrow = 30, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/head/helmet/medieval/tes13/imperial
	name = "imperial helmet"
	desc = "An imperial helmet made of leather"
	icon_state = "tes13_imperial"
	item_state = "tes13_imperial"
	worn_state = "tes13_imperial"
	body_parts_covered = HEAD
	flags_inv = BLOCKHAIR
	armor = list(melee = 45, arrow = 40, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 80
	slowdown = 0.01

/obj/item/clothing/head/helmet/medieval/tes13/imperial/officer
	name = "imperial officer helmet"
	desc = "An imperial helmet made of steel"
	icon_state = "tes13_imperial_officer"
	item_state = "tes13_imperial_officer"
	worn_state = "tes13_imperial_officer"
	body_parts_covered = HEAD
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 50, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 80
	slowdown = 0.03


/obj/item/clothing/under/tes13/stormcloak/ulfirc
	name = "Ulfric Stormcloak's clothes"
	desc = "A suit of blue fine clothing over some trousers"
	icon_state = "ulfric"
	item_state = "ulfric"
	worn_state = "ulfric"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
	body_parts_covered = HEAD|EYES|LOWER_TORSO|LEGS|UPPER_TORSO|ARMS
	armor = list(melee = 80, arrow = 80, gun = 10, energy = 15, bomb = 80, bio = 20, rad = FALSE)
	health = 200

/obj/item/clothing/under/tes13/imperial/bolgruf
	name = "Jarl Bolgruf's clothes"
	desc = "A suit of fine clothing over some trousers"
	icon_state = "bolgruf"
	item_state = "bolgruf"
	worn_state = "bolgruf"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
	body_parts_covered = HEAD|EYES|LOWER_TORSO|LEGS|UPPER_TORSO|ARMS
	armor = list(melee = 80, arrow = 80, gun = 10, energy = 15, bomb = 80, bio = 20, rad = FALSE)
	health = 200
/////////////tes13 civilian/////////////////////////
/obj/item/clothing/suit/storage/coat/tes13/fine_clothing
	name = "fine clothing"
	desc = "A fine fur jacket and shirt, for the better off people."
	icon_state = "fine_clothes"
	item_state = "fine_clothes"
	worn_state = "fine_clothes"
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	health = 60

/obj/item/clothing/suit/storage/coat/tes13/fine_clothing/blue
	name = "fine clothing"
	desc = "A fine fur jacket and shirt, for the better off people. This one is blue"
	icon_state = "fine_clothes2"
	item_state = "fine_clothes2"
	worn_state = "fine_clothes2"
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	health = 60