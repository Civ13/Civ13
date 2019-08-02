/obj/item/clothing/suit/storage/coat/germcoat
	name = "german coat"
	desc = "A German army coat."
	icon_state = "germtrench"
	item_state = "germtrench"
	worn_state = "germtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 20)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/coat/frenchcoat
	name = "french trench coat"
	desc = "A French trench coat."
	icon_state = "frenchtrench"
	item_state = "frenchtrench"
	worn_state = "frenchtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/coat/britishcoat
	name = "british coat"
	desc = "A British coat."
	icon_state = "britishtrench"
	item_state = "britishtrench"
	worn_state = "britishtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 20)
	value = 65
	var/colorn = 1


/obj/item/clothing/head/ww/germcap
	name = "german cap"
	desc = "A cap worn by german soldiers."
	icon_state = "germcap2"
	item_state = "germcap2"

/obj/item/clothing/head/ww/frenchcap
	name = "french képi"
	desc = "A flat circular cap worn by french soldiers."
	icon_state = "frenchcap"
	item_state = "frenchcap"

/obj/item/clothing/head/ww/britishcap
	name = "british cap"
	desc = "A cap worn by british soldiers."
	icon_state = "brittcap"
	item_state = "brittcap"

/obj/item/clothing/head/helmet/ww
	health = 18

/obj/item/clothing/head/helmet/ww/stahlhelm
	name = "M1915 stahlhelm"
	desc = "A typical grman stahlhelm helmet."
	icon_state = "stahlhelm_old"
	item_state = "stahlhelm_old"
	worn_state = "stahlhelm_old"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 35, gun = 10, energy = 15, bomb = 45, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww/adrian
	name = "Adrian helmet"
	desc = "A typical french adrian helmet."
	icon_state = "adrian"
	item_state = "adrian"
	worn_state = "adrian"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww/brodie
	name = "Brodie helmet"
	desc = "A typical british helmet."
	icon_state = "brodie"
	item_state = "brodie"
	worn_state = "brodie"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)
/obj/item/clothing/head/helmet/ww/pickelhaube2
	name = "leather pickelhaube"
	desc = "A typical pointed helmet."
	icon_state = "pickelhaube2"
	item_state = "pickelhaube2"
	worn_state = "pickelhaube2"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 30, gun = 3, energy = 10, bomb = 35, bio = 20, rad = FALSE)
/obj/item/clothing/head/helmet/ww/brodie/khaki
	name = "khaki Brodie helmet"
	desc = "A typical british helmet, with a khaki cover."
	icon_state = "brodie_old"
	item_state = "brodie_old"
	worn_state = "brodie_old"

/obj/item/clothing/glasses/pilot
	name = "pilot goggles"
	desc = "Early 20th century pilot goggles."
	icon_state = "biker"
	item_state = "biker"
	worn_state = "biker"
	restricts_view = 1
////////////////////////////////////////////////////////////////////////
///////////////////////////////WW2 JAPS/////////////////////////////////
////////////////////////////////////////////////////////////////////////
/obj/item/clothing/head/helmet/ww2
	health = 20
/obj/item/clothing/head/helmet/ww2/japhelm
	name = "japanese helmet"
	desc = "A typical rounded steel helmet."
	icon_state = "japhelm"
	item_state = "japhelm"
	worn_state = "japhelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 43, arrow = 33, gun = 10, energy = 15, bomb = 44, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/japhelm_med
	name = "japanese medic helmet"
	desc = "A typical rounded steel helmet, this one bearing the marks of a medic."
	icon_state = "japhelm_medic"
	item_state = "japhelm_medic"
	worn_state = "japhelm_medic"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 43, arrow = 33, gun = 10, energy = 15, bomb = 44, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/japhelm_tanker
	name = "japanese tanker helmet"
	desc = "A typical rounded steel helmet, this one more made of meshes and hard leather."
	icon_state = "japtanker"
	item_state = "japtanker"
	worn_state = "japtanker"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/japhelm/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/clothing/head/ww2/jap_headband))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the heabdand on the helmet.</span>"
		new/obj/item/clothing/head/helmet/ww2/japhelm_bandana(user.loc)
		qdel(src)
		qdel(W)

/obj/item/clothing/head/helmet/ww2/japhelm_bandana
	name = "japanese helmet"
	desc = "A typical rounded steel helmet. This one has a headband attached to it."
	icon_state = "japhelm_bandana"
	item_state = "japhelm_bandana"
	worn_state = "japhelm_bandana"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 43, arrow = 33, gun = 10, energy = 15, bomb = 44, bio = 20, rad = FALSE)

/obj/item/clothing/head/ww2/japcap
	name = "japanese cap"
	desc = "A cap worn by japanese soldiers."
	icon_state = "ww2_japcap"
	item_state = "ww2_japcap"
	worn_state = "ww2_japcap"
	var/toggled = FALSE

/obj/item/clothing/head/ww2/japcap/verb/toggle_flaps()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/ww2/japcap)
		return
	else
		if (toggled)
			item_state = "ww2_japcap"
			worn_state = "ww2_japcap"
			item_state_slots["slot_w_uniform"] = "ww2_japcap"
			usr << "<span class = 'danger'>You put down your cap's flaps.</span>"
			toggled = FALSE
		else if (!toggled)
			item_state = "ww2_japcap_extended"
			worn_state = "ww2_japcap_extended"
			item_state_slots["slot_w_uniform"] = "ww2_japcap_extended"
			usr << "<span class = 'danger'>You put up your cap's flaps.</span>"
			toggled = TRUE
	update_clothing_icon()


/obj/item/clothing/head/ww2/japoffcap
	name = "japanese officer cap"
	desc = "A cap worn by japanese officers."
	icon_state = "ww2_japoffcap"
	item_state = "ww2_japoffcap"
	worn_state = "ww2_japoffcap"
	var/toggled = FALSE

/obj/item/clothing/head/ww2/japoffcap/verb/toggle_flaps()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/ww2/japoffcap)
		return
	else
		if (toggled)
			item_state = "ww2_japoffcap"
			worn_state = "ww2_japoffcap"
			item_state_slots["slot_w_uniform"] = "ww2_japoffcap"
			usr << "<span class = 'danger'>You put down your cap's flaps.</span>"
			toggled = FALSE
		else if (!toggled)
			item_state = "ww2_japoffcap_extended"
			worn_state = "ww2_japoffcap_extended"
			item_state_slots["slot_w_uniform"] = "ww2_japoffcap_extended"
			usr << "<span class = 'danger'>You put up your cap's flaps.</span>"
			toggled = TRUE
	update_clothing_icon()

/obj/item/clothing/under/ww2/japoffuni
	name = "japanese officer uniform"
	desc = "A imperial japanese army officer uniform."
	icon_state = "ww2_japoffuni"
	item_state = "ww2_japoffuni"
	worn_state = "ww2_japoffuni"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/japoffuni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/japoffuni)
		return
	else
		if (rolled)
			item_state = "ww2_japoffuni"
			worn_state = "ww2_japoffuni"
			item_state_slots["slot_w_uniform"] = "ww2_japoffuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
		else if (!rolled)
			item_state = "ww2_japoffuni_rolled"
			worn_state = "ww2_japoffuni_rolled"
			item_state_slots["slot_w_uniform"] = "ww2_japoffuni_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
	update_clothing_icon()

/obj/item/clothing/under/ww2/japuni
	name = "japanese uniform"
	desc = "A imperial japanese army uniform."
	icon_state = "ww2_japuni"
	item_state = "ww2_japuni"
	worn_state = "ww2_japuni"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/japuni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/japuni)
		return
	else
		if (rolled)
			item_state = "ww2_japuni"
			worn_state = "ww2_japuni"
			item_state_slots["slot_w_uniform"] = "ww2_japuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
		else if (!rolled)
			item_state = "ww2_japuni_rolled"
			worn_state = "ww2_japuni_rolled"
			item_state_slots["slot_w_uniform"] = "ww2_japuni_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
	update_clothing_icon()

obj/item/clothing/under/ww2/japuni_med
	name = "japanese medic uniform"
	desc = "A imperial japanese army uniform, this one bears the rank of a medic."
	icon_state = "japuni_med"
	item_state = "japuni_med"
	worn_state = "japuni_med"
	var/rolled = FALSE

obj/item/clothing/under/ww2/japuni_med/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/japuni_med)
		return
	else
		if (rolled)
			item_state = "japuni_med"
			worn_state = "japuni_med"
			item_state_slots["slot_w_uniform"] = "japuni_med"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
		else if (!rolled)
			item_state = "japuni_med_rolled"
			worn_state = "japuni_med_rolled"
			item_state_slots["slot_w_uniform"] = "japuni_med_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
	update_clothing_icon()

obj/item/clothing/under/ww2/japuni_mp
	name = "japanese Kenpeitai uniform"
	desc = "A imperial japanese army uniform, this one bears the rank of a military police."
	icon_state = "japuni_mp"
	item_state = "japuni_mp"
	worn_state = "japuni_mp"

obj/item/clothing/under/ww2/japuni_tanker
	name = "japanese tanker uniform"
	desc = "A imperial japanese army uniform, this one bears the rank of a tanker."
	icon_state = "japtanker"
	item_state = "japtanker"
	worn_state = "japtanker"

/obj/item/clothing/head/ww2/jap_headband
	name = "japanese headband"
	desc = "A headband worn by japanese soldiers."
	icon_state = "japbandana"
	item_state = "japbandana"
	worn_state = "japbandana"

obj/item/clothing/accessory/harness
	name = "japanese pilot harness"
	desc = "a harness made to strap someone to their plane."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "jap_harn"
	item_state = "jap_harn"
	worn_state = "jap_harn"

/obj/item/clothing/suit/storage/coat/ww2/japcoat
	name = "japanese coat"
	desc = "A japanese army coat."
	icon_state = "ww2_japcoat"
	item_state = "ww2_japcoat"
	worn_state = "ww2_japcoat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65

/obj/item/clothing/suit/storage/coat/ww2/japcoat_pilot
	name = "japanese pilot coat"
	desc = "A japanese air force kamikaze jacket."
	icon_state = "jappilotcoat"
	item_state = "jappilotcoat"
	worn_state = "jappilotcoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 100

obj/item/clothing/head/ww2/jap_pilotcap
	name = "japanese pilot cap"
	desc = "A cap worn by japanese pilots."
	icon_state = "jappilotcap"
	item_state = "jappilotcap"
	worn_state = "jappilotcap"

obj/item/clothing/head/ww2/jap_mp
	name = "Kenpeitai cap"
	desc = "A cap worn by japanese Kenpeitai."
	icon_state = "japcap_mp"
	item_state = "japcap_mp"
	worn_state = "japcap_mp"

///////////WW1 UNIFORMS///////////
/obj/item/clothing/under/ww1/german
	name = "german uniform"
	desc = "A german feldgrau uniform, used by the Imperial German Army."
	icon_state = "ww1_german"
	item_state = "ww1_german"
	worn_state = "ww1_german"

/obj/item/clothing/under/ww1/british
	name = "british uniform"
	desc = "A british khaki uniform, used by the Royal Army."
	icon_state = "ww1_british"
	item_state = "ww1_british"
	worn_state = "ww1_british"

/obj/item/clothing/under/ww1/french
	name = "french uniform"
	desc = "A french light blue uniform, used by the French Army."
	icon_state = "ww1_french"
	item_state = "ww1_french"
	worn_state = "ww1_french"


/obj/item/clothing/accessory/storage/webbing/ww1
	name = "webbing"
	desc = "two leather belts with small pouches for ammunition and grenades."
	icon_state = "german_vest"
	item_state = "german_vest"
	slots = 4
	New()
		..()
		hold.can_hold = list(/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade, /obj/item/weapon/attachment/bayonet,/obj/item/weapon/shovel/trench,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/weapon/reagent_containers/food/snacks/MRE,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/ww1/german
	name = "german webbing"
	icon_state = "german_vest"
	item_state = "german_vest"

/obj/item/clothing/accessory/storage/webbing/ww1/french
	name = "french webbing"
	icon_state = "french_vest"
	item_state = "french_vest"

/obj/item/clothing/accessory/storage/webbing/ww1/british
	name = "british webbing"
	icon_state = "british_vest"
	item_state = "british_vest"

/obj/item/clothing/accessory/storage/webbing/ww1/leather
	name = "leather webbing"
	icon_state = "british_vest"
	item_state = "british_vest"

/obj/item/clothing/accessory/armor/modern
	health = 20
/obj/item/clothing/accessory/armor/modern/plate
	name = "breastplate body armor"
	desc = "Wearable armor made of steel sheets."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "modern_platearmor"
	item_state = "modern_platearmor"
	worn_state = "modern_platearmor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 70, arrow = 95, gun = 45, energy = 15, bomb = 45, bio = 20, rad = 20)
	value = 50
	slowdown = 0.8

/obj/item/clothing/accessory/armor/modern/british
	name = "Dayfield body armor"
	desc = "British-made wearable armor made of steel sheets."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "modern_dayfield"
	item_state = "modern_dayfield"
	worn_state = "modern_dayfield"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 70, arrow = 90, gun = 40, energy = 12, bomb = 40, bio = 20, rad = 15)
	value = 50
	slowdown = 0.8

////////////////////////////////////
///////////////WW2//////////////////
////////////////////////////////////
/obj/item/clothing/under/ww2/german
	name = "german uniform"
	desc = "A german feldgrau uniform, used by the Wehrmacht."
	icon_state = "geruni_ww2"
	item_state = "geruni_ww2"
	worn_state = "geruni_ww2"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/german/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/german)
		return
	else
		if (rolled)
			item_state = "geruni_ww2"
			worn_state = "geruni_ww2"
			item_state_slots["slot_w_uniform"] = "geruni_ww2"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
		else if (!rolled)
			item_state = "geruni_ww2_rolled"
			worn_state = "geruni_ww2_rolled"
			item_state_slots["slot_w_uniform"] = "geruni_ww2_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
	update_clothing_icon()

/obj/item/clothing/under/ww2/german_doctor
	name = "german doctor uniform"
	desc = "A german feldgrau uniform, used by doctors in the Wehrmacht."
	icon_state = "geruni_doctor"
	item_state = "geruni_doctor"
	worn_state = "geruni_doctor"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/german_doctor/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/german_doctor)
		return
	else
		if (rolled)
			item_state = "geruni_doctor"
			worn_state = "geruni_doctor"
			item_state_slots["slot_w_uniform"] = "geruni_doctor"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
		else if (!rolled)
			item_state = "geruni_doctor_rolled"
			worn_state = "geruni_doctor_rolled"
			item_state_slots["slot_w_uniform"] = "geruni_doctor_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
	update_clothing_icon()

/obj/item/clothing/under/ww2/german_officer
	name = "german officer uniform"
	desc = "A german feldgrau uniform, used by officers in the Wehrmacht."
	icon_state = "geruni_officer"
	item_state = "geruni_officer"
	worn_state = "geruni_officer"

obj/item/clothing/under/ww2/german_tanker
	name = "german tanker uniform"
	desc = "A german feldgrau uniform, used by tankers in the Wehrmacht."
	icon_state = "gertanker"
	item_state = "gertanker"
	worn_state = "gertanker"

obj/item/clothing/under/ww2/german_mp
	name = "german mp uniform"
	desc = "A german feldgrau uniform, used by military police in the Wehrmacht."
	icon_state = "geruni_mp"
	item_state = "geruni_mp"
	worn_state = "geruni_mp"

obj/item/clothing/under/ww2/german_ss
	name = "german ss uniform"
	desc = "A german SS uniform, used by soldaten in the Schutzstaffel."
	icon_state = "ssuni"
	item_state = "ssuni"
	worn_state = "ssuni"

obj/item/clothing/under/ww2/german_ss_officer
	name = "german ss officer uniform"
	desc = "A german SS officer uniform, used by officers in the Schutzstaffel."
	icon_state = "ssuni_officer"
	item_state = "ssuni_officer"
	worn_state = "ssuni_officer"

obj/item/clothing/under/ww2/german_ss_camo
	name = "german camo ss uniform"
	desc = "A german SS uniform, in 1944 Erbsenmuster dot pattern."
	icon_state = "ssuni_camo"
	item_state = "ssuni_camo"
	worn_state = "ssuni_camo"

obj/item/clothing/under/ww2/soviet
	name = "soviet uniform"
	desc = "A soviet uniform, used by infantry in the red army."
	icon_state = "sovuni"
	item_state = "sovuni"
	worn_state = "sovuni"

obj/item/clothing/under/ww2/soviet_tanker
	name = "soviet tanker uniform"
	desc = "A soviet tanker uniform, used by tank crewmen in the red army."
	icon_state = "sovtanker"
	item_state = "sovtanker"
	worn_state = "sovtanker"

obj/item/clothing/under/ww2/soviet_officer
	name = "soviet officer uniform"
	desc = "A soviet officer uniform, used by officers in the red army."
	icon_state = "sovuni_officer"
	item_state = "sovuni_officer"
	worn_state = "sovuni_officer"

obj/item/clothing/under/ww2/soviet_nkvd
	name = "nkvd uniform"
	desc = "A soviet nkvd uniform, used by nkvd."
	icon_state = "nkvd_uni"
	item_state = "nkvd_uni"
	worn_state = "nkvd_uni"

obj/item/clothing/under/ww2/civ1
	name = "green civilian outfit"
	desc = "A mid 20th-century civilian outfit."
	icon_state = "ww2_civuni1"
	item_state = "ww2_civuni1"
	worn_state = "ww2_civuni1"

obj/item/clothing/under/ww2/civ2
	name = "brown civilian outfit"
	desc = "A mid 20th-century civilian outfit."
	icon_state = "ww2_civuni2"
	item_state = "ww2_civuni2"
	worn_state = "ww2_civuni2"

obj/item/clothing/under/ww2/hitlerjugend
	name = "Hitlerjugend outfit"
	desc = "The standard uniform of the HJ."
	icon_state = "hj_uni"
	icon_state = "hj_uni"
	icon_state = "hj_uni"

obj/item/clothing/under/ww2/us
	name = "american uniform"
	desc = "An american uniform, used by soldiers in the US army during WW2."
	icon_state = "usuni2"
	item_state = "usuni2"
	worn_state = "usuni2"

obj/item/clothing/under/ww2/us_cap
	name = "american captain uniform"
	desc = "An american uniform, used by captains in the US army."
	icon_state = "usuni_cap"
	item_state = "usuni_cap"
	worn_state = "usuni_cap"

obj/item/clothing/under/ww2/us_mp
	name = "american mp uniform"
	desc = "An american uniform, used by Military Police in the US army."
	icon_state = "usuni_mp"
	item_state = "usuni_mp"
	worn_state = "usuni_mp"

obj/item/clothing/under/ww2/us_shirtless
	name = "american uniform with shirt"
	desc = "An american uniform, used by soldiers in the US army, this one has no jacket."
	icon_state = "us_shirtless"
	item_state = "us_shirtless"
	worn_state = "us_shirtless"

/obj/item/clothing/suit/storage/coat/ww2/german
	name = "german parka"
	desc = "A german parka, worn by soldaten in the Wehrmacht."
	icon_state = "gerparka"
	item_state = "gerparka"
	worn_state = "gerparka"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65

/obj/item/clothing/suit/storage/coat/ww2/german/civ
	name = "grey parka"
	desc = "A grey parka, good for warmth in the winters."

/obj/item/clothing/suit/storage/coat/ww2/german_officer
	name = "german officer coat"
	desc = "A german officer's coat, worn by officers in the Wehrmacht."
	icon_state = "ger_offcoat"
	item_state = "ger_offcoat"
	worn_state = "ger_offcoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 100

/obj/item/clothing/suit/storage/coat/ww2/ss_parka
	name = "ss parka"
	desc = "A german ss parka, in 1944 Erbsenmuster dot camo, worn by soldaten in the Schutzstaffel."
	icon_state = "sssmock"
	item_state = "sssmock"
	worn_state = "sssmock"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65

/obj/item/clothing/suit/storage/coat/ww2/soviet
	name = "soviet coat"
	desc = "A soviet trenchcoat, worn by krasarmanev in the red army."
	icon_state = "ruscoat"
	item_state = "ruscoat"
	worn_state = "ruscoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65

/obj/item/clothing/suit/storage/coat/ww2/soviet_officer
	name = "soviet officer coat"
	desc = "A soviet trenchcoat, worn by officers in the red army."
	icon_state = "sov_offcoat"
	item_state = "sov_offcoat"
	worn_state = "sov_offcoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65

/obj/item/clothing/head/helmet/ww2/us_mp
	name = "us mp helmet"
	desc = "A typical rounded steel helmet. This one has the markings of MP on it."
	icon_state = "ushelmet_mp"
	item_state = "ushelmet_mp"
	worn_state = "ushelmet_mp"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

obj/item/clothing/head/ww2/us_nco_cap
	name = "us nco cap"
	desc = "A cap worn by american NCO's."
	icon_state = "usnco_cap"
	item_state = "usnco_cap"
	worn_state = "usnco_cap"

obj/item/clothing/head/ww2/german_tanker
	name = "german tanker headset"
	desc = "A cap and radio headset worn by german tank crewmen of the Wehrmacht."
	icon_state = "gertanker"
	item_state = "gertanker"
	worn_state = "gertanker"

obj/item/clothing/head/ww2/soviet_tanker
	name = "soviet tanker cap"
	desc = "A cap and worn by soviet tank crewmen of the red army."
	icon_state = "sovtanker"
	item_state = "sovtanker"
	worn_state = "sovtanker"

obj/item/clothing/head/ww2/ger_officercap
	name = "german officer cap"
	desc = "A cap and worn by german officers the Wehrmacht."
	icon_state = "ger_officercap"
	item_state = "ger_officercap"
	worn_state = "ger_officercap"

obj/item/clothing/head/ww2/sov_officercap
	name = "soviet officer cap"
	desc = "A cap and worn by soviet officers the red army."
	icon_state = "sov_officercap"
	item_state = "sov_officercap"
	worn_state = "sov_officercap"

obj/item/clothing/head/ww2/sov_pilotka
	name = "soviet pilotka"
	desc = "A cap and worn by soviet soldiers of the red army."
	icon_state = "sovpilotka"
	item_state = "sovpilotka"
	worn_state = "sovpilotka"

obj/item/clothing/head/ww2/sov_ushanka
	name = "soviet ushanka"
	desc = "A soviet ushanka, used by soldiers in the red army."
	icon_state = "ushanka"
	item_state = "ushanka"
	worn_state = "ushanka"

obj/item/clothing/head/ww2/sov_ushanka/attack_self(mob/user as mob)
	if (icon_state == "ushanka")
		icon_state = "ushanka_up"
		user << "You raise the ear flaps on the ushanka."
	else
		icon_state = "ushanka"
		user << "You lower the ear flaps on the ushanka."

obj/item/clothing/head/ww2/nkvd_cap
	name = "NKVD cap"
	desc = "A cap and worn by NKVD."
	icon_state = "nkvd_cap"
	item_state = "nkvd_cap"
	worn_state = "nkvd_cap"

obj/item/clothing/head/ww2/ss_cap
	name = "SS cap"
	desc = "A cap and worn by officers in the Schutzstaffel."
	icon_state = "sscap"
	item_state = "sscap"
	worn_state = "sscap"

obj/item/clothing/head/ww2/german_fieldcap
	name = "german field cap"
	desc = "A cap and worn by german Wehrmacht."
	icon_state = "fieldcap1"
	item_state = "fieldcap1"
	worn_state = "fieldcap1"

obj/item/clothing/head/ww2/soviet_fieldcap
	name = "soviet field cap"
	desc = "A cap and worn by soviets in the red army."
	icon_state = "fieldcap2"
	item_state = "fieldcap2"
	worn_state = "fieldcap2"

/obj/item/clothing/head/helmet/ww2/gerhelm
	name = "german stahlhelm"
	desc = "The typical rounded steel helmet of the Wehrmacht"
	icon_state = "stahlhelm"
	item_state = "stahlhelm"
	worn_state = "stahlhelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/gerhelm_medic
	name = "german medic stahlhelm"
	desc = "The typical rounded steel helmet of the Wehrmacht, this one belonging to a medic."
	icon_state = "gerhelm_medic"
	item_state = "gerhelm_medic"
	worn_state = "gerhelm_medic"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/ss
	name = "german ss helmet"
	desc = "The typical rounded steel helmet of the Schutzstaffel."
	icon_state = "sshelm"
	item_state = "sshelm"
	worn_state = "sshelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 42, arrow = 32, gun = 12, energy = 15, bomb = 42, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/soviet
	name = "soviet helmet"
	desc = "The typical rounded steel helmet of the red army."
	icon_state = "sovhelm"
	item_state = "sovhelm"
	worn_state = "sovhelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us
	name = "american helmet"
	desc = "The typical rounded steel helmet of the US Army."
	icon_state = "ushelmet"
	item_state = "ushelmet"
	worn_state = "ushelmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_medic
	name = "american medic helmet"
	desc = "The typical rounded steel helmet of the US Army, this one bearing a medic symbol."
	icon_state = "ushelmet_medical"
	item_state = "ushelmet_medical"
	worn_state = "ushelmet_medical"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_sgt
	name = "american sergeant helmet"
	desc = "The typical rounded steel helmet of the US Army, this one bearing the rank of Sergeant."
	icon_state = "ushelmet_sgt"
	item_state = "ushelmet_sgt"
	worn_state = "ushelmet_sgt"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_lt
	name = "american lieutenant helmet"
	desc = "The typical rounded steel helmet of the US Army, this one bearing the rank of Lieutenant."
	icon_state = "ushelmet_lt"
	item_state = "ushelmet_lt"
	worn_state = "ushelmet_lt"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_cap
	name = "american captain helmet"
	desc = "The typical rounded steel helmet of the US Army, this one bearing the rank of Captain."
	icon_state = "ushelmet_cap"
	item_state = "ushelmet_cap"
	worn_state = "ushelmet_cap"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_mar
	name = "USMC helmet"
	desc = "The typical rounded steel helmet of the USMC."
	icon_state = "ushelmet_mar"
	item_state = "ushelmet_mar"
	worn_state = "ushelmet_mar"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_mar_sgt
	name = "USMC sergeant helmet"
	desc = "The typical rounded steel helmet of the USMC, this one bearing the rank of Sergeant."
	icon_state = "ushelmet_mar_nco"
	item_state = "ushelmet_mar_nco"
	worn_state = "ushelmet_mar_nco"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/soviet_medic
	name = "soviet medical helmet"
	desc = "The typical rounded steel helmet of the red army, with the white markings of the medical corps."
	icon_state = "sovhelm_medic"
	item_state = "sovhelm_medic"
	worn_state = "sovhelm_medic"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/accessory/armband/redcross
	name = "red cross armband"
	desc = "A white armband with the red cross in it."
	icon_state = "redcross"
	slot = "armband"

/obj/item/clothing/accessory/armband/nsdap
	name = "NSDAP armband"
	desc = "A red armband with the swastika on it."
	icon_state = "nsdap"
	slot = "armband"

/obj/item/clothing/accessory/armband/kenpeitai
	name = "Kenpeitai armband"
	desc = "A white armband with red japanese characters on it."
	icon_state = "japanesemp"
	slot = "armband"

/obj/item/clothing/accessory/armband/usmp
	name = "military police armband"
	desc = "A black armband with \"MP\" written on it."
	icon_state = "usmp"
	slot = "armband"

/obj/item/clothing/accessory/armband/volkssturm
	name = "Volkssturm armband"
	desc = "A red, white and black armband of the Volkssturm"
	icon_state = "volkssturm"
	slot = "armband"