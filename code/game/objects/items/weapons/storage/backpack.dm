
/*
 * Backpack
 */

/obj/item/weapon/storage/backpack
	name = "backpack"
	desc = "You wear this on your back and put items into it."
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_backpacks.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_backpacks.dmi',
		)
	icon_state = "backpack0"
	item_state = "backpack"
	worn_state = "backpack"
	//most backpacks use the default backpack state for inhand overlays
	item_state_slots = list(
		slot_l_hand_str = "backpack",
		slot_r_hand_str = "backpack",
		)
	w_class = 4
	slot_flags = SLOT_BACK
	max_w_class = 4
	max_storage_space = 22 // can hold 2 w_class 4 items. 28 let it hold 3
	flammable = TRUE

/obj/item/weapon/storage/backpack/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (use_sound)
		playsound(loc, use_sound, 50, TRUE, -5)
	..()

/obj/item/weapon/storage/backpack/equipped(var/mob/user, var/slot)
	if (slot == slot_back && use_sound)
		playsound(loc, use_sound, 50, TRUE, -5)
	..(user, slot)

/*
/obj/item/weapon/storage/backpack/dropped(mob/user as mob)
	if (loc == user && use_sound)
		playsound(loc, use_sound, 50, TRUE, -5)
	..(user)
*/

/*
 * Satchel Types
 */

/obj/item/weapon/storage/backpack/satchel
	name = "leather satchel"
	desc = "It's a very fancy satchel made with fine leather."
	icon_state = "satchel"

/obj/item/weapon/storage/backpack/ww2/jap
	name = "japanese backpack"
	desc = "It's a standard issue backpack for japanese military personel"
	icon_state = "jappack"
	item_state = "jappack"
	worn_state = "jappack"
obj/item/weapon/storage/backpack/ww2/american
	name = "american backpack"
	desc = "It's a standard issue backpack for american military personel"
	icon_state = "uspack"
	item_state = "uspack"
	worn_state = "uspack"