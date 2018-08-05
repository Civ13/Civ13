/* Uniform Metadata: Soviet, German, Italian */


/obj/item/clothing/under
	var/swapped = FALSE


/obj/item/clothing/under/doctor
	name = "doctor's uniform"
	desc = "A sterile, nicely pressed suit for doctors."
	icon_state = "ba_suit"
	item_state = "ba_suit"

// pirates and partisans

/obj/item/clothing/shoes/swat/wrappedboots
	name = "\improper wrapped boots"
	icon_state = "wrappedboots"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, bullet = 60, laser = 50,energy = 25, bomb = 50, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6


// partisans / civs

/obj/item/clothing/under/civ1
	name = "Civilian Clothing"
	desc = "A nice set of threads for civilians. Smells of sweat and resentment."
	icon_state = "civuni1"
	item_state = "civuni1"
	worn_state = "civuni1"

/obj/item/clothing/under/civ2
	name = "Civilian Clothing"
	desc = "A nice set of threads for civilians. Smells of sweat and resentment."
	icon_state = "civuni2"
	item_state = "civuni2"
	worn_state = "civuni2"

/obj/item/clothing/under/civ3
	name = "Civilian Clothing"
	desc = "A nice set of threads for civilians. Smells of sweat and resentment."
	icon_state = "civuni3"
	item_state = "civuni3"
	worn_state = "civuni3"


// WEBBING - can hold everything but clothing

/obj/item/clothing/accessory/storage/webbing
	name = "bandolier"
	desc = "two cotton belts with small pouches for ammunition."
	icon_state = "bandolier"
	item_state = "bandolier"
	slots = 8

	New()
		..()
		hold.can_hold = list(/obj/item/ammo_casing/musketball,/obj/item/ammo_casing/musketball_pistol,/obj/item/ammo_casing/blunderbuss)

//pirate stuff

/obj/item/clothing/suit/storage/jacket/piratejacket1
	name = "black pirate jacket"
	desc = "A long black jacket."
	icon_state = "piratejacket1"
	item_state = "piratejacket1"
	worn_state = "piratejacket1"

/obj/item/clothing/suit/storage/jacket/piratejacket2
	name = "fancy pirate jacket"
	desc = "A fancy pirate jacket. This one is brown."
	icon_state = "piratejacket2"
	item_state = "piratejacket2"
	worn_state = "piratejacket2"

/obj/item/clothing/suit/storage/jacket/piratejacket3
	name = "blue pirate vest"
	desc = "A sleeveless pirate vest. This one is blue."
	icon_state = "piratejacket3"
	item_state = "piratejacket3"
	worn_state = "piratejacket3"

/obj/item/clothing/suit/storage/jacket/piratejacket4
	name = "black pirate vest"
	desc = "A sleeveless pirate vest. This one is black."
	icon_state = "piratejacket4"
	item_state = "piratejacket4"
	worn_state = "piratejacket4"

/obj/item/clothing/suit/storage/jacket/piratejacket5
	name = "fancy pirate jacket"
	desc = "A fancy pirate jacket. This one is red."
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
	name = "white shirt clothing"
	desc = "A set of clothes with a white shirt."
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
	name = "Pirate bandana"
	icon_state = "piratebandana1"
	item_state = "piratebandana1"

/obj/item/clothing/shoes/sailorboots1
	name = "black sailor boots"
	desc = "Classic black sailor boots."
	icon_state = "sailorboots1"
	item_state = "sailorboots1"
	worn_state = "sailorboots1"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, bullet = 60, laser = 50,energy = 25, bomb = 50, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6

/obj/item/clothing/shoes/sailorboots2
	name = "leather sailor boots"
	desc = "Classic leather sailor boots."
	icon_state = "sailorboots2"
	item_state = "sailorboots2"
	worn_state = "sailorboots2"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, bullet = 60, laser = 50,energy = 25, bomb = 50, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6

/////////british stuff/////////

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

/obj/item/clothing/head/tarred_hat
	name = "tarred hat"
	desc = "A tarred hat, used by sailors."
	icon_state = "tarred_hat"
	item_state = "tarred_hat"

/obj/item/clothing/head/tricorne_black
	name = "black tricorne"
	desc = "A black tricorne. Commonly used by navy officers."
	icon_state = "tricorne_black"
	item_state = "tricorne_black"

/obj/item/clothing/head/tricorne_british
	name = "Royal Navy tricorne"
	desc = "A blue tricorne, used by the British Royal Navy."
	icon_state = "tricorne_british"
	item_state = "tricorne_british"


/obj/item/clothing/accessory/armband/british_scarf
	name = "blue scarf"
	desc = "A blue scarf, used by Royal Navy sailors."
	icon_state = "british_scarf"
	item_state = "british_scarf"

/obj/item/clothing/suit/storage/jacket/british_captain
	name = "Royal Navy Captain jacket"
	desc = "A standard Captain jacket of the Royal Navy. Blue with golden buttons, white laces and golden cuffs."
	icon_state = "british_captain"
	item_state = "british_captain"
	worn_state = "british_captain"

/obj/item/clothing/suit/storage/jacket/british_officer
	name = "Royal Navy Officer jacket"
	desc = "A standard Officer jacket of the Royal Navy. Blue with golden buttons."
	icon_state = "british_officer"
	item_state = "british_officer"
	worn_state = "british_officer"