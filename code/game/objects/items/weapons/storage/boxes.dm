/obj/item/weapon/storage/box
	name = "box"
	desc = "It's just an ordinary box."
	icon_state = "box"
	item_state = "syringe_kit"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand.dmi',
		)

// BubbleWrap - A box can be folded up to make cardboard
/obj/item/weapon/storage/box/attack_self(mob/user as mob)
	if (..()) return

/obj/item/weapon/storage/box/drinkingglasses
	name = "box of drinking glasses"
	desc = "It has a picture of drinking glasses on it."
	New()
		..()
		for (var/i=1, i<= 12, i++)
			new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass(src)

/obj/item/weapon/storage/box/wineglasses
	name = "box of wine glasses"
	desc = "It has a picture of wine glasses on it."

	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wine(src)

/obj/item/weapon/storage/box/beermug
	name = "box of beer mugs"
	desc = "It has a picture of beer mugs on it."

	New()
		..()
		for (var/i=1, i<= 10, i++)
			new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/beermug(src)

/obj/item/weapon/storage/box/sandbags
	name = "box of sandbags"
	desc = "This is a very heavy box, it has a picture of sandbags on it.  Makes up to 4 barricades."
	can_hold = list(/obj/item/weapon/barrier/sandbag)
	New()
		..()
		for (var/i=1, i<= 12, i++)
			new /obj/item/weapon/barrier/sandbag(src)

/obj/item/weapon/storage/box/specialtyglass
	name = "box of specialty glasses"
	desc = "It has a picture of different drinking glasses on it."
	New()
		..()
		for (var/i=1, i<= 4, i++)
			new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/lowball(src)
			new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/flute(src)
			new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/cocktail(src)

/obj/item/weapon/storage/box/shotglass
	name = "box of shot glasses"
	desc = "It has a picture of shot glasses on it."
	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/shot(src)

/obj/item/weapon/storage/box/condimentbottles
	name = "box of condiment bottles"
	desc = "It has a large ketchup smear on it."

	New()
		..()
		for (var/i=1, i<= 6, i++)
			new /obj/item/weapon/reagent_containers/food/condiment(src)

/obj/item/weapon/storage/box/cups
	name = "box of paper cups"
	desc = "It has pictures of paper cups on the front."
	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/weapon/reagent_containers/food/drinks/sillycup(src)

/obj/item/weapon/storage/box/cutlery
	name = "box of cutlery"
	desc = "It has pictures of assorted flatware on the front."
	New()
		..()
		for (var/i=1, i<= 4, i++)
			new /obj/item/weapon/material/kitchen/utensil/fork(src)
			new /obj/item/weapon/material/kitchen/utensil/spoon(src)
			new /obj/item/weapon/material/kitchen/utensil/knife(src)

/obj/item/weapon/storage/box/handcuffs
	name = "box of spare handcuffs"
	desc = "A box full of handcuffs."

	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/weapon/handcuffs(src)

/obj/item/weapon/storage/box/pillbottles
	name = "box of pill bottles"
	desc = "It has pictures of pill bottles on its front."

	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/weapon/storage/pill_bottle(src)

/obj/item/weapon/storage/box/bowls
	name = "box of bowls"
	desc = "It has a picture of bowls on it."
	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/kitchen/wood_bowl(src)

/obj/item/weapon/storage/box/nood
	name = "box of noodles"
	desc = "It has a picture of dry noodles."
	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/weapon/reagent_containers/food/snacks/noodles(src)

/obj/item/weapon/storage/box/waffle
	name = "box of waffles"
	desc = "It has a picture of waffles."
	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/weapon/reagent_containers/food/snacks/waffles(src)

/obj/item/weapon/storage/box/canned
	name = "box of canned food"
	desc = "It has a picture of assorted can food brands."
	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/weapon/can/filled(src)

/obj/item/weapon/storage/box/wheat
	name = "box of unmilled wheat"
	desc = "It has a picture of a field of wheat."
	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/weapon/reagent_containers/food/snacks/grown/wheat(src)

/obj/item/weapon/storage/box/stermask
	name = "box of sterile masks"
	desc = "It has a picture of a blue sterile mask."
	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/clothing/mask/sterile(src)

/obj/item/weapon/storage/box/sterglove
	name = "box of sterile gloves"
	desc = "It has a picture of a white sterile gloves."
	New()
		..()
		for (var/i=1, i<= 8, i++)
			new /obj/item/clothing/gloves/color/white(src)

/obj/item/weapon/storage/box/ctail
	name = "box of cocktail garnishes"
	desc = "It has a celery, cocktail olives, and maraschino cherries."
	New()
		..()
		for (var/i=1, i<= 4, i++)
			new /obj/item/cocktail_stuff/celery(src)
			new /obj/item/cocktail_stuff/cocktail_olive(src)
			new /obj/item/cocktail_stuff/maraschino_cherry(src)

/obj/item/weapon/storage/box/occinn
	name = "box of spare Inn keys"
	desc = "It has a keychain on it."
	New()
		..()
		new /obj/item/weapon/key/civ/inn(src)
		new /obj/item/weapon/key/civ/room1(src)
		new /obj/item/weapon/key/civ/room2(src)
		new /obj/item/weapon/key/civ/room3(src)
		new /obj/item/weapon/key/civ/room4(src)
		new /obj/item/weapon/storage/belt/keychain(src)

/obj/item/weapon/storage/box/nbcbox
	name = "NBC Protection Box"
	desc = "cointains items that might increase your chances of survival against a Nuclear biological or a chemical attack."
	icon_state = "boxnbc"
	item_state = "boxnbc"
	w_class = ITEM_SIZE_NORMAL
	slot_flags = SLOT_BELT|SLOT_POCKET
	can_hold = list(
		/obj/item/clothing/accessory,
		/obj/item/clothing/suit/nbcponcho,
		/obj/item/weapon/pill_pack/potassium_iodide,
		/obj/item/weapon/pill_pack/adrenaline,
		/obj/item/clothing/mask/gas,
		/obj/item/stack/medical
		)
/obj/item/weapon/storage/box/nbcbox/sov/New()
	..()
	new /obj/item/clothing/mask/gas/soviet/gp5(src)
	new /obj/item/weapon/pill_pack/adrenaline(src)
	new /obj/item/weapon/pill_pack/potassium_iodide(src)
	new /obj/item/clothing/suit/nbcponcho(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)
	new /obj/item/stack/medical/advanced/sulfa/small(src)
	return
/obj/item/weapon/storage/box/nbcbox/ami/New()
	..()
	new /obj/item/clothing/mask/gas/modern2(src)
	new /obj/item/weapon/pill_pack/adrenaline(src)
	new /obj/item/weapon/pill_pack/potassium_iodide(src)
	new /obj/item/clothing/suit/nbcponcho/white(src)
	new /obj/item/stack/medical/bruise_pack/gauze(src)
	new /obj/item/stack/medical/advanced/sulfa/small(src)
	return
/obj/item/weapon/matchbox
	name = "matchbox"
	desc = "A small box of premium matches."
	icon = 'icons/obj/cigarettes.dmi'
	icon_state = "matchbox"
	item_state = "zippo"
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_BELT
	var/maxcap = 10
	var/currcap = 10
	flags = FALSE
	New()
		..()
		currcap = maxcap


/obj/item/weapon/matchbox/examine(mob/user)
	..(user)
	user << "It has [currcap] matches out of a maximum of [maxcap]."

/obj/item/weapon/matchbox/attack_hand(mob/living/human/H)
	if (currcap>=1 && (src == H.l_hand || src == H.r_hand))
		H << "You take a match from the matchbox."
		H.put_in_hands(new/obj/item/weapon/flame/match(H))
		currcap--
		return
	else if (currcap <= 0)
		H << "<span class='notice'>The matchbox is empty!</span>"
		currcap = 0
		return
	else
		..()

/obj/item/weapon/matchbox/attackby(obj/item/weapon/flame/match/W as obj, mob/user as mob)
	if (istype(W) && !W.lit && !W.burnt)
		if (prob(50))
			playsound(loc, 'sound/items/matchstick_lit.ogg', 25, FALSE, -1)
			W.lit = TRUE
			W.damtype = "burn"
			W.icon_state = "match_lit"
			processing_objects.Add(W)
		else
			playsound(loc, 'sound/items/matchstick_hit.ogg', 25, FALSE, -1)
	W.update_icon()
	return

/obj/item/weapon/storage/box/flare
	name = "box of flares"
	desc = "Contains 10 red flares."
	icon_state = "flare_box"
	can_hold = list(/obj/item/flashlight/flare)
	New()
		..()
		for (var/i=1, i<= 10, i++)
			new /obj/item/flashlight/flare(src)

/obj/item/weapon/storage/box/flare/attack_hand(mob/user as mob)
	..()
	update_icon()
/obj/item/weapon/storage/attack_self(mob/user as mob)
	..()
	update_icon()

/obj/item/weapon/storage/box/flare/update_icon()
	if (contents.len > 0)
		switch(contents.len)
			if (1 to 3)
				icon_state = "flare_box_33"
			if (4 to 7)
				icon_state = "flare_box_66"
			if (8 to INFINITY)
				icon_state = "flare_box_full"
	else
		icon_state = "flare_box_empty"
	
	
