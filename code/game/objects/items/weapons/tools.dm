//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

/* Tools!
 * Note: Multitools are /obj/item
 *
 * Contains:
 * 		Wrench
 * 		Screwdriver
 * 		Wirecutters
 * 		Welding Tool
 * 		Crowbar
 */

/*
 * Wrench
 */
/obj/item/weapon/wrench
	name = "wrench"
	desc = "A wrench with many common uses. Can be usually found in your hand."
	icon = 'icons/obj/items.dmi'
	icon_state = "wrench"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = 2.0
	matter = list(DEFAULT_WALL_MATERIAL = 150)
	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")


/*
 * Screwdriver
 */
/obj/item/weapon/screwdriver
	name = "screwdriver"
	desc = "You can be totally screwwy with this."
	icon = 'icons/obj/items.dmi'
	icon_state = "screwdriver"
	flags = CONDUCT
	slot_flags = SLOT_BELT | SLOT_EARS
	force = WEAPON_FORCE_NORMAL
	w_class = 1.0
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 3
	throw_range = 5
	matter = list(DEFAULT_WALL_MATERIAL = 75)
	attack_verb = list("stabbed")

/obj/item/weapon/screwdriver/New()
	switch(pick("red","blue","purple","brown","green","cyan","yellow"))
		if ("red")
			icon_state = "screwdriver2"
			item_state = "screwdriver"
		if ("blue")
			icon_state = "screwdriver"
			item_state = "screwdriver_blue"
		if ("purple")
			icon_state = "screwdriver3"
			item_state = "screwdriver_purple"
		if ("brown")
			icon_state = "screwdriver4"
			item_state = "screwdriver_brown"
		if ("green")
			icon_state = "screwdriver5"
			item_state = "screwdriver_green"
		if ("cyan")
			icon_state = "screwdriver6"
			item_state = "screwdriver_cyan"
		if ("yellow")
			icon_state = "screwdriver7"
			item_state = "screwdriver_yellow"

	if (prob(75))
		pixel_y = rand(0, 16)
	..()

/obj/item/weapon/screwdriver/attack(mob/living/carbon/M as mob, mob/living/carbon/user as mob)
	if (!istype(M) || user.a_intent == "help")
		return ..()
	if (user.targeted_organ != "eyes" && user.targeted_organ != "head")
		return ..()
	if ((CLUMSY in user.mutations) && prob(50))
		M = user
	return eyestab(M,user)

/*
 * Wirecutters
 */
/obj/item/weapon/wirecutters
	name = "wirecutters"
	desc = "This cuts wires."
	icon = 'icons/obj/items.dmi'
	icon_state = "cutters"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK
	throw_speed = 2
	throw_range = 9
	w_class = 2.0
	matter = list(DEFAULT_WALL_MATERIAL = 80)
	attack_verb = list("pinched", "nipped")
	sharp = TRUE
	edge = TRUE

/obj/item/weapon/wirecutters/New()
	if (!istype(src, /obj/item/weapon/wirecutters/boltcutters))
		if (prob(50))
			icon_state = "cutters-y"
			item_state = "cutters_yellow"
	..()

/obj/item/weapon/wirecutters/attack(mob/living/carbon/C as mob, mob/user as mob)
	..()

/*
 * Crowbar
 */

/obj/item/weapon/crowbar
	name = "crowbar"
	desc = "Used to remove floors and to pry open doors."
	icon = 'icons/obj/items.dmi'
	icon_state = "crowbar"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_PAINFUL
	throwforce = WEAPON_FORCE_NORMAL
	item_state = "crowbar"
	w_class = 2.0
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("attacked", "bashed", "battered", "bludgeoned", "whacked")

/obj/item/weapon/crowbar/red
	icon = 'icons/obj/items.dmi'
	icon_state = "red_crowbar"
	item_state = "crowbar_red"