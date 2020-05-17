/obj/item/weapon/storage/box
	name = "box"
	desc = "It's just an ordinary box."
	icon_state = "box"
	item_state = "syringe_kit"

// BubbleWrap - A box can be folded up to make cardboard
/obj/item/weapon/storage/box/attack_self(mob/user as mob)
	if (..()) return


/obj/item/weapon/storage/box/drinkingglasses
	name = "box of drinking glasses"
	desc = "It has a picture of drinking glasses on it."

	New()
		..()
		new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass(src)
		new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass(src)
		new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass(src)
		new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass(src)
		new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass(src)
		new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass(src)

/obj/item/weapon/storage/box/condimentbottles
	name = "box of condiment bottles"
	desc = "It has a large ketchup smear on it."

	New()
		..()
		new /obj/item/weapon/reagent_containers/food/condiment(src)
		new /obj/item/weapon/reagent_containers/food/condiment(src)
		new /obj/item/weapon/reagent_containers/food/condiment(src)
		new /obj/item/weapon/reagent_containers/food/condiment(src)
		new /obj/item/weapon/reagent_containers/food/condiment(src)
		new /obj/item/weapon/reagent_containers/food/condiment(src)



/obj/item/weapon/storage/box/cups
	name = "box of paper cups"
	desc = "It has pictures of paper cups on the front."
	New()
		..()
		new /obj/item/weapon/reagent_containers/food/drinks/sillycup( src )
		new /obj/item/weapon/reagent_containers/food/drinks/sillycup( src )
		new /obj/item/weapon/reagent_containers/food/drinks/sillycup( src )
		new /obj/item/weapon/reagent_containers/food/drinks/sillycup( src )
		new /obj/item/weapon/reagent_containers/food/drinks/sillycup( src )
		new /obj/item/weapon/reagent_containers/food/drinks/sillycup( src )
		new /obj/item/weapon/reagent_containers/food/drinks/sillycup( src )

/obj/item/weapon/storage/box/handcuffs
	name = "box of spare handcuffs"
	desc = "A box full of handcuffs."

	New()
		..()
		new /obj/item/weapon/handcuffs(src)
		new /obj/item/weapon/handcuffs(src)
		new /obj/item/weapon/handcuffs(src)
		new /obj/item/weapon/handcuffs(src)
		new /obj/item/weapon/handcuffs(src)
		new /obj/item/weapon/handcuffs(src)
		new /obj/item/weapon/handcuffs(src)


/obj/item/weapon/storage/box/pillbottles
	name = "box of pill bottles"
	desc = "It has pictures of pill bottles on its front."

	New()
		..()
		new /obj/item/weapon/storage/pill_bottle( src )
		new /obj/item/weapon/storage/pill_bottle( src )
		new /obj/item/weapon/storage/pill_bottle( src )
		new /obj/item/weapon/storage/pill_bottle( src )
		new /obj/item/weapon/storage/pill_bottle( src )
		new /obj/item/weapon/storage/pill_bottle( src )
		new /obj/item/weapon/storage/pill_bottle( src )


/obj/item/weapon/matchbox
	name = "matchbox"
	desc = "A small box of premium matches."
	icon = 'icons/obj/cigarettes.dmi'
	icon_state = "matchbox"
	item_state = "zippo"
	w_class = TRUE
	slot_flags = SLOT_BELT
	var/maxcap = 10
	var/currcap = 10
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