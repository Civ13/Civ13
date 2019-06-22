/obj/item/clothing/shoes/medieval
	name = "leather shoes"
	desc = "A pair of simple, thin leather shoes. Covers up to the ankle."
	icon_state = "medieval"
	item_state = "medieval"
	worn_state = "medieval"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 15, arrow = 10, gun = FALSE, energy = 8, bomb = 15, bio = 10, rad = 10)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
/obj/item/clothing/shoes/medieval/arab
	name = "arabic leather shoes"
	desc = "A pair of simple, thin leather shoes. Loose at the tip."
	icon_state = "arab"
	item_state = "arab"
	worn_state = "arab"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 10, arrow = 8, gun = FALSE, energy = 6, bomb = 12, bio = 10, rad = 10)
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
	armor = list(melee = 75, arrow = 60, gun = 10, energy = 8, bomb = 25, bio = 15, rad = 25)
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/under/medieval
	name = "white tunic"
	desc = "A long white tunic, with golden trimmings."
	icon_state = "white_tunic_long"
	item_state = "white_tunic_long"
	worn_state = "white_tunic_long"

/obj/item/clothing/under/renaissance
	name = "purple renaissance clothing"
	desc = "A baggy renaissance-style outfit."
	icon_state = "renaissance"
	item_state = "renaissance"
	worn_state = "renaissance"

/obj/item/clothing/under/renaissance_pontifical
	name = "pontifical renaissance clothing"
	desc = "A baggy renaissance-style outfit, with colored stripes."
	icon_state = "pontifical"
	item_state = "pontifical"
	worn_state = "pontifical"

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

/obj/item/clothing/suit/storage/jacket/arabic_robe
	name = "arabic robe"
	desc = "A light, loose fitting arabic robe."
	icon_state = "arabw_robe"
	item_state = "arabw_robe"
	worn_state = "arabw_robe"

/obj/item/clothing/under/medieval/arab1
	name = "light brown arabic tunic"
	desc = "A light, loose fitting arabic tunic."
	icon_state = "arab1"
	item_state = "arab1"
	worn_state = "arab1"

/obj/item/clothing/under/medieval/arab2
	name = "light white arabic tunic"
	desc = "A light, loose fitting arabic tunic."
	icon_state = "arab1"
	item_state = "arab1"
	worn_state = "arab1"

/obj/item/clothing/under/medieval/arab3
	name = "white arabic tunic"
	desc = "A loose fitting arabic tunic."
	icon_state = "arab3"
	item_state = "arab3"
	worn_state = "arab3"

/obj/item/clothing/suit/armor/medieval
	name = "plated armor"
	desc = "A thick, expensive iron armor, covering most of the body."
	icon_state = "knight_simple"
	item_state = "knight_simple"
	worn_state = "knight_simple"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = 45)
	value = 50
	slowdown = 1.5
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
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 40, bio = 20, rad = 20)
	value = 25
	slowdown = 0.7
/obj/item/clothing/suit/armor/medieval/iron_chestplate
	name = "iron chestplate"
	desc = "An iron chestplate."
	icon_state = "iron_chestplate"
	item_state = "iron_chestplate"
	worn_state = "iron_chestplate"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 40, gun = 8, energy = 15, bomb = 40, bio = 20, rad = 25)
	value = 32
	slowdown = 0.8
/obj/item/clothing/suit/armor/medieval/iron_chestplate/red
	..()
	icon_state = "iron_chestplater"
	item_state = "iron_chestplater"
	worn_state = "iron_chestplater"

/obj/item/clothing/suit/armor/medieval/iron_chestplate/crusader
	..()
	icon_state = "iron_chestplatec"
	item_state = "iron_chestplatec"
	worn_state = "iron_chestplatec"
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
	armor = list(melee = 30, arrow = 15, gun = FALSE, energy = 15, bomb = 20, bio = 20, rad = 10)
	value = 20
	flammable = TRUE
	slowdown = 0.2

/obj/item/clothing/accessory/armor
	icon = 'icons/obj/clothing/suits.dmi'
	slot = "armor"
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

/obj/item/clothing/suit/armor/medieval/chainmail
	name = "chainmail"
	desc = "Wearable armor made of several small interlinked chains."
	icon_state = "chainmail"
	item_state = "chainmail"
	worn_state = "chainmail"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 30, bio = 20, rad = 10)
	value = 30
	slowdown = 0.6

/obj/item/clothing/accessory/armor/chainmail
	name = "chainmail"
	desc = "Wearable armor made of several small interlinked chains."
	icon_state = "chainmail"
	item_state = "chainmail"
	worn_state = "chainmail"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 30, bio = 20, rad = 10)
	value = 30
	slowdown = 0.6

/obj/item/clothing/suit/armor/medieval/hauberk
	name = "hauberk"
	desc = "A longer version of the chainmail, worn as a coat. Offers greater protection."
	icon_state = "hauberk"
	item_state = "hauberk"
	worn_state = "hauberk"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 60, arrow = 55, gun = 10, energy = 20, bomb = 40, bio = 30, rad = 15)
	value = 40
	slowdown = 0.75
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
	item_state = "gold_crown"
	worn_state = "gold_crown_diamond"
	armor = list(melee = 25, arrow = 20, gun = 10, energy = 25, bomb = 20, bio = 15, rad = FALSE)

/obj/item/clothing/head/helmet/silver_crown_diamond
	name = "inlaid silver crown"
	desc = "A crown of silver, with a diamond in it. Extra Fancy."
	icon_state = "silver_crown_diamond"
	item_state = "silver_crown"
	worn_state = "gold_crown_diamond"
	armor = list(melee = 25, arrow = 20, gun = 10, energy = 25, bomb = 20, bio = 15, rad = FALSE)

/obj/item/clothing/head/helmet/silver_crown/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/stack/material/diamond))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the diamond in the crown.</span>"
		new/obj/item/clothing/head/helmet/silver_crown_diamond(user.loc)
		qdel(src)
		qdel(W)

/obj/item/clothing/head/helmet/gold_crown/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/stack/material/diamond))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the diamond in the crown.</span>"
		new/obj/item/clothing/head/helmet/gold_crown_diamond(user.loc)
		qdel(src)
		qdel(W)
//continue

/obj/item/clothing/head/helmet/medieval
	name = "knight helmet"
	desc = "A thick knight helmet."
	icon_state = "knight_simple"
	item_state = "knight_simple"
	worn_state = "knight_simple"
	body_parts_covered = HEAD|FACE|EYES
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = 35)
	flags_inv = BLOCKHAIR
	restricts_view = 2

/obj/item/clothing/head/helmet/medieval/templar
	name = "templar knight helmet"
	desc = "A thick knight helmet, with a yellow cross painted on the front."
	icon_state = "knight_templar"
	item_state = "knight_templar"
	worn_state = "knight_templar"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = 35)

/obj/item/clothing/head/helmet/medieval/helmet1
	name = "protective conical helmet"
	desc = "A conical helmet, with nose and ear protection."
	icon_state = "medieval_helmet1"
	item_state = "medieval_helmet1"
	worn_state = "medieval_helmet1"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/helmet2
	name = "kettle helmet"
	desc = "A wide brim iron helmet."
	icon_state = "medieval_helmet2"
	item_state = "medieval_helmet2"
	worn_state = "medieval_helmet2"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 35, gun = 5, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/helmet3
	name = "conical helmet"
	desc = "A conical helmet, with nose protection."
	icon_state = "medieval_helmet3"
	item_state = "medieval_helmet3"
	worn_state = "medieval_helmet3"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 5, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/coif
	name = "iron coif"
	desc = "A chainmail headcover."
	icon_state = "coif"
	item_state = "coif"
	worn_state = "coif"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 40, gun = 7, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/coif_helmet
	name = "iron coif and helmet"
	desc = "A chainmail headcover, with a conical helmet on top."
	icon_state = "coif_helmet"
	item_state = "coif_helmet"
	worn_state = "coif_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 10, energy = 15, bomb = 60, bio = 30, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/arab
	name = "conical arabic helmet and turban"
	desc = "An iron helmet, covered with a turban."
	icon_state = "turhelm1"
	item_state = "turhelm1"
	worn_state = "turhelm1"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/arab2
	name = "long arabic helmet and turban"
	desc = "An iron helmet, covered with a turban, with side protections for the face."
	icon_state = "arabw_helmet1"
	item_state = "arabw_helmet1"
	worn_state = "arabw_helmet1"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)

/obj/item/clothing/head/helmet/medieval/arab3
	name = "long arabic helmet"
	desc = "An iron helmet, covered with a turban, with side protections for the face."
	icon_state = "arabw_helmet"
	item_state = "arabw_helmet"
	worn_state = "arabw_helmet"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 5, energy = 15, bomb = 60, bio = 30, rad = FALSE)


/obj/item/clothing/head/helmet/medieval/arab/New()
	..()
	var/pickcolor = pick("turhelm1", "turhelm2", "turhelm3", "turhelm4")
	icon_state = pickcolor
	item_state = pickcolor
	worn_state = pickcolor

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
	name = "brown noble hat"
	icon_state = "noblehat1"
	item_state = "noblehat1"

/obj/item/clothing/head/noblehat2
	name = "black noble hat"
	icon_state = "noblehat2"
	item_state = "noblehat2"

/obj/item/clothing/head/turban
	name = "turban"
	desc = "a colored, light fabric turban."
	icon_state = "turban1"
	item_state = "turban1"
	worn_state = "turban1"

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
/obj/item/clothing/head/turban/New()
	..()
	var/pickcolor = pick("turban1", "turban2", "turban3", "turban4")
	icon_state = pickcolor
	item_state = pickcolor
	worn_state = pickcolor

//mesoamerican stuff
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

/obj/item/clothing/under/halfhuipil
	name = "half huipil"
	desc = "a light cloth, covering the lower part of the body. With red trimmings."
	icon_state = "halfhuipil"
	item_state = "halfhuipil"
	worn_state = "halfhuipil"

/obj/item/clothing/suit/armor/samurai
	name = "samurai armor"
	desc = "A thick, leather armor, covering most of the body. Often worn by a lord's bodyguards."
	icon_state = "samurai3"
	item_state = "samurai3"
	worn_state = "samurai3"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 65, arrow = 75, gun = 5, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	value = 45
	slowdown = 0.6

/obj/item/clothing/suit/armor/samurai/red
	name = "red samurai armor"
	desc = "A thick, leather armor, covering most of the body. Often worn by a lord's bodyguards."
	icon_state = "samurai1"
	item_state = "samurai1"
	worn_state = "samurai1"

/obj/item/clothing/suit/armor/samurai/blue
	name = "blue samurai armor"
	desc = "A thick, leather armor, covering most of the body. Often worn by a lord's bodyguards."
	icon_state = "samurai2"
	item_state = "samurai2"
	worn_state = "samurai2"

/obj/item/clothing/suit/armor/samurai/black
	name = "black samurai armor"
	desc = "A thick, leather armor, covering most of the body. Often worn by a lord's bodyguards."
	icon_state = "samurai4"
	item_state = "samurai4"
	worn_state = "samurai4"

/obj/item/clothing/suit/armor/samurai/lord
	name = "lord's samurai armor"
	desc = "A thick, leather armor, covering most of the body. Often worn by a lord."
	icon_state = "samurai_lord3"
	item_state = "samurai_lord3"
	worn_state = "samurai_lord3"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 65, arrow = 75, gun = 5, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	value = 45
	slowdown = 0.9

/obj/item/clothing/suit/armor/samurai/lord/red
	name = "lord's red samurai armor"
	desc = "A thick, leather armor, covering most of the body. Often worn by a lord."
	icon_state = "samurai_lord1"
	item_state = "samurai_lord1"
	worn_state = "samurai_lord1"

/obj/item/clothing/suit/armor/samurai/lord/blue
	name = "lord's blue samurai armor"
	desc = "A thick, leather armor, covering most of the body. Often worn by a lord."
	icon_state = "samurai_lord2"
	item_state = "samurai_lord2"
	worn_state = "samurai_lord2"

/obj/item/clothing/suit/armor/samurai/lord/black
	name = "lord's black samurai armor"
	desc = "A thick, leather armor, covering most of the body. Often worn by a lord."
	icon_state = "samurai_lord4"
	item_state = "samurai_lord4"
	worn_state = "samurai_lord4"

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

/obj/item/clothing/head/helmet/samurai
	name = "samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by feudal lords."
	icon_state = "samurai3"
	item_state = "samurai3"
	worn_state = "samurai3"
	body_parts_covered = HEAD
	armor = list(melee = 65, arrow = 55, gun = 5, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/samurai/guard
	name = "samurai helmet"
	desc = "A thick leather helmet of japanese origin."
	icon_state = "samurai_guard3"
	item_state = "samurai_guard3"
	worn_state = "samurai_guard3"
	body_parts_covered = HEAD
	armor = list(melee = 55, arrow = 55, gun = 5, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/samurai/guard/red
	name = "red samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by samurai."
	icon_state = "samurai_guard1"
	item_state = "samurai_guard1"
	worn_state = "samurai_guard1"

/obj/item/clothing/head/helmet/samurai/guard/blue
	name = "blue samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by samurai."
	icon_state = "samurai_guard2"
	item_state = "samurai_guard2"
	worn_state = "samurai_guard2"

/obj/item/clothing/head/helmet/samurai/guard/black
	name = "black samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by samurai."
	icon_state = "samurai_guard4"
	item_state = "samurai_guard4"
	worn_state = "samurai_guard4"

obj/item/clothing/head/helmet/samurai/red
	name = "red samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by feudal lords."
	icon_state = "samurai1"
	item_state = "samurai1"
	worn_state = "samurai1"

obj/item/clothing/head/helmet/samurai/blue
	name = "blue samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by feudal lords."
	icon_state = "samurai2"
	item_state = "samurai2"
	worn_state = "samurai2"

obj/item/clothing/head/helmet/samurai/black
	name = "black samurai helmet"
	desc = "A thick leather helmet of japanese origin. Typically worn by feudal lords."
	icon_state = "samurai4"
	item_state = "samurai4"
	worn_state = "samurai4"

/obj/item/clothing/mask/samurai
	name = "samurai mask"
	desc = "A mask of metal, worn by lords to protect their face."
	icon_state = "samurai1"
	item_state = "samurai1"
	worn_state = "samurai1"
	body_parts_covered = FACE|EYES
	flags_inv = 0
	w_class = 2
	armor = list(melee = 55, arrow = 45, gun = 10, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	restricts_view = 1

/obj/item/clothing/mask/samurai/red
	name = "red samurai mask"
	desc = "A mask of metal, worn by lords to protect their face."
	icon_state = "samurai2"
	item_state = "samurai2"
	worn_state = "samurai2"

/obj/item/clothing/mask/samurai/blue
	name = "blue samurai mask"
	desc = "A mask of metal, worn by lords to protect their face."
	icon_state = "samurai3"
	item_state = "samurai3"
	worn_state = "samurai3"