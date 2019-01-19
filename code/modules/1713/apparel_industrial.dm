///////////////////INDUSTRIAL AGE APPAREL (LATE 1850's)///////////////////
/obj/item/clothing/head/bowler_hat
	name = "bowler hat"
	desc = "A round bowler hat."
	icon_state = "bowler_hat"
	item_state = "bowler_hat"
/obj/item/clothing/head/cowboyhat
	name = "cowboy hat"
	desc = "a curved leather hat."
	icon_state = "cowboy"
	item_state = "cowboy"
/obj/item/clothing/head/cowboyhat2
	name = "dark cowboy hat"
	desc = "a dark, curved leather hat."
	icon_state = "cowboy2"
	item_state = "cowboy2"
/obj/item/clothing/head/sombrero
	name = "cowboy hat"
	desc = "ay caranba!"
	icon_state = "sombrero"
	item_state = "sombrero"

/obj/item/clothing/head/rice_hat
	name = "rice hat"
	desc = "Asian style."
	icon_state = "rice_hat"
	item_state = "rice_hat"

/obj/item/clothing/accessory/armband/blue_scarf
	name = "blue scarf"
	desc = "A light cotton scarf, in blue."
	icon_state = "british_scarf"
	item_state = "british_scarf"
	slot = "decor"

/obj/item/clothing/accessory/armband/grey_scarf
	name = "grey scarf"
	desc = "A light cotton scarf, in grey."
	icon_state = "grey_scarf"
	item_state = "grey_scarf"
	slot = "decor"

/obj/item/clothing/accessory/armband/red_scarf
	name = "red scarf"
	desc = "A light cotton scarf, in red."
	icon_state = "red_scarf"
	item_state = "red_scarf"
	slot = "decor"

/obj/item/clothing/under/industrial1
	name = "pioneer outfit"
	desc = "A red shirt with leather trousers, commonly used among pioneers."
	icon_state = "pioneer_outfit"
	item_state = "pioneer_outfit"
	worn_state = "pioneer_outfit"

/obj/item/clothing/under/industrial2
	name = "rancher outfit"
	desc = "A blue shirt with light beige trousers."
	icon_state = "rancher_outfit"
	item_state = "rancher_outfit"
	worn_state = "rancher_outfit"

/obj/item/clothing/under/industrial3
	name = "cowboy outfit"
	desc = "A white shirt with leather trousers, worn among cowboys and ranchers."
	icon_state = "cowboy_outfit"
	item_state = "cowboy_outfit"
	worn_state = "cowboy_outfit"

/obj/item/clothing/under/industrial4
	name = "checkered outfit"
	desc = "A red-and-white checkered shirt and light beige trousers."
	icon_state = "checkered_outfit"
	item_state = "checkered_outfit"
	worn_state = "checkered_outfit"

/obj/item/clothing/under/industrial5
	name = "worker outfit"
	desc = "A navy blue shirt with denim trousers."
	icon_state = "worker_outfit"
	item_state = "worker_outfit"
	worn_state = "worker_outfit"

/obj/item/clothing/suit/storage/jacket/leatherovercoat1
	name = "leather overcoat"
	desc = "A long leather overcoat."
	icon_state = "leather_overcoat"
	item_state = "leather_overcoat"
	worn_state = "leather_overcoat"

/obj/item/clothing/suit/storage/jacket/leatherovercoat2
	name = "black leather overcoat"
	desc = "A long black leather overcoat."
	icon_state = "black_leather_overcoat"
	item_state = "black_leather_overcoat"
	worn_state = "black_leather_overcoat"

/obj/item/clothing/suit/storage/jacket/blackvest
	name = "black vest"
	desc = "A simple black vest."
	icon_state = "blackvest"
	item_state = "blackvest"
	worn_state = "blackvest"

/obj/item/clothing/suit/storage/jacket/olivevest
	name = "olive vest"
	desc = "A simple olive vest."
	icon_state = "olivevest"
	item_state = "olivevest"
	worn_state = "olivevest"

/obj/item/clothing/suit/storage/jacket/bluevest
	name = "blue vest"
	desc = "A simple blue vest."
	icon_state = "bluevest"
	item_state = "bluevest"
	worn_state = "bluevest"

/obj/item/clothing/shoes/riding1
	name = "black riding boots"
	desc = "Black leather boots with spurs, perfect for riding."
	icon_state = "cowboyboots1"
	item_state = "cowboyboots1"
	worn_state = "cowboyboots1"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 70, bullet = 40, laser = 50,energy = 25, bomb = 50, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6

/obj/item/clothing/shoes/riding2
	name = "leather riding boots"
	desc = "Leather boots with spurs, perfect for riding."
	icon_state = "cowboyboots2"
	item_state = "cowboyboots2"
	worn_state = "cowboyboots2"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 70, bullet = 40, laser = 50,energy = 25, bomb = 50, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6


/obj/item/clothing/suit/storage/coat/kozhanka
	name = "fur coat"
	desc = "A thick fur coat, great for the winter."
	icon_state = "kozhanka"
	item_state = "kozhanka"
	worn_state = "kozhanka"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, bullet = 0, laser = 10,energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 65
	var/colorn = 1
	var/specific = FALSE
	flags_inv = BLOCKHEADHAIR
	specific = TRUE
/obj/item/clothing/suit/storage/coat/kozhanka/New()
	..()
	if (!specific)
		colorn = pick(1,2,)
		icon_state = "kozhanka[colorn]"
		item_state = "kozhanka[colorn]"
		worn_state = "kozhanka[colorn]"

/obj/item/clothing/suit/storage/coat/kozhanka/verb/toggle_hood()
	set category = null
	set src in usr
	set name = "Toggle Hood"
	if (hood)
		icon_state = "kozhanka[colorn]"
		item_state = "kozhanka[colorn]"
		worn_state = "kozhanka[colorn]"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
		item_state_slots["slot_wear_suit"] = "kozhanka[colorn]"
		usr << "<span class = 'danger'>You take off your coat's hood.</span>"
		update_icon()
		hood = FALSE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return
	else if (!hood)
		icon_state = "kozhanka[colorn]h"
		item_state = "kozhanka[colorn]h"
		worn_state = "kozhanka[colorn]h"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|HEAD
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT|HEAD
		item_state_slots["slot_wear_suit"] = "kozhanka[colorn]h"
		usr << "<span class = 'danger'>You cover your head with your coat's hood.</span>"
		update_icon()
		hood = TRUE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return

/obj/item/clothing/suit/storage/coat/kozhanka/white
	name = "white fur coat"
	desc = "A thick white fur coat, great for the winter."
	icon_state = "kozhanka_w"
	item_state = "kozhanka_w"
	worn_state = "kozhanka_w"
	specific = TRUE
	colorn = 2