
/////////indian/prehistoric stuff/////////
/obj/item/clothing/under/loinleather
	name = "leather loincloth"
	desc = "A wrap of leather cloth, worn around the waist."
	icon_state = "leatherloincloth1"
	item_state = "leatherloincloth1"
	worn_state = "leatherloincloth1"

/obj/item/clothing/under/loinleather/New()
	..()
	var/randcloth = pick(1,2,3,4)
	icon_state = "leatherloincloth[randcloth]"
	item_state = "leatherloincloth[randcloth]"
	worn_state = "leatherloincloth[randcloth]"

/obj/item/clothing/under/leaves_skirt
	name = "leaf skirt"
	desc = "A wrap of leaves, worn around the waist."
	icon_state = "leaves_skirt"
	item_state = "leaves_skirt"
	worn_state = "leaves_skirt"

/obj/item/clothing/under/leaves_skirt/long
	name = "long leaf skirt"
	icon_state = "leaves_skirt_long"
	item_state = "leaves_skirt_long"
	worn_state = "leaves_skirt_long"

/obj/item/clothing/under/indian1
	name = "short leather loincloth"
	desc = "A wrap of leather cloth, worn around the waist."
	icon_state = "indian1"
	item_state = "indian1"
	worn_state = "indian1"

/obj/item/clothing/under/indian2
	name = "long leather loincloth"
	desc = "A wrap of leather cloth, worn around the waist."
	icon_state = "indian2"
	item_state = "indian2"
	worn_state = "indian2"

/obj/item/clothing/under/indian3
	name = "covering leather loincloth"
	desc = "A wrap of leather cloth, worn around the waist and the chest."
	icon_state = "indian3"
	item_state = "indian3"
	worn_state = "indian3"

/obj/item/clothing/under/loincotton
	name = "cotton loincloth"
	desc = "An wrap of cotton loincloth, worn around the waist."
	icon_state = "loincloth1"
	item_state = "loincloth1"
	worn_state = "loincloth1"

/obj/item/clothing/under/indianchief
	name = "indian chief clothing"
	desc = "An elaborate wrap of leather cloth, worn by tribal chiefs."
	icon_state = "indianchef"
	item_state = "indianchef"
	worn_state = "indiancgef"

/obj/item/clothing/under/indianshaman
	name = "indian shaman clothing"
	desc = "A white cloth, worn around the waist, painted with religious symbols."
	icon_state = "indianshaman"
	item_state = "indianshaman"
	worn_state = "indianshaman"

/obj/item/clothing/suit/storage/jacket/bonearmor
	name = "bone armor"
	desc = "A spooky armor, made of human bones."
	icon_state = "bonearmor"
	item_state = "bonearmor"
	worn_state = "bonearmor"
	armor = list(melee = 50, arrow = 15, gun = 0, energy = 0, bomb = 10, bio = 0, rad = FALSE)

/obj/item/clothing/under/indianhuge
	name = "big leopard pelt"
	desc = "A massive leopard pelt."
	icon_state = "giant_leopard_pelt"
	item_state = "giant_leopard_pelt"
	worn_state = "giant_leopard_pelt"

/obj/item/clothing/accessory/armband/talisman
	name = "bone talisman"
	desc = "A bone talisman."
	icon_state = "talisman"
	item_state = "talisman"
	slot = "decor"
	var/religion = "none"

/obj/item/clothing/accessory/armband/indian1
	name = "indian acessories"
	desc = "red face paint and indian necklaces."
	icon_state = "indian1"
	item_state = "indian1"

/obj/item/clothing/accessory/armband/indian2
	name = "indian acessories"
	desc = "Gold indian necklaces."
	icon_state = "indian2"
	item_state = "indian2"

/obj/item/clothing/accessory/armband/indianshaman
	name = "indian shaman bodypaint"
	desc = "Red and white bodypaint, worn by native shamans."
	icon_state = "indianshaman"
	item_state = "indianshaman"

/obj/item/clothing/accessory/armband/indianr
	name = "red indian acessories"
	desc = "red face paint and indian necklaces."
	icon_state = "indianr"
	item_state = "indianr"

/obj/item/clothing/accessory/armband/indiang
	name = "green indian acessories"
	desc = "green face paint and indian necklaces."
	icon_state = "indiang"
	item_state = "indiang"

/obj/item/clothing/accessory/armband/indianb
	name = "blue indian acessories"
	desc = "blue face paint and indian necklaces."
	icon_state = "indianb"
	item_state = "indianb"

/obj/item/clothing/accessory/armband/indiany
	name = "yellow indian acessories"
	desc = "yellow face paint and indian necklaces."
	icon_state = "indiany"
	item_state = "indiany"

/obj/item/clothing/accessory/armband/indianw
	name = "white indian acessories"
	desc = "white face paint and indian necklaces."
	icon_state = "indianw"
	item_state = "indianw"

/obj/item/clothing/accessory/armband/indianbl
	name = "black indian acessories"
	desc = "black face paint and indian necklaces."
	icon_state = "indianbl"
	item_state = "indianbl"

/obj/item/clothing/mask/skullmask
	name = "skull mask"
	desc = "A skull mask, used by shamans."
	icon_state = "skull_mask"
	item_state = "skull_mask"
	body_parts_covered = FACE|EYES
	armor = list(melee = 25, arrow = 10, gun = 0, energy = 0, bomb = 15, bio = 0, rad = FALSE)

/obj/item/clothing/mask/iogplate
	name = "face plate"
	desc = "A bulletproof face plate. Used to protect your pretty face."
	icon_state = "iogplate"
	item_state = "iogplate"
	body_parts_covered = FACE|EYES
	armor = list(melee = 80, arrow = 70, gun = 90, energy = 20, bomb = 40, bio = 25, rad = FALSE)

/obj/item/clothing/head/helmet/bone
	name = "bone helmet"
	desc = "A helmet made of bones."
	icon_state = "bone_helmet"
	item_state = "bone_helmet"
	worn_state = "bone_helmet"
	armor = list(melee = 25, arrow = 15, gun = 10, energy = 16, bomb = 16, bio = 16, rad = FALSE)

/obj/item/clothing/mask/wooden
	name = "wooden mask"
	desc = "A tribal wooden mask."
	icon_state = "woodenmask"
	item_state = "woodenmask"
	body_parts_covered = FACE|EYES
	armor = list(melee = 15, arrow = 10, gun = 0, energy = 0, bomb = 10, bio = 0, rad = FALSE)

/obj/item/clothing/mask/clown
	name = "clown mask"
	desc = "A mask used around the world by clowns."
	icon_state = "clownmask"
	item_state = "clownmask"
	body_parts_covered = FACE|EYES
	armor = list(melee = 5, arrow = 5, gun = 1, energy = 0, bomb = 5, bio = 0, rad = FALSE)

/obj/item/clothing/mask/chitinmask
	name = "chitin mask"
	desc = "A mask made from insect chitin."
	icon_state = "chitin_mask"
	item_state = "chitin_mask"
	body_parts_covered = FACE|EYES
	armor = list(melee = 19, arrow = 9, gun = 0, energy = 0, bomb = 12, bio = 0, rad = FALSE)

/obj/item/clothing/head/helmet/chitin
	name = "gold crown"
	desc = "A crown of gold. Fancy."
	icon_state = "chitin_helmet"
	item_state = "chitin_helmet"
	worn_state = "chitin_helmet"
	armor = list(melee = 30, arrow = 19, gun = 12, energy = 18, bomb = 18, bio = 19, rad = FALSE)

/obj/item/clothing/head/chief_hat
	name = "Chief hat"
	desc = "A hat made with withe feathers. Worn by tribal leaders."
	icon_state = "chief_hat"
	item_state = "chief_hat"
	flags_inv = BLOCKHEADHAIR