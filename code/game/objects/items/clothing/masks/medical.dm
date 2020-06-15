/obj/item/clothing/mask/muzzle
	name = "muzzle"
	desc = "To stop that awful noise."
	icon_state = "muzzle"
	item_state = "muzzle"
	body_parts_covered = FACE
	w_class = 2
	gas_transfer_coefficient = 0.90
	voicechange = TRUE
	heat_protection = 0

/obj/item/clothing/mask/muzzle/tape
	name = "length of tape"
	desc = "It's a robust DIY muzzle!"
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "tape_cross"
	item_state = null
	w_class = TRUE

/obj/item/clothing/mask/muzzle/New()
	..()
	say_messages = list("Mmfph!", "Mmmf mrrfff!", "Mmmf mnnf!")
	say_verbs = list("mumbles", "says")

// Clumsy folks can't take the mask off themselves.
/obj/item/clothing/mask/muzzle/attack_hand(mob/user as mob)
	if (user.wear_mask == src && !user.IsAdvancedToolUser())
		return FALSE
	..()

/obj/item/clothing/mask/plaguedoctor //ye olde gasmask for quacks.
	name = "plague doctor's mask"
	desc = "A covid shaped mask stuffed with herbs to better protect against malanges & plagues."
	icon_state = "plaguedoctor"
	item_state = "plaguedoctor"
	flags_inv = HIDEFACE
	body_parts_covered = FACE|EYES
	w_class = 2
	blocks_scope = TRUE
	armor = list(melee = 15, arrow = 15, gun = FALSE, energy = 15, bomb = 25, bio = 45, rad = FALSE)
	restricts_view = 1

/obj/item/clothing/mask/sterile
	name = "sterile mask"
	desc = "A thin surgical mask, worn by medical professionals to stop the spread of disease or transmission."
	icon_state = "sterile"
	item_state = "sterile"
	body_parts_covered = FACE
	armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = FALSE, bomb = FALSE, bio = 75, rad = FALSE)
	w_class = 1