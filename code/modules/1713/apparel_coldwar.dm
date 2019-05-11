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

/obj/item/clothing/head/helmet/modern/ushelmet/sgt
	name = "M1 helmet (sergeant)"
	desc = "A typical US Army helmet. With sergeant markings."
	icon_state = "ushelmet_sgt"
	item_state = "ushelmet_sgt"
	worn_state = "ushelmet_sgt"

/obj/item/clothing/head/helmet/modern/ushelmet/lt
	name = "M1 helmet (lieutenant)"
	desc = "A typical US Army helmet. With lieutenant markings."
	icon_state = "ushelmet_lt"
	item_state = "ushelmet_lt"
	worn_state = "ushelmet_lt"

/obj/item/clothing/head/helmet/modern/ushelmet/camo
	name = "M1 camo helmet"
	desc = "A typical US Army helmet. With a woodland camo cover."
	icon_state = "ushelmet_camo"
	item_state = "ushelmet_camo"
	worn_state = "ushelmet_camo"

/obj/item/clothing/head/helmet/modern/ushelmet/camo/accessory/New()
	..()
	var/numb = rand(0,1)
	var/list/optlist = list("card","bullets","cigpack","peace","text")
	if (numb > 0)
		for (var/i = 1, i <= numb, i++)
			var/chosen = pick(optlist)
			attachments += chosen
			optlist -= chosen


/obj/item/clothing/head/helmet/modern/ushelmet/late
	name = "M1 helmet"
	desc = "A typical US Army helmet."
	icon_state = "ushelmet2"
	item_state = "ushelmet2"
	worn_state = "ushelmet2"
/obj/item/clothing/head/helmet/modern/ushelmet/medical
	name = "M1 medical helmet"
	desc = "A typical US Army helmet, with a red cross on a white background."
	icon_state = "ushelmet_medical"
	item_state = "ushelmet_medical"
	worn_state = "ushelmet_medical"

/obj/item/clothing/head/helmet/modern/ushelmet/late/New()
	..()
	var/numb = rand(0,2)
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


/obj/item/clothing/head/jungle_hat
	name = "green jungle hat"
	desc = "A wide brim, soft jungle hat."
	icon_state = "jungle_hat_green"
	item_state = "jungle_hat_green"
	body_parts_covered = HEAD

/obj/item/clothing/head/jungle_hat/khaki
	name = "khaki jungle hat"
	icon_state = "jungle_hat_khaki"
	item_state = "jungle_hat_khaki"

/obj/item/clothing/accessory/armband/khan_ran_scarf
	name = "khan ran scarf"
	desc = "A traditional Mekong Delta white-and-grey chekered scarf."
	icon_state = "khan_ran_scarf"
	item_state = "khan_ran_scarf"
	slot = "decor"