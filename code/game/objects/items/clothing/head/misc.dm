/obj/item/clothing/head/hairflower
	name = "hair flower pin"
	icon_state = "hairflower"
	desc = "Smells nice."
	slot_flags = SLOT_HEAD | SLOT_EARS
	body_parts_covered = FALSE

/obj/item/clothing/head/powdered_wig
	name = "powdered wig"
	desc = "A powdered wig."
	icon_state = "pwig"
	item_state = "pwig"

/obj/item/clothing/head/that
	name = "top-hat"
	desc = "It's an amish looking hat."
	icon_state = "tophat"
	item_state = "tophat"
	siemens_coefficient = 0.9
	body_parts_covered = FALSE


/obj/item/clothing/head/plaguedoctorhat
	name = "plague doctor's hat"
	desc = "These were once used by Plague doctors. They're pretty much useless."
	icon_state = "plaguedoctor"
	permeability_coefficient = 0.01
	siemens_coefficient = 0.9
	body_parts_covered = FALSE

/obj/item/clothing/head/pirate
	name = "pirate hat"
	desc = "Yarr."
	icon_state = "pirate"
	body_parts_covered = FALSE

/obj/item/clothing/head/bandana
	name = "pirate bandana"
	desc = "Yarr."
	icon_state = "bandana"


//stylish bs12 hats

/obj/item/clothing/head/beaverhat
	name = "beaver hat"
	icon_state = "beaver_hat"
	desc = "Soft felt makes this hat both comfortable and elegant."

/obj/item/clothing/head/feathertrilby
	name = "feather trilby"
	icon_state = "feather_trilby"
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
	siemens_coefficient = 2.0 //why is it so conductive?!
	body_parts_covered = FALSE

/obj/item/clothing/head/orangebandana //themij: Taryn Kifer
	name = "orange bandana"
	desc = "An orange piece of cloth, worn on the head."
	icon_state = "orange_bandana"
	body_parts_covered = FALSE