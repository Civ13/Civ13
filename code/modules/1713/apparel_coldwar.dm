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
   14 - Astronaut Suit and Helmet
   15 - Miscallaneous
   15a - John Toughguy - Jungle Commando
   15b - Swinging Sixties
   15c - Other Miscallaneous */

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

/obj/item/clothing/suit/storage/jacket/afghanka
	name = "afghanka coat"
	desc = "A soviet winter jacket issued and developped in the early 80's."
	icon_state = "rus_winter_afghanka"
	item_state = "rus_winter_afghanka"
	worn_state = "rus_winter_afghanka"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|ARM_LEFT|ARM_RIGHT
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

/obj/item/clothing/suit/storage/atf
	name = "ATF jacket"
	desc = "An ATF jacket, standard issue for ATF agents."
	icon_state = "atf"
	item_state = "atf"
	worn_state = "atf"

/obj/item/clothing/suit/storage/dea
	name = "DEA jacket"
	desc = "A DEA jacket, standard issue for DEA agents."
	icon_state = "dea"
	item_state = "dea"
	worn_state = "dea"

/obj/item/clothing/suit/storage/jacket/forensics
	name = "forensics jacket"
	desc = "A forensic department jacket."
	icon_state = "forensics"
	item_state = "forensics"
	worn_state = "forensics"

/obj/item/clothing/suit/storage/jacket/police
	name = "police jacket"
	desc = "A police jacket."
	icon_state = "policejacket"
	item_state = "policejacket"
	worn_state = "policejacket"
	var/closed = TRUE

/obj/item/clothing/suit/storage/jacket/police/New()
	..()
	if (map.ID == MAP_THE_ART_OF_THE_DEAL)
		name = "sheriff's office jacket"

/obj/item/clothing/suit/storage/jacket/police/verb/toggle()
	set category = null
	set src in usr
	set name = "Adjust jacket"
	if (type != /obj/item/clothing/suit/storage/jacket/police)
		return
	else
		if(closed)
			worn_state = "policejacket_open"
			item_state = "policejacket_open"
			icon_state = "policejacket_open"
			item_state_slots["w_uniform"] = "policejacket_open"
			usr << "You <b>open up</b> your jacket."
			closed = FALSE
			update_clothing_icon()
		else if (!closed)
			worn_state = "policejacket"
			item_state = "policejacket"
			icon_state = "policejacket"
			item_state_slots["w_uniform"] = "policejacket"
			usr << "You <b>close up</b> your jacket."
			closed = TRUE
			update_clothing_icon()

/obj/item/clothing/suit/storage/jacket/police/black
	name = "police jacket"
	desc = "A black police jacket."
	icon_state = "policejacket_black"
	item_state = "policejacket_black"
	worn_state = "policejacket_black"
	closed = TRUE

/obj/item/clothing/suit/storage/jacket/police/black/toggle()
	set category = null
	set src in usr
	set name = "Adjust jacket"
	if (type != /obj/item/clothing/suit/storage/jacket/police/black)
		return
	else
		if(closed)
			worn_state = "policejacket_black_open"
			item_state = "policejacket_black_open"
			icon_state = "policejacket_black_open"
			item_state_slots["w_uniform"] = "policejacket_open"
			usr << "You <b>open up</b> your jacket."
			closed = FALSE
			update_clothing_icon()
		else if (!closed)
			worn_state = "policejacket_black"
			item_state = "policejacket_black"
			icon_state = "policejacket_black"
			item_state_slots["w_uniform"] = "policejacket_black"
			usr << "You <b>close up</b> your jacket."
			closed = TRUE
			update_clothing_icon()

/obj/item/clothing/suit/swat //these likely need upgrading to armor
	name = "swat heavy vest"
	desc = "A heavy NIJ level IV vest, used by swat officers."
	icon_state = "swat"
	item_state = "swat"
	worn_state = "swat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 80, arrow = 80, gun = 90, energy = 40, bomb = 20, bio = 44, rad = 40)
	var/slots = 6
	ripable = FALSE
	flags = CONDUCT

/obj/item/clothing/suit/swat_new
	name = "swat bulletproof vest"
	desc = "A heavy NIJ level IV vest, used by swat officers."
	icon_state = "policevest"
	item_state = "policevest"
	worn_state = "policevest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 80, arrow = 80, gun = 90, energy = 40, bomb = 20, bio = 44, rad = 40)
	var/slots = 6
	ripable = FALSE
	ripable = FALSE

/obj/item/clothing/suit/police
	name = "police bulletproof vest"
	desc = "A police vest (Level III)."
	icon_state = "policevest"
	item_state = "policevest"
	worn_state = "policevest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 20, gun = 74, energy = 40, bomb = 20, bio = 32, rad = 20)
	var/slots = 3
	ripable = FALSE

/obj/item/clothing/under/traffic_police
	name = "police outfit"
	desc = "An outfit composed of a blue emergency services shirt and denim trousers. It has a police badge attached"
	icon_state = "traffic_cop"
	item_state = "traffic_cop"
	worn_state = "traffic_cop"

/obj/item/clothing/under/traffic_police/supervisor
	name = "police supervisor outfit"
	desc = "An outfit composed of a blue emergency services shirt and denim trousers. It has a police supervisor badge attached"
	icon_state = "traffic_cop_sup"
	item_state = "traffic_cop_sup"
	worn_state = "traffic_cop_sup"

/obj/item/clothing/under/countysheriff
	name = "sheriff's department sheriff outfit"
	desc = "A law enforcement outfit worn by the town's sherrif."
	icon_state = "sd_sheriff"
	item_state = "sd_sheriff"
	worn_state = "sd_sheriff"

/obj/item/clothing/under/countysheriff/deputy
	name = "sheriff's department deputy outfit"
	desc = "A law enforcement outfit worn by the town's deputies."
	icon_state = "sd_deputy"
	item_state = "sd_deputy"
	worn_state = "sd_deputy"

/obj/item/clothing/under/countysheriff/deputy/short
	name = "sheriff's department deputy outfit"
	desc = "A law enforcement outfit worn by the town's deputies. Short sleeved version."
	icon_state = "sd_deputy_shortsleeves"
	item_state = "sd_deputy_shortsleeves"
	worn_state = "sd_deputy_shortsleeves"

/obj/item/clothing/head/countysheriff_hat
	name = "sheriff's stratton hat"
	desc = "A stratton hat worn by the LEOs of the town's Sheriff Department."
	icon_state = "sd_sheriffhat"
	item_state = "sd_sheriffhat"
	worn_state = "sd_sheriffhat"

/obj/item/clothing/head/countysheriff_cap
	name = "sheriff's department cap"
	desc = "A baseball cap worn by the LEOs of the town's Sheriff Department."
	icon_state = "sd_cap"
	item_state = "sd_cap"
	worn_state = "sd_cap"

/obj/item/clothing/head/countysheriff_cap/black
	name = "sheriff's department cap"
	desc = "A baseball cap worn by the LEOs of the town's Sheriff Department. Black version."
	icon_state = "sd_cap_black"
	item_state = "sd_cap_black"
	worn_state = "sd_cap_black"

/obj/item/clothing/head/traffic_police
	name = "police cap"
	desc = "A blue cap often worn by members of the police and security guards."
	icon_state = "traffic_cop"
	item_state = "traffic_cop"
	worn_state = "traffic_cop"

/obj/item/clothing/head/beret_red
	name = "red beret"
	desc = "A red beret."
	icon_state = "beret_red"
	item_state = "beret_red"
	body_parts_covered = HEAD

/obj/item/clothing/head/beret_black
	name = "black beret"
	desc = "A black military beret."
	icon_state = "beret_black"
	item_state = "beret_black"
	body_parts_covered = HEAD

/obj/item/clothing/head/beret_black/insig
	name = "black beret"
	desc = "A black beret with golden insignia."
	icon_state = "beret_black_insig"
	item_state = "beret_black_insig"
	body_parts_covered = HEAD

/obj/item/clothing/head/beret_green
	name = "green beret"
	desc = "A green beret."
	icon_state = "beret_green"
	item_state = "beret_green"
	body_parts_covered = HEAD

/obj/item/clothing/head/beret_green/insig
	name = "green beret"
	desc = "A green beret with golden insignia."
	icon_state = "beret_green_insig"
	item_state = "beret_green_insig"
	body_parts_covered = HEAD

/* US Army Clothes*/

/obj/item/clothing/under/us_uni
	name = "OG-107 uniform"
	desc = "The standard US Army uniform of the mid-20th century."
	icon_state = "us_uni_og107"
	item_state = "us_uni_og107"
	worn_state = "us_uni_og107"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_camo
	name = "woodland camo uniform"
	desc = "The standard US Army camo uniform implemented in the early 1980s. Still used during the present day by many countries."
	icon_state = "us_camo"
	item_state = "us_camo"
	worn_state = "us_camo"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/us_uni/us_greentrousers
	name = "OG-107 trousers"
	desc = "The standard US Army OG-107 uniform trousers."
	icon_state = "us_greentrousers_og107"
	item_state = "us_greentrousers_og107"
	worn_state = "us_greentrousers_og107"
	body_parts_covered = LOWER_TORSO|LEGS

/obj/item/clothing/under/us_uni/us_lightuni
	name = "OG-107 uniform with rolled sleeves"
	desc = "A rolled-sleeves version of the US Army OG-107 uniform."
	icon_state = "us_uni_og107_rolled"
	item_state = "us_uni_og107_rolled"
	worn_state = "us_uni_og107_rolled"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS

/obj/item/clothing/under/us_uni/us_lightuni2
	name = "OG-107 trousers and khaki undershirt"
	desc = "A light version of the US Army OG-107 trousers and the service khaki undershirt."
	icon_state = "us_og107_lightuni"
	item_state = "us_og107_lightuni"
	worn_state = "us_og107_lightuni"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS

/obj/item/clothing/under/us_uni/us_lightuni3
	name = "OG-107 trousers and white undershirt"
	desc = "A light version of the US Army OG-107 trousers and the service white untucked undershirt."
	icon_state = "us_og107_lightuni2"
	item_state = "us_og107_lightuni2"
	worn_state = "us_og107_lightuni2"
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

/obj/item/clothing/head/helmet/modern/ushelmet/un
	name = "UN helmet"
	desc = "A typical blue UN helmet."
	icon_state = "unitednations"
	item_state = "unitednations"
	worn_state = "unitednations"
	flash_protection = FLASH_PROTECTION_MODERATE
/obj/item/clothing/head/helmet/modern/ushelmet/un/medic
	name = "UN medic helmet"
	desc = "A typical blue UN helmet, with doctor markings."
	icon_state = "unitednations_medic"
	item_state = "unitednations_medic"
	worn_state = "unitednations_medic"
/obj/item/clothing/head/un_beret
	name = "UN beret"
	desc = "A blue UN beret."
	icon_state = "unitednations_beret"
	item_state = "unitednations_beret"
	worn_state = "unitednations_beret"

/obj/item/clothing/head/helmet/modern/ushelmet/sgt
	name = "M1 helmet 2nd LT"
	desc = "A typical us army helmet. With lieutenant markings."
	icon_state = "m1_2nd_lt"
	item_state = "m1_2nd_lt"
	worn_state = "m1_2nd_lt"

/obj/item/clothing/head/helmet/modern/ushelmet/lt
	name = "M1 helmet 1st LT"
	desc = "A typical US Army helmet. With lieutenant markings."
	icon_state = "m1_1st_lt"
	item_state = "m1_1st_lt"
	worn_state = "m1_1st_lt"

/obj/item/clothing/head/helmet/modern/ushelmet/camo
	name = "M1 camo helmet"
	desc = "A typical US Army helmet. With a Mitchell camo cover."
	icon_state = "m1_camo_mitchell"
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

/obj/item/clothing/head/helmet/modern/ushelmet/camo/lt
	name = "M1 camo helmet"
	desc = "A typical US Army helmet. With a Mitchell camo cover."
	icon_state = "m1_camo_mitchell_lt"
	item_state = "ushelmet_camo_lt"
	worn_state = "ushelmet_camo_lt"

/obj/item/clothing/head/helmet/modern/ushelmet/crewman
	name = "CVC helmet"
	desc = "A standard issue helmet for vehicle crewmen."
	icon_state = "cvc_helmet"
	item_state = "cvc_helmet"
	worn_state = "cvc_helmet"

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

/obj/item/clothing/suit/storage/ghillie/winter
	name = "winter ghillie suit"
	desc = "A camo winter ghillie suit."
	icon_state = "ghillie_winter"
	item_state = "ghillie_winter"
	worn_state = "ghillie_winter"

/obj/item/clothing/head/ghillie/winter
	name = "winter ghillie headcover"
	desc = "A headcover for a winter ghillie suit."
	icon_state = "ghillie_winter"
	item_state = "ghillie_winter"

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

/obj/item/clothing/head/jungle_hat/og107
	name = "olive green boonie"
	desc = "A wide brim, soft jungle hat."
	icon_state = "og107_boonie"
	item_state = "og107_boonie"
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

/obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized
	name = "Chinese helmet"
	desc = "A steel helmet used by the People's Liberation Army."
	icon_state = "chi_korea_helm"
	item_state = "chi_korea_helm"
	worn_state = "chi_korea_helm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 35, energy = 25, bomb = 55, bio = 20, rad = FALSE)
	health = 100

/obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized/winter
	name = "White Chinese helmet"
	icon_state = "chi_whitehelm"
	item_state = "chi_whitehelm"
	worn_state = "chi_whitehelm"

/obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized/med
	name = "Medical Chinese helmet"
	desc = "A steel helmet used by the medics in the People's Liberation Army."
	icon_state = "chi_med"
	item_state = "chi_med"
	worn_state = "chi_med"

/obj/item/clothing/head/nva_hat
	name = "NVA cap"
	desc = "A field cap with the markings of an NVA officer."
	icon_state = "nva_off_cap"
	item_state = "nva_off_cap"
	body_parts_covered = HEAD

/obj/item/clothing/head/sov_ushanka_new
	name = "soviet ushanka"
	desc = "A soviet ushanka, used by soldiers in the Red Army."
	icon_state = "ushanka_new_up"
	item_state = "ushanka_new_up"
	worn_state = "ushanka_new_up"
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/head/sov_ushanka_new/down
	icon_state = "ushanka_new"
	item_state = "ushanka_new"
	worn_state = "ushanka_new"

/obj/item/clothing/head/sov_ushanka_new/attack_self(mob/user as mob)
	if (icon_state == "ushanka_new")
		icon_state = "ushanka_new_up"
		item_state = "ushanka_new_up"
		user << "You raise the ear flaps on the ushanka."
	else
		icon_state = "ushanka_new"
		item_state = "ushanka_new"
		user << "You lower the ear flaps on the ushanka."

/obj/item/clothing/head/ww2/nkvd_cap/kgb
	name = "KGB cap"
	desc = "A cap worn by KGB."
	icon_state = "nkvd_cap"
	item_state = "nkvd_cap"
	worn_state = "nkvd_cap"

/obj/item/clothing/head/coldwar/soviet_officer
	name = "soviet officer cap"
	desc = "A cap worn by Soviet officers."
	icon_state = "sov_officercap2"
	item_state = "sov_officercap2"
	worn_state = "sov_officercap2"

/obj/item/clothing/head/fieldcap/afghanka
	name = "Afghanka field cap"
	desc = "A field cap issued to Soviet forces in the 1980s."
	icon_state = "fieldcap_afghanka"
	item_state = "fieldcap_afghanka"
	worn_state = "fieldcap_afghanka"
	body_parts_covered = HEAD

/obj/item/clothing/head/beret_rus_vdv
	name = "VDV beret"
	desc = "A beret worn by the Russian Airborn Forces."
	icon_state = "beret_rus_vdv"
	item_state = "beret_rus_vdv"
	body_parts_covered = HEAD

/obj/item/clothing/head/beret_rus_spez
	name = "Spetznaz beret"
	desc = "A beret worn by the Spetznaz."
	icon_state = "beret_rus_spez"
	item_state = "beret_rus_spez"
	body_parts_covered = HEAD

/obj/item/clothing/head/beret_blugoslavia
	name = "Blugoslavian beret"
	desc = "A beret worn by Blugoslavian Officers."
	icon_state = "beret_rus_vdv"
	item_state = "beret_rus_vdv"
	body_parts_covered = HEAD

/obj/item/clothing/head/beret_redmenia
	name = "Redmenian beret"
	desc = "A beret worn by Redmenian Officers."
	icon_state = "beret_rus_spez"
	item_state = "beret_rus_spez"
	body_parts_covered = HEAD

/obj/item/clothing/head/cap_blugoslavia
	name = "Blugoslavian navy cap"
	desc = "A cap worn by Blugoslavian Officers of the Blugoslavian Naval Force."
	icon_state = "blugoslavia_cap"
	item_state = "blugoslavia_cap"
	body_parts_covered = HEAD

/obj/item/clothing/head/cap_redmenia
	name = "Redmenian navy cap"
	desc = "A cap worn by Redmenian Officers of the Imperial Redmenian Navy."
	icon_state = "redmenia_cap"
	item_state = "redmenia_cap"
	body_parts_covered = HEAD

/obj/item/clothing/head/ww2/us_sailor_hat/blugoslavia
	name = "Blugoslavian sailor hat"
	desc = "A hat worn by sailors of the Blugoslavian Naval Force."
	icon_state = "upapilotka"
	item_state = "upapilotka"
	worn_state = "upapilotka"
/obj/item/clothing/head/ww2/us_sailor_hat/redmenia
	name = "Redmenian sailor hat"
	desc = "A hat worn by sailors of the Imperial Redmenian Navy."

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
	desc = "A green chest-level webbing with multiple small-sized pouches."
	slots = 8
	icon_state = "nlfchestrig_v2"
	item_state = "nlfchestrig_v2"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,
			/obj/item/weapon/key,
			/obj/item/ammo_casing,
			/obj/item/ammo_magazine,
			/obj/item/weapon/grenade,
			/obj/item/weapon/attachment,
			/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/nlfsmallpouches/filled_sks/New()
	..()
	for (var/i=1; i <= 7; i++)
		new /obj/item/ammo_magazine/sks(hold)
	new /obj/item/stack/medical/bruise_pack/bint(hold)
/obj/item/clothing/accessory/storage/webbing/nlfsmallpouches/filled_mosin/New()
	..()
	for (var/i=1; i <= 7; i++)
		new /obj/item/ammo_magazine/mosin(hold)
	new /obj/item/stack/medical/bruise_pack/bint(hold)

/obj/item/clothing/accessory/storage/webbing/nlfchestrig
	name = "NLF chestrig"
	desc = "A green chest-level webbing, with three medium-sized pouches along with two smaller ones."
	slots = 5
	icon_state = "nlfchestrig_v1"
	item_state = "nlfchestrig_v1"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,
			/obj/item/weapon/key,
			/obj/item/ammo_casing,
			/obj/item/ammo_magazine,
			/obj/item/weapon/grenade,
			/obj/item/weapon/attachment,
			/obj/item/weapon/gun/projectile/pistol,
			/obj/item/weapon/gun/projectile/revolver,
			/obj/item/weapon/handcuffs,
			/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
			/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/nlfchestrig/filled_akm/New()
	..()
	for (var/i=1; i <= 3; i++)
		new /obj/item/ammo_magazine/ak47(hold)
	new /obj/item/stack/medical/bruise_pack/bint(hold)
	if (prob(50))
		new /obj/item/weapon/grenade/smokebomb/rdg2(hold)
	else
		new /obj/item/weapon/grenade/modern/f1(hold)

/obj/item/clothing/under/nva
	name = "NVA uniform"
	desc = "A khaki uniform of the North Vietnamese Army."
	icon_state = "NVAuni"
	item_state = "NVAuni"
	worn_state = "NVAuni"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
/obj/item/clothing/under/nva/green
	desc = "A green uniform of the North Vietnamese Army."
	icon_state = "NVAuni_green"
	item_state = "NVAuni_green"
	worn_state = "NVAuni_green"
/obj/item/clothing/under/nva/sl
	name = "NVA sergeant uniform"
	desc = "A khaki uniform of the North Vietnamese Army. This one is bearing the ranks of a sergeant."
	icon_state = "NVAuni_sl"
	item_state = "NVAuni_sl"
	worn_state = "NVAuni_sl"
/obj/item/clothing/under/nva/sl/green
	desc = "A green uniform of the North Vietnamese Army. This one is bearing the ranks of a sergeant."
	icon_state = "NVAuni_green_sl"
	item_state = "NVAuni_green_sl"
	worn_state = "NVAuni_green_sl"
/obj/item/clothing/under/nva/officer
	name = "NVA officer uniform"
	desc = "A khaki uniform of the North Vietnamese Army. This one is bearing the ranks of an officer"
	icon_state = "NVAuni_off"
	item_state = "NVAuni_off"
	worn_state = "NVAuni_off"
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
	armor = list(melee = 55, arrow = 75, gun = 40, energy = 24, bomb = 66, bio = 25, rad = FALSE)

/obj/item/clothing/head/helmet/modern/ssh_68/med
	icon_state = "ssh_68med"
	item_state = "ssh_68med"
	worn_state = "ssh_68med"

/obj/item/clothing/head/helmet/modern/ssh_68/winter
	icon_state = "ssh_68_winter"
	item_state = "ssh_68_winter"
	worn_state = "ssh_68_winter"

/obj/item/clothing/head/helmet/modern/ssh_68/winter/med
	icon_state = "ssh_68wintmed"
	item_state = "ssh_68wintmed"
	worn_state = "ssh_68wintmed"

/obj/item/clothing/suit/b3 //need checking these assets before path name change, but i've updated the name to a real B3 russian armor circa 1980's
	name = "6B3 body armor"
	desc = "A ballistic vest of Soviet origin, issued in the mid 1980s."
	icon_state = "6b3"
	item_state = "6b3"
	worn_state = "6b3"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|FEET|HANDS
	armor = list(melee = 67, arrow = 95, gun = 60, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	ripable = FALSE
	flags = CONDUCT

/obj/item/clothing/accessory/armor/coldwar/plates/b3 //Accessory version
	name = "6B3 body armor"
	desc = "A ballistic vest of Soviet origin, issued in the mid 1980s."
	icon_state = "6b3"
	item_state = "6b3"
	worn_state = "6b3"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 67, arrow = 95, gun = 60, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	ripable = FALSE
	flags = CONDUCT
	slots = 2
	slowdown = 0.1

/obj/item/clothing/accessory/armor/coldwar/plates/b3/blue
	name = "6B3 Blue body armor"
	icon_state = "6b3blu"
	item_state = "6b3blu"
	worn_state = "6b3blu"

/obj/item/clothing/accessory/armor/coldwar/plates/b3/camo //uses civ grass tiles, provides alot more camo
	name = "6B3 green camo body armor"
	icon_state = "6b3cam"
	item_state = "6b3cam"
	worn_state = "6b3cam"

/obj/item/clothing/accessory/armor/coldwar/plates/b2
	name = "6B2 body armor"
	desc = "A ballistic vest of Soviet origin, issued in the early 1980s."
	icon_state = "6b2"
	item_state = "6b2"
	worn_state = "6b2"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 67, arrow = 95, gun = 30, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	ripable = FALSE
	flags = CONDUCT
	slowdown = 0.2

/obj/item/clothing/accessory/armor/coldwar/plates/b5
	name = "6B5 body armor"
	desc = "A ballistic vest of Soviet origin, issued in the late 1980s."
	icon_state = "6b5"
	item_state = "6b5"
	worn_state = "6b5"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 70, arrow = 95, gun = 70, energy = 30, bomb = 70, bio = 20, rad = FALSE)
	ripable = FALSE
	flags = CONDUCT
	slots = 2
	slowdown = 0.1

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

/obj/item/weapon/storage/belt/largepouches/olive/m60
/obj/item/weapon/storage/belt/largepouches/olive/m60/New()
	..()
	new/obj/item/ammo_magazine/b762(src)
	new/obj/item/ammo_magazine/b762(src)

/obj/item/weapon/storage/belt/largepouches/olive/madsen
/obj/item/weapon/storage/belt/largepouches/olive/madsen/New()
	..()
	new/obj/item/ammo_magazine/madsen(src)
	new/obj/item/ammo_magazine/madsen(src)
/obj/item/weapon/storage/belt/largepouches/m249
/obj/item/weapon/storage/belt/largepouches/m249/New()
	..()
	new/obj/item/ammo_magazine/m249(src)
	new/obj/item/ammo_magazine/m249(src)

/obj/item/weapon/storage/belt/largepouches/green/m249
/obj/item/weapon/storage/belt/largepouches/green/m249/New()
	..()
	new/obj/item/ammo_magazine/m249(src)
	new/obj/item/ammo_magazine/m249(src)

/obj/item/weapon/storage/belt/largepouches/sovietmg
/obj/item/weapon/storage/belt/largepouches/sovietmg/New()
	..()
	new/obj/item/ammo_magazine/dp(src)
	new/obj/item/ammo_magazine/dp(src)

/obj/item/weapon/storage/belt/largepouches/sovietmg/white
	icon_state = "largepouches_white"
	item_state = "largepouches_white"

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

/obj/item/weapon/storage/belt/destructionpouch
/obj/item/weapon/storage/belt/destructionpouch/New()
	..()
	new /obj/item/weapon/grenade/smokebomb(src)
	new /obj/item/weapon/grenade/antitank/stg24_bundle(src)
	new /obj/item/weapon/grenade/antitank/stg24_bundle(src)
	new /obj/item/weapon/grenade/antitank/stg24_bundle(src)
	new /obj/item/weapon/grenade/ww2/stg1924(src)
	new /obj/item/weapon/grenade/ww2/stg1924(src)

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

/obj/item/weapon/storage/belt/smallpouches/us_stanag
/obj/item/weapon/storage/belt/smallpouches/us_stanag/New()
	..()
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/un_fal
/obj/item/weapon/storage/belt/smallpouches/un_fal/New()
	..()
	new /obj/item/ammo_magazine/fal(src)
	new /obj/item/ammo_magazine/fal(src)
	new /obj/item/ammo_magazine/fal(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/sov_74
/obj/item/weapon/storage/belt/smallpouches/green/sov_74/New()
	..()
	new /obj/item/weapon/grenade/chemical/xylyl_bromide(src)
	new /obj/item/ammo_magazine/ak74(src)
	new /obj/item/ammo_magazine/ak74(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt
/obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt/New()
	..()
	new /obj/item/weapon/grenade/coldwar/rgd5(src)
	new /obj/item/ammo_magazine/ak74(src)
	new /obj/item/ammo_magazine/ak74(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/rpk74
/obj/item/weapon/storage/belt/smallpouches/green/rpk74/New()
	..()
	new/obj/item/ammo_magazine/rpk74(src)
	new/obj/item/ammo_magazine/rpk74(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)
	new /obj/item/weapon/grenade/coldwar/rgd5(src)

/obj/item/weapon/storage/belt/smallpouches/green/sov_74m
/obj/item/weapon/storage/belt/smallpouches/green/sov_74m/New()
	..()
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/sov_svd
/obj/item/weapon/storage/belt/smallpouches/green/sov_svd/New()
	..()
	new /obj/item/weapon/grenade/smokebomb/rdg2(src)
	new /obj/item/ammo_magazine/svd(src)
	new /obj/item/ammo_magazine/svd(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/sov_vintorez
/obj/item/weapon/storage/belt/smallpouches/green/sov_vintorez/New()
	..()
	new /obj/item/weapon/grenade/smokebomb/rdg2(src)
	new /obj/item/ammo_magazine/vintorez(src)
	new /obj/item/ammo_magazine/vintorez(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/sov_saiga
/obj/item/weapon/storage/belt/smallpouches/green/sov_saiga/New()
	storage_slots = 5
	..()
	new /obj/item/weapon/grenade/coldwar/rgd5(src)
	new /obj/item/ammo_magazine/saiga12(src)
	new /obj/item/ammo_magazine/saiga12(src)
	new /obj/item/ammo_magazine/saiga12(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/sov_swat
/obj/item/weapon/storage/belt/smallpouches/green/sov_swat/New()
	storage_slots = 6
	..()
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/ammo_magazine/makarov(src)
	new /obj/item/weapon/grenade/chemical/xylyl_bromide(src)
	new /obj/item/weapon/grenade/chemical/xylyl_bromide(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/sov_spz
/obj/item/weapon/storage/belt/smallpouches/green/sov_spz/New()
	storage_slots = 6
	..()
	new /obj/item/weapon/grenade/antitank/rpg40(src)
	new /obj/item/weapon/grenade/modern/f1(src)
	new /obj/item/weapon/grenade/chemical/xylyl_bromide(src)
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/ammo_magazine/ak74/ak74m(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/ak74
/obj/item/weapon/storage/belt/smallpouches/green/ak74/New()
	..()
	new /obj/item/ammo_magazine/ak74(src)
	new /obj/item/ammo_magazine/ak74(src)
	new /obj/item/ammo_magazine/ak74(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/ak47
/obj/item/weapon/storage/belt/smallpouches/green/ak47/New()
	..()
	new /obj/item/ammo_magazine/ak47(src)
	new /obj/item/ammo_magazine/ak47(src)
	new /obj/item/ammo_magazine/ak47(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/stanag
/obj/item/weapon/storage/belt/smallpouches/green/stanag/New()
	..()
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/ammo_magazine/m16(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/green/m14
/obj/item/weapon/storage/belt/smallpouches/green/m14/New()
	..()
	new /obj/item/weapon/grenade/smokebomb(src)
	new /obj/item/ammo_magazine/m14(src)
	new /obj/item/ammo_magazine/m14(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/* PLA Belts */
/obj/item/weapon/storage/belt/smallpouches/china_qbz95
/obj/item/weapon/storage/belt/smallpouches/china_qbz95/New()
	..()
	new /obj/item/ammo_magazine/qbz95(src)
	new /obj/item/ammo_magazine/qbz95(src)
	new /obj/item/ammo_magazine/qbz95(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/china_qbza95_2
/obj/item/weapon/storage/belt/smallpouches/china_qbz95_2/New()
	..()
	new /obj/item/ammo_magazine/qbz95(src)
	new /obj/item/ammo_magazine/qbz95(src)
	new /obj/item/weapon/grenade/coldwar/rgd5(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/china_qblz1
/obj/item/weapon/storage/belt/smallpouches/china_qblz1/New()
	..()
	new /obj/item/ammo_magazine/tibannagas/qblz1(src)
	new /obj/item/ammo_magazine/tibannagas/qblz1(src)
	new /obj/item/weapon/pill_pack/tramadol(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/china_qbz95_officer
/obj/item/weapon/storage/belt/smallpouches/china_qbz95_officer/New()
	..()
	new /obj/item/ammo_magazine/qbz95(src)
	new /obj/item/ammo_magazine/qbz95(src)
	new /obj/item/weapon/pill_pack/tramadol(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/mk18
/obj/item/weapon/storage/belt/smallpouches/mk18/New()
	..()
	new /obj/item/ammo_magazine/mk18(src)
	new /obj/item/ammo_magazine/mk18(src)
	new /obj/item/weapon/pill_pack/tramadol(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/p90
/obj/item/weapon/storage/belt/smallpouches/p90/New()
	new /obj/item/ammo_magazine/p90(src)
	new /obj/item/ammo_magazine/p90(src)
	new /obj/item/weapon/grenade/smokebomb(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)

/obj/item/weapon/storage/belt/smallpouches/sten
/obj/item/weapon/storage/belt/smallpouches/sten/New()
	new /obj/item/ammo_magazine/sten2(src)
	new /obj/item/ammo_magazine/sten2(src)
	new /obj/item/weapon/grenade/smokebomb/m18smoke(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)
/* Cold War Balaclavas*/

/obj/item/clothing/mask/balaclava
	name = "black balaclava"
	desc = "A black balaclava, covering the face."
	icon_state = "balaclava"
	item_state = "balaclava"
	worn_state = "balaclava"
	body_parts_covered = FACE|EYES|HEAD
	flags_inv = HIDEFACE
	w_class = ITEM_SIZE_TINY
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/mask/headscarfgrey ////German Toque head scarf Issued to soldiers during WW2 to wear as a neck warmer
	name = "grey headscarf"
	desc = "A headscarf,it protects your face from the cold."
	icon_state = "headscarfgrey"
	item_state = "headscarfgrey"
	worn_state = "headscarfgrey"
	body_parts_covered = FACE|HEAD
	slot_flags = SLOT_BELT|SLOT_MASK
	flags_inv = BLOCKHAIR
	w_class = ITEM_SIZE_TINY
	min_cold_protection_temperature = HELMET_MIN_COLD_PROTECTION_TEMPERATURE*2
	flammable = TRUE
	cold_protection = HEAD|FACE

/obj/item/clothing/mask/headscarfgrey/asbestos
	name = "Asbestos headscarf"
	desc = "A Heavy Asbestos farbic headscarf, it protects your head from heat and cold."
	icon_state = "headscarfgreyA"
	item_state = "headscarfgreyA"
	worn_state = "headscarfgreyA"
	body_parts_covered = FACE|HEAD
	w_class = ITEM_SIZE_SMALL
	max_heat_protection_temperature = HELMET_MAX_HEAT_PROTECTION_TEMPERATURE*4
	armor = list(melee = 5, arrow = FALSE, gun = FALSE, energy = 35, bomb = 25, bio = 5, rad = 5)
	heat_protection = HEAD|FACE
	flammable = FALSE
	cold_protection = HEAD|FACE

/obj/item/clothing/mask/headscarfgrey/olive
	name = "olive headscarf"
	icon_state = "headscarfolive"
	item_state = "headscarfolive"
	worn_state = "headscarfolive"

/obj/item/clothing/mask/headscarfgrey/white
	name = "white headscarf"
	icon_state = "headscarfwhite"
	item_state = "headscarfwhite"
	worn_state = "headscarfwhite"

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
	w_class = ITEM_SIZE_TINY
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

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/sksm
	New()
		..()
		new/obj/item/ammo_magazine/sksm(hold)
		new/obj/item/ammo_magazine/sksm(hold)
		new/obj/item/ammo_magazine/sksm(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/svd
	New()
		..()
		new/obj/item/ammo_magazine/svd(hold)
		new/obj/item/ammo_magazine/svd(hold)
		new/obj/item/ammo_magazine/svd(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak
	New()
		..()
		new/obj/item/ammo_magazine/ak47(hold)
		new/obj/item/ammo_magazine/ak47(hold)
		new/obj/item/ammo_magazine/ak47(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74
	New()
		..()
		new/obj/item/ammo_magazine/ak74(hold)
		new/obj/item/ammo_magazine/ak74(hold)
		new/obj/item/ammo_magazine/ak74(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/akdrum
	New()
		..()
		new/obj/item/ammo_magazine/ak47/drum(hold)
		new/obj/item/ammo_magazine/ak47/drum(hold)
		new/obj/item/ammo_magazine/ak47/drum(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/red/m16
	New()
		..()
		new/obj/item/ammo_magazine/m16(hold)
		new/obj/item/ammo_magazine/m16(hold)
		new/obj/item/ammo_magazine/m16(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/mosin
	New()
		..()
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/mosin/sniper
	New()
		..()
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosinbox(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/m24
	New()
		..()
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)

/obj/item/clothing/accessory/storage/webbing/khaki_webbing
	name = "khaki chest webbing"
	desc = "A khaki chest-level webbing, with three medium sized pouches."
	slots = 3
	icon_state = "khaki_webbing"
	item_state = "khaki_webbing"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/gun/projectile/pistol,/obj/item/weapon/gun/projectile/revolver,/obj/item/weapon/handcuffs,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/khaki_webbing/akm
	New()
		..()
		new/obj/item/weapon/grenade/ww2/mk2(hold)
		new/obj/item/ammo_magazine/ak47(hold)
		new/obj/item/ammo_magazine/ak47(hold)

/obj/item/clothing/accessory/storage/webbing/khaki_webbing/g3
	New()
		..()
		new/obj/item/weapon/grenade/ww2/mk2(hold)
		new/obj/item/ammo_magazine/hk(hold)
		new/obj/item/ammo_magazine/hk(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/akm
	New()
		..()
		new/obj/item/weapon/grenade/ww2/mk2(hold)
		new/obj/item/ammo_magazine/ak47(hold)
		new/obj/item/ammo_magazine/ak47(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/g3
	New()
		..()
		new/obj/item/weapon/grenade/ww2/mk2(hold)
		new/obj/item/ammo_magazine/hk(hold)
		new/obj/item/ammo_magazine/hk(hold)

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
	slot = "sash"

/obj/item/clothing/accessory/storage/webbing/ubacgreen
	name = "green UBAC"
	desc = "A flexible, close-fitting shirt with camouflage sleeves designed to be worn under combat equipment. This one is green."
	icon_state = "ubac_green"
	item_state = "ubac_green"
	slot = "sash"

/obj/item/clothing/accessory/storage/webbing/ubacblack
	name = "black UBAC"
	desc = "A flexible, close-fitting shirt with camouflage sleeves designed to be worn under combat equipment. This one is black."
	icon_state = "ubac_black"
	item_state = "ubac_black"
	slot = "sash"

/obj/item/clothing/accessory/storage/webbing/sweater //does not the capacity to protect against cold currently
	name = "grey sweater"
	desc = "A sweater to help you be comfy."
	icon_state = "sweater"
	item_state = "sweater"
	slot = "sash"

/obj/item/clothing/accessory/storage/webbing/light
	name = "light webbing"
	desc = "a light webbing, with lower capacity but permitting fast movement."
	slots = 3
	icon_state = "german_vest"
	item_state = "german_vest"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/handcuffs,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/light/chinese
	name = "Chinese light webbing"
	slots = 4
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
/obj/item/clothing/accessory/storage/webbing/light/chinese/gewehr98
	New()
		..()
		new/obj/item/ammo_magazine/gewehr98(hold)
		new/obj/item/ammo_magazine/gewehr98(hold)
		new/obj/item/ammo_magazine/gewehr98(hold)
		new/obj/item/ammo_magazine/gewehr98(hold)
		new/obj/item/ammo_magazine/gewehr98(hold)

/obj/item/clothing/accessory/storage/webbing/light/chinese/ak47
	New()
		..()
		new/obj/item/ammo_magazine/ak47(hold)
		new/obj/item/ammo_magazine/ak47(hold)
		new/obj/item/ammo_magazine/ak47(hold)
		new/obj/item/ammo_magazine/ak47(hold)

/obj/item/clothing/accessory/storage/webbing/light/chinese/sks
	New()
		..()
		new/obj/item/ammo_magazine/sks(hold)
		new/obj/item/ammo_magazine/sks(hold)
		new/obj/item/ammo_magazine/sks(hold)
		new/obj/item/ammo_magazine/sks(hold)
		new/obj/item/ammo_magazine/sks(hold)

/obj/item/clothing/accessory/storage/webbing/us_vest
	name = "US Army webbing"
	desc = "A large webbing with several small pockets."
	icon_state = "us_vest"
	item_state = "us_vest"
	slots = 5
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/handcuffs,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/us_vest/m16
	New()
		..()
		new /obj/item/stack/medical/bruise_pack/gauze(hold)
		new /obj/item/ammo_magazine/m16(hold)
		new /obj/item/ammo_magazine/m16(hold)
		new /obj/item/ammo_magazine/m16(hold)
		new /obj/item/ammo_magazine/m16(hold)

/obj/item/clothing/accessory/storage/webbing/us_vest/m60
	New()
		..()
		new /obj/item/stack/medical/bruise_pack/gauze(hold)
		new /obj/item/ammo_magazine/b762(hold)
		new /obj/item/ammo_magazine/b762(hold)
		new /obj/item/ammo_magazine/b762(hold)
		new /obj/item/ammo_magazine/b762(hold)

/obj/item/clothing/accessory/storage/webbing/us_vest/m249
	New()
		..()
		new /obj/item/stack/medical/bruise_pack/gauze(hold)
		new /obj/item/ammo_magazine/m249(hold)
		new /obj/item/ammo_magazine/m249(hold)
		new /obj/item/ammo_magazine/m249(hold)
		new /obj/item/ammo_magazine/m249(hold)

/obj/item/clothing/accessory/storage/webbing/us_vest/c6
	New()
		..()
		new /obj/item/stack/medical/bruise_pack/gauze(hold)
		new /obj/item/ammo_magazine/c6can(hold)
		new /obj/item/ammo_magazine/c6can(hold)
		new /obj/item/ammo_magazine/c6can(hold)
		new /obj/item/ammo_magazine/c6can(hold)

/obj/item/clothing/accessory/storage/webbing/us_vest/sten
	New()
		..()
		new /obj/item/stack/medical/bruise_pack/gauze(hold)
		new /obj/item/ammo_magazine/sten2(hold)
		new /obj/item/ammo_magazine/sten2(hold)
		new /obj/item/ammo_magazine/sten2(hold)
		new /obj/item/ammo_magazine/sten2(hold)

/obj/item/clothing/accessory/storage/webbing/us_vest/springfield
	New()
		..()
		new /obj/item/stack/medical/bruise_pack/gauze(hold)
		new /obj/item/ammo_magazine/springfield(hold)
		new /obj/item/ammo_magazine/springfield(hold)
		new /obj/item/ammo_magazine/springfield(hold)
		new /obj/item/ammo_magazine/springfield(hold)

/obj/item/clothing/accessory/storage/webbing/us_bandolier
	name = "US Army bandolier"
	desc = "A large cotton bandolier with several small pouches."
	icon_state = "us_bandolier"
	item_state = "us_badolier"
	slots = 5
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/handcuffs,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/shotgun_bandolier
	name = "shotgun bandolier"
	desc = "A bandolier with several holes made to fit shotgun shells."
	icon_state = "shotgun_bandolier"
	item_state = "shotgun_bandolier"
	slots = 12
	New()
		..()
		hold.can_hold = list(/obj/item/ammo_casing/shotgun)

/obj/item/clothing/accessory/storage/webbing/shotgun_bandolier/filled_buckshot
	New()
		..()
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)
		new /obj/item/ammo_casing/shotgun/buckshot(hold)

/obj/item/clothing/accessory/storage/webbing/m79_vest
	name = "US Army M79 Vest"
	desc = "A large webbing with several small pockets."
	icon_state = "m79_vest"
	item_state = "m79_vest"
	slots = 8
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/grenade/frag/ugl,/obj/item/weapon/grenade/smokebomb/ugl,/obj/item/weapon/grenade/chemical/ugl,/obj/item/weapon/key)

/obj/item/clothing/accessory/storage/webbing/m79_vest/filled
	New()
		..()
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)

/obj/item/clothing/accessory/storage/webbing/shell40mm
	name = "Grenadier Webbing"
	desc = "A large webbing with several small pockets."
	icon_state = "m79_vest"
	item_state = "m79_vest"
	slots = 8
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/grenade/frag/ugl,/obj/item/weapon/grenade/smokebomb/ugl,/obj/item/weapon/grenade/chemical/ugl,/obj/item/weapon/key)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/frag/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/smokebomb/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/smokebomb/ugl/shell40mm(hold)
		new /obj/item/weapon/grenade/smokebomb/ugl/shell40mm(hold)

/obj/item/clothing/accessory/storage/webbing/vog25
	name = "Grenadier Webbing"
	desc = "A large webbing with several small pockets."
	icon_state = "m79_vest"
	item_state = "m79_vest"
	slots = 8
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/grenade/frag/ugl,/obj/item/weapon/grenade/smokebomb/ugl,/obj/item/weapon/grenade/chemical/ugl,/obj/item/weapon/key)
		new /obj/item/weapon/grenade/frag/ugl/vog25(hold)
		new /obj/item/weapon/grenade/frag/ugl/vog25(hold)
		new /obj/item/weapon/grenade/frag/ugl/vog25(hold)
		new /obj/item/weapon/grenade/frag/ugl/vog25(hold)
		new /obj/item/weapon/grenade/frag/ugl/vog25(hold)
		new /obj/item/weapon/grenade/smokebomb/ugl/vog25(hold)
		new /obj/item/weapon/grenade/smokebomb/ugl/vog25(hold)
		new /obj/item/weapon/grenade/smokebomb/ugl/vog25(hold)

/obj/item/clothing/accessory/storage/webbing/survival
	name = "survival webbing"
	desc = "A green set of chest and knee-level pouches for storing a pistol, magazines and other gear needed to survive in the wilderness."
	slots = 11
	w_class = ITEM_SIZE_LARGE // Heavier because it can hold a lot of stuff.
	icon_state = "survival_webbing"
	item_state = "survival_webbing"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/gun/projectile/pistol,
							/obj/item/weapon/gun/projectile/revolver,
							/obj/item/weapon/key,
							/obj/item/ammo_casing,
							/obj/item/ammo_magazine,
							/obj/item/weapon/grenade,
							/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
							/obj/item/weapon/reagent_containers/food/snacks/MRE/generic,
							/obj/item/weapon/material/hatchet,
							/obj/item/weapon/material/shovel/trench/foldable,
							/obj/item/weapon/attachment/scope/adjustable/binoculars,
							/obj/item/stack/medical/bruise_pack,
							/obj/item/stack/medical/advanced/sulfa)

/obj/item/clothing/accessory/storage/webbing/survival/white
	desc = "A white set of chest and knee level pouches for storing a pistol, magazines and other things needed to survive in the wilderniss."
	icon_state = "survival_webbing_white"
	item_state = "survival_webbing_white"

/obj/item/clothing/accessory/storage/webbing/survival/filled
	New()
		..()
		new /obj/item/weapon/material/shovel/trench/foldable/etool(hold)
		new /obj/item/weapon/material/hatchet/steel(hold)
		new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(hold)
		new /obj/item/flashlight/flare(hold)
		new /obj/item/stack/medical/advanced/sulfa(hold)
		new /obj/item/weapon/reagent_containers/food/drinks/bottle/canteen(hold)
		new /obj/item/weapon/reagent_containers/food/snacks/MRE/generic(hold)
		new /obj/item/weapon/grenade/smokebomb/signal/rdg2_yellow(hold)

/obj/item/clothing/accessory/storage/webbing/survival/filled/soviet
	New()
		..()
		new /obj/item/weapon/gun/projectile/pistol/tt30(hold)
		new /obj/item/ammo_magazine/tt30(hold)
		new /obj/item/ammo_magazine/tt30(hold)

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

/obj/item/clothing/head/nbc/olive/fire
	name = "firefighting hood"
	desc = "A suit primarily intended to protect against fire."
	armor = list(melee = 40, arrow = FALSE, gun = FALSE, energy = 80, bomb = 25, bio = 60, rad = 40)

/obj/item/clothing/suit/nbc/olive
	name = "olive drab NBC suit"
	desc = "An olive drab coloured NBC suit, made protect against biological, chemical and nuclear threats."
	icon_state = "nbc2"
	item_state = "nbc2"
	worn_state = "nbc2"

/obj/item/clothing/suit/nbc/olive/fire
	name = "firefighting suit"
	desc = "A suit primarily intended to protect against fire."
	armor = list(melee = 40, arrow = FALSE, gun = FALSE, energy = 80, bomb = 25, bio = 60, rad = 40)

/obj/item/clothing/suit/hazmat
	name = "hazmat suit"
	desc = "A bright hazard protection suit, made to protect against biological, chemical and nuclear threats."
	icon_state = "hazmat_suit"
	item_state = "hazmat_suit"
	worn_state = "hazmat_suit"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|FEET|HANDS|HEAD
	armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = 5, bomb = 5, bio = 100, rad = 100)
	ripable = FALSE

/obj/item/clothing/suit/nbcponcho
	name = "NBC poncho"
	desc = "a NBC poncho,very light and easy to put on, made to protect against biological, chemical and nuclear threats."
	icon_state = "nbcponcho"
	item_state = "nbcponcho"
	worn_state = "nbcponcho"
	w_class = ITEM_SIZE_TINY // its light
	item_flags = AIRTIGHT
	flags_inv = HIDEFACE|BLOCKHAIR
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|HEAD|FEET|HANDS
	armor = list(melee = 5, arrow = FALSE, gun = FALSE, energy = 5, bomb = 5, bio = 100, rad = 75)
	ripable = FALSE

/obj/item/clothing/suit/nbcponcho/white
	name = "White NBC poncho"
	icon_state = "nbcponchowhite"
	item_state = "nbcponchowhite"
	worn_state = "nbcponchowhite"
/* Astronaut Suit and Helmet*/

/obj/item/clothing/head/astronaut
	name = "astronaut helmet"
	desc = "A grey helmet, made to protect against low pressure, temperature and radioactive threa"
	icon_state = "astronaut"
	armor = list(melee = 20, arrow = 10, gun = 5, energy = 10, bomb = 35, bio = 150, rad = 195)

/obj/item/clothing/suit/astronaut
	name = "astronaut suit"
	desc = "A grey space suit, made protect to against low pressure, temperature and radioactive threats."
	icon_state = "astronaut"
	item_state = "astronaut"
	worn_state = "astronaut"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|FEET|HANDS
	armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = 5, bomb = 35, bio = 150, rad = 195)
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
	armor = list(melee = 30, arrow = 5, gun = 5, energy = 15, bomb = 30, bio = 10, rad = FALSE)
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
    //china cold war
/obj/item/clothing/under/chinaguard
	name = "Chinese Red Guard Uniform"
	desc = "An uniform worn by the Red guard."
	icon_state = "redguard"
	item_state = "redguard"
	worn_state = "redguard"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 5, arrow = 5, gun = FALSE, energy = 2, bomb = 5, bio = 10, rad = 10)

obj/item/clothing/head/chinaguardcap
	name = "Chinese Red Guard cap"
	desc = "A cap worn by the Chinese Red guard."
	icon_state = "redguardcap"
	item_state = "redguardcap"
	worn_state = "redguardcap"
	body_parts_covered = HEAD
	armor = list(melee = 5, arrow = FALSE, gun = 1, energy = FALSE, bomb = FALSE, bio = FALSE, rad = FALSE)
	/* Sovie apparel 70-80'ss*/

/obj/item/clothing/under/afghanka
	name = "afghanka uniform"
	desc = "A standard soviet uniform developped and issued in the early 80's, still in use after the collapse of the Soviet Union."
	icon_state = "milrus_afghanka_open"
	item_state = "milrus_afghanka_open"
	worn_state = "milrus_afghanka_open"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	var/adjusted = FALSE
/obj/item/clothing/under/afghanka/verb/toggle()
	set category = null
	set src in usr
	set name = "Adjust collar"
	if (type != /obj/item/clothing/under/afghanka)
		return
	else
		if(adjusted)
			worn_state = "milrus_afghanka_open"
			item_state = "milrus_afghanka_open"
			icon_state = "milrus_afghanka_open"
			item_state_slots["w_uniform"] = "milrus_afghanka_open"
			usr << "You <b>open up</b> the collar of your uniform."
			adjusted = FALSE
			update_clothing_icon()
		else if (!adjusted)
			worn_state = "milrus_afghanka_closed"
			item_state = "milrus_afghanka_closed"
			icon_state = "milrus_afghanka_closed"
			item_state_slots["w_uniform"] = "milrus_afghanka_closed"
			usr << "You <b>close up</b> the collar of your uniform."
			adjusted = TRUE
			update_clothing_icon()

/obj/item/clothing/under/sov_klmk
	name = "KLMK camo uniform"
	desc = "A suit in the KLMK camo pattern, issued by the Soviet Union in the 1970s."
	icon_state = "sov_klmk"
	item_state = "sov_klmk"
	worn_state = "sov_klmk"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/sov_kzs
	name = "KZS camo uniform"
	desc = "A suit in the KZS camo pattern, issued by the Soviet Union in the late 1970s."
	icon_state = "sov_kzs"
	item_state = "sov_kzs"
	worn_state = "sov_kzs"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/under/coldwar/soviet_officer
	name = "soviet officer uniform"
	desc = "An officer uniform, used by officers in the Soviet Army."
	icon_state = "sovuni_officer2"
	item_state = "sovuni_officer2"
	worn_state = "sovuni_officer2"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

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
	flags = CONDUCT

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
	flags = CONDUCT

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
	flags = CONDUCT

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
	flags = CONDUCT

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
	flags = CONDUCT

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

/obj/item/clothing/head/helmet/modern/vchelmet/two
	icon_state = "viet_pith2"
	item_state = "viet_pith2"
	worn_state = "viet_pith2"
/obj/item/clothing/head/helmet/modern/vchelmet/three
	icon_state = "viet_pith3"
	item_state = "viet_pith3"
	worn_state = "viet_pith3"

/obj/item/clothing/head/helmet/modern/hardhaty
	name = "yellow hard hat"
	desc = "A yellow hard hat used by the workers."
	icon_state = "hardhat_yellow"
	item_state = "hardhat_yellow"
	worn_state = "hardhat_yellow"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 65, arrow = 15, gun = 5, energy = 5, bomb = 55, bio = 10, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/modern/hardhatw
	name = "white hard hat"
	desc = "A white hard hat used by the workers."
	icon_state = "hardhat_white"
	item_state = "hardhat_white"
	worn_state = "hardhat_white"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 65, arrow = 15, gun = 5, energy = 5, bomb = 55, bio = 10, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/modern/hardhato
	name = "orange hard hat"
	desc = "A orange hard hat used by the workers."
	icon_state = "hardhat_orange"
	item_state = "hardhat_orange"
	worn_state = "hardhat_orange"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 65, arrow = 15, gun = 5, energy = 5, bomb = 55, bio = 10, rad = FALSE)
	health = 30

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

/obj/item/clothing/under/ww2/soviet_nkvd/kgb
	name = "KGB uniform"
	desc = "A Russian KGB uniform, used by KGB."
	icon_state = "nkvd_uni"
	item_state = "nkvd_uni"
	worn_state = "nkvd_uni"

/obj/item/clothing/under/coldwar/dra/soldier
	name = "DRA uniform"
	desc = "A military uniform worn by DRA soldiers."
	icon_state = "dra_uni"
	item_state = "dra_uni"
	worn_state = "dra_uni"

/obj/item/clothing/under/coldwar/dra/nco
	name = "DRA NCO uniform"
	desc = "A military uniform worn by DRA NCOs."
	icon_state = "dra_uni_nco"
	item_state = "dra_uni_nco"
	worn_state = "dra_uni_nco"

/obj/item/clothing/under/coldwar/dra/officer
	name = "DRA officer uniform"
	desc = "A military uniform worn by DRA officers."
	icon_state = "dra_uni_officer"
	item_state = "dra_uni_officer"
	worn_state = "dra_uni_officer"

/obj/item/clothing/suit/coldwar/dra/officer
	name = "DRA officer jacket"
	desc = "A military jacket worn by DRA officers."
	icon_state = "dra_officer"
	item_state = "dra_officer"
	worn_state = "dra_officer"

/obj/item/clothing/head/custom/fieldcap/dra
	name = "DRA field cap"
	desc = "A cap worn by DRA military personnel."
	color = "#767160"
	uncolored1 = FALSE

//blugoslavian and redmenian stuff
/obj/item/clothing/under/blugoslavian_sailor
	name = "Blugoslavian navy uniform"
	desc = "A blue uniform of the Blugoslavian Navy."
	icon_state = "blugoslavian_sailor"
	item_state = "blugoslavian_sailor"
	worn_state = "blugoslavian_sailor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS


/obj/item/clothing/under/redmenian_sailor
	name = "Redmenian navy uniform"
	desc = "A red uniform of the Redmenian Navy."
	icon_state = "redmenian_sailor"
	item_state = "redmenian_sailor"
	worn_state = "redmenian_sailor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS
/obj/item/clothing/under/coldwar/bowling_red
	name = "red bowling outfit"
	desc = "A stylish red bowling shirt with black pants."
	icon_state = "bowling_red"
	item_state = "bowling_red"
	worn_state = "bowling_red"

/obj/item/clothing/under/coldwar/bowling_yellow
	name = "yellow bowling outfit"
	desc = "A stylish yellow bowling shirt with black pants."
	icon_state = "bowling_yellow"
	item_state = "bowling_yellow"
	worn_state = "bowling_yellow"

/obj/item/clothing/under/coldwar/bowling_green
	name = "green bowling outfit"
	desc = "A stylish green bowling shirt with black pants."
	icon_state = "bowling_green"
	item_state = "bowling_green"
	worn_state = "bowling_green"

/obj/item/clothing/under/coldwar/bowling_blue
	name = "blue bowling outfit"
	desc = "A stylish blue bowling shirt with black pants."
	icon_state = "bowling_blue"
	item_state = "bowling_blue"
	worn_state = "bowling_blue"

/obj/item/clothing/under/coldwar/hippie
	name = "hippie outfit"
	desc = "A tie-dye t-shirt with bootleg grey jeans. Right on, man!"
	icon_state = "hippy"
	item_state = "hippy"
	worn_state = "hippy"

///////MEDICAL SCRUBS//////////////

/obj/item/clothing/under/scrubs
	name = "white medical scrubs"
	desc = "Sanitary clothing worn by medical personnel."
	icon_state = "scrubs_white"
	item_state = "scrubs_white"
	worn_state = "scrubs_white"

/obj/item/clothing/under/scrubs/darkgreen
	name = "dark green medical scrubs"
	desc = "Sanitary clothing worn by medical personnel. This one is dark green."
	icon_state = "scrubs_darkgreen"
	item_state = "scrubs_darkgreen"
	worn_state = "scrubs_darkgreen"

/obj/item/clothing/under/scrubs/lightgreen
	name = "light green medical scrubs"
	desc = "Sanitary clothing worn by medical personnel. This one is light green."
	icon_state = "scrubs_lightgreen"
	item_state = "scrubs_lightgreen"
	worn_state = "scrubs_lightgreen"

/obj/item/clothing/under/scrubs/blue
	name = "blue medical scrubs"
	desc = "Sanitary clothing worn by medical personnel. This one is blue."
	icon_state = "scrubs_blue"
	item_state = "scrubs_blue"
	worn_state = "scrubs_blue"

/obj/item/clothing/under/scrubs/navy
	name = "navy medical scrubs"
	desc = "Sanitary clothing worn by medical personnel. This one is navy."
	icon_state = "scrubs_navy"
	item_state = "scrubs_navy"
	worn_state = "scrubs_navy"


////////SURGICAL CAPS/////////

/obj/item/clothing/head/surgical_cap
	name = "white surgical cap"
	desc = "A white sterile surgical cap."
	icon_state = "surgcap_white"
	item_state = "surgcap_white"
	worn_state = "surgcap_white"

/obj/item/clothing/head/surgical_cap/darkgreen
	name = "dark green surgical cap"
	desc = "A dark green sterile surgical cap."
	icon_state = "surgcap_darkgreen"
	item_state = "surgcap_darkgreen"
	worn_state = "surgcap_darkgreen"

/obj/item/clothing/head/surgical_cap/lightgreen
	name = "light green surgical cap"
	desc = "A light green sterile surgical cap."
	icon_state = "surgcap_lightgreen"
	item_state = "surgcap_lightgreen"
	worn_state = "surgcap_lightgreen"

/obj/item/clothing/head/surgical_cap/blue
	name = "blue surgical cap"
	desc = "A blue sterile surgical cap."
	icon_state = "surgcap_blue"
	item_state = "surgcap_blue"
	worn_state = "surgcap_blue"

/obj/item/clothing/head/surgical_cap/navy
	name = "navy surgical cap"
	desc = "A navy sterile surgical cap."
	icon_state = "surgcap_navy"
	item_state = "surgcap_navy"
	worn_state = "surgcap_navy"

/obj/item/clothing/under/un_irish
	name = "irish olive uniform"
	desc = "A uniform worn by the UN Irish troops."
	icon_state = "un_irish"
	item_state = "un_irish"
	worn_state = "un_irish"

/obj/item/clothing/under/afr_merc
	name = "african mercenary uniform"
	desc = "A light uniform worn by mercenaries."
	icon_state = "afr_merc"
	item_state = "afr_merc"
	worn_state = "arc_merc"

/obj/item/clothing/under/afr_merc/alt
	icon_state = "afr_merc2"
	item_state = "afr_merc2"
	worn_state = "arc_merc2"
