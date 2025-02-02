/////////////////////
/* Forged Weaponry */
/////////////////////

// Arming Sword
/obj/item/heatable/forged/weapon
	name = "arming sword"
	desc = "A very common medieval medium-sized sword."
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "arming_sword"
	item_state = "longsword2"
	force = 40
	throwforce = 15
	cooldownw = 11
	sharpness = 25
	block_chance = 37
	throw_speed = 3
	throw_range = 3
	sharp = TRUE
	edge = TRUE
	drawsound = 'sound/items/unholster_sword01.ogg'
	hitsound = "slash_sound"
	attack_verb = list("slashed", "diced")
	slot_flags = SLOT_BELT | SLOT_BACK
	quenchable = TRUE
	handleable = TRUE


// Longsword
/obj/item/heatable/forged/weapon/longsword
	name = "longsword"
	desc = "A sword with a long blade. Commonly used in the medieval era."
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "longsword"
	item_state = "longsword"
	force = 60
	throwforce = 10
	cooldownw = 15
	block_chance = 47
	throw_speed = 2
	throw_range = 2


// Halberd
/obj/item/heatable/forged/weapon/halberd
	name = "halberd"
	desc = "A spear topped by an axe blade."
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "halberd"
	item_state = "halberd"
	force = 35
	throwforce = 24
	cooldownw = 12
	block_chance = 25
	throw_speed = 3
	throw_range = 4
	attack_verb = list("jabbed","impaled","ripped")


// Spear
/obj/item/heatable/forged/weapon/spear
	name = "spear"
	desc = "A simple and effective weapon for poking holes in your foes."
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "spear"
	item_state = "spear"
	force = 32
	throwforce = 32
	cooldownw = 12
	block_chance = 15
	throw_speed = 6
	throw_range = 11
	allow_spin = FALSE
	attack_verb = list("jabbed","impaled","ripped")


// Pike
/obj/item/heatable/forged/weapon/pike
	name = "spear"
	desc = "A simple and effective weapon for poking holes in your foes."
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "spear"
	item_state = "spear"
	force = 35
	throwforce = 16
	cooldownw = 13
	block_chance = 18
	throw_speed = 4
	throw_range = 7
	allow_spin = FALSE
	attack_verb = list("jabbed","impaled","ripped")


// Spear
/obj/item/heatable/forged/weapon/throwing_axe
	name = "spear"
	desc = "A simple and effective weapon for poking holes in your foes."
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "throwingaxe"
	item_state = "battleaxe"
	force = 40
	throwforce = 34
	cooldownw = 12
	block_chance = 15
	throw_speed = 6
	throw_range = 11
	allow_spin = FALSE
	tool_flags = TOOL_AXE | TOOL_KNIFE


// Spear
/obj/item/heatable/forged/weapon/battle_axe
	name = "spear"
	desc = "A simple and effective weapon for poking holes in your foes."
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "battleaxe"
	item_state = "battleaxe"
	force = 50
	throwforce = 16
	cooldownw = 12
	block_chance = 15
	throw_speed = 3
	throw_range = 4
	allow_spin = FALSE
	attack_verb = list("chopped", "torn", "cut")
	tool_flags = TOOL_AXE | TOOL_KNIFE