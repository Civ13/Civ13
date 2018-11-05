/obj/item/clothing/shoes/medieval
	name = "leather shoes"
	desc = "A pair of simple, thin leather shoes. Covers up to the ankle."
	icon_state = "medieval"
	item_state = "medieval"
	worn_state = "medieval"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 15, bullet = 10, laser = 10,energy = 8, bomb = 15, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6

/obj/item/clothing/shoes/medieval/knight
	name = "armored shoes"
	desc = "A pair of plated armored shoes."
	icon_state = "knight"
	item_state = "knight"
	worn_state = "knight"
	body_parts_covered = FEET
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 75, bullet = 60, laser = 10,energy = 8, bomb = 25, bio = 15, rad = FALSE)

/obj/item/clothing/under/medieval
	name = "white tunic"
	desc = "A long white tunic, with golden trimmings."
	icon_state = "white_tunic_long"
	item_state = "white_tunic_long"
	worn_state = "white_tunic_long"

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

/obj/item/clothing/suit/armor/medieval
	name = "plated armor"
	desc = "A thick, expensive iron armor, covering most of the body."
	icon_state = "knight_simple"
	item_state = "knight_simple"
	worn_state = "knight_simple"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 70, bullet = 90, laser = 10,energy = 15, bomb = 60, bio = 20, rad = FALSE)
	value = 50
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
	armor = list(melee = 50, bullet = 30, laser = 10,energy = 15, bomb = 40, bio = 20, rad = FALSE)
	value = 25
/obj/item/clothing/suit/armor/medieval/iron_chestplate
	name = "iron chestplate"
	desc = "An iron chestplate."
	icon_state = "iron_chestplate"
	item_state = "iron_chestplate"
	worn_state = "iron_chestplate"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, bullet = 40, laser = 10,energy = 15, bomb = 40, bio = 20, rad = FALSE)
	value = 32

/obj/item/clothing/suit/armor/medieval/iron_chestplate/red
	..()
	icon_state = "iron_chestplater"
	item_state = "iron_chestplater"
	worn_state = "iron_chestplater"
/obj/item/clothing/suit/armor/medieval/iron_chestplate/blue
	..()
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
	armor = list(melee = 30, bullet = 15, laser = 10,energy = 15, bomb = 20, bio = 20, rad = FALSE)
	value = 15
/obj/item/clothing/suit/armor/medieval/chainmail
	name = "chainmail"
	desc = "Wearable armor made of several small interlinked chains."
	icon_state = "chainmail"
	item_state = "chainmail"
	worn_state = "chainmail"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 50, bullet = 35, laser = 15,energy = 15, bomb = 30, bio = 20, rad = FALSE)
	value = 20

/obj/item/clothing/head/helmet/medieval
	name = "knight helmet"
	desc = "A thick knight helmet."
	icon_state = "knight_simple"
	item_state = "knight_simple"
	worn_state = "knight_simple"
	body_parts_covered = HEAD|FACE|EYES
	armor = list(melee = 70, bullet = 90, laser = 10,energy = 15, bomb = 60, bio = 20, rad = FALSE)
	flags_inv = BLOCKHAIR

/obj/item/clothing/head/helmet/medieval/templar
	name = "templar knight helmet"
	desc = "A thick knight helmet, with a yellow cross painted on the front."
	icon_state = "knight_templar"
	item_state = "knight_templar"
	worn_state = "knight_templar"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, bullet = 90, laser = 10,energy = 15, bomb = 60, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/helmet1
	name = "protective conical helmet"
	desc = "A conical helmet, with nose and ear protection."
	icon_state = "medieval_helmet1"
	item_state = "medieval_helmet1"
	worn_state = "medieval_helmet1"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, bullet = 40, laser = 10,energy = 15, bomb = 50, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/helmet2
	name = "kettle helmet"
	desc = "A wide brim iron helmet."
	icon_state = "medieval_helmet2"
	item_state = "medieval_helmet2"
	worn_state = "medieval_helmet2"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, bullet = 35, laser = 10,energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/helmet3
	name = "conical helmet"
	desc = "A conical helmet, with nose protection."
	icon_state = "medieval_helmet3"
	item_state = "medieval_helmet3"
	worn_state = "medieval_helmet3"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, bullet = 30, laser = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/coif
	name = "iron coif"
	desc = "A chainmail headcover."
	icon_state = "coif"
	item_state = "coif"
	worn_state = "coif"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, bullet = 40, laser = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/coif_helmet
	name = "iron coif and helmet"
	desc = "A chainmail headcover, with a conical helmet on top."
	icon_state = "coif"
	item_state = "coif"
	worn_state = "coif"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, bullet = 45, laser = 10, energy = 15, bomb = 60, bio = 30, rad = FALSE)


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




/obj/item/clothing/head/noblehat1
	name = "red noble hat"
	icon_state = "noblehat1"
	item_state = "noblehat1"

/obj/item/clothing/head/noblehat2
	name = "purple noble hat"
	icon_state = "noblehat2"
	item_state = "noblehat2"