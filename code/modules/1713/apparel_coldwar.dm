/obj/item/clothing/suit/storage/coat/modern_winter
	name = "Dark Green Winter Coat"
	desc = "An army-style coat, in olive drab."
	icon_state = "modern_winter"
	item_state = "modern_winter"
	worn_state = "modern_winter"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 12, arrow = 5, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 75

/obj/item/clothing/under/modern_camo
	name = "woodland camo uniform"
	desc = "A modern woodland camo uniform."
	icon_state = "modern_camo"
	item_state = "modern_camo"
	worn_state = "modern_camo"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/vietcong
	name = "Vietcong uniform"
	desc = "A black uniform of the Vietcong."
	icon_state = "vietcong"
	item_state = "vietcong"
	worn_state = "vietcong"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/head
	var/list/attachments = list()

/obj/item/clothing/head/helmet/modern/ushelmet
	name = "M1 helmet"
	desc = "A typical US Army helmet."
	icon_state = "ushelmet"
	item_state = "ushelmet"
	worn_state = "ushelmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 15, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/ushelmet/late
	name = "M1 helmet"
	desc = "A typical US Army helmet."
	icon_state = "ushelmet2"
	item_state = "ushelmet2"
	worn_state = "ushelmet2"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 15, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/ushelmet/late/New()
	..()
	var/numb = rand(0,3)
	var/list/optlist = list("card","bullets","cigpack","peace","text")
	if (numb > 0)
		for (var/i = 1, i <= numb, i++)
			var/chosen = pick(optlist)
			attachments += chosen
			optlist -= chosen
