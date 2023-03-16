/*Index*/
/*   * 1 - Colonial Suits
     * 1a - Colonial Armor
     * 2 - Colonial Uniforms
     * 3 - Colonial Hats
     * 3a - Colonial Helmets
     * 4 - Colonial Boots
     * 5 - Colonial Accessories & Items
     * 6 - Colonial Pirate Clothing
     ///////////////////////////////////
     * 7 - Colonial Infantry & Sailor Clothes
     * 7a - Colonial Infantry & Sailor Boots
     * 7b - Colonial British Army & Navy Clothes
     * 7c - Colonial Portuguese Army & Navy Clothes
     * 7d - Colonial Spanish Army & Navy Clothes
     * 7e - Colonial French Army & Navy Clothes
     * 7f - Colonial Dutch Army & Navy Clothes
     ///////////////////////////////////
     * 8 - Colonial Army Clothes
     * 8a - Colonial Army Uniforms
     * 8b - Colonial Army Jackets
     ///////////////////////////////////
     * 9 - Napoleonic Clothing
     * 9a - Napoleonic Army Clothing
     * 9b - Napoleonic Armor
     ////////////////////////////////
     * 10 - Miscallaneous*/

/* Colonial Suits*/

//pending, due to recently rebased content.

	/* Colonial Armor*/

/obj/item/clothing/suit/armor/imperial/imperial_chestplate
	name = "imperial chestplate"
	desc = "An iron chestplate made in a imperial style, it is not wholly protective against bullets but allows more maneuverability to avoid them."
	icon_state = "imperial_breastplate"
	item_state = "imperial_breastplate"
	worn_state = "imperial_breastplate"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 50, gun = 12, energy = 15, bomb = 40, bio = 20, rad = 0)
	value = 20
	slowdown = 0.4
	health = 50


/* Colonial Uniforms*/

/obj/item/clothing/under/civ4
	name = "fancy colonial clothing"
	desc = "A set composed of a quality white linen shirt and black trousers."
	icon_state = "civuni4"
	item_state = "civuni4"
	worn_state = "civuni4"

/obj/item/clothing/under/civ1
	name = "blue colonial clothing"
	desc = "A set composed of a light blue linen shirt and short trousers."
	icon_state = "civuni1"
	item_state = "civuni1"
	worn_state = "civuni1"

/obj/item/clothing/under/civ2
	name = "white colonial clothing"
	desc = "A set composed of a white linen shirt and black trousers."
	icon_state = "civuni2"
	item_state = "civuni2"
	worn_state = "civuni2"

/obj/item/clothing/under/civ3
	name = "short-sleeved colonial clothing"
	desc = "A set composed of a light white linen shirt with short sleeves and black trousers."
	icon_state = "civuni3"
	item_state = "civuni3"
	worn_state = "civuni3"

/obj/item/clothing/under/civ5
	name = "green colonial clothing"
	desc = "A set composed of a green linen shirt and black trousers."
	icon_state = "civuni5"
	item_state = "civuni5"
	worn_state = "civuni5"

/obj/item/clothing/under/civ6
	name = "pink colonial clothing"
	desc = "A set composed of a pink linen shirt and black trousers."
	icon_state = "civuni6"
	item_state = "civuni6"
	worn_state = "civuni6"

/obj/item/clothing/under/doctor
	name = "doctor's uniform"
	desc = "A sterile, nicely pressed suit for doctors."
	icon_state = "ba_suit"
	item_state = "ba_suit"

/obj/item/clothing/under/civf1
	name = "dark dress"
	desc = "A dark dress, used by peasant women."
	icon_state = "dress1"
	item_state = "dress1"
	worn_state = "dress1"

/obj/item/clothing/under/civf2
	name = "blue dress"
	desc = "A blue dress."
	icon_state = "dress2"
	item_state = "dress2"
	worn_state = "dress2"

/obj/item/clothing/under/civf3
	name = "brown dress"
	desc = "A brown dress."
	icon_state = "dress3"
	item_state = "dress3"
	worn_state = "dress3"

/obj/item/clothing/under/civfg
	name = "green dress"
	desc = "A green dress."
	icon_state = "dressg"
	item_state = "dressg"
	worn_state = "dressg"

/obj/item/clothing/under/civfr
	name = "red dress"
	desc = "A red dress."
	icon_state = "dressr"
	item_state = "dressr"
	worn_state = "dressr"

/obj/item/clothing/under/debutante/blue
	name = "blue debutante gown"
	desc = "A long and elegant debutante gown, often worn by women of high status at societal events."
	icon_state = "gown_blue"
	item_state = "gown_blue"
	worn_state = "gown_blue"

/obj/item/clothing/under/debutante/orange
	name = "orange debutante gown"
	desc = "A long and elegant debutante gown, often worn by women of high status at societal events."
	icon_state = "gown_orange"
	item_state = "gown_orange"
	worn_state = "gown_orange"

/obj/item/clothing/under/debutante/purple
	name = "purple debutante gown"
	desc = "A long and elegant debutante gown, often worn by women of high status at societal events."
	icon_state = "gown_purple"
	item_state = "gown_purple"
	worn_state = "gown_purple"

/obj/item/clothing/under/debutante/red
	name = "red debutante gown"
	desc = "A long and elegant debutante gown, often worn by women of high status at societal events."
	icon_state = "gown_red"
	item_state = "gown_red"
	worn_state = "gown_red"

/obj/item/clothing/under/debutante/yellow
	name = "red debutante gown"
	desc = "A long and elegant debutante gown, often worn by women of high status at societal events."
	icon_state = "gown_yellow"
	item_state = "gown_yellow"
	worn_state = "gown_yellow"

/obj/item/clothing/under/conquistador
	name = "conquistador uniform"
	desc = "A regal uniform often worn by a class of explorers known as conquistadors in search of wealth."
	icon_state = "conquistador"
	item_state = "conquistador"
	worn_state = "conquistador"

/obj/item/clothing/under/pilgrim
	name = "pilgrim clothing"
	desc = "A set of plain black and grey clothes worn by transient followers of faith."
	icon_state = "pilgrim"
	item_state = "pilgrim"
	worn_state = "pilgrim"

/* Colonial Hats*/

/obj/item/clothing/head/furhat
	name = "fur hat"
	desc = "A hat made of fur."
	icon_state = "furhat_hat"
	item_state = "furhat_hat"
	cold_protection = HEAD
	min_cold_protection_temperature = HELMET_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/head/furcap
	name = "fur cap"
	desc = "A cap made of fur."
	icon_state = "furcap_hat"
	item_state = "furcap_hat"
	cold_protection = HEAD
	min_cold_protection_temperature = HELMET_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/head/roundcap
	name = "roundcap"
	desc = "A cap made of leather."
	icon_state = "roundcap_hat"
	item_state = "roundcap_hat"

/obj/item/clothing/head/kerchief
	name = "kerchief"
	icon_state = "kerchief"
	item_state = "kerchief"
	worn_state = "kerchief"
	desc = "A kerchief, worn by women over the hair."
	flags_inv = BLOCKHAIR
	body_parts_covered = HEAD

/obj/item/clothing/head/red_sailorberet
	name = "red sailor beret"
	desc = "A red beret."
	icon_state = "redberet"
	item_state = "redberet"

/obj/item/clothing/head/blue_sailorberet
	name = "blue sailor beret"
	desc = "A blue beret."
	icon_state = "blueberet"
	item_state = "blueberet"

/obj/item/clothing/head/tarred_hat
	name = "tarred hat"
	desc = "A tarred hat, commonly used by sailors."
	icon_state = "tarred_hat"
	item_state = "tarred_hat"
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/head/strawhat
	name = "straw hat"
	icon_state = "boater_hat"
	desc = "A straw hat, commonly used by sailors."
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/head/tricorne_black
	name = "black tricorne"
	desc = "A black tricorne. In fashion."
	icon_state = "tricorne_black"
	item_state = "tricorne_black"

/obj/item/clothing/head/capotain
	name = "capotain"
	desc = "A black capotain, high fashion amongst the courts of nobilty."
	icon_state = "capotain"
	item_state = "capotain"
	worn_state = "capotain"

/obj/item/clothing/head/capotain/pilgrim
	name = "capotain"
	desc = "A stylized capotain, often worn by transient pilgrims."
	icon_state = "pilgrim"
	item_state = "pilgrim"
	worn_state = "pilgrim"

	/* Colonial Helmets*/

/obj/item/clothing/head/helmet/imperial/morion
	name = "morion helmet"
	desc = "A protective and hardy morion helmet covering the dome of the head and ears."
	icon_state = "morion_helmet"
	item_state = "morion_helmet"
	worn_state = "morion_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 5, energy = 15, bomb = 40, bio = 20, rad = 0)
	health = 32

/obj/item/clothing/head/helmet/imperial/cabasset
	name = "cabasset helmet"
	desc = "A protective and hardy morion helmet without the narrow ridge dent covering."
	icon_state = "morion_helmet"
	item_state = "morion_helmet"
	worn_state = "morion_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 35, arrow = 32, gun = 8, energy = 15, bomb = 41, bio = 21, rad = 0)
	health = 34


/* Colonial Boots*/

/obj/item/clothing/shoes/blackboots
	name = "black boots"
	desc = "Classic black boots."
	icon_state = "sailorboots1"
	item_state = "sailorboots1"
	worn_state = "sailorboots1"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 10, arrow = 20, gun = 0, energy = 25, bomb = 50, bio = 10, rad = 0)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/leatherboots
	name = "leather boots"
	desc = "Classic leather boots."
	icon_state = "sailorboots2"
	item_state = "sailorboots2"
	worn_state = "sailorboots2"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 10, arrow = 20, gun = 0, energy = 25, bomb = 50, bio = 10, rad = 0)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/winterboots
	name = "winter boots"
	desc = "Classic winter boots."
	icon_state = "winterboots"
	item_state = "winterboots"
	worn_state = "winterboots"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 15, arrow = 20, gun = 0, energy = 25, bomb = 50, bio = 10, rad = 5)
	item_flags = NOSLIP
	siemens_coefficient = 0.9
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/whiteputtee
	name = "black puttee boots"
	desc = "Classic black boots with white puttees."
	icon_state = "whiteput"
	item_state = "whiteput"
	worn_state = "whiteput"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 10, arrow = 20, gun = 0, energy = 25, bomb = 50, bio = 10, rad = 0)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/* Colonial Accessories & Items*/

/obj/item/clothing/accessory/ruffle/neck
	name = "neck ruffle"
	desc = "A ruffle neck collar made of soft material."
	icon_state = "ruffle_neck"
	item_state = "ruffle_neck"

// WEBBING - can hold everything but clothing
/obj/item/clothing/accessory/storage/webbing
	name = "bandolier"
	desc = "two leather belts with small pouches for ammunition."
	icon_state = "bandolier"
	item_state = "bandolier"
	slots = 8
	slot = "utility"
	New()
		..()
		hold.can_hold = list(
			/obj/item/ammo_casing,
			/obj/item/stack/ammopart/stoneball
			)

/obj/item/clothing/accessory/storage/coinpouch
	name = "coin pouch"
	desc = "A small pouch, where you can carry your coins and small objects."
	icon = 'icons/obj/storage.dmi'
	icon_state = "coinpouch1"
	slot_flags = SLOT_ID | SLOT_BELT | SLOT_POCKET
	slots = 8

/obj/item/clothing/accessory/storage/coinpouch/tes13
	name = "coin pouch"
	desc = "A small pouch, where you can carry your septims and small objects."
	icon = 'icons/obj/storage.dmi'
	icon_state = "coinpouch_tes13"
	slot_flags = SLOT_ID | SLOT_BELT | SLOT_POCKET
	slots = 8

/obj/item/clothing/accessory/storage/coinpouch/wallet
	name = "wallet"
	desc = "A personal wallet, where you can carry your coins and small objects."
	icon = 'icons/obj/storage.dmi'
	icon_state = "wallet"


/obj/item/clothing/accessory/storage/coinpouch/wallet/occinn
	name = "Inn keyset"
	desc = "A full set of keys for the Inn."
	slot_flags = SLOT_ID | SLOT_BELT | SLOT_POCKET
	New()
		..()
		hold.can_hold = list(
		/obj/item/weapon/key
		)
/obj/item/clothing/accessory/storage/coinpouch/wallet/occinn/New()
	..()
	new /obj/item/weapon/key/civ/inn(src)
	new /obj/item/weapon/key/civ/room1(src)
	new /obj/item/weapon/key/civ/room2(src)
	new /obj/item/weapon/key/civ/room3(src)
	new /obj/item/weapon/key/civ/room4(src)




/obj/item/clothing/accessory/storage/coinpouch/gator_wallet
	name = "alligator scale wallet"
	desc = "A exotic personal wallet decorated in alligator scale, where you can carry your coins and small objects."
	icon = 'icons/obj/storage.dmi'
	icon_state = "gator_wallet"

/obj/item/clothing/accessory/storage/coinpouch/New()
	..()
	hold.max_storage_space = 25
	hold.can_hold = list(/obj/item/stack/money,\
	/obj/item/weapon/key,\
	/obj/item/weapon/storage/belt/keychain,\
	/obj/item/clothing/accessory/storage/passport,\
	/obj/item/weapon/visa)


/obj/item/clothing/accessory/storage/passport
	name = "passport"
	desc = "A personal passport. Can hold several visas."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "passport"
	item_state = "paper"
	slot_flags = SLOT_ID | SLOT_POCKET
	slots = 15
	w_class = ITEM_SIZE_SMALL
	var/mob/living/human/owner = null
	var/faction = ""
	flammable = TRUE

/obj/item/clothing/accessory/storage/passport/New()
	..()
	hold.max_storage_space = 50
	hold.can_hold = list(/obj/item/weapon/visa)

/obj/item/clothing/accessory/storage/passport/proc/own()
	spawn(5)
		if (owner)
			faction = owner.civilization
			name = "[faction]'s passport"
			desc = "[faction] passport, issued to [owner]. Can hold several visas."
/*
/obj/item/weapon/civilian_passport
	name = "Identification Documents"
	desc = "The identification papers of a civilian."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "passport"
	item_state = "paper"
	throwforce = FALSE
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_ID | SLOT_POCKET
	throw_range = TRUE
	throw_speed = TRUE
	attack_verb = list("bapped")
	flammable = TRUE
	var/mob/living/human/owner = null
	var/document_name = ""
	var/list/document_details = list()
	var/list/guardnotes = list()
	secondary_action = TRUE
	New()
		..()
		spawn(20)
			if (ishuman(loc))
				var/mob/living/human/H = loc
				document_name = H.real_name
				owner = H
				name = "[document_name] indentification documents"
				desc = "The identification papers of <b>[document_name]</b>."
				var/crimereason = "Nationality"
				if (istype(H.original_job, /datum/job/civilian/prisoner))
					switch(H.nationality)
						if ("German")
							crimereason = "German Citizen."
						if ("Ukrainian")
							crimereason = "Ukrainian Citizen."
						if ("Polish")
							crimereason = "Polish Citizen."

					document_details = list(H.h_style, H.f_style, crimereason, H.gender, rand(6,32))
/obj/item/weapon/civilian_passport/examine(mob/user)
	user << "<span class='info'>*---------*</span>"
	..(user)
	if (document_details.len >= 9)
		user << "<b><span class='info'>Hair:</b> [document_details[1]], [document_details[2]] color</span>"
		if (document_details[6] == "male")
			user << "<b><span class='info'>Face:</b> [document_details[3]], [document_details[4]] color</span>"
		user << "<b><span class='info'>Eyes:</b> [document_details[8]]</span>"
		user << "<b><span class='info'>Detained for:</b> [document_details[5]]</span>"
		user << "<b><span class='info'>Sentence:</b> [document_details[7]] years</span>"
		user << "<b><span class='info'>Assigned Job:</b> [document_details[9]]</span>"
	user << "<span class='info'>*---------*</span>"
	if (guardnotes.len)
		for(var/i in guardnotes)
			user << "NOTE: [i]"
	user << "<span class='info'>*---------*</span>"

/obj/item/weapon/civilian_passport/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!ishuman(H))
		return
	if (istype(I, /obj/item/weapon/pen) && istype(H.original_job, /datum/job/russian))
		var/confirm = WWinput(H, "Do you want to add a note to these documents?", "Prisoner Documents", "No", list("No","Yes"))
		if (confirm == "No")
			return
		else
			var/texttoadd = input(H, "What do you want to write? Up to 150 characters", "Notes", "") as text
			texttoadd = sanitize(texttoadd, 150, FALSE)
			texttoadd = "<i>[texttoadd] - <b>[H.real_name]</b></i>"
			guardnotes += texttoadd
			return

/obj/item/weapon/civilian_passport/secondary_attack_self(mob/living/human/user)
	showoff(user)
	return
*/
/obj/item/weapon/visa
	name = "visa"
	desc = "a traveller visa."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "visa0"
	item_state = "paper"
	throwforce = FALSE
	w_class = ITEM_SIZE_TINY
	flags = FALSE
	throw_range = TRUE
	throw_speed = TRUE
	attack_verb = list("bapped")
	flammable = TRUE
	var/mob/living/human/owner = null
	var/duration = 0

/obj/item/weapon/visa/attackby(obj/item/W as obj, mob/living/human/user as mob)
	if (istype(W, /obj/item/weapon/pen) && !owner && duration == 0)
		if (user.civilization == "none")
			user << "You are not in a faction!"
			return
		else
			if (user.faction_perms[4] == 0)
				user << "You don't have the recruitment permissions to issue visas!"
				return
			else
				var/mob/living/human/U = null
				var/closemobs = list("Cancel")
				for (var/mob/living/human/M in range(4,loc))
					if (M.civilization != user.civilization)
						closemobs += M
				var/choice2 = WWinput(usr, "Who to give the visa to?", "Visa", "Cancel", closemobs)
				if (choice2 == "Cancel" || !choice2)
					return
				else
					U = choice2
					var/inp = input(user, "How long should the visa last? In minutes. (Up to 3 days - 4320 minutes)") as num|null
					if (!isnum(inp))
						return
					if (inp <= 0)
						return
					if (inp > 4320)
						inp = 4320
						return
					else
						duration = inp
						owner = U
						icon_state = "visa1"
						name = "[user.civilization] visa"
						var/cdur = ""
						if (duration > 60)
							cdur = "[duration/60] hours"
						else
							cdur = "[duration] minutes"
						desc = "A visa issued by <b>[user.civilization]</b> to <b>[owner]</b>.<br>Issued on <b>[roundduration2text_days()]</b> and valid for <b>[cdur]</b> starting then.<br>Signed by: <b><i>[user]</i></b>."
						user << "You issue the visa."
						update_icon()
						do_duration()
						return
	else
		..()
/obj/item/weapon/visa/proc/do_duration()
	spawn(duration*600)
		qdel(src)
		return

//* Colonial Pirate Clothing*/

/obj/item/clothing/suit/storage/jacket/piratejacket1
	name = "black jacket"
	desc = "A long black jacket."
	icon_state = "piratejacket1"
	item_state = "piratejacket1"
	worn_state = "piratejacket1"

/obj/item/clothing/suit/storage/jacket/piratejacket2
	name = "fancy brown jacket"
	desc = "A fancy jacket. This one is brown."
	icon_state = "piratejacket2"
	item_state = "piratejacket2"
	worn_state = "piratejacket2"

/obj/item/clothing/suit/storage/jacket/piratejacket3
	name = "blue vest"
	desc = "A sleeveless vest. This one is blue."
	icon_state = "piratejacket3"
	item_state = "piratejacket3"
	worn_state = "piratejacket3"

/obj/item/clothing/suit/storage/jacket/piratejacket4
	name = "black vest"
	desc = "A sleeveless vest. This one is black."
	icon_state = "piratejacket4"
	item_state = "piratejacket4"
	worn_state = "piratejacket4"

/obj/item/clothing/suit/storage/jacket/piratejacket5
	name = "fancy red jacket"
	desc = "A fancy jacket. This one is red."
	icon_state = "piratejacket5"
	item_state = "piratejacket5"
	worn_state = "piratejacket5"

/obj/item/clothing/under/pirate1
	name = "black stripes clothing"
	desc = "A set of clothes with a black striped shirt."
	icon_state = "pirate1"
	item_state = "pirate1"
	worn_state = "pirate1"

/obj/item/clothing/under/pirate2
	name = "red stripes clothing"
	desc = "A set of clothes with a red striped shirt."
	icon_state = "pirate2"
	item_state = "pirate2"
	worn_state = "pirate2"

/obj/item/clothing/under/pirate3
	name = "blue stripes clothing"
	desc = "A set of clothes with a blue striped shirt."
	icon_state = "pirate3"
	item_state = "pirate3"
	worn_state = "pirate3"

/obj/item/clothing/under/pirate4
	name = "baggy clothing"
	desc = "A set of clothes with a white shirt and baggy trousers"
	icon_state = "pirate4"
	item_state = "pirate4"
	worn_state = "pirate4"

/obj/item/clothing/under/pirate5
	name = "sleeveless clothing"
	desc = "A set of clothes with a sleeveless shirt."
	icon_state = "pirate5"
	item_state = "pirate5"
	worn_state = "pirate5"

/obj/item/clothing/head/piratehat
	name = "Pirate hat"
	icon_state = "piratehat"
	item_state = "piratehat"

/obj/item/clothing/head/piratebandana1
	name = "bandana"
	icon_state = "piratebandana1"
	item_state = "piratebandana1"
	flags_inv = BLOCKHAIR

/* Colonial Infantry Clothes*/
	/* Colonial Infantry & Sailor Boots*/

/obj/item/clothing/shoes/soldiershoes
	name = "infantry shoes"
	desc = "Low black infantry shoes."
	icon_state = "soldier_shoes"
	item_state = "soldier_shoes"
	worn_state = "soldier_shoes"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 30, arrow = 25, gun = 10, energy = 15, bomb = 30, bio = 10, rad = 5)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/sailorboots1
	name = "black sailor boots"
	desc = "Classic black sailor boots."
	icon_state = "sailorboots1"
	item_state = "sailorboots1"
	worn_state = "sailorboots1"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 30, arrow = 20, gun = 0, energy = 25, bomb = 50, bio = 10, rad = 0)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/sailorboots2
	name = "leather sailor boots"
	desc = "Classic leather sailor boots."
	icon_state = "sailorboots2"
	item_state = "sailorboots2"
	worn_state = "sailorboots2"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, arrow = 20, gun = 0, energy = 25, bomb = 50, bio = 10, rad = 30)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/usmc
	name = "military boots"
	desc = "Classic tan military boots."
	icon_state = "usmc"
	item_state = "usmc"
	worn_state = "usmc"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 30, arrow = 20, gun = 10, energy = 25, bomb = 50, bio = 10, rad = 0)
	item_flags = NOSLIP
	siemens_coefficient = 0.7
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

	/* Colonial British Army & Navy Clothes*/

/obj/item/clothing/under/british_sailor1
	name = "british sailor clothes"
	desc = "A set of royal navy sailor clothes, with a white shirt and trousers."
	icon_state = "british_sailor1"
	item_state = "british_sailor1"
	worn_state = "british_sailor1"

/obj/item/clothing/under/british_sailor2
	name = "open british sailor clothes"
	desc = "A set of royal navy sailor clothes, with an unbuttoned white shirt and trousers."
	icon_state = "british_sailor2"
	item_state = "british_sailor2"
	worn_state = "british_sailor2"

/obj/item/clothing/under/british_sailor3
	name = "british sailor trousers"
	desc = "White british sailor trousers. For when it's too hot to wear a shirt."
	icon_state = "british_sailor3"
	item_state = "british_sailor3"
	worn_state = "british_sailor3"

/obj/item/clothing/under/british_sailor4
	name = "grey british sailor clothes"
	desc = "A set of royal navy sailor clothes, with a grey shirt and trousers."
	icon_state = "british_sailor4"
	item_state = "british_sailor4"
	worn_state = "british_sailor4"

/obj/item/clothing/head/tricorne_british
	name = "royal navy tricorne"
	desc = "A blue tricorne, used by the british royal navy."
	icon_state = "tricorne_british"
	item_state = "tricorne_british"

/obj/item/clothing/head/tricorne_british_army
	name = "british Army tricorne"
	desc = "A red tricorne, used by the british army."
	icon_state = "tricorne_british2"
	item_state = "tricorne_british2"

/obj/item/clothing/head/bicorne_british_soldier
	name = "black bicorne"
	desc = "A black bicorne, commonly used by the armed forces."
	icon_state = "tricorne_british_soldier"
	item_state = "tricorne_british_soldier"

/obj/item/clothing/accessory/armband/british_scarf
	name = "blue scarf"
	desc = "A blue scarf, used by royal navy sailors."
	icon_state = "british_scarf"
	item_state = "british_scarf"

/obj/item/clothing/suit/storage/jacket/british_captain
	name = "royal navy captain jacket"
	desc = "A standard captain jacket of the royal navy. Blue with golden buttons, white laces and golden cuffs."
	icon_state = "british_captain"
	item_state = "british_captain"
	worn_state = "british_captain"

/obj/item/clothing/suit/storage/jacket/british_officer
	name = "royal navy officer jacket"
	desc = "A standard officer jacket of the royal navy. Blue with golden buttons."
	icon_state = "british_officer"
	item_state = "british_officer"
	worn_state = "british_officer"

/obj/item/clothing/suit/storage/jacket/british_soldier
	name = "british red jacket"
	desc = "The british redcoat, used by the british army and marines."
	icon_state = "british_soldier_jacket"
	item_state = "british_soldier_jacket"
	worn_state = "british_soldier_jacket"

/obj/item/clothing/head/chasseur_british
	name = "british feathered hat"
	desc = "A feathered black bicorne, used by the british light infantry."
	icon_state = "chasseur_br"
	item_state = "chasseur_br"

/* Colonial Portuguese Army & Navy Clothes*/

/obj/item/clothing/head/tricorne_portuguese
	name = "portuguese navy tricorne"
	desc = "A green tricorne, used by the Portuguese Navy."
	icon_state = "tricorne_portuguese"
	item_state = "tricorne_portuguese"

/obj/item/clothing/head/chasseur_portuguese
	name = "portuguese feathered hat"
	desc = "A feathered black bicorne, used by the portuguese light infantry."
	icon_state = "chasseur_pt"
	item_state = "chasseur_pt"

/obj/item/clothing/head/portuguese_army
	name = "portuguese army tricorne"
	desc = "A green tricorne, used by the portuguese army"
	icon_state = "tricorne_portuguese"
	item_state = "tricorne_portuguese"

/obj/item/clothing/suit/storage/jacket/portuguese_captain
	name = "portuguese captain jacket"
	desc = "A standard captain jacket of the portuguese navy. Blue with golden buttons, white laces and golden cuffs."
	icon_state = "portuguese_captain"
	item_state = "portuguese_captain"
	worn_state = "portuguese_captain"

/obj/item/clothing/suit/storage/jacket/portuguese_officer
	name = "portuguese officer jacket"
	desc = "A standard officer jacket of the portuguese navy. Blue with golden buttons."
	icon_state = "portuguese_officer"
	item_state = "portuguese_officer"
	worn_state = "portuguese_officer"

/obj/item/clothing/under/portuguese_sailor1
	name = "portuguese sailor clothes"
	desc = "A set of portuguese navy sailor clothes, with a white shirt and green trousers."
	icon_state = "portuguese_sailor1"
	item_state = "portuguese_sailor1"
	worn_state = "portuguese_sailor1"

/obj/item/clothing/under/portuguese_sailor2
	name = "open portuguese sailor clothes"
	desc = "A set of portuguese navy sailor clothes, with an unbuttoned white shirt and geen trousers."
	icon_state = "portuguese_sailor2"
	item_state = "portuguese_sailor2"
	worn_state = "portuguese_sailor2"

/obj/item/clothing/under/portuguese_sailor3
	name = "portuguese sailor trousers"
	desc = "Green portuguese sailor trousers. For when it's too hot to wear a shirt."
	icon_state = "portuguese_sailor3"
	item_state = "portuguese_sailor3"
	worn_state = "portuguese_sailor3"

/obj/item/clothing/under/portuguese_sailor4
	name = "portuguese sailor clothes with scarf"
	desc = "A set of portuguese navy sailor clothes, with a white shirt and green trousers. There's a green scarf attached."
	icon_state = "portuguese_sailor4"
	item_state = "portuguese_sailor4"
	worn_state = "portuguese_sailor4"


/* Colonial Spanish Army & Navy Clothes*/

/obj/item/clothing/head/tricorne_spanish
	name = "spanish navy tricorne"
	desc = "A yellow tricorne, used by the spanish navy."
	icon_state = "tricorne_spanish"
	item_state = "tricorne_spanish"

/obj/item/clothing/head/spanish_army
	name = "spanish army tricorne"
	desc = "A yellow tricorne, used by the spanish army."
	icon_state = "tricorne_spanish"
	item_state = "tricorne_spanish"

/obj/item/clothing/suit/storage/jacket/spanish_captain
	name = "spanish captain jacket"
	desc = "A standard Captain jacket of the spanish navy. Yellow with golden buttons, white laces and golden cuffs."
	icon_state = "spanish_captain"
	item_state = "spanish_captain"
	worn_state = "spanish_captain"

/obj/item/clothing/suit/storage/jacket/spanish_officer
	name = "spanish officer jacket"
	desc = "A standard Officer jacket of the spanish navy. Yellow with golden buttons."
	icon_state = "spanish_officer"
	item_state = "spanish_officer"
	worn_state = "spanish_officer"

/obj/item/clothing/suit/storage/jacket/spanish_soldier
	name = "spanish soldier jacket"
	desc = "A standard jacket of the spanish army. Yellow with red trimming."
	icon_state = "spanish_army"
	item_state = "spanish_army"
	worn_state = "spanish_army"

/obj/item/clothing/under/spanish_sailor1
	name = "spanish sailor clothes"
	desc = "A set of spanish navy sailor clothes, with brown shirt and trousers."
	icon_state = "spanish_sailor1"
	item_state = "spanish_sailor1"
	worn_state = "spanish_sailor1"

/obj/item/clothing/under/spanish_sailor2
	name = "open spanish sailor clothes"
	desc = "A set of spanish navy sailor clothes, with an unbuttoned brown shirt and trousers."
	icon_state = "spanish_sailor2"
	item_state = "spanish_sailor2"
	worn_state = "spanish_sailor2"

/obj/item/clothing/under/spanish_sailor3
	name = "spanish sailor trousers"
	desc = "Brown spanish sailor trousers. For when it's too hot to wear a shirt."
	icon_state = "spanish_sailor3"
	item_state = "spanish_sailor3"
	worn_state = "spanish_sailor3"

/obj/item/clothing/under/spanish_soldier
	name = "spanish soldier uniform"
	desc = "Blue spanish soldier trousers and a fancy white shirt."
	icon_state = "spanish_soldier"
	item_state = "spanish_soldier"
	worn_state = "spanish_soldier"

/* Colonial French Army & Navy Clothes*/

/obj/item/clothing/head/tricorne_french
	name = "french navy tricorne"
	desc = "A white and blue tricorne, used by the french navy."
	icon_state = "tricorne_french"
	item_state = "tricorne_french"

/obj/item/clothing/head/french_army
	name = "french army tricorne"
	desc = "A blue tricorne, used by the french army."
	icon_state = "tricorne_british"
	item_state = "tricorne_british"

/obj/item/clothing/suit/storage/jacket/french_captain
	name = "french captain jacket"
	desc = "A standard captain jacket of the french navy. White with golden buttons, blue laces and golden cuffs."
	icon_state = "french_captain"
	item_state = "french_captain"
	worn_state = "french_captain"

/obj/item/clothing/suit/storage/jacket/french_officer
	name = "french officer jacket"
	desc = "A standard officer jacket of the french navy. White with golden buttons."
	icon_state = "french_officer"
	item_state = "french_officer"
	worn_state = "french_officer"

/obj/item/clothing/under/french_officer
	name = "french officer clothes"
	desc = "A set of french officer clothes, with a light blue shirt and black trousers, both with golden buttons."
	icon_state = "french_officer"
	item_state = "french_officer"
	worn_state = "french_officer"

/obj/item/clothing/under/baycona
	name = "baycona outfit"
	desc = "A set of baycona officer clothes, this seems to be very old."
	icon_state = "baycona"
	item_state = "baycona"
	worn_state = "baycona"

/obj/item/clothing/under/french_sailor1
	name = "french sailor clothes"
	desc = "A set of french navy sailor clothes, with light blue shirt and trousers."
	icon_state = "french_sailor1"
	item_state = "french_sailor1"
	worn_state = "french_sailor1"

/obj/item/clothing/under/french_sailor2
	name = "open french sailor clothes"
	desc = "A set of french navy sailor clothes, with an unbuttoned light blue shirt and trousers."
	icon_state = "french_sailor2"
	item_state = "french_sailor2"
	worn_state = "french_sailor2"

/obj/item/clothing/under/french_sailor3
	name = "french sailor trousers"
	desc = "Light blue french sailor trousers. For when it's too hot to wear a shirt."
	icon_state = "french_sailor3"
	item_state = "french_sailor3"
	worn_state = "french_sailor3"

/obj/item/clothing/head/french_army
	name = "french army tricorne"
	desc = "A white and blue tricorne, used by the french army."
	icon_state = "tricorne_french"
	item_state = "tricorne_french"

/obj/item/clothing/head/chasseur_french
	name = "french feathered hat"
	desc = "A feathered black bicorne, used by the french light infantry."
	icon_state = "chasseur_fr"
	item_state = "chasseur_fr"

/* Colonial Dutch Army & Navy Clothes*/

/obj/item/clothing/head/tricorne_dutch
	name = "united provinces navy tricorne"
	desc = "An orange tricorne, used by the united provinces navy."
	icon_state = "tricorne_dutch"
	item_state = "tricorne_dutch"

/obj/item/clothing/head/chasseur_dutch
	name = "united Provinces feathered hat"
	desc = "A feathered black bicorne, used by the united provinces light infantry."
	icon_state = "chasseur_nl"
	item_state = "chasseur_nl"

/obj/item/clothing/head/dutch_army
	name = "united Provinces Army tricorne"
	desc = "An orange tricorne, used by the dutch united provinces army."
	icon_state = "tricorne_dutch"
	item_state = "tricorne_dutch"

/obj/item/clothing/suit/storage/jacket/dutch_captain
	name = "united provinces captain jacket"
	desc = "A standard captain jacket of the united provinces navy. Orange with golden buttons, white laces and golden cuffs."
	icon_state = "dutch_captain"
	item_state = "dutch_captain"
	worn_state = "dutch_captain"

/obj/item/clothing/suit/storage/jacket/dutch_officer
	name = "united provinces officer jacket"
	desc = "A standard officer jacket of the united provinces navy. Orange with golden buttons."
	icon_state = "dutch_officer"
	item_state = "dutch_officer"
	worn_state = "dutch_officer"

/obj/item/clothing/under/dutch_sailor1
	name = "dutch sailor clothes"
	desc = "A set of dutch navy sailor clothes, with a white shirt and orange trousers."
	icon_state = "dutch_sailor1"
	item_state = "dutch_sailor1"
	worn_state = "dutch_sailor1"

/obj/item/clothing/under/dutch_sailor2
	name = "open dutch sailor clothes"
	desc = "A set of dutch navy sailor clothes, with an unbuttoned white shirt and orange trousers."
	icon_state = "dutch_sailor2"
	item_state = "dutch_sailor2"
	worn_state = "dutch_sailor2"

/obj/item/clothing/under/dutch_sailor3
	name = "dutch sailor trousers"
	desc = "Orange dutch sailor trousers. For when it's too hot to wear a shirt."
	icon_state = "dutch_sailor3"
	item_state = "dutch_sailor3"
	worn_state = "dutch_sailor3"

//* Colonial Army Clothes*/
	/* Colonial Army Uniforms*/

/obj/item/clothing/under/generic_officer
	name = "officer clothes"
	desc = "A set of officer clothes, with a white shirt and black trousers, both with golden buttons."
	icon_state = "officer"
	item_state = "officer"
	worn_state = "officer"

/obj/item/clothing/under/dutch_soldier
	name = "dutch army uniform"
	desc = "A set of united provinces army clothes. Yellow shirts and trousers."
	icon_state = "dutch_army"
	item_state = "dutch_army"
	worn_state = "dutch_army"

/obj/item/clothing/under/portuguese_soldier
	name = "portuguese army uniform"
	desc = "A set of portuguese army clothes. Red shirt with black and white trousers."
	icon_state = "portuguese_army"
	item_state = "portuguese_army"
	worn_state = "portuguese_army"

/obj/item/clothing/under/french_soldier
	name = "French Army uniform"
	desc = "A set of french army clothes. White shirt with blue and white trousers."
	icon_state = "french_army"
	item_state = "french_army"
	worn_state = "french_army"

	/* Colonial Army Jackets*/ //officer army jackets seem to be... unfinished.

/obj/item/clothing/suit/storage/jacket/dutch_officer_army
	name = "united provinces army jacket"
	desc = "A standard army jacket of the united provinces army. Orange with golden buttons."
	icon_state = "dutch_army"
	item_state = "dutch_army"
	worn_state = "dutch_army"

/obj/item/clothing/suit/storage/jacket/spanish_officer_army
	name = "spanish army jacket"
	desc = "A standard army jacket of the spanish Army. Yellow with golden buttons."
	icon_state = "spanish_officer"
	item_state = "spanish_officer"
	worn_state = "spanish_officer"

/obj/item/clothing/suit/storage/jacket/portuguese_officer_army
	name = "portuguese army jacket"
	desc = "A standard army jacket of the portuguese Army. Green with golden buttons."
	icon_state = "portuguese_army"
	item_state = "portuguese_army"
	worn_state = "portuguese_army"

/obj/item/clothing/suit/storage/jacket/french_officer_army
	name = "french army jacket"
	desc = "A standard army jacket of the french army. White with blue trimmings."
	icon_state = "french_army"
	item_state = "french_army"
	worn_state = "french_army"

/obj/item/clothing/suit/storage/jacket/british_officer_army
	name = "british army jacket"
	desc = "A standard army jacket of the british army. Red and white."
	icon_state = "british_officer"
	item_state = "british_officer"
	worn_state = "british_officer"

/* Napoleonic Clothes*/

/obj/item/clothing/under/nightingale
	name = "nightingale dress"
	desc = "A modest nurse dress with a sown on apron. Often found worn by nurses tending to the injuries within wartime field hospitals."
	icon_state = "nightingale"
	item_state = "nightingale"
	worn_state = "nightingale"

/obj/item/clothing/head/nurse
	name = "nurse hat"
	desc = "A white nurse hat, symbolic of care and empathy."
	icon_state = "nursehat"
	item_state = "nursehat"
	worn_state = "nursehat"
	body_parts_covered = HEAD

/* Napoleonic Army Clothing*/

/obj/item/clothing/under/napoleonic
	name = "napoleonic french soldier uniform"
	desc = "A uniform of the french army, with golden epaulettes, black shirt and a gold buttoned white gilet." //gilet is a light jacket which would be worn under a coat
	icon_state = "nap_french_army"
	item_state = "nap_french_army"
	worn_state = "nap_french_army"

/obj/item/clothing/under/napoleonic/british
	name = "napoleonic british soldier uniform"
	desc = "A uniform of the british army, with a red shirt, blue epaulettes and white frogging." //criss cross on the sprite is called frogging.
	icon_state = "nap_british_army"
	item_state = "nap_british_army"
	worn_state = "nap_british_army"

/obj/item/clothing/under/napoleonic/blackwatch
	name = "napoleonic blackwatch soldier uniform"
	desc = "A uniform of the british army's scottish infantry. Often worn in fearsome highland charges with a red shirt, itchy kilt and a white saltire." //saltire is a cross often found in flags
	icon_state = "blackwatch"
	item_state = "blackwatch"
	worn_state = "blackwatch"

/obj/item/clothing/under/napoleonic/walloon
	name = "napoleonic walloon soldier uniform"
	desc = "A uniform of the spanish army. Often worn by swiss conscripts loyal to spain it has a dark navy shirt with a red gilet with gold buttons."
	icon_state = "walloon_guard"
	item_state = "walloon_guard"
	worn_state = "walloon_guard"

/obj/item/clothing/under/napoleonic/russian
	name = "napoleonic russian soldier uniform"
	desc = "A uniform of the russian army. It has brown trousers and a green shirt with a single line of gold buttons."
	icon_state = "nap_russian_army"
	item_state = "nap_russian_army"
	worn_state = "nap_russian_army"

/obj/item/clothing/under/napoleonic/patriot
	name = "patriotic american soldier uniform"
	desc = "A uniform of the american army. Often worn by proud defenders of freedom and liberty it is blue with a white saltire and a red undershirt."
	icon_state = "patriot"
	item_state = "patriot"
	worn_state = "patriot"

/obj/item/clothing/under/napoleonic/prussian
	name = "napoleonic prussian soldier uniform"
	desc = "A uniform of the prussian army. Often worn by professional troops it has a navy shirt with red and white leather shoulder epaulettes with a assortment of buttons."
	icon_state = "nap_prussian_army"
	item_state = "nap_prussian_army"
	worn_state = "nap_prussian_army"

/obj/item/clothing/under/napoleonic/jaeger
	name = "napoleonic jaeger soldier uniform"
	desc = "A uniform of the joint austrian and german army. It has a dark green shirt with black saltire, and a lime green collar and epaulletes."
	icon_state = "nap_jaegers"
	item_state = "nap_jaegers"
	worn_state = "nap_jaegers"

/obj/item/clothing/under/napoleonic/portuguese
	name = "napoleonic portuguese soldier uniform"
	desc = "A uniform of the portuguese army. Often worn by pennisula soldiers, it has a dark navy shirt with a white saltire."
	icon_state = "nap_portuguese_army"
	item_state = "nap_portuguese_army"
	worn_state = "nap_portuguese_army"

/obj/item/clothing/under/napoleonic/italian
	name = "napoleonic italian soldier uniform"
	desc = "A uniform of the italian army. It has a dark green shirt with a bright orange trimmings along the arms and feet and a white saltire."
	icon_state = "nap_portuguese_army"
	item_state = "nap_portuguese_army"
	worn_state = "nap_portuguese_army"

/obj/item/clothing/under/napoleonic/satsuma
	name = "japanese soldier uniform"
	desc = "A uniform of the imperial japanese army. It has a black buttoned shirt and blue trousers with a white harness."
	icon_state = "nap_satsuma"
	item_state = "nap_satsuma"
	worn_state = "nap_satsuma"

/obj/item/clothing/under/merchant_suit
	name = "merchant suit"
	desc = "A fancy imperial merchant suit."
	icon_state = "merchant_suit"
	item_state = "merchant_suit"
	worn_state = "merchant_suit"

/* Napoleonic Armor*/
// Can't add these helmets to blacksmithing.dm until code seperation of the napoleonic era or new functions make them inaccessible to early colonial settlers. @FantasticFwoosh

/obj/item/clothing/head/helmet/leather_infantry
	name = "leather infantry cap"
	desc = "A protective leather cap often worn by soldiers of early era modern warfare."
	icon_state = "nap_lea_infantry_cap"
	item_state = "nap_lea_infantry_cap"
	worn_state = "nap_lea_infantry_cap"
	body_parts_covered = HEAD
	armor = list(melee = 20, arrow = 25, gun = 8, energy = 25, bomb = 50, bio = 10, rad = 0)
	health = 25

/obj/item/clothing/head/helmet/leather_infantry/brown
	name = "brown leather infantry helmet"
	icon_state = "brown_nap_lea_infantry_cap"
	item_state = "brown_nap_lea_infantry_cap"
	worn_state = "brown_nap_lea_infantry_cap"

/obj/item/clothing/head/helmet/prussian
	name = "prussian leather infantry helmet"
	desc = "A protective leather cap often worn by prussian soldiers of the napoleonic era."
	icon_state = "prussian_lea_infantry_cap"
	item_state = "prussian_lea_infantry_cap"
	worn_state = "prussian_lea_infantry_cap"
	armor = list(melee = 35, arrow = 25, gun = 10, energy = 15, bomb = 40, bio = 20, rad = 0)
	health = 35

/obj/item/clothing/head/helmet/leather_infantry/blue //for nomads
	name = "blue leather infantry helmet"
	icon_state = "prussian_lea_infantry_cap"
	item_state = "prussian_lea_infantry_cap"
	worn_state = "prussian_lea_infantry_cap"

/obj/item/clothing/head/helmet/leather_infantry/red //for nomads
	name = "red leather infantry helmet"
	icon_state = "commissar"
	item_state = "commissar"
	worn_state = "commissar"

/obj/item/clothing/head/helmet/satsuma
	name = "satsuma infantry hat"
	desc = "A pointed black hat often worn by soldiers of imperial japan's satsuma era."
	icon_state = "nap_satsuma"
	item_state = "nap_satsuma"
	worn_state = "nap_satsuma"
	body_parts_covered = HEAD
	armor = list(melee = 20, arrow = 25, gun = 8, energy = 25, bomb = 50, bio = 10, rad = 0) //equal to infantry cap
	health = 25

/obj/item/clothing/head/helmet/napoleonic/dragoon
	name = "dragoon helmet"
	desc = "A bronze helmet with a impressive plume. It is often worn by napoleonic cavalry squadrons; though it is more for show it can still deflect harm."
	icon_state = "dragoon"
	item_state = "dragoon"
	worn_state = "dragoon"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 40, gun = 8, energy = 15, bomb = 45, bio = 20, rad = 0) //slightly stronger than a kettle helmet being its equal, protective conical outclasses it
	health = 32

/obj/item/clothing/head/helmet/napoleonic/bearskin
	name = "black napoleonic bearskin hat"
	desc = "A decorative parade hat felted from bear skin and bronze. Often worn by napoleonic grenadiers."
	icon_state = "nap_bearskin_hat"
	item_state = "nap_bearskin_hat"
	worn_state = "nap_bearskin_hat"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 40, gun = 8, energy = 15, bomb = 45, bio = 20, rad = 0)
	health = 30

/obj/item/clothing/head/helmet/napoleonic/bearskin/brown
	name = "brown napoleonic bearskin hat"
	icon_state = "b_nap_bearskin_hat"
	item_state = "b_nap_bearskin_hat"
	worn_state = "b_nap_bearskin_hat"

/obj/item/clothing/head/helmet/napoleonic/bearskin/white
	name = "white napoleonic bearskin hat"
	icon_state = "w_nap_bearskin_hat"
	item_state = "w_nap_bearskin_hat"
	worn_state = "w_nap_bearskin_hat"

/* Miscallaneous*/

//These two seem misplaced, refer to be moved to modern or their own apparel, quiver is wierdly placed too.
/obj/item/clothing/under/scavfit
	name = "Ripped outfit"
	desc = "A set of blue jeans and brown hoodie."
	icon_state = "scavfit"
	item_state = "scavfit"
	worn_state = "scavfit"

/obj/item/clothing/under/wastelander
	name = "outfit"
	desc = "A set of tan pants and a brown coat."
	icon_state = "wastelander"
	item_state = "wastelander"
	worn_state = "wastelander"

/obj/item/clothing/head/helmet/leather_infantry/commissar //rdming your men at random to 'inspire' them is against the rules
	name = "commisar hat"
	desc = "A protective leather cap often worn by squadron commanders of a grimdark future."
	icon_state = "commissar"
	item_state = "commissar"
	worn_state = "commissar"
	armor = list(melee = 35, arrow = 50, gun = 15, energy = 15, bomb = 40, bio = 20, rad = 0)
	health = 35
