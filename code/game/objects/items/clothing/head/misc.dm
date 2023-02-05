
/obj/item/clothing/head/hairflower
	name = "hair flower pin"
	icon_state = "hairflower"
	desc = "Smells nice."
	slot_flags = SLOT_HEAD | SLOT_EARS
	body_parts_covered = FALSE
	heat_protection = 0

/obj/item/clothing/head/powdered_wig
	name = "powdered wig"
	desc = "A powdered wig."
	icon_state = "pwig"
	item_state = "pwig"

/obj/item/clothing/head/tophat
	name = "top-hat"
	desc = "It's an amish looking hat."
	icon_state = "tophat"
	item_state = "tophat"
	siemens_coefficient = 0.9
	body_parts_covered = FALSE

/obj/item/clothing/head/pimphat
	name = "pimp-hat"
	desc = "It's a gangster hat."
	icon_state = "pimp_hat"
	item_state = "pimp_hat"
	siemens_coefficient = 0.9
	body_parts_covered = FALSE

/obj/item/clothing/head/peakyblinder
	name = "flat cap"
	desc = "It's an common cap."
	icon_state = "peakyblindercap"
	item_state = "peakyblindercap"
	siemens_coefficient = 2.0
	body_parts_covered = FALSE

/obj/item/clothing/head/peakyblinderblade
	name = "flat cap"
	desc = "It's an common cap. Has razor blades in it."
	icon_state = "peakyblindercap"
	item_state = "peakyblindercap"
	siemens_coefficient = 2.0
	body_parts_covered = FALSE
	force = WEAPON_FORCE_PAINFUL
	flags = CONDUCT

/obj/item/clothing/head/pirate
	name = "pirate hat"
	desc = "Yarr."
	icon_state = "pirate"
	body_parts_covered = FALSE

/obj/item/clothing/head/bandana
	name = "pirate bandana"
	desc = "Yarr."
	icon_state = "bandana"

/obj/item/clothing/head/olivebandana
	name = "olive bandana"
	desc = "An olive bandana."
	icon_state = "bandana_olive"
	item_state = "bandana_olive"

//stylish bs12 hats

/obj/item/clothing/head/beaverhat
	name = "beaver hat"
	icon_state = "beaver_hat"
	desc = "Soft felt makes this hat both comfortable and elegant."

/obj/item/clothing/head/feathertrilby
	name = "feather trilby"
	icon_state = "feathered_hat"
	desc = "A sharp, stylish hat with a feather."

/obj/item/clothing/head/fez
	name = "fez"
	icon_state = "fez"
	desc = "You should wear a fez. Fezzes are cool."

//end bs12 hats

/obj/item/clothing/head/bearpelt
	name = "bear pelt hat"
	desc = "Fuzzy."
	icon_state = "bearpelt"
	item_state = "bearpelt"
	worn_state = "bearpelt"
	flags_inv = BLOCKHAIR
	siemens_coefficient = 0.7
	ripable = FALSE

/obj/item/clothing/head/bearpelt/black
	name = "black bear pelt hat"
	icon_state = "bearpelt"
	item_state = "bearpelt"
	worn_state = "bearpelt"

/obj/item/clothing/head/bearpelt/brown
	name = "brown bear pelt hat"
	icon_state = "brownbearpelt"
	item_state = "brownbearpelt"
	worn_state = "brownbearpelt"

/obj/item/clothing/head/bearpelt/white
	name = "polar bear pelt hat"
	icon_state = "whitebearpelt"
	item_state = "whitebearpelt"
	worn_state = "whitebearpelt"

/obj/item/clothing/head/philosopher_wig
	name = "natural philosopher's wig"
	desc = "A stylish monstrosity unearthed from Earth's Renaissance period. With this most distinguish'd wig, you'll be ready for your next soiree!"
	icon_state = "philosopher_wig"
	item_state_slots = list(
		slot_l_hand_str = "pwig",
		slot_r_hand_str = "pwig",
		)
	flags_inv = BLOCKHAIR
	body_parts_covered = FALSE

/obj/item/clothing/head/orangebandana //themij: Taryn Kifer
	name = "orange bandana"
	desc = "An orange piece of cloth, worn on the head."
	icon_state = "orange_bandana"
	body_parts_covered = FALSE

