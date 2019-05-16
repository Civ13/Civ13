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
	name = "olive drab uniform with rolled sleeves"
	desc = "A rolled-sleeves version of the US Army olive drab uniform."
	icon_state = "us_uni_rolled"
	item_state = "us_uni_rolled"
	worn_state = "us_uni_rolled"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS

/obj/item/clothing/under/us_uni/us_lightuni2
	name = "olive drab trousers and white undershirt"
	desc = "A light version of the US Army olive drab trousers and the service white undershirt."
	icon_state = "us_lightuni2"
	item_state = "us_lightuni2"
	worn_state = "us_lightuni2"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS

/obj/item/clothing/under/us_uni/us_tigerstripes
	name = "tigerstripes camo uniform"
	desc = "A camo uniform in the tigerstripes pattern."
	icon_state = "us_camo_tigerstripes"
	item_state = "us_camo_tigerstripes"
	worn_state = "us_camo_tigerstripes"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/head/commando_bandana
	name = "olive drab bandana"
	desc = "An olive drab coloured bandana."
	icon_state = "commando_bandana"
	item_state = "commando_bandana"
	body_parts_covered = HEAD

/obj/item/clothing/accessory/storage/webbing/light
	name = "light webbing"
	desc = "a light webbing, with lower capacity but permitting fast movement."
	slots = 3
	icon_state = "german_vest"
	item_state = "german_vest"
	New()
		..()
		hold.can_hold = list(/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,)
/obj/item/clothing/mask/facecamo
	name = "woodlands face camo"
	desc = "Face painting in woodland camo pattern."
	icon_state = "painting_woodland"
	item_state = "painting_woodland"
	blocks_scope = FALSE
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
	desc = "A large webbing with several small pockets."
	icon_state = "us_vest"
	item_state = "us_vest"
	slots = 5
	New()
		..()
		hold.can_hold = list(/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,)

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

/obj/item/clothing/accessory/armor/coldwar
	icon = 'icons/obj/clothing/ties.dmi'
/obj/item/clothing/accessory/armor/coldwar/get_mob_overlay()
	if (!mob_overlay)
		var/tmp_icon_state = "[overlay_state? "[overlay_state]" : "[icon_state]"]"
		if (icon_override)
			if ("[tmp_icon_state]_mob" in icon_states(icon_override))
				tmp_icon_state = "[tmp_icon_state]_mob"
			mob_overlay = image("icon" = icon_override, "icon_state" = "[tmp_icon_state]")
		else
			mob_overlay = image("icon" = 'icons/mob/ties.dmi', "icon_state" = "[tmp_icon_state]")
	return mob_overlay
/obj/item/clothing/accessory/armor/coldwar/flakjacket
	name = "M-1952 Flak Jacket"
	desc = "Wearable armor meant to protect against shrapnel and light hits. Won't do much against large caliber weapons."
	icon_state = "flakjacket"
	item_state = "flakjacket"
	worn_state = "flakjacket"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 75, gun = 15, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	value = 60
	slowdown = 0.2

/obj/item/clothing/accessory/armor/coldwar/flakjacket/m1969
	name = "M-1969 Flak Jacket"
	desc = "Wearable armor with neck protection meant to protect against shrapnel and light hits. Won't do much against large caliber weapons."
	icon_state = "flakjacket1969"
	item_state = "flakjacket1969"
	worn_state = "flakjacket1969"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 65, arrow = 75, gun = 20, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	value = 60
	slowdown = 0.2

/obj/item/weapon/storage/belt/largepouches/green/m60
/obj/item/weapon/storage/belt/largepouches/green/m60/New()
	..()
	new/obj/item/ammo_magazine/b762(src)

/obj/item/weapon/storage/belt/smallpouches/vc_officer
/obj/item/weapon/storage/belt/smallpouches/vc_officer/New()
	..()
	new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new /obj/item/weapon/key/vietnamese(src)
	new /obj/item/weapon/whistle(src)

/obj/item/clothing/accessory/armor/coldwar/plates
	var/slots = 2
	var/obj/item/weapon/storage/internal/hold

/obj/item/clothing/accessory/armor/coldwar/plates/New()
	..()
	hold = new/obj/item/weapon/storage/internal(src)
	hold.storage_slots = slots
	hold.can_hold = list(/obj/item/weapon/armorplates,)

/obj/item/clothing/accessory/armor/coldwar/plates/attack_hand(mob/user as mob)
	if (has_suit)	//if we are part of a suit
		hold.open(user)
		return

	if (hold.handle_attack_hand(user))	//otherwise interact as a regular storage item
		..(user)

/obj/item/clothing/accessory/armor/coldwar/plates/MouseDrop(obj/over_object as obj)
	if (has_suit)
		return

	if (hold.handle_mousedrop(usr, over_object))
		..(over_object)

/obj/item/clothing/accessory/armor/coldwar/plates/attackby(obj/item/W as obj, mob/user as mob)
	return hold.attackby(W, user)

/obj/item/clothing/accessory/armor/coldwar/plates/emp_act(severity)
	hold.emp_act(severity)
	..()

/obj/item/clothing/accessory/armor/coldwar/plates/attack_self(mob/user as mob)
	user << "<span class='notice'>You empty [src].</span>"
	var/turf/T = get_turf(src)
	hold.hide_from(usr)
	for (var/obj/item/I in hold.contents)
		hold.remove_from_storage(I, T)
	add_fingerprint(user)

/obj/item/clothing/accessory/armor/coldwar/plates/interceptor
	name = "black Interceptor Body Armor"
	desc = "Wearable armor that can stop even some rifle rounds. Can be fitted with plates to increase protection."
	icon_state = "modern_kevlar"
	item_state = "modern_kevlar"
	worn_state = "modern_kevlar"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 75, arrow = 100, gun = 65, energy = 25, bomb = 65, bio = 20, rad = FALSE)
	value = 120
	slowdown = 0.4
	w_class = 4
	weight = 3.8


/obj/item/weapon/armorplates
	name = "ballistic plates"
	desc = "Used to increase the protection of some body armors."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "plates"
	item_state = "plates"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 8.0
	throwforce = 6.0
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = TRUE
	w_class = 2.0