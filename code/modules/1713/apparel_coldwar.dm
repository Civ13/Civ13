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
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/handcuffs,)

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
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/handcuffs,)


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
	restricts_view = 1

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

/obj/item/weapon/storage/belt/largepouches/m249
/obj/item/weapon/storage/belt/largepouches/m249/New()
	..()
	new/obj/item/ammo_magazine/m249(src)

/obj/item/weapon/storage/belt/largepouches/sovietmg
/obj/item/weapon/storage/belt/largepouches/sovietmg/New()
	..()
	new/obj/item/ammo_magazine/dp(src)
	new/obj/item/ammo_magazine/dp(src)

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

//late coldwar stuff

/obj/item/clothing/accessory/armor/coldwar/pasgt
	name = "woodland PASGT body armor"
	desc = "Wearable armor that can stop most pistol rounds. This one is in U.S. Woodland pattern."
	icon_state = "pasgt_woodland"
	item_state = "pasgt_woodland"
	worn_state = "pasgt_woodland"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 67, arrow = 95, gun = 52, energy = 22, bomb = 60, bio = 20, rad = FALSE)
	value = 90
	slowdown = 0.3
	w_class = 4
	weight = 3.8

/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki
	name = "khaki PASGT body armor"
	desc = "Wearable armor that can stop most pistol rounds. This one is khaki colored."
	icon_state = "pasgt_khaki"
	item_state = "pasgt_khaki"
	worn_state = "pasgt_khaki"

/obj/item/clothing/accessory/armor/coldwar/plates/interceptor
	name = "black Interceptor Body Armor"
	desc = "Wearable armor that can stop even some rifle rounds. Can be fitted with plates to increase protection."
	icon_state = "iba_black"
	item_state = "iba_black"
	worn_state = "iba_black"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 75, arrow = 100, gun = 65, energy = 25, bomb = 65, bio = 20, rad = FALSE)
	value = 120
	slowdown = 0.4
	w_class = 4
	weight = 6

/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ucp
	name = "UCP Interceptor Body Armor"
	desc = "Wearable armor that can stop even some rifle rounds. Can be fitted with plates to increase protection. This one has the Universal Camouflage Pattern."
	icon_state = "iba_ucp"
	item_state = "iba_ucp"
	worn_state = "iba_ucp"

/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp
	name = "OCP Interceptor Body Armor"
	desc = "Wearable armor that can stop even some rifle rounds. Can be fitted with plates to increase protection. This one has the Operational Camouflage Pattern."
	icon_state = "iba_ocp"
	item_state = "iba_ocp"
	worn_state = "iba_ocp"

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

/obj/item/clothing/accessory/armor/knee_protections
	name = "knee protections"
	desc = "Used to increase the protection of the legs."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "knee_protections"
	item_state = "knee_protections"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 6.0
	throwforce = 3.0
	slot = "leg_armor"
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("bashed", "bludgeoned", "whacked")
	body_parts_covered = LEGS
	armor = list(melee = 75, arrow = 50, gun = 15, energy = 25, bomb = 55, bio = 20, rad = FALSE)
	slowdown = 0.1
	sharp = FALSE
	edge = TRUE
	w_class = 2.0

/obj/item/clothing/accessory/armor/elbow_protections
	name = "elbow protections"
	desc = "Used to increase the protection of the arms."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "elbow_protections"
	item_state = "elbow_protections"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 6.0
	throwforce = 3.0
	slot = "arm_armor"
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("bashed", "bludgeoned", "whacked")
	body_parts_covered = ARMS
	armor = list(melee = 65, arrow = 45, gun = 15, energy = 25, bomb = 55, bio = 20, rad = FALSE)
	slowdown = 0.1
	sharp = FALSE
	edge = TRUE
	w_class = 2.0


/obj/item/clothing/head/helmet/modern/pasgt
	name = "PASGT helmet"
	desc = "A typical US Army PASGT helmet. This one is in U.S. Woodland pattern."
	icon_state = "pasgt_woodland"
	item_state = "pasgt_woodland"
	worn_state = "pasgt_woodland"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 62, arrow = 55, gun = 21, energy = 15, bomb = 55, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/pasgt/desert
	name = "PASGT helmet"
	desc = "A typical US Army PASGT helmet. This one is in U.S. Desert pattern."
	icon_state = "pasgt_desert"
	item_state = "pasgt_desert"
	worn_state = "pasgt_desert"

/obj/item/clothing/head/helmet/modern/pasgt/desert/New()
	..()
	if (prob(50))
		icon_state = "pasgt_desert_attachments"
		item_state = "pasgt_desert_attachments"
		worn_state = "pasgt_desert_attachments"
		update_icon()

/obj/item/clothing/head/helmet/modern/lwh
	name = "LWH helmet"
	desc = "A typical US Army LightWeight Helmet. This one is in beige color."
	icon_state = "lwh_desert"
	item_state = "lwh_desert"
	worn_state = "lwh_desert"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 68, arrow = 67, gun = 27, energy = 18, bomb = 65, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/modern/lwh/black
	name = "black LWH helmet"
	desc = "A typical US Army LightWeight Helmet. This one is in black color."
	icon_state = "lwh_black"
	item_state = "lwh_black"
	worn_state = "lwh_black"



/obj/item/clothing/under/us_uni/us_camo_woodland
	name = "woodland camouflage uniform"
	desc = "The standard US Army camo uniform the late 20th century."
	icon_state = "us_camo_woodland"
	item_state = "us_camo_woodland"
	worn_state = "us_camo_woodland"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_camo_dcu
	name = "desert camouflage uniform"
	desc = "The standard US Army desert camo uniform the late 20th century."
	icon_state = "us_camo_dcu"
	item_state = "us_camo_dcu"
	worn_state = "us_camo_dcu"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_camo_ucp
	name = "UCP camo uniform"
	desc = "The standard US Army camo uniform the early 21st century."
	icon_state = "us_camo_ucp"
	item_state = "us_camo_ucp"
	worn_state = "us_camo_ucp"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS


/obj/item/clothing/under/us_uni/us_camo_ocp
	name = "OCP camo uniform"
	desc = "The standard US Army camo uniform from 2018 onwards."
	icon_state = "us_camo_ocp"
	item_state = "us_camo_ocp"
	worn_state = "us_camo_ocp"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/mask/balaclava
	name = "black balaclava"
	desc = "A black balaclava, covering the face."
	icon_state = "balaclava"
	item_state = "balaclava"
	worn_state = "balaclava"
	body_parts_covered = FACE|EYES|HEAD
	w_class = 1
	restricts_view = 2


/obj/item/clothing/accessory/storage/webbing/green_webbing
	name = "green chest webbing"
	desc = "a green chest-level webbing, with three medium sized pouches."
	slots = 3
	icon_state = "green_webbing"
	item_state = "green_webbing"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/gun/projectile/pistol,/obj/item/weapon/gun/projectile/revolver,/obj/item/weapon/handcuffs,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,)

/obj/item/clothing/accessory/storage/webbing/khaki_webbing
	name = "khaki chest webbing"
	desc = "a khaki chest-level webbing, with three medium sized pouches."
	slots = 3
	icon_state = "khaki_webbing"
	item_state = "khaki_webbing"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/gun/projectile/pistol,/obj/item/weapon/gun/projectile/revolver,/obj/item/weapon/handcuffs,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,)

/obj/item/clothing/under/insurgent_black
	name = "black tunic"
	desc = "An all black tunic and trousers outfit."
	icon_state = "insurgent_black"
	item_state = "insurgent_black"
	worn_state = "insurgent_black"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/insurgent_sand
	name = "sand-colored tunic"
	desc = "A dark yellow, sand-colored tunic and trousers outfit."
	icon_state = "insurgent_sand"
	item_state = "insurgent_sand"
	worn_state = "insurgent_sand"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/insurgent_sand_woodland
	name = "sand-colored tunic with woodland camo trousers"
	desc = "A dark yellow, sand-colored tunic with woodland camo trousers."
	icon_state = "insurgent_sand_woodland"
	item_state = "insurgent_sand_woodland"
	worn_state = "insurgent_sand_woodland"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/insurgent_sand_dcu
	name = "sand-colored uniform with desert camo trousers"
	desc = "A dark yellow, sand-colored uniform with desert camo trousers."
	icon_state = "insurgent_sand_dcu"
	item_state = "insurgent_sand_dcu"
	worn_state = "insurgent_sand_dcu"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/insurgent_sand_green
	name = "light brown uniform with green trousers"
	desc = "A light brown uniform with green trousers."
	icon_state = "insurgent_sand_green"
	item_state = "insurgent_sand_green"
	worn_state = "insurgent_sand_green"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/insurgent_leader
	name = "black tunic with desert camo trousers"
	desc = "A black tunic with desert camo trousers, worn by insurgent leaders."
	icon_state = "insurgent_leader"
	item_state = "insurgent_leader"
	worn_state = "insurgent_leader"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
/obj/item/clothing/under/us_uni/us_lightuni_modern
	name = "U.S. Army training uniform"
	desc = "An informal outfit made of OCP pattern trousers and a olive drab shirt."
	icon_state = "us_lightuni_modern"
	item_state = "us_lightuni_modern"
	worn_state = "us_lightuni_modern"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS

/obj/item/clothing/gloves/fingerless
	name = "fingerless black gloves"
	icon_state = "fingerless"
	item_state = "fingerless"
	body_parts_covered = HANDS
	slot_flags = SLOT_GLOVES

/obj/item/clothing/head/black_bandana
	name = "black bandana"
	desc = "A light black piece of cloth worn wrapped around the head."
	icon_state = "black_bandana"
	item_state = "black_bandana"
	body_parts_covered = HEAD

/obj/item/clothing/head/black_shemagh
	name = "black shemagh"
	desc = "A light black piece of cloth worn loosely wrapped around the head, typical of middle-east countries."
	icon_state = "black_shemagh"
	item_state = "black_shemagh"
	body_parts_covered = HEAD

/obj/item/weapon/material/sword/arabsword
	name = "arabic sword"
	desc = "A light sword with a thin, stright blade. Commonly used by officers and nobility."
	icon_state = "arabsword1"
	item_state = "longsword"
	throw_speed = 4
	throw_range = 5
	force_divisor = 0.75 // 45 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 14 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 26
	cooldownw = 9
	value = 60

/obj/item/clothing/head/nbc
	name = "yellow NBC hood"
	desc = "A yellow coloured NBC hood, made protect against biological, chemical and nuclear threats."
	icon_state = "nbc"
	flags_inv = BLOCKHAIR
	body_parts_covered = HEAD
	armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = 25, bomb = 10, bio = 100, rad = 80)

/obj/item/clothing/suit/nbc
	name = "yellow NBC suit"
	desc = "A yellow coloured NBC suit, made protect against biological, chemical and nuclear threats."
	icon_state = "nbc"
	item_state = "nbc"
	worn_state = "nbc"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|FEET|HANDS
	armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = 25, bomb = 10, bio = 100, rad = 80)

/obj/item/clothing/head/nbc/olive
	name = "olive drab NBC hood"
	desc = "An olive drab coloured NBC hood, made protect against biological, chemical and nuclear threats."
	icon_state = "nbc2"

/obj/item/clothing/suit/nbc/olive
	name = "olive drab NBC suit"
	desc = "An olive drab coloured NBC suit, made protect against biological, chemical and nuclear threats."
	icon_state = "nbc2"
	item_state = "nbc2"
	worn_state = "nbc2"