/obj/item/weapon/storage/ww2
	name = "messkit"
	desc = "It's a cheap tin messkit"
	icon_state = "gerkit"
	item_state = "gerkit"
	max_storage_space = 8
	w_class = ITEM_SIZE_SMALL
	max_w_class = 1
	can_hold = new/list(
	/obj/item/weapon/material/kitchen/utensil,
	/obj/item/weapon/reagent_containers/food/snacks,
	/obj/item/kitchen/snack_bowl,
	/obj/item/kitchen/wood_bowl,
	/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2,
	/obj/item/weapon/reagent_containers/glass/small_pot/german_kit_lid
	)

/obj/item/weapon/storage/ww2/german
	name = "german messkit"
	desc = "It's a standard issue messkit for german military personel"
	icon_state = "gerkit"
	item_state = "gerkit"

	New()
		..()
		new /obj/item/weapon/reagent_containers/glass/small_pot/german_kit_lid( src )
		new /obj/item/weapon/material/kitchen/utensil/fork( src )
		new /obj/item/weapon/material/kitchen/utensil/spoon( src )
		new /obj/item/weapon/material/kitchen/utensil/knife( src )

/obj/item/weapon/storage/ww2/unmeal
	name = "UN messkit"
	desc = "It's a cheap tin messkit for all peacekeeping personel."
	max_w_class = 2
	can_hold = new/list(
	/obj/item/weapon/material/kitchen/utensil,
	/obj/item/weapon/reagent_containers/food/snacks/MRE/generic,
	/obj/item/kitchen/snack_bowl,
	/obj/item/kitchen/wood_bowl,
	/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2,
	/obj/item/weapon/reagent_containers/food/drinks/can/water,
	)
	New()
		..()
		new /obj/item/weapon/material/kitchen/utensil/spoon( src )
		new /obj/item/weapon/reagent_containers/food/snacks/MRE/generic( src )
		new /obj/item/weapon/reagent_containers/food/drinks/can/water( src )
		new /obj/item/weapon/reagent_containers/food/drinks/can/water( src )

/obj/item/weapon/storage/ww2/german/proc/handle_item_insertion1(obj/item/W as obj, prevent_warning = FALSE)
	if (!istype(W)) return FALSE
	if (usr)
		usr.remove_from_mob(W)
		usr.update_icons()	//update our overlays
	W.loc = src
	W.on_enter_storage(src)
	if (usr)
		if (usr.client && usr.s_active != src)
			usr.client.screen -= W
		W.dropped(usr)
		add_fingerprint(usr)

		if (!prevent_warning)
			for (var/mob/M in viewers(usr, null))
				if (M == usr)
					usr << "<span class='notice'>You put \the [W] into [src].</span>"
				else if (M in range(1)) //If someone is standing close enough, they can tell what it is...
					M.show_message("<span class='notice'>\The [usr] puts [W] into [src].</span>")
				else if (W && W.w_class >= 3) //Otherwise they can only see large or normal items from a distance...
					M.show_message("<span class='notice'>\The [usr] puts [W] into [src].</span>")
		if (istype(W, /obj/item/weapon/reagent_containers/glass/small_pot/german_kit_lid))
			icon_state = "gerkit"
		orient2hud(usr)
		if (usr.s_active)
			usr.s_active.show_to(usr)
	update_icon()
	return TRUE

//Call this proc to handle the removal of an item from the storage item. The item will be moved to the atom sent as new_target
/obj/item/weapon/storage/ww2/german/proc/remove_from_storage1(obj/item/W as obj, atom/new_location)
	if (!istype(W)) return FALSE


	for (var/mob/M in range(1, loc))
		if (M.s_active == src)
			if (M.client)
				M.client.screen -= W

	if (new_location)
		if (ismob(loc))
			W.dropped(usr)
		if (ismob(new_location))
			W.layer = 20
			W.plane = GAME_PLANE
		else
			W.layer = initial(W.layer)
			W.plane = GAME_PLANE
		W.loc = new_location
	else
		W.loc = get_turf(src)

	if (istype(W, /obj/item/weapon/reagent_containers/glass/small_pot/german_kit_lid))
		icon_state = "gerkit_open"
	if (usr)
		orient2hud(usr)
		if (usr.s_active)
			usr.s_active.show_to(usr)
	if (W.maptext)
		W.maptext = ""
	W.on_exit_storage(src)
	update_icon()
	return TRUE

/obj/item/weapon/storage/ww2/shaving_kit
	name = "small pouch"
	desc = "It's a small leather pouch."
	icon_state = "shaving_kit"
	item_state = "shaving_kit"
	max_storage_space = 2
	w_class = ITEM_SIZE_TINY
	can_hold = new/list(
	/obj/item/weapon/material/kitchen/utensil/knife/razorblade,
	/obj/item/weapon/haircomb
	)

/obj/item/weapon/storage/ww2/shaving_kit/german
	name = "german shaving kit"
	desc = "It's a standard issue shaving kit for german military personel"
	icon_state = "shaving_kit_germ"
	item_state = "shaving_kit_germ"
	New()
		..()
		new /obj/item/weapon/material/kitchen/utensil/knife/razorblade( src )
		new /obj/item/weapon/haircomb( src )

/obj/item/weapon/storage/emergencykit
	name = "emergency kit"
	desc = "Bandages and a little something to keep you going."
	icon_state = "shaving_kit"
	item_state = "shaving_kit"
	max_storage_space = 4
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_ID
	can_hold = new/list(
	/obj/item/stack/medical/bruise_pack/bint,
	/obj/item/weapon/reagent_containers/food/snacks/hardtack
	)

/obj/item/weapon/storage/emergencykit/base
	New()
		..()
		new /obj/item/stack/medical/bruise_pack/bint/leather( src )
/obj/item/weapon/storage/emergencykit/base/generic
	New()
		..()
		new /obj/item/weapon/reagent_containers/food/snacks/hardtack( src )
/obj/item/weapon/storage/emergencykit/base/french
	New()
		..()
		new /obj/item/weapon/reagent_containers/food/snacks/hardtack/hardtacknwine( src )
/obj/item/weapon/storage/emergencykit/base/arabrich
	New()
		..()
		new /obj/item/weapon/reagent_containers/food/snacks/hardtack/hardtacknopium( src )
/obj/item/weapon/storage/emergencykit/base/arab
	New()
		..()
		new /obj/item/weapon/reagent_containers/food/snacks/hardtack/hardtacknkhat( src )
/obj/item/weapon/storage/emergencykit/base/brit
	New()
		..()
		new /obj/item/weapon/reagent_containers/food/snacks/hardtack/hardtacknbeer( src )
/obj/item/weapon/storage/emergencykit/base/germ
	New()
		..()
		new /obj/item/weapon/reagent_containers/food/snacks/hardtack/hardtacknale( src )

/obj/item/weapon/reagent_containers/glass/small_pot/german_kit_lid
	desc = "A lid to the german messkit. Can be used as a pot to boil water."
	name = "Messkit Lid"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "gerkit_lid"
	item_state = "bucket"
	w_class = ITEM_SIZE_TINY
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(10,20,30,40)
	volume = 40

/obj/item/weapon/storage/ww2/slunch
	name = "lunch kit"
	desc = "It's a lunch kit pressed from steel."
	icon_state = "slunch"
	item_state = "slunch"
	max_storage_space = 12
	w_class = ITEM_SIZE_SMALL