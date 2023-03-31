/*
 * The 'fancy' path is for objects like donut boxes that show how many items are in the storage item on the sprite itself
 * .. Sorry for the shitty path name, I couldnt think of a better one.
 *
 * WARNING: var/key_type is used for both examine text and sprite name. Please look at the procs below and adjust your sprite names accordingly
 *		TODO: Cigarette boxes should be ported to this standard
 *
 * Contains:
 *		Donut Box
 *		Egg Box<-- removed at some point before this -siro
 *		Candle Box
 *		Crayon Box<-- removed at some point before this -siro
 *		Cigarette Box
 *		Medal Box
 *		Pickle Jar
 */

/obj/item/weapon/storage/fancy
	item_state = "syringe_kit" //placeholder, many of these don't have inhands
	var/obj/item/key_type //path of the key item that this "fancy" container is meant to store
	var/opened = 0 //if an item has been removed from this container

/obj/item/weapon/storage/fancy/remove_from_storage()
	. = ..()
	if(!opened && .)
		opened = 1
		update_icon()


/obj/item/weapon/storage/fancy/update_icon()
	if(!opened)
		src.icon_state = initial(icon_state)
	else
		var/key_count = count_by_type(contents, key_type)
		src.icon_state = "[initial(icon_state)][key_count]"

/obj/item/weapon/storage/fancy/examine(mob/user)
	if(!..(user, 1))
		return

	var/key_name = initial(key_type.name)
	if(!contents.len)
		to_chat(user, "There are no [key_name]s left in the box.")
	else
		var/key_count = count_by_type(contents, key_type)
		to_chat(user, "There [key_count == 1? "is" : "are"] [key_count] [key_name]\s in the box.")

/*
 * Egg Box
 */

/obj/item/weapon/storage/fancy/egg_box
	icon = 'icons/obj/food/food.dmi'
	icon_state = "eggbox"
	name = "egg box"
	storage_slots = 12

	key_type = /obj/item/weapon/reagent_containers/food/snacks/egg
	can_hold = list(
		/obj/item/weapon/reagent_containers/food/snacks/egg,
		/obj/item/weapon/reagent_containers/food/snacks/boiledegg
		)

	startswith = list(/obj/item/weapon/reagent_containers/food/snacks/egg = 12)

/obj/item/weapon/storage/fancy/egg_box/empty
	startswith = null

/*
 * Donut box //Code needs complete overhaul, especially for the icon updates
 */

/obj/item/weapon/storage/fancy/donut_box
	name = "donut box"
	desc = "Mmm. Donuts."
	icon = 'icons/obj/food/donuts.dmi'
	icon_state = "donutbox"
	storage_slots = 6
	throwforce = WEAPON_FORCE_HARMLESS
	key_type = /obj/item/weapon/reagent_containers/food/snacks/donut
	can_hold = list(
		/obj/item/weapon/reagent_containers/food/snacks/donut,
		)
	var/list/donut_types = list(
		/obj/item/weapon/reagent_containers/food/snacks/donut/plain,
		/obj/item/weapon/reagent_containers/food/snacks/donut/berry,
		/obj/item/weapon/reagent_containers/food/snacks/donut/cherry,
		/obj/item/weapon/reagent_containers/food/snacks/donut/apple,
		/obj/item/weapon/reagent_containers/food/snacks/donut/caramel,
		/obj/item/weapon/reagent_containers/food/snacks/donut/chocolate,
		/obj/item/weapon/reagent_containers/food/snacks/donut/mint,
		/obj/item/weapon/reagent_containers/food/snacks/donut/banana,
		/obj/item/weapon/reagent_containers/food/snacks/donut/lime,
		/obj/item/weapon/reagent_containers/food/snacks/donut/grenadine,
		)
	var/random_donut
	var/random_donut2
	var/random_donut3

/obj/item/weapon/storage/fancy/donut_box/New()
	..()
	random_donut = pick(donut_types)
	random_donut2 = pick(donut_types)
	random_donut3 = pick(donut_types)
	for (var/i=1; i <= 2; i++)
		new random_donut(src)
		new random_donut2(src)
		new random_donut3(src)
	return

/obj/item/weapon/storage/fancy/donut_box/attack_hand(mob/living/user)
	..()
	if(loc == user)
		if(!opened)
			opened = 1
			update_icon()
	return

/obj/item/weapon/storage/fancy/donut_box/update_icon()
	..()
	if(!opened)
		src.icon_state = "donutbox"
	else
		overlays.Cut()
		src.icon_state = "donutbox_open"
		var/i = 0
		for(var/obj/item/weapon/reagent_containers/food/snacks/donut/D in contents)
			overlays += image('icons/obj/food/donuts.dmi', icon_state = "[D.icon_state]_inbox", pixel_x = i * 3)
			i++

/obj/item/weapon/storage/fancy/donut_box/empty/
/obj/item/weapon/storage/fancy/donut_box/empty/New()
	..()
	random_donut = null
	random_donut2 = null
	random_donut3 = null

/*
 * Candle Box
 */

/obj/item/weapon/storage/fancy/candle_box
	name = "candle pack"
	desc = "A pack of red candles."
	icon = 'icons/obj/candle.dmi'
	icon_state = "candlebox"
	opened = 1 //no closed state
	throwforce = 2
	w_class = ITEM_SIZE_TINY
	max_storage_space = 5
	slot_flags = SLOT_BELT

	key_type = /obj/item/weapon/flame/candle
	startswith = list(/obj/item/weapon/flame/candle = 5)


////////////
//CIG PACK//
////////////
/obj/item/weapon/storage/fancy/cigarettes
	name = "cigarette packet"
	desc = "A cigarette packet."
	icon = 'icons/obj/cigarettes.dmi'
	icon_state = "cigpacket"
	item_state = "cigpacket"
	w_class = ITEM_SIZE_TINY
	throwforce = WEAPON_FORCE_HARMLESS
	slot_flags = SLOT_BELT
	max_storage_space = 6

	can_hold = list(/obj/item/clothing/mask/smokable/cigarette, /obj/item/weapon/flame/lighter)
	key_type = /obj/item/clothing/mask/smokable/cigarette
	startswith = list(/obj/item/clothing/mask/smokable/cigarette = 6)

	var/customcolor = "#000000"
	var/lighter = FALSE //set to TRUE to make it spawn with a lighter inside
	var/randomize = FALSE

/obj/item/weapon/storage/fancy/cigarettes/New()
	..()
	flags |= NOREACT|OPENCONTAINER
	if (lighter)
		new /obj/item/weapon/flame/lighter/random(src)
	create_reagents(15 * storage_slots)//so people can inject cigarettes without opening a packet, now with being able to inject the whole one

/obj/item/weapon/storage/fancy/cigarettes/randompack
	randomize = TRUE

/obj/item/weapon/storage/fancy/cigarettes/randompack/New()
	..()
	if (randomize)
		icon_state = pick("luckystrike","marlboro","LSpacket","TMpacket","atika","pachka_papiros","prima")

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

/obj/item/weapon/storage/fancy/cigarettes/attack(mob/living/human/M as mob, mob/living/human/user as mob)
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

/obj/item/weapon/storage/fancy/cigarettes/marlboro
	name = "Marlboro cigarette packet"
	desc = "A Marlboro cigarette packet."
	icon_state = "marlboro"

/obj/item/weapon/storage/fancy/cigarettes/luckystrike
	name = "Lucky Strike cigarette packet"
	desc = "A Lucky Strike cigarette packet."
	icon_state = "luckystrike"

/obj/item/weapon/storage/fancy/cigarettes/newport
	name = "Newport cigarette packet"
	desc = "A Newport cigarette packet."
	icon_state = "newports"

/obj/item/weapon/storage/fancy/cigarettes/prima
	name = "Prima cigarette packet"
	desc = "A Prima cigarette packet."
	icon_state = "prima"
	startswith = list(/obj/item/clothing/mask/smokable/cigarette/unfiltered = 6)

/obj/item/weapon/storage/fancy/cigarettes/papirosi
	name = "papirosi packet"
	desc = "An unfiltered cigarettes packet."
	icon_state = "pachka_papiros"
	startswith = list(/obj/item/clothing/mask/smokable/cigarette/unfiltered = 6)

/obj/item/weapon/storage/fancy/cigar
	name = "cigar case"
	desc = "A case for holding your cigars when you are not smoking them."
	icon_state = "cigarcase"
	item_state = "cigarcase"
	icon = 'icons/obj/cigarettes.dmi'
	w_class = ITEM_SIZE_TINY
	max_storage_space = 6
	throwforce = WEAPON_FORCE_HARMLESS
	slot_flags = SLOT_BELT
	storage_slots = 7

	can_hold = list(/obj/item/clothing/mask/smokable/cigarette/cigar)
	key_type = /obj/item/clothing/mask/smokable/cigarette/cigar
	startswith = list(/obj/item/clothing/mask/smokable/cigarette/cigar = 6)

/obj/item/weapon/storage/fancy/cigar/New()
	..()
	flags |= NOREACT|OPENCONTAINER
	create_reagents(10 * storage_slots)

/obj/item/weapon/storage/fancy/medal
	name = "medal case"
	desc = "A case for holding medals to be awarded."
	icon_state = "medalcase"
	item_state = "medalcase"
	key_type = "medal"
	icon = 'icons/obj/cigarettes.dmi'
	w_class = ITEM_SIZE_TINY
	throwforce = WEAPON_FORCE_HARMLESS
	slot_flags = SLOT_BELT
	storage_slots = 14
	can_hold = list(/obj/item/clothing/accessory/medal)

/obj/item/weapon/storage/fancy/medal/update_icon()
	icon_state = "[initial(icon_state)][contents.len]"
	return

/obj/item/weapon/storage/fancy/medal/german_full
	name = "German medal case"
	startswith = list( /obj/item/clothing/accessory/medal/german/ww2/eastern_front,
						/obj/item/clothing/accessory/medal/german/ww2/assault_badge,
						/obj/item/clothing/accessory/medal/german/ww2/tank_destruction,
						/obj/item/clothing/accessory/medal/german/ww2/tank_destruction_gold,
						/obj/item/clothing/accessory/medal/german/ww2/wound,
						/obj/item/clothing/accessory/medal/german/ww2/wound_silver,
						/obj/item/clothing/accessory/medal/german/ww2/wound_gold,
						/obj/item/clothing/accessory/medal/german/ww2/eastern_front,
						/obj/item/clothing/accessory/medal/german/ww2/assault_badge,
						/obj/item/clothing/accessory/medal/german/ww2/tank_destruction,
						/obj/item/clothing/accessory/medal/german/ww2/tank_destruction_gold,
						/obj/item/clothing/accessory/medal/german/ww2/wound,
						/obj/item/clothing/accessory/medal/german/ww2/wound_silver,
						/obj/item/clothing/accessory/medal/german/ww2/wound_gold)

/obj/item/weapon/storage/fancy/medal/german_iron
	name = "German Iron Cross case"
	startswith = list( /obj/item/clothing/accessory/medal/german/ww2/iron_cross_knight_gold_oak = 2,
						/obj/item/clothing/accessory/medal/german/ww2/iron_cross_knight_oak = 2,
						/obj/item/clothing/accessory/medal/german/ww2/iron_cross_knight = 2,
						/obj/item/clothing/accessory/medal/german/ww2/iron_cross_1st = 4,
						/obj/item/clothing/accessory/medal/german/ww2/iron_cross_2nd = 4)

/obj/item/weapon/storage/fancy/medal/occupation/german_party
	name = "German Party Pin case"
	startswith = list( 	/obj/item/clothing/accessory/medal/german/ww2/nsdap_pin = 7,
						/obj/item/clothing/accessory/medal/german/ww2/ss_pin = 7)

/obj/item/weapon/storage/fancy/medal/occupation/minefarm
	name = "A case with miner and farmer union pins."
	startswith = list( 	/obj/item/clothing/accessory/medal/pin/worker/farmer = 7,
						/obj/item/clothing/accessory/medal/pin/worker/miner = 7)

/obj/item/weapon/storage/fancy/medal/occupation/factolabo
	name = "A case with labourer and factory worker union pins."
	startswith = list( 	/obj/item/clothing/accessory/medal/pin/worker/factory = 7,
						/obj/item/clothing/accessory/medal/pin/worker/labour = 7)

/obj/item/weapon/storage/fancy/medal/occupation/hospimedi
	name = "A case with labourer and factory worker union pins."
	startswith = list( 	/obj/item/clothing/accessory/medal/pin/worker/aristocrat = 7,
						/obj/item/clothing/accessory/medal/pin/worker/medic = 7)

/obj/item/weapon/storage/fancy/medal/german_action
	name = "German Action Medals case"
	startswith = list( 	/obj/item/clothing/accessory/medal/german/ww2/assault_badge = 5,
						/obj/item/clothing/accessory/medal/german/ww2/wound = 4,
						/obj/item/clothing/accessory/medal/german/ww2/wound_silver = 3,
						/obj/item/clothing/accessory/medal/german/ww2/wound_gold = 2)

/obj/item/weapon/storage/fancy/medal/japanese_pacific_full
	name = "japanese medal case"
	startswith = list( 	/obj/item/clothing/accessory/medal/japanese/ww2/east_asia = 10,
						/obj/item/clothing/accessory/medal/japanese/ww2/rising_sun = 4)

obj/item/weapon/storage/fancy/medal/japanese_china_full
	name = "japanese medal case"
	startswith = list( 	/obj/item/clothing/accessory/medal/japanese/ww2/china_incident1931 = 4,
						/obj/item/clothing/accessory/medal/japanese/ww2/china_incident1937 =6,
						/obj/item/clothing/accessory/medal/japanese/ww2/rising_sun = 4)


/obj/item/weapon/storage/fancy/cigar/full
	name = "cigar case"
	desc = "A case for holding your cigars when you are not smoking them."

/obj/item/weapon/storage/fancy/cigar/full/New()
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
	if (!istype(C))
		return
	if (reagents)
		reagents.trans_to_obj(C, (reagents.total_volume/contents.len))
	..()


/*
 * Pickle Jar
 */

/obj/item/weapon/storage/fancy/picklejar
	name = "pickle jar"
	desc = "a jar filled with pickles and vinegar"
	icon = 'icons/obj/food/food.dmi'
	icon_state = "picklejar"
	key_type = "pickles"
	throwforce = WEAPON_FORCE_NORMAL
	storage_slots = 7

	startswith = list(/obj/item/weapon/reagent_containers/food/snacks/pickle = 14)

/obj/item/weapon/storage/fancy/picklejar/update_icon()
	if (contents.len == 0)
		icon_state = "emptyjar_open"
	else if (contents.len < 14)
		icon_state = "picklejar_open"
	return