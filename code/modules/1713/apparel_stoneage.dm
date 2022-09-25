/*Index*/
/*  * - Stone-Age Uniforms
    * - Stone-Age Pelt Coats
    * - Indian-Carib Cultural Clothing
    * - Indian-Carib Cultural Accessories
    * - Bone Clothing, Armor & Accessories
    * - Stone-Age Masks
    * - Zulu
    * - Miscallaneous */

/* Stone-Age Uniforms*/

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

/obj/item/clothing/under/loincotton
	name = "cotton loincloth"
	desc = "An wrap of cotton loincloth, worn around the waist."
	icon_state = "loincloth1"
	item_state = "loincloth1"
	worn_state = "loincloth1"

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

/* Stone-Age Pelt Coats*/

/obj/item/clothing/suit/prehistoricfurcoat
	name = "primitive pelt coat"
	icon_state = "prehistoric_fur1"
	item_state = "prehistoric_fur1"
	worn_state = "prehistoric_fur1"
	desc = "A makeshift pelt coat made from fur skins, worn to protect early man from the elements."
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 15, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	var/specific = FALSE
	var/colorn = 2

/obj/item/clothing/suit/prehistoricfurcoat/brown
	name = "brown primitive pelt coat"
	desc = "A makeshift brown pelt coat made from fur skins, worn to protect early man from the elements."
	specific = TRUE
	colorn = 1

/obj/item/clothing/suit/prehistoricfurcoat/black
	name = "black primitive pelt coat"
	desc = "A makeshift black pelt coat made from fur skins, worn to protect early man from the elements."
	icon_state = "prehistoric_fur2"
	item_state = "prehistoric_fur2"
	worn_state = "prehistoric_fur2"
	specific = TRUE
	colorn = 2

/obj/item/clothing/suit/prehistoricfurcoat/white
	name = "white primitive pelt coat"
	desc = "A makeshift white pelt coat made from fur skins, worn to protect early man from the elements."
	icon_state = "prehistoric_fur3"
	item_state = "prehistoric_fur3"
	worn_state = "prehistoric_fur3"
	specific = TRUE
	colorn = 3

/obj/item/clothing/suit/prehistoricfurcoat/grey
	name = "grey primitive pelt coat"
	desc = "A makeshift grey pelt coat made from fur skins, worn to protect early man from the elements."
	icon_state = "prehistoric_fur4"
	item_state = "prehistoric_fur4"
	worn_state = "prehistoric_fur4"
	specific = TRUE
	colorn = 4

/obj/item/clothing/suit/prehistoricfurcoat/New()
	..()
	if (!specific)
		colorn = pick(1,2,3,4)
		icon_state = "prehistoric_fur[colorn]"
		item_state = "prehistoric_fur[colorn]"
		worn_state = "prehistoric_fur[colorn]"

/* Indian-Carib Cultural Clothing*/

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

/obj/item/clothing/under/indianhuge
	name = "big leopard pelt"
	desc = "A massive leopard pelt."
	icon_state = "giant_leopard_pelt"
	item_state = "giant_leopard_pelt"
	worn_state = "giant_leopard_pelt"

	/* Indian-Carib Cultural Accessories*/

/obj/item/clothing/accessory/armband/indian1
	name = "indian accessories"
	desc = "red face paint and indian necklaces."
	icon_state = "indian1"
	item_state = "indian1"

/obj/item/clothing/accessory/armband/indian2
	name = "indian accessories"
	desc = "gold indian necklaces."
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

/* Bone Clothing, Armor & Accessories*/

/obj/item/clothing/suit/storage/jacket/bonearmor
	name = "bone armor"
	desc = "A spooky armor, made of assorted bones."
	icon_state = "bonearmor"
	item_state = "bonearmor"
	worn_state = "bonearmor"
	armor = list(melee = 50, arrow = 15, gun = 0, energy = 0, bomb = 10, bio = 0, rad = FALSE)

/obj/item/clothing/head/helmet/bone
	name = "bone helmet"
	desc = "A helmet made of bones."
	icon_state = "bone_helmet"
	item_state = "bone_helmet"
	worn_state = "bone_helmet"
	armor = list(melee = 25, arrow = 15, gun = 10, energy = 16, bomb = 16, bio = 16, rad = FALSE)

/obj/item/clothing/suit/woodarmor
	name = "primitive wood armor"
	desc = "A wooden set of armor made of small planks held together by plant fiber ropes."
	icon_state = "wooden_chestarmor"
	item_state = "wooden_chestarmor"
	worn_state = "wooden_chestarmor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 15, arrow = 18, gun = FALSE, energy = 10, bomb = 4, bio = 20, rad = 15)

/obj/item/clothing/suit/hairbonearmor
	name = "primitive bone hair-pipe armor"
	desc = "A bone set of chest armor made of tightly packed small bones held together by plant fiber ropes."
	icon_state = "native_bonearmor"
	item_state = "native_bonearmor"
	worn_state = "native_bonearmor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 21, arrow = 13, gun = FALSE, energy = 8, bomb = 6, bio = 10, rad = 18)

/obj/item/clothing/accessory/armband/talisman
	name = "bone talisman"
	desc = "A bone talisman."
	icon_state = "talisman"
	item_state = "talisman"
	slot = "decor"
	var/religion = "none"

/* Stone-Age Masks*/

/obj/item/clothing/mask/skullmask
	name = "skull mask"
	desc = "A skull mask, used by shamans."
	icon_state = "skull_mask"
	item_state = "skull_mask"
	body_parts_covered = FACE|EYES
	armor = list(melee = 25, arrow = 10, gun = 0, energy = 0, bomb = 15, bio = 0, rad = FALSE)

/obj/item/clothing/mask/wooden
	name = "wooden mask"
	desc = "A tribal wooden mask."
	icon_state = "woodenmask"
	item_state = "woodenmask"
	body_parts_covered = FACE|EYES
	armor = list(melee = 15, arrow = 10, gun = 0, energy = 0, bomb = 10, bio = 0, rad = FALSE)
	flags_inv = BLOCKHAIR

/obj/item/clothing/mask/wooden/expressive
	name = "expressive wooden mask"
	desc = "A tribal wooden mask. This one has a grin transfixed on its face"
	icon_state = "bumba"
	item_state = "bumba"

/* Zulu*/

/obj/item/clothing/under/zulu_slene
	name = "slene cattle fur loincloth"
	desc = "A wrap of cattle fur tassles fashioned into a loincloth, often worn by the zulu people."
	icon_state = "zulu_slene"
	item_state = "zulu_slene"
	worn_state = "zulu_slene"

/obj/item/clothing/suit/zulu_mbata
	name = "mbata pelt vest"
	desc = "A shoulder vest made from big cat pelt, worn ceremonially & military dress by the zulu."
	icon_state = "zulu_mbata"
	item_state = "zulu_mbata"
	worn_state = "zulu_mbata"

/obj/item/clothing/head/zulu_umghele
	name = "umghele headband"
	desc = "A headband made from big cat pelt, worn ceremonially & military dress by the zulu."
	icon_state = "zulu_umghele"
	item_state = "zulu_umghele"
	worn_state = "zulu_umghele"

/* Pygmy */

/obj/item/clothing/under/indianchief/pygmy
	name = "pygmy chief clothing"
	desc = "An elaborate wrap of leather cloth, worn by tribal chiefs."
	icon_state = "indianchef"
	item_state = "indianchef"
	worn_state = "indiancgef"

/obj/item/clothing/under/indianshaman/pygmy
	name = "pygmy shaman clothing"
	desc = "A white cloth, worn around the waist, painted with religious symbols."
	icon_state = "indianshaman"
	item_state = "indianshaman"
	worn_state = "indianshaman"

/obj/item/clothing/accessory/armband/indian2/pygmy
	name = "indian accessories"
	desc = "gold indian necklaces."
	icon_state = "indian2"
	item_state = "indian2"

/obj/item/clothing/head/leaves
	name = "leaf head covering"
	desc = "A simple batch of leaves dampened down as rudimentary headwear."
	icon_state = "leaf_hat"
	item_state = "leaf_hat"
	worn_state = "leaf_hat"

/obj/item/clothing/head/leaves/crown
	name = "leaf crown"
	desc = "A crown assembled out of leaves, fastened with a leather strap."
	icon_state = "leaf_crown"
	item_state = "leaf_crown"
	worn_state = "leaf_crown"

/obj/item/clothing/head/leaves/star_platinum // jojo meme
	name = "star platinum headband"
	desc = "A spiritually infused headband that lets your hair flow wildly in the wind, you feel as if you could punch endlessly."
	icon_state = "star_platinum"
	item_state = "star_platinum"
	worn_state = "star_platinum"

/obj/item/clothing/mask/wooden/african
	name = "black african wooden mask"
	desc = "A african tribal wooden mask. Often used for ceremonial purposes"
	icon_state = "african1"
	item_state = "african1"
	flags_inv = BLOCKHAIR|BLOCKHEADHAIR

/* Miscallaneous*/

// These three seem misplaced, someone ought to revise the implementation & placement later.
/obj/item/clothing/mask/iogplate
	name = "face plate"
	desc = "A bulletproof face plate. Used to protect your pretty face."
	icon_state = "iogplate"
	item_state = "iogplate"
	body_parts_covered = FACE|EYES
	flags = CONDUCT
	armor = list(melee = 80, arrow = 70, gun = 90, energy = 20, bomb = 40, bio = 25, rad = FALSE)

/obj/item/clothing/mask/salamon
	name = "gold plated mask"
	desc = "A mask plated in gold. Looks expensive."
	icon_state = "salamon"
	item_state = "salamon"
	flags = CONDUCT
	body_parts_covered = FACE|EYES
	armor = list(melee = 5, arrow = 14, gun = 10, energy = 20, bomb = 10, bio = 10, rad = FALSE)

/////////////////////////////

/obj/item/clothing/head/chief_hat
	name = "chief hat"
	desc = "A hat made with with feathers. Worn by tribal leaders."
	icon_state = "chief_hat"
	item_state = "chief_hat"
	flags_inv = BLOCKHEADHAIR

/obj/item/weapon/storage/backpack/quiver
	name = "quiver"
	desc = "The best way to carry a bow and arrows."
	icon = 'icons/obj/storage.dmi'
	icon_state = "quiver"
	item_state = "quiver"
	slot_flags = SLOT_BACK | SLOT_BELT

/obj/item/weapon/storage/backpack/quiver/New()
		..()
		can_hold = list(/obj/item/ammo_casing/bolt, /obj/item/ammo_casing/arrow, /obj/item/weapon/gun/projectile/bow, /obj/item/weapon/material/pilum)

/obj/item/weapon/storage/backpack/quiver/full/New()
	..()
	can_hold = list(/obj/item/ammo_casing/bolt, /obj/item/ammo_casing/arrow, /obj/item/weapon/gun/projectile/bow, /obj/item/weapon/material/pilum)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)
	new /obj/item/ammo_casing/arrow/bronze(src)

/obj/item/weapon/storage/backpack/quiver/medieval/New()
	..()
	can_hold = list(/obj/item/ammo_casing/bolt, /obj/item/ammo_casing/arrow, /obj/item/weapon/gun/projectile/bow, /obj/item/weapon/material/pilum)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)
	new /obj/item/ammo_casing/arrow/iron(src)

/obj/item/weapon/storage/backpack/quiver/crossbow/New()
	..()
	can_hold = list(/obj/item/ammo_casing/bolt, /obj/item/ammo_casing/arrow, /obj/item/weapon/gun/projectile/bow, /obj/item/weapon/material/pilum)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)
	new /obj/item/ammo_casing/bolt/iron(src)

/obj/item/weapon/storage/backpack/quiver/poison/New()
	..()
	new /obj/item/ammo_casing/arrow/vial/poisonous(src)
	new /obj/item/ammo_casing/arrow/vial/poisonous(src)
	new /obj/item/ammo_casing/arrow/vial/poisonous(src)
	new /obj/item/ammo_casing/arrow/vial/poisonous(src)
	new /obj/item/ammo_casing/arrow/vial/poisonous(src)
	new /obj/item/ammo_casing/arrow/vial/poisonous(src)
	new /obj/item/ammo_casing/arrow/vial/poisonous(src)
	new /obj/item/ammo_casing/arrow/vial/poisonous(src)
	new /obj/item/ammo_casing/arrow/vial/poisonous(src)
	new /obj/item/ammo_casing/arrow/vial/poisonous(src)

/obj/item/clothing/under/leaves_skirt/au_naturel
	name = "au naturel leaf covering"
	desc = "leaves arranged on the body to preserve modesty"
	icon_state = "adam"
	item_state = "adam"
	worn_state = "adam"

/obj/item/clothing/under/leaves_skirt/au_naturel/eve
	icon_state = "eve"
	item_state = "eve"
	worn_state = "eve"

/obj/item/weapon/storage/backpack/quiver/modern/New()
	..()
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)
	new /obj/item/ammo_casing/arrow/modern(src)