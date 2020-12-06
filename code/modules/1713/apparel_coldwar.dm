/* Index*/

/* 1 - Coldwar Coats
   2 - Cold War Accessories
   3 - FBI & Law Enforcement Clothes
   4 - US Army Clothes
   5 - US Army Helmets
   6 - Ghillie Suits
   7 - Cold War Hats
   8 - Vietcong Clothes
   9 - Cold War Armor
   10 - Cold War Belts
   11 - Cold War Balaclavas
   12 - Cold War Webbing
   13 - NBC &  Hazmat Suits
   14 - Miscallaneous
   14a - John Toughguy - Jungle Commando
   14b - Swinging Sixties
   14c - Other Miscallaneous */

/* Coldwar Coats*/

/obj/item/clothing/suit/storage/coat/modern_winter
	name = "dark green winter coat"
	desc = "An army-style coat, in olive drab."
	icon_state = "modern_winter"
	item_state = "modern_winter"
	worn_state = "modern_winter"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 12, arrow = 5, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 75

/obj/item/clothing/suit/storage/coat/oldyjacket
	name = "red jacket"
	desc = "A red jacket from the 80s."
	icon_state = "jacket80s"
	item_state = "jacket80s"
	worn_state = "jacket80s"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 100

/obj/item/clothing/suit/storage/coat/chinese
	name = "chinese coat"
	desc = "A chinese winter coat."
	icon_state = "chi_korea_coat"
	item_state = "chi_korea_coat"
	worn_state = "chi_korea_coat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 12, arrow = 5, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 75

/obj/item/clothing/suit/storage/coat/chinese/officer
	name = "chinese officer coat"
	desc = "A chinese winter coat, designed for officers."
	icon_state = "chi_korea_offcoat"
	item_state = "chi_korea_offcoat"
	worn_state = "chi_korea_offcoat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 12, arrow = 5, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)

/obj/item/clothing/suit/storage/coat/american
	name = "american coat"
	desc = "An american winter coat."
	icon_state = "us_coat_korea"
	item_state = "us_coat_korea"
	worn_state = "us_coat_korea"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 12, arrow = 5, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)

/* Cold War Accessories*/

/obj/item/clothing/mask/facecamo
	name = "woodlands face camo"
	desc = "Face painting in woodland camo pattern."
	icon_state = "painting_woodland"
	item_state = "painting_woodland"
	blocks_scope = FALSE

/* FBI & Law Enforcement Clothes*/

/obj/item/clothing/suit/storage/fbi
	name = "FBI jacket"
	desc = "A secret FBI jacket perhaps."
	icon_state = "fbi2"
	item_state = "fbi2"
	worn_state = "fbi2"

/obj/item/clothing/suit/swat //these likely need upgrading to armor
	name = "swat heavy vest"
	desc = "A heavy NIJ level IV vest, used by swat officers."
	icon_state = "swat"
	item_state = "swat"
	worn_state = "swat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 105, arrow = 80, gun = 116, energy = 70, bomb = 74, bio = 44, rad = 40)
	var/slots = 6
	ripable = FALSE

/obj/item/clothing/suit/police
	name = "police bulletproof vest"
	desc = "A police vest (Level III)."
	icon_state = "policevest"
	item_state = "policevest"
	worn_state = "policevest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 60, arrow = 20, gun = 74, energy = 40, bomb = 20, bio = 32, rad = 20)
	ripable = FALSE

/obj/item/clothing/under/traffic_police
	name = "police outfit"
	desc = "An outfit composed of a blue emergency services shirt and denim trousers. It has a police badge attached"
	icon_state = "traffic_cop"
	item_state = "traffic_cop"
	worn_state = "traffic_cop"

/obj/item/clothing/head/traffic_police
	name = "police cap"
	desc = "A blue cap often worn by members of the police and security guards."
	icon_state = "traffic_cop"
	item_state = "traffic_cop"
	worn_state = "traffic_cop"

/* US Army Clothes*/

/obj/item/clothing/under/us_uni
	name = "olive drab uniform"
	desc = "The standard us army uniform of the mid-20th century."
	icon_state = "us_uni"
	item_state = "us_uni"
	worn_state = "us_uni"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_camo
	name = "woodland camo uniform"
	desc = "The standard us army camo uniform the mid-20th century."
	icon_state = "us_camo"
	item_state = "us_camo"
	worn_state = "us_camo"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_greentrousers
	name = "olive drab trousers"
	desc = "The standard us army olive drab uniform trousers."
	icon_state = "us_greentrousers"
	item_state = "us_greentrousers"
	worn_state = "us_greentrousers"
	body_parts_covered = LOWER_TORSO|LEGS

/obj/item/clothing/under/us_uni/us_lightuni
	name = "olive drab uniform with rolled sleeves"
	desc = "A rolled-sleeves version of the us army olive drab uniform."
	icon_state = "us_uni_rolled"
	item_state = "us_uni_rolled"
	worn_state = "us_uni_rolled"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS

/obj/item/clothing/under/us_uni/us_lightuni2
	name = "olive drab trousers and white undershirt"
	desc = "A light version of the us army olive drab trousers and the service white undershirt."
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

/obj/item/clothing/suit/storage/us_jacket
	name = "olive drab jacket"
	desc = "The standard us army olive drab jacket of the mid-20th century."
	icon_state = "us_jacket"
	item_state = "us_jacket"
	worn_state = "us_jacket"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
//korean war//
/obj/item/clothing/under/us_uni_korean
	name = "american uniform"
	desc = "The standard us army uniform of the korean war, this one outfitted for winter."
	icon_state = "usuni_korea"
	item_state = "usuni_korea"
	worn_state = "usuni_korea"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT

/obj/item/clothing/under/chinese_winter
	name = "chinese uniform"
	desc = "The standard winter chinese uniform."
	icon_state = "korea_china"
	item_state = "korea_china"
	worn_state = "korea_china"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT

/* US Army Armor & Helmets*/

/obj/item/clothing/head //why is this HERE? @fantasticfwoosh
	var/list/attachments = list()

/obj/item/clothing/head/helmet/modern/ushelmet
	name = "M1 helmet"
	desc = "A typical us army helmet."
	icon_state = "m1_standard"
	item_state = "m1_standard"
	worn_state = "m1_standard"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 15, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	health = 24

/obj/item/clothing/head/helmet/modern/ushelmet/sgt
	name = "M1 helmet 2nd LT"
	desc = "A typical us army helmet. With lieutenant markings."
	icon_state = "m1_2nd_lt"
	item_state = "m1_2nd_lt"
	worn_state = "m1_2nd_lt"

/obj/item/clothing/head/helmet/modern/ushelmet/lt
	name = "M1 helmet 1st LT"
	desc = "A typical us army helmet. With lieutenant markings."
	icon_state = "m1_1st_lt"
	item_state = "m1_1st_lt"
	worn_state = "m1_1st_lt"

/obj/item/clothing/head/helmet/modern/ushelmet/camo
	name = "M1 camo helmet"
	desc = "A typical us army helmet. With a woodland camo cover."
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

/obj/item/clothing/head/helmet/modern/ushelmet/late/New()
	..()
	var/numb = rand(0,2)
	var/list/optlist = list("card","bullets","cigpack","peace","text")
	if (numb > 0)
		for (var/i = 1, i <= numb, i++)
			var/chosen = pick(optlist)
			attachments += chosen
			optlist -= chosen

/* Korean war Helmets */
/obj/item/clothing/head/helmet/korean/usm1
	name = "M1 Helmet"
	desc = "The typical rounded steel helmet of the US Army."
	icon_state = "korea_m1_standard"
	item_state = "korea_m1_standard"
	worn_state = "korea_m1_standard"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/korean/usm1/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/stack/material/rope))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You put netting on the helmet.</span>"
		new/obj/item/clothing/head/helmet/korean/ustannet(user.loc)
		qdel(src)
		qdel(W)

/obj/item/clothing/head/helmet/korean/ustannet
	name = "M1 Helmet with netting"
	desc = "The typical rounded steel helmet of the US Army, with tan netting."
	icon_state = "korea_m1_tan_netting"
	item_state = "korea_m1_tan_netting"
	worn_state = "korea_m1_tan_netting"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/korean/ustannet/verb/toggle_color()
	set category = null
	set src in usr
	set name = "Toggle Color"
	if (color)
		icon_state = "korea_m1_tan_netting"
		item_state = "korea_m1_tan_netting"
		worn_state = "korea_m1_tan_netting"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "m1_tan_netting"
		usr << "<span class = 'danger'>You switch out your tan netting for green netting.</span>"
		update_icon()
		color = FALSE
		usr.update_inv_head(1)
	else if (!color)
		icon_state = "korea_m1_green_netting"
		item_state = "korea_m1_green_netting"
		worn_state = "korea_m1_green_netting"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "m1_green_netting"
		usr << "<span class = 'danger'>You switch out your green netting for tan netting.</span>"
		update_icon()
		color = TRUE
		usr.update_inv_head(1)

/obj/item/clothing/head/helmet/korean/usgreennet
	name = "M1 Helmet with green netting"
	desc = "The typical rounded steel helmet of the US Army, with green netting."
	icon_state = "korea_m1_green_netting"
	item_state = "korea_m1_green_netting"
	worn_state = "korea_m1_green_netting"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/korean/us_medic
	name = "M1 Medic Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one for medics"
	icon_state = "korea_m1_medic"
	item_state = "korea_m1_medic"
	worn_state = "korea_m1_medic"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/korean/us_2lt
	name = "M1 2nd LT Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one bearing the rank of 2nd Lieutenant."
	icon_state = "korea_m1_2nd_lt"
	item_state = "korea_m1_2nd_lt"
	worn_state = "korea_m1_2nd_lt"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/korean/us_1lt
	name = "M1 1st LT Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one bearing the rank of 1st Lieutenant."
	icon_state = "korea_m1_1st_lt"
	item_state = "korea_m1_1st_lt"
	worn_state = "korea_m1_1st_lt"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/korean/us_cap
	name = "M1 Captain Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one bearing the rank of Captain."
	icon_state = "korea_m1_cpt"
	item_state = "korea_m1_cpt"
	worn_state = "korea_m1_cpt"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/* Ghillie Suits*/

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
	desc = "A headcover for a ghillie suit."
	icon_state = "ghillie"
	item_state = "ghillie"
	body_parts_covered = HEAD
	restricts_view = 1

/* Cold War Hats*/

/obj/item/clothing/head/jungle_hat
	name = "black boonie"
	desc = "A wide brim, soft jungle hat."
	icon_state = "black_boonie"
	item_state = "black_boonie"
	body_parts_covered = HEAD

/obj/item/clothing/head/jungle_hat/khaki
	name = "khaki boonie"
	desc = "A wide brim, soft jungle hat."
	icon_state = "khaki_boonie"
	item_state = "khaki_boonie"
	body_parts_covered = HEAD

/obj/item/clothing/head/rice_hat
	name = "rice hat"
	desc = "A wide brim, rice farmer hat."
	icon_state = "rice_hat"
	item_state = "rice_hat"
	body_parts_covered = HEAD

/obj/item/clothing/head/chinese_ushanka
	name = "chinese ushanka"
	desc = "A chinese ushanka, used by soldiers in the chinese army."
	icon_state = "chinese_ushanka_up"
	item_state = "chinese_ushanka_up"
	worn_state = "chinese_ushanka_up"

/obj/item/clothing/head/chinese_ushanka/down
	icon_state = "chinese_ushanka"
	item_state = "chinese_ushanka"
	worn_state = "chinese_ushanka"
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/head/chinese_ushanka/attack_self(mob/user as mob)
	if (icon_state == "chinese_ushanka")
		icon_state = "chinese_ushanka_up"
		item_state = "chinese_ushanka_up"
		user << "You raise the ear flaps on the ushanka."
	else if (icon_state == "chinese_ushanka_up")
		icon_state = "chinese_ushanka"
		item_state = "chinese_ushanka"
		flags_inv = BLOCKHEADHAIR
		user << "You lower the ear flaps on the ushanka."

/obj/item/clothing/head/helmet/modern/chi_korea_helmet
	name = "Chinese helmet"
	desc = "A leftover japanese helmet repurposed for the People's Liberation Army."
	icon_state = "chi_korea_helm"
	item_state = "chi_korea_helm"
	worn_state = "chi_korea_helm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 45, gun = 15, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	health = 24

/* Vietcong Clothes*/

/obj/item/clothing/under/localnlf1
	name = "local NLF uniform"
	desc = "A black uniform of the NLF."
	icon_state = "localnlfuniform_v1"
	item_state = "localnlfuniform_v1"
	worn_state = "localnlfuniform_v1"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/localnlf2
	name = "local NLF uniform"
	desc = "A black and blue uniform of the NLF."
	icon_state = "localnlfuniform_v2"
	item_state = "localnlfuniform_v2"
	worn_state = "localnlfuniform_v2"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/localnlf3
	name = "local NLF uniform"
	desc = "A black and khaki uniform of the NLF."
	icon_state = "localnlfuniform_v3"
	item_state = "localnlfuniform_v3"
	worn_state = "localnlfuniform_v3"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/localnlf4
	name = "local NLF uniform"
	desc = "A blue and khaki uniform of the NLF."
	icon_state = "localnlfuniform_v4"
	item_state = "localnlfuniform_v4"
	worn_state = "localnlfuniform_v4"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/localnlf5
	name = "local NLF uniform"
	desc = "A grey uniform of the NLF."
	icon_state = "localnlfuniform_v5"
	item_state = "localnlfuniform_v5"
	worn_state = "localnlfuniform_v5"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/accessory/armband/khan_ran/black
	name = "khan ran scarf (black and white)"
	desc = "A traditional mekong delta white-and-grey checkered scarf."
	icon_state = "khan_ran_v1"
	item_state = "khan_ran_v1"
	slot = "decor"

/obj/item/clothing/accessory/armband/khan_ran/blue
	name = "khan ran scarf (blue and white)"
	desc = "A traditional mekong delta white-and-blue checkered scarf."
	icon_state = "khan_ran_v2"
	item_state = "khan_ran_v2"
	slot = "decor"

/obj/item/clothing/accessory/storage/webbing/nlfsmallpouches
	name = "NLF small pouches"
	desc = "A green chest-level webbing, with 5 medium sized pouches."
	slots = 5
	icon_state = "nlfchestrig_v2"
	item_state = "nlfchestrig_v2"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/gun/projectile/pistol,/obj/item/weapon/gun/projectile/revolver,/obj/item/weapon/handcuffs,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/nlfchestrig
	name = "NLF chestrig"
	desc = "A green chest-level webbing, with three medium sized pouches."
	slots = 5
	icon_state = "nlfchestrig_v1"
	item_state = "nlfchestrig_v1"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/gun/projectile/pistol,/obj/item/weapon/gun/projectile/revolver,/obj/item/weapon/handcuffs,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/shoes/nlfsandal1
	name = "leather sandals"
	desc = "A pair of simple, thin leather strap sandals. Covers up to the lower foot."
	icon_state = "nlfsandals_v2"
	item_state = "nlfsandals_v2"
	worn_state = "nlfsandals_v2"
	force = WEAPON_FORCE_WEAK
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	var/colorn = 1

/obj/item/clothing/shoes/nlfsandal2
	name = "leather sandals"
	desc = "A pair of simple, thin leather strap sandals. Covers up to the lower foot and wraps around the ankle."
	icon_state = "nlfsandals_v1"
	item_state = "nlfsandals_v1"
	worn_state = "nlfsandals_v1"
	force = WEAPON_FORCE_WEAK
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	var/colorn = 1

/* Cold War Armor*/

/obj/item/clothing/accessory/armor //again im confused why this is the case. It should be moved somewhere higher up into armor.dm or/and tagged into /modern especially @fantasticfwoosh
	health = 20
	ripable = FALSE

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

/obj/item/clothing/head/helmet/modern/ssh_68 //1960 precursor to the 6B47 helmet on apparel_modern.dm
	name = "SSh-68 helmet"
	desc = "A mass produced metal helmet often used by USSR infantry forces in the mid 20th century."
	icon_state = "ssh_68_sovhelm"
	item_state = "ssh_68_sovhelm"
	worn_state = "ssh_68_sovhelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 100, gun = 76, energy = 24, bomb = 66, bio = 25, rad = FALSE)

/obj/item/clothing/suit/b3 //need checking these assets before path name change, but i've updated the name to a real B3 russian armor circa 1980's
	name = "USSR 6B3 body armor"
	desc = "A russian body armor, made with glory."
	icon_state = "b3vest"
	item_state = "b3vest"
	worn_state = "b3vest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|FEET|HANDS
	armor = list(melee = 65, arrow = 100, gun = 69, energy = 30, bomb = 40, bio = 10, rad = 30)
	ripable = FALSE

/obj/item/clothing/accessory/armor/coldwar/flakjacket // Google searches only reveal M-1965 Field Jacket's being normal american jackets, replace eventually please.
	name = "M-1952 Flak Jacket"
	desc = "Wearable armor meant to protect against shrapnel and light hits. Won't do much against large caliber weapons."
	icon_state = "flakjacket"
	item_state = "flakjacket"
	worn_state = "flakjacket"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 75, gun = 15, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	value = 60
	slowdown = 0.2

/obj/item/clothing/accessory/armor/coldwar/flakjacket/m1969 // see note above, this highly likely isn't real article.
	name = "M-1969 Flak Jacket"
	desc = "Wearable armor with neck protection meant to protect against shrapnel and light hits. Won't do much against large caliber weapons."
	icon_state = "flakjacket1969"
	item_state = "flakjacket1969"
	worn_state = "flakjacket1969"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 65, arrow = 75, gun = 20, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	value = 60
	slowdown = 0.2

/* Cold War Belts*/

/obj/item/weapon/storage/belt/largepouches/green/m60
/obj/item/weapon/storage/belt/largepouches/green/m60/New()
	..()
	new/obj/item/ammo_magazine/b762(src)
	new/obj/item/ammo_magazine/b762(src)

/obj/item/weapon/storage/belt/largepouches/m249
/obj/item/weapon/storage/belt/largepouches/m249/New()
	..()
	new/obj/item/ammo_magazine/m249(src)
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

/obj/item/weapon/storage/belt/largepouches/green/negev
/obj/item/weapon/storage/belt/largepouches/green/negev/New()
	..()
	new/obj/item/ammo_magazine/negev(src)
	new/obj/item/ammo_magazine/negev(src)

/obj/item/weapon/storage/belt/largepouches/pkm
/obj/item/weapon/storage/belt/largepouches/pkm/New()
	..()
	new/obj/item/ammo_magazine/pkm/c100(src)
	new/obj/item/ammo_magazine/pkm/c100(src)

/obj/item/weapon/storage/belt/smallpouches/soviet_ppsh
/obj/item/weapon/storage/belt/smallpouches/soviet_ppsh/New()
	..()
	new /obj/item/ammo_magazine/c762x25_ppsh(src)
	new /obj/item/ammo_magazine/c762x25_ppsh(src)
	new /obj/item/ammo_magazine/c762x25_ppsh(src)
	new /obj/item/ammo_magazine/c762x25_ppsh(src)

/obj/item/weapon/storage/belt/smallpouches/chinese_rifle
/obj/item/weapon/storage/belt/smallpouches/chinese_rifle/New()
	..()
	new /obj/item/ammo_magazine/gewehr98(src)
	new /obj/item/ammo_magazine/gewehr98(src)
	new /obj/item/ammo_magazine/gewehr98(src)
	new /obj/item/ammo_magazine/gewehr98(src)

/* Cold War Balaclavas*/

/obj/item/clothing/mask/balaclava
	name = "black balaclava"
	desc = "A black balaclava, covering the face."
	icon_state = "balaclava"
	item_state = "balaclava"
	worn_state = "balaclava"
	body_parts_covered = FACE|EYES|HEAD
	flags_inv = HIDEFACE
	w_class = 1
	restricts_view = 2
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/commando_bandana
	name = "olive drab bandana"
	desc = "An olive drab coloured bandana."
	icon_state = "commando_bandana"
	item_state = "commando_bandana"
	body_parts_covered = HEAD

/obj/item/clothing/mask/sovietbala
	name = "green balaclava"
	desc = "A green balaclava, covering the mouth."
	icon_state = "sovietbala"
	item_state = "sovietbala"
	worn_state = "sovietbala"
	body_parts_covered = FACE|EYES|HEAD
	w_class = 1
	restricts_view = 2
	heat_protection = HEAD|FACE|EYES

/* Cold War Webbing*/

/obj/item/clothing/accessory/storage/webbing/green_webbing
	name = "green chest webbing"
	desc = "A green chest-level webbing, with three medium sized pouches."
	slots = 3
	icon_state = "green_webbing"
	item_state = "green_webbing"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/gun/projectile/pistol,/obj/item/weapon/gun/projectile/revolver,/obj/item/weapon/handcuffs,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/khaki_webbing
	name = "khaki chest webbing"
	desc = "A khaki chest-level webbing, with three medium sized pouches."
	slots = 3
	icon_state = "khaki_webbing"
	item_state = "khaki_webbing"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/gun/projectile/pistol,/obj/item/weapon/gun/projectile/revolver,/obj/item/weapon/handcuffs,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/pouches
	name = "black pouches"
	desc = "A set of pouches to store magazines in."
	slots = 3
	icon_state = "black_pouches"
	item_state = "black_pouches"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine)

/obj/item/clothing/accessory/storage/webbing/largepouches
	name = "large black pouches"
	desc = "A large set of pouches to store magazines in."
	slots = 6
	icon_state = "largepouches"
	item_state = "largepouches"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine)

/obj/item/clothing/accessory/storage/webbing/largepouchestan
	name = "large tan pouches"
	desc = "A large set of pouches to store magazines in."
	slots = 6
	icon_state = "largepouches_tan"
	item_state = "largepouches_tan"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine)

/obj/item/clothing/accessory/storage/webbing/tanpouches
	name = "tan pouches"
	desc = "A set of pouches to store magazines in."
	slots = 3
	icon_state = "tan_pouches"
	item_state = "tan_pouches"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine)

/obj/item/clothing/accessory/storage/webbing/ubac
	name = "tan UBAC"
	desc = "A flexible, close-fitting shirt with camouflage sleeves designed to be worn under combat equipment. This one is tan."
	icon_state = "ubac_tan"
	item_state = "ubac_tan"

/obj/item/clothing/accessory/storage/webbing/ubacgreen
	name = "green UBAC"
	desc = "A flexible, close-fitting shirt with camouflage sleeves designed to be worn under combat equipment. This one is green."
	icon_state = "ubac_green"
	item_state = "ubac_green"

/obj/item/clothing/accessory/storage/webbing/ubacblack
	name = "black UBAC"
	desc = "A flexible, close-fitting shirt with camouflage sleeves designed to be worn under combat equipment. This one is black."
	icon_state = "ubac_black"
	item_state = "ubac_black"

/obj/item/clothing/accessory/storage/webbing/sweater //does not the capacity to protect against cold currently
	name = "white sweater"
	desc = "A sweater to help you be comfy."
	icon_state = "sweater"
	item_state = "sweater"

/obj/item/clothing/accessory/storage/webbing/light
	name = "light webbing"
	desc = "a light webbing, with lower capacity but permitting fast movement."
	slots = 3
	icon_state = "german_vest"
	item_state = "german_vest"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/handcuffs,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/us_vest
	name = "us army webbing"
	desc = "A large webbing with several small pockets."
	icon_state = "us_vest"
	item_state = "us_vest"
	slots = 5
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/handcuffs,/obj/item/stack/medical/bruise_pack)

/* NBC &  Hazmat Suits*/

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
	ripable = FALSE

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

/obj/item/clothing/suit/hazmat
	name = "hazmat suit"
	desc = "A bright hazard protection suit, made protect against biological, chemical and nuclear threats."
	icon_state = "hazmat_suit"
	item_state = "hazmat_suit"
	worn_state = "hazmat_suit"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|FEET|HANDS|HEAD
	armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = 5, bomb = 5, bio = 100, rad = 100)
	ripable = FALSE

/* Miscallaneous*/

	/* John Toughguy - Jungle Commando defintiely does not rhyme with a certain movie franchise*/

/* Woodland Face Paint Recommended*/

/obj/item/clothing/head/bandana/toughguy
	name = "specialist bandana"
	desc = "A red bandana, the preferred headwear of seasoned jungle fighters."
	icon_state = "toughguy"
	item_state = "toughguy"
	worn_state = "toughguy"
	body_parts_covered = HEAD

/obj/item/clothing/under/toughguy
	name = "specialist pants with woodland pattern paint"
	desc = "A army issued pair of pants and woodland pattern body-paint; to blend seamlessly into the enviroment"
	icon_state = "toughguy"
	item_state = "toughguy"
	worn_state = "toughguy"

/obj/item/clothing/gloves/toughguy
	name = "specialist leather gloves"
	icon_state = "toughguy"
	item_state = "toughguy"
	worn_state = "toughguy"
	body_parts_covered = HANDS
	slot_flags = SLOT_GLOVES

/obj/item/clothing/shoes/toughguy
	name = "specialist boots"
	desc = "A well made and importantly quiet treading pair of army-issue leather boots.."
	icon_state = "toughguy"
	item_state = "toughguy"
	worn_state = "toughguy"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 20, arrow = 40, gun = FALSE, energy = 10, bomb = 40, bio = 20, rad = 40)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

	/* Swinging 60's*/

/obj/item/clothing/under/sundress
	name = "yellow sundress"
	desc = "A mid century style dress often worn outside in fair weather associated with a new generation of independent women"
	icon_state = "sundress_yellow"
	item_state = "sundress_yellow"
	worn_state = "sundress_yellow"

/obj/item/clothing/under/sundress/blue
	name = "blue sundress"
	desc = "A mid century style dress often worn outside in fair weather associated with a new generation of independent women"
	icon_state = "sundress_blue"
	item_state = "sundress_blue"
	worn_state = "sundress_blue"

/obj/item/clothing/under/sundress/orange
	name = "orange sundress"
	desc = "A mid century style dress often worn outside in fair weather associated with a new generation of independent women"
	icon_state = "sundress_orange"
	item_state = "sundress_orange"
	worn_state = "sundress_orange"

/obj/item/clothing/under/sundress/purple
	name = "purple sundress"
	desc = "A mid century style dress often worn outside in fair weather associated with a new generation of independent women"
	icon_state = "sundress_purple"
	item_state = "sundress_purple"
	worn_state = "sundress_purple"

/obj/item/clothing/under/sundress/red
	name = "red sundress"
	desc = "A mid century style dress often worn outside in fair weather associated with a new generation of independent women"
	icon_state = "sundress_red"
	item_state = "sundress_red"
	worn_state = "sundress_red"

/obj/item/clothing/under/gatorpants
	name = "shirtless gator pants"
	desc = "A tight fitting pair of alligator scale pants. When you're this on-point; wearing a shirt would just cramp your style."
	icon_state = "gator_pants"
	item_state = "gator_pants"
	worn_state = "gator_pants"
	body_parts_covered = LOWER_TORSO|LEGS

	/* Other Miscallaneous */

/obj/item/clothing/suit/bx //is this futuristic?
	name = "carbon black suit"
	desc = "A high tech suit made of comprssed carbon materials."
	icon_state = "bxsuit"
	item_state = "bxsuit"
	worn_state = "bxsuit"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|FEET|HANDS
	armor = list(melee = 140, arrow = 200, gun = 150, energy = 100, bomb = 100, bio = 100, rad = 80)
	ripable = FALSE

/obj/item/clothing/suit/a6b45 //isn't this armor? || Note @FantasticFwoosh- (29/08/2020) Ratnik Programme russian armor is developed in 2016 this is classified in the wrong era.
	name = "6B45 heavy vest"
	desc = "6B45 is a modular bullet-resistant vest. It comprises frontal and rear section and soft-armour shoulder and side protection."
	icon_state = "a6b45"
	item_state = "a6b45"
	worn_state = "a6b45"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 103, arrow = 110, gun = 110, energy = 67, bomb = 70, bio = 40, rad = 36)
	var/slots = 4
	ripable = FALSE

/obj/item/clothing/suit/heavyvest1 // Is designative of armor grade/type but not a armor itself. Please replace with identifiable/recognizable armor.
	name = "heavy vest"
	desc = "a heavy NIJ level IV vest."
	icon_state = "heavypolice"
	item_state = "heavypolice"
	worn_state = "heavypolice"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 50, arrow = 40, gun = 112, energy = 68, bomb = 40, bio = 32, rad = 20)
	var/slots = 6
	ripable = FALSE

/obj/item/clothing/suit/medvest // Is designative of armor grade/type but not a armor itself. Please replace with identifiable/recognizable armor.
	name = "medium vest"
	desc = "a heavy NIJ level III vest."
	icon_state = "mediumvest"
	item_state = "mediumvest"
	worn_state = "mediumvest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 30, arrow = 40, gun = 84, energy = 47, bomb = 35, bio = 29, rad = 10)
	var/slots = 6
	ripable = FALSE

/obj/item/clothing/suit/a6b44 // Is designative of armor grade/type but not a armor itself. Please replace with identifiable/recognizable armor.
	name = "6B44 vest"
	desc = "6B44 is a modular bullet-resistant vest."
	icon_state = "a6b44"
	item_state = "a6b44"
	worn_state = "a6b44"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 80, arrow = 100, gun = 93, energy = 56, bomb = 64, bio = 40, rad = 36)
	var/slots = 4
	ripable = FALSE

/obj/item/clothing/suit/a6b28 // Is designative of armor grade/type but not a armor itself. Please replace with identifiable/recognizable armor.
	name = "6B28 plate carrier"
	desc = "6B28 is a level III plate carrier."
	icon_state = "a6b28"
	item_state = "a6b28"
	worn_state = "a6b28"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 74, arrow = 87, gun = 83, energy = 67, bomb = 56, bio = 40, rad = 36)
	var/slots = 3
	ripable = FALSE

/obj/item/clothing/head/helmet/modern/vchelmet
	name = "viet pith helmet"
	desc = "A pith helmet used by the vietnamese."
	icon_state = "viet_pith"
	item_state = "viet_pith"
	worn_state = "viet_pith"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 45, gun = 15, energy = 15, bomb = 55, bio = 20, rad = FALSE)
	health = 24

//yare yare daze.

/obj/item/clothing/head/bizarre_hat
	name = "bizarre dark blue hat"
	desc = "A dark blue hat worn by troublemakers."
	icon_state = "bizarre_hat"
	item_state = "bizarre_hat"
	worn_state = "bizarre_hat"

/obj/item/clothing/suit/storage/coat/bizarre_coat
	name = "bizarre dark blue coat"
	desc = "A very stylish coat."
	icon_state = "bizarre_coat"
	item_state = "bizarre_coat"
	worn_state = "bizarre_coat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 15, arrow = 5, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 150