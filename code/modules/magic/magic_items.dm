// Magic Items and Potions

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/not_butter_beer
	name = "I-Can't-Believe-It's-Not-Butter-Beer"
	desc = "Wait, is it actually butter beer? No, you can't believe it's not!"
	icon_state = "oldstyle_beer"
	item_state = "beer"
	volume = 50
	New()
		..()
		reagents.add_reagent("not_butter_beer", 50)

/datum/reagent/drink/not_butter_beer
	name = "I-Can't-Believe-It's-Not-Butter-Beer"
	id = "not_butter_beer"
	description = "A buttery alcoholic beverage that feels magical."
	taste_description = "sweet buttery ale"
	color = "#c89d3c"

/datum/reagent/drink/not_butter_beer/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (M.juice < M.max_juice)
		M.juice = min(M.max_juice, M.juice + 1.0 * removed)
	M.eye_blurry = max(M.eye_blurry, 3)
	if (M.dizziness < 108)
		M.make_dizzy(108 - M.dizziness)


/obj/item/weapon/reagent_containers/food/drinks/bottle/small/green_goop
	name = "Professor Snip's Green Goop"
	desc = "A rare potion flask containing a bubbling green fluid."
	icon = 'icons/obj/magic_items.dmi'
	icon_state = "potion_green"
	item_state = "beer"
	volume = 5
	slot_flags = SLOT_BELT | SLOT_POCKET
	New()
		..()
		reagents.add_reagent("green_goop", 5)

/datum/reagent/drink/green_goop
	name = "Professor Snip's Green Goop"
	id = "green_goop"
	description = "A rare, swirling green goop. Smells like trouble, but tastes like pure energy."
	taste_description = "sour chemicals and raw power"
	color = "#00FF00"

/datum/reagent/drink/green_goop/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (M.juice < M.max_juice)
		M.juice = min(M.max_juice, M.juice + 20.0 * removed)
	M.stats["stamina"][1] = M.stats["stamina"][2]
	M.adjustToxLoss(1.0 * removed)


/obj/item/weapon/reagent_containers/food/snacks/chocotoad
	name = "Choco-Toad"
	desc = "A chocolate toad. Eating one instantly restores 50 Juice."
	icon = 'icons/obj/magic_items.dmi'
	icon_state = "chocotoad"
	volume = 10
	bitesize = 10
	biteamount = 1
	nutriment_amt = 2
	nutriment_desc = list("chocolate" = 2)

/obj/item/weapon/reagent_containers/food/snacks/chocotoad/On_Consume(var/mob/M)
	..()
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.juice < H.max_juice)
			H.juice = min(H.max_juice, H.juice + 50)

