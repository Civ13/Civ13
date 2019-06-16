/*
 * The 'fancy' path is for objects like donut boxes that show how many items are in the storage item on the sprite itself
 * .. Sorry for the shitty path name, I couldnt think of a better one.
 *
 * WARNING: var/icon_type is used for both examine text and sprite name. Please look at the procs below and adjust your sprite names accordingly
 *		TODO: Cigarette boxes should be ported to this standard
 *
 * Contains:
 *		Donut Box
 *		Egg Box
 *		Candle Box
 *		Crayon Box
 *		Cigarette Box
 */

/obj/item/weapon/storage/fancy/
	icon = 'icons/obj/food.dmi'
	icon_state = "donutbox6"
	name = "donut box"
	var/icon_type = "donut"

/obj/item/weapon/storage/fancy/update_icon(var/itemremoved = FALSE)
	var/total_contents = contents.len - itemremoved
	icon_state = "[icon_type]box[total_contents]"
	return

/obj/item/weapon/storage/fancy/examine(mob/user)
	if (!..(user, TRUE))
		return

	if (contents.len <= 0)
		user << "There are no [icon_type]s left in the box."
	else if (contents.len == TRUE)
		user << "There is one [icon_type] left in the box."
	else
		user << "There are [contents.len] [icon_type]s in the box."

	return

/*
 * Egg Box
 */

/obj/item/weapon/storage/fancy/egg_box
	icon = 'icons/obj/food.dmi'
	icon_state = "eggbox"
	icon_type = "egg"
	name = "egg box"
	storage_slots = 12
	can_hold = list(
		/obj/item/weapon/reagent_containers/food/snacks/egg,
		/obj/item/weapon/reagent_containers/food/snacks/boiledegg
		)

/obj/item/weapon/storage/fancy/egg_box/New()
	..()
	for (var/i=1; i <= storage_slots; i++)
		new /obj/item/weapon/reagent_containers/food/snacks/egg(src)
	return

/*
 * Candle Box
 */

/obj/item/weapon/storage/fancy/candle_box
	name = "candle pack"
	desc = "A pack of red candles."
	icon = 'icons/obj/candle.dmi'
	icon_state = "candlebox5"
	icon_type = "candle"
	item_state = "candlebox5"
	throwforce = WEAPON_FORCE_HARMLESS
	slot_flags = SLOT_BELT


/obj/item/weapon/storage/fancy/candle_box/New()
	..()
	for (var/i=1; i <= 5; i++)
		new /obj/item/weapon/flame/candle(src)
	return


////////////
//CIG PACK//
////////////
/obj/item/weapon/storage/fancy/cigarettes
	name = "cigarette packet"
	desc = "A cigarette packet."
	icon = 'icons/obj/cigarettes.dmi'
	icon_state = "cigpacket0"
	item_state = "cigpacket"
	w_class = TRUE
	throwforce = WEAPON_FORCE_HARMLESS
	slot_flags = SLOT_BELT
	storage_slots = 6
	can_hold = list(/obj/item/clothing/mask/smokable/cigarette, /obj/item/weapon/flame/lighter)
	icon_type = "cigarette"
	var/customcolor = "#000000"
	var/lighter = FALSE //set to TRUE to make it spawn with a lighter inside

/obj/item/weapon/storage/fancy/cigarettes/update_icon()
	return

/obj/item/weapon/storage/fancy/cigarettes/New()
	..()
	flags |= NOREACT
	if (lighter)
		new /obj/item/weapon/flame/lighter/random(src)
	for (var/i = TRUE to storage_slots)
		new /obj/item/clothing/mask/smokable/cigarette(src)
	create_reagents(15 * storage_slots)//so people can inject cigarettes without opening a packet, now with being able to inject the whole one
	flags |= OPENCONTAINER

/obj/item/weapon/storage/fancy/cigarettes/randompack
	var/randomize = TRUE

/obj/item/weapon/storage/fancy/cigarettes/randompack/New()
	..()
	if (randomize)
		icon_state = pick("luckystrike","marlboro","prima","ls","tm","atika","pachka_papiros")

/obj/item/weapon/storage/fancy/cigarettes/randompack/lighter
	lighter = TRUE

/obj/item/weapon/storage/fancy/cigarettes/proc/do_color()
	if (customcolor)
		var/image/colorov = image("icon" = icon, "icon_state" = "[icon_state]_o")
		colorov.color = customcolor
		overlays += colorov

/obj/item/weapon/storage/fancy/cigarettes/remove_from_storage(obj/item/W as obj, atom/new_location)
	// Don't try to transfer reagents to lighters
	if (istype(W, /obj/item/clothing/mask/smokable/cigarette))
		var/obj/item/clothing/mask/smokable/cigarette/C = W
		reagents.trans_to_obj(C, (reagents.total_volume/contents.len))
	..()

/obj/item/weapon/storage/fancy/cigarettes/attack(mob/living/carbon/M as mob, mob/living/carbon/user as mob)
	if (!istype(M, /mob))
		return

	if (M == user && user.targeted_organ == "mouth")
		// Find ourselves a cig. Note that we could be full of lighters.
		var/obj/item/clothing/mask/smokable/cigarette/cig = null
		for (var/obj/item/clothing/mask/smokable/cigarette/C in contents)
			cig = C
			break

		if (cig == null)
			user << "<span class='notice'>Looks like the packet is out of cigarettes.</span>"
			return

		// Instead of running equip_to_slot_if_possible() we check here first,
		// to avoid dousing cig with reagents if we're not going to equip it
		if (!cig.mob_can_equip(user, slot_wear_mask))
			return

		// We call remove_from_storage first to manage the reagent transfer and
		// UI updates.
		remove_from_storage(cig, null)
		user.equip_to_slot(cig, slot_wear_mask)

		reagents.maximum_volume = 15 * contents.len
		user << "<span class='notice'>You take a cigarette out of the pack.</span>"
		update_icon()
	else
		..()

/obj/item/weapon/storage/fancy/cigar
	name = "cigar case"
	desc = "A case for holding your cigars when you are not smoking them."
	icon_state = "cigarcase"
	item_state = "cigarcase"
	icon = 'icons/obj/cigarettes.dmi'
	w_class = 1
	throwforce = WEAPON_FORCE_HARMLESS
	slot_flags = SLOT_BELT
	storage_slots = 7
	can_hold = list(/obj/item/clothing/mask/smokable/cigarette/cigar)
	icon_type = "cigar"

/obj/item/weapon/storage/fancy/cigar/New()
	..()
	flags |= NOREACT
	for (var/i = 1 to storage_slots)
		new /obj/item/clothing/mask/smokable/cigarette/cigar(src)
	create_reagents(15 * storage_slots)

/obj/item/weapon/storage/fancy/cigar/update_icon()
	icon_state = "[initial(icon_state)][contents.len]"
	return

/obj/item/weapon/storage/fancy/cigar/remove_from_storage(obj/item/W as obj, atom/new_location)
		var/obj/item/clothing/mask/smokable/cigarette/cigar/C = W
		if (!istype(C)) return
		reagents.trans_to_obj(C, (reagents.total_volume/contents.len))
		..()


/*
 * Pickle Jar
 */

/obj/item/weapon/storage/fancy/picklejar
	name = "pickle jar"
	desc = "a jar filled with pickles and vinegar"
	icon = 'icons/obj/food.dmi'
	icon_state = "picklejar"
	icon_type = "pickles"
	throwforce = WEAPON_FORCE_NORMAL
	storage_slots = 7


/obj/item/weapon/storage/fancy/picklejar/New()
	..()
	for (var/i=1; i <= 14; i++)
		new /obj/item/weapon/reagent_containers/food/snacks/pickle(src)
	return

/obj/item/weapon/storage/fancy/picklejar/update_icon()
	if (contents.len == 0)
		icon_state = "emptyjar_open"
	else if (contents.len < 14)
		icon_state = "picklejar_open"
	return