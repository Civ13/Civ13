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

/obj/item/clothing/under/us_uni
	name = "olive drab uniform"
	desc = "The standard US Army uniform of the mid-20th century."
	icon_state = "us_uni"
	item_state = "us_uni"
	worn_state = "us_uni"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_camo
	name = "woodland camo uniform"
	desc = "The standard US Army camo uniform the mid-20th century."
	icon_state = "us_camo"
	item_state = "us_camo"
	worn_state = "us_camo"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_greentrousers
	name = "olive drab trousers"
	desc = "The standard US olive drab uniform trousers."
	icon_state = "us_greentrousers"
	item_state = "us_greentrousers"
	worn_state = "us_greentrousers"
	body_parts_covered = LOWER_TORSO|LEGS

/obj/item/clothing/under/us_uni/us_lightuni
	name = "olive drab shirt and trousers"
	desc = "A light version of the US Army olive drab uniform."
	icon_state = "us_lightuni"
	item_state = "us_lightuni"
	worn_state = "us_lightuni"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS

/obj/item/clothing/under/us_uni/us_lightuni2
	name = "woodland camo trousers and olive drab shirt"
	desc = "A light version of the US Army woodland camo trousers and a olive drab shirt."
	icon_state = "us_lightuni2"
	item_state = "us_lightuni2"
	worn_state = "us_lightuni2"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS

/obj/item/clothing/suit/storage/us_jacket
	name = "olive drab jacket"
	desc = "The standard US Army olive drab jacket of the mid-20th century."
	icon_state = "us_jacket"
	item_state = "us_jacket"
	worn_state = "us_jacket"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS

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

/obj/item/clothing/accessory/storage/webbing/us_vest
	name = "US Army webbing"
	desc = "A large webbing with several pockets."
	icon_state = "us_vest"
	item_state = "us_vest"
	slots = 10
	New()
		..()
		hold.can_hold = list(/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade, /obj/item/weapon/attachment/bayonet,/obj/item/weapon/shovel/trench,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/weapon/reagent_containers/food/snacks/MRE,)

/obj/item/clothing/suit/storage/ghillie
	name = "ghillie suit"
	desc = "A camo ghillie suit."
	icon_state = "ghillie"
	item_state = "ghillie"
	worn_state = "ghillie"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|HANDS|FEET
	armor = list(melee = 12, arrow = 5, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 100

/obj/item/clothing/head/ghillie
	name = "ghillie headcover"
	desc = "An headcover for a ghillie suit."
	icon_state = "ghillie"
	item_state = "ghillie"
	body_parts_covered = HEAD